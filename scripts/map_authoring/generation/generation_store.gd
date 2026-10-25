@tool
extends RefCounted
const Document = preload("res://scripts/map_authoring/generation/generation_document.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
static func load_source(path: String) -> Dictionary:
	var raw := IO._bytes(path)
	return Document.read(raw.bytes) if raw.ok else raw
static func save_source(path: String, source: Dictionary, expected: String) -> Dictionary:
	var checked := Document.read(JSON.stringify(source,"\t",true,true).to_utf8_buffer())
	if not checked.ok: return checked
	var lock := path+".writer_lock"
	if DirAccess.make_dir_absolute(lock) != OK: return Document.fail("io_writer_locked")
	var result := _save(path,source,expected)
	DirAccess.remove_absolute(lock)
	return result
static func _save(path: String, source: Dictionary, expected: String) -> Dictionary:
	if IO.disk_hash(path) != expected: return Document.fail("io_conflict")
	if FileAccess.file_exists(path+".pending") or FileAccess.file_exists(path+".bak.pending"): return Document.fail("io_recovery_pending")
	if not IO._write(path+".pending",JSON.stringify(source,"\t",true,true).to_utf8_buffer()): return Document.fail("io_failure")
	var staged := load_source(path+".pending")
	if not staged.ok or staged.output_hash != Document.hash_source(source): return Document.fail("io_failure")
	if expected != "":
		var prior := load_source(path)
		var raw := IO._bytes(path)
		if not prior.ok or not raw.ok or not IO._write(path+".bak.pending",raw.bytes): return Document.fail("io_failure")
		if DirAccess.rename_absolute(path+".bak.pending",path+".bak") != OK: return Document.fail("io_failure")
	if IO.disk_hash(path) != expected: return Document.fail("io_conflict")
	if DirAccess.rename_absolute(path+".pending",path) != OK: return Document.fail("io_failure")
	return {"ok":true,"code":"","output_hash":Document.hash_source(source)}
