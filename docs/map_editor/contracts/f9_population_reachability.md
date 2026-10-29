# F9 — alcance canônico na população

29/10/2026, Sol. Base `bc52103eee28072d70243b42a002056bc0bf90fa`, branch
`codex/map-editor-f9`, checkout `.tools/map-editor-m5`. Mesmo F9 autorizado.
Propriedade nominal em [f9_ownership.json](f9_ownership.json).

O rascunho real salvo por Terra via AX não chegou à prévia: timeout AX300s e
watchdog360s. Instrumentação de cópia exata localizou a primeira busca individual
entrada→santuário, ainda sem terminar aos120s (mapa28,313s; início da busca38,372s).
A primeira sonda leu JSON sem StrictJSON e falhou antes do mapa; é diagnóstico
inválido para performance, preservado como tal. A segunda usa PopulationStore.

PopulationCompiler só precisa provar existência de ida/retorno para interações
e colocações. Usa `WorldGeometry.connectivity_batch` já contratado em
[f9_navigation_batch.md](f9_navigation_batch.md), sem alterar `WorldGeometry.path`,
custos, desempate, leash ou ataque. Perfil/corpo, mapa, pontos, quotas e limites
existentes permanecem. Não inferir alcance de todos os pontos de um suporte.

Interações são verificadas juntas. Pool coleta na ordem original os pontos
exatos do grid16 e das células, aplica exclusões e position_query canônica e
consulta o lote antes da seleção determinística. Conserva primeira célula legal
por amostra, política, densidade, pins, espaçamento, grupo e diff revisável.
Pontos inválidos não entram no lote. Cancelamento, stale, budget e falha de
consulta são erros operacionais propagados; nunca viram déficit/inacessibilidade
nem resultado parcial. Reservas temáticas também propagam tais erros.

O grafo unido pode demonstrar novos positivos com testemunhas geométricas.
Por isso a revisão do compilador passa a `map_population_v2`; fonte JSON e
recipe_hash mantêm formato. Pacotes/bundles v1 são recusados sem reescrever o
arquivo, e devem ser recompilados da fonte. O intercâmbio informa v2.

Luna cria testes dirigidos em arquivo exclusivo: ida/retorno dirigido,
desconexão/corpo, determinismo e equivalência com sucessos individuais pequenos,
cancelamento/budget distintos de negativo, reserva e ausência de mutação.
Sol integra, importa na fixture única, confere UIDs gerados e regressões
Population/Patrol/Context/Exchange mais verify selecionado. Terra só retoma AX
após liberação do produtor; mesma fonte real completa deve concluir ou gerar
diagnóstico honesto. Nenhum teste isolado certifica FPS ou fecha F9.
