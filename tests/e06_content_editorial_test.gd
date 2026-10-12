extends SceneTree
const Demo = preload("res://tools/content/demo_bundle.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _run() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/demo_texts.json"))
	_check(raw is Dictionary, "actual creative document is parseable")
	if not raw is Dictionary: quit(1); return
	var compiled := ContentAuthoring.compile_bundle(Demo.entries(), raw)
	_check(compiled["ok"] and compiled.get("ready", false), "actual creative batch is complete and bound to current mechanics")
	if not compiled["ok"]: print(compiled); quit(1); return
	var loaded_entries: Array[Dictionary] = []
	var directory := "res://.godot/verification/e06_content_editorial_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	for entry: Dictionary in compiled["entries"]:
		var item: Resource = entry["definition"]
		_check(not item.display_name.is_empty() and not item.flavor_text.is_empty() and not item.description.is_empty() and item.flavor_text != item.description, "actual entry separates name, narrative and factual description")
		var path := directory.path_join("%s_%s.tres" % [entry["origin"], item.id])
		_check(ResourceSaver.save(item, path) == OK, "actual entry can save as native Resource")
		var loaded := load(path) as Resource
		_check(loaded != null and loaded.display_name == item.display_name and loaded.flavor_text == item.flavor_text and loaded.description == item.description, "native resource roundtrip preserves all three prose fields")
		loaded_entries.append({"origin": entry["origin"], "definition": loaded, "purpose": entry["purpose"]})
	var reloaded := ContentAuthoring.prepare(loaded_entries)
	_check(reloaded["ok"] and reloaded["mechanical_digest"] == compiled["mechanical_digest"], "all native Resource roundtrips preserve complete mechanic fingerprint")
	var production := BuildContentLoader.load_catalog()
	_check(production["ok"], "existing production catalog still loads")
	if production["ok"]:
		var catalog: BuildEffectCatalog = production["catalog"]
		for entry: Dictionary in compiled["entries"]:
			var absent := false
			if entry["origin"] == &"mob": absent = catalog.mob_catalog().get_definition(entry["definition"].id) == null
			elif entry["origin"] == &"set": absent = catalog.get_set(entry["definition"].id) == null
			else: absent = catalog.get_definition(entry["origin"], entry["definition"].id) == null
			_check(absent, "prepared demo entry cannot silently enter production loader")
	print("E06 content editorial: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
