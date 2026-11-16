# E09 K1 — contrato curto do kit do Paladino (`sp_ac`)

Executor: Sol (sessão K1, Opus 5.5), 16/11/2026. Fontes: ficha do Paladino em
[HYBRIDS_56_V3](../../HYBRIDS_56_V3.md), [e09_contract.md](../e09_contract.md) §1 e §5 (C4),
a costura de T1 ([t1_kit_seam_api.md](t1_kit_seam_api.md), com a T1.1) e Santuário/Graça de T5
([t5_contract.md](t5_contract.md), [t5_delivery.md](t5_delivery.md)).

O núcleo da ficha não muda: **o Paladino carrega o Santuário no escudo; cada impacto de frente
mitigado e cada cura que passa do HP máximo enchem a mesma reserva de Graça; o Juízo sai pelo
escudo como uma coluna de luz.** Os números abaixo são ajuste de playtest (preâmbulo de C2/C4).

## 1. Cinco perguntas (C4.1)

| Pergunta | Resposta |
|---|---|
| Distância | Corpo a corpo. O ataque básico é o da origem (Espadachim); o kit não o substitui. |
| Recurso | Graça (0–5 cargas; sem limite na Hora do Juramento), da autoridade de T5. SP para as ativas. |
| Abertura e fechamento | Abre com o **Juramento** (cone à frente); fecha com o **Impacto Consagrado**, que gasta a Graça numa coluna de luz. |
| Contra o chefe | Juramento de frente para o chefe: cada golpe frontal mitigado rende Graça; o Selo prende o chefe no Paladino, e a queima do cone no selado também rende Graça. Impacto a cada ~5 s. Sem adds e sem augment, o laço fecha sozinho (teste integrado). |
| Fraqueza | O flanco: golpes fora do cone não são reduzidos nem rendem Graça (a não ser na Hora). Chefes que atacam de lado ou à distância fora do cone. |

## 2. Skills e números por rank

Prefixo `paladin_`, IDs de C1 (§1 do contrato). Luz = dano mágico de skill com
`element = &"light"` (A2). O montante de luz parte do **ATQ corpo a corpo** do
`stat_breakdown` (atributos VIT > FOR > INT) e a defesa aplicada é a mágica, por `CombatMath`.

### Juramento — `paladin_oath` (job 20, ativa, entrada; R1 grátis)

Ergue o escudo e projeta um Santuário em cone à frente (zona `oath` de C2, forma `cone`,
âncora no dono, meio-ângulo 55°). Dentro: golpes frontais no Paladino recebem o multiplicador; os
inimigos no cone queimam a cada 1 s (luz, `burn_stat = melee_attack`).

| R | SP | Recarga | Duração | Raio | Dano frontal recebido | Queima por pulso |
|---|---|---|---|---|---|---|
| 1 | 20 | 14 s | 6,0 s | 150 | × 0,82 | 12% ATQ |
| 2 | 21 | 14 s | 6,5 s | 155 | × 0,80 | 14% ATQ |
| 3 | 22 | 14 s | 7,0 s | 160 | × 0,78 | 16% ATQ |
| 4 | 23 | 14 s | 7,5 s | 165 | × 0,76 | 18% ATQ |
| 5 | 24 | 14 s | 8,0 s | 170 | × 0,74 | 20% ATQ |

- Sem pré-requisito: o R1 grátis da entrada não pode exigir rank comprado da base
  (`ProfileCatalog._rank_requirements_are_valid`). Recusado durante a Hora (`paladin_hour_active`).
- Multiplicador de cura da zona: 1,00 sem Fé Inabalável (a Fé dá o bônus, abaixo).
- **Graça (fonte do kit):** cada golpe direto recebido que a zona reduz (no cone, só os frontais)
  rende +1, deduplicado pela identidade do evento no ledger (C2).

### Graça de Guarda — `paladin_guard_grace` (job 23, passiva, R1–R3)

| R | DEF física | Cura excedente por carga | Parede de Escudos |
|---|---|---|---|
| 1 | +4% | 7% do HP máx. | golpe frontal com a postura erguida rende +1 Graça |
| 2 | +7% | 6% do HP máx. | idem |
| 3 | +10% | 5% do HP máx. | idem |

- Sem a passiva, a cura excedente rende 1 carga a cada 8% do HP máximo (padrão de T5) e só a
  zona gera Graça por golpe frontal. A passiva acrescenta o token de guarda do Defendente: com a
  Parede de Escudos erguida, o golpe frontal também rende Graça. Um mesmo golpe nunca rende
  duas vezes.
