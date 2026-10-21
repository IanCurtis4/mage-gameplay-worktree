# E07-F2 — despacho e propriedade exclusiva

20/10/2026. **EM_EXECUÇÃO**, por aval humano neste chat: “F1 foi entregue. Podemos começar F2.” Executor Sol/Alto, chat `01a150a6-7a1d-7ef2-8c91-cfd5ea1dc93c`.

Base real `61c3828085f7c5f757f436379f67e4edbfdf414e`, fechamento documental de F1, runtime `5b54cf4820502b50cc4d9159a01f866ad687b9ad`. F0 integrado é ancestral (`42604ef8674a2c28f5aadc633b73cda15178e0b3`). F1 entregue/validada, ainda sem integração operacional no playtest. F2 usa sua árvore exata como base isolada; não afirma que F1 foi integrada. Branch `codex/e07-f2`, checkout `C:/Users/João Pedro/.codex/worktrees/e07-f2/RagRPG`. Não escreve no checkout F1 nem no habitual.

## Decisões humanas desta liberação

D01 **APROVADA**: migração assistida proposta; sugestão somente com referência única, escolha explícita para bens disputados/sem referência/cartas soltas, cartas encaixadas seguem host, prévia das referências removidas, preservação de IDs/metadados/recibos e confirmação completa antes de gravar. Gold legado zero. Resposta: “Aprovar migração assistida proposta”. Não é autorização para migrar save pessoal.

D02 **APROVADA SOMENTE NO DELTA F2**: uma expedição pendente por personagem; consulta livre no lobby, sem alterar build/equipamento/gastar bens/iniciar outra fase até concluir; alts livres. Resposta: “Aprovar uma expedição e bloqueio proposto”. Quest antecipada, simulação dos estágios e demais escolhas D02 não foram respondidas.

Contrato v1 e guia persistence_and_identity, com estes deltas humanos, regem a implementação. Schema reservado **8**, catálogo14/ruleset inalterados.

## Manifesto e transferência

Dono exclusivo F2 dos seguintes existentes em scripts/core/: profile_state.gd, character_state.gd, profile_codec.gd, profile_store.gd, profile_facade.gd, build_snapshot.gd, run_build_service.gd, run_card_inventory.gd, equipment_instance.gd. F1 não modificou esses arquivos em relação ao playtest.

Novos exclusivos: scripts/core/expedition/ownership/character_assets.gd, migration_plan.gd, expedition_asset_lock.gd; seus .uid; tests/e07_f2_ownership_test.gd, e07_f2_migration_test.gd, e07_f2_store_test.gd, e07_f2_integration_test.gd e .uid; fixtures em tests/fixtures/e07/f2/**.

Runner tools/verify.ps1 transferido sequencialmente de F1 entregue/idle para F2, apenas para registrar os testes F2 e isolamento necessário; nenhum escritor paralelo. Documentação exclusiva: este despacho, delivery/f2.md, f2_api.md e seção F2 em docs/epics/e07.md. Decisões/contrato arquiteturais conservados; este despacho registra a resposta humana prevalecente.

Regressões legadas de perfil/inventário serão executadas e avaliadas por impacto. Mudanças necessárias nas expectativas da posse compartilhada deverão ser nominais e justificadas antes de editar; nenhuma expectativa será afrouxada para esconder falhas.

## Resultado e aceite

MigrationPlan dry_run/validate/apply com digest/revision e mapa completo; CharacterAssets preview/commit via mesmo ProfileStore, queries por dono, wallet inteira com limites, unlocks por perfil e seção tipada de expedições. Posse em presets/build/opções/equip/encaixes/loot. migration_required bloqueia load/commit automático; unknowns, backup, retry e recuperação preservados. I10/I11 e integrações de perfil/inventário. Sem lojas/consumíveis, UI, novos consumidores F3+, migração pessoal, playtest/master/push.

Validação: Godot4.7.2 standard, tools/verify.ps1 por impacto, fixture explícita; supervisão Luna delimitada e consolidação Sol. CLI versionado de workflow e docs/WORKFLOW_TOOLING.md ausentes na base: diagnóstico por Git/contratos conforme guia validation, sem inventar tooling.

## Transferência complementar antes da edição —20/10

A inspeção dos consumidores reais encontrou três fronteiras necessárias a I10: scripts/core/build_presentation.gd (DTO do inventário), run_reward_service.gd (projeção após loot) e run_state.gd (atribuição de inventário inclusive refresh admin já existente em main). Estes três arquivos ficam exclusivos de F2 no delta de posse, sequencialmente a F1 entregue. Não há edição de main/character_menu/atores. F3 recebe RunState/RewardService somente após entrega/integração F2. A expansão corrige consumidores do contrato, sem nova escolha de produto.

## Transferência dos testes de regressão — após diagnóstico Luna

Antes de editar: tests/e06_tx_fixture.gd e tests/profile_store_test.gd ficam exclusivos de F2. A fixture passa a atribuir explicitamente suas aquisições ao personagem primário de teste. profile_store conserva os oráculos históricos no leitor histórico e substitui somente o aceite de conversão automática por migration_required/bytes preservados; a aplicação confirmada é coberta pelos testes F2. Não altera fórmulas ou expectativas de efeitos. Fonte suja anterior e falhas ficam preservadas em baseline_dirty_sources.zip e luna_baseline_*_01.

## Adequação nominal das regressões históricas — antes da edição

F2 assume exclusivamente os testes tests/e06_migration_test.gd, tests/stat_threshold_migration_test.gd, tests/e05_hunter_catalog_migration_test.gd, tests/e04_learn_from_zero_migration_test.gd, tests/e05_defender_catalog_migration_test.gd, tests/e05_berserker_catalog_migration_test.gd, tests/e05_elementalist_catalog_migration_test.gd, tests/e05_spiritualist_catalog_migration_test.gd, tests/e06_tx_migration_test.gd, tests/e06_power_migration_test.gd, tests/e06_card_migration_store_test.gd, tests/e06_all_skill_migration_test.gd. O helper novo tests/fixtures/e07/f2/confirmed_history.gd escolhe e confirma destinos somente de fixtures isoladas e exige que o leitor público primeiro retorne migration_required; não é policy/default de produção. Os testes continuam usando MigrationPlan/ProfileStore reais e os mesmos oráculos de atributos/catálogos/metadados. Factories que sintetizam envelopes antigos removem somente campos de schema8; expectativas de posse compartilhada/conversão ao abrir são atualizadas nominalmente segundo D01. Nenhum leitor/gravador paralelo de produção.

Transferência complementar de fixtures antes da edição: tests/e06_admin_profile_test.gd (confirmação D01 na migração histórica administrativa) e tests/e07_f1_composition_test.gd (dono explícito nos exemplares/cartas sintéticos). Somente setup/contrato de posse; oráculos de efeitos, dano e geometria preservados.
