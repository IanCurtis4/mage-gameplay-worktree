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
	for origin: Variant in definition.origin_levels:
		if typeof(origin) not in [TYPE_STRING, TYPE_STRING_NAME] or not IdentityIds.is_technical_id(String(origin)) or not EquipmentRules.exact_integer(definition.origin_levels[origin], 1, 30):
			return BuildEffectCatalog.failure(&"invalid_mob_origin")
	if definition.visual_kind not in [&"humanoid", &"gel", &"companion"] or not is_finite(definition.aggro_radius) or not is_finite(definition.leash_radius) or not is_finite(definition.sight_timeout) or definition.sight_timeout <= 0.0 or definition.aggro_radius < 0.0 or definition.leash_radius < 0.0 or (definition.aggro_radius > 0.0 and definition.leash_radius <= definition.aggro_radius):
		return BuildEffectCatalog.failure(&"invalid_mob_behavior")
	if definition.summons_companion and (&"normal" in definition.allowed_occurrence_categories or definition.visual_kind == &"companion"):
		return BuildEffectCatalog.failure(&"invalid_mob_summon")
	var seen: Dictionary = {}
	for category: StringName in definition.allowed_occurrence_categories:
		if category not in CATEGORIES or seen.has(category):
			return BuildEffectCatalog.failure(&"invalid_mob_category")
		seen[category] = true
	if definition.primary_attributes.size() != StatCalculator.PRIMARY_IDS.size():
		return BuildEffectCatalog.failure(&"invalid_mob_stats")
	for axis: StringName in StatCalculator.PRIMARY_IDS:
		if not EquipmentRules.exact_integer(definition.primary_attributes.get(axis), 0):
			return BuildEffectCatalog.failure(&"invalid_mob_stats")
	if definition.archetype not in [&"chaser", &"archer"] or definition.animation_kind not in [&"warrior", &"archer", &"gel", &"beast_master", &"animal_companion"] or not is_finite(definition.collision_radius) or definition.collision_radius <= 0.0:
		return BuildEffectCatalog.failure(&"invalid_mob_definition")
	if definition.skill_ranks.size() != definition.skill_ids.size():
		return BuildEffectCatalog.failure(&"invalid_mob_skill")
	seen.clear()
	for skill: StringName in definition.skill_ids:
		if seen.has(skill) or not EquipmentRules.exact_integer(definition.skill_ranks.get(skill), 1, 5) or not MobSkillAdapters.supports(skill, int(definition.skill_ranks[skill])):
			return BuildEffectCatalog.failure(&"invalid_mob_skill")
		seen[skill] = true
	var stats := StatCalculator.try_calculate(definition.primary_attributes, {}, definition.fixed_level, definition.modifier_sources)
	if not stats["ok"] or stats["breakdown"].value(&"max_hp") <= 0.0:
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

func stats(id: StringName) -> Dictionary:
	var definition := get_definition(id)
	if definition == null:
		return BuildEffectCatalog.failure(&"invalid_mob_definition")
	return StatCalculator.try_calculate(definition.primary_attributes, {}, definition.fixed_level, definition.modifier_sources)

func level_for_occurrence(spawn: MobOccurrence) -> Dictionary:
	if spawn == null: return BuildEffectCatalog.failure(&"invalid_occurrence")
	var definition := get_definition(spawn.mob_base_id)
	if definition == null or spawn.category_id not in definition.allowed_occurrence_categories:
		return BuildEffectCatalog.failure(&"invalid_mob_category")
	var level := definition.fixed_level
	if not definition.origin_levels.is_empty():
		if not definition.origin_levels.has(spawn.origin_id): return BuildEffectCatalog.failure(&"invalid_mob_origin")
		level = int(definition.origin_levels[spawn.origin_id])
	return {"ok": true, "definition": definition, "level": level}

func stats_for_occurrence(spawn: MobOccurrence) -> Dictionary:
	var checked := level_for_occurrence(spawn)
	if not checked["ok"]: return checked
	var definition: MobDefinition = checked["definition"]
	var base := StatCalculator.try_calculate(definition.primary_attributes, {}, checked["level"], definition.modifier_sources)
	if not base["ok"]: return base
	var derived := StatCalculator.try_calculate(definition.primary_attributes, {}, checked["level"], MobTierRules.sources(definition, spawn.category_id, base["breakdown"]))
	if derived["ok"]: derived["level"] = checked["level"]
	return derived
