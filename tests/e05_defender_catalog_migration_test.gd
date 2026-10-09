extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174066"

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_defender_catalog_migration")
	_cleanup_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	_run()

func _run() -> void:
	var profile := ProfileState.new(PROFILE_ID)
	profile.revision = 4
	profile.next_character_counter = 2
	profile.next_run_counter = 3
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Legado E05", &"swordsman")
	character.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	character.job_xp_total = ProgressionRules.EVOLUTION_MIN_JOB_XP
	character.evolution_id = &"defender"
	character.purchased_skill_ranks[&"slash"] = 1
	character.presets[0]["active_slots"][0] = &"slash"
	profile.characters.append(character)
	profile.selected_character_id = character_id
	var encoded := ProfileCodec.encode(profile)
	_check(encoded["ok"] and ProfileState.SCHEMA_VERSION == 2 and ProfileState.CATALOG_VERSION == 9, "current catalog keeps schema 2 and accepts the earlier Defender migration")
	var old_data: Dictionary = encoded["data"].duplicate(true)
	old_data["catalog_version"] = ProfileCodec.PRE_DEFENDER_CATALOG_VERSION
	old_data["ruleset_id"] = ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	var old_text := JSON.stringify(old_data, "\t")
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), old_text)
	var decoded := ProfileCodec.decode(old_text)
	_check(decoded["ok"] and decoded["migrated"] and decoded["migration_kind"] == &"catalog_v2" and decoded["profile"].revision == 4, "catalog-2 payload is accepted without changing in-memory progression")
	var store := ProfileStore.new(directory)
	var loaded := store.load_profile()
	_check(loaded["ok"] and loaded["migrated"] and loaded["profile"].revision == 5, "store commits one atomic catalog migration revision")
	var migrated_character: CharacterState = loaded["profile"].character_by_id(character_id)
	_check(migrated_character.evolution_id == &"defender" and migrated_character.purchased_skill_ranks == {&"slash": 1} and migrated_character.presets[0]["active_slots"][0] == &"slash" and migrated_character.base_xp_total == character.base_xp_total and migrated_character.job_xp_total == character.job_xp_total, "migration preserves identity, XP, purchases and preset")
	var backup_text := _read_text(directory.path_join(ProfileStore.BACKUP_FILE))
	var durable_data: Dictionary = JSON.parse_string(_read_text(directory.path_join(ProfileStore.PRIMARY_FILE)))
	_check(backup_text == old_text and durable_data["catalog_version"] == ProfileState.CATALOG_VERSION and durable_data["ruleset_id"] == ProfileState.RULESET_ID and durable_data["schema_version"] == 2, "transaction preserves exact old bytes as backup and writes current catalog")
	var reloaded := ProfileStore.new(directory).load_profile()
	_check(reloaded["ok"] and not reloaded.get("migrated", false) and reloaded["profile"].revision == 5, "catalog migration is idempotent on reload")
	var future_data: Dictionary = durable_data.duplicate(true)
	future_data["catalog_version"] = ProfileState.CATALOG_VERSION + 1
	var future := ProfileCodec.decode(JSON.stringify(future_data))
	_check(not future["ok"] and future["error_code"] == &"invalid_catalog", "unknown future catalog stays incompatible")
	_check_catalog_backup_guard(profile, old_text)
	_cleanup_directory()
	print("E05 Defendente migração catálogo: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_backup_guard(source: ProfileState, primary_text: String) -> void:
	var newer := source.copy_state()
	newer.revision = source.revision + 5
	var newer_encoded := ProfileCodec.encode(newer)
	var newer_data: Dictionary = newer_encoded["data"].duplicate(true)
	newer_data["catalog_version"] = ProfileCodec.PRE_DEFENDER_CATALOG_VERSION
	newer_data["ruleset_id"] = ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	var newer_text := JSON.stringify(newer_data, "\t")
	_assert_protected_backup(primary_text, newer_text, "newer same-profile catalog-2 backup")
	var foreign := ProfileState.new("123e4567-e89b-42d3-a456-426614174067")
	foreign.revision = 1
	var foreign_encoded := ProfileCodec.encode(foreign)
	var foreign_data: Dictionary = foreign_encoded["data"].duplicate(true)
	foreign_data["catalog_version"] = ProfileCodec.PRE_DEFENDER_CATALOG_VERSION
	foreign_data["ruleset_id"] = ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	var foreign_text := JSON.stringify(foreign_data, "\t")
	_assert_protected_backup(primary_text, foreign_text, "different-profile catalog-2 backup")
	_cleanup_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var older := source.copy_state()
	older.revision = source.revision - 1
	var older_encoded := ProfileCodec.encode(older)
	var older_data: Dictionary = older_encoded["data"].duplicate(true)
	older_data["catalog_version"] = ProfileCodec.PRE_DEFENDER_CATALOG_VERSION
	older_data["ruleset_id"] = ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), primary_text)
	_write_text(directory.path_join(ProfileStore.BACKUP_FILE), JSON.stringify(older_data, "\t"))
	var migrated := ProfileStore.new(directory).load_profile()
	_check(migrated["ok"] and migrated.get("migrated", false) and migrated["profile"].revision == source.revision + 1, "compatible older catalog-2 backup permits normal migration")
	_check(_read_text(directory.path_join(ProfileStore.BACKUP_FILE)) == primary_text, "successful migration preserves exact former primary as backup")

func _assert_protected_backup(primary_text: String, backup_text: String, description: String) -> void:
	_cleanup_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), primary_text)
	_write_text(directory.path_join(ProfileStore.BACKUP_FILE), backup_text)
	var result := ProfileStore.new(directory).load_profile()
	_check(not result["ok"] and result["error_code"] == &"recovery_required" and result.get("read_only", false), "%s requires read-only recovery" % description)
	_check(_read_text(directory.path_join(ProfileStore.PRIMARY_FILE)) == primary_text and _read_text(directory.path_join(ProfileStore.BACKUP_FILE)) == backup_text and not FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "%s preserves both payloads byte-for-byte" % description)

func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var value := file.get_as_text()
	file.close()
	return value

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _cleanup_directory() -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file_name))
	DirAccess.remove_absolute(directory)
