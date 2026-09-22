# E04-S0-D5 — decisão de design da Lança de Fogo

Base técnica: Parede de Fogo entregue em `bbaeca9`. Este pacote migra somente
`fire_spear`. Valores seguem sujeitos a playtest.

## Tabela autorizada

| Rank | Poder por projétil sobre ATQM | SP | Quantidade-base |
|---|---:|---:|---:|
| 1 | 1,35 | 16 | 1 |
| 2 | 1,55 | 18 | 1 |
| 3 | 1,75 | 19 | 1 |
| 4 | 1,95 | 20 | 1 |
| 5 | 2,15 | 21 | 1 |

O dano por projétil cresce linearmente. O custo usa a curva côncava de S0-C entre
16 e 21 SP, arredondada somente na autoria. Do R1 ao R5, poder cresce 59,26%,
custo 31,25% e poder por SP 21,33%; a eficiência não diminui entre ranks.

O rank deixa de ser interpretado como quantidade de Lanças de Fogo. A quantidade
base é sempre 1; cada stack de `extra_fire_spear`/Fogo Geminado continua adicionando
exatamente um projétil, até o limite já existente. Isso impede multiplicar ao mesmo
tempo dano por rank e quantidade por rank. Lança de Gelo mantém temporariamente o
comportamento legado até seu próprio pacote.

Todos os ranks preservam recarga 3 s, preparo variável 0,22 s, alcance 360,
velocidade 760, peso mágico 1, targeting único contestado e crítico. O efeito tipado
`burning_target_bonus` mantém `×1,5` por projétil somente se o alvo estiver queimando
no impacto. Homing e colisão com obstáculos não mudam. Rank inválido não recua para R1.

Bola/Parede não mudam. Lança de Gelo, Teleporte e passiva ficam fora do pacote.
