# E12 H3 — recibo: componentes visuais do HUD

Tarefa H3 do [E12](../e12.md) (contrato §4, [e12_contract.md](../e12_contract.md)). Terra,
Sonnet 5.5. Só apresentação: nenhum componente lê ou escreve regra, relógio ou save.

## Origem

- **SHA-base:** `03c2c2db31010b4471e33fe40984d894c21cf5ee` (ponta de H1,
  `claude/e12-h1-708c9b`).
- **Branch:** `claude/e12-h3-8253c4`.
- **Checkout:** `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\e12-h3-8253c4`.
- **Commit entregue:** o commit desta branch que contém este recibo (ver `git log` da branch).

## Entrega

| Arquivo | Papel |
|---|---|
| `scripts/ui/hud/hud_palette.gd` (`HudPalette`) | Paleta única por elemento e cores/constantes da barra de cast; leitura defensiva de `cast_progress` (`read_cast`) e do topo do DTO (`is_clean_state`) |
| `scripts/ui/hud/cast_bar.gd` (`CastBar`, `Control`) | `set_progress(progress)`, `flash(&"cancel" \| &"release")`; nome, `%.1fs`, preenchimento `1 - remaining/total`; `{"active": false}` esconde; o flash mantém a última barra por 0,35 s (a leitura já volta a inativa no cancelamento) |
| `scripts/presentation/actor_cast_bar.gd` (`ActorCastBar`) | `draw_overhead(canvas, progress, top_y, width, flash = &"", show_label = false)`; barra de 3 px, mesma razão e cores do `CastBar`; `plan_overhead` expõe a geometria para teste |
| `scripts/ui/hud/kit_resource_panel.gd` (`KitResourcePanel`, `Control`) | `set_state(dto)`: `pips` em pontos, ∞ com prazo (`unlimited`), `charges` em losangos com a recarga (só enquanto recarrega), `timer` em barra com prazo; `{}` esconde |
| `scripts/presentation/kit_world_overlay.gd` (`KitWorldOverlay`, `Node2D`) | `mode` `&"ground"` (zonas) ou `&"overhead"` (marcadores); `set_state(dto, actors)`; zona `world` projetada ponto a ponto por `expedition_projection.gd`, `flat` em coordenadas da arena; cone/círculo/círculo ampliado na cor do elemento; Sentença em pontos acima de `overhead_bar_y()`; IDs fora do mapa (ou atores liberados) são ignorados (A7) |
| `tests/e12/hud_components_test.gd` | 164 verificações (170 com renderizador real) |
| `docs/epics/e12/h3_*.png` | Capturas nativas |

Para H4: durante um flash, `ActorCastBar.draw_overhead` deve receber o **último** progresso ativo
(o relógio já está inativo); sem progresso válido o flash desenha uma barra cheia na cor do
flash. `KitWorldOverlay` no modo `overhead` pede redraw por quadro enquanto há estado (os
marcadores seguem os atores); o `ground` só redesenha em `set_state`. O painel define o próprio
`custom_minimum_size` (252 × linhas); o `CastBar` tem 360 × 20.

## Decisões de robustez (DTO malformado)

- Painel e overlays recusam o DTO inteiro (nada desenhado) com schema errado, chave de topo
  desconhecida, ou qualquer entrada da própria seção inválida (recurso, zona ou marca; `id`
  duplicado no painel). Seções alheias não são avaliadas (variante com skill inválida ainda
  desenha recursos e zonas).
- Todo `Variant` é checado por `typeof` antes de comparar (comparar `int` com `String` gerava
  SCRIPT ERROR; corrigido).

## Cores e tamanhos (ajuste de playtest)

Elementos: `none` c9c3b4, `fire` ff7a3d, `ice` 72c9ff, `lightning` e9d76a, `tricolor` e58cc8,
`light` f6e7a8, `arcane` ba8de9. Barra de cast: preenchimento f5cc77, cancelamento dc5757,
liberação fff3c4, fundo da barra como o da barra de HP. Pontos de raio 3,5 (marcadores) e 4,5
(painel); zonas com preenchimento 16 % e contorno 85 % de alfa, esmaecendo até 55 % conforme o
prazo acaba. Marcadores a `overhead_bar_y() - 9`, empilhados de 12 em 12 px.

