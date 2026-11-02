@tool
extends RefCounted
## F10 H1 (contracts/f10_height_grid.md): one rectangular stretch of a terrain
## height grid as a single support surface. Pure and static: no stage, actor or
## navigation state. The triangulation is the renderer's and the compiler's: each
## quad (a,b,c,d) = (x,z),(x+1,z),(x+1,z+1),(x,z+1) is split into (a,b,c) and
## (a,c,d). Steep triangles are holes of the surface, never ground.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const EPS := 0.00001
const WALK_NORMAL_Y := 0.7071067811865476
const MAX_SAMPLES := 257
const MAX_LATTICE := 263169
const DIRECTIONS: Array[Vector2i] = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]

static func valid(grid: Variant) -> bool:
	if not grid is Dictionary or not grid.has_all(["origin_xz","sample_spacing","columns","rows","heights"]): return false
	if not (grid.columns is int or grid.columns is float) or not (grid.rows is int or grid.rows is float): return false
	var columns := int(grid.columns); var rows := int(grid.rows)
	if float(columns) != float(grid.columns) or float(rows) != float(grid.rows): return false
	if columns < 2 or rows < 2 or columns > MAX_SAMPLES or rows > MAX_SAMPLES: return false
	if not (grid.sample_spacing is int or grid.sample_spacing is float) or not is_finite(float(grid.sample_spacing)) or float(grid.sample_spacing) <= 0.0: return false
	if not grid.origin_xz is Array or grid.origin_xz.size() != 2: return false
	for value: Variant in grid.origin_xz:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	if not (grid.heights is Array or grid.heights is PackedFloat64Array or grid.heights is PackedFloat32Array) or grid.heights.size() != columns*rows: return false
	for value: Variant in grid.heights:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	return true

## Prepared, read-only view: heights as f64 and the walkable mask per triangle.
static func prepare(grid: Dictionary) -> Dictionary:
	if not valid(grid): return {}
	var columns := int(grid.columns); var rows := int(grid.rows)
	var heights := PackedFloat64Array()
	for value: Variant in grid.heights: heights.append(float(value))
	var prepared := {"ox":float(grid.origin_xz[0]),"oz":float(grid.origin_xz[1]),"s":float(grid.sample_spacing),"columns":columns,"rows":rows,"qx":columns-1,"qz":rows-1,"h":heights}
	var walk := PackedByteArray(); walk.resize((columns-1)*(rows-1)*2)
	var count := 0
	for t: int in walk.size():
		var flag := 1 if absf(Kernel.plane_normal(triangle_vertices(prepared,t)).y) >= WALK_NORMAL_Y-EPS else 0
		walk[t] = flag; count += flag
	prepared["walk"] = walk; prepared["walkable_count"] = count
	return prepared

static func point(prepared: Dictionary, x: int, z: int) -> Vector3:
	return Vector3(float(prepared.ox)+float(x)*float(prepared.s),float(prepared.h[z*int(prepared.columns)+x]),float(prepared.oz)+float(z)*float(prepared.s))

static func bounds(prepared: Dictionary) -> Rect2:
	return Rect2(float(prepared.ox),float(prepared.oz),float(prepared.qx)*float(prepared.s),float(prepared.qz)*float(prepared.s))

static func triangle_vertices(prepared: Dictionary, t: int) -> Array:
	var quad := t >> 1; var x := quad % int(prepared.qx); var z := quad / int(prepared.qx)
	if t & 1 == 0: return [point(prepared,x,z),point(prepared,x+1,z),point(prepared,x+1,z+1)]
	return [point(prepared,x,z),point(prepared,x+1,z+1),point(prepared,x,z+1)]

static func triangle_walkable(prepared: Dictionary, t: int) -> bool:
	return t >= 0 and t < prepared.walk.size() and prepared.walk[t] == 1

## Triangle under (x, z), or -1 outside the stretch. Points on a shared edge
## belong to the lower quad index and to (a,b,c) on the diagonal; both agree on y.
static func triangle_at(prepared: Dictionary, x: float, z: float) -> int:
	var u := (x-float(prepared.ox))/float(prepared.s); var v := (z-float(prepared.oz))/float(prepared.s)
	if not is_finite(u) or not is_finite(v) or u < -EPS or v < -EPS or u > float(prepared.qx)+EPS or v > float(prepared.qz)+EPS: return -1
	var i := clampi(int(floor(u)),0,int(prepared.qx)-1); var j := clampi(int(floor(v)),0,int(prepared.qz)-1)
	var fu := u-float(i); var fv := v-float(j)
	return (j*int(prepared.qx)+i)*2+(0 if fu >= fv else 1)

