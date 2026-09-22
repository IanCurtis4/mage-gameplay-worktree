# E04-S0-D6 — decisão de design da Lança de Gelo

Base técnica: Lança de Fogo entregue em `e95f976`. Este pacote migra somente
`ice_spear`. Valores seguem sujeitos a playtest.

## Tabela autorizada

| Rank | Poder por projétil sobre ATQM | SP | Quantidade-base |
|---|---:|---:|---:|
| 1 | 1,10 | 14 | 1 |
| 2 | 1,25 | 15 | 1 |
| 3 | 1,40 | 16 | 1 |
| 4 | 1,55 | 17 | 1 |
| 5 | 1,70 | 18 | 1 |

O dano por projétil cresce linearmente. O custo usa a curva côncava de S0-C entre
14 e 18 SP, arredondada somente na autoria. Do R1 ao R5, poder cresce 54,55%,
custo 28,57% e poder por SP 20,20%; a eficiência não diminui entre ranks.

O rank deixa de ser quantidade: a base é sempre 1 e cada stack de
`extra_ice_spear`/Gelo Geminado adiciona um projétil. Isso espelha a decisão da Lança
de Fogo e evita multiplicar dano por rank e quantidade por rank.

Todos os ranks preservam recarga 3 s, preparo variável 0,22 s, alcance 360,
velocidade 760, peso mágico 1, targeting único contestado e crítico. O efeito
`slow` permanece 30% por 2 s após dano positivo, sem empilhar intensidade nem
alterar stats. Homing e colisão não mudam. Rank ausente ou inválido não recua para R1.

Demais skills do Mago não mudam. Teleporte e passiva ficam fora do pacote.
