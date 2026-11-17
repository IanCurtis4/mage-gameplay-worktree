# E09 T5 — contrato curto de Santuário e Graça (C2)

Executor: Sol (sessão T5), 16/11/2026. Fonte: [e09_contract.md](../e09_contract.md) §3 (C2) e
§5 (K1, K2); fichas do Sacerdote ([EXTENDED_CLASS_SPECS](../../EXTENDED_CLASS_SPECS.md)),
do Paladino e do Taumaturgo ([HYBRIDS_56_V3](../../HYBRIDS_56_V3.md)). Única porta para os
atores: a costura de T1 ([t1_kit_seam_api.md](t1_kit_seam_api.md)).

Os números abaixo são **padrões do sistema**. K1 e K2 podem escolher outros valores por
rank dentro das faixas indicadas. São ajuste de playtest e não exigem decisão de arquitetura
(C2, preâmbulo do contrato).

## 1. Peças

Pasta `scripts/systems/sanctuary/`:

| Script | `class_name` | Papel |
|---|---|---|
| `sanctuary_rules.gd` | `SanctuaryRules` | Constantes, formas, elementos e regras de dentro como dados (dicionário validado) |
| `sanctuary_zone.gd` | `SanctuaryZone` | Uma zona: dono, papel, forma, âncora, duração, pulso, elemento, regras |
| `sanctuary_grace.gd` | `SanctuaryGrace` | Cargas de Graça, teto, modo sem limite, decaimento, deduplicação por evento |
| `sanctuary_authority.gd` | `SanctuaryAuthority` | Estado da família guardado no kit: zonas por papel, Graça, Égide, Selo; recebe os ganchos |
| `sanctuary_helpers.gd` | `SanctuaryHelpers` | Juízo (coluna), luz (A2), chaves de evento; sem estado |

O kit (K1, K2) guarda **uma** `SanctuaryAuthority` numa variável própria e repassa os
ganchos de T1 (lista em [t5_delivery.md](t5_delivery.md)). O sistema não guarda `Node` nem
`PlayerActor`. Entidades ficam como IDs com os nomes de `SnapshotIdentityRoles`
(`owner_id`, `marked_target_id`, `_inside`).

## 2. Zonas

| Forma | ID | Raio padrão | Faixa | Outros |
|---|---|---|---|---|
| Círculo | `&"circle"` | 130 | 80–200 | — |
| Cone preso ao facing do dono | `&"cone"` | 160 | 100–220 | meio-ângulo 55° (faixa 35°–80°); âncora sempre o dono |
| Círculo ampliado (pico) | `&"wide_circle"` | raio da zona × 1,6 | × 1,2–2,0 | usado pelo pico: Hora do Juramento e Aurora |

- **Âncora.** `&"world"`: ponto fixo do mundo, capturado num `WorldEffectArea`
  (`ground_connected`, perfil de travessia do dono). `&"owner"`: presa ao dono, reavaliada
  na posição atual dele. O cone é sempre `&"owner"`.
- **Pertencer.** No mundo: `WorldEffectArea.contains_actor(alvo, raio)`, a mesma consulta
  `ground_connected` da âncora do Defensor e do targeting. O raio do corpo do alvo soma, e o
  desnível conta: um alvo numa laje acima do centro não está dentro. No cone, além disso, o
  deslocamento no plano do chão (x/z) precisa caber no meio-ângulo em torno de
  `gameplay_ground_facing()` do dono. No mapa plano antigo, `global_position`, o raio de
  colisão do alvo e `SkillGeometry.cone_contains`.
- **Transição de forma.** `set_shape(forma, raio)` em zona ativa (o cone vira círculo na
  Hora; o círculo amplia na Aurora). A duração e o relógio de pulso não reiniciam.
- **Duração.** Padrão 8 s (faixa 3–15 s). A zona termina por tempo, por `end_zone`, pela
  morte do dono ou por outra zona no mesmo papel.
- **Pulso.** A cada 1,0 s (faixa 0,5–2,0 s). O primeiro pulso cai 1,0 s depois da criação.
  `pulse_now` solta um pulso imediato, sem mexer no relógio, usado pela Mudança de Altar.
- **Presença do dono.** É reavaliada a cada 0,25 s e em cada pulso. Zona presa ao dono:
  ele está sempre dentro.
