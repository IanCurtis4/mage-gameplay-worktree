# E10a T6 — contrato curto do kit do Sacerdote (`priest`)

Executora: Terra (sessão T6, Sonnet 5.5), 18/11/2026. Fontes: ficha do Sacerdote em
[EXTENDED_CLASS_SPECS](../../EXTENDED_CLASS_SPECS.md) (§"Sacerdote — halo"),
[e10a_contract.md](../e10a_contract.md) §1, §4 e §4.2, decisões D3, D5, D6 e A7 de
[e10a.md](../e10a.md), a API da T1 ([t1_base_seam_api.md](t1_base_seam_api.md)) e o Santuário e a
Graça do E09 ([t5_contract.md](../e09/t5_contract.md), [t5_delivery.md](../e09/t5_delivery.md)).
O Paladino ([k1_contract.md](../e09/k1_contract.md)) é o exemplo de consumidor.

O núcleo da ficha não muda: **o Sacerdote desenha o Santuário no ponto escolhido e luta de dentro
dele; a cura que passaria do HP máximo vira Graça; o Juízo gasta a Graça numa coluna de luz; a
Hora Santa dobra a cura, solta a Graça e zera o custo do Juízo.** Os números abaixo são ajuste de
playtest (preâmbulo do contrato do E10a) e não pedem decisão de arquitetura.

## 1. Cinco perguntas (C3.1)

| Pergunta | Resposta |
|---|---|
| Distância | Curta a média, dentro do Santuário (raio 130–150, até 260 de alcance para pôr o círculo). Fora dele só tem o ataque básico mágico da base e a Luz Punitiva (alcance 220). |
| Recurso | Graça (0–5 cargas; sem limite na Hora Santa), da autoridade do E09; SP para as ativas; o tempo do Santuário (9–11 s, recarga 14 s). |
| Abertura e fechamento | Abre com o **Santuário** (e o **Selo de Luz** no alvo); fecha com o **Juízo** de Graça cheia ou com a **Hora Santa**. |
| Contra o chefe | Pôr o Santuário onde o chefe luta (ou puxá-lo para o círculo); o Selo de Luz o deixa lento e dá Graça a cada dano de luz nele (a queimadura do Santuário já conta); o Juízo cai a cada ~6 s com as cargas cheias. Sem buff nem escudo no chefe, o Exorcista o deixa **Exposto** à luz. Sem adds e sem augment o laço fecha sozinho (teste integrado). |
| Fraqueza | Dano baixo fora do Santuário; chefes que forçam movimento constante tiram o Sacerdote do círculo (sair não desfaz o círculo, mas perde os bônus). |

## 2. Skills e números por rank

IDs de §1 do contrato do E10a, prefixo `priest_`. Luz = dano mágico de skill com
`element = &"light"` (A2 do E09, D5): sem eixo de resistência. Todos os montantes partem do
`magic_attack` do `stat_breakdown`, e a defesa mágica é aplicada por `CombatMath`.

### Santuário — `priest_sanctuary` (job 20, ativa, entrada; R1 grátis)

Alvo: ponto (`Targeting.POINT`), alcance 260. Abre uma zona `circle` âncora `world` (papel
`sanctuary`; uma por dono, substitui a anterior) no ponto escolhido. Dentro: o Sacerdote recebe
menos dano e a cura dele rende mais; os inimigos dentro queimam a cada 1 s (luz, `magic_attack`).

| R | SP | Recarga | Raio | Duração | Dano recebido | Cura recebida | Queima por pulso |
|---|---|---|---|---|---|---|---|
| 1 | 22 | 14 s | 130 | 9,0 s | × 0,84 | × 1,20 | 14% MATQ |
| 2 | 23 | 14 s | 135 | 9,5 s | × 0,82 | × 1,25 | 16% MATQ |
| 3 | 24 | 14 s | 140 | 10,0 s | × 0,80 | × 1,30 | 18% MATQ |
| 4 | 25 | 14 s | 145 | 10,5 s | × 0,78 | × 1,35 | 20% MATQ |
| 5 | 26 | 14 s | 150 | 11,0 s | × 0,76 | × 1,40 | 22% MATQ |

