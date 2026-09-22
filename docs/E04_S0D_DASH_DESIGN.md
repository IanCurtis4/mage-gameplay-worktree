# E04-S0-D1 — decisão de design da Investida

Base técnica: padrão de rank de S0-C aprovado em `8bb0f63`. Este pacote migra
somente a Investida (`dash`); a passiva do Espadachim permanece fora do escopo.
Valores de balanceamento seguem sujeitos a playtest.

## Tabela autorizada

| Rank | SP | Recarga | Alcance | Duração |
|---|---:|---:|---:|---:|
| 1 | 20 | 6,0 s | 270 | 0,18 s |
| 2 | 20 | 5,7 s | 270 | 0,18 s |
| 3 | 20 | 5,4 s | 270 | 0,18 s |
| 4 | 20 | 5,1 s | 270 | 0,18 s |
| 5 | 20 | 4,8 s | 270 | 0,18 s |

A especialização reduz somente a recarga, em passos explícitos de 0,3 s, até
20% no R5. Custo, alcance e duração permanecem iguais aos valores atuais. Cast
fixo/variável, pós-cast, poder, pesos, projétil e efeitos ficam em zero.

Essa escolha preserva geometria de mapa, colisão e navegação; não acrescenta
dano, controle, invulnerabilidade ou atravessamento. Runtime, mira e HUD leem a
mesma cópia da definição de rank capturada do snapshot, sem fórmula de curva.
Rank ausente ou inválido não recua para R1.

## Limite do pacote

S0-D1 cobre catálogo, execução, débito de SP, recarga, destino da movimentação,
dispatch e preview da Investida. Não altera a passiva, outras classes, carteiras,
progressão, slots ou persistência.
