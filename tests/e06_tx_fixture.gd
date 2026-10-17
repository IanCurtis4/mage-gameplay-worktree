extends RefCounted
const TXEffects = preload("res://tests/e06_effects_fixture.gd")
const HISTORICAL_EQUIPMENT_IDS: Array[StringName] = [&"starter_blade", &"starter_staff", &"starter_bow", &"traveler_vest", &"traveler_charm", &"riposte_blade", &"ember_staff", &"hunters_bow", &"warden_mail", &"channeler_robe", &"trailcoat", &"prismatic_charm"]

# Closed historical fixture; publication must not change its recipes or pools.
static func neutral_effect_catalog(profile_catalog: ProfileCatalog = null) -> BuildEffectCatalog:
	var source: BuildEffectCatalog = BuildContentLoader.pilot() if profile_catalog == null else BuildContentLoader.load_catalog_for_profile(profile_catalog)["catalog"] as BuildEffectCatalog
	var result := TXEffects.registry()
	var legacy := BuildEffectCatalog.pilot()
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for id: StringName in source.ids(origin):
			if origin == &"equipment" and id not in HISTORICAL_EQUIPMENT_IDS and id not in [&"fixture_wand", &"fixture_shield", &"fixture_focus"]: continue
			if origin == &"augment" and id not in legacy.ids(&"augment"): continue
			var definition := source.get_definition(origin, id)
			if definition is CardDefinition:
				definition.effects.clear()
				definition.allowed_origins.clear()
				definition.mob_base_id = &"fixture_elite"
			assert(result.register_definition(origin, definition)["ok"])
	return result

class FaultStore:
	extends ProfileStore
	var failure_stage: StringName = &""
	var uncertain := false
	var uncertain_before_write := false
	var hide_reads := false
	var callback: Callable
	func _should_fail(stage: StringName) -> bool:
		return stage == failure_stage and not failure_stage.is_empty()
	func commit(source: ProfileState) -> Dictionary:
		if uncertain_before_write:
			uncertain_before_write = false
			hide_reads = true
			return {"ok": false, "error_code": &"save_failed"}
		if callback.is_valid():
			var captured := callback
			callback = Callable()
			captured.call()
		var result := super.commit(source)
		if uncertain and result["ok"]:
			uncertain = false
			hide_reads = true
			return {"ok": false, "error_code": &"save_failed"}
		return result
	func load_profile() -> Dictionary:
		if hide_reads: return {"ok": false, "error_code": &"result_uncertain", "read_only": true}
		return super.load_profile()

static func profile_catalog() -> ProfileCatalog:
	var metadata: Dictionary = {}
	for resource: Resource in BuildContentLoader.definitions(&"equipment"):
		var item := resource as EquipmentDefinition
		if item.id not in HISTORICAL_EQUIPMENT_IDS: continue
		metadata[item.id] = item.metadata()
	metadata[&"warden_mail"]["socket_capacity"] = 4
	for row: Array in [[&"fixture_wand", &"main_hand", &"weapon", &"one_hand", 1], [&"fixture_shield", &"off_hand", &"shield", &"none", 4], [&"fixture_focus", &"off_hand", &"focus", &"none", 0]]:
		metadata[row[0]] = {"slot": row[1], "item_kind": row[2], "hand_usage": row[3], "socket_capacity": row[4], "origin_id": &"fixture_origin", "quality_id": &"rare", "item_level": 7, "allowed_base_classes": [&"mage"], "allowed_evolutions": [], "starter": false}
	return ProfileCatalog.pilot(metadata)