- Sem pré-requisito (o R1 grátis da entrada não pode exigir rank da base).
- A abertura pelo `resolve_cast`, para o protótipo da queimadura herdar a raiz causal do cast.

### Graça — `priest_grace` (job 23, passiva, R1–R3)

| R | Cura excedente por carga | Pulso ao entrar com Graça cheia |
|---|---|---|
| sem a passiva | 12% do HP máx. | — |
| 1 | 8% do HP máx. | cura 6% do HP máx. |
| 2 | 6,5% do HP máx. | cura 9% do HP máx. |
| 3 | 5% do HP máx. | cura 12% do HP máx. |

- "Liga as cargas": sem a passiva a Graça existe, mas a cura excedente rende devagar (12%) e não
  há pulso. As fontes do kit (Selo de Luz, Prece, Escudo Votivo) não dependem da passiva.
- **Pulso de entrada:** quando o Sacerdote passa de fora para dentro do Santuário (ou abre um
  Santuário com ele dentro) com a Graça no teto (5, ou sem limite), `heal_player` de uma fração do
  HP máximo (fonte `priest_grace_pulse`). Recarga de 6 s do pulso, no relógio de gameplay.
- Trocar a build ajusta a fração, sem mexer em cargas, reservatório nem HP.

### Égide — `priest_aegis` (job 25, ativa, própria, defensiva)

Halo (`grant_aegis` do E09) por 6 s; ao quebrar ou expirar, **um** pulso de luz de raio 120 que
fere e empurra.

| R | SP | Recarga | Escudo (base + VIT/INT) | Pulso de luz |
|---|---|---|---|---|
| 1 | 22 | 15 s | 45 | 55% MATQ |
| 2 | 23 | 15 s | 60 | 65% MATQ |
| 3 | 24 | 15 s | 75 | 75% MATQ |
| 4 | 25 | 15 s | 90 | 85% MATQ |
| 5 | 26 | 15 s | 105 | 95% MATQ |

A capacidade usa `StatCalculator.personal_shield_capacity`, a mesma da Perseverança e da Égide do
Paladino, sem fórmula nova.

### Juízo — `priest_judgment` (job 28, ativa, alvo único, ofensiva)

Gasta a Graça no commit (`spend_for_cast`, mínimo 1) e deixa uma coluna de luz no alvo. Dano de
cada atingido = `MATQ × base × (1 + 0,40 × cargas)` (`SanctuaryHelpers.judgment_request`).

| R | SP | Recarga | Alcance | Base |
|---|---|---|---|---|
| 1 | 24 | 6 s | 300 | 100% |
| 2 | 25 | 6 s | 300 | 115% |
| 3 | 26 | 6 s | 300 | 130% |
| 4 | 27 | 6 s | 300 | 145% |
| 5 | 28 | 6 s | 300 | 160% |

- Gasta **até 5 cargas** (até **10** durante a Hora Santa, em que a Graça passa do teto); sem
  cargas, sai o dano base. O restante fica para o próximo Juízo. Com 5 cargas, × 3,0.
- **Dentro do Santuário** (o Sacerdote e o alvo no círculo ativo): atinge **todos os inimigos no
  círculo** (`judgment_targets` com a zona). Fora, coluna vertical de raio 55 sobre o alvo.
- **Hora Santa:** sem custo de SP enquanto durar e o Sacerdote estiver dentro do Santuário
  (`skill_cost`, T1.2); as linhas "SP base" do tooltip continuam com o valor do rank.

### Exorcista — `priest_exorcist` (job 31, passiva, R1–R3) — D3

