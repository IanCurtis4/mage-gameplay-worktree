class_name MobCatalog
extends RefCounted
const CATEGORIES: Array[StringName] = [&"normal", &"rare", &"elite", &"rare_elite", &"boss"]
const COMPLEX_BASES: Array[StringName] = [&"elite", &"rare_elite", &"boss"]
var _definitions: Dictionary = {}
func copy_catalog() -> MobCatalog:
	var result := MobCatalog.new()
	for id: StringName in _definitions:
		result._definitions[id] = _definitions[id].duplicate(true)
	return result
func register_definition(definition: MobDefinition) -> Dictionary:
	if definition == null or not IdentityIds.is_technical_id(String(definition.id)) or _definitions.has(definition.id) or definition.base_category not in CATEGORIES or definition.fixed_level < 1 or definition.fixed_level > ProgressionRules.MAX_BASE_LEVEL or definition.allowed_occurrence_categories.is_empty():
		return BuildEffectCatalog.failure(&"invalid_mob_definition")
	var seen: Dictionary = {}
	for category: StringName in definition.allowed_occurrence_categories:
		if category not in CATEGORIES or seen.has(category):
			return BuildEffectCatalog.failure(&"invalid_mob_category")
		seen[category] = true
	if definition.primary_attributes.size() != StatCalculator.PRIMARY_IDS.size():
		return BuildEffectCatalog.failure(&"invalid_mob_stats")
	for axis: StringName in StatCalculator.PRIMARY_IDS:
		if not EquipmentRules.exact_integer(definition.primary_attributes.get(axis), 0, 1000000):
			return BuildEffectCatalog.failure(&"invalid_mob_stats")
	_definitions[definition.id] = definition.duplicate(true)
	return {"ok": true}
func get_definition(id: StringName) -> MobDefinition:
	var definition: MobDefinition = _definitions.get(id)
	return definition.duplicate(true) as MobDefinition if definition != null else null
func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_definitions.keys())
	result.sort()
	return result
