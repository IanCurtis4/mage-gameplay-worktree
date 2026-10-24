@tool
extends RefCounted
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")

static func _bytes(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return Schema.result(false, "io_missing")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return Schema.result(false, "io_failure")
	if file.get_length() > StrictJSON.MAX_BYTES:
		file.close()
		return Schema.result(false, "source_limit_exceeded")
	var bytes := file.get_buffer(file.get_length())
	var complete := file.get_position() == file.get_length()
	file.close()
	return {"ok": complete, "code": "" if complete else "io_failure", "bytes": bytes}

static func load_source(path: String) -> Dictionary:
	var raw := _bytes(path)
	if not raw.ok: return raw
	return Schema.read(raw.bytes)

static func disk_hash(path: String) -> String:
	if not FileAccess.file_exists(path): return ""
	var raw := _bytes(path)
	return Schema.bytes_hash(raw.bytes) if raw.ok else "unreadable"

static func _write(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and disk_hash(path) == Schema.bytes_hash(bytes)

static func save_source(path: String, data: Dictionary, expected_hash: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(path.get_base_dir()): return Schema.result(false, "io_failure")
	# Atomic directory creation serializes cooperating GUI/CLI writers.
	var lock_path := path + ".writer_lock"
	if DirAccess.make_dir_absolute(lock_path) != OK: return Schema.result(false, "io_writer_locked")
	var result := _save_locked(path, data, expected_hash)
	DirAccess.remove_absolute(lock_path)
	return result

static func _save_locked(path: String, data: Dictionary, expected_hash: String) -> Dictionary:
	var bytes := JSON.stringify(data, "\t", true, true).to_utf8_buffer()
	var checked := Schema.read(bytes)
	if not checked.ok: return checked
	if disk_hash(path) != expected_hash: return Schema.result(false, "io_conflict")
	# Preserve any interrupted staging file; recovery is explicit, never auto-promoted.
	var pending := path + ".pending"
	if FileAccess.file_exists(pending): return Schema.result(false, "io_recovery_pending")
	if not _write(pending, bytes): return Schema.result(false, "io_failure")
	var staged := load_source(pending)
	if not staged.ok or staged.output_hash != checked.output_hash: return Schema.result(false, "io_failure")
	if disk_hash(path) != expected_hash: return Schema.result(false, "io_conflict")
	if not expected_hash.is_empty():
		var prior := load_source(path)
		if not prior.ok: return Schema.result(false, "io_recovery_required")
		var backup_pending := path + ".bak.pending"
		if FileAccess.file_exists(backup_pending): return Schema.result(false, "io_recovery_pending")
		var prior_raw := _bytes(path)
		if not prior_raw.ok or not _write(backup_pending, prior_raw.bytes): return Schema.result(false, "io_failure")
		if DirAccess.rename_absolute(backup_pending, path + ".bak") != OK: return Schema.result(false, "io_failure")
	if disk_hash(path) != expected_hash: return Schema.result(false, "io_conflict")
	if DirAccess.rename_absolute(pending, path) != OK: return Schema.result(false, "io_failure")
	checked.byte_hash = Schema.bytes_hash(bytes)
	checked.expected_byte_hash = expected_hash
	return checked

static func autosave(path: String, data: Dictionary, base_hash: String) -> Dictionary:
	var checked := Schema.read(JSON.stringify(data, "", true, true).to_utf8_buffer())
	if not checked.ok: return checked
	var envelope := {"recovery_version": 1, "base_hash": base_hash, "source": data}
	var bytes := JSON.stringify(envelope, "", true, true).to_utf8_buffer()
	if bytes.size() > StrictJSON.MAX_BYTES: return Schema.result(false, "source_limit_exceeded")
	var temporary := path + ".autosave.pending"
	if FileAccess.file_exists(temporary): return Schema.result(false, "io_recovery_pending")
	if not _write(temporary, bytes): return Schema.result(false, "io_failure")
	if DirAccess.rename_absolute(temporary, path + ".autosave") != OK: return Schema.result(false, "io_failure")
	return checked

static func recover(path: String, kind: String) -> Dictionary:
	if kind not in ["autosave", "pending", "bak", "autosave.pending", "bak.pending"]: return Schema.result(false, "io_recovery_invalid")
	var candidate := path + "." + kind
	if kind in ["pending", "bak", "bak.pending"]:
		var source := load_source(candidate)
		if source.ok:
			source.base_hash = "unknown"
			source.disk_hash = disk_hash(path)
		return source
	var raw := _bytes(candidate)
	if not raw.ok: return raw
	var decoded: Dictionary = StrictJSON.new().decode(raw.bytes)
	if not decoded.ok: return decoded
	var envelope: Variant = decoded.value
	if not envelope is Dictionary or envelope.size() != 3 or envelope.get("recovery_version") != 1 or not envelope.get("base_hash") is String or not envelope.get("source") is Dictionary: return Schema.result(false, "io_recovery_invalid")
	var checked := Schema.read(JSON.stringify(envelope.source, "", true, true).to_utf8_buffer())
	if checked.ok:
		checked.base_hash = envelope.base_hash
		checked.disk_hash = disk_hash(path)
		checked.base_diverged = checked.disk_hash != checked.base_hash
	return checked
