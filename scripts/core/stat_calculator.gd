class_name StatCalculator
extends RefCounted
## Canonical E00/E03 stat authority.
##
## Persistent state owns initial attributes, allocations and base level.
## Runtime/content systems contribute identified modifier sources. UI/actors must
## consume StatBreakdown rather than duplicating any formula in this file.

const PRIMARY_IDS: Array[StringName] = [
	&"str", &"agi", &"vit", &"int", &"dex", &"luk",
]

const DERIVED_IDS: Array[StringName] = [
	&"max_hp",
	&"max_sp",
	&"hp_regen",
	&"sp_regen",
	&"melee_attack",
	&"precision_attack",
	&"magic_attack",
	&"physical_defense",
	&"magic_defense",
	&"hit_rating",
	&"flee_rating",
	&"crit_chance",
	&"crit_multiplier",
	&"crit_resistance",
	&"attacks_per_second",
	&"attack_speed_index",
	&"move_speed",
	&"variable_cast_multiplier",
	&"fixed_cast_reduction",
	&"after_cast_reduction",
	&"cooldown_reduction",
	&"physical_cc_resistance",
	&"magic_cc_resistance",
	&"damage_dealt_multiplier",
]

# attack_speed_index is derived from the already-effective attacks_per_second and
# therefore intentionally refuses direct flat/increased modifiers.
const DIRECT_MODIFIER_IDS: Array[StringName] = [
	&"max_hp",
	&"max_sp",
	&"hp_regen",
	&"sp_regen",
	&"melee_attack",
	&"precision_attack",
	&"magic_attack",
	&"physical_defense",
	&"magic_defense",
	&"hit_rating",
	&"flee_rating",
	&"crit_chance",
	&"crit_multiplier",
	&"crit_resistance",
	&"attacks_per_second",
	&"move_speed",
	&"variable_cast_multiplier",
	&"fixed_cast_reduction",
	&"after_cast_reduction",
	&"cooldown_reduction",
	&"physical_cc_resistance",
	&"magic_cc_resistance",
	&"damage_dealt_multiplier",
]

const DERIVED_LIMITS := {
	&"max_hp": Vector2(1.0, 100000.0),
	&"max_sp": Vector2(0.0, 100000.0),
	&"hp_regen": Vector2(0.0, 100.0),
	&"sp_regen": Vector2(0.0, 100.0),
	&"melee_attack": Vector2(0.0, 10000.0),
	&"precision_attack": Vector2(0.0, 10000.0),
	&"magic_attack": Vector2(0.0, 10000.0),
	&"physical_defense": Vector2(0.0, 900.0),
	&"magic_defense": Vector2(0.0, 900.0),
	&"hit_rating": Vector2(0.0, 1000.0),
	&"flee_rating": Vector2(0.0, 1000.0),
	&"crit_chance": Vector2(0.0, 0.75),
	&"crit_multiplier": Vector2(1.0, 3.0),
	&"crit_resistance": Vector2(0.0, 0.5),
	&"attacks_per_second": Vector2(0.2, 4.0),
	&"attack_speed_index": Vector2(20.0, 400.0),
	&"move_speed": Vector2(80.0, 440.0),
	&"variable_cast_multiplier": Vector2(0.25, 2.0),
	&"fixed_cast_reduction": Vector2(0.0, 0.5),
	&"after_cast_reduction": Vector2(-1.0, 0.8),
	&"cooldown_reduction": Vector2(-1.0, 0.8),
	&"physical_cc_resistance": Vector2(0.0, 0.5),
	&"magic_cc_resistance": Vector2(0.0, 0.5),
	&"damage_dealt_multiplier": Vector2(0.0, 4.0),
}

const PRIMARY_MIN := 0.0
const PRIMARY_MAX := 120.0
const INVESTED_ATTRIBUTE_MAX := 60

static func calculate(
	initial_attributes: Dictionary,
	attribute_allocations: Dictionary = {},
	base_level: int = 1,
	modifier_sources: Array[Dictionary] = []
) -> StatBreakdown:
	var result := try_calculate(initial_attributes, attribute_allocations, base_level, modifier_sources)
	if not result["ok"]:
		push_error("StatCalculator failed: %s (%s)" % [result["error_code"], result.get("detail", "")])
		return null
	return result["breakdown"]

