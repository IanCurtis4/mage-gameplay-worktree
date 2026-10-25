extends SceneTree
const Store = preload("res://scripts/map_authoring/composition/map_store.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var result: Dictionary = {"ok":false,"code":"arguments_missing"}
	if args.size() >= 1:
		result = Store.load_source(args[0])
		if result.ok: result = Compiler.compile(result.data)
		if result.ok and args.size() == 2: result = Store.publish(args[1],result.package,result.input_hash)
	result.erase("package"); result.erase("data")
	print("MAP_COMPOSITION_RESULT "+JSON.stringify(result)); quit(0 if result.ok else 1)
