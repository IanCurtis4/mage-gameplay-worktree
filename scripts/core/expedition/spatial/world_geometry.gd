class_name WorldGeometry
extends RefCounted
## Logical world units: x/z horizontal, y height. No camera or projected pixels.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const SolidPrism = preload("res://scripts/core/expedition/spatial/world_solid_prism.gd")
const SupportPatch = preload("res://scripts/core/expedition/spatial/world_support_patch.gd")
const HeightGrid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const EPS := 0.00001
const NAVIGATION_MEMO_LIMIT := 32768
## F10 H6: regular offsets along a seam between two stretches in a batch, and
## the bucket size of the stretch boxes' broadphase.
const GRID_SEAM_STEP := 256.0
const GRID_BUCKET := 1024.0
## Cross-query memo of exact pair predicates (checkpoint35). Same keys and values
## as the per-query memo; valid only for one effective geometry and full profile.
const NAVIGATION_SHARED_MEMO_LIMIT := 262144
var _navigation_epoch := 0
var _navigation_shared: Dictionary = {}
var geometry_revision := 0
var configuration_revision := 0
var _stage: Dictionary = {}
var _temporary: Dictionary[String, AABB] = {}
var _segments: Dictionary[String, WorldSolidSegment] = {}
var _solid_slabs: Array[AABB] = []
var _occupancy: Dictionary[String, Dictionary] = {}
var _support_index: Dictionary = {}
## Background navigation (checkpoint36, contracts/f9_navigation_async.md).
## Off by default: tests, editor and headless runs stay synchronous. All fields
## below are transient and omitted from snapshots.
var navigation_async := false
var _navigation_view: WorldGeometry
var _navigation_view_key: Array = []
var _navigation_queue: Array[PathRequest] = []
var _navigation_task := -1
var _navigation_running: PathRequest
var _navigation_box: Dictionary = {}
## F10 H3: lattices of height-grid stretches per body radius (read-only once
## built). Replaced, never cleared, on configure; shared with worker views and
## connectivity shadows of the same stage, so it is guarded by its mutex.
var _grid_cache: Dictionary = {}
var _grid_mutex := Mutex.new()

class PathRequest extends RefCounted:
	var from: ExpeditionWorldPoint
	var to: ExpeditionWorldPoint
	var profile: Dictionary = {}
	var revision := 0
	var priority := 0
	var owner: WeakRef
	var state := &"queued"
	var result: Dictionary = {}
	var queued_usec := 0
	var compute_usec := 0
	var finished_usec := 0
	func done() -> bool: return state == &"done"
	func cancel() -> void:
		if state == &"queued" or state == &"running": state = &"cancelled"

func configure(manifest: ExpeditionManifest, stage_id: String) -> Dictionary:
	if manifest == null: return _failure(&"invalid_manifest")
	var data := manifest.to_data()
	for stage: Dictionary in data.get("stages", []):
		if stage["stage_id"] == stage_id:
			if not _stage_prisms_valid(stage): return _failure(&"invalid_manifest")
			_stage = stage.duplicate(true)
			# A background view may still read the previous index: replace, never clear.
			_support_index = {}
			_grid_cache = {}
			_solid_slabs.clear()
			# Preserve F0's distinction between authored solids and planar blockers.
			for instance: Dictionary in stage["part_instances"]:
				for definition: Dictionary in data["input"]["parts"]:
					if definition["part_id"] != instance["part_id"]: continue
					for original: AABB in definition["solid_volumes"]:
						var volume := Kernel.transform_volume(original,instance["rotation_quarters"],instance["translation"])
						if _supports_solid_floor(volume): _solid_slabs.append(volume)
			_temporary.clear()
			_segments.clear()
			_occupancy.clear()
			_navigation_invalidate()
			# Monotonic even when replacing a world with another revision-1 manifest.
			geometry_revision += 1
			configuration_revision += 1
			return _success({"manifest_hash": manifest.canonical_hash(), "stage_id": stage_id})
	return _failure(&"unknown_stage")

static func _stage_prisms_valid(stage: Dictionary) -> bool:
	var values: Variant = stage.get("solid_prisms",[])
	if not values is Array or values.size() > 2048: return false
	if values.is_empty(): return true
	if not stage.get("surfaces") is Array: return false
	var ids: Dictionary = {}; var cells: Dictionary = {}
	for cell: Variant in stage.surfaces:
		if not cell is Dictionary or not cell.get("surface_id") is String or not cell.get("vertices") is Array or not _finite_number(cell.get("headroom")): return false
		for vertex: Variant in cell.vertices:
			if not vertex is Vector3 or not vertex.is_finite(): return false
		if not Kernel.valid_cell(cell): return false
		cells[cell.surface_id] = cell
	for value: Variant in values:
		if not SolidPrism.valid(value) or ids.has(value.volume_id): return false
		ids[value.volume_id] = true
		if value.support_surface_id.is_empty(): continue
		if not cells.has(value.support_surface_id): return false
		for vertex: Vector3 in value.top:
			if not Kernel.contains(cells[value.support_surface_id],vertex): return false
	return true

func _supports_solid_floor(volume: AABB) -> bool:
	var rectangle := PackedVector2Array([Vector2(volume.position.x,volume.position.z),Vector2(volume.end.x,volume.position.z),Vector2(volume.end.x,volume.end.z),Vector2(volume.position.x,volume.end.z)])
	for cell: Dictionary in _stage["surfaces"]:
		if cell.has("height_grid"): continue
		var polygon := PackedVector2Array()
		var horizontal := true
		for vertex: Vector3 in cell["vertices"]:
			if absf(vertex.y-volume.end.y) > EPS: horizontal = false; break
			polygon.append(Vector2(vertex.x,vertex.z))
		if horizontal and not Geometry2D.intersect_polygons(rectangle,polygon).is_empty(): return true
	return false
func _success(data: Dictionary = {}) -> Dictionary:
	return {"ok": true, "error_code": &"", "geometry_revision": geometry_revision, "data": data.duplicate(true)}

func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "error_code": code, "geometry_revision": geometry_revision, "data": {}}

func _current(revision: int) -> bool:
	return not _stage.is_empty() and revision == geometry_revision

func _ensure_support_index() -> void:
	if _support_index.is_empty() and not _stage.is_empty():
		_support_index = SupportPatch.index(_stage)
		_support_index["solid_prisms"] = []
		var masses: Array = _stage.get("solid_prisms",[]).duplicate()
		masses.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.volume_id < b.volume_id)
		for prism: Dictionary in masses: _support_index.solid_prisms.append(SolidPrism.prepare(prism))
		_support_index["mass_broadphase"] = SolidPrism.spatial_index(_support_index.solid_prisms)
		# F10 H2: a stretch is solid below its support; boxes are its broadphase.
		var grid_boxes: Dictionary = {}
		for id: String in _support_index.grids:
			var view: Dictionary = _support_index.grids[id]
			var outline := HeightGrid.bounds(view); var span := HeightGrid.height_range(view)
			grid_boxes[id] = AABB(Vector3(outline.position.x,span.x-4.0,outline.position.y),Vector3(outline.size.x,span.y-span.x+4.0,outline.size.y))
		_support_index["grid_boxes"] = grid_boxes
		# F10 H6: buckets over the boxes' xz rectangles; candidates keep the
		# boxes' order, so the sweep's tie order does not change.
		var box_ids: Array = grid_boxes.keys(); var buckets: Dictionary = {}
		for index: int in box_ids.size():
			var box: AABB = grid_boxes[box_ids[index]]
			for bx: int in range(int(floor(box.position.x/GRID_BUCKET)),int(floor(box.end.x/GRID_BUCKET))+1):
				for bz: int in range(int(floor(box.position.z/GRID_BUCKET)),int(floor(box.end.z/GRID_BUCKET))+1):
					var key := Vector2i(bx,bz)
					if not buckets.has(key): buckets[key] = PackedInt32Array()
					buckets[key].append(index)
		_support_index["grid_box_ids"] = box_ids; _support_index["grid_buckets"] = buckets

func _cell(id: String) -> Dictionary:
	_ensure_support_index()
	return _support_index.get("cells",{}).get(id,{})

func _volumes() -> Array:
	var volumes: Array = _stage.get("volumes", []).duplicate()
	var ids: Array = _temporary.keys()
	ids.sort()
	for id: String in ids: volumes.append(_temporary[id])
	return volumes

func _profile_valid(profile: Dictionary) -> bool:
	if not profile.has_all(["radius", "height", "connector_kinds"]): return false
	if not _finite_number(profile["radius"]) or not _finite_number(profile["height"]): return false
	if not (profile["connector_kinds"] is Array or profile["connector_kinds"] is PackedStringArray) or profile["connector_kinds"].is_empty(): return false
	for kind: Variant in profile["connector_kinds"]:
		if not (kind is String or kind is StringName) or str(kind).is_empty(): return false
	return float(profile["radius"]) > 0.0 and float(profile["height"]) > 0.0

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _point_valid(point: ExpeditionWorldPoint, radius: float = 0.0, height: float = 0.0) -> bool:
	if point == null or not point.position.is_finite() or point.stage_id != _stage.get("stage_id", ""): return false
	var cell := _cell(point.surface_id)
	if cell.is_empty() or float(cell["headroom"])+EPS < height or not _supported(cell,point.position,radius,height): return false
	var contact := ground_sweep(point.surface_id,point.position,point.position,{"radius":radius,"height":height},geometry_revision)
	return contact["ok"] and not contact["data"]["hit"]

func _supported(cell: Dictionary, position: Vector3, radius: float, height: float) -> bool:
	_ensure_support_index()
	return SupportPatch.contains(cell,position,radius,height,_support_index)