static func try_calculate(
	initial_attributes: Dictionary,
	attribute_allocations: Dictionary = {},
	base_level: int = 1,
	modifier_sources: Array[Dictionary] = []
) -> Dictionary:
	if base_level < 1 or base_level > ProgressionRules.MAX_BASE_LEVEL:
		return _failure(&"invalid_base_level", "base_level must be within the accepted progression cap")

	var initial_result := _validated_attributes(initial_attributes, &"initial")
	if not initial_result["ok"]:
		return initial_result
	var allocation_result := _validated_attributes(attribute_allocations, &"allocation")
	if not allocation_result["ok"]:
		return allocation_result

	var source_result := _aggregate_sources(modifier_sources)
	if not source_result["ok"]:
		return source_result

	var initial: Dictionary = initial_result["values"]
	var allocated: Dictionary = allocation_result["values"]
	var aggregate: Dictionary = source_result["aggregate"]
	var primary_flat: Dictionary = aggregate["primary_flat"]
	var flat: Dictionary = aggregate["flat"]
	var increased: Dictionary = aggregate["increased"]

	var breakdown := StatBreakdown.new()
	breakdown.base_level = base_level
	breakdown.modifier_sources = source_result["sources"]

	var effective_primary: Dictionary[StringName, float] = {}
	for stat_id: StringName in PRIMARY_IDS:
		var initial_value := float(initial.get(stat_id, 0))
		var allocated_value := float(allocated.get(stat_id, 0))
		if initial_value + allocated_value > INVESTED_ATTRIBUTE_MAX:
			return _failure(
				&"investment_cap_exceeded",
				"%s initial + allocated exceeds %d" % [stat_id, INVESTED_ATTRIBUTE_MAX]
			)
		var flat_value := float(primary_flat.get(stat_id, 0.0))
		var effective := clampf(initial_value + allocated_value + flat_value, PRIMARY_MIN, PRIMARY_MAX)
		effective_primary[stat_id] = effective
		breakdown.primary[stat_id] = {
			"initial": initial_value,
			"allocated": allocated_value,
			"flat": flat_value,
			"effective": effective,
			"minimum": PRIMARY_MIN,
			"maximum": PRIMARY_MAX,
		}

	var raw := _raw_derived(effective_primary, base_level)
	for stat_id: StringName in DIRECT_MODIFIER_IDS:
		var limits: Vector2 = DERIVED_LIMITS[stat_id]
		var raw_value := float(raw[stat_id])
		var flat_value := float(flat.get(stat_id, 0.0))
		var increased_value := float(increased.get(stat_id, 0.0))
		var effective := clampf(
			(raw_value + flat_value) * (1.0 + increased_value),
			limits.x,
			limits.y
		)
		breakdown.derived[stat_id] = {
			"raw": raw_value,
			"flat": flat_value,
			"increased": increased_value,
			"effective": effective,
			"minimum": limits.x,
			"maximum": limits.y,
		}

	var aspd_limits: Vector2 = DERIVED_LIMITS[&"attack_speed_index"]
	var effective_aps := float(breakdown.derived[&"attacks_per_second"]["effective"])
	var attack_speed_index := clampf(100.0 * effective_aps, aspd_limits.x, aspd_limits.y)
	breakdown.derived[&"attack_speed_index"] = {
		"raw": attack_speed_index,
		"flat": 0.0,
		"increased": 0.0,
		"effective": attack_speed_index,
		"minimum": aspd_limits.x,
		"maximum": aspd_limits.y,
	}

	return {"ok": true, "breakdown": breakdown}

static func contested_hit_chance(attacker_hit_rating: float, target_flee_rating: float) -> float:
	return clampf(0.90 + (attacker_hit_rating - target_flee_rating) / 200.0, 0.05, 0.98)

static func effective_crit_chance(attacker_crit_chance: float, target_crit_resistance: float) -> float:
	return clampf(attacker_crit_chance - target_crit_resistance, 0.0, 0.75)

static func effective_cast_time(fixed_cast_s: float, variable_cast_s: float, stats: StatBreakdown) -> float:
	if stats == null or not _valid_duration(fixed_cast_s) or not _valid_duration(variable_cast_s):
		return NAN
	return (
		fixed_cast_s * (1.0 - stats.value(&"fixed_cast_reduction"))
		+ variable_cast_s * stats.value(&"variable_cast_multiplier")
	)

static func effective_after_cast(after_cast_s: float, stats: StatBreakdown) -> float:
	if stats == null or not _valid_duration(after_cast_s):
		return NAN
	return after_cast_s * (1.0 - stats.value(&"after_cast_reduction"))

static func effective_cooldown(cooldown_s: float, stats: StatBreakdown) -> float:
	if stats == null or not _valid_duration(cooldown_s):
		return NAN
	return cooldown_s * (1.0 - stats.value(&"cooldown_reduction"))

