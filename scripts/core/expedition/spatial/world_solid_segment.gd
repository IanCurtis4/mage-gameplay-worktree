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
func configure(point: ExpeditionWorldPoint, normal: Vector3, half_length: float, half_width: float, height: float, traversal: Dictionary) -> bool:
	_valid = false
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
	result.configure(anchor(),_normal,_length,_width,_height,_profile)
	return result
func ends() -> Array[Vector3]: return [_anchor.position-_axis*_length,_anchor.position+_axis*_length]
func corners(radius: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var padding := _width+radius+WorldGeometry.EPS*4
	for side: float in [-1.0,1.0]:
		for outward: float in [-1.0,1.0]: result.append(_anchor.position+_axis*side*(_length+padding)+_normal*outward*padding)
	return result
func contact(from: Vector3, to: Vector3, collider: Dictionary) -> Dictionary:
	if not _valid or not from.is_finite() or not to.is_finite() or not collider.has_all(["radius","height"]): return {}
	if not WorldGeometry._finite_number(collider["radius"]) or not WorldGeometry._finite_number(collider["height"]) or minf(float(collider["radius"]),float(collider["height"])) < 0: return {}
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
