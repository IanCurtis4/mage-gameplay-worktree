@tool
extends RefCounted
## F10 H1 (contracts/f10_height_grid.md): one rectangular stretch of a terrain
## height grid as a single support surface. Pure and static: no stage, actor or
## navigation state. The triangulation is the renderer's and the compiler's: each
## quad (a,b,c,d) = (x,z),(x+1,z),(x+1,z+1),(x,z+1) is split into (a,b,c) and
## (a,c,d). Steep triangles are holes of the surface, never ground.
const EPS := 0.00001
const WALK_NORMAL_Y := 0.7071067811865476
const MAX_SAMPLES := 257
const MAX_LATTICE := 263169
const DIRECTIONS: Array[Vector2i] = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]
const MAX_SHARED_LATTICES := 2048
static var _lattices: Dictionary = {}
static var _lattices_mutex := Mutex.new()
static var lattices_built := 0

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
		var flag := 1 if _walkable_vertices(triangle_vertices(prepared,t)) else 0
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

## F10 Q1: the walkable triangles of the quads touching a box, as vertex lists.
static func triangles_in(prepared: Dictionary, low: Vector2, high: Vector2) -> Array:
	var qx := int(prepared.qx); var s := float(prepared.s)
	var x0 := clampi(floori((low.x-float(prepared.ox))/s),0,qx-1); var x1 := clampi(floori((high.x-float(prepared.ox))/s),0,qx-1)
	var z0 := clampi(floori((low.y-float(prepared.oz))/s),0,int(prepared.qz)-1); var z1 := clampi(floori((high.y-float(prepared.oz))/s),0,int(prepared.qz)-1)
	var result: Array = []
	for z: int in range(z0,z1+1):
		for x: int in range(x0,x1+1):
			for t: int in [(z*qx+x)*2,(z*qx+x)*2+1]:
				if triangle_walkable(prepared,t): result.append(triangle_vertices(prepared,t))
	return result

static func triangle_walkable(prepared: Dictionary, t: int) -> bool:
	if t < 0 or t >= int(prepared.qx)*int(prepared.qz)*2: return false
	if prepared.has("walk"): return prepared.walk[t] == 1
	return _walkable_vertices(triangle_vertices(prepared,t))

## The planar kernel's normal rule (Vector3 arithmetic, like
## ExpeditionFixtureGeometry.plane_normal and the compiler's topology).
static func _walkable_vertices(vertices: Array) -> bool:
	var normal := (Vector3(vertices[1])-Vector3(vertices[0])).cross(Vector3(vertices[2])-Vector3(vertices[0])).normalized()
	return absf(normal.y) >= WALK_NORMAL_Y-EPS

## O(1) view over a grid that was already validated (a stage surface): no copy
## and no mask; walkability is evaluated per triangle on demand.
static func view(grid: Dictionary) -> Dictionary:
	var columns := int(grid.columns); var rows := int(grid.rows)
	return {"ox":float(grid.origin_xz[0]),"oz":float(grid.origin_xz[1]),"s":float(grid.sample_spacing),"columns":columns,"rows":rows,"qx":columns-1,"qz":rows-1,"h":grid.heights}

static func walkable_count(prepared: Dictionary) -> int:
	var count := 0
	for t: int in int(prepared.qx)*int(prepared.qz)*2:
		if triangle_walkable(prepared,t): count += 1
	return count

## Outline of the stretch in the kernel's vertex order, at the exact corner heights.
static func corners(prepared: Dictionary) -> Array:
	return [point(prepared,0,0),point(prepared,int(prepared.qx),0),point(prepared,int(prepared.qx),int(prepared.qz)),point(prepared,0,int(prepared.qz))]

static func height_range(prepared: Dictionary) -> Vector2:
	var low := INF; var high := -INF
	for value: Variant in prepared.h: low = minf(low,float(value)); high = maxf(high,float(value))
	return Vector2(low,high)

