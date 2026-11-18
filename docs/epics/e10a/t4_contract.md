# E10a T4 — contrato curto de Loucura, Êxtase e Ídolo (C2)

Executor: Sol (sessão T4), 18/11/2026. Fonte: [e10a_contract.md](../e10a_contract.md) §3 (C2),
§4.3 (T7) e as decisões D4 e A3, A4 e A7 de [e10a.md](../e10a.md); ficha do Cultista em
[EXTENDED_CLASS_SPECS](../../EXTENDED_CLASS_SPECS.md) §"Cultista — olho". A única porta para os
atores é a costura da T1 ([t1_base_seam_api.md](t1_base_seam_api.md)): marcas (`ActorMarks`),
sobrescrita de alvo, desvio no commit, isca (`KitDecoy`) e modificadores do inimigo.
Precedente: o Santuário do E09 ([t5_contract.md](../e09/t5_contract.md)).

Os números abaixo são **padrões do sistema**. T5, T7 e as híbridas futuras podem passar outros
valores por skill e por rank, dentro das faixas. São ajuste de playtest e não pedem decisão de
arquitetura. Os limites decididos pelo usuário (D4) **não** são parâmetros: teto 3 de Delírio,
chefe sem troca de alvo, imunidade depois da Desorientação, 1 Ídolo por dono, contágio de um
salto e Êxtase de 0 a 5 com ônus a partir de 3.

## 1. Peças

Pasta `scripts/systems/madness/`:

| Script | `class_name` | Papel |
|---|---|---|
| `madness_rules.gd` | `MadnessRules` | Constantes, faixas, chaves de marca e validação de opções |
| `madness_ecstasy.gd` | `MadnessEcstasy` | Cargas de Êxtase, decaimento e valores por carga (estado do jogador) |
| `madness_authority.gd` | `MadnessAuthority` | Autoridade da família: Loucura, Delírio, Desorientação, Ídolo, contágio, memória de eventos e `describe()` |
| `madness_helpers.gd` | `MadnessHelpers` | Sem estado: inimigos da run, chefe, distâncias, chaves de evento, desenho do Ídolo |
| `fixture/madness_fixture_kit.gd` | — | Kit de fixture dos testes (fora do registro) |

**Uma autoridade por jogador.** O módulo que a cria guarda **uma** `MadnessAuthority` num campo
chamado `madness`. Na família Acólito, é a base (T5), ligada antes e depois da evolução. O
Cultista (T7) não cria outra: lê a da origem com `MadnessAuthority.of(player)`. Uma híbrida
futura de outra origem cria a sua. Os dois módulos podem repassar `on_tick`: a autoridade
avança uma vez por instante de `kit_time` e ignora a segunda chamada. Os ganchos do Êxtase
(`temporary_stat_sources`, `skill_cost`, `before_hit_mitigation`) são repassados **só pelo
módulo que liga o Êxtase** (T7), para não contar duas vezes na composição de C1.4.

**Retenção de combate (A8).** Exceção a A6: a T4 acrescenta a `scripts/actors/enemy_actor.gd`
`set_combat_hold(owner_id, duration, reason)`, `clear_combat_hold()`, `has_combat_hold()` e
`combat_hold_remaining()`. O chefe recusa (`boss_refuses_hold`). O inimigo retido não se move,
não ataca e não conjura, nos dois caminhos. Não é controle: não usa `HardControlState`, não
desenha atordoamento e não liga bônus de "controlado". O estado é a marca `combat_hold` de
`ActorMarks` (valor = motivo, dono, prazo). Por isso congela na pausa, segue a restauração do
inimigo no snapshot e cai com a morte e com a limpeza de status, sem campo novo no manifesto.

A autoridade não guarda `Node`, `Callable` nem ator. O estado por inimigo fica em marcas do
próprio inimigo, com dono = ID do jogador. O estado do jogador fica na autoridade.

## 2. Loucura

| Item | Valor | Faixa |
|---|---|---|
| Limiar | 100 | fixo |
| Ganho por chamada | o da skill | `0 < valor ≤ 100` |
| Espera antes de decair | 4,0 s sem ganho | — |
| Decaimento | −20 por segundo | — |

- Marcas: `madness` (valor) e `madness_hold` (relógio da espera). Ambas congelam na pausa
  (`ActorMarks` avança em `advance_statuses`).
- `add(enemy, amount, event, owner)`. O `event` é a identidade do evento, deduplicada por
  alvo:
  - com `CombatEventContext` (resultado de dano): a identidade do `EffectProcLedger`,
    `<root_event_id>#<event_id>`, a mesma de `apply_once`;
  - sem contexto: uma chave explícita (`MadnessHelpers.cast_event`, um tique do Ídolo).
  A chave final junta o alvo pelo `occurrence_id` (estável no snapshot exato). As chaves aceitas
  ficam num anel de 256 entradas, no snapshot. A mesma chave nunca rende duas vezes: nem em
  retry, nem em dois ganchos do mesmo golpe, nem depois de uma restauração exata.
