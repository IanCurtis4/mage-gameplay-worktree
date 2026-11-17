extends ClassKit
## E09 K3 — Duelista (`sp_la`): Espadachim → Ladino (Defendente + Assassino).
## Contract with the numbers: docs/epics/e09/k3_contract.md. Seam: T1/T1.1/T1.2
## (docs/epics/e09/t1_kit_seam_api.md). Costas/ocultação/Sentença: T6 (FlankAuthority).
## The Duelista does not vanish before the fight: the parry creates the back and the
## concealment. A frontal melee hit parried inside the window turns the attacker and
## makes it lose sight; the last parried enemy is the victim that holds the Sentence,
## spent by the Fatal Riposte (C3 execution). Every kit request is marked by the
## authority. Data methods are pure; the variables below are run state (fragment).

const PARRY := &"duelist_parry"
const READ := &"duelist_read_opponent"
const RIPOSTE := &"duelist_fatal_riposte"
const FEINT := &"duelist_feint"
const PATIENT := &"duelist_patient_guard"
const RETREAT := &"duelist_guarded_retreat"
const DUEL := &"duelist_duel"
const SKILLS: Array[StringName] = [PARRY, READ, RIPOSTE, FEINT, PATIENT, RETREAT, DUEL]
const PASSIVES: Array[StringName] = [READ, PATIENT]

const FEINT_KEY := &"duelist_feint"
const REASON_FEINT := &"duelist_feint"
const REASON_AUTO := &"duelist_auto_parry"
const READING_KEY := "duelist_reading"
## Sources of the Sentence counted for kit requests (the Duelista has no concealment source).
const COUNTED := {&"back": true, &"concealment": false, &"direct": true}

# --- Numbers (k3_contract §3) ----------------------------------------------------------
const PARRY_SP: Array[float] = [4.0, 4.0, 4.0, 3.0, 3.0]
const PARRY_COOLDOWN: Array[float] = [1.2, 1.1, 1.0, 0.9, 0.8]
const PARRY_WINDOW: Array[float] = [0.30, 0.32, 0.34, 0.36, 0.38]
const READ_BACK_BONUS: Array[float] = [0.10, 0.15, 0.20]
const RIPOSTE_SP: Array[float] = [10.0, 11.0, 12.0, 13.0, 14.0]
const RIPOSTE_COOLDOWN := 6.0
const RIPOSTE_RANGE := 90.0
const RIPOSTE_POWER: Array[float] = [1.50, 1.70, 1.90, 2.10, 2.30]
const AUTO_PARRY_DURATION := 8.0
const FEINT_SP: Array[float] = [10.0, 10.0, 11.0, 11.0, 12.0]
const FEINT_COOLDOWN: Array[float] = [9.0, 8.5, 8.0, 7.5, 7.0]
const FEINT_RANGE := 220.0
const FEINT_DURATION: Array[float] = [2.5, 2.75, 3.0, 3.25, 3.5]
const FEINT_STEP := 48.0
const PATIENT_DELAY: Array[float] = [3.0, 2.5, 2.0]
const PATIENT_BONUS: Array[float] = [0.10, 0.14, 0.18]
const PATIENCE_CAP := 60.0
const RETREAT_SP: Array[float] = [10.0, 10.0, 11.0, 11.0, 12.0]
const RETREAT_COOLDOWN: Array[float] = [10.0, 9.5, 9.0, 8.5, 8.0]
const RETREAT_SIGHT: Array[float] = [1.2, 1.4, 1.6, 1.8, 2.0]
const RETREAT_STEP := 80.0
const RETREAT_RADIUS := 180.0
const DUEL_SP: Array[float] = [30.0, 32.0, 34.0, 36.0, 38.0]
const DUEL_COOLDOWN: Array[float] = [50.0, 48.0, 46.0, 44.0, 42.0]
const DUEL_DURATION: Array[float] = [4.0, 4.5, 5.0, 5.5, 6.0]
const DUEL_THRUST: Array[float] = [0.90, 1.00, 1.10, 1.20, 1.30]
const STEP_FRACTIONS: Array[float] = [1.0, 2.0 / 3.0, 1.0 / 3.0]