## Upward unit normal of one triangle.
static func triangle_normal(prepared: Dictionary, t: int) -> Vector3:
	var vertices := triangle_vertices(prepared,t)
	var normal := (Vector3(vertices[1])-Vector3(vertices[0])).cross(Vector3(vertices[2])-Vector3(vertices[0])).normalized()
	return normal if normal.y >= 0.0 else -normal

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
	return support_on(prepared,t,x,z)

## The stretch's support extended past its outline by clamping to the nearest
## point inside, as a planar cell extends its plane (seams query just outside).
static func support_y_clamped(prepared: Dictionary, x: float, z: float) -> float:
	var box := bounds(prepared)
	var cx := clampf(x,box.position.x,box.end.x); var cz := clampf(z,box.position.y,box.end.y)
	var t := triangle_at(prepared,cx,cz)
	return support_on(prepared,t,x,z)

## The plane of triangle `t` evaluated at (x, z), in f64 from its f32 vertices.
static func support_on(prepared: Dictionary, t: int, x: float, z: float) -> float:
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

## F10 H6: the walkable mask plus, per quad row, a prefix count of the quads
## that hold a steep triangle, so box and capsule queries skip steep-free rows
## and quads (same triangles, same answers). Adds the keys to `prepared` in
## place and returns it; callers index a view they own, before sharing it.
static func index(prepared: Dictionary) -> Dictionary:
	if prepared.has("steep_rows"): return prepared
	var qx := int(prepared.qx); var qz := int(prepared.qz)
	if not prepared.has("walk"):
		var mask := PackedByteArray(); mask.resize(qx*qz*2)
		for t: int in mask.size(): mask[t] = 1 if _walkable_vertices(triangle_vertices(prepared,t)) else 0
		prepared["walk"] = mask
	var walk: PackedByteArray = prepared.walk
	var rows := PackedInt32Array(); rows.resize(qz*(qx+1))
	for j: int in qz:
		var base := j*(qx+1); var count := 0
		for i: int in qx:
			var q := (j*qx+i)*2
			if walk[q] == 0 or walk[q+1] == 0: count += 1
			rows[base+i+1] = count
	prepared["steep_rows"] = rows
	return prepared

## Steep triangles whose quads meet the box [low, high] (clamped to the stretch).
static func _steep_in(prepared: Dictionary, low: Vector2, high: Vector2) -> Array[int]:
	var result: Array[int] = []
	var s := float(prepared.s); var qx := int(prepared.qx)
	var i0 := clampi(int(floor((low.x-float(prepared.ox))/s)),0,qx-1); var i1 := clampi(int(floor((high.x-float(prepared.ox))/s)),0,qx-1)
	var j0 := clampi(int(floor((low.y-float(prepared.oz))/s)),0,int(prepared.qz)-1); var j1 := clampi(int(floor((high.y-float(prepared.oz))/s)),0,int(prepared.qz)-1)
	var rows: PackedInt32Array = prepared.get("steep_rows",PackedInt32Array())
	for j: int in range(j0,j1+1):
		if not rows.is_empty() and rows[j*(qx+1)+i1+1] == rows[j*(qx+1)+i0]: continue
		for i: int in range(i0,i1+1):
			for k: int in 2:
				var t := (j*qx+i)*2+k
				if not triangle_walkable(prepared,t): result.append(t)
	return result

