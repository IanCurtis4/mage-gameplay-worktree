extends RefCounted
## Minimal value fixtures only, never registered in production or profile/save.

static func count_effect(id: StringName = &"fixture_count", magnitude: float = 1.0) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = id
	effect.family_id = &"fixture_projectiles"
	effect.kind = EffectDefinition.Kind.SKILL_RULE
	effect.handler_id = EffectDefinition.Handler.PROJECTILE_COUNT
	effect.target_skill_ids = [&"fire_spear"]
	effect.axis = &"projectile_count"
	effect.unit = &"count"
	effect.magnitude = magnitude
	effect.limit = 16.0
	return effect

static func definition(origin: StringName, id: StringName, effects: Array[EffectDefinition]) -> Resource:
	var result: Resource
	if origin == &"augment":
		result = AugmentDefinition.new()
		result.max_stacks = 1
	elif origin == &"equipment":
		result = EquipmentDefinition.new()
		result.quality_id = &"rare"
		result.origin_id = &"fixture_origin"
		result.item_level = 1
		result.socket_capacity = 1
	else:
		result = CardDefinition.new()
		result.mob_base_id = &"fixture_elite"
	result.id = id
	result.display_name = "Fixture"
	result.effects = effects
	return result

static func snapshot() -> BuildSnapshot:
	return RunState.new(&"mage").build_snapshot.copy_snapshot()

static func equip(snapshot: BuildSnapshot, id: StringName, slot: StringName = &"main_hand") -> void:
	snapshot.equipped = EquipmentRules.empty_layout()
	snapshot.equipped[slot] = id
	var created := EquipmentInstance.from_metadata(id, id, {"origin_id": &"fixture_origin", "item_level": 1, "quality_id": &"rare", "socket_capacity": 1})
	assert(created["ok"])
	snapshot.equipment_instances[id] = created["instance"]

static func state_for(origin: StringName, snapshot: BuildSnapshot, id: StringName = &"fixture") -> Dictionary:
	if origin == &"augment": return {"augment_stacks": {id: 1}}
	if origin == &"equipment":
		equip(snapshot, id)
		return {}
	equip(snapshot, &"fixture_empty_item")
	return {"card_sockets": {&"fixture_empty_item": [id]}, "card_instances": {id: id}}

static func catalog_for(origin: StringName, effects: Array[EffectDefinition]) -> BuildEffectCatalog:
	var registry := registry()
	assert(registry.register_definition(origin, definition(origin, &"fixture", effects))["ok"])
	if origin == &"card":
		var empty: Array[EffectDefinition] = []
		assert(registry.register_definition(&"equipment", definition(&"equipment", &"fixture_empty_item", empty))["ok"])
	return registry

static func proc_effect(id: StringName = &"fixture_proc", family: StringName = &"fixture_hit", magnitude: float = 5.0) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = id
	effect.family_id = family
	effect.kind = EffectDefinition.Kind.PROC
	effect.handler_id = EffectDefinition.Handler.HIT_DAMAGE
	effect.trigger = EffectDefinition.Trigger.ON_HIT
	effect.axis = &"physical_damage"
	effect.unit = &"damage"
	effect.magnitude = magnitude
	effect.limit = 100.0
	return effect

static func range_effect() -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = &"fixture_range"
	effect.family_id = &"fixture_range"
	effect.kind = EffectDefinition.Kind.SKILL_RULE
	effect.handler_id = EffectDefinition.Handler.SKILL_SCALAR
	effect.target_skill_ids = [&"fire_spear"]
	effect.axis = &"range"
	effect.unit = &"units"
	effect.magnitude = 100.0
	effect.limit = 900.0
	return effect

static func registry() -> BuildEffectCatalog:
	var mobs := MobCatalog.new()
	var mob := MobDefinition.new()
	mob.id = &"fixture_elite"
	mob.base_category = &"elite"
	mob.allowed_occurrence_categories = [&"elite", &"rare_elite"]
	for axis: StringName in StatCalculator.PRIMARY_IDS:
		mob.primary_attributes[axis] = 3
	assert(mobs.register_definition(mob)["ok"])
	var result := BuildEffectCatalog.new()
	assert(result.set_mob_catalog(mobs)["ok"])
	return result
