# E04-MG4 — Impacto das Almas

Base: `e62a22c`. Escopo: somente Impacto das Almas, conforme a
[sequência aprovada](E04_MAGE_EXPANSION_PACKAGES.md). Não inicia MG5.

## Design e tabela

Alvo único dentro de 400 unidades, validado no fim do preparo. O preparo
variável é 0,36 s escalado por DES; recarga base de 6 s. A emissão trava o ID
do alvo e copia o `DamageRequest` completo. O dano-base **total** é dividido
em três impactos iguais, espaçados em 0,12 s. Os pulsos não recalculam ataque,
rank, custo ou chance de acerto depois da emissão e não trocam de alvo. O alvo
pode se mover durante a sequência; morte/remoção interrompe os pulsos restantes.
Cada pulso usa a mitigação mágica canônica. Após seleção e alcance válidos, os
pulsos têm precisão geométrica e não criticam. O primeiro impacto é primário;
os dois seguintes são secundários para não multiplicar procs. Não há marca,
controle ou nova resistência espiritual neste pacote.

| Rank | Dano-base total × ataque mágico | SP |
|---|---:|---:|
| R1 | 1,35 | 19 |
| R2 | 1,58 | 21 |
| R3 | 1,78 | 23 |
| R4 | 1,95 | 24 |
| R5 | 2,10 | 25 |

O crescimento marginal de dano e SP decresce entre R1 e R5. A divisão é do
dano bruto capturado; cada pulso é mitigado e arredondado pelo resolver, portanto
a soma efetiva pode diferir de um golpe único com o mesmo dano-base total.

## Integração, prova e limites

- `soul_impact` entra na biblioteca persistente em R0. Aprender R1–R5 não
  equipa automaticamente e não altera os cinco slots ativos.
- Menu/preset/save/reload/run, HUD, mira de alvo único e cancelamento de cast
  usam o rank equipado. Os anéis de mira e de impacto são VFX provisórios.
- `tests/e04_mage_soul_impact_rank_integration_test.gd` cobre tabela,
  R0/inválido, R1/R5, SP, alcance, snapshot, pausa, divisão sem multiplicação,
  alvo móvel/morto, menu e run persistente, cancelamento, limpeza e dano real.
  Rodar `tools/verify.ps1` completo no Godot 4.7.2.

O pacote não cria projétil, dano em área, fear, debuff, resistência elemental,
augments ou arte final. `codex/playtest` e `master` permanecem intocadas. Próximo
checkpoint sob novo comando: MG5, Assombro.
