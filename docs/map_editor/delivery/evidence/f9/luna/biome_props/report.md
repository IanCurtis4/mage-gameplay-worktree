# Supervisão Luna — catálogo de props por bioma F9

## Identificação

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- SHA congelado e HEAD confirmado: `a44cfb1f9096bb39e51be9f315746c2716b17592`; árvore limpa antes das execuções. Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Uma fixture fixa `.godot/verification/e07_f1/fixture_project`; cada uma das quatro importações registra 1.908 inputs e zero diferenças de SHA entre source e fixture.

## Resultados no SHA congelado

| Etapa | Resultado |
|---|---:|
| BiomeProps | PASS, 30/30 |
| BiomePropsNative | PASS, 23/23 |
| Objects | PASS, 53/53 |
| ObjectsNative | PASS, 25/25 |
| Verify oficial | PASS, 2/2 etapas selecionadas (102 + 37 checks) |

Os quatro runners de completion encerraram com seus marcadores `F9 ...: True`, exit 0, `ok:true` e sem timeout. Verify foi listado antes: `e07_f1_pilot_scene_test` e `e07_f1_presentation_test`, 2/299; executado com `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`, perfil descartável dentro da fixture (`APPDATA`/`LOCALAPPDATA` apontados para `.godot/discardable_profile` e restaurados ao encerrar). Plan registra origem `a44cfb1f9096bb39e51be9f315746c2716b17592`; 2 registros exit0, sem falhas ou timeouts. Saída: `Selected checks passed (2/299 steps); unselected steps were not run.` Nenhum log contém `SCRIPT ERROR`, `Parse Error` ou `ERROR:`.

Os estágios nativos abriram no renderer OpenGL Compatibility da NVIDIA GeForce GTX 1080. O importador avisou que ignorou `res://tools/map_editor_probe/hosting/project.godot`; os marcadores e resultados foram PASS.

## Proveniência

Recibos autorais pertencem ao HEAD de trabalho `c4d7665078de88e1eb1bcade30caeefeb71cf010`, com árvore suja; não os atribuo ao congelamento atual. `author/biome_props_01` registrou falha e está preservado (30 resultados/checks no arquivo; runs SHA256 `196B22300627E296484532921A8944E13B3F1457AD17479968E222E13A21C9CB`). `author/biome_props_02` passou 30, runs SHA256 `C79958C77BA65AAD86321DB67A4A925D45E9C518F54DFA1828EAE1FEFC1595B5`; `author/biome_props_native_01` passou 23, runs SHA256 `A44E40C44A05E372201AF400AA32646A26CB8D58E8D80A4E4437FA96E72479D9`. Os erros de parse e o oráculo JSON genérico anterior não foram removidos nem alterados nos dados para obter PASS. A inspeção de Sol do piso claro/escuro é evidência autoral separada.

## Hashes desta supervisão

- `props/runs.json`: `BE653D751C559648718FF7DBDFE2B721FBE78B13DB274C7AD670445F862A2089`; `props/import/manifest.json`: `9E9E27E0E8155324338458B0BE19E61EFA572CBE80506711C1CD4B5408D91E0B`.
-`native/runs.json`: `23C18D418C95BD2295ACBF1569ECB79CA2C7539D45946CF9CD1E56882C0C4E12`;`native/import/manifest.json`: `653FBF503BF1078F4C79F36011E44CF8670C57E0DF6DA7F8DF6C584A0FC2995A`.
- `objects/runs.json`: `7D80C2CCCC513F37D7065EC1A4A10B2E71F1C4445CD4BE3F02B2C06B6F2BC5E4`; `objects/import/manifest.json`: `0A047AF7DBFFCCC87390A17F17AC50986A69D9C8EEA52F87FBCAE031817AEF04`.
- `objects_native/runs.json`: `3F91FC5557F5BD611C52A0C8428994C4A34B7C240AFEBAC2D0C0E691C11E0BC7`; `objects_native/import/manifest.json`: `D635871C99CE9EBF8C8159CD5B0D82338F85F5AB1F440904A6B2D5FBAB926585`.
- `official/plan.json`: `A6B51521A808D011A81824747783E215163C9665CD249DE252106716B3537AC1`; `official/checks.jsonl`: `F69D9B4D2D226268EA1E2BC79D4FA0BCEF321A8CAE2DAC4BCB6113F3F809F1A5`.

## Limites

Native comprova comportamento automatizado da API/renderização dos sprites dos props; a seleção nativa não prova um avatar renderizado em gameplay. A seleção oficial cobre somente 2/299 etapas. Esta supervisão verifica execução, marcadores, erros, timeouts e hashes; não é auditoria semântica independente nem aprovação completa de F9. Biomas finais, export/transporte integral, compatibilidade extensa e aceite humano permanecem fora desta evidência. Fixture liberada após coleta dos registros.
