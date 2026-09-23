# E04-SW3 — Perseverança

Base: `c5ce237`. Escopo: escudo pessoal temporário. Não altera master/playtest.

Perseverança é ação defensiva instantânea, compatível com Parede de Escudos.
Capacidade = base do rank + 2 × VIT efetiva + 1,5 × INT efetiva, calculada em
`StatCalculator.personal_shield_capacity`. Dura 6 s ou até esgotar; recarga
base 10 s inicia no uso. Reaplicar renova duração e mantém a maior capacidade
entre escudo restante e novo valor, sem somar. Pausa congela; morte, fim de
encontro e resultado limpam.

| Rank | Base de absorção | SP |
|---|---:|---:|
| R1 | 40 | 18 |
| R2 | 55 | 20 |
| R3 | 68 | 22 |
| R4 | 80 | 23 |
| R5 | 90 | 24 |

`HealthState` consome capacidade após `CombatMath.resolve` e antes do HP.
Resultado expõe `absorbed_damage` e `actual_damage`; impacto totalmente
absorvido não dispara efeitos secundários. O pedido original não é mutado.
R0 não equipa; menu/HUD/mira usam definição catalogada. Círculo azul é VFX
provisório.

`tests/e04_swordsman_perseverance_rank_integration_test.gd` passou com 26
checks para ranks, fórmula VIT/INT, SP/recarga, coexistência com postura,
absorção, pausa e expiração. `tools/verify.ps1` completo passou no Godot 4.7.2.
Balanceamento e legibilidade visual ainda exigem playtest.
