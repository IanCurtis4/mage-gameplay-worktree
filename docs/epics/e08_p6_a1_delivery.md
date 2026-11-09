# E08 P6 A1 — contrato executável de feedback (Sol)

Pacote A1 do [contrato P6](e08_p6_contract.md) ([posse](e08_p6_files.json)). Checkout
`.tools/map-editor-m5`, branch `codex/e08`, sem commit/push/merge, sem checkout
habitual nem save pessoal. Aprovação técnica ≠ aceite de produto: o usuário ainda
ouve a prévia (A3) e avalia em jogo.

## O que mudou

| Arquivo | Mudança |
|---|---|
| `scripts/presentation/presentation_event_bridge.gd` | 7 kinds novos, `skill_id` em casts instantâneos, `reason` em `area_end`, `actor_variant`/`source_variant` nos payloads. Tudo por `_publish` → `emit_confirmed` (dedup, época, pausa inalterados). |
| `scripts/presentation/feedback_recipe_catalog.gd` (novo) | Catálogo constante `skill_id → {family, element, signature, audio}`; cópias em todo acesso. |
| `scripts/presentation/audio_event_catalog.gd` | 13 cues existentes intactos; 75 cues planejados (`PLANNED`) família × elemento + assinaturas; cadeia de candidatos com fallback. |
| `scripts/presentation/audio_service.gd` | Seleção (kind, receita) → cue mais específico disponível; variação determinística por `event_id`; limite de taxa de impactos antes do pool. |
| `scripts/actors/player_actor.gd` | Só o sinal `presentation_fact` e 7 emissões (sem variável nova, sem mudança de fluxo). |
| `scripts/actors/enemy_actor.gd` | Só o sinal `presentation_fact` e 2 emissões. |
| `tests/e08_feedback_recipe_test.gd` (novo), `tests/e08_presentation_test.gd`, `tests/e08_audio_test.gd` | Cobertura descrita em "Testes". |

Não foram tocados: `scripts/main.gd`, `scripts/world/player_trap.gd`,
`tests/e08_pilot_test.gd`, `tests/e08_forest_ambience_test.gd` (posse mantida, sem
necessidade). Nenhum arquivo fora da posse do A1 foi editado.

### Fronteira com o gameplay

- Atores ganham **apenas sinais** (`presentation_fact(kind, skill_id, direction,
  duration)`). Sinais não são variáveis de script, então o esquema explícito do
  `SnapshotRegistry` não muda; a única conexão é da ponte (Control), que o registro
  já ignora como alvo de apresentação. Nenhuma variável nova em atores/armadilhas.
- Emissões ficam **depois** da mudança canônica e não leem nada que a simulação
  depois consome: `_spend` emite após SP/recarga; cura emite a fonte imediatamente
  antes de `HealthState.heal` (a ponte só publica no sinal `healed`, depois da cura);
  deslocamentos espaciais emitem após a rota adotada/linha aplicada; investida após
  `_charge_remaining/_charge_cooldown`; ataque básico inimigo antes do
  `presentation_action` já existente. Nenhuma chamada de volta para gameplay.
- Sem mudança de dano, tempo, RNG, IA, colisão, recargas, save ou ordem de simulação.
  O digest de fontes do snapshot muda como em qualquer mudança de código (formato
  inalterado; snapshots de memória antigos não são reaproveitados entre builds).

## Kinds novos e payloads

Todos passam por `_publish` (dedup FIFO 2048, `presentation_epoch`, rejeição em
pausa — nenhum é kind de limpeza). Posição: âncora canônica do ator/área; caminho
legado mantém `position_unavailable` + `legacy_position_2d`.

| Kind | Quando (fato canônico) | Ator | Essencial | Payload específico |
|---|---|---|---|---|
| `melee_swing` | `presentation_action` `slash` (sempre) ou `basic_attack` cuja receita é melee (Espadachim, `enemy_claw`) | quem golpeia | não | `direction_2d`, `actor_variant`; duração = animação. Nunca implica acerto; pode sair no mesmo frame **depois** dos impactos do golpe (ex.: contraforte emite `slash` após `attack_requested`) — consumidor não infere causalidade pela ordem. |
| `movement` | `dash` 2D (Investida, Salto Cruento, Avanço de Muralha, Guarda de Retirada) e espacial (`use_world_dash`, `_use_world_travel_skill`) após rota/linha aplicada | quem se desloca | não | `phase: "start"`, `direction_2d`, duração do deslocamento; sem evento de fim. |
| `effect_start` | commit (`_spend`) de habilidade cuja receita tem `COMMIT` (buff/grito/marca/postura e explosões sem nó próprio: reprisal, nova, arco, dissipação, colapso…) | conjurador | não | contexto do cast (`target_id`, `target_anchor` ou `legacy_target_2d`), `actor_variant`. |
| `heal` | `HealthState.healed` precedido, no mesmo frame, de `heal_source` (Arrancar Fôlego, Drenagem Espiritual, Sede de Sangue) | curado | não | `amount`, `application_sequence`, `target_id`; identidade `heal/<health>/<seq>`. Regeneração contínua e recuperação de leash **não** publicam (fluxo por frame, não é feedback discreto). |
| `summon` | companheiro `is_summoned` entra na árvore após o spawn canônico (`_spawn_route_enemy`); retomada (`restoring`) nunca republica | mestre (`summoner_id`) | **sim** | `companion_id`, `actor_variant` do mestre; `skill_id = enemy_summon`. |
| `charge_start` | `EnemyActor._try_charge` depois de armar a investida | investidor | **sim** | `target_id`, `direction` (3D) ou `direction_2d`, duração `CHARGE_SECONDS`; `skill_id = enemy_charge`. |
| `trap_trigger` | sinal `removed` com `REASON_TRIGGERED` (emitido depois de todos os handlers de `triggered`, efeito já aplicado) | dono da armadilha | **sim** | `target_id` (vítima), `reason: "trigger"`, `entity_id`, geometria da área. Expiração nunca publica. |

