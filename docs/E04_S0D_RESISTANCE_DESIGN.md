# E04-S0-D2 — decisão de design da Resistência

Base técnica: Investida entregue em `0504b9f`. Este pacote encerra somente o kit
piloto atual do Espadachim, migrando a passiva `swordsman_resistance`. Valores de
balanceamento seguem sujeitos a playtest.

## Tabela autorizada

| Rank | Aumento de DEF física | SP | Outros parâmetros |
|---|---:|---:|---|
| 1 | +50% | 0 | zero |
| 2 | +75% | 0 | zero |
| 3 | +100% | 0 | zero |

R1 preserva exatamente o efeito legado. R2 e R3 aumentam a mesma fonte aditiva,
sem introduzir redução final de dano, defesa mágica, resistência a crítico/controle,
HP, duração ou estado temporário. A passiva custa somente pontos de job e não SP.

No vetor inicial do Espadachim, a DEF física bruta 20 resulta em 30/35/40. Contra
100 de dano físico bruto e sem outros modificadores, a fórmula canônica produz
aproximadamente 77/74/71 de dano. O benefício cresce, mas a mitigação mantém retorno
decrescente. Dano mágico permanece inalterado.

## Contrato de execução

Cada rank declara `physical_defense_increased` e usa `power` como magnitude
fracionária do modificador (`0,50/0,75/1,00`). O handler fechado da passiva converte
essa definição em uma fonte identificada para `StatCalculator`; preview e ator não
repetem a magnitude. Rank zero, ausente ou inválido não aplica fonte nem recua para
R1. Equipar continua obrigatório.

Não altera Mago, Arqueiro, equipamentos, augments, progressão, slots ou persistência.
