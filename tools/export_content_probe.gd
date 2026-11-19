extends SceneTree
## Inspect a PCK's runtime catalog without opening user:// profile data.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1 or args.size() > 2 or not FileAccess.file_exists(args[0]):
		push_error("Usage: export_content_probe.gd -- <absolute .pck path> [loader patch .zip]")
		quit(2)
		return
	if not ProjectSettings.load_resource_pack(args[0], true):
		push_error("Could not load PCK")
		quit(2)
		return
	if args.size() == 2 and not ProjectSettings.load_resource_pack(args[1], true):
		push_error("Could not load loader patch ZIP")
		quit(2)
		return
	var loader: GDScript = load("res://scripts/core/build_content_loader.gd")
	if loader == null:
		push_error("Could not load BuildContentLoader from PCK")
		quit(2)
		return
	# F10 Q4 added the five published forest species to the runtime catalog.
	# E09 T8 (A15) added the four e09_* equipment items: 85→89.
	# E10a T9 added three e10a_* items (89→92) and T11 six augments (31→37); exact counts (T13).
	var expected := {&"mob": 16, &"equipment": 92, &"card": 6, &"augment": 37, &"set": 14}
	var forest_species: Array[StringName] = [&"forest_wolf", &"forest_boar", &"forest_stalker", &"forest_canopy_archer", &"forest_ancient_warden"]
	var failures := 0
	for origin: StringName in expected:
		var directory := "res://resources/build_effects/%s" % origin
		var files := DirAccess.get_files_at(directory)
		var definitions: Array = loader.call("definitions", origin, true)
		var remapped := 0
		for file: String in files:
			if file.ends_with(".tres.remap"):
				remapped += 1
		print("PACK_FILES ", origin, " ", files.size(), " remapped=", remapped)
		if not files.is_empty():
			var logical_path := directory.path_join(files[0].trim_suffix(".remap"))
			print("PACK_SAMPLE_LOAD ", origin, " ", load(logical_path) != null)
		print("PACK_DEFINITIONS ", origin, " ", definitions.size())
		if definitions.size() != expected[origin]:
			failures += 1
	var loaded: Dictionary = loader.call("load_catalog", true)
	if not loaded.get("ok", false):
		push_error("PACK_CATALOG " + JSON.stringify(loaded))
		quit(1)
		return
	var catalog: Object = loaded["catalog"]
	var mob_ids: Array = (catalog.call("mob_catalog") as Object).call("ids")
	for origin: StringName in expected:
		var count: int = mob_ids.size() if origin == &"mob" else (catalog.get("_sets").size() if origin == &"set" else catalog.call("ids", origin).size())
		print("PACK_CATALOG_COUNT ", origin, " ", count)
		if origin != &"augment" and count != expected[origin]:
			failures += 1
	for species: StringName in forest_species:
		if species not in mob_ids:
			push_error("PACK_MISSING_FOREST_SPECIES " + String(species))
			failures += 1
	print("PACK_PROBE failures=", failures)
	quit(1 if failures else 0)