- A DEF entra como fonte de passiva (`passive_modifier_source`), na composição única do breakdown.
- Trocar a build ajusta a fração do excedente sem mexer nas cargas, no reservatório nem no HP.

### Impacto Consagrado — `paladin_consecrated_impact` (job 25, ativa, alvo único, ofensiva)

Golpe de escudo que gasta a Graça: uma coluna de luz desce no alvo à frente (coluna vertical de
C2, raio 55). Dano de cada alvo da coluna = `ATQ × base × (1 + 0,40 × cargas)`
(`SanctuaryHelpers.judgment_request`).

| R | SP | Recarga | Alcance | Base |
|---|---|---|---|---|
| 1 | 22 | 5 s | 110 | 110% |
| 2 | 23 | 5 s | 110 | 125% |
| 3 | 24 | 5 s | 110 | 140% |
| 4 | 25 | 5 s | 110 | 155% |
| 5 | 26 | 5 s | 110 | 170% |

- Gasta **até 5 cargas** no commit (`spend_for_cast` em `on_cast_confirmed`); com 0 cargas, sai
  o dano base. Com 5 cargas, × 3,0.
- Na Hora do Juramento: a coluna cobre **todos os inimigos dentro do círculo**, e o SP pago no
  commit é devolvido no mesmo commit (custo líquido zero). As cargas acima de 5 ficam para o
  próximo Impacto.

### Égide do Juramento — `paladin_oath_aegis` (job 28, ativa, própria, defensiva)

Halo de escudo (`grant_aegis` de C2) por 6 s. Ao quebrar ou expirar, **um** pulso de luz de raio
120 que causa dano e empurra.

| R | SP | Recarga | Escudo (base + VIT/INT, como a Perseverança) | Pulso de luz |
|---|---|---|---|---|
| 1 | 24 | 16 s | 50 | 60% ATQ |
| 2 | 25 | 16 s | 65 | 70% ATQ |
| 3 | 26 | 16 s | 80 | 80% ATQ |
| 4 | 27 | 16 s | 95 | 90% ATQ |
| 5 | 28 | 16 s | 110 | 100% ATQ |

A capacidade usa `StatCalculator.personal_shield_capacity` (a mesma da Perseverança), sem fórmula nova.

### Fé Inabalável — `paladin_unshaken_faith` (job 31, passiva, R1–R3)

Enquanto o Paladino está dentro do Juramento (cone ou círculo):

| R | Resistência a controle físico e mágico | Cura recebida |
|---|---|---|
| 1 | +0,10 | × 1,10 |
| 2 | +0,15 | × 1,20 |
| 3 | +0,20 | × 1,30 |

- A resistência entra como fonte temporária do kit (T1.1, `paladin_unshaken_faith`, `flat`), e os
  controles duram menos por `HardControlState` (teto existente de 0,5 no eixo). Sai quando a zona
  acaba ou na morte.
- A cura usa a regra `heal_multiplier` da zona (C2): o valor é gravado na zona ao abrir o Juramento
  (ou o círculo da Hora). Aprender a Fé com a zona aberta vale a partir da próxima zona.

### Selo do Condenado — `paladin_condemned_seal` (job 34, ativa, alvo único, defensiva)

Aro de luz sobre um inimigo (`seal` de C2: marca `paladin_seal` em `ActorMarks` + `force_target`).

| R | SP | Recarga | Alcance | Duração |
|---|---|---|---|---|
| 1 | 18 | 14 s | 300 | 5,0 s |
| 2 | 19 | 14 s | 300 | 5,5 s |
| 3 | 20 | 14 s | 300 | 6,0 s |
| 4 | 21 | 14 s | 300 | 6,5 s |
| 5 | 22 | 14 s | 300 | 7,0 s |

- Pré-requisito: Provocar R1.
- **Graça (fonte do kit):** todo dano de luz confirmado no selado (Impacto, queima do Juramento,
  pulso da Égide) rende Graça igual ao valor do Selo (1 a 3), uma vez por evento.
- Valor inicial 1; Provocar soma (abaixo).

### Hora do Juramento — `paladin_oath_hour` (job 37, ativa, própria, defensiva)

