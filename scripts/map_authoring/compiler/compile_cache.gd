@tool
extends RefCounted
## Checkpoint42 (F9-10): verifiable on-disk cache of compiled map and population
## packages, shared by the editor, its worker processes and headless tools.
## Key = kind + compiler revision + canonical source hash + environment hash (every
## script, the expedition data, the authoring content and the map-editor assets and
## catalogs the compilers read). A hit is accepted only if the stored package passes
## the compiler's own validate_package (which re-derives the package hash) and names
## the same source hash. Exported builds never compile, so they never use it.
## Opt-in through RAGRPG_COMPILE_CACHE=1: the editor plugin sets it for the editor
## and the worker processes it spawns (unless already set); test runners set 0 so
## every test compiles for real.
const ROOT := "res://.godot/map_authoring/cache"
const FORMAT := 1
const MAX_FILES := 24
const MAX_BYTES := 96 * 1024 * 1024
const HASH_ROOTS := ["res://scripts","res://content","res://data/expedition","res://assets/art/map_authoring"]
const HASH_FILES := ["res://data/map_authoring/prop_catalog.json","res://data/map_authoring/border_profiles.json","res://data/map_authoring/asset_manifest.json"]
static var _environment := ""
static var _mutex := Mutex.new()

static func enabled() -> bool:
	return not OS.has_feature("template") and OS.get_environment("RAGRPG_COMPILE_CACHE") == "1"

## sha256 over the sorted (path, sha256) of every input file; once per process.
static func environment_hash() -> String:
	_mutex.lock()
	var cached := _environment
	_mutex.unlock()
	if not cached.is_empty(): return cached
	var paths: Array[String] = []
	for root: String in HASH_ROOTS: _collect(root, paths)
	for path: String in HASH_FILES:
		if FileAccess.file_exists(path): paths.append(path)
	paths.sort()
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	for path: String in paths: context.update((path + "\n" + FileAccess.get_sha256(path) + "\n").to_utf8_buffer())
	var value := context.finish().hex_encode()
	_mutex.lock(); _environment = value; _mutex.unlock()
	return value

static func _collect(directory: String, paths: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(directory):
		if file.ends_with(".uid"): continue
		paths.append(directory.path_join(file))
	for child: String in DirAccess.get_directories_at(directory):
		if child.begins_with("."): continue
		_collect(directory.path_join(child), paths)

static func key(kind: String, revision: String, source_hash: String) -> String:
	if not enabled() or source_hash.is_empty(): return ""
	return ("%s|%s|%s|%s|%d" % [kind, revision, source_hash, environment_hash(), FORMAT]).sha256_text()

static func _path(kind: String, cache_key: String) -> String:
	return ROOT.path_join(kind + "_" + cache_key + ".bin")

## {"ok":true,"package":...} for a stored entry whose header matches; the caller
## still runs its validate_package before trusting it.
static func fetch(kind: String, cache_key: String, source_hash: String) -> Dictionary:
	if cache_key.is_empty(): return {"ok":false}
	var path := _path(kind, cache_key)
	if not FileAccess.file_exists(path): return {"ok":false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return {"ok":false}
	var record: Variant = bytes_to_var(file.get_buffer(file.get_length())); file.close()
	if not record is Dictionary or record.size() != 5 or record.get("format") != FORMAT or record.get("kind") != kind or record.get("key") != cache_key or not record.get("package") is Dictionary: return {"ok":false}
	var package: Dictionary = record["package"]
	if package.get("source_hash") != source_hash or package.get("package_hash") != record.get("output_hash"): return {"ok":false}
	return {"ok":true,"package":package}

static func store(kind: String, cache_key: String, package: Dictionary) -> void:
	if cache_key.is_empty() or not package.has("package_hash") or not package.has("source_hash"): return
	var bytes := var_to_bytes({"format":FORMAT,"kind":kind,"key":cache_key,"output_hash":package.package_hash,"package":package})
	if bytes.size() > MAX_BYTES: return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var path := _path(kind, cache_key)
	var temporary := path + ".tmp" + str(OS.get_process_id())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return
	file.store_buffer(bytes); file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary)); return
	_prune()

# Newest kept first; older entries go beyond MAX_FILES or MAX_BYTES.
static func _prune() -> void:
	var root := ProjectSettings.globalize_path(ROOT)
	var entries: Array = []; var total := 0
	for name: String in DirAccess.get_files_at(root):
		if not name.ends_with(".bin"): continue
		var full := root.path_join(name)
		var reader := FileAccess.open(full, FileAccess.READ)
		var size := reader.get_length() if reader != null else 0
		if reader != null: reader.close()
		entries.append([FileAccess.get_modified_time(full), full, size]); total += size
	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var kept := 0; var bytes := 0
	for entry: Array in entries:
		kept += 1; bytes += int(entry[2])
		if kept > MAX_FILES or bytes > MAX_BYTES: DirAccess.remove_absolute(entry[1])
