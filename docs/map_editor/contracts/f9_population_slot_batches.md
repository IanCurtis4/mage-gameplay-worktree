# F9 — próxima margem de preparação do editor

29/10/2026, análise Sol apenas, base0bef9d5377a37e338085df5a063b4b9c70f55564.
Mesmo F9 autorizado. Terra ocupa fixture para compile/patrulha AX; não alterar
inputs/HEAD ou executar engine até todos os jobs terminarem e liberar fixture.

Core Planner foi corrigido e compilação real02 terminou183,971s, pacote
543a125634b45cfa426b3340adee22349bb401586d6a18bc95c3f8b0e1cd0854. Esse tempo
inclui startup e não prova worker editor180s. Antes do Planner, editor terminou
169,356s; ainda há quatro buscas de conectividade parecidas para slots distantes,
além das checagens de pools. Não aumentar180/300/360 ou reduzir mapa/corpo/quotas.

Próximo ensaio permitido: agrupar validação dos slots do editor por perfil inteiro
no mesmo contexto/world. Preservar a ordem original dos checks locais de espécie,
origem, regra, brush/região, exclusões, proteção de caminhos, ponto/corpo, reservas
e espaçamento. Acumular reservas em cópia local; nunca mutar occupied recebido ou
fonte antes da aprovação. Só depois provar ida E retorno em lote por perfil, com
os mesmos pontos exatos e WorldGeometry.connectivity_batch, sem cache global.

Refatorar validate_slot em validação local e lote interno para lista de slots.
API validate_slot existente conserva retorno/semântica, delegando lista unitária;
compile pode usar lista completa, regenerate lista de pins. Sem flag público
"pré-validado" ou bypass, nenhum reuso por superfície/epoch. Falha de um grupo
impede retorno parcial. Cancel/stale/budget propagados, negativo mantém entidade
diagnosticada. Array de registros continua associado aos índices originais.

A união pode acrescentar positivos físicos com testemunhas como no contrato
canônico; não pode perder sucessos individuais. Nenhum custo BFS vira leash,
movimento, dano ou ataque. Rule/manifest/save/pacote não recebem métricas ou
certificados. Provar que fonte real e hash do pacote continuam exatamente iguais.

Antes de integrar: propriedade nominal runtime/testes, testes de body/direção,
espaçamento/pins/fora de região/política, sem mutação, cancel/stale/budget e
regressões Population/Context/Patrol/Exchange. Repetir fonte integral, medir
compilação fria/quente e caminho REAL do worker editor180; um ensaio abaixo do
limite não certifica toda escala ou FPS. Se insuficiente, continuar F9-10 com
diagnóstico. GameplayCandidate._both e path individual continuam separados.
