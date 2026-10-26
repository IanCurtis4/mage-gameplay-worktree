# Supervisão Luna — portas e batch canônico F9 (tentativa interrompida)

## Identificação

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- SHA congelado: `a802ec46466a45bada79d354495045aa8fa3ca00` (HEAD confirmado após falha).
- Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única: `.godot/verification/e07_f1/fixture_project`.

## Recibos anteriores

Os recibos `ports_receivers_07` (89 checks) e `navigation_batch_final_01` (34 checks) são anteriores ao congelamento, em HEAD `8776...`, e têm delta. Não são atribuídos a este SHA. Esta tentativa começou nova reprodução no SHA congelado.

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
