@tool
extends RefCounted
const Assets = preload("res://scripts/map_authoring/assets/asset_manifest.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Metadata = preload("res://scripts/map_authoring/objects/object_schema.gd")
const MAX_OBJECTS := 1024

static func fail(code: String, id: String = "", position: Vector3 = Vector3.ZERO) -> Dictionary:
	var messages := {"object_limit":"A peça excede o orçamento de1024 objetos.","object_support_missing":"O objeto não tem suporte no piso escolhido.","object_not_settled":"Assente o objeto no terreno antes de compilar.","object_slope":"O declive supera o limite deste objeto.","object_rotation":"A definição não permite essa rotação.","object_connector":"O objeto invade uma abertura protegida.","object_protected":"O objeto invade uma região protegida.","object_overlap":"Dois objetos sólidos se sobrepõem.","object_dependency_changed":"A revisão ou a dependência do objeto mudou."}
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"severity":"error","entity_id":id,"field":"placements","location":position,"message":messages.get(code,"Revise o objeto indicado."),"suggestion":"Ajuste o objeto, o piso ou a proteção indicada."}]}

static func compile(source: Dictionary, terrain: Dictionary, manifest: ExpeditionManifest) -> Dictionary:
	if source.placements.is_empty() and source.dependencies.is_empty(): return {"ok":true,"objects":[],"volumes":[],"dependencies":[]}
	if source.placements.size() > MAX_OBJECTS: return fail("object_limit")
	var catalog := Catalog.load_catalog()
	if not catalog.ok: return catalog
	var dependencies := {}
	for dependency: Dictionary in source.dependencies:
		var resolved := Catalog.definition(dependency.definition_id,catalog)
		if not resolved.ok: return resolved
		if dependency != Catalog.dependency(resolved.definition): return fail("object_dependency_changed",dependency.definition_id)
		dependencies[dependency.definition_id] = dependency
	var world := WorldGeometry.new()
	if manifest == null or not world.configure(manifest,"terrain_preview").ok: return fail("object_support_missing")
	var objects: Array = []; var volumes: Array = []; var assets: Dictionary = {}
	var placements: Array = source.placements.duplicate(true)
	placements.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.placement_id < b.placement_id)
	for placement: Dictionary in placements:
		var found := Catalog.definition(placement.definition_id,catalog)
		if not found.ok: return found
		var definition: Dictionary = found.definition
		if not dependencies.has(placement.definition_id) or placement.revision != definition.revision: return fail("object_dependency_changed",placement.placement_id)
		var rotation_allowed := false
		for angle: Variant in definition.allowed_rotations:
			if float(angle) == float(placement.rotation_y): rotation_allowed = true; break
		if not rotation_allowed: return fail("object_rotation",placement.placement_id)
		var supported := support(terrain,world,placement,definition)
		if not supported.ok: return supported
		var position: Vector3 = supported.position
		var protected_code := protection(source,placement.surface_id,position,definition.footprint_radius)
		if protected_code != "": return fail(protected_code,placement.placement_id,position)
		var record := {"placement_id":placement.placement_id,"definition_id":definition.definition_id,"revision":definition.revision,"surface_id":supported.surface_id,"source_surface_id":placement.surface_id,"position":position,"rotation_y":placement.rotation_y,"definition":definition.duplicate(true),"editor_state":Metadata.state(source,placement.placement_id)}
		if definition.capabilities.body:
			var values: Array = definition.body_box_xyz
			var box := Kernel.transform_volume(AABB(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5])),roundi(float(placement.rotation_y)/90.0),position)
			for other: AABB in volumes:
				if Kernel.overlaps(box,other): return fail("object_overlap",placement.placement_id,position)
			volumes.append(box); record["body_volume"] = box
		objects.append(record)
		assets[definition.sprite_path] = {"definition_id":definition.definition_id+"_sprite","revision":1,"path":definition.sprite_path,"sha256":definition.sprite_sha256}
		var import_path: String = definition.sprite_path+".import"
		var import_digest := Assets.sha256(import_path)
		if import_digest.is_empty(): return Catalog.failure("object_asset_missing",definition.definition_id)
		assets[import_path] = {"definition_id":definition.definition_id+"_sprite_import","revision":1,"path":import_path,"sha256":import_digest}
	var output_dependencies: Array = [{"definition_id":"prop_catalog_json","revision":int(catalog.revision),"path":Catalog.PATH,"sha256":Assets.sha256(Catalog.PATH)}]
	var keys: Array = assets.keys(); keys.sort()
	for path: String in keys: output_dependencies.append(assets[path])
	return {"ok":true,"objects":objects,"volumes":volumes,"dependencies":output_dependencies}

