class_name WorldConnectivityBatch
extends RefCounted
## Internal WorldGeometry consumer. Certificates prove existence, never shortest cost.
const REVISION := "canonical_connectivity_batch_v2"
## F10 H6: above this many targets on a stage with height-grid stretches, the
## direct pairs are tried only for the targets the graph search left unreached
## (a direct edge to an already reached target adds no reachability).
const LAZY_DIRECT_TARGETS := 64
const LIMITS := {"max_targets":4096,"max_states":131072,"max_pair_candidates":8000000,"max_edge_tests":4000000,"max_expansions":262144,"max_storage_bytes":268435456,"max_usec":240000000}

## Conservative allocation-accounting units, not an OS heap/RSS measurement.
## Retained copies remain charged; scoped scratch is released at its lifetime end.
static func storage_units(value: Variant) -> int:
	if value is String or value is StringName: return 64+str(value).length()*4
	if value is Dictionary:
		var total: int = 256+value.size()*64
		for key: Variant in value: total += storage_units(key)+storage_units(value[key])
		return total
	if value is Array:
		var total: int = 128+value.size()*32
		for item: Variant in value: total += storage_units(item)
		return total
	if value is PackedByteArray: return 128+value.size()
	if value is PackedVector2Array or value is PackedVector3Array or value is PackedStringArray: return 128+value.size()*64
	if value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat32Array or value is PackedFloat64Array: return 128+value.size()*16
	return 64

static func reserve(ctx: Dictionary, value: Variant, copies: int = 1) -> bool:
	if ctx.is_empty(): return true
	return tick(ctx,"storage_bytes",storage_units(value)*copies)

static func scratch(ctx: Dictionary, value: Variant, copies: int = 1) -> bool:
	return _scratch_units(ctx,storage_units(value)*copies)

static func _scratch_units(ctx: Dictionary, units: int) -> bool:
	if ctx.is_empty(): return true
	if not tick(ctx,"storage_bytes",units): return false
	ctx["scratch_live"] = int(ctx.get("scratch_live",0))+units
	return true

static func release_scratch(ctx: Dictionary, mark: int) -> void:
	if ctx.is_empty(): return
	var released := int(ctx.get("scratch_live",0))-mark
	ctx.metrics.storage_bytes -= released; ctx.scratch_live = mark

static func tick(ctx: Dictionary, metric: String = "operations", amount: int = 1, force: bool = false) -> bool:
	if ctx.is_empty(): return true
	if not ctx.error_code.is_empty(): return false
	ctx.metrics[metric] = int(ctx.metrics.get(metric,0))+amount
	if metric == "storage_bytes": ctx.metrics["peak_storage_bytes"] = maxi(int(ctx.metrics.get("peak_storage_bytes",0)),int(ctx.metrics.storage_bytes))
	ctx.operations += maxi(1,amount)
	var key := "max_"+metric
	if ctx.limits.has(key) and int(ctx.metrics[metric]) > int(ctx.limits[key]): ctx.error_code = &"navigation_budget_exceeded"; return false
	if not force and ctx.operations-ctx.last_poll < 64: return true
	ctx.last_poll = ctx.operations
	if Time.get_ticks_usec()-int(ctx.started) > int(ctx.limits.max_usec): ctx.error_code = &"navigation_budget_exceeded"; return false
	var owner: WorldGeometry = ctx.owner
	if not owner._current(ctx.revision) or owner.configuration_revision != ctx.configuration: ctx.error_code = &"stale_geometry"; return false
	var cancelled: bool = ctx.cancellation.is_valid() and bool(ctx.cancellation.call())
	if not owner._current(ctx.revision) or owner.configuration_revision != ctx.configuration: ctx.error_code = &"stale_geometry"; return false
	if cancelled: ctx.error_code = &"cancelled"; return false
	return true

# Checkpoint42 (F9-10): wall time per phase in metrics.phase_usec (diagnostic only;
# metrics already carry elapsed_ms and are never part of a proof).
static func _enter(ctx: Dictionary, phase: String) -> void:
	var now := Time.get_ticks_usec()
	var spent: Dictionary = ctx.metrics.get("phase_usec",{})
	var previous := String(ctx.get("phase","prepare"))
	spent[previous] = int(spent.get(previous,0)) + now - int(ctx.get("phase_started",ctx.started))
	ctx.metrics["phase_usec"] = spent; ctx["phase_started"] = now; ctx.phase = phase

static func failed(world: WorldGeometry, ctx: Dictionary, code: StringName = &"") -> Dictionary:
	if code.is_empty(): code = ctx.get("error_code",&"invalid_support")
	return {"ok":false,"error_code":code,"geometry_revision":world.geometry_revision,"data":{"phase":ctx.get("phase","prepare"),"metrics":ctx.get("metrics",{}).duplicate(true)}}

static func _ordered(value: Variant, status: Dictionary, depth: int = 0) -> Variant:
	if depth > 64: status.ok = false; return null
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING: return value
		TYPE_STRING_NAME: return str(value)
		TYPE_FLOAT:
			if not is_finite(value): status.ok = false
			return value
		TYPE_VECTOR2,TYPE_VECTOR3:
			if not value.is_finite(): status.ok = false
			return value
		TYPE_AABB:
			if not value.position.is_finite() or not value.size.is_finite(): status.ok = false
			return value
		TYPE_ARRAY:
			var result: Array = []
			for item: Variant in value: result.append(_ordered(item,status,depth+1))
			return result
		TYPE_DICTIONARY:
			var result: Dictionary = {}; var keys: Array = value.keys(); keys.sort()
			for key: Variant in keys:
				if not (key is String or key is StringName) or result.has(str(key)): status.ok = false; return null
				result[str(key)] = _ordered(value[key],status,depth+1)
			return result
		TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_INT64_ARRAY,TYPE_PACKED_STRING_ARRAY: return value.duplicate()
		TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY:
			for item: float in value:
				if not is_finite(item): status.ok = false
			return value.duplicate()
		TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY:
			for item: Variant in value:
				if not item.is_finite(): status.ok = false
			return value.duplicate()
	status.ok = false
	return null

