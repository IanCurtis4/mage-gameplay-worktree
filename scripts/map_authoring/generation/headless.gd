extends SceneTree
const Store = preload("res://scripts/map_authoring/generation/generation_store.gd")
const Solver = preload("res://scripts/map_authoring/generation/generation_solver.gd")
const Assembler = preload("res://scripts/map_authoring/generation/assembler_adapter.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[1] not in ["--experimental-wfc","--assembler"]:
		print('MAP_GENERATION_RESULT {"ok":false,"code":"usage: source.json --experimental-wfc|--assembler"}'); quit(1); return
	var source := Store.load_source(args[0])
	var result: Dictionary = source
	if source.ok: result = Solver.new().solve(source.data,true) if args[1] == "--experimental-wfc" else Assembler.build(source.data)
	# CLI is a proposal/diagnostic operation; publication remains M3's local flow.
	result.erase("package")
	result.erase("before_package")
	print("MAP_GENERATION_RESULT "+JSON.stringify(result,"",true,true))
	quit(0 if result.ok else 1)