Mudanças em kinds existentes:

- `cast_start` de jogador: `skill_id` passa a ser a habilidade comprometida no mesmo
  frame quando não há cast temporizado (`payload.instant: true`); casts temporizados
  mantêm `active_cast_skill` (`instant: false`). Era vazio antes do P6.
- `area_end.payload.reason`: `trigger` | `expire` | `cleanup`, quando o nó informa
  (armadilha por `removal_reason`; Abrigo por `REASON_EXPIRED`; Chuva por volleys
  emitidos; paredes por `remaining`). Removido antes do fim natural = `cleanup`.
- `actor_variant` (classe do jogador ou `mob_base_id`) em eventos de ator;
  `source_variant` em `impact`/`projectile_launch`/`area_*`/`trap_trigger` quando a
  fonte é um ator observado. Servem só para escolher a variante da receita.

Dica de commit: `presentation_fact(&"skill_committed")` grava, na própria ponte,
a habilidade do frame atual; ela é consumida pela primeira `presentation_action`
seguinte do mesmo ator e expira no frame seguinte. `basic_attack` de ator sem
identidade (fixture `CombatActor`) não vira golpe. Risco residual documentado: um
commit sem ação própria seguido, no mesmo frame, por um básico desse ator rotularia
o básico com a habilidade anterior (o básico de projétil continua sem golpe).

## Catálogo de receitas

`FeedbackRecipeCatalog.recipe(skill_id, variant := &"")` devolve uma cópia:
`skill_id, variant, family, element, signature, is_signature, signature_kind,
commit_effect, periodic, generic, audio` (`audio` = cadeia de candidatos por kind).
`for_event(event)` usa `actor_variant`/`source_variant` e aplica
`element_override(recipe, payload)`: `payload.element` (String/StringName) vence só se
for um dos 9 elementos — gancho para Elementalista/Geômetra; a ponte ainda não
preenche esse campo (ver Limitações). Ids desconhecidos → receita genérica
(`generic: true`), que mantém o áudio anterior ao P6 (cue só pelo kind).

Famílias: cast, projectile, melee, impact, area, trap, buff, heal, movement, summon,
charge, teleport, death, revive. Elementos: physical, fire, ice, lightning, arcane,
spirit, nature, geometry, blood. Cobertura: as 71 ativas de `profile_catalog`
(lidas pela API pública por identidade + evoluções), 3 variantes de `basic_attack`,
`enemy_claw`, `enemy_arrow`, `enemy_charge`, `enemy_summon` (variante Guardião) e os
ids derivados que aparecem em impactos/curas (`cone_slash`, `burn_tick`,
`bleed_tick`, `berserker_blood_rift_tick`, `berserker_rupture_detonation`,
`hunter_thorn_bleed`, `hunter_exploit`, `geometer_*` derivados, `blood_thirst`).

Assinaturas (contrato "Assinaturas propostas"), cada uma ligada ao kind que a
habilidade realmente emite: Mago `mage_fireball` (impact), `mage_teleport`
(teleport) · Espadachim `swordsman_slash` (melee_swing),
`swordsman_terrifying_shout` (effect_start) · Arqueiro `archer_arrow_rain`
(area_start), `archer_explosive_trap` (trap_trigger) · Defensor
`defender_reprisal_wave` (effect_start), `defender_counterstroke` (melee_swing) ·
Berserker `berserker_blood_rift` (melee_swing), `berserker_wound_leap` (movement) ·
Elementalista `elementalist_tri_nova`, `elementalist_lightning_arc` (effect_start) ·
Espiritualista `spiritualist_dissipation` (effect_start; arte própria preservada) ·
Geômetra `geometer_collapse` (effect_start), `geometer_triangulation`
(projectile_launch) · Sentinela `sentinel_explosive_shot` (impact),
`sentinel_headshot` (projectile_launch) · Caçador `hunter_freezing_trap`
(trap_trigger), `hunter_covering_shot` (projectile_launch) · Guardião
`warden_charge` (charge_start), `warden_summon` (summon).

### Tabela de receitas (fonte: `RECIPES`)