## F10 H6: steep triangles of the quads a capsule of `reach` around [a, b] can
## meet. Per row, the segment is clipped to the row's band grown by the reach
## and only the quads within the reach of that piece are listed: every steep
## triangle closer than the reach is included (a margin covers rounding).
static func _steep_near(prepared: Dictionary, a: Vector2, b: Vector2, reach: float) -> Array[int]:
	var result: Array[int] = []
	var s := float(prepared.s); var ox := float(prepared.ox); var oz := float(prepared.oz)
	var qx := int(prepared.qx); var qz := int(prepared.qz)
	var grow := reach+0.001
	var rows: PackedInt32Array = prepared.get("steep_rows",PackedInt32Array())
	var j0 := clampi(int(floor((minf(a.y,b.y)-grow-oz)/s)),0,qz-1); var j1 := clampi(int(floor((maxf(a.y,b.y)+grow-oz)/s)),0,qz-1)
	var dz := b.y-a.y
	for j: int in range(j0,j1+1):
		var low_z := oz+float(j)*s-grow; var high_z := oz+float(j+1)*s+grow
		var t0 := 0.0; var t1 := 1.0
		if absf(dz) <= EPS:
			if maxf(a.y,b.y) < low_z or minf(a.y,b.y) > high_z: continue
		else:
			var u := (low_z-a.y)/dz; var v := (high_z-a.y)/dz
			t0 = maxf(0.0,minf(u,v)); t1 = minf(1.0,maxf(u,v))
			if t0 > t1: continue
		var xa := a.x+(b.x-a.x)*t0; var xb := a.x+(b.x-a.x)*t1
		var i0 := clampi(int(floor((minf(xa,xb)-grow-ox)/s)),0,qx-1); var i1 := clampi(int(floor((maxf(xa,xb)+grow-ox)/s)),0,qx-1)
		if not rows.is_empty() and rows[j*(qx+1)+i1+1] == rows[j*(qx+1)+i0]: continue
		for i: int in range(i0,i1+1):
			for k: int in 2:
				var t := (j*qx+i)*2+k
				if not triangle_walkable(prepared,t): result.append(t)
	return result

## F10 H6: whether any quad meeting the box holds a steep triangle.
static func _box_has_steep(prepared: Dictionary, low: Vector2, high: Vector2) -> bool:
	var rows: PackedInt32Array = prepared.get("steep_rows",PackedInt32Array())
	if rows.is_empty(): return not _steep_in(prepared,low,high).is_empty()
	var s := float(prepared.s); var qx := int(prepared.qx)
	var i0 := clampi(int(floor((low.x-float(prepared.ox))/s)),0,qx-1); var i1 := clampi(int(floor((high.x-float(prepared.ox))/s)),0,qx-1)
	var j0 := clampi(int(floor((low.y-float(prepared.oz))/s)),0,int(prepared.qz)-1); var j1 := clampi(int(floor((high.y-float(prepared.oz))/s)),0,int(prepared.qz)-1)
	for j: int in range(j0,j1+1):
		if rows[j*(qx+1)+i1+1] != rows[j*(qx+1)+i0]: return true
	return false

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
	return _segment_clear_between_disks(prepared,a,b,radius)

## Private capsule interior: both endpoint disks were proved against this same
## immutable view, radius and inside policy. Public callers use segment_clear.
static func _segment_clear_between_disks(prepared: Dictionary, a: Vector2, b: Vector2, radius: float) -> bool:
	var reach := maxf(radius,EPS)
	for t: int in _steep_near(prepared,a,b,reach):
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

const OPPOSITE: Array[int] = [1,0,3,2,7,6,5,4]

## Route inside the stretch for a body of `radius`: the cached lattice (every
## link checked by the exact capsule), one Dijkstra from `from`, then greedy
## string pulling. Ties are broken by node index, so the route is deterministic.
static func path(prepared: Dictionary, from: Vector2, to: Vector2, radius: float, inside: bool = true) -> Dictionary:
	if not disk_clear(prepared,from,radius,inside) or not disk_clear(prepared,to,radius,inside): return {"ok":false,"code":"height_grid_endpoint"}
	if segment_clear(prepared,from,to,radius,inside): return {"ok":true,"points":PackedVector2Array([from,to]),"length":from.distance_to(to),"expanded":0}
	var built := lattice(prepared,radius,inside)
	if built.is_empty(): return {"ok":false,"code":"height_grid_limit"}
	return route(built,field(built,from),to)

