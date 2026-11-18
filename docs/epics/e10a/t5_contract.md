# E10a T5 — contrato curto do módulo da base Acólito (`acolyte`)

Executora: Terra (sessão T5, Sonnet 5.5), 18/11/2026. Fontes: ficha "Família Acólito" de
[EXTENDED_CLASS_SPECS](../../EXTENDED_CLASS_SPECS.md), [e10a_contract.md](../e10a_contract.md) §1,
§4 e §4.1, decisões D2, D4 e A7, A9, A10 e A11 de [e10a.md](../e10a.md), a costura de base da T1
([t1_base_seam_api.md](t1_base_seam_api.md)) e a Loucura da T4
([t4_madness_api.md](t4_madness_api.md), [t4_contract.md](t4_contract.md)). O recibo do Sacerdote
([t6_delivery.md](t6_delivery.md)) é o exemplo de módulo pronto.

O núcleo da ficha não muda: **o Acólito ainda não escolheu lado.** Serve (luz: Luz Punitiva, Prece,
Escudo Votivo) e contempla (sombra: Selo Sombrio, Sussurro Perturbador); a Devoção premia quem
alterna. Os números abaixo são ajuste de playtest (preâmbulo do contrato do E10a) e não pedem
decisão de arquitetura.

## 1. Identidade

| Item | Valor |
|---|---|
| ID, nome | `acolyte`, "Acólito" |
| Atributos iniciais (soma 30) | INT 8, VIT 7, DEX 5, AGI 4, STR 3, LUK 3 |
| Ataque básico | mágico (`magic`), alcance 220, poder 1,0, com o livro |
| Skills iniciais (mapa plano) | Luz Punitiva e Prece |
| Passiva de partida | Fé Protetora |
| Mobilidade | nenhuma: o Sussurro afasta |
| Corpo | pasta `acolyte`; corpo de reserva `mage` enquanto não houver arte (T8) |
| Prefixo de skill, de família e de efeito | `acolyte_` |

## 2. Cinco perguntas (C3.1)

| Pergunta | Resposta |
|---|---|
| Distância | Média, de 150 a 300. Luz Punitiva e Selo a 300; o Sussurro é curto (150–190); o básico chega a 220 (mais 40–120 com a Visão Eldritch). Sem mobilidade: quem chega perto é afastado pelo Sussurro. |
| Recurso | SP. A Loucura é do inimigo, não do Acólito. O tempo das janelas (Prece 4 s, Escudo 5 s, Selo 6 s, Visão 6–10 s, Devoção 8 s). |
| Abertura e fechamento | Abre com o **Selo Sombrio** (DoT, menos precisão, Loucura) e a **Visão Eldritch**; fecha com o **Sussurro** dobrado, que empurra os comuns e leva a Loucura ao limiar; **Luz Punitiva** é o dano. |
| Contra o chefe | Selo Sombrio reduz o acerto dele e dá DoT; Sussurro e Selo somam Loucura e, no limiar, a autoridade da T4 o deixa em Desorientação (sem empurrá-lo: o chefe recusa o recuo). Prece e Escudo Votivo seguram o dano. Sem adds e sem augment o laço fecha sozinho (teste integrado). |
| Fraqueza | Dano modesto e sem mobilidade. O Delírio na base é lento: precisa de Visão Eldritch, Sussurro e Selo juntos nos ranks altos, dentro de 4 s. Contra muitos comuns, o Sussurro só ganha tempo. |

## 3. Skills e números por rank

IDs de §1 do contrato do E10a. Todos os montantes partem do `magic_attack` do `stat_breakdown`; a
defesa mágica é aplicada por `CombatMath`. Luz e sombra são dano mágico com etiqueta, sem eixo de
resistência (A2 do E09, D5). Pré-requisitos (fechados nos dados do módulo): Escudo Votivo pede Prece
1; Selo Sombrio pede Luz Punitiva 1; Sussurro pede Selo Sombrio 1; Visão Eldritch pede Sussurro 1;
Devoção pede Luz Punitiva 1 e Selo Sombrio 1; Fé Protetora pede Escudo Votivo 1. Nível de job 1 para
todas; sem rank grátis (19 pontos de base).

### Luz Punitiva — `acolyte_punishing_light` (ativa, `light`)

Alvo único, projétil mágico (`kit_emit_projectile`, entrega `mage`); acerto por geometria, pode crítico.

| R | SP | Recarga | Alcance | Poder (× MATQ) |
|---|---|---|---|---|
| 1 | 10 | 3,0 s | 300 | 1,40 |
| 2 | 11 | 3,0 s | 300 | 1,60 |
| 3 | 12 | 3,0 s | 300 | 1,80 |
| 4 | 13 | 3,0 s | 300 | 2,00 |
| 5 | 14 | 3,0 s | 300 | 2,20 |

