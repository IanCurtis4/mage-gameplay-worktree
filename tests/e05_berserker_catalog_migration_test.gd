extends SceneTree
const H = preload("res://tests/fixtures/e07/f2/confirmed_history.gd")
const TX = preload("res://tests/e06_tx_fixture.gd")

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
	var encoded := ProfileCodec.encode(profile, ProfileCatalog.pilot().pre_swordsman_cluster_catalog())
	_check(encoded["ok"] and ProfileState.CATALOG_VERSION == 14, "historical fixture encodes under its previous rules before schema6/catalog14 migration")
	var old_data: Dictionary = TX.legacy_data(encoded["data"])
	old_data["catalog_version"] = ProfileCodec.PRE_BERSERKER_CATALOG_VERSION
	old_data["ruleset_id"] = ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	var old_text := JSON.stringify(old_data, "\t")
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), old_text)
	var decoded := H.decode_confirmed(old_text)
	_check(decoded["ok"] and decoded["migration_kind"] == &"catalog_v3" and &"swordsman_clusters_v1" in decoded["migration_kinds"] and decoded["profile"].revision == 7, "catalog3 fixture migrates with explicit cluster refund without changing decode revision")
	var loaded := H.load_confirmed(ProfileStore.new(directory))
	_check(loaded["ok"] and loaded["migrated"] and loaded["profile"].revision == 8, "store commits one transactional migration revision")
	var durable: CharacterState = loaded["profile"].character_by_id(character_id)
	_check(durable.evolution_id == &"defender" and durable.purchased_skill_ranks.is_empty() and durable.presets[0]["active_slots"][0] == &"defender_anchor" and decoded["migration_removals"][0]["evolution_refund"] == 1 and durable.base_xp_total == character.base_xp_total and durable.job_xp_total == character.job_xp_total, "migration refunds illegal Anchor without buying Shield and preserves Defender identity/XP")
	var current_data: Dictionary = JSON.parse_string(_read_text(directory.path_join(ProfileStore.PRIMARY_FILE)))
	_check(_read_text(directory.path_join(ProfileStore.BACKUP_FILE)) == old_text and current_data["catalog_version"] == ProfileState.CATALOG_VERSION and current_data["ruleset_id"] == ProfileState.RULESET_ID and current_data["schema_version"] == ProfileState.SCHEMA_VERSION, "backup preserves exact catalog-3 source bytes")
	var reloaded := H.load_confirmed(ProfileStore.new(directory))
	_check(reloaded["ok"] and not reloaded.get("migrated", false) and reloaded["profile"].revision == 8, "current catalog reload is idempotent")
	var newer := profile.copy_state()
	newer.revision = 9
	var newer_data: Dictionary = TX.legacy_data(ProfileCodec.encode(newer, ProfileCatalog.pilot().pre_swordsman_cluster_catalog())["data"])
	newer_data["catalog_version"] = ProfileCodec.PRE_BERSERKER_CATALOG_VERSION
	newer_data["ruleset_id"] = ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	_assert_protected_backup(old_text, JSON.stringify(newer_data, "\t"), "newer same-profile catalog-3 backup")
	var foreign := ProfileState.new("123e4567-e89b-42d3-a456-426614174069")
	var foreign_data: Dictionary = TX.legacy_data(ProfileCodec.encode(foreign)["data"])
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
	var result := H.load_confirmed(ProfileStore.new(directory))
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
