extends SceneTree
## Catalog 7→9 migration with additive inventory starters. All file writes are isolated test fixtures.

class FailingStore:
	extends ProfileStore
	var failure_stage: StringName = &""
	func _should_fail(stage: StringName) -> bool:
		return stage == failure_stage

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174000"
var root_directory: String
var checks := 0
var failures := 0

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/hunter_migration_%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	_pairs_and_validation()
	_store_and_first_mutation()
	_transaction_guards()
	print("Hunter catalog migration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _profile(origin: StringName = &"swordsman", evolution: StringName = &"berserker") -> ProfileState:
	var profile := ProfileState.new(PROFILE_ID)
	profile.revision = 5
	profile.next_character_counter = 3
	profile.next_run_counter = 9
	profile.selected_character_id = IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(profile.selected_character_id, "Referência", origin)
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP if not evolution.is_empty() else ProgressionRules.UNEVOLVED_MAX_JOB_XP
	character.evolution_id = evolution
	character.action_slots = ActionBarLayout.empty()
	var alt := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 2), "Outro", &"mage")
	profile.characters.assign([character, alt])
	return profile

func _old_text(profile: ProfileState) -> String:
	var encoded := ProfileCodec.encode(profile, ProfileCatalog.pilot())
	_check(encoded["ok"], "legal source before changing only envelope")
	if not encoded["ok"]: return "invalid fixture"
	var data: Dictionary = encoded["data"]
	data["catalog_version"] = 7
	return JSON.stringify(data, "\t")

func _pairs_and_validation() -> void:
	_check(ProfileState.CATALOG_VERSION == 9 and ProfileState.SCHEMA_VERSION == 2 and ProfileState.RULESET_ID == "stat_thresholds_v1", "only catalog version changes")
	for pair: Array in [[&"swordsman", &""], [&"mage", &""], [&"archer", &""], [&"swordsman", &"defender"], [&"swordsman", &"berserker"], [&"mage", &"elementalist"], [&"mage", &"spiritualist"], [&"mage", &"mg_ar"], [&"archer", &"sentinel"], [&"archer", &"hunter"]]:
		var source := _profile(pair[0], pair[1])
		var decoded := ProfileCodec.decode(_old_text(source))
		_check(decoded.get("ok", false) and decoded.get("migration_kind", &"") == &"catalog_v7", "known threshold envelope migrates every existing origin")
		if not decoded.get("ok", false): continue
		var migrated: ProfileState = decoded["profile"]
		_check(migrated.revision == source.revision and migrated.characters[0].base_xp_total == source.characters[0].base_xp_total and migrated.characters[0].job_xp_total == source.characters[0].job_xp_total and migrated.characters[0].evolution_id == pair[1], "pure codec never changes identity/XP/revision")
		_check(migrated.characters[0].granted_skill_ranks.is_empty() and migrated.characters[0].purchased_skill_ranks.is_empty(), "catalog addition never injects saved rank grants")
		var encoded := ProfileCodec.encode(migrated)
		_check(encoded["ok"] and not ProfileCodec.decode(encoded["text"])["migrated"], "current envelope reload is idempotent")
	var profile := _profile()
	profile.characters[0].attribute_allocations.merge({&"str": 40, &"vit": 35, &"dex": 25}, true)
	var text := _old_text(profile)
	_check(ProfileCodec.decode(text)["ok"], "legitimate threshold-era investment above 87 increments migrates")
	for change: Dictionary in [
		{"ruleset_id": ProfileCodec.PRE_THRESHOLDS_RULESET_ID}, {"ruleset_id": "unknown"},
		{"catalog_version": 10}, {"schema_version": 3},
	]:
		var data: Dictionary = JSON.parse_string(text)
		data.merge(change, true)
		_check(not ProfileCodec.decode(JSON.stringify(data))["ok"], "unknown/future catalog/ruleset/schema cannot be certified by migration")
	for kind: StringName in [&"budget", &"rank", &"runtime"]:
		var invalid: Dictionary = JSON.parse_string(text)
		if kind == &"budget": invalid["characters"][0]["attribute_allocations"] = {"str": 56, "agi": 55, "vit": 55, "int": 57, "dex": 55, "luk": 57}
		if kind == &"rank": invalid["characters"][0]["purchased_skill_ranks"] = {"slash": 99}
		if kind == &"runtime": invalid["current_hp"] = 30
		_check(not ProfileCodec.decode(JSON.stringify(invalid))["ok"], "migration does not rescue invalid current costs/ranks/runtime fields")

