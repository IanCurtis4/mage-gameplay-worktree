# E04-SW6 — Golpe Brutal

Base: `2a35e19`. Skill ofensiva de alvo único até 110 unidades e linha de
visão livre; preparo variável de 0,55 s reduzido por DES. Ao concluir, alvo,
alcance, SP e recarga são revalidados. Impacto físico geométrico pode critar.
Somente após dano positivo num alvo sobrevivente aplica 30% redução de DEF
física por 4 s; o próprio impacto usa a defesa anterior. Recarga base 8 s.

| Rank | Multiplicador melee | SP |
|---|---:|---:|
| R1 | 2,20 | 20 |
| R2 | 2,55 | 23 |
| R3 | 2,85 | 25 |
| R4 | 3,10 | 27 |
| R5 | 3,30 | 28 |

R0 não equipa. Ação validada encerra Parede de Escudos no commit, não no
preparo; cancelamento não causa dano nem cobra SP. Linha de impacto e mira
provisórias. `tests/e04_swordsman_brutal_strike_rank_integration_test.gd`
passou com 24 checks de ranks, preparo/cancelamento, SP/recarga, postura,
ordem dano→debuff e expiração. `tools/verify.ps1` integral passou no Godot
4.7.2. Arte/balanceamento aguardam playtest. Sem master/playtest.
