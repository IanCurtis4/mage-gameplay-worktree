# Supervisão Luna — sombras de contato e ordem de canvas F9

## Escopo e proveniência

- Checkout: `.tools/map-editor-m5`; branch `codex/map-editor-f9`.
- HEAD congelado antes e depois: `04a7dfcfb0ca8bd9ef2ef98a27073ca4cbe86734`.
- Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture exclusiva: `.godot/verification/e07_f1/fixture_project`; importação normal nos runners de completion. Verificação oficial usou `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300` conforme seleção solicitada.
- `APPDATA` e `LOCALAPPDATA` apontaram para `.godot/discardable_profile/Roaming` e `Local` dentro da fixture durante as execuções e foram restaurados quando os processos terminaram.
- A sequência executou `Shadows`, `CanvasOrder`, `ShadowsNative`, `BordersNative`, `ObjectsNative`, `BiomePropsNative`, `MaterialsNative` e `CliffNative`, nesta ordem. O pedido inicial usava números no argumento `-Stage`; o ValidateSet do runner define aliases textuais, usados aqui com os números tratados como contagens esperadas.

## Resultados

| Etapa | Resultado literal | Contagem |
|---|---|---:|
| Shadows | PASS (`F9 Shadows: True`, `ok:true`) | 21/21 |
| CanvasOrder | PASS (`F9 CanvasOrder: True`, `ok:true`) | 18/18 |
| ShadowsNative | PASS (`F9 ShadowsNative: True`, `ok:true`) | 86/86 |
| BordersNative | PASS (`F9 BordersNative: True`, `ok:true`) | 32/32 |
| ObjectsNative | PASS (`F9 ObjectsNative: True`, `ok:true`) | 25/25 |
| BiomePropsNative | PASS (`F9 BiomePropsNative: True`, `ok:true`) | 23/23 |
| MaterialsNative | PASS (`F9 MaterialsNative: True`, `ok:true`) | 20/20 |
| CliffNative | PASS (`F9 CliffNative: True`, `ok:true`) | 17/17 |
| Verify selecionado | PASS (`Selected checks passed (3/299 steps)`) | 3 checks |

Verify listou `combat_animation_test` (índice 10), `e07_f1_pilot_scene_test` (296) e `e07_f1_presentation_test` (297). Saídas: animações PASS (39 checks); piloto F1 102 checks/0 falhas; apresentação F1 37 checks/0 falhas. Nenhum timeout ou erro de engine/teste foi observado. Avisos benignos do importador indicaram que `tools/map_editor_probe/hosting/project.godot` foi ignorado por ser outro projeto.

## Integridade e hashes

Após o último `verify`, recalculei SHA256 para cada entrada listada nos oito manifests, lendo a fonte atual do checkout e o caminho correspondente na fixture. Cada manifest contém 1.939 inputs: fonte atual = fixture = hash registrado nos campos `sha256`/`fixture_sha256`, em todas as 1.939 entradas de cada estágio; divergências: 0/1.939 em cada um dos oito estágios (15.512 comparações de entradas no total). Isso confirma o estado final da fonte `04a7dfc` e da fixture, não apenas os hashes capturados durante o import.

| Manifest de importação | Inputs | Divergências SHA256 fonte/manifest/fixture |
|---|---:|---:|
| `geometry/import/manifest.json` | 1.939 | 0 |
| `order/import/manifest.json` | 1.939 | 0 |
| `native/import/manifest.json` | 1.939 | 0 |
| `borders_native/import/manifest.json` | 1.939 | 0 |
| `objects_native/import/manifest.json` | 1.939 | 0 |
| `biome_props_native/import/manifest.json` | 1.939 | 0 |
| `materials_native/import/manifest.json` | 1.939 | 0 |
| `cliff_native/import/manifest.json` | 1.939 | 0 |

