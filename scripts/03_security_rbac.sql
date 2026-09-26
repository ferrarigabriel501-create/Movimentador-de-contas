\connect movimentador_contas
REVOKE ALL ON DATABASE movimentador_contas FROM PUBLIC;
REVOKE ALL ON SCHEMA public, workflow, audit FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA workflow, audit FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA workflow, audit FROM PUBLIC;
CREATE ROLE role_operacional NOLOGIN;
CREATE ROLE role_gestao NOLOGIN;
CREATE ROLE role_admin_workflow NOLOGIN;
GRANT CONNECT ON DATABASE movimentador_contas TO role_operacional,role_gestao,role_admin_workflow;
GRANT USAGE ON SCHEMA workflow TO role_operacional,role_gestao,role_admin_workflow;
GRANT USAGE ON SCHEMA audit TO role_admin_workflow;
GRANT SELECT ON workflow.setores,workflow.contas_workflow TO role_operacional;
GRANT SELECT(id,login_corporativo,nome_completo,setor_id) ON workflow.usuarios TO role_operacional;
GRANT INSERT ON workflow.comentarios TO role_operacional;
GRANT SELECT ON workflow.movimentacoes,workflow.comentarios TO role_operacional;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA workflow TO role_operacional;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA workflow TO role_admin_workflow;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA workflow TO role_admin_workflow;

CREATE VIEW workflow.vw_indicadores_setor WITH (security_barrier=true) AS
SELECT s.id AS setor_id, s.nome AS setor,
 count(DISTINCT c.id) AS contas_atuais,
 count(DISTINCT m.id) AS movimentacoes_recebidas,
 round(avg(extract(epoch FROM (m.ocorrido_em-c.data_entrada))/3600)::numeric,2) AS horas_ate_movimentacao_media
FROM workflow.setores s
LEFT JOIN workflow.contas_workflow c ON c.setor_atual_id=s.id
LEFT JOIN workflow.movimentacoes m ON m.setor_destino_id=s.id AND m.conta_id=c.id
GROUP BY s.id,s.nome;
GRANT SELECT ON workflow.vw_indicadores_setor TO role_gestao;

SET password_encryption = 'scram-sha-256';
CREATE ROLE usr_auditor_op LOGIN PASSWORD 'Trocar-Auditor-2026!';
CREATE ROLE usr_coordenador_gestao LOGIN PASSWORD 'Trocar-Gestao-2026!';
CREATE ROLE usr_dba_admin LOGIN PASSWORD 'Trocar-Admin-2026!';
GRANT role_operacional TO usr_auditor_op;
GRANT role_gestao TO usr_coordenador_gestao;
GRANT role_admin_workflow TO usr_dba_admin;
ALTER ROLE usr_auditor_op SET search_path = workflow;
ALTER ROLE usr_coordenador_gestao SET search_path = workflow;
ALTER ROLE usr_dba_admin SET search_path = workflow;
