extends SceneTree
const Store = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const Compiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var result: Dictionary = {"ok":false,"code":"arguments_missing"}
	if args.size() in [1,2]:
		result = Store.load_source(args[0])
		if result.ok: result = Compiler.compile(result.data)
		if result.ok and args.size() == 2: result = Store.publish(args[1],result.package,result.input_hash)
	result.erase("package"); result.erase("data")
	print("MAP_PATROL_RESULT "+JSON.stringify(result)); quit(0 if result.ok else 1)