Quando um **golpe direto** de luz do Sacerdote (não secundário: nada de queimadura nem pulso)
acerta um inimigo:

1. se o inimigo tem **escudo** (`health.shield_hp > 0`), o escudo é removido;
2. senão, se tem **buff** (uma fonte de dano recebido com multiplicador < 1 no inimigo, o único
   buff genérico que a C1.7 define), a fonte mais forte é removida;
3. senão, o alvo fica **Exposto**: fonte `priest_exposed` de dano recebido, só da luz **deste
   dono** (filtro de dono e de `light`, C1.7), que renova a cada golpe.

| R | Exposto | Duração |
|---|---|---|
| 1 | × 1,10 | 4 s |
| 2 | × 1,15 | 5 s |
| 3 | × 1,20 | 6 s |

- **Bônus contra mortos-vivos e fantasmas** (D3): `UNDEAD_BONUS` = +15/20/25% do dano de luz,
  registrado como dado e **sem efeito**: `undead_bonus_for(alvo)` devolve sempre 0 enquanto a
  categoria não existir. Um teste prova que o dano não muda.
- O modificador respeita a pausa e some com os status do inimigo (C1.7).

### Selo de Luz — `priest_light_seal` (job 34, ativa, alvo único, defensiva) — D3

Aro de luz sobre o inimigo (`seal` do E09: marca `priest_light_seal` em `ActorMarks` com o dono e
`force_target`). Em seguida:
- **Não-chefe:** raiz mágica (`apply_root`).
- **Chefe** (`hard_controls.boss`): só **lentidão** (`apply_slow`, fonte `priest_light_seal`) pela
  duração da marca, nunca raiz.
- **Graça (fonte do kit):** todo dano de luz confirmado no marcado, direto ou secundário, rende 1
  Graça, uma vez por evento (`SanctuaryHelpers.result_event`).

| R | SP | Recarga | Alcance | Marca | Raiz (não-chefe) | Lentidão (chefe) |
|---|---|---|---|---|---|---|
| 1 | 18 | 12 s | 300 | 4,0 s | 1,6 s | 30% |
| 2 | 19 | 12 s | 300 | 4,5 s | 1,8 s | 32% |
| 3 | 20 | 12 s | 300 | 5,0 s | 2,0 s | 34% |
| 4 | 21 | 12 s | 300 | 5,5 s | 2,2 s | 36% |
| 5 | 22 | 12 s | 300 | 6,0 s | 2,4 s | 38% |

- A raiz respeita a resistência a controle mágico, o teto de controle e o orçamento de controle do
  chefe (`HardControlState`); por isso o chefe só recebe lentidão (D3).
- Sem pré-requisito.

### Hora Santa — `priest_holy_hour` (job 37, ativa, própria, defensiva)

| R | SP | Recarga | Duração |
|---|---|---|---|
| 1 | 40 | 60 s | 7,0 s |
| 2 | 42 | 57 s | 7,5 s |
| 3 | 44 | 54 s | 8,0 s |
| 4 | 46 | 51 s | 8,5 s |
| 5 | 48 | 48 s | 9,0 s |

- O Santuário vira **círculo ampliado** (`wide_circle`, raio × 1,6, dourado na apresentação) e a
  cura recebida passa a **× 2,00**. Se o Santuário ativo dura ao menos a Hora, só muda de forma e
  de regra (relógios preservados); senão a Hora abre um Santuário novo no mesmo ponto (ou no
  Sacerdote, se não havia nenhum) com o rank atual do Santuário (mínimo R1) e a duração da Hora.
- **Graça sem limite** (`begin_unlimited`); ao fim, volta ao teto de 5.
- **Juízo sem SP** e atingindo o círculo inteiro.
- Ao fim: se a Hora abriu o círculo, ele termina; senão a forma, o raio e a cura voltam ao que o
  Santuário tinha. Morte encerra tudo.

### Interações com a base Acólito (C3.3 do contrato)

