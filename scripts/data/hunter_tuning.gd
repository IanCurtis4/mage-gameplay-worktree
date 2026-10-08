class_name HunterTuning
extends RefCounted
## Initial Caçadora tuning. Values are immutable catalog snapshots; runtime state lives elsewhere.

const SKILL_IDS: Array[StringName] = [
	&"hunter_freezing_trap", &"hunter_tar_trap", &"hunter_thorn_trap",
	&"hunter_mark", &"hunter_shooting_discipline", &"hunter_covering_shot",
	&"hunter_easy_prey", &"hunter_total_cover",
]
const OPENING_DURATION := 4.0
const STEP_DURATION := 1.5
const STEP_COOLDOWN := 3.0
const STEP_SPEED_BONUS := 0.25
const EMISSION_LIFETIME := 12.0
const EMISSION_CAP := 256
const ACTIVATION_LIFETIME := 16.0
const ACTIVATION_CAP := 256
const OPENING_CAP := 32
const TRAP_RANGE := 360.0
const TRAP_PREPARATION := 0.25
const TRAP_ARMING_TIME := 0.60
const ARMED_TRAP_LIFETIME := 12.0
const COVER_BUDGET := 3.0
const COVER_COOLDOWN := 18.0
const COVER_REVEAL := 1.25

static func max_rank(skill_id: StringName) -> int:
	if skill_id not in SKILL_IDS:
		return 0
	return 3 if skill_id in [&"hunter_shooting_discipline", &"hunter_easy_prey"] else 5

static func values(skill_id: StringName, rank: int) -> Dictionary:
	var maximum := max_rank(skill_id)
	if maximum == 0 or rank < 1 or rank > maximum:
		return {}
	var fraction := float(rank - 1) / float(maximum - 1)
	var result := {
		"sp_cost": 0.0, "cooldown": 0.0, "range": 0.0, "projectile_speed": 0.0, "power": 0.0,
		"secondary_power": 0.0, "variable_cast_time": 0.0,
	}
	match skill_id:
		&"hunter_freezing_trap":
			result.merge({
				"sp_cost": _linear(16.0, 22.0, fraction), "cooldown": 7.0,
				"range": TRAP_RANGE, "variable_cast_time": TRAP_PREPARATION,
				"radius": 52.0, "arming_time": TRAP_ARMING_TIME,
				"armed_lifetime": ARMED_TRAP_LIFETIME,
				"base": 12.0, "int_coefficient": 1.8,
				"rank_factor": 1.0 + 0.1 * float(rank - 1),
				"root_duration": _linear(0.8, 1.6, fraction),
			}, true)
		&"hunter_tar_trap":
			result.merge({
				"sp_cost": _linear(16.0, 22.0, fraction), "cooldown": 9.0,
				"range": TRAP_RANGE, "variable_cast_time": TRAP_PREPARATION,
				"trigger_radius": 52.0, "field_radius": 100.0,
				"arming_time": TRAP_ARMING_TIME, "armed_lifetime": ARMED_TRAP_LIFETIME,
				"field_duration": _linear(4.0, 6.0, fraction),
				"slow_fraction": _linear(0.30, 0.40, fraction), "residual_duration": 0.4,
			}, true)
		&"hunter_thorn_trap":
			result.merge({
				"sp_cost": _linear(18.0, 26.0, fraction), "cooldown": 9.0,
				"range": TRAP_RANGE, "variable_cast_time": TRAP_PREPARATION,
				"trigger_radius": 52.0, "radius": 85.0,
				"arming_time": TRAP_ARMING_TIME, "armed_lifetime": ARMED_TRAP_LIFETIME,
				"base": 16.0, "int_coefficient": 1.6,
				"rank_factor": 1.0 + 0.1 * float(rank - 1),
				"bleed_fraction": 0.20, "bleed_interval": 1.0, "bleed_duration": 4.0,
				"slow_fraction": 0.20, "slow_duration": 2.0,
			}, true)
		&"hunter_mark":
			result.merge({
				"sp_cost": _linear(10.0, 14.0, fraction), "cooldown": 10.0,
				"range": 360.0, "duration": _linear(6.0, 10.0, fraction),
				"opening_extension": _linear(1.0, 2.0, fraction),
				"reward_bonus": _linear(0.15, 0.25, fraction),
			}, true)
		&"hunter_shooting_discipline":
			result["power"] = [0.05, 0.10, 0.15][rank - 1]
		&"hunter_covering_shot":
			result.merge({
				"sp_cost": _linear(16.0, 22.0, fraction), "cooldown": 8.0,
				"range": 520.0, "projectile_speed": 880.0,
				"power": _linear(1.1, 1.5, fraction), "recoil_distance": 80.0,
			}, true)
		&"hunter_easy_prey":
			result["power"] = [0.08, 0.12, 0.16][rank - 1]
		&"hunter_total_cover":
			result.merge({
				"sp_cost": _linear(20.0, 28.0, fraction), "cooldown": COVER_COOLDOWN,
				"range": 300.0, "radius": 125.0,
				"duration": _linear(4.0, 6.0, fraction),
				"exit_grace": 1.0, "shared_cover_budget": COVER_BUDGET,
			}, true)
	return result

static func _linear(first: float, last: float, fraction: float) -> float:
	return lerpf(first, last, fraction)
