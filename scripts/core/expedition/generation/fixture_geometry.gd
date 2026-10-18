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

static func valid_cell(cell: Dictionary) -> bool:
	var vertices: Array = cell["vertices"]
	if vertices.size() < 3 or cell["headroom"] <= 0.0: return false
	var normal := plane_normal(vertices)
	if absf(normal.y) < EPSILON: return false
	for point: Vector3 in vertices:
		if absf((point - Vector3(vertices[0])).dot(normal)) > EPSILON: return false
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
	if absf((point - Vector3(vertices[0])).dot(plane_normal(vertices))) > EPSILON: return false
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
	var normal := plane_normal(vertices)
	point.y = Vector3(vertices[0]).y - (normal.x*(point.x-Vector3(vertices[0]).x) + normal.z*(point.z-Vector3(vertices[0]).z))/normal.y
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
	# Sweep the vertical actor envelope with Minkowski-expanded authored AABBs.
	for volume: AABB in volumes:
		var expanded := AABB(volume.position-Vector3(radius,height,radius), volume.size+Vector3(2*radius,height,2*radius))
		expanded.position += Vector3.ONE*EPSILON
		expanded.size -= Vector3.ONE*2.0*EPSILON
		if expanded.has_point(a) or expanded.has_point(b) or expanded.intersects_segment(a,b) != null: return false
	return true
