class_name CombatMath
extends RefCounted
## Pure resolver: rolls are injected for deterministic tests/replays.
## The caller applies HP changes and emits events exactly once.

static func resolve(request: DamageRequest, defense: float, hit_roll: float, crit_roll: float) -> Dictionary:
	var landed := hit_roll < clampf(request.hit_chance, 0.0, 1.0)
	var critical := landed and request.can_crit and crit_roll < clampf(request.crit_chance, 0.0, 0.75)
	var damage := 0
	if landed and request.base_damage > 0.0:
		var mitigated := request.base_damage * 100.0 / (100.0 + maxf(0.0, defense))
		damage = maxi(1, int(round(mitigated * (1.5 if critical else 1.0))))
	return {
		"source_id": request.source_id,
		"target_id": request.target_id,
		"skill_id": request.skill_id,
		"kind": request.kind,
		"landed": landed,
		"critical": critical,
		"damage": damage,
		"can_trigger_effects": landed and damage > 0 and not request.is_secondary,
	}
