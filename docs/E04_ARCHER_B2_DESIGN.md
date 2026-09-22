# E04-AR-B2 — decisão de design do Disparo Duplo

Base técnica: projétil de precisão entregue em `1ebc077`. Este pacote adiciona
somente `double_shot`; demais skills e passivas do Arqueiro ficam fora.

## Tabela autorizada

| Rank | Poder por flecha sobre ATQ de precisão | Dano total máximo | SP |
|---|---:|---:|---:|
| 1 | 0,70 | 1,40 | 14 |
| 2 | 0,80 | 1,60 | 16 |
| 3 | 0,90 | 1,80 | 17 |
| 4 | 1,00 | 2,00 | 18 |
| 5 | 1,10 | 2,20 | 19 |

Todos os ranks emitem exatamente duas flechas direcionais independentes. Cada uma
resolve HIT/FLEE e crítico no próprio impacto e para no primeiro inimigo ou obstáculo.
O custo e a recarga são aplicados uma vez por uso, não por flecha.

Recarga 4 s, alcance 520, velocidade 880 e cast zero permanecem fixos. O rank
aumenta somente o dano por flecha: do R1 ao R5, dano total cresce 57,14%, custo
35,71% e dano total por SP 15,79%. Quantidade, área e controle não crescem.

O targeting é direcional e não exige alvo selecionado. Preview, HUD, execução e
projéteis consomem a definição capturada do snapshot. Rank inválido não recua para
R1. `ProfileCatalog` conhece a skill, mas o Arqueiro continua indisponível porque
ainda não alcançou o gate de duas ativas e uma passiva.