- **Uma zona por dono e por papel.** Os papéis são `StringName` do kit (`&"oath"`,
  `&"votive"`…). Criar outra no mesmo papel substitui a anterior.
- **Sair não desfaz.** A zona segue o relógio dela; fora dela o dono só perde os bônus.
- **Elemento.** `&"none"`, `&"fire"`, `&"ice"`, `&"lightning"` ou `&"tricolor"`
  (os três juntos). `set_element(e)` em zona ativa.

## 3. Regras de dentro (dados)

Dicionário validado por `SanctuaryRules.validate_rules`. Chave ausente usa o padrão; chave
desconhecida ou valor fora da faixa recusa a zona (`invalid_rules`).

| Chave | Padrão | Faixa | Efeito |
|---|---|---|---|
| `owner_damage_taken` | 0,80 | 0,40–1,00 | Multiplica o dano de golpes diretos no dono dentro da zona. No cone, só para golpes com `facing_dot ≥ cos(meio-ângulo)` |
| `heal_multiplier` | 1,25 | 1,00–2,00 | Cura recebida pelo dono dentro da zona rende mais |
| `burn_ratio` | 0,20 | 0,00–1,00 | A cada pulso, cada inimigo dentro recebe dano de luz igual a `burn_stat × burn_ratio` |
| `burn_stat` | `&"magic_attack"` | `magic_attack`, `melee_attack` | Atributo do `stat_breakdown` do dono, lido no commit |
| `fire_burn_multiplier` | 1,50 | 1,00–3,00 | Fogo (e tricolor): a queimadura do pulso é multiplicada |
| `ice_defense` | 0,15 | 0,00–0,50 | Gelo: +15% de DEF física e mágica do dono, como fonte temporária de atributo (§3.1) |
| `ice_slow` | 0,25 | 0,00–0,50 | Gelo: lentidão nos inimigos dentro, por pulso |
| `ice_slow_duration` | 1,2 | 0,5–3,0 | Duração da lentidão (renova a cada pulso) |
| `lightning_sp_regen` | 0,50 | 0,00–2,00 | Raio: o dono dentro recupera mais `sp_regen × valor × delta` de SP |

- **Queimadura por `DamageRequest`.** No commit, a zona captura um protótipo com
  `kit_make_request(null, skill_id, 0, montante, GEOMETRY, false)`, marcado secundário. Cada
  pulso usa `scheduled_tick()` (raiz nova, intrínseca, ancestral = raiz do cast), com
  `context.family_id` = família da zona (padrão: a própria skill), e sai por `kit_emit_hit`.
  A defesa é aplicada por `CombatMath.resolve` dentro de `HealthState`. Não há fórmula nova.
- **Nenhuma regra duas vezes no mesmo tick.** A autoridade agrega as zonas do dono. Por
  tick de gameplay, cada par (regra, alvo) aplica no máximo uma vez:
  - queimadura e lentidão: uma vez por inimigo, mesmo com duas zonas pulsando juntas;
  - SP do raio: uma vez por tick, com o maior valor;
  - multiplicador de dano: o menor, uma vez por golpe;
  - multiplicador de cura: o maior, uma vez por cura;
  - DEF do gelo: o maior.

### 3.1 Regras do dono pelos ganchos da T1.1 (decisão A12, 16/11)

A pergunta à arquitetura levou à decisão A12: os dois ganchos entram na costura (T1.1,
`bd66d3c3`) e o plano B foi descartado.

- **`owner_damage_taken`.** `SanctuaryAuthority.before_hit` devolve
  `{"damage_multiplier": m}` quando `m < 1`. O jogador aplica o multiplicador numa cópia do
  pedido, depois do teste de `cancel` (C1.4, passo 1). O `hit.request` original não muda, e
  o resultado traz `kit_damage_multiplier`. Um kit que cancela, como o Aparo, devolve a
  própria decisão antes.
- **`ice_defense`.** É DEF de verdade.
  - `temporary_stat_sources(player)` publica
    `{"source_id": <prefixo do kit>sanctuary_ice, "increased": {physical_defense, magic_defense}}`,
    no formato do Marco de Guarda. A fonte entra no `stat_breakdown`, na ficha e nas
    defesas de `HealthState`.
  - `sync_stats(player)` chama `player.refresh_kit_stats()` só quando o valor muda: ao
    entrar ou sair, ao trocar de elemento, ao abrir ou encerrar a zona e na morte. Não cura
    nem recarrega.
  - O valor publicado (`ice_defense_applied`) fica no snapshot.

