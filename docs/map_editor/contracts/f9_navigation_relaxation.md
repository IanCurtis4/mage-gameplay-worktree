# F9 — próximo ensaio da consulta individual

29/10/2026, análise Sol, ainda sem implementação/execução. Base de produção
9c8185c6, checkpoint documentald03b6d93, mesma branch/checkout/fixture. F9-04/10
continua aberto. Terra ocupa a fixture para autoria AX; não editar inputs/HEAD
nem executar engine até todos os seus jobs terminarem e a fixture ser liberada.

O lote resolveu a geração real em157,130s, mas não altera a busca individual
de menor custo, ainda sem retorno no baseline até santuário aos120s. Essa consulta
pode ocorrer durante o jogo, portanto continua prioridade de produto. Não
extrapolar o sucesso da prévia como solução de FPS/pausas do jogador.

## Hipótese delimitada

`WorldGeometry._path` avalia sweep e suporte de toda aresta local antes de saber
se sua relaxação poderia melhorar a distância. O custo dessa aresta já é
exatamente `Vector3(a).distance_to(b)`, independente do predicado geométrico.
Antes dos predicados, calcular a MESMA soma `float(distances[current])+cost` e
aplicar a MESMA rejeição `route_cost+EPS >= distances.get(other,INF)`.
Se já rejeitada, omitir apenas o trabalho geométrico da aresta não relaxável.
Não eliminar estados, candidatos, portais ou materialização de superfícies.

A construção local precede a relaxação das arestas de portal. Distâncias dos
outros estados só podem diminuir durante essas relaxações; uma aresta incapaz
de melhorar antes continua incapaz depois. Arestas potencialmente úteis mantêm
ordem original, mesma geometria, custo, heap, EPS e segunda checagem de relaxação.
Não é A*, mudança de prioridade, topologia ou aproximação. Não inferir
simetria geométrica. Reutilizar o custo calculado, sem arredondamento novo.
Manter o produtor eager sem a otimização como referência diferencial.

## Provas exigidas antes de integrar

Dono runtime Sol, somente world_geometry.gd se a hipótese se confirmar. Luna
pode estender testes delimitados após registrar arquivos e API efetiva. Comparar
lazy/eager com pontos, conexões, custo/erro/desempate exatos; EPS abaixo/em/acima,
zero, igualdades, arestas dirigidas, candidato especulativo, obstáculos/segmentos,
stale, perfil, superfície sobreposta e negativos. Verificar contadores de arestas
consideradas versus avaliadas/rejeitadas por distância; nunca chamar uma aresta
omitida de geometria aprovada. Preservar efeitos de saturação/memo/contexto.

Repetir ponto entrada→santuário e retorno do Bosque exatos, corpo20x32, mais
amostra densa original e pequenas; medir construção, clear/support e total, frio/
quente, sem reduzir fonte/escala/corpo ou aumentar guards/caps. Selecionar verify
e regressões de navegação por impacto. A medição deve decidir suficiência; se
ainda lenta, continuar análise conforme contrato anterior, sem declarar F9-10
resolvido. Compilação final/AX e gameplay real continuam provas separadas.
