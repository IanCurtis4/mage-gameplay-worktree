# E09 K2 — contrato curto do kit do Taumaturgo (`mg_ac`)

Executor: Sol (sessão K2, Opus 5.5), 16/11/2026. Fontes: ficha do Taumaturgo em
[HYBRIDS_56_V3](../../HYBRIDS_56_V3.md), [e09_contract.md](../e09_contract.md) §1 e §5 (C4),
a costura de T1 ([t1_kit_seam_api.md](t1_kit_seam_api.md), com T1.1 e T1.2) e Santuário/Graça
de T5 ([t5_contract.md](t5_contract.md), [t5_delivery.md](t5_delivery.md)).

O núcleo da ficha não muda: **o Santuário do Taumaturgo tem elemento. O círculo de fogo pune,
o de gelo protege e o de raio acelera o SP; alternar elementos dentro do círculo vira Graça.**
Os números abaixo são ajuste de playtest (preâmbulo de C2/C4).

## 1. Cinco perguntas (C4.1)

| Pergunta | Resposta |
|---|---|
| Distância | Média, de dentro do círculo. O ataque básico é o da origem (projétil do Mago); o kit não o substitui. |
| Recurso | Graça (0–5 cargas; sem limite na Aurora), da autoridade de T5, e SP. |
| Abertura e fechamento | Abre com o **Círculo Votivo**; fecha com o **Juízo Prismático**, que gasta a Graça em três pulsos. |
| Contra o chefe | O Taumaturgo fica no círculo e alterna Bola de Fogo, Lança de Gelo e Relâmpago no chefe. Cada troca de elemento rende Graça, três seguidas deixam o círculo tricolor, e o Juízo descarrega. Sem adds e sem augment, o laço fecha sozinho (teste integrado). |
| Fraqueza | Sair do círculo perde tudo: fora dele, os feitiços não rendem Graça e zeram a sequência de elementos, e os bônus do círculo somem. A conjuração fica exposta (o círculo não reduz dano recebido). |

## 2. Regras do kit

### Elemento do círculo

- O kit guarda o **elemento do altar** (`circle_element`): `none` ao abrir o círculo.
- O **elemento mostrado** na zona é `tricolor` durante o Coro ou a Aurora; senão, o do altar.
- **Feitiço de elemento lançado dentro.** Vale o commit pago de uma skill da origem com
  `context.element` em fogo, gelo ou raio (`on_base_skill_committed`, T1.2), com o Taumaturgo
  dentro do círculo (pertença da zona no instante do commit). Não há detecção por recarga.
  - Com o altar em `none`, o elemento do feitiço **define** o altar.
  - Depois disso, o altar só muda pela Mudança de Altar.
  - **Alternância:** elemento diferente do último feitiço lançado dentro. Com o Prisma Votivo,
    rende Graça (abaixo). A chave do evento é `alt:<skill>@<kit_time>`, então o mesmo commit
    nunca rende duas vezes.
  - **Sequência do Coro:** o elemento entra na sequência quando difere do último; três
    elementos diferentes em seguida acionam o Coro.
- **Feitiço de elemento lançado fora** do círculo (ou sem círculo): zera o último elemento e a
  sequência do Coro. É a fraqueza da ficha.
- Skills da origem sem elemento (Barreira Fantasma, Teleporte, Impacto das Almas,
  Assombro) não contam e não zeram nada.
- As skills do kit são de luz (A2) e não contam como elemento, exceto a Mudança de Altar, que
  conta como o lançamento do elemento novo dentro do círculo.

### Graça

- Fontes: alternância (com o Prisma Votivo) e cura excedente (fonte própria de T5).
- A Refração Curativa cura no máximo o HP que falta, então não gera excedente nem Graça sobre
  a própria cura. O círculo usa `heal_multiplier = 1,0`: não há bônus de cura.
- Gasto: Refração e Juízo gastam até 5 cargas em `on_cast_confirmed`; com 0 cargas, saem com o
  valor base.

## 3. Skills e números por rank

Prefixo `thaumaturge_`, IDs de C1 (§1 do contrato). Todas com `element = &"light"` (A2): o
dano é mágico, parte do **ATQ mágico** do `stat_breakdown` (atributos INT > VIT > DES) e a
defesa aplicada é a mágica, por `CombatMath`. `×(1 + 0,40 × cargas)` é
`SanctuaryHelpers.judgment_amount`.

### Círculo Votivo — `thaumaturge_votive_circle` (job 20, ativa, entrada; R1 grátis)

Zona `votive` de C2: círculo com âncora no mundo, no ponto do Taumaturgo. Pulso a cada 1 s:
queima de luz nos inimigos dentro. Regras do elemento (padrões de T5, salvo o indicado):
fogo × 1,5 na queima; gelo +DEF física e mágica do dono e lentidão de 25% por 1,2 s nos
inimigos; raio +SP. Dano recebido × 1,0 e cura × 1,0.

