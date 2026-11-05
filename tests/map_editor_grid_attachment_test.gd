extends SceneTree
## Q5: complete differential against the frozen capsule/attachment producer,
## then its field and route consumers. No timing threshold or new cache.
const Grid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
var checks: Array[Dictionary] = []
var cases := 0
var attachment_pairs := 0
var nonempty_attachments := 0
var empty_attachments := 0
var equal_fields := 0
var routes_ok := 0
var routes_failed := 0
var routes_bent := 0

func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_GRID_ATTACHMENT_CHECK "+id+" "+str(ok))

# Frozen pre-Q5 segment_clear, including both endpoint disks and the exact
# zero-radius branch. Do not use the extracted interior as the test oracle.
func reference_segment_clear(prepared: Dictionary, a: Vector2, b: Vector2, radius: float, inside: bool) -> bool:
	if not Grid.disk_clear(prepared,a,radius,inside) or not Grid.disk_clear(prepared,b,radius,inside): return false
	var reach := maxf(radius,Grid.EPS)
	for t: int in Grid._steep_near(prepared,a,b,reach):
		var tri := Grid._triangle_2d(prepared,t)
		if radius > 0.0:
			if Grid._segment_triangle_distance(a,b,tri) < radius-Grid.EPS: return false
		elif Grid._crosses_interior(a,b,tri): return false
	return true

# Frozen pre-Q5 attachment order and distances (the original 25 capsules).
func reference_attach(built: Dictionary, point: Vector2) -> Array:
	var view: Dictionary = built.view; var size: Vector2i = built.size
	var half := float(view.s)*0.5
	var cx := int(round((point.x-float(view.ox))/half)); var cz := int(round((point.y-float(view.oz))/half))
	var result: Array = []
	for dz: int in range(-2,3):
		for dx: int in range(-2,3):
			var n := Vector2i(cx+dx,cz+dz)
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y: continue
			var id := n.y*size.x+n.x
			if built.usable[id] == 0: continue
			var q := Grid._node_point(view,n)
			if reference_segment_clear(view,point,q,float(built.radius),bool(built.inside)): result.append([id,point.distance_to(q)])
	return result

func reference_field(built: Dictionary, from: Vector2) -> Dictionary:
	var view: Dictionary = built.view; var size: Vector2i = built.size
	if not Grid.disk_clear(view,from,float(built.radius),bool(built.inside)): return {"ok":false,"code":"height_grid_endpoint"}
	var count := size.x*size.y
	var dist := PackedFloat64Array(); dist.resize(count); dist.fill(INF)
	var parent := PackedInt32Array(); parent.resize(count); parent.fill(-2)
	var heap: Array = []
	for item: Array in reference_attach(built,from):
		var id: int = item[0]; var d: float = item[1]
		if d < dist[id]: dist[id] = d; parent[id] = -1; Grid._heap_push(heap,[d,id])
	var step := float(view.s)*0.5; var diagonal := step*sqrt(2.0)
	var expanded := 0
	while not heap.is_empty():
		var entry: Array = Grid._heap_pop(heap)
		var id: int = entry[1]
		if float(entry[0]) != dist[id]: continue
		expanded += 1
		var bits: int = built.links[id]
		if bits == 0: continue
		var node := Vector2i(id%size.x,id/size.x)
		for k: int in 8:
			if bits & (1 << k) == 0: continue
			var n := node+Grid.DIRECTIONS[k]
			var other := n.y*size.x+n.x
			var cost := dist[id]+(step if k < 4 else diagonal)
			if cost < dist[other]:
				dist[other] = cost; parent[other] = id; Grid._heap_push(heap,[cost,other])
	return {"ok":true,"dist":dist,"parent":parent,"from":from,"expanded":expanded}

func reference_route(built: Dictionary, reach: Dictionary, to: Vector2) -> Dictionary:
	if not reach.get("ok",false): return {"ok":false,"code":reach.get("code","height_grid_endpoint")}
	var view: Dictionary = built.view; var size: Vector2i = built.size
	var radius := float(built.radius); var inside := bool(built.inside)
	var from: Vector2 = reach.from
	if not Grid.disk_clear(view,to,radius,inside): return {"ok":false,"code":"height_grid_endpoint"}
	if reference_segment_clear(view,from,to,radius,inside): return {"ok":true,"points":PackedVector2Array([from,to]),"length":from.distance_to(to),"expanded":reach.expanded}
	var best := INF; var best_id := -1
	for item: Array in reference_attach(built,to):
		var id: int = item[0]
		if reach.dist[id] == INF: continue
		var total: float = reach.dist[id]+float(item[1])
		if total < best or (total == best and id < best_id): best = total; best_id = id
	if best_id < 0: return {"ok":false,"code":"height_grid_unreachable","expanded":reach.expanded}
	var raw: Array[Vector2] = [to]
	var cursor := best_id
	while cursor >= 0:
		raw.push_front(Grid._node_point(view,Vector2i(cursor%size.x,cursor/size.x)))
		cursor = reach.parent[cursor]
	raw.push_front(from)
	var points := PackedVector2Array([raw[0]])
	var i := 0
	while i < raw.size()-1:
		var j := raw.size()-1
		while j > i+1 and not reference_segment_clear(view,raw[i],raw[j],radius,inside): j -= 1
		points.append(raw[j]); i = j
	var length := 0.0
	for k: int in points.size()-1: length += points[k].distance_to(points[k+1])
	return {"ok":true,"points":points,"length":length,"expanded":reach.expanded}

