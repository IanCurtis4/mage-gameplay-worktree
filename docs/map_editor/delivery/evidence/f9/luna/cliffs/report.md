# Supervisão Luna — terreno misto e lados expostos F9

## Identificação

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- SHA congelado confirmado antes da execução: `6400dac848f38139ca36ef4f1a02a9922ca58d45`; Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única `.godot/verification/e07_f1/fixture_project`; manifests das seis importações registram 1.903 inputs cada, com zero divergências entre hash da fonte e da fixture.

## Execuções Luna neste SHA

| Etapa | Resultado |
|---|---:|
| Cliff | PASS, 58/58 |
| CliffNative | PASS, 17/17 |
| Ports | PASS, 92/92 |
| Mesh | PASS, 34/34 |
| Relief | PASS, 58/58 |
| Objects | FALHA, 52/53 |
| Scale | Não executado após a primeira falha |
| Core (639) | Pendente |
| Verify oficial (30) | Pendente |

Os cinco primeiros runners concluíram com o marcador esperado, exit 0, `ok:true`, sem timeout/aborto ou `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. CliffNative executou as asserções/capturas de face íngreme real, lado exposto, piso visível, composição rotacionada e faixa inferior junto à ponte. O aviso do importador sobre `res://tools/map_editor_probe/hosting/project.godot` ser ignorado não impediu o marcador PASS.

Objects importou a fixture com sucesso e passou M8_SELECTED_PASS, mas terminou `F9 Objects: False`, 53 checks, 52 verdadeiros, exit 1, sem timeout. A única asserção falsa foi `catalog_and_sprite_dependencies`, em `tests/map_editor_objects_test.gd:45`, que ainda fixa `compiled.package.dependencies.size() == 12`. Reproduzível com o runner primário `tools/map_editor_completion/run.ps1 -GodotPath <engine> -EvidenceDirectory docs/map_editor/delivery/evidence/f9/luna/cliffs/objects -Stage Objects`. O erro é de expectativa/compatibilidade: com quatro materiais, o contrato passa a nove dependências de material; junto ao catálogo e três props (sprite + import cada), a contagem esperada é 16. Registrei a falha como ocorrida; não alterei teste, runtime ou expectativas e não executei Scale/Core/verify. A fixture ficou liberada após o runner terminar.

Hashes de Objects: `objects/runs.json` `0B930159F32872626DA09CDB474D1342FFBA76833327B72BD6C55160B8CD454A`; `objects/import/manifest.json` `40870D5AC5BA49DDC05BF617985824538B70802E925EC2174FC6AA0CC0C09604`; `objects/geometry.engine.log` `1A7940D6E26BD1C1594A6C4737AD95702329DAF6CCAE4F2C0C172539C103CA12`; `objects/geometry.output.log` `0490AE05C82179712E9FFE4B7AF925BCE17B8541138C55A4E39A4A5AC0AE2705`.

Hashes das etapas concluídas:

- Cliff: `cliffs/runs.json` `E00FC4385DC7E68974A7CC7C5EA376871EF495C0962ED6905699E706663710BF`; `cliffs/import/manifest.json` `FE55A6845C532E7F0E152D92B3FF503344FD6D6C06C7E3324DD6360268BC1D04`.
- CliffNative:`native/runs.json` `4FF74E5943871A8D87F50FC731E9D4911CB3201C7FDEBF95292C08B0F23590A7`;`native/import/manifest.json` `6B166A23E87497289300BDD865AA8FF45B3FF9F782D36CD406C1C485164181AB`.
- Ports: `ports/runs.json` `E2E41EA38B0A94380FD013B6F6CE619516ABC5FE7E153064B1D889FBAF18A598`; `ports/import/manifest.json` `E48301BD708D498A6B2A59DBF73A2A195C7AC66916A0AB7D9E85267B9BB68F2B`.
- Mesh: `mesh/runs.json` `0AD0969E43C2FDA7113330DA3D95D3DAD056356C1A61A86FEEDB9019A096E604`; `mesh/import/manifest.json` `5689DD263E406E8D907B0C7F840276E94EA5FE46408D00222D3A1CBAF6F9A13C`.
- Relief: `relief/runs.json` `C5463CF22991EA93BC3C9442E9D4868FA4AD8343EC9B6BB6263679933F1A979F`; `relief/import/manifest.json` `4B58853CE1A212483A0757F3CBACE17FF8253FCD013941879DB7C2DC3BFE5C7A`.

