extends SceneTree
const Store = preload("res://scripts/map_authoring/composition/map_store.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Session = preload("res://scripts/map_authoring/composition/map_session.gd")
const Reader = preload("res://scripts/map_authoring/io/strict_json.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var result: Dictionary = {"ok":false,"code":"arguments_missing"}
	if args.size() == 5 and args[0] == "--border-command":
		result = Store.load_source(args[1])
		if result.ok:
			var session := Session.new(); session.replace(result.data)
			var request := Reader.new().decode(FileAccess.get_file_as_bytes(args[2])); var errors: Array = []
			if request.ok: Store.Schema._shape(request.value,{"expected_source_hash":"hash","command":"object"},"border_request",errors)
			if not request.ok or not errors.is_empty(): result = {"ok":false,"code":"arguments_invalid"}
			else:
				result = session.apply_border(request.value.command,request.value.expected_source_hash)
				if result.ok:
					var diff: Dictionary = result.diff
					result = Store.save_source(args[3],session.data,"" if args[4] == "-" else args[4]); result["diff"] = diff
	elif args.size() >= 1 and args[0] != "--border-command":
		result = Store.load_source(args[0])
		if result.ok: result = Compiler.compile(result.data)
		if result.ok and args.size() == 2: result = Store.publish(args[1],result.package,result.input_hash)
	result.erase("package"); result.erase("data")
	print("MAP_COMPOSITION_RESULT "+JSON.stringify(result)); quit(0 if result.ok else 1)
