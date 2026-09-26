\connect movimentador_contas
\echo '=== Autoria, instante e mudanças ==='
SELECT id,session_actor,transaction_at,occurred_at,table_name,operation,
 old_row->>'codigo_fatura' AS codigo_anterior,
 new_row->>'codigo_fatura' AS codigo_atual,
 old_row->>'setor_atual_id' AS setor_anterior,
 new_row->>'setor_atual_id' AS setor_novo,
 old_row,new_row
FROM audit.logged_actions ORDER BY id;
\echo '=== Integridade: movimentos anexados e conta no setor esperado ==='
SELECT c.codigo_fatura,c.setor_atual_id,m.id AS movimento_id,m.setor_origem_id,m.setor_destino_id,
 m.observacao,a.session_actor,a.occurred_at,
 (a.new_row->>'id')::bigint=m.id AS auditado_sem_divergencia
FROM workflow.movimentacoes m
JOIN workflow.contas_workflow c ON c.id=m.conta_id
LEFT JOIN audit.logged_actions a ON a.table_name='movimentacoes' AND a.operation='I'
 AND (a.new_row->>'id')::bigint=m.id
ORDER BY m.id;
\echo '=== Histórico carregado antes da criação das triggers não terá trilha retrospectiva ==='
SELECT count(*) FILTER (WHERE id <= 2) AS carga_inicial,
 count(*) FILTER (WHERE id > 2) AS novos_movimentos
FROM workflow.movimentacoes;
\echo '=== Ausência de UPDATE/DELETE em movimentações durante os testes ==='
SELECT count(*) AS eventos_de_alteracao_ou_exclusao
FROM audit.logged_actions WHERE table_name='movimentacoes' AND operation IN ('U','D');
