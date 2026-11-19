# E10a T12 — recibo: HUD da família Acólito (C9, A18)

- **Base:** `claude/e10a-candidato` @ `65f32d47` (T15 `223f05e8` e T16 `8530b3e5` confirmados como ancestrais).
- **Branch/checkout:** `claude/fervent-torvalds-91db0b`, worktree `.claude/worktrees/fervent-torvalds-91db0b`. Sem push, sem `master`, sem `codex/playtest`, sem save pessoal. `.import` reescritos pelo editor não foram commitados.

## O que mudou

| Arquivo | Mudança |
|---|---|
| `scripts/classes/kit_hud_state.gd` | `shadow` em `ELEMENTS`; `madness_` em `SYSTEM_PREFIXES`. Nada mais no validador. |
| `scripts/actors/player_actor.gd` | `kit_hud_state()` compõe os módulos (A18); auxiliares `_hud_claim` e `reset_hud_composition_warnings` (só teste). |
| `scripts/classes/bases/acolyte/acolyte_base.gd` | `hud_state`: Loucura em `target_marks`, em 5 degraus (`pips`, chave `madness`, `shadow`) e selo `madness_delirium` (`badge`) para o inimigo em Delírio. Sem recurso. |
| `scripts/classes/priest/priest_kit.gd` | `hud_state`: Graça (pips, ∞ com prazo na Hora Santa), Égide e Hora Santa (timers), zona do Santuário, selo de Luz (badge). |
| `scripts/classes/cultist/cultist_kit.gd` | `hud_state`: Êxtase (pips 0–5, só com a passiva ativa) e Ídolo (timer e zona circular `idol`). Não publica Loucura. |
| `scripts/ui/hud/hud_palette.gd` | **Fora da posse da T12.** Uma linha: `&"shadow": Color("d16ad8")` (autorizado pela Astra, A23 em `5c6b03df`; mesma cor dos projéteis de sombra). Contraste legível nas capturas; a `8a5fb0` não foi necessária. |
| `tests/e10a/hud_family_test.gd` | Teste novo, 131 checagens (118 headless). |

### Composição (A18)
`kit_modules()` em ordem (origem, evolução); cada módulo é validado contra ele mesmo com `KitHudState.checked`; um módulo inválido zera só ele. Um só estado não vazio é devolvido sem mudança (mesma instância; byte a byte para os híbridos). Dois: um v1 com `kit_id` = `kit` (senão `origin_kit`), `resources`/`zones`/`target_marks` concatenados na ordem, `skills` unidas. Colisão (recurso por `id`, zona por `role`, marca por `(target_id, key)`, skill por id): fica o primeiro, um `push_warning` por chave. O composto não é revalidado.

## Testes (um por chamada, `verify.ps1 -SkipEditorImport -F1Fixture -CheckTimeoutSeconds 300`)
Antes: `editor_import` duas vezes e `e07_f1_import_test` (refeito depois de cada edição do teste).

| Teste | Resultado |
|---|---|
| `hud_family_test` | 118 checagens, 0 falhas |
| `hud_seam_test` | 194, 0 |
| `hud_components_test` | 168, 0 |
| `hud_integration_test` | 234, 0 |
| `mg_ac_hud_test` / `mg_la_hud_test` / `sp_ac_hud_test` / `sp_la_hud_test` | 60 / 53 / 57 / 49, 0 |
| `acolyte_base_test` / `priest_kit_test` / `cultist_kit_test` / `madness_test` | 332 / 240 / 237 / 276, 0 |
| `kit_seam_test` / `base_seam_test` / `mage_gameplay_test` | 276 / 172 / 52, 0 |

Suíte completa **não** rodada (como pedido). Os avisos `duplicate HUD key` e `invalid HUD state` na saída do `hud_family_test` são esperados: vêm dos testes de colisão e de módulo inválido.

Depois da A23 (cor `d16ad8`), `e07_f1_import_test` refeito e `hud_components_test` (168), `hud_integration_test` (234) e `hud_family_test` (118) rodados de novo: 0 falhas.

## Capturas nativas (Godot 4.7.2, janela e renderer reais, 1280×720)
`docs/epics/e10a/t12_evidence/`, geradas por `hud_family_test.gd -- <dir>` (131 checagens, 0 falhas):

| Arquivo | SHA256 |
|---|---|
| `t12_acolyte.png` | `b51251a5654b24b4a8b0f18bb57d3f733c9af287a2f9942c1687d0f184e1a81e` |
| `t12_priest.png` | `4264f55b8f33b47044e314ea904b23fbe17958b648d513e1cc5686bb847f52d6` |
| `t12_cultist.png` | `ac47f666f143e405398b9767b8d37971c5649949c712038df8458855d3ed1570` |

Priest: Graça (3 pips), Égide, círculo do Santuário e selo. Cultista: Êxtase (3 pips), Ídolo (timer) e zona do Ídolo; Loucura sobre o inimigo. Acólito: só marcas de Loucura sobre os inimigos.

## Limitações
1. **Paleta:** a entrada `shadow` é a única mudança em `hud_palette.gd` (A23); sem ela, Êxtase, Ídolo e Loucura seriam descartados pelo painel e pelos overlays.
2. O Acólito sem evolução não tem linha de recurso: a Loucura aparece só como marcas sobre os inimigos (painel oculto). Vale para a base com qualquer evolução, que também publica as marcas.
3. A Loucura é mostrada em degraus de 20 (`ceil(Loucura/100×5)`); o valor exato não é exposto na marca. Sem fórmula nova: a leitura vem de `MadnessAuthority.describe_enemy`.
4. `skills` não é publicado por nenhum dos três módulos (fora do C9); a união de `skills` só é exercida pelo teste de colisão, com módulos de teste.
5. O Ídolo no mundo da expedição usa `world_point()` do decoy; o teste cobre só a arena plana (como o C9 pede para a captura). O mundo F1 não foi exercitado para a família.
6. Não-verificado: o passo 148 e a suíte completa ficam para a T13/T14.