| skill_id | família | elemento | assinatura | flags |
|---|---|---|---|---|
| `slash` | melee | physical | `swordsman_slash` | — |
| `cone_slash` | melee | physical | `swordsman_slash` | — |
| `dash` | movement | physical | — | — |
| `shield_wall` | buff | physical | — | effect_start no commit |
| `provoke` | buff | physical | — | effect_start no commit |
| `perseverance` | buff | physical | — | effect_start no commit |
| `piercing_shout` | buff | physical | — | effect_start no commit |
| `fury` | buff | blood | — | effect_start no commit |
| `brutal_strike` | melee | physical | — | — |
| `concentrated_rage` | melee | physical | — | — |
| `terrifying_shout` | buff | physical | `swordsman_terrifying_shout` | effect_start no commit |
| `fireball` | projectile | fire | `mage_fireball` | — |
| `fire_wall` | area | fire | — | — |
| `fire_spear` | projectile | fire | — | — |
| `ice_spear` | projectile | ice | — | — |
| `lightning` | projectile | lightning | — | — |
| `electric_discharge` | projectile | lightning | — | — |
| `lightning_wall` | area | lightning | — | — |
| `soul_impact` | impact | spirit | — | effect_start no commit |
| `haunt` | area | spirit | — | effect_start no commit |
| `phantom_barrier` | area | spirit | — | — |
| `ice_wall` | area | ice | — | — |
| `teleport` | teleport | arcane | `mage_teleport` | — |
| `burn_tick` | impact | fire | — | periódico (DOT) |
| `double_shot` | projectile | physical | — | — |
| `piercing_arrow` | projectile | physical | — | — |
| `arrow_rain` | area | physical | `archer_arrow_rain` | — |
| `extended_aim` | buff | physical | — | effect_start no commit |
| `snare_trap` | trap | nature | — | — |
| `explosive_trap` | trap | fire | `archer_explosive_trap` | — |
| `slowing_arrow` | projectile | nature | — | — |
| `foliage_shelter` | area | nature | — | — |
| `defender_counterstroke` | melee | physical | `defender_counterstroke` | — |
| `defender_anchor` | buff | physical | — | effect_start no commit |
| `defender_line_lock` | melee | physical | — | — |
| `defender_wall_advance` | movement | physical | — | — |
| `defender_reprisal_wave` | area | physical | `defender_reprisal_wave` | effect_start no commit |
| `defender_riposte` | melee | physical | — | — |
| `defender_retreat_guard` | movement | physical | — | — |
| `berserker_rupture` | melee | blood | — | — |
| `berserker_rupture_detonation` | impact | blood | — | — |
| `berserker_wound_leap` | movement | blood | `berserker_wound_leap` | — |
| `berserker_execution` | melee | blood | — | — |
| `berserker_blood_rift` | area | blood | `berserker_blood_rift` | — |
| `berserker_blood_rift_tick` | impact | blood | — | periódico (DOT) |
| `berserker_breath_steal` | melee | blood | — | — |
| `berserker_pursuit_cut` | melee | blood | — | — |
| `bleed_tick` | impact | blood | — | periódico (DOT) |
| `blood_thirst` | heal | blood | — | — |
| `elementalist_flame_burst` | area | fire | — | effect_start no commit |
| `elementalist_glacial_ring` | area | ice | — | effect_start no commit |
| `elementalist_lightning_arc` | impact | lightning | `elementalist_lightning_arc` | effect_start no commit |
| `elementalist_ember_path` | area | fire | — | effect_start no commit |
| `elementalist_tri_nova` | area | arcane | `elementalist_tri_nova` | effect_start no commit |
| `spiritualist_echo_curse` | impact | spirit | — | effect_start no commit |
| `spiritualist_soul_drain` | impact | spirit | — | — |
| `spiritualist_spectral_veil` | area | spirit | — | effect_start no commit |
| `spiritualist_procession` | impact | spirit | — | effect_start no commit |
| `spiritualist_dissipation` | area | spirit | `spiritualist_dissipation` | effect_start no commit |
| `geometer_trace` | projectile | geometry | — | — |
| `geometer_translation` | cast | geometry | — | effect_start no commit |
| `geometer_triangulation` | projectile | geometry | `geometer_triangulation` | — |
| `geometer_collapse` | area | geometry | `geometer_collapse` | effect_start no commit |
| `geometer_rewrite` | cast | geometry | — | effect_start no commit |
| `geometer_triangle_maintenance` | impact | geometry | — | periódico (DOT) |
| `geometer_incidence` | impact | geometry | — | — |
| `geometer_wall_entry` | impact | geometry | — | — |
| `geometer_wall_exit` | impact | geometry | — | — |
| `sentinel_headshot` | projectile | physical | `sentinel_headshot` | — |
| `sentinel_observe` | buff | physical | — | effect_start no commit |
| `sentinel_piercing_shot` | projectile | physical | — | — |
| `sentinel_net_shot` | projectile | physical | — | — |
| `sentinel_explosive_shot` | projectile | fire | `sentinel_explosive_shot` | — |
| `sentinel_concussion_shot` | projectile | physical | — | — |
| `sentinel_absolute_focus` | buff | physical | — | effect_start no commit |
| `hunter_freezing_trap` | trap | ice | `hunter_freezing_trap` | — |
| `hunter_tar_trap` | trap | nature | — | — |
| `hunter_thorn_trap` | trap | nature | — | — |
| `hunter_mark` | buff | nature | — | effect_start no commit |
| `hunter_covering_shot` | projectile | physical | `hunter_covering_shot` | — |
| `hunter_total_cover` | area | nature | — | — |
| `hunter_thorn_bleed` | impact | nature | — | periódico (DOT) |
| `hunter_exploit` | impact | physical | — | — |
| `basic_attack` | melee | physical | — | — |
| `enemy_claw` | melee | physical | — | — |
| `enemy_arrow` | projectile | physical | — | — |
| `enemy_charge` | charge | physical | — | — |
| `enemy_summon` | summon | nature | — | — |

## Áudio

- **Preservado:** 4 canais (general/effects/interface/ambience), 32 vozes (24/4/4),
  `max_polyphony = 1`, prioridades e paths dos 13 cues, limiter nativo (−1,01 dB,
  release 0,1 s, pré-ganho 0), pausa (mundo PAUSABLE, interface ALWAYS), dedup FIFO
  por época, retomada só com o ambiente atual, ambiente por bioma.
- **Seleção:** `select_cue(kind, recipe)` percorre `AudioEventCatalog.candidates`:
  assinatura (se `signature_kind == kind`) → família × elemento → família × physical
  → cue atual do kind (`for_kind`, ou `KIND_FALLBACK`: `trap_trigger → world.area_end`).
  Cue planejado só é elegível se houver stream injetado ou WAV no disco
  (`ResourceLoader.exists`, cache por id); cues de `EVENTS` continuam sempre
  elegíveis (WAV ausente segue em `missing_samples`). Antes dos WAVs do A3 o jogo
  soa como hoje; kinds novos sem cue ficam em silêncio (status quo: não existiam).
