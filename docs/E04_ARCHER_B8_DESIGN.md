# E04-AR-B8 — decisão de design da Armadilha Explosiva

Base técnica: Armadilha de Laço entregue em `55a3f79`. Este pacote adiciona
somente `explosive_trap` e reutiliza o runtime compartilhado de armadilhas.
Flecha Entorpecente, ocultação e passivas ficam fora do escopo.

## Tabela autorizada

| Rank | Poder físico sobre ATQ de precisão | SP |
|---|---:|---:|
| 1 | 1,35 | 20 |
| 2 | 1,60 | 22 |
| 3 | 1,85 | 24 |
| 4 | 2,10 | 26 |
| 5 | 2,35 | 28 |

Recarga de 9 s, alcance de colocação de 360, raio de acionamento de 48,
raio da explosão de 105, armação de 0,75 s e permanência armada de 12 s
são fixos. Cast e controle são zero. O rank aumenta somente o dano: do R1 ao
R5, o poder cresce 74,07%, o custo 40% e o dano bruto por SP 24,34%. Área,
alcance, recarga, armação e permanência não crescem. Mira Estendida não
altera colocação de traps.

A colocação captura posição e `DamageRequest`: `precision_attack` em dano
físico, multiplicador de dano, chance e multiplicador crítico. Falha por terreno
ocorre antes de custo e recarga. O primeiro alvo vivo no raio de acionamento
consome a trap; proximidade e instance ID definem o desempate.

No acionamento, cada ator vivo dentro do raio da explosão somado à própria
colisão recebe uma cópia independente do request, em ordem de instance ID. A
geometria já confirmada não disputa HIT/FLEE, mas cada impacto resolve defesa
física e crítico no pipeline canônico. A trap emite requests; não subtrai HP
diretamente e não aplica root, slow ou outro controle.

Substituição FIFO, timeout e limpeza usam `EXPIRED` e nunca detonam. Somente a
transição real para `TRIGGERED` produz a explosão uma vez.

## Fronteira dos cinco slots

`ProfileCatalog` publica a sexta ativa da biblioteca, mas o piloto legado mantém
seu loadout existente de cinco ações. A Explosiva precisa ocupar explicitamente
um dos cinco slots num `BuildSnapshot`/preset; aprender não autoequipa e nenhum
sexto slot ou atalho é criado. O Arqueiro continua indisponível no perfil porque
ainda não possui passiva funcional.
