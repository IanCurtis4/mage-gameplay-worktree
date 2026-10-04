class_name SentinelMath
extends RefCounted
## Central, local kit formulas. Never alter MATK or cooldowns of other identities.

static func raw_power(skill_id: StringName, rank: int, stats: StatBreakdown) -> float:
	var tuning := SentinelTuning.values(skill_id, rank)
	if tuning.is_empty() or stats == null:
		return 0.0
	if skill_id in [&"sentinel_headshot", &"sentinel_concussion_shot"]:
		return stats.value(&"precision_attack") * float(tuning["power"])
	if skill_id not in [&"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot"]:
		return 0.0
	return float(tuning["base"]) + stats.primary_value(&"int") * float(tuning["int_coefficient"]) + stats.primary_value(&"dex") * float(tuning.get("dex_coefficient", 0.0))

static func cooldown(skill_id: StringName, base_seconds: float, stats: StatBreakdown) -> float:
	var factor := 1.0
	if skill_id in [&"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot"]:
		var dex := maxf(0.0, stats.primary_value(&"dex"))
		factor = 1.0 - SentinelTuning.CASTER_COOLDOWN_REDUCTION_CAP * dex / (dex + SentinelTuning.CASTER_COOLDOWN_DEX_SCALE)
	return StatCalculator.effective_cooldown(base_seconds * factor, stats)

static func stance_source(rank: int) -> Dictionary:
	if rank < 1 or rank > 3:
		return {}
	var values := SentinelTuning.values(&"sentinel_precision_stance", rank)
	return {"source_id": &"sentinel_precision_stance", "label": "Postura de Precisão", "primary_flat": {&"dex": values["dex_bonus"], &"luk": values["luk_bonus"]}}
