extends SceneTree
const Faults = preload("res://tests/e06_inventory_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_tx/migration_source_%d" % Time.get_ticks_usec())
	var facade := ProfileFacade.new(ProfileStore.new(directory))
	var first := facade.create_character("first", 0, "Mago", &"mage")
	_check(first["ok"], "source character")
	var second := facade.create_character("second", facade.current_profile().revision, "Arqueiro", &"archer")
	_check(second["ok"], "shared alt source")
	var source := facade.current_profile()
	var armor: StringName = source.add_equipment_instance(&"warden_mail", ProfileCatalog.pilot().equipment_metadata(&"warden_mail"))["instance_id"]
	source.characters[0].equipped[&"torso"] = null
	source.characters[0].presets[0]["equipped"][&"torso"] = null
	source.characters[0].presets[1]["equipped"][&"torso"] = armor
	source.settings = {"volume": 0.5, "custom": ["keep", 7]}
	source.extension_fields["custom_extension"] = {"opaque": true}
	source.unresolved_legacy = {"equipment_ids": ["unknown_old_relic"]}
	var encoded := ProfileCodec.encode(source)
	_check(encoded["ok"], "source profile valid")
	var old := _legacy_data(encoded["data"], source)
	var old_text := JSON.stringify(old, "\t")
	var wire: Dictionary = JSON.parse_string(old_text)
	var decoded := ProfileCodec.decode(old_text)
	_check(decoded["ok"] and decoded.get("migrated", false), "schema2 catalog9 migrates")
	if decoded["ok"]:
		var migrated: ProfileState = decoded["profile"]
		_check(migrated.equipment_instances.size() == old["equipment_collection"].size(), "one exemplar per actual legacy acquisition")
		_check(migrated.settings == wire["settings"] and migrated.extension_fields["custom_extension"] == wire["custom_extension"] and migrated.extension_fields.size() == source.extension_fields.size() and migrated.unresolved_legacy == wire["unresolved_legacy"] and migrated.lifetime_stats == source.lifetime_stats, "opaque values and counters preserved")
		var mage := migrated.characters[0]
		var archer := migrated.characters[1]
		_check(mage.equipped[&"torso"] == null and mage.presets[0]["equipped"][&"torso"] == null and mage.presets[1]["equipped"][&"torso"] == migrated.first_instance_for_definition(&"warden_mail"), "catalog9 nulls and inactive preference preserved")
		_check(mage.equipped[&"accessory_1"] == archer.equipped[&"accessory_1"], "alts share one preserved exemplar")
		_check(mage.action_slots == source.characters[0].action_slots and mage.attribute_allocations == source.characters[0].attribute_allocations and mage.purchased_skill_ranks == source.characters[0].purchased_skill_ranks and mage.base_xp_total == source.characters[0].base_xp_total and mage.job_xp_total == source.characters[0].job_xp_total, "progression and layout unchanged")
		var instances := migrated.equipment_instances.values()
		var starter: EquipmentInstance = migrated.equipment_instances[mage.equipped[&"main_hand"]]
		var rare: EquipmentInstance = migrated.equipment_instances[migrated.first_instance_for_definition(&"warden_mail")]
		_check(starter.quality_id == &"common" and rare.quality_id == &"rare" and starter.item_level == 1 and rare.origin_id == &"demo_arena" and rare.socket_capacity == 1, "approved migration metadata")
		var current := ProfileCodec.encode(migrated)
		_check(current["ok"] and current["data"]["schema_version"] == 6 and current["data"]["catalog_version"] == 14 and not current["data"].has("equipment_collection") and not current["data"].has("card_sockets"), "only exemplar records persist")
		var again := ProfileCodec.decode(current["text"])
		_check(again["ok"] and not again.get("migrated", false) and ProfileCodec.encode(again["profile"])["text"] == current["text"], "current envelope reopens without remigration")
		var duplicate := migrated.copy_state()
		var zero := ProfileCatalog.pilot().equipment_metadata(&"warden_mail")
		zero["socket_capacity"] = 0
		var four := zero.duplicate(true)
		four["socket_capacity"] = 4
		four["quality_id"] = &"common"
		var a := duplicate.add_equipment_instance(&"warden_mail", zero)
		var b := duplicate.add_equipment_instance(&"warden_mail", four)
		_check(a["ok"] and b["ok"] and a["instance_id"] != b["instance_id"] and duplicate.equipment_instances.size() == migrated.equipment_instances.size() + 2 and duplicate.equipment_instances[b["instance_id"]].socket_capacity == 4, "copies and sockets independent of rarity")
	for version: int in range(1, 9):
		var historical := old.duplicate(true)
		historical["catalog_version"] = version
		historical["ruleset_id"] = "e00_v1" if version == 1 else ("e04_learn_from_zero_v1" if version <= 6 else ProfileState.RULESET_ID)
		if version == 1:
			for character: Dictionary in historical["characters"]:
				character.erase("granted_skill_ranks")
		var result := ProfileCodec.decode(JSON.stringify(historical))
		_check(result["ok"] and result.get("migrated", false), "supported old catalog: %d" % version)
	var path := ProjectSettings.globalize_path("res://.godot/verification/e06_tx/migration_store_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(path)
	var primary := path.path_join(ProfileStore.PRIMARY_FILE)
	_write(primary, old_text)
	var store := Faults.FaultStore.new(path)
	store.failure_stage = &"write_pending"
	var failed := store.load_profile()
	_check(not failed["ok"] and FileAccess.get_file_as_string(primary) == old_text, "failed migration preserves source")
	store.failure_stage = &""
	var loaded := store.load_profile()
	_check(loaded["ok"] and loaded["profile"].revision == source.revision + 1 and FileAccess.get_file_as_string(path.path_join(ProfileStore.BACKUP_FILE)) == old_text, "migration commits once with verbatim backup")
	var durable := FileAccess.get_file_as_string(primary)
	var reopened := store.load_profile()
	_check(reopened["ok"] and reopened["profile"].revision == loaded["profile"].revision and FileAccess.get_file_as_string(primary) == durable, "reopen is idempotent")
	var future := JSON.parse_string(durable) as Dictionary
	future["schema_version"] = ProfileState.SCHEMA_VERSION + 1
	var future_text := JSON.stringify(future)
	_write(primary, future_text)
	var protected := store.load_profile()
	_check(not protected["ok"] and protected.get("read_only", false) and FileAccess.get_file_as_string(primary) == future_text, "future schema preserved despite old backup")
	print("E06 TX1 migration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func _legacy_data(current: Dictionary, profile: ProfileState) -> Dictionary:
	var result := current.duplicate(true)
	result["schema_version"] = 2
	result.erase("card_inventory")
	result["catalog_version"] = 9
	result.erase("equipment_instances")
	result.erase("next_equipment_counter")
	result["equipment_collection"] = []
	for id: StringName in profile.equipment_instance_ids():
		result["equipment_collection"].append(String(profile.equipment_instances[id].definition_id))
	for character: Dictionary in result["characters"]:
		character["equipped"] = _old_layout(character["equipped"], profile)
		for preset: Dictionary in character["presets"]:
			preset["equipped"] = _old_layout(preset["equipped"], profile)
	return result
func _old_layout(layout: Dictionary, profile: ProfileState) -> Dictionary:
	var result := {}
	for row: Array in [["weapon", "main_hand"], ["armor", "torso"], ["accessory", "accessory_1"]]:
		var id: Variant = layout[row[1]]
		result[row[0]] = null if id == null else String(profile.equipment_instances[StringName(id)].definition_id)
	return result
func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