static func _hash(value: Variant) -> Dictionary:
	var status := {"ok":true}; var ordered: Variant = _ordered(value,status)
	if not status.ok: return {"ok":false}
	var bytes := var_to_bytes(ordered); var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
	return {"ok":true,"hash":digest.finish().hex_encode(),"bytes":bytes.size(),"storage":storage_units(ordered)}

static func signature(world: WorldGeometry) -> Dictionary:
	var segments: Dictionary = {}
	for id: String in world._segments: segments[id] = world._segments[id].geometry_record()
	return _hash({"stage":world._stage,"temporary":world._temporary,"slabs":world._solid_slabs,"segments":segments})

static func _shadow(world: WorldGeometry) -> WorldGeometry:
	var result := WorldGeometry.new()
	result._stage = world._stage.duplicate(true); result._temporary = world._temporary.duplicate(true)
	result._solid_slabs.assign(world._solid_slabs)
	# F10 H3: the same stage's stretch lattices (signature-checked at publish).
	result._grid_cache = world._grid_cache; result._grid_mutex = world._grid_mutex
	for id: String in world._segments: result._segments[id] = world._segments[id].snapshot()
	result.geometry_revision = world.geometry_revision; result.configuration_revision = world.configuration_revision
	return result

static func _stage_valid(world: WorldGeometry) -> bool:
	var stage: Dictionary = world._stage
	for field: String in ["surfaces","connectors","connections","volumes"]:
		if not stage.get(field) is Array: return false
	var cells: Dictionary = {}; var ports: Dictionary = {}
	for cell: Variant in stage.surfaces:
		if not cell is Dictionary or not cell.get("surface_id") is String or cells.has(cell.surface_id) or not cell.get("vertices") is Array or not WorldGeometry._finite_number(cell.get("headroom")): return false
		for vertex: Variant in cell.vertices:
			if not vertex is Vector3 or not vertex.is_finite(): return false
		if not WorldGeometry.Kernel.valid_cell(cell): return false
		cells[cell.surface_id] = true
	for port: Variant in stage.connectors:
		if not port is Dictionary or not port.has_all(["connector_id","surface_id","position","outward","width","headroom","kind"]) or not port.connector_id is String or ports.has(port.connector_id) or not port.surface_id is String or not cells.has(port.surface_id) or not port.kind is String: return false
		if not port.position is Vector3 or not port.position.is_finite() or not port.outward is Vector3 or not port.outward.is_finite() or not WorldGeometry._finite_number(port.width) or not WorldGeometry._finite_number(port.headroom) or port.width <= 0 or port.headroom <= 0: return false
		ports[port.connector_id] = true
	for link: Variant in stage.connections:
		if not link is Dictionary or not link.has_all(["connection_id","a_connector","b_connector","forward","backward"]) or not link.connection_id is String or not link.a_connector is String or not link.b_connector is String or not ports.has(link.a_connector) or not ports.has(link.b_connector) or not link.forward is bool or not link.backward is bool: return false
	for volume: Variant in stage.volumes:
		if not volume is AABB or not volume.position.is_finite() or not volume.size.is_finite(): return false
	return world._stage_prisms_valid(stage)