Os manifests registram `project_source_sha256` `ADF17C0941269918DEE0A0005329D874DA199778DDEFCE294CA00E655367857E` e `project_fixture_sha256` `33726AFE86093A0D6F580114F803045E4F6624DC94528ECBEBD61FB199A06517`. A diferença corresponde aos deltas de projeto declarados pelos runners (desativar VCS no startup; habilitar plugin/driver UI no modo nativo; habilitar cena principal/map editor e preset de export isolado no release). Todos os arquivos listados como inputs, inclusive `project.godot`, foram re-hashados após Verify e conferem fonte/fixture/manifest.

Todos os SHA256 desta tabela foram recalculados diretamente dos arquivos citados e conferem com os valores registrados abaixo. HEAD e SHA do engine foram conferidos após a execução.

| Evidência | SHA256 |
|---|---|
| `geometry/runs.json` | `08997CE241B1A0528CF524BD88794CA7A2B938A8C6F4B6F3F7993AD5560C1B2B` |
| `geometry/import/manifest.json` | `CA1AA428F571D092943C256708C3C4B44F4013AB00E13D2AB6AFA688F7F5E40A` |
| `order/runs.json` | `0C4B86BC2F54D018DF6834999CE984EFB0EF6FE13E74B957B72819B69CD42000` |
| `order/import/manifest.json` | `40766B3EAB21FCFBC933FA943F733EFABBA099F2D482D7822373181A9BD27D75` |
| `native/runs.json` | `D03683093264AD63B64BAF87F08827276B405FA80F2431E39A288FEFF114C367` |
| `native/import/manifest.json` | `D80A82AD75E33022964FC1EFBD56204BFEA6F622AE9E26850B1E7D3A04CB5604` |
| `borders_native/runs.json` | `4522C50959905DD2DC6CC0A9BB9FD63E19D7AD2296A62C9C6707FD9374C8EEFF` |
| `borders_native/import/manifest.json` | `380DE5C432056AED9DBD68F293689C482C0CEC87AB5AEAAE17DE07A1B36B964D` |
| `objects_native/runs.json` | `85F390D494D0A90836A077D6F84630BA8B795593E2396062C124AAD72574D893` |
| `objects_native/import/manifest.json` | `88768B705DFB20FDE13B7986D3F9F5B207543C4C0F518370C0EA7B6A98BFDED2` |
| `biome_props_native/runs.json` | `2AF49A944E800B212F4C66FB6B0DD28524BE84B64383A0129BFAC0A97FA36B4C` |
| `biome_props_native/import/manifest.json` | `658D695F6B9CB1DBB6DCD5D4B8AB521423CABAEEE003CCD48E4F19ACAAFF0D95` |
| `materials_native/runs.json` | `078FC8272E0A8635F2CC9EFE78641347979A4659D2CCB294883CB3492C72C175` |
| `materials_native/import/manifest.json` | `F4F0D035273BA44B5713CBA753C51E7DAFCFFB83FD69EACD1ED977B366AAA1EE` |
| `cliff_native/runs.json` | `2DDCE8AFB44CBC7059D26B9C1196B8886E93B40D49FE4916AF8F4DA8BF0DCBD2` |
| `cliff_native/import/manifest.json` | `4A375B5EC487FAE35883C393629DDD61D5B2B92A9F4C022B319D5E4A02498E51` |
| `official/plan.json` | `82FC39B87B77370ABB0602257E4FBFCFE85E3A36372857531DB9AED8483DC9A9` |
| `official/checks.jsonl` | `127D2A522C753F73F1C1B902D78630669B08D4F9CBB3D659F2D06D498987650C` |

Os recibos autorais permanecem vinculados a `43147e0` mais seu delta e não são atribuídos ao SHA congelado aqui. Esta evidência é reprodução/supervisão de execução, não auditoria semântica independente, inspeção visual humana, aceite humano nem certificação completa de F9.

## Fixture

Execuções encerradas sem processo Godot desta tarefa remanescente. Fixture liberada para o coordenador; nenhum arquivo do checkout pessoal de playtest/save foi tocado.
