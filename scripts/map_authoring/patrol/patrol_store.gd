@tool
extends RefCounted
const Document = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const Compiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
static func load_source(path: String) -> Dictionary:
	var raw := IO._bytes(path)
	if not raw.ok: return raw
	var checked := Document.read(raw.bytes)
	if checked.ok: checked.byte_hash = Schema.bytes_hash(raw.bytes)
	return checked
static func save_source(path: String, data: Dictionary, expected: String) -> Dictionary:
	var checked := Document.read(JSON.stringify(data,"\t",true,true).to_utf8_buffer())
	if not checked.ok: return checked
	var lock := path+".writer_lock"
	if DirAccess.make_dir_absolute(lock) != OK: return Schema.result(false,"io_writer_locked")
	var result := _save_locked(path,data,expected)
	DirAccess.remove_absolute(lock); return result
static func _save_locked(path: String, data: Dictionary, expected: String) -> Dictionary:
	if IO.disk_hash(path) != expected: return Schema.result(false,"io_conflict")
	if FileAccess.file_exists(path+".pending"): return Schema.result(false,"io_recovery_pending")
	var bytes := JSON.stringify(data,"\t",true,true).to_utf8_buffer()
	if not IO._write(path+".pending",bytes): return Schema.result(false,"io_failure")
	var staged := load_source(path+".pending")
	if not staged.ok or staged.output_hash != Document.hash_source(data): return Schema.result(false,"io_failure")
	if expected != "":
		var raw := IO._bytes(path)
		if not raw.ok or not IO._write(path+".bak",raw.bytes): return Schema.result(false,"io_failure")
	if IO.disk_hash(path) != expected: return Schema.result(false,"io_conflict")
	if DirAccess.rename_absolute(path+".pending",path) != OK: return Schema.result(false,"io_failure")
	return {"ok":true,"code":"","byte_hash":Schema.bytes_hash(bytes)}
static func publish(root: String, package: Dictionary, current_hash: String) -> Dictionary:
	if not Compiler.validate_package(package): return Schema.result(false,"package_invalid")
	if package.source_hash != current_hash: return Compiler.fail("stale_source")
	var payload := var_to_bytes(package)
	var bytes := ("RPP1"+Schema.bytes_hash(payload)).to_utf8_buffer()+payload
	if bytes.size() > Compiler.MAX_PACKAGE_BYTES: return Compiler.fail("patrol_limit")
	DirAccess.make_dir_recursive_absolute(root)
	var path := root.path_join(package.package_hash+".rpp")
	var lock := path+".writer_lock"
	if DirAccess.make_dir_absolute(lock) != OK: return Schema.result(false,"io_writer_locked")
	var result := _publish_locked(path,package,bytes)
	DirAccess.remove_absolute(lock); return result
static func _publish_locked(path: String, package: Dictionary, bytes: PackedByteArray) -> Dictionary:
	if FileAccess.file_exists(path):
		var prior := load_package(path)
		if not prior.ok or prior.package != package: return Schema.result(false,"immutable_conflict")
		return {"ok":true,"code":"","path":path,"package_hash":package.package_hash}
	if FileAccess.file_exists(path+".pending"): return Schema.result(false,"io_recovery_pending")
	if not IO._write(path+".pending",bytes): return Schema.result(false,"io_failure")
	var staged := load_package(path+".pending")
	if not staged.ok or staged.package != package: return Schema.result(false,"io_failure")
	if DirAccess.rename_absolute(path+".pending",path) != OK: return Schema.result(false,"io_failure")
	return {"ok":true,"code":"","path":path,"package_hash":package.package_hash}
static func load_package(path: String) -> Dictionary:
	var raw := IO._bytes(path)
	if not raw.ok: return raw
	if raw.bytes.size() > Compiler.MAX_PACKAGE_BYTES: return Schema.result(false,"patrol_limit")
	# bytes_to_var (without _with_objects) never instantiates executable objects.
	if raw.bytes.size() < 72 or raw.bytes.slice(0,4).get_string_from_utf8() != "RPP1": return Schema.result(false,"package_invalid")
	var payload: PackedByteArray = raw.bytes.slice(68)
	if Schema.bytes_hash(payload) != raw.bytes.slice(4,68).get_string_from_utf8(): return Schema.result(false,"package_invalid")
	var decoded: Variant = bytes_to_var(payload)
	if not decoded is Dictionary or not Compiler.validate_package(decoded): return Schema.result(false,"package_invalid")
	return {"ok":true,"code":"","package":decoded}
