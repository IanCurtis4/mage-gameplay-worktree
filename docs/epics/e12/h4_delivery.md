# E12 H4 — recibo: ligação do HUD de combate (C5)

Tarefa H4 do [E12](../e12.md) (contrato §6, [e12_contract.md](../e12_contract.md)). Terra,
Sonnet 5.5. Só apresentação: nenhuma regra, fórmula, custo, recarga, sinal de gameplay ou campo
de save mudou.

## Origem

- **SHA-base:** `82fecf2f799a61de31bc80deb116e7f09612ee42` (ponta da H2, `claude/e12-h2-e4e790`).
- **Merge da H3:** `claude/e12-h3-8253c4` (ponta `5582539bdda7fe939d9e7337f48a5d48f4cc977f`) em
  `2f46529db3ae99b7809305eb70cfcf1d952cd480`, sem conflito.
- **Branch:** `claude/e12-h4-5cd9ff`.
- **Checkout:** `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\e12-h4-5cd9ff`.
- **Commit entregue:** o commit desta branch que contém este recibo (ver `git log`).
- **Decisão A7** (faltava na cópia do índice): `target_marks[].target_id` pode apontar para um
  ator ausente ou morto; o consumidor ignora IDs fora do mapa `target_id → ator` vivo. Cumprida
  em `main.gd` (só inimigos vivos entram no mapa) e já garantida pelo `KitWorldOverlay`.

## Entrega

| Arquivo | Mudança |
|---|---|
| `scripts/main.gd` | `_update_combat_hud()` dentro de `_update_hud`: lê `player.cast_progress()` e `player.kit_hud_state()` **uma vez** por atualização e repassa o mesmo DTO ao `KitResourcePanel`, aos dois `KitWorldOverlay` (`ground`/`overhead`) e ao `BattleControls`. Painel sob VIDA e SP (só com kit). `CastBar` centralizada acima do atalho (`-218` no plano; `-258` no mundo, que mantém a linha de status). Flashes por `presentation_action` (`cast_cancel`, `cast_release`), só quando havia cast na tela no quadro anterior. Saíram "Conjurando X · Ns" e "CONJURANDO Ns"; a linha "mover / Direito / Esc cancela" fica. `_skill_state` devolve a razão do kit (prioridade: recarga canônica, kit, pronto). Botão Admin desce sob o painel quando este cresce. Overlays vivem sob `arena_view` (plano) ou `expedition_view` (mundo). |
| `scripts/ui/battle_controls.gd` | `set_kit_skill_states`, `kit_status_text` e `kit_detail_text`; `show_skill_state` mostra a palavra do kit no atalho e o detalhe (cargas e recarga própria) no tooltip; `show_skill_cooldown` mostra a recarga do kit quando não há recarga canônica. |
| `scripts/actors/combat_actor.gd` | `_draw` chama `ActorCastBar.draw_overhead` em `overhead_bar_y() + 7` (logo sob a barra de HP, mesma largura), com `show_label` para `elite`, `rare_elite` e `boss`; categoria `player` nunca desenha (tem a barra do HUD). `queue_redraw()` só enquanto há cast ou flash, mais um redesenho final que apaga a barra. O flash vem dos `presentation_action` do próprio ator. |
| `scripts/core/expedition/snapshot/runtime_manifest.json` | **Fora da lista de dono** (decisão minha, ver abaixo): só entradas `omitted` para as variáveis novas de apresentação de `main.gd` e `combat_actor.gd`. Nenhuma revisão, campo ou fragmento muda. |
| `tests/mage_gameplay_test.gd` | **Fora da lista de dono:** uma asserção ("HUD exposes remaining cast time") trocada, porque testava exatamente o texto "Conjurando"/"CONJURANDO" que o contrato manda retirar. Passa a conferir a barra, o tempo e a linha de ajuda. |
| `tests/e12/hud_integration_test.gd` (+ `.uid`) | 234 verificações (277 com renderizador, que também checa o desenho). |
| `docs/epics/e12/h4_*.png`, este recibo | Capturas nativas. |

### Dois arquivos fora do dono