## Proveniência e limites

Os recibos autorais em `docs/map_editor/delivery/evidence/f9/author/` pertencem ao HEAD `db0557fdada60b57ae420ff2233393748e14c72b` com delta de trabalho, não ao SHA congelado. `cliff_01` e `cliff_02` falharam antes de checks (runs SHA256 `a4b2c6e80beaf8bcda94e544f1a8dd2c24021acc5a7c8f25a9b08e9bb3879972` e `36ddeb00c0810688ca3620d0644331cf8793e0b919a935c97995b3b06bd4266f`); `cliff_03` passou 55 e `cliff_04` 58 (runs SHA256 `2a3687e2d0291838181c07d591bd917472be6040ff2b462b765156ecb70be7ad` e `ccd1027b3fc4b5e85db51e05165e872c9133e35bac512909cc3df7b7c70f6de0`); `cliff_native_01` passou 17 (runs SHA256 `1d2e5db96ce8824faa6ddc8e8ddecfabf5d23d2bf63d006d6484b570dc454078`). A inspeção visual nativa de Sol é evidência autoral separada; esta reprodução Native confirma a execução automatizada no SHA congelado.

A seleção oficial permanece pendente porque Objects falhou antes dela. A cobertura concluída não prova F9 completo, FPS, qualidade de biomas, área final ou aceite humano. Supervisão Luna verifica execução, saída, timeout e hashes; não é auditoria semântica independente.

## Retomada após correção Objects — SHA `0264ce10fa542bc38967a8c83f2e5037d1cec421`

- HEAD confirmado; Godot/fixture unchanged. O diff autorizado no runner/data/runtime era apenas o teste `tests/map_editor_objects_test.gd`; os cinco manifests anteriores em `cliffs/`,`native/`, `ports/`, `mesh/` e `relief/` foram comparados input a input com a fonte atual. Cada um tem exatamente um input divergente: esse teste de Objects. Os testes/implementações específicos das cinco etapas e todo o restante de inputs permanecem byte idênticos. Reutilizo esses PASS somente como recibos de `6400dac848f38139ca36ef4f1a02a9922ca58d45`, não como repetição no novo SHA.
- Objects retry01: 53/53, `F9 Objects: True`, exit 0, sem timeout. O check de dependências passou com o oráculo explícito de 16 caminhos. Manifest de importação: 1.903 inputs, 0 divergências fonte/fixture. `objects_retry01/runs.json` SHA256 `09ED4969DEBDB0D12DDAC7FE5FFF4FC7AA785B7941CF6B2E7701EA0889A4D108`; `objects_retry01/import/manifest.json` SHA256 `40870D5AC5BA49DDC05BF617985824538B70802E925EC2174FC6AA0CC0C09604`.
- Scale: 46/46, `F9 Scale: True`, exit 0, sem timeout. Manifest: 1.903 inputs, 0 divergências fonte/fixture. `scale/runs.json` SHA256 `5C7757A4C61D4EE65C0B8C02FD38A4876EE2C8DA58CA77CBB153A0330475E7D9`; `scale/import/manifest.json` SHA256 `A0EC84B4958E2B2F9825DD706B71DFDEAD0B4D14EFBA517AC328FE72975B8F11`.
- Core retry foi interrompido em Terrain: Candidate 53/53 e Document 70/70 passaram; Terrain teve 101/102 checks verdadeiros, o único falso `too_steep_rejected`, `ok:false`, exit 1, sem timeout. Resultado resumido no log: `M2_HASH e33efc30aae734e02dc8e5f6e41bf8fc59e4cdb09f1dbc6f5937e3fae7731d20`, depois runner encerrou `M8 failed: terrain`. Core completo (639), Verify (30) e Scale/Core posteriores ao primeiro erro não foram executados. Por falhar antes do fechamento, não há manifesto Core completo para esse retry. `core/runs.json` SHA256 `FEE1FE87704673BDDDC78BED81A6665242E1D31C085199E802082D3C3963AAAA`; `core/terrain.engine.log` SHA256 `9EE80EBC8247883BB470B09F6B3ACA2437DFD92DFA47AEE68662FD3CB080E15D`; `core/terrain.output.log` SHA256 `29296BAE62E55B2D6CD96A5367B7D8E16DC0F528FFE53A7CA01E881C8886B241`.
- Logs do estágio sem `SCRIPT ERROR`, `Parse Error` ou `ERROR:`; sem timeouts. Parei na primeira falha e liberei a fixture depois do encerramento e coleta.

