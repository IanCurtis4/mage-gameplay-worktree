# Supervisão Luna — F3/M3

24/10/2026. Supervisão de execução congelada no checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m3`, HEAD
`a6d516ef08585a7ca6ba2ba00479cdcbe16e6edf`. A árvore de código estava limpa
antes da execução e permaneceu sem alterações; a única saída no Git é este
relatório e `luna_run/`.

## Execução

Comando executado no host Windows:

```powershell
& 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m3/tools/map_editor_composition/run.ps1' -GodotPath 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe' -EvidenceDirectory '.tools/m3_luna_final' -Native
```

Resultado `M3_ALL_PASS`, exit 0. Godot reportou
`4.7.2.stable.official.ed1daf0bf`; SHA256
`AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`, igual
ao hash esperado. As seis etapas passaram, sem timeout:

| Etapa | Resultado |
|---|---:|
| Importação/editor | PASS, exit 0 |
| Composição | PASS, 63/63 |
| CLI independente A | PASS, exit 0 |
| CLI independente B | PASS, exit 0 |
| Regressão do documento M1 | PASS, 70/70 |
| UI nativa | PASS, 22/22 |

Os hashes dos pacotes de ambos os processos CLI coincidiram entre si e com o
hash produzido pelo teste-fonte. O manifesto registra 148 inputs; cada SHA256
da fonte coincidiu com o correspondente na fixture, incluindo os inputs de
autoridade espacial. Não houve `SCRIPT ERROR`, `Parse Error`, `ERROR:` ou
timeout nos logs de saída examinados. A importação registrou apenas o aviso de
que `tools/map_editor_probe/hosting/project.godot` aninhado seria ignorado.

Os 15 arquivos do primeiro nível da saída temporária foram preservados em
[`luna_run/`](luna_run/): manifesto, resultados, logs e captura nativa. A pasta
`fixture/` não foi copiada.

## Papel e limites

Este registro supervisiona conclusão, códigos de saída, contagens, erros,
timeouts, hashes e correspondência fonte/fixture. Não é auditoria semântica
independente do código, não cobre comportamento além dos casos selecionados e
a captura nativa não substitui inspeção visual/aceite humano. A regressão
oficial `tools/verify.ps1` permanece com Sol, conforme o despacho.

## Registros oficiais de Sol — conferência documental

Complemento de 24/10/2026, sem repetir a suíte. Os registros em
[`official/`](official/) são execuções de Sol, separadas do runner M3 executado
por Luna acima. O manifesto aponta para o mesmo HEAD
`a6d516ef08585a7ca6ba2ba00479cdcbe16e6edf`, Godot com o SHA256 esperado e
1.758 inputs primários. Os quatro IDs selecionados passaram: `e07_f1_import_test`
(índice 239), `editor_import`, `e07_f1_geometry_test` (273) e
`e07_f1_actor_integration_test` (274). Os JSONL também registram as etapas
auxiliares de importação do editor; todas as seis entradas têm exit 0,
`failed=false` e `timed_out=false`.

Os 1.758 caminhos de `source_hashes.json` foram confrontados com os arquivos da
fonte atual: zero ausências ou diferenças de hash. Os hashes de todos os
arquivos de evidência listados no manifesto também conferem. Os logs de saída
não contêm `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. Esta conferência valida
registros, hashes e conclusão declarada; não substitui a validação técnica de
Sol nem amplia o escopo dos quatro IDs.

## Recuperação de rascunho — candidato corrigido

24/10/2026. Repeti o runner F3/M3 com `-Native` no candidato congelado
`5c25f837c939e459757829b052a49e036174bd1d`, usando Godot 4.7.2 com o mesmo
SHA256 esperado. Resultado `M3_ALL_PASS`, exit 0, sem timeout ou marcadores de
erro: importação passou, composição 63/63, CLI A e B passaram com hashes iguais
ao teste-fonte, regressão documental M1 70/70 e UI nativa 24/24. Os 148 inputs
do manifesto coincidiram com a fixture. As novas contraprovas aparecem como
PASS no marcador nativo: `switch_map_preserves_prior_draft` e
`recover_current_draft`. Preservei os 15 arquivos de primeiro nível em
[`luna_run/recovery/`](luna_run/recovery/); a execução anterior continua
preservada no nível anterior da pasta.

Também conferi documentalmente os registros oficiais atualizados de Sol, sem
reexecutá-los. O manifesto oficial aponta para o mesmo HEAD e todos os 19 hashes
de evidência listados conferem. O bootstrap `e07_f1_import_test` tem exit 0,
`failed=false`, `timed_out=false` e nenhum marcador de erro; a saída registra
1.758 arquivos byte-idênticos. `source_hashes_recovery.json` contém 1.758
entradas, todas correspondentes à fonte atual. O comparativo oficial registra
somente os três arquivos autorizados do delta: `map_panel.gd`, o teste UI e o
runner; as autoridades espaciais e testes de geometria/atores permanecem iguais.
Por isso os testes de geometria e integração de atores são reaproveitados do
SHA anterior (33 e 193 verificações, respectivamente), enquanto a importação
oficial e o runner M3 nativo foram executados no SHA corrigido. Esta conferência
de registros não substitui a revisão de compatibilidade/reimportação que Sol
reservou para si.