- **Regras de mix novas:** `area_end` com `reason == "trigger"` é silencioso (o som
  sai em `trap_trigger`, mesmo frame); cast instantâneo de buff toca o cue de cast e o
  `effect_start` toca o de buff (camadas — A3 deve manter `p6.cast.*` curtos e
  discretos).
- **`ids()`:** os 13 de `EVENTS` + planejados **cujo WAV existe**. Assim os testes
  que exigem WAV válido para todo `ids()` (`e08_pilot_test`, prova nativa de mix)
  continuam válidos e passam a cobrir cada cue do A3 assim que o WAV for criado.
  `planned_cue_ids()` lista os 75; `definition()` devolve cópia de ambos.
- **Variação:** só canal effects; `variation_for(event_id)` semeia um
  `RandomNumberGenerator` local com `event_id.hash()` (nunca o RNG global): altura
  1 ± 0,04, volume ± 1,5 dB, idêntica para o mesmo evento. Interface/ambiente: 1,0 e
  0 dB. (Contrato P2 dizia "pitch/ganho 1"; P6 muda isso por decisão do usuário.)
- **Limite de taxa de impactos** (relógio visual da ponte, congelado na pausa;
  antes do pool, contado em `diagnostics().rate_limited`): mesmo `skill_id` + mesmo
  `target_id` no máx. 1 voz a cada 0,10 s (0,40 s para receitas periódicas/DOT);
  uma habilidade abre no máx. 3 vozes de impacto por janela de 0,06 s (vários alvos).
  Memória limitada a 256 chaves, limpa na troca de estágio. Impactos sem `target_id`
  (DTO manual/fixture) não são agrupados — todo impacto da ponte tem `target_id`.

## Lista final de cues para o A3 (Terra)

75 WAVs, todos one-shot, 44,1 kHz, mono, PCM16, sem loop, canal effects, em
`res://assets/audio/e08/p6/`. Regras de síntese do contrato: ruído filtrado em
camadas, transientes, famílias por elemento/entrega, sem amostras externas nem
música; pico < 0 dBFS com folga (o limiter protege a soma, não o sample). Os 11
one-shots atuais podem ser regenerados no mesmo estilo mantendo ids/paths.

