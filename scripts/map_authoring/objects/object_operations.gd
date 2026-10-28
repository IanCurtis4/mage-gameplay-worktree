@tool
extends RefCounted
## Proposals only: GUI, AX and CLI commit through the same document session.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Compiler = preload("res://scripts/map_authoring/objects/object_compiler.gd")
const Metadata = preload("res://scripts/map_authoring/objects/object_schema.gd")

const PARAMETERS := {
	"place":{"required":{"definition_id":"id","surface_id":"id","position_xz":"v2"},"optional":{"placement_id":"id","rotation_y":"number","snap":"number"}},
	"move":{"required":{"ids":"strings","position_xz":"v2"},"optional":{"surface_id":"id","snap":"number"}},
	"translate":{"required":{"ids":"strings","delta_xz":"v2"},"optional":{"snap":"number"}},
	"rotate":{"required":{"ids":"strings","degrees":"number"},"optional":{"snap":"number"}},
	"duplicate":{"required":{"ids":"strings","delta_xz":"v2"},"optional":{"snap":"number"}},
	"remove":{"required":{"ids":"strings"},"optional":{}},
	"group":{"required":{"ids":"strings","group_id":"id"},"optional":{"name":"string"}},
	"ungroup":{"required":{"ids":"strings"},"optional":{}},
	"lock":{"required":{"ids":"strings","value":"bool"},"optional":{}},
	"hide":{"required":{"ids":"strings","value":"bool"},"optional":{}},
	"group_state":{"required":{"group_id":"id"},"optional":{"locked":"bool","hidden":"bool"}},
	"scatter":{"required":{"definition_id":"id","surface_id":"id","center_xz":"v2","radius":"number","count":"int"},"optional":{"spacing":"number","seed_text":"string","snap":"number","exclusions":"array"}}}

static func valid_parameters(operation: String, params: Dictionary) -> bool:
	if not PARAMETERS.has(operation): return false
	var fields: Dictionary = PARAMETERS[operation]
	for key: Variant in params:
		if not fields.required.has(key) and not fields.optional.has(key): return false
	for key: String in fields.required:
		if not params.has(key) or not Schema._type(params[key],fields.required[key]): return false
	for key: String in fields.optional:
		if params.has(key) and not Schema._type(params[key],fields.optional[key]): return false
	return true

static func fail(code: String, id: String = "") -> Dictionary: return Compiler.fail(code,id)

