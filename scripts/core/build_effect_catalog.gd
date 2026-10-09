class_name BuildEffectCatalog
extends RefCounted
## One copied registry for all three content origins. No production items in T1.

const ORIGINS: Array[StringName] = [&"augment", &"equipment", &"card"]
const SLOTS: Array[StringName] = [&"weapon", &"armor", &"accessory"]
const SCALAR_AXES: Array[StringName] = [&"range"]
const INTRINSIC_FAMILIES: Array[StringName] = [&"hunter_exploit", &"sentinel_focus", &"berserker_wound", &"berserker_pursuit", &"berserker_breath_heal", &"elementalist_focus", &"spiritualist_echo", &"spiritualist_echo_recovery", &"spiritualist_channel_focus", &"spiritualist_drain_heal", &"blood_thirst", &"defender_watch", &"defender_token", &"defender_guard_return"]
const PROJECTILE_SKILLS: Array[StringName] = [&"fire_spear", &"ice_spear", &"double_shot"]
var _definitions: Dictionary = {}

static func pilot() -> BuildEffectCatalog:
	var catalog := BuildEffectCatalog.new()
	for row: Array in [
		[&"vitality", "Vitalidade", "+20% de Vida Máxima", &"max_hp_increased", 0.20, &"", &"max_hp", &"increased"],
		[&"keen_edge", "Fio Preciso", "+5 pontos percentuais de crítico", &"crit_chance_flat", 0.05, &"", &"crit_chance", &"flat"],
		[&"battle_rhythm", "Ritmo de Batalha", "+15% de velocidade de ataque", &"attack_speed_increased", 0.15, &"", &"attacks_per_second", &"increased"],
		[&"extra_fire_spear", "Fogo Geminado", "+1 Lança de Fogo", &"fire_spear_count_flat", 1.0, &"mage", &"projectile_count", &"flat"],
		[&"extra_ice_spear", "Gelo Geminado", "+1 Lança de Gelo", &"ice_spear_count_flat", 1.0, &"mage", &"projectile_count", &"flat"],
	]:
		var augment := AugmentDefinition.new()
		augment.id = row[0]
		augment.display_name = row[1]
		augment.description = row[2]
		augment.effect_id = row[3]
		augment.magnitude_per_stack = row[4]
		augment.class_id = row[5]
		augment.max_stacks = 3
		var effect := EffectDefinition.new()
		effect.id = row[3]
		effect.family_id = row[3]
		effect.axis = row[6]
		effect.channel = row[7]
		effect.unit = &"ratio" if row[7] == &"increased" else &"points"
		effect.magnitude = row[4]
		effect.stack_values = [float(row[4]), float(row[4]) * 2.0, float(row[4]) * 3.0]
		if row[6] == &"projectile_count":
			effect.kind = EffectDefinition.Kind.SKILL_RULE
			effect.handler_id = EffectDefinition.Handler.PROJECTILE_COUNT
			effect.target_skill_ids = [&"fire_spear" if augment.id == &"extra_fire_spear" else &"ice_spear"]
			effect.unit = &"count"
			effect.limit = 16.0
		augment.effects = [effect]
		assert(catalog.register_definition(&"augment", augment)["ok"])
	return catalog

func copy_catalog() -> BuildEffectCatalog:
	var result := BuildEffectCatalog.new()
	for key: String in _definitions:
		result._definitions[key] = (_definitions[key] as Resource).duplicate(true)
	return result

func get_definition(origin: StringName, id: StringName) -> Resource:
	var definition: Resource = _definitions.get(_key(origin, id))
	return definition.duplicate(true) if definition != null else null

