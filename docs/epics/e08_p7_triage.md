# P7-C3a — Triagem das falhas da suíte completa (Sol)

Pacote `C3a_sol_triage` de [P7](e08_p7_contract.md), [posse](e08_p7_files.json).
Entrada: C2 Luna, `C2_luna_full_verify_luna_p7_full2..full12` — 322 etapas
executadas pela fixture F1 (`tools/e08_p7_fixture.ps1 -AllTests`, bootstrap
1/251/255/256 excluído), 312 PASS, 10 FAIL. Checkout `.tools/map-editor-m5`,
branch `codex/e08`, HEAD `45b930ba` + acabamento C1 não commitado. Base E08
`c8b80b13` (contém o runtime F10 aceito `2ff1c00f`).

## Conclusão

**As 10 falhas são pré-existentes à E08. Nenhuma é ambiental nem causada por
P1–P7.** Nenhuma correção foi feita: todas exigiriam mudar oráculos de
save/schema/migração, de conteúdo publicado ou do contrato de persistência de
morte da expedição — fora do contrato E08 (apresentação/arte/áudio/mapas).

Evidências comuns a todas:

1. **E08 não alterou nenhuma entrada dessas etapas.** `git diff --name-only
   c8b80b13..HEAD` não toca `content/`, `resources/`, `data/expedition/`,
   `scenes/`, `project.godot`, `scripts/data/`, `tools/content/` nem
   `scripts/core/` (exceto `combat_animation_state.gd`, só `face()` ignorando
   ator morto/direção não finita e dois índices de pose de apresentação). Nenhum
   dos nove testes falhos mudou em E08 (`git log c8b80b13..HEAD -- tests/<t>.gd`
   vazio); o último commit de cada um é de 16–17/10 (`99f81668`, `a4f846eb`),
   anterior a E07 F2.
2. **As mesmas falhas, com as mesmas contagens e mensagens, já estavam
   registradas na F10.** `docs/map_editor/delivery/evidence/f10/author/q3/`:
   `verify_base_3c35f7f2.txt` (base master `3c35f7f2`) e
   `verify_steps_1_51.txt`/`verify_steps_52_299.txt` (branch F10) — hunter
   619/1, SWI 4 de 93, Sentinela 313, publicação 1123/36, UI menu 105/3, cartas
   42/7, downrank 112, clusters 186 e F8 resume 19/1 "death persisted before
   replacement" (103 s). `docs/map_editor/delivery/f10.md` (§Q3) já as declara
   "iguais na base `3c35f7f2`… esquema 7 esperado onde o perfil é 8 desde o
   E07 (20/10), migrações históricas, publicação E06".
3. **Determinísticas e independentes de ordem.** Cada uma reexecutada sozinha
   pelo wrapper (após `-Stage sync`, `c3a_sync_01`: 0 entradas, 2896 fontes)
   reproduz exatamente as mesmas mensagens/contagens que no lote C2 (publicação:
   36 linhas `ERROR` idênticas por `diff`).

## Tabela