static func propose(source: Dictionary, operation: String, params: Dictionary) -> Dictionary:
	if not PARAMETERS.has(operation): return fail("object_operation_unknown")
	if not valid_parameters(operation,params):
		# Keep the existing public selection diagnostic while closing the rest
		# of the parameter shape for GUI and AX alike.
		if PARAMETERS[operation].required.has("ids") and not Schema._type(params.get("ids"),"strings"): return fail("object_selection_invalid")
		return fail("object_parameters_invalid")
	var read := Schema.read(JSON.stringify(source,"",true,true).to_utf8_buffer())
	if not read.ok or not read.valid: return fail("source_invalid")
	if operation not in ["place","move","translate","rotate","duplicate","remove","group","ungroup","group_state","lock","hide","scatter"]: return fail("object_operation_unknown")
	var data: Dictionary = read.data
	if operation == "group_state":
		if not Schema._type(params.get("group_id"),"id") or not data.has("objects"): return fail("object_group_invalid")
		var group := _find(data.objects.groups,"group_id",params.group_id)
		if group.is_empty() or (not params.has("locked") and not params.has("hidden")): return fail("object_group_invalid")
		for field: String in ["locked","hidden"]:
			if not params.has(field): continue
			if not params[field] is bool: return fail("object_metadata_invalid")
			group[field] = params[field]
		return _proposal(source,data)
	var raw_ids: Variant = params.get("ids",[])
	if not raw_ids is Array or raw_ids.size() > 1024: return fail("object_selection_invalid")
	var ids: Array = raw_ids
	var selected: Array = []; var seen := {}
	for value: Variant in ids:
		if not Schema._type(value,"id") or seen.has(value): return fail("object_selection_invalid")
		seen[value] = true
		var item := _find(data.placements,"placement_id",value)
		if item.is_empty(): return fail("object_selection_invalid",value)
		if operation not in ["lock","hide"] and Metadata.locked(data,item): return fail("object_locked",value)
		selected.append(item)
	if operation not in ["place","scatter"] and selected.is_empty(): return fail("object_selection_invalid")
	if operation in ["group","ungroup","lock","hide"]:
		if not data.has("objects"): data["objects"] = Metadata.empty()
		var group_id: Variant = params.get("group_id","")
		if operation == "group":
			if not Schema._type(group_id,"id") or not params.get("name","") is String: return fail("object_group_invalid")
			var group := _find(data.objects.groups,"group_id",group_id)
			if group.is_empty(): data.objects.groups.append({"group_id":group_id,"name":params.get("name",group_id),"locked":false,"hidden":false})
		for placement: Dictionary in selected:
			var state := _find(data.objects.states,"placement_id",placement.placement_id)
			if state.is_empty():
				state = {"placement_id":placement.placement_id,"group_id":"","locked":false,"hidden":false}
				data.objects.states.append(state)
			if operation == "group": state.group_id = group_id
			elif operation == "ungroup": state.group_id = ""
			else:
				if not params.get("value") is bool: return fail("object_metadata_invalid")
				state["locked" if operation == "lock" else "hidden"] = params.value
		return _proposal(source,data)
	if operation == "remove":
		data.placements = data.placements.filter(func(p: Dictionary) -> bool: return p.placement_id not in ids)
		if data.has("objects"): data.objects.states = data.objects.states.filter(func(s: Dictionary) -> bool: return s.placement_id not in ids)
		return _proposal(source,data)
	var catalog := Catalog.load_catalog()
	if not catalog.ok: return catalog
	var base := data.duplicate(true); base.placements = []; base.dependencies = []; base.erase("objects")
	var terrain := Terrain.compile(base)
	if not terrain.ok: return terrain
	var world := WorldGeometry.new(); world.configure(Terrain.preview_manifest(terrain.package),"terrain_preview")
	if operation == "place":
		var id: Variant = params.get("placement_id",new_id(data,"place",params))
		var definition_id: Variant = params.get("definition_id")
		var surface: Variant = params.get("surface_id")
		if not Schema._type(id,"id") or not Schema._type(definition_id,"id") or not Schema._type(surface,"id") or not Schema._type(params.get("position_xz"),"v2"): return fail("object_parameters_invalid")
		if not _find(data.placements,"placement_id",id).is_empty(): return fail("object_duplicate_id",id)
		var definition := Catalog.definition(definition_id,catalog)
		if not definition.ok: return definition
		var p: Array = params.position_xz
		var placement := {"placement_id":id,"definition_id":definition_id,"revision":int(definition.definition.revision),"position_xyz":[p[0],0,p[1]],"rotation_y":params.get("rotation_y",0),"surface_id":surface}
		if Metadata.locked(data,placement): return fail("object_locked",id)
		var settled := _settle(placement,definition.definition,terrain.package,world,params.get("snap",0))
		if not settled.ok: return settled
		data.placements.append(placement); _dependency(data,definition.definition)
	elif operation == "scatter":
		var scattered := _scatter(data,params,catalog,terrain.package,world)
		if not scattered.ok: return scattered
		data = scattered.data
	else:
		var center := Vector2.ZERO
		for item: Dictionary in selected: center += Vector2(item.position_xyz[0],item.position_xyz[2])
		center /= float(selected.size())
		if operation == "move" and (selected.size() != 1 or not Schema._type(params.get("position_xz"),"v2")): return fail("object_parameters_invalid")
		if operation in ["translate","duplicate"] and not Schema._type(params.get("delta_xz"),"v2"): return fail("object_parameters_invalid")
		if operation == "rotate" and not Schema._type(params.get("degrees"),"number"): return fail("object_parameters_invalid")
		var additions: Array = []
		var duplicated_ids := {}
		for item: Dictionary in selected:
			var changed := item.duplicate(true) if operation == "duplicate" else item
			var p := Vector2(changed.position_xyz[0],changed.position_xyz[2])
			if operation == "move": p = Vector2(params.position_xz[0],params.position_xz[1])
			elif operation in ["translate","duplicate"]: p += Vector2(params.delta_xz[0],params.delta_xz[1])
			else:
				p = center+(p-center).rotated(-deg_to_rad(float(params.degrees)))
				changed.rotation_y = fposmod(float(changed.rotation_y)+float(params.degrees),360.0)
			if operation == "duplicate":
				changed.placement_id = new_id(data,"duplicate",{"original":item.placement_id,"params":params})
				duplicated_ids[item.placement_id] = changed.placement_id
				additions.append(changed)
			if operation == "move" and params.has("surface_id"):
				if not Schema._type(params.surface_id,"id"): return fail("object_parameters_invalid")
				changed.surface_id = params.surface_id
				if Metadata.locked(data,changed): return fail("object_locked",changed.placement_id)
			changed.position_xyz = [p.x,changed.position_xyz[1],p.y]
			var resolved := Catalog.definition(changed.definition_id,catalog)
			if not resolved.ok: return resolved
			var definition: Dictionary = resolved.definition
			var settled := _settle(changed,definition,terrain.package,world,params.get("snap",0))
			if not settled.ok: return settled
		data.placements.append_array(additions)
		if not duplicated_ids.is_empty(): Metadata.duplicate_metadata(data,duplicated_ids,func(group_id: String) -> String: return new_id(data,"duplicate_group",{"group_id":group_id,"ids":duplicated_ids}))
	var compiled := Terrain.compile(data)
	if not compiled.ok: return compiled
	var result := _proposal(source,data); result["package"] = compiled.package
	return result

