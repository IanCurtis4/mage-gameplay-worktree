# E04-AR-B5 — decisão de design da Mira Estendida

Base técnica: Chuva de Flechas entregue em `e1fdb0f`. Este pacote adiciona
somente `extended_aim`, `Targeting.SELF` e o buff temporário de alcance;
armadilhas e demais skills e passivas do Arqueiro ficam fora.

## Tabela autorizada

| Rank | Duração | Bônus fixo de alcance | SP |
|---|---:|---:|---:|
| 1 | 4 s | +120 | 16 |
| 2 | 5 s | +120 | 17 |
| 3 | 6 s | +120 | 18 |
| 4 | 7 s | +120 | 19 |
| 5 | 8 s | +120 | 20 |

Recarga 12 s e cast zero permanecem fixos. O rank aumenta somente a duração:
do R1 ao R5 ela cresce 100%, o custo 25% e a duração por SP 60%. Magnitude,
dano, velocidade, quantidade, área e controle não crescem.

O bônus se aplica ao alcance de engajamento e à distância máxima da flecha do
autoataque, além de `double_shot`, `piercing_arrow` e ao posicionamento de
`arrow_rain`. O projétil ou centro emitido captura o alcance vigente; expirar o
buff não encurta uma ação já emitida. Não afeta a própria skill, skills de outra
classe nem posicionamento das futuras armadilhas. Novas skills precisam aderir
explicitamente a essa lista.

O buff não acumula. Novo uso permitido pela recarga substitui o tempo restante
pela duração integral do rank. Pausa congela o timer; morte e nova configuração
do ator limpam o estado. HUD exibe `ATIVA` e o tempo restante.

`Targeting.SELF` não consome coordenada do mouse: tecla ou botão executam a skill
imediatamente em qualquer modo de cast e não deixam intenção pendente. Preview de
contrato, quando chamado diretamente, ancora o indicador no próprio ator.
`ProfileCatalog` conhece a quarta ativa, mas o Arqueiro continua indisponível por
ainda não possuir uma passiva funcional.
