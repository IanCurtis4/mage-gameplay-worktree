extends ClassBase
## E10a T5 — Acólito (`acolyte`): the base of the Acólito family (Sacerdote 2-1, Cultista 2-2).
## Contract with the numbers: docs/epics/e10a/t5_contract.md. Seam: docs/epics/e10a/t1_base_seam_api.md
## (the base object stays attached before and after the evolution; the evolution kit is the second
## module). Madness: MadnessAuthority (T4), kept in the field `madness`.
## The Acólito has not chosen a side: light (Luz Punitiva, Prece, Escudo Votivo) and shadow (Selo
## Sombrio, Sussurro Perturbador). The Devoção rewards alternating them.
## Script-cycle rule (A7): this script never names EnemyActor or its own class; enemies are
## CombatActor and are recognised by method (MadnessHelpers.is_enemy / hard_controls.boss).
## Data methods are pure; the variables below are run state (snapshot fragment).

const PUNISHING_LIGHT := &"acolyte_punishing_light"
const PRAYER := &"acolyte_prayer"
const VOTIVE_SHIELD := &"acolyte_votive_shield"
const SHADOW_SEAL := &"acolyte_shadow_seal"
const WHISPER := &"acolyte_disturbing_whisper"
const VISION := &"acolyte_eldritch_vision"
const DEVOTION := &"acolyte_devotion"
const FAITH := &"acolyte_protective_faith"
const SKILLS: Array[StringName] = [PUNISHING_LIGHT, PRAYER, VOTIVE_SHIELD, SHADOW_SEAL, WHISPER, VISION, DEVOTION, FAITH]

const LIGHT := &"light"
const SHADOW := &"shadow"
const SEAL_MARK := &"acolyte_shadow_seal"
const SEAL_ACCURACY_SOURCE := &"acolyte_shadow_seal"
const DEVOTION_SOURCE := &"acolyte_devotion"
const FAITH_HEAL_SOURCE := &"acolyte_faith"
const ECSTASY_SOURCE := &"acolyte_ecstasy"

# --- Numbers (t5_contract §3) ---------------------------------------------------------
const BASIC_RANGE := 220.0
const BASIC_POWER := 1.0
const LIGHT_SP: Array[float] = [10.0, 11.0, 12.0, 13.0, 14.0]
const LIGHT_COOLDOWN := 3.0
const LIGHT_RANGE := 300.0
const LIGHT_POWER: Array[float] = [1.40, 1.60, 1.80, 2.00, 2.20]
const PRAYER_SP: Array[float] = [14.0, 15.0, 16.0, 17.0, 18.0]
const PRAYER_COOLDOWN := 10.0
const PRAYER_PULSES := 4
const PRAYER_INTERVAL := 1.0
const PRAYER_TOTAL: Array[float] = [0.16, 0.20, 0.24, 0.28, 0.32]
const VOTIVE_SP: Array[float] = [14.0, 15.0, 16.0, 17.0, 18.0]
const VOTIVE_COOLDOWN := 9.0
const VOTIVE_DURATION := 5.0
const VOTIVE_BASE: Array[float] = [30.0, 42.0, 54.0, 66.0, 78.0]
const SEAL_SP: Array[float] = [16.0, 17.0, 18.0, 19.0, 20.0]
const SEAL_COOLDOWN := 8.0
const SEAL_RANGE := 300.0
const SEAL_DURATION := 6.0
const SEAL_TICKS := 6
const SEAL_POWER: Array[float] = [0.60, 0.75, 0.90, 1.05, 1.20]
const SEAL_ACCURACY: Array[float] = [0.20, 0.24, 0.28, 0.32, 0.36]
const SEAL_MADNESS: Array[float] = [18.0, 20.0, 22.0, 24.0, 26.0]
const WHISPER_SP: Array[float] = [16.0, 17.0, 18.0, 19.0, 20.0]
const WHISPER_COOLDOWN := 10.0
const WHISPER_RANGE: Array[float] = [150.0, 160.0, 170.0, 180.0, 190.0]
const WHISPER_MADNESS: Array[float] = [24.0, 28.0, 32.0, 36.0, 40.0]
const WHISPER_PUSH: Array[float] = [45.0, 55.0, 65.0, 75.0, 85.0]
const WHISPER_HALF_ANGLE_COS := 0.6428  # cos(50 degrees)
const VISION_SP: Array[float] = [14.0, 14.0, 15.0, 15.0, 16.0]
const VISION_COOLDOWN: Array[float] = [18.0, 17.0, 16.0, 15.0, 14.0]
const VISION_DURATION: Array[float] = [6.0, 7.0, 8.0, 9.0, 10.0]
const VISION_RANGE_BONUS: Array[float] = [40.0, 60.0, 80.0, 100.0, 120.0]
const VISION_MADNESS_FACTOR := 2.0
const DEVOTION_BONUS: Array[float] = [0.10, 0.15, 0.20]
const DEVOTION_PAIR_WINDOW := 8.0
const DEVOTION_READY_WINDOW := 8.0
const FAITH_BONUS: Array[float] = [0.10, 0.15, 0.20]