# --- Run state (scripts/classes/sp_la/snapshot_manifest.json) ----------------------------
## Costas/ocultação/Sentença family authority (T6): parry window, victim, Sentence, execution.
var flank := FlankAuthority.new()
## Gameplay seconds without attacking (Guarda Paciente). Reset by every attack (§2).
var patience := 0.0
## Remaining seconds of the Duelo (parry mode of the authority plus the back thrusts).
var duel_remaining := 0.0
## Armed by a Fatal Riposte kill: the next frontal melee hit is parried without a window.
var auto_parry_remaining := 0.0
## Successful parries of this kit object (manual, feint, automatic, Duelo); key of the parry combo.
var parry_serial := 0
## SP paid by the Aparo whose window is open; refunded by a parry through that window
## (rewards the rhythm). Zero once the window closes or another source reopens it.
var parry_refund := 0.0

# --- Catalog data (pure) ------------------------------------------------------------

func kit_id() -> StringName:
	return &"sp_la"

func ready_for_play() -> bool:
	return true

func display_name() -> String:
	return "Duelista"

func skill_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	result.append(_active(PARRY, "Aparo", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, PARRY_SP, PARRY_COOLDOWN, _fill(0.0), PARRY_WINDOW, _fill(1.0), [&"parry_window", &"frontal_melee_only", &"turn_and_break_sight"]))
	result.append(_passive(READ, "Leitura do Oponente", READ_BACK_BONUS, _fill(2.0, 3), [&"sentence_on_last_parried", &"parry_plus_2", &"back_plus_2", &"other_hits_plus_1"]))
	var riposte := _active(RIPOSTE, "Riposte Fatal", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.OFFENSIVE, RIPOSTE_SP, _fill(RIPOSTE_COOLDOWN), _fill(RIPOSTE_RANGE), RIPOSTE_POWER, _fill(FlankRules.EXECUTION_PER_CHARGE), [&"flank_execution", &"spend_sentence", &"auto_parry_on_kill"])
	riposte.can_crit = true
	result.append(riposte)
	result.append(_active(FEINT, "Finta", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.DEFENSIVE, FEINT_SP, FEINT_COOLDOWN, _fill(FEINT_RANGE), FEINT_DURATION, _fill(FEINT_STEP), [&"side_step", &"next_melee_hit_parried"]))
	result.append(_passive(PATIENT, "Guarda Paciente", PATIENT_BONUS, PATIENT_DELAY, [&"parry_window_increased", &"reset_on_attack"]))
	result.append(_active(RETREAT, "Recuo em Guarda", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, RETREAT_SP, RETREAT_COOLDOWN, _fill(RETREAT_RADIUS), RETREAT_SIGHT, _fill(RETREAT_STEP), [&"back_step", &"break_sight", &"parry_window"]))
	result.append(_active(DUEL, "Duelo", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, DUEL_SP, DUEL_COOLDOWN, _fill(0.0), DUEL_DURATION, DUEL_THRUST, [&"parry_mode", &"back_thrust_on_parry"]))
	return result

func learning_entries() -> Array[Dictionary]:
	return [
		{"skill_id": PARRY, "category": &"active", "free_rank": 1, "max_purchased_rank": 4, "job_level": 20},
		{"skill_id": READ, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 23, "prerequisites": {}},
		{"skill_id": RIPOSTE, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 25, "prerequisites": {READ: 1}},
		{"skill_id": FEINT, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 28, "prerequisites": {}},
		{"skill_id": PATIENT, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 31, "prerequisites": {}},
		{"skill_id": RETREAT, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 34, "prerequisites": {}},
		{"skill_id": DUEL, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 37, "prerequisites": {PARRY: 3}},
	]

