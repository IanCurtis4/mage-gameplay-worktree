# E04-AR-B12 — decisão de design da Cadência

Base técnica: Precisão entregue em `006d67a`. Este pacote adiciona somente
`archer_cadence` e seu consumo pelo intervalo do autoataque. Técnica de
Armadilhas e o fechamento integrado do Arqueiro ficam fora do escopo.

## Tabela autorizada

| Rank | Aumento de ataques por segundo |
|---|---:|
| 1 | +10% |
| 2 | +15% |
| 3 | +20% |

Cadência é uma passiva de três ranks adquiridos com pontos de job da classe
base. Ela não possui custo de SP, cast, recarga, alcance, projétil ou peso de
dano. O bônus entra como `increased.attacks_per_second` identificado no
`StatCalculator`; percentuais de outras fontes somam antes de uma única
multiplicação.

O Arqueiro base possui 1,155 ataques/s. Os ranks produzem respectivamente
1,2705, 1,32825 e 1,386 ataques/s. `attack_speed_index` continua derivado como
100 vezes o valor efetivo, sem receber modificador direto.

## Relógio do autoataque

Cada auto emitido arma `1 / attacks_per_second`: aproximadamente 0,7871 s em R1,
0,7529 s em R2 e 0,7215 s em R3. Alterar APS não encurta nem estende um cooldown
já em curso; somente a próxima emissão usa o novo intervalo. A recuperação visual
permanece em 0,14 s e não cria ataques extras.

Cadência não altera ataque de precisão, HIT, FLEE, crítico, movimento, cooldown
de skills ou projéteis. Ela pode coexistir com Precisão nos dois slots passivos,
e duplicar Cadência nos slots não duplica sua fonte.

## Progressão

`ProfileCatalog` publica Cadência em R0–R3. Personagens persistentes continuam
nascendo em R0 e com slots vazios; aprender não equipa. O piloto legado conserva
Precisão R1 como sua única passiva padrão, sem receber Cadência gratuitamente.
