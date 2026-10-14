extends SceneTree

const Bundle = preload("res://tools/content/inventory_fixes_bundle.gd")

func _initialize() -> void:
	var counts := {&"equipment": 0, &"set": 0}
	var ids: Dictionary = {}
	for entry: Dictionary in Bundle.entries():
		var definition: Resource = entry.get("definition")
		if definition == null:
			push_error("Bundle entry missing Resource definition")
			quit(1)
			return
		var id := StringName(definition.get("id"))
		if id.is_empty() or ids.has(id):
			push_error("Bundle ID missing or duplicated: %s" % id)
			quit(1)
			return
		ids[id] = true
		counts[entry["origin"]] = int(counts.get(entry["origin"], 0)) + 1
	if counts[&"equipment"] != 46 or counts[&"set"] != 13:
		push_error("Unexpected inventory batch counts: %s" % counts)
		quit(1)
		return
	var loaded := BuildContentLoader.load_catalog(true)
	if not loaded["ok"]:
		push_error("Production catalog failed: %s" % loaded)
		quit(1)
		return
	var catalog: BuildEffectCatalog = loaded["catalog"]
	var table: MobLootTable = EquipmentLootProfiles.production(catalog)
	var created := MobLootResolver.create(catalog, table)
	if not created["ok"]:
		push_error("Production MobLootResolver.create failed: %s" % created)
		quit(1)
		return
	print("inventory_fixes_probe ok equipment=%d sets=%d unique_ids=%d production_equipment=%d resolver=ok" % [counts[&"equipment"], counts[&"set"], ids.size(), catalog.ids(&"equipment").size()])
	quit()
