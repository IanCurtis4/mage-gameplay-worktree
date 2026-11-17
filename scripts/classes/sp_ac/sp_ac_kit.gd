extends ClassKit
## E09 K1 — Paladino (`sp_ac`): Espadachim → Acólito (Defendente + Sacerdote).
## Contract with the numbers: docs/epics/e09/k1_contract.md. Seam: T1/T1.1
## (docs/epics/e09/t1_kit_seam_api.md). Santuário/Graça: T5 (SanctuaryAuthority).
## The shield carries the Sanctuary: frontal hits reduced by the Oath cone and
## excess healing fill one Grace reserve; the Consecrated Impact spends it as a
## light column. Light = magic damage of a skill with element `light` (A2).
## Data methods are pure; the variables below are run state (snapshot fragment).

const OATH := &"paladin_oath"
const GUARD_GRACE := &"paladin_guard_grace"
const IMPACT := &"paladin_consecrated_impact"
const AEGIS := &"paladin_oath_aegis"
const FAITH := &"paladin_unshaken_faith"
const SEAL := &"paladin_condemned_seal"
const HOUR := &"paladin_oath_hour"
const SKILLS: Array[StringName] = [OATH, GUARD_GRACE, IMPACT, AEGIS, FAITH, SEAL, HOUR]

const ROLE_OATH := &"oath"
const SEAL_KEY := &"paladin_seal"
const GRACE_FAMILY := &"paladin_grace"
const FAITH_SOURCE := &"paladin_unshaken_faith"
const ICE_SOURCE := &"paladin_sanctuary_ice"

# --- Numbers (k1_contract §2) -------------------------------------------------------
const OATH_SP: Array[float] = [20.0, 21.0, 22.0, 23.0, 24.0]
const OATH_COOLDOWN := 14.0
const OATH_DURATION: Array[float] = [6.0, 6.5, 7.0, 7.5, 8.0]
const OATH_RADIUS: Array[float] = [150.0, 155.0, 160.0, 165.0, 170.0]
const OATH_TAKEN: Array[float] = [0.82, 0.80, 0.78, 0.76, 0.74]
const OATH_BURN: Array[float] = [0.12, 0.14, 0.16, 0.18, 0.20]
const OATH_HALF_ANGLE := deg_to_rad(55.0)
const GUARD_DEFENSE: Array[float] = [0.04, 0.07, 0.10]
const GUARD_EXCESS: Array[float] = [0.07, 0.06, 0.05]
const IMPACT_SP: Array[float] = [22.0, 23.0, 24.0, 25.0, 26.0]
const IMPACT_COOLDOWN := 5.0
const IMPACT_RANGE := 110.0
const IMPACT_POWER: Array[float] = [1.10, 1.25, 1.40, 1.55, 1.70]
const IMPACT_MAX_CHARGES := 5
const IMPACT_COLUMN := 55.0
const AEGIS_SP: Array[float] = [24.0, 25.0, 26.0, 27.0, 28.0]
const AEGIS_COOLDOWN := 16.0
const AEGIS_BASE: Array[float] = [50.0, 65.0, 80.0, 95.0, 110.0]
const AEGIS_PULSE: Array[float] = [0.60, 0.70, 0.80, 0.90, 1.00]
const AEGIS_DURATION := 6.0
const AEGIS_RADIUS := 120.0
const FAITH_CC: Array[float] = [0.10, 0.15, 0.20]
const FAITH_HEAL: Array[float] = [1.10, 1.20, 1.30]
const SEAL_SP: Array[float] = [18.0, 19.0, 20.0, 21.0, 22.0]
const SEAL_COOLDOWN := 14.0
const SEAL_RANGE := 300.0
const SEAL_DURATION: Array[float] = [5.0, 5.5, 6.0, 6.5, 7.0]
const SEAL_MAX_VALUE := 3
const HOUR_SP: Array[float] = [40.0, 42.0, 44.0, 46.0, 48.0]
const HOUR_COOLDOWN: Array[float] = [60.0, 57.0, 54.0, 51.0, 48.0]
const HOUR_DURATION: Array[float] = [6.0, 6.5, 7.0, 7.5, 8.0]
const HOUR_RADIUS := 170.0