| ID | Path | Família | Elemento | Kind | Prioridade | Caráter |
|---|---|---|---|---|---:|---|
| `p6.cast.arcane` | `res://assets/audio/e08/p6/cast_arcane.wav` | cast | arcane | cast_start | 20 | preparação/conjuração curta (0,25–0,4 s), ataque suave; brilho tonal com modulação suave |
| `p6.cast.blood` | `res://assets/audio/e08/p6/cast_blood.wav` | cast | blood | cast_start | 20 | preparação/conjuração curta (0,25–0,4 s), ataque suave; golpe úmido grave, ruído surdo |
| `p6.cast.fire` | `res://assets/audio/e08/p6/cast_fire.wav` | cast | fire | cast_start | 20 | preparação/conjuração curta (0,25–0,4 s), ataque suave; crepitar e sopro de chama, passa-banda médio-grave |
| `p6.cast.geometry` | `res://assets/audio/e08/p6/cast_geometry.wav` | cast | geometry | cast_start | 20 | preparação/conjuração curta (0,25–0,4 s), ataque suave; pulso tonal limpo (senoides compostas) com ruído leve |
| `p6.cast.ice` | `res://assets/audio/e08/p6/cast_ice.wav` | cast | ice | cast_start | 20 | preparação/conjuração curta (0,25–0,4 s), ataque suave; cristal e estalo agudo, ressonância brilhante |
| `p6.cast.lightning` | `res://assets/audio/e08/p6/cast_lightning.wav` | cast | lightning | cast_start | 20 | preparação/conjuração curta (0,25–0,4 s), ataque suave; estalo elétrico agudo com zumbido curto |
| `p6.cast.nature` | `res://assets/audio/e08/p6/cast_nature.wav` | cast | nature | cast_start | 20 | preparação/conjuração curta (0,25–0,4 s), ataque suave; folhas/galhos/terra, ruído orgânico |
| `p6.cast.physical` | `res://assets/audio/e08/p6/cast_physical.wav` | cast | physical | cast_start | 20 | preparação/conjuração curta (0,25–0,4 s), ataque suave; madeira/metal/couro, ruído filtrado seco |
| `p6.cast.spirit` | `res://assets/audio/e08/p6/cast_spirit.wav` | cast | spirit | cast_start | 20 | preparação/conjuração curta (0,25–0,4 s), ataque suave; sussurro etéreo, ruído filtrado com cauda curta |
| `p6.projectile.arcane` | `res://assets/audio/e08/p6/projectile_arcane.wav` | projectile | arcane | projectile_launch | 10 | lançamento/disparo (0,15–0,3 s) com transiente de saída; brilho tonal com modulação suave |
| `p6.projectile.fire` | `res://assets/audio/e08/p6/projectile_fire.wav` | projectile | fire | projectile_launch | 10 | lançamento/disparo (0,15–0,3 s) com transiente de saída; crepitar e sopro de chama, passa-banda médio-grave |
| `p6.projectile.geometry` | `res://assets/audio/e08/p6/projectile_geometry.wav` | projectile | geometry | projectile_launch | 10 | lançamento/disparo (0,15–0,3 s) com transiente de saída; pulso tonal limpo (senoides compostas) com ruído leve |
| `p6.projectile.ice` | `res://assets/audio/e08/p6/projectile_ice.wav` | projectile | ice | projectile_launch | 10 | lançamento/disparo (0,15–0,3 s) com transiente de saída; cristal e estalo agudo, ressonância brilhante |
| `p6.projectile.lightning` | `res://assets/audio/e08/p6/projectile_lightning.wav` | projectile | lightning | projectile_launch | 10 | lançamento/disparo (0,15–0,3 s) com transiente de saída; estalo elétrico agudo com zumbido curto |
| `p6.projectile.nature` | `res://assets/audio/e08/p6/projectile_nature.wav` | projectile | nature | projectile_launch | 10 | lançamento/disparo (0,15–0,3 s) com transiente de saída; folhas/galhos/terra, ruído orgânico |
| `p6.projectile.physical` | `res://assets/audio/e08/p6/projectile_physical.wav` | projectile | physical | projectile_launch | 10 | lançamento/disparo (0,15–0,3 s) com transiente de saída; madeira/metal/couro, ruído filtrado seco |
| `p6.melee.blood` | `res://assets/audio/e08/p6/melee_blood.wav` | melee | blood | melee_swing | 35 | golpe/whoosh corpo a corpo (0,15–0,25 s), sem som de acerto; golpe úmido grave, ruído surdo |
| `p6.melee.physical` | `res://assets/audio/e08/p6/melee_physical.wav` | melee | physical | melee_swing | 35 | golpe/whoosh corpo a corpo (0,15–0,25 s), sem som de acerto; madeira/metal/couro, ruído filtrado seco |
| `p6.impact.arcane` | `res://assets/audio/e08/p6/impact_arcane.wav` | impact | arcane | impact | 40 | acerto (0,15–0,35 s), transiente forte e cauda curta; brilho tonal com modulação suave |
| `p6.impact.blood` | `res://assets/audio/e08/p6/impact_blood.wav` | impact | blood | impact | 40 | acerto (0,15–0,35 s), transiente forte e cauda curta; golpe úmido grave, ruído surdo |
| `p6.impact.fire` | `res://assets/audio/e08/p6/impact_fire.wav` | impact | fire | impact | 40 | acerto (0,15–0,35 s), transiente forte e cauda curta; crepitar e sopro de chama, passa-banda médio-grave |
| `p6.impact.geometry` | `res://assets/audio/e08/p6/impact_geometry.wav` | impact | geometry | impact | 40 | acerto (0,15–0,35 s), transiente forte e cauda curta; pulso tonal limpo (senoides compostas) com ruído leve |
| `p6.impact.ice` | `res://assets/audio/e08/p6/impact_ice.wav` | impact | ice | impact | 40 | acerto (0,15–0,35 s), transiente forte e cauda curta; cristal e estalo agudo, ressonância brilhante |
| `p6.impact.lightning` | `res://assets/audio/e08/p6/impact_lightning.wav` | impact | lightning | impact | 40 | acerto (0,15–0,35 s), transiente forte e cauda curta; estalo elétrico agudo com zumbido curto |
| `p6.impact.nature` | `res://assets/audio/e08/p6/impact_nature.wav` | impact | nature | impact | 40 | acerto (0,15–0,35 s), transiente forte e cauda curta; folhas/galhos/terra, ruído orgânico |
| `p6.impact.physical` | `res://assets/audio/e08/p6/impact_physical.wav` | impact | physical | impact | 40 | acerto (0,15–0,35 s), transiente forte e cauda curta; madeira/metal/couro, ruído filtrado seco |
| `p6.impact.spirit` | `res://assets/audio/e08/p6/impact_spirit.wav` | impact | spirit | impact | 40 | acerto (0,15–0,35 s), transiente forte e cauda curta; sussurro etéreo, ruído filtrado com cauda curta |
| `p6.dot.blood` | `res://assets/audio/e08/p6/dot_blood.wav` | dot | blood | impact | 15 | tique periódico discreto (até 0,15 s), nível baixo; golpe úmido grave, ruído surdo |
| `p6.dot.fire` | `res://assets/audio/e08/p6/dot_fire.wav` | dot | fire | impact | 15 | tique periódico discreto (até 0,15 s), nível baixo; crepitar e sopro de chama, passa-banda médio-grave |
| `p6.dot.geometry` | `res://assets/audio/e08/p6/dot_geometry.wav` | dot | geometry | impact | 15 | tique periódico discreto (até 0,15 s), nível baixo; pulso tonal limpo (senoides compostas) com ruído leve |
| `p6.dot.nature` | `res://assets/audio/e08/p6/dot_nature.wav` | dot | nature | impact | 15 | tique periódico discreto (até 0,15 s), nível baixo; folhas/galhos/terra, ruído orgânico |
| `p6.area.arcane` | `res://assets/audio/e08/p6/area_arcane.wav` | area | arcane | area_start | 20 | abertura de área/explosão de efeito (0,4–0,8 s); brilho tonal com modulação suave |
| `p6.area.blood` | `res://assets/audio/e08/p6/area_blood.wav` | area | blood | area_start | 20 | abertura de área/explosão de efeito (0,4–0,8 s); golpe úmido grave, ruído surdo |
| `p6.area.fire` | `res://assets/audio/e08/p6/area_fire.wav` | area | fire | area_start | 20 | abertura de área/explosão de efeito (0,4–0,8 s); crepitar e sopro de chama, passa-banda médio-grave |
| `p6.area.geometry` | `res://assets/audio/e08/p6/area_geometry.wav` | area | geometry | area_start | 20 | abertura de área/explosão de efeito (0,4–0,8 s); pulso tonal limpo (senoides compostas) com ruído leve |
| `p6.area.ice` | `res://assets/audio/e08/p6/area_ice.wav` | area | ice | area_start | 20 | abertura de área/explosão de efeito (0,4–0,8 s); cristal e estalo agudo, ressonância brilhante |
| `p6.area.lightning` | `res://assets/audio/e08/p6/area_lightning.wav` | area | lightning | area_start | 20 | abertura de área/explosão de efeito (0,4–0,8 s); estalo elétrico agudo com zumbido curto |
| `p6.area.nature` | `res://assets/audio/e08/p6/area_nature.wav` | area | nature | area_start | 20 | abertura de área/explosão de efeito (0,4–0,8 s); folhas/galhos/terra, ruído orgânico |
| `p6.area.physical` | `res://assets/audio/e08/p6/area_physical.wav` | area | physical | area_start | 20 | abertura de área/explosão de efeito (0,4–0,8 s); madeira/metal/couro, ruído filtrado seco |
| `p6.area.spirit` | `res://assets/audio/e08/p6/area_spirit.wav` | area | spirit | area_start | 20 | abertura de área/explosão de efeito (0,4–0,8 s); sussurro etéreo, ruído filtrado com cauda curta |
| `p6.trap.fire` | `res://assets/audio/e08/p6/trap_fire.wav` | trap | fire | trap_trigger | 45 | disparo de armadilha (0,2–0,4 s): estalo mecânico + elemento; crepitar e sopro de chama, passa-banda médio-grave |
| `p6.trap.ice` | `res://assets/audio/e08/p6/trap_ice.wav` | trap | ice | trap_trigger | 45 | disparo de armadilha (0,2–0,4 s): estalo mecânico + elemento; cristal e estalo agudo, ressonância brilhante |
| `p6.trap.nature` | `res://assets/audio/e08/p6/trap_nature.wav` | trap | nature | trap_trigger | 45 | disparo de armadilha (0,2–0,4 s): estalo mecânico + elemento; folhas/galhos/terra, ruído orgânico |
| `p6.buff.blood` | `res://assets/audio/e08/p6/buff_blood.wav` | buff | blood | effect_start | 30 | ativação de buff/grito/marca/postura (0,3–0,6 s); golpe úmido grave, ruído surdo |
| `p6.buff.nature` | `res://assets/audio/e08/p6/buff_nature.wav` | buff | nature | effect_start | 30 | ativação de buff/grito/marca/postura (0,3–0,6 s); folhas/galhos/terra, ruído orgânico |
| `p6.buff.physical` | `res://assets/audio/e08/p6/buff_physical.wav` | buff | physical | effect_start | 30 | ativação de buff/grito/marca/postura (0,3–0,6 s); madeira/metal/couro, ruído filtrado seco |
| `p6.heal.blood` | `res://assets/audio/e08/p6/heal_blood.wav` | heal | blood | heal | 35 | cura (0,3–0,5 s), brilho ascendente; golpe úmido grave, ruído surdo |
| `p6.heal.spirit` | `res://assets/audio/e08/p6/heal_spirit.wav` | heal | spirit | heal | 35 | cura (0,3–0,5 s), brilho ascendente; sussurro etéreo, ruído filtrado com cauda curta |
| `p6.movement.blood` | `res://assets/audio/e08/p6/movement_blood.wav` | movement | blood | movement | 30 | deslocamento (0,2–0,35 s), ar/passos rápidos; golpe úmido grave, ruído surdo |
| `p6.movement.physical` | `res://assets/audio/e08/p6/movement_physical.wav` | movement | physical | movement | 30 | deslocamento (0,2–0,35 s), ar/passos rápidos; madeira/metal/couro, ruído filtrado seco |
| `p6.summon.nature` | `res://assets/audio/e08/p6/summon_nature.wav` | summon | nature | summon | 55 | chamado de invocação (0,6–1,0 s); folhas/galhos/terra, ruído orgânico |
| `p6.charge.nature` | `res://assets/audio/e08/p6/charge_nature.wav` | charge | nature | charge_start | 55 | investida inimiga (0,4–0,6 s), aviso grave crescente; folhas/galhos/terra, ruído orgânico |
| `p6.charge.physical` | `res://assets/audio/e08/p6/charge_physical.wav` | charge | physical | charge_start | 55 | investida inimiga (0,4–0,6 s), aviso grave crescente; madeira/metal/couro, ruído filtrado seco |
| `p6.teleport.arcane` | `res://assets/audio/e08/p6/teleport_arcane.wav` | teleport | arcane | teleport | 50 | teleporte (0,3–0,5 s), sucção e reaparição; brilho tonal com modulação suave |
| `p6.sig.mage_fireball` | `res://assets/audio/e08/p6/sig_mage_fireball.wav` | signature | fire | impact | 45 | explosão de bola de fogo: estouro grave + crepitar longo |
| `p6.sig.mage_teleport` | `res://assets/audio/e08/p6/sig_mage_teleport.wav` | signature | arcane | teleport | 55 | teleporte do Mago: sucção arcana + reaparição cintilante |
| `p6.sig.swordsman_slash` | `res://assets/audio/e08/p6/sig_swordsman_slash.wav` | signature | physical | melee_swing | 40 | corte em cone: whoosh largo de lâmina com brilho metálico |
| `p6.sig.swordsman_terrifying_shout` | `res://assets/audio/e08/p6/sig_swordsman_terrifying_shout.wav` | signature | physical | effect_start | 35 | grito aterrorizante: rugido grave filtrado com tremor |
| `p6.sig.archer_arrow_rain` | `res://assets/audio/e08/p6/sig_archer_arrow_rain.wav` | signature | physical | area_start | 25 | chuva de flechas: assobio crescente de muitas flechas |
| `p6.sig.archer_explosive_trap` | `res://assets/audio/e08/p6/sig_archer_explosive_trap.wav` | signature | fire | trap_trigger | 50 | armadilha explosiva: clique + explosão seca de fogo |
| `p6.sig.defender_reprisal_wave` | `res://assets/audio/e08/p6/sig_defender_reprisal_wave.wav` | signature | physical | effect_start | 35 | onda de represália: impacto de escudo + onda grave |
| `p6.sig.defender_counterstroke` | `res://assets/audio/e08/p6/sig_defender_counterstroke.wav` | signature | physical | melee_swing | 40 | contraforte: pancada de escudo e lâmina, curta e pesada |
| `p6.sig.berserker_blood_rift` | `res://assets/audio/e08/p6/sig_berserker_blood_rift.wav` | signature | blood | melee_swing | 40 | fenda sangrenta: rasgo úmido grave ao longo do chão |
| `p6.sig.berserker_wound_leap` | `res://assets/audio/e08/p6/sig_berserker_wound_leap.wav` | signature | blood | movement | 35 | salto cruento: impulso + aterrissagem úmida |
| `p6.sig.elementalist_tri_nova` | `res://assets/audio/e08/p6/sig_elementalist_tri_nova.wav` | signature | arcane | effect_start | 35 | nova tríplice: três camadas (fogo, gelo, raio) em sequência rápida |
| `p6.sig.elementalist_lightning_arc` | `res://assets/audio/e08/p6/sig_elementalist_lightning_arc.wav` | signature | lightning | effect_start | 35 | arco voltaico: estalo elétrico encadeado |
| `p6.sig.spiritualist_dissipation` | `res://assets/audio/e08/p6/sig_spiritualist_dissipation.wav` | signature | spirit | effect_start | 35 | rito de dissipação: coro etéreo que se desfaz |
| `p6.sig.geometer_collapse` | `res://assets/audio/e08/p6/sig_geometer_collapse.wav` | signature | geometry | effect_start | 35 | colapso geométrico: acorde tonal que implode |
| `p6.sig.geometer_triangulation` | `res://assets/audio/e08/p6/sig_geometer_triangulation.wav` | signature | geometry | projectile_launch | 15 | triangulação: três pulsos tonais em arpejo ao disparar |
| `p6.sig.sentinel_explosive_shot` | `res://assets/audio/e08/p6/sig_sentinel_explosive_shot.wav` | signature | fire | impact | 45 | disparo explosivo: impacto + estouro de fogo |
| `p6.sig.sentinel_headshot` | `res://assets/audio/e08/p6/sig_sentinel_headshot.wav` | signature | physical | projectile_launch | 15 | tiro na cabeça: estalo de corda forte e seco |
| `p6.sig.hunter_freezing_trap` | `res://assets/audio/e08/p6/sig_hunter_freezing_trap.wav` | signature | ice | trap_trigger | 50 | armadilha congelante: clique + cristalização rápida |
| `p6.sig.hunter_covering_shot` | `res://assets/audio/e08/p6/sig_hunter_covering_shot.wav` | signature | physical | projectile_launch | 15 | tiro de cobertura: disparo abafado com folhagem |
| `p6.sig.warden_charge` | `res://assets/audio/e08/p6/sig_warden_charge.wav` | signature | nature | charge_start | 60 | investida do Guardião: passos pesados e rugido de madeira |
| `p6.sig.warden_summon` | `res://assets/audio/e08/p6/sig_warden_summon.wav` | signature | nature | summon | 60 | invocação do Guardião: chamado grave com galhos e vento |

