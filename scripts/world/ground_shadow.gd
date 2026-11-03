@tool
extends RefCounted
## Shared presentation only. Connected receivers come from the canonical support
## patch; clipping and UVs never create gameplay support, mass, or persisted state.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Patch = preload("res://scripts/core/expedition/spatial/world_support_patch.gd")
const HeightGrid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const EPS := Kernel.EPSILON
const MAX_RECEIVERS := 128
static var _texture: GradientTexture2D

static func texture() -> Texture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0,Color(0.015,0.025,0.035,0.32)); gradient.set_color(1,Color(0.015,0.025,0.035,0.0))
		gradient.add_point(0.25,Color(0.015,0.025,0.035,0.25)); gradient.add_point(0.6,Color(0.015,0.025,0.035,0.11))
		_texture = GradientTexture2D.new(); _texture.width = 128; _texture.height = 128
		_texture.gradient = gradient; _texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5,0.5); _texture.fill_to = Vector2(1.0,0.5)
	return _texture

static func _point(a: Vector3, b: Vector3, t: float) -> Vector3:
	if t == 0.0: return a
	if t == 1.0: return b
	return Vector3(float(a.x)+(float(b.x)-float(a.x))*t,float(a.y)+(float(b.y)-float(a.y))*t,float(a.z)+(float(b.z)-float(a.z))*t)

static func _clip(vertices: Array, axis: int, boundary: float, sign_value: float) -> Array:
	var output: Array = []
	for k: int in vertices.size():
		var a: Vector3 = vertices[k]; var b: Vector3 = vertices[(k+1)%vertices.size()]
		var da := (boundary-float(a[axis]))*sign_value; var db := (boundary-float(b[axis]))*sign_value
		if da >= 0.0 and (output.is_empty() or output[-1] != a): output.append(a)
		if (da < 0.0) != (db < 0.0):
			var p := _point(a,b,da/(da-db))
			if output.is_empty() or output[-1] != p: output.append(p)
	if output.size() > 1 and output[0] == output[-1]: output.pop_back()
	return output

static func index_from_topology(faces: Array, topology: Dictionary) -> Dictionary:
	if not topology.get("ok",false): return {}
	var surfaces: Array = []
	for face: Dictionary in faces:
		if face.walkable: surfaces.append({"surface_id":face.face_id,"vertices":face.vertices.duplicate(),"headroom":face.headroom})
	return Patch.index({"surfaces":surfaces,"connectors":topology.connectors,"connections":topology.adjacency})

## F10 Q1: a height-grid piece has no planar faces; its stretches are the receivers.
static func index_from_stretches(built: Dictionary) -> Dictionary:
	return Patch.index({"surfaces":built.cells,"connectors":built.connectors,"connections":built.adjacency})

static func receiver(anchor: Vector3, index: Dictionary, preferred: String = "") -> String:
	if not index.get("cells") is Dictionary: return ""
	# An authored object names its layer; a stretch of that layer receives it.
	var ids: Array = [preferred] if not preferred.is_empty() and (index.cells.has(preferred) or index.get("grids",{}).is_empty()) else index.cells.keys()
	ids.sort()
	for id: String in ids:
		if not index.cells.has(id): continue
		var cell: Dictionary = index.cells[id]
		if Kernel.contains(cell,anchor): return id
	return ""