1. **`runtime_manifest.json`.** O registro de snapshot lista toda variável de script de
   `RunController` e de `CombatActor`; uma variável nova sem entrada em `fields` ou `omitted`
   quebra a captura (`checkpoint_incomplete`). Precedente: F9 ("campos novos são transitórios e
   entram em `omitted`"). Revertível sem efeito em nada além disso. Se a arquitetura preferir outra
   rota, é só reverter as 11 linhas.
2. **`mage_gameplay_test.gd`.** Uma asserção contrária ao contrato (C5), não uma expectativa
   ocultando falha.

## Posições e ajustes de legibilidade (inspeção das capturas)

- **Rótulo do inimigo** (decisão pedida pela H3): fica **sob a barra de cast**, ou seja, sobre o
  topo da cabeça do sprite. Com o contorno quase preto da H3 é legível sobre grama, terra e
  pedra (`zoom` conferido); acima da barra de HP exigiria mudar o componente. Mantido.
- **Barra do jogador no mundo:** a primeira captura mostrou a barra sobre "Habilidade preparada",
  porque o mundo não esconde a linha de status durante o cast (o plano esconde). Esconder as
  linhas do rodapé encolhia o minimapa, então a barra sobe para `-258` só no mundo.
- **Botão Admin · F10** ficava atrás do painel de recurso (que alarga a caixa de VIDA e SP). Desce
  para `painel + 8 px`.
- **Atalho:** "SEM CARGA", "OCULTO", "HORA ATIVA", "AURORA ATIVA", "SEM CÍRCULO", "DUELO ATIVO"
  em fonte 9 no canto do atalho (cabe nos 60 px), mais o número da recarga do kit no centro, como
  uma recarga normal. Código desconhecido vira "INDISPONÍVEL".
- **Zonas no mundo:** entre o piso e os atores da mesma altura (`z = floor(y*4)+1`); pisos
  superiores continuam cobrindo a zona, como cobrem o corpo.
- Painel, pontos de Sentença, selo e zona do cone/círculo legíveis nas duas vistas; sem ajuste de
  cor ou tamanho nos componentes da H3.

## Espectro da Lâmina (limitação 3 da H2)

Medido no teste: com **um** inimigo o único reflexo golpeia no tick do cast e o marcador nunca
aparece. Com **três** inimigos os reflexos são escalonados em 0,20 s e o marcador fica **0,40 s**
na tela (20 atualizações de 20 ms): perceptível. Nenhuma regra mudou.

## Testes e logs

Godot 4.7.2 standard,
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe`,
SHA-256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`. F1 reimportada antes de
cada rodada (`e07_f1_import_test`), `-SkipEditorImport -F1Fixture`, `-CheckTimeoutSeconds 300`. O
cache de importação veio da worktree da H3 (cópia de `.godot` sem `verification`).

O teste cobre: painel só com kit e linhas do DTO; **uma** leitura de `hud_state` por atualização
(kit de contagem, com marcas e dois inimigos); overlays seguem o DTO e ignoram alvo morto ou
ausente; zonas e marcas das quatro híbridas no plano e no mundo (z entre o piso e o ator); atalho
da Refração sem carga (palavra, recarga do kit, tooltip), cast ainda recusado e sem gasto de SP;
prioridade canônica > kit > pronto; barra do jogador cobrindo o preparo inteiro (plano e mundo),
flash de cancelamento, flash de liberação por `cast_release`, sem flash falso; linha de ajuda no
lugar do texto antigo; barra do inimigo (normal, elite, chefe: rótulo só em elite e acima), cancel
e flash; luta roteirizada com e sem HUD: dano, SP, recargas e estado do kit idênticos e snapshot
exato do controlador idêntico antes e depois de 30 atualizações; snapshot do controlador com o
HUD ligado no mundo; marcadores do Espectro.

Rodada de impacto 1 (`h4_reg2`, 52 etapas, exit 0, sem `SCRIPT ERROR`, `checks.jsonl`
`1f5be79128d7621871bd281860765fecb798f6ca76bb305a0274db0322aab9f0`): os quatro `*_hud_test`,
`hud_components_test`, `hud_seam_test`, os testes de kit, chefe, atalho, barra de ação, ui, cast,
snapshot e onboarding. Rodada final (`h4_reg4`, 24 etapas sobre o `main.gd` final, exit 0, sem
`SCRIPT ERROR`, `checks.jsonl`
`7F8D8D219B35E7F63F47CC89A893B1AED1E9C32507B577DC7B5F7D34F03B5592`): o teste novo, os três de HUD,
`battle_ui_test`, `arena_flow_test`, `mage_gameplay_test`, `e02_run_integration_test`,
`e08_pilot_ui_test`, `action_bar_game_integration_test`, `e07_f1_{cast,consumer,pilot_scene,presentation}`,
`e07_f3/f6_snapshot`, `e08_compact_checkpoint`, `e08_presentation`, `ui_evolution` e `kit_seam`. A rodada 1 foi feita antes de dois retoques de posição da barra no mundo e do
guarda `is_connected` (a ligação do sinal falhou primeiro em `e08_pilot_ui_test`, que restaura
snapshot, e foi corrigida); os hashes de saída dos testes não tocados são idênticos aos da H2.

| Etapa | Resultado | SHA-256 do log |
|---|---|---|
| `hud_integration_test` | PASS, 234 verificações | `940E96198515B50FD0A251E33B1FCD17D41351A27D2C77AF1C39995620A301F2` |
| `hud_components_test` | PASS | `6C770612B5DE131160AA0C767A9A698DA597849CED6A6F75ABA225220B99DA40` |
| `hud_seam_test` | PASS, 188 | `319B453DD0B59FEF583D465A7C3947432ED94142AF18CD5141F19313898CBF1E` |
| `mage_gameplay_test` | PASS (asserção trocada) | `02D14E4B0067A2FC483B56F165EC8534C00262007966F3D45930D287E2919C5C` |

## Capturas nativas

Geradas pelo próprio teste com renderizador real (OpenGL, GTX 1080, 1280 × 720) e uma pasta como
argumento, dentro do projeto de fixture F1:
`Godot_v4.7.2-stable_win64.exe --path .godot/verification/e07_f1/fixture_project --resolution 1280x720 --script res://tests/e12/hud_integration_test.gd -- <pasta>`
(277 verificações, 0 falhas).

| Arquivo | Estado |
|---|---|
| [h4_flat_sp_ac.png](h4_flat_sp_ac.png) | Paladino no plano: Graça 3, Juramento e Égide, cone, Selo |
| [h4_flat_mg_ac.png](h4_flat_mg_ac.png) | Taumaturgo no plano: Graça, Círculo em gelo, "SEM CÍRCULO" no atalho |
| [h4_flat_sp_la.png](h4_flat_sp_la.png) | Duelista no plano: Duelo, Aparo, Sentença, "DUELO ATIVO" |
| [h4_flat_mg_la.png](h4_flat_mg_la.png) | Lâmina no plano: Refração 6,5 s, "SEM CARGA", Sentença e selo do Espectro |
| [h4_flat_player_cast.png](h4_flat_player_cast.png) | Barra do jogador a 50 %, com a linha de ajuda |
| [h4_flat_mob_cast_normal.png](h4_flat_mob_cast_normal.png), [h4_flat_mob_cast_elite.png](h4_flat_mob_cast_elite.png) | Cast de mob normal (sem nome) e de elite (com nome) |
| [h4_world_sp_ac.png](h4_world_sp_ac.png), [h4_world_mg_ac.png](h4_world_mg_ac.png), [h4_world_sp_la.png](h4_world_sp_la.png), [h4_world_mg_la.png](h4_world_mg_la.png) | As quatro híbridas no mundo |
| [h4_world_player_cast.png](h4_world_player_cast.png) | Barra do jogador no mundo |

## Limitações

1. **Cast de mob no mundo** não tem captura própria: o componente é o mesmo do plano e o teste
   cobre só o plano (o `_try_declared_skill` do mob exige alcance e linha de visão). O desenho
   usa `overhead_bar_y()`, igual nos dois espaços.
2. **Marcadores sobre ator oculto por piso superior** (o ator fica atrás de uma ponte) seguem
   desenhados acima dela no mundo (z 4001); o overlay é um nó só. Só ocorre sob pisos que ocultam
   o corpo.
3. **Linha de ajuda no mundo.** O caminho de mira do mundo nunca a definiu; a barra aparece e a
   linha "mover / Direito / Esc cancela" segue só no plano, como antes.
4. **Liberação do jogador.** Um cast concluído do mago plano emite `cast` e não `cast_release`,
   então a barra só some (sem flash de liberação); o flash existe e é testado quando o ator emite
   `cast_release`. Cancelamento sempre pisca.
5. **Cone do Paladino** segue a orientação atual do sprite (DTO da H2), não a do cast.
6. O snapshot do controlador passa a registrar a ligação `presentation_action` → método do
   ator/controlador (padrão já usado por `_animate_action`); o registro a restaura sem duplicar.
   Nenhum campo ou revisão muda.
7. `editor_import` em worktree nova segue falhando por `GitPlugin` neste ambiente; usado o cache da
   H3 com `-SkipEditorImport`.

## Próximo passo

H5 (integração e candidato) depois do aceite do E09, rebaseando sobre `master`; o recibo e o
manifesto de execução acima são a evidência de entrada.
