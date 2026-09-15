extends SceneTree

class FailingStore:
	extends ProfileStore
	var failure_stage: StringName

	func _init(directory: String, stage: StringName) -> void:
		super(directory)
		failure_stage = stage

	func _should_fail(stage: StringName) -> bool:
		return stage == failure_stage

const PROFILE_ID := "00000000-0000-4000-8000-000000000001"

var failures := 0
var checks := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e01_profile_store")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	_check_reference_fixture()
	_check_round_trip_and_unknown_fields()
	_check_catalog_references()
	_check_evolution_catalog_boundary()
	_check_atomic_write_failures()
	_check_counter_monotonicity()
	_check_backup_recovery()
	_check_future_and_invalid_files()
	_check_v1_migration()
	_cleanup_directory(root_directory)
	print("Persistência E01.2: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_reference_fixture() -> void:
	var fixture_file := FileAccess.open("res://docs/fixtures/e00_reference.json", FileAccess.READ)
	_check(fixture_file != null, "E00 reference fixture is readable")
	var fixture: Dictionary = JSON.parse_string(fixture_file.get_as_text())
	fixture_file.close()
	var decoded := ProfileCodec.decode(JSON.stringify(fixture["profile"]))
	_check(decoded["ok"] and decoded["profile"].characters.size() == 1, "schema decoder consumes the accepted E00 profile fixture")
	_check(decoded["profile"].characters[0].display_name == "Referência", "Unicode display names survive fixture decoding")

func _check_round_trip_and_unknown_fields() -> void:
	var directory := root_directory.path_join("round_trip")
	_prepare_directory(directory)
	var store := ProfileStore.new(directory)
	_check(ProfileStore.new()._path(ProfileStore.PRIMARY_FILE) == "user://profile.json", "default production path preserves the user:// scheme")
	var profile := _profile_with_character()
	profile.extension_fields["future_root_note"] = {"kept": true}
	profile.characters[0].extension_fields["future_character_note"] = [1, 2, 3]
	var committed := store.commit(profile)
	_check(committed["ok"] and committed["new_revision"] == 1 and profile.revision == 0, "commit publishes a copied revision without mutating its source")
	var loaded := store.load_profile()
	_check(loaded["ok"] and loaded["profile"].revision == 1, "committed schema-2 profile reloads")
	var loaded_profile: ProfileState = loaded["profile"]
	_check(loaded_profile.extension_fields["future_root_note"]["kept"] and loaded_profile.characters[0].extension_fields["future_character_note"][2] == 3, "unknown root and character fields are preserved")
	loaded_profile.characters[0].base_xp_total = 375
	var second_commit := store.commit(loaded_profile)
	_check(second_commit["ok"] and second_commit["new_revision"] == 2, "a second commit advances the revision once")
	var backup := _decode_file(directory.path_join(ProfileStore.BACKUP_FILE))
	_check(backup["ok"] and backup["profile"].revision == 1, "the previous valid primary becomes the backup")
	_check(not FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "successful replacement leaves no pending transaction")
	var encoded := ProfileCodec.encode(second_commit["profile"])
	var runtime_payload: Dictionary = encoded["data"].duplicate(true)
	runtime_payload["characters"][0]["augment_stacks"] = {"vitality": 2}
	var rejected := ProfileCodec.decode(JSON.stringify(runtime_payload))
	_check(not rejected["ok"] and rejected["error_code"] == &"runtime_state_in_save", "runtime augment state is rejected from persistent payloads")
	var boolean_payload: Dictionary = encoded["data"].duplicate(true)
	boolean_payload["characters"][0]["base_xp_total"] = true
	_check(ProfileCodec.decode(JSON.stringify(boolean_payload))["error_code"] == &"invalid_integer", "boolean XP is not accepted as an integer")
	var overspent_payload: Dictionary = encoded["data"].duplicate(true)
	overspent_payload["characters"][0]["attribute_allocations"]["str"] = 50
	_check(ProfileCodec.decode(JSON.stringify(overspent_payload))["error_code"] == &"overspent_attributes", "attribute allocations cannot exceed level grants or the investment cap")
	var bad_counter_payload: Dictionary = encoded["data"].duplicate(true)
	bad_counter_payload["characters"][0]["character_id"] = PROFILE_ID + "_99"
	bad_counter_payload["selected_character_id"] = PROFILE_ID + "_99"
	_check(ProfileCodec.decode(JSON.stringify(bad_counter_payload))["error_code"] == &"invalid_character_id", "character IDs must use a reserved counter below the next counter")
	var unowned_payload: Dictionary = encoded["data"].duplicate(true)
	unowned_payload["characters"][0]["equipped"]["weapon"] = "not_owned"
	_check(ProfileCodec.decode(JSON.stringify(unowned_payload))["error_code"] == &"invalid_equipment", "equipped items must belong to the profile collection")
	var invalid_id_payload: Dictionary = encoded["data"].duplicate(true)
	invalid_id_payload["characters"][0]["purchased_skill_ranks"]["../not_an_id"] = 1
	_check(ProfileCodec.decode(JSON.stringify(invalid_id_payload))["error_code"] == &"invalid_skill_ranks", "catalog IDs are restricted to lowercase snake_case")
	var unknown_skill_payload: Dictionary = encoded["data"].duplicate(true)
	unknown_skill_payload["characters"][0]["purchased_skill_ranks"]["nonexistent_skill"] = 1
	_check(ProfileCodec.decode(JSON.stringify(unknown_skill_payload))["error_code"] == &"invalid_catalog", "unknown purchased skills block the incompatible profile")
	var foreign_skill_payload: Dictionary = encoded["data"].duplicate(true)
	foreign_skill_payload["characters"][0]["purchased_skill_ranks"]["fireball"] = 1
	_check(ProfileCodec.decode(JSON.stringify(foreign_skill_payload))["error_code"] == &"invalid_catalog", "skills from another base origin are rejected")
	var wrong_slot_payload: Dictionary = encoded["data"].duplicate(true)
	wrong_slot_payload["characters"][0]["presets"][0]["active_slots"][0] = "swordsman_resistance"
	_check(ProfileCodec.decode(JSON.stringify(wrong_slot_payload))["error_code"] == &"invalid_presets", "passive skills cannot occupy active slots")
	var excessive_rank_payload: Dictionary = encoded["data"].duplicate(true)
	excessive_rank_payload["characters"][0]["purchased_skill_ranks"]["slash"] = 5
	_check(ProfileCodec.decode(JSON.stringify(excessive_rank_payload))["error_code"] == &"invalid_skill_ranks", "purchased ranks respect catalog limits")
	var overspent_skill_payload: Dictionary = encoded["data"].duplicate(true)
	overspent_skill_payload["characters"][0]["purchased_skill_ranks"]["slash"] = 2
	_check(ProfileCodec.decode(JSON.stringify(overspent_skill_payload))["error_code"] == &"overspent_skill_points", "purchased ranks cannot exceed granted base skill points")
	var unknown_owned_item_payload: Dictionary = encoded["data"].duplicate(true)
	unknown_owned_item_payload["equipment_collection"] = ["nonexistent_item"]
	unknown_owned_item_payload["characters"][0]["equipped"]["weapon"] = "nonexistent_item"
	_check(ProfileCodec.decode(JSON.stringify(unknown_owned_item_payload))["error_code"] == &"invalid_catalog", "syntactically valid but unknown equipment blocks the profile")
	var early_evolution_payload: Dictionary = encoded["data"].duplicate(true)
	early_evolution_payload["characters"][0]["evolution_id"] = "sp_mg"
	_check(ProfileCodec.decode(JSON.stringify(early_evolution_payload))["error_code"] == &"requirements_unmet", "evolution cannot be persisted before accepted base and job thresholds")
	var duplicate_payload: Dictionary = encoded["data"].duplicate(true)
	duplicate_payload["characters"].append(duplicate_payload["characters"][0].duplicate(true))
	_check(ProfileCodec.decode(JSON.stringify(duplicate_payload))["error_code"] == &"duplicate_character_id", "duplicate character IDs are rejected")
	var too_large_profile: ProfileState = second_commit["profile"].copy_state()
	too_large_profile.extension_fields["oversized"] = "x".repeat(ProfileCodec.MAX_FILE_BYTES)
	_check(ProfileCodec.encode(too_large_profile)["error_code"] == &"profile_too_large", "encoded profiles enforce the four MiB limit")
	var stale_source: ProfileState = second_commit["profile"].copy_state()
	stale_source.revision = 1
	var stale_result := store.commit(stale_source)
	_check(not stale_result["ok"] and stale_result["error_code"] == &"stale_revision", "store rejects a stale in-memory revision before writing")

func _check_atomic_write_failures() -> void:
	for stage: StringName in [&"write_pending", &"validate_pending", &"backup", &"replace"]:
		var directory := root_directory.path_join("failure_" + String(stage))
		_prepare_directory(directory)
		var initial_store := ProfileStore.new(directory)
		var initial := initial_store.commit(_profile_with_character())
		_check(initial["ok"], "%s failure fixture creates an initial primary" % stage)
		var source: ProfileState = initial["profile"]
		source.characters[0].base_xp_total = 375
		var failing_store := FailingStore.new(directory, stage)
		var failed := failing_store.commit(source)
		var disk := _decode_file(directory.path_join(ProfileStore.PRIMARY_FILE))
		_check(not failed["ok"] and failed["error_code"] == &"save_failed", "%s failure is reported" % stage)
		_check(source.revision == 1 and source.characters[0].base_xp_total == 375, "%s failure does not roll back or publish over the caller state" % stage)
		_check(disk["ok"] and disk["profile"].revision == 1 and disk["profile"].characters[0].base_xp_total == 350, "%s failure leaves the committed primary intact" % stage)

func _check_catalog_references() -> void:
	var catalog := _catalog_with_training_sword()
	var profile := _profile_with_character()
	profile.equipment_collection.append(&"training_sword")
	profile.characters[0].equipped[&"weapon"] = &"training_sword"
	var encoded := ProfileCodec.encode(profile, catalog)
	_check(encoded["ok"], "explicit catalog accepts known equipment in its legal slot and origin")
	var wrong_slot: Dictionary = encoded["data"].duplicate(true)
	wrong_slot["characters"][0]["equipped"]["weapon"] = null
	wrong_slot["characters"][0]["equipped"]["armor"] = "training_sword"
	var wrong_slot_result := ProfileCodec.decode(JSON.stringify(wrong_slot), catalog)
	_check(not wrong_slot_result["ok"] and wrong_slot_result["error_code"] == &"invalid_equipment" and wrong_slot_result["catalog_incompatible"], "equipment metadata enforces slot and marks incompatibility as protected")

	var directory := root_directory.path_join("unknown_catalog_reference")
	_prepare_directory(directory)
	var valid := ProfileCodec.encode(_profile_with_character())
	var unknown_skill: Dictionary = valid["data"].duplicate(true)
	unknown_skill["characters"][0]["purchased_skill_ranks"]["nonexistent_skill"] = 1
	var unknown_text := JSON.stringify(unknown_skill)
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), unknown_text)
	_write_text(directory.path_join(ProfileStore.BACKUP_FILE), valid["text"])
	var loaded := ProfileStore.new(directory).load_profile()
	_check(not loaded["ok"] and loaded["error_code"] == &"invalid_catalog" and loaded["read_only"], "unknown catalog references block the profile without backup rollback")
	_check(_read_text(directory.path_join(ProfileStore.PRIMARY_FILE)) == unknown_text, "catalog-incompatible primary remains byte-for-byte intact")

