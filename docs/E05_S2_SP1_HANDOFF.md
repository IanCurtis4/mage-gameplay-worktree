# E05-S2-SP1 — fronteira mínima de identidade

Estado: implementado na branch `codex/e05-evolutions`; parar no gate de Astra antes de SP2. Autoridade: `REVIEW_E05_S2_SP0_ASTRA.md`. Este pacote não habilita nenhum kit de produção.

## API e consumidores

- `ProfileCatalog.skill_ids_for_identity(base_class_id, evolution_id = &"")` devolve uma cópia da biblioteca legal (skills base da origem + skills específicas do ID direcional). Origem/identidade incompatível devolve lista vazia. `skill_is_allowed` usa a mesma validação de origem; `effective_skill_ranks` percorre a biblioteca resolvida. Metadados e `EvolutionDefinition` permanecem no catálogo existente, sem `IdentityRuntime` paralelo.
- `ProfileFacade._build_snapshot` captura essa biblioteca em `BuildSnapshot.library_skill_ids` junto dos IDs de origem/evolução e ranks efetivos. `copy_snapshot` copia a lista; `RunState.from_build` já copia o snapshot e mantém `class_id` como origem para o combate base.
- `ProfileFacade.available_build_options` continua derivando opções equipáveis dos ranks efetivos. `progression_skill_options` continua exibindo ramos futuros como indisponíveis, sem alteração de UI. `PlayerActor.available_skill_ids`, fonte única dos controles e HUD da run, agora recusa slot fora da biblioteca capturada antes de exigir definição concreta e rank. Snapshots sintéticos antigos sem a lista preservam o comportamento dos testes E04; o caminho persistente da fachada sempre a fornece.
- `ClassCatalog` não foi alterado: não há skill de evolução concreta a registrar neste pacote. O registro de definição/handler e seu dispatch ficam para os pacotes de habilidade, sem falsa disponibilidade no HUD.

## Versionamento e leitura de saves

Decisão: manter `ProfileState.SCHEMA_VERSION = 2`, `CATALOG_VERSION = 2` e `RULESET_ID = e04_learn_from_zero_v1`. A lista de biblioteca existe apenas no `BuildSnapshot` em memória; não é campo de `ProfileCodec`, não adiciona ID/rank persistível e não muda o significado dos campos salvos. Nenhum save real foi reescrito.

Evidência no codec existente: `ProfileCodec.decode` migra schema 1 e catalog 1 explicitamente, aceita schema/catalog 2 somente com o ruleset atual, valida `evolution_id` contra a origem, e valida compras/grants/slots por `skill_is_allowed`. `tests/profile_store_test.gd` cobre skill desconhecida ou de outra origem, catálogo incompatível e perfil somente leitura; `tests/e04_learn_from_zero_migration_test.gd` cobre migração do catalog 1; `tests/e05_evolution_catalog_test.gd` cobre releitura de evolução conhecida com conteúdo indisponível. Uma skill nova de produção que torne ranks persistíveis exigirá decisão explícita de versão/migração antes de registrar o ID; não há migração especulativa aqui.

## Prova e limites

`tests/e05_identity_boundary_test.gd` usa apenas fixtures isoladas: base, Defendente, Berserker e `mg_ar` resolvem a biblioteca correta, sem herança de outro ramo ou da afinidade; origem inválida é rejeitada. Após commit/reload de uma fixture pronta, preview, opções de build, snapshot de run, ator e fonte HUD conservam a mesma identidade. A run não expõe skill da outra origem mesmo com slot e rank injetados. As 12 identidades de `ProfileCatalog.pilot()` continuam `content_ready=false`.

Validação: `pwsh -NoProfile -File .\tools\verify.ps1 -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\review-engine\Godot.exe'` passou com importação, todas as suítes E01–E05 e smoke; a nova suíte passou com 18 checks. `git diff --check` não apontou erro de whitespace.

SP1 não implementa skill, token, ferida, UI nova, fórmula, dano ou migração. O ator ainda exige `ClassCatalog.skill_definition` para exibir uma ativa no HUD; portanto a entrada de fixture é intencionalmente não executável. Nenhum efeito de evolução foi balanceado ou submetido a playtest. Não atualizar `master` ou `codex/playtest` nesta entrega.