static func execute(world: WorldGeometry, root: ExpeditionWorldPoint, targets: Array[ExpeditionWorldPoint], profile: Dictionary, revision: int, cancellation: Callable, budget: Dictionary) -> Dictionary:
	if not world._current(revision): return world._failure(&"stale_geometry")
	if not world._profile_valid(profile): return world._failure(&"invalid_profile")
	if not _stage_valid(world): return world._failure(&"invalid_support")
	var limits: Dictionary = LIMITS.duplicate(true)
	for key: Variant in budget:
		var value: Variant = budget[key]
		if not key is String or not limits.has(key) or not WorldGeometry._finite_number(value) or float(value) < 0 or float(value) != floor(float(value)) or float(value) > 9007199254740991.0: return world._failure(&"invalid_navigation_budget")
		limits[key] = int(value)
	var ctx := {"owner":world,"revision":revision,"configuration":world.configuration_revision,"cancellation":cancellation,"limits":limits,"started":Time.get_ticks_usec(),"operations":0,"last_poll":0,"error_code":&"","phase":"prepare","metrics":{},"visibility":{},"point_proofs":{},"segment_proofs":{}}
	if targets.size() > int(limits.max_targets): return failed(world,ctx,&"navigation_budget_exceeded")
	if root == null: return failed(world,ctx,&"invalid_support")
	var start := ExpeditionWorldPoint.create(root.stage_id,root.surface_id,root.position)
	var captured: Array[ExpeditionWorldPoint] = []
	for target: ExpeditionWorldPoint in targets:
		if target == null: return failed(world,ctx,&"invalid_support")
		captured.append(ExpeditionWorldPoint.create(target.stage_id,target.surface_id,target.position))
	var traversal := profile.duplicate(true); var profile_signature := _hash(traversal)
	if not profile_signature.ok: return failed(world,ctx,&"invalid_profile")
	var source_signature := signature(world)
	if not source_signature.ok: return failed(world,ctx,&"invalid_support")
	ctx["snapshot_hash"] = source_signature.hash; ctx["profile_hash"] = profile_signature.hash
	if not tick(ctx,"storage_bytes",source_signature.storage*3+profile_signature.storage*3,true): return failed(world,ctx)
	ctx.metrics["snapshot_storage_units"] = ctx.metrics.storage_bytes
	var shadow := _shadow(world)
	ctx["memo"] = world._navigation_shared_memo(traversal)
	if not shadow._point_valid(start,traversal.radius,traversal.height): return failed(world,ctx,&"invalid_support")
	var nodes := {"@root":start.to_data()}; var ids: Array[String] = []; var points: Dictionary = {"@root":start}
	for target: ExpeditionWorldPoint in captured:
		if not tick(ctx,"terminal_checks"): return failed(world,ctx)
		if not shadow._point_valid(target,traversal.radius,traversal.height): return failed(world,ctx,&"invalid_support")
		var id: String = "@root" if target.to_data() == start.to_data() else "@terminal/"+ExpeditionCanonical.digest(target.to_data())
		if nodes.has(id) and nodes[id] != target.to_data(): return failed(world,ctx,&"invalid_support")
		nodes[id] = target.to_data(); points[id] = target; ids.append(id)
	if not tick(ctx,"states",nodes.size()): return failed(world,ctx)
	if not reserve(ctx,[nodes,ids,points],3) or not reserve(ctx,shadow._support_index): return failed(world,ctx)
	var sorted: Array = nodes.keys(); sorted.sort()
	var ordered_nodes: Dictionary = {}
	for id: String in sorted: ordered_nodes[id] = nodes[id]
	nodes = ordered_nodes
	if _reusable(shadow): return _execute_reused(world,shadow,start,captured,nodes,ids,points,sorted,traversal,revision,ctx)
	var pairs: Array = []; var direct_edges: Dictionary = {}; var trusted_direct: Dictionary = {}; var all_direct := true
	var lazy: bool = ids.size() > LAZY_DIRECT_TARGETS and not shadow._support_index.get("grids",{}).is_empty()
	_enter(ctx,"direct")
	for id: String in sorted:
		if id == "@root": continue
		for outward: bool in [true,false]:
			if not tick(ctx,"direct_pairs",1,true): return failed(world,ctx)
			var a: String = "@root" if outward else id; var b: String = id if outward else "@root"
			pairs.append({"from":points[a],"to":points[b],"from_id":a,"to_id":b})
			if not reserve(ctx,[a,b],4): return failed(world,ctx)
			if lazy: all_direct = false; continue
			var direct := shadow._navigation_direct(points[a],points[b],traversal,revision,null)
			if not direct.ok: all_direct = false; continue
			var scratch_mark := int(ctx.get("scratch_live",0))
			if not scratch(ctx,direct): return failed(world,ctx)
			var kept := _direct_edge(ctx,direct,nodes[a],nodes[b],b)
			direct.clear(); release_scratch(ctx,scratch_mark)
			if not kept.ok: return failed(world,ctx,ctx.error_code if not ctx.error_code.is_empty() else &"invalid_support")
			var edge: Dictionary = kept.edge
			if not direct_edges.has(a): direct_edges[a] = []
			direct_edges[a].append(edge)
			if not trusted_direct.has(a):
				if not tick(ctx,"storage_bytes",256): return failed(world,ctx)
				trusted_direct[a] = {}
			if not tick(ctx,"storage_bytes",128): return failed(world,ctx)
			trusted_direct[a][b] = edge
	var graph := {"ok":true,"nodes":nodes,"edges":{},"by_surface":{}}
	if not all_direct:
		_enter(ctx,"construct")
		# Checkpoint42 (F9-10): reuse the exact predicates (point/clear/fraction) the
		# owner already memoized for this geometry and profile. Each batch used to
		# rebuild them from nothing (~11 s per batch on the Bosque population).
		graph = shadow._navigation_graph(start,start,traversal,null,nodes,pairs,ctx,{"memo":ctx.memo})
		if not graph.ok: return failed(world,ctx)
	else:
		for id: String in nodes: graph.edges[id] = []
	for id: String in direct_edges: graph.edges[id].append_array(direct_edges[id])
	var incoming: Dictionary = {}
	for id: String in graph.nodes:
		if not reserve(ctx,[id,[]]): return failed(world,ctx)
		incoming[id] = []
	for id: String in graph.edges:
		for edge: Dictionary in graph.edges[id]:
			# Incidence/predecessor records retain the immutable edge by reference.
			if not tick(ctx,"storage_bytes",512): return failed(world,ctx)
			incoming[edge.to].append({"source":id,"edge":edge})
	_enter(ctx,"outward")
	var outward := _search(shadow,graph,incoming,ids,traversal,ctx,false,all_direct)
	if not outward.ok: return failed(world,ctx)
	_enter(ctx,"inward")
	var inward := _search(shadow,graph,incoming,ids,traversal,ctx,true,all_direct)
	if not inward.ok: return failed(world,ctx)
	if lazy:
		# F10 H6: direct pairs only for what is still unreached, then search again.
		_enter(ctx,"direct")
		var added := false
		for id: String in sorted:
			if id == "@root": continue
			for direction: bool in [true,false]:
				if (outward if direction else inward).visited.has(id): continue
				var a: String = "@root" if direction else id; var b: String = id if direction else "@root"
				if not tick(ctx,"lazy_direct_pairs",1,true): return failed(world,ctx)
				var direct := shadow._navigation_direct(points[a],points[b],traversal,revision,null)
				if not direct.ok: continue
				var scratch_mark := int(ctx.get("scratch_live",0))
				if not scratch(ctx,direct): return failed(world,ctx)
				var kept := _direct_edge(ctx,direct,nodes[a],nodes[b],b)
				direct.clear(); release_scratch(ctx,scratch_mark)
				if not kept.ok: return failed(world,ctx,ctx.error_code if not ctx.error_code.is_empty() else &"invalid_support")
				graph.edges[a].append(kept.edge)
				if not tick(ctx,"storage_bytes",512): return failed(world,ctx)
				incoming[b].append({"source":a,"edge":kept.edge}); added = true
		if added:
			_enter(ctx,"outward")
			outward = _search(shadow,graph,incoming,ids,traversal,ctx,false,false)
			if not outward.ok: return failed(world,ctx)
			_enter(ctx,"inward")
			inward = _search(shadow,graph,incoming,ids,traversal,ctx,true,false)
			if not inward.ok: return failed(world,ctx)
	var results: Array = []; var all_reachable := true
	_enter(ctx,"witnesses")
	for index: int in ids.size():
		var id := ids[index]; var out: bool = outward.visited.has(id); var back: bool = inward.visited.has(id)
		all_reachable = all_reachable and out and back
		if all_direct:
			# The canonical direct authority already accepted these exact sequences.
			# No public certificate flag can confer this private proof identity.
			if not tick(ctx,"direct_witness_proofs_reused",1,true): return failed(world,ctx)
			if id == "@root":
				if nodes[id] != captured[index].to_data(): return failed(world,ctx,&"invalid_support")
			elif not out or not back or not _direct_previous(outward.previous,id,true,trusted_direct) or not _direct_previous(inward.previous,id,false,trusted_direct): return failed(world,ctx,&"invalid_support")
		else:
			for direction: bool in [true,false]:
				if not (out if direction else back): continue
				var scratch_mark := int(ctx.get("scratch_live",0))
				var route := reconstruct(graph.nodes,(outward if direction else inward).previous,id,direction,ctx)
				if not route.ok or not route_valid(shadow,route.data.points,traversal,ctx): return failed(world,ctx,ctx.error_code if not ctx.error_code.is_empty() else &"invalid_support")
				release_scratch(ctx,scratch_mark)
		results.append({"input_index":index,"point":captured[index].to_data(),"node_id":id,"outward_reachable":out,"inward_reachable":back})
		if not reserve(ctx,results[-1]): return failed(world,ctx)
	_enter(ctx,"publish")
	if not tick(ctx,"operations",1,true): return failed(world,ctx)
	var after := signature(world)
	if not after.ok or after.hash != ctx.snapshot_hash or not world._current(revision) or world.configuration_revision != ctx.configuration: return failed(world,ctx,&"stale_geometry")
	_enter(ctx,"done")
	ctx.metrics["elapsed_ms"] = (Time.get_ticks_usec()-int(ctx.started))/1000.0
	var data := {"complete":true,"all_reachable":all_reachable,"configuration_revision":ctx.configuration,"profile_hash":ctx.profile_hash,"profile":traversal,"graph_revision":REVISION,"snapshot_hash":ctx.snapshot_hash,"targets":results,"states":graph.nodes,"outward_previous":outward.previous,"inward_previous":inward.previous,"metrics":ctx.metrics}
	return world._success(data)