## Prerequisites of section 1 of the contract, closed here (rank >= 1 of a skill of this base).
const PREREQUISITES := {
	VOTIVE_SHIELD: {PRAYER: 1},
	SHADOW_SEAL: {PUNISHING_LIGHT: 1},
	WHISPER: {SHADOW_SEAL: 1},
	VISION: {WHISPER: 1},
	DEVOTION: {PUNISHING_LIGHT: 1, SHADOW_SEAL: 1},
	FAITH: {VOTIVE_SHIELD: 1},
}

# --- Run state (scripts/classes/bases/acolyte/snapshot_manifest.json) -------------------------
## Madness family authority (T4): Loucura, Delírio, Desorientação, Êxtase (off here) and Ídolo.
var madness := MadnessAuthority.new()
## Prece: pulses left, seconds to the next pulse and the fraction of max HP of each pulse.
var prayer_pulses := 0
var prayer_tick := 0.0
var prayer_fraction := 0.0
## Escudo Votivo: seconds left and the capacity granted (to clear only what is still its own).
var votive_remaining := 0.0
var votive_capacity := 0.0
## Selo Sombrio: marked enemy, seconds left, seconds to the next DoT pulse and the pulse prototype.
var marked_target_id := 0
var seal_remaining := 0.0
var seal_tick := 0.0
var seal_prototype: DamageRequest
## Visão Eldritch: seconds left, basic-attack range bonus and the doubled-Madness charge.
var vision_remaining := 0.0
var vision_range_bonus := 0.0
var vision_charged := false
## Devoção: last light/shadow element, seconds to pair it, the MATQ bonus waiting for the next
## skill (and its seconds), `fresh` (set by the pairing commit itself, which it must not boost),
## `spent` (the skill in course uses it) and `rearm` (that skill paired again).
var devotion_element: StringName = &""
var devotion_pair_remaining := 0.0
var devotion_bonus := 0.0
var devotion_ready_remaining := 0.0
var devotion_fresh := false
var devotion_spent := false
var devotion_rearm := false

# --- Catalog data (pure) ------------------------------------------------------------

func base_id() -> StringName:
	return &"acolyte"

func ready_for_play() -> bool:
	return true

func display_name() -> String:
	return "Acólito"

func initial_attributes() -> Dictionary[StringName, int]:
	return {&"str": 3, &"agi": 4, &"vit": 7, &"int": 8, &"dex": 5, &"luk": 3}

func basic_attack() -> Dictionary:
	return {"delivery": &"magic", "range": BASIC_RANGE, "power": BASIC_POWER}

func starting_skill_ids() -> Array[StringName]:
	return [PUNISHING_LIGHT, PRAYER]

func starting_passive_id() -> StringName:
	return FAITH

func skill_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	var light := _active(PUNISHING_LIGHT, "Luz Punitiva", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.OFFENSIVE, LIGHT, LIGHT_SP, _fill(LIGHT_COOLDOWN), _fill(LIGHT_RANGE), LIGHT_POWER, _fill(0.0), [&"light_projectile", &"first_enemy_in_line"])
	light.can_crit = true
	result.append(light)
	result.append(_active(PRAYER, "Prece", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, LIGHT, PRAYER_SP, _fill(PRAYER_COOLDOWN), _fill(0.0), PRAYER_TOTAL, _fill(float(PRAYER_PULSES)), [&"heal_over_time", &"four_pulses"]))
	result.append(_active(VOTIVE_SHIELD, "Escudo Votivo", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, LIGHT, VOTIVE_SP, _fill(VOTIVE_COOLDOWN), _fill(0.0), VOTIVE_BASE, _fill(VOTIVE_DURATION), [&"personal_shield", &"short_barrier"]))
	result.append(_active(SHADOW_SEAL, "Selo Sombrio", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.OFFENSIVE, SHADOW, SEAL_SP, _fill(SEAL_COOLDOWN), _fill(SEAL_RANGE), SEAL_POWER, SEAL_ACCURACY, [&"seal_mark", &"shadow_dot", &"enemy_accuracy_down", &"madness"]))
	result.append(_active(WHISPER, "Sussurro Perturbador", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.OFFENSIVE, SHADOW, WHISPER_SP, _fill(WHISPER_COOLDOWN), WHISPER_RANGE, WHISPER_MADNESS, WHISPER_PUSH, [&"short_cone", &"madness", &"push_common_enemies"]))
	result.append(_active(VISION, "Visão Eldritch", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, &"", VISION_SP, VISION_COOLDOWN, _fill(0.0), VISION_DURATION, VISION_RANGE_BONUS, [&"basic_range_up", &"next_seal_or_whisper_doubles_madness"]))
	result.append(_passive(DEVOTION, "Devoção", &"", DEVOTION_BONUS, _fill(DEVOTION_PAIR_WINDOW, 3), [&"light_shadow_alternation", &"next_skill_stronger"]))
	result.append(_passive(FAITH, "Fé Protetora", LIGHT, FAITH_BONUS, _fill(0.0, 3), [&"heal_received_up", &"votive_shield_up"]))
	return result