## Exact support on the triangle under (x, z); NAN outside.
static func support_y(prepared: Dictionary, x: float, z: float) -> float:
	var t := triangle_at(prepared,x,z)
	if t < 0: return NAN
	var vertices := triangle_vertices(prepared,t)
	var a: Vector3 = vertices[0]; var b: Vector3 = vertices[1]; var c: Vector3 = vertices[2]
	var ux := float(b.x)-float(a.x); var uy := float(b.y)-float(a.y); var uz := float(b.z)-float(a.z)
	var vx := float(c.x)-float(a.x); var vy := float(c.y)-float(a.y); var vz := float(c.z)-float(a.z)
	var nx := uy*vz-uz*vy; var ny := uz*vx-ux*vz; var nz := ux*vy-uy*vx
	return float(a.y)-(nx*(x-float(a.x))+nz*(z-float(a.z)))/ny

static func _triangle_2d(prepared: Dictionary, t: int) -> PackedVector2Array:
	var vertices := triangle_vertices(prepared,t)
	return PackedVector2Array([Vector2(vertices[0].x,vertices[0].z),Vector2(vertices[1].x,vertices[1].z),Vector2(vertices[2].x,vertices[2].z)])

static func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b-a; var length := ab.length_squared()
	if length <= 0.0: return p.distance_to(a)
	return p.distance_to(a+ab*clampf((p-a).dot(ab)/length,0.0,1.0))

static func _inside_triangle(p: Vector2, tri: PackedVector2Array) -> bool:
	var d1 := (tri[1]-tri[0]).cross(p-tri[0]); var d2 := (tri[2]-tri[1]).cross(p-tri[1]); var d3 := (tri[0]-tri[2]).cross(p-tri[2])
	var negative := d1 < -EPS or d2 < -EPS or d3 < -EPS; var positive := d1 > EPS or d2 > EPS or d3 > EPS
	return not (negative and positive)

static func _point_triangle_distance(p: Vector2, tri: PackedVector2Array) -> float:
	if _inside_triangle(p,tri): return 0.0
	return minf(_point_segment_distance(p,tri[0],tri[1]),minf(_point_segment_distance(p,tri[1],tri[2]),_point_segment_distance(p,tri[2],tri[0])))

static func _segments_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	return Geometry2D.segment_intersects_segment(a,b,c,d) != null

static func _segment_triangle_distance(a: Vector2, b: Vector2, tri: PackedVector2Array) -> float:
	if _inside_triangle(a,tri) or _inside_triangle(b,tri): return 0.0
	for k: int in 3:
		if _segments_cross(a,b,tri[k],tri[(k+1)%3]): return 0.0
	var best := INF
	for k: int in 3:
		best = minf(best,_point_segment_distance(tri[k],a,b))
		best = minf(best,minf(_point_segment_distance(a,tri[k],tri[(k+1)%3]),_point_segment_distance(b,tri[k],tri[(k+1)%3])))
	return best

## Steep triangles whose quads meet the box [low, high] (clamped to the stretch).
static func _steep_in(prepared: Dictionary, low: Vector2, high: Vector2) -> Array[int]:
	var result: Array[int] = []
	var s := float(prepared.s)
	var i0 := clampi(int(floor((low.x-float(prepared.ox))/s)),0,int(prepared.qx)-1); var i1 := clampi(int(floor((high.x-float(prepared.ox))/s)),0,int(prepared.qx)-1)
	var j0 := clampi(int(floor((low.y-float(prepared.oz))/s)),0,int(prepared.qz)-1); var j1 := clampi(int(floor((high.y-float(prepared.oz))/s)),0,int(prepared.qz)-1)
	for j: int in range(j0,j1+1):
		for i: int in range(i0,i1+1):
			for k: int in 2:
				var t := (j*int(prepared.qx)+i)*2+k
				if prepared.walk[t] == 0: result.append(t)
	return result

## The body's disk at `center` lies on walkable triangles. With `inside`, the
## disk must also stay within the stretch; otherwise the part outside is left to
## the neighbouring surface (the stage's support union decides it). A zero-radius
## body may stand on the edge of a steep triangle, never inside it.
static func disk_clear(prepared: Dictionary, center: Vector2, radius: float, inside: bool = true) -> bool:
	if not center.is_finite() or not is_finite(radius) or radius < 0.0: return false
	var box := bounds(prepared)
	if inside:
		if center.x-radius < box.position.x-EPS or center.y-radius < box.position.y-EPS or center.x+radius > box.end.x+EPS or center.y+radius > box.end.y+EPS: return false
	elif not box.grow(EPS).has_point(center): return false
	var reach := maxf(radius,EPS)
	for t: int in _steep_in(prepared,center-Vector2(reach,reach),center+Vector2(reach,reach)):
		var tri := _triangle_2d(prepared,t)
		if radius > 0.0:
			if _point_triangle_distance(center,tri) < radius-EPS: return false
		elif _strictly_inside(center,tri): return false
	return true