## 4. Graça

| Item | Valor |
|---|---|
| Teto | 5 cargas |
| Modo sem limite | `begin_unlimited(duração)`; sem teto até 99 (trava de segurança); ao fim, `min(cargas, 5)` |
| Ganho próprio: cura excedente | Excedente acumulado num reservatório; cada 8% do HP máximo vira 1 carga (faixa 4–20%) |
| Ganho do kit | `gain(evento, quantidade)`; quantidade de 1 a 5 |
| Decaimento | Só sem zona ativa, fora do modo sem limite e 8 s depois do último ganho ou gasto. A partir daí, −1 carga a cada 2 s. Quando começa, o reservatório de excedente zera |
| Gasto | `spend_for_cast(cast, mínimo, máximo)` em `on_cast_confirmed`; devolve as cargas gastas |
| Morte do dono | Zonas, Égide e Selo terminam, o modo sem limite acaba e a Graça zera |
| Troca de build | Nada muda: sem recarga, sem reset e sem cura (`on_build_changed` só revalida o teto) |

**Medição do excedente depois do `heal()`.** A costura chama `on_heal(player, pedido,
aplicado, fonte)` depois de `HealthState.heal`, com `aplicado` = HP depois − HP antes.
Excedente = `max(0, pedido − aplicado)`. Cura sem excedente (`aplicado == pedido`) não muda o
reservatório e não gera Graça.

O multiplicador de cura da zona é aplicado depois: a autoridade pede
`heal_player(pedido × (m − 1), &"sanctuary_heal_bonus")`. Essa cura reentra em `on_heal`
com a fonte do bônus, que não é multiplicada de novo, e tem o próprio excedente medido. O
total equivale a uma cura única de `pedido × m`. As curas da base que não passam por
`on_heal` não são vistas; nas origens Espadachim e Mago, todas passam.

**Deduplicação por evento.** Cada ganho tem uma chave de evento:

- com um `CombatEventContext` no evento (resultado de dano ou golpe recebido): a identidade
  emitida pelo `EffectProcLedger`, `"<família>@<root_event_id>#<event_id>:<alvo>"`. É a
  mesma identidade que o ledger usa em `apply_once`: uma aplicação aceita pelo ledger tem
  exatamente uma chave, e um retry do mesmo resultado repete a chave;
- sem contexto: uma chave explícita do kit (`"cast:<skill>@<kit_time>"`, por exemplo) ou a
  da própria Graça (`"heal:<serial>:<parte>"`).

A Graça **não** reserva `family:alvo` com `claim_batch`. A reserva gastaria orçamento de
aplicações da raiz, exigiria a família no plano causal de cada raiz (inclusive nas raízes
dos inimigos) e é recusada em contextos secundários, como o tique de queimadura no selado.
Uma recusa por orçamento seria indistinguível de uma repetição.

As chaves aceitas ficam num anel de 128 entradas, guardado no snapshot. A mesma chave nunca
rende Graça duas vezes, mesmo em retry, em dois ganchos do mesmo golpe ou depois de uma
restauração exata.

**Gasto atômico com o commit.** `spend_for_cast` só é chamado em `on_cast_confirmed`, depois
do pagamento canônico. O preparo cancelado nunca chega lá. A chave do gasto é
`<skill>@<kit_time>`: chamar de novo no mesmo commit devolve o mesmo número sem gastar
outra vez. Antes do commit, `can_spend(mínimo)` é puro e serve para `can_cast`.

## 5. Ajudantes

- **Juízo.** `SanctuaryHelpers.judgment_amount(base, cargas, por_carga = 0,40)` =
  `base × (1 + por_carga × cargas)`; com 5 cargas, × 3,0. O pedido é
  `kit_make_request(vítima, skill, 0, montante, GEOMETRY, pode_crit)`, dano mágico. A defesa
  vem de `CombatMath`. Alvos da coluna: inimigos numa coluna vertical de raio 45 (faixa
  30–90) e altura ±200 em torno do ponto, no plano x/z. Com uma zona dada, todos os
  inimigos dentro dela.