func support_at(surface_id: String, horizontal: Vector2, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not horizontal.is_finite(): return _failure(&"invalid_position")
	var cell := _cell(surface_id)
	if cell.is_empty(): return _failure(&"unknown_surface")
	var point := Kernel.support_y(cell, Vector3(horizontal.x,0,horizontal.y))
	if not Kernel.contains(cell,point): return _failure(&"invalid_support")
	return _success({"point":ExpeditionWorldPoint.create(_stage["stage_id"],surface_id,point).to_data()})
func position_query(point: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not _profile_valid(profile): return _failure(&"invalid_profile")
	if not _point_valid(point, profile["radius"], profile["height"]): return _failure(&"invalid_support")
	var occupants: Array[String] = []
	for id: String in _occupancy:
		var item: Dictionary = _occupancy[id]
		var other: Vector3 = item["point"]["position"]
		if point.position.y < other.y + float(item["height"]) and point.position.y + float(profile["height"]) > other.y and Vector2(point.position.x, point.position.z).distance_to(Vector2(other.x, other.z)) < float(profile["radius"]) + float(item["radius"]): occupants.append(id)
	occupants.sort()
	return _success({"point": point.to_data(), "occupants": occupants})

func set_occupant(id: String, point: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	var check := position_query(point, profile, revision)
	if not check["ok"]: return check
	if id.is_empty(): return _failure(&"invalid_identity")
	_occupancy[id] = {"point": point.to_data(), "radius": profile["radius"], "height": profile["height"], "profile": profile.duplicate(true)}
	return _success()

func remove_occupant(id: String) -> void:
	_occupancy.erase(id)

func path(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	return _path(from,to,profile,revision,null)

# Same answer as path(). With navigation_async on, only the graph search runs on
# a worker thread; invalid input and the straight route are answered here.
func request_path(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int, owner: Object = null, priority: int = 0) -> PathRequest:
	var request := PathRequest.new()
	request.revision = revision; request.priority = priority; request.queued_usec = Time.get_ticks_usec()
	if owner != null: request.owner = weakref(owner)
	if from == null or to == null: _navigation_finish(request,_failure(&"invalid_support")); return request
	request.from = ExpeditionWorldPoint.create(from.stage_id,from.surface_id,from.position)
	request.to = ExpeditionWorldPoint.create(to.stage_id,to.surface_id,to.position)
	request.profile = profile.duplicate(true)
	if not navigation_async: _navigation_finish(request,path(request.from,request.to,request.profile,revision)); return request
	if not _current(revision) or not _profile_valid(profile) or not _candidate_point(request.from,profile["radius"],profile["height"],null) or not _candidate_point(request.to,profile["radius"],profile["height"],null):
		_navigation_finish(request,path(request.from,request.to,request.profile,revision)); return request
	var direct := _navigation_direct(request.from,request.to,request.profile,revision,null)
	if direct.ok: _navigation_finish(request,direct); return request
	var index := _navigation_queue.size()
	while index > 0 and _navigation_queue[index-1].priority < priority: index -= 1
	_navigation_queue.insert(index,request)
	navigation_pump()
	return request

func navigation_pending() -> int:
	return _navigation_queue.size()+(1 if _navigation_task >= 0 else 0)

# Collect a finished task, deliver it, and start the next queued request.
func navigation_pump() -> void:
	if _navigation_task >= 0:
		if not WorkerThreadPool.is_task_completed(_navigation_task): return
		WorkerThreadPool.wait_for_task_completion(_navigation_task)
		_navigation_task = -1
		var request := _navigation_running; var box := _navigation_box
		_navigation_running = null; _navigation_box = {}
		if request.state == &"running":
			request.compute_usec = int(box.get("usec",0))
			var result: Dictionary = box.get("result",_failure(&"navigation_budget_exceeded"))
			_navigation_finish(request,result if _current(request.revision) else _failure(&"stale_geometry"))
			_navigation_deliver(request)
	while _navigation_task < 0 and not _navigation_queue.is_empty():
		var next: PathRequest = _navigation_queue.pop_front()
		if next.state != &"queued": continue
		if not _current(next.revision):
			_navigation_finish(next,_failure(&"stale_geometry")); _navigation_deliver(next); continue
		var view := _navigation_current_view()
		next.state = &"running"; _navigation_running = next; _navigation_box = {}
		_navigation_task = WorkerThreadPool.add_task(_navigation_work.bind(view,next.from,next.to,next.profile,next.revision,_navigation_box),false,"world_navigation")

func _navigation_finish(request: PathRequest, result: Dictionary) -> void:
	request.result = result; request.state = &"done"; request.finished_usec = Time.get_ticks_usec()

func _navigation_deliver(request: PathRequest) -> void:
	var owner: Object = request.owner.get_ref() if request.owner != null else null
	if owner != null and owner.has_method("_navigation_delivered"): owner._navigation_delivered(request)

# Runs on a worker thread. It touches only the frozen view and its own box.
func _navigation_work(view: WorldGeometry, from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int, box: Dictionary) -> void:
	var started := Time.get_ticks_usec()
	box["result"] = view.path(from,to,profile,revision)
	box["usec"] = Time.get_ticks_usec()-started

# Read-only copy for the worker: _stage and _support_index are never mutated in
# place after configure, the mutable containers are copied. Its memo is private.
func _is_grid(surface_id: String) -> bool:
	_ensure_support_index()
	return _support_index.has("grids") and _support_index.grids.has(surface_id)

func _grid_lattice(surface_id: String, radius: float) -> Dictionary:
	var key := surface_id+"|"+str(radius)
	_grid_mutex.lock(); var known: Variant = _grid_cache.get(key); _grid_mutex.unlock()
	if known != null: return known
	var built := HeightGrid.lattice(_support_index.grids[surface_id],radius,true)
	_grid_mutex.lock()
	if not _grid_cache.has(key): _grid_cache[key] = built
	var result: Dictionary = _grid_cache[key]
	_grid_mutex.unlock()
	return result

## F10 H6: lattice components of a stretch, cached with its lattice.
func _grid_parts(surface_id: String, radius: float) -> Dictionary:
	var key := surface_id+"|"+str(radius)+"|parts"
	_grid_mutex.lock(); var known: Variant = _grid_cache.get(key); _grid_mutex.unlock()
	if known != null: return known
	var built := _grid_lattice(surface_id,radius)
	var parts: Dictionary = {} if built.is_empty() else HeightGrid.lattice_components(built)
	_grid_mutex.lock()
	if not _grid_cache.has(key): _grid_cache[key] = parts
	var result: Dictionary = _grid_cache[key]
	_grid_mutex.unlock()
	return result

## F10 H3: the local edge between two states of one stretch when the straight
## segment is blocked: a lattice route around steep ground (one field per
## source, kept in `field`), every leg and corner then checked by the same exact
## predicates as a straight local edge (props, temporaries and support). Cost is
## the 3D length of the legs, never below the chord.
func _navigation_grid_edge(a: Dictionary, b: Dictionary, profile: Dictionary, candidate: WorldSolidSegment, memo: Dictionary, field: Dictionary) -> Dictionary:
	var surface: String = a.surface_id
	var cell := _cell(surface)
	var built := _grid_lattice(surface,float(profile.radius))
	if built.is_empty(): return {"ok":false}
	# F10 H6: endpoints attached to no common lattice component have no lattice
	# route (the field would not reach `b`); skip the field. Same answer.
	var parts := _grid_parts(surface,float(profile.radius))
	if not field.has("labels"): field["labels"] = _grid_labels(surface,float(profile.radius),built,parts,Vector2(a.position.x,a.position.z))
	var shared := false
	for label: int in _grid_labels(surface,float(profile.radius),built,parts,Vector2(b.position.x,b.position.z)):
		if field.labels.has(label): shared = true; break
	if not shared: return {"ok":false}
	if not field.has("ok"): field.merge(HeightGrid.field(built,Vector2(a.position.x,a.position.z)))
	if not field.get("ok",false): return {"ok":false}
	var routed := HeightGrid.route(built,field,Vector2(b.position.x,b.position.z))
	if not routed.ok or routed.points.size() < 3: return {"ok":false}
	var points: Array[Vector3] = [a.position]
	for index: int in range(1,routed.points.size()-1):
		var corner: Vector2 = routed.points[index]
		points.append(Kernel.support_y(cell,Vector3(corner.x,0,corner.y)))
	points.append(b.position)
	var via: Array = []; var cost := 0.0
	for index: int in range(1,points.size()):
		if index < points.size()-1:
			var state := ExpeditionWorldPoint.create(_stage.stage_id,surface,points[index])
			if not _navigation_point(state,float(profile.radius),float(profile.height),candidate,memo): return {"ok":false}
			via.append(state.to_data())
		if not _navigation_clear(points[index-1],points[index],profile,candidate,surface,memo) or _navigation_fraction(cell,points[index-1],points[index],profile,memo) < 1.0-EPS: return {"ok":false}
		cost += points[index-1].distance_to(points[index])
	return {"ok":true,"via":via,"cost":cost}

func _navigation_current_view() -> WorldGeometry:
	var key := [configuration_revision,geometry_revision,_navigation_epoch]
	if _navigation_view != null and _navigation_view_key == key: return _navigation_view
	_ensure_support_index()
	var view := WorldGeometry.new()
	view._stage = _stage; view._support_index = _support_index; view._grid_cache = _grid_cache; view._grid_mutex = _grid_mutex
	view._temporary.assign(_temporary); view._segments.assign(_segments); view._solid_slabs.assign(_solid_slabs)
	view.geometry_revision = geometry_revision; view.configuration_revision = configuration_revision; view._navigation_epoch = _navigation_epoch
	_navigation_view = view; _navigation_view_key = key
	return view

# The local-edge test of the navigation graph (exact sweep and full support),
# used to join a route computed in the background to an actor that moved on.
func segment_walkable(surface_id: String, a: Vector3, b: Vector3, profile: Dictionary, revision: int) -> bool:
	if not _current(revision) or not _profile_valid(profile) or _cell(surface_id).is_empty(): return false
	return _navigation_clear(a,b,profile,null,surface_id,{}) and _navigation_fraction(_cell(surface_id),a,b,profile,{}) >= 1.0-EPS

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _navigation_task >= 0: WorkerThreadPool.wait_for_task_completion(_navigation_task)

func _navigation_invalidate() -> void:
	_navigation_epoch += 1; _navigation_shared = {}

# One memo per effective geometry (configuration, revision, mutation epoch) and
# full profile. It only stores the exact predicates the per-query memo stores.
func _navigation_shared_memo(profile: Dictionary) -> Dictionary:
	var key := [configuration_revision,geometry_revision,_navigation_epoch,ExpeditionCanonical.digest(profile)]
	if _navigation_shared.get("key") != key:
		_navigation_shared = {"key":key,"memo":{"point":{},"clear":{},"fraction":{},"entries":0,"hits":0,"misses":0,"peak":0,"stored":0,"released":0,"shared":true,"limit":NAVIGATION_SHARED_MEMO_LIMIT}}
	return _navigation_shared.memo

func _path(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int, candidate: WorldSolidSegment, lazy_graph: bool = true, trace: Dictionary = {}, memoize: bool = true, heuristic: bool = true) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not _profile_valid(profile): return _failure(&"invalid_profile")
	var radius: float = profile["radius"]
	var height: float = profile["height"]
	if not _candidate_point(from,radius,height,candidate) or not _candidate_point(to,radius,height,candidate): return _failure(&"invalid_support")
	var tracing: bool = trace.get("enabled",false) == true
	var query_started := Time.get_ticks_usec() if tracing else 0
	if tracing:
		trace["build_usec"] = 0; trace["surfaces"] = 0; trace["expansions"] = 0; trace["edge_tests"] = 0
	var direct := _navigation_direct(from,to,profile,revision,candidate)
	if tracing: trace["direct_usec"] = Time.get_ticks_usec()-query_started
	if direct.ok:
		if tracing: trace["direct"] = true; trace["total_usec"] = Time.get_ticks_usec()-query_started
		return direct
	var graph := {"ok":true,"nodes":{},"edges":{},"by_surface":{}}
	var context: Dictionary = {}
	if lazy_graph:
		context = _navigation_index(profile,trace,memoize)
		if not context.ok: return _failure(&"navigation_budget_exceeded")
		if memoize and candidate == null: context["memo"] = _navigation_shared_memo(profile)
		var made := _navigation_surface(graph,context,from.surface_id,from,to,profile,candidate)
		if not made.ok: return _failure(&"navigation_budget_exceeded")
		if heuristic and context.get("inadmissible",false): return _navigation_dijkstra(from,to,profile,revision,candidate,lazy_graph,trace,memoize)
	else:
		var build_started := Time.get_ticks_usec() if tracing else 0
		graph = _navigation_graph(from,to,profile,candidate)
		if tracing: trace["build_usec"] = Time.get_ticks_usec()-build_started; trace["surfaces"] = _stage["surfaces"].size()
	if not graph.ok: return _failure(&"navigation_budget_exceeded")
	if heuristic and not lazy_graph and not _navigation_admissible(graph.nodes,graph.edges): return _navigation_dijkstra(from,to,profile,revision,candidate,lazy_graph,trace,memoize)
	var memo: Dictionary = context.get("memo",{}); var query_scopes: Dictionary = context.get("query",{})
	var nodes: Dictionary = graph.nodes; var edges: Dictionary = graph.edges; var by_surface: Dictionary = graph.by_surface
	var distances := {"@from": 0.0}
	var previous: Dictionary = {}
	# A* (checkpoint35): local edges cost their exact chord and portal edges
	# ia->seam->ib, so the straight distance to @to is consistent and the first
	# @to expansion is optimal. heuristic=false keeps the original Dijkstra order.
	var goal: Vector3 = to.position
	var frontier: Array[Dictionary] = [{"id":"@from","cost":(Vector3(from.position).distance_to(goal) if heuristic else 0.0),"g":0.0}]
	var visited: Dictionary = {}; var expanded_surfaces := {}
	while not frontier.is_empty():
		var next := _navigation_heap_pop(frontier); var current: String = next.id
		if visited.has(current) or float(next.g) != float(distances[current]): continue
		visited[current] = true
		if tracing: trace["expansions"] += 1
		if current == "@to": break
		if lazy_graph and not context.prepared.has(nodes[current]["surface_id"]):
			var made := _navigation_surface(graph,context,nodes[current]["surface_id"],from,to,profile,candidate)
			if not made.ok: return _failure(&"navigation_budget_exceeded")
			if heuristic and context.get("inadmissible",false): return _navigation_dijkstra(from,to,profile,revision,candidate,lazy_graph,trace,memoize)
		# The same visibility graph is evaluated when Dijkstra expands its source
		# state. Unvisited cells/states need no pair tests. Candidate nodes, costs,
		# tie order, directed portals and all geometry checks remain identical.
		var portal_edge_count: int = edges[current].size()
		var current_cost: float = float(distances[current])
		var grid_field: Dictionary = {}
		for other: String in by_surface[nodes[current]["surface_id"]]:
			if current == other: continue
			# Exact cost before any predicate (f9_navigation_relaxation): distances
			# only decrease, so an edge the relaxation would reject now is rejected
			# below too. Skip only its geometry; order and cost stay identical.
			var local_cost := Vector3(nodes[current]["position"]).distance_to(nodes[other]["position"])
			if current_cost + local_cost + EPS >= float(distances.get(other, INF)):
				if tracing: trace["edge_skipped"] = int(trace.get("edge_skipped",0))+1
				continue
			if tracing: trace["edge_tests"] += 1
			var segment_context: Variant = {} if lazy_graph else null
			var clear_started := Time.get_ticks_usec() if tracing else 0
			var clear := _navigation_clear(nodes[current]["position"],nodes[other]["position"],profile,candidate,nodes[current]["surface_id"],memo,query_scopes.get(nodes[current]["surface_id"],{}),segment_context)
			if tracing: trace["clear_usec"] = int(trace.get("clear_usec",0))+Time.get_ticks_usec()-clear_started
			var supported := false
			if clear:
				var support_started := Time.get_ticks_usec() if tracing else 0
				supported = _navigation_fraction(_cell(nodes[current]["surface_id"]),nodes[current]["position"],nodes[other]["position"],profile,memo,segment_context if segment_context != null else {}) >= 1.0-EPS
				if tracing: trace["support_usec"] = int(trace.get("support_usec",0))+Time.get_ticks_usec()-support_started
			if clear and supported:
				edges[current].append({"to":other,"via":[],"connection_id":"","cost":local_cost})
			elif _is_grid(nodes[current]["surface_id"]):
				# F10 H3: on a stretch the local edge may bend around steep ground.
				var bent := _navigation_grid_edge(nodes[current],nodes[other],profile,candidate,memo,grid_field)
				if bent.ok: edges[current].append({"to":other,"via":bent.via,"connection_id":"","cost":bent.cost})
		for edge: Dictionary in edges[current]:
			var route_cost: float = float(distances[current]) + float(edge["cost"])
			if route_cost + EPS >= float(distances.get(edge["to"], INF)): continue
			distances[edge["to"]] = route_cost
			previous[edge["to"]] = {"from": current, "edge": edge}
			_navigation_heap_push(frontier,edge["to"],route_cost+(Vector3(nodes[edge["to"]]["position"]).distance_to(goal) if heuristic else 0.0),route_cost)
		# This state is expanded once. Previous records retain their accepted
		# edges; unselected local visibility edges need no lifetime past here.
		if lazy_graph:
			edges[current].resize(portal_edge_count)
			var completed_surface: String = nodes[current]["surface_id"]
			expanded_surfaces[completed_surface] = int(expanded_surfaces.get(completed_surface,0))+1
			if expanded_surfaces[completed_surface] == by_surface[completed_surface].size():
				if not memo.get("shared",false): _navigation_memo_release(memo,completed_surface)
				context.query.erase(completed_surface)
	if tracing:
		trace["total_usec"] = Time.get_ticks_usec()-query_started; trace["states"] = nodes.size()
		trace["memo_entries"] = memo.get("entries",0); trace["memo_hits"] = memo.get("hits",0); trace["memo_misses"] = memo.get("misses",0)
		trace["memo_peak"] = memo.get("peak",0); trace["memo_stored"] = memo.get("stored",0); trace["memo_released"] = memo.get("released",0)
	if not visited.has("@to"): return _failure(&"unreachable")
	var steps: Array[Dictionary] = []
	var cursor := "@to"
	while cursor != "@from":
		steps.push_front(previous[cursor])
		cursor = previous[cursor]["from"]
	var route := _navigation_route(from.to_data(),steps,nodes)
	route["cost"] = distances["@to"]
	return _success(route)

# A graph edge cheaper than its chord would make the straight-distance estimate
# inconsistent (only synthetic graphs do this; portal edges cost ia->seam->ib).
# The whole query is then repeated with the original Dijkstra order.
func _navigation_dijkstra(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int, candidate: WorldSolidSegment, lazy_graph: bool, trace: Dictionary, memoize: bool) -> Dictionary:
	var result := _path(from,to,profile,revision,candidate,lazy_graph,trace,memoize,false)
	if trace.get("enabled",false) == true: trace["heuristic_fallback"] = true
	return result

static func _navigation_admissible(nodes: Dictionary, edges: Dictionary) -> bool:
	for state: String in edges:
		for edge: Dictionary in edges[state]:
			if float(edge["cost"])+EPS < Vector3(nodes[state]["position"]).distance_to(nodes[edge["to"]]["position"]): return false
	return true

func _navigation_direct(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int, candidate: WorldSolidSegment) -> Dictionary:
	# A clear straight ground route may cross any legal point of each opening.
	# Keep its support-plane transitions and recheck a proposed temporary segment.
	var direct := ground_line_to(from,to,profile,revision)
	if direct["ok"]:
		var route: Array = direct["data"]["points"]
		var clear := true
		for index: int in range(1,route.size()):
			if not _clear_path_segment(route[index-1]["position"],route[index]["position"],profile,candidate,route[index-1]["surface_id"]): clear = false; break
		if clear:
			route[-1] = to.to_data()
			return _success({"points":route,"connection_ids":_route_connection_ids(route),"cost":direct["data"]["cost"]})
	return _failure(&"unsupported_contact")

# Generation scopes never replace _stage: every body/support/mass predicate
# still sees the whole canonical world and the original ordered pair.
func _navigation_endpoints(profile: Dictionary, control: Dictionary = {}) -> Dictionary:
	var endpoints: Dictionary = {}
	for endpoint: Dictionary in _stage["connectors"]:
		if not WorldConnectivityBatch.tick(control,"endpoint_checks"): return {"ok":false}
		if not endpoint["kind"] in profile["connector_kinds"] or float(endpoint["headroom"])+EPS < float(profile["height"]): continue
		endpoints[endpoint["connector_id"]] = endpoint
	return {"ok":true,"endpoints":endpoints}

func _navigation_index(profile: Dictionary, trace: Dictionary = {}, memoize: bool = true) -> Dictionary:
	var started := Time.get_ticks_usec() if trace.get("enabled",false) == true else 0
	var selected := _navigation_endpoints(profile)
	if not selected.ok: return selected
	var endpoints: Dictionary = selected.endpoints; var incidents := {}
	for connection: Dictionary in _stage["connections"]:
		if not endpoints.has(connection["a_connector"]) or not endpoints.has(connection["b_connector"]): continue
		var a: String = endpoints[connection["a_connector"]]["surface_id"]; var b: String = endpoints[connection["b_connector"]]["surface_id"]
		var ids: Array = [a] if a == b else [a,b]
		for id: String in ids:
			if not incidents.has(id): incidents[id] = []
			incidents[id].append(connection)
	if started > 0: trace["build_usec"] = Time.get_ticks_usec()-started
	return {"ok":true,"endpoints":endpoints,"incidents":incidents,"generated":{},"prepared":{},"query":{},"trace":trace,"memo":{"point":{},"clear":{},"fraction":{},"entries":0,"hits":0,"misses":0,"peak":0,"stored":0,"released":0} if memoize else {}}

func _navigation_surface(graph: Dictionary, context: Dictionary, id: String, from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, candidate: WorldSolidSegment) -> Dictionary:
	if context.prepared.has(id): return {"ok":true}
	var cell := _cell(id)
	if cell.is_empty(): return {"ok":false}
	var started := Time.get_ticks_usec() if context.trace.get("enabled",false) == true else 0
	var fresh: Array = []
	for connection: Dictionary in context.incidents.get(id,[]):
		if not context.generated.has(connection["connection_id"]): fresh.append(connection)
	var part := _navigation_graph(from,to,profile,candidate,{},[],{},{"endpoints":context.endpoints,"connections":fresh,"surfaces":[cell],"memo":context.memo})
	if not part.ok: return part
	for state: String in part.nodes:
		if graph.nodes.has(state):
			if graph.nodes[state] != part.nodes[state]: return {"ok":false}
		else:
			graph.nodes[state] = part.nodes[state]; graph.edges[state] = []
			var support: String = part.nodes[state]["surface_id"]
			if not graph.by_surface.has(support): graph.by_surface[support] = []
			graph.by_surface[support].append(state)
	for state: String in part.edges:
		for edge: Dictionary in part.edges[state]:
			if not graph.edges[state].has(edge): graph.edges[state].append(edge)
	for connection: Dictionary in fresh: context.generated[connection["connection_id"]] = true
	if not _navigation_admissible(graph.nodes,part.edges): context["inadmissible"] = true
	# Every incident connection is now generated. Future slices cannot append
	# another local state here. Sorting matches the original eager producer.
	if not graph.by_surface.has(id): graph.by_surface[id] = []
	graph.by_surface[id].sort(); context.prepared[id] = true
	context.query[id] = _navigation_mass_context(graph,id,profile)
	context.query[id]["trace"] = context.trace
	if started > 0:
		context.trace["build_usec"] += Time.get_ticks_usec()-started
		context.trace["surfaces"] += 1
	return {"ok":true}

# The completed bin is immutable. Every subsequent local segment has endpoints
# in this exact finite envelope, so the global broadphase supplies a conservative
# subset for all of them. Keep original mass order and the same pair filter/sweep.
func _navigation_mass_context(graph: Dictionary, id: String, profile: Dictionary) -> Dictionary:
	if graph.by_surface[id].is_empty(): return {}
	var low: Vector3 = graph.nodes[graph.by_surface[id][0]]["position"]; var high := low
	for state: String in graph.by_surface[id]:
		var point: Vector3 = graph.nodes[state]["position"]
		low = low.min(point); high = high.max(point)
	var masses := SolidPrism.spatial_candidates(_support_index.solid_prisms,_support_index.mass_broadphase,low,high,profile.radius,profile.height)
	var volume_ids: Array[int] = []
	for index: int in _stage["volumes"].size():
		var box: AABB = _stage["volumes"][index]; var outside := false
		for axis: int in 3:
			var margin: float = profile.radius if axis != 1 else profile.height
			var minimum := float(box.position[axis])-margin-EPS
			var maximum := float(box.position[axis])+float(box.size[axis])+(float(profile.radius) if axis != 1 else 0.0)+EPS
			if float(high[axis]) < minimum or float(low[axis]) > maximum: outside = true; break
		if not outside: volume_ids.append(index)
	return {"items":masses,"index":SolidPrism.spatial_index(masses),"volumes":volume_ids}

func _navigation_graph(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, candidate: WorldSolidSegment, terminals: Dictionary = {}, pairs: Array = [], control: Dictionary = {}, generation: Dictionary = {}) -> Dictionary:
	var radius: float = profile.radius; var height: float = profile.height
	var memo: Dictionary = generation.get("memo",{})
	var nodes: Dictionary = terminals.duplicate(true) if not terminals.is_empty() else {"@from":from.to_data(),"@to":to.to_data()}
	if not WorldConnectivityBatch.reserve(control,nodes,2): return {"ok":false}
	var edges: Dictionary = {}
	for id: String in nodes: edges[id] = []
	var endpoints: Dictionary = generation.get("endpoints",{})
	if not generation.has("endpoints"):
		var selected := _navigation_endpoints(profile,control)
		if not selected.ok: return selected
		endpoints = selected.endpoints
	# Portals are traversable intervals, clipped by the body radius. Visibility
	# candidates include interval ends, source/destination projections and obstacle
	# corners. A blocked center never removes the whole opening from the graph.
	for connection: Dictionary in generation.get("connections",_stage["connections"]):
		if not WorldConnectivityBatch.tick(control,"connections"): return {"ok":false}
		if not endpoints.has(connection["a_connector"]) or not endpoints.has(connection["b_connector"]): continue
		var a: Dictionary = endpoints[connection["a_connector"]]
		var b: Dictionary = endpoints[connection["b_connector"]]
		var index := 0
		var scratch_mark := int(control.get("scratch_live",0))
		var contribution := _navigation_seams(a,b,from.position,to.position,radius,candidate,height,pairs,control)
		if not contribution.ok: return contribution
		for seam: Vector3 in contribution.points:
			if not WorldConnectivityBatch.tick(control,"portal_checks"): return {"ok":false}
			var pa := ExpeditionWorldPoint.create(from.stage_id,a["surface_id"],seam)
			var pb := ExpeditionWorldPoint.create(from.stage_id,b["surface_id"],seam)
			if not _navigation_point(pa,radius,height,candidate,memo) or not _navigation_point(pb,radius,height,candidate,memo): continue
			# Keep an inset state on each support, allowing turns between adjacent
			# openings without forcing the body to travel along their shared edge.
			var ia := Kernel.support_y(_cell(a["surface_id"]),seam-Vector3(a["outward"])*radius)
			var ib := Kernel.support_y(_cell(b["surface_id"]),seam-Vector3(b["outward"])*radius)
			var inside_a := ExpeditionWorldPoint.create(from.stage_id,a["surface_id"],ia)
			var inside_b := ExpeditionWorldPoint.create(from.stage_id,b["surface_id"],ib)
			if not _navigation_point(inside_a,radius,height,candidate,memo): inside_a = pa; ia = seam
			if not _navigation_point(inside_b,radius,height,candidate,memo): inside_b = pb; ib = seam
			if not _navigation_clear(ia,seam,profile,candidate,a["surface_id"],memo) or not _navigation_clear(seam,ib,profile,candidate,b["surface_id"],memo): continue
			if _navigation_fraction(_cell(a["surface_id"]),ia,seam,profile,memo) < 1.0-EPS or _navigation_fraction(_cell(b["surface_id"]),seam,ib,profile,memo) < 1.0-EPS: continue
			if not WorldConnectivityBatch.tick(control,"states",2): return {"ok":false}
			var token := str(index) if pairs.is_empty() else ExpeditionCanonical.digest([seam,ia,ib])
			var aid := "@portal/%s/%s/a"%[connection["connection_id"],token]
			var bid := "@portal/%s/%s/b"%[connection["connection_id"],token]
			index += 1
			var ad := inside_a.to_data(); var bd := inside_b.to_data(); var av := pa.to_data(); var bv := pb.to_data()
			nodes[aid] = ad; nodes[bid] = bd; edges[aid] = []; edges[bid] = []
			var cost := ia.distance_to(seam)+seam.distance_to(ib)
			if connection["forward"]: edges[aid].append({"to":bid,"via":[av,bv],"connection_id":connection["connection_id"],"cost":cost})
			if connection["backward"]: edges[bid].append({"to":aid,"via":[bv,av],"connection_id":connection["connection_id"],"cost":cost})
			if not WorldConnectivityBatch.reserve(control,[aid,bid,ad,bd,edges[aid],edges[bid]]): return {"ok":false}
		WorldConnectivityBatch.release_scratch(control,scratch_mark)
	# Visibility graph corners give detours around AABBs within convex supports.
	_ensure_support_index()
	for cell: Dictionary in generation.get("surfaces",_stage["surfaces"]):
		# F10 H6: a stretch only holds corners inside its outline (a point
		# outside it is never a valid state there); skip the others early.
		var outline := HeightGrid.bounds(_support_index.grids[cell.surface_id]).grow(1.0) if _is_grid(cell.surface_id) else Rect2()
		for volume_index: int in range(_volumes().size()):
			var box: AABB = _volumes()[volume_index]
			for x: float in [box.position.x - radius - EPS * 4.0, box.end.x + radius + EPS * 4.0]:
				for z: float in [box.position.z - radius - EPS * 4.0, box.end.z + radius + EPS * 4.0]:
					if outline.has_area() and not outline.has_point(Vector2(x,z)): continue
					if not WorldConnectivityBatch.tick(control,"landmark_checks"): return {"ok":false}
					var position := Kernel.support_y(cell, Vector3(x, 0, z))
					var point := ExpeditionWorldPoint.create(from.stage_id, cell["surface_id"], position)
					if not _navigation_point(point,radius,height,candidate,memo): continue
					var id := "@corner/%s/%d/%s/%s" % [cell["surface_id"], volume_index, x, z]
					if not WorldConnectivityBatch.tick(control,"states"): return {"ok":false}
					if not WorldConnectivityBatch.reserve(control,[id,point.to_data(),[]]): return {"ok":false}
					nodes[id] = point.to_data()
					edges[id] = []
	# Generate detour states from the mass cut by THIS support plane/profile.
	# Candidate padding only makes an outside point representable; all contacts
	# and support predicates retain their original EPS and are checked again.
	for cell: Dictionary in generation.get("surfaces",_stage["surfaces"]):
		var bounds := AABB(cell["vertices"][0],Vector3.ZERO)
		for vertex: Vector3 in cell["vertices"]: bounds = bounds.expand(vertex)
		for prism: Dictionary in SolidPrism.spatial_candidates(_support_index.solid_prisms,_support_index.mass_broadphase,bounds.position,bounds.end,radius,height):
			if not WorldConnectivityBatch.tick(control,"landmark_checks"): return {"ok":false}
			if prism.support_surface_id == cell["surface_id"]: continue
			var blocked := SolidPrism.blocking_polygon(prism,cell,radius,height)
			if blocked.is_empty(): continue
			var padding := EPS*4.0
			for vertex: Vector2 in blocked: padding = maxf(padding,point_tolerance(Vector3(vertex.x,0,vertex.y),Vector3.ZERO))
			var corner_index := 0
			for outline: PackedVector2Array in Geometry2D.offset_polygon(blocked,padding,Geometry2D.JOIN_MITER):
				for corner: Vector2 in outline:
					if not WorldConnectivityBatch.tick(control,"landmark_checks"): return {"ok":false}
					var position := Kernel.support_y(cell,Vector3(corner.x,0,corner.y))
					var point := ExpeditionWorldPoint.create(from.stage_id,cell["surface_id"],position)
					if not _navigation_point(point,radius,height,candidate,memo): continue
					var id := "@mass/%s/%s/%d"%[cell["surface_id"],prism.volume_id,corner_index]; corner_index += 1
					if not WorldConnectivityBatch.tick(control,"states"): return {"ok":false}
					if not WorldConnectivityBatch.reserve(control,[id,point.to_data(),[]]): return {"ok":false}
					nodes[id] = point.to_data(); edges[id] = []
	var segments: Array = []
	var segment_ids: Array = _segments.keys(); segment_ids.sort()
	for id: String in segment_ids: segments.append(_segments[id])
	if candidate != null: segments.append(candidate)
	for cell: Dictionary in generation.get("surfaces",_stage["surfaces"]):
		for segment_index: int in segments.size():
			var segment := segments[segment_index] as WorldSolidSegment
			for corner_index: int in segment.corners(radius).size():
				if not WorldConnectivityBatch.tick(control,"landmark_checks"): return {"ok":false}
				var position := Kernel.support_y(cell,segment.corners(radius)[corner_index])
				var point := ExpeditionWorldPoint.create(from.stage_id,cell["surface_id"],position)
				if not _navigation_point(point,radius,height,candidate,memo): continue
				var id := "@segment/%s/%d/%d" % [cell["surface_id"],segment_index,corner_index]
				if not WorldConnectivityBatch.tick(control,"states"): return {"ok":false}
				if not WorldConnectivityBatch.reserve(control,[id,point.to_data(),[]]): return {"ok":false}
				nodes[id] = point.to_data(); edges[id] = []
	var by_surface: Dictionary = {}
	var ids: Array = nodes.keys(); ids.sort()
	for id: String in ids:
		# Sorted IDs and surface bins retain existing ID strings by reference.
		if not WorldConnectivityBatch.tick(control,"storage_bytes",192): return {"ok":false}
		var surface: String = nodes[id]["surface_id"]
		if not by_surface.has(surface): by_surface[surface] = []
		by_surface[surface].append(id)
	return {"ok":true,"nodes":nodes,"edges":edges,"by_surface":by_surface}

# Private memo is born and discarded with ONE synchronous path query. Its
# stage, full profile, candidate and effective geometry never cross a query.
# Keep ordered Vector3 endpoints as dictionary keys: no EPS/string rounding or
# reverse-edge inference. Saturation computes normally without retaining more.
static func _navigation_memo_get(memo: Dictionary, family: String, surface: String, a: Vector3, b: Vector3) -> Variant:
	if memo.is_empty(): return null
	var surfaces: Dictionary = memo[family]
	var starts: Dictionary = surfaces.get(surface,{})
	var ends: Dictionary = starts.get(a,{})
	var value: Variant = ends.get(b)
	memo["misses" if value == null else "hits"] += 1
	return value

static func _navigation_memo_put(memo: Dictionary, family: String, surface: String, a: Vector3, b: Vector3, value: Variant) -> void:
	if memo.is_empty() or int(memo.entries) >= int(memo.get("limit",NAVIGATION_MEMO_LIMIT)): return
	var surfaces: Dictionary = memo[family]
	if not surfaces.has(surface): surfaces[surface] = {}
	if not surfaces[surface].has(a): surfaces[surface][a] = {}
	surfaces[surface][a][b] = value; memo.entries += 1; memo.stored += 1
	memo.peak = maxi(memo.peak,memo.entries)

# Every local state of a completed support has now expanded. All incident
# connections were already generated before its first expansion; no subsequent
# slice can query a new point or local edge here. Recycle the bounded memo.
static func _navigation_memo_release(memo: Dictionary, surface: String) -> void:
	if memo.is_empty(): return
	var removed := 0
	for family: String in ["point","clear","fraction"]:
		var surfaces: Dictionary = memo[family]
		for ends: Dictionary in surfaces.get(surface,{}).values(): removed += ends.size()
		surfaces.erase(surface)
	memo.entries -= removed; memo.released += removed

func _navigation_point(point: ExpeditionWorldPoint, radius: float, height: float, candidate: WorldSolidSegment, memo: Dictionary) -> bool:
	if point.stage_id != _stage.stage_id: return false
	var value: Variant = _navigation_memo_get(memo,"point",point.surface_id,point.position,point.position)
	if value != null: return bool(value)
	var accepted := _candidate_point(point,radius,height,candidate)
	_navigation_memo_put(memo,"point",point.surface_id,point.position,point.position,accepted)
	return accepted

func _navigation_clear(a: Vector3, b: Vector3, profile: Dictionary, candidate: WorldSolidSegment, surface: String, memo: Dictionary, mass_context: Dictionary = {}, segment_context: Variant = null) -> bool:
	var value: Variant = _navigation_memo_get(memo,"clear",surface,a,b)
	if value != null: return bool(value)
	var accepted := _clear_path_segment(a,b,profile,candidate,surface,mass_context,segment_context)
	_navigation_memo_put(memo,"clear",surface,a,b,accepted)
	return accepted

func _navigation_fraction(cell: Dictionary, a: Vector3, b: Vector3, profile: Dictionary, memo: Dictionary, segment_context: Dictionary = {}) -> float:
	var value: Variant = _navigation_memo_get(memo,"fraction",cell.surface_id,a,b)
	if value != null: return float(value)
	_ensure_support_index()
	var fraction: float = SupportPatch._fraction_prepared(cell,a,b,profile,_support_index,segment_context.get("members",{}))
	_navigation_memo_put(memo,"fraction",cell.surface_id,a,b,fraction)
	return fraction

func _navigation_seams(a: Dictionary, b: Dictionary, source: Vector3, target: Vector3, radius: float, candidate: WorldSolidSegment, height: float, pairs: Array, control: Dictionary) -> Dictionary:
	if pairs.is_empty(): return {"ok":true,"points":_portal_candidates(a,b,source,target,radius,candidate,height)}
	var common := _portal_common_offsets(a,b,radius,candidate,height,control); var cache: Dictionary = {}; var unique: Dictionary = {}
	if not control.is_empty() and not control.error_code.is_empty(): return {"ok":false}
	_ensure_support_index()
	if _is_grid(a.surface_id) and _is_grid(b.surface_id): return _grid_seam_points(a,b,common,control)
	for pair: Dictionary in pairs:
		if not WorldConnectivityBatch.tick(control,"portal_pairs"): return {"ok":false}
		var points := _portal_pair_candidates(a,b,pair.from.position,pair.to.position,common,cache,control)
		if not control.is_empty() and not control.error_code.is_empty(): return {"ok":false}
		if not WorldConnectivityBatch.tick(control,"pair_candidates",points.size()): return {"ok":false}
		for point: Vector3 in points:
			if not unique.has(point) and not WorldConnectivityBatch.scratch(control,[point,true],2): return {"ok":false}
			unique[point] = true
	var ordered: Array = unique.keys()
	ordered.sort_custom(func(x: Vector3,y: Vector3) -> bool: return ExpeditionCanonical.encode(x) < ExpeditionCanonical.encode(y))
	return {"ok":true,"points":ordered}

## F10 H6: a batch's seam between two stretches keeps the opening's own
## offsets (ends, insets, centre and landmarks) plus one every GRID_SEAM_STEP,
## instead of every pair's projections (the same opening, far fewer states;
## certificates prove existence, never shortest cost).
func _grid_seam_points(a: Dictionary, b: Dictionary, common: Array[float], control: Dictionary) -> Dictionary:
	var center: Vector3 = a.position; var normal: Vector3 = a.outward; var tangent := Vector3(-normal.z,0,normal.x)
	var half_width := minf(float(a.width),float(b.width))*0.5
	var offsets: Array[float] = common.duplicate()
	for k: int in range(1,int(floor(2.0*half_width/GRID_SEAM_STEP))+1):
		var offset := -half_width+float(k)*GRID_SEAM_STEP
		if offset < half_width: offsets.append(offset)
	offsets.sort()
	var unique: Dictionary = {}; var previous: Variant = null
	for offset: float in offsets:
		if not WorldConnectivityBatch.tick(control,"offset_checks"): return {"ok":false}
		var point := Kernel.support_y(_cell(a.surface_id),center+tangent*offset)
		if previous != null and Vector3(previous).distance_to(point) <= EPS: continue
		previous = point
		if not unique.has(point) and not WorldConnectivityBatch.scratch(control,[point,true],2): return {"ok":false}
		unique[point] = true
	var ordered: Array = unique.keys()
	ordered.sort_custom(func(x: Vector3,y: Vector3) -> bool: return ExpeditionCanonical.encode(x) < ExpeditionCanonical.encode(y))
	return {"ok":true,"points":ordered}

## F10 H6: a straight local edge between two states whose bodies lie inside one
## stretch is blocked when the stretch's capsule test fails (a steep triangle
## within the body's reach): the exact predicates are then skipped.
func _grid_straight_blocked(surface_id: String, a: Vector3, b: Vector3, profile: Dictionary) -> bool:
	if not _is_grid(surface_id): return false
	var view: Dictionary = _support_index.grids[surface_id]; var radius := float(profile.radius)
	var p := Vector2(a.x,a.z); var q := Vector2(b.x,b.z)
	return HeightGrid.disk_clear(view,p,radius,true) and HeightGrid.disk_clear(view,q,radius,true) and not HeightGrid.segment_clear(view,p,q,radius,true)

## F10 H6: labels of the lattice components a point attaches to, cached.
func _grid_labels(surface_id: String, radius: float, built: Dictionary, parts: Dictionary, point: Vector2) -> Dictionary:
	var key := surface_id+"|"+str(radius)+"|labels"
	_grid_mutex.lock()
	if not _grid_cache.has(key): _grid_cache[key] = {}
	var known: Variant = _grid_cache[key].get(point)
	_grid_mutex.unlock()
	if known != null: return known
	var labels := HeightGrid.attached_labels(built,parts,point)
	_grid_mutex.lock(); _grid_cache[key][point] = labels; _grid_mutex.unlock()
	return labels

func connectivity_batch(root: ExpeditionWorldPoint, targets: Array[ExpeditionWorldPoint], profile: Dictionary, revision: int, cancellation: Callable = Callable(), budget: Dictionary = {}) -> Dictionary:
	return WorldConnectivityBatch.execute(self,root,targets,profile,revision,cancellation,budget)

func connectivity_witness(certificate: Dictionary, index: int, outward: bool, revision: int) -> Dictionary:
	return WorldConnectivityBatch.witness(self,certificate,index,outward,revision)

static func _navigation_route(start: Dictionary, steps: Array[Dictionary], nodes: Dictionary) -> Dictionary:
	var points: Array = [start.duplicate(true)]; var connections: Array[String] = []; var cost := 0.0
	for step: Dictionary in steps:
		var edge: Dictionary = step["edge"]
		points.append_array(edge["via"]); points.append(nodes[edge["to"]]); cost += float(edge.cost)
		if edge.has("connection_ids"): connections.append_array(edge.connection_ids)
		elif not edge["connection_id"].is_empty(): connections.append(edge["connection_id"])
	return {"points":points,"connection_ids":connections,"cost":cost}

static func _navigation_heap_before(a: Dictionary, b: Dictionary) -> bool:
	return float(a.cost) < float(b.cost) if a.cost != b.cost else str(a.id) < str(b.id)

static func _navigation_heap_push(heap: Array[Dictionary], id: String, cost: float, g: float = NAN) -> void:
	heap.append({"id":id,"cost":cost,"g":(cost if is_nan(g) else g)}); var index := heap.size()-1
	while index > 0:
		var parent := (index-1)>>1
		if not _navigation_heap_before(heap[index],heap[parent]): break
		var swap: Dictionary = heap[parent]; heap[parent] = heap[index]; heap[index] = swap; index = parent

static func _navigation_heap_pop(heap: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = heap[0]; var last: Dictionary = heap.pop_back()
	if heap.is_empty(): return result
	heap[0] = last; var index := 0
	while index*2+1 < heap.size():
		var child := index*2+1
		if child+1 < heap.size() and _navigation_heap_before(heap[child+1],heap[child]): child += 1
		if not _navigation_heap_before(heap[child],heap[index]): break
		var swap: Dictionary = heap[index]; heap[index] = heap[child]; heap[child] = swap; index = child
	return result

func _portal_candidates(a: Dictionary, b: Dictionary, source: Vector3, target: Vector3, radius: float, candidate: WorldSolidSegment, height: float = 0.0) -> Array[Vector3]:
	return _portal_pair_candidates(a,b,source,target,_portal_common_offsets(a,b,radius,candidate,height),{})

func _portal_common_offsets(a: Dictionary, b: Dictionary, radius: float, candidate: WorldSolidSegment, height: float, control: Dictionary = {}) -> Array[float]:
	var center: Vector3 = a["position"]
	var normal: Vector3 = a["outward"]
	var tangent := Vector3(-normal.z,0,normal.x)
	var half_width := minf(float(a["width"]),float(b["width"]))*0.5
	var inset := maxf(0.0,half_width-radius)
	var offsets: Array[float] = [-half_width,-inset,0.0,inset,half_width]
	var landmarks: Array[Vector3] = []
	var cell := _cell(a["surface_id"])
	var bounds := AABB(cell.vertices[0],Vector3.ZERO)
	for vertex: Vector3 in cell.vertices: bounds = bounds.expand(vertex)
	# Relevant mass landmarks belong to this support's body envelope. Their set
	# must not depend on how broadphase buckets happen to overlap the seam.
	for prism: Dictionary in SolidPrism.spatial_candidates(_support_index.solid_prisms,_support_index.mass_broadphase,bounds.position,bounds.end,radius,height):
		if not WorldConnectivityBatch.tick(control,"landmark_checks"): return []
		if prism.support_surface_id == a["surface_id"]: continue
		for vertex: Vector2 in SolidPrism.blocking_polygon(prism,cell,radius,height): landmarks.append(Vector3(vertex.x,center.y,vertex.y))
	for box: AABB in _volumes():
		if not WorldConnectivityBatch.tick(control,"landmark_checks"): return []
		for x: float in [box.position.x-radius-EPS*4.0,box.end.x+radius+EPS*4.0]:
			for z: float in [box.position.z-radius-EPS*4.0,box.end.z+radius+EPS*4.0]: landmarks.append(Vector3(x,center.y,z))
	for segment: WorldSolidSegment in _segments.values():
		if not WorldConnectivityBatch.tick(control,"landmark_checks"): return []
		landmarks.append_array(segment.corners(radius))
	if candidate != null: landmarks.append_array(candidate.corners(radius))
	for point: Vector3 in landmarks:
		if not WorldConnectivityBatch.tick(control,"landmark_checks") or not WorldConnectivityBatch.scratch(control,[point,0.0],2): return []
		offsets.append(clampf((point-center).dot(tangent),-half_width,half_width))
	# Repeated mass vertices often contribute the exact same offset. Removing only
	# exact duplicates before each pair sorts them preserves its EPS representative.
	var seen: Dictionary = {}
	for offset: float in offsets: seen[offset] = true
	var unique: Array[float] = []; unique.assign(seen.keys()); unique.sort()
	return unique

func _portal_pair_candidates(a: Dictionary, b: Dictionary, source: Vector3, target: Vector3, common: Array[float], point_cache: Dictionary, control: Dictionary = {}) -> Array[Vector3]:
	var center: Vector3 = a.position; var normal: Vector3 = a.outward; var tangent := Vector3(-normal.z,0,normal.x)
	var half_width := minf(a.width,b.width)*0.5
	var offsets: Array[float] = common.duplicate()
	for point: Vector3 in [source,target]: offsets.append(clampf((point-center).dot(tangent),-half_width,half_width))
	var delta := target-source
	var denominator := delta.dot(normal)
	if absf(denominator) > EPS:
		var intersection := source+delta*((center-source).dot(normal)/denominator)
		offsets.append(clampf((intersection-center).dot(tangent),-half_width,half_width))
	offsets.sort()
	var result: Array[Vector3] = []
	for offset: float in offsets:
		if not WorldConnectivityBatch.tick(control,"offset_checks"): return []
		if not point_cache.has(offset):
			if not WorldConnectivityBatch.scratch(control,[offset,Vector3.ZERO],2): return []
			point_cache[offset] = Kernel.support_y(_cell(a["surface_id"]),center+tangent*offset)
		var point: Vector3 = point_cache[offset]
		if result.is_empty() or result[-1].distance_to(point) > EPS: result.append(point)
	return result

func _route_connection_ids(route: Array) -> Array[String]:
	var result: Array[String] = []
	_ensure_support_index()
	for index: int in range(1,route.size()):
		if route[index-1]["surface_id"] == route[index]["surface_id"]: continue
		var found := false; var point: Vector3 = route[index]["position"]
		for a: Dictionary in _support_index.ports.get(route[index-1]["surface_id"],[]):
			if not SupportPatch.on_opening(a.surface_id,a.connector_id,point,_support_index): continue
			for transition: Dictionary in _support_index.transitions.get(a.connector_id,[]):
				var b: Dictionary = _support_index.endpoints[transition.other_id]
				if transition.allowed and b.surface_id == route[index]["surface_id"] and SupportPatch.on_opening(b.surface_id,b.connector_id,point,_support_index):
					result.append(transition.connection_id); found = true; break
			if found: break
	return result

func sweep(from: Vector3, to: Vector3, collider: Dictionary, revision: int, mask: StringName = &"all") -> Dictionary:
	return _sweep(from,to,collider,revision,mask,{})

func ground_sweep(surface_id: String, from: Vector3, to: Vector3, collider: Dictionary, revision: int) -> Dictionary:
	return _ground_sweep(surface_id,from,to,collider,revision,{})

func _ground_sweep(surface_id: String, from: Vector3, to: Vector3, collider: Dictionary, revision: int, mass_context: Dictionary, segment_context: Variant = null) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not collider.has_all(["radius","height"]) or not _finite_number(collider["radius"]) or not _finite_number(collider["height"]) or float(collider["radius"]) < 0 or float(collider["height"]) < 0: return _failure(&"invalid_collider")
	var cell := _cell(surface_id)
	if cell.is_empty() or not from.is_finite() or not to.is_finite() or not Kernel.contains(cell,from) or not Kernel.contains(cell,to): return _failure(&"invalid_support")
	var trace: Dictionary = mass_context.get("trace",{})
	var tracing: bool = trace.get("enabled",false) == true
	var members_started := Time.get_ticks_usec() if tracing else 0
	var excluded: Dictionary = {}
	if segment_context != null and segment_context.has("members"): excluded = segment_context.members
	else:
		excluded = SupportPatch.members(surface_id,Vector2(from.x,from.z),Vector2(to.x,to.z),float(collider["radius"]),float(collider["height"]),_support_index)
		if segment_context != null: segment_context["members"] = excluded
	if tracing: trace["members_usec"] = int(trace.get("members_usec",0))+Time.get_ticks_usec()-members_started
	return _sweep(from,to,collider,revision,&"all",excluded,mass_context)

func _sweep(from: Vector3, to: Vector3, collider: Dictionary, revision: int, mask: StringName, excluded_supports: Dictionary, mass_context: Dictionary = {}) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not from.is_finite() or not to.is_finite() or not collider.has_all(["radius", "height"]) or not _finite_number(collider["radius"]) or not _finite_number(collider["height"]) or float(collider["radius"]) < 0.0 or float(collider["height"]) < 0.0: return _failure(&"invalid_collider")
	if mask not in [&"all",&"supporting_slabs"]: return _failure(&"invalid_mask")
	var fraction := 1.0
	var normal := Vector3.ZERO
	var hit_id := ""
	var volumes: Array = _volumes() if mask == &"all" else _solid_slabs
	var volume_ids: Array = range(volumes.size())
	if mask == &"all" and mass_context.has("volumes"):
		volume_ids = mass_context.volumes.duplicate()
		# Temporaries always use the complete current list, after authored indices.
		for index: int in range(_stage["volumes"].size(),volumes.size()): volume_ids.append(index)
	for index: int in volume_ids:
		var volume: AABB = volumes[index]
		var radius: float = collider["radius"]
		var height: float = collider["height"]
		var hit := Kernel.sweep_box(from,to,volume,radius,height)
		if hit.is_empty() or float(hit["fraction"]) > fraction: continue
		fraction = hit["fraction"]
		normal = hit["normal"]
		if mask == &"supporting_slabs":
			hit_id = "%s/slab/%d" % [_stage["stage_id"],index]
		elif index < _stage["volumes"].size():
			hit_id = "%s/volume/%d" % [_stage["stage_id"],index]
		else:
			var ids: Array = _temporary.keys()
			ids.sort()
			hit_id = "temporary/"+str(ids[index-_stage["volumes"].size()])
	_ensure_support_index()
	for prism: Dictionary in SolidPrism.spatial_candidates(mass_context.get("items",_support_index.solid_prisms),mass_context.get("index",_support_index.mass_broadphase),from,to,float(collider["radius"]),float(collider["height"])):
		if excluded_supports.has(prism.support_surface_id): continue
		var hit := SolidPrism.sweep(from,to,prism,float(collider["radius"]),float(collider["height"]))
		if hit.is_empty() or float(hit["fraction"]) > fraction: continue
		fraction = hit["fraction"]; normal = hit["normal"]; hit_id = "terrain/"+str(prism.volume_id)
	# F10 H2: stretch ground. The collider's centre line meets the support; the
	# body's radius on a stretch is enforced by its support, not by the mass.
	var grid_boxes: Dictionary = _support_index.grid_boxes if _support_index.has("grid_boxes") else {}
	for id: String in _grid_box_candidates(from,to):
		if excluded_supports.has(id): continue
		if Kernel.sweep_box(from,to,grid_boxes[id],0.0,0.0,false).is_empty(): continue
		var view: Dictionary = _support_index.grids[id]
		var at := HeightGrid.ground_fraction(view,from,to,EPS)
		if at < 0.0 or at > fraction: continue
		fraction = at; hit_id = "terrain/grid/"+id
		var touched := from.lerp(to,at)
		var triangle := HeightGrid.triangle_at(view,touched.x,touched.z)
		normal = HeightGrid.triangle_normal(view,triangle) if triangle >= 0 else Vector3.UP
	if mask == &"all":
		var segment_ids: Array = _segments.keys(); segment_ids.sort()
		for id: String in segment_ids:
			var hit := _segments[id].contact(from,to,collider)
			if hit.is_empty() or float(hit["fraction"]) > fraction: continue
			fraction = hit["fraction"]; normal = hit["normal"]; hit_id = "temporary/"+id
	return _success({"hit": not hit_id.is_empty(), "fraction": fraction, "position": from.lerp(to, fraction), "normal": normal, "volume_id": hit_id})

## F10 H6: stretch boxes whose xz rectangle may meet the segment, in the
## boxes' order (conservative: a 1 u margin around the segment's rectangle).
func _grid_box_candidates(from: Vector3, to: Vector3) -> Array:
	if not _support_index.has("grid_box_ids"): return []
	var ids: Array = _support_index.grid_box_ids
	if ids.size() <= 8: return ids
	var x0 := int(floor((minf(from.x,to.x)-1.0)/GRID_BUCKET)); var x1 := int(floor((maxf(from.x,to.x)+1.0)/GRID_BUCKET))
	var z0 := int(floor((minf(from.z,to.z)-1.0)/GRID_BUCKET)); var z1 := int(floor((maxf(from.z,to.z)+1.0)/GRID_BUCKET))
	if not is_finite(from.x+from.z+to.x+to.z) or (x1-x0+1)*(z1-z0+1) > 64: return ids
	var buckets: Dictionary = _support_index.grid_buckets; var picked: Dictionary = {}
	for bx: int in range(x0,x1+1):
		for bz: int in range(z0,z1+1):
			var bucket: Variant = buckets.get(Vector2i(bx,bz))
			if bucket == null: continue
			for index: int in bucket: picked[index] = true
	var order: Array = picked.keys(); order.sort()
	var result: Array = []
	for index: int in order: result.append(ids[index])
	return result

static func _segment_box(from: Vector3, to: Vector3, box: AABB) -> Dictionary:
	# Existing consumers supply their own expanded/local box; preserve this API.
	return Kernel.sweep_box(from,to,box,0.0,0.0,false)

func query_attack(shape: Dictionary, source: ExpeditionWorldPoint, target: ExpeditionWorldPoint, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not shape.has_all(["geometry_rule_id", "range"]) or not _finite_number(shape["range"]) or float(shape["range"]) < 0.0: return _failure(&"invalid_shape")
	if not _point_valid(source) or not _point_valid(target): return _failure(&"invalid_support")
	if not (shape["geometry_rule_id"] is String or shape["geometry_rule_id"] is StringName): return _failure(&"invalid_shape")
	var rule: StringName = shape["geometry_rule_id"]
	if rule not in [&"direct_volume", &"ground_connected", &"teleport_legal"]: return _failure(&"unknown_geometry_rule")
	var source_position := source.position
	var target_position := target.position
	if shape.has("source_offset") or shape.has("target_offset"):
		if rule != &"direct_volume": return _failure(&"invalid_shape")
		if not shape.get("source_offset",Vector3.ZERO) is Vector3 or not shape.get("target_offset",Vector3.ZERO) is Vector3: return _failure(&"invalid_shape")
		var source_offset: Vector3 = shape.get("source_offset",Vector3.ZERO)
		var target_offset: Vector3 = shape.get("target_offset",Vector3.ZERO)
		if not source_offset.is_finite() or not target_offset.is_finite(): return _failure(&"invalid_shape")
		source_position += source_offset
		target_position += target_offset
	var distance := source_position.distance_to(target_position)
	var range_ok := distance <= float(shape["range"]) + EPS
	var los_ok := true
	var surfaces: Array[String] = [source.surface_id]
	if rule == &"ground_connected":
		if not shape.has("traversal"): return _failure(&"invalid_profile")
		var route := path(source, target, shape["traversal"], revision)
		los_ok = route["ok"]
		if los_ok:
			distance = route["data"]["cost"]
			range_ok = distance <= float(shape["range"]) + EPS
			for point: Dictionary in route["data"]["points"]:
				if not surfaces.has(point["surface_id"]): surfaces.append(point["surface_id"])
	elif rule == &"teleport_legal":
		if not shape.has("traversal") or not _profile_valid(shape["traversal"]): return _failure(&"invalid_profile")
		if not _point_valid(target, shape["traversal"]["radius"], shape["traversal"]["height"]): return _failure(&"invalid_destination")
		# The swept body may leave a supporting top, but may not enter its solid slab.
		# Authored planar blockers and temporary walls retain E06's bypass exception.
		var body: Dictionary = shape["traversal"]
		var local := SupportPatch.members(source.surface_id,Vector2(source.position.x,source.position.z),Vector2(target.position.x,target.position.z),body["radius"],body["height"],_support_index)
		var excluded: Dictionary = {}
		for prism: Dictionary in _support_index.get("solid_prisms",[]):
			if local.has(prism.support_surface_id) and SolidPrism.above_cap(prism,source.position,target.position): excluded[prism.support_surface_id] = true
		if _support_index.has("grids"):
			for id: String in local:
				if _support_index.grids.has(id): excluded[id] = true
		var check := _sweep(source.position,target.position,body,revision,&"supporting_slabs",excluded)
		los_ok = not check["data"]["hit"]
	else:
		var check := sweep(source_position, target_position, {"radius": 0.0, "height": 0.0}, revision)
		los_ok = not check["data"]["hit"]
	var shape_ok := true
	if not (shape.get("kind",&"sphere") is String or shape.get("kind",&"sphere") is StringName): return _failure(&"invalid_shape")
	var kind: StringName = shape.get("kind", &"sphere" )
	if kind not in [&"sphere", &"cone", &"line"]: return _failure(&"invalid_shape")
	if kind in [&"cone", &"line"]:
		if not shape.get("direction",Vector3.ZERO) is Vector3: return _failure(&"invalid_shape")
		var direction: Vector3 = shape.get("direction", Vector3.ZERO)
		if not direction.is_finite() or direction.is_zero_approx(): return _failure(&"invalid_shape")
		var offset := target_position - source_position
		var along := offset.dot(direction.normalized())
		if kind == &"cone":
			var angle := float(shape.get("half_angle", -1.0))
			if not is_finite(angle) or angle < 0.0 or angle > PI: return _failure(&"invalid_shape")
			shape_ok = offset.is_zero_approx() or direction.angle_to(offset) <= angle + EPS
		else:
			var width := float(shape.get("half_width", -1.0))
			if not is_finite(width) or width < 0.0: return _failure(&"invalid_shape")
			shape_ok = along >= 0.0 and (offset - direction.normalized() * along).length() <= width + EPS
	if not surfaces.has(target.surface_id): surfaces.append(target.surface_id)
	var hit := range_ok and los_ok and shape_ok
	return _success({"range_ok": range_ok, "los_ok": los_ok, "shape_ok": shape_ok, "hit": hit, "distance": distance, "affected_surfaces": surfaces if hit else []})

func trace_ground(source: ExpeditionWorldPoint, heading: Vector3, maximum_distance: float, profile: Dictionary, revision: int) -> Dictionary:
	if not is_finite(maximum_distance) or maximum_distance <= 0.0: return _failure(&"invalid_distance")
	var result := ground_line_samples(source,heading,maximum_distance,1,profile,revision)
	if not result["ok"]: return result
	var best: Dictionary = result if not result["data"]["points"].is_empty() else {}
	if best.is_empty():
		var low := 0.0
		var high := maximum_distance
		# Refine the first obstruction/support boundary; no detour or nearest-floor repair.
		for _iteration: int in 32:
			var middle := (low+high)*0.5
			var probe := ground_line_samples(source,heading,middle,1,profile,revision)
			if not probe["ok"]: return probe
			if probe["data"]["points"].is_empty(): high = middle
			else: low = middle; best = probe
	var route: Array = best["data"]["route"].duplicate(true) if not best.is_empty() else [source.to_data()]
	var cost := 0.0
	for index: int in range(1,route.size()): cost += Vector3(route[index-1]["position"]).distance_to(route[index]["position"])
	return _success({"points":route,"cost":cost,"destination":route[-1],"truncated":cost < maximum_distance-EPS})

func _support_segment_fraction(cell: Dictionary, from: Vector3, to: Vector3, profile: Dictionary) -> float:
	_ensure_support_index()
	return SupportPatch.fraction(cell,from,to,profile,_support_index)

static func point_tolerance(a: Vector3, b: Vector3) -> float:
	# Standard Godot Vector3 components are f32; comparisons must account for their ULP scale.
	return EPS+maxf(a.length(),b.length())*1.1920928955078125e-7*4.0

func ground_region(anchor: ExpeditionWorldPoint, polygon: PackedVector2Array, profile: Dictionary, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	var segments: Array = _segments.values()
	var result := WorldSupportRegion.prepare(self,anchor,polygon,profile,revision,_stage["surfaces"],_volumes(),segments)
	return _success(result["data"]) if result["ok"] else _failure(result["error_code"])

func ground_line_to(source: ExpeditionWorldPoint, destination: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if source == null or destination == null: return _failure(&"invalid_ground_line")
	if not _profile_valid(profile): return _failure(&"invalid_profile")
	if not _point_valid(destination,float(profile.get("radius",-1.0)),float(profile.get("height",-1.0))): return _failure(&"invalid_support")
	var heading := Vector3(destination.position.x-source.position.x,0,destination.position.z-source.position.z)
	if heading.is_zero_approx():
		var valid := position_query(source,profile,revision)
		if not valid["ok"]: return valid
		if source.stage_id != destination.stage_id or source.position != destination.position: return _failure(&"unsupported_contact")
		var stationary := _ground_contact_route(source.surface_id,destination.surface_id,destination.position,profile)
		return _success({"points":stationary,"cost":0.0,"destination":destination.to_data()}) if not stationary.is_empty() else _failure(&"unsupported_contact")
	var sampled := _ground_line_samples(source,heading,heading.length(),1,profile,revision,true)
	if not sampled["ok"]: return sampled
	if sampled["data"]["points"].is_empty(): return _failure(&"unsupported_contact")
	var reached: Dictionary = sampled["data"]["points"][0]
	if reached["stage_id"] != destination.stage_id or Vector3(reached["position"]).distance_to(destination.position) > point_tolerance(source.position,destination.position): return _failure(&"unsupported_contact")
	var route: Array = sampled["data"]["route"]
	# Sampling stores f32 coordinates. Revalidate the exact requested endpoint on
	# the reached support before changing context across a coincident opening.
	var last_cell := _cell(reached["surface_id"])
	var end_start: Vector3 = route[-2]["position"] if route.size() > 1 else source.position
	if _support_segment_fraction(last_cell,end_start,destination.position,profile) < 1.0-EPS or not _clear_path_segment(end_start,destination.position,profile,null,reached["surface_id"]): return _failure(&"unsupported_contact")
	var contact := _ground_contact_route(reached["surface_id"],destination.surface_id,destination.position,profile)
	if contact.is_empty(): return _failure(&"unsupported_contact")
	route[-1]["position"] = destination.position
	for index: int in range(1,contact.size()): route.append(contact[index])
	var cost := 0.0
	for index: int in range(1,route.size()): cost += Vector3(route[index-1]["position"]).distance_to(route[index]["position"])
	return _success({"points":route.duplicate(true),"cost":cost,"destination":destination.to_data()})

func ground_line_point_at(source: ExpeditionWorldPoint, horizontal: Vector2, profile: Dictionary, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if source == null or not horizontal.is_finite(): return _failure(&"invalid_ground_line")
	var heading := Vector3(horizontal.x-source.position.x,0,horizontal.y-source.position.z)
	if heading.is_zero_approx(): return position_query(source,profile,revision)
	var sampled := _ground_line_samples(source,heading,heading.length(),1,profile,revision,true)
	if not sampled["ok"]: return sampled
	if sampled["data"]["points"].is_empty(): return _failure(&"unsupported_contact")
	return _success({"point":sampled["data"]["points"][0]})

## F10 H2: on a stretch the support bends at every quad edge and diagonal, so
## travel is measured along those pieces; a planar cell keeps its single chord.
func _ground_line_pieces(cell: Dictionary, point: Vector3, exit: Vector3, horizontal_metric: bool) -> Dictionary:
	if not cell.has("height_grid"): return {"length":Vector2(exit.x-point.x,exit.z-point.z).length() if horizontal_metric else point.distance_to(exit),"points":[],"lengths":[]}
	var view := HeightGrid.view(cell.height_grid)
	var a := Vector2(point.x,point.z); var b := Vector2(exit.x,exit.z)
	var cuts := HeightGrid.crossings(view,a,b)
	var points: Array[Vector3] = [point]
	for t: float in cuts:
		if t <= EPS or t >= 1.0-EPS: continue
		points.append(Kernel.support_y(cell,point.lerp(exit,t)))
	points.append(exit)
	var lengths: Array[float] = []; var total := 0.0
	for index: int in range(1,points.size()):
		var step := Vector2(points[index].x-points[index-1].x,points[index].z-points[index-1].z).length() if horizontal_metric else points[index-1].distance_to(points[index])
		lengths.append(step); total += step
	return {"length":total,"points":points,"lengths":lengths}

func _ground_line_point(cell: Dictionary, point: Vector3, exit: Vector3, pieces: Dictionary, along: float) -> Vector3:
	if pieces.points.is_empty(): return Kernel.support_y(cell,point.lerp(exit,clampf(along/float(pieces.length),0.0,1.0)))
	var remaining := along
	for index: int in pieces.lengths.size():
		var step: float = pieces.lengths[index]
		if remaining <= step or index == pieces.lengths.size()-1:
			var from: Vector3 = pieces.points[index]; var to: Vector3 = pieces.points[index+1]
			return Kernel.support_y(cell,from.lerp(to,clampf(remaining/step,0.0,1.0) if step > 0.0 else 1.0))
		remaining -= step
	return exit

func ground_line_samples(source: ExpeditionWorldPoint, heading: Vector3, spacing: float, count: int, profile: Dictionary, revision: int) -> Dictionary:
	return _ground_line_samples(source,heading,spacing,count,profile,revision,false)

func _ground_line_samples(source: ExpeditionWorldPoint, heading: Vector3, spacing: float, count: int, profile: Dictionary, revision: int, horizontal_metric: bool) -> Dictionary:
	# Heading chooses x/z direction; support supplies y. Spacing measures actual 3D travel.
	if not _current(revision): return _failure(&"stale_geometry")
	if not _profile_valid(profile): return _failure(&"invalid_profile")
	if not _point_valid(source,profile["radius"],profile["height"]): return _failure(&"invalid_support")
	if not heading.is_finite() or Vector2(heading.x,heading.z).is_zero_approx() or not is_finite(spacing) or spacing <= 0.0 or count < 1: return _failure(&"invalid_ground_line")
	var direction := Vector2(heading.x,heading.z).normalized()
	var point := source.position
	var cell := _cell(source.surface_id)
	var distance := 0.0
	var points: Array[Dictionary] = []
	var route: Array[Dictionary] = [source.to_data()]
	var visited: Array[String] = []
	var stopped: StringName = &"unsupported_edge"
	while not cell.is_empty() and not visited.has(cell["surface_id"]):
		visited.append(cell["surface_id"])
		var exit_distance := INF
		var exit := point
		var vertices: Array = cell["vertices"]
		var plane := Kernel._plane(vertices)
		for index: int in vertices.size():
			var a: Vector3 = vertices[index]
			var b: Vector3 = vertices[(index+1)%vertices.size()]
			# Intersect in scalar f64, then store the point ON the selected edge.
			# Vector2.cross and a second f32 ray interpolation can overshoot a vertex.
			var ex: float = float(b.x)-float(a.x); var ez: float = float(b.z)-float(a.z)
			var ox: float = float(a.x)-float(point.x); var oz: float = float(a.z)-float(point.z)
			var denominator: float = float(direction.x)*ez-float(direction.y)*ex
			if absf(denominator) <= EPS: continue
			# An f32 seam anchor can lie a half-ULP outside the entered cell.
			# Select only outgoing edges; never immediately re-cross the incoming
			# edge because its rounded ray intersection has a tiny positive distance.
			if denominator*plane[1] >= 0: continue
			var along: float = (ox*ez-oz*ex)/denominator
			var fraction: float = (ox*float(direction.y)-oz*float(direction.x))/denominator
			if along > EPS and along < exit_distance and fraction >= -EPS and fraction <= 1.0+EPS:
				exit_distance = along
				var t := clampf(fraction,0,1)
				exit = Kernel.support_y(cell,Vector3(float(a.x)+ex*t,0,float(a.z)+ez*t))
		if not is_finite(exit_distance):
			# A legal origin may already lie on the outgoing connector seam.
			var immediate := _ground_line_connection(cell["surface_id"],point,direction,profile)
			if immediate.is_empty(): break
			route.append(ExpeditionWorldPoint.create(source.stage_id,immediate["surface_id"],point).to_data())
			cell = immediate
			continue
		var pieces := _ground_line_pieces(cell,point,exit,horizontal_metric)
		var length: float = pieces.length
		while points.size() < count and spacing*float(points.size()+1) <= distance+length+EPS:
			# Re-evaluate this selected support plane after f32 interpolation; never choose another floor.
			var sample := _ground_line_point(cell,point,exit,pieces,spacing*float(points.size()+1)-distance)
			var supported := ExpeditionWorldPoint.create(source.stage_id,cell["surface_id"],sample)
			var contact := ground_sweep(cell["surface_id"],point,sample,profile,revision)
			if _support_segment_fraction(cell,point,sample,profile) < 1.0-EPS or not _point_valid(supported,profile["radius"],profile["height"]) or not contact["ok"] or contact["data"]["hit"]:
				return _success({"points":points,"truncated":true,"stop_reason":&"blocked_or_unsupported"})
			points.append(supported.to_data())
		if points.size() == count:
			route.append(points[-1].duplicate(true))
			return _success({"points":points,"route":route,"truncated":false,"stop_reason":&""})
		var crossing := ground_sweep(cell["surface_id"],point,exit,profile,revision)
		if _support_segment_fraction(cell,point,exit,profile) < 1.0-EPS or not crossing["ok"] or crossing["data"]["hit"]: stopped = &"blocked"; break
		var following := _ground_line_connection(cell["surface_id"],exit,direction,profile)
		if following.is_empty(): break
		route.append(ExpeditionWorldPoint.create(source.stage_id,cell["surface_id"],exit).to_data())
		route.append(ExpeditionWorldPoint.create(source.stage_id,following["surface_id"],exit).to_data())
		distance += length
		point = exit
		cell = following
	return _success({"points":points,"route":route,"truncated":true,"stop_reason":stopped,"stopped_at":ExpeditionWorldPoint.create(source.stage_id,cell["surface_id"],point).to_data()})

func _ground_line_connection(surface: String, point: Vector3, direction: Vector2, profile: Dictionary) -> Dictionary:
	_ensure_support_index()
	for endpoint: Dictionary in _support_index.ports.get(surface,[]):
		if endpoint["kind"] not in profile["connector_kinds"] or float(endpoint["headroom"]) + EPS < float(profile["height"]): continue
		var outward: Vector3 = endpoint["outward"]
		if direction.dot(Vector2(outward.x,outward.z)) <= EPS: continue
		for following: String in _ground_contact_neighbors(endpoint,point,profile): return _cell(following)
	return {}

func _ground_contact_neighbors(endpoint: Dictionary, point: Vector3, profile: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if endpoint.kind not in profile.connector_kinds or float(endpoint.headroom)+EPS < float(profile.height) or not SupportPatch.on_opening(endpoint.surface_id,endpoint.connector_id,point,_support_index): return result
	for transition: Dictionary in _support_index.transitions.get(endpoint.connector_id,[]):
		if not transition.allowed: continue
		var other: Dictionary = _support_index.endpoints[transition.other_id]
		if other.kind not in profile.connector_kinds or float(other.headroom)+EPS < float(profile.height) or not SupportPatch.on_opening(other.surface_id,other.connector_id,point,_support_index): continue
		if _point_valid(ExpeditionWorldPoint.create(_stage.stage_id,other.surface_id,point),profile.radius,profile.height): result.append(other.surface_id)
	return result

func _ground_contact_route(surface: String, target: String, point: Vector3, profile: Dictionary) -> Array:
	_ensure_support_index()
	if not _point_valid(ExpeditionWorldPoint.create(_stage.stage_id,surface,point),profile.radius,profile.height): return []
	var previous := {surface:""}; var queue: Array[String] = [surface]; var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]; cursor += 1
		if current == target:
			var route: Array = []
			while not current.is_empty():
				route.push_front(ExpeditionWorldPoint.create(_stage.stage_id,current,point).to_data()); current = previous[current]
			return route
		for endpoint: Dictionary in _support_index.ports.get(current,[]):
			for neighbor: String in _ground_contact_neighbors(endpoint,point,profile):
				if previous.has(neighbor): continue
				previous[neighbor] = current; queue.append(neighbor)
	return []

func _candidate_point(point: ExpeditionWorldPoint, radius: float, height: float, candidate: WorldSolidSegment) -> bool:
	if not _point_valid(point,radius,height): return false
	return candidate == null or candidate.contact(point.position,point.position,{"radius":radius,"height":height}).is_empty()

func _clear_path_segment(from: Vector3, to: Vector3, profile: Dictionary, candidate: WorldSolidSegment, surface_id: String = "", mass_context: Dictionary = {}, segment_context: Variant = null) -> bool:
	var contact := _ground_sweep(surface_id,from,to,profile,geometry_revision,mass_context,segment_context) if not surface_id.is_empty() else _sweep(from,to,profile,geometry_revision,&"all",{},mass_context)
	if not contact["ok"] or contact["data"]["hit"]: return false
	return candidate == null or candidate.contact(from,to,profile).is_empty()

func _region_mass_overlap(polygon: PackedVector2Array, support: Dictionary, height: float) -> bool:
	_ensure_support_index()
	for prism: Dictionary in _support_index.get("solid_prisms",[]):
		if not prism.support_surface_id.is_empty() and prism.support_surface_id == support.get("surface_id",""): continue
		if SolidPrism.intersects_patch(prism,polygon,support,height): return true
	return false

func can_insert_segment(id: String, segment: WorldSolidSegment, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if id.is_empty() or _temporary.has(id) or _segments.has(id): return _failure(&"invalid_identity")
	if segment == null or not segment.is_valid(): return _failure(&"invalid_volume")
	var profile := segment.profile(); var anchor := segment.anchor()
	if not _profile_valid(profile) or not _point_valid(anchor,profile["radius"],profile["height"]): return _failure(&"invalid_support")
	var region := segment.support_region()
	if not region.is_empty():
		var support := ground_region(anchor,region["polygon"],region["profile"],revision)
		if not support["ok"]: return support
	else:
		var endpoints := segment.ends()
		for endpoint: Vector3 in endpoints:
			var support := ground_line_point_at(anchor,Vector2(endpoint.x,endpoint.z),profile,revision)
			if not support["ok"]: return support
			if Vector3(support["data"]["point"]["position"]).distance_to(endpoint) > EPS: return _failure(&"non_planar_field_support")
		var excluded := SupportPatch.members(anchor.surface_id,Vector2(endpoints[0].x,endpoints[0].z),Vector2(endpoints[1].x,endpoints[1].z),profile["radius"],profile["height"],_support_index)
		if _sweep(endpoints[0],endpoints[1],profile,revision,&"all",excluded)["data"]["hit"]: return _failure(&"blocked_obstacle")
	for occupant: Dictionary in _occupancy.values():
		var position: Vector3 = occupant["point"]["position"]
		if not segment.contact(position,position,occupant["profile"]).is_empty(): return _failure(&"occupied")
	for occupant: Dictionary in _occupancy.values():
		var data: Dictionary = occupant["point"]
		var origin := ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
		for socket: Dictionary in _stage["sockets"]:
			var destination := ExpeditionWorldPoint.create(_stage["stage_id"],socket["surface_id"],socket["position"])
			if path(origin,destination,occupant["profile"],revision)["ok"] and not _path(origin,destination,occupant["profile"],revision,segment)["ok"]: return _failure(&"would_disconnect")
	return _success()

func insert_segment(id: String, segment: WorldSolidSegment, revision: int) -> Dictionary:
	var valid := can_insert_segment(id,segment,revision)
	if not valid["ok"]: return valid
	_segments[id] = segment.snapshot()
	_navigation_invalidate()
	geometry_revision += 1
	return _success()

func insert_obstacle(id: String, volume: AABB, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if id.is_empty() or _temporary.has(id) or _segments.has(id): return _failure(&"invalid_identity")
	if not volume.position.is_finite() or not volume.size.is_finite() or volume.size.x <= 0.0 or volume.size.y <= 0.0 or volume.size.z <= 0.0: return _failure(&"invalid_volume")
	for occupant: Dictionary in _occupancy.values():
		if not Kernel.clear_segment(occupant["point"]["position"], occupant["point"]["position"], [volume], occupant["radius"], occupant["height"]): return _failure(&"occupied")
	# Preserve every currently reachable authored socket for each registered occupant.
	# Compute before insertion, then reject atomically if the candidate disconnects one.
	var protected: Array[Dictionary] = []
	for occupant: Dictionary in _occupancy.values():
		var origin := ExpeditionWorldPoint.create(occupant["point"]["stage_id"], occupant["point"]["surface_id"], occupant["point"]["position"])
		for socket: Dictionary in _stage["sockets"]:
			var destination := ExpeditionWorldPoint.create(_stage["stage_id"], socket["surface_id"], socket["position"])
			if path(origin, destination, occupant["profile"], revision)["ok"]:
				protected.append({"from": origin, "to": destination, "profile": occupant["profile"]})
	_temporary[id] = volume
	# The protection paths below run at the SAME revision with the new volume.
	_navigation_invalidate()
	for route: Dictionary in protected:
		if not path(route["from"], route["to"], route["profile"], revision)["ok"]:
			_temporary.erase(id)
			_navigation_invalidate()
			return _failure(&"would_disconnect")
	geometry_revision += 1
	return _success()

func remove_obstacle(id: String, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not _temporary.erase(id) and not _segments.erase(id): return _failure(&"unknown_obstacle")
	_navigation_invalidate()
	geometry_revision += 1
	return _success()

func resolve_surface(origin: Vector3, direction: Vector3, visible_surfaces: Array[String], revision: int) -> Dictionary:
	# Pure logical ray query; the presentation adapter supplies the camera ray.
	if not _current(revision): return _failure(&"stale_geometry")
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx(): return _failure(&"invalid_ray")
	var visible := {}
	for id: String in visible_surfaces: visible[id] = true
	var nearest := INF
	var hits: Array[Dictionary] = []
	for cell: Dictionary in _stage["surfaces"]:
		if not visible.has(cell["surface_id"]): continue
		if cell.has("height_grid"):
			# F10 H2: the first hit on the stretch from above; steep ground is no pick.
			var grid_hit := HeightGrid.ray_hit(HeightGrid.view(cell.height_grid),origin,direction)
			if grid_hit.is_empty() or not grid_hit.walkable: continue
			var grid_t: float = float(grid_hit.distance)/direction.length()
			var grid_tolerance := point_tolerance(origin,grid_hit.position)
			hits.append({"surface_id":cell.surface_id,"position":grid_hit.position,"normal":grid_hit.normal,"t":grid_t,"tolerance":grid_tolerance/direction.length(),"precision":grid_tolerance})
			nearest = minf(nearest,grid_t)
			continue
		var normal := Kernel.plane_normal(cell["vertices"])
		var denominator := normal.dot(direction)
		if absf(denominator) < EPS: continue
		var t: float = normal.dot(Vector3(cell["vertices"][0]) - origin) / denominator
		if not is_finite(t) or t < 0.0: continue
		var point := Kernel.support_y(cell,origin + direction * t)
		if not point.is_finite(): continue
		var tolerance := point_tolerance(origin,point)
		if not _ray_contains(cell,point,tolerance): continue
		hits.append({"surface_id":cell.surface_id,"position":point,"normal":normal if normal.y > 0 else -normal,"t":t,"tolerance":tolerance/direction.length(),"precision":tolerance})
		nearest = minf(nearest,t)
	if hits.is_empty(): return _failure(&"hidden_or_missing_surface")
	var candidates: Dictionary = {}
	var owner: Dictionary = {}
	for hit: Dictionary in hits:
		if absf(float(hit.t)-nearest) > float(hit.tolerance): continue
		candidates[hit.surface_id] = hit
		if owner.is_empty() or String(hit.surface_id) < String(owner.surface_id): owner = hit
	if owner.is_empty(): return _failure(&"hidden_or_missing_surface")
	var position: Vector3 = owner.position
	if candidates.size() > 1:
		var seam := _pick_component(candidates,owner)
		if not seam.ok: return _failure(&"ambiguous_surface")
		position = seam.position
	var resolved := {"point":ExpeditionWorldPoint.create(_stage["stage_id"],owner.surface_id,position).to_data(),"normal":owner.normal}
	var obstruction := sweep(origin, resolved["point"]["position"], {"radius": 0.0, "height": 0.0}, revision)
	if obstruction["data"]["hit"] and float(obstruction["data"]["fraction"]) < 1.0 - EPS: return _failure(&"occluded_surface")
	return _success(resolved)

func _pick_component(candidates: Dictionary, owner: Dictionary) -> Dictionary:
	# A distant f32 camera ray can place its intersection just outside the edge.
	# Find a common point on an authored opening inside the existing projection
	# error budget, then prove that ALL candidates support that same point.
	_ensure_support_index()
	var start: String = owner.surface_id
	var anchors: Array[Vector3] = [owner.position]
	for edge: Dictionary in _support_index.outlines.get(start,[]):
		for opening: Dictionary in edge.openings:
			if not candidates.has(opening.neighbor): continue
			var horizontal := Vector2(owner.position.x,owner.position.z)
			var closest := Geometry2D.get_closest_point_to_segment(horizontal,opening.a,opening.b)
			for at: Vector2 in [closest,opening.a,opening.b]:
				var anchor := Kernel.support_y(_support_index.cells[start],Vector3(at.x,owner.position.y,at.y))
				if anchor.distance_to(owner.position) <= float(owner.precision) and anchor not in anchors: anchors.append(anchor)
	anchors.sort_custom(func(a: Vector3,b: Vector3) -> bool:
		var da := a.distance_squared_to(owner.position); var db := b.distance_squared_to(owner.position)
		if da != db: return da < db
		if a.x != b.x: return a.x < b.x
		if a.z != b.z: return a.z < b.z
		return a.y < b.y)
	for anchor: Vector3 in anchors:
		if _pick_component_at(candidates,start,anchor): return {"ok":true,"position":anchor}
	return {"ok":false}

func _pick_component_at(candidates: Dictionary, start: String, anchor: Vector3) -> bool:
	for id: String in candidates:
		var hit: Dictionary = candidates[id]
		if Vector3(hit.position).distance_to(anchor) > float(hit.precision): return false
		# Plane/edge membership uses the canonical local coordinate budgets, not
		# the far camera tolerance. Distinct heights cannot acquire a shared floor.
		if not Kernel.contains(_support_index.cells[id],anchor): return false
	var included := {start:true}
	var queue: Array[String] = [start]
	var cursor := 0
	while cursor < queue.size():
		var id := queue[cursor]; cursor += 1
		for port: Dictionary in _support_index.ports.get(id,[]):
			if port.kind != "walk" or not SupportPatch.on_opening(id,port.connector_id,anchor,_support_index): continue
			for transition: Dictionary in _support_index.transitions.get(port.connector_id,[]):
				if not transition.allowed: continue
				var other: Dictionary = _support_index.endpoints[transition.other_id]
				if other.kind != "walk" or included.has(other.surface_id) or not candidates.has(other.surface_id): continue
				if not SupportPatch.on_opening(other.surface_id,other.connector_id,anchor,_support_index): continue
				var reciprocal := false
				for back: Dictionary in _support_index.transitions.get(other.connector_id,[]):
					if back.other_id == port.connector_id and back.connection_id == transition.connection_id and back.allowed:
						reciprocal = true; break
				if reciprocal:
					included[other.surface_id] = true; queue.append(other.surface_id)
	return included.size() == candidates.size()

func presentation_snapshot(revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	# Copy only authored presentation geometry. Visibility never changes collision.
	return _success({"stage_id":_stage["stage_id"],"surfaces":_stage["surfaces"],"volumes":_volumes()})

static func _ray_contains(cell: Dictionary, point: Vector3, tolerance: float) -> bool:
	# A projection ray far from its plane loses f32 ULPs. Conservatively refuse
	# near-coincident edges. resolve_surface proves connected ties explicitly.
	var side := 0.0
	var vertices: Array = cell["vertices"]
	for index: int in vertices.size():
		var a: Vector3 = vertices[index]; var b: Vector3 = vertices[(index+1)%vertices.size()]
		var edge := Vector2(b.x-a.x,b.z-a.z)
		var signed_distance := edge.cross(Vector2(point.x-a.x,point.z-a.z))/edge.length()
		if absf(signed_distance) <= tolerance: continue
		if side == 0.0: side = signf(signed_distance)
		elif side*signed_distance < 0: return false
	return true
