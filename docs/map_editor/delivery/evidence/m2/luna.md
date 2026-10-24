# Supervisão automatizada Luna — F2/M2

Papel: supervisão automatizada delimitada, conforme dispatch F2 e docs/WORKFLOW.md. Esta evidência registra execução, conclusão, erros, timeouts e hashes; não representa auditoria semântica independente.

Candidato: 9d39144ffbc1cf180f7b64c69b0aa0388461ab05 (codex/map-editor-m2).

Comando executado no checkout exclusivo:

`tools/map_editor_terrain/run.ps1 -GodotPath C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe -EvidenceDirectory .godot/m2_luna_02 -Native -ReuseFixture .godot/m2_luna_01/fixture`

O primeiro intento isolado falhou apenas na importação porque o processo do Godot não pôde ler o armazenamento de certificados do Windows. Repeti a execução com acesso elevado autorizado pelo coordenador, reutilizando apenas a fixture descartável criada por mim; todos os testes foram executados novamente. Nenhum resultado de teste anterior foi reaproveitado.

Engine: Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`. Início: `2026-10-24T20:13:10.2766934Z`. Fim: `2026-10-24T20:13:48.5775479Z`. Resultado global: `M2_ALL_PASS`.

- Terreno/brush, movimento canônico e geometria: 102/102 checks aprovados.
- CLI: dois processos aprovados; SHA256 da saída de ambos igual a `27DD31E525450A00CA7051EA1B99AC23358F5FEEB30247CFC0B67D0707394CB0`.
- Regressão documental: 70/70 checks aprovados.
- UI nativa: 24/24 checks aprovados; captura incluída em `luna_run/terrain.png`.
- Todos os processos terminaram com exit code 0, sem timeout. Logs não contêm `SCRIPT ERROR`, `Parse Error` ou `ERROR:`.
- Os hashes atuais de todos os inputs do manifesto conferem; nenhum delta detectado em relação aos valores registrados.

Hashes dos registros: `manifest.json` `4269B10D6A213572185C68A805B0182A2D6E2EE7AF4E1A9F2DE240EE8AC4720A`; `runs.json` `C146DBC515C3F1625ECDA7263E5D4277E41867FC78CCACB17308DF1C476C2C1E`; captura `terrain.png` `FAC03C001D24A6E9C40CF421C8203982FCBFBD4145805DFB292BC9D654DAFB6D`. Os arquivos de resultado e logs foram copiados da raiz da pasta da execução para `luna_run/`; nenhuma pasta `fixture/` ou `.godot/` foi copiada.

Limites: esta supervisão confirma a execução e as expectativas listadas pelo runner. Não atesta cobertura completa do contrato, avaliação visual qualitativa, desempenho de produto, balanceamento ou aceite humano. O aceite D4 permanece pendente conforme contrato.

## Rodada final — candidato 69837145b7857bb630bcfecef0747bf525deeec8

Supervisão automatizada Luna repetida após a correção delimitada, mantendo a rodada anterior registrada acima. O runner foi executado em `tools/map_editor_terrain/run.ps1 -GodotPath C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe -EvidenceDirectory .godot/m2_luna_03 -ReuseFixture .godot/m2_luna_01/fixture -Native`. Fixture própria descartável; todos os checks M2 desta execução foram executados novamente.

Engine Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`. Início `2026-10-24T20:15:53Z`; fim `2026-10-24T20:16:30Z`; resultado `M2_ALL_PASS`.

- Terreno: 104/104 checks aprovados, incluindo rejeição integral de brush em grade acima do limite e de traço com 4097 pontos.
- CLI: ambos os processos aprovados com saída SHA256 idêntica `27DD31E525450A00CA7051EA1B99AC23358F5FEEB30247CFC0B67D0707394CB0`.
- Regressão documental: 70/70 aprovados.
- UI nativa: 25/25 aprovados, incluindo preflight de grade 257×257 sem alocação de triângulos.
- Importação, terreno, CLI A/B, regressão e UI terminaram com exit code 0, sem timeout. Nenhum log da rodada contém `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. Hashes atuais dos 30 inputs do manifesto conferem com os hashes registrados.

Reuso oficial autorizado pelo dispatch/coordenador: os arquivos `.godot/m2_official_frozen_import/checks.jsonl` e `.godot/m2_official_frozen_regression/checks.jsonl` foram conferidos. Import E07/F1, import do editor, teste de geometria (33 checks) e integração de atores (193 checks) registram `failed=false`, exit 0, sem timeout; SHA256 de cada output confere com o registro. Os logs de engine correspondentes também não mostram `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. Sol registrará a justificativa de compatibilidade do reuso e hashes para o SHA final.

Hashes desta rodada: `manifest.json` `4D27F512C7DA3CE8A50B47BF8652C9A16096E1FA4B3D2963D62545B3749FB465`; `runs.json` `1941B223EBA3C230F73AD5FEC88ECE392F54AE59A27640891036F3916470E0BB`; captura `terrain.png` `06B4DFE73CC4CF7FA240AD1F52B9D4161292D24685BCAA3B3A08E4E5E034C34C`. Os arquivos de resultado/log/manifest/captura/métricas estão em `luna_run/final/`; a fixture e `.godot` não foram copiadas.

Limitações: confirma apenas as expectativas executadas e os checks congelados declarados; não é auditoria semântica completa, avaliação visual qualitativa, afirmação de FPS/balanceamento nem aceite humano. D4 segue pendente.


