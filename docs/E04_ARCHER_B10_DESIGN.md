# E04-AR-B10 — decisão de design do Abrigo de Folhagem

Base técnica: Flecha Entorpecente entregue em `e731278`. Este pacote adiciona
somente `foliage_shelter`, a área de ocultação e sua integração com aquisição de
alvo. As três passivas e o fechamento integrado do Arqueiro ficam fora do escopo.

## Tabela autorizada

| Rank | Duração da área | SP |
|---|---:|---:|
| 1 | 4 s | 18 |
| 2 | 5 s | 19 |
| 3 | 6 s | 20 |
| 4 | 7 s | 21 |
| 5 | 8 s | 22 |

Recarga de 12 s, alcance de colocação de 360, raio de 110 e cast zero são
fixos. O rank aumenta somente a duração; área, alcance, recarga e revelação não
crescem. Mira Estendida não altera a colocação porque o Abrigo é uma área
defensiva, não um ataque de arco.

O ator dentro da área fica oculto para inimigos externos. Um inimigo com os pés
dentro da mesma instância de Abrigo ainda pode adquirir e reter o jogador. Quando
um inimigo externo deixa de poder adquiri-lo, abandona a rota; ao sair da área,
entrar na mesma área ou durante revelação, a aquisição retorna automaticamente.

Autoataque ou skill ofensiva bem-sucedida revela por 1,25 s. Buff próprio,
movimento, dano recebido e tentativa ofensiva bloqueada não revelam. Pausa congela
área e revelação. Ocultação não concede invulnerabilidade, não remove projéteis
já emitidos, não altera colisão e não depende de esconder o sprite.

A área registra uma fonte imutável de centro/raio no jogador e a remove uma vez
ao expirar, limpar ou perder o dono. Múltiplas áreas podem coexistir; o jogador
fica oculto enquanto estiver em ao menos uma, e um observador precisa compartilhar
uma das áreas que contém o jogador. Morte e fim da run limpam o estado explicitamente.

## Fronteira dos cinco slots

`ProfileCatalog` publica a oitava ativa da biblioteca, mas o piloto legado mantém
seu loadout existente de cinco ações. O Abrigo precisa ocupar explicitamente um
dos cinco slots num `BuildSnapshot`/preset; aprender não autoequipa e nenhum sexto
slot ou atalho é criado. O Arqueiro continua indisponível no perfil porque ainda
não possui passiva funcional.