| # | Etapa | Classificação | Causa e evidência | Ação | Risco residual no candidato |
|---|---|---|---|---|---|
| 1 | 68 `e05_hunter_catalog_test` (619/1) | pré-existente | Pino `ProfileState.SCHEMA_VERSION == 7`; o schema é 8 desde E07 F2 `3b15ae8a` (20/10). F10 base/branch idênticos. Rerun `c3a_rerun_isolated_01`: 619/1. | Nenhuma; atualizar pino é manutenção de teste pós-E07, fora de E08. | Nenhum: o catálogo Caçadora (618 checks) passa; só o pino de versão está velho. |
| 2 | 106 `e04_swordsman_integrated_closure_test` (4 de 93) | pré-existente | O teste reutiliza o `equipped` de um personagem no preset de outro; desde E07 F2 (`3b15ae8a`, posse individual de bens, `not_owner`/`invalid_equipment`) o `update_preset` recusa, e as três checagens seguintes dependem desse salvamento. F10 idêntico. Rerun `c3a_rerun_isolated_02`: 4 de 93. | Nenhuma (semântica de posse/save). | Baixo: posse individual coberta por `e07_f2_ownership_test` 45/0 no C2. |
| 3 | 152 `e05_sentinel_builds_test` (313, 1 falha) | pré-existente | Abre save de catálogo antigo e espera migração automática; desde F2 schema 1–7 abre protegido com `migration_required` (`profile_codec.gd` `decode`, confirmação explícita obrigatória — `docs/epics/e07/delivery/f2.md`). F10 idêntico. Rerun `c3a_rerun_isolated_03`. | Nenhuma (migração de save). | Baixo: migração confirmada coberta por `e07_f2_migration_test` 35/0 e `e07_f2_store_test` 87/0 no C2. |
| 4 | 221 `e06_publication_test` (1123/36) | pré-existente | 34× "native active resource matches publication": recursos nativos (`resources/build_effects/augment/*.tres`, inalterados desde `b0712451`) normalizados divergem da publicação recompilada após a evolução dos scripts de definição/conteúdo E06 (`be9bd8d7`, `9f05ce5c`, `b0ad3d44`, `99f81668`), todos antes da F10; 2× pino schema 7 e codificação de perfil antigo (F2). E08 não altera `scripts/data/` nem `tools/content/`. F10 base/branch 1123/36. Rerun `c3a_rerun_isolated_04`: 36 `ERROR` idênticos ao C2. | Nenhuma (oráculo de publicação/conteúdo, decisão de produto). | Baixo para o playtest: carregador ativo e exportação passam (`e06_export_content_test` só falha na contagem de mobs). |
| 5 | 223 `e06_ui_menu_test` (105/3) | pré-existente | Coleção histórica compartilhada entre personagens/perfil antigo publicado: contrato substituído pela posse individual e migração confirmada da F2. F10 base/branch e recheck F10 idênticos. Rerun `c3a_rerun_isolated_05`. | Nenhuma. | Baixo: menu/inventário dos perfis novos cobertos pelos demais testes de UI que passaram. |
| 6 | 230 `e06_permanent_cards_test` (42/7) | pré-existente | Migração schema4 automática, alternativo vendo a mesma coleção e JSON "schema/catálogo atual" fixado em 7 — todos contrariam F2 (schema 8, posse por personagem). F10 idêntico. Rerun `c3a_rerun_isolated_06`: 42/7. | Nenhuma. | Baixo: cartas por personagem cobertas por `e06_card_migration_store_test` e F2 no C2. |
| 7 | 243 `e06_skill_downrank_test` (112, 1 falha) | pré-existente | "schema5 explicit migration" chama `ProfileCodec.decode` direto e espera `ok`; F2 devolve `migration_required` para schema ≤ 7. F10 idêntico. Rerun `c3a_rerun_isolated_07`. | Nenhuma. | Nenhum para perfis novos. |
| 8 | 244 `e06_swordsman_cluster_test` (186, 3 falhas) | pré-existente | Mesmo mecanismo (fixture durável histórica e schema5/catálogo12 decodificados sem confirmação). F10 idêntico. Rerun `c3a_rerun_isolated_08`. | Nenhuma. | Nenhum para perfis novos. |
| 9 | 250 `e06_export_content_test` (162/2) | pré-existente | Espera 11 mobs; há 16 desde F10 Q4 `a49459c8` (3/11, cinco espécies em `resources/forest_phase/mob/`), presente em `2ff1c00f` e na base. F10 Q3 (antes da Q4) passava 157/0. Já registrado em [e08_dispatch.md](e08_dispatch.md) (P0: reproduz 16/11 contra o PCK F10 aceito). Rerun `c3a_rerun_isolated_09`. | Nenhuma; "não alterar oráculo" (P0). | Nenhum: diferença é a fase floresta aceita na F10. |
| 10 | 323 `e07_f8_candidate_resume` (19/1) | pré-existente | A sonda F8 (23/10) mata um mob e espera a cena ser substituída em ≤ 90 s. Desde `21b0b2fd`/`2c597e70` (31/10, "write mob deaths at once"/journal), mortes de mob vão ao diário no mesmo quadro **sem capturar nem substituir o mundo** (`main.gd` `_journal_flush`, `_on_enemy_died`), então a espera expira. Branch F10 (`verify_steps_52_299.txt`, etapa 299): FAIL 19/1, mesma mensagem, 103 s. Rerun do par prepare+resume `c3a_rerun_f8_pair_01` (ver abaixo). | Nenhuma (contrato de persistência de morte/expedição). | Baixo: diário/campanha/retomada cobertos no C2 por `map_editor_journal_capacity_test`, `e07_f5_campaign_test`, `e07_f5_death_kits_test` e `e07_f4_resume_staging_test` (PASS); o caminho "morte → substituição" da sonda não existe mais. |