func _check_counter_monotonicity() -> void:
	var directory := root_directory.path_join("counter_regression")
	_prepare_directory(directory)
	var profile := ProfileState.new(PROFILE_ID)
	profile.next_character_counter = 100
	profile.next_run_counter = 100
	var store := ProfileStore.new(directory)
	var committed := store.commit(profile)
	_check(committed["ok"], "counter regression fixture persists high counters without characters or a reward session")
	var original_primary := _read_text(directory.path_join(ProfileStore.PRIMARY_FILE))
	var run_regression: ProfileState = committed["profile"].copy_state()
	run_regression.next_run_counter = 1
	var run_result := store.commit(run_regression)
	_check(not run_result["ok"] and run_result["error_code"] == &"counter_regression", "next_run_counter can never regress")
	var character_regression: ProfileState = committed["profile"].copy_state()
	character_regression.next_character_counter = 1
	var character_result := store.commit(character_regression)
	_check(not character_result["ok"] and character_result["error_code"] == &"counter_regression", "next_character_counter can never regress")
	_check(_read_text(directory.path_join(ProfileStore.PRIMARY_FILE)) == original_primary and not FileAccess.file_exists(directory.path_join(ProfileStore.BACKUP_FILE)) and not FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "counter regression leaves all disk artifacts unchanged")