## Testes e logs

Godot 4.7.2 standard, `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe`,
SHA-256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.

`tools/verify.ps1 -SkipEditorImport -F1Fixture -CheckTimeoutSeconds 300 -Test 'hud_components_test','hud_seam_test'`
(diretório `.godot/verification/h3_final2/`; a fixture F1 veio de `-Test e07_f1_import_test`,
`h3_f1/`):

| Etapa | Resultado | SHA-256 do log |
|---|---|---|
| `hud_components_test` | PASS, 164 verificações, 0 falhas, sem SCRIPT ERROR | `DC81FA52194B8DF2F8C9C8F9DFD526BAE6A22903AFAE951A87530E50F3DA6AF1` |
| `hud_seam_test` (H1, regressão) | PASS, 188 verificações, 0 falhas | `B79A9762A8523F438CA13E40AF22018F08548208BB978E5DA62519A8F5D826AD` |

O teste cobre: DTO de fixture com cada `kind` (pips, ∞, charges, timer); cone e círculo nos dois
espaços (pontos projetados conferidos um a um; plano em coordenadas da arena); marcadores com 0 e
5; empilhamento; ID ausente e ator liberado; progresso a 0 %, 50 % e 100 %, cancelamento e
liberação; as 12 variantes do kit de fixture e lixo variado (nenhum desenho, sem erro); desenho
real quando há renderizador.

## Capturas nativas

Geradas pelo próprio teste com renderizador real (OpenGL, GTX 1080) e um argumento de pasta:
`Godot_v4.7.2-stable_win64.exe --path . --resolution 1000x640 --script res://tests/e12/hud_components_test.gd -- <pasta>`.
O `verify.ps1` roda em `--headless` e não captura.

| Arquivo | Estado |
|---|---|
| [h3_cast_bar_player.png](h3_cast_bar_player.png) | `CastBar` a 0 %, 50 %, 100 %, cancelada e liberada |
| [h3_actor_cast_bar.png](h3_actor_cast_bar.png) | `ActorCastBar` sob a barra de HP: 0 %, 50 % com nome, 100 %, cancelada, liberada |
| [h3_resource_panel.png](h3_resource_panel.png) | Painel: DTO de fixture (pips, ∞, charges, timer) e outro com pontos 0 e 5 |
| [h3_world_overlay_flat.png](h3_world_overlay_flat.png) | Cone, círculo e círculo ampliado no plano; Sentença 5/5 com selo e 0/5 |
| [h3_world_overlay_world.png](h3_world_overlay_world.png) | Os mesmos no mundo, projetados |

## Limitações

- Sem legibilidade provada em jogo: tamanhos e cores são de laboratório sobre fundo liso; H4 e
  o playtest ajustam. No mundo as zonas são desenhadas no plano do chão do `center` (a altura de
  cada ponto vem de `center.y`; terreno desnivelado não é seguido).
- O nome da skill do inimigo (`show_label`) fica sob a barra e pode cruzar o corpo do ator; H4
  decide a posição final.
- `KitResourcePanel` não valida `kit_id` nem `skills` (não são da sua seção).
- A janela da captura é a do projeto (780 × 500 recortados); o recorte é só da prova visual.
- `editor_import` em worktree novo terminou com falha de acesso (código `-1073741819`) neste
  ambiente, depois de erros de GitPlugin; a importação já existente do cache bastou
  (`-SkipEditorImport`). A execução modificou arquivos `.import` rastreados, que foram
  revertidos; `.uid` de outras pastas ficaram só como não rastreados e não entram no commit.

## Próximo passo

H4 liga os quatro componentes no `main.gd`/`combat_actor.gd` depois de H2 e H3: painel junto de
VIDA e SP, `CastBar` acima da barra de atalhos, `ActorCastBar` no `_draw` com `show_label` para
`elite`, `rare_elite` e `boss`, e os dois overlays na camada do mundo.
