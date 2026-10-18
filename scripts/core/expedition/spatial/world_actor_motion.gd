class_name WorldActorMotion
extends RefCounted
## Logical movement, independent of rendering. Surface transitions occur only in a current route.
var geometry: WorldGeometry
var _point: ExpeditionWorldPoint
var _profile: Dictionary = {}
var _route: Array = []
var _cursor := 0
var _route_revision := 0
var _occupant_id := ""
var _configuration_revision := 0
func configure(world: WorldGeometry, point: ExpeditionWorldPoint, profile: Dictionary, occupant_id: String) -> Dictionary:
	if world == null: return {"ok":false,"error_code":&"invalid_geometry"}
	var check := world.position_query(point,profile,world.geometry_revision)
	if not check["ok"]: return check
	if occupant_id.is_empty(): return {"ok":false,"error_code":&"invalid_identity"}
	geometry = world
	_configuration_revision = world.configuration_revision
	_point = ExpeditionWorldPoint.create(point.stage_id,point.surface_id,point.position)
	_profile = profile.duplicate(true)
	_occupant_id = occupant_id
	_route.clear()
	return geometry.set_occupant(_occupant_id,_point,_profile,geometry.geometry_revision)
func point() -> ExpeditionWorldPoint:
	return ExpeditionWorldPoint.create(_point.stage_id,_point.surface_id,_point.position) if _point != null else null
func profile() -> Dictionary:
	return _profile.duplicate(true)
func plan(destination: ExpeditionWorldPoint, revision: int) -> Dictionary:
	if geometry == null: return {"ok":false,"error_code":&"invalid_geometry"}
	if not is_current_world(): return _failure(&"world_reconfigured")
	var result := geometry.path(_point,destination,_profile,revision)
	if not result["ok"]: return result
	_route = result["data"]["points"].duplicate(true)
	_cursor = 1
	_route_revision = revision
	return result
func advance(distance: float) -> Dictionary:
	var before := point()
	var previous_cursor := _cursor
	var result := _advance(distance)
	if not result["ok"]:
		_point = before
		_cursor = previous_cursor
	return result
func _advance(distance: float) -> Dictionary:
	if geometry == null: return {"ok":false,"error_code":&"invalid_geometry"}
	if not is_current_world(): return _failure(&"world_reconfigured")
	if not is_finite(distance) or distance < 0.0: return _failure(&"invalid_distance")
	if _route_revision != geometry.geometry_revision: return _failure(&"stale_geometry")
	var remaining := distance
	var travelled := 0.0
	while _cursor < _route.size():
		var destination: Dictionary = _route[_cursor]
		var position: Vector3 = destination["position"]
		var length := _point.position.distance_to(position)
		if length <= WorldGeometry.EPS:
			_point = ExpeditionWorldPoint.create(destination["stage_id"],destination["surface_id"],position)
			_cursor += 1
			continue
		if remaining <= 0.0: break
		var step := minf(remaining,length)
		var next := _point.position.move_toward(position,step)
		var support := geometry.support_at(_point.surface_id,Vector2(next.x,next.z),geometry.geometry_revision)
		if not support["ok"]: return support
		next = support["data"].get("point", {})["position"]
		var contact := geometry.sweep(_point.position,next,_profile,geometry.geometry_revision)
		if not contact["ok"] or contact["data"]["hit"]: return _failure(&"movement_blocked")
		_point.position = next
		travelled += step
		remaining -= step
		if step >= length: _cursor += 1
	var registered := geometry.set_occupant(_occupant_id,_point,_profile,geometry.geometry_revision)
	if not registered["ok"]: return registered
	return {"ok":true,"error_code":&"","geometry_revision":geometry.geometry_revision,"data":{"point":_point.to_data(),"travelled":travelled,"arrived":_cursor>=_route.size()}}
func teleport(destination: ExpeditionWorldPoint, maximum_range: float, revision: int) -> Dictionary:
	if geometry == null: return {"ok":false,"error_code":&"invalid_geometry"}
	if not is_current_world(): return _failure(&"world_reconfigured")
	var check := geometry.query_attack({"geometry_rule_id":&"teleport_legal","range":maximum_range,"traversal":_profile},_point,destination,revision)
	if not check["ok"]: return check
	if not check["data"]["hit"]: return _failure(&"illegal_teleport")
	_point = ExpeditionWorldPoint.create(destination.stage_id,destination.surface_id,destination.position)
	_route.clear()
	return geometry.set_occupant(_occupant_id,_point,_profile,revision)
func _failure(code: StringName) -> Dictionary:
	return {"ok":false,"error_code":code,"geometry_revision":geometry.geometry_revision if geometry != null else 0,"data":{}}

func release() -> void:
	if is_current_world() and not _occupant_id.is_empty(): geometry.remove_occupant(_occupant_id)
	geometry = null
	_route.clear()

func cancel() -> void:
	_route.clear()
	_cursor = 0
	_route_revision = geometry.geometry_revision if geometry != null else 0

func has_route() -> bool:
	return _cursor < _route.size()

func displace(destination: ExpeditionWorldPoint, maximum_distance: float, revision: int) -> Dictionary:
	if geometry == null: return {"ok":false,"error_code":&"invalid_geometry"}
	if not is_current_world(): return _failure(&"world_reconfigured")
	if not is_finite(maximum_distance) or maximum_distance <= 0.0: return _failure(&"invalid_distance")
	var route := geometry.path(_point,destination,_profile,revision)
	if not route["ok"]: return route
	var heading := Vector2(destination.position.x-_point.position.x,destination.position.z-_point.position.z)
	if heading.is_zero_approx(): return _failure(&"nonlinear_displacement")
	# Push may follow a ramp, but cannot acquire a detour around a wall.
	for item: Dictionary in route["data"]["points"]:
		var offset := Vector2(item["position"].x-_point.position.x,item["position"].z-_point.position.z)
		if absf(offset.cross(heading.normalized())) > WorldGeometry.EPS or offset.dot(heading) < -WorldGeometry.EPS: return _failure(&"nonlinear_displacement")
	var previous_route := _route.duplicate(true)
	var previous_cursor := _cursor
	var previous_revision := _route_revision
	_route = route["data"]["points"].duplicate(true)
	_cursor = 1
	_route_revision = revision
	var result := advance(minf(maximum_distance,float(route["data"]["cost"])))
	if not result["ok"]:
		_route = previous_route
		_cursor = previous_cursor
		_route_revision = previous_revision
		return result
	cancel()
	return result

func is_current_world() -> bool:
	return geometry != null and _configuration_revision == geometry.configuration_revision