static func mesh_data(anchor: Vector3, radii: Vector2, index: Dictionary, surface_id: String, project: Callable) -> Dictionary:
	if not anchor.is_finite() or not radii.is_finite() or minf(radii.x,radii.y) <= EPS or maxf(radii.x,radii.y) > 512 or not project.is_valid() or not index.get("cells") is Dictionary or not index.cells.has(surface_id): return {"ok":false,"code":"shadow_invalid"}
	if not Kernel.contains(index.cells[surface_id],anchor): return {"ok":false,"code":"shadow_receiver_missing"}
	var center := Vector2(anchor.x,anchor.z)
	var members := Patch.members(surface_id,center,center,maxf(radii.x,radii.y),0.0,index)
	if members.size() > MAX_RECEIVERS: return {"ok":false,"code":"shadow_limit"}
	var positions := PackedVector2Array(); var uv := PackedVector2Array(); var indices := PackedInt32Array(); var world: Array = []; var used: Array[String] = []
	var origin: Vector2 = project.call(anchor); var ids: Array = members.keys(); ids.sort()
	for id: String in ids:
		var pieces: Array = [index.cells[id].vertices.duplicate()]
		if index.get("grids",{}).has(id): pieces = HeightGrid.triangles_in(index.grids[id],center-radii,center+radii)
		for piece: Array in pieces:
			var polygon := piece
			for cut: Array in [[0,float(anchor.x)+radii.x,1.0],[0,float(anchor.x)-radii.x,-1.0],[2,float(anchor.z)+radii.y,1.0],[2,float(anchor.z)-radii.y,-1.0]]:
				polygon = _clip(polygon,int(cut[0]),float(cut[1]),float(cut[2]))
				if polygon.size() < 3: break
			if polygon.size() < 3: continue
			var first := positions.size(); var area := 0.0
			for k: int in polygon.size():
				var a: Vector3 = polygon[k]; var b: Vector3 = polygon[(k+1)%polygon.size()]
				area += float(a.x)*float(b.z)-float(b.x)*float(a.z)
			if absf(area) <= EPS: continue
			if id not in used: used.append(id)
			for p: Vector3 in polygon:
				positions.append(Vector2(project.call(p))-origin); uv.append(Vector2((float(p.x)-float(anchor.x))/radii.x*0.5+0.5,(float(p.z)-float(anchor.z))/radii.y*0.5+0.5)); world.append(p)
			for k: int in range(2,polygon.size()): indices.append_array(PackedInt32Array([first,first+k-1,first+k]))
	if indices.is_empty(): return {"ok":false,"code":"shadow_receiver_missing"}
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = positions; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = indices
	return {"ok":true,"arrays":arrays,"world_vertices":world,"receivers":used}

static func mesh(data: Dictionary) -> ArrayMesh:
	var value := ArrayMesh.new(); value.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data.arrays); return value

static func attach(sprite: Sprite2D, anchor: Vector3, radii: Vector2, index: Dictionary, surface_id: String, project: Callable) -> Dictionary:
	var built := mesh_data(anchor,radii,index,surface_id,project)
	if not built.ok: return built
	var shadow := MeshInstance2D.new(); shadow.name = "ContactShadow"; shadow.mesh = mesh(built); shadow.texture = texture()
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR; shadow.z_index = 0; shadow.show_behind_parent = true
	shadow.scale = Vector2(1.0/sprite.scale.x,1.0/sprite.scale.y)
	shadow.set_meta("world_vertices",built.world_vertices); shadow.set_meta("receivers",built.receivers)
	sprite.add_child(shadow)
	return {"ok":true,"node":shadow}

static func draw_on(canvas: CanvasItem, anchor: Vector3, radii: Vector2, index: Dictionary, surface_id: String, project: Callable, cache: Dictionary, epoch: Array) -> bool:
	if cache.get("anchor") != anchor or cache.get("radii") != radii or cache.get("surface_id") != surface_id or cache.get("epoch") != epoch:
		var built := mesh_data(anchor,radii,index,surface_id,project)
		cache.clear(); cache["anchor"] = anchor; cache["radii"] = radii; cache["surface_id"] = surface_id; cache["epoch"] = epoch.duplicate()
		if built.ok: cache["mesh"] = mesh(built)
	if not cache.has("mesh"): return false
	canvas.draw_mesh(cache.mesh,texture()); return true

static func draw_flat(canvas: CanvasItem, radius: float = 15.0) -> void:
	canvas.draw_texture_rect(texture(),Rect2(Vector2(-radius,-radius*0.3),Vector2(radius*2.0,radius*0.6)),false)
