class_name ProfileStore
extends RefCounted
## Durable profile storage. Tests must pass an explicit temporary directory.

const PRIMARY_FILE := "profile.json"
const BACKUP_FILE := "profile.backup.json"
const PENDING_FILE := "profile.pending.json"

var _base_directory: String
var _catalog: ProfileCatalog
var _write_in_progress := false

func _init(base_directory: String = "user://", catalog: ProfileCatalog = null) -> void:
	var requested_directory := base_directory if not base_directory.strip_edges().is_empty() else "user://"
	_base_directory = requested_directory if requested_directory.ends_with("://") else requested_directory.trim_suffix("/").trim_suffix("\\")
	var requested_catalog := catalog if catalog != null else ProfileCatalog.pilot()
	_catalog = requested_catalog.copy_catalog()

func load_profile() -> Dictionary:
	var primary_exists := FileAccess.file_exists(_path(PRIMARY_FILE))
	var backup_exists := FileAccess.file_exists(_path(BACKUP_FILE))
	var pending_exists := FileAccess.file_exists(_path(PENDING_FILE))
	if primary_exists:
		var primary_result := _read_and_decode(PRIMARY_FILE)
		if primary_result["ok"]:
			if primary_result.get("migrated", false):
				return _commit_migration(primary_result["profile"])
			return primary_result
		if _must_preserve_incompatible(primary_result):
			return {"ok": false, "error_code": primary_result["error_code"], "read_only": true}
		if backup_exists:
			var recovery := _recover_from_backup(true)
			if recovery["ok"]:
				return recovery
			if _must_preserve_incompatible(recovery):
				return {"ok": false, "error_code": recovery["error_code"], "read_only": true}
		return {"ok": false, "error_code": &"recovery_required", "read_only": true}
	if backup_exists:
		var recovery := _recover_from_backup(false)
		if recovery["ok"]:
			return recovery
		if _must_preserve_incompatible(recovery):
			return {"ok": false, "error_code": recovery["error_code"], "read_only": true}
		return {"ok": false, "error_code": &"recovery_required", "read_only": true}
	if pending_exists:
		return {"ok": false, "error_code": &"recovery_required", "read_only": true}
	return {"ok": true, "profile": ProfileState.new(IdentityIds.new_profile_id()), "created_empty": true, "migrated": false}

func commit(source: ProfileState) -> Dictionary:
	return _commit(source, false)

func catalog_copy() -> ProfileCatalog:
	return _catalog.copy_catalog()

func _commit(source: ProfileState, allow_v1_migration: bool) -> Dictionary:
	if _write_in_progress:
		return {"ok": false, "error_code": &"save_in_progress"}
	_write_in_progress = true
	var preflight := _preflight_commit(source, allow_v1_migration)
	if not preflight["ok"]:
		_write_in_progress = false
		return preflight
	var candidate := source.copy_state()
	candidate.revision += 1
	var encoded := ProfileCodec.encode(candidate, _catalog)
	if not encoded["ok"]:
		_write_in_progress = false
		return encoded
	var result := _write_transaction(encoded["text"], candidate)
	_write_in_progress = false
	return result

func _write_transaction(text: String, candidate: ProfileState) -> Dictionary:
	if _should_fail(&"write_pending"):
		return {"ok": false, "error_code": &"save_failed"}
	if DirAccess.make_dir_recursive_absolute(_absolute_base_directory()) != OK and not DirAccess.dir_exists_absolute(_absolute_base_directory()):
		return {"ok": false, "error_code": &"save_failed"}
	var pending := FileAccess.open(_path(PENDING_FILE), FileAccess.WRITE)
	if pending == null:
		return {"ok": false, "error_code": &"save_failed"}
	pending.store_string(text)
	pending.flush()
	var write_error := pending.get_error()
	pending.close()
	if write_error != OK:
		return {"ok": false, "error_code": &"save_failed"}
	if _should_fail(&"validate_pending"):
		return {"ok": false, "error_code": &"save_failed"}
	var pending_result := _read_and_decode(PENDING_FILE)
	if not pending_result["ok"] or pending_result.get("migrated", false) or pending_result["profile"].revision != candidate.revision:
		return {"ok": false, "error_code": &"save_failed"}
	if FileAccess.file_exists(_path(PRIMARY_FILE)):
		if _should_fail(&"backup") or DirAccess.copy_absolute(_absolute_path(PRIMARY_FILE), _absolute_path(BACKUP_FILE)) != OK:
			return {"ok": false, "error_code": &"save_failed"}
	if _should_fail(&"replace") or DirAccess.rename_absolute(_absolute_path(PENDING_FILE), _absolute_path(PRIMARY_FILE)) != OK:
		return {"ok": false, "error_code": &"save_failed"}
	return {"ok": true, "profile": candidate, "new_revision": candidate.revision}

