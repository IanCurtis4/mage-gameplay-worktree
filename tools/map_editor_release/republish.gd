extends SceneTree
## F10 Q4: republishes a released map from its committed source with the real
## producer (patrol compiler, which compiles its encounters), after a catalog
## change made the pinned package stale. Same checks as the editor's publish step:
## a new immutable package file, the source unchanged, the registry re-pinned.
## Usage: --headless --path <project> --script res://tools/map_editor_release/republish.gd -- <package_id>
## or, for a reference package outside the registry: -- --file <source.json> <package.rpp>
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")
const Patrol = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const Store = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 3 and args[0] == "--file": _file(args[1],args[2]); return
	if args.size() != 1: _done({"ok":false,"code":"arguments_invalid"}); return
	var read := MapRelease.entry(args[0])
	if not read.ok: _done(read); return
	var entry: Dictionary = read.entry
	var source_read: Dictionary = Store.load_source(entry.source_path)
	if not source_read.ok: _done(source_read); return
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var started := Time.get_ticks_usec()
	var compiled := Patrol.compile(source_read.data)
	var compile_ms := (Time.get_ticks_usec()-started)/1000.0
	if not compiled.ok: _done(compiled); return
	if compiled.package.source_hash != entry.source_hash: _done({"ok":false,"code":"source_changed","detail":[compiled.package.source_hash,entry.source_hash]}); return
	var current := MapRelease._current(MapRelease.FOLDER)
	if not current.ok: _done(current); return
	var published := MapRelease.publish(entry.package_id,entry.name,compiled.package,source_read.data,current.registry_hash)
	published["compile_ms"] = compile_ms; published["previous_package_hash"] = entry.package_hash
	_done(published)
## Rewrites a reference package (same bytes format as a publication) from its
## committed source; the source itself is not touched.
func _file(source_path: String, package_path: String) -> void:
	var source_read: Dictionary = Store.load_source(source_path)
	if not source_read.ok: _done(source_read); return
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var compiled := Patrol.compile(source_read.data)
	if not compiled.ok: _done(compiled); return
	var scratch := "res://.godot/republish"
	var written := Store.publish(scratch,compiled.package,compiled.package.source_hash)
	if not written.ok: _done(written); return
	var bytes := FileAccess.get_file_as_bytes(written.path)
	var file := FileAccess.open(package_path,FileAccess.WRITE)
	if file == null: _done({"ok":false,"code":"release_io"}); return
	file.store_buffer(bytes); file.close()
	_done({"ok":Store.load_package(package_path).ok,"package_hash":compiled.package.package_hash,"source_hash":compiled.package.source_hash,"path":package_path})

func _done(result: Dictionary) -> void:
	print("F10_REPUBLISH_RESULT "+JSON.stringify(result))
	quit(0 if result.get("ok",false) else 1)
