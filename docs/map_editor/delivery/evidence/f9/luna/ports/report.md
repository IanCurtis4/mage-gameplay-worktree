# Supervisão Luna — portas e batch canônico F9 (tentativa interrompida)

## Identificação

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- SHA congelado: `a802ec46466a45bada79d354495045aa8fa3ca00` (HEAD confirmado após falha).
- Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única: `.godot/verification/e07_f1/fixture_project`.

## Recibos anteriores

Os recibos `ports_receivers_07` (89 checks) e`navigation_batch_final_01` (34 checks) são anteriores ao congelamento, em HEAD `8776...`, e têm delta. Não são atribuídos a este SHA. Esta tentativa começou nova reprodução no SHA congelado.

## Execução

A seleção oficial foi listada com `-Test` explícito e confirmou 30/299 etapas. Um primeiro `-List` sem seleção também foi chamado por engano; foi apenas planejamento, sem executar checks (298/299 selecionados), não conta como validação.

Iniciei `tools/map_editor_completion/run.ps1` do checkout primário para `Stage Ports`, sem `SkipImport`, usando a fixture compartilhada. Import passou (`M8_SELECTED_PASS`). O estágio Ports falhou antes do marcador final: checks de portas até `terrain_receiver_rejects_malformed_profile_without_error` passaram; em seguida ocorreu:

`SCRIPT ERROR: Invalid operands 'Array' and 'Dictionary' in operator '!='.`

Local: `scripts/map_authoring/compiler/terrain_compiler.gd:357`, chamado por `tests/map_editor_port_fragments_test.gd:283` (`terrain_cases`) e linha 109 (`run`). O runner encerrou com `F9 Ports failed; logs preserved.` Resultado: não alcançou 91 checks; sem PASS, sem exit 0 válido, e interrompi a sequência conforme instruído. Batch, Geometry, Relief, Mesh, Objects, Core e verify oficial não foram executados nesta tentativa.

## Evidências e hashes

- `ports/runs.json`: `87E75633142EB2D5C8B15C7F1903315C0683F1F9F5D4FB9D541EBB7A11FA2F73`.
- `ports/geometry.engine.log`: `91AFE2627CD87C376393B2EE3BDB43151E7B7C7A0C97D7ECDE1BABCE4346E094`.
- `ports/geometry.output.log`: `FFCCEB5F9F3E4C0068F0C24AA1F662C5DE6FA3EEAC08E3D25798674F5F1FC482`.
- `ports/import/manifest.json`: `9A7371E052B8959F4A1E3272E789AAB1A47A4DC0DC12AA9F250959A0DA8EE38F`.
- `ports/import/runs.json`: `D39061C61A91056AF18B7F655725B2D332ABED342F803AC0AFB7AAD72D9E01C0`.
- `ports/import/import.engine.log`: `5FADBFDEE9D3B8366EB72E65BD33C2D4FE56DB9AC49C87E052255E678F4FA283`.
- `ports/import/import.output.log`: `65266ECC51590D7E85010DAB58E897AC1A8BD879079AA036BDFA5F18A05C9AA7`.

## Limitações e liberação

Esta tentativa não valida o candidato: falhou no primeiro runner. Não fiz alterações em runtime, testes, runner ou expectativas. Supervisão de execução não é auditoria semântica nem aprovação de F9 completo. A execução encerrou e a fixture compartilhada está liberada para a próxima correção/reprodução; preservar esta pasta como tentativa histórica.

## Retomada após correção — SHA `bea3f6fc2b4defbbf00bc864f5209d167f32750c`