func view_for(kind: String, origin: Vector2, spacing: float) -> Dictionary:
	var heights: Array = []
	for z: int in 9:
		for x: int in 9:
			var y := 0.0
			if kind == "slope": y = spacing*(float(x)*0.125+float(z)*0.0625)
			elif kind != "flat" and x == 4 and not (kind == "gap" and z >= 3 and z <= 5): y = spacing*4.0
			heights.append(y)
	return Grid.index(Grid.view({"origin_xz":[origin.x,origin.y],"sample_spacing":spacing,"columns":9,"rows":9,"heights":heights}))

func probes(view: Dictionary, radius: float) -> Array[Vector2]:
	var origin := Vector2(float(view.ox),float(view.oz)); var width := float(view.qx)*float(view.s)
	return [origin+Vector2(width*0.15,width*0.20),origin+Vector2(width*0.85,width*0.20),origin+Vector2(width*0.85,width*0.80),origin+Vector2(width*0.5,width*0.5),origin,origin+Vector2(width,width),origin+Vector2(0,width*0.5),origin+Vector2(radius,width*0.5),origin+Vector2(radius*0.5,width*0.5),origin+Vector2(radius-Grid.EPS*2.0,width*0.5),origin+Vector2(-1.0,width*0.5),origin+Vector2(width+float(view.s),width*0.5),origin+Vector2(float(view.s)*3.5,float(view.s)*1.5)]

func audit(kind: String, origin: Vector2, spacing: float, radius: float, inside: bool) -> void:
	cases += 1
	var id := "%s_%s_s%s_r%s_inside%s"%[kind,str(origin),spacing,radius,inside]
	var built := Grid.lattice(view_for(kind,origin,spacing),radius,inside)
	check(id+"_lattice_exists",not built.is_empty())
	if built.is_empty(): return
	var points := probes(built.view,radius)
	var attachments_same := true; var capsules_same := true; var usable_proved := true
	for index: int in built.usable.size():
		usable_proved = usable_proved and (built.usable[index] == 1) == Grid.disk_clear(built.view,Grid.node_point(built,index),radius,inside)
	for point: Vector2 in points:
		var old := reference_attach(built,point); var current := Grid._attach(built,point)
		attachment_pairs += 1
		if current.is_empty(): empty_attachments += 1
		else: nonempty_attachments += 1
		attachments_same = attachments_same and old == current
		capsules_same = capsules_same and reference_segment_clear(built.view,points[0],point,radius,inside) == Grid.segment_clear(built.view,points[0],point,radius,inside)
		capsules_same = capsules_same and reference_segment_clear(built.view,point,points[0],radius,inside) == Grid.segment_clear(built.view,point,points[0],radius,inside)
	check(id+"_usable_proves_exact_disks",usable_proved)
	check(id+"_same_ordered_ids_and_distances",attachments_same)
	check(id+"_same_public_capsules_both_directions",capsules_same)
	var fields_same := true; var routes_same := true
	# Include a far route across the wall and a route starting on the border;
	# failures are compared in full, like positive distance/parent arrays.
	for source: Vector2 in [points[0],points[6]]:
		var old := reference_field(built,source); var current := Grid.field(built,source)
		fields_same = fields_same and old == current
		if old == current: equal_fields += 1
		for target: Vector2 in [points[1],points[2],points[10]]:
			var old_route := reference_route(built,old,target); var route := Grid.route(built,current,target)
			routes_same = routes_same and old_route == route
			if route.ok:
				routes_ok += 1
				if route.points.size() > 2: routes_bent += 1
			else: routes_failed += 1
	check(id+"_same_complete_fields",fields_same)
	check(id+"_same_complete_routes",routes_same)

func run() -> void:
	for location: Dictionary in [{"origin":Vector2.ZERO,"spacing":64.0},{"origin":Vector2(-4224,3840),"spacing":32.0},{"origin":Vector2(8192,-12288),"spacing":128.0}]:
		for kind: String in ["flat","slope","gap","wall"]:
			for radius: float in [0.0,20.0,48.0]:
				for inside: bool in [true,false]: audit(kind,location.origin,location.spacing,radius,inside)
	# Canonical lattices with invalid radii have no usable nodes, so both old
	# and new attachment producers must reject without inventing attachment.
	for radius: float in [-1.0,INF,NAN]:
		var built := Grid.lattice(view_for("flat",Vector2.ZERO,64.0),radius,true)
		var point := Vector2(100,100)
		check("invalid_radius_%s"%str(radius),Grid._attach(built,point).is_empty() and reference_attach(built,point).is_empty() and Grid.field(built,point) == reference_field(built,point))
	# Nonfinite point rejection precedes lattice-coordinate conversion now;
	# the public disk/capsule contract already rejects these inputs.
	var finite := Grid.lattice(view_for("flat",Vector2.ZERO,64.0),20.0,true)
	for point: Vector2 in [Vector2(NAN,0),Vector2(INF,0),Vector2(0,-INF)]:
		check("nonfinite_point_%s"%str(point),Grid._attach(finite,point).is_empty() and not Grid.segment_clear(finite.view,point,Vector2(100,100),20.0,true))
	check("positive_negative_and_bent_cases_exercised",nonempty_attachments > 0 and empty_attachments > 0 and routes_ok > 0 and routes_failed > 0 and routes_bent > 0)
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_GRID_ATTACHMENT_METRICS "+JSON.stringify({"cases":cases,"attachment_pairs":attachment_pairs,"nonempty":nonempty_attachments,"empty":empty_attachments,"equal_fields":equal_fields,"routes_ok":routes_ok,"routes_failed":routes_failed,"routes_bent":routes_bent}))
	print("F10_GRID_ATTACHMENT_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
