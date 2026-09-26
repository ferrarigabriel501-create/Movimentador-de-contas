\connect movimentador_contas
INSERT INTO workflow.setores(id,nome) VALUES
 (1,'Auditoria'),(2,'Central de Guias'),(3,'Faturamento'),(4,'Recurso de Glosa');
INSERT INTO workflow.usuarios(id,login_corporativo,nome_completo,setor_id,credencial_hash,perfil_acesso) VALUES
 (1,'auditor.op','Operador de Auditoria',1,'$2b$12$DEMO_NAO_AUTENTICAVEL','operacional'),
 (2,'guias.op','Operador de Guias',2,'$2b$12$DEMO_NAO_AUTENTICAVEL','operacional'),
 (3,'faturamento.op','Operador de Faturamento',3,'$2b$12$DEMO_NAO_AUTENTICAVEL','operacional'),
 (4,'coordenador.gestao','Coordenador de Gestão',1,'$2b$12$DEMO_NAO_AUTENTICAVEL','gestao');
-- Identidades acima são dados fictícios; as contas de login do SGBD são criadas no script 03.
INSERT INTO workflow.contas_workflow(id,codigo_fatura,convenio,valor_aproximado,setor_atual_id,data_entrada) VALUES
 (1,'FAT-2026-001','Convenio Horizonte',1250.00,1,now()-interval '3 days'),
 (2,'FAT-2026-002','Convenio Leste',980.50,2,now()-interval '5 days'),
 (3,'FAT-2026-003','Convenio Sul',2220.00,4,now()-interval '7 days');
INSERT INTO workflow.movimentacoes(conta_id,setor_origem_id,setor_destino_id,usuario_executor_id,observacao) VALUES
 (2,1,2,1,'Guia encaminhada para validacao'),
 (3,3,4,3,'Recurso de glosa solicitado');
INSERT INTO workflow.comentarios(conta_id,usuario_autor_id,descricao) VALUES
 (1,1,'Em conferencia de materiais e medicamentos'),
 (2,2,'Aguardando guia complementar'),
 (3,3,'Divergencia em item faturado');
SELECT setval(pg_get_serial_sequence('workflow.setores','id'),4,true);
SELECT setval(pg_get_serial_sequence('workflow.usuarios','id'),4,true);
SELECT setval(pg_get_serial_sequence('workflow.contas_workflow','id'),3,true);
