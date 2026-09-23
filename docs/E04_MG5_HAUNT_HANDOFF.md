# E04-MG5 — Assombro

Base: `640d7c3`. Escopo: somente Assombro, conforme a
[sequência aprovada](E04_MAGE_EXPANSION_PACKAGES.md). Não inicia MG6.

## Design e tabela

Cone direcional de alcance 230 e meia abertura de 42° (84° no total).
Preparo variável de 0,40 s escalado por DES e recarga base de 9 s. A emissão
captura origem, direção, alcance e `DamageRequest`; cada alvo vivo dentro do
mesmo cone recebe um golpe mágico de precisão geométrica, sem crítico. Somente
um golpe com dano positivo em alvo sobrevivente aplica fear base de 0,90 s e
redução de 25% do dano causado por 3,0 s. Fear e redução são independentes:
imunidade a controle pode bloquear fear, mas não o debuff. Reaplicação do debuff
mantém a maior redução e duração, sem somar frações. Ranks aumentam apenas dano;
ângulo, durações e redução permanecem fixos.

| Rank | Dano-base × ataque mágico | SP |
|---|---:|---:|
| R1 | 0,35 | 18 |
| R2 | 0,43 | 20 |
| R3 | 0,50 | 21 |
| R4 | 0,56 | 22 |
| R5 | 0,61 | 23 |

O crescimento marginal de dano e SP decresce entre R1 e R5. Sem resistência
espiritual nova: a mitigação mágica e a resistência mágica a CC existentes são
usadas.

## Contrato de controle e dano causado

`fear` é uma família de `HardControlState`, separada de root e stun. Portanto
usa a mesma resistência, `unstoppable`, teto de duração e orçamento compartilhado
de boss, inclusive sobreposição sem cobrança dupla. Fear interrompe a rota de
perseguição e impede **novas** emissões de ataque. A IA escolhe uma rota
navegável de afastamento; não atravessa obstáculos nem aceita um primeiro
waypoint significativamente mais próximo do jogador. Se nenhuma fuga segura
existir, fica parada. Root sobreposto
impede deslocamento, mas fear continua impedindo ataques; stun mantém prioridade.
Quando fear termina, a rota de fuga é descartada e a IA retoma sua lógica normal.
Projetéis já emitidos não são cancelados retroativamente.

O estado temporário de redução pertence a `CombatActor`, não ao catálogo ou
`StatCalculator`. `outgoing_damage_multiplier()` é o único ponto que compõe o
multiplicador derivado e o debuff ao **emitir** novos `DamageRequest`s de
`EnemyActor` ou `PlayerActor`. Requisições já emitidas preservam seu snapshot.
Pausa congela fear e debuff; expiração, limpeza e morte removem ambos. Essa
adição ao contrato de controle/dano emitido pede revisão de Astra no gate
proporcional.

## Integração, prova e limites

- `haunt` entra na biblioteca persistente em R0; aprender R1–R5 não equipa
  automaticamente e não altera os cinco slots ativos.
- Menu, preset, save/reload/run, HUD, mira e cancelamento do preparo acompanham
  o rank equipado. Cone e estados têm sinais visuais provisórios, sem arte final.
- `tests/e04_mage_haunt_rank_integration_test.gd` cobre ranks, SP, snapshot,
  pausa/morte/limpeza, fuga com e sem obstáculo, root, ataques interrompidos,
  imunidade e orçamento de boss, debuff em ataques novos, cone, menu e run.
  Rodar `tools/verify.ps1` completo no Godot 4.7.2.

Este pacote não cria ataques de fear contra o jogador, resistência elemental,
projéteis espirituais, augments ou arte final. Não atualizar `codex/playtest` ou
`master` aqui. Próximo checkpoint sob novo comando: MG6, Barreira Fantasma.