static func _settle(placement: Dictionary, definition: Dictionary, terrain: Dictionary, world: WorldGeometry, snap: Variant) -> Dictionary:
	if not Schema._type(snap,"number") or snap < 0 or snap > 8192: return fail("object_parameters_invalid")
	if snap > 0:
		placement.position_xyz[0] = snappedf(placement.position_xyz[0],snap)
		placement.position_xyz[2] = snappedf(placement.position_xyz[2],snap)
	var supported := Compiler.support(terrain,world,placement,definition,true)
	if not supported.ok: return supported
	placement.position_xyz = [supported.position.x,supported.position.y,supported.position.z]
	return {"ok":true}

static func _scatter(data: Dictionary, params: Dictionary, catalog: Dictionary, terrain: Dictionary, world: WorldGeometry) -> Dictionary:
	if not Schema._type(params.get("definition_id"),"id") or not Schema._type(params.get("surface_id"),"id") or not Schema._type(params.get("center_xz"),"v2") or not Schema._type(params.get("radius"),"number") or not Schema._type(params.get("count"),"number"): return fail("object_parameters_invalid")
	var count: float = params.count
	if count != floor(count) or count < 1 or count > 1024 or params.radius <= 0 or params.radius > 8192 or data.placements.size()+count > Compiler.MAX_OBJECTS: return fail("object_limit")
	var seed_text: Variant = params.get("seed_text","0")
	if not seed_text is String or seed_text != str(seed_text.to_int()): return fail("object_seed_invalid")
	var spacing: Variant = params.get("spacing",0.0)
	if not Schema._type(spacing,"number") or spacing < 0 or spacing > 8192: return fail("object_parameters_invalid")
	var exclusions: Variant = params.get("exclusions",[])
	if not exclusions is Array or exclusions.size() > 64: return fail("object_parameters_invalid")
	for exclusion: Variant in exclusions:
		if not Schema._type(exclusion,"points2") or exclusion.size() < 3: return fail("object_parameters_invalid")
	var resolved := Catalog.definition(params.definition_id,catalog)
	if not resolved.ok: return resolved
	var definition: Dictionary = resolved.definition
	var accepted := 0; var attempts := 0
	var budget := mini(65536,int(count)*128)
	while accepted < count and attempts < budget:
		var index := attempts; attempts += 1
		var angle := random_unit(seed_text,index,"angle")*TAU
		var distance := sqrt(random_unit(seed_text,index,"radius"))*float(params.radius)
		var x := float(params.center_xz[0])+cos(angle)*distance; var z := float(params.center_xz[1])+sin(angle)*distance
		var placement := {"placement_id":new_id(data,"scatter",{"seed":seed_text,"attempt":index,"definition":params.definition_id}),"definition_id":params.definition_id,"revision":int(definition.revision),"position_xyz":[x,0,z],"rotation_y":definition.allowed_rotations[int(random_unit(seed_text,index,"rotation")*definition.allowed_rotations.size())],"surface_id":params.surface_id}
		if Metadata.locked(data,placement): return fail("object_locked",placement.placement_id)
		if not _settle(placement,definition,terrain,world,params.get("snap",0)).ok: continue
		var p := Vector2(placement.position_xyz[0],placement.position_xyz[2]); var radius: float = definition.footprint_radius
		if Compiler.protection(data,placement.surface_id,Vector3(p.x,placement.position_xyz[1],p.y),radius) != "": continue
		var excluded := false
		for exclusion: Array in exclusions:
			var polygon := PackedVector2Array()
			for xz: Array in exclusion: polygon.append(Vector2(xz[0],xz[1]))
			if Geometry2D.is_point_in_polygon(p,polygon): excluded = true; break
			for i: int in polygon.size():
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()])) < radius: excluded = true; break
		if excluded: continue
		for other: Dictionary in data.placements:
			if other.surface_id != placement.surface_id: continue
			var other_radius: float = catalog.definitions[other.definition_id].footprint_radius
			if p.distance_to(Vector2(other.position_xyz[0],other.position_xyz[2])) < radius+other_radius+float(spacing): excluded = true; break
		if excluded: continue
		data.placements.append(placement); accepted += 1
	if accepted != int(count):
		var failure := fail("object_scatter_deficit")
		failure["requested"] = int(count); failure["realized"] = accepted; failure["deficit"] = int(count)-accepted; failure["attempts"] = attempts
		return failure
	_dependency(data,definition)
	return {"ok":true,"data":data,"attempts":attempts}

