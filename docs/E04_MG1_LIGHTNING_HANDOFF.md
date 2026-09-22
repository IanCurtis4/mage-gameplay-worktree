# E04-MG1 — Relâmpago e marca Eletrizado

Base: `6059c7d`. Escopo autorizado em
[E04_MAGE_EXPANSION_PACKAGES.md](E04_MAGE_EXPANSION_PACKAGES.md). Este pacote
entrega somente Relâmpago; Descarga Elétrica, stun e consumo da marca são MG2.

## Design e tabela

Relâmpago é habilidade ativa do Mago, alvo único, projétil homing com a colisão
compartilhada das Lanças, dano mágico contestado por HIT/FLEE e crítico normal.
O preparo variável de 0,26 s usa DES e revalida alvo/alcance/SP ao concluir.
Alcance 380, velocidade 820 e recarga-base 4,0 s ficam fixos por rank. A marca
Eletrizado dura 4,0 s depois de um golpe com dano positivo; reaplicação reinicia
o tempo, sem stack, dano periódico ou stun. Morte e limpeza da run a removem.

| Rank | Dano × ataque mágico | SP |
|---|---:|---:|
| R1 | 1,25 | 16 |
| R2 | 1,43 | 18 |
| R3 | 1,60 | 20 |
| R4 | 1,75 | 21 |
| R5 | 1,90 | 22 |

O crescimento marginal de dano cai de 0,18 para 0,15; o custo marginal cai de
2 para 1. É dano intermediário entre Lança de Gelo e Lança de Fogo do mesmo rank,
com recarga maior em troca da futura sinergia de marca. Um único projétil e uma
única aplicação de marca por uso; nenhum augment de quantidade é associado.

## Integração e evidência

- `lightning` entrou na biblioteca persistente do Mago em R0, mas não nos cinco
  slots iniciais nem no kit piloto. Aprender e equipar são transações separadas.
- O menu usa o nome visível “Relâmpago”; HUD/tecla/mira consomem o preset da run.
- Marca é estado temporário de `CombatActor`, não Resource de catálogo nem save.
  Expiração respeita pausa; morte e `clear_statuses()` removem a marca.
- `tests/e04_mage_lightning_rank_integration_test.gd` cobre tabela, R0/inválido,
  R1/R5, SP/cooldown, snapshot, ciclo da marca, menu → save/reload → arena,
  cast/cancelamento/revalidação, projétil e impacto.
- Godot 4.7.2 import headless e `tools/verify.ps1` completo passaram após a
  última correção, incluindo `E04 MG1 Relâmpago: PASS (66 checks)`.

## Limites e próximo checkpoint

A marca ainda não tem consumidor; isto é intencional até MG2. Não há stun na
aplicação, detonação, nova resistência elemental, alteração de fogo/gelo ou
aprovação visual de arte final. MG2 permanece o próximo pacote, somente após
novo comando de continuidade. Não atualizar `codex/playtest`/`master` neste passo.
