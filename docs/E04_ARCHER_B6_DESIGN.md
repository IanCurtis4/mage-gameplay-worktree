# E04-AR-B6 — decisão de design do runtime de armadilhas

Base técnica: Mira Estendida entregue em `e93f99d`. Este pacote adiciona
somente a infraestrutura compartilhada das futuras armadilhas do Arqueiro;
`snare_trap`, `explosive_trap`, controle de movimento, dano, ranks e catálogo
continuam fora do escopo.

## Ciclo de vida

Toda armadilha captura dono, skill de origem, posição fixa, raio, tempo de
armação e permanência armada. O fluxo terminal é fechado:

- `configure` inicia em `ARMING`, ou diretamente em `ARMED` quando o tempo de
  armação é zero;
- ao terminar a armação, emite `armed` uma vez e passa a consumir a
  permanência;
- `try_trigger` só aceita ator vivo dentro do raio somado ao raio de colisão e
  conclui em `TRIGGERED`;
- timeout, substituição e limpeza concluem em `EXPIRED`, sem sintetizar um
  disparo.

As transições terminais são idempotentes. A permanência começa somente depois
da armação, inclusive quando um frame atravessa as duas fases. A pausa da
árvore congela ambos os relógios. O alvo é amostrado no momento do disparo;
efeitos concretos serão assinantes de `triggered` nos pacotes correspondentes.

## Registro e limpeza

`PlayerTrapRegistry` mantém no máximo três armadilhas ativas por dono,
compartilhadas entre todos os tipos. A quarta expira a mais antiga por ordem de
registro com motivo `replaced`; não causa dano, controle ou recompensa. Donos
distintos possuem limites independentes.

Armadilhas registradas pertencem aos grupos `player_traps` e `player_effects`.
Fim de encontro limpa o registro com `encounter_end`; morte e fim da run usam
`run_end`. Cada remoção é observável uma única vez, inclusive quando o nó sai
externamente da árvore.
