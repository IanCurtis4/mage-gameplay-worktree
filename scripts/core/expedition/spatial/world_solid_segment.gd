class_name WorldSolidSegment
extends RefCounted
## Captured horizontal capsule extruded vertically; bounds are never collision authority.
var _anchor: ExpeditionWorldPoint
var _normal := Vector3.RIGHT
var _axis := Vector3.BACK
var _length := 0.0
var _width := 0.0
var _height := 0.0
var _profile: Dictionary = {}
var _valid := false
var _support_region: Dictionary = {}
func configure(point: ExpeditionWorldPoint, normal: Vector3, half_length: float, half_width: float, height: float, traversal: Dictionary) -> bool:
	_valid = false
	_support_region.clear()
	if point == null or not point.position.is_finite() or not normal.is_finite() or normal.is_zero_approx() or absf(normal.y) > WorldGeometry.EPS: return false
	if not is_finite(half_length) or not is_finite(half_width) or not is_finite(height) or minf(half_length,minf(half_width,height)) <= WorldGeometry.EPS: return false
	_anchor = ExpeditionWorldPoint.create(point.stage_id,point.surface_id,point.position)
	_normal = normal.normalized(); _axis = Vector3(-_normal.z,0,_normal.x)
	_length = half_length; _width = half_width; _height = height
	_profile = traversal.duplicate(true); _profile["radius"] = half_width; _profile["height"] = height
	_valid = true
	return true
func is_valid() -> bool: return _valid
func anchor() -> ExpeditionWorldPoint: return ExpeditionWorldPoint.create(_anchor.stage_id,_anchor.surface_id,_anchor.position) if _valid else null
func profile() -> Dictionary: return _profile.duplicate(true)
func snapshot() -> WorldSolidSegment:
	if not _valid: return null
	var result := WorldSolidSegment.new()
	# Snapshot copies the captured geometry exactly; normalizing again can move
	# a diagonal unit vector by one f32 ULP on each successive copy.
	result._anchor = anchor(); result._normal = _normal; result._axis = _axis
	result._length = _length; result._width = _width; result._height = _height
	result._profile = _profile.duplicate(true); result._valid = _valid
	result._support_region = _support_region.duplicate(true)
	return result
func geometry_record() -> Dictionary:
	return {"anchor":anchor().to_data() if _valid else {},"normal":_normal,"axis":_axis,"half_length":_length,"half_width":_width,"height":_height,"profile":_profile.duplicate(true),"valid":_valid,"support_region":_support_region.duplicate(true)}
func bind_support_region(region: Dictionary) -> void: _support_region = region.duplicate(true)
func support_region() -> Dictionary: return _support_region.duplicate(true)
func ends() -> Array[Vector3]:
	var result: Array[Vector3] = [_anchor.position-_axis*_length,_anchor.position+_axis*_length]
	for index: int in result.size():
		for patch: Dictionary in _support_region.get("patches",[]):
			var horizontal := Vector2(result[index].x,result[index].z)
			if WorldSupportRegion.contains(patch["polygon"],horizontal): result[index].y = WorldSupportRegion.support_y(patch,horizontal); break
	return result