## Lattice of one stretch for one body: usable nodes (the disk is clear) and the
## 8-neighbour links whose capsule is clear, as bit masks. Read-only once built;
## WorldGeometry caches it per stretch and radius.
## F10 Q1: a lattice is a pure function of the stretch and the radius. Maps that
## share a stretch (the next compile after a stroke) reuse it by content.
static func lattice_shared(prepared: Dictionary, radius: float) -> Dictionary:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes([prepared.ox,prepared.oz,prepared.s,prepared.qx,prepared.qz,prepared.h,radius]))
	var content := context.finish()
	_lattices_mutex.lock(); var known: Variant = _lattices.get(content); _lattices_mutex.unlock()
	if known != null: return known
	var built := lattice(prepared,radius,true)
	_lattices_mutex.lock()
	lattices_built += 1
	if _lattices.size() >= MAX_SHARED_LATTICES: _lattices.clear()
	if not _lattices.has(content): _lattices[content] = built
	var result: Dictionary = _lattices[content]
	_lattices_mutex.unlock()
	return result

static func clear_shared_lattices() -> void:
	_lattices_mutex.lock(); _lattices.clear(); _lattices_mutex.unlock()

static func lattice(prepared: Dictionary, radius: float, inside: bool = true) -> Dictionary:
	var masked := index(prepared.duplicate())
	var size := _lattice(masked)
	var reach := maxf(radius,EPS)
	if size.x*size.y > MAX_LATTICE: return {}
	var usable := PackedByteArray(); usable.resize(size.x*size.y)
	for id: int in usable.size(): usable[id] = 1 if disk_clear(masked,_node_point(masked,Vector2i(id%size.x,id/size.x)),radius,inside) else 0
	var links := PackedByteArray(); links.resize(size.x*size.y)
	for id: int in usable.size():
		if usable[id] == 0: continue
		var node := Vector2i(id%size.x,id/size.x)
		for k: int in 8:
			var n := node+DIRECTIONS[k]
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y: continue
			var other := n.y*size.x+n.x
			if usable[other] == 0: continue
			if other < id:
				if links[other] & (1 << OPPOSITE[k]): links[id] |= (1 << k)
				continue
			# Both ends are usable (their disks are clear): with no steep quad in
			# the leg's box the capsule is clear, as segment_clear would find.
			var p := _node_point(masked,node); var q := _node_point(masked,n)
			if not _box_has_steep(masked,Vector2(minf(p.x,q.x),minf(p.y,q.y))-Vector2(reach,reach),Vector2(maxf(p.x,q.x),maxf(p.y,q.y))+Vector2(reach,reach)) or segment_clear(masked,p,q,radius,inside): links[id] |= (1 << k)
	return {"view":masked,"size":size,"usable":usable,"links":links,"radius":radius,"inside":inside}

## Usable lattice nodes around `point` (two rings) that the body reaches in a
## straight clear capsule, with that distance.
static func _attach(built: Dictionary, point: Vector2) -> Array:
	var view: Dictionary = built.view; var size: Vector2i = built.size
	var radius := float(built.radius)
	if not disk_clear(view,point,radius,bool(built.inside)): return []
	var half := float(view.s)*0.5
	var cx := int(round((point.x-float(view.ox))/half)); var cz := int(round((point.y-float(view.oz))/half))
	var result: Array = []
	for dz: int in range(-2,3):
		for dx: int in range(-2,3):
			var n := Vector2i(cx+dx,cz+dz)
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y: continue
			var id := n.y*size.x+n.x
			if built.usable[id] == 0: continue
			var q := _node_point(view,n)
			# usable proved q's disk in this same lattice; point's disk was proved
			# once above. Keep the ordered steep test and distance unchanged.
			if _segment_clear_between_disks(view,point,q,radius): result.append([id,point.distance_to(q)])
	return result

