# E04-S0-D4 — decisão de design da Parede de Fogo

Base técnica: Bola de Fogo entregue em `e40d27b`. Este pacote migra somente
`fire_wall`. Valores seguem sujeitos a playtest.

## Tabela autorizada

| Rank | Poder por tick sobre ATQM | SP |
|---|---:|---:|
| 1 | 0,30 | 24 |
| 2 | 0,34 | 27 |
| 3 | 0,38 | 29 |
| 4 | 0,42 | 30 |
| 5 | 0,46 | 32 |

O dano por tick cresce linearmente. O custo usa a curva côncava de S0-C entre
24 e 32 SP, arredondada somente na autoria. Do R1 ao R5, poder cresce 53,33%,
custo 33,33% e poder por SP 15%; a eficiência não diminui entre ranks.

Todos os ranks preservam recarga 7 s, preparo variável 0,48 s, centro a 180,
quatro pilares, espaçamento 54, raio 22, duração da parede 5 s e queimadura 3 s
com um tick por segundo. A parede continua atravessável, renova um único fluxo de
queimadura e não ganha área, duração, controle ou cadências adicionais por rank.

Cada rank declara o efeito tipado `burn`, peso mágico 1 e demais pesos/tempos
adicionais zero. O handler captura o dano no lançamento; defesa do alvo continua
lida em cada tick. Rank ausente ou inválido não recua para R1.

Bola de Fogo não muda. Lanças, Teleporte e passiva do Mago ficam fora do pacote.
