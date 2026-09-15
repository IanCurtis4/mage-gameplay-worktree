class_name StatBreakdown
extends RefCounted
## Immutable-by-convention result produced by StatCalculator.
## Consumers read values/details; only StatCalculator populates these dictionaries.

var base_level: int = 1
var primary: Dictionary = {}
var derived: Dictionary = {}
var modifier_sources: Array[Dictionary] = []

func primary_value(stat_id: StringName) -> float:
	var detail: Dictionary = primary.get(stat_id, {})
	return float(detail.get("effective", NAN))

func value(stat_id: StringName) -> float:
	if primary.has(stat_id):
		return primary_value(stat_id)
	var detail: Dictionary = derived.get(stat_id, {})
	return float(detail.get("effective", NAN))

func values() -> Dictionary[StringName, float]:
	var result: Dictionary[StringName, float] = {}
	for raw_id: Variant in primary:
		var stat_id := StringName(raw_id)
		result[stat_id] = float(primary[raw_id]["effective"])
	for raw_id: Variant in derived:
		var stat_id := StringName(raw_id)
		result[stat_id] = float(derived[raw_id]["effective"])
	return result

func primary_detail(stat_id: StringName) -> Dictionary:
	return primary.get(stat_id, {}).duplicate(true)

func derived_detail(stat_id: StringName) -> Dictionary:
	return derived.get(stat_id, {}).duplicate(true)

func sources() -> Array[Dictionary]:
	return modifier_sources.duplicate(true)