static func _direct_edge(ctx: Dictionary, direct: Dictionary, source: Dictionary, target: Dictionary, target_id: String) -> Dictionary:
	if not direct.get("data") is Dictionary or not direct.data.get("points") is Array: return {"ok":false}
	var points: Array = direct.data.points
	# Unit routes are handled by execute's exact coincident-root deduplication.
	# No distinct-terminal edge may manufacture a second endpoint for one item.
	if points.size() < 2 or points[0] != source or points[-1] != target: return {"ok":false}
	var via: Array = points.duplicate(true); via.pop_front(); via.pop_back()
	var composed: Array = [source]; composed.append_array(via); composed.append(target)
	if not _scratch_units(ctx,128+composed.size()*32) or composed != points: return {"ok":false}
	var edge := {"to":target_id,"via":via,"connection_id":"","connection_ids":direct.data.connection_ids.duplicate(),"cost":direct.data.cost}
	# One retained content allocation; incidence and predecessor references are
	# accounted separately. The original direct result is scoped scratch.
	if not reserve(ctx,edge): return {"ok":false}
	return {"ok":true,"edge":edge}

static func _direct_previous(previous: Dictionary, id: String, outward: bool, trusted: Dictionary) -> bool:
	if not previous.get(id) is Dictionary: return false
	var record: Dictionary = previous[id]
	var source := "@root" if outward else id; var target := id if outward else "@root"
	if record.get("from") != "@root" or not record.get("edge") is Dictionary or record.edge.get("to") != target: return false
	return trusted.has(source) and trusted[source].has(target) and is_same(record.edge,trusted[source][target])

static func _search(world: WorldGeometry, graph: Dictionary, incoming: Dictionary, targets: Array[String], profile: Dictionary, ctx: Dictionary, reverse: bool, direct_only: bool) -> Dictionary:
	var visited := {"@root":true}; var previous: Dictionary = {}; var queue: Array[String] = ["@root"]; var cursor := 0
	var missing: Dictionary = {}
	for id: String in targets:
		if id != "@root": missing[id] = true
	while cursor < queue.size() and not missing.is_empty():
		if not tick(ctx,"expansions"): return {"ok":false}
		var current := queue[cursor]; cursor += 1
		if reverse:
			for record: Dictionary in incoming[current]:
				if not _admit(record.source,current,record.edge,visited,previous,queue,missing,ctx): return {"ok":false}
		else:
			for edge: Dictionary in graph.edges[current]:
				if not _admit(edge.to,current,edge,visited,previous,queue,missing,ctx): return {"ok":false}
		if direct_only: continue
		for other: String in graph.by_surface[graph.nodes[current].surface_id]:
			if visited.has(other): continue
			var a: String = other if reverse else current; var b: String = current if reverse else other
			var found: Variant = _local_edge(world,graph,profile,ctx,a,b)
			if found == null: return {"ok":false}
			if found.is_empty(): continue
			if not _admit(other,current,found,visited,previous,queue,missing,ctx): return {"ok":false}
	return {"ok":true,"visited":visited,"previous":previous}

