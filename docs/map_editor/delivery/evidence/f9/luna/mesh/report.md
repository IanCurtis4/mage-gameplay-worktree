# Supervisão Luna — suporte contínuo de malha

## Identificação e integridade

- Checkout: `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- HEAD antes e depois de todos os runners: `50ba51ac03960e4eba3cc92729fd557c80290e5d`.
- Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única `.godot/verification/e07_f1/fixture_project`, executada sequencialmente. Fixture liberada depois da comparação de inputs; Sol foi avisado.

## Evidência autoral anterior

Os recibos `mesh_core_01`, `mesh_objects_01` e `mesh_geometry_02` declaram HEAD de execução `18fa57fc1cb21c47e88e6cf2d54d41ae2fd87e37`, não o SHA congelado desta rodada. Os resultados autorais foram concluídos com exit 0, sem timeout/aborto e `ok: true`: Core 53/70/102/63/91/58/89/113 (639 checks), Objects 53 checks e Geometry 46 checks. Conferi os SHA256 de todos os inputs contra o checkout atual: nos três manifests, as únicas divergências são as mesmas três entradas abaixo. Assim, a evidência é compatível como resultado autoral anterior à guarda final, mas não atribuo essas execuções ao SHA atual nem trato-as como reprodução independente.

| Input divergente desde os recibos em 18fa57f | SHA no recibo | SHA no checkout congelado |
| --- | --- | --- |
| `scripts/core/expedition/spatial/world_support_patch.gd` | `D540AD3D95740988D53743DE7815C1C6518404AAACA5976A6287B2F79DD04A80` | `56D67B1C8960DD242DEC315B9622951B12EFFCE8D8CBB51433C1878950F205ED` |
| `tests/map_editor_mesh_test.gd` | `AF493FAB7B9FFD4BBD0288738EDDCBE7656804827A082EE5F4186225341544A8` | `96657526EBDD4C343976D8AA4CFF4CF468730DF865D7B9AE4510CE1D3AB0FA0F` |
| `tools/map_editor_completion/run.ps1` | `5044B2A1F6492B3151C6D0D5942CCC8AA36E2D92A8FE939CE13AF024D8B70F73` | `36A945869AEED10DD47DE81BBFD8CBF8C596D76F3B5E02DE3B84F437EC158532` |

O checkout permaneceu no SHA congelado. A comparação contra os três recibos mostrou 1.874 inputs em `mesh_core_01` e 1.877 em cada etapa isolada; não foram vistas outras divergências.

## Execuções Luna

1. `tools/map_editor_completion/run.ps1 -GodotPath <engine> -EvidenceDirectory <...>/luna/mesh/authorities -Stage Mesh` (importação padrão): import passou; 23/23 checks Mesh passaram. Inclui malha curva, seis triângulos encontrando-se no mesmo vértice, ator atravessando o vértice, rejeições de suporte parcial/descontínuo e snapshot sem índice derivado. Manifesto: exit 0, `ok: true`, sem timeout/aborto, HEAD antes/depois igual ao congelado.
2. `tools/map_editor_completion/run.ps1 -GodotPath <engine> -EvidenceDirectory <...>/luna/mesh/geometry -Stage Geometry`: import passou; 46/46 checks de geometria passaram. Manifesto: exit 0, `ok: true`, sem timeout/aborto, HEAD antes/depois igual ao congelado.
3. A listagem confirmou 27 checks oficiais: E07 F3 snapshot, E07 F6 snapshot e os 25 F1 solicitados. `tools/verify.ps1` com `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300` concluiu os 27 sem falhas ou timeouts: F6 snapshot 40, F3 snapshot 50; F1 geometria 33, atores 193, inventário 371, adversarial 29, consumidores 133, canais 32, casts 113, casts de área 59, ecos 271, chains 121, ember 102, guard/travel 293, Sentinel direto 364, Hunter traps 631, Hunter cover 235, Sentinel áreas 433, birth/collection 210, fields 499, Ice Wall 262, Geometer trace 400, Geometer full 1160, não planar 311, composição 299, cena piloto 102 e apresentação 37. `checks.jsonl` tem 27 registros de etapa mais o resumo de execução; `plan.json` fixa os argumentos e hash do runner.

## Logs e hashes

Logs de saída, logs Godot, `runs.json`, `plan.json` e `checks.jsonl` estão preservados nos diretórios `authorities/`, `geometry/` e `official/`. SHA256 dos principais manifestos Luna:

- `authorities/runs.json`: `C0806FAACBA497F9AC2C497F0E89CAFE235F3D0B1A575E944D6089160C13662F`.
- `geometry/runs.json`: `ACBB4244B4B0610276930E8B5F4D9B7164152001E32DCE7A4819D7C9F9B9680B`.
- `official/plan.json`: `1A4A81CD0D669AA806AA1439D59FF1745059A4DDE3CA4E59FE3695F32F30FD94`.
- `official/checks.jsonl`: `58FC0EE2274FAA44C7F84FAB2B1F6676C0A58E07A1A49304FFB1A0A711496845` (27/27 etapas registradas; 0 falhas, 0 timeouts; resumo final não é registro de etapa).

A engine foi re-hasheada após a execução e corresponde ao SHA indicado. Não há `SCRIPT ERROR`, `Parse Error` ou `ERROR:` nos logs Luna. Não houve falha ou timeout.

## Limites

Esta supervisão cobre o contrato de suporte contínuo de malha, geometria compartilhada, snapshots selecionados e dependências F1 selecionadas. A sequência não cobriu material, cliffs ou biomas, não executou export e não certifica o F9 completo. A evidência autoral de Core/Objects/Geometry é histórica e não pertence ao SHA atual; a conclusão no SHA congelado apoia-se nas etapas Luna listadas. Supervisão de execução e integridade, sem auditoria semântica independente.
