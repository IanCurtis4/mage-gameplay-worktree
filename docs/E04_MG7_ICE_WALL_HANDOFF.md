# E04-MG7 — Parede de Gelo

Base: `4f1a3a6` (MG6). Escopo: somente Parede de Gelo, conforme a
[sequência aprovada](E04_MAGE_EXPANSION_PACKAGES.md). Não inicia MGI.

## Design e ranks

Mira direcional; uma faixa sólida de 210 × 20 unidades nasce com centro a 200
unidades do Mago, perpendicular à direção escolhida. Não causa dano, slow ou
outro controle. Preparo variável de 0,45 s escalado por DES; recarga base de
9 s. O eixo de rank é **somente duração**, com incrementos decrescentes.

| Rank | Duração (`power`) | SP |
|---|---:|---:|
| R1 | 3,0 s | 22 |
| R2 | 3,6 s | 24 |
| R3 | 4,1 s | 26 |
| R4 | 4,5 s | 27 |
| R5 | 4,8 s | 28 |

R0 continua não equipável. Aprender não equipa automaticamente; cinco slots
ativos e carteira de 19 pontos permanecem iguais. Biblioteca, menu/preset,
save/reload/run, HUD, mira e VFX provisório acompanham o novo ID.

## Contrato de colisão e limpeza

`ArenaNavigation` agora guarda segmentos temporários sólidos por ID. Seu
teste de ponto/segmento usa a distância mínima ao segmento inflado pelo raio
da parede e pela folga do consumidor. Assim, a mesma parede bloqueia atores,
projéteis próprios e inimigos de ambos os lados; a malha AStar é reconstruída
ao criar ou retirar o segmento. Jogador e inimigos invalidam rotas antigas
por revisão da navegação e replanejam. Isso altera um contrato compartilhado
e pede revisão técnica de Astra antes da preparação de playtest.

A colocação exige faixa inteira livre de bordas, obstáculos estáticos e outras
paredes, e nenhum ator vivo dentro da geometria inflada pelo raio de navegação.
Posição inválida não consome SP nem recarga; não há deslocamento automático da
parede. O obstáculo é removido sincronicamente ao expirar, no fim do encontro
e na morte/resultado; `_exit_tree` é salvaguarda idempotente. Pausa congela a
duração. A linha de gelo desenhada usa as mesmas pontas da colisão.

## Validação e limites

`tests/e04_mage_ice_wall_rank_integration_test.gd` cobre R0/inválido,
R1/R5, SP, isolamento de snapshot/catálogo, compra/equipagem/save/reload/run,
HUD/mira/preparo/cancelamento, colocação segura, bloqueio bidirecional de
movimento e projéteis reais, desvio/replanejamento, pausa, expiração e limpeza
de encontro/morte. Executar `tools/verify.ps1` completo com Godot 4.7.2.

O visual ainda é provisório e não substitui playtest de legibilidade/tempo de
vida. A malha de 32 unidades é reconstruída a cada parede criada/retirada;
desempenho com várias paredes simultâneas não foi medido em jogo. Não atualizar
`codex/playtest` nem `master` neste pacote. Próximo checkpoint, sob novo
comando do usuário: MGI, fechamento integrado do Mago.