func feedback_recipes() -> Dictionary:
	return {
		PARRY: [&"buff", &"physical", &"", FeedbackRecipeCatalog.COMMIT],
		READ: [&"buff", &"physical", &"", 0],
		RIPOSTE: [&"impact", &"physical", &"", FeedbackRecipeCatalog.COMMIT],
		FEINT: [&"movement", &"physical", &"", FeedbackRecipeCatalog.COMMIT],
		PATIENT: [&"buff", &"physical", &"", 0],
		RETREAT: [&"movement", &"physical", &"", FeedbackRecipeCatalog.COMMIT],
		DUEL: [&"melee", &"physical", &"", FeedbackRecipeCatalog.COMMIT],
	}

func skill_texts() -> Dictionary:
	var texts := {
		PARRY: {"flavor": "A lâmina fina espera o golpe, não o procura.", "effect": "Ergue a guarda por um instante: um golpe corpo a corpo de frente que chega dentro da janela é aparado. O atacante é girado, fica de costas e perde o Duelista de vista. O aparo no tempo certo devolve o SP do Aparo.", "combo": "O aparado vira o último aparado: é nele que a Sentença acumula.", "mechanics": "Janela de tempo curtíssima; projéteis, áreas e golpes de lado ou de costas não são aparados."},
		READ: {"flavor": "Quem errou o golpe já contou tudo.", "effect": "O último aparado acumula Sentença: aparo +2, golpe pelas costas +2, outros golpes +1. Os golpes do Duelista pelas costas nele causam mais dano.", "combo": "Aparo e estocada pelas costas enchem 4 das 5 cargas.", "mechanics": "Passiva automática; até 5 cargas de Sentença, um alvo por vez."},
		RIPOSTE: {"flavor": "A resposta que encerra a conversa.", "effect": "Golpe final que gasta toda a Sentença do alvo; o dano cresce com cada carga. Com a Sentença cheia e o alvo ferido abaixo do limiar da categoria, é morte certa. No chefe, só dano muito alto.", "combo": "Se matar, o próximo golpe corpo a corpo de frente é aparado sozinho.", "mechanics": "Execução: % do ATQ corpo a corpo × (1 + 0,40 por carga)."},
		FEINT: {"flavor": "Um passo para o lado, e o golpe vai junto.", "effect": "Passo lateral que puxa o golpe do inimigo para o lado: o próximo golpe corpo a corpo dele conta como aparado, de qualquer lado.", "combo": "Force o aparo quando o ritmo do inimigo é difícil de ler.", "mechanics": "Marca no alvo por alguns segundos; projéteis e áreas continuam fora."},
		PATIENT: {"flavor": "A pressa é do outro.", "effect": "Sem atacar por alguns segundos, em guarda, a janela do Aparo e do Recuo em Guarda aumenta.", "combo": "Ataque básico, skills da base e o Riposte zeram a contagem.", "mechanics": "Passiva automática; aparar não zera a contagem."},
		RETREAT: {"flavor": "Recuar também é guardar.", "effect": "Passo para trás mantendo a guarda: os inimigos próximos perdem o Duelista de vista de novo, e a janela de aparo se abre. É a saída.", "combo": "Sem Sentença bastante para o Riposte, recue e apare de novo.", "mechanics": "Passo de até 80; perda de visão num raio de 180."},
		DUEL: {"flavor": "Um contra todos, um golpe de cada vez.", "effect": "Por alguns segundos, todo golpe corpo a corpo de frente é aparado sozinho, e cada aparo devolve uma estocada pelas costas no atacante.", "combo": "Contra três inimigos: cada golpe que vem é aparado, girado e respondido pelas costas.", "mechanics": "Aparos ilimitados de frente; flancos, costas, projéteis e áreas continuam acertando."},
	}
	for skill: StringName in SKILLS:
		var ranks: Array[String] = []
		for rank: int in range(1, (3 if skill in PASSIVES else 5) + 1): ranks.append(rank_tooltip(skill, rank))
		texts[skill]["ranks"] = ranks
		texts[skill]["mechanics"] = String(texts[skill]["mechanics"]) + " " + " · ".join(ranks)
	return texts

