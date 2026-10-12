extends SceneTree
const F = preload("res://tests/e06_effects_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _mob_registry(category: StringName) -> BuildEffectCatalog:
	var mobs := MobCatalog.new()
	var mob := MobDefinition.new()
	mob.id = &"matrix_mob"
	mob.base_category = category
	mob.allowed_occurrence_categories = [category]
	for axis: StringName in StatCalculator.PRIMARY_IDS:
		mob.primary_attributes[axis] = 3
	assert(mobs.register_definition(mob)["ok"])
	var result := BuildEffectCatalog.new()
	result.set_mob_catalog(mobs)
	return result
func _stat() -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = &"hp"
	effect.family_id = &"hp"
	effect.axis = &"max_hp"
	effect.unit = &"points"
	effect.magnitude = 10.0
	return effect
func _grant() -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = &"grant"
	effect.family_id = &"grant"
	effect.kind = EffectDefinition.Kind.ACTIVE_GRANT
	effect.handler_id = EffectDefinition.Handler.ACTIVE_SKILL
	effect.granted_skill_id = &"fire_spear"
	effect.granted_rank = 3
	effect.allowed_origins = [&"swordsman", &"mage", &"archer"]
	effect.unit = &"points"
	return effect
func _item(id: StringName, slot: StringName, effects: Array[EffectDefinition]) -> EquipmentDefinition:
	var item := F.definition(&"equipment", id, effects) as EquipmentDefinition
	item.slot = slot
	item.item_kind = EquipmentRules.default_kind(slot)
	item.hand_usage = &"one_hand" if slot == &"main_hand" else &"none"
	item.socket_capacity = 0 if item.item_kind == &"jewelry" else 4
	return item
func _equip(snapshot: BuildSnapshot, item: EquipmentDefinition, id: StringName) -> void:
	var instance: EquipmentInstance = EquipmentInstance.from_metadata(id, item.id, item.metadata())["instance"]
	snapshot.equipment_instances[id] = instance
	snapshot.equipped[&"accessory_1" if item.slot == &"accessory" else item.slot] = id
func _run() -> void:
	var recipes: Array[EffectDefinition] = [_stat(), F.range_effect(), F.count_effect(), F.proc_effect(), _grant()]
	for quality: StringName in EquipmentRules.QUALITY_IDS:
		for effect: EffectDefinition in recipes:
			var registry := F.registry()
			var item := _item(&"matrix", &"accessory" if effect.capability() == &"active_grant" else &"torso", [effect])
			item.quality_id = quality
			var expected := quality in [&"rare", &"epic", &"legendary"] or effect.capability() == &"stat"
			_check(registry.register_definition(&"equipment", item)["ok"] == expected, "quality/handler matrix %s/%s" % [quality, effect.capability()])
	for category: StringName in MobCatalog.CATEGORIES:
		for effect: EffectDefinition in recipes:
			var registry := _mob_registry(category)
			var card := F.definition(&"card", &"matrix", [effect]) as CardDefinition
			card.mob_base_id = &"matrix_mob"
			var expected := effect.capability() != &"active_grant" and (category in MobCatalog.COMPLEX_BASES or effect.capability() in [&"stat", &"skill_buff"])
			_check(registry.register_definition(&"card", card)["ok"] == expected, "base/handler matrix %s/%s" % [category, effect.capability()])
	var tag := _stat()
	tag.tags = [&"flaming", &"renewing"]
	var plain := _stat()
	var snapshot := F.snapshot()
	var tagged_result := BuildEffectComposer.compose(snapshot, {"augment_stacks": {&"fixture": 1}}, [], F.catalog_for(&"augment", [tag]))
	var plain_result := BuildEffectComposer.compose(snapshot, {"augment_stacks": {&"fixture": 1}}, [], F.catalog_for(&"augment", [plain]))
	_check(tagged_result["breakdown"].values() == plain_result["breakdown"].values(), "multiple descriptive tags have no implicit bonus")
	tag.tags.append(&"unregistered")
	_check(BuildEffectCatalog.validate_effect(tag)["error_code"] == &"unknown_effect_tag", "unknown tag rejected")
	var registry := F.registry()
	var named := _stat()
	named.unique_effect_id = &"shared_power"
	var head := _item(&"head", &"head", [named])
	var torso := _item(&"torso", &"torso", [named])
	registry.register_definition(&"equipment", head)
	registry.register_definition(&"equipment", torso)
	_equip(snapshot, head, &"head_copy")
	_equip(snapshot, torso, &"torso_copy")
	_check(BuildEffectComposer.compose(snapshot, {}, [], registry)["error_code"] == &"duplicate_unique_effect", "different definitions with same named effect reject whole build")
	var downgraded := snapshot.copy_snapshot()
	downgraded.equipment_instances[&"head_copy"].quality_id = &"uncommon"
	head.effects = [F.proc_effect()]
	var rarity_registry := F.registry()
	rarity_registry.register_definition(&"equipment", head)
	downgraded.equipped[&"torso"] = null
	_check(BuildEffectComposer.compose(downgraded, {}, [], rarity_registry)["error_code"] == &"capability_not_allowed", "acquired quality controls actual recipe eligibility")
	snapshot = F.snapshot()
	registry = F.registry()
	var set_recipe := EquipmentSetDefinition.new()
	set_recipe.id = &"fixture_set"
	set_recipe.display_name = "Conjunto de teste"
	set_recipe.thresholds = {2: [_stat()], 3: [F.proc_effect()]}
	_check(registry.register_set(set_recipe)["ok"], "set registered independently of pieces")
	for slot: StringName in [&"head", &"torso", &"legs"]:
		var piece := _item(slot, slot, [])
		piece.set_id = set_recipe.id
		registry.register_definition(&"equipment", piece)
		_equip(snapshot, piece, StringName("copy_" + String(slot)))
	var result := BuildEffectComposer.compose(snapshot, {}, [], registry)
	_check(result["ok"] and result["stat_sources"].size() == 1 and result["procs"].size() == 1 and result["provenance"].size() == 2, "three pieces activate each threshold exactly once")
	snapshot.equipped[&"legs"] = null
	result = BuildEffectComposer.compose(snapshot, {}, [], registry)
	_check(result["ok"] and result["procs"].is_empty() and result["stat_sources"].size() == 1, "set threshold removed on unequip")
	registry = F.registry()
	snapshot = F.snapshot()
	var host := _item(&"host", &"torso", [])
	registry.register_definition(&"equipment", host)
	_equip(snapshot, host, &"host_copy")
	var card := F.definition(&"card", &"repeat", [F.count_effect()]) as CardDefinition
	registry.register_definition(&"card", card)
	var cards := {"card_instances": {&"a": &"repeat", &"b": &"repeat", &"c": &"repeat"}, "card_sockets": {&"host_copy": [&"a", &"b", &"c", null]}}
	result = BuildEffectComposer.compose(snapshot, cards, [], registry)
	_check(result["ok"] and SkillEffectResolver.capture(&"fire_spear", 1, result)["values"]["projectile_count"] == 4 and result["provenance"].size() == 3, "same card definition sums per physical instance")
	var bad_grant := _grant()
	bad_grant.granted_skill_id = &"sentinel_headshot"
	_check(BuildEffectCatalog.validate_effect(bad_grant)["error_code"] == &"unsupported_item_active", "kit with no concrete item adapter rejected")
	var grant_item := _item(&"active_weapon", &"main_hand", [_grant()])
	_check(F.registry().register_definition(&"equipment", grant_item)["error_code"] == &"capability_not_allowed", "weapon cannot grant player button")
	print("E06 TX2 composition: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
