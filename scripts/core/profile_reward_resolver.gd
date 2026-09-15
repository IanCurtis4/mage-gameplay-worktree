class_name ProfileRewardResolver
extends RefCounted
## Immutable local reward table. Callers select an ID; they never supply reward values.

const MAX_EXACT_INTEGER := 9007199254740991
const ALLOWED_STAT_INCREMENTS: Array[StringName] = [&"kills"]

var _definitions: Dictionary[StringName, Dictionary] = {}
var _valid := true

func _init(definitions: Dictionary = {}) -> void:
	for raw_reward_id: Variant in definitions:
		if not raw_reward_id is StringName and not raw_reward_id is String:
			_valid = false
			continue
		var reward_id := StringName(raw_reward_id)
		var normalized := _normalize_definition(definitions[raw_reward_id])
		if not IdentityIds.is_technical_id(String(reward_id)) or _definitions.has(reward_id) or not normalized["ok"]:
			_valid = false
			continue
		_definitions[reward_id] = normalized["definition"]

func is_valid() -> bool:
	return _valid

func is_compatible_with(catalog: ProfileCatalog) -> bool:
	if not _valid or catalog == null or not catalog.is_valid():
		return false
	for definition: Dictionary in _definitions.values():
		for item_id: StringName in definition["equipment_ids"]:
			if not catalog.knows_equipment(item_id):
				return false
	return true

func copy_resolver() -> ProfileRewardResolver:
	var copy := ProfileRewardResolver.new(_definitions.duplicate(true))
	if not _valid:
		copy._valid = false
	return copy

func resolve(reward_id: StringName) -> Dictionary:
	if not _valid:
		return {"ok": false, "error_code": &"invalid_catalog"}
	if not _definitions.has(reward_id):
		return {"ok": false, "error_code": &"invalid_reward"}
	return {"ok": true, "reward": _definitions[reward_id].duplicate(true)}

func _normalize_definition(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {"ok": false}
	var data: Dictionary = raw
	for key: Variant in data:
		if key not in ["base_xp", "job_xp", "equipment_ids", "stat_increments"]:
			return {"ok": false}
	var base_xp: Variant = data.get("base_xp", 0)
	var job_xp: Variant = data.get("job_xp", 0)
	if not _is_nonnegative_exact_integer(base_xp) or not _is_nonnegative_exact_integer(job_xp):
		return {"ok": false}
	var raw_equipment: Variant = data.get("equipment_ids", [])
	if not raw_equipment is Array:
		return {"ok": false}
	var equipment_ids: Array[StringName] = []
	for raw_item_id: Variant in raw_equipment:
		if not raw_item_id is StringName and not raw_item_id is String:
			return {"ok": false}
		var item_id := StringName(raw_item_id)
		if not IdentityIds.is_technical_id(String(item_id)):
			return {"ok": false}
		if item_id not in equipment_ids:
			equipment_ids.append(item_id)
	var raw_stats: Variant = data.get("stat_increments", {})
	if not raw_stats is Dictionary:
		return {"ok": false}
	var stat_increments: Dictionary[StringName, int] = {}
	for raw_stat_id: Variant in raw_stats:
		if not raw_stat_id is StringName and not raw_stat_id is String:
			return {"ok": false}
		var stat_id := StringName(raw_stat_id)
		if stat_id not in ALLOWED_STAT_INCREMENTS or not _is_nonnegative_exact_integer(raw_stats[raw_stat_id]):
			return {"ok": false}
		stat_increments[stat_id] = int(raw_stats[raw_stat_id])
	return {
		"ok": true,
		"definition": {
			"base_xp": int(base_xp),
			"job_xp": int(job_xp),
			"equipment_ids": equipment_ids,
			"stat_increments": stat_increments,
		},
	}

func _is_nonnegative_exact_integer(value: Variant) -> bool:
	return value is int and value >= 0 and value <= MAX_EXACT_INTEGER
