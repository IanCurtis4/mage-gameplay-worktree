class_name BuildContentLoader
extends RefCounted
## Resource files are the single metadata source. T3 can add recipes without code edits.

# Never return a cached registry: BuildEffectCatalog copies Resources on both ingress and egress.
static var _catalog_cache: Dictionary = {}

static func _definitions_in(directory: String) -> Array[Resource]:
	var result: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(directory):
		return result
	var files := DirAccess.get_files_at(directory)
	var paths: Dictionary = {}
	for file: String in files:
		var resource_file := file.trim_suffix(".remap") if file.ends_with(".tres.remap") else file
		if resource_file.ends_with(".tres"):
			paths[resource_file] = true
	var names: Array = paths.keys()
	names.sort()
	for file: String in names:
		var definition := load(directory.path_join(file)) as Resource
		result.append(definition.duplicate(true) if definition != null else null)
	return result

static func definitions(origin: StringName, include_progression: bool = false) -> Array[Resource]:
	var directory := "res://resources/build_effects/%s" % origin
	var result := _definitions_in(directory)
	if include_progression and origin in [&"equipment", &"mob"]:
		var extra := "res://resources/loot_progression/equipment" if origin == &"equipment" else "res://resources/playtest_gameplay/mob"
		result.append_array(_definitions_in(extra))
		# F10 Q4: species of the first authored phase (forest).
		if origin == &"mob": result.append_array(_definitions_in("res://resources/forest_phase/mob"))
	if include_progression and origin in [&"equipment",&"set"]:
		var content_dir := "res://resources/e06_inventory_content/%s" % origin
		result.append_array(_definitions_in(content_dir))
	return result

static func load_catalog(include_progression: bool = false, gameplay_behaviors: bool = false) -> Dictionary:
	var cache_key := int(include_progression) * 2 + int(gameplay_behaviors)
	if _catalog_cache.has(cache_key):
		return {"ok": true, "error_code": &"", "request_id": "", "catalog": (_catalog_cache[cache_key] as BuildEffectCatalog).copy_catalog()}
	var catalog := BuildEffectCatalog.new()
	var mobs := MobCatalog.new()
	for definition: Resource in definitions(&"mob", include_progression):
		var mob := definition as MobDefinition
		if gameplay_behaviors and mob != null and String(mob.id).begins_with("pilot_"):
			mob.aggro_radius = 420.0
			mob.leash_radius = 850.0
			mob.modifier_sources.append({"source_id": &"trial_pilot_movement", "flat": {&"move_speed": -66.0}})
		var registered := mobs.register_definition(mob)
		if not registered["ok"]:
			return registered
	catalog.set_mob_catalog(mobs)
	for definition: Resource in definitions(&"set", include_progression):
		var registered := catalog.register_set(definition as EquipmentSetDefinition)
		if not registered["ok"]:
			return registered
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for definition: Resource in definitions(origin, include_progression):
			var registered := catalog.register_definition(origin, definition)
			if not registered["ok"]:
				return registered
	var legacy := BuildEffectCatalog.pilot()
	for id: StringName in legacy.ids(&"augment"):
		if catalog.get_definition(&"augment", id) == null:
			var registered := catalog.register_definition(&"augment", legacy.get_definition(&"augment", id))
			if not registered["ok"]:
				return registered
	_catalog_cache[cache_key] = catalog
	return {"ok": true, "error_code": &"", "request_id": "", "catalog": catalog.copy_catalog()}

static func pilot() -> BuildEffectCatalog:
	var loaded := load_catalog(true)
	assert(loaded["ok"], "Catálogo de efeitos inválido")
	return loaded.get("catalog", BuildEffectCatalog.new())

static func load_catalog_for_profile(profile_catalog: ProfileCatalog, gameplay_behaviors: bool = false) -> Dictionary:
	var loaded := load_catalog(true, gameplay_behaviors)
	if not loaded["ok"]:
		return loaded
	var catalog: BuildEffectCatalog = loaded["catalog"]
	# Metadata-only injected catalogs remain valid neutral equipment. Production
	# IDs always keep their Resource effects and never synthesize a second recipe.
	var production_ids: Dictionary = {}
	for id: StringName in catalog.ids(&"equipment"):
		production_ids[id] = true
	for id: StringName in profile_catalog.equipment_ids():
		if production_ids.has(id):
			continue
		var metadata := profile_catalog.equipment_metadata(id)
		var item := EquipmentDefinition.new()
		item.id = id
		item.slot = metadata["slot"]
		item.item_kind = metadata["item_kind"]
		item.hand_usage = metadata["hand_usage"]
		item.origin_id = metadata["origin_id"]
		item.item_level = metadata["item_level"]
		item.quality_id = metadata["quality_id"]
		item.socket_capacity = metadata["socket_capacity"]
		item.allowed_origins.assign(metadata["allowed_base_classes"])
		item.allowed_evolutions.assign(metadata["allowed_evolutions"])
		item.starter = metadata["starter"]
		var registered := catalog.register_definition(&"equipment", item)
		if not registered["ok"]:
			return registered
	return loaded