## The local edge a -> b between two states of one support, tested once per
## batch: straight (exact sweep and support), or bent on a stretch (F10 H3).
## {} when none; null when the budget stops the batch.
static func _local_edge(world: WorldGeometry, graph: Dictionary, profile: Dictionary, ctx: Dictionary, a: String, b: String) -> Variant:
	if not ctx.visibility.has(a):
		if not tick(ctx,"storage_bytes",384): return null
		ctx.visibility[a] = {}
	var cached: Dictionary = ctx.visibility[a]
	if not cached.has(b):
		if not tick(ctx,"edge_tests"): return null
		# Cache keys retain state IDs; their string backing is owned by nodes.
		if not tick(ctx,"storage_bytes",128): return null
		var from: Dictionary = graph.nodes[a]; var to: Dictionary = graph.nodes[b]
		# Checkpoint42: same predicates through the owner's shared memo
		# (_navigation_clear/_fraction wrap exactly these two calls).
		var memo: Dictionary = ctx.get("memo",{})
		var tested := Time.get_ticks_usec()
		var straight: bool = not world._grid_straight_blocked(from.surface_id,from.position,to.position,profile) and world._navigation_clear(from.position,to.position,profile,null,from.surface_id,memo) and world._navigation_fraction(world._cell(from.surface_id),from.position,to.position,profile,memo) >= 1.0-WorldGeometry.EPS
		ctx.metrics["straight_usec"] = int(ctx.metrics.get("straight_usec",0))+Time.get_ticks_usec()-tested
		cached[b] = {"via":[],"cost":Vector3(from.position).distance_to(to.position)} if straight else {}
		if not straight and world._is_grid(from.surface_id):
			# F10 H3: a stretch's local edge may bend around steep ground.
			tested = Time.get_ticks_usec()
			if not ctx.has("grid_fields"): ctx["grid_fields"] = {}
			if not ctx.grid_fields.has(a): ctx.grid_fields[a] = {}
			var bent := world._navigation_grid_edge(from,to,profile,null,memo,ctx.grid_fields[a])
			if bent.ok: cached[b] = {"via":bent.via,"cost":bent.cost}
			ctx.metrics["grid_bent_tests"] = int(ctx.metrics.get("grid_bent_tests",0))+1
			ctx.metrics["grid_bent_usec"] = int(ctx.metrics.get("grid_bent_usec",0))+Time.get_ticks_usec()-tested
	else: ctx.metrics["visibility_cache_hits"] = int(ctx.metrics.get("visibility_cache_hits",0))+1
	if cached[b].is_empty(): return {}
	return {"to":b,"via":cached[b].via,"connection_id":"","cost":cached[b].cost}

## F10 H6: closure search over a support graph. `queue` starts with `seeds`
## states; the first `seeded` of them only test the states in `only` (their
## other pairs were already tested when the closure was built). With `wanted`
## empty the search runs until the queue is exhausted.
static func _continue(world: WorldGeometry, graph: Dictionary, incoming: Dictionary, wanted: Array[String], profile: Dictionary, ctx: Dictionary, reverse: bool, visited: Dictionary, previous: Dictionary, queue: Array[String], only: Dictionary, seeded: int) -> Dictionary:
	var missing: Dictionary = {}
	for id: String in wanted:
		if not visited.has(id): missing[id] = true
	var full := wanted.is_empty(); var cursor := 0
	while cursor < queue.size() and (full or not missing.is_empty()):
		if not tick(ctx,"expansions"): return {"ok":false}
		var current := queue[cursor]; var restricted := cursor < seeded; cursor += 1
		if not restricted:
			if reverse:
				for record: Dictionary in incoming[current]:
					if not _admit(record.source,current,record.edge,visited,previous,queue,missing,ctx): return {"ok":false}
			else:
				for edge: Dictionary in graph.edges[current]:
					if not _admit(edge.to,current,edge,visited,previous,queue,missing,ctx): return {"ok":false}
		for other: String in graph.by_surface.get(graph.nodes[current].surface_id,[]):
			if visited.has(other) or (restricted and not only.has(other)): continue
			var a: String = other if reverse else current; var b: String = current if reverse else other
			var found: Variant = _local_edge(world,graph,profile,ctx,a,b)
			if found == null: return {"ok":false}
			if found.is_empty(): continue
			if not _admit(other,current,found,visited,previous,queue,missing,ctx): return {"ok":false}
	return {"ok":true,"visited":visited,"previous":previous}

## F10 H6: base closures per geometry, body and root: the support graph
## without targets and its complete outward and inward searches from the root,
## plus the witness proofs already established. Later batches on an equal
## geometry (also in another WorldGeometry, e.g. the population planner's) add
## only their targets. Used only on stages whose connections all join
## height-grid stretches, where the graph does not depend on the targets.
## Sockets and the entrance marker are not geometry and are not in the key.
static var _closures: Dictionary = {}
static var _closure_order: Array = []
static var _closure_mutex: Mutex = Mutex.new()
const MAX_CLOSURES := 3

static func _reusable(world: WorldGeometry) -> bool:
	world._ensure_support_index()
	var grids: Dictionary = world._support_index.get("grids",{})
	if grids.is_empty(): return false
	var surfaces: Dictionary = {}
	for endpoint: Dictionary in world._stage.get("connectors",[]): surfaces[endpoint.connector_id] = endpoint.surface_id
	for connection: Dictionary in world._stage.get("connections",[]):
		if not grids.has(surfaces.get(connection.a_connector,"")) or not grids.has(surfaces.get(connection.b_connector,"")): return false
	return true

