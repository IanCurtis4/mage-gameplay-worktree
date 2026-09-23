# E04-SW4 — Grito Perfurante

Base: `c6e244f`. Pulso instantâneo em raio de 140 unidades: dano físico
geométrico baixo (0,45 × ataque corpo a corpo), sem crítico. Alvos vivos que
recebem dano positivo sofrem 30% slow e 25% redução de ASPD em canais
independentes. É ação ofensiva válida: encerra Parede de Escudos antes do
impacto. Recarga base 8 s; custos e durações:

| Rank | Debuffs | SP |
|---|---:|---:|
| R1 | 1,5 s | 17 |
| R2 | 1,9 s | 19 |
| R3 | 2,2 s | 21 |
| R4 | 2,4 s | 22 |
| R5 | 2,5 s | 23 |

R0 não equipa. Pulso desenhado e mira circular são provisórios; menu/HUD
seguem o catálogo. `tests/e04_swordsman_piercing_shout_rank_integration_test.gd`
passou com 22 checks: ranks, SP/recarga, raio, postura, dano, dois canais,
pausa e expiração. `tools/verify.ps1` completo passou no Godot 4.7.2.
Balanceamento e legibilidade em grupo aguardam playtest. Sem master/playtest.
