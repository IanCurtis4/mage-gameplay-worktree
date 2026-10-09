extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
const ID := "123e4567-e89b-42d3-a456-426614174000"
var checks := 0
var failures := 0
var directory: String
func _initialize() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e06_t2/migration_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	_check(ProfileState.CATALOG_VERSION == 9 and ProfileState.SCHEMA_VERSION == 2 and ProfileState.RULESET_ID == "stat_thresholds_v1", "audited8 -> catalog9, schema/ruleset unchanged")
	var effects := BuildContentLoader.pilot()
	_check(effects.ids(&"equipment").size() == 12 and effects.ids(&"card").size() == 6, "reserved metadata counts")
	for origin: StringName in [&"swordsman", &"mage", &"archer"]:
		var starters := catalog.starter_equipment(origin)
		_check(starters[&"armor"] == &"traveler_vest" and starters[&"accessory"] == &"traveler_charm" and catalog.starter_item_ids(origin).size() == 3, "origin starter trio from unique catalog")
	for id: StringName in effects.ids(&"equipment"):
		var item := effects.get_definition(&"equipment", id) as EquipmentDefinition
		var metadata := catalog.equipment_metadata(id)
		_check(metadata["slot"] == item.slot and metadata["allowed_base_classes"] == item.allowed_origins and metadata["starter"] == item.starter, "profile metadata matches Resource")
	for version: int in range(1, 9):
		var payload := _payload(version)
		var encoded := JSON.stringify(payload)
		var result := ProfileCodec.decode(encoded)
		_check(result["ok"] and result["migrated"], "explicit supported catalog migration " + str(version))
		if not result["ok"]: continue
		var profile: ProfileState = result["profile"]
		var character := profile.characters[0]
		_check(character.equipped[&"armor"] == &"warden_mail" and character.equipped[&"weapon"] == &"starter_staff" and character.presets[1]["equipped"][&"armor"] == &"channeler_robe", "preserve valid selections, fill only null slots")
		_check(character.action_slots.size() == 24 and character.action_slots[0] == &"fire_spear" and character.attribute_allocations[&"int"] == (7 if version >= 7 else 1) and character.base_xp_total == 225, "XP ranks/actions and threshold investment preserved")
		_check(profile.extension_fields["extension"] == {"keep": [1.0, 2.0]} and character.extension_fields["note"] == "keep" and profile.legacy_loadouts == {"custom": "keep"} and profile.unresolved_legacy == {"unknown": "keep"}, "extensions and unresolved legacy preserved")
		var serialized := ProfileCodec.encode(profile)
		var again := ProfileCodec.decode(serialized["text"])
		_check(again["ok"] and not again["migrated"] and ProfileCodec.encode(again["profile"])["text"] == serialized["text"], "migration idempotent")
	var old := JSON.stringify(_payload(8))
	var migration_dir := directory.path_join("durable")
	_write(migration_dir, ProfileStore.PRIMARY_FILE, old)
	var migrated := ProfileStore.new(migration_dir).load_profile()
	_check(migrated["ok"] and migrated["profile"].revision == 6 and FileAccess.get_file_as_string(migration_dir.path_join(ProfileStore.BACKUP_FILE)) == old, "migration saves once with exact old backup")
	_check(ProfileStore.new(migration_dir).load_profile()["profile"].revision == 6, "reopen never repeats additive migration")
	for stage: StringName in [&"write_pending", &"validate_pending", &"backup", &"replace"]:
		var target := directory.path_join(String(stage))
		_write(target, ProfileStore.PRIMARY_FILE, old)
		var store := F.FaultStore.new(target)
		store.failure_stage = stage
		var failed := store.load_profile()
		_check(not failed["ok"] and FileAccess.get_file_as_string(target.path_join(ProfileStore.PRIMARY_FILE)) == old, "migration failure preserves original: " + String(stage))
		if stage != &"write_pending":
			var pending := FileAccess.get_file_as_string(target.path_join(ProfileStore.PENDING_FILE))
			_check(not ProfileStore.new(target).load_profile()["ok"] and FileAccess.get_file_as_string(target.path_join(ProfileStore.PENDING_FILE)) == pending, "unconfirmed pending untouched")
	for artifact: String in [ProfileStore.PRIMARY_FILE, ProfileStore.BACKUP_FILE]:
		var target := directory.path_join("future_" + artifact)
		_write(target, ProfileStore.PRIMARY_FILE, old)
		var future := _payload(8)
		future["catalog_version"] = 10
		var bytes := JSON.stringify(future)
		_write(target, artifact, bytes)
		_check(not ProfileStore.new(target).load_profile()["ok"] and FileAccess.get_file_as_string(target.path_join(artifact)) == bytes, "future catalog preserved, no downgrade")
	var pending_dir := directory.path_join("pending_backup")
	_write(pending_dir, ProfileStore.BACKUP_FILE, old)
	_write(pending_dir, ProfileStore.PENDING_FILE, "pending evidence")
	_check(not ProfileStore.new(pending_dir).load_profile()["ok"] and FileAccess.get_file_as_string(pending_dir.path_join(ProfileStore.PENDING_FILE)) == "pending evidence", "backup cannot overwrite pending evidence")
	var runtime := _payload(8)
	runtime["cards"] = ["echo_card"]
	_check(not ProfileCodec.decode(JSON.stringify(runtime))["ok"], "runtime cards cannot enter save through migration")
	print("E06 migration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _payload(version: int) -> Dictionary:
	var profile := ProfileState.new(ID)
	profile.revision = 5
	profile.next_character_counter = 2
	profile.selected_character_id = IdentityIds.character_id(ID, 1)
	profile.equipment_collection = [&"warden_mail", &"channeler_robe"]
	profile.extension_fields["extension"] = {"keep": [1, 2]}
	profile.legacy_loadouts = {"custom": "keep"}
	profile.unresolved_legacy = {"unknown": "keep"}
	var character := CharacterState.new(profile.selected_character_id, "MigraÃ§Ã£o", &"mage")
	character.base_xp_total = 225
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	character.purchased_skill_ranks = {&"fire_spear": 1}
	character.action_slots = ActionBarLayout.empty()
	character.action_slots[0] = &"fire_spear"
	character.attribute_allocations[&"int"] = 7 if version >= 7 else 1
	character.equipped[&"armor"] = &"warden_mail"
	character.presets[0]["equipped"][&"armor"] = &"warden_mail"
	character.presets[1]["equipped"][&"armor"] = &"channeler_robe"
	character.extension_fields["note"] = "keep"
	profile.characters.append(character)
	var encoded := ProfileCodec.encode(profile)
	assert(encoded["ok"])
	var payload: Dictionary = encoded["data"]
	payload["catalog_version"] = version
	payload["ruleset_id"] = "e00_v1" if version == 1 else (ProfileCodec.PRE_THRESHOLDS_RULESET_ID if version <= 6 else ProfileState.RULESET_ID)
	if version == 1: payload["characters"][0].erase("granted_skill_ranks")
	return payload
func _write(target: String, file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(target)
	var file := FileAccess.open(target.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