func corners(radius: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var padding := _width+radius+WorldGeometry.EPS*4
	for side: float in [-1.0,1.0]:
		for outward: float in [-1.0,1.0]: result.append(_anchor.position+_axis*side*(_length+padding)+_normal*outward*padding)
	return result
func contact(from: Vector3, to: Vector3, collider: Dictionary) -> Dictionary:
	if not _valid or not from.is_finite() or not to.is_finite() or not collider.has_all(["radius","height"]): return {}
	if not WorldGeometry._finite_number(collider["radius"]) or not WorldGeometry._finite_number(collider["height"]) or minf(float(collider["radius"]),float(collider["height"])) < 0: return {}
	if not _support_region.is_empty():
		var a := _anchor.position-_axis*_length; var b := _anchor.position+_axis*_length
		var at := WorldSupportRegion.capsule_fraction(_support_region,Vector2(a.x,a.z),Vector2(b.x,b.z),_width,from,to,collider,_height)
		return {"fraction":at,"normal":_normal} if at >= 0 else {}
	var start := from-_anchor.position; var finish := to-_anchor.position
	var radius := _width+float(collider["radius"])
	var body_height := float(collider["height"])
	var hit := WorldGeometry._segment_box(Vector3(start.dot(_normal),start.y,start.dot(_axis)),Vector3(finish.dot(_normal),finish.y,finish.dot(_axis)),AABB(Vector3(-radius,-body_height,-_length),Vector3(2*radius,_height+body_height-WorldGeometry.EPS,2*_length)))
	var first := float(hit["fraction"]) if not hit.is_empty() else 2.0
	for end: Vector3 in ends():
		var fraction := WorldProjectileMotion.cylinder_fraction(from,to,end,radius,_height-WorldGeometry.EPS,body_height)
		if fraction >= 0 and fraction < first: first = fraction
	if first > 1: return {}
	var position := from.lerp(to,first)
	var delta := position-_anchor.position
	var closest := _anchor.position+_axis*clampf(delta.dot(_axis),-_length,_length)
	var normal := Vector3(position.x-closest.x,0,position.z-closest.z).normalized()
	if absf(position.y-(_anchor.position.y+_height-WorldGeometry.EPS)) <= WorldGeometry.EPS: normal = Vector3.UP
	elif absf(position.y-(_anchor.position.y-body_height)) <= WorldGeometry.EPS and absf(to.y-from.y) > WorldGeometry.EPS: normal = Vector3.DOWN
	elif normal.is_zero_approx(): normal = _normal
	return {"fraction":first,"normal":normal}

func intersects_region(polygon: PackedVector2Array, origin: Vector3, plane: Vector3, height: float) -> bool:
	if not _support_region.is_empty():
		var source_patch := {"origin":origin,"normal":plane}
		var endpoints := ends(); var a := Vector2(endpoints[0].x,endpoints[0].z); var b := Vector2(endpoints[1].x,endpoints[1].z)
		for patch: Dictionary in _support_region["patches"]:
			for intersection: PackedVector2Array in Geometry2D.intersect_polygons(polygon,patch["polygon"]):
				var clipped := WorldSupportRegion.clip_vertical_overlap(intersection,source_patch,patch,-height+WorldGeometry.EPS,_height-WorldGeometry.EPS)
				if clipped.size() < 3: continue
				if WorldSupportRegion.contains(clipped,a) or WorldSupportRegion.contains(clipped,b): return true
				for index: int in clipped.size():
					if WorldSupportRegion.capsule_fraction_2d(a,b,clipped[index],clipped[(index+1)%clipped.size()],_width) >= 0: return true
		return false
	# Restrict the region footprint to vertical overlap before exact capsule footprint tests.
	var clipped := polygon
	for side: int in 2:
		var output := PackedVector2Array()
		for index: int in clipped.size():
			var a := clipped[index]; var b := clipped[(index+1)%clipped.size()]
			var ay := origin.y-(plane.x*(a.x-origin.x)+plane.z*(a.y-origin.z))/plane.y-_anchor.position.y
			var by := origin.y-(plane.x*(b.x-origin.x)+plane.z*(b.y-origin.z))/plane.y-_anchor.position.y
			var av := _height-WorldGeometry.EPS-ay if side == 0 else ay+height-WorldGeometry.EPS
			var bv := _height-WorldGeometry.EPS-by if side == 0 else by+height-WorldGeometry.EPS
			if av >= 0: output.append(a)
			if (av < 0) != (bv < 0): output.append(a.lerp(b,av/(av-bv)))
		clipped = output
		if clipped.size() < 3: return false
	var endpoints := ends()
	for endpoint: Vector3 in endpoints:
		if WorldSupportRegion.contains(clipped,Vector2(endpoint.x,endpoint.z)): return true
	for index: int in clipped.size():
		var a := clipped[index]; var b := clipped[(index+1)%clipped.size()]
		# Capsule footprint contact at its captured base height, independent of region's y.
		if not contact(Vector3(a.x,_anchor.position.y,a.y),Vector3(b.x,_anchor.position.y,b.y),{"radius":0.0,"height":0.0}).is_empty(): return true
	return false