func _store_and_first_mutation() -> void:
	var profile := _profile()
	var character := profile.characters[0]
	character.attribute_allocations.merge({&"str": 40, &"vit": 35, &"dex": 25}, true)
	character.purchased_skill_ranks = {&"slash": 3, &"blood_thirst": 1, &"berserker_execution": 1}
	character.action_slots[0] = &"slash"
	character.action_slots[23] = &"berserker_execution"
	character.extension_fields["note"] = ["preservar"]
	profile.extension_fields["note"] = {"keep": true}
	profile.settings["volume"] = 0.7
	profile.legacy_loadouts = {"old": ["preservar"]}
	profile.unresolved_legacy = {"entry": "sem mudança"}
	var text := _old_text(profile)
	var directory := _directory("roundtrip")
	_write(directory.path_join(ProfileStore.PRIMARY_FILE), text)
	var store := ProfileStore.new(directory)
	var result := store.load_profile()
	_check(result.get("ok", false) and result.get("warning", &"") == &"profile_migrated", "store durably migrates with explicit warning")
	if not result.get("ok", false): return
	var migrated: ProfileState = result["profile"]
	_check(FileAccess.get_file_as_string(directory.path_join(ProfileStore.BACKUP_FILE)) == text, "backup conserves byte-exact source before envelope write")
	var kept := migrated.characters[0]
	_check(migrated.revision == profile.revision + 1 and migrated.profile_id == PROFILE_ID and migrated.next_character_counter == 3 and migrated.next_run_counter == 9 and migrated.selected_character_id == profile.selected_character_id, "single revision increment preserves IDs/counters/selection")
	_check(kept.attribute_allocations == character.attribute_allocations and kept.purchased_skill_ranks == character.purchased_skill_ranks and kept.granted_skill_ranks == character.granted_skill_ranks and kept.action_slots == character.action_slots, "all investments/skills/24 slots/presets/equipment preserved")
	var expected_equipment := {&"weapon": &"starter_blade", &"armor": &"traveler_vest", &"accessory": &"traveler_charm"}
	_check(kept.equipped == expected_equipment, "inventory migration fills only previously null equipment")
	for index: int in CharacterState.PRESET_COUNT:
		_check(kept.presets[index]["equipped"] == expected_equipment and kept.presets[index]["active_slots"] == character.presets[index]["active_slots"] and kept.presets[index]["passive_slots"] == character.presets[index]["passive_slots"], "both presets retain skill slots and gain only additive starters")
	_check(kept.extension_fields == character.extension_fields and migrated.extension_fields == profile.extension_fields and migrated.settings == profile.settings and migrated.legacy_loadouts == profile.legacy_loadouts and migrated.unresolved_legacy == profile.unresolved_legacy and migrated.lifetime_stats == profile.lifetime_stats, "extensions/settings/legacy/lifetime totals preserved")
	var facade := ProfileFacade.new(store)
	_check(facade.open_profile()["ok"], "migrated facade opens")
	var revision := facade.current_profile().revision
	var allocation := facade.allocate_attributes("hunter-migration-first", revision, kept.character_id, {&"dex": 1})
	_check(allocation["ok"] and allocation["spent"] == ProgressionRules.attribute_points_spent({&"str": 40, &"vit": 35, &"dex": 26}, &"swordsman") - ProgressionRules.attribute_points_spent(character.attribute_allocations, &"swordsman"), "first mutation respects canonical cost with catalog-7 backup")
	if not allocation["ok"]: return
	var spent := ProgressionRules.attribute_points_spent(facade.current_profile().characters[0].attribute_allocations, &"swordsman")
	var respec := facade.respec_attributes("hunter-migration-refund", facade.current_profile().revision, kept.character_id)
	_check(respec["ok"] and respec["refunded"] == spent and respec["progression"]["attribute_points_available"] == 458, "respec refunds canonical threshold cost, never old increment count")
	var reload := ProfileFacade.new(ProfileStore.new(directory))
	_check(reload.open_profile()["ok"] and reload.current_profile().characters[0].purchased_skill_ranks == character.purchased_skill_ranks and reload.current_profile().characters[0].action_slots == character.action_slots and reload.current_profile().characters[1].base_xp_total == 0, "mutation/reload isolate other character and keep skills/bars")
	var started := reload.start_run("hunter-migration-active", reload.current_profile().revision)
	_check(started["ok"], "legal existing identity starts reward-session fixture")
	if started["ok"]:
		var active := reload.current_profile()
		var active_dir := _directory("active")
		_write(active_dir.path_join(ProfileStore.PRIMARY_FILE), _old_text(active))
		var active_result := ProfileStore.new(active_dir).load_profile()
		_check(active_result["ok"] and active_result["profile"].reward_session == active.reward_session and active_result["profile"].next_run_counter == active.next_run_counter and active_result["profile"].lifetime_stats == active.lifetime_stats, "migration preserves active reward cursor and lifetime counters exactly")

