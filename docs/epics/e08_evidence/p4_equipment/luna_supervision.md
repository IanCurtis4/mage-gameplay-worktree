# Supervisão Luna — integração Gear P4

Data: 2026-11-08. **Integridade conferida** para o candidato Gear/Mago no commit `94dfaf7f97e8faa094d9f9ad7612baf7729d801c`, branch `codex/e08`. Procedimento: somente leitura de recibos, arquivos, logs e ZIP existente; nenhum teste foi reexecutado.

## Freeze e integridade

- `evidence.zip`: 522 membros únicos, 37.891.701 bytes, SHA-256 `6421f67fd2461ca1771d011a1aba422f776e6fd6803f47933c1c3f3f0b1b5d85`. Os hashes dos 522 membros conferem.
- Manifesto origem/fixture: 2.468 inputs, SHA-256 `30978d236f9383d02f802cb08278785a4ea9270bc5e874d99ab1dd07d17893b5`. Todos os caminhos/hash conferem no checkout. A conformidade registra 28 metadados gerados, arte Gear/Mago read-only e backups preservados; única diferença da fixture é `version_control/autoload_on_startup=false` em `project.godot`.
- Arquivos rastreados pela posse: 83 hashes do candidato e 52 hashes de arte read-only conferem. Os quatro backups listados no manifesto existem e conferem.
- Engine Godot 4.7.2 standard SHA-256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424` confere diretamente com o executável local. O commit contém 97 caminhos.

## Validação registrada

- Seleção: 24 etapas únicas de 318, 31.283 checks, 0 falhas, 0 erros de execução e 0 timeouts. Composição: 22 testes compatíveis da regression_final1 e 2 consumidores da regression_pose_final1, que substituem as verificações anteriores apenas para os quatro ângulos de cadáver corrigidos. Repetições não foram somadas. O resumo congelado registra exit code 0, `failed=false` e `timed_out=false` para cada um dos 24 resultados.
- Renderer nativo final2: 5.568 checks, 0 falhas e 35 PNGs; execução registrada com exit 0 e sem timeout.
- Movimento final2: 76 checks, 64 PNGs, 0 falhas; GIF de prévia 6,4 s; execução registrada com exit 0 e sem timeout.
- Export final2: PCK de 101.077.828 bytes, SHA-256 `14c9be3e24924c09fe0fa012c1978fb0f906eb216d7c7627f03816776b3e3eb1`. Os quatro testes no PCK passaram: equipamentos 2.589, unidades 10.887, conteúdo 3.461 e animação direcional 814 checks. Export e os quatro consumidores registram exit 0, `failed=false` e sem timeout. Warnings do export sobre projeto aninhado/GDExtension ausente e os warnings dos casos de fallback ausente/inválido são esperados e documentados; não há falha de teste.
- PCK final1 preservado e conferido: 101.077.652 bytes, SHA-256 `7e9b380ebdbdb3ef69ff39c3f54f9dd55ce4237dda6343eae2143e34b8444084`. Os dois PCKs permanecem no local para Root; não removi nada.

## Tentativas anteriores e limites

O ZIP conserva as tentativas anteriores com seus registros: `import_initial1` omitiu scripts novos na lista do wrapper; `unit_initial2` teve 42 falhas por montar catálogo mínimo em vez do catálogo de conteúdo com 14 definições; `native_initial3` e `native_fit1` documentam o ajuste de encaixe. Essas tentativas não foram reclassificadas como PASS nem somadas à seleção final.

Esta supervisão confirma hashes e coerência dos recibos e logs congelados. Não é auditoria visual independente nem aceite humano ou de produto; não conclui P4, não autoriza limpeza dos PCKs e não reexecuta gameplay.