## The body's capsule from `a` to `b` lies on walkable triangles.
static func segment_clear(prepared: Dictionary, a: Vector2, b: Vector2, radius: float, inside: bool = true) -> bool:
	if not disk_clear(prepared,a,radius,inside) or not disk_clear(prepared,b,radius,inside): return false
	var reach := maxf(radius,EPS)
	var low := Vector2(minf(a.x,b.x),minf(a.y,b.y))-Vector2(reach,reach); var high := Vector2(maxf(a.x,b.x),maxf(a.y,b.y))+Vector2(reach,reach)
	for t: int in _steep_in(prepared,low,high):
		var tri := _triangle_2d(prepared,t)
		if radius > 0.0:
			if _segment_triangle_distance(a,b,tri) < radius-EPS: return false
		elif _crosses_interior(a,b,tri): return false
	return true

## A zero-radius segment may run along a steep triangle's edge, not through it.
static func _crosses_interior(a: Vector2, b: Vector2, tri: PackedVector2Array) -> bool:
	for piece: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a,b]),tri):
		for k: int in piece.size()-1:
			if piece[k].distance_to(piece[k+1]) > EPS and _strictly_inside((piece[k]+piece[k+1])*0.5,tri): return true
	return false

static func _strictly_inside(p: Vector2, tri: PackedVector2Array) -> bool:
	var d1 := (tri[1]-tri[0]).cross(p-tri[0]); var d2 := (tri[2]-tri[1]).cross(p-tri[1]); var d3 := (tri[0]-tri[2]).cross(p-tri[2])
	return (d1 > EPS and d2 > EPS and d3 > EPS) or (d1 < -EPS and d2 < -EPS and d3 < -EPS)

static func _heap_push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var k := heap.size()-1
	while k > 0:
		var up := (k-1)/2
		if not _heap_less(heap[k],heap[up]): break
		var swap: Array = heap[k]; heap[k] = heap[up]; heap[up] = swap; k = up

static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]; var last: Array = heap.pop_back()
	if heap.is_empty(): return top
	heap[0] = last
	var k := 0
	while true:
		var l := k*2+1; var r := l+1; var m := k
		if l < heap.size() and _heap_less(heap[l],heap[m]): m = l
		if r < heap.size() and _heap_less(heap[r],heap[m]): m = r
		if m == k: break
		var swap: Array = heap[k]; heap[k] = heap[m]; heap[m] = swap; k = m
	return top

static func _heap_less(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])

## Lattice at half the sample spacing; a node is usable when the body's disk is.
static func _lattice(prepared: Dictionary) -> Vector2i:
	return Vector2i(int(prepared.qx)*2+1,int(prepared.qz)*2+1)

static func _node_point(prepared: Dictionary, node: Vector2i) -> Vector2:
	return Vector2(float(prepared.ox)+float(node.x)*float(prepared.s)*0.5,float(prepared.oz)+float(node.y)*float(prepared.s)*0.5)