func _transaction_guards() -> void:
	var text := _old_text(_profile())
	for stage: StringName in [&"write_pending", &"validate_pending", &"backup", &"replace"]:
		var directory := _directory(str(stage))
		_write(directory.path_join(ProfileStore.PRIMARY_FILE), text)
		var store := FailingStore.new(directory)
		store.failure_stage = stage
		var result := store.load_profile()
		_check(not result["ok"] and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == text, "failed migration keeps original primary at each transaction stage")
		if stage != &"write_pending":
			var pending := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PENDING_FILE))
			var blocked := ProfileStore.new(directory).load_profile()
			_check(not blocked["ok"] and blocked.get("read_only", false) and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PENDING_FILE)) == pending, "uncertain pending neither promoted nor overwritten")
	for artifact: String in [ProfileStore.PRIMARY_FILE, ProfileStore.BACKUP_FILE, ProfileStore.PENDING_FILE]:
		for field: String in ["catalog_version", "ruleset_id", "schema_version"]:
			var directory := _directory(artifact + field)
			_write(directory.path_join(ProfileStore.PRIMARY_FILE), text)
			_write(directory.path_join(ProfileStore.BACKUP_FILE), text)
			var future: Dictionary = JSON.parse_string(text)
			future[field] = "unknown" if field == "ruleset_id" else 99
			var future_text := JSON.stringify(future)
			_write(directory.path_join(artifact), future_text)
			var blocked := ProfileStore.new(directory).load_profile()
			_check(not blocked["ok"] and blocked.get("read_only", false), "future/incompatible artifact blocks envelope write")
			for name: String in [ProfileStore.PRIMARY_FILE, ProfileStore.BACKUP_FILE, ProfileStore.PENDING_FILE]:
				if name == artifact:
					_check(FileAccess.get_file_as_string(directory.path_join(name)) == future_text, "incompatible artifact bytes preserved")
				elif name != ProfileStore.PENDING_FILE:
					_check(FileAccess.get_file_as_string(directory.path_join(name)) == text, "other durable artifacts unchanged")
	var recovery_dir := _directory("backup_recovery")
	_write(recovery_dir.path_join(ProfileStore.PRIMARY_FILE), "{broken")
	_write(recovery_dir.path_join(ProfileStore.BACKUP_FILE), text)
	var recovered := ProfileStore.new(recovery_dir).load_profile()
	_check(recovered["ok"] and recovered.get("warning", &"") == &"profile_migrated_from_backup" and FileAccess.get_file_as_string(recovery_dir.path_join(ProfileStore.BACKUP_FILE)) == text, "recognized catalog-7 backup recovers conservatively")

func _directory(name: String) -> String:
	var result := root_directory.path_join(name)
	DirAccess.make_dir_recursive_absolute(result)
	return result

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
