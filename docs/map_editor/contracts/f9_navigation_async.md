# F9 — rotas em segundo plano (contrato, Astra)

31/10/2026. Sol/Astra (Claude Opus). Base e8d6532a. Dono runtime: Sol
(`world_geometry.gd`, `world_actor_motion.gd`, `enemy_actor.gd`,
`player_actor.gd`, `main.gd`, `runtime_manifest.json`). Sem mudança de corpo,
cap, guard, quota, fonte ou escala; o resultado de cada rota é o mesmo de
`WorldGeometry.path`.

## Pedido humano

"1 s de travamento ainda é muita coisa, porque é visível pro jogador. Podemos
fazer o cálculo aos poucos." Calcular só as rotas que os personagens pedem,
nunca todas até todos os alvos.

## Por que uma thread, e não fatias por quadro

Com o checkpoint35, a primeira busca na emenda leva 0,73 s e uma busca quente
ainda leva ~80 ms (refazer os estados da superfície com acertos no memo). Fatias
de poucos milissegundos no quadro principal não chegam a isso sem reescrever a
busca como máquina de estados retomável. A mesma busca, inteira e sem mudança,
roda numa thread do `WorkerThreadPool`; o quadro principal só enfileira e recebe.

## Modelo

- `WorldGeometry.request_path(de, para, perfil, revisão, dono, prioridade)`
  devolve um `WorldGeometry.PathRequest`.
  - Desligado (`navigation_async = false`, padrão): resolve na hora com `path`.
    Testes, editor, prévia de patrulha e execuções headless ficam síncronos e
    determinísticos.
  - Ligado: validade, perfil, apoio e a linha direta são checados na hora
    (submilissegundo; o mesmo início de `path`). Só a busca no grafo vai para a
    fila.
- Fila por prioridade (jogador antes de inimigos), uma tarefa por vez por
  geometria. `navigation_pump()` (chamado por `main._process` a cada quadro)
  recolhe a tarefa concluída, entrega o resultado e inicia a próxima.
- A tarefa roda sobre uma **vista congelada** da geometria: `_stage` e
  `_support_index` por referência (não são alterados no lugar depois de
  `configure`; `configure` passa a atribuir um índice novo em vez de
  `clear()`), cópias de `_temporary`, `_segments` e `_solid_slabs`, as mesmas
  revisões e o epoch. A vista tem memo próprio, usado só pela thread. A vista é
  refeita quando revisão, configuração ou epoch mudam.
- Ao concluir, um resultado cuja revisão já não é a atual vira `stale_geometry`.
  Pedido cancelado não é entregue. Ao liberar a geometria, a tarefa em curso é
  aguardada.

## Atores

- `WorldActorMotion.plan_async(destino, revisão, prioridade, ao_terminar)`:
  desligado, é `plan`. Ligado, guarda um pedido pendente (um por ator; um novo
  substitui o anterior). `plan`, `adopt_route`, `plan_ground_line`, `teleport`,
  `cancel` e `release` descartam o pendente.
- O ator continua na rota anterior enquanto espera. Na entrega, se ele já saiu
  do ponto de partida, a rota é emendada: ponto atual → segundo ponto da rota
  (ou → ponto de partida), só na mesma superfície e só se esse trecho passar no
  mesmo teste de aresta local do grafo (sweep livre e apoio integral). Sem
  emenda válida, o pedido falha (`route_moved`) e o ator pede de novo; nunca há
  replanejamento síncrono na entrega.
- Inimigos: perseguição, última posição vista, recuo de arqueiro e volta para
  casa (inclusive patrulha) usam `plan_async`; não pedem de novo enquanto há
  pendente.
- Jogador: perseguição do alvo usa `plan_async`. O clique no chão guarda o
  pedido em `main._pending_world_click`; ao chegar, aplica exatamente o que o
  clique síncrono fazia (cancela conjuração e alvo só se houver rota). Clique
  recusado continua sem mudar o estado de jogo.
- Ficam síncronos nesta etapa (curtos ou raros): dash (limitado pelo alcance),
  empurrões, fuga por medo, âncora de skill `walk_path` e o serviço de expedição.

## Snapshot

Campos novos são transitórios e entram em `omitted` do runtime_manifest.json:
`WorldGeometry.navigation_async` e o estado da fila/vista,
`WorldActorMotion._pending`/`_pending_finished`, `main._pending_world_click`.
Após restaurar, pedidos pendentes somem; a IA pede de novo no próximo ciclo e o
host restaurado religa `navigation_async` em `attach_expedition_view`.

## Ligar e desligar

`main.attach_expedition_view` liga quando o display não é headless. A variável
de ambiente `RAGRPG_SYNC_NAVIGATION=1` força o modo síncrono (diagnóstico).

## Provas

- `tests/map_editor_navigation_async_test.gd` (estágio NavigationAsync): resultado
  igual ao síncrono; linha direta imediata; pedido obsoleto após mutação;
  cancelamento; prioridade; mutação na thread principal durante a tarefa; emenda
  com o ator andando; o quadro principal não bloqueia durante uma busca longa;
  campos novos cobertos pelo registro de snapshot.
- Regressões de navegação, gameplay e E07 legados.
- Bosque com `navigation_async` ligado: pior quadro ao cruzar a emenda.

## Decisões do diário registradas (31/10)

- Compactação só em pontos seguros, até a gravação deixar de travar o jogo
  (assíncrona).
- Estado dos inimigos vivos após uma queda: pergunta levada ao tester.

## Resultado (31/10, fixture compartilhada, Godot 4.7.2 debug, headless)

- NavigationAsync 18: busca de 1,78 s no relevo orgânico feita em segundo plano
  com o laço principal rodando 261 quadros; pior `navigation_pump` 0,5 ms;
  chamada `request_path` 5 ms (inclui a checagem da linha direta).
- Bosque, clique que cruza a emenda clareira→viaduto (walk probe com
  `navigation_async` ligado): antes, um quadro travado de 0,76 s; agora o pior
  quadro do passo é 76 ms (os outros passos ficam entre 29 e 98 ms em headless)
  e a rota chega 0,79 s depois do clique, com o personagem parado e o aviso
  "Calculando caminho…". Os demais cliques seguem pela linha direta, imediatos.
- Combate no Bosque (3 mortes, 45 s, duas rodadas de cada): com e sem segundo
  plano, p50 14–15 ms e p99 49–64 ms; nenhuma busca no grafo foi necessária
  nesse combate (as perseguições seguem pela linha direta). Acima de 250 ms: a
  gravação do fim do combate (11,5–13,3 s) em todas as rodadas, que é o problema
  do diário, e um quadro de 345 ms numa rodada, com a fila de navegação vazia
  (origem fora da navegação, a investigar).

## Limites conhecidos

- Uma busca por vez por geometria; o jogador fura a fila, mas espera a tarefa em
  curso.
- Na primeira passagem pela emenda o personagem fica parado ~0,8 s até a rota
  chegar (sem travar o jogo). Aquecer superfícies vizinhas no tempo ocioso da
  thread pode encurtar essa espera, se ainda incomodar.
- Fuga por medo, âncora `walk_path`, dash e empurrões continuam síncronos.