## Per-rank tooltip line (pt-BR) of one skill. Pure.
func rank_tooltip(skill_id: StringName, rank: int) -> String:
	var i := rank - 1
	match skill_id:
		PARRY:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP (devolvido ao aparar), recarga %ss, janela %ss" % [rank, _num(PARRY_SP[i]), _num(PARRY_COOLDOWN[i]), _num(PARRY_WINDOW[i])]
		READ:
			if i < 0 or i >= 3: return ""
			return "R%d: golpes pelas costas no último aparado +%d%% de dano" % [rank, roundi(READ_BACK_BONUS[i] * 100.0)]
		RIPOSTE:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, %d%% do ATQ, × 3 com 5 cargas" % [rank, _num(RIPOSTE_SP[i]), roundi(RIPOSTE_POWER[i] * 100.0)]
		FEINT:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, marca %ss" % [rank, _num(FEINT_SP[i]), _num(FEINT_COOLDOWN[i]), _num(FEINT_DURATION[i])]
		PATIENT:
			if i < 0 or i >= 3: return ""
			return "R%d: sem atacar por %ss, janela +%ss" % [rank, _num(PATIENT_DELAY[i]), _num(PATIENT_BONUS[i])]
		RETREAT:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, perda de visão %ss" % [rank, _num(RETREAT_SP[i]), _num(RETREAT_COOLDOWN[i]), _num(RETREAT_SIGHT[i])]
		DUEL:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, %ss, estocada %d%% do ATQ" % [rank, _num(DUEL_SP[i]), _num(DUEL_COOLDOWN[i]), _num(DUEL_DURATION[i]), roundi(DUEL_THRUST[i] * 100.0)]
	return ""

func vfx_effects() -> Dictionary:
	return {
		&"duelist_parry_flash": {"skill_id": PARRY, "kinds": [&"effect_start"], "size": 64.0},
		&"duelist_riposte_lunge": {"skill_id": RIPOSTE, "kinds": [&"effect_start"], "size": 80.0},
		&"duelist_riposte_strike": {"skill_id": RIPOSTE, "kinds": [&"impact"], "size": 72.0},
		&"duelist_feint_step": {"skill_id": FEINT, "kinds": [&"effect_start"], "size": 64.0},
		&"duelist_retreat_step": {"skill_id": RETREAT, "kinds": [&"effect_start"], "size": 90.0},
		&"duelist_duel_ring": {"skill_id": DUEL, "kinds": [&"effect_start"], "size": 120.0},
		&"duelist_duel_thrust": {"skill_id": DUEL, "kinds": [&"impact"], "size": 56.0},
	}

const SILVER := Color(0.86, 0.89, 0.95)
const CRIMSON := Color(0.62, 0.08, 0.14)
const SHADOW := Color(0.08, 0.08, 0.10)

