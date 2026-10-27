# Supervisão Luna — broadphase da ordem de canvas F9-10

## Identificação

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- HEAD congelado confirmado antes/depois: `fec5bc193f45f55bea54d27557aa9b76b15a5597`.
- Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture exclusiva `.godot/verification/e07_f1/fixture_project`; completion usou import normal. Verify oficial usou `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`.
- APPDATA/LOCALAPPDATA apontaram para `.godot/discardable_profile/Roaming` e `Local` na fixture durante Verify e foram restaurados pelo bloco `finally`.
- Escopo executado sequencialmente: `CanvasOrder` (esperado 36) e `ShadowsNative` (esperado 86), seguido dos três checks oficiais.

## Resultados

| Etapa | Resultado | Contagem |
|---|---|---:|
| CanvasOrder | PASS (`F9 CanvasOrder: True`, `ok:true`, exit 0, sem timeout) | 36/36 |
| ShadowsNative | PASS (`F9 ShadowsNative: True`, `ok:true`, exit 0, sem timeout) | 86/86 |
| Verify selecionado | PASS (`Selected checks passed (3/299 steps)`) | 3 checks |

`verify -List` confirmou `combat_animation_test` (índice 10), `e07_f1_pilot_scene_test` (296) e `e07_f1_presentation_test` (297). As saídas foram animações PASS (39 checks), piloto F1 102 checks/0 falhas e apresentação F1 37 checks/0 falhas. `official/checks.jsonl` registra todos com exit 0, `failed:false`, `timed_out:false`. Logs examinados sem `SCRIPT ERROR`, `Parse Error` ou `ERROR:`.

## Integridade dos inputs

Após Verify, recalculei SHA256 de todas as entradas dos manifests contra a fonte atual e a fixture: cada manifest tem 1.939 inputs; em `order` e `native`, as 1.939 fontes conferem com o hash do manifest e com as 1.939 cópias na fixture. Divergências: 0/1.939 por raiz (3.878 entradas fonte+fixture). O SHA do projeto-fonte registrado é `ADF17C0941269918DEE0A0005329D874DA199778DDEFCE294CA00E655367857E`; o SHA do projeto-fixture é `33726AFE86093A0D6F580114F803045E4F6624DC94528ECBEBD61FB199A06517`, diferença restrita aos deltas declarados de projeto nos manifests (VCS startup, configuração do modo nativo e preset/cena de release). HEAD manteve-se no SHA congelado.

## PNGs comparados com a evidência de 04a7dfc

Os dez PNGs de `native` são byte a byte idênticos à baseline `docs/map_editor/delivery/evidence/f9/luna/shadows/native` (`SHA256 igual` em cada par):

| Captura | SHA256 igual nos dois diretórios |
|---|---|
| `bridge_after.png` | `9EC7A556F131D9B1F7F4C8FB512ECA763AF920B35AB0649E080BBE21EEF6B9CD` |
| `bridge_before.png` | `480E68F53B5D218C8B91ACCF63F740A12531FF2445E69C38F43839B198D07BEB` |
| `earth_flat_after.png` | `CAE5857E03F1A3E0AB23F13C765A54AABCD8CBFEFDABB77CFD0B497A760D9111` |
| `earth_flat_before.png` | `DFEA3A56F18776399F1F83D8C607F3729DD7B5DDA323469BD719A3768B995D7C` |
| `sand_flat_after.png` | `B3686D2B935F6FE3BFAF06B7ADFF23E916019A3AE6B23055F265014B882C1FDB` |
| `sand_flat_before.png` | `FC3593A45ACA45BEEE229DAA559FA47E5AAC3E79BFC43E5BE00CFE7985501A5E` |
| `sand_ramp_after.png` | `D7BC1CD3686A49D5097CFC05DC2D815F9E996F3E7C1AC19646D32C6D44A5F447` |
| `sand_ramp_before.png` | `F8166D2A784641A7524333BFA680F26CE5D07C922CD09488FC3B778065B6CC9D` |
| `sand_rotated_after.png` | `C394292CE86727E7C3F684B95C259C7905D1077811698C0987AA08C3D3222917` |
| `sand_rotated_before.png` | `D74B27A8060C6BE4D8CF89D6221A74FD6EFA7837B279BCA2B830D83A684DB8D` |

## Tempos do broadphase

Medições de CPU da ordenação apenas, preservadas em JSON; não certificam FPS, renderização ou latência integral da UI. CPU reportada: Intel Core i7-8700 @ 3.20GHz. Cada vetor contém as amostras originais, sem normalização:

| Condição | Itens (atores/terreno) | Frio (µs) | Quente (µs) | Movimento de 1 ator (µs) | Movimento de todos (µs) |
|---|---:|---|---|---|---|
| small | 72 (8/64) | 9.654, 7.200, 7.812 | 585, 343, 318, 312, 315, 494, 386 | 1.919, 517, 498, 494, 498, 492, 490 | 2.467, 1.183, 1.496, 1.174, 1.377, 1.264, 1.193 |
| representative | 576 (64/512) | 81.699, 73.124, 60.280 | 2.950, 2.709, 2.756, 3.694, 3.474, 3.038, 3.039 | 19.576, 3.826, 4.146, 4.149, 3.589, 3.097, 3.133 | 28.372, 16.168, 13.977, 12.723, 18.278, 16.046, 14.332 |
| stress | 2.176 (128/2.048) | 727.239, 626.969, 301.418 | 14.320, 14.471, 14.891, 15.006, 13.452, 14.197, 12.639 | 104.432, 14.774, 15.404, 14.266, 17.297, 15.136, 13.668 | 130.099, 38.310, 37.850, 35.687, 48.875, 49.413, 51.456 |

## Hashes confirmados

Recalculei diretamente os hashes abaixo e conferem com a tabela/evidência persistida.

| Arquivo | SHA256 |
|---|---|
| `order/runs.json` | `A8888F2690313E721C76372D83D393CD6D1D0B73EDF164C2F9387BC0F83DF159` |
| `order/import/manifest.json` | `139F1D2F8B13EDC28B50532B8A0C1AFA820B44327052124875729039C53A8EA9` |
| `order/canvas_order_metrics.json` | `2E585F8B30391AE0E15BE3E14B45205CEFCC54B9A83720BAEE7389FCEDE8FFB9` |
| `order/canvas_order_scaling_metrics.json` | `95C2BA34EA54181E374B0D882AD579E11A1AA687651369D84D3303D4058B5593` |
| `native/runs.json` | `FEBBAC454C0B7498AFCF0CA5EB74AADFB7EA7B1781ACB980EC40646D2E563795` |
| `native/import/manifest.json` | `DFC5EE74D0E64F18E7819AF92A366618F352ED5E840941AFDB563210290FDEFE` |
| `official/plan.json` | `9B33FA970BE1E86B849172D8D1B8168A7F434309FCE06CC36B8272719E58333B` |
| `official/checks.jsonl` | `A7A677D75DF66F2C745A126BF1B022EC20E281446D0501ABEF570BF4078A1B27` |

Os recibos autorais pertencem a `8bd0420` mais seu delta e não são atribuídos a `fec5bc1`. O trabalho é supervisão de execução e reprodução delimitada; não é auditoria semântica independente, aprovação visual humana ou certificação completa de F9. A fixture foi liberada após encerrar os processos desta execução; checkout pessoal/playtest/save não foi tocado.
