# E04-S0-D8 — decisão de design da Regeneração de SP

Base técnica: Teleporte entregue em `038e21c`. Este pacote migra somente
`mage_mana_regeneration`. Valores seguem sujeitos a playtest.

## Tabela autorizada

| Rank | Aumento de regeneração de SP | Demais parâmetros |
|---|---:|---:|
| 1 | +50% | zero |
| 2 | +75% | zero |
| 3 | +100% | zero |

R1 preserva exatamente o efeito legado. A passiva aumenta a regeneração derivada
de SP por meio de uma fonte aditiva identificada; não concede valor flat, SP máximo,
INT, redução de custo ou restauração instantânea. Ela custa somente pontos de job.

No vetor inicial do Mago, a regeneração bruta `2 + 0,12*INT` resulta em 3,08 SP/s.
R1–R3 produzem 4,62/5,39/6,16 SP/s. Outras fontes `increased` somam suas magnitudes
antes da aplicação única pelo `StatCalculator`; a passiva não multiplica o resultado
de outras fontes separadamente.

O ator continua apenas consumindo `sp_regen` do breakdown canônico, inclusive em
combate, enquanto vivo e sem pausa, limitado por `max_sp`. Passiva não equipada,
rank zero, ausente ou inválido não aplica fonte nem recua para R1.

Demais skills, passivas, progressão, slots e persistência não mudam neste pacote.