| R | SP | Recarga | Duração |
|---|---|---|---|
| 1 | 40 | 60 s | 6,0 s |
| 2 | 42 | 57 s | 6,5 s |
| 3 | 44 | 54 s | 7,0 s |
| 4 | 46 | 51 s | 7,5 s |
| 5 | 48 | 48 s | 8,0 s |

- O cone vira **círculo completo**: com um Juramento ativo que dure ao menos a Hora,
  `set_zone_shape(oath, circle)` (relógios preservados); senão abre a zona `oath` como círculo
  preso ao dono, raio 170, com as regras do rank atual do Juramento e a duração da Hora. No
  círculo, o multiplicador de dano recebido vale de todos os lados, e todo golpe reduzido rende
  Graça.
- **Graça sem limite** durante a Hora (`begin_unlimited`); ao fim, volta ao teto de 5.
- **Impacto sem custo de SP** e com coluna no círculo inteiro.
- Ao fim da Hora, se o Juramento continua, o círculo volta a cone.

### Interações com a base Espadachim (C4.3)

| Skill da base | Efeito no Paladino |
|---|---|
| Parede de Escudos | Cada uso confirmado rende +1 Graça; com Graça de Guarda, os golpes frontais com a postura erguida também rendem. |
| Perseverança | Cada uso confirmado rende +1 Graça. |
| Provocar | Com um Selo ativo, cada uso confirmado soma +1 ao valor do Selo (máx. 3). |

Detecção: a costura não tem gancho de skill da base. O kit observa, em `on_tick`, o aumento da
recarga canônica dessas três skills (`skill_cooldown`), que só sobe no pagamento (`_spend`). O
uso é visto no primeiro tick depois do commit. A chave de Graça é `cast:<skill>@<kit_time>`.

## 3. Estado, snapshot e pausa

- Variáveis do kit (fragmento `scripts/classes/sp_ac/snapshot_manifest.json`): `sanctuary`
  (autoridade de T5), `impact_charges`, `hour_remaining`, `hour_opened_zone`, `faith_applied`,
  `base_cooldowns`.
- Exato: tudo volta, inclusive zona, Égide, Selo e relógio da Hora. Compacto: inelegível com
  zona, Égide, Selo ou Hora ativos (`paladin_hour` além dos motivos de T5); sem eles, a Graça e o
  modo sem limite sobrevivem no jogador.
- A Hora avança só em `on_tick` (congela na pausa).
- Morte: zonas, Égide, Selo e Hora terminam; a Graça zera (T5). Troca de build: nada recarrega,
  nada cura, nada zera.

## 4. Efeitos em código e IDs de flipbook reservados (C4.4)

| ID | Skill | Tipo do evento |
|---|---|---|
| `paladin_oath_cone` | Juramento | `effect_start` |
| `paladin_oath_burn` | Juramento | `impact` |
| `paladin_grace_rings` | Impacto Consagrado | `effect_start` |
| `paladin_impact_column` | Impacto Consagrado | `impact` |
| `paladin_aegis_halo` | Égide do Juramento | `effect_start` |
| `paladin_aegis_pulse` | Égide do Juramento | `impact` |
| `paladin_seal_ring` | Selo do Condenado | `effect_start` |
| `paladin_hour_circle` | Hora do Juramento | `effect_start` |

Receitas de feedback: família `buff` (ativas defensivas e passivas) ou `impact` (Impacto), elemento
`arcane` (a lista de C1 não tem `light`), sem assinatura.

## 5. Builds nomeadas (C4.2, A11)

`scripts/classes/sp_ac/review_builds.json`, esquema `ragrpg_review_builds_v1`. Os mapas trazem o
**rank final**. Na base não há rank grátis (rank = pontos, soma 19); na evolução o Juramento tem R1
grátis, então os pontos comprados somam 20 (soma dos ranks 21).

| Build | Base (19) | Evolução (20 pontos) |
|---|---|---|
| `paladin_bulwark` — Baluarte da Luz | Parede 5, Perseverança 5, Provocar 3, Corte 3, Resistência 3 | Juramento 5, Graça de Guarda 3, Impacto 3, Égide 4, Fé 3, Selo 2, Hora 1 |
| `paladin_hammer` — Martelo Consagrado | Corte 5, Parede 3, Perseverança 3, Provocar 1, Fúria 4, Resistência 3 | Juramento 3, Graça de Guarda 2, Impacto 5, Égide 2, Fé 1, Selo 3, Hora 5 |