| R | SP | Recarga | Duração | Raio | Queima (ATQ mágico) | DEF do gelo | SP do raio (× regen) |
|---|---|---|---|---|---|---|---|
| 1 | 18 | 12 s | 8 s | 120 | 10% | +10% | +0,40 |
| 2 | 19 | 12 s | 9 s | 125 | 12% | +12% | +0,50 |
| 3 | 20 | 12 s | 10 s | 130 | 14% | +14% | +0,60 |
| 4 | 21 | 12 s | 11 s | 135 | 16% | +16% | +0,70 |
| 5 | 22 | 12 s | 12 s | 140 | 18% | +18% | +0,80 |

- Sem pré-requisito (entrada, A13). Recusado durante a Aurora (`thaumaturge_dawn_active`).
- Recolocar o círculo substitui a zona e volta o altar a `none` e a sequência a vazio.

### Prisma Votivo — `thaumaturge_votive_prism` (job 23, passiva, R1–R3)

| R | ATQ mágico | Graça por alternância |
|---|---|---|
| 1 | +3% | 1 |
| 2 | +6% | 1 |
| 3 | +9% | 2 |

O ATQ mágico entra como fonte de passiva (`passive_modifier_source`). Sem a passiva, a
alternância não rende Graça (mas segue alimentando o Coro).

### Refração Curativa — `thaumaturge_healing_refraction` (job 25, ativa, própria, ofensiva)

Gasta até 5 cargas. Cura o Taumaturgo em `ATQ mágico × cura × (1 + 0,40 × cargas)`, limitada
ao HP que falta. Solta uma onda do **elemento mostrado** do círculo em todos os inimigos dentro
dele (sem círculo, raio 90 em volta): dano `ATQ mágico × onda × (1 + 0,40 × cargas)`.
Fogo: × 1,5. Gelo: lentidão da regra da zona. Raio: +5% do SP máximo, uma vez por cast.
Tricolor: os três.

| R | SP | Recarga | Cura | Onda |
|---|---|---|---|---|
| 1 | 20 | 8 s | 60% | 50% |
| 2 | 21 | 8 s | 70% | 60% |
| 3 | 22 | 8 s | 80% | 70% |
| 4 | 23 | 8 s | 90% | 80% |
| 5 | 24 | 8 s | 100% | 90% |

### Mudança de Altar — `thaumaturge_altar_shift` (job 28, ativa, própria, ofensiva)

Exige o círculo ativo (`thaumaturge_no_circle`). Troca o altar na hora, na ordem
fogo → gelo → raio → fogo (de `none`, vai a fogo), e solta um pulso do **elemento mostrado
antes da troca**:
- `pulse_now` de T5 com o elemento antigo (queima, × 1,5 no fogo, lentidão no gelo);
- um choque de luz de `ATQ mágico × choque` em cada inimigo dentro (× 1,5 com fogo antigo);
  com raio antigo, +5% do SP máximo.

Com o Taumaturgo dentro, conta como lançar o elemento novo dentro do círculo (alternância e
sequência do Coro).

| R | SP | Recarga | Choque |
|---|---|---|---|
| 1 | 16 | 10 s | 40% |
| 2 | 17 | 9,5 s | 50% |
| 3 | 18 | 9 s | 60% |
| 4 | 19 | 8,5 s | 70% |
| 5 | 20 | 8 s | 80% |

### Coro dos Elementos — `thaumaturge_elemental_choir` (job 31, passiva, R1–R3)

Três elementos diferentes em sequência dentro do círculo o deixam **tricolor** (os três
efeitos juntos: queima × 1,5, DEF, lentidão e SP) por 3 / 4 / 5 s. A sequência zera ao
acionar. Um novo Coro durante outro renova a duração. Ao fim, volta o elemento do altar.

### Juízo Prismático — `thaumaturge_prismatic_judgment` (job 34, ativa, alvo único, ofensiva)

Gasta até 5 cargas. Uma coluna de luz (raio 45, C2) cai sobre o alvo em **três pulsos**:

| Pulso | Instante | Efeito |
|---|---|---|
| Fogo | no commit | dano × 1,25 |
| Gelo | +0,3 s | dano e lentidão de 30% por 1,5 s |
| Raio | +0,6 s | dano e +3% do SP máximo |

Dano de cada pulso, em cada inimigo da coluna em volta da posição atual do alvo:
`ATQ mágico × base × (1 + 0,40 × cargas)`. O primeiro pulso é um golpe direto do cast; os
dois seguintes são tiques agendados (`scheduled_tick`) de um protótipo capturado no commit,
marcados secundários. Se o alvo morrer, os pulsos restantes não caem.

| R | SP | Recarga | Alcance | Base por pulso |
|---|---|---|---|---|
| 1 | 26 | 9 s | 320 | 50% |
| 2 | 27 | 9 s | 320 | 60% |
| 3 | 28 | 9 s | 320 | 70% |
| 4 | 29 | 9 s | 320 | 80% |
| 5 | 30 | 9 s | 320 | 90% |

### Aurora Convergente — `thaumaturge_convergent_dawn` (job 37, ativa, própria, defensiva)

