# E04-MG3 — Parede de Raios

Base: `debdc36`. Escopo: somente Parede de Raios, conforme a
[sequência aprovada](E04_MAGE_EXPANSION_PACKAGES.md). Não inicia MG4.

## Design e tabela

Mira direcional; o centro da parede nasce a 220 unidades do Mago, com linha
perpendicular à direção escolhida. A faixa tem 240 unidades de comprimento,
24 de largura, duração de 5 s e é atravessável: não altera navegação ou colisão.
O preparo variável é 0,38 s escalado por DES; recarga base de 8 s. Cada entrada
ou travessia detectada por varredura do movimento causa um golpe mágico de
precisão geométrica, sem crítico, e aplica Eletrizado por 4 s **somente se o
golpe causar dano positivo e o alvo sobreviver**. A marca não atordoa nem causa
DoT. Alvo já sobre a parede na criação não recebe tick gratuito; permanecer
parado nela também não causa ticks. Cada alvo tem intervalo de 0,9 s entre
contatos, inclusive em retravessias rápidas.

| Rank | Dano-base × ataque mágico | SP |
|---|---:|---:|
| R1 | 0,50 | 22 |
| R2 | 0,60 | 24 |
| R3 | 0,69 | 26 |
| R4 | 0,77 | 27 |
| R5 | 0,84 | 28 |

O crescimento marginal de dano e SP decresce entre R1 e R5. A emissão copia o
`DamageRequest` com dano capturado no cast; cada travessia copia essa emissão
para o alvo, usando o pipeline canônico de mitigação. O impacto é secundário
para não disparar cascatas de procs. A parede congela na pausa e é removida na
expiração, morte do jogador ou fim do encontro. O estado Eletrizado continua
sob o contrato compartilhado de MG1/MG2; Descarga Elétrica pode consumi-lo.

## Integração, prova e limites

- `lightning_wall` entra na biblioteca persistente do Mago em R0; aprender
  R1–R5 não equipa automaticamente e não altera os cinco slots ativos.
- Menu, preset salvo/reaberto, HUD, mira e cast consomem o rank equipado. O
  traço na arena e a prévia de mira são VFX provisórios, sem arte final.
- `tests/e04_mage_lightning_wall_rank_integration_test.gd` cobre tabela,
  R0/inválido, R1/R5, SP, snapshot, menu/save/reload/run, cast/cancelamento,
  geometria e varredura, intervalo por alvo, pausa, morte/limpeza e interação
  com Descarga. Rodar `tools/verify.ps1` completo no Godot 4.7.2.

Este pacote não cria stun, resistência elemental, bloqueio de passagem ou
ataques inimigos de raio. A geometria usa faixa fixa sem desviar obstáculos;
isso é intencional para a parede atravessável. Não atualizar `codex/playtest`
ou `master` neste pacote. Próximo checkpoint sob novo comando: MG4,
Impacto das Almas.