Os PASS anteriores Cliff58, CliffNative17, Ports92, Mesh34 e Relief58 continuam anexados ao SHA6400dac, com input de teste Objects como única diferença; seus contadores e hashes permanecem na seção de execução anterior. A causa da nova falha está com Sol; nenhuma expectativa foi editada por Luna. Verify oficial continua pendente. Esta evidência não certifica F9 completo, FPS ou qualidade visual fora das verificações/capturas registradas; supervisão de execução não é auditoria semântica independente.

## Retomada Core após ajuste do oráculo de penhasco — SHA `f898e2a1912f64d6a3c6e5fa32d6cc853a0f4de1`

- SHA confirmado antes da execução; Godot 4.7.2 standard com SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`; fixture única preservada.
- Os PASS dirigidos Cliff58, CliffNative17, Ports92, Mesh34, Relief58 e os retries Objects53/Scale46 não foram repetidos. Os recibos diretos antigos continuam atribuídos aos SHAs originais. Comparação contra os manifests de `objects_retry01` e `scale` aponta uma única diferença de input desde `0264ce1`: `tests/map_editor_terrain_test.gd`. Runtime dos estágios, seus outros testes e demais inputs listados são idênticos; nenhum PASS anterior é atribuído a `f898e2a`.
- Core foi chamado sequencialmente com runner primário e fixture única. Import exit0; Candidate 53/53 passou; Document 70/70 passou; Terrain não carregou o teste, então Core completo não foi alcançado e contagem 639 não é certificada. Erro reproduzido: `SCRIPT ERROR: Parse Error: Cannot infer the type of "walking_only" variable because the value doesn't have a set type.` em `res://tests/map_editor_terrain_test.gd:118`, seguido de `ERROR: Failed to load script ... Parse error.` Runner encerrou `M8 failed: terrain`, exit1, `timed_out:false`. Verify oficial 30 etapas não foi iniciado. Parei na primeira falha; nenhuma alteração de código/oráculo por Luna.
- Evidências Core: `core_retry01/runs.json` SHA256 `4C208B9B2B1A608F2E9C3717BA1EDF817F5C1971A1099B06B3D8115C36E6764B`; `core_retry01/terrain.engine.log` SHA256 `13EDEA0BC754C85D813A515FB2BFAA48D29925E4321A674AE0B5E1C13FF7F59B`; `core_retry01/terrain.output.log` SHA256 `8CF00BF25A5C1C5DA4355DB5A8CDF3B24DD0A02431D462C8AF79C75B809DB20B`. Candidate/document logs e seus hashes foram preservados junto aos registros. Sem timeout; erros são exatamente o parse/rejeição de script acima.
- Fixture liberada depois do runner encerrar e da coleta de hashes. F9 continua incompleto; este recibo não é auditoria semântica nem aceite.