func _commit_migration(migrated_profile: ProfileState) -> Dictionary:
	var result := _commit(migrated_profile, true)
	if result["ok"]:
		result["migrated"] = true
		result["warning"] = &"profile_migrated"
	return result

func _recover_from_backup(preserve_corrupt_primary: bool) -> Dictionary:
	var backup_result := _read_and_decode(BACKUP_FILE)
	if not backup_result["ok"]:
		return backup_result
	if preserve_corrupt_primary:
		var corrupt_name := "profile.corrupt.%d.%d.json" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
		if DirAccess.copy_absolute(_absolute_path(PRIMARY_FILE), _absolute_path(corrupt_name)) != OK:
			return {"ok": false, "error_code": &"recovery_required"}
	if DirAccess.copy_absolute(_absolute_path(BACKUP_FILE), _absolute_path(PENDING_FILE)) != OK:
		return {"ok": false, "error_code": &"recovery_required"}
	var pending_result := _read_and_decode(PENDING_FILE)
	if not pending_result["ok"]:
		return {"ok": false, "error_code": &"recovery_required"}
	if DirAccess.rename_absolute(_absolute_path(PENDING_FILE), _absolute_path(PRIMARY_FILE)) != OK:
		return {"ok": false, "error_code": &"recovery_required"}
	if backup_result.get("migrated", false):
		var migration := _commit_migration(backup_result["profile"])
		if migration["ok"]:
			migration["recovered"] = true
			migration["warning"] = &"profile_migrated_from_backup"
		return migration
	pending_result["warning"] = &"recovered_from_backup"
	pending_result["recovered"] = true
	return pending_result

func _read_and_decode(file_name: String) -> Dictionary:
	var path := _path(file_name)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error_code": &"file_missing"}
	if FileAccess.get_size(path) > ProfileCodec.MAX_FILE_BYTES:
		return {"ok": false, "error_code": &"profile_too_large"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error_code": &"file_unreadable"}
	var text := file.get_as_text()
	file.close()
	return ProfileCodec.decode(text, _catalog)

func _preflight_commit(source: ProfileState, allow_v1_migration: bool) -> Dictionary:
	if not FileAccess.file_exists(_path(PRIMARY_FILE)):
		if FileAccess.file_exists(_path(BACKUP_FILE)) or FileAccess.file_exists(_path(PENDING_FILE)):
			return {"ok": false, "error_code": &"recovery_required", "read_only": true}
		if source.revision != 0:
			return {"ok": false, "error_code": &"stale_revision"}
		return {"ok": true}
	var disk := _read_and_decode(PRIMARY_FILE)
	if not disk["ok"]:
		return {"ok": false, "error_code": disk["error_code"], "read_only": true}
	var backup_guard := _guard_existing_backup(disk)
	if not backup_guard["ok"]:
		return backup_guard
	if disk.get("migrated", false):
		return {"ok": true} if allow_v1_migration and source.revision == 0 else {"ok": false, "error_code": &"unsupported_schema", "read_only": true}
	var disk_profile: ProfileState = disk["profile"]
	if disk_profile.profile_id != source.profile_id or disk_profile.revision != source.revision:
		return {"ok": false, "error_code": &"stale_revision"}
	if source.next_character_counter < disk_profile.next_character_counter or source.next_run_counter < disk_profile.next_run_counter:
		return {"ok": false, "error_code": &"counter_regression"}
	return {"ok": true}

func _guard_existing_backup(primary_result: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(_path(BACKUP_FILE)):
		return {"ok": true}
	var backup := _read_and_decode(BACKUP_FILE)
	if not backup["ok"]:
		if _must_preserve_incompatible(backup):
			return {"ok": false, "error_code": backup["error_code"], "read_only": true}
		return {"ok": true}
	if backup.get("migrated", false):
		return {"ok": true}
	if primary_result.get("migrated", false):
		return {"ok": false, "error_code": &"recovery_required", "read_only": true}
	var primary_profile: ProfileState = primary_result["profile"]
	var backup_profile: ProfileState = backup["profile"]
	if backup_profile.profile_id != primary_profile.profile_id or backup_profile.revision > primary_profile.revision:
		return {"ok": false, "error_code": &"recovery_required", "read_only": true}
	return {"ok": true}

func _path(file_name: String) -> String:
	return _base_directory + file_name if _base_directory.ends_with("://") else _base_directory.path_join(file_name)

func _absolute_base_directory() -> String:
	return ProjectSettings.globalize_path(_base_directory)

func _absolute_path(file_name: String) -> String:
	return ProjectSettings.globalize_path(_path(file_name))

func _should_fail(_stage: StringName) -> bool:
	return false

func _must_preserve_incompatible(result: Dictionary) -> bool:
	return result.get("future_schema", false) or result.get("catalog_incompatible", false) or result.get("error_code", &"") in [&"unsupported_schema", &"invalid_catalog", &"invalid_origin"]
