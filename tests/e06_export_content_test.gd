extends SceneTree
## Run against source or as an external script with --main-pack <export.pck>.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var loader: GDScript = load("res://scripts/core/build_content_loader.gd")
	if loader == null:
		push_error("BuildContentLoader unavailable")
		quit(1)
		return
	var expected := {&"mob": 11, &"equipment": 85, &"card": 6, &"augment": 31, &"set": 14}
	var failures := 0
	var checked := 0
	for origin: StringName in expected:
		var definitions: Array = loader.call("definitions", origin, true)
		checked += 1
		if definitions.size() != expected[origin]:
			push_error("%s: expected %d resources, found %d" % [origin, expected[origin], definitions.size()])
			failures += 1
		var ids: Dictionary = {}
		for definition: Resource in definitions:
			checked += 1
			if definition == null or StringName(definition.get("id")) in ids:
				push_error("%s: null or duplicate definition" % origin)
				failures += 1
			else:
				ids[StringName(definition.get("id"))] = true
	var loaded: Dictionary = loader.call("load_catalog", true)
	checked += 1
	if not loaded.get("ok", false):
		push_error("Catalog failed to load: " + JSON.stringify(loaded))
		failures += 1
	else:
		var catalog: Object = loaded["catalog"]
		var mobs: Object = catalog.call("mob_catalog")
		for origin: StringName in [&"mob", &"equipment", &"card", &"set"]:
			var count: int = mobs.call("ids").size() if origin == &"mob" else (catalog.get("_sets").size() if origin == &"set" else catalog.call("ids", origin).size())
			checked += 1
			if count != expected[origin]:
				push_error("%s: catalog count %d differs from %d" % [origin, count, expected[origin]])
				failures += 1
	print("E06_EXPORT_CONTENT checks=%d failures=%d" % [checked, failures])
	quit(1 if failures else 0)
