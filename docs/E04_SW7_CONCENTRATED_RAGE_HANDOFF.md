# E04-SW7 — Raiva Concentrada

Base: `dce3859`. Estocada direcional em faixa de 230 unidades e meia largura
de 19, com raio do alvo considerado na colisão. Preparo variável de 0,35 s
reduzido por DES; movimento cancela preparo pela regra existente. No commit,
zera impulso/caminho/perseguição e atinge todos os alvos válidos da faixa,
sem deslocar o Espadachim. Dano físico geométrico pode critar. Recarga base
7,5 s, iniciada no commit. Ação ofensiva válida cancela Parede de Escudos.

| Rank | Multiplicador melee | SP |
|---|---:|---:|
| R1 | 1,45 | 19 |
| R2 | 1,65 | 21 |
| R3 | 1,83 | 23 |
| R4 | 1,99 | 24 |
| R5 | 2,12 | 25 |

R0 não equipa. Faixa desenhada é VFX provisório; menu/HUD/mira vêm do catálogo.
`tests/e04_swordsman_concentrated_rage_rank_integration_test.gd` passou
com 23 checks de ranks, SP/recarga, postura, geometria, múltiplos alvos e
pés firmes. `tools/verify.ps1` completo passou no Godot 4.7.2. Falta
playtest de leitura visual/balanceamento. Sem master/playtest.
