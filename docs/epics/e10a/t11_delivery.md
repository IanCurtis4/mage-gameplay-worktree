# E10a T11 — recibo dos 6 augments da família Acólito (C8)

Papel: Terra (Claude Sonnet 5.5, esforço médio). Contrato: [e10a_contract.md](../e10a_contract.md) §9 (C8), D4, D6, D7 e A13.
Skill seguida: `$ragrpg-augmentdelivery` (receita sobre handlers existentes, sem código novo).

## Base e checkout

| Item | Valor |
|---|---|
| SHA-base | `5f702caa6a5d38a9c59e23dab2e8e142163bd659` (`git log -1` depois de `git merge --ff-only claude/e10a-candidato`) |
| Ancestrais conferidos | T5 `50fb61bd`, T6 `ce629e74`, T7 `de11f99d` (`git merge-base --is-ancestor`, os três presentes) |
| A13 (T9) na base | sim: `build_effect_catalog.gd` usa `IdentityIds.is_base_class`, então `allowed_origins = [acolyte]` é válido |
| Partida | `master` = `7795f56d`, levada ao candidato por fast-forward; branch de arquitetura não foi mesclada |
| Branch | `claude/youthful-robinson-db714a` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\youthful-robinson-db714a` |
| Commit | o que contém este recibo (ponta da branch) |
| Engine | `Godot_v4.7.2-stable_win64.exe` (A7), `-GodotPath`; `editor_import` estourou os 300 s na primeira rodada e passou na segunda; `e07_f1_import_test` regenerado depois da última edição de teste |

Sem push, sem `master`, sem `codex/playtest`, sem save pessoal, sem worktree extra. Os `.import` reescritos ficaram fora do commit.

## Os seis augments

Todos: origem `acolyte`, 3 stacks, curva = magnitude × stack, textos pt-BR, descrição idêntica a `ContentAuthoring.describe`.
Nenhum toca Madness, Delírio ou Êxtase: os limites da D4 (Delírio ≤3, nunca no chefe, Êxtase 0–5) não são alcançáveis por estas receitas.

| ID | Nome | Elegível | Receita (handler existente) | Build reforçada |
|---|---|---|---|---|
| `pilot_acolyte_pressure` | Pressão Votiva | Acólito, Sacerdote, Cultista | `HIT_DAMAGE` mágico, ao acertar, +6/+12/+18, limite 60, qualquer skill | base |
| `pilot_acolyte_reserve` | Reserva Votiva | Acólito, Sacerdote, Cultista | `STAT_MODIFIER` SP máximo +6/+12/+18 | base |
| `pilot_priest_a` | Muralha da Fé | só Sacerdote | `STAT_MODIFIER` vida máxima +30/+60/+90 | Bastião da Fé |
| `pilot_priest_b` | Juízo Implacável | só Sacerdote | `HIT_DAMAGE` mágico +6/+12/+18 só em `priest_judgment` | Inquisição |
| `pilot_cultist_a` | Delírio Compartilhado Profundo | só Cultista | `HIT_DAMAGE` mágico +6/+12/+18 só em `cultist_shared_delirium` | Profeta |
| `pilot_cultist_b` | Olhar Sem Fundo | só Cultista | `HIT_DAMAGE` mágico +6/+12/+18 só em `cultist_abyss_gaze` | Vidente |

Os números (6/12/18, 30/60/90) seguem o padrão dos augments do piloto; o contrato não os fixa. Para o artista de balanceamento: o +30 de vida é a única escala nova.

## Testes

Todos com `tools/verify.ps1 -SkipEditorImport -F1Fixture -CheckTimeoutSeconds 300 -Test <nome>`, um por chamada. sha256 = da saída capturada de cada chamada.

| Teste | Resultado | sha256 |
|---|---|---|
| `augments_test` (novo) | 180 checks, 0 falhas | `426225E8D68D194C7AE4A931FE68CB69C95CE45150C5FD357A3EF5622AD32681` |
| `e06_content_pilot_test` | 481 checks, 0 falhas | `C6F714C0B15F054945481D38C8134DBC8A73CCFE88DB3990A6F6ED677A5F24A0` |
| `e06_content_pilot_runtime_test` | 252 checks, 0 falhas | `95D621DDBB270586F7FDF7E8E8BB8E1D1C7B54F3E9D634D2864FCC38C8FCE662` |
| `e06_publication_test` (depois da A15) | 1162 checks, 0 falhas | `CEF2E4E8A845BD71521EBD0E59269A7B39DFF0DDA1B8ADE3A58BCD8DE66B4B76` |
| `e08_feedback_recipe_test` | 1433 checks, 0 falhas | `E97ADF505B423907E991D5851EE7FE4410619652E3BC1637EA1D7FC3A322E91F` |
| `acolyte_base_test` | 306 checks, 0 falhas | `69E4C581F5001A7CD435C2B6AEF7740D140E29B26AFF1A3FA434B49188A19996` |
| `priest_kit_test` | 220 checks, 0 falhas | `3220A3109D14AF6972A79B470CD857D6C7C273312DF11CF08E73DE2F8F37212D` |
| `cultist_kit_test` | 215 checks, 0 falhas | `97165F876B908DE0BE921E2033C7B424AB300D7372A34054EE5CA03D96CC2E5A` |

O `e06_publication_test` falhou 1 check antes do ajuste (esperado: contagem de augments).

`augments_test` prova: forma da receita e do catálogo (37 augments); elegibilidade pela identidade (Acólito, Sacerdote, Cultista, e bloqueio para mago, espadachim, arqueiro e elementalista); legibilidade (nome, flavor e descrição presentes, únicos, sem ID interno, descrição canônica com a curva); e efeito mensurável em combate curto com a base e os kits reais: pressão +6/12/18 por acerto, reserva +12 SP em 2 stacks nas três identidades, Muralha +90 de vida em 3 stacks (inerte no Cultista), e cada augment direcionado adiciona exatamente +6 só na skill-alvo, sem cascata, sem efeito sem o augment, +18 em cada um de cinco acertos com 3 stacks.

## Ajustes da A15

Um, com número exato: `tests/e06_publication_test.gd` linha 28, `ids(&"augment").size() == 31` → `== 37` (31 + 6) e o texto do rótulo. Nada mais enumerava augments: `e06_content_pilot_test` e `e06_effects_composition_test` leem o catálogo do piloto, sem os novos.

## Limitações

- O combate é de acertos reais de requisição de kit pelo caminho do `RunController` (`kit_emit_hit`), não uma rotação completa nem IA real; não prova diversão nem equilíbrio.
- Os limites da D4 são provados por construção (nenhum eixo de Loucura/Delírio/Êxtase), não por combate: o Delírio só entra em `EnemyActor`, e o teste usa `CombatActor`.
- O texto de `pilot_cultist_a` ("Delírio Compartilhado Profundo") é longo; Luna pode rever nomes e flavor sem mudar mecânica.
- A contagem 37 de augments em `e06_publication_test` e em `augments_test` precisa de nova conferência se outra tarefa (T9, T10) acrescentar augments; a T9 mexe em equipamento, não em augment.

## Próximo passo

T13 compõe esta ponta no candidato; conferir a contagem 37 após a composição.

## A16 — correção na composição 8 (parcial: item 1 feito, item 2 bloqueado)

Worktree recriada da branch e levada ao candidato por `git merge --ff-only claude/e10a-candidato` (HEAD `c497f26e`).

**Item 1 (feito):** `tests/e09/ui_evolution_test.gd`, `_install_states`: `ClassKitRegistry.ids()` → `hybrid_ids()`. Nenhuma expectativa mudou. Antes: falha por `unknown_skill_target` (Sacerdote e Cultista viravam esqueleto); depois: 97 checks, 0 falhas.

**Item 2 (NÃO entregue, reportado à arquitetura):** `e07_f1_composition_test`.
- A contagem `27 → 31` e os ranks da família no `_setup` ficaram só na árvore de trabalho, sem commit. Com isso: 342 checks, 2 falhas (antes 3); `pilot_acolyte_pressure` (básico) e `pilot_cultist_a` (`cultist_shared_delirium`) passam.
- `pilot_priest_b` (`priest_judgment`): a coluna do Juízo acerta o inimigo do andar de cima também (`JUDGMENT_COLUMN_HALF_HEIGHT = 200`, a ponte está a y=40). Medido: `lower` 100000→99856 e `upper` 100000→99856. O check "nunca projeta no outro andar" não é satisfeito por desenho da coluna.
- `pilot_cultist_b` (`cultist_abyss_gaze`): `gaze_targets` retorna 0 alvos porque a família só reconhece inimigo que seja `EnemyActor` (`MadnessHelpers.is_enemy` exige `set_target_override`; `madness_authority.gd:325` tipa `hostile` como `EnemyActor`). O fixture usa `CombatActor`; um carrier com os métodos falsos ainda quebra no `as EnemyActor` (Nil). Prova do cone: facing e posições corretos, `channeling=true`, 0 alvos.
- Não é lacuna do PROC em si (o handler dispara); é o fixture F1 sem `EnemyActor` real e a coluna do Juízo sem filtro de andar. Decisão para a arquitetura: fixture com `EnemyActor` real, ou filtro de andar no Juízo (T15), ou check específico.

### Testes depois da A16 (item 1)

| Teste | Resultado | sha256 |
|---|---|---|
| `ui_evolution_test` | 97 checks, 0 falhas | `AF5649F0015025B91CD431E0D5A6AC607D4D490757B4B471B39C45DF7B823E60` |
| `augments_test` | 180 checks, 0 falhas | `D2080594CFEB43E2D9225D07137E629AFA2586980F8246E5464AF1E83ED2357A` |
| `e06_publication_test` | 1162 checks, 0 falhas | `BBEA52A2C04245B24C361A4E8EBD95FEA8B9D744F6A6F396851B0BB180A27EC8` |
| `ui_family_test` | 86 checks, 0 falhas | `99F94E287D1454AB5E4F01AE6ED08C2BCE71DD0B6502A16318CF903DDA899D2D` |
| `kit_seam_test` | 276 checks, 0 falhas | `387339E5A5C3F2A138ED2301861C3BC9EA4FBEC29810CB397E25270B55B7C888` |
| `e07_f1_composition_test` | 342 checks, **2 falhas** (priest_b, cultist_b), com edições não commitadas | n/a |
