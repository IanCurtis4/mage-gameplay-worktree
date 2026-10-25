extends SceneTree
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
const Compiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var result := Compiler.failure("arguments_invalid")
	if args.size() == 1:
		var source := Store.load_source(args[0])
		result = Compiler.compile(source.data) if source.ok else source
	if result.has("package"):
		result.piece_count = result.package.piece_count
		result.grid_quads = result.package.grid_quads
		result.support_count = result.package.part.surfaces.size()
		result.connections = result.package.adjacency.size()
		result.erase("package")
	print("MAP_TERRAIN_RESULT " + JSON.stringify(result))
	quit(0 if result.ok else 1)
