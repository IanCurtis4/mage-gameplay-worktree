@tool
extends RefCounted
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Document = preload("res://scripts/map_authoring/population/population_document.gd")
const Point = preload("res://scripts/core/expedition/model/world_point.gd")

static func record(source: Dictionary, context: Dictionary, point: ExpeditionWorldPoint) -> Dictionary:
	var id := point.surface_id.get_slice("/",0)
	var instance := MapCompiler._find(context.map_package.realized_instances,"instance_id",id)
	if instance.is_empty(): return {}
	var piece := MapCompiler._find(source.map[0].pieces,"piece_hash",instance.piece_hash)
	if not piece.source.has("context"): return {}
	var local := Kernel.rotate(point.position-MapCompiler._vector(instance.position_xyz),-int(instance.rotation_quarters))
	return {"id":id,"instance":instance,"source":piece.source,"context":piece.source.context,"local":Vector2(local.x,local.z),"family":context.families.get(point.surface_id,point.surface_id)}

static func touches(polygon: Array, at: Vector2, radius: float) -> bool:
	var points := PackedVector2Array()
	for pair: Array in polygon: points.append(Vector2(pair[0],pair[1]))
	if Geometry2D.is_point_in_polygon(at,points): return true
	for index: int in points.size():
		if Geometry2D.get_closest_point_to_segment(at,points[index],points[(index+1)%points.size()]).distance_to(at) < radius: return true
	return false

static func site_id(instance: String, encounter: Dictionary) -> String:
	return "reserved_"+(instance+"/"+encounter.encounter_id).sha256_text().substr(0,24)

static func policy(source: Dictionary, context: Dictionary, point: ExpeditionWorldPoint, spec: Dictionary, radius: float, site: String = "") -> String:
	var info := record(source,context,point)
	if info.is_empty(): return ""
	var map: Dictionary = source.map[0]
	# This switch controls random eligibility. A manually pinned rare is an
	# explicit author choice; species, reservation, catalog and body still apply.
	var random_rare: bool = spec.category in ["rare","rare_elite","boss"] and not spec.get("fixed",false)
	for area: Dictionary in info.context.areas:
		var region := Context._find(info.source.regions,"region_id",area.region_id)
		if info.family != info.id+"/layer/"+region.layer_id or not touches(region.polygon_xz,info.local,radius): continue
		if not area.reserved.is_empty() and not Context.overridden(map,info.id,"reservation"):
			var reserved: Dictionary = area.reserved[0]
			if site != site_id(info.id,reserved) or spec.species_id != reserved.species_id or spec.category != reserved.category or spec.origin_id != reserved.origin_id: return "context_reserved"
			# A named reservation is explicit eligibility, independent of random pools.
			return "" if _inside(region.polygon_xz,info.local,radius) else "context_reserved"
		if not area.allowed_species.is_empty() and spec.species_id not in area.allowed_species and not Context.overridden(map,info.id,"species"): return "context_species"
		if random_rare and not area.allow_rare and not Context.overridden(map,info.id,"rare"): return "context_rare"
	if not info.context.allowed_species.is_empty() and spec.species_id not in info.context.allowed_species and not Context.overridden(map,info.id,"species"): return "context_species"
	if random_rare and not info.context.allow_rare and not Context.overridden(map,info.id,"rare"): return "context_rare"
	return ""

static func rare_allowed(source: Dictionary, context: Dictionary, slot: Dictionary, radius: float) -> bool:
	var point := Point.create("map_preview",slot.surface_id,MapCompiler._vector(slot.position_xyz))
	return not record(source,context,point).is_empty() and policy(source,context,point,slot,radius,slot.site_id) == ""

static func requirements(source: Dictionary, context: Dictionary) -> Array:
	var records: Array = []
	for instance: Dictionary in context.map_package.realized_instances:
		if Context.overridden(source.map[0],instance.instance_id,"reservation"): continue
		var piece := MapCompiler._find(source.map[0].pieces,"piece_hash",instance.piece_hash)
		for area: Dictionary in piece.source.get("context",Context.empty()).areas:
			if area.reserved.is_empty(): continue
			var region := Context._find(piece.source.regions,"region_id",area.region_id)
			records.append({"instance":instance,"region":region,"encounter":area.reserved[0],"site_id":site_id(instance.instance_id,area.reserved[0])})
	records.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.site_id < b.site_id)
	return records

