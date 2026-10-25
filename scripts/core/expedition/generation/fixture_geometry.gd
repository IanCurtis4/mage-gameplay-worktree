class_name ExpeditionFixtureGeometry
extends RefCounted
## Pure conservative geometry kernel for convex planar cells. Not F1's actor/attack WorldGeometry.
const EPSILON := 0.00001

static func rotate(point: Vector3, quarter: int) -> Vector3:
	match posmod(quarter, 4):
		1: return Vector3(-point.z, point.y, point.x)
		2: return Vector3(-point.x, point.y, -point.z)
		3: return Vector3(point.z, point.y, -point.x)
	return point

static func transform_volume(volume: AABB, quarter: int, offset: Vector3) -> AABB:
	var result := AABB(rotate(volume.position, quarter) + offset, Vector3.ZERO)
	for index: int in range(8): result = result.expand(rotate(volume.get_endpoint(index), quarter) + offset)
	return result

static func plane_normal(vertices: Array) -> Vector3:
	return (Vector3(vertices[1]) - Vector3(vertices[0])).cross(Vector3(vertices[2]) - Vector3(vertices[0])).normalized()

static func _plane(vertices: Array) -> PackedFloat64Array:
	# Vector3 arithmetic rounds to f32, even though GDScript scalar floats are f64.
	# Form/evaluate the plane with scalars so a 400/160 ramp remains planar.
	var a: Vector3 = vertices[0]; var b: Vector3 = vertices[1]; var c: Vector3 = vertices[2]
	var ux := float(b.x)-float(a.x); var uy := float(b.y)-float(a.y); var uz := float(b.z)-float(a.z)
	var vx := float(c.x)-float(a.x); var vy := float(c.y)-float(a.y); var vz := float(c.z)-float(a.z)
	return PackedFloat64Array([uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx])

static func plane_distance(vertices: Array, point: Vector3) -> float:
	var normal := _plane(vertices); var a: Vector3 = vertices[0]
	var length := sqrt(normal[0]*normal[0]+normal[1]*normal[1]+normal[2]*normal[2])
	if length == 0.0: return INF
	return (normal[0]*(float(point.x)-float(a.x))+normal[1]*(float(point.y)-float(a.y))+normal[2]*(float(point.z)-float(a.z)))/length

static func _support_roundoff(vertices: Array, point: Vector3) -> float:
	# support_y stores its exact scalar result in an f32 y component. Permit only
	# that final half-ULP of height, projected on the plane normal; EPS is unchanged.
	var normal := _plane(vertices)
	var length := sqrt(normal[0]*normal[0]+normal[1]*normal[1]+normal[2]*normal[2])
	if length == 0.0: return 0.0
	var half_ulp := pow(2.0,-150.0)
	if absf(point.y) >= pow(2.0,-126.0): half_ulp = pow(2.0,floor(log(absf(point.y))/log(2.0))-24.0)
	return absf(normal[1])/length*half_ulp

static func valid_cell(cell: Dictionary) -> bool:
	var vertices: Array = cell["vertices"]
	if vertices.size() < 3 or cell["headroom"] <= 0.0: return false
	var normal := plane_normal(vertices)
	if absf(normal.y) < EPSILON: return false
	for point: Vector3 in vertices:
		if absf(plane_distance(vertices,point)) > EPSILON: return false
	var sign_value := 0.0
	for index: int in range(vertices.size()):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[(index + 1) % vertices.size()]
		var c: Vector3 = vertices[(index + 2) % vertices.size()]
		var turn := Vector2(b.x-a.x, b.z-a.z).cross(Vector2(c.x-b.x, c.z-b.z))
		if absf(turn) <= EPSILON: return false
		if sign_value == 0.0: sign_value = signf(turn)
		if sign_value * turn <= 0.0: return false
		for point: Vector3 in vertices:
			if sign_value * Vector2(b.x-a.x,b.z-a.z).cross(Vector2(point.x-a.x,point.z-a.z)) < -EPSILON: return false
	return true

static func contains(cell: Dictionary, point: Vector3, radius: float = 0.0) -> bool:
	var vertices: Array = cell["vertices"]
	if absf(plane_distance(vertices,point)) > EPSILON+_support_roundoff(vertices,point): return false
	var side := 0.0
	for index: int in range(vertices.size()):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[(index + 1) % vertices.size()]
		var edge := Vector2(b.x-a.x, b.z-a.z)
		var cross_value := edge.cross(Vector2(point.x-a.x, point.z-a.z))
		if absf(cross_value) > EPSILON and side == 0.0: side = signf(cross_value)
		if side * cross_value < -EPSILON or absf(cross_value) / edge.length() + EPSILON < radius: return false
	return true

