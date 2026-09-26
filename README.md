# Movimentador de Contas

**Instituição de ensino:** AEMS  
**Disciplina:** Administração de Banco de Dados  
**Integrante:** Gabriel Augusto Ferrari  
**Cenário:** Hospital Universitário

## 1. Objetivo

Este projeto implementa um banco PostgreSQL próprio para acompanhar o trânsito de contas hospitalares entre setores. Ele registra a localização atual da conta, as movimentações e as ocorrências do fluxo. Também aplica permissões por perfil, restringe a leitura de dados cadastrais e mantém uma trilha de auditoria das alterações relevantes.

O banco `movimentador_contas` é separado do ERP legado. O código da fatura funciona como referência lógica do processo; não há conexão, chave estrangeira ou operação de escrita no banco do ERP. Todos os registros da carga inicial são fictícios e não contêm dados de pacientes reais.

## 2. Modelo de dados

Os objetos de negócio ficam no esquema `workflow`; a trilha de alterações fica no esquema `audit`.

| Tabela | Finalidade | Restrições principais |
| --- | --- | --- |
| `workflow.setores` | Setores da esteira e status de atividade. | ID como chave primária; nome único e obrigatório. |
| `workflow.usuarios` | Identificação corporativa fictícia, setor e perfil. | Login único; vínculo obrigatório com setor; perfil validado. |
| `workflow.contas_workflow` | Fatura, convênio, valor aproximado, setor atual e data de entrada. | Código único; valor não negativo; setor referenciado. |
| `workflow.movimentacoes` | Histórico de origem, destino, executor, instante e observação. | Chaves estrangeiras; origem diferente do destino; observação obrigatória. |
| `workflow.comentarios` | Ocorrências e anotações ligadas à conta e ao autor. | Chaves estrangeiras; descrição obrigatória. |
| `audit.logged_actions` | Operação, ator, horário e estados anterior/novo. | Registro estruturado em JSONB, com ID próprio. |

A função `workflow.transferir_conta` valida o destino, bloqueia a linha da conta durante a transferência, insere a movimentação e atualiza o setor atual na mesma transação. Assim, o operador consegue movimentar a conta sem receber permissão direta para alterar `contas_workflow`. O comentário é registrado em comando separado.

## 3. Instalação e ordem de execução

Requisitos: PostgreSQL 14 ou superior e cliente `psql`. Os comandos abaixo são executados **a partir da raiz do repositório** com uma conta administrativa local. Os scripts de instalação foram preparados para um banco novo; não os execute novamente depois de instalados.

```bash
psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -f scripts/01_setup_database.sql
psql -X -v ON_ERROR_STOP=1 -U postgres -d movimentador_contas -f scripts/02_seed_data.sql
psql -X -v ON_ERROR_STOP=1 -U postgres -d movimentador_contas -f scripts/03_security_rbac.sql
psql -X -v ON_ERROR_STOP=1 -U postgres -d movimentador_contas -f scripts/04_audit_setup.sql
```

O script 01 cria o banco `movimentador_contas`; o 02 insere quatro setores, quatro usuários corporativos fictícios, três contas, duas movimentações iniciais e três comentários. O 03 configura roles, permissões e a view gerencial; o 04 instala a auditoria e a função de transferência. Os arquivos contêm o metacomando `\connect`, portanto devem ser executados pelo `psql`, não pelo editor SQL do pgAdmin.

Em seguida, execute a simulação e as consultas forenses. O script 05 conecta-se sucessivamente como os três usuários de teste; as senhas de demonstração estão declaradas no script 03. O `ON_ERROR_STOP off` do script 05 é proposital para continuar após os erros de permissão esperados. **Execute o script 05 uma única vez**, pois a operação válida adiciona uma movimentação.

```bash
psql -X -U postgres -d movimentador_contas -f scripts/05_attack_simulation.sql 2>&1 | tee evidencias/05_execucao.txt
psql -X -v ON_ERROR_STOP=1 -U postgres -d movimentador_contas -f scripts/06_forensic_queries.sql 2>&1 | tee evidencias/06_forense.txt
```

No PowerShell, use `Tee-Object -FilePath evidencias/05_execucao.txt` ou `Tee-Object -FilePath evidencias/06_forense.txt` no lugar de `tee ...`. As senhas são digitadas no prompt e não devem ser incluídas nos arquivos de evidência. As credenciais de demonstração presentes no script 03 servem somente para execução local; não devem ser utilizadas em uma instância exposta à rede.

## 4. Controle de acesso e proteção dos dados

As permissões padrão de `PUBLIC` são revogadas no banco e nos esquemas. As roles funcionais não fazem login diretamente:

| Role | Acesso concedido |
| --- | --- |
| `role_operacional` | Consulta setores, contas, movimentações e comentários; consulta somente `id`, `login_corporativo`, `nome_completo` e `setor_id` de usuários; insere comentários e executa `transferir_conta`. |
| `role_gestao` | Consulta somente a view `workflow.vw_indicadores_setor`, com contagens e tempo médio por setor. |
| `role_admin_workflow` | Administra tabelas e sequências do workflow e consulta a auditoria; não altera `audit.logged_actions`. |

Os logins `usr_auditor_op`, `usr_coordenador_gestao` e `usr_dba_admin` recebem essas roles, respectivamente. Suas senhas são criadas com `password_encryption = 'scram-sha-256'`. A coluna `credencial_hash` da tabela `usuarios` contém apenas marcadores fictícios para demonstrar a restrição em nível de coluna; a autenticação real dos testes ocorre pelas roles do PostgreSQL.

A view gerencial reúne indicadores sem expor credenciais, nomes de pacientes ou documentos pessoais. A função de auditoria usa `SECURITY DEFINER` e `search_path` controlado. O campo `session_actor` registra `session_user`, isto é, o login que iniciou a conexão. O administrador funcional só lê a auditoria. Como em qualquer instalação PostgreSQL, o proprietário dos objetos e o superusuário mantêm capacidade de administração: a proteção contra adulteração é aplicada aos perfis da aplicação, não ao superusuário da instância.

## 5. Simulação de incidentes: resultados obtidos

A execução do script 05 está registrada em [`evidencias/05_execucao.txt`](evidencias/05_execucao.txt). Foram testados os seguintes cenários:

| Cenário | Usuário e ação | Resultado observado |
| --- | --- | --- |
| A: adulteração | `usr_auditor_op` tentou `UPDATE` e `DELETE` em `workflow.movimentacoes`. | Os dois comandos foram rejeitados por falta de permissão na tabela. |
| B: coluna restrita | `usr_auditor_op` tentou consultar `credencial_hash` em `workflow.usuarios`. | Consulta rejeitada por falta de permissão. |
| C: movimentação válida | `usr_auditor_op` transferiu `FAT-2026-001` da Auditoria (setor 1) para a Central de Guias (setor 2) e adicionou um comentário. | A função retornou o ID de movimentação **3**; o comentário foi inserido (`INSERT 0 1`). |
| Gestão | `usr_coordenador_gestao` consultou a view e tentou consultar a tabela base `contas_workflow`. | A view retornou quatro setores; a leitura direta da tabela foi rejeitada. |

A consulta final do script 05 mostrou dois registros em `audit.logged_actions`, ambos atribuídos a `usr_auditor_op`: um `INSERT` em `movimentacoes` e um `UPDATE` em `contas_workflow`.

## 6. Análise forense e parecer técnico

A saída completa das consultas está em [`evidencias/06_forense.txt`](evidencias/06_forense.txt). A auditoria conserva os estados `OLD` e `NEW` em JSONB e os horários da transação e da ocorrência. Na conta `FAT-2026-001`, o estado anterior indicava `setor_atual_id = 1` e o novo estado indica `setor_atual_id = 2`. A movimentação 3 indica a mesma origem e o mesmo destino; a comparação com a imagem gravada na auditoria retornou verdadeiro.

O teste forense encontrou **duas movimentações da carga inicial** e **uma movimentação nova**. As duas iniciais não possuem log retrospectivo porque a carga foi feita antes da instalação dos triggers. Para o período testado, a consulta apontou **zero eventos de UPDATE ou DELETE em movimentações**. Além da falta de privilégio de escrita para a role operacional, um trigger impede alteração ou exclusão de movimentos já registrados, inclusive por uma role funcional que receba essas permissões.

Os erros de permissão aparecem na saída da simulação. Eles não geram uma linha em `audit.logged_actions`, pois o PostgreSQL rejeita os comandos antes que o trigger de alteração seja acionado. A combinação da saída do teste, do histórico preservado e da trilha de auditoria comprova o bloqueio dos acessos indevidos e a autoria da movimentação autorizada. Os horários mostrados nas evidências são os retornados pela sessão PostgreSQL na configuração local usada no teste.

## 7. Arquivos do repositório

```text
README.md
scripts/
  01_setup_database.sql
  02_seed_data.sql
  03_security_rbac.sql
  04_audit_setup.sql
  05_attack_simulation.sql
  06_forensic_queries.sql
evidencias/
  05_execucao.txt
  06_forense.txt
```