# --- Run state (scripts/classes/sp_ac/snapshot_manifest.json) ---------------------------
## Santuário/Graça family authority (T5): zones, Grace, Égide, Selo.
var sanctuary := SanctuaryAuthority.new()
## Grace charges spent by the last committed Consecrated Impact (read by resolve_cast).
var impact_charges := 0
## Remaining seconds of the Hora do Juramento (gameplay clock, frozen in pause).
var hour_remaining := 0.0
## True when the Hora opened its own circle (no Oath zone lasted long enough).
var hour_opened_zone := false
## Crowd-control resistance currently published by Fé Inabalável (0 outside the Oath).
var faith_applied := 0.0

# --- Catalog data (pure) ------------------------------------------------------------

func kit_id() -> StringName:
	return &"sp_ac"

func ready_for_play() -> bool:
	return true

func display_name() -> String:
	return "Paladino"

func skill_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	result.append(_active(OATH, "Juramento", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, OATH_SP, _fill(OATH_COOLDOWN), OATH_RADIUS, OATH_DURATION, OATH_BURN, [&"paladin_oath_cone", &"owner_frontal_damage_taken", &"light_burn_pulse", &"grace_on_mitigated_hit"]))
	result.append(_passive(GUARD_GRACE, "Graça de Guarda", GUARD_DEFENSE, GUARD_EXCESS, [&"physical_defense_increased", &"grace_excess_heal_fraction", &"grace_on_shield_wall_frontal_hit"]))
	var impact := _active(IMPACT, "Impacto Consagrado", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.OFFENSIVE, IMPACT_SP, _fill(IMPACT_COOLDOWN), _fill(IMPACT_RANGE), IMPACT_POWER, _fill(SanctuaryRules.JUDGMENT_PER_CHARGE), [&"spend_grace_up_to_5", &"light_column_radius_55", &"judgment_per_charge_0_40"])
	impact.can_crit = true
	result.append(impact)
	result.append(_active(AEGIS, "Égide do Juramento", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, AEGIS_SP, _fill(AEGIS_COOLDOWN), _fill(AEGIS_RADIUS), AEGIS_BASE, AEGIS_PULSE, [&"personal_shield", &"single_light_pulse_on_break_or_expiry", &"push_radius_120"]))
	result.append(_passive(FAITH, "Fé Inabalável", FAITH_CC, FAITH_HEAL, [&"cc_resistance_inside_oath", &"heal_multiplier_inside_oath"]))
	result.append(_active(SEAL, "Selo do Condenado", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.DEFENSIVE, SEAL_SP, _fill(SEAL_COOLDOWN), _fill(SEAL_RANGE), SEAL_DURATION, _fill(0.0), [&"seal_mark", &"force_target", &"grace_on_light_damage"]))
	result.append(_active(HOUR, "Hora do Juramento", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, HOUR_SP, HOUR_COOLDOWN, _fill(HOUR_RADIUS), HOUR_DURATION, _fill(0.0), [&"oath_cone_becomes_circle", &"grace_unlimited", &"impact_without_sp"]))
	return result

func learning_entries() -> Array[Dictionary]:
	return [
		{"skill_id": OATH, "category": &"active", "free_rank": 1, "max_purchased_rank": 4, "job_level": 20, "prerequisites": {}},
		{"skill_id": GUARD_GRACE, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 23, "prerequisites": {}},
		{"skill_id": IMPACT, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 25, "prerequisites": {}},
		{"skill_id": AEGIS, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 28, "prerequisites": {}},
		{"skill_id": FAITH, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 31, "prerequisites": {}},
		{"skill_id": SEAL, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 34, "prerequisites": {&"provoke": 1}},
		{"skill_id": HOUR, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 37, "prerequisites": {}},
	]

func passive_modifier_source(skill_id: StringName, rank: int) -> Dictionary:
	if skill_id != GUARD_GRACE or rank < 1 or rank > GUARD_DEFENSE.size(): return {}
	return {"source_id": &"passive_paladin_guard_grace", "label": "Graça de Guarda", "increased": {&"physical_defense": GUARD_DEFENSE[rank - 1]}}