func learning_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill: StringName in SKILLS:
		var passive := skill == DEVOTION or skill == FAITH
		result.append({"skill_id": skill, "category": &"passive" if passive else &"active", "max_purchased_rank": 3 if passive else 5, "job_level": 1, "prerequisites": PREREQUISITES.get(skill, {})})
	return result

func feedback_recipes() -> Dictionary:
	return {
		PUNISHING_LIGHT: [&"projectile", LIGHT, &"", FeedbackRecipeCatalog.COMMIT],
		PRAYER: [&"buff", LIGHT, &"", FeedbackRecipeCatalog.COMMIT],
		VOTIVE_SHIELD: [&"buff", LIGHT, &"", FeedbackRecipeCatalog.COMMIT],
		SHADOW_SEAL: [&"buff", SHADOW, &"", FeedbackRecipeCatalog.COMMIT | FeedbackRecipeCatalog.PERIODIC],
		WHISPER: [&"area", SHADOW, &"", FeedbackRecipeCatalog.COMMIT],
		VISION: [&"buff", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		DEVOTION: [&"buff", &"arcane", &"", 0],
		FAITH: [&"buff", LIGHT, &"", 0],
	}

func basic_attack_recipe() -> Array:
	return [&"projectile", LIGHT, &"", 0]

func skill_texts() -> Dictionary:
	var texts := {
		PUNISHING_LIGHT: {"flavor": "A luz também sabe cobrar.", "effect": "Lança um projétil de luz que fere o inimigo escolhido. É o dano à distância do Acólito.", "combo": "Seguida de uma skill de sombra (ou o contrário), alimenta a Devoção.", "mechanics": "Dano mágico de luz; alcance 300."},
		PRAYER: {"flavor": "Oração curta, dita sem pressa.", "effect": "Cura o Acólito aos poucos, em quatro pulsos, por uma parte do HP máximo.", "combo": "Cura que passa do HP máximo vira Graça no Sacerdote; a Fé Protetora a faz render mais.", "mechanics": "Cura própria em 4 pulsos de 1s."},
		VOTIVE_SHIELD: {"flavor": "Uma vela acesa basta para fazer sombra.", "effect": "Uma barreira curta absorve dano por 5s.", "combo": "Compensa o ônus do Êxtase do Cultista e alimenta a Graça do Sacerdote.", "mechanics": "Escudo pessoal como o da Perseverança."},
		SHADOW_SEAL: {"flavor": "Ele não escolheu a sombra. Ela escolheu o que ele marca.", "effect": "Marca um inimigo: ele sofre dano de sombra aos poucos, erra mais e acumula Loucura.", "combo": "Com a Visão Eldritch carregada, a Loucura do Selo vale o dobro. No chefe, a Loucura cheia o desorienta.", "mechanics": "Marca de 6s, um alvo por vez; dano de sombra por segundo; menos acerto; Loucura."},
		WHISPER: {"flavor": "Algo atrás de você diz o seu nome.", "effect": "Um sussurro em cone curto dá Loucura aos inimigos à frente e afasta os comuns por um instante. O chefe não recua.", "combo": "Com a Visão Eldritch carregada, a Loucura do Sussurro vale o dobro.", "mechanics": "Cone curto de 50° de semiângulo; sem dano; empurra os comuns."},
		VISION: {"flavor": "Os olhos se abrem para o que não devia ser visto.", "effect": "Por alguns segundos, o ataque básico alcança mais longe, e o próximo Selo Sombrio ou Sussurro dá o dobro de Loucura.", "combo": "Feche com o Sussurro para levar a Loucura ao limiar.", "mechanics": "Reforço curto; a carga some ao usar ou ao fim do reforço."},
		DEVOTION: {"flavor": "Servir e contemplar são o mesmo ofício, em turnos.", "effect": "Usar uma skill de luz e depois uma de sombra (ou o contrário) deixa a skill seguinte mais forte.", "combo": "Vale também para as skills da evolução, pelo elemento de cada uma.", "mechanics": "Passiva automática; alterna light e shadow em até 8s."},
		FAITH: {"flavor": "Quem crê é mais difícil de ferir.", "effect": "Toda cura recebida rende mais, e toda barreira recebida fica mais forte: o Escudo Votivo, a Égide do Sacerdote e as outras.", "combo": "Soma-se à cura do Santuário e à Graça do Sacerdote.", "mechanics": "Passiva automática; cura extra do mesmo tamanho pedido; barreiras de qualquer fonte, uma vez cada."},
	}
	for skill: StringName in SKILLS:
		var ranks: Array[String] = []
		for rank: int in range(1, (3 if skill in [DEVOTION, FAITH] else 5) + 1): ranks.append(rank_tooltip(skill, rank))
		texts[skill]["ranks"] = ranks
		texts[skill]["mechanics"] = String(texts[skill]["mechanics"]) + " " + " · ".join(ranks)
	return texts

## Per-rank tooltip line (pt-BR) of one skill. Pure.
func rank_tooltip(skill_id: StringName, rank: int) -> String:
	var i := rank - 1
	match skill_id:
		PUNISHING_LIGHT:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, %d%% do MATQ" % [rank, _num(LIGHT_SP[i]), _num(LIGHT_COOLDOWN), roundi(LIGHT_POWER[i] * 100.0)]
		PRAYER:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, cura %d%% do HP máximo em %d pulsos" % [rank, _num(PRAYER_SP[i]), _num(PRAYER_COOLDOWN), roundi(PRAYER_TOTAL[i] * 100.0), PRAYER_PULSES]
		VOTIVE_SHIELD:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, barreira %d + VIT/INT por %ss" % [rank, _num(VOTIVE_SP[i]), _num(VOTIVE_COOLDOWN), int(VOTIVE_BASE[i]), _num(VOTIVE_DURATION)]
		SHADOW_SEAL:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, marca %ss, sombra %d%% do MATQ no total, acerto do inimigo −%d%%, Loucura %d" % [rank, _num(SEAL_SP[i]), _num(SEAL_COOLDOWN), _num(SEAL_DURATION), roundi(SEAL_POWER[i] * 100.0), roundi(SEAL_ACCURACY[i] * 100.0), int(SEAL_MADNESS[i])]
		WHISPER:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, alcance %d, Loucura %d, empurra %d" % [rank, _num(WHISPER_SP[i]), _num(WHISPER_COOLDOWN), int(WHISPER_RANGE[i]), int(WHISPER_MADNESS[i]), int(WHISPER_PUSH[i])]
		VISION:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, %ss, alcance do básico +%d" % [rank, _num(VISION_SP[i]), _num(VISION_COOLDOWN[i]), _num(VISION_DURATION[i]), int(VISION_RANGE_BONUS[i])]
		DEVOTION:
			if i < 0 or i >= 3: return ""
			return "R%d: a skill seguinte ao par luz e sombra sai com MATQ +%d%%" % [rank, roundi(DEVOTION_BONUS[i] * 100.0)]
		FAITH:
			if i < 0 or i >= 3: return ""
			return "R%d: cura recebida e barreiras recebidas +%d%%" % [rank, roundi(FAITH_BONUS[i] * 100.0)]
	return ""

func vfx_effects() -> Dictionary:
	return {
		&"acolyte_light_bolt": {"skill_id": PUNISHING_LIGHT, "kinds": [&"impact"], "size": 64.0},
		&"acolyte_prayer_glow": {"skill_id": PRAYER, "kinds": [&"effect_start"], "size": 90.0},
		&"acolyte_votive_ward": {"skill_id": VOTIVE_SHIELD, "kinds": [&"effect_start"], "size": 90.0},
		&"acolyte_seal_mark": {"skill_id": SHADOW_SEAL, "kinds": [&"effect_start"], "size": 80.0},
		&"acolyte_whisper_wave": {"skill_id": WHISPER, "kinds": [&"effect_start"], "size": 190.0},
		&"acolyte_vision_eye": {"skill_id": VISION, "kinds": [&"effect_start"], "size": 80.0},
	}

const IVORY := Color(1.0, 0.97, 0.86)
const GOLD := Color(1.0, 0.84, 0.38)
const INK := Color(0.08, 0.07, 0.14)
const MAGENTA := Color(0.86, 0.22, 0.62)
const TURQUOISE := Color(0.32, 0.86, 0.78)

func draw_vfx(effect_id: StringName, canvas: CanvasItem, pulse: Dictionary, position: Vector2, t: float) -> bool:
	var fade := clampf(1.0 - t, 0.0, 1.0)
	match effect_id:
		&"acolyte_light_bolt":
			for k: int in 8:
				var direction := Vector2.from_angle(k * TAU / 8.0)
				canvas.draw_line(position + direction * (6.0 + 8.0 * t), position + direction * (14.0 + 22.0 * t), Color(GOLD, fade), 2.0)
			canvas.draw_circle(position, 7.0 * fade + 2.0, Color(IVORY, 0.9 * fade))
		&"acolyte_prayer_glow":
			for k: int in 5:
				var drift := Vector2(sin(t * TAU + k * 1.3) * 12.0, -10.0 - 34.0 * t - 5.0 * k)
				canvas.draw_circle(position + drift, 2.8 * fade + 0.8, Color(IVORY, 0.85 * fade))
			canvas.draw_arc(position + Vector2(0.0, -4.0), 18.0 + 10.0 * t, 0.0, TAU, 24, Color(GOLD, 0.7 * fade), 2.0)
		&"acolyte_votive_ward":
			for k: int in 6:
				var angle := k * TAU / 6.0 + t * 0.8
				var spot := position + Vector2(cos(angle) * 22.0, -20.0 + sin(angle) * 10.0)
				canvas.draw_line(spot, spot + Vector2(0.0, -7.0), Color(IVORY, fade), 3.0)
				canvas.draw_circle(spot + Vector2(0.0, -9.0), 2.2, Color(GOLD, fade))
			canvas.draw_arc(position + Vector2(0.0, -20.0), 24.0, 0.0, TAU, 28, Color(GOLD, 0.6 * fade), 2.0)
		&"acolyte_seal_mark":
			var radius := 44.0 * (1.0 - 0.5 * t)
			var center := position + Vector2(0.0, -20.0)
			canvas.draw_arc(center, radius, 0.0, TAU, 28, Color(MAGENTA, fade), 3.0)
			canvas.draw_arc(center, radius * 0.6, 0.0, TAU, 20, Color(TURQUOISE, 0.8 * fade), 2.0)
			for k: int in 3: canvas.draw_line(center + Vector2.from_angle(k * TAU / 3.0 + t) * radius * 0.6, center + Vector2.from_angle((k + 1) * TAU / 3.0 + t) * radius * 0.6, Color(INK, 0.9 * fade), 2.0)
		&"acolyte_whisper_wave":
			var direction: Vector2 = pulse.get("dir", Vector2.RIGHT)
			if direction.is_zero_approx(): direction = Vector2.RIGHT
			var reach := 170.0 * minf(1.0, t * 2.5)
			for k: int in 3:
				var arc_reach := reach * (0.5 + 0.25 * k)
				canvas.draw_arc(position, arc_reach, direction.angle() - 0.87, direction.angle() + 0.87, 18, Color(MAGENTA, 0.8 * fade), 2.5)
			canvas.draw_arc(position, reach, direction.angle() - 0.87, direction.angle() + 0.87, 18, Color(TURQUOISE, 0.6 * fade), 1.5)
		&"acolyte_vision_eye":
			var eye := position + Vector2(0.0, -34.0 - 6.0 * t)
			var open := 0.25 + 0.65 * sin(minf(1.0, t * 1.6) * PI)
			var lid := PackedVector2Array()
			for i: int in 13:
				var a := PI * float(i) / 12.0
				lid.append(eye + Vector2(cos(a) * 14.0, -sin(a) * 14.0 * open))
			for i: int in range(11, 0, -1):
				var a := PI * float(i) / 12.0
				lid.append(eye + Vector2(cos(a) * 14.0, sin(a) * 14.0 * open))
			canvas.draw_colored_polygon(lid, Color(IVORY, 0.85 * fade))
			canvas.draw_circle(eye, 4.5 * open + 1.0, Color(TURQUOISE, fade))
			canvas.draw_circle(eye, 1.8, Color(INK, fade))
		_:
			return false
	return true

# --- Hooks ----------------------------------------------------------------------------

func on_attach(player: PlayerActor) -> void:
	madness.configure(player, {"stat_source_id": ECSTASY_SOURCE})

func on_tick(player: PlayerActor, delta: float) -> void:
	madness.tick(player, delta)
	_tick_prayer(player, delta)
	_tick_votive(player, delta)
	_tick_seal(player, delta)
	_tick_vision(delta)
	_tick_devotion(player, delta)

## The Devoção bonus is the only stat source of the base. The Êxtase (temporary_stat_sources,
## skill_cost, before_hit_mitigation of the authority) is forwarded by the Cultista, never here (T4 §1.1).
func temporary_stat_sources(_player: PlayerActor) -> Array[Dictionary]:
	if devotion_bonus <= 0.0 or devotion_ready_remaining <= 0.0 or devotion_fresh: return []
	return [{"source_id": DEVOTION_SOURCE, "label": "Devoção", "increased": {&"magic_attack": devotion_bonus}}]

func on_cast_confirmed(player: PlayerActor, cast: Dictionary) -> void:
	_note_commit(player, StringName(cast["skill_id"]), StringName(cast.get("element", &"")))

## The evolution's commits join the Devoção by their element (the Sacerdote's are all light).
func on_base_skill_committed(player: PlayerActor, skill_id: StringName, context: Dictionary) -> void:
	_note_commit(player, skill_id, StringName(context.get("element", &"")))

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	var values := _rank_values(player, skill, int(cast["rank"]))
	if values == null: return false
	match skill:
		PUNISHING_LIGHT: return _resolve_light(player, cast, values)
		PRAYER: return _resolve_prayer(values)
		VOTIVE_SHIELD: return _resolve_votive(player, values)
		SHADOW_SEAL: return _resolve_seal(player, cast, values)
		WHISPER: return _resolve_whisper(player, cast, values)
		VISION: return _resolve_vision(values)
	return false

## Basic attack: the base data, plus the Visão Eldritch range bonus while it lasts.
func basic_attack_profile(player: PlayerActor) -> Dictionary:
	var profile := super.basic_attack_profile(player)
	if vision_remaining > 0.0 and vision_range_bonus > 0.0 and profile.has("range"): profile["range"] = float(profile["range"]) + vision_range_bonus
	return profile

## Fé Protetora: every heal reported to the player yields an extra heal of `bonus` times the
## requested amount. The bonus heals (this one and the Santuário's) are never multiplied again.
func on_heal(player: PlayerActor, requested: float, _applied: float, source: StringName) -> void:
	if source == FAITH_HEAL_SOURCE or source == SanctuaryRules.HEAL_BONUS_SOURCE or requested <= 0.0 or not is_finite(requested): return
	var rank := player.skill_rank(FAITH) if is_instance_valid(player) else 0
	if rank < 1: return
	player.heal_player(requested * FAITH_BONUS[clampi(rank, 1, 3) - 1], FAITH_HEAL_SOURCE)

## Fé Protetora (T15, A15.3): every barrier the player gains (Escudo Votivo, Égide of the
## Sacerdote, any later producer through CombatActor.grant_barrier) is +10/15/20%. Once per
## grant: the composition calls each module once, and the Votive asks for the plain capacity.
func barrier_received(player: PlayerActor, capacity: float, _context: Dictionary) -> float:
	var rank := player.skill_rank(FAITH) if is_instance_valid(player) else 0
	if rank < 1: return capacity
	return capacity * (1.0 + FAITH_BONUS[clampi(rank, 1, 3) - 1])

func on_death(player: PlayerActor) -> void:
	madness.on_death(player)
	prayer_pulses = 0
	prayer_tick = 0.0
	prayer_fraction = 0.0
	votive_remaining = 0.0
	votive_capacity = 0.0
	_end_seal()
	vision_remaining = 0.0
	vision_range_bonus = 0.0
	vision_charged = false
	var had_bonus := devotion_bonus > 0.0 and devotion_ready_remaining > 0.0
	devotion_element = &""
	devotion_pair_remaining = 0.0
	devotion_bonus = 0.0
	devotion_ready_remaining = 0.0
	devotion_fresh = false
	devotion_spent = false
	devotion_rearm = false
	if had_bonus and is_instance_valid(player): player.refresh_kit_stats()

## Build change: nothing recharges or resets; the waiting Devoção bonus follows the new rank.
func on_build_changed(player: PlayerActor) -> void:
	madness.on_build_changed(player)
	if devotion_ready_remaining <= 0.0 or not is_instance_valid(player): return
	var rank := player.skill_rank(DEVOTION)
	var wanted := DEVOTION_BONUS[clampi(rank, 1, 3) - 1] if rank > 0 else 0.0
	if is_equal_approx(wanted, devotion_bonus): return
	devotion_bonus = wanted
	if wanted <= 0.0: devotion_ready_remaining = 0.0
	player.refresh_kit_stats()

## The Selo leaves its mark and the accuracy debuff on an enemy the compact cut would restore
## fresh, and the Escudo Votivo is a barrier without a compact projection: both force the exact format.
func snapshot_compact_blocker(player: PlayerActor) -> String:
	if seal_remaining > 0.0: return "acolyte_shadow_seal"
	if votive_remaining > 0.0: return "acolyte_votive_shield"
	return madness.compact_blocker(player)

# --- Queries --------------------------------------------------------------------------

func prayer_active() -> bool:
	return prayer_pulses > 0

func seal_active() -> bool:
	return seal_remaining > 0.0

func vision_active() -> bool:
	return vision_remaining > 0.0

func devotion_ready() -> bool:
	return devotion_ready_remaining > 0.0 and devotion_bonus > 0.0

# --- Skills ---------------------------------------------------------------------------

func _resolve_light(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var victim := cast.get("target") as CombatActor
	if not is_instance_valid(victim) or not victim.is_alive(): return false
	var request := player.kit_make_request(victim, PUNISHING_LIGHT, 0.0, player.stat_breakdown.value(&"magic_attack") * values.power, DamageRequest.AccuracyMode.GEOMETRY, true)
	player.kit_emit_projectile(request, victim, &"mage")
	return true

func _resolve_prayer(values: SkillRankDefinition) -> bool:
	prayer_pulses = PRAYER_PULSES
	prayer_tick = PRAYER_INTERVAL
	prayer_fraction = values.power / float(PRAYER_PULSES)
	return true

## The Fé Protetora reinforces the Votive through barrier_received, like any other barrier
## (T15, A15.3): the capacity here is the plain one, so it is never counted twice.
func _resolve_votive(player: PlayerActor, values: SkillRankDefinition) -> bool:
	var capacity := StatCalculator.personal_shield_capacity(values.power, player.stat_breakdown)
	if not is_finite(capacity) or capacity <= 0.0: return false
	var granted := player.grant_barrier(capacity, VOTIVE_SHIELD)
	if granted <= 0.0: return false
	votive_capacity = granted
	votive_remaining = values.secondary_power
	player.resources_changed.emit()
	return true

func _resolve_seal(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var victim := cast.get("target") as CombatActor
	if not is_instance_valid(victim) or not victim.is_alive() or victim == player: return false
	if marked_target_id != 0 and marked_target_id != victim.get_instance_id(): _end_seal()
	var owner_id := player.get_instance_id()
	if not victim.marks.set_mark(SEAL_MARK, owner_id, values.rank, SEAL_DURATION): return false
	victim.add_accuracy_source(SEAL_ACCURACY_SOURCE, values.secondary_power, SEAL_DURATION, owner_id)
	var pulse := player.kit_make_request(null, SHADOW_SEAL, 0.0, player.stat_breakdown.value(&"magic_attack") * values.power / float(SEAL_TICKS), DamageRequest.AccuracyMode.GEOMETRY, false)
	pulse.is_secondary = true
	seal_prototype = pulse
	marked_target_id = victim.get_instance_id()
	seal_remaining = SEAL_DURATION
	seal_tick = 1.0
	var amount := SEAL_MADNESS[clampi(values.rank, 1, 5) - 1] * _vision_factor()
	madness.add(victim, minf(amount, MadnessRules.THRESHOLD), MadnessHelpers.cast_event(cast, player.kit_time), player, false, cast.get("actors", []))
	return true

func _resolve_whisper(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var victim := cast.get("target") as CombatActor
	if not is_instance_valid(victim) or not victim.is_alive(): return false
	var actors: Array = cast.get("actors", [])
	if actors.is_empty(): actors = [victim]
	var direction := _offset(player, victim)
	var facing: Variant = cast.get("facing_2d")
	if facing is Vector2 and not (facing as Vector2).is_zero_approx(): direction = facing
	direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var amount := minf(WHISPER_MADNESS[clampi(values.rank, 1, 5) - 1] * _vision_factor(), MadnessRules.THRESHOLD)
	var push := WHISPER_PUSH[clampi(values.rank, 1, 5) - 1]
	var event := MadnessHelpers.cast_event(cast, player.kit_time)
	var reached := 0
	# T15 (A20): in the world, the cone reaches only the Acolyte's floor.
	var anchor := ClassKit.world_anchor(player)
	var area := ClassKit.floor_area(player, anchor)
	for candidate: Variant in actors:
		var enemy := candidate as CombatActor
		if enemy == null or enemy == player or not MadnessHelpers.is_enemy(enemy) or not MadnessHelpers.is_live(enemy): continue
		var offset := _offset(player, enemy)
		if offset.length() > values.range + enemy.collision_radius: continue
		if not offset.is_zero_approx() and offset.normalized().dot(direction) < WHISPER_HALF_ANGLE_COS: continue
		if not ClassKit.on_anchor_floor(area, anchor, enemy, values.range): continue
		reached += 1
		madness.add(enemy, amount, event, player, false, actors)
		if is_instance_valid(enemy) and enemy.is_alive() and not enemy.hard_controls.boss: _push(player, enemy, offset, push)
	return reached > 0

func _resolve_vision(values: SkillRankDefinition) -> bool:
	vision_remaining = values.power
	vision_range_bonus = values.secondary_power
	vision_charged = true
	return true

# --- Clocks ---------------------------------------------------------------------------

func _tick_prayer(player: PlayerActor, delta: float) -> void:
	if prayer_pulses <= 0: return
	prayer_tick -= delta
	while prayer_tick <= 0.00001 and prayer_pulses > 0:
		prayer_tick += PRAYER_INTERVAL
		prayer_pulses -= 1
		player.heal_player(player.health.max_hp * prayer_fraction, PRAYER)
	if prayer_pulses <= 0:
		prayer_tick = 0.0
		prayer_fraction = 0.0

func _tick_votive(player: PlayerActor, delta: float) -> void:
	if votive_remaining <= 0.0: return
	votive_remaining = maxf(0.0, votive_remaining - delta)
	if player.health.shield_hp <= 0.0: votive_remaining = 0.0
	if votive_remaining > 0.0: return
	if player.health.shield_hp > 0.0 and player.health.shield_hp <= votive_capacity + 0.001:
		player.health.clear_shield()
		player.resources_changed.emit()
	votive_capacity = 0.0

func _tick_seal(player: PlayerActor, delta: float) -> void:
	if seal_remaining <= 0.0: return
	var enemy := _marked_enemy()
	if enemy == null or not enemy.is_alive():
		_end_seal()
		return
	seal_remaining = maxf(0.0, seal_remaining - delta)
	seal_tick -= delta
	while seal_tick <= 0.00001 and seal_prototype != null:
		seal_tick += 1.0
		var hit := seal_prototype.scheduled_tick()
		if hit.cancelled: continue
		hit.target_id = enemy.get_instance_id()
		player.kit_emit_hit(hit, enemy)
		if not is_instance_valid(enemy) or not enemy.is_alive(): break
	if seal_remaining <= 0.0 or not is_instance_valid(enemy) or not enemy.is_alive(): _end_seal()

func _tick_vision(delta: float) -> void:
	if vision_remaining <= 0.0: return
	vision_remaining = maxf(0.0, vision_remaining - delta)
	if vision_remaining <= 0.0:
		vision_range_bonus = 0.0
		vision_charged = false

func _tick_devotion(player: PlayerActor, delta: float) -> void:
	if devotion_pair_remaining > 0.0:
		devotion_pair_remaining = maxf(0.0, devotion_pair_remaining - delta)
		if devotion_pair_remaining <= 0.0: devotion_element = &""
	var changed := false
	if devotion_spent:
		devotion_spent = false
		devotion_ready_remaining = DEVOTION_READY_WINDOW if devotion_rearm else 0.0
		if not devotion_rearm: devotion_bonus = 0.0
		devotion_rearm = false
		devotion_fresh = false
		changed = true
	elif devotion_fresh:
		devotion_fresh = false
		changed = true
	elif devotion_ready_remaining > 0.0:
		devotion_ready_remaining = maxf(0.0, devotion_ready_remaining - delta)
		if devotion_ready_remaining <= 0.0:
			devotion_bonus = 0.0
			changed = true
	if changed and is_instance_valid(player): player.refresh_kit_stats()

# --- Devoção --------------------------------------------------------------------------

## One paid commit of any skill of the player (own or the evolution's). A skill with the
## opposite light/shadow element of the previous one (within the window) makes the NEXT skill
## stronger; the pairing commit itself is not boosted (`fresh`). A skill that uses the waiting
## bonus holds it until the next tick (`spent`) so its own resolution still sees the stat.
func _note_commit(player: PlayerActor, _skill_id: StringName, element: StringName) -> void:
	var rank := player.skill_rank(DEVOTION) if is_instance_valid(player) else 0
	if rank < 1: return
	if devotion_ready():
		devotion_spent = true
	if element != LIGHT and element != SHADOW: return
	var paired := devotion_element != &"" and devotion_element != element and devotion_pair_remaining > 0.0
	devotion_element = element
	devotion_pair_remaining = DEVOTION_PAIR_WINDOW
	if not paired: return
	devotion_bonus = DEVOTION_BONUS[clampi(rank, 1, 3) - 1]
	if devotion_spent:
		devotion_rearm = true
	else:
		devotion_ready_remaining = DEVOTION_READY_WINDOW
		devotion_fresh = true

# --- Internals --------------------------------------------------------------------------

## Madness multiplier of the Visão Eldritch charge; consumes the charge.
func _vision_factor() -> float:
	if not vision_charged or vision_remaining <= 0.0: return 1.0
	vision_charged = false
	return VISION_MADNESS_FACTOR

func _marked_enemy() -> CombatActor:
	if marked_target_id == 0: return null
	var found: Object = instance_from_id(marked_target_id)
	return found as CombatActor if found != null and is_instance_valid(found) else null

func _end_seal() -> void:
	var enemy := _marked_enemy()
	if enemy != null:
		enemy.marks.remove(SEAL_MARK)
		enemy.remove_accuracy_source(SEAL_ACCURACY_SOURCE)
	marked_target_id = 0
	seal_remaining = 0.0
	seal_tick = 0.0
	seal_prototype = null

## Offset from the player to an enemy on the ground plane, on either path (flat arena or world).
func _offset(player: PlayerActor, enemy: CombatActor) -> Vector2:
	if player.world_motion != null and player.world_point() != null and enemy.world_point() != null:
		var delta := enemy.world_point().position - player.world_point().position
		return Vector2(delta.x, delta.z)
	return enemy.global_position - player.global_position

## Pushes a common enemy away from the player (the boss is filtered out by the caller and refuses it anyway).
func _push(player: PlayerActor, enemy: CombatActor, offset: Vector2, distance: float) -> void:
	if offset.is_zero_approx(): return
	if player.world_motion != null:
		if enemy.has_method(&"apply_world_defender_push_direction"): enemy.call(&"apply_world_defender_push_direction", Vector3(offset.x, 0.0, offset.y).normalized(), distance, player.world_motion.geometry.geometry_revision)
	elif enemy.has_method(&"apply_defender_push"):
		enemy.call(&"apply_defender_push", offset.normalized(), distance)

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

static func _active(id: StringName, name: String, targeting: SkillDefinition.Targeting, kind: SkillDefinition.ActionKind, element: StringName, costs: Array[float], cooldowns: Array[float], ranges: Array[float], powers: Array[float], secondary: Array[float], effects: Array[StringName]) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.KIT
	definition.targeting = targeting
	definition.action_kind = kind
	definition.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	definition.element = element
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

static func _passive(id: StringName, name: String, element: StringName, powers: Array[float], secondary: Array[float], effects: Array[StringName]) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.category = SkillDefinition.Category.PASSIVE
	definition.handler_id = SkillDefinition.Handler.KIT
	definition.targeting = SkillDefinition.Targeting.SELF
	definition.action_kind = SkillDefinition.ActionKind.DEFENSIVE
	definition.element = element
	for index: int in 3:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition
