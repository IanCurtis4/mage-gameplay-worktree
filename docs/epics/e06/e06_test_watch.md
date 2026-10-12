# Recibo de supervisão automatizada E06

Luna supervisionou uma cobertura consolidada de **193 etapas de nomes distintos**, composta por reuso compatível, regressões dirigidas e duas caudas. Foram conferidos **202 registros de saída** contra os arquivos reais (90 da primeira execução, 2 focados, 20 da primeira cauda, 7 regressões do snapshot e 83 da cauda final); verificações repetidas não aumentam a contagem de etapas. A suíte integral não foi repetida.

O candidato final foi `2803f1165ee8883e462bfa8909e6707bb30e004d` (árvore `b5582130407daea85c37a248ee75bf74efe60271`), branch `codex/e06-inventory`. A validação usou Godot 4.7.2 standard, SHA-256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`, e `tools/verify.ps1`, SHA-256 `0A8143EF881AD75502E6D3DA778ADAE8CA14426B92A477018657402AF23BDAFD`, com timeout de 120 segundos por etapa.

## Cobertura composta

- **Etapas 1–89:** PASS reusado da execução limpa em `e7257563e70f0cb00c931d0067b7c7a89d76354c`. Os 90 registros do prefixo antigo (incluindo a etapa 90 que falhou) foram auditados; todos os outputs e engine logs existem e cada hash de saída confere com seu arquivo. Sol confirmou compatibilidade executável do prefixo: runner, runtime, recursos e cenas sem diferenças relevantes para esse reuso.
- **Etapa 90:** PASS na execução focada em `d2b64e0f3a445be109576238668f39beed335764`: `e04_learn_from_zero_migration_test` passou 20 checks. O teste focado `e06_tx_migration_test` passou 25 checks.
- **Etapas 91–109:** PASS na primeira cauda em `d2b64e0f3a445be109576238668f39beed335764`.
- **Etapa 110:** PASS na seleção de regressão em `2803f1165ee8883e462bfa8909e6707bb30e004d`: legibilidade do Espiritualista (39 checks) e teste TX2 active (58 checks). Os outros cinco consumidores dirigidos também passaram: effects runtime (53), fechamento integrado do Mago (103), integração E02 (9), UI de batalha (47) e fluxo da arena (33).
- **Etapas 111–193:** PASS na cauda em `2803f1165ee8883e462bfa8909e6707bb30e004d`, 83/83, sem timeout ou erro registrado.

O único delta de runtime desde a base original `e725756` é a guarda de snapshot nulo em `RunState.available_active_ids`: consultas sem `build_snapshot` retornam uma coleção tipada vazia, e a restauração mantém a biblioteca e a ordem esperadas. Os consumidores dirigidos acima verificaram o caminho ausente e o caminho normal. A correção do teste da etapa 90 alterou apenas a fixture histórica para representar o schema/catalog legado; seus oráculos de grants, carteira, identidade, contadores, XP, backup e respec foram preservados.

## Falhas preservadas e resolvidas

A primeira execução integrada começou na base `e7257563e70f0cb00c931d0067b7c7a89d76354c`, mas parou na etapa 90. O teste emitiu um `SCRIPT ERROR` por acesso inválido à chave `profile` de uma `Dictionary`, embora também imprimisse uma linha PASS e terminasse com exit code 0. O runner marcou corretamente `failed=true`; o exit code persistido da execução foi 1. Depois da correção da fixture, a etapa 90 passou na execução focada.

A primeira retomada passou 91–109 e parou na etapa 110. A saída da legibilidade continha três `SCRIPT ERROR` chamando `learned_skill_ids` quando o snapshot ainda estava nulo, apesar da linha PASS e exit code 0. Após a guarda de runtime, a etapa 110 passou na regressão dirigida; a cauda final começou em 111 e passou até 193. As evidências antigas com falha foram preservadas e não contam como PASS.

## Artefatos e limites

O recibo estruturado em [e06_test_watch_validation.json](e06_test_watch_validation.json) registra commits-base, planos, hashes dos manifests, fingerprints de saída e engine log por etapa, falhas históricas e método de conferência. Os detalhes brutos permanecem nos diretórios `.godot/verification/e06_rx/round2/integrated/` e `.godot/verification/e06_test_watch/`; não são adicionados ao Git.

Este recibo registra supervisão automatizada e reuso por impacto; não é auditoria semântica independente nem aprovação Astra. Não houve inspeção visual, playtest humano, aceite de produto, preparação de playtest, push ou merge. Esses resultados não afirmam balanceamento, desempenho ou diversão.
