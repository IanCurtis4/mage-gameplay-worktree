# E10a T4 — API da Loucura, do Êxtase e do Ídolo (C2)

Leitores: T5 (base Acólito), T7 (Cultista), T12 (HUD) e as híbridas futuras da afinidade
Acólito. Os números estão no [contrato curto](t4_contract.md); o recibo é
[t4_delivery.md](t4_delivery.md). A costura da T1 continua em
[t1_base_seam_api.md](t1_base_seam_api.md).

## 1. Quem guarda a autoridade

- Uma `MadnessAuthority` por jogador, num campo do módulo chamado **`madness`** (o nome é
  parte da API: `MadnessAuthority.of(player)` procura esse campo).
- **T5 (base Acólito)** cria a autoridade e repassa os ganchos de ciclo de vida. A base fica
  ligada antes e depois da evolução.
- **T7 (Cultista)** não cria outra. Ele lê a da origem a cada uso, sem guardá-la em campo
  (o snapshot salvaria duas cópias):

```gdscript
func _madness(player: PlayerActor) -> MadnessAuthority:
	return MadnessAuthority.of(player) as MadnessAuthority
```

- Uma híbrida futura de outra origem (Flagelante, por exemplo) cria a sua no próprio campo
  `madness`.

### 1.1 Repasses

| Gancho de `ClassKit` | Quem repassa | Chamada |
|---|---|---|
| `on_attach` | quem cria (T5) | `madness.configure(player, {"stat_source_id": &"acolyte_ecstasy"})` |
| `on_tick` | T5 (T7 pode repassar também: a segunda chamada no mesmo `kit_time` é ignorada) | `madness.tick(player, delta)` |
| `on_death` | quem cria (T5) | `madness.on_death(player)` |
| `on_build_changed` | quem cria; T7 liga ou desliga o Êxtase pela passiva | `madness.on_build_changed(player)`; `madness.set_ecstasy_enabled(player, tem_passiva)` |
| `snapshot_compact_blocker` | quem cria (T5) | `madness.compact_blocker(player)` |
| `temporary_stat_sources` | **só T7** | `madness.temporary_stat_sources(player)` |
| `skill_cost` | **só T7** | `madness.skill_cost(base_cost)` |
| `before_hit_mitigation` | **só T7**, depois do próprio `cancel` | `madness.before_hit(player, hit)` |

Os três últimos ganchos são compostos pela T1 (C1.4: custo encadeado, multiplicadores
multiplicados, fontes concatenadas). Se os dois módulos os repassassem, o Êxtase valeria
duas vezes. Por isso, só o módulo que liga o Êxtase os repassa.

O `stat_source_id` leva o prefixo do módulo. O módulo de base pode deixar
`acolyte_ecstasy`, mesmo que o Êxtase só ligue no Cultista.

## 2. Loucura

| Chamada | Retorno | Uso |
|---|---|---|
| `add(enemy, amount, event, owner, copy = false, actors = [])` | `{"ok", "error_code", "added", "entered"}` | Soma Loucura (0 < `amount` ≤ 100). `entered`: `&""`, `&"delirium"`, `&"disoriented"` ou `&"pending"` |
| `MadnessAuthority.madness_of(enemy)` | `float` | Valor atual |
| `MadnessAuthority.state_of(enemy)` | `StringName` | `none`, `pending`, `delirium`, `disoriented` ou `immune` (`MadnessRules.STATE_*`) |
| `MadnessAuthority.is_maddened(enemy, owner_id = 0)` | `bool` | Delírio ou Desorientação: o filtro da Pupila Aberta |
| `delirium_count(owner, actors = [])` | `int` | Delirantes do dono (teto 3) |

**Evento** (`event`) — escolha um:
- o resultado de um dano: `MadnessHelpers.result_event(result)` (vem de `on_damage_dealt`).
  Para um golpe entre inimigos (Delírio, desvio do chefe), devolve `{}`, e o `add` recusa com
  `missing_event`. O abate por Delírio não gera Loucura;
- o commit de um cast: `MadnessHelpers.cast_event(cast, player.kit_time)` (vem de
  `resolve_cast` ou de `on_cast_confirmed`);