static func _closure_key(world: WorldGeometry, ctx: Dictionary, start: ExpeditionWorldPoint) -> Dictionary:
	var stage: Dictionary = world._stage.duplicate(); stage.erase("sockets"); stage.erase("entrance")
	var segments: Dictionary = {}
	for id: String in world._segments: segments[id] = world._segments[id].geometry_record()
	return _hash({"revision":REVISION,"stage":stage,"temporary":world._temporary,"slabs":world._solid_slabs,"segments":segments,"profile":ctx.profile_hash,"root":start.to_data()})

static func _closure_base(world: WorldGeometry, shadow: WorldGeometry, start: ExpeditionWorldPoint, traversal: Dictionary, ctx: Dictionary) -> Dictionary:
	var keyed := _closure_key(shadow,ctx,start)
	if not keyed.ok: return {"ok":false,"code":&"invalid_support"}
	_closure_mutex.lock(); var known: Variant = _closures.get(keyed.hash); _closure_mutex.unlock()
	if known != null:
		ctx.metrics["closure"] = "reused"
		if not tick(ctx,"storage_bytes",int(known.storage),true): return {"ok":false}
		return {"ok":true,"base":known}
	ctx.metrics["closure"] = "built"
	_enter(ctx,"construct")
	var self_pair := [{"from":start,"to":start,"from_id":"@root","to_id":"@root"}]
	var graph := shadow._navigation_graph(start,start,traversal,null,{"@root":start.to_data()},self_pair,ctx,{"memo":ctx.memo})
	if not graph.ok: return {"ok":false}
	var incoming: Dictionary = {}
	for id: String in graph.nodes: incoming[id] = []
	for id: String in graph.edges:
		for edge: Dictionary in graph.edges[id]:
			if not tick(ctx,"storage_bytes",512): return {"ok":false}
			incoming[edge.to].append({"source":id,"edge":edge})
	var none: Array[String] = []
	_enter(ctx,"outward")
	var out_queue: Array[String] = ["@root"]
	var outward := _continue(shadow,graph,incoming,none,traversal,ctx,false,{"@root":true},{},out_queue,{},0)
	if not outward.ok: return {"ok":false}
	_enter(ctx,"inward")
	var in_queue: Array[String] = ["@root"]
	var inward := _continue(shadow,graph,incoming,none,traversal,ctx,true,{"@root":true},{},in_queue,{},0)
	if not inward.ok: return {"ok":false}
	var base := {"graph":graph,"incoming":incoming,"outward":outward,"inward":inward,"point_proofs":{},"segment_proofs":{},"storage":int(ctx.metrics.get("storage_bytes",0))}
	_closure_mutex.lock()
	if not _closures.has(keyed.hash):
		_closures[keyed.hash] = base; _closure_order.append(keyed.hash)
		while _closure_order.size() > MAX_CLOSURES: _closures.erase(_closure_order.pop_front())
	base = _closures[keyed.hash]
	_closure_mutex.unlock()
	return {"ok":true,"base":base}

