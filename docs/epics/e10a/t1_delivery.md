# E10a T1 — recibo da costura de base e das primitivas de alvo (C1)

Papel: Sol (Claude Opus 5.5). Contrato: [e10a_contract.md](../e10a_contract.md) §2. API publicada:
[t1_base_seam_api.md](t1_base_seam_api.md).

## Base e checkout

| Item | Valor |
|---|---|
| SHA-base | `6938db71dc6bd56cce2658bcfbe7af956849ab8c` (docs(e10a): open the Acolyte family subepic with index and contract), ponta de `claude/e10a-arquitetura-a413a1` |
| Branch | `claude/e10a-t1-ae3f9f` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\e10a-t1-ae3f9f` |
| Commits do código | `f71f564c` (costura e primitivas), `574264e7` (teste de VFX do `shadow`), `fd8b5718` (WIP da investigação do vazamento), `03a2bf51` (correção do vazamento; substitui o WIP sem reescrever o histórico) |
| Commit verificado pela suíte | `03a2bf51` |
| Commit entregue | o commit deste recibo (ponta da branch) |
| Engine | `Godot_v4.7.2-stable_win64.exe` (`4.7.2.stable.official.ed1daf0bf`); ver limitação 1 |

Sem push, sem `master`, sem tocar em `codex/playtest` nem no save pessoal. Perfis e saves só de
fixture (diretórios temporários dos testes).

## Entregas (C1.1–C1.13)

1. **Registro de bases** `scripts/classes/class_base_registry.gd` com `acolyte`; classe
   `ClassBase` em `scripts/classes/bases/class_base.gd`; esqueleto
   `scripts/classes/bases/acolyte/acolyte_base.gd` (não pronto) e fragmentos. Os catálogos
   agregam os dados do módulo: `IdentityIds` (atributos, `is_base_class`), `ClassCatalog`
   (definição composta, com o campo novo `ClassDefinition.basic_delivery`), `ProfileCatalog`
   (biblioteca na carteira de base, disponibilidade na criação), `SkillDependencyRules`
   (`requirements_for`), `BuildEffectCatalog`, `FeedbackRecipeCatalog`, `SkillCopy` e
   `SkillPresentation` (pela agregação de `ClassKitRegistry`).
2. **Dois módulos por jogador** (`PlayerActor.origin_kit` + `kit`) com a composição de C1.4.
3. **`priest` e `cultist`** no `ClassKitRegistry` com origem `acolyte` e ramo `2-1`/`2-2` por
   dado; `IdentityIds.evolution_origin`, `kit_affinity` e o `ProfileCatalog` leem o registro;
   esqueletos `scripts/classes/{priest,cultist}/<id>_kit.gd` e fragmentos.
4. **Alvo inimigo** (C1.6): sobrescrita nos dois caminhos, recusa do chefe, desvio no commit
   com o RNG do inimigo, dano entre inimigos com autoria do jogador, isca `KitDecoy`.
5. **Modificadores** (C1.7): dano recebido (filtros de autor e elemento) e acerto, compostos em
   `CombatMath`; desorientação de movimento, recusada pelo chefe.
6. **Elementos** (C1.8): `shadow` aceito; cor e efeito de `light` e `shadow`; Paladino e
   Taumaturgo mostrados em `light`; lista exata de lacunas de áudio (abaixo).
7. **Snapshot e verificador** (C1.9, C1.12): campos novos no manifesto, fragmentos das pastas
   novas; `tools/verify.ps1` descobre `tests/e10a/**/*_test.gd`.
8. **Prova** (C1.13): `scripts/classes/fixture/fixture_base.gd` e o `FixtureKit` sobre `priest`;
   `tests/e10a/base_seam_test.gd` (171 checks) e `tests/e10a/enemy_target_test.gd` (88 checks,
   com a vigia de ciclos de script).
9. **API** em `docs/epics/e10a/t1_base_seam_api.md`.

## Decisões de implementação dentro do contrato

Para a arquitetura conferir (nenhuma muda escolha de produto):

- **Ganchos de cast.** `can_cast` consulta os dois módulos. `on_cast_requested`,
  `on_cast_confirmed` e `resolve_cast` vão só ao dono da skill. O outro módulo recebe
  `on_base_skill_committed` no mesmo instante, na ordem origem → evolução. Isso cumpre "a
  evolução recebe os commits pagos das skills da origem" sem entregar o mesmo commit duas
  vezes, e deixa a base ver as skills da evolução (Devoção). Skills de item chegam aos dois.
- **`before_hit_mitigation`.** O primeiro `cancel` encerra o golpe, e o módulo seguinte não é
  consultado. Os multiplicadores se multiplicam.
- **Listas de base.** `IdentityIds.base_class_ids()` continua com as três do E00 (contrato
  estável, usado por itens e ferramentas); `registered_base_ids()`/`all_base_ids()` listam a
  nova; `is_base_class` aceita as duas. `kit_evolution_ids()` passa a ser o registro inteiro
  (seis).
- **Luz do Paladino e do Taumaturgo.** Regra de apresentação no registro
  (`LIGHT_PRESENTATION_KITS`: linhas `arcane` mostradas como `light`), sem editar as pastas
  `sp_ac`/`mg_ac`. O elemento de gameplay continua `SkillDefinition.element`.
- **Oferta das puras.** Uma pura pronta só entra no catálogo com a base pronta; um kit pronto
  escondido pela base não é erro de catálogo.
- **Inimigo sob sobrescrita** ataca com o básico do arquétipo (limitação 3 da API).

## Arquivos tocados fora de C1.10

| Arquivo | Motivo |
|---|---|
| `scripts/classes/kit_decoy.gd` (novo) | primitiva da isca (C1.6); fica na costura da T1, ao lado de `class_kit.gd`, com o esquema no fragmento `scripts/classes/snapshot_manifest.json` |
| `tools/e09_review_profiles.gd`, `tools/e09_release_probe.gd` | percorriam `ClassKitRegistry.ids()`, que cresceu; passam a ler `hybrid_ids()` para manter o comportamento do E09 (a família tem `tools/e10a_review_profiles.gd`, da T10). Nenhuma tarefa do E10a é dona deles |
| `tests/e08_feedback_vfx_test.gd` | C1.11: `shadow` ainda não tem receita de produção (módulos da família são esqueletos); o check "element has a visual" aceita, só para `shadow`, a entrada própria na paleta |
| Testes legados (abaixo) | C1.11 e C1.8 |

## Testes legados ajustados (C1.11)

Só checks de enumeração que cresceram por este contrato, com a lista ou a contagem exata nova:

| Teste | Ajuste |
|---|---|
| `tests/e09/kit_seam_test.gd` | `ClassKitRegistry.ids()` = as seis e `hybrid_ids()` = as quatro; os laços dos checks do E09 passam a `hybrid_ids()`; `kit_evolution_ids()` = as seis; `reserved_base_ids() == [&"rogue"]`; `acolyte` é base registrada; `eligible_identities().size() == 17`; a base reservada testada vira `rogue`; a receita do Paladino passa a `light` (C1.8) |
| `tests/e09/hybrid_bodies_test.gd` | `hybrid_ids() == BODIES.keys()` |
| `tests/e09/ui_evolution_test.gd` | laço do onboarding nas quatro híbridas (o da família é da T10) |
| `tests/e09/equipment_items_test.gd` | o laço de elegibilidade usa as 14 identidades do E09; `eligible_identities().size() == 17` |
| `tests/e08_feedback_recipe_test.gd` | só checks novos: a lista exata de lacunas `light`/`shadow` (abaixo) |
| `tests/e08_feedback_vfx_test.gd` | `shadow` sem receita de produção: verificado pela entrada própria na paleta, distinta de `arcane` |

As listas de destinos de evolução e de bases oferecidas na criação (`E00_DESTINATIONS`,
`tests/e05_evolution_catalog_test.gd`) não mudaram e ficam com a T10.

## Lacunas de áudio (C1.8)

Nenhuma deixa nova. Nenhuma das 13 famílias de deixa da paleta P6 (`area`, `buff`, `cast`,
`charge`, `dot`, `heal`, `impact`, `melee`, `movement`, `projectile`, `summon`, `teleport`,
`trap`) tem `p6.<família>.light` ou `p6.<família>.shadow`. Com isso:

- `area`, `buff`, `cast`, `charge`, `impact`, `melee`, `movement` e `projectile` caem em
  família × físico;
- `dot` cai em `world.impact`, `trap` em `world.area_end` e `teleport` na deixa do tipo;
- `heal` e `summon` ficam em silêncio.

A lista está em `tests/e08_feedback_recipe_test.gd`. A lista de lacunas dos kits do E09
(`KIT_AUDIO_GAPS`) não mudou com a troca do Paladino e do Taumaturgo para `light`.

## Testes, logs e hashes

Lote de impacto, antes da suíte, cada teste numa chamada `verify.ps1 -Test <nome>
-SkipEditorImport` (importação feita antes, em passo próprio):

| Teste | Resultado |
|---|---|
| `base_seam_test` | 171 checks, 0 falhas |
| `enemy_target_test` | 88 checks, 0 falhas (sobre `03a2bf51`) |
| `kit_seam_test` | 276, 0 |
| `kit_seam_hooks_v2_test` | 38, 0 |
| `hybrid_bodies_test` | 6300, 0 |
| `ui_evolution_test` | 97, 0 |
| `equipment_items_test` | 244, 0 |
| `e08_feedback_recipe_test` | 1309, 0 |
| `e06_publication_test` / `e06_migration_test` | 1162, 0 / 147, 0 |
| `e05_evolution_catalog_test`, `persistent_state_test`, `e06_admin_profile_test` | passaram |
| `sp_ac_*`, `mg_ac_*`, `sp_la_*`, `mg_la_*`, `sanctuary_test`, `flank_test` | passaram (0 falhas) |

### Suíte completa (`tools/verify.ps1`, sem filtro `-Test`)

Rodada sobre `03a2bf51`, em `.godot/verification/t1_suite_03a2bf51/` (ignorado pelo Git).

**Método.** São 349 passos (`verify.ps1 -List`). Cada passo rodou numa chamada própria de
`verify.ps1 -FromStep N -ToStep N -CheckTimeoutSeconds 300`, com `-GodotPath` no executável da
limitação 1. Os quatro passos de bootstrap rodaram primeiro e sem fixture: `editor_import`,
`e07_f0_import_test`, `e07_f1_import_test` e `e07_f1_native_import`. Os demais rodaram com
`-F1Fixture`, na ordem do plano, como no E09.

**Resultado.**
- `summary.jsonl`: sha256 `4C5ABEC1D0519C0D3BAF207E2360297698229F9708C1C1FBAFBEEBBB50AC4AEF`.
- 349 linhas, 0 timeouts, 347 passos passaram.
- Procurei `SCRIPT ERROR`, `still in use`, `Parse Error` e `Compile Error` em todas as saídas:
  só a do passo 148 tem ocorrência (abaixo). Nenhuma saída veio vazia.
- Falhas:
  - **255 `e07_f1_native_import`**: falha conhecida da base em worktree novo
    (`Cannot get class 'GitPlugin'`). Saída `AB79025F6B8201D30245FD016889D79306A398E5D3D1C02D5CAF801D5E17831F`,
    o mesmo hash do recibo do E09. Não depende da T1.
  - **148 `e05_sentinel_net_test`**: 167 checks e 0 falhas, mas `1 resources still in use at
    exit` e `6 ObjectDB instances were leaked`. Saída
    `B6546646CE017092E1D39C76A718D14A1C2764525610089BBB56B8E81AC12886`; o `engine.log` não traz
    mais nada. Ver "Passo 148" abaixo.

**Vazamento corrigido nesta entrega.** As rodadas anteriores, sobre `f71f564c` e `574264e7`,
foram interrompidas. Nelas, `e04_mage_electric_discharge_rank_integration_test` (e, fora da
F1, `e04_mage_haunt_rank_integration_test`) passava nos checks, mas terminava com `22
resources still in use at exit` ou com crash `0xC0000005` na saída.
- A base `6938db71` estava limpa.
- Bisseção por grupos de arquivos (base com partes da ponta, `--verbose`, 2 a 3 rodadas cada):
  - `scripts/core`, `scripts/data` e `scripts/classes` da ponta: limpo;
  - com `scripts/actors` da ponta: vaza;
  - só `combat_actor` + `player_actor`, ou `combat_actor` + `character_animation`: limpo;
  - `enemy_actor.gd` com apenas as declarações novas (sem chamadas): vaza;
  - sem o `is EnemyActor`: limpo.
- **Causa:** `enemy_actor.gd` nomeava a própria classe (`not actor is EnemyActor`, `not victim
  is EnemyActor`). O ciclo é do mesmo tipo do A10 do E09, mas com o script apontando para si
  mesmo, não `PlayerActor` → `EnemyActor`.
- **Correção (`03a2bf51`):**
  - reconhecimento por método (`EnemyActor._is_enemy`) e jogador por duck typing;
  - `KitDecoy`, que também se nomeava, reconhece e cria por caminho (`KitDecoy.is_decoy`);
  - `tests/e10a/enemy_target_test.gd` passa a vigiar a regra.
- O WIP (registros lidos por caminho, revisão própria de `ClassBaseRegistry`) não era a causa,
  mas ficou: evita outros ciclos.
- Depois da correção, `e04_mage_haunt…` e `e04_mage_electric_discharge…` terminaram com exit 0
  e 0 recursos em uso, em 3 de 3 rodadas cada. Na suíte, os passos 89 e 92 passaram.

**Passo 148 (`e05_sentinel_net_test`).** Ocorrência única, não reproduzida. Contagens no mesmo
ambiente (fixture F1, mesma engine):

| Código | Execuções | Com recurso em uso |
|---|---|---|
| ponta `03a2bf51` | suíte (1) + 20 por `verify.ps1 -Test -F1Fixture` + 60 diretas com `--verbose` (4 em paralelo) + 8 diretas com `--verbose` | **1 de 89** (a da suíte) |
| base `6938db71` (fontes da base e fixture F1 reconstruída) | 20 por `verify.ps1 -Test -F1Fixture` + 60 diretas com `--verbose` | **0 de 80** |

- Logs:
  - `.godot/verification/step148_tip_03a2bf51/`, `step148_tip_burst/`,
    `step148_base_6938db71/` e `step148_base_burst/` (cada um com `repeat.txt` ou `burst.txt`);
  - a saída da suíte em `t1_suite_03a2bf51/148/`.
- Com 1 em 89 contra 0 em 80, os dados não separam regressão de instabilidade pré-existente.
  A frequência é baixa demais, e a única ocorrência foi sem `--verbose`, então o nome do
  recurso não foi capturado.
- O teste fecha cada cenário com `queue_free()` + `await process_frame`. Um recurso solto de
  vez em quando combina com uma liberação adiada que não terminou antes do `quit()`, mas isso
  é hipótese.
- Nos scripts que o teste usa, não há referência nova da T1 que feche ciclo: a vigia de
  `enemy_target_test` cobre `EnemyActor`, `KitDecoy` e `PlayerActor`.
- **O teste não foi alterado.** Fica como pendência aberta para a arquitetura (limitação 7).

## Limitações e próximo passo

1. **Executável.** O `Godot_v4.7.2-stable_win64_console.exe` pedido falha nesta máquina com
   `CreateProcess failed, error 193`, dentro e fora do sandbox, já no `--version`. A suíte usou o
   `Godot_v4.7.2-stable_win64.exe` da mesma pasta, mesma build, por `-GodotPath`. O
   `verify.ps1` redireciona a saída por `ProcessStartInfo`, então os logs são os mesmos.
2. **Primeira importação.** Na worktree nova, a primeira `editor_import` falhou com
   `Cannot get class 'GitPlugin'` (a mesma falha conhecida do E09); a segunda passou.
3. **`has_kit()`** agora é verdadeiro só com a origem. `scripts/ui/classes/kit_onboarding_base.gd`
   (pasta da T10) lê `_player.kit` depois de `has_kit()`; o onboarding do Acólito precisa
   tratar `kit == null` (API, limitação 2).
4. **Sobrescrita com skills de mob**, **filtro de elemento**, **itens sem origem**, **skills
   iniciais** e **XP/loot de abate entre inimigos**: limitações 3 a 7 da API.
5. **E12.** O E12 ainda não está em `master` e edita `class_kit.gd`, `combat_actor.gd`,
   `player_actor.gd`, `enemy_actor.gd` e `main.gd`. Quando a T13 compuser o E12, o gancho
   `hud_state` precisa da mesma composição de dois módulos (`kit_modules()`); um conflito de
   conteúdo volta à T1.
6. **Ruído de importação.** A importação do Godot deixa ~1990 `.import` com só fim de linha
   diferente no checkout; não foram versionados.
7. **Passo 148 sem classificação.** O vazamento de 1 recurso em `e05_sentinel_net_test`
   apareceu 1 vez em 89 execuções na ponta e 0 em 80 na base (seção da suíte). Se reaparecer
   na T13/T14, rodar com `--verbose` para capturar o recurso antes de decidir. Se for da T1,
   a correção volta à T1.
8. **Regra de ciclos de script** (API, limitação 7): nenhum script nomeia a própria
   `class_name`, nem `PlayerActor` ↔ `EnemyActor`. T4–T10 devem seguir a mesma regra nos
   módulos.

Próximo passo: T4, T6 e T10 podem partir da ponta desta branch (onda 2), e depois T8 e T9 com o
merge da T2. A T13 compõe esta entrega no candidato.