func draw_vfx(effect_id: StringName, canvas: CanvasItem, pulse: Dictionary, position: Vector2, t: float) -> bool:
	var fade := clampf(1.0 - t, 0.0, 1.0)
	var dir: Vector2 = pulse.get("dir", Vector2.RIGHT) if pulse.get("dir") is Vector2 else Vector2.RIGHT
	if dir.is_zero_approx(): dir = Vector2.RIGHT
	dir = dir.normalized()
	var chest := position + Vector2(0.0, -26.0)
	match effect_id:
		&"duelist_parry_flash":
			# Short glint of the parry: a crossed blade spark and a turning arc.
			var reach := 14.0 + 18.0 * minf(1.0, t * 3.0)
			var across := dir.orthogonal()
			canvas.draw_line(chest + dir * 10.0 - across * reach, chest + dir * 10.0 + across * reach, Color(SILVER, fade), 3.0)
			canvas.draw_line(chest + dir * (10.0 + reach * 0.6), chest + dir * (10.0 - reach * 0.6), Color(1.0, 1.0, 1.0, fade), 2.0)
			canvas.draw_arc(chest + dir * 10.0, reach, dir.angle() - 1.2, dir.angle() + 1.2 + TAU * 0.4 * t, 18, Color(CRIMSON, 0.8 * fade), 2.0)
		&"duelist_riposte_lunge":
			var length := 70.0 * minf(1.0, t * 2.5)
			canvas.draw_line(chest, chest + dir * length, Color(SILVER, fade), 3.0)
			canvas.draw_line(chest + dir.orthogonal() * 3.0, chest + dir * length * 0.8 + dir.orthogonal() * 3.0, Color(CRIMSON, 0.6 * fade), 2.0)
		&"duelist_riposte_strike":
			# Sentence marks closing on the target, then the strike line.
			for k: int in 5:
				var angle := TAU * k / 5.0 + t * 2.0
				canvas.draw_circle(chest + Vector2.from_angle(angle) * (26.0 * fade + 6.0), 3.5, Color(CRIMSON, fade))
			canvas.draw_line(chest - dir * 24.0, chest + dir * 24.0, Color(1.0, 1.0, 1.0, fade), 4.0 * fade + 1.0)
		&"duelist_feint_step":
			var side := dir.orthogonal()
			for k: int in 3:
				canvas.draw_line(position - side * (8.0 + 10.0 * k) * (0.4 + t), position - side * (8.0 + 10.0 * k) * (0.4 + t) + Vector2(0.0, -40.0), Color(SHADOW, 0.45 * fade / (k + 1)), 6.0)
			canvas.draw_arc(chest, 22.0, side.angle() - 0.8, side.angle() + 0.8, 12, Color(SILVER, fade), 2.0)
		&"duelist_retreat_step":
			for k: int in 3:
				var back := position + dir * (12.0 + 14.0 * k) * (0.3 + t)
				canvas.draw_line(back + Vector2(-6.0, 0.0), back + Vector2(6.0, 0.0), Color(SILVER, 0.7 * fade), 2.0)
			canvas.draw_arc(chest, 26.0, dir.angle() - 1.0, dir.angle() + 1.0, 14, Color(SILVER, fade), 3.0)
			canvas.draw_arc(position, 20.0 + RETREAT_RADIUS * 0.4 * t, 0.0, TAU, 32, Color(SHADOW, 0.35 * fade), 2.0)
		&"duelist_duel_ring":
			var radius := 30.0 + 60.0 * minf(1.0, t * 2.0)
			canvas.draw_arc(position, radius, 0.0, TAU, 40, Color(CRIMSON, 0.9 * fade), 3.0)
			for k: int in 6:
				var angle := TAU * k / 6.0 + t
				canvas.draw_line(position + Vector2.from_angle(angle) * radius * 0.8, position + Vector2.from_angle(angle) * radius, Color(SILVER, fade), 2.0)
		&"duelist_duel_thrust":
			canvas.draw_line(chest - dir * 30.0, chest + dir * (10.0 + 20.0 * t), Color(SILVER, fade), 3.0)
			canvas.draw_circle(chest + dir * (10.0 + 20.0 * t), 4.0 * fade + 1.0, Color(CRIMSON, fade))
		_:
			return false
	return true

# --- Hooks ----------------------------------------------------------------------------