### Prece — `acolyte_prayer` (ativa, `light`)

Própria. Cura o Acólito em 4 pulsos de 1 s; cada pulso é uma fração do HP máximo no instante do
pulso (`heal_player`, fonte `acolyte_prayer`). Recastar renova.

| R | SP | Recarga | Cura total | Por pulso |
|---|---|---|---|---|
| 1 | 14 | 10 s | 16% do HP máx. | 4,0% |
| 2 | 15 | 10 s | 20% | 5,0% |
| 3 | 16 | 10 s | 24% | 6,0% |
| 4 | 17 | 10 s | 28% | 7,0% |
| 5 | 18 | 10 s | 32% | 8,0% |

### Escudo Votivo — `acolyte_votive_shield` (ativa, `light`)

Própria. Barreira por 5 s (`HealthState.grant_shield`) com a capacidade
`StatCalculator.personal_shield_capacity(base, stats)`, a mesma da Perseverança e da Égide. Quando o
prazo acaba, o que sobrou da barreira some (só se ela ainda for a do Escudo).

| R | SP | Recarga | Base da capacidade |
|---|---|---|---|
| 1 | 14 | 9 s | 30 |
| 2 | 15 | 9 s | 42 |
| 3 | 16 | 9 s | 54 |
| 4 | 17 | 9 s | 66 |
| 5 | 18 | 9 s | 78 |

### Selo Sombrio — `acolyte_shadow_seal` (ativa, `shadow`)

Alvo único, ofensiva. Marca por 6 s (um alvo por vez; marcar outro troca o selo):
- **DoT de sombra:** um pulso por segundo, dano mágico secundário `shadow` de
  `MATQ × poder ÷ 6` por pulso (poder = total sobre os 6 s);
- **Precisão:** `add_accuracy_source` no inimigo, pela C1.7 (reduz o acerto dos golpes dele);
- **Loucura:** `MadnessAuthority.add` no commit, deduplicada pelo evento do cast. Dobrada se a
  Visão Eldritch está carregada (consome a carga).

| R | SP | Recarga | Alcance | Poder total | Acerto do inimigo | Loucura |
|---|---|---|---|---|---|---|
| 1 | 16 | 8 s | 300 | 0,60 | −20% | 18 |
| 2 | 17 | 8 s | 300 | 0,75 | −24% | 20 |
| 3 | 18 | 8 s | 300 | 0,90 | −28% | 22 |
| 4 | 19 | 8 s | 300 | 1,05 | −32% | 24 |
| 5 | 20 | 8 s | 300 | 1,20 | −36% | 26 |

O DoT é um pedido secundário guardado no módulo (`seal_prototype`, com a raiz causal do cast) e
repetido por `scheduled_tick()`, como a queimadura do Santuário. O burn do `CombatActor` não serve:
perderia a etiqueta `shadow` e desenharia fogo.

### Sussurro Perturbador — `acolyte_disturbing_whisper` (ativa, `shadow`)

Alvo único (a mira define a direção); cone curto a partir do Acólito, semiângulo de 50°, alcance
= `range` do rank. Cada inimigo no cone (nos dois caminhos, plano e mundo):
- recebe Loucura (dobrada se a Visão Eldritch está carregada, uma só vez por cast);
- se não for chefe, é empurrado (`apply_defender_push`, ou a variante do mundo). **O chefe recusa o
  empurrão e fica onde está.**
Sem dano.

| R | SP | Recarga | Alcance | Loucura por inimigo | Empurrão |
|---|---|---|---|---|---|
| 1 | 16 | 10 s | 150 | 24 | 45 |
| 2 | 17 | 10 s | 160 | 28 | 55 |
| 3 | 18 | 10 s | 170 | 32 | 65 |
| 4 | 19 | 10 s | 180 | 36 | 75 |
| 5 | 20 | 10 s | 190 | 40 | 85 |

### Visão Eldritch — `acolyte_eldritch_vision` (ativa, sem etiqueta)

Própria, reforço curto, como a Mira Estendida do Arqueiro: enquanto dura, o alcance do ataque
básico aumenta; o **próximo** Selo Sombrio ou Sussurro dá o **dobro** de Loucura (a carga some ao
usar ou ao fim do reforço).

| R | SP | Recarga | Duração | Alcance do básico |
|---|---|---|---|---|
| 1 | 14 | 18 s | 6 s | +40 |
| 2 | 14 | 17 s | 7 s | +60 |
| 3 | 15 | 16 s | 8 s | +80 |
| 4 | 15 | 15 s | 9 s | +100 |
| 5 | 16 | 14 s | 10 s | +120 |

### Devoção — `acolyte_devotion` (passiva, R1–R3)