## F10 H6: a batch over a reused base closure. The targets join the graph; the
## searches continue from the base closures (a base state only tests the new
## targets on its support, every newly reached state expands normally); the
## direct pairs are tried for what is still unreached; every reached target's
## route is reconstructed and verified as before.
static func _execute_reused(world: WorldGeometry, shadow: WorldGeometry, start: ExpeditionWorldPoint, captured: Array[ExpeditionWorldPoint], nodes: Dictionary, ids: Array[String], points: Dictionary, sorted: Array, traversal: Dictionary, revision: int, ctx: Dictionary) -> Dictionary:
	var made := _closure_base(world,shadow,start,traversal,ctx)
	if not made.ok: return failed(world,ctx,made.get("code",ctx.error_code if not ctx.error_code.is_empty() else &"invalid_support"))
	var base: Dictionary = made.base
	var graph := {"ok":true,"nodes":base.graph.nodes.duplicate(),"edges":base.graph.edges.duplicate(),"by_surface":base.graph.by_surface.duplicate()}
	var incoming: Dictionary = base.incoming.duplicate()
	var fresh: Array[String] = []; var only: Dictionary = {}; var touched: Array = []
	for id: String in sorted:
		if id == "@root" or graph.nodes.has(id): continue
		if not tick(ctx,"storage_bytes",768): return failed(world,ctx)
		graph.nodes[id] = nodes[id]; graph.edges[id] = []; incoming[id] = []
		var surface: String = nodes[id].surface_id
		var bin: Array = graph.by_surface.get(surface,[]).duplicate(); bin.append(id); graph.by_surface[surface] = bin
		fresh.append(id); only[id] = true
		if surface not in touched: touched.append(surface)
	var searches: Array = []
	for reverse: bool in [false,true]:
		_enter(ctx,"inward" if reverse else "outward")
		var closure: Dictionary = base.inward if reverse else base.outward
		var visited: Dictionary = closure.visited.duplicate(); var previous: Dictionary = closure.previous.duplicate()
		var queue: Array[String] = []
		for surface: String in touched:
			for other: String in base.graph.by_surface.get(surface,[]):
				if visited.has(other): queue.append(other)
		var searched := _continue(shadow,graph,incoming,fresh,traversal,ctx,reverse,visited,previous,queue,only,queue.size())
		if not searched.ok: return failed(world,ctx)
		# Direct pairs only for what is still unreached, then continue from them.
		_enter(ctx,"direct")
		var reached: Array[String] = []
		for id: String in fresh:
			if visited.has(id): continue
			var a: String = id if reverse else "@root"; var b: String = "@root" if reverse else id
			if not tick(ctx,"lazy_direct_pairs",1,true): return failed(world,ctx)
			var direct := shadow._navigation_direct(points[a],points[b],traversal,revision,null)
			if not direct.ok: continue
			var scratch_mark := int(ctx.get("scratch_live",0))
			if not scratch(ctx,direct): return failed(world,ctx)
			var kept := _direct_edge(ctx,direct,nodes[a],nodes[b],b)
			direct.clear(); release_scratch(ctx,scratch_mark)
			if not kept.ok: return failed(world,ctx,ctx.error_code if not ctx.error_code.is_empty() else &"invalid_support")
			if not tick(ctx,"storage_bytes",768): return failed(world,ctx)
			visited[id] = true; previous[id] = {"from":"@root","edge":kept.edge}; reached.append(id)
		if not reached.is_empty():
			_enter(ctx,"inward" if reverse else "outward")
			searched = _continue(shadow,graph,incoming,fresh,traversal,ctx,reverse,visited,previous,reached,{},0)
			if not searched.ok: return failed(world,ctx)
		searches.append(searched)
	var outward: Dictionary = searches[0]; var inward: Dictionary = searches[1]
	_enter(ctx,"witnesses")
	_closure_mutex.lock(); ctx.point_proofs = base.point_proofs.duplicate(true); ctx.segment_proofs = base.segment_proofs.duplicate(); _closure_mutex.unlock()
	var results: Array = []; var all_reachable := true
	# Each target's route is the root's tree path; verifying every tree edge on
	# those paths once is verifying every route (same points, same segments).
	var verified := [{"@root":true},{"@root":true}]
	if not route_valid(shadow,[graph.nodes["@root"]],traversal,ctx): return failed(world,ctx,ctx.error_code if not ctx.error_code.is_empty() else &"invalid_support")
	for index: int in ids.size():
		var id := ids[index]; var out: bool = outward.visited.has(id); var back: bool = inward.visited.has(id)
		all_reachable = all_reachable and out and back
		for direction: bool in [true,false]:
			if not (out if direction else back): continue
			if not _tree_valid(shadow,graph.nodes,(outward if direction else inward).previous,id,direction,verified[0 if direction else 1],traversal,ctx): return failed(world,ctx,ctx.error_code if not ctx.error_code.is_empty() else &"invalid_support")
		results.append({"input_index":index,"point":captured[index].to_data(),"node_id":id,"outward_reachable":out,"inward_reachable":back})
		if not reserve(ctx,results[-1]): return failed(world,ctx)
	_closure_mutex.lock(); base.point_proofs = ctx.point_proofs; base.segment_proofs = ctx.segment_proofs; _closure_mutex.unlock()
	_enter(ctx,"publish")
	if not tick(ctx,"operations",1,true): return failed(world,ctx)
	var after := signature(world)
	if not after.ok or after.hash != ctx.snapshot_hash or not world._current(revision) or world.configuration_revision != ctx.configuration: return failed(world,ctx,&"stale_geometry")
	_enter(ctx,"done")
	ctx.metrics["elapsed_ms"] = (Time.get_ticks_usec()-int(ctx.started))/1000.0
	var data := {"complete":true,"all_reachable":all_reachable,"configuration_revision":ctx.configuration,"profile_hash":ctx.profile_hash,"profile":traversal,"graph_revision":REVISION,"snapshot_hash":ctx.snapshot_hash,"targets":results,"states":graph.nodes,"outward_previous":outward.previous,"inward_previous":inward.previous,"metrics":ctx.metrics}
	return world._success(data)

static func _admit(next: String, current: String, edge: Dictionary, visited: Dictionary, previous: Dictionary, queue: Array[String], missing: Dictionary, ctx: Dictionary) -> bool:
	if visited.has(next): return true
	# Predecessor dictionary, visited entry and queue slot share graph IDs/edge.
	if not tick(ctx,"storage_bytes",768): return false
	visited[next] = true; previous[next] = {"from":current,"edge":edge}; queue.append(next); missing.erase(next)
	return true

static func reconstruct(nodes: Dictionary, previous: Dictionary, target: String, outward: bool, ctx: Dictionary = {}) -> Dictionary:
	var steps: Array[Dictionary] = []; var cursor := target; var seen: Dictionary = {}
	if not nodes.has(cursor): return {"ok":false}
	while cursor != "@root":
		if not tick(ctx,"reconstruction_steps"): return {"ok":false}
		if seen.has(cursor) or not previous.has(cursor): return {"ok":false}
		seen[cursor] = true
		if not previous[cursor] is Dictionary: return {"ok":false}
		var record: Dictionary = previous[cursor]
		if not record.get("from") is String or not nodes.has(record.from) or not record.get("edge") is Dictionary: return {"ok":false}
		var edge: Dictionary = record.edge
		if not edge.get("to") is String or not nodes.has(edge.to) or not edge.get("via") is Array or not edge.get("connection_id") is String or not WorldGeometry._finite_number(edge.get("cost")) or edge.cost < 0: return {"ok":false}
		if not scratch(ctx,[record,edge.via,nodes[edge.to]],2): return {"ok":false}
		if edge.to != (cursor if outward else record.from): return {"ok":false}
		if edge.has("connection_ids"):
			if not edge.connection_ids is Array: return {"ok":false}
			for id: Variant in edge.connection_ids:
				if not id is String: return {"ok":false}
		if outward: steps.push_front(record)
		else: steps.append({"from":cursor,"edge":record.edge})
		cursor = record.from
	return {"ok":true,"data":WorldGeometry._navigation_route(nodes["@root" if outward else target],steps,nodes)}

