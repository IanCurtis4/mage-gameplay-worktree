# E04-AR-B13 — decisão de design da Técnica de Armadilhas

Base técnica: Cadência entregue em `d8e9683`. Este pacote adiciona somente
`trap_technique`, a terceira passiva da biblioteca do Arqueiro.

## Tabela

| Rank | Bônus à permanência armada | Laço e Explosiva |
|---|---:|---:|
| 0 | 0 s | 12 s |
| 1 | +3 s | 15 s |
| 2 | +6 s | 18 s |
| 3 | +9 s | 21 s |

O bônus é plano e se aplica somente ao relógio no estado `ARMED`. Os tempos
de armação continuam 0,60 s para Laço e 0,75 s para Explosiva. O rank não
altera duração do root, dano da explosão, raio, limite de três armadilhas,
custo de SP nem recarga das skills.

A passiva é uma fonte de regra identificada, separada das fontes de atributos
do `StatCalculator`. `BuildSnapshot` lê o rank efetivo da passiva equipada,
deduplica os slots e calcula uma única duração. O controlador captura o valor
na criação da armadilha; uma mudança posterior na build ou no estado da run
não reescreve o relógio de instâncias já colocadas. Rank inválido, R0 ou
passiva apenas aprendida mantêm os 12 s base.

## Progressão

`ProfileCatalog` publica `trap_technique` como passiva base R0–R3 comprada com
pontos de job. Personagem persistente novo continua em R0 e com dois slots
passivos vazios. O piloto legado mantém Precisão R1 como passiva padrão; a
Técnica de Armadilhas deve ser aprendida e equipada explicitamente no perfil.
