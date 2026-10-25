extends SceneTree
const Compiler = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var decoded := StrictJSON.new().decode(FileAccess.get_file_as_bytes(args[0]))
	var result: Dictionary = {"ok":false,"code":"worker_request_invalid","diagnostics":[]}
	if decoded.ok and decoded.value is Dictionary:
		var request: Dictionary = decoded.value
		match request.get("operation",""):
			"catalog":
				var loaded := Catalog.load_current()
				if loaded.ok: result = {"ok":true,"options":Catalog.options(loaded.catalog),"catalog_hash":loaded.hash,"policy_hash":loaded.policy_hash}
			"compile":
				if request.get("source") is Dictionary: result = Compiler.compile(request.source)
			"regenerate":
				if request.get("source") is Dictionary: result = Compiler.regenerate(request.source)
			"validate":
				if request.get("package_path") is String:
					var candidate: Variant = bytes_to_var(FileAccess.get_file_as_bytes(request.package_path))
					result = {"ok":candidate is Dictionary and Compiler.validate_package(candidate),"code":"package_invalid"}
			"campaign":
				if request.get("package_path") is String:
					var candidate: Variant = bytes_to_var(FileAccess.get_file_as_bytes(request.package_path))
					if candidate is Dictionary:
						var made := Compiler.make_campaign(candidate)
						if made.ok:
							var data: Dictionary = {}
							for field: String in ["expedition_id","character_id","manifest_data","policy","current_stage_id","lifecycle","stages","slots","population_rules","anchor","entry_claims","death_events","current_death_id","objectives","traversed_edges","completed"]: data[field] = made.state.get(field)
							result = {"ok":true,"state_data":data,"clock_interval":made.state.clock.interval}
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_buffer(var_to_bytes(result)); file.close(); quit(0 if result.ok else 1)
