class_name WorldActorMotion
extends RefCounted

signal traversed(segments: Array[Dictionary])
## Logical movement, independent of rendering. Surface transitions occur only in a current route.
var geometry: WorldGeometry
var _point: ExpeditionWorldPoint
var _profile: Dictionary = {}
var _route: Array = []
var _cursor := 0
var _route_revision := 0
var _occupant_id := ""
var _configuration_revision := 0
## Transient background request (checkpoint36); omitted from snapshots.
var _pending: WorldGeometry.PathRequest
var _pending_finished := Callable()
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
	_drop_pending()
	var result := geometry.path(_point,destination,_profile,revision)
	if not result["ok"]: return result
	_route = result["data"]["points"].duplicate(true)
	_cursor = 1
	_route_revision = revision
	return result
## Installs a route the caller already computed with geometry.path for this exact
## point and profile at `revision`, instead of searching the same route twice.
## A route computed in the background for an actor that kept walking is joined
## at the current point when that first segment passes the graph's local-edge
## test. Another revision, an empty route or a route that cannot be joined fall
## back to plan(), or fail when replan is false.
func adopt_route(result: Dictionary, destination: ExpeditionWorldPoint, revision: int, replan: bool = true) -> Dictionary:
	if not result.get("ok",false): return result
	if geometry == null or not is_current_world() or revision != geometry.geometry_revision: return plan(destination,revision) if replan else _failure(&"stale_geometry")
	_drop_pending()
	var points: Array = _joined(result["data"].get("points",[]),revision)
	if points.is_empty(): return plan(destination,revision) if replan else _failure(&"route_moved")
	_route = points.duplicate(true)
	_cursor = 1
	_route_revision = revision
	if points == result["data"].get("points",[]): return result
	var joined := result.duplicate(true); joined["data"]["points"] = points.duplicate(true)
	return joined
func _joined(points: Array, revision: int) -> Array:
	if points.is_empty() or _point == null: return []
	if Vector3(points[0]["position"]).distance_to(_point.position) <= WorldGeometry.EPS and points[0]["surface_id"] == _point.surface_id: return points
	for index: int in [1,0]:
		if index >= points.size() or points[index]["surface_id"] != _point.surface_id: continue
		if geometry.segment_walkable(_point.surface_id,_point.position,points[index]["position"],_profile,revision):
			return [_point.to_data()]+points.slice(index)
	return []
## With navigation_async off this is plan(). On, the graph search runs in the
## background; the actor keeps its current route until the answer arrives.
func plan_async(destination: ExpeditionWorldPoint, revision: int, priority: int = 0, finished: Callable = Callable()) -> Dictionary:
	if geometry == null: return {"ok":false,"error_code":&"invalid_geometry"}
	if not is_current_world(): return _failure(&"world_reconfigured")
	if not geometry.navigation_async: return plan(destination,revision)
	_drop_pending()
	var request := geometry.request_path(_point,destination,_profile,revision,self,priority)
	if request.done():
		return adopt_route(request.result,destination,revision,false) if request.result.get("ok",false) else request.result
	_pending = request; _pending_finished = finished
	return {"ok":false,"pending":true,"error_code":&"navigation_pending","geometry_revision":revision,"data":{}}
func plan_pending() -> bool:
	return _pending != null
func _navigation_delivered(request: WorldGeometry.PathRequest) -> void:
	if request != _pending: return
	var finished := _pending_finished
	_pending = null; _pending_finished = Callable()
	var result: Dictionary = adopt_route(request.result,request.to,request.revision,false) if request.result.get("ok",false) else request.result
	if finished.is_valid(): finished.call(result)
func _drop_pending() -> void:
	if _pending != null: _pending.cancel()
	_pending = null; _pending_finished = Callable()
func plan_ground_line(heading: Vector3, distance: float, revision: int) -> Dictionary:
	if not is_current_world(): return _failure(&"world_reconfigured")
	_drop_pending()
	var result := geometry.trace_ground(_point,heading,distance,_profile,revision)
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
	elif not result["data"]["segments"].is_empty(): traversed.emit(result["data"]["segments"].duplicate(true))
	return result
func _advance(distance: float) -> Dictionary:
	if geometry == null: return {"ok":false,"error_code":&"invalid_geometry"}
	if not is_current_world(): return _failure(&"world_reconfigured")
	if not is_finite(distance) or distance < 0.0: return _failure(&"invalid_distance")
	if _route_revision != geometry.geometry_revision: return _failure(&"stale_geometry")
	var remaining := distance
	var travelled := 0.0
	var segments: Array[Dictionary] = []
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
		var contact := geometry.ground_sweep(_point.surface_id,_point.position,next,_profile,geometry.geometry_revision)
		if not contact["ok"] or contact["data"]["hit"]: return _failure(&"movement_blocked")
		var segment_start := point()
		_point.position = next
		segments.append({"from":segment_start.to_data(),"to":point().to_data()})
		travelled += step
		remaining -= step
		if step >= length: _cursor += 1
	var registered := geometry.set_occupant(_occupant_id,_point,_profile,geometry.geometry_revision)
	if not registered["ok"]: return registered
	return {"ok":true,"error_code":&"","geometry_revision":geometry.geometry_revision,"data":{"point":_point.to_data(),"travelled":travelled,"segments":segments,"arrived":_cursor>=_route.size()}}
func teleport(destination: ExpeditionWorldPoint, maximum_range: float, revision: int) -> Dictionary:
	if geometry == null: return {"ok":false,"error_code":&"invalid_geometry"}
	if not is_current_world(): return _failure(&"world_reconfigured")
	var check := geometry.query_attack({"geometry_rule_id":&"teleport_legal","range":maximum_range,"traversal":_profile},_point,destination,revision)
	if not check["ok"]: return check
	if not check["data"]["hit"]: return _failure(&"illegal_teleport")
	var before := point()
	_point = ExpeditionWorldPoint.create(destination.stage_id,destination.surface_id,destination.position)
	_route.clear(); _drop_pending()
	var registered := geometry.set_occupant(_occupant_id,_point,_profile,revision)
	if registered["ok"]:
		var segments: Array[Dictionary] = [{"from":before.to_data(),"to":point().to_data(),"kind":&"teleport"}]
		traversed.emit(segments)
	return registered
func _failure(code: StringName) -> Dictionary:
	return {"ok":false,"error_code":code,"geometry_revision":geometry.geometry_revision if geometry != null else 0,"data":{}}

func release() -> void:
	if is_current_world() and not _occupant_id.is_empty(): geometry.remove_occupant(_occupant_id)
	_drop_pending()
	geometry = null
	_route.clear()

func cancel() -> void:
	_drop_pending()
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
