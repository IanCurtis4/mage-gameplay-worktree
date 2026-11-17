# E09 K4 — contrato curto do kit da Lâmina Arcana (`mg_la`)

Executor: Sol (sessão K4, Opus 5.5), 17/11/2026. Fontes: ficha da Lâmina Arcana em
[HYBRIDS_56_V3](../../HYBRIDS_56_V3.md) (e a decisão de 14/11: lâmina de cristal conjurada no cajado,
efeito e não arma), a ficha do Assassino em [EXTENDED_CLASS_SPECS](../../EXTENDED_CLASS_SPECS.md),
[e09_contract.md](../e09_contract.md) §1, §4 (C3) e §5 (C4, K4), as decisões A2, A4, A5, A7, A9–A13 de
[e09.md](../e09.md), a costura de T1 com T1.1 e T1.2 ([t1_kit_seam_api.md](t1_kit_seam_api.md)) e a
autoridade de costas da T6 ([t6_contract.md](t6_contract.md), [t6_delivery.md](t6_delivery.md)).

O núcleo da ficha não muda: **a Lâmina Arcana some dobrando a luz, aparece nas costas da vítima pelo
teleporte e a corta com uma lâmina de cristal que alterna os elementos; o golpe final é de perto.**
Os números abaixo são ajuste de playtest (preâmbulo de C3/C4).

## 1. Cinco perguntas (C4.1)

| Pergunta | Resposta |
|---|---|
| Distância | Média enquanto oculta (Marca a até 420–500, Salto a até 300–380); corpo a corpo no golpe final (lâmina de cristal, alcance 50; Sentença Prismática, alcance 80). |
| Recurso | Sentença (0–5) na vítima, da T6, e a sequência de elementos da lâmina (fogo → gelo → raio). SP para as ativas; cargas de Refração (§3). |
| Abertura e fechamento | Abre com a **Marca Refratada** e a **Refração**; fecha com a **Sentença Prismática**. Se a Sentença (ou um reflexo do Espectro) matar, a Fratura de Luz devolve a Refração e SP. |
| Contra o chefe | Marcar, ocultar, **Salto às costas** (+2), alternar os três elementos (+2 e reação), Sentença Prismática (só dano alto, A4) e **sair com o Teleporte** da base quando o chefe vira para ela. Sem adds e sem augment, o laço fecha sozinho (teste integrado). |
| Fraqueza | Frágil exposta: depois do Salto ela está colada no inimigo, sem guarda nem aparo. Fraca contra grupos que a cercam: a ocultação não é área e o Teleporte só tira de vista quem está perto da partida. |

## 2. Regras gerais do kit

- **Pedidos do kit.** Ataque básico (com ou sem a lâmina), golpe do Salto, reação dos três elementos,
  Sentença e reflexos passam por `flank.mark_request` (lado e abertura no commit). A execução passa
  pelo `flank.execute`, que chama `mark_request` por dentro.
- **Fontes de Sentença** na vítima: costas +2, primeiro golpe saindo da ocultação +2, outro golpe
  direto +1 (`record_hit` com as três fontes ligadas; por golpe vale a maior), e o combo dos três
  elementos +2 (`gain(&"combo", "triad:<n>")`). Golpes da base na vítima contam pelo resultado
  (direto +1). Execução, DoT, golpe sem dano e a própria reação não geram.
- **Bônus da Marca.** Os pedidos do kit **na vítima** levam `damage_dealt_multiplier × (1 + bônus)` do
  rank da Marca Refratada.
- **Elemento (A2).** Dano mágico, a partir do **ATQ mágico** do `stat_breakdown`, por `CombatMath`.
  `SkillDefinition.element`: `arcane` para Marca, Lâmina e Salto; `light` para Refração, Fratura,
  Sentença e Espectro. As receitas de luz usam `arcane` (`FeedbackRecipeCatalog.ELEMENTS` não tem `light`).
- **Sem escrita de estado privado do jogador.** Recarga, SP e custo canônicos (`_spend`) valem para
  todas as ativas; o kit só lê `kit_concealed()`, `skill_rank`, `stat_breakdown` e usa os ajudantes
  públicos (`kit_make_request`, `kit_emit_hit`, `recover_sp`, `pursue`).