static func support_y(cell: Dictionary, point: Vector3) -> Vector3:
	var vertices: Array = cell["vertices"]
	var normal := _plane(vertices)
	point.y = float(Vector3(vertices[0]).y) - (normal[0]*(float(point.x)-float(Vector3(vertices[0]).x)) + normal[2]*(float(point.z)-float(Vector3(vertices[0]).z)))/normal[1]
	return point

static func connector_valid(connector: Dictionary, cell: Dictionary) -> bool:
	var outward: Vector3 = connector["outward"]
	var point: Vector3 = connector["position"]
	if absf(outward.y) > EPSILON or absf(outward.length()-1.0) > EPSILON: return false
	if not contains(cell, point): return false
	var tangent := Vector3(-outward.z, 0, outward.x)
	var half_width: float = connector["width"] * 0.5
	if not contains(cell, support_y(cell, point+tangent*half_width)) or not contains(cell, support_y(cell, point-tangent*half_width)): return false
	return contains(cell, support_y(cell, point-outward*0.001)) and not contains(cell, support_y(cell, point+outward*0.001))

static func overlaps(a: AABB, b: AABB) -> bool:
	return a.position.x < b.end.x-EPSILON and a.end.x > b.position.x+EPSILON and a.position.y < b.end.y-EPSILON and a.end.y > b.position.y+EPSILON and a.position.z < b.end.z-EPSILON and a.end.z > b.position.z+EPSILON

static func cells_overlap(a: Dictionary, b: Dictionary) -> bool:
	# Only projected interiors at intersecting support heights are forbidden. Distinct bridge levels are allowed.
	var av: Array = a["vertices"]
	var bv: Array = b["vertices"]
	for vertices: Array in [av, bv]:
		for index: int in range(vertices.size()):
			var edge: Vector3 = Vector3(vertices[(index+1)%vertices.size()])-Vector3(vertices[index])
			var axis := Vector2(-edge.z, edge.x).normalized()
			var amin := INF
			var amax := -INF
			var bmin := INF
			var bmax := -INF
			for point: Vector3 in av:
				var projection := axis.dot(Vector2(point.x,point.z))
				amin=minf(amin,projection); amax=maxf(amax,projection)
			for point: Vector3 in bv:
				var projection := axis.dot(Vector2(point.x,point.z))
				bmin=minf(bmin,projection); bmax=maxf(bmax,projection)
			if amax <= bmin+EPSILON or bmax <= amin+EPSILON: return false
	var ay: Array[float] = []
	var by: Array[float] = []
	for point: Vector3 in av: ay.append(point.y)
	for point: Vector3 in bv: by.append(point.y)
	return ay.min() <= by.max()+EPSILON and by.min() <= ay.max()+EPSILON

static func clear_segment(a: Vector3, b: Vector3, volumes: Array, radius: float, height: float) -> bool:
	for volume: AABB in volumes:
		if not sweep_box(a,b,volume,radius,height).is_empty(): return false
	return true

static func sweep_box(from: Vector3, to: Vector3, box: AABB, radius: float, height: float, actor_envelope: bool = true) -> Dictionary:
	# Keep expanded bounds as f64 scalars. Storing (slab_top - EPS) in an AABB
	# rounds it back to slab_top at height160/200 and falsely blocks its own floor.
	var low := 0.0; var high := 1.0; var normal := Vector3.ZERO
	for axis: int in 3:
		var margin := radius if axis != 1 else height
		var minimum := float(box.position[axis])-margin+(EPSILON if actor_envelope and axis != 1 else 0.0)
		var maximum := float(box.position[axis])+float(box.size[axis])+(radius if axis != 1 else 0.0)-(EPSILON if actor_envelope else 0.0)
		var delta := float(to[axis])-float(from[axis])
		if absf(delta) < EPSILON:
			if float(from[axis]) < minimum or float(from[axis]) > maximum: return {}
			continue
		var a := (minimum-float(from[axis]))/delta
		var b := (maximum-float(from[axis]))/delta
		var entry := minf(a,b)
		if entry >= low:
			low = entry; normal = Vector3.ZERO; normal[axis] = -signf(delta)
		high = minf(high,maxf(a,b))
		if low > high: return {}
	return {"fraction":low,"normal":normal}
