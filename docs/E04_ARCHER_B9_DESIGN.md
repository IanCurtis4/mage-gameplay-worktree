# E04-AR-B9 — decisão de design da Flecha Entorpecente

Base técnica: Armadilha Explosiva entregue em `64a16c2`. Este pacote adiciona
somente `slowing_arrow`, seu projétil direcional e o slow por impacto positivo.
Ocultação, Abrigo de Folhagem e passivas ficam fora do escopo.

## Tabela autorizada

| Rank | Duração do slow | SP |
|---|---:|---:|
| 1 | 1,4 s | 15 |
| 2 | 1,8 s | 16 |
| 3 | 2,2 s | 17 |
| 4 | 2,6 s | 18 |
| 5 | 3,0 s | 19 |

Dano físico de `0,90 × ATQ de precisão`, slow de 35%, recarga de 5 s,
alcance de 560, velocidade de 880 u/s e cast zero são fixos. O rank aumenta
somente a duração do controle; dano, intensidade, alcance, velocidade e recarga
não crescem. Mira Estendida acrescenta seus 120 pontos de alcance porque a
Flecha Entorpecente pertence à família de ataques de arco, não às traps.

A emissão captura direção, dano, HIT, crítico, duração e intensidade. O
projétil não tem homing, pode ser esquivado por movimento, é bloqueado por
obstáculo, expira no alcance e acerta no máximo um alvo. O impacto continua
disputando HIT/FLEE e resolvendo defesa física e crítico no pipeline canônico.

Slow só é aplicado depois de dano positivo e enquanto o alvo permanece vivo.
Reaplicação não soma intensidade: preserva a maior fração e a maior duração
restante. O runtime compartilhado limita o slow total a 50%, conforme
`E00_02_STATS_CONTRACT.md`, congela em pausa, não altera stats e limpa na morte.

## Fronteira dos cinco slots

`ProfileCatalog` publica a sétima ativa da biblioteca, mas o piloto legado mantém
seu loadout existente de cinco ações. A Flecha Entorpecente precisa ocupar
explicitamente um dos cinco slots num `BuildSnapshot`/preset; aprender não
autoequipa e nenhum sexto slot ou atalho é criado. O Arqueiro continua
indisponível no perfil porque ainda não possui passiva funcional.
