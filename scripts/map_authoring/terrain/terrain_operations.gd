@tool
extends RefCounted
## Pure editorial proposals. GUI and AX commit through the same DocumentSession.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")

static func propose(source: Dictionary, operation: String, parameters: Dictionary) -> Dictionary:
	var fields: Dictionary = {
		"grid/create":{"layer_id":"id","name":"string","origin_xz":"v2","columns":"int","rows":"int","sample_spacing":"number","height":"number"},
		"bridge/create":{"surface_id":"id","layer_id":"id","origin_xz":"v2","width":"number","length":"number","height":"number"},
		"connector/upsert":Schema.FIELDS.connectors,
		"connector/remove":{"connector_id":"id"},
		"layer/lock":{"layer_id":"id","locked":"bool"},
		"layer/protection":{"layer_id":"id","region_ids":"strings"}}
	if not fields.has(operation): return Schema.result(false,"action_missing")
	var errors: Array = []
	Schema._shape(parameters,fields[operation],"parameters",errors)
	if not errors.is_empty(): return Schema.result(false,"arguments_invalid",errors)
	var read := Schema.read(JSON.stringify(source,"",true,true).to_utf8_buffer())
	if not read.ok or not read.valid: return Schema.result(false,"source_invalid")
	var data: Dictionary = read.data
	var id := str(parameters.get("layer_id",parameters.get("surface_id",parameters.get("connector_id",""))))
	match operation:
		"grid/create":
			if _surface_exists(data,parameters.layer_id): return Schema.result(false,"source_duplicate_id")
			if not _origin(parameters.origin_xz) or not _range(parameters.columns,2,257) or not _range(parameters.rows,2,257) or not _range(parameters.sample_spacing,4,256) or not _range(parameters.height,-512,512): return Schema.result(false,"arguments_invalid")
			var heights: Array = []; heights.resize(int(parameters.columns)*int(parameters.rows)); heights.fill(parameters.height)
			data.layers.append({"layer_id":parameters.layer_id,"name":parameters.name,"origin_xz":parameters.origin_xz.duplicate(),"columns":int(parameters.columns),"rows":int(parameters.rows),"sample_spacing":parameters.sample_spacing,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]})
		"bridge/create":
			id = parameters.surface_id
			if _surface_exists(data,id): return Schema.result(false,"source_duplicate_id")
			var layer := _layer(data,parameters.layer_id)
			if layer.is_empty(): return Schema.result(false,"source_reference_missing")
			if layer.locked: return Schema.result(false,"layer_locked")
			if not _origin(parameters.origin_xz) or not _range(parameters.width,4,1024) or not _range(parameters.length,4,1024) or not _range(parameters.height,4,1024): return Schema.result(false,"arguments_invalid")
			var x: float = parameters.origin_xz[0]; var z: float = parameters.origin_xz[1]; var y: float = parameters.height
			var vertices := [[x,y,z],[x+parameters.width,y,z],[x+parameters.width,y,z+parameters.length],[x,y,z+parameters.length]]
			var polygon := PackedVector2Array()
			for vertex: Array in vertices: polygon.append(Vector2(vertex[0],vertex[2]))
			for region: Dictionary in data.regions:
				if region.region_id not in layer.protected_regions: continue
				var protected_polygon := PackedVector2Array()
				for point: Array in region.polygon_xz: protected_polygon.append(Vector2(point[0],point[1]))
				if not Geometry2D.intersect_polygons(polygon,protected_polygon).is_empty(): return Schema.result(false,"region_protected")
			data.special_surfaces.append({"surface_id":id,"layer_id":parameters.layer_id,"vertices_xyz":vertices,"headroom":100.0})
		"connector/upsert":
			id = parameters.connector_id
			if not _surface_exists(data,parameters.surface_id): return Schema.result(false,"source_reference_missing")
			if surface_locked(data,parameters.surface_id): return Schema.result(false,"layer_locked")
			# Array membership distinguishes int and float elements. JSON and GUI
			# normals must use identical numeric rules, without vector32 rounding.
			var nx: float = parameters.normal_xyz[0]; var ny: float = parameters.normal_xyz[1]; var nz: float = parameters.normal_xyz[2]
			var cardinal := ny == 0.0 and (((nx == -1.0 or nx == 1.0) and nz == 0.0) or ((nz == -1.0 or nz == 1.0) and nx == 0.0))
			if parameters.kind != "walk" or parameters.direction not in ["both","in","out"] or not cardinal or not _range(parameters.width,4,8192) or not _range(parameters.headroom,12,8192): return Schema.result(false,"arguments_invalid")
			for coordinate: float in parameters.position_xyz:
				if not _range(coordinate,-8192,8192): return Schema.result(false,"arguments_invalid")
			for index: int in data.connectors.size():
				if data.connectors[index].connector_id != id: continue
				if surface_locked(data,data.connectors[index].surface_id): return Schema.result(false,"layer_locked")
				data.connectors.remove_at(index); break
			data.connectors.append(parameters.duplicate(true))
		"connector/remove":
			var found := false
			for index: int in data.connectors.size():
				if data.connectors[index].connector_id != id: continue
				if surface_locked(data,data.connectors[index].surface_id): return Schema.result(false,"layer_locked")
				data.connectors.remove_at(index); found = true; break
			if not found: return Schema.result(false,"source_reference_missing")
		"layer/lock", "layer/protection":
			var layer := _layer(data,id)
			if layer.is_empty(): return Schema.result(false,"source_reference_missing")
			if operation == "layer/lock": layer.locked = parameters.locked
			else:
				if layer.locked: return Schema.result(false,"layer_locked")
				var selected: Array = []
				for region_id: String in parameters.region_ids:
					if region_id in selected: return Schema.result(false,"arguments_invalid")
					var found := false
					for region: Dictionary in data.regions:
						if region.region_id == region_id and region.layer_id == id: found = true; break
					if not found: return Schema.result(false,"source_reference_missing")
					selected.append(region_id)
				layer.protected_regions = selected
	var checked := Schema.read(JSON.stringify(data,"",true,true).to_utf8_buffer())
	if not checked.ok or not checked.valid: return Schema.result(false,checked.code if not checked.ok else checked.diagnostics[0].code,checked.diagnostics)
	checked.input_hash = read.output_hash
	checked.changed = checked.output_hash != read.output_hash
	checked.entity_id = id
	return checked

static func _range(value: float, low: float, high: float) -> bool:
	return is_finite(value) and value >= low and value <= high

static func _origin(value: Array) -> bool:
	return _range(value[0],-8192,8192) and _range(value[1],-8192,8192)

static func _layer(data: Dictionary, id: String) -> Dictionary:
	for layer: Dictionary in data.layers:
		if layer.layer_id == id: return layer
	return {}

static func _surface_exists(data: Dictionary, id: String) -> bool:
	if not _layer(data,id).is_empty(): return true
	for surface: Dictionary in data.special_surfaces:
		if surface.surface_id == id: return true
	return false

static func surface_locked(data: Dictionary, id: String) -> bool:
	var layer_id := id
	for surface: Dictionary in data.special_surfaces:
		if surface.surface_id == id: layer_id = surface.layer_id; break
	var layer := _layer(data,layer_id)
	return layer.is_empty() or layer.locked