- uma chave própria e estável (`"whisper:%d" % serial`), ou um `CombatEventContext`.

O `add` junta o evento ao alvo (pelo `occurrence_id`) e guarda a chave num anel de 256
entradas. A mesma chave nunca rende duas vezes, nem em retry, nem depois do snapshot exato.
Um mesmo cast em área pode dar Loucura a cada alvo com o mesmo evento.

**Recusas:** `invalid_owner`, `invalid_target` (não é inimigo, é isca ou está morto),
`invalid_amount`, `missing_event`, `duplicate_event`, `already_maddened` (em Delírio ou
Desorientação) e `immune`. A chave fica consumida mesmo quando a recusa vem do estado do
inimigo.

Exemplo (Sussurro da base, cone):

```gdscript
var event := MadnessHelpers.cast_event(cast, player.kit_time)
for enemy: CombatActor in alvos_no_cone:
	madness.add(enemy, 25.0, event, player)
```

## 3. Delírio e Desorientação

O limiar dispara tudo sozinho; a skill só soma Loucura.

- **Delírio** (não chefe): mira o inimigo não-chefe mais próximo, pela sobrescrita da T1, com
  o motivo `MadnessRules.DELIRIUM_REASON`. Escolhe outro alvo se o atual cai. **Teto 3 por
  dono**: com o teto cheio, a Loucura fica no limiar (`pending`) até abrir vaga, em ordem de
  chegada. Sem alvo, retenção de combate (A8): parado, sem atacar o jogador, até aparecer
  alvo. Duração padrão de 5 s; `configure(..., {"delirium_duration": s})` aceita 2–8 s.
- **Desorientação** (chefe): × 1,20 de dano recebido, −25% de acerto, 35% dos golpes num
  lacaio a até 110 (pelo desvio no commit) e imunidade por 4 + 12 s. O chefe nunca troca de
  alvo.
- **Revelação (T7):**

```gdscript
madness.disorient(boss, "revelation:%d" % serial, player, {
	"bypass_immunity": true, "duration": 6.0, "damage_taken": 1.4,
	"minion_chance": 0.6, "immunity": 20.0})
```

  Vale uma vez por evento, mesmo sob imunidade. Opções e faixas em
  `MadnessRules.DISORIENT_DEFAULTS`. Sem `bypass_immunity`, a imunidade recusa (`immune`).

Para "delirantes causam mais dano entre si" (Revelação) e para a Pupila Aberta, use as fontes
da T1 sobre os inimigos com `MadnessAuthority.is_maddened(enemy)`:
`add_received_damage_source(fonte, mult, prazo, owner_id)`. O golpe entre inimigos tem
`source_id` = dono, então o filtro de dono pega os dois.

## 4. Êxtase

| Chamada | Uso |
|---|---|
| `set_ecstasy_enabled(player, bool)` | A passiva Êxtase da T7 liga. Desligado: não ganha e os ajudantes não aplicam nada (as cargas ficam e decaem) |
| `ecstasy.charges`, `ecstasy.has_onus()`, `ecstasy.damage_taken_multiplier()` | Leitura |
| `temporary_stat_sources(player)`, `skill_cost(base)`, `before_hit(player, hit)` | Repasses (§1.1) |
| `configure(player, {"ecstasy": {"matk_per_charge", "cost_per_charge", "onus_per_charge"}})` | Valores por carga, dentro das faixas |

Cada entrada em Delírio ou Desorientação dá +1 carga (0–5). O ônus começa com 3 cargas.
Troca de build não muda nada; a morte zera. Escudo Votivo e Prece (T5) compensam o ônus pelos
caminhos normais de escudo e cura; a T4 não os conhece.

## 5. Ídolo

```gdscript
var point: Variant = cast["anchor"] if bool(cast.get("world", false)) else cast["point"]
var placed := madness.place_idol(player, point, {"duration": 8.0})
# placed = {"ok", "error_code", "decoy"}
```

- `point`: o `Vector2` do mapa plano ou o `ExpeditionWorldPoint` do mundo (`cast["anchor"]`
  quando `cast["world"]`). `host` opcional (padrão: o pai do jogador, o `RunController`).