## Reexecuções (wrapper P7, pacote `C3a_sol_triage`)

- `c3a_sync_01`: sincronização, 0 entradas alteradas, 2896 fontes rastreadas.
- `c3a_rerun_isolated_01`…`09`: um teste por chamada, na ordem 68, 106, 152,
  221, 223, 230, 243, 244, 250 — mesmas falhas/contagens do C2.
- `c3a_rerun_f8_pair_01`: `e07_f8_candidate_prepare` + `e07_f8_candidate_resume`.
  A sonda exige perfil sintético novo; a saída anterior do C2 na fixture
  (`.godot/verification/e07_f8/probe_headless`) foi preservada em
  `.godot/verification/p7/C3a_sol_triage_preserved_c2_f8_probe_headless` antes
  da rodada. Resultado: prepare PASS 16/0; resume FAIL 19/1 "death persisted
  before replacement" — idêntico ao C2 e à branch F10 (etapa 299).

## Causas comuns

- **E07 F2 `3b15ae8a` (20/10)** — schema 8, schema 1–7 abre protegido
  (`migration_required`) e bens/cartas passam a ter dono por personagem:
  explica 68, 106, 152, 223, 230, 243, 244 e 2 das 36 falhas de 221. Os
  testes E04–E06 não foram atualizados (F2 rodou 39 IDs selecionados, não a
  suíte completa).
- **Evolução do conteúdo/definições E06 após a publicação de 13/10** — 34 das
  36 falhas de 221.
- **F10 Q4 `a49459c8`** — cinco mobs da floresta: 250.
- **Diário de mortes 31/10 (`21b0b2fd`, `2c597e70`)** — 323.

Nenhum tema ambiental: não há dependência de bytes/CRLF da fixture (as falhas
são semânticas e idênticas às da F10 fora da fixture), nem de estado `user://`
ou ordem (reexecuções isoladas idênticas).

## Recomendações (decisão do coordenador/usuário)

1. Não corrigir dentro da E08. Atualizar esses oráculos é manutenção dos
   testes históricos ao contrato E07 F2/F10 (migração confirmada via prévia,
   posse individual, schema 8, 16 mobs, diário de mortes) e mexe em
   expectativas de save/migração/conteúdo — precisa de pacote próprio
   autorizado, com dono Sol.
2. Para o candidato P7, tratar a suíte como **312/322 + 10 falhas
   pré-existentes classificadas**, sem regressão E08.
3. O candidato usa APPDATA isolado e perfis novos (`prepare_e08_p4_review_profile.gd`),
   sem save pessoal; os caminhos de migração histórica não são exercitados
   no playtest.

## Limitações

- A prova de pré-existência usa os registros F10 (base `3c35f7f2` e branch
  F10) e a ausência de diff E08 nas entradas; não houve execução sobre
  `c8b80b13` (proibido terceiro checkout). Os commits F10 posteriores à Q3
  não foram auditados um a um; a Q4 explica a etapa 250 e as demais mensagens
  continuam idênticas às da Q3 no HEAD E08.
- A causa exata de cada divergência de normalização em 221 não foi isolada
  campo a campo; basta que seja anterior à F10 e fora de arquivos E08.
- Sem commit, push ou merge. Nenhum arquivo de runtime/teste alterado.
