extends RefCounted

class FaultStore:
	extends ProfileStore
	var fail_stage: StringName = &""
	var lose_ack := false
	var hide_reads := false
	var hide_after_ack := false
	func _should_fail(stage: StringName) -> bool:
		return stage == fail_stage and not fail_stage.is_empty()
	func _write_transaction(text: String, candidate: ProfileState, archive: bool) -> Dictionary:
		var result := super._write_transaction(text, candidate, archive)
		if result["ok"] and lose_ack:
			lose_ack = false
			if hide_after_ack: hide_reads = true
			return {"ok": false, "error_code": &"save_failed"}
		return result
	func load_profile() -> Dictionary:
		if hide_reads: return {"ok": false, "error_code": &"result_uncertain", "read_only": true}
		return super.load_profile()

static func make(label: String) -> Dictionary:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e07_f2/fixtures/%s_%d" % [label, Time.get_ticks_usec()])
	var store := FaultStore.new(directory)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var first := facade.create_character("create_a", 0, "Primeira", &"mage")
	assert(first["ok"], str(first))
	var second := facade.create_character("create_b", facade.current_profile().revision, "Segunda", &"mage")
	assert(second["ok"], str(second))
	var profile := facade.current_profile()
	var catalog := ProfileCatalog.pilot()
	for character: CharacterState in profile.characters:
		var added := profile.add_equipment_instance(&"warden_mail", catalog.equipment_metadata(&"warden_mail"), character.character_id)
		assert(added["ok"])
		for card: StringName in [&"echo_card", &"bulwark_card"]:
			assert(profile.card_inventory.grant(card, BuildContentLoader.pilot(), character.character_id + String(card), character.character_id)["ok"])
	profile.extension_fields["future_note"] = {"nested": [1, "preservar", true]}
	profile.characters[0].extension_fields["future_character_note"] = ["preservar"]
	assert(store.commit(profile)["ok"])
	facade = ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	assert(facade.open_profile()["ok"])
	profile = facade.current_profile()
	var a := profile.characters[0].character_id
	assert(facade.select_character("select_a", profile.revision, a)["ok"])
	return {"store": store, "facade": facade, "directory": directory, "a": a, "b": profile.characters[1].character_id}

static func item(profile: ProfileState, owner: String, definition: StringName) -> StringName:
	for id: StringName in profile.equipment_for_character(owner):
		if profile.equipment_instances[id].definition_id == definition: return id
	return &""

static func card(profile: ProfileState, owner: String, definition: StringName) -> StringName:
	for id: StringName in profile.card_inventory.describe()["owned"]:
		if profile.card_inventory.owner_of(id) == owner and profile.card_inventory.definition_id(id) == definition: return id
	return &""

static func legacy(profile: ProfileState) -> String:
	var source := profile.copy_state()
	# Deliberately shared legacy loadout; alternate references must be removed in preview.
	source.characters[1].equipped = source.characters[0].equipped.duplicate(true)
	for preset: Dictionary in source.characters[1].presets: preset["equipped"] = source.characters[0].equipped.duplicate(true)
	var host := item(source, source.characters[0].character_id, &"starter_staff")
	var selected := card(source, source.characters[0].character_id, &"echo_card")
	var socket := source.card_inventory.preview({"kind": &"socket", "equipment_instance_id": host, "card_instance_id": selected, "socket_index": 0}, source.characters[0].equipped, source.equipment_instances, ProfileCatalog.pilot().all_equipment_metadata())
	assert(socket["ok"], str(socket))
	source.card_inventory = socket["inventory"]
	return JSON.stringify(ProfileCodec._profile_to_dictionary(source), "  ")

static func complete(text: String) -> Dictionary:
	var decoded := ProfileCodec.decode(text)
	var source: ProfileState = decoded["legacy_profile"]
	var assignments := {}
	for id: StringName in source.equipment_instances: assignments[String(id)] = source.characters[0].character_id
	for id: StringName in source.card_inventory.describe()["owned"]: assignments[String(id)] = source.characters[0].character_id
	return MigrationPlan.dry_run(text, null, assignments)

static func write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