static func make(tree: SceneTree, label: String) -> Dictionary:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_tx/fixtures/%s_%d" % [label, Time.get_ticks_usec()])
	var catalog := profile_catalog()
	var store := FaultStore.new(directory, catalog)
	var facade := ProfileFacade.new(store)
	var created := facade.create_character("create", 0, "Teste", &"mage")
	assert(created["ok"], str(created))
	var profile := facade.current_profile()
	for id: StringName in catalog.equipment_ids():
		if profile.first_instance_for_definition(id).is_empty():
			assert(profile.add_equipment_instance(id, catalog.equipment_metadata(id))["ok"])
	assert(profile.add_equipment_instance(&"traveler_charm", catalog.equipment_metadata(&"traveler_charm"))["ok"])
	assert(store.commit(profile)["ok"])
	facade = ProfileFacade.new(store)
	assert(facade.open_profile()["ok"])
	var started := facade.start_run("start", facade.current_profile().revision)
	assert(started["ok"], str(started))
	var state: RunState = started["run_state"]
	var effects := neutral_effect_catalog(catalog)
	var registry := TXEffects.registry()
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for id: StringName in effects.ids(origin):
			var definition := effects.get_definition(origin, id)
			if id == &"bulwark_card":
				var effect := EffectDefinition.new()
				effect.id = &"fixture_card_hp"
				effect.family_id = &"fixture_card_hp"
				effect.axis = &"max_hp"
				effect.magnitude = 30.0
				effect.unit = &"points"
				definition.effects.assign([effect])
			if definition is CardDefinition:
				definition.mob_base_id = &"fixture_elite"
			assert(registry.register_definition(origin, definition)["ok"])
	assert(state.set_effect_catalog(registry)["ok"])
	RunController.pending_run_state = state
	RunController.pending_run_facade = facade
	var controller := RunController.new()
	tree.root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	controller.encounter_active = false
	return {"controller": controller, "facade": facade, "store": store, "directory": directory, "catalog": catalog}

static func item(fixture: Dictionary, definition: StringName) -> StringName:
	return (fixture["facade"] as ProfileFacade).current_profile().first_instance_for_definition(definition)

static func change(fixture: Dictionary, kind: StringName, values: Dictionary) -> Dictionary:
	var controller: RunController = fixture["controller"]
	var intent := controller.build_service.context()
	intent.merge(values, true)
	intent["kind"] = kind
	intent["request_id"] = "tx-%d" % Time.get_ticks_usec()
	var preview := controller.build_service.preview_change(intent)
	return controller.build_service.commit_change(preview["intent"]) if preview["ok"] else preview

static func disk(fixture: Dictionary) -> String:
	return FileAccess.get_file_as_string(String(fixture["directory"]).path_join(ProfileStore.PRIMARY_FILE))

# Historical fixtures project through the published record format, not runtime formulas.
static func own(profile: ProfileState, definition: StringName, catalog: ProfileCatalog = null) -> StringName:
	var id := profile.first_instance_for_definition(definition)
	if not id.is_empty():
		return id
	var source := catalog if catalog != null else ProfileCatalog.pilot()
	var added := profile.add_equipment_instance(definition, source.equipment_metadata(definition))
	assert(added["ok"], str(added))
	return added["instance_id"]

static func definition_ids(profile: ProfileState) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in profile.equipment_instance_ids():
		var definition := profile.equipment_instances[id].definition_id
		if definition not in result:
			result.append(definition)
	return result

static func definition(profile: ProfileState, id: Variant) -> Variant:
	return null if id == null else profile.equipment_instances[StringName(id)].definition_id

static func legacy_data(current: Dictionary) -> Dictionary:
	if not current.has("equipment_instances"):
		return current.duplicate(true)
	var result := current.duplicate(true)
	result.erase("card_inventory")
	var lookup: Dictionary = {}
	for record: Dictionary in current["equipment_instances"]:
		lookup[record["instance_id"]] = record["definition_id"]
	result["equipment_collection"] = lookup.values()
	var seen: Dictionary = {}
	for id: Variant in result["equipment_collection"]:
		assert(not seen.has(id), "Historical fixture must not discard acquisitions")
		seen[id] = true
	result["schema_version"] = 2
	for fixture_character: Dictionary in result["characters"]: fixture_character.erase("admin_skills_unlocked")
	result.erase("equipment_instances")
	result.erase("next_equipment_counter")
	for character: Dictionary in result["characters"]:
		var layouts: Array = [character]
		layouts.append_array(character["presets"])
		for layout: Dictionary in layouts:
			var slots: Dictionary = layout["equipped"]
			var old := {}
			for row: Array in [["weapon", "main_hand"], ["armor", "torso"], ["accessory", "accessory_1"]]:
				var value: Variant = slots.get(row[1])
				old[row[0]] = null if value == null else lookup.get(value, value)
			layout["equipped"] = old
	return result

static func legacy_expected(profile: ProfileState, definitions: Dictionary) -> Dictionary[StringName, Variant]:
	var result := EquipmentRules.empty_layout()
	for slot: Variant in definitions:
		var id: Variant = definitions[slot]
		result[EquipmentRules.legacy_position(StringName(slot))] = null if id == null else profile.first_instance_for_definition(StringName(id))
	return result
