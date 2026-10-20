class_name WorldSupportRegion
extends RefCounted
## Convex footprint partitioned over explicit connected support. No inferred floor or renderer.
const EPS := WorldGeometry.EPS
static func area(polygon: PackedVector2Array) -> float:
	var result := 0.0
	for index: int in polygon.size(): result += polygon[index].cross(polygon[(index+1)%polygon.size()])
	return absf(result)*0.5
static func prepare(world: WorldGeometry, anchor: ExpeditionWorldPoint, polygon: PackedVector2Array, profile: Dictionary, revision: int, surfaces: Array, volumes: Array, segments: Array) -> Dictionary:
	if polygon.size() < 3 or area(polygon) <= EPS: return WorldSkillCast.failure(&"invalid_region")
	for point: Vector2 in polygon:
		if not point.is_finite(): return WorldSkillCast.failure(&"invalid_region")
	var valid := world.position_query(anchor,profile,revision)
	if not valid["ok"]: return valid
	var patches: Array[Dictionary] = []
	var covered := 0.0
	for cell: Dictionary in surfaces:
		var outline := PackedVector2Array()
		for vertex: Vector3 in cell["vertices"]: outline.append(Vector2(vertex.x,vertex.z))
		for intersection: PackedVector2Array in Geometry2D.intersect_polygons(polygon,outline):
			var size := area(intersection)
			if size <= EPS: continue
			var center := Vector2.ZERO
			for point: Vector2 in intersection: center += point
			center /= float(intersection.size())
			var probe := world.ground_line_point_at(anchor,center,profile,revision)
			if not probe["ok"] or probe["data"]["point"]["surface_id"] != cell["surface_id"]: continue
			# Convex cells and openings: every piece vertex and midpoint must reach the SAME support.
			for index: int in intersection.size():
				for point: Vector2 in [intersection[index],intersection[index].lerp(intersection[(index+1)%intersection.size()],0.5)]:
					var reached := world.ground_line_point_at(anchor,point,profile,revision)
					var expected := WorldGeometry.Kernel.support_y(cell,Vector3(point.x,0,point.y))
					if not reached["ok"] or Vector3(reached["data"]["point"]["position"]).distance_to(expected) > WorldGeometry.point_tolerance(anchor.position,expected): return WorldSkillCast.failure(&"unsupported_region")
			var origin: Vector3 = cell["vertices"][0]
			var normal := WorldGeometry.Kernel.plane_normal(cell["vertices"])
			var patch := {"surface_id":cell["surface_id"],"polygon":intersection,"origin":origin,"normal":normal}
			for volume: AABB in volumes:
				var rectangle := PackedVector2Array([Vector2(volume.position.x,volume.position.z),Vector2(volume.end.x,volume.position.z),Vector2(volume.end.x,volume.end.z),Vector2(volume.position.x,volume.end.z)])
				for overlap: PackedVector2Array in Geometry2D.intersect_polygons(intersection,rectangle):
					if area(overlap) <= EPS: continue
					var low := INF; var high := -INF
					for point: Vector2 in overlap:
						var y := support_y(patch,point)
						low = minf(low,y); high = maxf(high,y)
					if low < volume.end.y-EPS and high+float(profile["height"]) > volume.position.y+EPS: return WorldSkillCast.failure(&"region_occluded")
			for segment: WorldSolidSegment in segments:
				if segment.intersects_region(intersection,origin,normal,float(profile["height"])): return WorldSkillCast.failure(&"region_occluded")
			patches.append(patch); covered += size
	if absf(covered-area(polygon)) > maxf(EPS,area(polygon)*0.00001): return WorldSkillCast.failure(&"unsupported_region")
	return {"ok":true,"error_code":&"","data":{"patches":patches,"polygon":polygon,"anchor":anchor.to_data(),"profile":profile.duplicate(true)}}
static func support_y(patch: Dictionary, point: Vector2) -> float:
	var origin: Vector3 = patch["origin"]; var normal: Vector3 = patch["normal"]
	return origin.y-(normal.x*(point.x-origin.x)+normal.z*(point.y-origin.z))/normal.y
static func contains(polygon: PackedVector2Array, point: Vector2, radius: float = 0.0) -> bool:
	if Geometry2D.is_point_in_polygon(point,polygon): return true
	for index: int in polygon.size():
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[index],polygon[(index+1)%polygon.size()])) <= radius+EPS: return true
	return false
static func polygon_fraction(polygon: PackedVector2Array, from: Vector2, to: Vector2, radius: float) -> float:
	if contains(polygon,from,radius): return 0.0
	var first := 2.0
	for index: int in polygon.size():
		var a := polygon[index]; var b := polygon[(index+1)%polygon.size()]
		var axis := (b-a).normalized(); var normal := axis.orthogonal()
		var start := from-a; var finish := to-a
		var hit := WorldGeometry._segment_box(Vector3(start.dot(axis),0,start.dot(normal)),Vector3(finish.dot(axis),0,finish.dot(normal)),AABB(Vector3(0,-1,-radius),Vector3(a.distance_to(b),2,2*radius)))
		if not hit.is_empty(): first = minf(first,float(hit["fraction"]))
		var cap := WorldProjectileMotion.cylinder_fraction(Vector3(from.x,0,from.y),Vector3(to.x,0,to.y),Vector3(a.x,0,a.y),radius,0,0)
		if cap >= 0: first = minf(first,cap)
	return first if first <= 1 else -1.0
