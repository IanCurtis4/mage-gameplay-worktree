# F9 — preparação canônica de população em lote

29/10/2026, Sol; base d03b6d93872f969b0f6d87c70920916652acd1f5, mesma branch/
checkout/fixture. Donos nominais no f9_ownership.json. Continuação F9-08/10/11,
sem novo épico ou escolha de produto. Terra salvou a população real via AX,
SHA2563debc7674a1770702639e8bb33b1e6598c52929e9230395ccfbf505c1ed04889,
mas compile_01 atingiu timeout300/watchdog360,557s; não há pacote aprovado.

Sonda compilação01 confirmou todos os slots e pools do editor concluídos aos
159,533s. Entrou no ExpeditionPopulationPlanner.build aos159,557s e não saiu
até guard300. Leitura anterior incompleta dizia que Planner usava só position_query;
o código também chama geometry.path(entry,home) para cada slot. Essa função é
usada na preparação do jogo, portanto a correção deve ocorrer na autoridade
canônica, sem pular Planner no editor ou confiar em um marcador de aprovação.

Agrupar admissões por estágio e perfil INTEIRO exato, após validação existente
de identidade/regras/políticas/origem/espécie/testemunha/corpo. `connectivity_batch`
recebe os mesmos pontos exatos e entrada canônica. Conferir outward_reachable de
cada terminal; não exigir retorno que Planner não exigia. Perfil maior ou outra
lista de connectors não recebe certificado do grupo anterior. Mundo de cada
estágio continua sendo WorldGeometry. Não alterar path individual, custo, leash,
ataque, fórmulas, catálogo, quotas, mapa ou corpo.

API build mantém3argumentos existentes e acrescenta cancellation opcional.
Cancelar durante grupos/busca impede sucesso parcial; dados continuam locais.
Negativo geométrico/invalid_support conserva population_unreachable. Budget,
stale e cancel são erros operacionais distintos com diagnóstico. Compilador de
população deve propagar esses erros e seu cancelamento ao Planner. Métricas
derivadas podem ser retornadas fora do manifesto/save, sem mudar hash do pacote.
Limites canônicos e guards existentes não aumentam.

Luna testa admissões dirigidas, só ida válida, desconexão, corpo/perfil, grupos
independentes, repetição sem mutação, testemunha obrigatória, regras/políticas e
cancelamento, além de regressões reais F5/campanha/Population/Patrol/Exchange e
verify selecionado. Sol consolida. Medir de novo a fonte real inteira, depois
Terra repete compile por AX e continua patrulha se PASS. Guard editor180s e
performance individual continuam obrigações de F9, não resolvidas por inferência.

Leitura dos consumidores confirmou ainda `gameplay_candidate.gd._both` chamando
path individual para objetivos e slots durante preparação. Esse consumidor
continua pendente por existência, além da consulta real de movimento. Não
confundir Planner corrigido com pipeline de gameplay completo. EnemyPatrol
valida custo/leash: essa regra não pode trocar menor custo por testemunha BFS.
