class_name BuildEffectCatalog
extends RefCounted
## One copied registry for all three content origins. No production items in T1.

const ORIGINS: Array[StringName] = [&"augment", &"equipment", &"card"]
const SLOTS: Array[StringName] = [&"head", &"neck", &"shoulders", &"arms", &"torso", &"cloak", &"legs", &"feet", &"main_hand", &"off_hand", &"accessory_1", &"accessory_2", &"accessory_3", &"accessory_4"]
const KIT_POLICIES := {
	&"drain_inscription": {"origin": &"mage", "evolution": &"spiritualist", "skills": [&"spiritualist_soul_drain", &"spiritualist_echo_curse"], "required": [&"spiritualist_soul_drain", &"spiritualist_echo_curse"]},
	&"hunter_marked_mechanism": {"origin": &"archer", "evolution": &"hunter", "skills": [&"hunter_freezing_trap", &"hunter_tar_trap", &"hunter_thorn_trap"], "required": [&"hunter_mark"]},
	&"hunter_covering_fan": {"origin": &"archer", "evolution": &"hunter", "skills": [&"hunter_covering_shot"]},
	&"geometer_collapse_first_element": {"origin": &"mage", "evolution": &"mg_ar", "skills": [&"geometer_collapse"], "required": [&"geometer_triangulation"]},
	&"echo_origin_fixed": {"evolution": &"spiritualist", "skills": [&"spiritualist_echo_curse"]},
	&"geometer_ground_anchor": {"evolution": &"mg_ar", "skills": [&"geometer_trace", &"geometer_triangulation"]},
}
const SCALAR_AXES: Array[StringName] = [&"range"]
const INTRINSIC_FAMILIES: Array[StringName] = [&"elementalist_tri_nova_ice", &"elementalist_tri_nova_lightning", &"hunter_exploit", &"sentinel_focus", &"berserker_wound", &"berserker_pursuit", &"berserker_breath_heal", &"elementalist_focus", &"spiritualist_echo", &"spiritualist_echo_recovery", &"spiritualist_channel_focus", &"spiritualist_drain_heal", &"blood_thirst", &"defender_watch", &"defender_token", &"defender_guard_return"]
const INTRINSIC_COMPONENTS: Array[StringName] = [&"basic_attack", &"burn_tick", &"bleed_tick", &"hunter_thorn_bleed", &"berserker_blood_rift_tick", &"berserker_rupture_detonation", &"geometer_wall_entry", &"geometer_wall_exit", &"geometer_foundation_fire", &"geometer_foundation_lightning", &"geometer_rule_fire", &"geometer_rule_lightning", &"geometer_resolution_fire", &"geometer_resolution_ice", &"geometer_resolution_lightning", &"geometer_triangle_maintenance", &"geometer_incidence"]
const PROJECTILE_SKILLS: Array[StringName] = [&"fire_spear", &"ice_spear", &"double_shot"]
var _definitions: Dictionary = {}
var _mob_catalog := MobCatalog.new()
var _sets: Dictionary = {}

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
	result._mob_catalog = _mob_catalog.copy_catalog()
	for id: StringName in _sets:
		result._sets[id] = _sets[id].duplicate(true)
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
	if definition is EquipmentDefinition:
		var equipment_check := EquipmentRules.validate_definition(definition.metadata())
		if not equipment_check["ok"]:
			return equipment_check
	if definition is EquipmentDefinition and not definition.set_id.is_empty():
		var set_check := validate_equipment_quality(definition, definition.quality_id)
		if not set_check["ok"]:
			return set_check
	if definition is CardDefinition:
		if not definition.effects.is_empty() and _mob_catalog.get_definition(definition.mob_base_id) == null:
			return failure(&"missing_mob_base")
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
		var capability_check := validate_recipe(origin, definition, effect)
		if not capability_check["ok"]:
			return capability_check
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
	if effect == null or effect.id.is_empty() or effect.family_id.is_empty() or effect.unit not in [&"ratio", &"points", &"count", &"units", &"seconds", &"sp", &"damage", &"policy"] or effect.minimum_rank < 1 or effect.minimum_rank > 5:
		return failure(&"invalid_effect")
	if (effect.unit == &"policy") != (effect.kind == EffectDefinition.Kind.KIT_RULE): return failure(&"invalid_policy_unit")
	if not EffectTags.valid(effect.tags):
		return failure(&"unknown_effect_tag")
	if not effect.unique_effect_id.is_empty() and not IdentityIds.is_technical_id(String(effect.unique_effect_id)):
		return failure(&"invalid_unique_effect")
	if effect.kind != EffectDefinition.Kind.ACTIVE_GRANT and not effect.granted_skill_id.is_empty():
		return failure(&"invalid_item_active")
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
		if effect.family_id in INTRINSIC_FAMILIES or effect.family_id in INTRINSIC_COMPONENTS or effect.family_id == &"geometer_incidence_refund" or ClassCatalog.skill_definition(effect.family_id) != null:
			return failure(&"intrinsic_family_requires_adapter")
		if effect.handler_id != EffectDefinition.Handler.HIT_DAMAGE or effect.trigger != EffectDefinition.Trigger.ON_HIT or effect.axis not in [&"physical_damage", &"magic_damage"] or effect.magnitude < 0.0 or effect.increased < 0.0 or effect.limit <= 0.0 or effect.unit != &"damage":
			return failure(&"unsupported_proc")
	elif effect.kind == EffectDefinition.Kind.KIT_RULE:
		var policy: Dictionary = KIT_POLICIES.get(effect.axis, {})
		if policy.is_empty() or effect.handler_id != EffectDefinition.Handler.KIT_POLICY or effect.trigger != EffectDefinition.Trigger.NONE or effect.unit != &"policy" or effect.magnitude != 0 or effect.increased != 0 or effect.limit != 0 or not effect.stack_values.is_empty() or effect.channel != &"flat" or effect.minimum_rank != 1:
			return failure(&"invalid_kit_policy")
		if effect.target_skill_ids != policy["skills"] or effect.allowed_origins != [policy.get("origin", &"mage")] or effect.allowed_evolutions != [policy["evolution"]] or effect.stacking_mode != EffectDefinition.Stacking.EXCLUSIVE or effect.conflict_group != effect.axis:
			return failure(&"invalid_kit_policy_restrictions")
	elif effect.kind == EffectDefinition.Kind.ACTIVE_GRANT:
		if effect.handler_id != EffectDefinition.Handler.ACTIVE_SKILL or effect.trigger != EffectDefinition.Trigger.NONE or not effect.target_skill_ids.is_empty() or effect.magnitude != 0.0 or effect.increased != 0.0 or effect.limit != 0.0 or not effect.stack_values.is_empty():
			return failure(&"invalid_item_active")
		if effect.granted_rank < 1 or effect.granted_rank > 5:
			return failure(&"invalid_item_rank")
		if effect.allowed_origins.is_empty():
			return failure(&"invalid_item_compatibility")
		for origin: StringName in effect.allowed_origins:
			if not ItemSkillAdapters.supports(effect.granted_skill_id, origin):
				return failure(&"unsupported_item_active")
	else:
		return failure(&"unsupported_handler")
	return {"ok": true, "error_code": &"", "request_id": ""}