## 3. Skills e números por rank

Prefixo `arcane_blade_`, IDs de C1.

### Marca Refratada — `arcane_blade_refracted_mark` (job 20, ativa, entrada; R1 grátis; sem pré-requisito)

Alvo único, defensiva (não revela a ocultação). Marca a vítima de C3 (`mark_victim`): ela acumula
Sentença e fica visível através de obstáculos (`see_through`). Marcar outro inimigo zera a anterior.

| R | SP | Recarga | Alcance | Bônus na vítima |
|---|---|---|---|---|
| 1 | 8 | 4,0 s | 420 | +5% |
| 2 | 8 | 3,5 s | 440 | +7% |
| 3 | 7 | 3,0 s | 460 | +9% |
| 4 | 7 | 2,5 s | 480 | +11% |
| 5 | 6 | 2,0 s | 500 | +13% |

### Lâmina Encantada — `arcane_blade_enchanted_edge` (job 23, passiva, R1–R3)

Substitui o ataque básico do Mago por um **golpe corpo a corpo de cristal** (`basic_attack_profile`:
alcance 50, entrega `direct`; `compose_basic_attack` devolve um pedido mágico novo). A cada golpe o
elemento avança: fogo → gelo → raio → fogo (estado do kit, `blade_index`), gravado no pedido
(`effect_snapshot["arcane_blade_element"]`). Sem a passiva (rank 0), o básico é o projétil do Mago,
também marcado pela autoridade.

**Os três na vítima:** quando fogo, gelo e raio aterrissam na vítima atual (a mesma marca), ela ganha
+2 de Sentença (combo) e sofre a **reação prismática**, um golpe mágico extra no tick seguinte.

| R | Lâmina | Reação |
|---|---|---|
| 1 | 100% do ATQ mágico | 80% |
| 2 | 110% | 100% |
| 3 | 120% | 120% |

- A sequência recomeça quando a vítima muda ou morre. Golpe repetido do mesmo resultado (retry) não
  conta duas vezes.
- **Lança de Gelo segura a vítima de longe** (interação da ficha): com a passiva, um acerto da Lança
  de Gelo na vítima conta como o **gelo** da sequência, além da lentidão própria da Lança.

### Refração — `arcane_blade_refraction` (job 25, ativa, própria, defensiva)

Ocultação própria da T6 (`enter_concealment`). Atacar revela; o primeiro golpe ao sair vale +2.
Recusada já oculta ou com a ocultação armada (`arcane_blade_already_concealed`).

**Cargas (limitação 2 da T6).** A costura não dá ao kit um gancho de recarga nem encurta a revelação
de 1,25 s. Por isso a recarga real da Refração é uma **carga do kit**: 1 carga, que volta depois da
recarga do rank, contada em `on_tick` (congela na pausa). A recarga canônica da skill é só 1,0 s
(contra toque duplo). Sem carga, a Refração é recusada (`arcane_blade_refraction_recharging`). A
Fratura de Luz devolve a carga (§ Fratura), **e não uma ocultação instantânea**.

| R | SP | Duração | Recarga da carga |
|---|---|---|---|
| 1 | 14 | 3,0 s | 14 s |
| 2 | 14 | 3,5 s | 13 s |
| 3 | 13 | 4,0 s | 12 s |
| 4 | 13 | 4,5 s | 11 s |
| 5 | 12 | 5,0 s | 10 s |

### Salto Prismático — `arcane_blade_prismatic_leap` (job 28, ativa, alvo único, ofensiva)

**Só oculta** (`can_cast` exige `player.kit_concealed()`, senão `arcane_blade_not_concealed`) e **só na
vítima** (`arcane_blade_not_victim`). Teleporte às costas validado pela geometria do mundo
(`flank.back_point`/`teleport_behind`: 0°, +30°, −30°; no mundo, `trace_ground` e `teleport_legal`;
no mapa plano, ponto andável e segmento livre). O ponto é validado também no `can_cast`
(`back_point_blocked`), para não pagar um salto impossível. Depois do teleporte, golpe mágico
marcado: sai das costas e da ocultação (+2; as fontes não somam).

