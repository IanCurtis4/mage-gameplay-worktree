class_name SentinelTuning
extends RefCounted
## Initial balance data only. No actor, clocks, resources or mutable catalog state.

const SKILL_IDS: Array[StringName] = [
	&"sentinel_headshot", &"sentinel_observe", &"sentinel_precision_stance",
	&"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot",
	&"sentinel_opening_read", &"sentinel_concussion_shot", &"sentinel_absolute_focus",
]
const FOCUS_CAP := 100.0
const FOCUS_STABILITY_DELAY := 0.5
const FOCUS_GENERATION_PER_SECOND := 10.0
const FOCUS_OUT_OF_COMBAT_DELAY := 3.0
const FOCUS_DECAY_PER_SECOND := 10.0
const ABSOLUTE_GENERATION_PER_SECOND := 15.0
const PRECISION_STABILITY_DELAY := 0.75
const OBSERVE_HIT_COUNT := 3
const OBSERVE_INTERNAL_COOLDOWN := 0.5
const OPENING_INTERNAL_COOLDOWN := 1.0
const CASTER_COOLDOWN_REDUCTION_CAP := 0.25
const CASTER_COOLDOWN_DEX_SCALE := 100.0

static func max_rank(skill_id: StringName) -> int:
	if skill_id not in SKILL_IDS:
		return 0
	return 3 if skill_id in [&"sentinel_precision_stance", &"sentinel_opening_read"] else 5

static func values(skill_id: StringName, rank: int) -> Dictionary:
	var maximum := max_rank(skill_id)
	if maximum == 0 or rank < 1 or rank > maximum:
		return {}
	var step := float(rank - 1) / float(maximum - 1)
	var result := {
		"sp_cost": 0.0, "cooldown": 0.0, "range": 0.0,
		"projectile_speed": 0.0, "variable_cast_time": 0.0,
		"power": 0.0, "secondary_power": 0.0, "focus_cost": 0.0,
	}
	match skill_id:
		&"sentinel_headshot":
			result.merge({"sp_cost": _sp(14.0, 20.0, step), "cooldown": 6.0, "range": 340.0, "projectile_speed": 900.0, "power": lerpf(2.0, 2.8, step), "focus_cost": 30.0}, true)
		&"sentinel_observe":
			result.merge({"sp_cost": _sp(8.0, 12.0, step), "cooldown": 10.0, "range": 340.0, "duration": 8.0, "focus_return": 5.0 + rank, "hit_count": OBSERVE_HIT_COUNT, "internal_cooldown": OBSERVE_INTERNAL_COOLDOWN, "power": 5.0 + rank, "secondary_power": 8.0}, true)
		&"sentinel_precision_stance":
			result.merge({"dex_bonus": 3.0 * rank, "luk_bonus": 2.0 * rank, "stability_delay": PRECISION_STABILITY_DELAY, "power": 3.0 * rank, "secondary_power": 2.0 * rank}, true)
		&"sentinel_piercing_shot":
			result.merge({"sp_cost": _sp(16.0, 22.0, step), "cooldown": 5.0, "range": 600.0, "projectile_speed": 900.0, "base": lerpf(10.0, 18.0, step), "int_coefficient": lerpf(2.0, 3.2, step), "dex_coefficient": lerpf(1.4, 2.2, step), "focus_cost": 20.0, "power": lerpf(2.0, 3.2, step), "secondary_power": lerpf(1.4, 2.2, step)}, true)
		&"sentinel_net_shot":
			result.merge({"sp_cost": _sp(18.0, 26.0, step), "cooldown": 10.0, "range": 340.0, "projectile_speed": 900.0, "variable_cast_time": 0.25, "radius": 90.0, "base": lerpf(20.0, 36.0, step), "int_coefficient": lerpf(1.2, 2.0, step), "root_duration": lerpf(1.0, 2.0, step), "power": lerpf(1.2, 2.0, step), "secondary_power": lerpf(1.0, 2.0, step)}, true)
		&"sentinel_explosive_shot":
			result.merge({"sp_cost": _sp(20.0, 28.0, step), "cooldown": 7.0, "range": 340.0, "projectile_speed": 900.0, "radius": 80.0, "base": lerpf(45.0, 65.0, step), "int_coefficient": lerpf(3.0, 4.2, step), "focus_cost": 25.0, "power": lerpf(3.0, 4.2, step), "secondary_power": 80.0}, true)
		&"sentinel_opening_read":
			result.merge({"focus_return": 1.0 + rank, "internal_cooldown": OPENING_INTERNAL_COOLDOWN, "power": 1.0 + rank}, true)
		&"sentinel_concussion_shot":
			result.merge({"sp_cost": _sp(12.0, 18.0, step), "cooldown": 12.0, "range": 340.0, "projectile_speed": 900.0, "power": lerpf(0.65, 0.85, step), "stun_duration": lerpf(0.4, 0.8, step), "duration": lerpf(2.0, 4.0, step), "damage_dealt_reduction": 0.10, "secondary_power": lerpf(0.4, 0.8, step)}, true)
		&"sentinel_absolute_focus":
			result.merge({"sp_cost": _sp(24.0, 32.0, step), "cooldown": 30.0, "duration": lerpf(4.0, 6.0, step), "range_bonus": 0.20, "focus_generation_per_second": ABSOLUTE_GENERATION_PER_SECOND, "focus_stability_delay": 0.0, "power": lerpf(4.0, 6.0, step), "secondary_power": 0.20}, true)
	return result

static func _sp(first: float, last: float, rank_fraction: float) -> float:
	return lerpf(first, last, sqrt(rank_fraction))
