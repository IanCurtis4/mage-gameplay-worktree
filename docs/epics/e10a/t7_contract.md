# E10a T7 — contrato curto do Cultista (`cultist`, C3 e §4.3)

Executor: Sol (sessão T7), 18/11/2026. Fontes: [e10a_contract.md](../e10a_contract.md) §1, §4 e
§4.3; decisões D4, D6, A7, A8 e A9 de [e10a.md](../e10a.md); ficha "Cultista — olho" em
[EXTENDED_CLASS_SPECS](../../EXTENDED_CLASS_SPECS.md); API da Loucura em
[t4_madness_api.md](t4_madness_api.md) e da costura em [t1_base_seam_api.md](t1_base_seam_api.md)
e [t1_kit_seam_api.md](../e09/t1_kit_seam_api.md).

Os números abaixo são ajuste de playtest. Os limites de D4 não são números deste contrato: vêm
da autoridade da T4 (`MadnessRules`) e são conferidos em teste.

## 1. Peças

| Arquivo | Papel |
|---|---|
| `scripts/classes/cultist/cultist_kit.gd` | Kit: dados, textos, efeitos, ganchos e estado da run |
| `scripts/classes/cultist/snapshot_manifest.json` | Fragmento do kit (revisão 2) |
| `scripts/classes/cultist/review_builds.json` | Builds Profeta e Vidente (`ragrpg_review_builds_v1`) |
| `scripts/classes/cultist/fixture/cultist_fixture_base.gd` | Base de teste: substitui a base Acólito da T5 enquanto ela não está no ramo. Guarda a autoridade no campo `madness`, como a T5 vai fazer. Nunca entra no registro |

**Autoridade.** O Cultista não cria `MadnessAuthority`: lê a da origem a cada uso com
`MadnessAuthority.of(player)`. Sem autoridade (base sem o campo), as skills ainda causam dano,
mas não dão Loucura; o kit não falha. O Cultista repassa `on_tick` (deduplicado pela T4) e é o
**único** que repassa `temporary_stat_sources`, `skill_cost` e `before_hit_mitigation` (Êxtase).

## 2. Skills e números

Ranks: ativas 1–5 (entrada grátis R1 + 4 comprados), passivas 1–3. Todas com elemento `shadow`
(dano mágico com etiqueta, sem eixo de resistência). Sem pré-requisitos (a entrada do job 20
não aceita; nas outras, nenhum é necessário para a ficha).

| Job | Skill | Alvo | SP R1→R5 | Recarga | Números por rank (R1→R5 ou R1→R3) |
|---|---|---|---|---|---|
| 20 | `cultist_abyss_gaze` Olhar do Abismo | si (cone à frente) | 14→18 | 4 s | Canalização de 2,0 s, 5 tiques (0,4 s). Cone de raio 200, meio-ângulo 40°. Por tique: 22→38% do ATQ mágico e 8→12 de Loucura. Mover mais de 24 ou usar outra skill interrompe |
| 23 | `cultist_ecstasy` Êxtase | passiva | — | — | Liga o Êxtase da T4. Por carga: +3/4/5% ATQ mágico e −3/4/5% de SP. Ônus fixo da T4: +8% de dano recebido por carga acima de 2 (0–5 cargas) |
| 25 | `cultist_impossible_idol` Ídolo Impossível | ponto | 22→26 | 14 s | Ídolo (isca da T4) por 6→10 s, HP 25→45% do HP máximo, raio 180, 6→10 de Loucura por tique (1 s) |
| 28 | `cultist_shared_delirium` Delírio Compartilhado | alvo | 18→22 | 8 s | 60→100% do ATQ mágico, marca de contágio por 8 s (fração 40→60%, raio 140, pulso 20→40) e depois 15→35 de Loucura no alvo (copiada uma vez) |
| 31 | `cultist_open_pupil` Pupila Aberta | passiva | — | — | Inimigos em Delírio ou Desorientação do Cultista recebem ×1,10/1,15/1,20 do dano dele (C1.7, filtro de dono) |
| 34 | `cultist_impossible_geometry` Geometria Impossível | ponto | 24→28 | 12 s | Figura de raio 110 por 4 s, pulso a cada 0,5 s. Comum ou elite dentro: desorientação de movimento de 1,0→2,0 s, uma vez por inimigo por figura, e 10 de Loucura nessa entrada. Chefe dentro: lentidão de 30→40% por 1 s, renovada a cada pulso |
| 37 | `cultist_revelation` Revelação | si | 40→48 | 60→48 s | Olho aberto por 5→7 s, raio 360. A cada 0,5 s: 12→20 de Loucura em todos os inimigos no raio. Delirantes do Cultista: ×1,40→1,60 de dano recebido do dono. Chefe no raio, no commit: Desorientação forte (`bypass_immunity`, 5→6 s, ×1,40 de dano recebido, −25% de acerto, 60% dos golpes num lacaio a até 110, imunidade de 20 s) |

**Tabela R1→R5 (ativas):**

