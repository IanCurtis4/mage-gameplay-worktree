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
	else:
		result = CardDefinition.new()
	result.id = id
	result.display_name = "Fixture"
	result.effects = effects
	return result

static func snapshot() -> BuildSnapshot:
	return RunState.new(&"mage").build_snapshot.copy_snapshot()

static func state_for(origin: StringName, snapshot: BuildSnapshot, id: StringName = &"fixture") -> Dictionary:
	if origin == &"augment":
		return {"augment_stacks": {id: 1}}
	if origin == &"equipment":
		snapshot.equipped = {&"weapon": id}
		return {}
	snapshot.equipped = {&"weapon": &"fixture_empty_item"}
	return {"card_sockets": {&"fixture_empty_item": id}}

static func catalog_for(origin: StringName, effects: Array[EffectDefinition]) -> BuildEffectCatalog:
	var registry := BuildEffectCatalog.new()
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
