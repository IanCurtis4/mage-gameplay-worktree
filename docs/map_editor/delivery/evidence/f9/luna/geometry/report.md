# Supervisão Luna — geometria F9

## Identificação

- Checkout: `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- HEAD antes e depois da execução: `5854b5e7f055d15cafa779af4ddf3e1eede42407`.
- Engine: Godot 4.7.2 standard, `Godot_v4.7.2-stable_win64.exe`; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única compartilhada: `.godot/verification/e07_f1/fixture_project` (preservada; não foi limpa).

## Execução

1. `tools/map_editor_completion/run.ps1 -GodotPath <engine> -EvidenceDirectory <...>/geometry/authorities` falhou na primeira tentativa restrita ao importar: Godot não conseguiu ler o repositório de certificados Windows. A repetição elevada não pôde reutilizar esse diretório porque o runner exige um destino ainda ausente. Repetido sequencialmente em `authorities_retry01` com execução elevada: importação passou e os 46 checks F9 passaram (`F9_GEOMETRY_RESULT`, `count: 46`, `ok: true`).
2. `tools/map_editor_candidate/run.ps1 -GodotPath <engine> -EvidenceDirectory <...>/geometry/core -Stage Core` falhou no mesmo erro de certificado sob execução restrita. Repetido em `core_retry01` com execução elevada. Import, candidate e document passaram. O estágio terrain executou 102 checks, dos quais 99 passaram e 3 falharam; runner encerrou com código 1 e a sequência foi interrompida.

Falhas reproduzidas em `core_retry01/terrain.output.log` e `runs.json`:

- `connected_route_to_bridge`: `ok: false`
- `canonical_motion_plan`: `ok: false`
- `continuous_motion_no_teleport`: `ok: false`

Os outros 99 checks terrain passaram. Resultado reportado pelo runner: `count: 102`, `ok: false`, pacote `2d22699e4d9fc7c5f2784aacc5314b301a75344a42bfc43f4889838f0d1f80f4`.

## Logs e hashes

Diretório de preservação da repetição Core: `core_retry01/`. SHA256 dos arquivos principais:

- `runs.json`: `22146CCA996BAF590DE702B9D990B0C563A28DE79792FD919F163C0C851E47D0`
- `terrain.output.log`: `E37BEFEFD54E44C8C8978CF464699CA714F3C8D22A0BA02A4A81138442E9924F`
- `terrain.engine.log`: `92A3BD63C514FBF9D2FB6CD09EC95B9A6911D08052890278D5E4D5D3DD6E2A69`

Os logs de import/candidate/document permanecem junto desses arquivos. O conjunto foi verificado sem ocorrências de `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. Exit 1 corresponde à falha de checks e parada intencional do runner.

## Cobertura omitida e limites

Não foram executados os stages Core posteriores ao terreno. A seleção oficial `tools/verify.ps1 -FromStep 273 -ToStep 297` (25 IDs F1: geometria, atores, inventário, adversos, consumidores, canais, casts/áreas, classes, composição, cena piloto e apresentação) também não foi executada por causa da falha Core, conforme regra de parar na primeira falha. Nenhum teste, expectativa, runner, código ou fixture foi editado. Esta é supervisão de execução automatizada, não auditoria semântica independente.
