@tool
extends RefCounted
## Presentation order for existing canvas drawables. Gameplay stays in World.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const EPS := Kernel.EPSILON
const MAX_ITEMS := 8192
const MAX_PAIRS := 8388608

static func _bounds(vertices: Array) -> AABB:
	var result := AABB(vertices[0],Vector3.ZERO)
	for point: Vector3 in vertices: result = result.expand(point)
	return result

static func _screen(vertices: Array) -> Rect2:
	var result := Rect2(ProjectionMath.project(vertices[0]),Vector2.ZERO)
	for point: Vector3 in vertices: result = result.expand(ProjectionMath.project(point))
	return result.grow(0.01)

static func _caps_at(mesh: Dictionary, sprite: Dictionary) -> int:
	for vertices: Array in mesh.get("caps",[]):
		var cell := {"vertices":vertices,"headroom":1.0}
		var contact := Kernel.support_y(cell,sprite.anchor)
		if not Kernel.contains(cell,contact): continue
		return -1 if float(contact.y) <= float(sprite.anchor.y)+EPS+Kernel._support_roundoff(vertices,sprite.anchor) else 1
	return 0

static func _before(a: Dictionary, b: Dictionary) -> int:
	if not a.screen.intersects(b.screen,true): return 0
	if a.kind == "mesh" and b.kind == "sprite":
		var receiver := _caps_at(a,b)
		if receiver != 0: return receiver
	if b.kind == "mesh" and a.kind == "sprite":
		var receiver := _caps_at(b,a)
		if receiver != 0: return -receiver
	var aa: AABB = a.bounds; var bb: AABB = b.bounds
	var ab := aa.end.x <= bb.position.x+EPS or aa.end.z <= bb.position.z+EPS or aa.end.y <= bb.position.y+EPS
	var ba := bb.end.x <= aa.position.x+EPS or bb.end.z <= aa.position.z+EPS or bb.end.y <= aa.position.y+EPS
	if ab != ba: return -1 if ab else 1
	return 0

static func _less(a: String, b: String, records: Dictionary) -> bool:
	var pa: Vector3 = records[a].anchor; var pb: Vector3 = records[b].anchor
	var da := float(pa.x)+float(pa.z)+float(pa.y)*2.0; var db := float(pb.x)+float(pb.z)+float(pb.y)*2.0
	return da < db if da != db else a < b

static func _push(heap: Array[String], id: String, records: Dictionary) -> void:
	heap.append(id); var cursor := heap.size()-1
	while cursor > 0:
		var parent: int = (cursor-1)>>1
		if not _less(heap[cursor],heap[parent],records): break
		var old: String = heap[parent]; heap[parent] = heap[cursor]; heap[cursor] = old; cursor = parent

static func _pop(heap: Array[String], records: Dictionary) -> String:
	var result := heap[0]; var last: String = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last; var cursor := 0
		while cursor*2+1 < heap.size():
			var child := cursor*2+1
			if child+1 < heap.size() and _less(heap[child+1],heap[child],records): child += 1
			if not _less(heap[child],heap[cursor],records): break
			var old: String = heap[cursor]; heap[cursor] = heap[child]; heap[child] = old; cursor = child
	return result