## Single-source distances over the lattice from `from` (2D, along the links).
static func field(built: Dictionary, from: Vector2) -> Dictionary:
	var view: Dictionary = built.view; var size: Vector2i = built.size
	if not disk_clear(view,from,float(built.radius),bool(built.inside)): return {"ok":false,"code":"height_grid_endpoint"}
	var count := size.x*size.y
	var dist := PackedFloat64Array(); dist.resize(count); dist.fill(INF)
	var parent := PackedInt32Array(); parent.resize(count); parent.fill(-2)
	var heap: Array = []
	for item: Array in _attach(built,from):
		var id: int = item[0]; var d: float = item[1]
		if d < dist[id]: dist[id] = d; parent[id] = -1; _heap_push(heap,[d,id])
	var step := float(view.s)*0.5; var diagonal := step*sqrt(2.0)
	var expanded := 0
	while not heap.is_empty():
		var entry: Array = _heap_pop(heap)
		var id: int = entry[1]
		if float(entry[0]) != dist[id]: continue
		expanded += 1
		var bits: int = built.links[id]
		if bits == 0: continue
		var node := Vector2i(id%size.x,id/size.x)
		for k: int in 8:
			if bits & (1 << k) == 0: continue
			var n := node+DIRECTIONS[k]
			var other := n.y*size.x+n.x
			var cost := dist[id]+(step if k < 4 else diagonal)
			if cost < dist[other]:
				dist[other] = cost; parent[other] = id; _heap_push(heap,[cost,other])
	return {"ok":true,"dist":dist,"parent":parent,"from":from,"expanded":expanded}

## Route from the field's source to `to`, string-pulled. Deterministic.
static func route(built: Dictionary, reach: Dictionary, to: Vector2) -> Dictionary:
	if not reach.get("ok",false): return {"ok":false,"code":reach.get("code","height_grid_endpoint")}
	var view: Dictionary = built.view; var size: Vector2i = built.size
	var radius := float(built.radius); var inside := bool(built.inside)
	var from: Vector2 = reach.from
	if not disk_clear(view,to,radius,inside): return {"ok":false,"code":"height_grid_endpoint"}
	if segment_clear(view,from,to,radius,inside): return {"ok":true,"points":PackedVector2Array([from,to]),"length":from.distance_to(to),"expanded":reach.expanded}
	var best := INF; var best_id := -1
	for item: Array in _attach(built,to):
		var id: int = item[0]
		if reach.dist[id] == INF: continue
		var total: float = reach.dist[id]+float(item[1])
		if total < best or (total == best and id < best_id): best = total; best_id = id
	if best_id < 0: return {"ok":false,"code":"height_grid_unreachable","expanded":reach.expanded}
	var raw: Array[Vector2] = [to]
	var cursor := best_id
	while cursor >= 0:
		raw.push_front(_node_point(view,Vector2i(cursor%size.x,cursor/size.x)))
		cursor = reach.parent[cursor]
	raw.push_front(from)
	var points := PackedVector2Array([raw[0]])
	var i := 0
	while i < raw.size()-1:
		var j := raw.size()-1
		while j > i+1 and not segment_clear(view,raw[i],raw[j],radius,inside): j -= 1
		points.append(raw[j]); i = j
	var length := 0.0
	for k: int in points.size()-1: length += points[k].distance_to(points[k+1])
	return {"ok":true,"points":points,"length":length,"expanded":reach.expanded}

