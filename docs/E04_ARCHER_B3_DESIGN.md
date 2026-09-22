# E04-AR-B3 — decisão de design da Flecha Perfurante

Base técnica: Disparo Duplo entregue em `f3a3f08`. Este pacote adiciona somente
`piercing_arrow` e fecha a política compartilhada de múltiplos impactos; demais
skills e passivas do Arqueiro ficam fora.

## Tabela autorizada

| Rank | Poder por alvo sobre ATQ de precisão | Dano máximo em 3 alvos | SP |
|---|---:|---:|---:|
| 1 | 1,05 | 3,15 | 18 |
| 2 | 1,20 | 3,60 | 20 |
| 3 | 1,35 | 4,05 | 22 |
| 4 | 1,50 | 4,50 | 23 |
| 5 | 1,65 | 4,95 | 24 |

Todos os ranks emitem uma flecha direcional capaz de atingir no máximo três
atores, sempre na ordem geométrica do mais próximo para o mais distante. Cada
ator pode ser atingido apenas uma vez. Cada impacto resolve HIT/FLEE e crítico
separadamente; uma parede encerra o percurso antes de qualquer alvo atrás dela.

Recarga 5 s, alcance 600, velocidade 920, limite de três impactos e cast zero
permanecem fixos. O rank aumenta somente o dano por alvo: do R1 ao R5, dano
máximo cresce 57,14%, custo 33,33% e dano máximo por SP 17,86%. Quantidade,
área e controle não crescem.

O projétil consome todo o trecho percorrido no frame e pode registrar vários
impactos no mesmo frame. Desempate de colisões simultâneas usa o ID da instância,
eliminando dependência da ordem da lista de alvos. Autoataque, Disparo Duplo e
projéteis do Mago preservam limite de um impacto.

O targeting é direcional e não exige alvo selecionado. Preview, HUD, execução e
projétil consomem a definição capturada do snapshot. Rank inválido não recua para
R1. `ProfileCatalog` conhece as duas ativas, mas o Arqueiro continua indisponível
porque ainda não possui uma passiva funcional.
