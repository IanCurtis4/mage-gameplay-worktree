# E04-SW1 — Parede de Escudos

Base: `22fab75`. Escopo: somente SW1 do
[contrato aprovado](E04_SWORDSMAN_EXPANSION_PACKAGES.md). Não inicia SW2,
SWI, MGI ou E05.

## Design

Postura instantânea e puramente defensiva. Arco frontal de 130° (65° por
lado), raio 34 em torno do corpo, fixado na direção da ativação e seguindo a
posição do Espadachim. Movimento e Investida não reduzem velocidade nem giram
a frente. Dura até 6 s; reduz em 30% o dano direto de uma fonte situada no
arco frontal, usando cópia do `DamageRequest` antes do resolver canônico.
Flancos/costas e dano secundário não recebem mitigação. Não altera navegação.

Cada projétil inimigo que atinge o arco antes do corpo consome uma carga e é
destruído. A última carga encerra a postura. Barreira Fantasma mais próxima e
obstáculo estático anterior têm precedência e não gastam cargas. Recarga base
de 12 s começa na ativação. Reativar enquanto ativa desliga sem SP e sem
reiniciar recarga, mesmo com SP insuficiente.

| Rank | Cargas (`power`) | SP |
|---|---:|---:|
| R1 | 2 | 18 |
| R2 | 3 | 20 |
| R3 | 4 | 22 |
| R4 | 5 | 23 |
| R5 | 6 | 24 |

O rank melhora somente resistência. Duração, arco, mitigação e recarga ficam
fixos. R0 não é equipável; aprender não ocupa automaticamente um dos cinco
slots. Biblioteca, menu/preset, save/reload/run, HUD, mira e VFX desenhado
seguem o rank equipado. O HUD mostra cargas e toggle gratuito durante a postura.

## Ações e limpeza

`SkillDefinition.action_kind` declara ofensiva, mobilidade ou defensiva.
Corte e autoataque válidos encerram a postura antes da emissão; SP/recarga
insuficientes não encerram. Nova perseguição válida também a encerra.
Investida permanece mobilidade. Ativar a parede apaga a perseguição/auto
anterior para que não se autocancele no frame seguinte. Provocar e Perseverança
deverão declarar `DEFENSIVE` nos pacotes próprios; não foram implementadas
nem antecipadas aqui. Duração, última carga, morte, fim de encontro e resultado
limpam a postura. Pausa congela o contador.

## Evidência e limite

`tests/e04_swordsman_shield_wall_rank_integration_test.gd` cobre ranks,
R0/inválido, SP/toggle/recarga, snapshot, menu/save/reload/run, HUD/mira,
movimento/Investida, auto antigo e novo, Corte válido/inválido, dano frontal
físico/misto versus flancos/costas, projéteis rápidos e ordenação com
Barreira Fantasma/obstáculo, pausa, morte e limpeza. `tools/verify.ps1`
completo passou no Godot 4.7.2. A ordem visual/legibilidade do arco e o
balanceamento ainda exigem playtest. Não há infraestrutura de debuffs por
fonte/atributo nesta entrega; esse contrato crítico pertence ao SW2.

Não atualizar `codex/playtest` nem `master`. Próximo checkpoint somente sob
novo comando: SW2, Provocar.
