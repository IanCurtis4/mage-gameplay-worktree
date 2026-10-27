# Supervisão Luna — componente biblioteca F9 (lote 73b6ee8)

## Proveniência e escopo executado

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- SHA de execução: `73b6ee8ff578343e7804cc7275d0b87d3afc0ffc`; engine Godot 4.7.2 standard.
- Fixture única `.godot/verification/e07_f1/fixture_project`; import normal nos completion runners.
- Escopo Luna encerrado neste SHA: `Library` 50/50, `LibraryNative` 53/53, `ObjectsNative` 25/25 e `BiomePropsNative` 23/23. Os quatro marcadores terminaram em `F9 <stage>: True`, resultados `ok:true`; sem falhas ou timeouts reportados.
- Core foi iniciado uma vez, até os grupos candidate53, document70, terrain102, composition63 e population91 passarem; falhou em `patrol` (57 checks, 56 ok/1 falha: `blocked_return_captures`). O runner parou ali; generation89, exchange113 e Verify oficial não foram executados por Luna no lote desse SHA.

## Falha e resolução posterior

A falha integrada apontou que `contact_shadows_enabled` e estado visual relacionado estavam ausentes do manifesto explícito de snapshot do ator. A evidência negativa está preservada em `core/runs.json` e nos logs Core deste lote. Não atribuo aprovação Core ou dos oficiais ao SHA `73b6ee8`.

Conforme o registro de retomada em `docs/map_editor/delivery/f9.md`, Sol corrigiu os campos visuais omitidos no manifesto (ator revisão 2; cache ArrayMesh/instância refeito) e preservou estado de gameplay e envelope. A validação autoral posterior em `431414e` passou Shadows28, Core639 (incluindo patrol58, generation89 e exchange113) e cinco oficiais. Esses resultados pertencem à autoria Sol em `431414e` mais delta e não são recibos Luna, nem devem ser retroativamente associados a `73b6ee8`. Nesta supervisão distinta, Core foi reexecutado no SHA congelado `6d729724ca29449d02847146f989378e194d2073` e passou os oito grupos/639; os detalhes estão em `../viewport/report.md`.

## Limites

Native cobre API/renderização automatizada, não auditoria semântica independente, aceite humano ou F9 completo. Não houve execução Luna de geração/intercâmbio/oficiais em `73b6ee8`; os checks posteriores de Core pertencem à rodada posterior descrita acima. Nenhuma expectativa foi alterada por Luna. A fixture foi liberada após encerrar a execução daquele lote.
