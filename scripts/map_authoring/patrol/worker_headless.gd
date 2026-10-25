extends SceneTree
const Compiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var result: Dictionary = Compiler.fail("worker_invalid_request")
	var raw := FileAccess.get_file_as_bytes(args[0])
	if raw.size() <= 8*1024*1024:
		var payload: Variant = bytes_to_var(raw)
		if payload is Dictionary:
			if payload.get("source") is Dictionary: result = Compiler.compile(payload.source)
			elif payload.get("package") is Dictionary: result = {"ok":Compiler.validate_package(payload.package)}
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_buffer(var_to_bytes(result)); file.close(); quit(0 if result.ok else 1)
