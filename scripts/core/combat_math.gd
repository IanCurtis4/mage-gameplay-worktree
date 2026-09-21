class_name CombatMath
extends RefCounted
## Pure resolver: rolls are injected for deterministic tests/replays.
## The caller applies HP changes and emits events exactly once.

static func resolve(
	request: DamageRequest,
	physical_defense: float,
	magic_defense: float,
	flee_rating: float,
	crit_resistance: float,
	hit_roll: float,
	crit_roll: float
) -> Dictionary:
	var hit_chance := 1.0
	if request.accuracy_mode == DamageRequest.AccuracyMode.CONTESTED:
		hit_chance = StatCalculator.contested_hit_chance(request.hit_rating, flee_rating)
	var landed := hit_roll < hit_chance
	var effective_crit := StatCalculator.effective_crit_chance(request.crit_chance, crit_resistance)
	var critical := landed and request.can_crit and (request.force_critical or crit_roll < effective_crit)
	var damage := 0
	var physical_component := 0.0
	var magic_component := 0.0
	var raw_damage := maxf(0.0, request.physical_damage) + maxf(0.0, request.magic_damage)
	if landed and raw_damage > 0.0:
		physical_component = maxf(0.0, request.physical_damage) * 100.0 / (100.0 + maxf(0.0, physical_defense))
		magic_component = maxf(0.0, request.magic_damage) * 100.0 / (100.0 + maxf(0.0, magic_defense))
		var critical_multiplier := maxf(1.0, request.crit_multiplier) if critical else 1.0
		var final_damage := (physical_component + magic_component) * maxf(0.0, request.damage_dealt_multiplier) * critical_multiplier
		if final_damage > 0.0:
			damage = maxi(1, floori(final_damage + 0.5))
	return {
		"source_id": request.source_id,
		"target_id": request.target_id,
		"skill_id": request.skill_id,
		"hit_chance": hit_chance,
		"effective_crit_chance": effective_crit,
		"physical_component": physical_component,
		"magic_component": magic_component,
		"landed": landed,
		"critical": critical,
		"damage": damage,
		"can_trigger_effects": landed and damage > 0 and not request.is_secondary,
	}
