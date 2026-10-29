# F9 Map Biome — evidência de execução Luna

Data: 2026-10-29  
Checkout: `.tools/map-editor-m5`  
Freeze: `4e3a3788878c7520552c7815d0c2915301857f5f`  
Fixture única: `.godot/verification/e07_f1/fixture_project`  
Engine: `Godot_v4.7.2-stable_win64.exe`, SHA-256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`

## Resultados

| Etapa | Resultado | Evidência |
|---|---:|---|
| MapBiome | PASS, 15/15, exit 0 | `model_01/runs.json`, `geometry.engine.log`, `geometry.output.log` |
| MapBiomeNative | PASS, 13/13, exit 0 | `native_01/runs.json`, captura `forest_border_batch_native.png` |
| Borders | PASS, 93/93, exit 0 | `borders/runs.json` |
| BordersNative | PASS, 32/32, exit 0 | `borders_native/runs.json`, quatro capturas, request/response CLI |
| GameplayNative | PASS, 52/52, exit 0 | `gameplay_native/runs.json`, capturas de início, combate e ponte |
| Candidate Context | PASS, 53/53, exit 0 | `context_02/runs.json` |
| Population | PASS, 91/91, exit 0 | `context_02/runs.json` |
| Patrol | PASS, 58/58, exit 0 | `context_02/runs.json` |
| Exchange | PASS, 113/113, exit 0 | `context_02/runs.json` |
| Verify `editor_import` | PASS, 1/299 selecionado, exit 0 | `verify/plan.json`, `verify/checks.jsonl` |

Os runners de completion compararam 2045 entradas source/fixture por execução, sem divergências, e mantiveram o mesmo HEAD antes/depois. O runner Candidate Context registrou 2039 entradas porque exclui os seis imports de props presentes no conjunto completion; suas 2039 comparações source/fixture também tiveram zero divergências. Os quatro imports de terreno foram conferidos separadamente por Sol, totalizando dez metadados de import. As duas fontes Terra permaneceram iguais às cópias da fixture: clearing `150509026fddc323396d20fdd015fee47c1dacb47685c1f326842b77260484ab`; overpass `1501a98d8e201ce10017c0f410d137da5bad0c21fbd97039c9e52a9d693341c9`.

Somando checks dos runners MapBiome, Borders, GameplayNative e Candidate Context: 520 passaram. O check adicional de `editor_import` também passou. Nenhum dos logs examinados contém `SCRIPT ERROR`, `Parse Error` ou `ERROR`. Godot emitiu um aviso informativo ao ignorar o projeto aninhado em `tools/map_editor_probe/hosting` durante varreduras do editor; não afetou os resultados.

A captura MapBiomeNative mede 1600×1000, igual à janela física, com canvas de 1269×632, 44 meshes, 19 cores e 8 spans de borda florestal. Hash da fonte: `8672bb93057f3adedd3b6941671646eebbfc87f53b14839fff19c4ef8da2fb04`; hash do pacote: `f11eb8065e1512f0479746a905d502224978c4153577258f1ff9884b4c633088`.

## Tentativa inválida preservada

A primeira invocação do runner Candidate Context recebeu `-ReuseFixture literalF1`, que o script interpretou como caminho relativo e começou a criar `.tools/map-editor-m5/literalF1/`. A tentativa foi interrompida após a importação e checks parciais de Candidate, preservados em `context/candidate.engine.log`, sem recibo terminal da suíte. Ela não conta como PASS. Após todos os processos terminarem, Sol moveu a cópia auxiliar para `.godot/verification/f9_invalid_literalF1_20261029`, preservando os arquivos; recibo em `author/map_biome/invalid_fixture_archive.json`. A execução válida foi repetida em `context_02` usando o caminho absoluto da fixture autorizada.

## Ambiente e escopo

`APPDATA` e `LOCALAPPDATA` das execuções Candidate Context e Verify apontaram para o perfil descartável dentro da fixture. Verify selecionou somente `editor_import`, com timeout padrão de 120 segundos. Não houve processo Godot ativo ao final.

Este relatório registra execução, contagens, hashes e triagem de erros; não representa auditoria semântica independente nem aceite de produto.