static func random_unit(seed_text: String, attempt: int, channel: String) -> float:
	var digest := ("objects/scatter/v1/"+seed_text+"/"+str(attempt)+"/"+channel).sha256_text()
	return float(digest.substr(0,12).hex_to_int())/281474976710656.0

static func new_id(source: Dictionary, operation: String, params: Dictionary) -> String:
	return "object_"+(Schema.semantic_hash(source)+operation+Schema._canonical(params)).sha256_text().substr(0,24)

static func _dependency(source: Dictionary, definition: Dictionary) -> void:
	var dep := Catalog.dependency(definition)
	if _find(source.dependencies,"definition_id",dep.definition_id).is_empty(): source.dependencies.append(dep)

static func _find(values: Array, key: String, value: Variant) -> Dictionary:
	for item: Dictionary in values:
		if item.get(key) == value: return item
	return {}

static func _proposal(before: Dictionary, after: Dictionary) -> Dictionary:
	var checked := Schema.read(JSON.stringify(after,"",true,true).to_utf8_buffer())
	if not checked.ok: return checked
	if not checked.valid: return Schema.result(false,"source_invalid",checked.diagnostics)
	return {"ok":true,"code":"","data":checked.data,"input_hash":Schema.semantic_hash(before),"output_hash":checked.output_hash,"no_op":Schema.semantic_hash(before) == checked.output_hash,"diagnostics":[]}