## Route inside the stretch for a body of `radius`: A* on the half-spacing lattice
## (every leg checked by the exact capsule), then greedy string pulling. Ties are
## broken by node index, so the route is deterministic.
static func path(prepared: Dictionary, from: Vector2, to: Vector2, radius: float, inside: bool = true) -> Dictionary:
	if not disk_clear(prepared,from,radius,inside) or not disk_clear(prepared,to,radius,inside): return {"ok":false,"code":"height_grid_endpoint"}
	if segment_clear(prepared,from,to,radius,inside): return {"ok":true,"points":PackedVector2Array([from,to]),"length":from.distance_to(to)}
	var size := _lattice(prepared)
	if size.x*size.y > MAX_LATTICE: return {"ok":false,"code":"height_grid_limit"}
	var usable := {}
	var node_ok := func(node: Vector2i) -> bool:
		var key := node.y*size.x+node.x
		if not usable.has(key): usable[key] = disk_clear(prepared,_node_point(prepared,node),radius,inside)
		return usable[key]
	var start := -1; var goal := -2
	var g := {start:0.0}; var parent := {}; var closed := {}
	var heap: Array = [[from.distance_to(to),start]]
	var at := func(id: int) -> Vector2:
		if id == start: return from
		if id == goal: return to
		return _node_point(prepared,Vector2i(id%size.x,id/size.x))
	var neighbours := func(id: int) -> Array:
		var result: Array = []
		if id < 0:
			var p: Vector2 = at.call(id)
			var cx := int(round((p.x-float(prepared.ox))/(float(prepared.s)*0.5))); var cz := int(round((p.y-float(prepared.oz))/(float(prepared.s)*0.5)))
			for dz: int in range(-1,2):
				for dx: int in range(-1,2):
					var n := Vector2i(cx+dx,cz+dz)
					if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y or not node_ok.call(n): continue
					if segment_clear(prepared,p,_node_point(prepared,n),radius,inside): result.append(n.y*size.x+n.x)
			return result
		var node := Vector2i(id%size.x,id/size.x)
		for d: Vector2i in DIRECTIONS:
			var n := node+d
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y or not node_ok.call(n): continue
			if segment_clear(prepared,_node_point(prepared,node),_node_point(prepared,n),radius,inside): result.append(n.y*size.x+n.x)
		var q: Vector2 = _node_point(prepared,node)
		if q.distance_to(to) <= float(prepared.s)*0.75 and segment_clear(prepared,q,to,radius,inside): result.append(goal)
		return result
	var expanded := 0
	while not heap.is_empty():
		var entry: Array = _heap_pop(heap)
		var id: int = entry[1]
		if closed.has(id): continue
		closed[id] = true; expanded += 1
		if id == goal: break
		for next: int in neighbours.call(id):
			if closed.has(next): continue
			var cost: float = float(g[id])+Vector2(at.call(id)).distance_to(at.call(next))
			if not g.has(next) or cost < float(g[next])-EPS:
				g[next] = cost; parent[next] = id
				_heap_push(heap,[cost+Vector2(at.call(next)).distance_to(to),next])
	if not closed.has(goal): return {"ok":false,"code":"height_grid_unreachable","expanded":expanded}
	var raw: Array[Vector2] = []
	var cursor := goal
	while true:
		raw.push_front(at.call(cursor))
		if cursor == start: break
		cursor = parent[cursor]
	var points := PackedVector2Array([raw[0]])
	var i := 0
	while i < raw.size()-1:
		var j := raw.size()-1
		while j > i+1 and not segment_clear(prepared,raw[i],raw[j],radius,inside): j -= 1
		points.append(raw[j]); i = j
	var length := 0.0
	for k: int in points.size()-1: length += points[k].distance_to(points[k+1])
	return {"ok":true,"points":points,"length":length,"expanded":expanded}

## Connected components of the usable lattice for `radius` (8-neighbour legs
## checked by the capsule). Returns labels (-1 unusable) and the count.
static func components(prepared: Dictionary, radius: float, inside: bool = true) -> Dictionary:
	var size := _lattice(prepared)
	if size.x*size.y > MAX_LATTICE: return {"ok":false,"code":"height_grid_limit"}
	var labels := PackedInt32Array(); labels.resize(size.x*size.y); labels.fill(-2)
	var count := 0
	for id: int in labels.size():
		if labels[id] != -2: continue
		var node := Vector2i(id%size.x,id/size.x)
		if not disk_clear(prepared,_node_point(prepared,node),radius,inside): labels[id] = -1; continue
		labels[id] = count
		var stack: Array[int] = [id]
		while not stack.is_empty():
			var current: int = stack.pop_back()
			var c := Vector2i(current%size.x,current/size.x)
			for d: Vector2i in DIRECTIONS:
				var n := c+d
				if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y: continue
				var key := n.y*size.x+n.x
				if labels[key] >= 0: continue
				if labels[key] == -1: continue
				if not disk_clear(prepared,_node_point(prepared,n),radius,inside): labels[key] = -1; continue
				if not segment_clear(prepared,_node_point(prepared,c),_node_point(prepared,n),radius,inside): continue
				labels[key] = count; stack.append(key)
		count += 1
	return {"ok":true,"labels":labels,"count":count,"size":size}

## Open spans along one side (0 = z min, 1 = x max, 2 = z max, 3 = x min): runs
## of boundary edges whose inner triangle is walkable. Endpoints in world x/z with
## their exact support; `from`/`to` are sample indices along the side.
static func edge_spans(prepared: Dictionary, side: int) -> Array[Dictionary]:
	var spans: Array[Dictionary] = []
	var count := int(prepared.qx) if side % 2 == 0 else int(prepared.qz)
	var open_from := -1
	for k: int in count+1:
		var open := false
		if k < count:
			var t := -1
			match side:
				0: t = (0*int(prepared.qx)+k)*2
				1: t = (k*int(prepared.qx)+int(prepared.qx)-1)*2
				2: t = ((int(prepared.qz)-1)*int(prepared.qx)+k)*2+1
				3: t = (k*int(prepared.qx))*2+1
			open = triangle_walkable(prepared,t)
		if open and open_from < 0: open_from = k
		if not open and open_from >= 0:
			spans.append({"side":side,"from":open_from,"to":k,"a":_side_point(prepared,side,open_from),"b":_side_point(prepared,side,k)})
			open_from = -1
	return spans

static func _side_point(prepared: Dictionary, side: int, k: int) -> Vector3:
	match side:
		0: return point(prepared,k,0)
		1: return point(prepared,int(prepared.qx),k)
		2: return point(prepared,k,int(prepared.qz))
	return point(prepared,0,k)