## Testes e evidências

Validação exclusivamente pelo wrapper `tools/e08_p6_fixture.ps1` (evidências em
`.godot/verification/p6/A1_sol_contract_*`, imutáveis; falhas intermediárias
preservadas: `a1_import_01`, `a1_recipe_probe_01`, `a1_verify_pa_01..05`,
`a1_verify_audio_01`, `a1_regression_02` (fixture desatualizada por mudança
concorrente em `tools/verify.ps1`), `a1_regression_03`, `a1_regression_04`).

**Novo teste** `tests/e08_feedback_recipe_test.gd` — **ainda não registrado em
`tools/verify.ps1`** (arquivo do coordenador): rodado por
`-Stage probe -Script res://tests/e08_feedback_recipe_test.gd -Headless`.
Cobre as 71 ativas (e 22 passivas como sanidade do inventário) lidas de
`ProfileCatalog.pilot()` por identidade + evoluções, variantes de básicos, inimigos
da floresta e Guardião, ids derivados, assinaturas exatamente iguais à lista do
contrato (1–2 por classe, kind real da ponte), imutabilidade (receita, cadeias de
áudio, assinatura, lista de ids), receita genérica e fallback, override de elemento
(válido/inválido/malformado), cobertura de áudio (todo par receita×kind produzido
tem cue planejado primeiro e termina no cue atual; todo cue planejado é alcançável),
definições planejadas (paths únicos sob `p6/`, canal effects, prioridade 0..60,
entrada em `ids()` só com WAV), os 13 cues e os limites 24/4/4 intactos.

