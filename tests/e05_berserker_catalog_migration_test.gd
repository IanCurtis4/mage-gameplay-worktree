extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174068"

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_berserker_catalog_migration")
	_cleanup_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	_run()

func _run() -> void:
	var profile := ProfileState.new(PROFILE_ID)
	profile.revision = 7
	profile.next_character_counter = 2
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Legado Defendente", &"swordsman")
	character.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	character.evolution_id = &"defender"
	character.purchased_skill_ranks[&"defender_anchor"] = 1
	character.presets[0]["active_slots"][0] = &"defender_anchor"
	profile.characters.append(character)
	profile.selected_character_id = character_id
	var encoded := ProfileCodec.encode(profile)
	_check(encoded["ok"] and ProfileState.CATALOG_VERSION == 8, "current catalog remains schema 2 and accepts earlier Berserker migration")
	var old_data: Dictionary = encoded["data"].duplicate(true)
	old_data["catalog_version"] = ProfileCodec.PRE_BERSERKER_CATALOG_VERSION
	old_data["ruleset_id"] = ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	var old_text := JSON.stringify(old_data, "\t")
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), old_text)
	var decoded := ProfileCodec.decode(old_text)
	_check(decoded["ok"] and decoded["migration_kind"] == &"catalog_v3" and decoded["profile"].revision == 7, "catalog-3 save migrates additively without changing revision")
	var loaded := ProfileStore.new(directory).load_profile()
	_check(loaded["ok"] and loaded["migrated"] and loaded["profile"].revision == 8, "store commits one transactional migration revision")
	var durable: CharacterState = loaded["profile"].character_by_id(character_id)
	_check(durable.evolution_id == &"defender" and durable.purchased_skill_ranks == {&"defender_anchor": 1} and durable.presets[0]["active_slots"][0] == &"defender_anchor" and durable.base_xp_total == character.base_xp_total and durable.job_xp_total == character.job_xp_total, "migration preserves existing Defender build and XP")
	var current_data: Dictionary = JSON.parse_string(_read_text(directory.path_join(ProfileStore.PRIMARY_FILE)))
	_check(_read_text(directory.path_join(ProfileStore.BACKUP_FILE)) == old_text and current_data["catalog_version"] == ProfileState.CATALOG_VERSION and current_data["ruleset_id"] == ProfileState.RULESET_ID and current_data["schema_version"] == 2, "backup preserves exact catalog-3 source bytes")
	var reloaded := ProfileStore.new(directory).load_profile()
	_check(reloaded["ok"] and not reloaded.get("migrated", false) and reloaded["profile"].revision == 8, "current catalog reload is idempotent")
	var newer := profile.copy_state()
	newer.revision = 9
	var newer_data: Dictionary = ProfileCodec.encode(newer)["data"].duplicate(true)
	newer_data["catalog_version"] = ProfileCodec.PRE_BERSERKER_CATALOG_VERSION
	newer_data["ruleset_id"] = ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	_assert_protected_backup(old_text, JSON.stringify(newer_data, "\t"), "newer same-profile catalog-3 backup")
	var foreign := ProfileState.new("123e4567-e89b-42d3-a456-426614174069")
	var foreign_data: Dictionary = ProfileCodec.encode(foreign)["data"].duplicate(true)
	foreign_data["catalog_version"] = ProfileCodec.PRE_BERSERKER_CATALOG_VERSION
	foreign_data["ruleset_id"] = ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	_assert_protected_backup(old_text, JSON.stringify(foreign_data, "\t"), "different-profile catalog-3 backup")
	_cleanup_directory()
	print("E05 Berserker migração catálogo: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _assert_protected_backup(primary_text: String, backup_text: String, description: String) -> void:
	_cleanup_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), primary_text)
	_write_text(directory.path_join(ProfileStore.BACKUP_FILE), backup_text)
	var result := ProfileStore.new(directory).load_profile()
	_check(not result["ok"] and result["error_code"] == &"recovery_required" and result.get("read_only", false), "%s requires read-only recovery" % description)
	_check(_read_text(directory.path_join(ProfileStore.PRIMARY_FILE)) == primary_text and _read_text(directory.path_join(ProfileStore.BACKUP_FILE)) == backup_text and not FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "%s preserves both files byte-for-byte" % description)

func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _cleanup_directory() -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file_name))
	DirAccess.remove_absolute(directory)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
