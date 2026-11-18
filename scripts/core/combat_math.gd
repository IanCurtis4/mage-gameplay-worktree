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
	if request.requires_hit_roll():
		hit_chance = StatCalculator.contested_hit_chance(request.hit_rating, flee_rating)
	var landed := (request.is_secondary and not request.requires_hit_roll()) or hit_roll < hit_chance
	var effective_crit := StatCalculator.effective_crit_chance(request.crit_chance, crit_resistance)
	var critical := landed and request.can_crit and not request.is_secondary and (request.force_critical or crit_roll < effective_crit)
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
		"context": request.context.copy_context() if request.context != null else null,
		"root_event_id": request.context.root_event_id if request.context != null else "",
		"event_id": request.context.event_id if request.context != null else 0,
		"secondary": request.is_secondary,
		"effect_snapshot": request.effect_snapshot.duplicate(true),
		"weapon_instance_ids": request.weapon_instance_ids.duplicate(),
		"target_id": request.target_id,
		"skill_id": request.skill_id,
		"emission_id": request.emission_id,
		"damage_dealt_multiplier": request.damage_dealt_multiplier,
		"hunter_precision_damage": request.hunter_precision_damage,
		"hunter_easy_prey_bonus": request.hunter_easy_prey_bonus,
		"hit_chance": hit_chance,
		"effective_crit_chance": effective_crit,
		"physical_component": physical_component,
		"magic_component": magic_component,
		"landed": landed,
		"critical": critical,
		"damage": damage,
		"can_trigger_effects": landed and damage > 0 and not request.is_secondary,
	}

## E10a C1.7: the single composition of the generic received-damage sources of an
## actor (CombatActor.received_damage_sources). Each entry is {"multiplier": float >= 0,
## "owner_id": int (0 = any author), "element": StringName (empty = any)}; entries whose
## filters match the request author and the skill element multiply together.
static func received_damage_multiplier(sources: Dictionary, author_id: int, element: StringName) -> float:
	var result := 1.0
	var keys: Array = sources.keys()
	keys.sort()
	for key: Variant in keys:
		var entry: Dictionary = sources[key]
		var owner := int(entry.get("owner_id", 0))
		var wanted := StringName(entry.get("element", &""))
		if owner != 0 and owner != author_id: continue
		if not wanted.is_empty() and wanted != element: continue
		result *= maxf(0.0, float(entry.get("multiplier", 1.0)))
	return result

## E10a C1.7: the single composition of the accuracy reductions of an actor's own
## attacks (CombatActor.accuracy_sources): each {"reduction": 0..1} multiplies the hit
## rating by (1 - reduction).
static func accuracy_multiplier(sources: Dictionary) -> float:
	var result := 1.0
	var keys: Array = sources.keys()
	keys.sort()
	for key: Variant in keys:
		result *= 1.0 - clampf(float((sources[key] as Dictionary).get("reduction", 0.0)), 0.0, 1.0)
	return result