static func solve(items: Array, cache: Dictionary = {}) -> Dictionary:
	if items.size() > MAX_ITEMS: return {"ok":false,"code":"presentation_limit"}
	var records := {}; var ids: Array[String] = []; var changed := {}
	var previous: Dictionary = cache.get("records",{}) if cache.get("version") == 1 else {}
	for item: Variant in items:
		if not item is Dictionary or not item.has_all(["id","kind","bounds","screen","anchor"]) or not item.id is String or item.id.is_empty() or records.has(item.id) or item.kind not in ["mesh","sprite"] or not item.bounds is AABB or not item.screen is Rect2 or not item.anchor is Vector3 or not item.anchor.is_finite() or not item.bounds.position.is_finite() or not item.bounds.size.is_finite(): return {"ok":false,"code":"presentation_invalid"}
		if not item.screen.position.is_finite() or not item.screen.size.is_finite() or minf(item.screen.size.x,item.screen.size.y) < 0 or minf(item.bounds.size.x,minf(item.bounds.size.y,item.bounds.size.z)) < 0: return {"ok":false,"code":"presentation_invalid"}
		var identical: bool = previous.has(item.id) and previous[item.id] == item
		if not identical and item.kind == "mesh":
			if not item.get("caps") is Array: return {"ok":false,"code":"presentation_invalid"}
			for vertices: Variant in item.caps:
				if not vertices is Array or vertices.size() < 3 or vertices.size() > 8: return {"ok":false,"code":"presentation_invalid"}
				for point: Variant in vertices:
					if not point is Vector3 or not point.is_finite(): return {"ok":false,"code":"presentation_invalid"}
				if not Kernel.valid_cell({"vertices":vertices,"headroom":1.0}): return {"ok":false,"code":"presentation_invalid"}
		ids.append(item.id); records[item.id] = item
		if not identical: changed[item.id] = true
	ids.sort()
	var same_ids: bool = cache.get("version") == 1 and cache.get("ids",[]) == ids
	if same_ids and changed.is_empty() and cache.has("order"): return {"ok":true,"order":cache.order.duplicate(),"updated_pairs":0,"constraints":cache.pairs.size(),"unchanged":true}
	var pairs: Dictionary = cache.get("pairs",{}).duplicate() if same_ids else {}
	var work := 0
	var changed_ids: Array = changed.keys() if same_ids else ids.duplicate(); changed_ids.sort()
	if not same_ids and ids.size()*(ids.size()-1)/2 > MAX_PAIRS: return {"ok":false,"code":"presentation_limit"}
	for a: String in changed_ids:
		for b: String in ids:
			if a == b or (a > b and (not same_ids or changed.has(b))): continue
			work += 1
			if work > MAX_PAIRS: return {"ok":false,"code":"presentation_limit"}
			var key: Array = [a,b]; key.sort()
			var order := _before(records[key[0]],records[key[1]])
			if order == 0: pairs.erase(key)
			else: pairs[key] = key if order < 0 else [key[1],key[0]]
	var next := {}; var degree := {}
	for id: String in ids: next[id] = []; degree[id] = 0
	for pair: Array in pairs.values(): next[pair[0]].append(pair[1]); degree[pair[1]] += 1
	var heap: Array[String] = []; var ordered: Array[String] = []
	for id: String in ids:
		if degree[id] == 0: _push(heap,id,records)
	while not heap.is_empty():
		var id := _pop(heap,records); ordered.append(id)
		for other: String in next[id]:
			degree[other] -= 1
			if degree[other] == 0: _push(heap,other,records)
	if ordered.size() != ids.size(): return {"ok":false,"code":"presentation_order_ambiguous"}
	var snapshots := {}
	for id: String in ids: snapshots[id] = records[id].duplicate(true) if changed.has(id) else previous[id]
	cache.clear(); cache["version"] = 1; cache["ids"] = ids; cache["records"] = snapshots; cache["pairs"] = pairs; cache["order"] = ordered.duplicate()
	return {"ok":true,"order":ordered,"updated_pairs":work,"constraints":pairs.size(),"unchanged":false}

static func world_vertices(mesh: ArrayMesh) -> Array:
	var values: PackedFloat32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]; var result: Array = []
	for i: int in range(0,values.size(),4): result.append(Vector3(values[i],values[i+1],values[i+2]))
	return result

static func tag_grid(view: MeshInstance2D, columns: int, rows: int) -> void:
	var vertices := world_vertices(view.mesh)
	var corners: Array = [vertices[0],vertices[columns-1],vertices[columns*rows-1],vertices[(rows-1)*columns]]
	var caps: Array = [corners] if Kernel.valid_cell({"vertices":corners,"headroom":1.0}) else [[corners[0],corners[1],corners[2]],[corners[0],corners[2],corners[3]]]
	view.set_meta("canvas_order_caps",caps)

