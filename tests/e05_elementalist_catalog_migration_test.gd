extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174078"

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_elementalist_catalog_migration")
	_cleanup_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	_run()

func _run() -> void:
	var profile := ProfileState.new(PROFILE_ID)
	profile.revision = 9
	profile.next_character_counter = 3
	var mage_id := IdentityIds.character_id(PROFILE_ID, 1)
	var mage := CharacterState.new(mage_id, "Mago legado", &"mage")
	mage.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	mage.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	mage.purchased_skill_ranks[&"ice_spear"] = 1
	mage.presets[0]["active_slots"][0] = &"ice_spear"
	profile.characters.append(mage)
	var defender_id := IdentityIds.character_id(PROFILE_ID, 2)
	var defender := CharacterState.new(defender_id, "Defendente legado", &"swordsman")
	defender.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	defender.job_xp_total = ProgressionRules.MAX_JOB_XP
	defender.evolution_id = &"defender"
	defender.purchased_skill_ranks[&"defender_anchor"] = 1
	defender.presets[0]["active_slots"][0] = &"defender_anchor"
	profile.characters.append(defender)
	profile.selected_character_id = mage_id
	var encoded := ProfileCodec.encode(profile)
	_check(encoded["ok"] and ProfileState.SCHEMA_VERSION == 2 and ProfileState.CATALOG_VERSION == 5, "new catalog keeps schema and ruleset")
	var old_data: Dictionary = encoded["data"].duplicate(true)
	old_data["catalog_version"] = ProfileCodec.PRE_ELEMENTALIST_CATALOG_VERSION
	var old_text := JSON.stringify(old_data, "\t")
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), old_text)
	var decoded := ProfileCodec.decode(old_text)
	_check(decoded["ok"] and decoded["migration_kind"] == &"catalog_v4" and decoded["profile"].revision == 9, "catalog 4 migrates additively without revision change in codec")
	var loaded := ProfileStore.new(directory).load_profile()
	_check(loaded["ok"] and loaded["migrated"] and loaded["profile"].revision == 10, "store commits migration transaction once")
	var durable: ProfileState = loaded["profile"]
	_check(durable.selected_character_id == mage_id and durable.characters.size() == 2 and durable.character_by_id(mage_id).purchased_skill_ranks == {&"ice_spear": 1} and durable.character_by_id(defender_id).purchased_skill_ranks == {&"defender_anchor": 1}, "characters, selection and builds survive")
	_check(durable.character_by_id(mage_id).base_xp_total == mage.base_xp_total and durable.character_by_id(mage_id).job_xp_total == mage.job_xp_total and durable.character_by_id(defender_id).job_xp_total == defender.job_xp_total, "XP remains exact")
	var current_data: Dictionary = JSON.parse_string(_read_text(directory.path_join(ProfileStore.PRIMARY_FILE)))
	_check(_read_text(directory.path_join(ProfileStore.BACKUP_FILE)) == old_text and current_data["catalog_version"] == 5 and current_data["ruleset_id"] == ProfileState.RULESET_ID, "backup retains exact source bytes")
	var reloaded := ProfileStore.new(directory).load_profile()
	_check(reloaded["ok"] and not reloaded.get("migrated", false) and reloaded["profile"].revision == 10, "current catalog reload is idempotent")
	var newer := profile.copy_state()
	newer.revision = 11
	var newer_data: Dictionary = ProfileCodec.encode(newer)["data"].duplicate(true)
	newer_data["catalog_version"] = ProfileCodec.PRE_ELEMENTALIST_CATALOG_VERSION
	_assert_protected_backup(old_text, JSON.stringify(newer_data, "\t"), "newer catalog-4 backup")
	var foreign := ProfileState.new("123e4567-e89b-42d3-a456-426614174079")
	var foreign_data: Dictionary = ProfileCodec.encode(foreign)["data"].duplicate(true)
	foreign_data["catalog_version"] = ProfileCodec.PRE_ELEMENTALIST_CATALOG_VERSION
	_assert_protected_backup(old_text, JSON.stringify(foreign_data, "\t"), "foreign catalog-4 backup")
	_cleanup_directory()
	print("E05 Elementalista migração catálogo: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _assert_protected_backup(primary_text: String, backup_text: String, description: String) -> void:
	_cleanup_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), primary_text)
	_write_text(directory.path_join(ProfileStore.BACKUP_FILE), backup_text)
	var result := ProfileStore.new(directory).load_profile()
	_check(not result["ok"] and result["error_code"] == &"recovery_required" and result.get("read_only", false), "%s requires read-only recovery" % description)
	_check(_read_text(directory.path_join(ProfileStore.PRIMARY_FILE)) == primary_text and _read_text(directory.path_join(ProfileStore.BACKUP_FILE)) == backup_text and not FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "%s preserves both files exactly" % description)

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
