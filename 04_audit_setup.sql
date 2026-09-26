\connect movimentador_contas
CREATE TABLE audit.logged_actions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 schema_name text NOT NULL,
 table_name text NOT NULL,
 session_actor text NOT NULL,
 transaction_at timestamptz NOT NULL,
 occurred_at timestamptz NOT NULL,
 operation char(1) NOT NULL CHECK(operation IN ('I','U','D')),
 old_row jsonb,
 new_row jsonb
);
REVOKE ALL ON audit.logged_actions FROM PUBLIC;

GRANT SELECT ON audit.logged_actions TO role_admin_workflow;
CREATE FUNCTION audit.log_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog,audit AS $$
BEGIN
 INSERT INTO audit.logged_actions(schema_name,table_name,session_actor,transaction_at,occurred_at,operation,old_row,new_row)
 VALUES(TG_TABLE_SCHEMA,TG_TABLE_NAME,session_user,transaction_timestamp(),clock_timestamp(),substring(TG_OP,1,1),
        CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END);
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $$;
REVOKE ALL ON FUNCTION audit.log_change() FROM PUBLIC;
CREATE TRIGGER audit_contas AFTER INSERT OR UPDATE OR DELETE ON workflow.contas_workflow
 FOR EACH ROW EXECUTE FUNCTION audit.log_change();
CREATE TRIGGER audit_movimentacoes AFTER INSERT OR UPDATE OR DELETE ON workflow.movimentacoes
 FOR EACH ROW EXECUTE FUNCTION audit.log_change();

CREATE FUNCTION workflow.bloquear_historico() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
 RAISE EXCEPTION 'Historico de movimentacoes e append-only';
END $$;
REVOKE ALL ON FUNCTION workflow.bloquear_historico() FROM PUBLIC;
CREATE TRIGGER bloquear_historico BEFORE UPDATE OR DELETE ON workflow.movimentacoes
 FOR EACH ROW EXECUTE FUNCTION workflow.bloquear_historico();

CREATE FUNCTION workflow.transferir_conta(p_codigo varchar,p_destino bigint,p_observacao text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog,workflow AS $$
DECLARE v_conta workflow.contas_workflow%ROWTYPE;
        v_executor bigint; v_id bigint;
BEGIN
 IF session_user <> 'usr_auditor_op' THEN
  RAISE EXCEPTION 'Usuario operacional nao autorizado: %',session_user;
 END IF;
 SELECT id INTO v_executor FROM workflow.usuarios
 WHERE login_corporativo='auditor.op';
 IF v_executor IS NULL OR p_observacao IS NULL OR length(btrim(p_observacao))=0 THEN
  RAISE EXCEPTION 'Executor ou observacao invalida';
 END IF;
 SELECT * INTO v_conta FROM workflow.contas_workflow
 WHERE codigo_fatura=p_codigo FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Conta nao encontrada'; END IF;
 IF v_conta.setor_atual_id=p_destino THEN RAISE EXCEPTION 'Destino igual a origem'; END IF;
 IF NOT EXISTS (SELECT 1 FROM workflow.setores WHERE id=p_destino AND ativo) THEN
  RAISE EXCEPTION 'Setor de destino inexistente ou inativo';
 END IF;
 INSERT INTO workflow.movimentacoes(conta_id,setor_origem_id,setor_destino_id,usuario_executor_id,observacao)
 VALUES(v_conta.id,v_conta.setor_atual_id,p_destino,v_executor,p_observacao)
 RETURNING id INTO v_id;
 UPDATE workflow.contas_workflow SET setor_atual_id=p_destino WHERE id=v_conta.id;
 RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION workflow.transferir_conta(varchar,bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION workflow.transferir_conta(varchar,bigint,text) TO role_operacional;
