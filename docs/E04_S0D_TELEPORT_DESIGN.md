# E04-S0-D7 — decisão de design do Teleporte

Base técnica: Lança de Gelo entregue em `b7a5096`. Este pacote migra somente
`teleport`. Valores seguem sujeitos a playtest.

## Tabela autorizada

| Rank | SP | Recarga | Alcance |
|---|---:|---:|---:|
| 1 | 22 | 6,0 s | 320 |
| 2 | 22 | 5,7 s | 320 |
| 3 | 22 | 5,4 s | 320 |
| 4 | 22 | 5,1 s | 320 |
| 5 | 22 | 4,8 s | 320 |

A especialização reduz somente a recarga, em passos explícitos de 0,3 s, até
20% no R5. Custo e alcance preservam o baseline atual. Cast fixo/variável,
pós-cast, poder, pesos, projétil e efeitos permanecem zero.

Essa escolha melhora a disponibilidade sem ampliar o atravessamento de obstáculos
ou alterar a geometria dos mapas. O Teleporte continua instantâneo, atravessa
obstáculos intermediários e exige que o destino final seja caminhável. Execução
bem-sucedida ainda limpa caminhada, impulso, perseguição e seleção anteriores.
Destino bloqueado, recursos insuficientes e rank inválido não gastam SP nem iniciam
recarga; rank inválido não recua para R1.

Demais skills e a passiva do Mago não mudam neste pacote.
