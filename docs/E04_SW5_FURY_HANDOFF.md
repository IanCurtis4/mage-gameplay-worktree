# E04-SW5 — Fúria

Base: `74eba21`. Ação ofensiva instantânea que encerra Parede de Escudos ao
ativar. Dura 6 s, recarga base 14 s. `ClassCatalog.active_modifier_source`
produz fonte identificada `active_fury`; `StatCalculator` recalcula melee e
ASPD com o benefício de rank, e aplica penalidade fixa de 25% à defesa física
e mágica. Benefício de ASPD é 60% da fração de melee. O snapshot de ataques
emitidos antes de ativar/expirar permanece intacto. Recalcular a build durante
a janela não duplica fonte; expiração/morte/resultado retiram a fonte.

| Rank | Melee | ASPD | SP |
|---|---:|---:|---:|
| R1 | +30% | +18% | 22 |
| R2 | +38% | +22,8% | 24 |
| R3 | +45% | +27% | 26 |
| R4 | +51% | +30,6% | 27 |
| R5 | +56% | +33,6% | 28 |

R0 não equipa; menu/HUD/mira e aura laranja provisória seguem rank e estado.
`tests/e04_swordsman_fury_rank_integration_test.gd` passou com 29 checks de
ranks, SP/recarga, postura, atributos, fonte única e restauração. Suíte
`tools/verify.ps1` integral passou no Godot 4.7.2. Balanceamento/arte final
aguardam playtest. Sem master/playtest.
