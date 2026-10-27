# Supervisão Luna — janela estável e controles F9

## Identificação e escopo

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- HEAD congelado antes/depois: `581dae4b236f84f178abde67ccf1587f70a147e7`.
- Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única `.godot/verification/e07_f1/fixture_project`. Os três completion runners usaram import normal; Core reutilizou a fixture. Verify usou `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`. APPDATA/LOCALAPPDATA foram direcionados a perfil descartável dentro da fixture e restaurados após execução.
- Seleção sequencial: GameplayNative52, GameplayWindow33, GameplayControls29, Core639 e Verify6.

## Resultados

| Grupo | Resultado | Contagem |
|---|---|---:|
| GameplayNative | PASS (`F9 GameplayNative: True`, `ok:true`, exit0, sem timeout) | 52/52 |
| GameplayWindow | PASS (`F9 GameplayWindow: True`, `ok:true`, exit0, sem timeout) | 33/33 |
| GameplayControls | PASS (`F9 GameplayControls: True`, `ok:true`, exit0, sem timeout) | 29/29 |
| Core candidate | PASS (`M8_SELECTED_PASS`) | 53/53 |
| Core document | PASS | 70/70 |
| Core terrain | PASS | 102/102 |
| Core composition | PASS | 63/63 |
| Core population | PASS | 91/91 |
| Core patrol | PASS | 58/58 |
| Core generation | PASS | 89/89 |
| Core exchange | PASS | 113/113 |
| Core total | PASS; nove registros incluindo import com exit0/`ok:true`/sem timeout | 639/639 |
| Verify selecionado | PASS (`Selected checks passed (6/299 steps)`) | 6 checks |

`verify -List` confirmou `combat_animation_test` (índice10), `e07_f6_snapshot_test` (252), `e07_f5_fault_test` (261), `e07_f3_snapshot_test` (268), `e07_f1_pilot_scene_test` (296) e `e07_f1_presentation_test` (297). Resultados: animações39 checks; F6 snapshot40/0 falhas; fault F5 20/0; F3 snapshot50/0; piloto F1 102/0; apresentação F1 37/0. Todas as linhas de `official/checks.jsonl` têm exit0, `failed:false`, `timed_out:false`. Logs examinados sem `SCRIPT ERROR`, `Parse Error` ou `ERROR:`.

## Auditoria de inputs pós-Verify

Após Verify, recalculei SHA256 de todas as entradas de `native/runs.json`, `window/runs.json`, `controls/runs.json` (1.982 cada) e `core/manifest.json` (1.976), total 7.922 inputs. Fonte atual e fixture conferem com cada hash registrado: 0 divergências em cada conjunto. Os manifests registram HEAD antes/depois igual ao SHA congelado e engine com o SHA listado acima.

`project.godot` foi separado da comparação de inputs. Source SHA256 `ADF17C0941269918DEE0A0005329D874DA199778DDEFCE294CA00E655367857E`; fixture SHA256 `33726AFE86093A0D6F580114F803045E4F6624DC94528ECBEBD61FB199A06517`. Normalizando somente `version_control/autoload_on_startup=true` para `false` no source, os dois arquivos ficam idênticos linha a linha. É o delta VCS declarado para a fixture.

## Capturas e hashes

| Captura | SHA256 |
|---|---|
| `native/gameplay_start.png` | `835A1F8A3C7267D53E21256FEDF88058C8EEAB3A65FB87347359183A32B61D91` |
| `native/gameplay_combat.png` | `D4E598E59515AB1013A3A7014865D99A669E6D0B6D593ECD0B5CD5D1F4C034E4` |
| `native/gameplay_bridge.png` | `177227AF4EE7DEB86480E55E362A4F10E9D5ADA9A1F98D6D128FD4944F78BB92` |

| Arquivo | SHA256 |
|---|---|
| `native/runs.json` | `A616C08B29FB36416C26FCDF90A6E2410CB90A20B8644775D824E1125FEB7F49` |
| `native/import/manifest.json` | `29DB596B76D5D8302AD1AC85D0E4ACCD0B2F927F4754AE16072F7B6976A15C03` |
| `window/runs.json` | `1DB8651D1B5B48CC872FD9F35032F25B6381A1DF022F75CF17DAA01758A70696` |
| `window/import/manifest.json` | `99CC492EEAB72E0589DA2D8A5ED534D038E674094E1C8FC41932DA5BFC35AB28` |
| `controls/runs.json` | `5385E946ABA69C7EE060E28BD058E12D796EB27662C7CDE9641F1815B22BC5EA` |
| `controls/import/manifest.json` | `E55948CA723DEE1894112765420538243BC2F540B0DBBDF7C0377507562A0941` |
| `core/manifest.json` | `CE414C2005504B04428FF976F55D9D1364370F471F44DCAEF30B5B29E910F48A` |
| `core/runs.json` | `C85D0566C524FFB9CAB889C98C8A274C86F26EEDB3906CDD7AE357F9BF3E4572` |
| `official/plan.json` | `6580B7A8B406955D284D7B9C736481F0D801F383EBD4E4203C08A1B30DEB1AB7` |
| `official/checks.jsonl` | `E2F6E2D4801E2704F53DCD1BDEB937DE08F9E4A15AA7CDD6D2FE6AAEB389329F` |

## Limites

GameplayWindow testa um processo Godot headless separado e os tokens/leases/restart; isso não certifica a apresentação visual de um binário release. GameplayNative/Controls invocam APIs App diretamente: não provam que GUI, AX ou CLI estejam ligados, nem cobrem release/export. O campo emitido não significa que os quatro campos WorldField ocultos no legado D05 já estejam visíveis. Não se afirma VFX completo, FPS ou aceite humano.

As falhas históricas Window01 e Controls01 permanecem preservadas: a primeira montagem aguardava o estado intermediário `ready`; a segunda esperava erro no poll enquanto o ACK ainda estava `pending`. Os testes atuais aguardam boot ativo e verificam `pending`, sem relaxar expectativas de produto.

O lote não declara F9-11 concluído. Custos/fluidez, controles ligados às telas, campos visuais D05, release limpo e área final permanecem pendentes. Fixture liberada após encerrar a execução; processos alheios, checkout pessoal e saves não foram tocados. Nenhum commit foi feito.