func feedback_recipes() -> Dictionary:
	return {
		OATH: [&"buff", &"arcane", &"", FeedbackRecipeCatalog.COMMIT | FeedbackRecipeCatalog.PERIODIC],
		GUARD_GRACE: [&"buff", &"arcane", &"", 0],
		IMPACT: [&"impact", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		AEGIS: [&"buff", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		FAITH: [&"buff", &"arcane", &"", 0],
		SEAL: [&"buff", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		HOUR: [&"buff", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
	}

func skill_texts() -> Dictionary:
	var texts := {
		OATH: {"flavor": "O escudo se ergue, e a luz se abre à frente dele.", "effect": "Projeta um Santuário em cone à frente do escudo: o Paladino recebe menos dano de frente, e os inimigos no cone queimam com luz.", "combo": "Cada golpe de frente reduzido pelo cone gera 1 Graça.", "mechanics": "Cone preso à frente do Paladino; pulso de luz a cada 1s."},
		GUARD_GRACE: {"flavor": "Aguentar de frente também é oração.", "effect": "Aumenta a DEF física e faz a cura excedente gerar Graça mais depressa. Com a Parede de Escudos erguida, golpes de frente também geram Graça.", "combo": "Um mesmo golpe nunca gera Graça duas vezes.", "mechanics": "Passiva automática; reserva de até 5 cargas de Graça."},
		IMPACT: {"flavor": "O escudo bate, e o céu responde.", "effect": "Golpe de escudo que gasta até 5 cargas de Graça: uma coluna de luz desce sobre o alvo, e o dano cresce com cada carga gasta.", "combo": "Na Hora do Juramento, não custa SP e a coluna cobre o círculo inteiro.", "mechanics": "Dano de luz: % do ATQ corpo a corpo × (1 + 0,40 por carga)."},
		AEGIS: {"flavor": "Um halo dourado se fecha sobre a armadura.", "effect": "Um halo absorve dano por 6s. Ao quebrar ou expirar, solta um único pulso de luz que fere e empurra os inimigos próximos.", "combo": "Use quando o cone não basta: o pulso abre espaço para o próximo Juramento.", "mechanics": "Escudo pessoal como o da Perseverança; pulso de raio 120."},
		FAITH: {"flavor": "Dentro do juramento, nada o derruba.", "effect": "Dentro do Juramento, os controles duram menos e a cura recebida rende mais.", "combo": "Cura que passa do HP máximo continua virando Graça.", "mechanics": "Passiva automática; vale no cone e no círculo da Hora."},
		SEAL: {"flavor": "Um aro de luz se fecha: só resta o Paladino.", "effect": "Sela um inimigo: ele só pode atacar o Paladino, e todo dano de luz nele gera Graça.", "combo": "Provocar o selado soma 1 ao Selo (até 3), e cada dano de luz gera Graça igual ao valor do Selo.", "mechanics": "Marca de um alvo por vez; força o alvo enquanto dura."},
		HOUR: {"flavor": "A hora em que o juramento cobra tudo.", "effect": "Por alguns segundos, o cone vira um círculo dourado completo: a Graça não tem limite, e o Impacto Consagrado não custa SP.", "combo": "Cercado, todo golpe reduzido vira Graça, e cada Impacto desce sobre o círculo inteiro.", "mechanics": "Círculo preso ao Paladino; ao fim, a Graça volta ao teto de 5."},
	}
	for skill: StringName in SKILLS:
		var ranks: Array[String] = []
		for rank: int in range(1, (3 if skill in [GUARD_GRACE, FAITH] else 5) + 1): ranks.append(rank_tooltip(skill, rank))
		texts[skill]["ranks"] = ranks
		texts[skill]["mechanics"] = String(texts[skill]["mechanics"]) + " " + " · ".join(ranks)
	return texts

## Per-rank tooltip line (pt-BR) of one skill. Pure.
func rank_tooltip(skill_id: StringName, rank: int) -> String:
	var i := rank - 1
	match skill_id:
		OATH:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, %ss, raio %d, dano de frente × %s, queima %d%% do ATQ" % [rank, _num(OATH_SP[i]), _num(OATH_DURATION[i]), int(OATH_RADIUS[i]), _num(OATH_TAKEN[i]), roundi(OATH_BURN[i] * 100.0)]
		GUARD_GRACE:
			if i < 0 or i >= 3: return ""
			return "R%d: DEF física +%d%%, 1 Graça a cada %d%% do HP máximo de cura excedente" % [rank, roundi(GUARD_DEFENSE[i] * 100.0), roundi(GUARD_EXCESS[i] * 100.0)]
		IMPACT:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, %d%% do ATQ, até 5 cargas (× 3 com 5)" % [rank, _num(IMPACT_SP[i]), roundi(IMPACT_POWER[i] * 100.0)]
		AEGIS:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, escudo %d + VIT/INT, pulso %d%% do ATQ" % [rank, _num(AEGIS_SP[i]), int(AEGIS_BASE[i]), roundi(AEGIS_PULSE[i] * 100.0)]
		FAITH:
			if i < 0 or i >= 3: return ""
			return "R%d: resistência a controle +%s, cura × %s" % [rank, _num(FAITH_CC[i]), _num(FAITH_HEAL[i])]
		SEAL:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, %ss" % [rank, _num(SEAL_SP[i]), _num(SEAL_DURATION[i])]
		HOUR:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, %ss" % [rank, _num(HOUR_SP[i]), _num(HOUR_COOLDOWN[i]), _num(HOUR_DURATION[i])]
	return ""

func vfx_effects() -> Dictionary:
	return {
		&"paladin_oath_cone": {"skill_id": OATH, "kinds": [&"effect_start"], "size": 170.0},
		&"paladin_oath_burn": {"skill_id": OATH, "kinds": [&"impact"], "size": 48.0},
		&"paladin_grace_rings": {"skill_id": IMPACT, "kinds": [&"effect_start"], "size": 64.0},
		&"paladin_impact_column": {"skill_id": IMPACT, "kinds": [&"impact"], "size": 110.0},
		&"paladin_aegis_halo": {"skill_id": AEGIS, "kinds": [&"effect_start"], "size": 90.0},
		&"paladin_aegis_pulse": {"skill_id": AEGIS, "kinds": [&"impact"], "size": 120.0},
		&"paladin_seal_ring": {"skill_id": SEAL, "kinds": [&"effect_start"], "size": 80.0},
		&"paladin_hour_circle": {"skill_id": HOUR, "kinds": [&"effect_start"], "size": 200.0},
	}

const GOLD := Color(1.0, 0.85, 0.40)
const SKY := Color(0.62, 0.84, 1.0)

func draw_vfx(effect_id: StringName, canvas: CanvasItem, pulse: Dictionary, position: Vector2, t: float) -> bool:
	var fade := clampf(1.0 - t, 0.0, 1.0)
	var dir: Vector2 = pulse.get("dir", Vector2.RIGHT) if pulse.get("dir") is Vector2 else Vector2.RIGHT
	if dir.is_zero_approx(): dir = Vector2.RIGHT
	dir = dir.normalized()
	match effect_id:
		&"paladin_oath_cone":
			var reach := 60.0 + 110.0 * minf(1.0, t * 2.5)
			var angle := dir.angle()
			var points := PackedVector2Array([position])
			for step: int in 13: points.append(position + Vector2.from_angle(angle - OATH_HALF_ANGLE + OATH_HALF_ANGLE * 2.0 * step / 12.0) * Vector2(reach, reach * 0.5))
			canvas.draw_colored_polygon(points, Color(GOLD, 0.28 * fade))
			canvas.draw_polyline(points.slice(1), Color(GOLD, 0.85 * fade), 3.0)
		&"paladin_oath_burn":
			for k: int in 3:
				var offset := Vector2(-6.0 + 6.0 * k, -10.0 - 18.0 * t - 4.0 * k)
				canvas.draw_circle(position + offset, 4.0 * fade + 1.0, Color(GOLD, 0.8 * fade))
		&"paladin_grace_rings":
			for k: int in 3:
				var center := position + Vector2(0.0, -46.0 - 10.0 * t) + Vector2.from_angle(TAU * (t + k / 3.0)) * Vector2(14.0, 5.0)
				canvas.draw_arc(center, 6.0, 0.0, TAU, 14, Color(GOLD, fade), 2.0)
		&"paladin_impact_column":
			var width := 26.0 * (1.0 - 0.5 * t)
			canvas.draw_rect(Rect2(position + Vector2(-width * 0.5, -150.0), Vector2(width, 150.0)), Color(GOLD, 0.55 * fade))
			canvas.draw_rect(Rect2(position + Vector2(-width * 0.2, -150.0), Vector2(width * 0.4, 150.0)), Color(1.0, 1.0, 0.92, 0.85 * fade))
			canvas.draw_arc(position, 18.0 + 30.0 * t, 0.0, TAU, 24, Color(GOLD, fade), 3.0)
		&"paladin_aegis_halo":
			canvas.draw_arc(position + Vector2(0.0, -24.0), 30.0 + 4.0 * sin(t * TAU), 0.0, TAU, 28, Color(GOLD, 0.9 * fade), 3.0)
			canvas.draw_arc(position + Vector2(0.0, -24.0), 22.0, 0.0, TAU, 24, Color(SKY, 0.5 * fade), 2.0)
		&"paladin_aegis_pulse":
			canvas.draw_arc(position, 20.0 + AEGIS_RADIUS * t, 0.0, TAU, 36, Color(GOLD, fade), 4.0 * fade + 1.0)
		&"paladin_seal_ring":
			var radius := 48.0 * (1.0 - 0.6 * t)
			canvas.draw_arc(position + Vector2(0.0, -20.0), radius, 0.0, TAU, 28, Color(GOLD, fade), 3.0)
			for k: int in 4: canvas.draw_line(position + Vector2(0.0, -20.0) + Vector2.from_angle(k * TAU / 4.0 + t) * radius, position + Vector2(0.0, -20.0) + Vector2.from_angle(k * TAU / 4.0 + t) * (radius + 8.0), Color(SKY, fade), 2.0)
		&"paladin_hour_circle":
			var reach := HOUR_RADIUS * minf(1.0, t * 2.0)
			canvas.draw_arc(position, reach, 0.0, TAU, 48, Color(GOLD, fade), 4.0)
			for k: int in 8: canvas.draw_line(position, position + Vector2.from_angle(k * TAU / 8.0) * reach, Color(GOLD, 0.35 * fade), 2.0)
		_:
			return false
	return true

# --- Hooks ----------------------------------------------------------------------------

func on_attach(player: PlayerActor) -> void:
	sanctuary.configure(player, GRACE_FAMILY, ICE_SOURCE)
	_apply_guard_grace(player)

func temporary_stat_sources(player: PlayerActor) -> Array[Dictionary]:
	var sources := sanctuary.temporary_stat_sources(player)
	if faith_applied > 0.0: sources.append({"source_id": FAITH_SOURCE, "label": "Fé Inabalável", "flat": {&"physical_cc_resistance": faith_applied, &"magic_cc_resistance": faith_applied}})
	return sources

func on_tick(player: PlayerActor, delta: float) -> void:
	sanctuary.tick(player, delta)
	if hour_remaining > 0.0:
		hour_remaining = maxf(0.0, hour_remaining - delta)
		if hour_remaining <= 0.0: _end_hour(player)
	_sync_faith(player)

func can_cast(_player: PlayerActor, cast: Dictionary) -> Dictionary:
	if StringName(cast.get("skill_id", &"")) == OATH and hour_active(): return {"ok": false, "error_code": &"paladin_hour_active"}
	return {"ok": true, "error_code": &""}

func on_cast_confirmed(player: PlayerActor, cast: Dictionary) -> void:
	if StringName(cast["skill_id"]) != IMPACT: return
	impact_charges = sanctuary.spend_for_cast(player, cast, 1, IMPACT_MAX_CHARGES)

## T1.2: the Consecrated Impact costs 0 SP during the Hora. Pure read of hour_remaining.
func skill_cost(_player: PlayerActor, skill_id: StringName, base_cost: float) -> float:
	return 0.0 if skill_id == IMPACT and hour_active() else base_cost

## T1.2: Shield Wall and Perseverance give +1 Grace per paid commit; Provoke adds 1 to
## the Seal (up to 3) only when its target is the sealed enemy.
func on_base_skill_committed(player: PlayerActor, skill_id: StringName, context: Dictionary) -> void:
	match skill_id:
		&"shield_wall", &"perseverance":
			sanctuary.gain({"key": "base:%s@%.5f" % [skill_id, player.kit_time]}, 1)
		&"provoke":
			var sealed := sanctuary.sealed_target()
			var provoked: Variant = context.get("target")
			if sealed == null or not is_instance_valid(provoked) or provoked != sealed: return
			if int(sealed.marks.value(SEAL_KEY, 1)) < SEAL_MAX_VALUE: sanctuary.add_to_seal(1)

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	var values := _rank_values(player, skill, int(cast["rank"]))
	if values == null: return false
	match skill:
		OATH:
			var opened := sanctuary.open_zone(player, _oath_config(player, values.rank, &"cone", values.range, values.power))
			_sync_faith(player)
			return opened["ok"]
		IMPACT:
			return _resolve_impact(player, cast, values)
		AEGIS:
			var capacity := StatCalculator.personal_shield_capacity(values.power, player.stat_breakdown)
			return sanctuary.grant_aegis(player, capacity, AEGIS_DURATION, player.stat_breakdown.value(&"melee_attack") * values.secondary_power, AEGIS, values.range)
		SEAL:
			var victim := cast.get("target") as CombatActor
			if not is_instance_valid(victim): return false
			return sanctuary.seal(player, victim, SEAL_KEY, values.power, 1)["ok"]
		HOUR:
			return _resolve_hour(player, values)
	return false

func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
	# Stance seen before this hit's mitigation (the hit itself may drop it).
	hit["paladin_stance"] = player.has_shield_stance()
	return sanctuary.before_hit(player, hit)

func after_hit_mitigation(player: PlayerActor, hit: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("landed", false)): return
	var reduced_by_zone := sanctuary.owner_damage_multiplier(hit) < 1.0
	var guarded := bool(hit.get("frontal", false)) and bool(hit.get("paladin_stance", false)) and player.skill_rank(GUARD_GRACE) > 0
	if reduced_by_zone or guarded: sanctuary.gain(SanctuaryHelpers.result_event(result), 1)

func on_shield_broken(player: PlayerActor, hit: Dictionary, result: Dictionary) -> void:
	sanctuary.on_shield_broken(player, hit, result)

func on_heal(player: PlayerActor, requested: float, applied: float, source: StringName) -> void:
	sanctuary.on_heal(player, requested, applied, source)

func on_damage_dealt(_player: PlayerActor, result: Dictionary) -> void:
	var victim := instance_from_id(int(result.get("target_id", 0))) as CombatActor
	if not sanctuary.is_sealed(victim) or not SanctuaryHelpers.is_light_result(result): return
	sanctuary.gain(SanctuaryHelpers.result_event(result), clampi(int(victim.marks.value(SEAL_KEY, 1)), 1, SEAL_MAX_VALUE))

func on_death(player: PlayerActor) -> void:
	sanctuary.on_death(player)
	hour_remaining = 0.0
	hour_opened_zone = false
	impact_charges = 0
	_sync_faith(player)

func on_build_changed(player: PlayerActor) -> void:
	sanctuary.on_build_changed(player)
	_apply_guard_grace(player)
	_sync_faith(player)

func snapshot_compact_blocker(_player: PlayerActor) -> String:
	if hour_active(): return "paladin_hour"
	return sanctuary.compact_blocker()

# --- Queries --------------------------------------------------------------------------

func hour_active() -> bool:
	return hour_remaining > 0.0

func grace_charges() -> int:
	return sanctuary.grace.charges

# --- Internals --------------------------------------------------------------------------

func _resolve_impact(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var victim := cast.get("target") as CombatActor
	if not is_instance_valid(victim) or not victim.is_alive(): return false
	var actors: Array = cast.get("actors", [])
	if actors.is_empty(): actors = [victim]
	var targets: Array[CombatActor] = []
	var oath := sanctuary.zone(ROLE_OATH)
	if hour_active() and oath != null:
		targets = SanctuaryHelpers.judgment_targets(player, actors, null, IMPACT_COLUMN, oath)
	else:
		var point: Variant = victim.world_point() if player.world_motion != null else victim.global_position
		targets = SanctuaryHelpers.judgment_targets(player, actors, point, IMPACT_COLUMN)
	if victim not in targets: targets.push_front(victim)
	var base := player.stat_breakdown.value(&"melee_attack") * values.power
	var struck := 0
	for enemy: CombatActor in targets:
		if not is_instance_valid(enemy) or not enemy.is_alive(): continue
		var request := SanctuaryHelpers.judgment_request(player, enemy, IMPACT, base, impact_charges, values.secondary_power, true)
		if request == null: continue
		player.kit_emit_hit(request, enemy)
		struck += 1
	return struck > 0

func _resolve_hour(player: PlayerActor, values: SkillRankDefinition) -> bool:
	var duration := values.power
	var oath := sanctuary.zone(ROLE_OATH)
	var ok := false
	if oath != null and oath.remaining >= duration:
		ok = sanctuary.set_zone_shape(ROLE_OATH, SanctuaryRules.SHAPE_CIRCLE)["ok"]
		hour_opened_zone = false
	else:
		var oath_rank := maxi(1, player.skill_rank(OATH))
		var opened := sanctuary.open_zone(player, _oath_config(player, oath_rank, SanctuaryRules.SHAPE_CIRCLE, HOUR_RADIUS, duration))
		ok = opened["ok"]
		hour_opened_zone = ok
	if not ok: return false
	hour_remaining = duration
	sanctuary.begin_unlimited(duration)
	_sync_faith(player)
	return true

func _end_hour(player: PlayerActor) -> void:
	hour_remaining = 0.0
	var oath := sanctuary.zone(ROLE_OATH)
	if oath != null and oath.shape != SanctuaryRules.SHAPE_CONE:
		if hour_opened_zone: sanctuary.end_zone(ROLE_OATH, player)
		else: sanctuary.set_zone_shape(ROLE_OATH, SanctuaryRules.SHAPE_CONE, oath.base_radius)
	hour_opened_zone = false

func _oath_config(player: PlayerActor, oath_rank: int, shape: StringName, radius: float, duration: float) -> Dictionary:
	var i := clampi(oath_rank, 1, 5) - 1
	var faith := player.skill_rank(FAITH)
	var heal := FAITH_HEAL[clampi(faith, 1, 3) - 1] if faith > 0 else 1.0
	return {
		"role": ROLE_OATH, "skill_id": OATH, "shape": shape, "anchor": SanctuaryRules.ANCHOR_OWNER,
		"radius": radius, "half_angle": OATH_HALF_ANGLE, "duration": duration,
		"rules": {"owner_damage_taken": OATH_TAKEN[i], "burn_ratio": OATH_BURN[i], "burn_stat": &"melee_attack", "heal_multiplier": heal},
	}

func _apply_guard_grace(player: PlayerActor) -> void:
	var rank := player.skill_rank(GUARD_GRACE) if is_instance_valid(player) else 0
	sanctuary.grace.excess_fraction = GUARD_EXCESS[clampi(rank, 1, 3) - 1] if rank > 0 else SanctuaryRules.GRACE_EXCESS_FRACTION

func _sync_faith(player: PlayerActor) -> void:
	var wanted := 0.0
	var rank := player.skill_rank(FAITH) if is_instance_valid(player) and player.is_alive() else 0
	var oath := sanctuary.zone(ROLE_OATH)
	if rank > 0 and oath != null and oath.owner_inside: wanted = FAITH_CC[clampi(rank, 1, 3) - 1]
	if is_equal_approx(wanted, faith_applied): return
	faith_applied = wanted
	if is_instance_valid(player): player.refresh_kit_stats()

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
	definition.element = &"light"
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
	definition.element = &"light"
	for index: int in 3:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition
