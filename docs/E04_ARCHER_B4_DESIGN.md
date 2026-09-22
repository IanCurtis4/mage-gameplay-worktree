# E04-AR-B4 — decisão de design da Chuva de Flechas

Base técnica: Flecha Perfurante entregue em `591ac3a`. Este pacote adiciona
somente `arrow_rain` e sua área anunciada; buff próprio, armadilhas e demais
skills e passivas do Arqueiro ficam fora.

## Tabela autorizada

| Rank | Poder total por alvo sobre ATQ de precisão | Poder por saraivada | SP |
|---|---:|---:|---:|
| 1 | 1,80 | 0,60 | 22 |
| 2 | 2,10 | 0,70 | 24 |
| 3 | 2,40 | 0,80 | 26 |
| 4 | 2,70 | 0,90 | 28 |
| 5 | 3,00 | 1,00 | 30 |

Todos os ranks anunciam uma área de raio 80 por 0,45 s e aplicam exatamente
três saraivadas, separadas por 0,18 s. O centro acompanha o cursor até o limite
de 480 unidades e é fixado no commit; terreno não bloqueia flechas que caem do
alto. Cada saraivada amostra a posição atual dos atores e resolve dano físico de
geometria e crítico separadamente. Sair durante o aviso ou entre impactos evita
as saraivadas restantes; entrar depois não recebe retroativamente as anteriores.

Recarga 7 s, alcance 480, raio 80, aviso, intervalo, três saraivadas e cast zero
permanecem fixos. O rank aumenta somente o dano: do R1 ao R5, dano total cresce
66,67%, custo 36,36% e dano total por SP 22,22%. Quantidade, área e controle não
crescem.

O targeting é `POINT` e não exige alvo selecionado. Preview, HUD, execução e
área consomem a definição capturada do snapshot. Rank inválido não recua para
R1. `ProfileCatalog` conhece as três ativas, mas o Arqueiro continua indisponível
porque ainda não possui uma passiva funcional.