## Core retry02 após correção de tipagem — SHA `d788a3160a9e8594aa1f4fbbcba7ea929e68504a`

- HEAD/engine confirmados: `d788a3160a9e8594aa1f4fbbcba7ea929e68504a`, Godot 4.7.2 SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`. Runtime segue idêntico ao SHA6400dac; delta único de input após f898e2a é a anotação `var walking_only: bool = mixed_peak.ok` em `tests/map_editor_terrain_test.gd`. Hash da fonte e da cópia na fixture é idêntico: `68B6DF08004898D96FE664202142E24F24E22FBB7D7CB8BAD1A2859642F842A1`. Os recibos dirigidos dos estágios antigos não são atribuídos a este SHA.
- Core retry02 repetiu import, candidate, document, terrain e composition: import exit0; candidate53, document70, terrain102 e composition63 passaram. Parou em population antes de gerar seu marcador/resultado, com o runtime acusando Nil em `population_compiler.gd:67` (acesso a `_data` dentro de `prepare`); em seguida erros de acesso `ok` em `population_compiler.gd:188` e `tests/map_editor_population_test.gd:142`. Output contém três `SCRIPT ERROR`; processo retornou exit -1; runner encerrou `M8 failed: population`. `timed_out:false`. Não avançou a patrol/generation/exchange, não atingiu 639 e Verify30 não foi iniciado. Não alterei código nem expectativa e parei na primeira falha.
- Hashes: `core_retry02/runs.json` `BB654A64FFFE14C1090275E2F5E803B05A15F2601D9B7F8A8E509426FDA0CA71`; `population.engine.log` `48E7F7BEE76CEB54556989431802706EEBEBA5E1824061561CAD88D7963C5774`; `population.output.log` `E9563E023347E23FB2B16A6EC4C5A39B72D59F41B679015BE666D194D561CF24`; `terrain.engine.log` `998B58C5F493EED57AE43CCA71507B3F4E9D4294B68005B4CCE2D0FEC4200D08`; `terrain.output.log` `A0509B150A4FCCBA7101139F0A8E97D1D4AB72B878CEDD311D74DAB813C05D13`.
- As falhas anteriores de expectativa `too_steep_rejected` e de parse `walking_only` permanecem registradas nas seções anteriores. Fixture liberada após o runner encerrar e hashes serem coletados. F9/verify oficial seguem pendentes; esta supervisão não é auditoria semântica independente nem certificação de F9 completo.

## Retomada após correções de abertura e população — SHA `7073d38257a9d456173b13e11dd53e296589c6c0`

### Execuções novas

- HEAD confirmado: `7073d38257a9d456173b13e11dd53e296589c6c0`, árvore limpa antes dos testes. Godot 4.7.2 standard SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`. Uma fixture fixa; sem bootstrap.
- Cliff retry01 passou 61/61 (`F9 Cliff: True`), incluindo os três invariantes da correção de runtime: população ignora visual não caminhável, abertura 24/400 chega ao próprio pacote e corpo real de largura20 não atravessa passagem24 sem crash. Exit0, sem timeout. Manifest: 1.903 inputs, source/fixture iguais. `cliffs_retry01/runs.json` SHA256 `DA9CD9ADADB8267DD86136E70930230314D6F046AF3629DB6B7D2344670C593B`; `cliffs_retry01/import/manifest.json` SHA256 `7215C32DBDC1A90F4CEC32DFDDC522B7D4C95CCB3708836EB3E86F186438CA45`.
- Ports retry01 passou 92/92 (`F9 Ports: True`), exit0, sem timeout. Manifest: 1.903 inputs, source/fixture iguais. `ports_retry01/runs.json` SHA256 `D937BBCF31FE6989308A79342FE269A6A721762B69E6523350FBB0FA36E0FFFF`; `ports_retry01/import/manifest.json` SHA256 `BD845AEA34D058F634EDF615442F5452D07D83D614765D47A761BAB93AE5E0B0`.
- Core retry03 passou candidate53, document70, terrain102, composition63, population91, patrol58, generation89 e exchange113; total 639, todos os nove registros (incluindo import) ok, exit0, sem timeout. Manifest: 1.903 inputs, source/fixture iguais. `core_retry03/runs.json` SHA256 `24A7FBBFB86308E709008D265FDF31554FDB9DF67D632C86B1215BBE55376DF7`; `core_retry03/manifest.json` SHA256 `A862E89EE7ADABC75771DB90755F47E642EE523414C085749AC44AD75E66F248`.
- A seleção oficial idêntica aos 30 nomes de `ports/official/plan.json` foi listada antes: 3 F0, 25 F1 e snapshots F3/F6; `Plan only: 30/299`. Executada com `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`. `APPDATA` e `LOCALAPPDATA` apontaram para `.godot/discardable_profile` dentro da fixture e foram restaurados ao encerrar. Plan registra origem `7073d38257a9d456173b13e11dd53e296589c6c0`, engine e 30 selecionados. Os 30 checks tiveram exit0, zero falha e zero timeout; saída final `Selected checks passed (30/299 steps); unselected steps were not run.` Nenhum `SCRIPT ERROR`, `Parse Error` ou `ERROR:` nos logs de Cliff/Ports/Core/verify. `official/plan.json` SHA256 `23167F409FB3478605FC730E84E148EC411638A2EE4C1213A54A6C3A2C7A9F34`; `official/checks.jsonl` SHA256 `6E4CE34D5DD30DF9932DC8814B62C5C27BA525B5C11C2A3DEE696A914041EA30`.

