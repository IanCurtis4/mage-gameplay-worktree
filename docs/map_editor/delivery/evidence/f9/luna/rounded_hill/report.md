# Supervisão Luna — F9 rounded hill

## Identificação e escopo

- Checkout: `.tools/map-editor-m5`; fixture única: `.godot/verification/e07_f1/fixture_project`.
- HEAD final dos inputs: `0b2d57a39a55c84ae2b3380714830f41440c6ce5`; permaneceu idêntico antes/depois das etapas corrigidas.
- Engine: Godot 4.7.2 standard, `Godot_v4.7.2-stable_win64.exe`, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Os runners completion registraram 2.008 hashes de inputs por etapa. `verify` conferiu a fixture importada e executou só os três IDs listados, com import explícito fora do plano e timeout de 300 s.
- Para `verify`, `APPDATA` e `LOCALAPPDATA` foram direcionados temporariamente a `.godot/verification/e07_f1/fixture_project/.godot/discardable_profile`; as variáveis do processo foram restauradas no `finally`. Não houve processo de engine ativo ao terminar.

## Resultados

| Etapa | Resultado | Evidência |
|---|---|---|
| Rounded | PASS, 19/19 | [manifesto](model_corrected/runs.json), [log](model_corrected/geometry.output.log) |
| RoundedNative | FAIL, 13/14 checks; GUI/AX, compilação, publicação, captura da curva/caminho e `App.open` passaram; `App.start` falhou | [manifesto e métricas](native_diagnostic/runs.json), [log](native_diagnostic/geometry.output.log), [captura](native_diagnostic/rounded_hill_curve_and_path.png) |
| Library | PASS, 50/50 | [manifesto](library/runs.json), [log](library/geometry.output.log) |
| LibraryNative | PASS, 53/53 | [manifesto](library_native_corrected/runs.json), [log](library_native_corrected/geometry.output.log) |
| Verify selecionado | PASS, 3/299 etapas | [plano](official/plan.json), [checks](official/checks.jsonl) |

`RoundedNative` continua bloqueado pelo limite de snapshot. `App.start()` retornou `snapshot_too_large`: `envelope_bytes=10,308,936` contra `limit_bytes=4,194,304`; 22.405 containers (11.083 arrays, 11.322 dictionaries), `container_record_bytes=9,498,624`, 634 objetos/747.616 bytes. `raw_geometry` reportou 536 superfícies, 828 conexões e 1.024.396 bytes. O limite de 4 MiB não foi alterado. O teste não chegou a picking, caminhada nem captura de gameplay; não há evidência de corpo 20/32 caminhando na peça.

Tempos medidos nesse mesmo fluxo, em milissegundos: preparo/compilação 3.319,990; publicação de mapa 26.381,105; abertura da aplicação 45.324,845; tentativa de início 71.333,846. O tempo de início terminou em falha e não é uma medição de frames. Não se infere FPS desses tempos.

`LibraryNative` emitiu um aviso do importador sobre ignorar `tools/map_editor_probe/hosting/project.godot`; seus 53 checks passaram e o runner encerrou com exit 0. O arquivo `official/checks.jsonl` contém três registros, todos exit 0, sem timeout ou falha: snapshot F3 (50 checks internos), geometria F1 (33) e integração de ator F1 (193). A lista anterior confirmou os IDs e índices 268, 273 e 274. A seleção terminou em `Selected checks passed (3/299 steps)`.

## Falhas de autoria corrigidas durante a rodada

