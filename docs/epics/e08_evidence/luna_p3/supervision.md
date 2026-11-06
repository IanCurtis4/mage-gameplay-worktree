# Supervisão Luna — E08 P3 final

Resultado: **PASS na integridade da evidência e execução registrada**. Isto não é aceite de produto, auditoria semântica independente ou avaliação artística/auditiva.

- Candidato `3ea5e9086da11c51d81d5a85b8f29d464b04c3d8`, base `22f5788882622d733ab822c4caa08692ceb7226d`, branch `codex/e08`; HEAD observado `1c2e94d547d5af82ffdc3eede36d64fa44175406` é posterior e documental.
- A evidência FINAL conferida é `forest_variants_evidence.zip`, SHA256 `953f37a5697841727457fb2a8f4704feaba9dabab8cdcf5ae755f6abbd169941`, com **35 membros** lidos sem extração. Os checksums dos outputs nos checks.jsonl batem com os bytes arquivados. `forest_variants_inputs.json` contém 19 caminhos de input e 9 capturas; os 9 hashes de captura conferem. Não usei `inputs.json` ou `raw_logs.zip` do WIP anterior como prova desta rodada.
- Os 19 inputs externos conferem byte a byte com a versão atual do checkout. A versão do código no candidato é equivalente após normalização de CRLF/LF. **Exceção de escopo documental:** `assets/art/e08_pilot/recipes.md` mudou após os testes para acrescentar os prompts literais do lobo extra e do javali extra. A versão testada e o manifesto testado estão em `fixture/recipes_tested.md` e `fixture/source_hashes_tested.json` dentro do ZIP. Comparei as versões: só esse caminho difere entre o manifesto testado e o manifesto atualizado; 18 dos 19 inputs coincidem com o manifesto testado. Não tratei a receita atual como bytes executados nem repeti gameplay por essa alteração documental.
- O manifesto atualizado da fixture tem **2.316** fontes; todos os hashes conferem individualmente em origem e fixture. Hash do manifesto `236060a2447ead32b724c8521b4b3bf76b1381a1a271f7893ae1fb80deb3ce1c`; `project.godot` confere com `33726afe86093a0d6f580114f803045e4f6624dc94528ecbebd61fb199a06517`. Engine Godot standard 4.7.2 `ed1daf0bf`, SHA256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`. Hash do runner em `plan.json` confere com `tools/verify.ps1`: `8c0dbf006d3d6366639c80885de0b8cf2271591507385ee3cf59c9ee5e0f5d6e`.
- Os **4/4** backups locais conferem com seus hashes preservados. Não foram editados.

## Execução final

Os **14/14** checks de `verify/checks.jsonl` têm nomes, índices, outputs e hashes coerentes; exit 0, `failed=false`, sem timeout e sem marcadores `SCRIPT ERROR`, `Parse Error` ou `ERROR:` nos outputs. Resultados: animação 39; apresentação 2.204 (mantém os 2.122 anteriores); UI piloto 55; áudio 132; piloto 125; layout 30; Mago 52; teleporte 29; F7 27; snapshot F3 52; continuation F3 2.743; matriz de ações F3 2.004; lifecycle F3 90; apresentação F1 39.

`native/process.json` registra exit 0, sem timeout; o hash do log coincide com o processo e `native.log` conclui **126 checks, zero falhas**. Os erros e falhas de desenvolvimento antigos permanecem nos arquivos históricos, fora desta seleção final; não foram reclassificados como sucesso nem misturados com a evidência final.

## Assets, proveniência e capturas

- Os dois atlas compilados conferem com os hashes em `assets/art/e08_pilot/provenance.json`; ambos medem 256×512 e têm **32/32 células não vazias e distintas** em grade 64×64. As quatro folhas de origem conferem com os hashes de proveniência e com os inputs registrados. Isso valida conteúdo/hash e estrutura dos quadros, não legibilidade ou qualidade artística.
- Os 12 WAVs de `assets/audio/e08` conferem com `assets/audio/e08/provenance.json`, incluindo hash, número de frames e formato PCM16 mono a 44,1 kHz. Não fiz audição subjetiva.
- As nove capturas listadas no manifesto (sete PNGs, `forest.log` e `forest_inputs.json`) conferem com os hashes. Comparei os metadados da floresta de baseline e final: seed, câmera inicial/offsets, posições, zooms, viewport e escala UI são iguais; quatro IDs de ocorrência diferem entre sessões e não foram considerados divergência. Esta comparação verifica condições registradas, sem juízo visual.

P0 já inspecionou atlas e fotos reais. Permanecem fora deste checkpoint comparação F10, exportação/empacotamento, desempenho, release e aceite humano. A supervisão não certifica arte, som ou prontidão do produto.
