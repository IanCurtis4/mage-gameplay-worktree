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
var _death_emitted: bool = false

func _init(runtime_id: int = 0, initial_stats: StatBreakdown = null) -> void:
	actor_id = runtime_id
	max_hp = maxf(1.0, initial_stats.value(&"max_hp")) if initial_stats != null else 1.0
	current_hp = max_hp
	_set_defensive_stats(initial_stats)

func is_alive() -> bool:
	return current_hp > 0.0

func apply(request: DamageRequest, hit_roll: float, crit_roll: float, debuffs: AttributeDebuffState = null) -> Dictionary:
	if not is_alive() or request.target_id != actor_id:
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
	var actual_damage := minf(previous_hp, float(result["damage"]))
	current_hp = maxf(0.0, current_hp - actual_damage)
	var killed := previous_hp > 0.0 and current_hp <= 0.0
	result["actual_damage"] = actual_damage
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
	_set_defensive_stats(new_stats)
	_death_emitted = false

func _set_defensive_stats(new_stats: StatBreakdown) -> void:
	physical_defense = maxf(0.0, new_stats.value(&"physical_defense")) if new_stats != null else 0.0
	magic_defense = maxf(0.0, new_stats.value(&"magic_defense")) if new_stats != null else 0.0
	flee_rating = maxf(0.0, new_stats.value(&"flee_rating")) if new_stats != null else 0.0
	crit_resistance = clampf(new_stats.value(&"crit_resistance"), 0.0, 0.5) if new_stats != null else 0.0