- Opções: `hp_fraction` (0,30), `duration` (8 s), `radius` (180), `tick` (1 s), `madness`
  (8 por tique). Faixas em `MadnessRules`.
- `idol(player)`, `idols(player)` e `remove_idol(player, reason)`. Um segundo Ídolo substitui o
  primeiro.
- O sistema registra o desenhador `&"madness_idol"` (`MadnessHelpers.draw_idol`). O ID de
  flipbook reservado é `cultist_impossible_idol`. O ator mostra o nome "Ídolo Impossível".

## 6. Contágio (Delírio Compartilhado)

```gdscript
madness.mark_contagion(player, alvo, {"duration": 8.0, "fraction": 0.5, "radius": 140.0, "pulse": 25.0})
```

Um ganho direto no marcado copia `fração × ganho real` aos vizinhos. Se o marcado entra em
Delírio por um ganho direto, cada vizinho recebe um pulso. Cópias e pulsos nunca se propagam
(um salto, D4).

## 7. HUD (T12)

`madness.describe(player, actors = [])` é puro:

```gdscript
{"ecstasy": 3, "ecstasy_cap": 5, "ecstasy_enabled": true, "onus": true, "damage_taken": 1.08,
 "idol": {"hp": 120.0, "max_hp": 150.0, "remaining": 5.2},  # {} sem Ídolo
 "delirium_count": 2, "delirium_cap": 3,
 "enemies": [{"id": 123, "madness": 40.0, "threshold": 100.0, "state": &"none",
              "remaining": 0.0, "boss": false, "contagion": true}]}
```

`MadnessAuthority.describe_enemy(enemy)` dá a linha de um inimigo, para o olho sobre ele.

## 8. Marcas e snapshot

| Marca (`MadnessRules.MARK_*`) | Valor | Prazo |
|---|---|---|
| `madness` | Loucura (float) | sem prazo; decai pelo tique da autoridade |
| `madness_hold` | ordem de chegada no limiar (int; 0 = não espera) | 4 s, renovado a cada ganho |
| `madness_delirium` | 1 | Delírio |
| `madness_disoriented` | 1 | janela do chefe |
| `madness_immune` | 1 | janela + imunidade |
| `madness_contagion` | `{"fraction", "radius", "pulse"}` | marca |

- O dono das marcas é o ID do jogador. Elas seguem a restauração do inimigo; o formato
  compacto devolve o inimigo sem marcas (A4).
- Fragmento `scripts/systems/madness/snapshot_manifest.json`, revisão 1. Um módulo que guarda
  a autoridade declara o campo `madness` no próprio fragmento.
- Exato: Êxtase, anel, relógio do Ídolo e o Ídolo (isca da T1). Compacto: o Êxtase; Ídolo
  ativo o torna inelegível (`madness_idol`, e a isca da T1 também bloqueia).

## 9. Regra de ciclos (A7)

Nenhum script de `scripts/systems/madness/` nomeia a própria `class_name`, e
`MadnessHelpers` não nomeia `MadnessAuthority`. `MadnessAuthority.of()` reconhece a
autoridade pelo caminho do script. Os módulos (T5, T7) podem nomear `MadnessAuthority` à
vontade.

## 10. Limitações

1. **Delírio sem alvo** usa a retenção de combate da A8 (`EnemyActor.set_combat_hold`,
   `clear_combat_hold`, `has_combat_hold`, `combat_hold_remaining`; marca
   `EnemyActor.COMBAT_HOLD_MARK`). Outra tarefa pode usá-la; o motivo vai no valor da marca, e
   a autoridade só limpa as retenções com o motivo `madness_delirium` e o próprio dono.
2. **Ataque sob sobrescrita**: o básico do arquétipo, nunca a skill declarada do mob
   (limitação 3 da T1, aceita).
3. **Inimigos da run** vêm de `RunController.enemies` (pai do jogador), como no Santuário. Um
   inimigo fora dessa lista não é visto pelo tique nem pelo `describe()`.
4. **Golpe nos lacaios** segue a regra da T1: só no ataque básico, na flecha e na skill de mob
   na liberação.