## Open spans shared by two stretches along a common side (`side` of `a`, the
## opposite side of `b`): world-space intervals where the inner triangle is
## walkable on both. Same spacing and aligned samples are required.
static func shared_spans(a: Dictionary, side: int, b: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_equal_approx(float(a.s),float(b.s)): return result
	var opposite := (side+2) % 4
	var axis_x := side % 2 == 0
	var origin_a := float(a.ox) if axis_x else float(a.oz); var origin_b := float(b.ox) if axis_x else float(b.oz)
	for left: Dictionary in edge_spans(a,side):
		for right: Dictionary in edge_spans(b,opposite):
			var lo := maxf(origin_a+float(left.from)*float(a.s),origin_b+float(right.from)*float(b.s))
			var hi := minf(origin_a+float(left.to)*float(a.s),origin_b+float(right.to)*float(b.s))
			if hi-lo <= EPS: continue
			var line: Vector3 = left.a
			var p := Vector3(lo,0,line.z) if axis_x else Vector3(line.x,0,lo)
			var q := Vector3(hi,0,line.z) if axis_x else Vector3(line.x,0,hi)
			p.y = support_y_clamped(a,p.x,p.z); q.y = support_y_clamped(a,q.x,q.z)
			result.append({"a":p,"b":q})
	return result

## Outward unit normal of a side (0 = z min, 1 = x max, 2 = z max, 3 = x min).
static func side_outward(side: int) -> Vector3:
	match side:
		0: return Vector3(0,0,-1)
		1: return Vector3(1,0,0)
		2: return Vector3(0,0,1)
	return Vector3(-1,0,0)

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

static func _half_ulp(value: float) -> float:
	return pow(2.0,-150.0) if absf(value) < pow(2.0,-126.0) else pow(2.0,floor(log(absf(value))/log(2.0))-24.0)

## Kernel contract for a stretch cell: the point lies on the support (the same
## perpendicular tolerance and f32 roundoff budget as a planar cell) and the
## body's disk stays inside the stretch, on walkable triangles.
static func contains(prepared: Dictionary, position: Vector3, radius: float = 0.0) -> bool:
	if not position.is_finite() or not is_finite(radius) or radius < 0.0: return false
	var t := triangle_at(prepared,position.x,position.z)
	if t < 0: return false
	var y := support_on(prepared,t,position.x,position.z)
	var normal := triangle_normal(prepared,t)
	if normal.y <= 0.0: return false
	var distance := absf(float(position.y)-y)*float(normal.y)
	var roundoff := absf(normal.x)*_half_ulp(position.x)+absf(normal.y)*_half_ulp(position.y)+absf(normal.z)*_half_ulp(position.z)
	if distance > EPS+roundoff: return false
	return disk_clear(prepared,Vector2(position.x,position.z),radius,true)

## Steep-triangle edges whose quads meet [low, high]: the closed boundaries a
## body's clearance must respect inside the stretch.
static func steep_edges_in(prepared: Dictionary, low: Vector2, high: Vector2) -> Array:
	var edges: Array = []
	for t: int in _steep_in(prepared,low,high):
		var tri := _triangle_2d(prepared,t)
		for k: int in 3: edges.append([tri[k],tri[(k+1)%3]])
	return edges

## F10 H6: the steep-triangle edges a capsule of `reach` around [a, b] can
## meet (see _steep_near); the others are farther than the reach.
static func steep_edges_near(prepared: Dictionary, a: Vector2, b: Vector2, reach: float) -> Array:
	var edges: Array = []
	for t: int in _steep_near(prepared,a,b,reach):
		var tri := _triangle_2d(prepared,t)
		for k: int in 3: edges.append([tri[k],tri[(k+1)%3]])
	return edges

## Sorted parameters in [0, 1] where the horizontal projection of a->b enters,
## leaves or crosses a quad edge or diagonal of the stretch. Between two
## consecutive values the support is one plane. Empty when it misses the stretch.
static func crossings(prepared: Dictionary, a: Vector2, b: Vector2) -> PackedFloat64Array:
	var box := bounds(prepared)
	var t0 := 0.0; var t1 := 1.0
	var d := b-a
	for axis: int in 2:
		var low := box.position[axis]; var high := box.end[axis]
		var start := a[axis]; var delta := d[axis]
		if absf(delta) < 1e-12:
			if start < low-EPS or start > high+EPS: return PackedFloat64Array()
			continue
		var ta := (low-start)/delta; var tb := (high-start)/delta
		t0 = maxf(t0,minf(ta,tb)); t1 = minf(t1,maxf(ta,tb))
	if t0 > t1: return PackedFloat64Array()
	var s := float(prepared.s)
	var ua := (a.x-float(prepared.ox))/s; var va := (a.y-float(prepared.oz))/s
	var du := d.x/s; var dv := d.y/s
	var values: Array[float] = [t0,t1]
	for line: Array in [[ua,du],[va,dv],[ua-va,du-dv]]:
		var start: float = line[0]; var delta: float = line[1]
		if absf(delta) < 1e-12: continue
		var from := start+delta*t0; var to := start+delta*t1
		for k: int in range(int(ceil(minf(from,to))),int(floor(maxf(from,to)))+1):
			var t := (float(k)-start)/delta
			if t > t0 and t < t1: values.append(t)
	values.sort()
	var result := PackedFloat64Array()
	for value: float in values:
		if result.is_empty() or value-result[result.size()-1] > 1e-12: result.append(value)
	return result

## First parameter in [0, 1] where the 3D segment goes below the stretch's
## ground (its solid mass) by more than `tolerance`; -1 when it never does. The
## stretch is solid below its support, steep triangles included.
static func ground_fraction(prepared: Dictionary, from: Vector3, to: Vector3, tolerance: float = EPS) -> float:
	var a := Vector2(from.x,from.z); var b := Vector2(to.x,to.z)
	if a.distance_to(b) < 1e-9:
		var y := support_y(prepared,a.x,a.y)
		if is_nan(y): return -1.0
		if float(from.y) < y-tolerance: return 0.0
		if float(to.y) < y-tolerance: return clampf((float(from.y)-(y-tolerance))/(float(from.y)-float(to.y)),0.0,1.0)
		return -1.0
	var cuts := crossings(prepared,a,b)
	for k: int in cuts.size()-1:
		var ta := cuts[k]; var tb := cuts[k+1]
		var middle := a.lerp(b,(ta+tb)*0.5)
		var t := triangle_at(prepared,middle.x,middle.y)
		if t < 0: continue
		var pa := a.lerp(b,ta); var pb := a.lerp(b,tb)
		var fa := (float(from.y)+(float(to.y)-float(from.y))*ta)-support_on(prepared,t,pa.x,pa.y)
		var fb := (float(from.y)+(float(to.y)-float(from.y))*tb)-support_on(prepared,t,pb.x,pb.y)
		if fa < -tolerance: return ta
		if fb < -tolerance: return ta+(tb-ta)*(fa+tolerance)/(fa-fb)
	return -1.0

## First hit of a ray on the stretch from above. Returns {} on a miss.
static func ray_hit(prepared: Dictionary, origin: Vector3, direction: Vector3) -> Dictionary:
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx(): return {}
	var span := height_range(prepared)
	var box := bounds(prepared)
	var reach := origin.distance_to(Vector3(box.get_center().x,span.x,box.get_center().y))+box.size.length()+absf(span.y-span.x)+1.0
	var end := origin+direction.normalized()*reach*2.0
	var fraction := ground_fraction(prepared,origin,end,0.0)
	if fraction < 0.0: return {}
	var hit := origin.lerp(end,fraction)
	var t := triangle_at(prepared,hit.x,hit.z)
	if t < 0: return {}
	hit.y = support_on(prepared,t,hit.x,hit.z)
	return {"position":hit,"triangle":t,"walkable":triangle_walkable(prepared,t),"normal":triangle_normal(prepared,t),"distance":origin.distance_to(hit)}

## Connected components of a built lattice over its links (node index order).
static func lattice_components(built: Dictionary) -> Dictionary:
	var size: Vector2i = built.size
	var labels := PackedInt32Array(); labels.resize(size.x*size.y); labels.fill(-1)
	var sizes: Array[int] = []; var firsts: Array[int] = []
	for id: int in labels.size():
		if built.usable[id] == 0 or labels[id] >= 0: continue
		var label := sizes.size(); var count := 0
		labels[id] = label
		var stack: Array[int] = [id]
		while not stack.is_empty():
			var current: int = stack.pop_back(); count += 1
			var bits: int = built.links[current]
			var node := Vector2i(current%size.x,current/size.x)
			for k: int in 8:
				if bits & (1 << k) == 0: continue
				var n := node+DIRECTIONS[k]
				var other := n.y*size.x+n.x
				if labels[other] < 0: labels[other] = label; stack.append(other)
		sizes.append(count); firsts.append(id)
	return {"labels":labels,"sizes":sizes,"firsts":firsts}

## F10 H6: labels of the lattice components that `point` attaches to (the
## nodes a route from or to it may use, see _attach).
static func attached_labels(built: Dictionary, parts: Dictionary, point: Vector2) -> Dictionary:
	var labels := {}
	for item: Array in _attach(built,point): labels[int(parts.labels[int(item[0])])] = true
	return labels

static func node_point(built: Dictionary, id: int) -> Vector2:
	var size: Vector2i = built.size
	return _node_point(built.view,Vector2i(id%size.x,id/size.x))
