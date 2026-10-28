@tool
extends RefCounted
## Editorial proposals shared by the context form and semantic AX commands.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
const Layers = preload("res://scripts/map_authoring/terrain/terrain_operations.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const FIELDS := {
	"rules/set":{"biome_ids":"strings","allowed_species":"strings","allow_rare":"bool"},
	"area/upsert":{"region_id":"id","layer_id":"id","min_xz":"v2","max_xz":"v2","allowed_species":"strings","allow_rare":"bool","reserved":"array"},
	"area/remove":{"region_id":"id"},
	"socket/upsert":Schema.FIELDS.sockets,
	"socket/remove":{"socket_id":"id"}}

static func propose(source: Dictionary, operation: String, parameters: Dictionary) -> Dictionary:
	if not FIELDS.has(operation): return Schema.result(false,"action_missing")
	var errors: Array = []
	Schema._shape(parameters,FIELDS[operation],"parameters",errors)
	if not errors.is_empty(): return Schema.result(false,"arguments_invalid",errors)
	var read := Schema.read(JSON.stringify(source,"",true,true).to_utf8_buffer())
	if not read.ok or not read.valid: return Schema.result(false,"source_invalid")
	var data: Dictionary = read.data
	var id := str(parameters.get("region_id",parameters.get("socket_id",data.document_id)))
	var context: Dictionary = data.get("context",Context.empty()).duplicate(true)
	match operation:
		"rules/set":
			var checked := _species(parameters.allowed_species)
			if not checked.ok: return checked
			context.biome_ids = parameters.biome_ids.duplicate()
			context.allowed_species = parameters.allowed_species.duplicate()
			context.allow_rare = parameters.allow_rare
			data.context = context
		"area/upsert":
			var target := Layers._layer(data,parameters.layer_id)
			if target.is_empty(): return Schema.result(false,"source_reference_missing")
			if target.locked: return Schema.result(false,"layer_locked")
			var previous := Context._find(data.regions,"region_id",id)
			if not previous.is_empty():
				if previous.purpose != "encounter": return Schema.result(false,"region_protected")
				if Layers.surface_locked(data,previous.layer_id): return Schema.result(false,"layer_locked")
			for point: Array in [parameters.min_xz,parameters.max_xz]:
				for coordinate: float in point:
					if absf(coordinate) > 8192.0: return Schema.result(false,"arguments_invalid")
			if parameters.min_xz[0] >= parameters.max_xz[0] or parameters.min_xz[1] >= parameters.max_xz[1]: return Schema.result(false,"arguments_invalid")
			var checked := _species(parameters.allowed_species)
			if not checked.ok: return checked
			checked = _reserved(parameters.reserved)
			if not checked.ok: return checked
			var a: Array = parameters.min_xz; var b: Array = parameters.max_xz
			var region := {"region_id":id,"layer_id":parameters.layer_id,"polygon_xz":[a.duplicate(),[b[0],a[1]],b.duplicate(),[a[0],b[1]]],"purpose":"encounter"}
			data.regions = data.regions.filter(func(item: Dictionary) -> bool: return item.region_id != id)
			data.regions.append(region)
			context.areas = context.areas.filter(func(item: Dictionary) -> bool: return item.region_id != id)
			context.areas.append({"region_id":id,"allowed_species":parameters.allowed_species.duplicate(),"allow_rare":parameters.allow_rare,"reserved":parameters.reserved.duplicate(true)})
			# A region moved to another layer cannot remain a protection reference
			# of the old layer. Keep the explicit protection on the new owner.
			if not previous.is_empty() and previous.layer_id != parameters.layer_id:
				var old := Layers._layer(data,previous.layer_id)
				if id in old.protected_regions:
					old.protected_regions.erase(id)
					if id not in target.protected_regions: target.protected_regions.append(id)
			data.context = context
		"area/remove":
			var previous := Context._find(data.regions,"region_id",id)
			if previous.is_empty() or Context._find(context.areas,"region_id",id).is_empty(): return Schema.result(false,"source_reference_missing")
			if previous.purpose != "encounter": return Schema.result(false,"region_protected")
			if Layers.surface_locked(data,previous.layer_id): return Schema.result(false,"layer_locked")
			context.areas = context.areas.filter(func(item: Dictionary) -> bool: return item.region_id != id)
			data.regions = data.regions.filter(func(item: Dictionary) -> bool: return item.region_id != id)
			for layer: Dictionary in data.layers: layer.protected_regions.erase(id)
			data.context = context
		"socket/upsert":
			if not Layers._surface_exists(data,parameters.surface_id): return Schema.result(false,"source_reference_missing")
			if Layers.surface_locked(data,parameters.surface_id): return Schema.result(false,"layer_locked")
			var previous := Context._find(data.sockets,"socket_id",id)
			if not previous.is_empty() and Layers.surface_locked(data,previous.surface_id): return Schema.result(false,"layer_locked")
			if parameters.kind not in ["entrance","exit","objective","thematic_encounter","population","portal"]: return Schema.result(false,"arguments_invalid")
			data.sockets = data.sockets.filter(func(item: Dictionary) -> bool: return item.socket_id != id)
			data.sockets.append(parameters.duplicate(true))
			var compiled := Terrain.compile(data)
			if not compiled.ok: return compiled
		"socket/remove":
			var previous := Context._find(data.sockets,"socket_id",id)
			if previous.is_empty(): return Schema.result(false,"source_reference_missing")
			if Layers.surface_locked(data,previous.surface_id): return Schema.result(false,"layer_locked")
			data.sockets = data.sockets.filter(func(item: Dictionary) -> bool: return item.socket_id != id)
	var checked := Schema.read(JSON.stringify(data,"",true,true).to_utf8_buffer())
	if not checked.ok: return checked
	if not checked.valid: return Schema.result(false,checked.diagnostics[0].code,checked.diagnostics)
	checked.input_hash = read.output_hash
	checked.no_op = read.output_hash == checked.output_hash
	checked.entity_id = id
	return checked

static func _species(ids: Array) -> Dictionary:
	var catalog := Catalog.list_options()
	if not catalog.ok: return catalog
	for id: String in ids:
		var found := false
		for option: Dictionary in catalog.options:
			if option.species_id == id: found = true; break
		if not found: return Context.fail("context_species",id)
	return {"ok":true}

static func _reserved(records: Array) -> Dictionary:
	if records.size() > 1: return Context.fail("context_invalid")
	var catalog := Catalog.list_options()
	if not catalog.ok: return catalog
	for record: Variant in records:
		var errors: Array = []
		Schema._shape(record,Context.RESERVED,"reserved",errors)
		if not errors.is_empty(): return Schema.result(false,"arguments_invalid",errors)
		var found := false
		for option: Dictionary in catalog.options:
			if option.species_id == record.species_id and option.category == record.category and option.origin_id == record.origin_id: found = true; break
		if not found: return Context.fail("context_reserved",record.encounter_id)
	return {"ok":true}