**Extensões** (nenhuma asserção existente removida ou enfraquecida; o diff só
acrescenta linhas):

- `e08_presentation_test`: gêmeos idênticos (um observado pela ponte, outro não)
  executam Fúria, Corte, Investida, cura por abate e regeneração — HP/SP/recargas/
  posição/estado de dash/sequências iguais; cada kind novo verificado dentro do
  listener depois do fato (SP e recarga já debitados, dash ativo, HP já curado,
  estado TRIGGERED da armadilha, `_charge_remaining` armado); cast instantâneo com
  `skill_id`; recusa por recarga não publica; dica de commit expira no frame
  seguinte; pausa e época antiga rejeitam os kinds novos; retomada não reemite
  cura/movimento/invocação/investida; um único observador de `presentation_fact`;
  armadilhas `trigger`/`expire`/`cleanup` sem dano; golpe de garra vs flecha;
  invocação do Guardião essencial com mestre/companheiro; RNG do controlador e HP
  inalterados; `area_end` da Chuva removida cedo com `reason: cleanup`.
- `e08_audio_test`: seleção assinatura → família×elemento → família×physical →
  cue do kind; WAV planejado ausente cai no cue atual sem `missing_samples`; kinds
  novos sem cue silenciosos; `trap_trigger` com fallback `world.area_end`;
  `area_end` de armadilha disparada silencioso e de expirada audível; variação
  determinística, limitada (±4 %, ±1,5 dB, tolerância só do float32 do `Vector2`),
  espalhada e sem tocar o RNG global; voz de efeito usa a variação do próprio evento;
  interface/ambiente sem variação; limite de taxa (mesmo alvo, rajada multialvo,
  DOT, relógio congelado na pausa, impactos sem alvo não agrupados, nenhum drop
  extra no pool, memória zerada na troca de estágio); 4 buses e 32 vozes.