static func definition_allowed(definition: Resource, snapshot: BuildSnapshot) -> bool:
	return (not definition is EquipmentDefinition or EquipmentEligibilityRules.identity_allowed(definition.metadata(),snapshot.base_class_id,snapshot.evolution_id)) and (definition.allowed_origins.is_empty() or snapshot.base_class_id in definition.allowed_origins) and (definition.allowed_evolutions.is_empty() or snapshot.evolution_id in definition.allowed_evolutions) and (not definition is AugmentDefinition or definition.class_id.is_empty() or definition.class_id == snapshot.base_class_id)

static func _restrictions_valid(origins: Array[StringName], evolutions: Array[StringName]) -> bool:
	# IdentityIds owns the closed evolution IDs; avoid loading equipment recipes
	# for every restriction check. Availability remains a separate composer gate.
	var seen: Dictionary = {}
	for origin: StringName in origins:
		if origin not in [&"swordsman", &"mage", &"archer"] or seen.has(origin):
			return false
		seen[origin] = true
	seen.clear()
	for evolution: StringName in evolutions:
		if not IdentityIds.is_evolution(evolution) or seen.has(evolution):
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

func set_mob_catalog(catalog: MobCatalog) -> Dictionary:
	if catalog == null or not ids(&"card").is_empty():
		return failure(&"catalog_frozen")
	_mob_catalog = catalog.copy_catalog()
	return {"ok": true}