| R | SP | Recarga | Alcance | Golpe |
|---|---|---|---|---|
| 1 | 16 | 8,0 s | 300 | 130% |
| 2 | 17 | 7,5 s | 320 | 145% |
| 3 | 18 | 7,0 s | 340 | 160% |
| 4 | 19 | 6,5 s | 360 | 175% |
| 5 | 20 | 6,0 s | 380 | 190% |

- Pré-requisito: Refração R1.
- O teleporte aceita até `alcance + corpos + 12 + 8` de distância até o ponto às costas.
- **Rota depois do teleporte (limitação 3 da T6).** O kit chama `player.pursue(vítima)` depois do
  teleporte: o comando público limpa o caminho plano pendente e engaja a vítima com a lâmina. Assim
  a rota antiga do mapa plano não continua. No mundo, `WorldActorMotion.teleport` já zera a rota.

### Fratura de Luz — `arcane_blade_light_fracture` (job 31, passiva, R1–R3)

Abate confirmado por execução (Sentença Prismática ou reflexo do Espectro; `on_kill_confirmed` com
`first` e `execution`) devolve a **carga de Refração** (zera a recarga da carga) e SP.

| R | SP devolvido |
|---|---|
| 1 | 8% do SP máximo |
| 2 | 12% |
| 3 | 16% |

Uma vez por abate (dedup da T6); retry não devolve de novo; abate comum não devolve.

### Sentença Prismática — `arcane_blade_prismatic_sentence` (job 34, ativa, alvo único, ofensiva)

Execução de C3 (`flank.execute`, montantes mágicos): gasta toda a Sentença; dano =
`ATQ mágico × base × (1 + 0,40 × cargas)`. Com 5 cargas e HP do alvo no limiar da categoria (normal
30%, raro 24%, elite 18%, raro-elite 12%), morte certa por `DamageRequest` de execução. **No chefe,
nunca há morte certa: só dano alto** (A4). Golpe de perto (alcance 80).

| R | SP | Recarga | Alcance | Base |
|---|---|---|---|---|
| 1 | 18 | 7 s | 80 | 160% |
| 2 | 19 | 7 s | 80 | 180% |
| 3 | 20 | 7 s | 80 | 200% |
| 4 | 21 | 7 s | 80 | 220% |
| 5 | 22 | 7 s | 80 | 240% |

- Pré-requisito: Lâmina Encantada R1. Uma execução por commit (chave da T6): retry no mesmo instante
  é recusado (`already_executed`) e não gasta de novo.

### Espectro de Prisma — `arcane_blade_prism_specter` (job 37, ativa, própria, ofensiva)

Três reflexos de cristal, um por elemento (fogo, gelo, raio), cada um numa vítima **diferente**: a
vítima marcada primeiro (se estiver no raio), depois os inimigos vivos mais próximos, até três. Cada
alvo precisa de um ponto às costas válido (`flank.back_point`). Os reflexos são entidades temporárias
registradas como marca `arcane_blade_specter` no alvo (dono = Lâmina, prazo de segurança 3 s) e saltam
em sequência, um a cada 0,20 s do relógio do kit. Cada salto é uma **execução** de C3 (`flank.execute`)
com o lado lido do ponto do reflexo (costas): na vítima, gasta a Sentença e pode matar abaixo do
limiar; nos outros, é só o golpe. Uma corrente de execuções: abate por reflexo aciona a Fratura.

| R | SP | Recarga | Raio | Golpe por reflexo |
|---|---|---|---|---|
| 1 | 36 | 50 s | 320 | 90% |
| 2 | 38 | 48 s | 320 | 100% |
| 3 | 40 | 46 s | 320 | 110% |
| 4 | 42 | 44 s | 320 | 120% |
| 5 | 44 | 42 s | 320 | 130% |

- Pré-requisito: Salto Prismático R3. Sem nenhum inimigo vivo no raio, recusado
  (`arcane_blade_no_reflection_target`).
- Enquanto há reflexo pendente, o corte compacto é inelegível (`snapshot_compact_blocker`; o save usa
  o formato exato, C1.9).

### Interações com a base Mago (C4.3)

