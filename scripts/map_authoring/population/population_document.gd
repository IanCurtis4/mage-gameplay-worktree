@tool
extends RefCounted
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const ROOT := {"schema_version":"int","document_id":"id","revision":"int","name":"string","map":"array","entrance":"array","brushes":"array","exclusions":"array","interactions":"array","slots":"array","plan_hash":"string"}
const ANCHOR := {"surface_id":"string","position_xyz":"v3"}
const BRUSH := {"brush_id":"id","surface_id":"string","center_xyz":"v3","radius":"number","mode":"id","quota_mode":"id","quantity":"number","density":"number","spacing":"number","group_radius":"number","seed":"string","round":"number","species":"array"}
const SPEC := {"species_id":"id","category":"id","origin_id":"id","weight":"int"}
const EXCLUSION := {"exclusion_id":"id","surface_id":"string","center_xyz":"v3","radius":"number"}
## F10 Q2: stage_unlock is the stage objective (sanctuary, switch) of a replay.
const INTERACTION_KINDS := ["portal","phase_completion","early_exit","thematic_encounter","stage_unlock"]
const INTERACTION := {"interaction_id":"id","kind":"id","surface_id":"string","position_xyz":"v3","target_id":"string"}
const SLOT := {"slot_id":"id","brush_id":"id","surface_id":"string","position_xyz":"v3","species_id":"id","category":"id","origin_id":"id","fixed":"bool","site_id":"string"}
static func empty(id: String = "encounters") -> Dictionary:
	return {"schema_version":1,"document_id":id,"revision":1,"name":"Encontros","map":[],"entrance":[],"brushes":[],"exclusions":[],"interactions":[],"slots":[],"plan_hash":""}
static func hash_source(data: Dictionary) -> String:
	var copy := data.duplicate(true)
	for collection: String in ["brushes","exclusions","interactions","slots"]:
		var field: String = {"brushes":"brush_id","exclusions":"exclusion_id","interactions":"interaction_id","slots":"slot_id"}[collection]
		copy[collection].sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a[field] < b[field])
	for brush: Dictionary in copy.brushes:
		brush.species.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return Schema.semantic_hash(a) < Schema.semantic_hash(b))
	return Schema.semantic_hash(copy)
static func read(bytes: PackedByteArray) -> Dictionary:
	var decoded := StrictJSON.new().decode(bytes)
	return validate(decoded.value) if decoded.ok else Schema.result(false,decoded.code)
static func recipe_hash(data: Dictionary) -> String:
	# Checkpoint46 (P3d): receipts are not part of the recipe a plan realizes.
	var copy := data.duplicate(true); copy.slots = []; copy.plan_hash = ""; copy.erase("synthesis_receipts"); return hash_source(copy)
static func validate(data: Variant) -> Dictionary:
	var root_fields := ROOT.duplicate()
	if data is Dictionary and data.has("synthesis_receipts"): root_fields.synthesis_receipts = "array"
	var errors: Array = []; Schema._shape(data,root_fields,"population",errors)
	if errors.is_empty() and data.has("synthesis_receipts") and not load("res://scripts/map_authoring/synthesis/receipt_schema.gd").valid(data.synthesis_receipts): return Schema.result(false,"receipts_invalid")
	if not errors.is_empty(): return Schema.result(false,"population_invalid",errors)
	if data.schema_version != 1: return Schema.result(false,"population_version")
	if data.map.size() > 1 or data.entrance.size() > 1 or data.brushes.size() > 16 or data.exclusions.size() > 64 or data.interactions.size() > 64 or data.slots.size() > 128: return Schema.result(false,"population_limit")
	if not data.map.is_empty():
		if data.map[0] is Dictionary and data.map[0].has("synthesis_receipts"): return Schema.result(false,"receipts_nested")
		var checked := Map.validate(data.map[0])
		if not checked.ok: return checked
	for entry: Variant in data.entrance: Schema._shape(entry,ANCHOR,"entrance",errors)
	var fields := {"brushes":BRUSH,"exclusions":EXCLUSION,"interactions":INTERACTION,"slots":SLOT}
	var brushes: Dictionary = {}
	for collection: String in fields:
		var ids: Dictionary = {}
		for entry: Variant in data[collection]:
			Schema._shape(entry,_fields(collection,fields[collection],entry),collection,errors)
			if not errors.is_empty(): return Schema.result(false,"population_invalid",errors)
			var id_field: String = {"brushes":"brush_id","exclusions":"exclusion_id","interactions":"interaction_id","slots":"slot_id"}[collection]
			if ids.has(entry[id_field]): return Schema.result(false,"duplicate_identity")
			ids[entry[id_field]] = true
			if collection == "brushes":
				brushes[entry.brush_id] = true
				if entry.mode not in ["dispersed","concentrated"] or entry.quota_mode not in ["count","density"] or entry.seed != str(entry.seed.to_int()): return Schema.result(false,"brush_invalid")
				if entry.radius < 1 or entry.radius > 512 or entry.spacing < 0 or entry.spacing > 1024 or entry.group_radius < 1 or entry.group_radius > entry.radius or entry.quantity < 0 or entry.quantity > 128 or entry.quantity != floor(entry.quantity) or entry.density < 0 or entry.density > 100 or entry.round < 0 or entry.round > 2147483647 or entry.round != floor(entry.round): return Schema.result(false,"brush_invalid")
				if entry.species.is_empty() or entry.species.size() > 16: return Schema.result(false,"species_invalid")
				var species: Dictionary = {}
				for spec: Variant in entry.species:
					Schema._shape(spec,SPEC,"species",errors)
					if not errors.is_empty(): return Schema.result(false,"species_invalid",errors)
					var key: String = spec.species_id+"/"+spec.category+"/"+spec.origin_id
					if species.has(key) or spec.weight > 10000: return Schema.result(false,"species_invalid")
					species[key] = true
			if collection == "exclusions" and (entry.radius <= 0 or entry.radius > 1024): return Schema.result(false,"exclusion_invalid")
			if collection == "interactions" and entry.kind not in INTERACTION_KINDS: return Schema.result(false,"interaction_unsupported")
	for slot: Dictionary in data.slots:
		if not brushes.has(slot.brush_id): return Schema.result(false,"brush_reference_missing")
	if not errors.is_empty(): return Schema.result(false,"population_invalid",errors)
	var result := Schema.result(true); result.data = data.duplicate(true); result.output_hash = hash_source(data); return result
## F10 Q2: a brush may declare `guardian: true` (absent means false, so earlier
## documents and their hashes do not change).
static func _fields(collection: String, base: Dictionary, entry: Variant) -> Dictionary:
	if collection != "brushes" or not entry is Dictionary or not entry.has("guardian"): return base
	var shape := base.duplicate(); shape["guardian"] = "bool"; return shape

static func brush(id: String, surface: String, center: Vector3, spec: Dictionary) -> Dictionary:
	var choice := spec.duplicate(true); choice.erase("label")
	return {"brush_id":id,"surface_id":surface,"center_xyz":[center.x,center.y,center.z],"radius":80,"mode":"dispersed","quota_mode":"count","quantity":3,"density":1.0,"spacing":8,"group_radius":60,"seed":"0","round":0,"species":[choice]}