func mob_catalog() -> MobCatalog:
	return _mob_catalog.copy_catalog()

func register_set(definition: EquipmentSetDefinition) -> Dictionary:
	if definition != null and not EquipmentEligibilityRules.validate(EquipmentEligibilityRules.for_resource(definition))["ok"]: return failure(&"invalid_set")
	if definition == null or not IdentityIds.is_technical_id(String(definition.id)) or _sets.has(definition.id) or definition.thresholds.is_empty():
		return failure(&"invalid_set")
	for threshold: Variant in definition.thresholds:
		if typeof(threshold) != TYPE_INT or threshold < 1 or threshold > EquipmentRules.ARMOR_SLOTS.size() or not definition.thresholds[threshold] is Array or definition.thresholds[threshold].is_empty():
			return failure(&"invalid_set")
		var seen: Dictionary = {}
		for raw: Variant in definition.thresholds[threshold]:
			if not raw is EffectDefinition:
				return failure(&"invalid_set")
			var effect: EffectDefinition = raw
			var checked := validate_effect(effect)
			if not checked["ok"]:
				return checked
			if effect.kind in [EffectDefinition.Kind.ACTIVE_GRANT, EffectDefinition.Kind.KIT_RULE] or seen.has(effect.id) or not effect.stack_values.is_empty():
				return failure(&"invalid_set")
			seen[effect.id] = true
	_sets[definition.id] = definition.duplicate(true)
	return {"ok": true}

func get_set(id: StringName) -> EquipmentSetDefinition:
	var definition: EquipmentSetDefinition = _sets.get(id)
	return definition.duplicate(true) as EquipmentSetDefinition if definition != null else null

func validate_recipe(origin: StringName, definition: Resource, effect: EffectDefinition) -> Dictionary:
	if effect.kind == EffectDefinition.Kind.KIT_RULE:
		if origin != &"augment" or not definition is AugmentDefinition or definition.max_stacks != 1 or definition.allowed_origins != effect.allowed_origins or definition.allowed_evolutions != effect.allowed_evolutions:
			return failure(&"capability_not_allowed")
	if origin == &"card":
		var mob := _mob_catalog.get_definition(definition.mob_base_id)
		if effect.capability() == &"active_grant" or (mob != null and mob.base_category not in MobCatalog.COMPLEX_BASES and effect.capability() not in [&"stat", &"skill_buff"]):
			return failure(&"capability_not_allowed")
	if origin == &"equipment":
		if effect.capability() != &"stat" and definition.quality_id not in [&"rare", &"epic", &"legendary"]:
			return failure(&"capability_not_allowed")
		if effect.capability() == &"active_grant" and definition.item_kind != &"jewelry":
			return failure(&"capability_not_allowed")
	return {"ok": true}

func validate_equipment_quality(definition: EquipmentDefinition, quality: StringName) -> Dictionary:
	if quality not in EquipmentRules.QUALITY_IDS:
		return failure(&"invalid_equipment_instance")
	if not definition.set_id.is_empty():
		if definition.item_kind != &"armor" or get_set(definition.set_id) == null or quality not in [&"rare", &"epic", &"legendary"]:
			return failure(&"invalid_set")
	for effect: EffectDefinition in definition.effects:
		if effect.capability() != &"stat" and quality not in [&"rare", &"epic", &"legendary"]:
			return failure(&"capability_not_allowed")
	return {"ok": true}