| R | SP | Recarga | Duração |
|---|---|---|---|
| 1 | 40 | 60 s | 6,0 s |
| 2 | 42 | 57 s | 6,5 s |
| 3 | 44 | 54 s | 7,0 s |
| 4 | 46 | 51 s | 7,5 s |
| 5 | 48 | 48 s | 8,0 s |

- O círculo fica **enorme** (`wide_circle`, raio × 1,6, relógios preservados) e **tricolor**.
  Sem círculo que dure ao menos a Aurora, abre a zona `votive` ampliada no Taumaturgo, com as
  regras do rank atual do Círculo e a duração da Aurora; ela termina com a Aurora.
- **Graça sem limite** (`begin_unlimited`); ao fim, volta ao teto de 5.
- **Feitiços pela metade do SP** pelo gancho `ClassKit.skill_cost` (T1.2), sem reembolso, com o
  Taumaturgo dentro do círculo. Valem as ativas do kit (exceto a Aurora) e os feitiços da
  origem (Bola de Fogo, Parede de Fogo, Lança de Fogo, Lança de Gelo, Parede de Gelo,
  Relâmpago, Descarga Elétrica, Parede de Raios, Impacto das Almas, Assombro, Barreira
  Fantasma). O Teleporte não é feitiço. `skill_cost` é leitura pura (o HUD a lê a cada quadro).
- Ao fim, um círculo que continua volta ao raio normal e ao elemento do altar (ou ao Coro).

### Interações com a base Mago (C4.3)

| Skill da base | Efeito no Taumaturgo |
|---|---|
| Bola de Fogo, Lança de Gelo, Relâmpago (e as outras de fogo, gelo e raio) | Dentro do círculo, definem o altar, alternam (Graça com o Prisma) e alimentam o Coro; fora, zeram a sequência. |
| Barreira Fantasma | Protege como sempre; não conta como elemento e não zera a sequência; custa metade na Aurora. |

## 4. Estado, snapshot e pausa

- Variáveis do kit (fragmento `scripts/classes/mg_ac/snapshot_manifest.json`, revisão 2):
  `sanctuary`, `circle_element`, `last_element`, `choir_sequence`, `choir_remaining`,
  `dawn_remaining`, `dawn_opened_zone`, `refraction_charges`, `judgment_charges`,
  `victim_id`, `judgment_pulses_left`, `judgment_delay`, `judgment_prototype`.
- Exato: tudo volta (zona, elemento, Coro, Aurora, pulsos do Juízo pendentes, Graça).
  Compacto: inelegível com zona (T5), Aurora (`thaumaturge_dawn`) ou pulsos do Juízo pendentes
  (`thaumaturge_judgment`); sem eles, a Graça e o modo sem limite sobrevivem no jogador.
- Relógios (Coro, Aurora, pulsos do Juízo) avançam só em `on_tick` e congelam na pausa.
- Morte: zonas terminam e a Graça zera (T5); Coro, Aurora, sequência e pulsos acabam.
  Troca de build: nada recarrega, nada cura, nada zera.

## 5. Efeitos em código e IDs de flipbook reservados (C4.4)

| ID | Skill | Tipo do evento |
|---|---|---|
| `thaumaturge_votive_circle` | Círculo Votivo | `effect_start` |
| `thaumaturge_votive_burn` | Círculo Votivo | `impact` |
| `thaumaturge_refraction_wave` | Refração Curativa | `effect_start` |
| `thaumaturge_refraction_hit` | Refração Curativa | `impact` |
| `thaumaturge_altar_pulse` | Mudança de Altar | `effect_start` |
| `thaumaturge_altar_shock` | Mudança de Altar | `impact` |
| `thaumaturge_judgment_column` | Juízo Prismático | `impact` |
| `thaumaturge_judgment_mark` | Juízo Prismático | `effect_start` |
| `thaumaturge_dawn_circle` | Aurora Convergente | `effect_start` |

Receitas de feedback: família `area` (Círculo), `heal` (Refração), `impact` (Altar e Juízo) ou
`buff` (passivas e Aurora), elemento `arcane` (a lista de C1 não tem `light`), sem assinatura.

## 6. Builds nomeadas (C4.2, A11)

`scripts/classes/mg_ac/review_builds.json`, esquema `ragrpg_review_builds_v1`. Os mapas trazem o
**rank final**. Base: soma dos ranks = 19 pontos. Evolução: o Círculo tem R1 grátis, então os
pontos comprados somam 20 (soma dos ranks 21).

| Build | Base (19) | Evolução (20 pontos) |
|---|---|---|
| `thaumaturge_prism_altar` — Altar Prismático | Bola de Fogo 5, Lança de Gelo 5, Relâmpago 5, Barreira Fantasma 2, Regeneração de SP 2 | Círculo 5, Prisma 3, Refração 2, Altar 4, Coro 3, Juízo 3, Aurora 1 |
| `thaumaturge_dawn_choir` — Coro da Aurora | Bola de Fogo 4, Lança de Gelo 3, Relâmpago 3, Parede de Fogo 2, Barreira Fantasma 3, Regeneração de SP 3, Teleporte 1 | Círculo 3, Prisma 2, Refração 4, Altar 2, Coro 2, Juízo 3, Aurora 5 |
