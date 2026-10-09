class_name HealthState
extends RefCounted
## Owns mutable health for one runtime actor and applies CombatMath results once.

signal damage_applied(result: Dictionary)
signal actor_died(actor_id: int)

var actor_id: int
var max_hp: float
var current_hp: float
var physical_defense: float
var magic_defense: float
var flee_rating: float
var crit_resistance: float
var shield_hp := 0.0
var _death_emitted: bool = false

func _init(runtime_id: int = 0, initial_stats: StatBreakdown = null) -> void:
	actor_id = runtime_id
	max_hp = maxf(1.0, initial_stats.value(&"max_hp")) if initial_stats != null else 1.0
	current_hp = max_hp
	_set_defensive_stats(initial_stats)

func is_alive() -> bool:
	return current_hp > 0.0

func spend_hp_nonlethal(cost: float) -> bool:
	if not is_finite(cost) or cost < 0.0 or current_hp <= cost:
		return false
	current_hp -= cost
	return true

func apply(request: DamageRequest, hit_roll: float, crit_roll: float, debuffs: AttributeDebuffState = null) -> Dictionary:
	if request == null or request.cancelled or request.target_id != actor_id:
		return {}
	if request.context != null:
		if request.source_id != request.context._budget.owner_id or (request.context.event_id > 0 and request.context.target_id != actor_id):
			return {}
		if not request.context.is_active():
			return {}
		if request.is_secondary and request.context.event_id == 0:
			var claims := request.context.ledger().claim_intrinsic(request.context, [{"family_id": request.skill_id, "source_id": StringName(str(request.source_id)), "target_id": actor_id}])
			if claims.is_empty():
				return {}
			request.context = claims[0]["context"]
		else:
			request.context = request.context.impact(actor_id)
		if not request.context.ledger().apply_once(request.context):
			return {}
	if not is_alive():
		return {}
	var effective_physical_defense := physical_defense
	var effective_magic_defense := magic_defense
	var effective_flee := flee_rating
	if debuffs != null:
		effective_physical_defense = StatCalculator.runtime_reduced_value(&"physical_defense", physical_defense, debuffs.fraction(AttributeDebuffState.PHYSICAL_DEFENSE))
		effective_magic_defense = StatCalculator.runtime_reduced_value(&"magic_defense", magic_defense, debuffs.fraction(AttributeDebuffState.MAGIC_DEFENSE))
		effective_flee = StatCalculator.runtime_reduced_value(&"flee_rating", flee_rating, debuffs.fraction(AttributeDebuffState.FLEE))
	var result := CombatMath.resolve(
		request,
		effective_physical_defense,
		effective_magic_defense,
		effective_flee,
		crit_resistance,
		hit_roll,
		crit_roll
	)
	var previous_hp := current_hp
	var absorbed_damage := minf(shield_hp, float(result["damage"]))
	shield_hp = maxf(0.0, shield_hp - absorbed_damage)
	var actual_damage := minf(previous_hp, float(result["damage"]) - absorbed_damage)
	current_hp = maxf(0.0, current_hp - actual_damage)
	var killed := previous_hp > 0.0 and current_hp <= 0.0
	result["actual_damage"] = actual_damage
	result["absorbed_damage"] = absorbed_damage
	result["can_trigger_effects"] = bool(result["can_trigger_effects"]) and actual_damage > 0.0
	result["killed"] = killed
	damage_applied.emit(result)
	if killed and not _death_emitted:
		_death_emitted = true
		actor_died.emit(actor_id)
	return result

func set_stats_preserving_missing(new_stats: StatBreakdown) -> void:
	assert(new_stats != null)
	var missing_hp := maxf(0.0, max_hp - current_hp)
	max_hp = maxf(1.0, new_stats.value(&"max_hp"))
	current_hp = clampf(max_hp - missing_hp, 0.0, max_hp)
	_set_defensive_stats(new_stats)

func reset(new_stats: StatBreakdown) -> void:
	assert(new_stats != null)
	max_hp = maxf(1.0, new_stats.value(&"max_hp"))
	current_hp = max_hp
	shield_hp = 0.0
	_set_defensive_stats(new_stats)
	_death_emitted = false

func grant_shield(capacity: float) -> bool:
	if not is_alive() or not is_finite(capacity) or capacity <= 0.0:
		return false
	shield_hp = maxf(shield_hp, capacity)
	return true

func clear_shield() -> void:
	shield_hp = 0.0

func _set_defensive_stats(new_stats: StatBreakdown) -> void:
	physical_defense = maxf(0.0, new_stats.value(&"physical_defense")) if new_stats != null else 0.0
	magic_defense = maxf(0.0, new_stats.value(&"magic_defense")) if new_stats != null else 0.0
	flee_rating = maxf(0.0, new_stats.value(&"flee_rating")) if new_stats != null else 0.0
	crit_resistance = clampf(new_stats.value(&"crit_resistance"), 0.0, 0.5) if new_stats != null else 0.0