- Recusas: alvo que não é inimigo ou é isca (`invalid_target`), morto, quantia inválida
  (`invalid_amount`), evento sem chave (`missing_event`), evento repetido (`duplicate_event`),
  imunidade (`immune`) e inimigo já em Delírio ou Desorientação (`already_maddened`).
- **Resultado entre inimigos não gera Loucura.** `MadnessHelpers.result_event` devolve um
  evento vazio para um resultado de relay (`EnemyActor.is_relay_result`): o abate e o dano por
  Delírio não alimentam a Loucura.
- No limiar, a Loucura volta a 0 e o inimigo entra em Delírio (não chefe) ou em Desorientação
  (chefe).

## 3. Delírio

| Item | Valor | Faixa |
|---|---|---|
| Duração | 5,0 s | 2–8 s |
| Teto por dono | **3** (D4) | fixo |

- Marca `madness_delirium`, com o prazo. O inimigo mira o **inimigo não-chefe vivo mais
  próximo** (plano: distância no mapa; mundo: `world_distance_to`, mesmo mundo), pela
  `set_target_override(alvo, dono, prazo, &"madness_delirium")`. O prazo da sobrescrita é o que
  resta da marca. Nunca mira o chefe, o jogador ou uma isca.
- Se o alvo morre ou sai do mundo, a autoridade escolhe outro no tique seguinte.
- **Sem alvo:** fica parado e não ataca o jogador, pela **retenção de combate** da decisão A8
  (18/11): `EnemyActor.set_combat_hold(dono, prazo, &"madness_delirium")`, acrescentada pela
  T4. A autoridade procura alvo a cada tique; quando aparece um, a retenção sai e a
  sobrescrita entra. A retenção termina com o Delírio.
- **Teto cheio:** a Loucura fica no limiar (a espera é renovada) até abrir uma vaga. As vagas
  são preenchidas por ordem de chegada ao limiar, e o desempate é pelo `occurrence_id`.
- Ataque: o básico do arquétipo (limitação 3 da API da T1, aceita pela T4). O golpe tem a
  autoria do dono (C1.6): claims, abate, XP e loot são do jogador, uma vez, inclusive em retry.
- Fim: a marca expira (relógio de gameplay) e a sobrescrita do Delírio é limpa. A morte do
  inimigo limpa os dois (`clear_statuses`).

## 4. Desorientação do chefe

| Item | Valor | Faixa |
|---|---|---|
| Duração | 4,0 s | 2–8 s |
| Dano recebido | × 1,20 (de qualquer autor) | 1,00–1,60 |
| Redução de acerto | 0,25 | 0,00–0,60 |
| Chance do golpe no lacaio | 0,35 por golpe | 0,00–1,00 |
| Alcance do lacaio "ao lado" | 110 | 60–200 |
| Imunidade depois | 12,0 s | 6–30 s |

- Marca `madness_disoriented` com o prazo, mais as fontes de C1.7:
  `add_received_damage_source(&"madness_disorientation", ...)` e
  `add_accuracy_source(&"madness_disorientation", ...)`, e o desvio de C1.6:
  `register_commit_deflection(&"madness_disorientation", dono, chance, alcance, prazo)`. O chefe
  **não** troca de alvo. Sem lacaio ao alcance, o golpe segue normal e nenhum sorteio é gasto
  (regra da T1).
- **Imunidade:** marca `madness_immune` com a duração da janela **mais** a imunidade. Durante a
  janela e depois dela, `add` recusa (`immune`).
- `disorient(boss, event, owner, opções)` aceita os números da tabela e
  `bypass_immunity: true`. Esse é o caminho da Revelação (T7): Desorientação forte, que vale uma
  vez por Revelação, pelo evento deduplicado, mesmo sob imunidade, e termina com a imunidade
  maior que a T7 passar.
- O chefe nunca recebe Delírio nem desorientação de movimento (a T1 já recusa
  `apply_disorient` e a sobrescrita).

## 5. Êxtase

| Item | Valor | Faixa |
|---|---|---|
| Cargas | 0–5 (D4) | fixo |
| Ganho | +1 por inimigo que entra em Delírio ou Desorientação | — |
| MATK | +4% por carga (+20% com 5) | 0–8% |
| Custo de SP | −4% por carga (−20% com 5) | 0–8% |
| Ônus (≥ 3 cargas) | dano recebido × (1 + 0,08 × (cargas − 2)): 1,08, 1,16 e 1,24 | 0–15% |
| Decaimento | 6,0 s sem ganho, depois −1 carga a cada 3,0 s | — |

- Liga com `set_ecstasy_enabled(true)` (a passiva Êxtase da T7). Desligado: não ganha, e os
  ajudantes devolvem a identidade. As cargas que restam continuam e decaem.
- Cada entrada dá uma carga uma vez, pela chave `enter:<occurrence_id>:<serial>`, no anel do §2.
- Ajudantes para a costura:
  - `temporary_stat_sources()` → `{"source_id": <prefixo>ecstasy, "label": "Êxtase",
    "increased": {&"magic_attack": 0,04 × cargas}}`, no formato do Marco de Guarda.
    A autoridade chama `refresh_kit_stats()` só quando as cargas mudam;
  - `skill_cost(base)` → `base × (1 − 0,04 × cargas)`;
  - `before_hit(hit)` → `{"damage_multiplier": m}` com 3 cargas ou mais; vazio abaixo de 3.
    Golpe secundário não é multiplicado (regra do Santuário).
