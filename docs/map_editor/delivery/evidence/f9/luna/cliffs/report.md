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