## F10 H6: the tree path from `target` to the root, with the checks of
## reconstruct(); every edge not yet in `done` is verified as the route piece it
## contributes ([its source] + via + [its head]) and joins `done`.
static func _tree_valid(world: WorldGeometry, nodes: Dictionary, previous: Dictionary, target: String, outward: bool, done: Dictionary, profile: Dictionary, ctx: Dictionary) -> bool:
	if not nodes.has(target): return false
	var chain: Array[String] = []; var cursor := target; var seen: Dictionary = {}
	while not done.has(cursor):
		if not tick(ctx,"reconstruction_steps"): return false
		if seen.has(cursor) or not previous.has(cursor) or not previous[cursor] is Dictionary: return false
		seen[cursor] = true
		var record: Dictionary = previous[cursor]
		if not record.get("from") is String or not nodes.has(record.from) or not record.get("edge") is Dictionary: return false
		var edge: Dictionary = record.edge
		if not edge.get("to") is String or not nodes.has(edge.to) or not edge.get("via") is Array or not edge.get("connection_id") is String or not WorldGeometry._finite_number(edge.get("cost")) or edge.cost < 0: return false
		if edge.to != (cursor if outward else record.from): return false
		if edge.has("connection_ids"):
			if not edge.connection_ids is Array: return false
			for id: Variant in edge.connection_ids:
				if not id is String: return false
		chain.append(cursor); cursor = record.from
	for node: String in chain:
		var record: Dictionary = previous[node]; var edge: Dictionary = record.edge
		var piece: Array = [nodes[record.from if outward else node]]
		piece.append_array(edge.via); piece.append(nodes[edge.to])
		if not route_valid(world,piece,profile,ctx): return false
		done[node] = true
	return true

static func witness(world: WorldGeometry, certificate: Dictionary, index: int, outward: bool, revision: int) -> Dictionary:
	if not world._current(revision): return world._failure(&"stale_geometry")
	if not certificate.get("ok",false) or not certificate.get("data") is Dictionary: return world._failure(&"invalid_support")
	if certificate.get("geometry_revision") != revision: return world._failure(&"stale_geometry")
	var data: Dictionary = certificate.data
	if not data.get("complete",false) or data.get("configuration_revision") != world.configuration_revision or data.get("graph_revision") != REVISION: return world._failure(&"stale_geometry")
	if not data.get("profile") is Dictionary or not world._profile_valid(data.profile) or not data.get("targets") is Array or not data.get("states") is Dictionary or not data.get("outward_previous") is Dictionary or not data.get("inward_previous") is Dictionary or index < 0 or index >= data.targets.size(): return world._failure(&"invalid_support")
	var profile_signature := _hash(data.profile); var now := signature(world)
	if not profile_signature.ok or profile_signature.hash != data.get("profile_hash"): return world._failure(&"invalid_profile")
	if not now.ok or now.hash != data.get("snapshot_hash"): return world._failure(&"stale_geometry")
	var target: Variant = data.targets[index]
	if not target is Dictionary or not target.get("node_id") is String or not target.get("outward_reachable" if outward else "inward_reachable",false): return world._failure(&"unreachable")
	if not data.states.get("@root") is Dictionary or not data.states.get(target.node_id) is Dictionary or target.get("input_index") != index or target.get("point") != data.states[target.node_id]: return world._failure(&"invalid_support")
	var result := reconstruct(data.states,data.outward_previous if outward else data.inward_previous,target.node_id,outward)
	var ctx := {"owner":world,"revision":revision,"configuration":world.configuration_revision,"cancellation":Callable(),"limits":LIMITS,"started":Time.get_ticks_usec(),"operations":0,"last_poll":0,"error_code":&"","phase":"witness","metrics":{},"point_proofs":{},"segment_proofs":{}}
	if not result.ok or not route_valid(world,result.data.points,data.profile,ctx): return failed(world,ctx,ctx.error_code if not ctx.error_code.is_empty() else &"invalid_support")
	var cost := 0.0
	for k: int in range(1,result.data.points.size()): cost += Vector3(result.data.points[k-1].position).distance_to(result.data.points[k].position)
	result.data.cost = cost; result.data["cost_kind"] = "witness_only"
	result.data.connection_ids = world._route_connection_ids(result.data.points)
	return world._success(result.data)

static func route_valid(world: WorldGeometry, points: Array, profile: Dictionary, ctx: Dictionary) -> bool:
	for point: Variant in points:
		if not tick(ctx,"witness_points"): return false
		if not point is Dictionary or not point.get("stage_id") is String or not point.get("surface_id") is String or not point.get("position") is Vector3: return false
		if point.stage_id != world._stage.stage_id or not point.position.is_finite(): return false
		if not ctx.point_proofs.has(point.surface_id): ctx.point_proofs[point.surface_id] = {}
		var known: Dictionary = ctx.point_proofs[point.surface_id]
		if not known.has(point.position):
			if not reserve(ctx,[point.surface_id,point.position,false],2): return false
			known[point.position] = world._point_valid(ExpeditionWorldPoint.create(point.stage_id,point.surface_id,point.position),profile.radius,profile.height)
		if not known[point.position]: return false
	for index: int in range(1,points.size()):
		if not tick(ctx,"witness_segments"): return false
		var a: Dictionary = points[index-1]; var b: Dictionary = points[index]
		# F10 H6: the proof depends only on these fields; an exact key without a
		# digest per segment (equal keys are compared by value).
		var key := [a.stage_id,a.surface_id,a.position,b.stage_id,b.surface_id,b.position]
		if not ctx.segment_proofs.has(key):
			if not reserve(ctx,[key,false],2): return false
			if a.surface_id == b.surface_id:
				ctx.segment_proofs[key] = world._clear_path_segment(a.position,b.position,profile,null,a.surface_id) and world._support_segment_fraction(world._cell(a.surface_id),a.position,b.position,profile) >= 1.0-WorldGeometry.EPS
			else:
				ctx.segment_proofs[key] = a.position == b.position and not world._ground_contact_route(a.surface_id,b.surface_id,a.position,profile).is_empty()
		if not ctx.segment_proofs[key]: return false
	return not points.is_empty()
