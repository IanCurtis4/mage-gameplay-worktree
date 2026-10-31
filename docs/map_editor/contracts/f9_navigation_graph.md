# F9 — grafo de navegação reutilizável (contrato, Astra)

31/10/2026. Sol/Astra (Claude Opus). Base 11c67b2a. Dono runtime: Sol,
somente `scripts/core/expedition/spatial/world_geometry.gd`. Sem mudança de
corpo, cap, guard, quota, fonte ou escala.

## Problema

No Bosque, a primeira passagem pelo cruzamento dos mapas trava alguns segundos e
não se repete. Cada `WorldGeometry.path` montava um memo privado dos predicados
exatos (`point`, `clear`, `fraction`) e o descartava ao fim da consulta. Toda
consulta seguinte (jogador, inimigos indo ao jogador ou voltando para casa)
refazia os mesmos sweeps e suportes entre os mesmos cantos de massa e portais.
A busca era Dijkstra puro: expandia todos os estados com custo menor que o da
rota, inclusive os que ficavam para trás do destino. O caminho longo
casa→entrada levava 55–87 s frio.

## Mudança 1: memo compartilhado entre consultas

- Mesmas chaves e valores do memo por consulta: família, superfície e o par
  exato `Vector3 a,b`. Os valores são predicados geométricos exatos e não
  dependem de origem/destino; ids de estado (que dependem da consulta) não
  entram na chave.
- Um memo por geometria efetiva e perfil:
  `[configuration_revision, geometry_revision, _navigation_epoch, digest(perfil)]`.
  Trocar qualquer elemento descarta o memo inteiro.
- `_navigation_epoch` avança em toda mutação da geometria: `configure`,
  `insert_segment`, `insert_obstacle` (logo após `_temporary[id]=volume`, e de
  novo se a inserção for recusada) e `remove_obstacle`. As rotas de proteção de
  `insert_obstacle` rodam na MESMA revisão com o volume novo; o epoch garante
  que elas não leiam a visibilidade de antes.
- Ocupação não entra: os sweeps de navegação já a ignoravam.
- Consulta especulativa (`candidate != null`, usada por `can_insert_segment`)
  nunca lê nem grava o memo compartilhado; continua com o memo privado e a
  liberação por superfície.
- O memo compartilhado não libera superfícies concluídas (a próxima consulta
  vai reusá-las). Limite próprio de 262 144 entradas; cheio, só deixa de gravar.
  O limite do memo privado (32 768) não muda.

## Mudança 2: A* com a distância reta ao destino

- Prioridade `g + |p − destino|` (3D). `g`, o teste de entrada obsoleta do heap
  e a regra de relaxação com EPS continuam iguais.
- Consistência: aresta local custa a corda exata `|a − b|`; aresta de portal
  custa `|ia − seam| + |seam − ib| ≥ |ia − ib|`. Pela desigualdade triangular,
  `h(u) ≤ c(u,v) + h(v)` em toda aresta, então a primeira expansão de `@to` é
  ótima e o custo é o do Dijkstra.
- Guarda: todo grafo materializado (eager inteiro, ou cada fatia lazy) é
  conferido; se alguma aresta custar menos que a corda (só grafos sintéticos,
  como os heaps do teste NavigationLazy), a consulta inteira é refeita na ordem
  Dijkstra original (`trace.heuristic_fallback`).
- `_path(..., heuristic=false)` mantém a ordem original como referência
  diferencial.
- Ressalva de desempate: com rotas de custo igual (dentro de EPS), A* e Dijkstra
  podem escolher rotas diferentes de mesmo custo. Os testes comparam resultado,
  erro e custo (tolerância 0,001), e exigem que a rota A* seja andável pelo corpo
  canônico. Lazy contra eager continua com igualdade exata, já que os dois usam a
  mesma ordem.

## Mudança 3: corte exato antes dos predicados

É a hipótese de contracts/f9_navigation_relaxation.md. Antes do sweep e do
suporte de uma aresta local, calcula-se a mesma soma `g(atual) + corda` e aplica-se
a mesma rejeição `custo + EPS >= distância(outro)`. Como as distâncias só
diminuem durante a expansão (as arestas de portal relaxam antes das locais), uma
aresta rejeitada agora também seria rejeitada depois. Só o trabalho geométrico é
omitido (`trace.edge_skipped`); estados, candidatos, ordem, custo e heap ficam
iguais, e lazy × eager continua com igualdade exata.

## Snapshot

`_navigation_epoch` e `_navigation_shared` entram em `omitted` de
runtime_manifest.json, como `_support_index`: são derivados, voltam vazios após
a restauração e se refazem nas consultas. A lista explícita do registro recusava
a captura (`checkpoint_incomplete`) sem essa declaração.

## Provas

- `tests/map_editor_navigation_astar_test.gd` (estágio NavigationAstar):
  - diferencial A* × Dijkstra no fixture de portas (quatro raios, ida/volta,
    mão única) e no relevo orgânico com massas;
  - A* nunca expande mais estados, e expande menos em desvios reais;
  - fallback em grafo sintético inconsistente;
  - segunda consulta igual: só acertos no memo, resultado idêntico ao de um
    mundo novo;
  - outra consulta e outro perfil iguais a um mundo novo;
  - invalidação por obstáculo (inserir/remover), segmento e reconfiguração;
  - consulta especulativa sem tocar no memo compartilhado;
  - proteção de `insert_obstacle` com memo quente recusa a parede que
    desconecta.
- Regressões: NavigationLazy/Dense/Context, CandidateBatch, PopulationPlanner/
  Reachability, SurfacePick, gameplay.
- Bosque real: caminho longo casa→entrada frio/quente, e a travessia da emenda
  (walk probe).

## Resultado (31/10, fixture compartilhada, Godot 4.7.2 debug)

Bosque real (dump do mundo, corpo 20×32, perfil `ruins_player`):

| Consulta | Antes | Depois |
|---|---|---|
| casa→entrada, fria | 57,9 s (Dijkstra, 3220 expansões, 53 superfícies) | 1,18 s (A*, 21 expansões, 5 superfícies) |
| casa→entrada, repetida | igual à fria | 0,10 s (só acertos no memo, rota idêntica) |
| entrada→casa, depois da ida | igual à fria | 0,83 s |
| emenda clareira→viaduto, fria | 1,08 s (Dijkstra) | 0,73 s |
| emenda, repetida / outra origem | igual à fria | 0,08 s / 0,12 s |

Só o corte exato da mudança 3, ainda em Dijkstra, já leva o caminho longo de
57,9 s para 8,1 s. Custo idêntico em todas as comparações (Δ = 0).

Na emenda fria, 0,50 s dos 0,73 s são a materialização das duas superfícies
(estados de portal, cantos de volume e de massa). Depois do primeiro uso da
superfície, o memo derruba esse custo para ~0,05 s. Uma etapa futura pode
aquecer essas superfícies em segundo plano, em fatias por quadro.

Fixtures sintéticas: A* expande de 2× a 12× menos estados (port r0,25: 20
contra 240; orgânico 10→30: 134 contra 1515).