| Skill | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|
| Olhar: SP / % ATQ mág. / Loucura | 14 / 22 / 8 | 15 / 26 / 9 | 16 / 30 / 10 | 17 / 34 / 11 | 18 / 38 / 12 |
| Ídolo: SP / s / % HP / Loucura | 22 / 6 / 25 / 6 | 23 / 7 / 30 / 7 | 24 / 8 / 35 / 8 | 25 / 9 / 40 / 9 | 26 / 10 / 45 / 10 |
| Delírio: SP / % ATQ / fração / pulso / Loucura | 18 / 60 / 40 / 20 / 15 | 19 / 70 / 45 / 25 / 20 | 20 / 80 / 50 / 30 / 25 | 21 / 90 / 55 / 35 / 30 | 22 / 100 / 60 / 40 / 35 |
| Geometria: SP / desorientação / lentidão | 24 / 1,00 / 30 | 25 / 1,25 / 32 | 26 / 1,50 / 35 | 27 / 1,75 / 38 | 28 / 2,00 / 40 |
| Revelação: SP / recarga / s / Loucura / ×delirantes / s no chefe | 40 / 60 / 5,0 / 12 / 1,40 / 5,0 | 42 / 57 / 5,5 / 14 / 1,45 / 5,25 | 44 / 54 / 6,0 / 16 / 1,50 / 5,5 | 46 / 51 / 6,5 / 18 / 1,55 / 5,75 | 48 / 48 / 7,0 / 20 / 1,60 / 6,0 |

**Eventos de Loucura (deduplicação da T4).** Olhar: `gaze:<série>:<tique>`; Ídolo: os tiques da
T4; Delírio Compartilhado: o evento do cast; Geometria: `geometry:<série>`; Revelação:
`revelation:<série>:<tique>` e, no chefe, `revelation:<série>` em `disorient`. As séries são
estado do kit e vão no snapshot: retry ou restauração exata nunca repetem um ganho.

**Pupila e Revelação** usam fontes C1.7 no inimigo (`cultist_open_pupil`,
`cultist_revelation`), com `owner_id` do Cultista e prazo curto (0,6 s) renovado a cada tique
do kit enquanto a condição vale. O golpe entre inimigos tem `source_id` = dono (T1), então os
delirantes que se ferem entre si recebem o bônus. Nenhuma fórmula de dano no kit: os montantes
são % do ATQ mágico, e o resto é `kit_make_request` / `CombatMath`.

## 3. Limites de D4 (conferidos em teste)

Delírio ≤ 3 por dono; nunca no chefe; abate por Delírio é do Cultista (crédito e XP/loot uma
vez, inclusive em retry); o chefe nunca troca de alvo (nem pelo Ídolo, nem pela Geometria); a
Desorientação é seguida de imunidade (a da Revelação vale uma vez por Revelação, mesmo sob
imunidade, e deixa a imunidade mais longa); golpes do chefe desorientado caem nos lacaios ao
lado; Êxtase 0–5 com ônus a partir de 3; Ídolo 1 por dono; contágio de um salto.

## 4. Da base

- **Sussurro e Selo Sombrio** dão Loucura pela mesma autoridade: somam com a do Cultista e
  levam ao mesmo limiar. O kit não os altera.
- **Escudo Votivo e Prece** compensam o ônus pelos caminhos normais (escudo absorve o golpe já
  multiplicado; cura repõe HP). O Cultista não muda a base; o teste prova as duas compensações
  com a base de teste.
- A base de teste (`fixture/cultist_fixture_base.gd`) reproduz isso: Selo e Sussurro dão 25 de
  Loucura, Prece cura, Escudo Votivo dá escudo. A T5 entrega a base real; a T13 roda os testes
  do Cultista sobre ela.

## 5. Estado, pausa e snapshot

Variáveis do kit (fragmento revisão 2): canalização do Olhar (restante, próximo tique, tiques,
série, origem), série e restante da Geometria (centro no chão), série, restante e próximo tique
da Revelação. Nenhuma referência a nó. Relógios só em `on_tick` (congela na pausa). Canalização,
Geometria ou Revelação ativas tornam o compacto inelegível (`cultist_channel`,
`cultist_geometry`, `cultist_revelation`); o Ídolo já bloqueia pela T4. A morte encerra os três.

## 6. Efeitos (desenhados em código, IDs de flipbook reservados)

`cultist_abyss_gaze_cone`, `cultist_abyss_gaze_hit`, `cultist_impossible_idol` (o desenhador do
Ídolo é o da T4), `cultist_shared_delirium_mark`, `cultist_shared_delirium_spread`,
`cultist_impossible_geometry`, `cultist_impossible_geometry_slip`, `cultist_revelation_eye`,
`cultist_revelation_gaze`. Paleta da ficha: preto-azulado, magenta e turquesa doentio.

## 7. As cinco perguntas

- **Distância:** média (cone de 200, Delírio a 220, Geometria e Ídolo em ponto). Perto o bastante
  para o olhar alcançar; frágil de perto.
- **Recurso:** Loucura nos inimigos (autoridade da T4) e Êxtase em si.
- **Abrir e fechar:** abre com Ídolo e Olhar (Loucura em grupo), espalha com o Delírio
  Compartilhado e fecha com a Revelação.
- **Contra o chefe:** vive das janelas de Desorientação (Olhar e Selo acumulam; a Revelação força
  uma janela forte fora de hora). A Pupila e a janela somam dano. Com lacaios, 35–60% dos golpes
  do chefe desorientado caem neles.
- **Fraqueza:** sem grupo o Delírio não serve; com 3+ cargas de Êxtase recebe mais dano; o Olhar
  canalizado prende o Cultista no lugar.

## 8. Builds de revisão (D6)

19 pontos de base e 20 de evolução (mais o R1 grátis do Olhar), em `review_builds.json`:
- **Profeta:** Olhar + Ídolo + Delírio Compartilhado + Sussurro + Revelação; Êxtase + Pupila.
- **Vidente:** Olhar + Geometria + Selo Sombrio + Escudo Votivo + Revelação; Pupila + Devoção.