func _check_evolution_catalog_boundary() -> void:
	var catalog := ProfileCatalog.pilot({}, {
		&"sp_mg_rune_entry": {
			"allowed_base_classes": [&"swordsman"],
			"category": ProfileCatalog.ACTIVE,
			"wallet": ProfileCatalog.EVOLUTION_WALLET,
			"free_rank": 1,
			"max_purchased_rank": 4,
			"required_evolution_id": &"sp_mg",
		},
	})
	var profile := _profile_with_character()
	var character: CharacterState = profile.characters[0]
	character.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	character.job_xp_total = ProgressionRules.EVOLUTION_MIN_JOB_XP
	character.presets[0]["active_slots"][0] = &"sp_mg_rune_entry"
	var unevolved := ProfileCodec.encode(profile, catalog)
	_check(not unevolved["ok"] and unevolved["error_code"] == &"invalid_catalog", "free evolution skill is blocked on an unevolved character")
	character.evolution_id = &"sp_ar"
	var wrong_evolution := ProfileCodec.encode(profile, catalog)
	_check(not wrong_evolution["ok"] and wrong_evolution["error_code"] == &"invalid_catalog", "free evolution skill is blocked on a different evolution of the same origin")
	character.evolution_id = &"sp_mg"
	var matching_evolution := ProfileCodec.encode(profile, catalog)
	_check(matching_evolution["ok"], "free evolution skill is accepted only on its declared evolution")

	var oversized_active := ProfileCatalog.pilot({}, {
		&"oversized_active": {
			"allowed_base_classes": [&"mage"],
			"category": ProfileCatalog.ACTIVE,
			"wallet": ProfileCatalog.BASE_WALLET,
			"free_rank": 9,
			"max_purchased_rank": 99,
		},
	})
	_check(not oversized_active.is_valid(), "catalog rejects active skill metadata above rank 5")
	_check(ProfileCodec.encode(_profile_with_character(), oversized_active)["error_code"] == &"invalid_catalog", "codec never certifies a catalog with an oversized active rank")
	var oversized_passive := ProfileCatalog.pilot({}, {
		&"oversized_passive": {
			"allowed_base_classes": [&"mage"],
			"category": ProfileCatalog.PASSIVE,
			"wallet": ProfileCatalog.BASE_WALLET,
			"free_rank": 1,
			"max_purchased_rank": 3,
		},
	})
	_check(not oversized_passive.is_valid(), "catalog rejects passive skill metadata above rank 3")