- HEAD confirmado antes da execução; árvore limpa. Godot 4.7.2 standard SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Nova execução Ports preservada em `ports_retry01/`: 91/91, `F9 Ports: True`, `ok:true`, sem erro ou timeout. `runs.json` SHA256 `06465295A0967620AC3AE48ADE55A8434ADF1CD3CD101AB079E015570837C26F`; `import/manifest.json` SHA256 `88F8F331D6230FA6C1E17D8D45EE1B145525A16FDCBD23D9DD626D79AEEF0361`; `geometry.engine.log` SHA256 `65BA2CD3D77A97577837AFE8936090E99C734CCC0B8991CEB95A284DAADC4EA5`.
- Batch: 34/34, `F9 Batch: True`, `ok:true`. `batch/runs.json` SHA256 `08BA5C97DBE1F7E1BFDACA1BACEE5CEF82A7034C87D41443A99BF4D05D51A22A`; `batch/geometry.engine.log` SHA256 `2C441A1792CB7B2445F024160F5906E8D064A7028B0B515E537CF36E3C4AADA4`.
- Geometry: 46/46, `F9 Geometry: True`, `ok:true`. `geometry/runs.json` SHA256 `070339A48FAE77A6410F67B5D01B764F3628E5543EEE0DE5FE293EFE74389FFD`; `geometry/geometry.engine.log` SHA256 `D2508953C26AF3DF8A3AE518B7275D7ED83DEF8F8F6FB82CF84F8B853996E6F4`.
- Relief: 58/58, `F9 Relief: True`, `ok:true`. `relief/runs.json` SHA256 `3CB8E82608882A975DA71EEE98060EFDC842EDE04FC1D23D199CA79559410DF2`; `relief/geometry.engine.log` SHA256 `517CB5E7411D58D486F46BCF2A76B264413B10E1FA39C9720440FF3C3769B56D`.
- Mesh: 34/34, `F9 Mesh: True`, `ok:true`. `mesh/runs.json` SHA256 `A1C7D8FDEA7A241EF96E276162CEFA8EEF800C36F06FEA97EF55C26C3B3CC910`; `mesh/geometry.engine.log` SHA256 `2037B1EDF25404C71EDA8937B22861457E9B6F713E04A8CC1D9846C7B6BF0FC1`.
- Objects: 53/53, `F9 Objects: True`, `ok:true`. `objects/runs.json` SHA256 `88D0EE85A4A282F650A341E828E290E67A73A5509045B9B93D79F6226F1D1BFB`; `objects/geometry.engine.log` SHA256 `1084920B203BA0592F81788DA122D484E63D19C5A67B122CB8EAD56E641C1F63`.

## Core interrompido

Core foi iniciado com a fixture única via runner primário. Candidate e Document passaram; Terrain teve `ok:false`, 102 checks, 101 verdadeiros e um falso: `port_wider_than_edge_rejected`. O runner interrompeu com `M8 failed: terrain`. `core/runs.json` SHA256 `158A26AD01BFA184DCD81D46D3852EE6A59018EF7A1E559084576F00ACDEC366`; `core/terrain.engine.log` SHA256 `B649B1B1E1C63C3C48BA647894242E35A6E47A8F4809DFB9819266DE26AD9762`; `core/terrain.output.log` SHA256 `F3A06D74F2AC83C74A1F173E0F31CB6FBDCE7E5A93FC762B03C4438131ABD55D`. Core esperado (639) não completou; official verify não foi iniciado. Nenhum erro de runner antes desse check falso; sem timeout relatado. A fixture foi liberada após o runner encerrar.

Os seis PASS dirigidos são evidência nova no SHA `bea3f6f`; o recibo Core e a regressão oficial permanecem pendentes. Limite continua: supervisão de execução não auditoria semântica nem aprovação de F9 completo.

## Retomada final — SHA `e6fdf437ad4f39ef690699941124ad6e8b485867`

### Base e recibos reaproveitados