### Recibos direcionados reaproveitados e deltas

- Native17, Mesh34 e Relief58 permanecem recibos do SHA `6400dac848f38139ca36ef4f1f02a9922ca58d45`; Objects53 e Scale46 do SHA `0264ce10fa542bc38967a8c83f2e5037d1cec421`. Não foram repetidos nem atribuídos ao SHA atual. Comparando seus manifests antigos ao checkout atual, as diferenças são os deltas já documentados: `terrain_compiler.gd`, `population_compiler.gd`, `map_editor_cliff_test.gd`, `map_editor_objects_test.gd`, `map_editor_terrain_test.gd` e `tools/map_editor_completion/run.ps1` (para recibos de 6400); para recibos de 0264, `terrain_compiler.gd`, `population_compiler.gd`, `map_editor_cliff_test.gd`, `map_editor_terrain_test.gd` e o runner. Os testes/implementações dirigidos de renderer, world, Mesh, Relief, Native, Objects e Scale permanecem byte idênticos nos seus recibos e no checkout corrente. Os deltas são os casos de penhasco/abertura/população e correções no teste/runner; não invalidam nem transformam os PASS históricos em execução nova.
- Cliff autoral `cliff_05` passou 61 checks no SHA `d788a3160a9e8594aa1f4fbbcba7ea929e68504a`, antes do ajuste isolado de tipagem; runs SHA256 `0700A5F374A2F6A90825274C224EF9C93B3D0850BF237CD38EE78E699C9FB58B`. É proveniência autoral separada; a execução Luna Cliff61 acima pertence a `7073d382`.
- As falhas das tentativas anteriores (`too_steep_rejected`, parse `walking_only`, Nil em `population.prepare`) continuam no histórico deste relatório sem serem apagadas; foram superadas no delta atual e Core foi reexecutado integralmente.

A fixture foi liberada depois do encerramento da regressão e coleta dos hashes. Esta seleção prova somente as etapas executadas; não é auditoria semântica independente, FPS, aceite humano ou validação completa de F9. Visualização, export, biomas/área final e demais requisitos de F9 continuam fora da cobertura indicada.
