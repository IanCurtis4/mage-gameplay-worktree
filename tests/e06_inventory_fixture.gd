extends RefCounted
const TX = preload("res://tests/e06_tx_fixture.gd")

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
		if hide_reads:
			return {"ok": false, "error_code": &"result_uncertain", "read_only": true}
		return super.load_profile()

static func stat(id: StringName, axis: StringName, amount: float) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = id
	effect.family_id = id
	effect.axis = axis
	effect.channel = &"flat"
	effect.unit = &"points"
	effect.magnitude = amount
	return effect

static func catalog() -> BuildEffectCatalog:
	var source := BuildContentLoader.pilot()
	var result := BuildEffectCatalog.new()
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for id: StringName in source.ids(origin):
			var definition := source.get_definition(origin, id)
			if id == &"warden_mail":
				definition.effects.assign([stat(&"fixture_hp", &"max_hp", 100.0)])
			elif id == &"channeler_robe":
				definition.effects.assign([stat(&"fixture_sp", &"max_sp", 100.0)])
			elif id == &"trailcoat":
				definition.effects.assign([stat(&"fixture_hp_small", &"max_hp", -20.0)])
			elif id == &"bulwark_card":
				definition.effects.assign([stat(&"fixture_card_hp", &"max_hp", 30.0)])
			elif id == &"trail_card":
				definition.effects.assign([stat(&"fixture_card_sp", &"max_sp", 30.0)])
			elif id in [&"echo_card", &"ember_card", &"ember_staff"]:
				var effect := stat(&"fixture_count", &"projectile_count", 1.0)
				effect.kind = EffectDefinition.Kind.SKILL_RULE
				effect.handler_id = EffectDefinition.Handler.PROJECTILE_COUNT
				effect.target_skill_ids = [&"fire_spear"]
				effect.unit = &"count"
				effect.limit = 16.0
				effect.stacking_mode = EffectDefinition.Stacking.EXCLUSIVE
				effect.conflict_group = &"fixture_exclusive"
				definition.effects.assign([effect])
			assert(result.register_definition(origin, definition)["ok"])
	return result

static func make(tree: SceneTree, label: String, origin: StringName = &"mage", own_all: bool = true) -> Dictionary:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_t2/fixtures/%s_%d" % [label, Time.get_ticks_usec()])
	var store := FaultStore.new(directory)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("fixture-create", 0, "Teste", origin)
	assert(created["ok"])
	var profile: ProfileState = facade.current_profile()
	var character := profile.characters[0]
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	if origin == &"mage":
		character.purchased_skill_ranks = {&"fire_spear": 1, &"ice_spear": 1}
		character.action_slots[0] = &"fire_spear"
	for id: StringName in BuildContentLoader.pilot().ids(&"equipment"):
		if own_all and profile.first_instance_for_definition(id).is_empty():
			TX.own(profile, id)
	var alt := CharacterState.new(IdentityIds.character_id(profile.profile_id, 2), "Outro", &"archer")
	profile.characters.append(alt)
	profile.next_character_counter = 3
	assert(store.commit(profile)["ok"])
	facade = ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	assert(facade.open_profile()["ok"])
	var started := facade.start_run("fixture-start", facade.current_profile().revision)
	assert(started["ok"])
	var state: RunState = started["run_state"]
	assert(state.set_effect_catalog(catalog())["ok"])
	RunController.pending_run_state = state
	RunController.pending_run_facade = facade
	var controller := RunController.new()
	tree.root.add_child(controller)
	controller.rng.seed = 260609
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	controller.encounter_active = false
	return {"controller": controller, "facade": facade, "store": store, "directory": directory}

static func intent(controller: RunController, kind: StringName, values: Dictionary = {}) -> Dictionary:
	var result := controller.build_service.context()
	var mapped := values.duplicate(true)
	var profile := controller.persistent_facade.current_profile() if controller.persistent_facade != null else ProfileState.new()
	if controller.persistent_facade == null:
		for id: StringName in controller.run_state.local_equipment_instances:
			profile.equipment_instances[id] = controller.run_state.local_equipment_instances[id].copy_instance()
	for pair: Array in [["item_id", "equipment_instance_id"], ["from_item_id", "from_equipment_instance_id"]]:
		if mapped.has(pair[0]):
			mapped[pair[1]] = profile.first_instance_for_definition(StringName(mapped[pair[0]])) if typeof(mapped[pair[0]]) in [TYPE_STRING, TYPE_STRING_NAME] else mapped[pair[0]]
			mapped.erase(pair[0])
	if mapped.has("card_id") and typeof(mapped["card_id"]) in [TYPE_STRING, TYPE_STRING_NAME]:
		for id: StringName in controller.run_state.card_inventory.describe()["owned"]:
			if controller.run_state.card_inventory.definition_id(id) == StringName(mapped["card_id"]):
				mapped["card_instance_id"] = id
				break
		mapped.erase("card_id")
	if kind in [&"socket", &"unsocket", &"transfer"]:
		mapped["socket_index"] = 0
	if kind == &"transfer": mapped["from_socket_index"] = 0
	if mapped.has("slot") and typeof(mapped["slot"]) in [TYPE_STRING, TYPE_STRING_NAME]:
		mapped["slot"] = EquipmentRules.legacy_position(StringName(mapped["slot"]))
	result.merge(mapped, true)
	result["kind"] = kind
	result["request_id"] = "fixture-%d" % Time.get_ticks_usec()
	return result

static func change(controller: RunController, kind: StringName, values: Dictionary = {}) -> Dictionary:
	var preview := controller.build_service.preview_change(intent(controller, kind, values))
	return controller.build_service.commit_change(preview["intent"]) if preview["ok"] else preview

static func disk(fixture: Dictionary) -> String:
	return FileAccess.get_file_as_string(String(fixture["directory"]).path_join(ProfileStore.PRIMARY_FILE))

static func selected(controller: RunController, slot: StringName) -> Variant:
	var id: Variant = controller.run_state.build_snapshot.equipped[slot]
	return null if id == null else controller.run_state.build_snapshot.equipment_instances[id].definition_id

static func equipment(controller: RunController, definition: StringName) -> StringName:
	return controller.persistent_facade.current_profile().first_instance_for_definition(definition)

static func card(controller: RunController, definition: StringName) -> StringName:
	for id: StringName in controller.run_state.card_inventory.describe()["owned"]:
		if controller.run_state.card_inventory.definition_id(id) == definition: return id
	return &""
