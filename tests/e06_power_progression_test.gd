extends SceneTree
## Authoral invariants: independent point oracles plus the twenty published builds.
const Publication = preload("res://tools/content/publication_bundle.gd")
const IDENTITIES := ["swordsman", "mage", "archer", "defender", "berserker", "elementalist", "spiritualist", "sentinel", "hunter", "mg_ar"]
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	_scalar_oracles()
	var loaded := BuildContentLoader.load_catalog()
	var publication := Publication.compile()
	_check(loaded["ok"] and publication["ok"], "real publication catalogs load")
	if loaded["ok"] and publication["ok"]:
		_composer_boundaries(loaded["catalog"])
		_published_builds(loaded["catalog"], publication["source_catalog"])
	print("E06 power progression: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _effect(channel: StringName, axis: StringName, amount: float) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = &"point_oracle"; effect.channel = channel; effect.axis = axis; effect.magnitude = amount
	return effect
func _scalar_oracles() -> void:
	var definition := EquipmentDefinition.new()
	definition.id = &"point_oracle"; definition.item_level = 1; definition.quality_id = &"common"
	var instance := EquipmentInstance.new()
	instance.instance_id = &"power_oracle"; instance.definition_id = definition.id; instance.origin_id = &"demo_arena"
	instance.item_level = 1; instance.quality_id = &"common"; instance.power_ruleset_id = &"equipment_growth_v1"
	var effect := _effect(&"flat", &"physical_defense", 4.0)
	# Literal oracle values do not call the production curve to produce expectations.
	for row: Array in [[1, 4.0], [5, 4.64], [10, 5.44], [20, 7.04], [30, 8.64]]:
		instance.item_level = row[0]
		_check(is_equal_approx(EquipmentPowerRules.modifier_magnitude(effect, instance, definition), row[1]), "4 DEF oracle ilvl %d" % row[0])
	instance.item_level = 1
	for row: Array in [[&"common", 4.0], [&"uncommon", 4.6], [&"rare", 5.4], [&"epic", 6.6], [&"legendary", 8.0]]:
		instance.quality_id = row[0]
		_check(is_equal_approx(EquipmentPowerRules.modifier_magnitude(effect, instance, definition), row[1]), "quality point oracle %s" % row[0])
	definition.item_level = 5; definition.quality_id = &"rare"
	instance.item_level = 5; instance.quality_id = &"rare"
	_check(is_equal_approx(EquipmentPowerRules.modifier_magnitude(effect, instance, definition), 4.0), "definition ilvl/quality normalization preserves recipe baseline")
	instance.item_level = 30; instance.quality_id = &"legendary"
	_check(is_equal_approx(EquipmentPowerRules.modifier_magnitude(effect, instance, definition), 11.03448275862069), "both definition denominators apply once")
	definition.item_level = 1; definition.quality_id = &"common"
	for axis: StringName in [&"str", &"agi", &"vit", &"int", &"dex", &"luk"]:
		_check(is_equal_approx(EquipmentPowerRules.modifier_magnitude(_effect(&"primary_flat", axis, 4), instance, definition), 17.28), "primary axis grows %s" % axis)
	for axis: StringName in [&"max_hp", &"max_sp", &"hp_regen", &"sp_regen", &"melee_attack", &"precision_attack", &"magic_attack", &"physical_defense", &"magic_defense", &"hit_rating", &"flee_rating", &"move_speed"]:
		_check(is_equal_approx(EquipmentPowerRules.modifier_magnitude(_effect(&"flat", axis, 4), instance, definition), 17.28), "point axis grows %s" % axis)
	for channel: StringName in [&"flat", &"increased"]:
		for axis: StringName in [&"attacks_per_second", &"attack_speed_index", &"crit_chance", &"crit_multiplier", &"crit_resistance", &"variable_cast_multiplier", &"fixed_cast_reduction", &"after_cast_reduction", &"cooldown_reduction", &"physical_cc_resistance", &"magic_cc_resistance", &"damage_dealt_multiplier"]:
			_check(EquipmentPowerRules.modifier_magnitude(_effect(channel, axis, 0.2), instance, definition) == 0.2, "utility/ratio fixed %s/%s" % [channel, axis])
	_check(EquipmentPowerRules.modifier_magnitude(_effect(&"increased", &"max_hp", 0.2), instance, definition) == 0.2, "increased point-stat fraction stays fixed")
	for kind: int in [EffectDefinition.Kind.SKILL_RULE, EffectDefinition.Kind.PROC, EffectDefinition.Kind.ACTIVE_GRANT, EffectDefinition.Kind.KIT_RULE]:
		var utility := _effect(&"flat", &"physical_defense", 4)
		utility.kind = kind
		_check(EquipmentPowerRules.modifier_magnitude(utility, instance, definition) == 4, "non-stat kind stays fixed %d" % kind)
	effect.stack_values = [4.5]
	instance.power_ruleset_id = &"legacy_unscaled"; instance.item_level = 500
	_check(EquipmentPowerRules.validate_instance(instance)["ok"] and EquipmentPowerRules.modifier_magnitude(effect, instance, definition) == 4.5, "legacy high ilvl uses value_at(1) without scaling")
	var copy := instance.copy_instance()
	_check(copy.to_record() == instance.to_record() and copy != instance, "copy preserves recipe and power refs by value")
	instance.power_ruleset_id = &"unknown_power"
	_check(EquipmentPowerRules.validate_instance(instance)["error_code"] == &"invalid_equipment_power", "unknown power rejects")
	instance.power_ruleset_id = &"equipment_growth_v1"; instance.item_level = 31
	_check(EquipmentPowerRules.validate_instance(instance)["error_code"] == &"invalid_equipment_power", "growth ilvl31 rejects")
	instance.item_level = 1; instance.recipe_revision_id = &"unknown_recipe"
	_check(EquipmentPowerRules.validate_instance(instance)["error_code"] == &"invalid_equipment_power", "unknown recipe rejects")
	instance.recipe_revision_id = &"catalog_v1"; instance.item_level = 0
	_check(not EquipmentPowerRules.validate_instance(instance)["ok"], "nonpositive ilvl rejects")
	_check(effect.magnitude == 4 and effect.stack_values == [4.5], "shared effect never mutates")
func _composer_boundaries(catalog: BuildEffectCatalog) -> void:
	var definition := catalog.get_definition(&"equipment", &"arena_warden_mail") as EquipmentDefinition
	if definition == null:
		# Pick a published stat recipe by metadata, independent of optional catalog extensions.
		for id: StringName in catalog.ids(&"equipment"):
			var candidate := catalog.get_definition(&"equipment", id) as EquipmentDefinition
			if candidate.slot == &"torso" and not candidate.effects.is_empty() and &"swordsman" in candidate.metadata()["allowed_base_classes"]:
				definition = candidate; break
	_check(definition != null, "published torso fixture found")
	if definition == null: return
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"swordsman"
	var instance := EquipmentInstance.from_metadata(&"composition_power", definition.id, definition.metadata())["instance"] as EquipmentInstance
	snapshot.equipment_instances[instance.instance_id] = instance; snapshot.equipped[&"torso"] = instance.instance_id
	var before: Variant = _normalize(definition)
	instance.power_ruleset_id = &"equipment_growth_v1"; instance.item_level = 30
	var first := BuildEffectComposer.compose(snapshot, {}, [], catalog)
	_check(first["ok"], "composer accepts valid growth exemplar")
	_check(_normalize(definition) == before, "composition leaves shared catalog resource byte-value equivalent")
	instance.power_ruleset_id = &"unrecognized_power"
	_check(BuildEffectComposer.compose(snapshot, {}, [], catalog)["error_code"] == &"invalid_equipment_power", "composer rejects unknown power before source output")
	instance.power_ruleset_id = &"equipment_growth_v1"; instance.recipe_revision_id = &"unrecognized_recipe"
	_check(BuildEffectComposer.compose(snapshot, {}, [], catalog)["error_code"] == &"invalid_equipment_power", "composer rejects unknown recipe")
func _published_builds(catalog: BuildEffectCatalog, source: BuildEffectCatalog) -> void:
	var completed := 0
	for identity: String in IDENTITIES:
		for branch: int in 2:
			var published := Publication.comparison(identity, branch, catalog, source)
			_check(published["ok"], "published build baseline %s/%d" % [identity, branch])
			if not published["ok"]: continue
			var snapshot: BuildSnapshot = published["snapshot"]
			var before: Dictionary = published["composed"]
			var resources_before := {}
			for instance: EquipmentInstance in snapshot.equipment_instances.values():
				resources_before[instance.definition_id] = _normalize(catalog.get_definition(&"equipment", instance.definition_id))
				instance.power_ruleset_id = &"equipment_growth_v1"
			# Nominal exemplar metadata must reproduce the published recipe exactly.
			var nominal := BuildEffectComposer.compose(snapshot, published["run_effects"], [], catalog)
			_check(nominal["ok"] and _normalize(nominal) == _normalize(before), "growth nominal baseline remains exact")
			for instance: EquipmentInstance in snapshot.equipment_instances.values(): instance.item_level = 30
			var grown := BuildEffectComposer.compose(snapshot, published["run_effects"], [], catalog)
			_check(grown["ok"], "published growth composition %s/%d" % [identity, branch])
			if not grown["ok"]: continue
			completed += 1
			for field: String in ["skill_ranks", "skill_rules", "kit_policies", "procs", "item_grants", "unique_effects", "inactive", "conflicts"]:
				_check(_normalize(before[field]) == _normalize(grown[field]), "growth preserves utility and causal parts %s" % field)
			for stat: StringName in before["breakdown"].derived:
				for bound: String in ["minimum", "maximum"]:
					_check(before["breakdown"].derived[stat][bound] == grown["breakdown"].derived[stat][bound], "canonical stat caps unchanged %s/%s" % [stat, bound])
			var increased := false
			_check(before["provenance"].size() == grown["provenance"].size(), "same provenance count")
			for index: int in before["provenance"].size():
				var old_row: Dictionary = before["provenance"][index]
				var new_row: Dictionary = grown["provenance"][index].duplicate(true)
				var scalable := false
				if old_row["origin"] == &"equipment":
					var definition := catalog.get_definition(&"equipment", old_row["definition_id"]) as EquipmentDefinition
					for effect: EffectDefinition in definition.effects:
						if effect.id == old_row["effect_id"]: scalable = EquipmentPowerRules.scales(effect)
				if scalable and float(old_row["magnitude"]) > 0:
					_check(is_equal_approx(float(new_row["magnitude"]), float(old_row["magnitude"]) * 2.16), "positive equipment points match ilvl30 literal factor")
					increased = true
				else:
					_check(new_row["magnitude"] == old_row["magnitude"], "non-growing source magnitude fixed")
				new_row["magnitude"] = old_row["magnitude"]
				_check(new_row == old_row, "source identities/families/targets stay exact")
			_check(increased and grown["breakdown"].values() != before["breakdown"].values(), "published point-stat build actually grows")
			for skill: StringName in before["skill_ranks"]:
				var rank: int = before["skill_ranks"][skill]
				var old_capture := SkillEffectResolver.capture(skill, rank, before)
				var new_capture := SkillEffectResolver.capture(skill, rank, grown)
				_check(old_capture["ok"] and new_capture["ok"] and _normalize(old_capture) == _normalize(new_capture), "skill captures keep ranks/caps/policies/procs %s" % skill)
			for id: StringName in resources_before:
				_check(_normalize(catalog.get_definition(&"equipment", id)) == resources_before[id], "shared recipe unchanged after build")
	_check(completed == 20, "all twenty A/B published builds covered")
func _normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[String(key)] = _normalize(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(_normalize(entry))
		return result
	if value is Resource or value is StatBreakdown:
		var result := {}
		for property: Dictionary in value.get_property_list():
			var name: String = property["name"]
			if int(property["usage"]) & PROPERTY_USAGE_STORAGE and name not in ["script", "resource_name", "resource_local_to_scene", "resource_path"]: result[name] = _normalize(value.get(name))
		if value is StatBreakdown: result = {"values": value.values(), "sources": value.modifier_sources}
		return result
	if value is StringName: return String(value)
	return value