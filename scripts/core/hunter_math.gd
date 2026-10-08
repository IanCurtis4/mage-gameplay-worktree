class_name HunterMath
extends RefCounted
## Local kit snapshots only. Mitigation, rounding and application stay canonical.

const TRAP_IDS: Array[StringName] = [
	&"snare_trap", &"explosive_trap", &"hunter_freezing_trap",
	&"hunter_tar_trap", &"hunter_thorn_trap",
]
const NEW_TRAP_IDS: Array[StringName] = [&"hunter_freezing_trap", &"hunter_tar_trap", &"hunter_thorn_trap"]

static func trap_request(owner_id: int, skill_id: StringName, rank: int, stats: StatBreakdown, multiplier: float) -> DamageRequest:
	var tuning := HunterTuning.values(skill_id, rank)
	if owner_id <= 0 or skill_id not in NEW_TRAP_IDS or tuning.is_empty() or stats == null or not is_finite(multiplier) or multiplier < 0.0:
		return null
	var request := DamageRequest.new()
	request.source_id = owner_id
	request.skill_id = skill_id
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.damage_dealt_multiplier = multiplier
	if skill_id != &"hunter_tar_trap":
		var raw := (float(tuning["base"]) + float(tuning["int_coefficient"]) * stats.primary_value(&"int")) * float(tuning["rank_factor"])
		if skill_id == &"hunter_freezing_trap":
			request.magic_damage = raw
		else:
			request.physical_damage = raw
	return request

static func opening_request(owner_id: int, trap_id: StringName, rank: int, stats: StatBreakdown, multiplier: float) -> DamageRequest:
	if owner_id <= 0 or trap_id not in TRAP_IDS or rank < 1 or rank > 5 or stats == null or not is_finite(multiplier) or multiplier < 0.0:
		return null
	var request := DamageRequest.new()
	request.source_id = owner_id
	request.skill_id = &"hunter_exploit"
	request.physical_damage = (8.0 + 1.4 * stats.primary_value(&"int")) * (1.0 + 0.1 * (rank - 1))
	request.damage_dealt_multiplier = multiplier
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.is_secondary = true
	return request

static func explosive_raw(rank: int, stats: StatBreakdown) -> float:
	if rank < 1 or rank > 5 or stats == null:
		return 0.0
	return (22.0 + 2.2 * stats.primary_value(&"int")) * (1.0 + 0.1 * (rank - 1))

static func step_source() -> Dictionary:
	return {"source_id": &"hunter_step", "label": "Passo de Caça", "increased": {&"move_speed": HunterTuning.STEP_SPEED_BONUS}}
