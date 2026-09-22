# E04-S0-D3 — decisão de design da Bola de Fogo

Base técnica: kit piloto do Espadachim concluído em `84a7ccf`. Este pacote inicia
o Mago migrando somente `fireball`. Valores seguem sujeitos a playtest.

## Tabela autorizada

| Rank | Poder sobre ATQM | SP |
|---|---:|---:|
| 1 | 1,80 | 18 |
| 2 | 2,05 | 20 |
| 3 | 2,30 | 22 |
| 4 | 2,55 | 23 |
| 5 | 2,80 | 24 |

O dano cresce linearmente. O custo usa a curva côncava aprovada em S0-C entre
18 e 24 SP, arredondada somente na autoria. Do R1 ao R5, dano bruto cresce 55,56%,
custo 33,33% e dano por SP 16,67%; a eficiência não diminui entre ranks.

Todos os ranks preservam recarga 2,5 s, preparo variável 0,32 s, alcance 700,
velocidade 680, peso mágico 1 e demais pesos/tempos adicionais zero. A Bola continua
direcional, para no primeiro inimigo ou obstáculo e mantém o crítico garantido
somente quando a queimadura está ativa no impacto. Não ganha área, projéteis, efeito,
velocidade, alcance ou controle por rank.

Runtime, preparo, HUD, mira e projétil leem a definição capturada do snapshot.
Rank ausente ou inválido não recua para R1. Parede, Lanças, Teleporte e passiva do
Mago permanecem fora deste pacote.
