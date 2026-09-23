# E04-MG6 — Barreira Fantasma

Base: `efabefc`. Escopo: somente Barreira Fantasma, conforme a
[sequência aprovada](E04_MAGE_EXPANSION_PACKAGES.md). Não inicia MG7.

## Design e tabela

Mira direcional; o centro nasce a 210 unidades do Mago e a faixa fica
perpendicular à direção escolhida. Mede 240 unidades de comprimento e 20 de
largura, dura até 5 s e não modifica navegação ou colisão de atores. Preparo
variável de 0,42 s escalado por DES; recarga base de 10 s. Cada projétil
inimigo interceptado gasta **uma** carga e desaparece; a última carga remove a
barreira. Inimigos que entram ou atravessam a faixa recebem slow de 30% por
2 s e redução de 20% do dano causado por 2,5 s. Alvos já sobre a faixa na
criação não recebem aplicação gratuita; ficar parado não renova efeitos.
Retravessias têm intervalo de 0,75 s por alvo. O jogador nunca integra a lista
de alvos da barreira e seus projéteis não gastam cargas.

| Rank | Projéteis absorvidos (`power`) | SP |
|---|---:|---:|
| R1 | 2 | 20 |
| R2 | 3 | 22 |
| R3 | 4 | 24 |
| R4 | 5 | 25 |
| R5 | 6 | 26 |

O rank melhora somente a capacidade; duração, geometria, slow e redução ficam
fixos. Não há dano da barreira nem nova resistência elemental ou hard control.

## Contrato de intercepção

`ArrowProjectile` é o único projétil inimigo atual. A cada passo, ele compara
continuamente o primeiro contato com alvo e barreiras ativas, evitando atravessar
uma faixa entre frames. Só consome carga se a barreira estiver antes do alvo e
o trajeto até ela estiver livre de obstáculo. Se um obstáculo vier antes, o
projétil é destruído por ele sem gastar carga; entre várias barreiras, a mais
próxima absorve. Alvo antes da barreira mantém o acerto. A comparação usa o
deslocamento dos pés (`BODY_OFFSET`) para casar projéteis com a faixa desenhada
em coordenadas de combate. Barreiras esgotadas ou já agendadas para remoção não
interceptam o próximo projétil. `PlayerProjectile` permanece intocado.

Essa mudança na ordenação de colisões de `ArrowProjectile` pede revisão de
Astra no gate proporcional. Tipos futuros de projétil inimigo precisarão adotar
explicitamente o mesmo contrato; não há registro global de projéteis. A
colocação é fixa e pode sobrepor visualmente um obstáculo, mas não cria passagem
nem intercepta um projétil bloqueado antes por esse obstáculo.

## Integração e prova

- `phantom_barrier` entra na biblioteca persistente em R0; aprender R1–R5 não
  equipa automaticamente e não altera os cinco slots ativos.
- Menu, preset, save/reload/run, HUD, mira e cancelamento do preparo acompanham
  o rank equipado. Faixa e indicadores de carga são VFX provisórios.
- `tests/e04_mage_phantom_barrier_rank_integration_test.gd` cobre ranks,
  R0/inválido, SP, snapshot, menu/run, geometria e travessia, intervalo, pausa,
  expiração, cargas, projétil rápido, múltiplas barreiras, obstáculos, ordem do
  alvo, projétil próprio, morte e limpeza. `tools/verify.ps1` completo deve
  passar no Godot 4.7.2 antes da entrega.

Não atualizar `codex/playtest` ou `master` neste pacote. Próximo checkpoint
somente sob novo comando: MG7, Parede de Gelo.
