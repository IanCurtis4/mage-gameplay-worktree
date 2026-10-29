@tool
extends RefCounted
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const JSONReader = preload("res://scripts/map_authoring/io/strict_json.gd")
const Population = preload("res://scripts/map_authoring/population/population_document.gd")
const ROOT := {"schema_version":"int","document_id":"id","revision":"int","name":"string","population":"array","patrols":"array"}
const ROUTE := {"patrol_id":"id","revision":"int","mode":"id","slot_ids":"strings","waypoints":"array"}
const WAYPOINT := {"point_id":"id","surface_id":"string","position_xyz":"v3","wait_seconds":"number"}
static func empty(id: String = "patrols") -> Dictionary:
	return {"schema_version":1,"document_id":id,"revision":1,"name":"Patrulhas","population":[],"patrols":[]}
static func hash_source(data: Dictionary) -> String:
	var copy := data.duplicate(true)
	copy.patrols.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.patrol_id < b.patrol_id)
	for route: Dictionary in copy.patrols: route.slot_ids.sort()
	if not copy.population.is_empty(): copy.population = [Population.hash_source(copy.population[0])]
	return Schema.semantic_hash(copy)
static func read(bytes: PackedByteArray) -> Dictionary:
	var result := JSONReader.new().decode(bytes)
	return validate(result.value) if result.ok else Schema.result(false,result.code)
static func validate(raw: Variant) -> Dictionary:
	var errors: Array = []; Schema._shape(raw,ROOT,"patrols",errors)
	if not errors.is_empty(): return Schema.result(false,"patrol_invalid",errors)
	if raw.schema_version != 1: return Schema.result(false,"patrol_version")
	if raw.population.size() > 1 or raw.patrols.size() > 16: return Schema.result(false,"patrol_limit")
	var slots: Dictionary = {}
	if not raw.population.is_empty():
		var checked := Population.validate(raw.population[0])
		if not checked.ok: return checked
		for slot: Dictionary in raw.population[0].slots: slots[slot.slot_id] = true
	var ids: Dictionary = {}; var assigned: Dictionary = {}
	for route: Variant in raw.patrols:
		Schema._shape(route,ROUTE,"route",errors)
		if not errors.is_empty(): return Schema.result(false,"patrol_invalid",errors)
		if ids.has(route.patrol_id): return Schema.result(false,"duplicate_identity")
		ids[route.patrol_id] = true
		if route.mode not in ["loop","ping_pong"] or route.waypoints.size() > 32 or route.slot_ids.size() > 128: return Schema.result(false,"patrol_invalid")
		var points: Dictionary = {}
		for waypoint: Variant in route.waypoints:
			Schema._shape(waypoint,WAYPOINT,"waypoint",errors)
			if not errors.is_empty(): return Schema.result(false,"patrol_invalid",errors)
			if points.has(waypoint.point_id) or waypoint.wait_seconds < 0 or waypoint.wait_seconds > 300: return Schema.result(false,"patrol_invalid")
			points[waypoint.point_id] = true
		for id: String in route.slot_ids:
			if not slots.has(id): return Schema.result(false,"patrol_slot_missing")
			if assigned.has(id): return Schema.result(false,"patrol_slot_duplicate")
			assigned[id] = true
	var result := Schema.result(true); result.data = raw.duplicate(true); result.output_hash = hash_source(raw); return result