- HEAD confirmado no início e após os runners: `e6fdf437ad4f39ef690699941124ad6e8b485867`; árvore limpa antes da execução. Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Os recibos Batch/Geometry/Relief/Mesh/Objects de `bea3f6fc2b4defbbf00bc864f5209d167f32750c` foram conferidos, não reexecutados, conforme autorização. Todos trazem 1.899 inputs; a comparação completa encontra somente três divergências, exatamente `scripts/map_authoring/compiler/terrain_compiler.gd`, `tests/map_editor_port_fragments_test.gd` e `tools/map_editor_completion/run.ps1`. O diff `bea3f6f..e6fdf43` confirma que a primeira só restaura o diagnóstico de fonte inválida fora dos extremos (mantendo `geometry_precision_limit` para excesso dentro de EPS), a segunda adiciona um invariante de diagnóstico e a terceira atualiza Ports para 92. Os arquivos fonte dos cinco estágios e seus testes específicos (`map_editor_navigation_batch_test`, F9 geometry, relief, mesh e objects) não divergiram dos recibos; os hashes dirigidos desses inputs foram conferidos. Os recibos continuam pertencendo ao SHA bea3f6f e não são reportados como reexecução no SHA novo.

### Nova execução no SHA congelado

- Ports retry02: 92/92, `F9 Ports: True`, `ok:true`, exit 0, sem timeout/erros. `ports_retry02/runs.json` SHA256 `74DC6F1B1C135F1B62D719DECAC7FA3B7A4943D093FA8E7AA947FEBE1DB381EF`; `ports_retry02/import/manifest.json` SHA256 `B6A8F4D3312628E9A7F0D88E38AD4ABD29FA75D8F4B5215204C87FE3AACA5A43`.
- Core retry01: candidate 53, document 70, terrain 102, composition 63, population 91, patrol 58, generation 89 e exchange 113; total 639, todos `ok:true`, exit 0 e sem timeout. `core_retry01/runs.json` SHA256 `4E3BF1F30D1F32CE7F91383BC8A0CDB2B364AA879F9FDF492ECA91B312E00D62`; `core_retry01/manifest.json` SHA256 `9B0F876CC7DF00A62454AB06E0DFD290D9FB7ED8781ECE373B4C4AA2B0F41D51`.
- A seleção oficial foi listada antes e marcou 30/299. Executada com `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`, teste explícito dos três F0, 25 F1 exceto import e native import, mais F3/F6 snapshots. `official/plan.json` registra SHA de origem `e6fdf437ad4f39ef690699941124ad6e8b485867`, engine acima, 30 selecionados, import ignorado, nenhum bootstrap/native import na lista. `official/checks.jsonl` tem 30 registros de execução: 30 exit 0, 0 falhas, 0 timeouts. Saída final: `Selected checks passed (30/299 steps); unselected steps were not run.` Sem `SCRIPT ERROR`, `Parse Error` ou `ERROR:` nos logs oficiais. `official/plan.json` SHA256 `7DB6D6C0C0D049AF5C4B504C0E873B116EAACDECACAD6D2F57AB2F044F5C51E8`; `official/checks.jsonl` SHA256 `1EBDD7EF5C509055131D281D9C6B3AE66DA6AB9840D518E9D2A31B07BDDB2796`.
- `APPDATA` e `LOCALAPPDATA` foram apontados durante verify a `.godot/discardable_profile` dentro da fixture descartável e restaurados no encerramento do processo. O verify levou aproximadamente 8m40s; o bloco novo inteiro (Ports, Core, verify) levou cerca de 18 minutos.
- Fixture encerrada e liberada depois da coleta de evidências. Nenhuma etapa bootstrap foi executada.

## Limitações concretas

O reaproveitamento dos cinco recibos é limitado às mudanças listadas e aos inputs específicos idênticos; não os converte em reprodução no novo SHA. A suíte oficial abrange somente os 30/299 passos selecionados. Os números densos de objetos são medições de compilação do teste, não FPS, distância mínima nem cobertura visual. A supervisão confirma execução/conclusão/erros/timeouts/hashes, não é auditoria semântica independente nem aprovação de F9 completo; renderização/material/cliffs/biomas/export e aceite humano permanecem fora desta evidência.
