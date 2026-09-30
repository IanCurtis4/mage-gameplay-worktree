extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174180"

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_spiritualist_catalog_migration")
	_cleanup()
	DirAccess.make_dir_recursive_absolute(directory)
	_run()

func _run() -> void:
	var profile := ProfileState.new(PROFILE_ID)
	profile.revision = 12
	profile.next_character_counter = 3
	var evolved_id := IdentityIds.character_id(PROFILE_ID, 1)
	var evolved := CharacterState.new(evolved_id, "Elementalista preservado", &"mage")
	evolved.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	evolved.job_xp_total = ProgressionRules.MAX_JOB_XP
	evolved.evolution_id = &"elementalist"
	evolved.purchased_skill_ranks[&"elementalist_glacial_ring"] = 1
	evolved.presets[0]["active_slots"][0] = &"elementalist_glacial_ring"
	profile.characters.append(evolved)
	var mage_id := IdentityIds.character_id(PROFILE_ID, 2)
	var mage := CharacterState.new(mage_id, "Mago preservado", &"mage")
	mage.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	mage.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	mage.purchased_skill_ranks[&"soul_impact"] = 1
	mage.presets[0]["active_slots"][0] = &"soul_impact"
	profile.characters.append(mage)
	profile.selected_character_id = evolved_id
	var encoded := ProfileCodec.encode(profile)
	_check(encoded["ok"] and ProfileState.SCHEMA_VERSION == 2 and ProfileState.CATALOG_VERSION == 6, "Spiritualist catalog increments only catalog version")
	if not encoded["ok"]:
		_finish()
		return
	var old_data: Dictionary = encoded["data"].duplicate(true)
	old_data["catalog_version"] = ProfileCodec.PRE_SPIRITUALIST_CATALOG_VERSION
	var old_text := JSON.stringify(old_data, "\t")
	_write(ProfileStore.PRIMARY_FILE, old_text)
	var decoded := ProfileCodec.decode(old_text)
	_check(decoded["ok"] and decoded["migrated"] and decoded["migration_kind"] == &"catalog_v5" and decoded["profile"].revision == 12, "catalog 5 decodes additively in memory")
	var loaded := ProfileStore.new(directory).load_profile()
	_check(loaded["ok"] and loaded["migrated"] and loaded["profile"].revision == 13, "store migrates once in an isolated transaction")
	var durable: ProfileState = loaded["profile"]
	_check(durable.selected_character_id == evolved_id and durable.characters.size() == 2 and durable.character_by_id(evolved_id).evolution_id == &"elementalist" and durable.character_by_id(mage_id).evolution_id.is_empty(), "both identities and selection survive")
	_check(durable.character_by_id(evolved_id).purchased_skill_ranks == {&"elementalist_glacial_ring": 1} and durable.character_by_id(evolved_id).presets[0]["active_slots"][0] == &"elementalist_glacial_ring" and durable.character_by_id(mage_id).purchased_skill_ranks == {&"soul_impact": 1}, "paid ranks and presets remain exact")
	_check(durable.character_by_id(evolved_id).job_xp_total == evolved.job_xp_total and durable.character_by_id(mage_id).job_xp_total == mage.job_xp_total, "both XP totals remain exact")
	var current_data: Dictionary = JSON.parse_string(_read(ProfileStore.PRIMARY_FILE))
	_check(_read(ProfileStore.BACKUP_FILE) == old_text and current_data["catalog_version"] == ProfileState.CATALOG_VERSION, "backup retains exact catalog-5 bytes")
	var reloaded := ProfileStore.new(directory).load_profile()
	_check(reloaded["ok"] and not reloaded.get("migrated", false) and reloaded["profile"].revision == 13, "subsequent load is idempotent")
	var future: Dictionary = current_data.duplicate(true)
	future["catalog_version"] = ProfileState.CATALOG_VERSION + 1
	var future_text := JSON.stringify(future, "\t")
	_check(not ProfileCodec.decode(future_text)["ok"], "future catalog remains incompatible")
	_cleanup()
	DirAccess.make_dir_recursive_absolute(directory)
	_write(ProfileStore.PRIMARY_FILE, future_text)
	var rejected := ProfileStore.new(directory).load_profile()
	_check(not rejected["ok"] and rejected.get("read_only", false) and _read(ProfileStore.PRIMARY_FILE) == future_text and not FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "future primary remains byte-identical and read only")
	_assert_backup_guard(old_text, profile, true)
	_assert_backup_guard(old_text, profile, false)
	_finish()

func _assert_backup_guard(primary_text: String, original: ProfileState, newer: bool) -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(directory)
	_write(ProfileStore.PRIMARY_FILE, primary_text)
	var candidate := original.copy_state() if newer else ProfileState.new("123e4567-e89b-42d3-a456-426614174181")
	if newer:
		candidate.revision += 2
	var encoded := ProfileCodec.encode(candidate)
	var data: Dictionary = encoded["data"].duplicate(true)
	data["catalog_version"] = ProfileCodec.PRE_SPIRITUALIST_CATALOG_VERSION
	var backup_text := JSON.stringify(data, "\t")
	_write(ProfileStore.BACKUP_FILE, backup_text)
	var loaded := ProfileStore.new(directory).load_profile()
	_check(not loaded["ok"] and loaded["error_code"] == &"recovery_required" and loaded.get("read_only", false), "newer or foreign catalog-5 backup blocks migration")
	_check(_read(ProfileStore.PRIMARY_FILE) == primary_text and _read(ProfileStore.BACKUP_FILE) == backup_text and not FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "blocked migration preserves both exact files")

func _write(file_name: String, value: String) -> void:
	var file := FileAccess.open(directory.path_join(file_name), FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _read(file_name: String) -> String:
	return FileAccess.get_file_as_string(directory.path_join(file_name))

func _cleanup() -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file_name))
	DirAccess.remove_absolute(directory)

func _finish() -> void:
	_cleanup()
	print("E05 Espiritualista migração catálogo: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
