class_name BuildContentLoader
extends RefCounted
## Resource files are the single metadata source. T3 can add recipes without code edits.

static func definitions(origin: StringName) -> Array[Resource]:
	var result: Array[Resource] = []
	var directory := "res://resources/build_effects/%s" % origin
	if not DirAccess.dir_exists_absolute(directory):
		return result
	var files := DirAccess.get_files_at(directory)
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			var definition := load(directory.path_join(file)) as Resource
			result.append(definition.duplicate(true) if definition != null else null)
	return result

static func load_catalog() -> Dictionary:
	var catalog := BuildEffectCatalog.new()
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for definition: Resource in definitions(origin):
			var registered := catalog.register_definition(origin, definition)
			if not registered["ok"]:
				return registered
	var legacy := BuildEffectCatalog.pilot()
	for id: StringName in legacy.ids(&"augment"):
		if catalog.get_definition(&"augment", id) == null:
			var registered := catalog.register_definition(&"augment", legacy.get_definition(&"augment", id))
			if not registered["ok"]:
				return registered
	return {"ok": true, "error_code": &"", "request_id": "", "catalog": catalog}

static func pilot() -> BuildEffectCatalog:
	var loaded := load_catalog()
	assert(loaded["ok"], "Catálogo de efeitos inválido")
	return loaded.get("catalog", BuildEffectCatalog.new())

static func load_catalog_for_profile(profile_catalog: ProfileCatalog) -> Dictionary:
	var loaded := load_catalog()
	if not loaded["ok"]:
		return loaded
	var catalog: BuildEffectCatalog = loaded["catalog"]
	# Metadata-only injected catalogs remain valid neutral equipment. Production
	# IDs always keep their Resource effects and never synthesize a second recipe.
	for id: StringName in profile_catalog.equipment_ids():
		if catalog.get_definition(&"equipment", id) != null:
			continue
		var metadata := profile_catalog.equipment_metadata(id)
		var item := EquipmentDefinition.new()
		item.id = id
		item.slot = metadata["slot"]
		item.allowed_origins.assign(metadata["allowed_base_classes"])
		item.allowed_evolutions.assign(metadata["allowed_evolutions"])
		item.starter = metadata["starter"]
		var registered := catalog.register_definition(&"equipment", item)
		if not registered["ok"]:
			return registered
	return loaded