static func support(terrain: Dictionary, world: WorldGeometry, placement: Dictionary, definition: Dictionary, settle: bool = false) -> Dictionary:
	var raw: Array = placement.position_xyz
	var position := Vector3(raw[0],raw[1],raw[2])
	if not position.is_finite(): return fail("object_support_missing",placement.placement_id)
	for visual: Dictionary in terrain.visuals:
		if visual.source_id != placement.surface_id or not visual.walkable: continue
		var cell: Dictionary = {}
		for support_cell: Dictionary in terrain.part.surfaces:
			if support_cell.surface_id == visual.surface_id: cell = support_cell; break
		if cell.is_empty(): continue
		var point := Kernel.support_y(cell,position)
		if not Kernel.contains(cell,point): continue
		if not settle and absf(float(raw[1])-float(point.y)) > 0.001: return fail("object_not_settled",placement.placement_id,position)
		var normal := Kernel.plane_normal(cell.vertices)
		if absf(normal.y) < cos(deg_to_rad(float(definition.max_slope_degrees)))-Kernel.EPSILON: return fail("object_slope",placement.placement_id,point)
		var profile := {"radius":float(definition.footprint_radius),"height":maxf(1.0,float(definition.body_box_xyz[4])),"connector_kinds":["walk"]}
		var query := world.position_query(ExpeditionWorldPoint.create("terrain_preview",cell.surface_id,point),profile,world.geometry_revision)
		if not query.ok: return fail("object_support_missing",placement.placement_id,point)
		return {"ok":true,"surface_id":cell.surface_id,"position":point,"normal":normal}
	return fail("object_support_missing",placement.placement_id,position)

static func protection(source: Dictionary, surface_id: String, position: Vector3, radius: float) -> String:
	var layer_id := surface_id
	for special: Dictionary in source.special_surfaces:
		if special.surface_id == surface_id: layer_id = special.layer_id; break
	for layer: Dictionary in source.layers:
		if layer.layer_id != layer_id: continue
		for region: Dictionary in source.regions:
			if region.layer_id != layer_id or region.region_id not in layer.protected_regions: continue
			var polygon := PackedVector2Array()
			for xz: Array in region.polygon_xz: polygon.append(Vector2(xz[0],xz[1]))
			var p := Vector2(position.x,position.z)
			if Geometry2D.is_point_in_polygon(p,polygon): return "object_protected"
			for i: int in polygon.size():
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()])) < radius: return "object_protected"
	for connector: Dictionary in source.connectors:
		if connector.surface_id != surface_id: continue
		var c: Array = connector.position_xyz; var n: Array = connector.normal_xyz
		var normal := Vector2(n[0],n[2]).normalized(); var tangent := Vector2(-normal.y,normal.x)
		var delta := Vector2(position.x-c[0],position.z-c[2])
		if absf(delta.dot(normal)) < radius+2.0 and absf(delta.dot(tangent)) < float(connector.width)*0.5+radius: return "object_connector"
	return ""

static func validate_dependencies(dependencies: Array, material_dependencies: Array) -> bool:
	if dependencies.size() < material_dependencies.size(): return false
	var seen := {}
	for expected: Dictionary in material_dependencies:
		if expected not in dependencies: return false
	for dependency: Variant in dependencies:
		if not dependency is Dictionary or dependency.size() != 4 or not dependency.has_all(["definition_id","revision","path","sha256"]): return false
		if not dependency.path is String or not dependency.definition_id is String or not dependency.sha256 is String or dependency.sha256.length() != 64 or not dependency.sha256.is_valid_hex_number(false): return false
		if seen.has(dependency.path): return false
		seen[dependency.path] = true
		if dependency in material_dependencies: continue
		if dependency.path != Catalog.PATH and (not dependency.path.begins_with("res://assets/art/map_authoring/props/") or (not dependency.path.ends_with(".png") and not dependency.path.ends_with(".png.import")) or ".." in dependency.path or "\\" in dependency.path): return false
		if Assets.sha256(dependency.path) != dependency.sha256: return false
	return true

static func validate_records(records: Variant) -> bool:
	if not records is Array or records.size() > MAX_OBJECTS: return false
	if records.is_empty(): return true
	var catalog := Catalog.load_catalog()
	if not catalog.ok: return false
	var seen := {}
	for value: Variant in records:
		if not value is Dictionary or not value.has_all(["placement_id","definition_id","revision","surface_id","source_surface_id","position","rotation_y","definition","editor_state"]): return false
		var object: Dictionary = value
		if not object.placement_id is String or not object.definition_id is String or not object.surface_id is String or not object.source_surface_id is String or seen.has(object.placement_id): return false
		seen[object.placement_id] = true
		if not object.position is Vector3 or not object.position.is_finite() or not (object.rotation_y is int or object.rotation_y is float) or not is_finite(float(object.rotation_y)): return false
		var current := Catalog.definition(object.definition_id,catalog)
		if not current.ok or not object.definition is Dictionary or object.definition != current.definition or object.revision != current.definition.revision: return false
		if not object.editor_state is Dictionary or not object.editor_state.has_all(["placement_id","group_id","locked","hidden"]) or not object.editor_state.locked is bool or not object.editor_state.hidden is bool: return false
		if current.definition.capabilities.body:
			if not object.get("body_volume") is AABB or not object.body_volume.position.is_finite() or not object.body_volume.size.is_finite(): return false
		elif object.has("body_volume"): return false
	return true