Lê o `context.element` de **todo** commit pago, do módulo da base ou da evolução (gancho
`on_base_skill_committed` da T1, mais o commit próprio), sem lista fixa de skills. Só `light` e
`shadow` contam; outro elemento (ou nenhum) não interrompe nem faz par. Quando um commit tem o
elemento **oposto** ao do anterior, dentro de 8 s, a **próxima** skill (qualquer uma) sai mais forte:
MATQ aumentado pela fonte temporária `acolyte_devotion` até o fim dessa skill. Alternar sempre
(luz, sombra, luz…) mantém o reforço.

| R | Reforço de MATQ |
|---|---|
| 1 | +10% |
| 2 | +15% |
| 3 | +20% |

### Fé Protetora — `acolyte_protective_faith` (passiva, R1–R3)

Cura e escudo recebidos rendem mais:
- **Cura:** toda cura reportada ao jogador (`on_heal`), de qualquer fonte, soma uma cura extra do
  mesmo tamanho pedido × bônus (fonte própria `acolyte_faith`; nunca multiplicada de novo, nem a do
  bônus do Santuário);
- **Escudo:** a capacidade do Escudo Votivo.

| R | Bônus |
|---|---|
| 1 | +10% |
| 2 | +15% |
| 3 | +20% |

## 4. Loucura (T4)

O módulo guarda a autoridade no campo `madness` (`MadnessAuthority.of` o encontra) e repassa:
`on_attach` (`configure` com `stat_source_id = acolyte_ecstasy`), `on_tick`, `on_death`,
`on_build_changed` e `snapshot_compact_blocker`. **Não** repassa `temporary_stat_sources` (só a da
Devoção), `skill_cost` nem `before_hit_mitigation` do Êxtase: o Êxtase fica desligado na base e só o
Cultista (T7) o liga. Eventos: `MadnessHelpers.cast_event(cast, kit_time)`, um por cast e por alvo.
No limiar, a autoridade põe o comum em Delírio e o chefe em Desorientação; o Delírio na base é lento
(§2, fraqueza): a Loucura espera 4 s e decai 20 por segundo.

## 5. Estado, snapshot e pausa

Variáveis do módulo (fragmento `scripts/classes/bases/acolyte/snapshot_manifest.json`, revisão 2):
`madness`, `prayer_pulses`, `prayer_tick`, `prayer_fraction`, `votive_remaining`,
`votive_capacity`, `marked_target_id`, `seal_remaining`, `seal_tick`, `seal_prototype`,
`vision_remaining`, `vision_range_bonus`, `vision_charged`, `devotion_element`,
`devotion_pair_remaining`, `devotion_bonus`, `devotion_ready_remaining`, `devotion_fresh`, `devotion_spent`, `devotion_rearm`.
- Todos os relógios avançam só em `on_tick` (congelam na pausa).
- Morte: Prece, Escudo, Selo, Visão e Devoção terminam; a autoridade trata a Loucura e o Êxtase.
- Troca de build: nada recarrega, nada cura, nada zera; só se recalculam os bônus de Devoção.
- Snapshot exato: tudo volta. Compacto: inelegível com Selo ativo (a marca e o acerto ficam no
  inimigo, que o compacto devolve sem marcas), com o Escudo Votivo ativo ou com o Ídolo (T4).

## 6. Efeitos em código e IDs de flipbook reservados (C3.4)

| ID | Skill | Tipo do evento |
|---|---|---|
| `acolyte_light_bolt` | Luz Punitiva | `impact` |
| `acolyte_prayer_glow` | Prece | `effect_start` |
| `acolyte_votive_ward` | Escudo Votivo | `effect_start` |
| `acolyte_seal_mark` | Selo Sombrio | `effect_start` |
| `acolyte_whisper_wave` | Sussurro | `effect_start` |
| `acolyte_vision_eye` | Visão Eldritch | `effect_start` |

Receitas de feedback: Luz Punitiva `projectile` + `light`; Prece `buff` + `light` (sem periódica: não gera golpe, e `heal`/periódica caem em lacuna de áudio); Escudo Votivo
`buff` + `light`; Selo Sombrio `buff` + `shadow` (periódico); Sussurro `area` + `shadow`; Visão
Eldritch `buff` + `arcane`; passivas `buff` + `light`/`arcane` sem evento. Ataque básico: `projectile`
+ `light`. Sem deixa de áudio nova.

## 7. Builds e pré-requisitos já usados

O Acólito puro não tem `review_builds.json` próprio (D6 só nomeia as builds das puras). As builds
do Sacerdote (T6) já usam os 19 pontos de base legais deste módulo; o combate integrado cobre os
jobs 1 a 19 com a alocação gulosa descrita em `tests/classes/acolyte/acolyte_boss_combat_test.gd`.