func on_tick(player: PlayerActor, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	flank.tick(player, delta)
	if parry_refund > 0.0 and not flank.parry_open(): parry_refund = 0.0
	patience = minf(PATIENCE_CAP, patience + delta)
	if duel_remaining > 0.0: duel_remaining = maxf(0.0, duel_remaining - delta)
	if auto_parry_remaining > 0.0: auto_parry_remaining = maxf(0.0, auto_parry_remaining - delta)

func can_cast(_player: PlayerActor, cast: Dictionary) -> Dictionary:
	if StringName(cast.get("skill_id", &"")) == PARRY and duel_active(): return {"ok": false, "error_code": &"duelist_duel_active"}
	return {"ok": true, "error_code": &""}

func on_cast_confirmed(player: PlayerActor, cast: Dictionary) -> void:
	match StringName(cast["skill_id"]):
		RIPOSTE: patience = 0.0
		PARRY: parry_refund = player.skill_cost(PARRY)

## T1.2: every paid commit of a base skill (Investida, Corte, …) is "attacking" for
## the Guarda Paciente. Never called for refused casts or the basic attack.
func on_base_skill_committed(_player: PlayerActor, _skill_id: StringName, _context: Dictionary) -> void:
	patience = 0.0

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	var values := _rank_values(player, skill, int(cast["rank"]))
	if values == null: return false
	match skill:
		PARRY:
			return flank.open_parry(player, parry_window(player), 1)
		RIPOSTE:
			return _resolve_riposte(player, cast, values)
		FEINT:
			var target := cast.get("target") as CombatActor
			if not is_instance_valid(target) or not target.is_alive(): return false
			if not target.marks.set_mark(FEINT_KEY, player.get_instance_id(), 1, values.power): return false
			_feint_step(player, target)
			return true
		RETREAT:
			parry_refund = 0.0
			return _resolve_retreat(player, cast, values)
		DUEL:
			parry_refund = 0.0
			if not flank.open_parry_mode(player, values.power): return false
			duel_remaining = values.power
			return true
	return false

func compose_basic_attack(player: PlayerActor, target: CombatActor, request: DamageRequest) -> DamageRequest:
	patience = 0.0
	return _mark(player, request, target)

## Incoming-hit step 1: Finta on this attacker (any side), then the open window
## (Aparo, Recuo, Duelo), then the automatic parry armed by a Riposte kill. Only
## melee hits; projectiles and areas are never parried.
func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
	if StringName(hit.get("kind", &"")) != &"melee": return {}
	var attacker := hit.get("source") as CombatActor
	if not is_instance_valid(attacker) or not attacker.is_alive() or attacker == player: return {}
	var reason := &""
	if attacker.marks.owner_of(FEINT_KEY) == player.get_instance_id():
		attacker.marks.remove(FEINT_KEY)
		flank.expose(player, attacker)
		reason = REASON_FEINT
	elif flank.parry_open():
		var parry := flank.try_parry(player, hit)
		if bool(parry["parried"]):
			reason = StringName(parry["reason"])
			if parry_refund > 0.0: player.recover_sp(parry_refund)
			parry_refund = 0.0
	elif auto_parry_remaining > 0.0 and flank.open_parry(player, FlankRules.PARRY_WINDOW, 1):
		var automatic := flank.try_parry(player, hit)
		if bool(automatic["parried"]):
			auto_parry_remaining = 0.0
			reason = REASON_AUTO
		else:
			flank.close_parry()
	if reason.is_empty(): return {}
	_on_parried(player, attacker)
	return {"cancel": true, "reason": reason}

func on_damage_dealt(player: PlayerActor, result: Dictionary) -> void:
	if player.skill_rank(READ) <= 0: return
	if FlankRules.result_flags(result).is_empty():
		# Base skill or item hit (not marked by the kit): side read on the confirmed result.
		if not bool(result.get("landed", false)) or float(result.get("damage", 0.0)) <= 0.0 or bool(result.get("secondary", false)): return
		var target := instance_from_id(int(result.get("target_id", 0))) as CombatActor
		if flank.is_victim(player, target) and FlankRules.side_between(target, player)["side"] == FlankRules.BACK:
			var key := FlankAuthority.event_key(result)
			if not key.is_empty(): flank.gain(player, target, FlankRules.SOURCE_BACK, "hit@" + key)
			return
	flank.record_hit(player, result, COUNTED)

func on_kill_confirmed(player: PlayerActor, result: Dictionary) -> void:
	var kill := flank.on_kill_confirmed(player, result)
	if bool(kill["first"]) and bool(kill["execution"]): auto_parry_remaining = AUTO_PARRY_DURATION

func on_death(player: PlayerActor) -> void:
	flank.on_death(player)
	parry_refund = 0.0
	duel_remaining = 0.0
	auto_parry_remaining = 0.0
	patience = 0.0
	for actor: CombatActor in _nearby_actors(player):
		if actor.marks.owner_of(FEINT_KEY) == player.get_instance_id(): actor.marks.remove(FEINT_KEY)

func concealment_active(_player: PlayerActor) -> bool:
	return flank.concealment_active()

func on_reveal(player: PlayerActor, duration: float) -> void:
	flank.on_reveal(player, duration)

# --- Queries --------------------------------------------------------------------------

func duel_active() -> bool:
	return duel_remaining > 0.0

## Window of the next Aparo or Recuo: rank of the Aparo plus the Guarda Paciente
## bonus once the Duelista went long enough without attacking; T6 cap 0.60 s.
func parry_window(player: PlayerActor) -> float:
	var parry_rank := clampi(player.skill_rank(PARRY), 1, 5) if is_instance_valid(player) else 1
	var window := PARRY_WINDOW[parry_rank - 1]
	if patient(player): window += PATIENT_BONUS[clampi(player.skill_rank(PATIENT), 1, 3) - 1]
	return minf(window, FlankRules.PARRY_RANGE.y)

func patient(player: PlayerActor) -> bool:
	var rank := player.skill_rank(PATIENT) if is_instance_valid(player) else 0
	return rank > 0 and patience + 1.0e-6 >= PATIENT_DELAY[clampi(rank, 1, 3) - 1]

func sentence(player: PlayerActor) -> int:
	return flank.sentence(player)

# --- Internals --------------------------------------------------------------------------

## Every kit request: side and opening at commit (T6), then the Leitura bonus on the
## victim from behind.
func _mark(player: PlayerActor, request: DamageRequest, target: CombatActor) -> DamageRequest:
	flank.mark_request(player, request, target)
	return _apply_reading(player, request, target)

## Leitura do Oponente: a kit request from behind on the victim deals more damage.
func _apply_reading(player: PlayerActor, request: DamageRequest, target: CombatActor) -> DamageRequest:
	var rank := player.skill_rank(READ)
	if request == null or rank <= 0 or not flank.is_victim(player, target): return request
	if FlankRules.flags_of(request.effect_snapshot).get("side", &"") != FlankRules.BACK: return request
	var bonus := 1.0 + READ_BACK_BONUS[clampi(rank, 1, 3) - 1]
	request.damage_dealt_multiplier *= bonus
	request.effect_snapshot[READING_KEY] = bonus
	return request

func _on_parried(player: PlayerActor, attacker: CombatActor) -> void:
	parry_serial += 1
	flank.mark_victim(player, attacker)
	if player.skill_rank(READ) > 0: flank.gain(player, attacker, FlankRules.SOURCE_COMBO, "parry:%d" % parry_serial)
	player.presentation_fact.emit(&"skill_committed", PARRY, player.gameplay_facing(), 0.0)
	if duel_active(): _duel_thrust(player, attacker)

func _duel_thrust(player: PlayerActor, attacker: CombatActor) -> void:
	if not is_instance_valid(attacker) or not attacker.is_alive(): return
	var rank := clampi(player.skill_rank(DUEL), 1, 5)
	patience = 0.0
	var request := player.kit_make_request(attacker, DUEL, player.stat_breakdown.value(&"melee_attack") * DUEL_THRUST[rank - 1], 0.0, DamageRequest.AccuracyMode.GEOMETRY, true)
	player.kit_emit_hit(_mark(player, request, attacker), attacker)

func _resolve_riposte(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var target := cast.get("target") as CombatActor
	if not is_instance_valid(target) or not target.is_alive(): return false
	var executed := flank.execute(player, target, RIPOSTE, player.stat_breakdown.value(&"melee_attack") * values.power, 0.0, {"emit": false})
	if not bool(executed["ok"]): return false
	player.kit_emit_hit(_apply_reading(player, executed["request"], target), target)
	return true

func _resolve_retreat(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var start := FlankRules.ground_position(player)
	var back := -player.gameplay_ground_facing()
	_step(player, back, RETREAT_STEP)
	var actors: Array = cast.get("actors", [])
	for candidate: Variant in actors:
		var enemy := candidate as CombatActor
		if not is_instance_valid(enemy) or not enemy.is_alive() or enemy == player: continue
		var offset := FlankRules.ground_position(enemy) - start
		offset.y = 0.0
		if offset.length() <= RETREAT_RADIUS: flank.break_sight(player, enemy, values.power)
	if not duel_active(): flank.open_parry(player, parry_window(player), 1)
	return true

## Side step of the Finta: left of the line to the target, then right; none if blocked.
func _feint_step(player: PlayerActor, target: CombatActor) -> void:
	var toward := FlankRules.ground_position(target) - FlankRules.ground_position(player)
	toward.y = 0.0
	if toward.is_zero_approx(): toward = player.gameplay_ground_facing()
	toward = toward.normalized()
	var left := Vector3(toward.z, 0.0, -toward.x)
	if _step(player, left, FEINT_STEP, [1.0]) <= 0.0: _step(player, -left, FEINT_STEP, [1.0])

## Short legal step on the ground: world through trace_ground + WorldActorMotion.teleport,
## flat arena through a walkable point and a clear segment (the T6 teleport rules).
## Tries the full distance, then the fractions. Returns the distance moved (0 if none).
func _step(player: PlayerActor, ground_direction: Vector3, distance: float, fractions: Array[float] = STEP_FRACTIONS) -> float:
	var heading := Vector3(ground_direction.x, 0.0, ground_direction.z)
	if not heading.is_finite() or heading.is_zero_approx() or not is_instance_valid(player): return 0.0
	heading = heading.normalized()
	for fraction: float in fractions:
		var reach := distance * fraction
		if player.world_motion != null:
			if not player.world_motion.is_current_world(): return 0.0
			var geometry := player.world_motion.geometry
			var traced := geometry.trace_ground(player.world_point(), heading, reach, player.world_motion.profile(), geometry.geometry_revision)
			if not traced.get("ok", false): continue
			var data: Dictionary = traced["data"]["destination"]
			var point := ExpeditionWorldPoint.create(String(data["stage_id"]), String(data["surface_id"]), data["position"])
			if not player.world_motion.teleport(point, reach + 1.0, geometry.geometry_revision).get("ok", false): continue
			return reach
		if player.navigation == null: return 0.0
		var destination := player.global_position + Vector2(heading.x, heading.z) * reach
		if not player.navigation.is_walkable(destination) or not player.navigation.is_segment_clear(player.global_position, destination, 0.0): continue
		player.global_position = destination
		player.velocity = Vector2.ZERO
		return reach
	return 0.0

func _nearby_actors(player: PlayerActor) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	if not is_instance_valid(player): return result
	var parents: Array[Node] = [player]
	if player.get_parent() != null: parents.append(player.get_parent())
	for parent: Node in parents:
		for child: Node in parent.get_children():
			if child is CombatActor and child != player and not result.has(child): result.append(child)
	return result

func _rank_values(player: PlayerActor, skill: StringName, rank: int) -> SkillRankDefinition:
	var values := player.skill_rank_definition(skill) if is_instance_valid(player) else null
	if values != null: return values
	var definition := ClassKitRegistry.skill_definition(skill)
	return definition.rank_definition(clampi(rank, 1, definition.ranks.size())) if definition != null else null

# --- Data builders (pure) ------------------------------------------------------------------

static func _fill(value: float, count: int = 5) -> Array[float]:
	var result: Array[float] = []
	for index: int in count: result.append(value)
	return result

static func _num(value: float) -> String:
	return String.num(value, 2).replace(".", ",")

static func _active(id: StringName, name: String, targeting: SkillDefinition.Targeting, kind: SkillDefinition.ActionKind, costs: Array[float], cooldowns: Array[float], ranges: Array[float], powers: Array[float], secondary: Array[float], effects: Array[StringName]) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.KIT
	definition.targeting = targeting
	definition.action_kind = kind
	definition.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	definition.element = &"physical"
	definition.range = ranges[0]
	for index: int in 5:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.sp_cost = costs[index]
		values.cooldown = cooldowns[index]
		values.range = ranges[index]
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition

static func _passive(id: StringName, name: String, powers: Array[float], secondary: Array[float], effects: Array[StringName]) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.category = SkillDefinition.Category.PASSIVE
	definition.handler_id = SkillDefinition.Handler.KIT
	definition.targeting = SkillDefinition.Targeting.SELF
	definition.action_kind = SkillDefinition.ActionKind.DEFENSIVE
	definition.element = &"physical"
	for index: int in 3:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition
