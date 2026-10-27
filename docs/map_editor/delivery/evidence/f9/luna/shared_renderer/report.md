# Supervisão Luna — renderer compartilhado F9

## Identificação e escopo

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- HEAD congelado antes/depois: `81e2f4252c85567173acd6557abed6b147c7cb36`.
- Engine Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única `.godot/verification/e07_f1/fixture_project`. Os quatro completion stages usaram import normal. Verify usou `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`; APPDATA/LOCALAPPDATA foram isolados pela fixture e restaurados ao final.
- Execução sequencial: RuntimeView12, CanvasOrder43, ShadowsNative90, ViewportNative52 e cinco checks oficiais. Nenhum Core foi executado nesta tarefa; Core639 anterior permanece evidência separada do SHA `6d72972`.

## Resultados

| Stage | Resultado literal | Checks |
|---|---|---:|
| RuntimeView | PASS (`F9 RuntimeView: True`, `ok:true`, exit0, sem timeout) | 12/12 |
| CanvasOrder | PASS (`F9 CanvasOrder: True`, `ok:true`, exit0, sem timeout) | 43/43 |
| ShadowsNative | PASS (`F9 ShadowsNative: True`, `ok:true`, exit0, sem timeout) | 90/90 |
| ViewportNative | PASS (`F9 ViewportNative: True`, `ok:true`, exit0, sem timeout) | 52/52 |
| Verify selecionado | PASS (`Selected checks passed (5/299 steps)`) | 5 checks |

`verify -List` confirmou `combat_animation_test` (índice10), `e07_f3_snapshot_test` (268), `e07_f6_snapshot_test` (252), `e07_f1_pilot_scene_test` (296) e `e07_f1_presentation_test` (297). Saídas: animações39 checks; F3 snapshot50/0 falhas; F6 snapshot40/0; F1 piloto102/0; F1 apresentação37/0. Cada linha de `official/checks.jsonl` mostra exit0, `failed:false`, `timed_out:false`. Logs examinados sem `SCRIPT ERROR`, `Parse Error` ou `ERROR:`.

## Auditoria pós-Verify dos inputs

Após Verify, recalculei SHA256 para todos os inputs nos quatro arquivos completos `model/runs.json`, `order/runs.json`, `native/runs.json` e `viewport/runs.json`: 1.965 inputs por conjunto, 7.860 entradas no total. Cada hash da fonte atual e cada arquivo espelhado na fixture conferiram com o hash de entrada registrado; divergências: 0/1.965 por conjunto. Isso inclui todos os arquivos `.import` presentes nos manifests completos.

O hash do `project.godot` foi auditado separadamente, sem exigir identidade entre source e fixture. Fonte: `ADF17C0941269918DEE0A0005329D874DA199778DDEFCE294CA00E655367857E`; fixture: `33726AFE86093A0D6F580114F803045E4F6624DC94528ECBEBD61FB199A06517`. Após normalizar somente `version_control/autoload_on_startup=true` para `false`, os arquivos são idênticos linha a linha. É o delta VCS declarado para impedir o autoload do GitPlugin local ausente na engine standard. Todos os manifests registraram HEAD antes/depois igual ao SHA congelado.

## Comparação de imagens

Comparei por SHA256 as dez capturas usuais de `native` com `docs/map_editor/delivery/evidence/f9/author/viewport_shadows_native_01`; todas são byte a byte idênticas. A captura adicional `bridge_external.png` também é byte a byte idêntica a `bridge_after.png`, reproduzindo a apresentação do ator externo sem reparenting.

| Captura | SHA256 |
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
| `sand_rotated_before.png` | `D74B27A8060C6BE4D8CF89D6221A74FD6EFA7837B279BCA2B830D83A684DB8D8` |
| `bridge_external.png` | `9EC7A556F131D9B1F7F4C8FB512ECA763AF920B35AB0649E080BBE21EEF6B9CD` |

## Hashes das evidências

Hashes recalculados diretamente dos arquivos:

| Arquivo | SHA256 |
|---|---|
| `model/runs.json` | `29139685258B25E2C7969E0209F11FBDBD68EE27120C0308412996AC73DF6B7A` |
| `model/import/manifest.json` | `3A8DD0D2E198DC9A81AC071CC6D1A1A6F8537A4AF56EA07ED5C89154F409DCCC` |
| `order/runs.json` | `819A673FD00D045FE4A73B031B719B584AD21189546D65C069D609747C105DB5` |
| `order/import/manifest.json` | `4919C59AE548F2EB6C76DBA7680D399DA02CDF4BC3239F6E5D6D21C089E56D16` |
| `native/runs.json` | `F15593D7C2C2F97D56CB48B1B6F77E4253FAFC85F2CE85B08BCE74BC00FC56B5` |
| `native/import/manifest.json` | `C642584A66CE80DA99F633B65B17D4C9483171F888411ECC297AFA67CF62CDE7` |
| `viewport/runs.json` | `45A119265B19A3E12C7C907B11AEF50E7BB045140A6C83BAD0FBF44AB9ED30B8` |
| `viewport/import/manifest.json` | `6CFCEB81438AD400441E0BF26840C1DBF76CBDAE79E15C77BDE694A4627FFCD8` |
| `official/plan.json` | `4BF0BF777D6B3606268AC00A95CCD3843AE93105C900118037D34A4374145C8A` |
| `official/checks.jsonl` | `16EAC2C0971C3D05DDBA543C5A71D8CE61607C13AAF065637E9FFBB1514BBEDD` |

## Limites

O produtor acrescenta a extração `MapPackageView`, observa atores externos sem reparenting e conserva as regras de imagem/perfil/raio provadas. Esta supervisão confirma execução, checks, hashes e igualdade de imagens; não é auditoria semântica independente nem aceite de produto. Não mede FPS ou custos integrados. Gameplay/PlayerActor/RunController, combate real, restart/export, janela de teste, área final e demais pendências F9 permanecem fora deste lote. Falhas históricas citadas no checkpoint foram preservadas, não reexecutadas nem alteradas aqui. Fixture liberada depois de encerrar os runners; nenhum commit realizado.
