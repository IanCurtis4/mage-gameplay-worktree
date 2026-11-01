# F9 — oclusão de câmera no editor e no jogo (P6c)

Checkpoint50. Escolha humana de 1/11: levar ao jogo o esmaecimento que antes só
existia na prévia do editor, para o jogador e os inimigos, com prova no Bosque.

## Regra (uma só, `object_view.gd` `reveal_actors`)

Um objeto com a capacidade `camera_occlusion` do catálogo de props fica
translúcido (alfa 0,38) enquanto algum ator está atrás dele:

- o sprite do objeto cobre o ponto logo acima dos pés do ator na tela;
- o objeto está à frente do ator (x+z não menor: a câmera olha de +X/+Z);
- o objeto não está muito acima do chão do ator (até 32 unidades).

Volta ao normal quando ninguém está atrás. Objetos sem `camera_occlusion`
(arbustos de decoração) nunca esmaecem; uma árvore atrás do ator também não. A
prévia do editor (`reveal_actor`) e o jogo usam a mesma função. Oclusão é só
apresentação: corpo, linha de visão e ataques continuam com as capacidades
`body` e `attack_los` e as autoridades do mundo.

## No jogo

`AuthoredExpeditionView.sync()`, a cada quadro, depois de posicionar os atores
observados (jogador e inimigos visíveis), aplica a regra aos sprites do mapa
(`skin.object_sprites`, peças e bordas) e guarda quantos esmaeceram em
`occluded`.

## Prova

`OcclusionNative` 12/12 (renderização real, Bosque publicado pela API do P5):
o jogador anda até atrás de uma árvore e só ela esmaece; à frente da mesma árvore
ela fica opaca; ao sair volta; um inimigo atrás de uma árvore a esmaece; um
arbusto nunca esmaece; a prévia do editor segue a mesma regra. Capturas
`occlusion_player_behind_tree.png` e `occlusion_enemy_behind_tree.png`.

## Limites

- O teste é por retângulo do sprite (como antes), não por pixel; uma copa com
  muito vazio pode esmaecer um pouco antes.
- O alfa muda de uma vez, sem transição.