- **Égide.** `grant_aegis(player, capacidade, duração, protótipo_do_pulso, raio = 120)`:
  - `HealthState.grant_shield(capacidade)`; duração padrão 6 s;
  - ao quebrar (`on_shield_broken`) ou expirar, solta **um** pulso: dano de luz opcional
    pelo protótipo (`scheduled_tick`) e empurrão de `PlayerActor.DEFENDER_PUSH_DISTANCE`
    nos inimigos a até 120, pelos empurrões existentes do inimigo;
  - um segundo evento (quebra depois de expirar, ou o contrário) não solta outro pulso;
  - ao expirar, o escudo só é limpo se o valor atual não passa da capacidade da Égide.
    Se não, outra fonte maior manda no escudo e ele fica.
- **Selo.** `seal(player, inimigo, chave, duração = 6 s, valor = 1)`:
  - grava a marca `chave` (com o prefixo do kit, como `paladin_seal`) em `ActorMarks`, com
    o dono = ID do jogador;
  - chama `kit_force_target(inimigo, duração)`;
  - um Selo por dono: selar outro inimigo remove a marca do anterior;
  - `add_to_seal(player, delta)` soma ao valor (a Provocação, em K1);
  - `is_sealed(inimigo)` diz se o alvo tem o Selo deste dono.
- **Luz (A2).** `SanctuaryHelpers.is_light_skill(skill)` = `SkillDefinition.element ==
  &"light"`. Dano de luz é dano mágico comum. Não há eixo de resistência novo, e nenhum
  inimigo resiste ou é fraco a luz. O sistema não lê nem cria resistência.

## 6. Snapshot (C1.9, A5)

- O fragmento `scripts/systems/sanctuary/snapshot_manifest.json` declara cada script da pasta,
  com todas as variáveis em `fields`. Os helpers sem estado também entram, com listas vazias.
- **Formato exato:** zonas (forma, âncora, relógios, elemento, regras, protótipo, presença),
  Graça (cargas, reservatório, modo, anel), Égide e Selo voltam iguais.
- **Formato compacto:** `compact_blocker()` devolve um motivo não vazio com zona ativa,
  Égide ativa ou Selo ativo (`sanctuary_zone:<papel>`, `sanctuary_aegis`,
  `sanctuary_seal`). O kit o repassa em `snapshot_compact_blocker`, e o corte cai no exato.
  Sem nenhum deles, o compacto preserva a Graça e o modo sem limite, que são estado do
  jogador.
- **Pausa:** todos os relógios avançam só em `tick` (chamado por `on_tick`, que não roda em
  pausa) e em `ActorMarks` (congela na pausa).

## 7. Respostas às regras de C2

| Regra de C2 | Resposta |
|---|---|
| Dono, forma e âncora | `SanctuaryZone.owner_id`, `shape`, `anchor_mode` (§2) |
| Círculo, cone no facing, círculo ampliado | §2; o cone usa `gameplay_ground_facing()` do dono a cada avaliação |
| Âncora no mundo ou no dono | `&"world"` (com `WorldEffectArea`) ou `&"owner"` |
| Duração e modo de elemento | §2 |
| Uma zona por dono e papel | Dicionário por papel na autoridade; substitui |
| Geometria do mundo, mesma projeção, desnível conta | `WorldEffectArea` `ground_connected`; teste com laje acima |
| Sair não desfaz | Zona segue; só a presença muda |
| Dano recebido (frontal no cone) | §3 e §3.1 |
| Multiplicador de cura | §4 (bônus reentrante) |
| Queimadura por `DamageRequest` | §3 |
| Fogo, gelo, raio | §3 e §3.1 |
| Nenhuma regra duas vezes no tick | §3 |
| Graça 0–5, sem limite, volta ao teto | §4 |
| `gain` deduplicado pelo `EffectProcLedger` | §4 |
| Gasto atômico com o commit | §4 |
| Cura excedente medida depois | §4 |
| Juízo por `CombatMath` | §5 |
| Égide por `grant_shield`, pulso único | §5 |
| Selo: marca + `force_target` | §5 |
| Luz mágica, etiqueta `light`, sem resistência | §5 |
| Invariantes mínimas | `tests/systems/sanctuary/sanctuary_test.gd` (lista no recibo) |
