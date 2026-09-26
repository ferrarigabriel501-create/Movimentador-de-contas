-- Requer psql; rode como superusuario local: psql -X -U postgres -d movimentador_contas -f scripts/05_attack_simulation.sql
\set ON_ERROR_STOP off
\echo '=== A: tentativa de UPDATE indevido; esperado ERROR permission denied ==='
\connect movimentador_contas usr_auditor_op localhost 5432
UPDATE workflow.movimentacoes SET observacao='adulterado' WHERE id=1;
\echo '=== A: tentativa de DELETE indevido; esperado ERROR permission denied ==='
DELETE FROM workflow.movimentacoes WHERE id=1;
\echo '=== B: leitura de credencial; esperado ERROR permission denied ==='
SELECT credencial_hash FROM workflow.usuarios WHERE id=1;
\echo '=== C: operação válida; esperado INSERT e trilha de auditoria ==='
-- API transacional: a função valida origem e ator; a tabela de contas não é diretamente alterável pelo operador.
SELECT workflow.transferir_conta('FAT-2026-001',2,'Transferencia autorizada para Central de Guias');
INSERT INTO workflow.comentarios(conta_id,usuario_autor_id,descricao)
VALUES(1,1,'Aguardando guia na Central de Guias');
\echo '=== Gestão: view acessível, tabela base negada ==='
\connect movimentador_contas usr_coordenador_gestao localhost 5432
SELECT * FROM workflow.vw_indicadores_setor ORDER BY setor_id;
SELECT * FROM workflow.contas_workflow;
\echo '=== DBA: leitura da auditoria ==='
\connect movimentador_contas usr_dba_admin localhost 5432
SELECT id,table_name,session_actor,operation,occurred_at FROM audit.logged_actions ORDER BY id;
