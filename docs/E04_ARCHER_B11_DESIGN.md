# E04-AR-B11 — decisão de design da Precisão

Base técnica: Abrigo de Folhagem entregue em `b3df810`. Este pacote adiciona
somente `archer_precision`, sua fonte canônica de HIT e a abertura do Arqueiro
na criação persistente. Cadência, Técnica de Armadilhas e o fechamento integrado
do Arqueiro ficam fora do escopo.

## Tabela autorizada

| Rank | HIT plano |
|---|---:|
| 1 | +8 |
| 2 | +12 |
| 3 | +16 |

Precisão é uma passiva de três ranks adquiridos com pontos de job da classe
base. Ela não possui custo de SP, cast, recarga, alcance, projétil ou peso de
dano. O bônus entra como `flat.hit_rating` identificado no `StatCalculator`;
não altera DEX, ataque de precisão, FLEE, crítico ou cadência.

HIT continua sendo capturado pelo `DamageRequest` no momento da ação. Assim,
autoataques e skills de acurácia contestada usam o valor aumentado contra FLEE,
enquanto skills confirmadas por geometria mantêm chance 1,0 e não ganham uma
segunda disputa. Duplicar a passiva nos dois slots não duplica sua fonte.

## Progressão e disponibilidade

Com ao menos duas ativas e esta primeira passiva funcional, o contrato existente
de `ProfileCatalog.base_class_is_available` passa a liberar o Arqueiro. O menu
publica `Criar Arqueiro` junto das demais classes base.

Um personagem persistente novo permanece com todas as skills em R0 e ambos os
slots passivos vazios: liberar a classe não aprende nem equipa Precisão. O piloto
não persistente segue o padrão histórico de Espadachim e Mago e equipa a passiva
padrão em R1 para exercitar a classe sem perfil.