func _check_backup_recovery() -> void:
	var directory := root_directory.path_join("recovery")
	_prepare_directory(directory)
	var store := ProfileStore.new(directory)
	var first := store.commit(_profile_with_character())
	var second_source: ProfileState = first["profile"]
	second_source.characters[0].base_xp_total = 375
	var second := store.commit(second_source)
	_check(second["ok"], "recovery fixture has a primary and previous backup")
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), "{broken")
	_write_text(directory.path_join(ProfileStore.PENDING_FILE), JSON.stringify({"schema_version": 2, "unconfirmed": true}))
	var recovered := store.load_profile()
	_check(recovered["ok"] and recovered["recovered"] and recovered["warning"] == &"recovered_from_backup", "corrupt primary recovers explicitly from the backup")
	_check(recovered["profile"].revision == 1 and recovered["profile"].characters[0].base_xp_total == 350, "backup recovery reports the older durable revision without claiming no loss")
	_check(_decode_file(directory.path_join(ProfileStore.PRIMARY_FILE))["ok"], "backup recovery repairs the primary with validated content")
	_check(not FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "stale pending data is never promoted during recovery")
	var corrupt_files := _files_beginning_with(directory, "profile.corrupt.")
	_check(corrupt_files.size() == 1 and _read_text(directory.path_join(corrupt_files[0])) == "{broken", "the corrupt primary is preserved separately")

