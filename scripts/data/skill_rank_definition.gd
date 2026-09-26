class_name SkillRankDefinition
extends Resource
## Immutable-by-convention execution values for one effective skill rank.

@export var rank: int = 1
@export var sp_cost: float = 0.0
@export var fixed_cast_time: float = 0.0
@export var variable_cast_time: float = 0.0
@export var post_cast_time: float = 0.0
@export var cooldown: float = 0.0
@export var range: float = 0.0
@export var power: float = 0.0
@export var secondary_power: float = 0.0
@export var physical_weight: float = 0.0
@export var precision_weight: float = 0.0
@export var magic_weight: float = 0.0
@export var projectile_speed: float = 0.0
@export var effect_ids: Array[StringName] = []

func is_valid() -> bool:
	if rank < 1:
		return false
	for value: float in [sp_cost, fixed_cast_time, variable_cast_time, post_cast_time, cooldown, range, power, secondary_power, projectile_speed]:
		if not is_finite(value) or value < 0.0:
			return false
	var weight_sum := 0.0
	for weight: float in [physical_weight, precision_weight, magic_weight]:
		if not is_finite(weight) or weight < 0.0 or weight > 1.0:
			return false
		weight_sum += weight
	if not is_zero_approx(weight_sum) and not is_equal_approx(weight_sum, 1.0):
		return false
	var seen_effects: Dictionary[StringName, bool] = {}
	for effect_id: StringName in effect_ids:
		if effect_id.is_empty() or seen_effects.has(effect_id):
			return false
		seen_effects[effect_id] = true
	return true