static func height_interval(from: float, to: float, low: float, high: float) -> Vector2:
	if absf(to-from) <= EPS: return Vector2(0,1) if from >= low and from <= high else Vector2(1,-1)
	var a := (low-from)/(to-from); var b := (high-from)/(to-from)
	return Vector2(maxf(0,minf(a,b)),minf(1,maxf(a,b)))
static func fraction(region: Dictionary, from: Vector3, to: Vector3, collider: Dictionary, height: float) -> float:
	var first := 2.0
	var radius := float(collider["radius"]); var body_height := float(collider["height"])
	for patch: Dictionary in region.get("patches",[]):
		var a := from.y-support_y(patch,Vector2(from.x,from.z)); var b := to.y-support_y(patch,Vector2(to.x,to.z))
		var normal: Vector3 = patch["normal"]
		var radial_height := radius*Vector2(normal.x,normal.z).length()/absf(normal.y)
		var interval := height_interval(a,b,-body_height-radial_height,height+radial_height-EPS)
		if interval.x > interval.y: continue
		var start := from.lerp(to,interval.x); var finish := from.lerp(to,interval.y)
		var at := polygon_fraction(patch["polygon"],Vector2(start.x,start.z),Vector2(finish.x,finish.z),radius)
		if at >= 0: first = minf(first,lerpf(interval.x,interval.y,at))
	return first if first <= 1 else -1.0
static func ground_contains(region: Dictionary, point: ExpeditionWorldPoint, radius: float = 0.0) -> bool:
	if point == null: return false
	for patch: Dictionary in region.get("patches",[]):
		if patch["surface_id"] == point.surface_id and absf(point.position.y-support_y(patch,Vector2(point.position.x,point.position.z))) <= EPS and contains(patch["polygon"],Vector2(point.position.x,point.position.z),radius): return true
	return false

static func capsule_fraction_2d(a: Vector2, b: Vector2, from: Vector2, to: Vector2, radius: float) -> float:
	var axis := (b-a).normalized(); var normal := axis.orthogonal()
	var start := from-a; var finish := to-a
	var strip := WorldGeometry._segment_box(Vector3(start.dot(axis),0,start.dot(normal)),Vector3(finish.dot(axis),0,finish.dot(normal)),AABB(Vector3(0,-1,-radius),Vector3(a.distance_to(b),2,2*radius)))
	var first := float(strip["fraction"]) if not strip.is_empty() else 2.0
	for endpoint: Vector2 in [a,b]:
		var at := WorldProjectileMotion.cylinder_fraction(Vector3(from.x,0,from.y),Vector3(to.x,0,to.y),Vector3(endpoint.x,0,endpoint.y),radius,0,0)
		if at >= 0: first = minf(first,at)
	return first if first <= 1 else -1.0
static func capsule_fraction(region: Dictionary, a: Vector2, b: Vector2, width: float, from: Vector3, to: Vector3, collider: Dictionary, height: float) -> float:
	var radius := float(collider["radius"]); var body_height := float(collider["height"])
	var start := Vector2(from.x,from.z); var finish := Vector2(to.x,to.z)
	var enter := capsule_fraction_2d(a,b,start,finish,width+radius)
	var reverse := capsule_fraction_2d(a,b,finish,start,width+radius)
	if enter < 0 or reverse < 0: return -1.0
	var first := 2.0
	for patch: Dictionary in region.get("patches",[]):
		var pin := polygon_fraction(patch["polygon"],start,finish,radius)
		var pout := polygon_fraction(patch["polygon"],finish,start,radius)
		if pin < 0 or pout < 0: continue
		var normal: Vector3 = patch["normal"]
		var radial_height := radius*Vector2(normal.x,normal.z).length()/absf(normal.y)
		var vertical := height_interval(from.y-support_y(patch,start),to.y-support_y(patch,finish),-body_height-radial_height,height+radial_height-EPS)
		var low := maxf(enter,maxf(pin,vertical.x)); var high := minf(1.0-reverse,minf(1.0-pout,vertical.y))
		if low <= high: first = minf(first,low)
	return first if first <= 1 else -1.0
static func clip_vertical_overlap(polygon: PackedVector2Array, region_patch: Dictionary, other_patch: Dictionary, lower: float, upper: float) -> PackedVector2Array:
	var clipped := polygon
	for side: int in 2:
		var output := PackedVector2Array()
		for index: int in clipped.size():
			var a := clipped[index]; var b := clipped[(index+1)%clipped.size()]
			var ay := support_y(region_patch,a)-support_y(other_patch,a)
			var by := support_y(region_patch,b)-support_y(other_patch,b)
			var av := upper-ay if side == 0 else ay-lower
			var bv := upper-by if side == 0 else by-lower
			if av >= 0: output.append(a)
			if (av < 0) != (bv < 0): output.append(a.lerp(b,av/(av-bv)))
		clipped = output
		if clipped.size() < 3: break
	return clipped