| Teste | Resultado | Evidência |
|---|---|---|
| e08_feedback_recipe_test (probe) | PASS 997 checks | `probe_a1_recipe_probe_02` |
| e08_presentation_test | PASS 2246 | `verify_a1_regression_03` (também `a1_verify_pa_07`) |
| e08_audio_test | PASS 177 | `verify_a1_regression_03` (também `a1_verify_audio_02`) |
| combat_animation_test | PASS 39 | `verify_a1_regression_03` |
| e08_pilot_ui_test | PASS 55 | `verify_a1_regression_03` |
| e08_pilot_test | 191 / 0 falhas | `verify_a1_regression_03` |
| e08_species_presentation_test | 172 / 0 | `verify_a1_regression_03` |
| e08_forest_ambience_test | 58 / 0 | `verify_a1_regression_03` |
| mage_gameplay_test | PASS 52 | `verify_a1_regression_03` |
| e04_teleport_rank_integration_test | PASS 29 | `verify_a1_regression_03` |
| e04_archer_trap_runtime_test | PASS 40 | `verify_a1_regression_03` |
| e05_hunter_traps_integration_test | 186 / 0 | `verify_a1_regression_03` |
| e04_swordsman_fury_rank_integration_test | PASS 29 | `verify_a1_regression_03` |
| e04_swordsman_blood_thirst_rank_integration_test | PASS 25 | `verify_a1_regression_03` |
| e05_spiritualist_soul_drain_test | PASS 28 | `verify_a1_regression_03` |
| e05_geometer_playtest_flow_test | PASS 28 | `verify_a1_regression_03` |
| e05_sentinel_integration_test | **FALHA** 8 checks (ver Limitações) | `verify_a1_regression_03` |
| e05_elementalist_tri_nova_test | PASS 12 | `verify_a1_regression_04` |
| e05_berserker_playtest_flow_test | PASS 21 | `verify_a1_regression_04` |
| e05_defender_playtest_flow_test | PASS 18 | `verify_a1_regression_04` |
| e06_tx_mob_test | 27 / 0 | `verify_a1_regression_04` |
| e06_rx_mob_ai_test | 4 / 0 | `verify_a1_regression_04` |
| e07_f7_presentation_test | 27 / 0 | `verify_a1_regression_04` |
| e07_f3_snapshot_test | 52 / 0 | `verify_a1_regression_04` |
| e07_f3_continuation_test | 2743 / 0 (30 cenários) | `verify_a1_regression_04` |
| e07_f3_action_matrix_test | 2004 / 0 (21 cenários) | `verify_a1_regression_04` |
| e07_f3_lifecycle_test | 90 / 0 | `verify_a1_regression_04` |
| e07_f3_mob_state_test | 372 / 0 | `verify_a1_regression_04` |
| e07_f1_hunter_traps_test | 631 / 0 | `verify_a1_regression_04` |
| e07_f1_presentation_test | 39 / 0 (aviso de vazamento na saída em `regression_04`; limpo em `probe_a1_f1pres_probe_01/02` e `verify_a1_regression_05`) | ver Limitações |
| e08_p5_world_republish_test | 63 / 63 ok | `verify_a1_regression_05` |

Não foi rodada a suíte completa de `tools/verify.ps1` (324 passos); só a seleção acima.

## Limitações e pendências

- **`e05_sentinel_integration_test` falha** em 2 checks × 4 cenários: "actual identity
  selects own Sentinel atlas, not base Archer" (espera `.../sentinel_weaponless.png`)
  e "real Sentinel guide replaces generic help". Sem SCRIPT ERROR; o A1 não toca
  atlas, onboarding nem UI. O atlas direcional da Sentinela entrou no commit P4
  `fd32d346` e o teste não muda desde o E05 — provável falha pré-existente, **não
  confirmada contra a linha de base**. Encaminhar a Luna/coordenador para rodar no
  baseline; não editei a expectativa.
- `e07_f1_presentation_test`: 1 execução com "11 ObjectDB leaked / 4 resources in
  use" na saída (39/0 checks) e 3 reexecuções limpas; tratado como intermitente de
  encerramento, não reproduzido.
- `e08_feedback_recipe_test.gd` precisa ser registrado em `tools/verify.ps1`.
- Elemento por pulso (tri_nova etc.): o gancho `payload.element` existe, mas a ponte
  ainda não o preenche (o elemento não chega no resultado de dano). A2 pode usar o
  elemento da receita ou um campo futuro.
- `melee_swing` pode sair depois dos impactos do mesmo golpe; `movement` só tem
  início (`phase: "start"`); `effect_start` de buff e `cast_start` instantâneo tocam
  juntos (camadas).
- Dica de commit por frame: um commit sem ação seguido, no mesmo frame, de ação do
  mesmo ator rotularia essa ação; básicos de projétil continuam sem golpe.
- Mapa assinatura → flipbook do B1 (`vfx_flipbook_catalog`) não foi definido aqui;
  é do consumidor A2.
- `e08_pilot_feedback.gd` ainda ignora os kinds novos (fica para o A2).
- O digest de fontes do snapshot muda (como em qualquer mudança de script); o
  formato e o esquema não mudam.
