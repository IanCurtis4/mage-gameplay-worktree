# E04-SW8 — Grito Aterrorizante

Base: `c6084b4`. Pulso instantâneo ofensivo em raio de 170 unidades, sem
dano direto. Aplica fear curto pelo `HardControlState`, respeitando resistência,
imunidade, teto e orçamento de boss; não cancela ataques já emitidos. O alvo
recebe independentemente +20% dano recebido por 3 s, pelo canal/fonte do SW2,
inclusive quando fear é imune. O pedido de dano recebido é copiado no impacto.
Recarga base 11 s; ação válida encerra Parede de Escudos.

| Rank | Fear base | SP |
|---|---:|---:|
| R1 | 0,75 s | 20 |
| R2 | 0,90 s | 22 |
| R3 | 1,00 s | 24 |
| R4 | 1,10 s | 25 |
| R5 | 1,15 s | 26 |

R0 não equipa. Círculo roxo e mira são provisórios. `tests/e04_swordsman_terrifying_shout_rank_integration_test.gd`
passou com 22 checks: ranks, SP/recarga, postura, área, imunidade,
amplificação de dano, pausa e limpeza. `tools/verify.ps1` completo passou
no Godot 4.7.2. Balanceamento/VFX exigem playtest. Sem master/playtest.
