# Forest consumer probe — execução Luna

Data: 2026-10-29  
HEAD antes/depois: `4e3a3788878c7520552c7815d0c2915301857f5f`  
Fixture: `.godot/verification/e07_f1/fixture_project`  
Engine SHA-256: `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`  
Resultado: **PASS, 12/12, exit 0, sem timeout ou erro genérico**.

## Pins e integridade

- Bytes do mapa AX: `8e3f1c3c47709d204eeaf3061e3d98beabb0dfa987ed09ff24ad2ec79e6a631f` — igual ao recibo Terra antes e depois.
- Hash semântico do mapa: `8a9051f8a416a58890365e1b262cea309053ff52c5ce20725d0598ef7875ed55` — igual ao recibo.
- Hash do pacote compilado: `098aa6b630015504ec47abfa45257fb0c7b571efabad590016dcc34acfc71fdc` — igual ao recibo.
- Entradas source/fixture conferidas: 2046, sem divergências. O total inclui o backup `sanctuary_woods.map.json.bak` presente na fonte.
- Metadados de import conferidos: 10/10, source e fixture iguais.
- HEAD, arquivos de entrada e bytes do mapa permaneceram estáveis durante a execução.

## Consumo verificado

A probe confirmou os dois snapshots originais e 47 placements, poses e link `woods_seam`, contexto manual de floresta sem overrides, bioma florestal no authoring context e no stage runtime, e perfis `forest_rootbank_v1` nas instâncias `clearing` e `overpass`. O compilado contém 35 spans florestais, cobrindo ambas as instâncias, e nenhum span `ruin_envelope_v1`.

O candidato usou o corpo canônico 20×32. `Candidate.prepare` passou para todos os apoios compilados. O package contém 2 peças, 2 render instances, 84 superfícies e 131 conexões. O marcador de entrada autorado em `[160, 0, 640]` foi preservado e comporta esse corpo. O preview de mapa usa entrada provisória; esta probe não registrou sua posição efetiva nem a escolheu a partir do marcador autorado.

## Tempos observados

- Compilação do mapa: 28,516 s medidos; métrica interna do compilador: 28,480 s.
- Preparação do candidato: 30,441 s medidos; navegação interna: 24,581 s.
- Execução total: 77,321 s.

## Arquivos

`forest_consumer.manifest.json` contém argv, ambiente descartável, hashes das entradas e imports, exit, timeout, saída estruturada e métricas canônicas. `forest_consumer.stdout.log`, `forest_consumer.stderr.log` e `forest_consumer.engine.log` preservam a saída bruta.

Escopo: esta execução valida a composição AX persistida, os snapshots, a compilação florestal, o candidato e o acesso do corpo real aos apoios. O candidato preparado é efêmero; a probe não salva a fonte de produto. A entrada de preview é provisória. Não houve App, caminhada, combate ou medição de FPS.

Sol corrigiu a descrição do marcador, as unidades dos tempos e a referência ausente a `result.records` na consolidação, após a execução terminal de Luna. Nenhum teste, oráculo, log ou manifesto bruto foi alterado.
