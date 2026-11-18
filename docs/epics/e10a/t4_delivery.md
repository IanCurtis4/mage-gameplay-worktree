# E10a T4 — recibo: Loucura, Êxtase e Ídolo (C2)

Executor: Sol (Claude Opus 5.5), sessão T4 iniciada pela arquitetura (`local_44faa7bb`), 18/11/2026.

## Base, branch e checkout

- **Base:** ponta da T1, `c8771d20a3dd3fa9de8f578cb1cc3c0908a608b1` (branch de origem
  `claude/e10a-t1-ae3f9f`). A worktree nasceu em `7795f56d` (limpa). Como ele é ancestral da
  ponta da T1, a branch foi levada a ela por `git merge --ff-only`, com o mesmo resultado do
  `reset --hard` pedido (o modo automático recusou o reset).
- **Branch:** `claude/wizardly-hermann-10d51a`.
- **Checkout:** `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.claude/worktrees/wizardly-hermann-10d51a`.
- **Decisão usada:** A8 (retenção de combate), registrada pela arquitetura em `35df9cef` na
  branch `claude/e10a-arquitetura-a413a1`, em resposta ao pedido desta tarefa.
- **Commit entregue:** o commit deste recibo, na ponta da branch.

## Entregas

| Item | Arquivo |
|---|---|
| Contrato curto com os números | [t4_contract.md](t4_contract.md) |
| API para T5, T7 e T12 | [t4_madness_api.md](t4_madness_api.md) |
| Sistema | `scripts/systems/madness/{madness_rules,madness_ecstasy,madness_authority,madness_helpers}.gd`, `snapshot_manifest.json` |
| Kit de fixture | `scripts/systems/madness/fixture/{madness_fixture_kit.gd,snapshot_manifest.json}` |
| Retenção de combate (A8) | `scripts/actors/enemy_actor.gd`, +34 linhas: `COMBAT_HOLD_MARK`, `set_combat_hold`, `clear_combat_hold`, `has_combat_hold`, `combat_hold_remaining` e o desvio no início da IA de `_process`. Teste: `tests/systems/madness/madness_test.gd` (`_check_combat_hold`) |
| Testes | `tests/systems/madness/madness_test.gd` |

### Arquivo fora da posse original

`scripts/actors/enemy_actor.gd` foi editado só pela A8: os métodos da retenção e um bloco em
`_process`, antes da IA do mundo e da IA plana. O estado é uma marca de `ActorMarks`, então
o manifesto principal (`runtime_manifest.json`, da T1) não precisou mudar. O estado entra no
snapshot pelo campo `CombatActor.marks`, que já está no manifesto. A regra A7 vale:
`enemy_actor.gd` continua sem nomear `EnemyActor`, e o `enemy_target_test` da T1 confere.
O plano B ficou descartado. Pela A8, a posse
volta ao regime de A6 depois desta entrega.

## Invariantes de C2 cobertas (`madness_test.gd`)

| Invariante | Seções do teste |
|---|---|
| A pausa congela Loucura, Delírio, Desorientação, imunidade, Êxtase e Ídolo | `_check_decay_and_pause` (inimigo, chefe, isca e jogador em `_process` com a árvore pausada); retenção em `_check_combat_hold` |
| Teto de 3 delirantes; Loucura no limiar até a vaga; ordem de chegada | `_check_delirium_cap` |
| Chefe nunca em Delírio e nunca redirecionado | `_check_delirium`, `_check_boss_disorientation`, `_check_idol`, `_check_world_path` |
| Imunidade depois da Desorientação; Revelação fura uma vez por evento | `_check_boss_disorientation` |
| Golpe do chefe nos lacaios pelo desvio no commit (chance 0,35; o teste exige de 8 a 35 dos 60 golpes, com o RNG determinístico do inimigo), nunca no inimigo distante | `_check_boss_disorientation` |
| Nenhum evento dá Loucura ou Êxtase duas vezes | `_check_madness_add_and_dedupe`, `_check_ecstasy`, `_check_contagion` |
| Contágio de um salto; pulso único ao entrar em Delírio | `_check_contagion` |
| Abate por Delírio creditado uma vez, inclusive em retry; sem Loucura por dano ou abate entre inimigos | `_check_delirium_kill_credit` |
| Delírio sem alvo: parado, sem atacar o jogador (A8), alvo retomado quando aparece | `_check_delirium_without_target`, `_check_combat_hold` (mapa e mundo) |
| Retenção (A8): chefe recusa (`boss_refuses_hold`); sem `HardControlState` e sem bônus de controle (critérios do Caçador e da Sentinela); prazo no relógio de gameplay, congela na pausa e expira; cai com a morte e com `clear_statuses`; sem mover nem atacar nos dois caminhos | `_check_combat_hold`, `_check_world_path` |
| Êxtase 0–5, MATK e custo por carga, ônus a partir de 3, decaimento, build não mexe, morte zera | `_check_ecstasy` |
| Ídolo: 1 por dono, HP do dono, comuns e elites o miram, Loucura por tique no chefe também, prazo, prioridade do Delírio | `_check_idol` |
| `describe()` puro | `_check_describe_and_tick_dedupe` |
| Snapshot exato preserva Êxtase e Ídolo; compacto preserva o Êxtase e é inelegível com Ídolo | `_check_snapshot_formats` |
| Regra A7 de ciclos | `_check_script_cycles` |
| Mobs reais nos dois caminhos | todos os casos usam `forest_wolf`, `forest_boar` e `forest_ancient_warden` do catálogo; `_check_world_path` repete Delírio, Desorientação, retenção e Ídolo no mundo da fixture F1 |