func _check_future_and_invalid_files() -> void:
	var future_directory := root_directory.path_join("future")
	_prepare_directory(future_directory)
	var future_text := JSON.stringify({"format_id": ProfileState.FORMAT_ID, "schema_version": 99, "future": "keep"})
	_write_text(future_directory.path_join(ProfileStore.PRIMARY_FILE), future_text)
	var backup_profile := ProfileCodec.encode(_profile_with_character())
	_write_text(future_directory.path_join(ProfileStore.BACKUP_FILE), backup_profile["text"])
	var future_result := ProfileStore.new(future_directory).load_profile()
	_check(not future_result["ok"] and future_result["error_code"] == &"unsupported_schema" and future_result["read_only"], "future schema blocks writes instead of falling back to an older backup")
	_check(_read_text(future_directory.path_join(ProfileStore.PRIMARY_FILE)) == future_text, "future schema remains byte-for-byte intact")
	var overwrite_future := ProfileStore.new(future_directory).commit(_profile_with_character())
	_check(not overwrite_future["ok"] and overwrite_future["read_only"] and _read_text(future_directory.path_join(ProfileStore.PRIMARY_FILE)) == future_text, "direct commit cannot overwrite a future schema")

	var future_backup_directory := root_directory.path_join("future_backup_only")
	_prepare_directory(future_backup_directory)
	_write_text(future_backup_directory.path_join(ProfileStore.BACKUP_FILE), future_text)
	var future_backup_store := ProfileStore.new(future_backup_directory)
	var future_backup_load := future_backup_store.load_profile()
	var future_backup_commit := future_backup_store.commit(_profile_with_character())
	_check(not future_backup_load["ok"] and future_backup_load["read_only"] and not future_backup_commit["ok"], "future backup without a primary cannot be bypassed by direct commit")
	_check(_read_text(future_backup_directory.path_join(ProfileStore.BACKUP_FILE)) == future_text and not FileAccess.file_exists(future_backup_directory.path_join(ProfileStore.PRIMARY_FILE)), "rejected future-backup commit preserves bytes and does not install a primary")

	var guarded_backup_directory := root_directory.path_join("future_backup_with_primary")
	_prepare_directory(guarded_backup_directory)
	var guarded_store := ProfileStore.new(guarded_backup_directory)
	var guarded_initial := guarded_store.commit(_profile_with_character())
	_write_text(guarded_backup_directory.path_join(ProfileStore.BACKUP_FILE), future_text)
	var guarded_primary_text := _read_text(guarded_backup_directory.path_join(ProfileStore.PRIMARY_FILE))
	var guarded_commit := guarded_store.commit(guarded_initial["profile"])
	_check(not guarded_commit["ok"] and guarded_commit["read_only"], "future backup is protected even when a current primary exists")
	_check(_read_text(guarded_backup_directory.path_join(ProfileStore.PRIMARY_FILE)) == guarded_primary_text and _read_text(guarded_backup_directory.path_join(ProfileStore.BACKUP_FILE)) == future_text, "blocked commit preserves both current primary and future backup")

	for artifact_kind: String in ["valid_backup", "corrupt_backup", "pending"]:
		var artifact_directory := root_directory.path_join(artifact_kind + "_commit_block")
		_prepare_directory(artifact_directory)
		var artifact_name := ProfileStore.PENDING_FILE if artifact_kind == "pending" else ProfileStore.BACKUP_FILE
		var artifact_text: String = backup_profile["text"] if artifact_kind != "corrupt_backup" else "broken backup"
		_write_text(artifact_directory.path_join(artifact_name), artifact_text)
		var artifact_commit := ProfileStore.new(artifact_directory).commit(_profile_with_character())
		_check(not artifact_commit["ok"] and artifact_commit["error_code"] == &"recovery_required" and artifact_commit["read_only"], "%s blocks normal commit when primary is absent" % artifact_kind)
		_check(_read_text(artifact_directory.path_join(artifact_name)) == artifact_text and not FileAccess.file_exists(artifact_directory.path_join(ProfileStore.PRIMARY_FILE)), "%s remains intact after rejected commit" % artifact_kind)

	var catalog_directory := root_directory.path_join("catalog_incompatible")
	_prepare_directory(catalog_directory)
	var catalog_payload: Dictionary = backup_profile["data"].duplicate(true)
	catalog_payload["catalog_version"] = 2
	var catalog_text := JSON.stringify(catalog_payload)
	_write_text(catalog_directory.path_join(ProfileStore.PRIMARY_FILE), catalog_text)
	_write_text(catalog_directory.path_join(ProfileStore.BACKUP_FILE), backup_profile["text"])
	var catalog_result := ProfileStore.new(catalog_directory).load_profile()
	_check(not catalog_result["ok"] and catalog_result["error_code"] == &"invalid_catalog" and catalog_result["read_only"], "catalog-incompatible schema 2 is blocked instead of treated as corruption")
	_check(_read_text(catalog_directory.path_join(ProfileStore.PRIMARY_FILE)) == catalog_text, "catalog-incompatible primary is preserved without backup rollback")

	var invalid_directory := root_directory.path_join("invalid")
	_prepare_directory(invalid_directory)
	_write_text(invalid_directory.path_join(ProfileStore.PRIMARY_FILE), "invalid primary")
	_write_text(invalid_directory.path_join(ProfileStore.BACKUP_FILE), "invalid backup")
	var invalid_result := ProfileStore.new(invalid_directory).load_profile()
	_check(not invalid_result["ok"] and invalid_result["error_code"] == &"recovery_required", "two invalid durable files require explicit recovery")
	_check(_read_text(invalid_directory.path_join(ProfileStore.PRIMARY_FILE)) == "invalid primary" and _read_text(invalid_directory.path_join(ProfileStore.BACKUP_FILE)) == "invalid backup", "failed recovery does not overwrite either invalid original")

	var pending_directory := root_directory.path_join("pending_only")
	_prepare_directory(pending_directory)
	_write_text(pending_directory.path_join(ProfileStore.PENDING_FILE), ProfileCodec.encode(_profile_with_character())["text"])
	var pending_result := ProfileStore.new(pending_directory).load_profile()
	_check(not pending_result["ok"] and pending_result["error_code"] == &"recovery_required" and not FileAccess.file_exists(pending_directory.path_join(ProfileStore.PRIMARY_FILE)), "an orphan pending file is isolated and never promoted")

	var empty_directory := root_directory.path_join("empty")
	_prepare_directory(empty_directory)
	var empty_result := ProfileStore.new(empty_directory).load_profile()
	_check(empty_result["ok"] and empty_result["created_empty"] and empty_result["profile"].characters.is_empty(), "absence of all profile files creates an unsaved empty schema-2 state")
	_check(not empty_result["profile"].profile_id.is_empty() and not FileAccess.file_exists(empty_directory.path_join(ProfileStore.PRIMARY_FILE)), "empty state receives a UUID without touching disk")