static func tag_box(node: Node2D, box: AABB) -> void:
	var vertices: Array = []
	for i: int in 8: vertices.append(box.get_endpoint(i))
	var p := box.position; var e := box.end
	var cap: Array = [Vector3(p.x,e.y,p.z),Vector3(e.x,e.y,p.z),Vector3(e.x,e.y,e.z),Vector3(p.x,e.y,e.z)]
	node.set_meta("canvas_order_record",{"id":"box_"+Canonical.digest(box).substr(0,32),"kind":"mesh","bounds":box,"screen":_screen(vertices),"anchor":box.get_center(),"caps":[cap]})

static func _mesh_record(node: MeshInstance2D, id: String) -> Dictionary:
	if node.has_meta("canvas_order_record"): return node.get_meta("canvas_order_record")
	var vertices := world_vertices(node.mesh)
	if vertices.is_empty(): return {}
	var caps: Array = node.get_meta("canvas_order_caps",[])
	if not node.has_meta("canvas_order_caps"):
		var indices: PackedInt32Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		for i: int in range(0,indices.size(),3):
			var triangle: Array = [vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]]]
			if Kernel.valid_cell({"vertices":triangle,"headroom":1.0}): caps.append(triangle)
	var bounds := _bounds(vertices)
	var record := {"id":"mesh_"+Canonical.digest([vertices,caps]).substr(0,32),"kind":"mesh","bounds":bounds,"screen":_screen(vertices),"anchor":bounds.get_center(),"caps":caps}
	node.set_meta("canvas_order_record",record); return record

static func apply(root: Node2D) -> Dictionary:
	var records: Array = []; var nodes := {}; var bindings := {}
	for node: Node in root.get_children():
		if not node is Node2D or not node.visible: continue
		var id := str(node.get_instance_id()); var record := {}
		if node.has_meta("canvas_order_record"): record = node.get_meta("canvas_order_record")
		elif node is MeshInstance2D and node.mesh is ArrayMesh: record = _mesh_record(node,id)
		elif node is Sprite2D and node.has_meta("world_position"):
			id = "prop_"+str(node.get_meta("placement_id"))
			var anchor: Vector3 = node.get_meta("world_position"); var radius := float(node.get_meta("footprint_radius",1.0)); var height := float(node.get_meta("world_height",1.0))
			var rect := Rect2(node.position+node.get_rect().position*node.scale,node.get_rect().size*node.scale)
			record = {"id":id,"kind":"sprite","anchor":anchor,"bounds":AABB(anchor-Vector3(radius,0,radius),Vector3(radius*2,height,radius*2)),"screen":rect}
		elif node.has_method("world_point"):
			id = "actor_"+str(node.name)
			var point: Variant = node.call("world_point")
			if point == null: continue
			var radius := float(node.get("collision_radius")); var height := float(node.get("_sprite_visible_height"))*float(node.get("sprite_visual_scale"))
			var anchor: Vector3 = point.position; var screen := ProjectionMath.project(anchor)
			record = {"id":id,"kind":"sprite","anchor":anchor,"bounds":AABB(anchor-Vector3(radius,0,radius),Vector3(radius*2,height,radius*2)),"screen":Rect2(screen-Vector2(height*0.65,height),Vector2(height*1.3,height+8))}
		if record.is_empty(): continue
		records.append(record); nodes[record.id] = node; bindings[record.id] = node.get_instance_id()
	var cache: Dictionary = root.get_meta("canvas_order_cache",{})
	var result := solve(records,cache)
	if not result.ok: return result
	root.set_meta("canvas_order_cache",cache)
	var same_bindings: bool = root.get_meta("canvas_order_bindings",{}) == bindings
	root.set_meta("canvas_order_bindings",bindings)
	if result.unchanged and same_bindings: return result
	for i: int in result.order.size():
		var node: Node2D = nodes[result.order[i]]
		node.z_index = mini(4000,2+i*2) if result.order.size() <= 2000 else 1+floori(float(i)*3999/maxi(1,result.order.size()-1))
		root.move_child(node,root.get_child_count()-1)
	return result