## Validação

Engine `Godot_v4.7.2-stable_win64.exe` (`4.7.2.stable.official.ed1daf0bf`; o `_console.exe`
falha nesta máquina, A7). Preparação: `editor_import` duas vezes (a primeira cai pelo
`GitPlugin`, a segunda passa) e `e07_f1_import_test` (PASS, 3510 arquivos idênticos). Os
testes rodaram com `tools/verify.ps1 -F1Fixture -Test ...`, como na T1 e no E09.
`kit_seam_hooks_v3` exige a fixture F1: fora dela, falha em "F1 world fixture is current".

**Leva 1, regressão por impacto** (`.godot/verification_t4/checks.jsonl`): 20 de 20.

| Passo | Teste | Checks | SHA-256 da saída (16) |
|---|---|---|---|
| 270 | `e07_f6_snapshot_test` | 40/40 | `2E091952F53115A7` |
| 294 | `e07_f3_snapshot_test` | 52/52 | `9FC703C4AB2986DD` |
| 331 | `kit_seam_hooks_v2_test` | 38/38 | `5182F32B62DE14BE` |
| 332 | `kit_seam_hooks_v3_test` | 63/63 | `D1DFD323C350F8F6` |
| 333 | `kit_seam_test` | 276/276 | `60643509690EB7E2` |
| 335 | `base_seam_test` (T1) | 171/171 | `83E3C22E78D21A6C` |
| 336 | `enemy_target_test` (T1, inclui a regra A7 sobre `enemy_actor.gd`) | 88/88 | `61C1F89F787761EA` |
| 337 | `flank_test` | 205/205 | `D23DC5D7B03B0FE0` |
| 338 | **`madness_test` (T4)** | **275/275** (276/276 depois do reforço da A8, rodado direto) | `30B16FB928B400CF` |
| 339 | `sanctuary_test` | 155/155 | `01B74920641522D9` |
| 340–349 | kits do E09: `mg_ac` (boss 29, kit 177), `mg_la` (boss 33, kit 231, salto 49), `sp_ac` (boss 25, kit 170), `sp_la` (boss 31, kit 217, aparo 55) | todos 0 falhas | `66AC49C6…`, `814D744C…`, `6710C89E…`, `B480859D…`, `F2E59EE4…`, `26957117…`, `2229F2DC…`, `4F9C0F3F…`, `D2DC91B2…`, `4F0C254B…` |

**Leva 2, IA de inimigo** (pela edição de `_process` da A8; `.godot/verification_t4b/checks.jsonl`): 6 de 6.

| Passo | Teste | Checks | SHA-256 (16) |
|---|---|---|---|
| 111 | `e05_training_boss_test` | 17 PASS | `F0B3638ABCA8C2DB` |
| 206 | `e06_tx_mob_test` | 27/27 | `5D56F0CD5FF05747` |
| 209 | `e06_rx_mob_ai_test` | 4/4 | `B9569774452019C5` |
| 228 | `e06_gameplay_ai_test` | 76/76 | `3E3923BEDEC4F28C` |
| 268 | `e07_f6_threat_test` | 43/43 | `C38ACB2F6A0A4F10` |
| 298 | `e07_f3_mob_state_test` | 372/372 | `A84CACBF8F2342C0` |

- Os 26 logs (`*.output.log` e `*.engine.log`) não têm `SCRIPT ERROR`, `resources still in use`
  nem `ObjectDB instances leaked`.
- Sonda à parte: uma autoridade que registra o desenhador do Ídolo e sai sem
  `unregister_drawer` termina com exit 0 e sem recurso em uso.
- A suíte completa não foi rodada (fora do pedido). Ela fica para a T13.

## Limitações

1. **Ataque sob sobrescrita:** o delirante usa o básico do arquétipo, nunca a skill declarada
   do mob (limitação 3 da T1, aceita sem pedir extensão). Os mobs da floresta não têm skill
   declarada.
2. **Inimigos vistos** são os de `RunController.enemies` (pai do jogador), como no Santuário.
3. **A marca da retenção no snapshot** segue a restauração das marcas do inimigo, já provada
   pelo Selo do E09. Esta tarefa não captura um `EnemyActor` retido num snapshot próprio.
4. **XP e loot** do abate por Delírio seguem a prova de crédito da T1 (`_credited_kills`, um só
   `on_kill_confirmed`). A prova de campanha é da T7 (A7.7).
5. **Arquivos de importação:** a importação do editor nesta worktree reescreveu ~1988
   arquivos `.import` (só fim de linha) e criou `.gd.uid` em `docs/map_editor/**`. Não foram
   commitados. Ficam na worktree até ela ser removida.

## Próximo passo

- T5 e T7 partem desta ponta e seguem [t4_madness_api.md](t4_madness_api.md) §1: o campo
  `madness` na base, e o Cultista usa `MadnessAuthority.of(player)`.
- T13 compõe esta branch.