| Skill da base | Efeito no Sacerdote |
|---|---|
| Prece | Cada commit pago rende +1 Graça (`on_base_skill_committed`, chave `base:<skill>@<kit_time>`). A cura da Prece, passando do HP máximo, vira Graça pela fonte própria do sistema. |
| Escudo Votivo | Cada commit pago rende +1 Graça. |
| Luz Punitiva | É o dano de luz fora do Santuário: conta para o Exorcista e para a Graça do Selo. |
| Devoção | O Sacerdote não a usa; a Devoção lê a alternância luz ↔ sombra pelo `context.element` dos commits do kit (todos `light`). |

## 3. Estado, snapshot e pausa

- Variáveis do kit (fragmento `scripts/classes/priest/snapshot_manifest.json`, revisão 2): `sanctuary`
  (autoridade do E09), `judgment_charges`, `hour_remaining`, `hour_opened_zone`,
  `hour_saved_heal`, `hour_saved_shape`, `pulse_cooldown`, `was_inside`.
- Exato: tudo volta (zona, Égide, Selo, relógio da Hora). Compacto: inelegível com zona, Égide, Selo
  ou Hora ativos (`priest_holy_hour` além dos motivos do E09); sem eles, a Graça e o modo sem
  limite sobrevivem no jogador. O Exposto, a raiz e a lentidão ficam no inimigo e seguem a
  restauração dele (C1.9).
- Hora, recarga do pulso e Santuário avançam só em `on_tick` (congelam na pausa).
- Morte: zona, Égide, Selo e Hora terminam; a Graça zera. Troca de build: nada recarrega, nada
  cura, nada zera.

## 4. Efeitos em código e IDs de flipbook reservados (C3.4)

| ID | Skill | Tipo do evento |
|---|---|---|
| `priest_sanctuary_circle` | Santuário | `effect_start` |
| `priest_sanctuary_burn` | Santuário | `impact` |
| `priest_grace_rings` | Juízo | `effect_start` |
| `priest_judgment_column` | Juízo | `impact` |
| `priest_aegis_halo` | Égide | `effect_start` |
| `priest_aegis_pulse` | Égide | `impact` |
| `priest_seal_ring` | Selo de Luz | `effect_start` |
| `priest_holy_hour_circle` | Hora Santa | `effect_start` |

Receitas de feedback com o elemento `light` (D5): família `area` (Santuário), `buff` (Égide, Selo,
Hora e as passivas), `impact` (Juízo). As passivas não emitem evento próprio. Sem deixa de áudio nova
(a lacuna família × `light` fica no recibo da T1).

## 5. Builds nomeadas (C3.2, D6, A11)

`scripts/classes/priest/review_builds.json`, esquema `ragrpg_review_builds_v1`. Os mapas trazem o
**rank final**; na base não há rank grátis (rank = pontos, soma 19); na evolução o Santuário tem R1
grátis, então os pontos comprados somam 20 (soma dos ranks 21). As builds citam IDs `acolyte_*` do
contrato do E10a (§1), e a base real só chega com a T5.

| Build | Base (19) | Evolução (20 pontos) |
|---|---|---|
| `priest_bastion` — Bastião da Fé | Prece 5, Escudo Votivo 5, Luz Punitiva 2, Selo Sombrio 1, Devoção 3, Fé Protetora 3 | Santuário 5, Graça 3, Égide 5, Juízo 3, Hora Santa 5 |
| `priest_inquisition` — Inquisição | Luz Punitiva 5, Prece 5, Escudo Votivo 4, Fé Protetora 3, Selo Sombrio 1, Devoção 1 | Santuário 3, Graça 3, Juízo 5, Exorcista 3, Selo de Luz 4, Hora Santa 3 |

O Selo Sombrio entra com 1 ponto nas duas por pré-requisito da Devoção e por não haver outro
destino legal para o ponto 19 sem ele; o Sacerdote não o usa.