| Skill da base | Na Lâmina Arcana |
|---|---|
| Teleporte (`teleport`) | **É a saída.** Observado por `on_base_skill_committed(player, &"teleport", context)` (T1.2, A13), não pela recarga. Todo inimigo vivo a até 220 da partida perde a Lâmina de vista (`flank.break_sight`, 1,2 s; chefe × 0,6). A partida é a posição do jogador no commit no mapa plano e a do último tick no mundo (onde o teleporte já moveu o jogador antes do pagamento). |
| Lança de Gelo (`ice_spear`) | Segura a vítima de longe: lentidão própria; com a Lâmina Encantada, o acerto na vítima conta como o gelo da sequência; +1 de Sentença (direto). |
| Demais feitiços | Acerto na vítima: +1 de Sentença (direto). |

## 4. Estado, snapshot e pausa

- Fragmento `scripts/classes/mg_la/snapshot_manifest.json`, revisão 2. Campos: `flank`, `blade_index`,
  `triad_serial`, `triad_landed`, `triad_keys`, `reaction_pending`, `reaction_serial`,
  `refraction_charges`, `refraction_recharge`, `specter_serial`, `specter_pending`, `last_ground`,
  `has_last_ground`, `fracture_total`. Nenhuma referência de entidade: a vítima vive na marca `flank_victim`, os reflexos
  na marca `arcane_blade_specter`; a sequência se liga à vítima pelo serial da marca.
- Exato: tudo volta, inclusive cargas, sequência, reação pendente, vítima, Sentença e reflexos.
  Compacto: elegível sem reflexo pendente; o estado do jogador fica, as marcas dos inimigos somem com
  eles (A5), e a sequência recomeça porque a vítima não existe mais.
- Relógios do kit só em `on_tick` (pausa congela); reflexos pelo `kit_time`; marcas, giro e perda de
  visão pelos relógios de T1.
- Morte: ocultação, abertura, vítima, sequência, reação pendente e reflexos acabam (marcas removidas).
  As cargas de Refração ficam. Troca de build: nada recarrega, nada cura, nada zera.

## 5. Efeitos em código e IDs de flipbook reservados (C4.4)

| ID | Skill | Tipo do evento |
|---|---|---|
| `arcane_blade_mark_prism` | Marca Refratada | `effect_start` |
| `arcane_blade_crystal_swing` | Lâmina Encantada | `effect_start` (a cada golpe da lâmina) |
| `arcane_blade_triad_burst` | Lâmina Encantada | `impact` (reação) |
| `arcane_blade_refraction_veil` | Refração | `effect_start` |
| `arcane_blade_leap_flash` | Salto Prismático | `effect_start` |
| `arcane_blade_leap_strike` | Salto Prismático | `impact` |
| `arcane_blade_light_fracture` | Fratura de Luz | `effect_start` (no abate por execução) |
| `arcane_blade_sentence_gather` | Sentença Prismática | `effect_start` |
| `arcane_blade_sentence_tricolor` | Sentença Prismática | `impact` |
| `arcane_blade_specter_summon` | Espectro de Prisma | `effect_start` |
| `arcane_blade_specter_strike` | Espectro de Prisma | `impact` |

Receitas: `buff`/`melee`/`impact`/`teleport`/`summon`, elemento `arcane`, sem assinatura. Básico
(`basic_attack_recipe`): `melee`, `arcane`.

## 6. Builds nomeadas (C4.2, A11)

`scripts/classes/mg_la/review_builds.json`, esquema `ragrpg_review_builds_v1`, com o rank final. Base
sem rank grátis (soma 19); evolução com R1 grátis na Marca (pontos 20, soma dos ranks 21).

| Build | Base (19) | Evolução (20 pontos) |
|---|---|---|
| `arcane_blade_execution_chain` — Corrente de Execuções | Teleporte 5, Lança de Gelo 5, Bola de Fogo 3, Relâmpago 3, Barreira Fantasma 1, Regeneração de SP 2 | Marca 2, Lâmina 3, Refração 4, Salto 4, Fratura 2, Sentença 5, Espectro 1 |
| `arcane_blade_prism_specter` — Espectro Prismático | Teleporte 3, Lança de Gelo 4, Bola de Fogo 4, Relâmpago 4, Barreira Fantasma 1, Regeneração de SP 3 | Marca 1, Lâmina 2, Refração 3, Salto 3, Fratura 3, Sentença 4, Espectro 5 |
