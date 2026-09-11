class_name HealthState
extends RefCounted
## Owns mutable health for one runtime actor and applies CombatMath results once.

signal damage_applied(result: Dictionary)
signal actor_died(actor_id: int)

var actor_id: int
var max_hp: float
var current_hp: float
var defense: float
var _death_emitted: bool = false

func _init(runtime_id: int = 0, initial_max_hp: float = 1.0, initial_defense: float = 0.0) -> void:
	actor_id = runtime_id
	max_hp = maxf(1.0, initial_max_hp)
	current_hp = max_hp
	defense = maxf(0.0, initial_defense)

func is_alive() -> bool:
	return current_hp > 0.0

func apply(request: DamageRequest, hit_roll: float, crit_roll: float) -> Dictionary:
	if not is_alive() or request.target_id != actor_id:
		return {}
	var result := CombatMath.resolve(request, defense, hit_roll, crit_roll)
	var previous_hp := current_hp
	var actual_damage := mini(int(round(previous_hp)), int(result["damage"]))
	current_hp = maxf(0.0, current_hp - float(actual_damage))
	var killed := previous_hp > 0.0 and current_hp <= 0.0
	result["actual_damage"] = actual_damage
	result["killed"] = killed
	damage_applied.emit(result)
	if killed and not _death_emitted:
		_death_emitted = true
		actor_died.emit(actor_id)
	return result

func set_max_preserving_missing(new_max_hp: float) -> void:
	var missing_hp := maxf(0.0, max_hp - current_hp)
	max_hp = maxf(1.0, new_max_hp)
	current_hp = clampf(max_hp - missing_hp, 0.0, max_hp)

func reset(new_max_hp: float, new_defense: float) -> void:
	max_hp = maxf(1.0, new_max_hp)
	current_hp = max_hp
	defense = maxf(0.0, new_defense)
	_death_emitted = false