func ids(origin: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for key: String in _definitions:
		if key.begins_with(String(origin) + ":"):
			result.append(StringName(key.substr(String(origin).length() + 1)))
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result

func register_definition(origin: StringName, definition: Resource) -> Dictionary:
	if origin not in ORIGINS or not ((origin == &"augment" and definition is AugmentDefinition) or (origin == &"equipment" and definition is EquipmentDefinition) or (origin == &"card" and definition is CardDefinition)):
		return failure(&"invalid_definition_type")
	if definition.id.is_empty() or _definitions.has(_key(origin, definition.id)):
		return failure(&"duplicate_or_empty_id")
	if not _restrictions_valid(definition.allowed_origins, definition.allowed_evolutions):
		return failure(&"invalid_restrictions")
	if definition is EquipmentDefinition and definition.slot not in SLOTS:
		return failure(&"invalid_slot")
	if definition is CardDefinition:
		if definition.allowed_slots.is_empty():
			return failure(&"invalid_slot")
		for slot: StringName in definition.allowed_slots:
			if slot not in SLOTS:
				return failure(&"invalid_slot")
	if definition is AugmentDefinition and (definition.max_stacks < 1 or definition.max_stacks > 3 or (not definition.class_id.is_empty() and definition.class_id not in [&"mage", &"archer", &"swordsman"])):
		return failure(&"invalid_stacks")
	var seen: Dictionary = {}
	for effect: EffectDefinition in definition.effects:
		var validation := validate_effect(effect)
		if not validation["ok"]:
			return validation
		if seen.has(effect.id):
			return failure(&"duplicate_effect")
		seen[effect.id] = true
		if definition is AugmentDefinition and effect.stacking_mode == EffectDefinition.Stacking.EXCLUSIVE and definition.max_stacks != 1:
			return failure(&"exclusive_requires_one_stack")
		if not effect.stack_values.is_empty() and (not definition is AugmentDefinition or effect.stack_values.size() != definition.max_stacks):
			return failure(&"invalid_curve")
	_definitions[_key(origin, definition.id)] = definition.duplicate(true)
	return {"ok": true, "error_code": &"", "request_id": ""}

static func validate_effect(effect: EffectDefinition) -> Dictionary:
	if effect == null or effect.id.is_empty() or effect.family_id.is_empty() or effect.unit not in [&"ratio", &"points", &"count", &"units", &"seconds", &"sp", &"damage"] or effect.minimum_rank < 1 or effect.minimum_rank > 5:
		return failure(&"invalid_effect")
	for value: float in [effect.magnitude, effect.increased, effect.limit]:
		if not is_finite(value):
			return failure(&"non_finite_parameter")
	for value: float in effect.stack_values:
		if not is_finite(value):
			return failure(&"invalid_curve")
	if effect.stack_values.size() > 3 or not _restrictions_valid(effect.allowed_origins, effect.allowed_evolutions):
		return failure(&"invalid_restrictions")
	if effect.stacking_mode not in [EffectDefinition.Stacking.ADDITIVE, EffectDefinition.Stacking.EXCLUSIVE] or (effect.stacking_mode == EffectDefinition.Stacking.EXCLUSIVE and effect.conflict_group.is_empty()) or (effect.stacking_mode == EffectDefinition.Stacking.ADDITIVE and not effect.conflict_group.is_empty()):
		return failure(&"invalid_conflict_group")
	var seen: Dictionary = {}
	for skill: StringName in effect.target_skill_ids:
		if seen.has(skill) or (skill != &"basic_attack" and ClassCatalog.skill_definition(skill) == null):
			return failure(&"unknown_skill_target")
		seen[skill] = true
	if effect.kind == EffectDefinition.Kind.STAT:
		if effect.handler_id != EffectDefinition.Handler.STAT_MODIFIER or effect.trigger != EffectDefinition.Trigger.NONE or effect.increased != 0.0 or effect.limit != 0.0 or not effect.target_skill_ids.is_empty():
			return failure(&"invalid_stat_handler")
		if not ((effect.channel == &"primary_flat" and effect.axis in StatCalculator.PRIMARY_IDS) or (effect.channel in [&"flat", &"increased"] and effect.axis in StatCalculator.DIRECT_MODIFIER_IDS)):
			return failure(&"invalid_stat_axis")
	elif effect.kind == EffectDefinition.Kind.SKILL_RULE:
		if effect.trigger != EffectDefinition.Trigger.NONE or effect.target_skill_ids.is_empty() or effect.limit <= 0.0 or effect.channel != &"flat":
			return failure(&"invalid_skill_rule")
		if effect.handler_id == EffectDefinition.Handler.PROJECTILE_COUNT:
			if effect.axis != &"projectile_count" or effect.unit != &"count" or effect.limit > 16.0 or effect.limit != floorf(effect.limit) or effect.magnitude != floorf(effect.magnitude) or effect.increased != 0.0:
				return failure(&"invalid_projectile_rule")
			for value: float in effect.stack_values:
				if value != floorf(value):
					return failure(&"invalid_curve")
			for skill: StringName in effect.target_skill_ids:
				if skill not in PROJECTILE_SKILLS:
					return failure(&"unsupported_skill_axis")
		elif effect.handler_id != EffectDefinition.Handler.SKILL_SCALAR or effect.axis not in SCALAR_AXES or effect.unit != &"units" or not _all_projectile_skills(effect.target_skill_ids):
			return failure(&"unsupported_skill_axis")
	elif effect.kind == EffectDefinition.Kind.PROC:
		if effect.family_id in INTRINSIC_FAMILIES or effect.family_id == &"geometer_incidence_refund" or ClassCatalog.skill_definition(effect.family_id) != null:
			return failure(&"intrinsic_family_requires_adapter")
		if effect.handler_id != EffectDefinition.Handler.HIT_DAMAGE or effect.trigger != EffectDefinition.Trigger.ON_HIT or effect.axis not in [&"physical_damage", &"magic_damage"] or effect.magnitude < 0.0 or effect.increased < 0.0 or effect.limit <= 0.0 or effect.unit != &"damage":
			return failure(&"unsupported_proc")
	else:
		return failure(&"unsupported_handler")
	return {"ok": true, "error_code": &"", "request_id": ""}

static func definition_allowed(definition: Resource, snapshot: BuildSnapshot) -> bool:
	return (definition.allowed_origins.is_empty() or snapshot.base_class_id in definition.allowed_origins) and (definition.allowed_evolutions.is_empty() or snapshot.evolution_id in definition.allowed_evolutions) and (not definition is AugmentDefinition or definition.class_id.is_empty() or definition.class_id == snapshot.base_class_id)

static func _restrictions_valid(origins: Array[StringName], evolutions: Array[StringName]) -> bool:
	var catalog := ProfileCatalog.pilot() if not evolutions.is_empty() else null
	var seen: Dictionary = {}
	for origin: StringName in origins:
		if origin not in [&"swordsman", &"mage", &"archer"] or seen.has(origin):
			return false
		seen[origin] = true
	seen.clear()
	for evolution: StringName in evolutions:
		if catalog.evolution_definition(evolution) == null or seen.has(evolution):
			return false
		seen[evolution] = true
	return true

static func failure(code: StringName, detail: String = "") -> Dictionary:
	return {"ok": false, "error_code": code, "request_id": "", "detail": detail}

static func _key(origin: StringName, id: StringName) -> String:
	return "%s:%s" % [origin, id]

static func _all_projectile_skills(skills: Array[StringName]) -> bool:
	for skill: StringName in skills:
		if skill not in PROJECTILE_SKILLS:
			return false
	return true