static func _raw_derived(primary: Dictionary[StringName, float], base_level: int) -> Dictionary[StringName, float]:
	var strength := primary[&"str"]
	var agility := primary[&"agi"]
	var vitality := primary[&"vit"]
	var intelligence := primary[&"int"]
	var dexterity := primary[&"dex"]
	var luck := primary[&"luk"]
	var level_delta := float(base_level - 1)

	return {
		&"max_hp": 100.0 + 10.0 * vitality + 8.0 * level_delta,
		&"max_sp": 40.0 + 5.0 * intelligence + 3.0 * level_delta,
		&"hp_regen": 0.5 + 0.05 * vitality,
		&"sp_regen": 2.0 + 0.12 * intelligence,
		&"melee_attack": 10.0 + 2.0 * strength + 0.4 * dexterity,
		&"precision_attack": 10.0 + 2.0 * dexterity + 0.4 * strength,
		&"magic_attack": 10.0 + 2.0 * intelligence + 0.4 * dexterity,
		&"physical_defense": 2.0 * vitality + 0.5 * strength,
		&"magic_defense": 2.0 * intelligence + 0.5 * vitality,
		&"hit_rating": 100.0 + float(base_level) + 2.0 * dexterity + 0.2 * luck,
		&"flee_rating": 100.0 + float(base_level) + 1.5 * agility + 0.2 * luck,
		&"crit_chance": 0.05 + 0.003 * luck + 0.0005 * dexterity,
		&"crit_multiplier": 1.5,
		&"crit_resistance": 0.0,
		&"attacks_per_second": 1.0 + 0.015 * agility + 0.005 * dexterity,
		&"move_speed": 220.0,
		&"variable_cast_multiplier": 1.0 - 0.003 * dexterity - 0.001 * intelligence,
		&"fixed_cast_reduction": 0.0,
		&"after_cast_reduction": 0.0,
		&"cooldown_reduction": 0.0,
		&"physical_cc_resistance": 0.002 * vitality,
		&"magic_cc_resistance": 0.002 * intelligence,
		&"damage_dealt_multiplier": 1.0,
	}

static func _validated_attributes(values: Dictionary, kind: StringName) -> Dictionary:
	var normalized: Dictionary[StringName, int] = {}
	for raw_id: Variant in values:
		if not (raw_id is String or raw_id is StringName):
			return _failure(&"invalid_stat_id", "%s attribute id is not text" % kind)
		var stat_id := StringName(raw_id)
		if stat_id not in PRIMARY_IDS:
			return _failure(&"invalid_stat_id", "%s is not a primary attribute" % stat_id)
		var raw_value: Variant = values[raw_id]
		if not (raw_value is int) or int(raw_value) < 0:
			return _failure(
				&"invalid_attribute_value",
				"%s %s must be a non-negative integer" % [kind, stat_id]
			)
		normalized[stat_id] = int(raw_value)
	return {"ok": true, "values": normalized}

static func _aggregate_sources(modifier_sources: Array[Dictionary]) -> Dictionary:
	var aggregate := {
		"primary_flat": {},
		"flat": {},
		"increased": {},
	}
	var normalized_sources: Array[Dictionary] = []

	for source: Dictionary in modifier_sources:
		var source_id_value: Variant = source.get("source_id", null)
		if source_id_value == null or not (source_id_value is String or source_id_value is StringName):
			return _failure(&"invalid_modifier_source", "every modifier source needs a textual source_id")
		var source_id := StringName(source_id_value)
		if source_id.is_empty():
			return _failure(&"invalid_modifier_source", "modifier source_id cannot be empty")
		if source.has("primary_increased"):
			return _failure(&"primary_percentage_not_allowed", "%s defines primary_increased" % source_id)
		for raw_source_key: Variant in source:
			if str(raw_source_key) not in ["source_id", "label", "primary_flat", "flat", "increased"]:
				return _failure(&"invalid_modifier_source", "%s contains unsupported field %s" % [source_id, raw_source_key])

		var normalized_source: Dictionary = {
			"source_id": source_id,
			"label": str(source.get("label", "")),
			"primary_flat": {},
			"flat": {},
			"increased": {},
		}

		for bucket_name: String in ["primary_flat", "flat", "increased"]:
			var bucket_value: Variant = source.get(bucket_name, {})
			if not (bucket_value is Dictionary):
				return _failure(
					&"invalid_modifier_bucket",
					"%s.%s must be a Dictionary" % [source_id, bucket_name]
				)
			var normalized_bucket: Dictionary = {}
			for raw_id: Variant in bucket_value:
				if not (raw_id is String or raw_id is StringName):
					return _failure(&"invalid_stat_id", "%s.%s contains a non-text stat id" % [source_id, bucket_name])
				var stat_id := StringName(raw_id)
				var id_is_valid := stat_id in PRIMARY_IDS if bucket_name == "primary_flat" else stat_id in DIRECT_MODIFIER_IDS
				if not id_is_valid:
					var error_code := &"modifier_not_allowed" if stat_id in DERIVED_IDS else &"invalid_stat_id"
					return _failure(error_code, "%s cannot modify %s through %s" % [source_id, stat_id, bucket_name])
				var raw_modifier: Variant = bucket_value[raw_id]
				if not (raw_modifier is int or raw_modifier is float) or not is_finite(float(raw_modifier)):
					return _failure(&"non_finite_modifier", "%s.%s.%s must be finite" % [source_id, bucket_name, stat_id])
				var modifier := float(raw_modifier)
				normalized_bucket[stat_id] = modifier
				aggregate[bucket_name][stat_id] = float(aggregate[bucket_name].get(stat_id, 0.0)) + modifier
			normalized_source[bucket_name] = normalized_bucket
		normalized_sources.append(normalized_source)

	return {
		"ok": true,
		"aggregate": aggregate,
		"sources": normalized_sources,
	}

static func _valid_duration(value: float) -> bool:
	return is_finite(value) and value >= 0.0

static func _failure(error_code: StringName, detail: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"detail": detail,
	}