func _check_v1_migration() -> void:
	var directory := root_directory.path_join("migration")
	_prepare_directory(directory)
	var legacy := {
		"schema_version": 1,
		"equipment_collection": {"swordsman": ["training_sword", "lost_relic"], "mage": ["training_sword"]},
		"equipped": {"swordsman": {"weapon": "training_sword", "armor": null, "accessory": null}},
		"settings": {"legacy_volume": 0.5},
		"lifetime_stats": {"kills": 7},
	}
	var legacy_text := JSON.stringify(legacy)
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), legacy_text)
	var migration_catalog := _catalog_with_training_sword()
	var store := ProfileStore.new(directory, migration_catalog)
	var migrated := store.load_profile()
	_check(migrated["ok"] and migrated["migrated"] and migrated["warning"] == &"profile_migrated", "recognized schema 1 migrates once to schema 2")
	var profile: ProfileState = migrated["profile"]
	_check(profile.characters.is_empty() and profile.equipment_collection == [&"training_sword"], "migration never invents characters or duplicate known equipment")
	_check(profile.unresolved_legacy["equipment_ids"] == ["lost_relic"] and profile.legacy_loadouts.has("swordsman"), "unknown equipment and legacy loadouts remain recoverable")
	_check(_read_text(directory.path_join(ProfileStore.BACKUP_FILE)) == legacy_text, "migration preserves the original schema-1 file as backup")
	var reloaded := store.load_profile()
	_check(reloaded["ok"] and not reloaded.get("migrated", false) and reloaded["profile"].revision == 1, "reloading migrated schema 2 is idempotent")

	var backup_directory := root_directory.path_join("migration_from_backup")
	_prepare_directory(backup_directory)
	_write_text(backup_directory.path_join(ProfileStore.BACKUP_FILE), legacy_text)
	var backup_migration := ProfileStore.new(backup_directory, migration_catalog).load_profile()
	_check(backup_migration["ok"] and backup_migration["migrated"] and backup_migration["recovered"] and backup_migration["warning"] == &"profile_migrated_from_backup", "schema-1 backup can be recovered and migrated without a primary")
	_check(ProfileCodec.decode(_read_text(backup_directory.path_join(ProfileStore.PRIMARY_FILE)), migration_catalog)["ok"], "backup migration installs a validated schema-2 primary")

func _catalog_with_training_sword() -> ProfileCatalog:
	return ProfileCatalog.pilot({
		&"training_sword": {"slot": &"weapon", "allowed_base_classes": [&"swordsman"]},
	})

func _profile_with_character() -> ProfileState:
	var profile := ProfileState.new(PROFILE_ID)
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Ana", &"swordsman")
	character.base_xp_total = 350
	character.job_xp_total = 80
	character.attribute_allocations[&"str"] = 3
	character.presets[0]["active_slots"][0] = &"slash"
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	return profile

func _decode_file(path: String) -> Dictionary:
	return ProfileCodec.decode(_read_text(path))

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write test fixture: %s" % path)
		return
	file.store_string(text)
	file.close()

func _prepare_directory(path: String) -> void:
	_cleanup_directory(path)
	DirAccess.make_dir_recursive_absolute(path)

func _cleanup_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	for child: String in directory.get_directories():
		_cleanup_directory(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _files_beginning_with(path: String, prefix: String) -> PackedStringArray:
	var matches := PackedStringArray()
	var directory := DirAccess.open(path)
	if directory == null:
		return matches
	for file_name: String in directory.get_files():
		if file_name.begins_with(prefix):
			matches.append(file_name)
	return matches

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