static func check_reservations(source: Dictionary, context: Dictionary) -> Dictionary:
	for requirement: Dictionary in requirements(source,context):
		var found := 0
		for slot: Dictionary in source.slots:
			if slot.site_id != requirement.site_id: continue
			var wanted: Dictionary = requirement.encounter
			if slot.fixed and slot.species_id == wanted.species_id and slot.category == wanted.category and slot.origin_id == wanted.origin_id: found += 1
		if found != 1: return Context.fail("context_reservation_missing",requirement.encounter.encounter_id)
	return {"ok":true}

static func realize(source: Dictionary, context: Dictionary, compiler: Script, cancel: Callable) -> Dictionary:
	var result := source.duplicate(true)
	for requirement: Dictionary in requirements(result,context):
		var id: String = requirement.site_id; var present := false
		for slot: Dictionary in result.slots:
			if slot.site_id == id and slot.fixed: present = true
		if present: continue
		if not MapCompiler._find(result.brushes,"brush_id",id).is_empty() or not MapCompiler._find(result.interactions,"interaction_id",id).is_empty(): return Context.fail("context_reservation_missing",id)
		var spec: Dictionary = requirement.encounter.duplicate(true); spec.erase("encounter_id"); spec.erase("quest_id"); spec.weight = 1
		var checked: Dictionary = compiler._spec(spec,context.catalog)
		if not checked.ok: return checked
		var family: String = requirement.instance.instance_id+"/layer/"+requirement.region.layer_id
		var found: ExpeditionWorldPoint
		for cell: Dictionary in context.family_cells.get(family,[]):
			if found != null: break
			var minimum := Vector2(INF,INF); var maximum := Vector2(-INF,-INF)
			for pair: Array in requirement.region.polygon_xz:
				var transformed := Kernel.rotate(Vector3(pair[0],0,pair[1]),int(requirement.instance.rotation_quarters))+MapCompiler._vector(requirement.instance.position_xyz)
				minimum = minimum.min(Vector2(transformed.x,transformed.z)); maximum = maximum.max(Vector2(transformed.x,transformed.z))
			if (maximum.x-minimum.x)*(maximum.y-minimum.y) > 1048576: return Context.fail("context_invalid",id)
			for z: int in range(int(floor(minimum.y/16.0)),int(ceil(maximum.y/16.0))):
				if found != null: break
				for x: int in range(int(floor(minimum.x/16.0)),int(ceil(maximum.x/16.0))):
					if cancel.is_valid() and cancel.call(): return compiler.fail("cancelled")
					var position := Kernel.support_y(cell,Vector3((x+0.5)*16,0,(z+0.5)*16))
					if not Kernel.contains(cell,position): continue
					var point := Point.create("map_preview",cell.surface_id,position)
					var local := Kernel.rotate(position-MapCompiler._vector(requirement.instance.position_xyz),-int(requirement.instance.rotation_quarters))
					if not _inside(requirement.region.polygon_xz,Vector2(local.x,local.z),checked.profile.radius): continue
					if policy(result,context,point,spec,checked.profile.radius,id) != "": continue
					var code: String = compiler.placement_code(result,context,point,checked.profile,id,cancel)
					if compiler.operational(code): return compiler.fail(code,id)
					if code != "": continue
					var separated := true
					for existing: Dictionary in result.slots:
						if not existing.fixed: continue
						var other: Dictionary = compiler._spec(existing,context.catalog)
						if not other.ok or not compiler._separated(point,checked.profile.radius,8,[{"point":compiler.anchor(existing),"radius":other.get("profile",checked.profile).radius,"spacing":8}]): separated = false; break
					if separated: found = point; break
		if found == null: return Context.fail("context_reservation_missing",requirement.encounter.encounter_id)
		var brush := Document.brush(id,found.surface_id,found.position,spec); brush.quantity = 1; brush.radius = 32; brush.group_radius = 32
		result.brushes.append(brush)
		result.interactions.append({"interaction_id":id,"kind":"thematic_encounter","surface_id":found.surface_id,"position_xyz":[found.position.x,found.position.y,found.position.z],"target_id":requirement.encounter.quest_id})
		result.slots.append({"slot_id":id,"brush_id":id,"surface_id":found.surface_id,"position_xyz":[found.position.x,found.position.y,found.position.z],"species_id":spec.species_id,"category":spec.category,"origin_id":spec.origin_id,"fixed":true,"site_id":id})
	return {"ok":true,"data":result}

static func _inside(polygon: Array, point: Vector2, radius: float) -> bool:
	var points := PackedVector2Array()
	for pair: Array in polygon: points.append(Vector2(pair[0],pair[1]))
	if not Geometry2D.is_point_in_polygon(point,points): return false
	for index: int in points.size():
		if Geometry2D.get_closest_point_to_segment(point,points[index],points[(index+1)%points.size()]).distance_to(point) < radius: return false
	return true
