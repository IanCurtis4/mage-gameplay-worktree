# Supervisão Luna — geometria F9, rodada final

## Congelamento e conferência autoral

- Checkout/branch: `.tools/map-editor-m5`, `codex/map-editor-f9`.
- HEAD antes e depois dos testes: `ce7bd5906accf71fffb60cc17c8c2f7ebffc2dd8`.
- Engine compartilhada Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture existente: `.godot/verification/e07_f1/fixture_project`; reutilizada, sem limpeza.
- Evidência autoral conferida: `docs/map_editor/delivery/evidence/f9/author/geometry_regression_01/`. Os `runs.json` mostram import e oito estágios concluídos, sem timeout/aborto, todos `ok: true`: candidate 53, document 70, terrain 102, composition 63, population 91, patrol 58, generation 89, exchange 113. Total: 669 checks de estágio, além do import.
- `manifest.json` autoral registra engine SHA acima e 1.848 inputs. Todos os 1.848 SHA256 foram comparados aos arquivos do checkout e coincidem. O manifesto, gerado antes da correção, registra `head_before/head_after=5854b5e7f055d15cafa779af4ddf3e1eede42407`; o HEAD congelado desta rodada é `ce7bd5906accf71fffb60cc17c8c2f7ebffc2dd8`. Conforme despacho, não repeti Core: registro a rodada como evidência autoral Sol conferida por Luna pelos inputs, engine e resultados, observando a diferença histórica de HEAD.

## Execução Luna

1. `tools/map_editor_completion/run.ps1 -GodotPath <engine> -EvidenceDirectory <...>/geometry/authorities_final`, execução elevada prevista para acesso ao certificado Windows: importação passou e os 46 checks F9 passaram (`count: 46`, `ok: true`). `runs.json` preserva conclusão e hashes.
2. Listagem `tools/verify.ps1 -List -FromStep 273 -ToStep 297` confirmou os 25 IDs 273–297 previstos. Em seguida, `tools/verify.ps1 -GodotPath <engine> -F1Fixture -FromStep 273 -ToStep 297 -VerificationDirectory <...>/geometry/official_final -CheckTimeoutSeconds 300`, execução elevada: 25/25 etapas selecionadas passaram, sem timeout/aborto/falha. `checks.jsonl` contém 25 registros de etapa e um resumo final. `plan.json` registra seleção 25/299. O console confirma zero falhas em cada grupo.

## Integridade dos logs

- SHA256 `authorities_final/runs.json`: `CB7292958C28389BABDC727768650260C7F46B2AB61D489CABAA961A1601CAF0`.
- SHA256 `official_final/checks.jsonl`: `748328213C74CB2AC479BF35910C960BCCC29145D407137E54D66FFA7D3D91DD`.
- SHA256 `official_final/plan.json`: `608C14150187AB34492E74D87B1BC00C0A42F21B75C65A9F410F7AF9D909C668`.
- Os logs individuais de engine e saída para os índices 273–297 estão preservados em `official_final/`; logs de import e autoridade estão em `authorities_final/`. Nenhuma ocorrência de `SCRIPT ERROR`, `Parse Error` ou `ERROR:` foi encontrada nos logs. O checksum da engine foi confirmado durante a rodada.

## Cobertura e limites

Cobertura Luna nesta etapa: importação + 46 checks de autoridades F9 + seleção oficial F1 de 25/299 etapas (geometria, atores, inventário, adversos, consumidores, canais, casts/áreas, ecos/classes, guard/travel, Sentinel/Hunter, coleta, campos, geômetra, composição, cena piloto e apresentação). Os 274 passos não selecionados da suíte oficial não foram executados. Core não foi repetido por decisão expressa do despacho; sua evidência é autoral conferida por hashes, não uma reprodução independente. A supervisão verifica execução/saídas/integridade e não constitui auditoria semântica independente nem inspeção visual D05.