- Uma invocação inicial do runner `Rounded` via Windows PowerShell 5 falhou antes de iniciar a engine porque o shell não fornecia `System.IO.Path.GetRelativePath`. A execução pelo PowerShell 7 passou; a pasta anterior foi preservada em `model/`.
- A primeira fixture do conector usou uma expectativa não vacuosa incorreta para o centro do stroke. O stroke foi reposicionado em `(100,100)`, mantendo a abertura em `(100,0)` protegida; a execução congelada seguinte passou 19/19.
- A primeira versão do teste nativo tinha deadline nomeado incorretamente e inferência GDScript sem tipo explícito. As declarações foram corrigidas; a prova de UI depois passou pelo menu visível “Criar”, com metadata da ação e item habilitado.
- A primeira prova LibraryNative esperava 11 comandos e quatro presets, contagem anterior ao T01. A verificação foi atualizada para 13 IDs sem duplicatas (cinco comandos de terreno e oito de viewport) e cinco presets; LibraryNative corrigido passou 53/53.

## Hashes dos testes congelados

Os hashes abaixo são os dos seis inputs de teste no manifesto `library_native_corrected/runs.json`; a etapa incluiu o hash de todos os 2.008 inputs e manteve HEAD `0b2d57a...` antes/depois.

| Arquivo | SHA256 |
|---|---|
| `tests/map_editor_rounded_hill_test.gd` | `BA37B0190C7DB92A076EB6508CC3C900641E3E6F7E3EE1C603F5871E1F7213D3` |
| `tests/map_editor_rounded_hill_test.gd.uid` | `6C844041B32D2AD55E49F6152AD7611F23126E1597DEF8940EBC3B237164E0FB` |
| `tests/map_editor_rounded_hill_ui_test.gd` | `DD219485633AD78B30B486631F2C9E7716A7D902268E6A60C78F015E874D5145` |
| `tests/map_editor_rounded_hill_ui_test.gd.uid` | `E91BBF190221B6CF7FA0195C8365A8A4B84B52A0C05B3FC6BBEBAF2E428DB9D4` |
| `tests/map_editor_library_test.gd` | `9E9631CE6F2FD4DA16E733BCC4C3B2E380B4544E368FB21795B1F70C4D65B3A4` |
| `tests/map_editor_library_ui_test.gd` | `890FBF52FCA5AAD4D17476F71AE69A7AD2F4C36480709D08D606B369C2AA66AB` |

## Draft SnapshotDensity não executado

Rascunho ignorado, fora dos inputs e sem importação/execução: `.godot/f9_shadow_draft/luna_snapshot_density/test.gd`. Planeja 17 oráculos:

1. Ator jogador e estado de run reais adquirem o `SnapshotTickBarrier`.
2. Captura do grafo metadata passivo de 1.000 células respeita o teto de 4 MiB.
3. Capturar não muta grafo, ciclo nem referências de origem.
4. Bytes e métricas declaradas correspondem ao envelope e ao limite.
5. Envelope valida.
6. Restauração cria ator e estado de run sem reutilizar a instância.
7. As 1.000 células, identificadores e ordem sobrevivem.
8. `Array[Vector3]` preserva tipo e conteúdo.
9. `Dictionary[String,int]` preserva ambos os tipos.
10. Referência cíclica de metadata permanece apontando para si.
11. Container compartilhado apontado por vários campos permanece `is_same`.
12. Arrays iguais porém distintos continuam distintos.
13. Descritores completos e não tipados (`TYPE_NIL`, classe/script vazios) validam e restauram.
14. Descritor parcial é rejeitado.
15. Tipo declarado incompatível é rejeitado.
16. Capturas seguintes não alteram o payload anterior.
17. Conteúdo acima de 4 MiB continua falhando com `snapshot_too_large` e reporta o teto.

Este draft não foi compilado nem executado e não substitui a prova T01 de gameplay real.

## Limites e estado

Model, biblioteca e checks oficiais selecionados passaram nos escopos relatados. A integração da colina arredondada pelo fluxo completo permanece tecnicamente inconclusa: o início do jogo com o candidato falha no orçamento de snapshot e walking/picking não foram exercitados. Não afirmar aprovação técnica do candidato, performance em jogo, aceitação de produto ou validação visual completa. Não foi executada a suíte ampla.