- Troca de build: nada muda (sem recarga, sem zerar). Morte do dono: o Êxtase zera.

## 6. Ídolo

| Item | Valor | Faixa |
|---|---|---|
| Por dono | **1** (D4) | fixo |
| HP | 30% do HP máximo do dono | 10–60% |
| Prazo | 8,0 s | 4–15 s |
| Alcance do olhar | 180 | 100–260 |
| Tique | 1,0 s | 0,5–2,0 s |
| Loucura por tique | 8 | 1–40 |

- `place_idol(player, ponto, opções)` cria um `KitDecoy` com `source_tag = &"madness_idol"` e o
  desenhador `&"madness_idol"`; o ID de flipbook reservado é `cultist_impossible_idol`. Um
  segundo Ídolo do mesmo dono remove o anterior (`&"replaced"`).
- A cada tique, os inimigos não-chefe ao alcance que não estão em Delírio e não têm outra
  sobrescrita miram o Ídolo (`&"madness_idol"`, pelo prazo que resta). O Delírio tem
  prioridade. **Todos** os inimigos ao alcance, chefe incluso, ganham a Loucura do tique, com a
  chave `idol:<serial>:<tique>`. O chefe nunca troca de alvo.
- O Ídolo não ataca nem cura. Golpe nele é do inimigo (regra da T1). Expira, é destruído ou
  some com a morte do dono.

## 7. Contágio

| Item | Valor | Faixa |
|---|---|---|
| Duração da marca | 8,0 s | 2–15 s |
| Fração copiada | 0,50 | 0,10–1,00 |
| Raio | 140 | 80–220 |
| Pulso ao entrar em Delírio | 25 | 0–100 |

- Marca `madness_contagion` no inimigo, com um dicionário de dados (fração, raio, pulso). Um
  ganho direto no marcado copia `fração × quantia` para cada vizinho vivo no raio, com a chave
  do evento mais `:copy`. Se o marcado entra em Delírio por um ganho direto, cada vizinho recebe
  um pulso único.
- **Um salto:** cópia e pulso são marcados `copy` e nunca se propagam, nem quando o vizinho
  também tem a marca, nem quando a cópia o leva ao Delírio.

## 8. Snapshot (A4) e pausa

- Fragmento `scripts/systems/madness/snapshot_manifest.json` (e o do fixture) declara cada
  script da pasta, com todas as variáveis.
- **Exato:** Êxtase (cargas e relógios), anel de eventos e o Ídolo (a isca da T1, com dono
  religado, e o relógio do tique na autoridade) voltam iguais. As marcas, a sobrescrita, o
  desvio e as fontes seguem a restauração do inimigo.
- **Compacto:** `compact_blocker()` devolve `madness_idol` com Ídolo ativo (a isca já bloqueia
  pela T1). Sem Ídolo, o compacto preserva o Êxtase, que é estado do jogador. O inimigo volta à
  origem sem marcas.
- **Pausa:** os relógios da autoridade correm só em `tick` (por `on_tick`, que não roda em
  pausa); as marcas, a sobrescrita, o desvio, as fontes e a isca congelam pela T1.

## 9. Leitura para o HUD

`describe(player, actors = [])` é puro: lê, não muda. Devolve o Êxtase (cargas, teto, ônus,
ligado), o Ídolo (HP, HP máximo, prazo), o número de delirantes e o teto, e uma linha por
inimigo com Loucura ou estado (`madness`, `threshold`, `state` = `none`/`pending`/`delirium`/
`disoriented`/`immune`, `remaining` e `contagion`). `MadnessAuthority.describe_enemy(enemy)` dá
a linha de um inimigo só.

## 10. Respostas às regras de C2

| Regra de C2 | Resposta |
|---|---|
| Loucura por inimigo, em `ActorMarks`, com dono, decai | §2 |
| `add` deduplicado por evento | §2 (identidade do ledger + alvo estável) |
| Limiar → Delírio ou Desorientação, Loucura a 0 | §2, §3, §4 |
| Delírio pela sobrescrita, outro alvo se morrer, sem alvo parado | §3 e §1 (retenção A8) |
| Teto 3 por dono, Loucura no limiar até vaga | §3 |
| Nunca mira o chefe; abate do dono; não gera Loucura | §2, §3 |
| Desorientação: erra mais, recebe mais, sem troca de alvo, lacaios pelo desvio, imunidade | §4 |
| Êxtase 0–5, MATK, custo, ônus a partir de 3, decaimento, build não mexe | §5 |
| Ídolo isca 1 por dono, prazo, HP do dono, comuns e elites, Loucura por tique, desenho em código | §6 |
| Contágio de um salto, pulso no Delírio | §7 |
| `describe()` puro | §9 |
| Snapshot e pausa | §8 |
| Invariantes mínimas | `tests/systems/madness/madness_test.gd` (lista no recibo) |
