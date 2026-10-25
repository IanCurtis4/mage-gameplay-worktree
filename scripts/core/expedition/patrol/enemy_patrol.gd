@tool
extends RefCounted
## Passive definition and durable cursor. Movement always uses WorldActorMotion.
const Point = preload("res://scripts/core/expedition/model/world_point.gd")
const RETRY_SECONDS := 1.0
static func valid_definition(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() != 5 or not raw.has_all(["patrol_id","revision","mode","waypoints","slot_ids"]): return false
	if not raw.patrol_id is String or not IdentityIds.is_technical_id(raw.patrol_id) or not EquipmentRules.exact_integer(raw.revision,1,2147483647) or raw.mode not in ["loop","ping_pong"]: return false
	if not raw.waypoints is Array or raw.waypoints.size() < 2 or raw.waypoints.size() > 32 or not raw.slot_ids is Array or raw.slot_ids.is_empty() or raw.slot_ids.size() > 128: return false
	var ids: Dictionary = {}
	for id: Variant in raw.slot_ids:
		if not id is String or not IdentityIds.is_technical_id(id) or ids.has(id): return false
		ids[id] = true
	ids.clear()
	for waypoint: Variant in raw.waypoints:
		if not waypoint is Dictionary or waypoint.size() != 3 or not waypoint.has_all(["point_id","point","wait_seconds"]): return false
		if not waypoint.point_id is String or not IdentityIds.is_technical_id(waypoint.point_id) or ids.has(waypoint.point_id): return false
		ids[waypoint.point_id] = true
		if typeof(waypoint.wait_seconds) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(waypoint.wait_seconds) or waypoint.wait_seconds < 0 or waypoint.wait_seconds > 300: return false
		var p: Variant = waypoint.point
		if not p is Dictionary or p.size() != 3 or not p.has_all(["stage_id","surface_id","position"]) or not p.stage_id is String or p.stage_id.is_empty() or not p.surface_id is String or p.surface_id.is_empty() or not p.position is Vector3 or not p.position.is_finite(): return false
	return true
static func create(definition: Dictionary) -> Dictionary:
	return {"definition":definition.duplicate(true),"cursor":0,"direction":1,"waiting":false,"wait_remaining":0.0,"retry_remaining":0.0,"interrupted":false,"state":"travel","error":""}
static func valid(state: Dictionary) -> bool:
	if state.is_empty(): return true
	if state.size() != 9 or not state.has_all(["definition","cursor","direction","waiting","wait_remaining","retry_remaining","interrupted","state","error"]) or not valid_definition(state.definition): return false
	if not EquipmentRules.exact_integer(state.cursor,0,state.definition.waypoints.size()-1) or typeof(state.direction) != TYPE_INT or state.direction not in [-1,1]: return false
	if state.definition.mode == "loop" and state.direction != 1: return false
	if not state.waiting is bool or not state.interrupted is bool or state.state not in ["travel","wait","blocked","interrupted"] or not state.error is String: return false
	for key: String in ["wait_remaining","retry_remaining"]:
		if typeof(state[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(state[key]) or state[key] < 0: return false
	if state.wait_remaining > state.definition.waypoints[state.cursor].wait_seconds or state.retry_remaining > RETRY_SECONDS: return false
	if not state.waiting and state.wait_remaining != 0: return false
	return true
static func validate_route(definition: Dictionary, world: WorldGeometry, home: ExpeditionWorldPoint, profile: Dictionary, leash: float) -> Dictionary:
	if not valid_definition(definition) or world == null or home == null or not is_finite(leash) or leash <= 0: return failure("patrol_invalid")
	var points: Array[ExpeditionWorldPoint] = [home]
	for waypoint: Dictionary in definition.waypoints:
		var p := ExpeditionPopulationPlanner.point(waypoint.point)
		if p.stage_id != home.stage_id or p.position.distance_to(home.position) > leash or not world.position_query(p,profile,world.geometry_revision).ok: return failure("patrol_waypoint_invalid",waypoint.point_id)
		points.append(p)
	# Every direction is proven: return after interruption and ping-pong use reverse edges.
	var edges: Array = []
	for i: int in range(points.size()-1): edges.append([points[i],points[i+1]]); edges.append([points[i+1],points[i]])
	for p: ExpeditionWorldPoint in points.slice(1): edges.append([home,p]); edges.append([p,home])
	if definition.mode == "loop": edges.append([points[-1],points[1]])
	for edge: Array in edges:
		var route := world.path(edge[0],edge[1],profile,world.geometry_revision)
		if not route.ok: return failure("patrol_unreachable")
		for p: Dictionary in route.data.points:
			if p.position.distance_to(home.position) > leash: return failure("patrol_leash")
	return {"ok":true}
static func failure(code: String, point_id: String = "") -> Dictionary:
	return {"ok":false,"code":code,"point_id":point_id}
static func authored_world(world: WorldGeometry) -> WorldGeometry:
	# A temporary blocker may postpone travel, never invalidate an admitted birth.
	# Keep the canonical kernel and authored solids; only transient blockers/occupants
	# are absent from this validation view. The actor keeps the original live world.
	var result := WorldGeometry.new()
	result._stage = world._stage.duplicate(true); result._solid_slabs.assign(world._solid_slabs)
	result.geometry_revision = world.geometry_revision; result.configuration_revision = world.configuration_revision
	return result
static func interrupt(actor: EnemyActor) -> void:
	if actor.patrol.is_empty() or actor.patrol.interrupted: return
	actor.patrol.interrupted = true; actor.patrol.state = "interrupted"
	actor.world_motion.cancel()
static func tick(actor: EnemyActor, delta: float) -> void:
	var state := actor.patrol
	if state.is_empty() or not actor.is_alive() or actor.world_motion == null or not actor.world_motion.is_current_world(): return
	if actor.is_rooted() or actor.is_stunned() or actor.is_feared(): return
	if state.interrupted:
		state.interrupted = false; state.retry_remaining = 0.0; actor.world_motion.cancel()
	var waypoint: Dictionary = state.definition.waypoints[state.cursor]
	var destination := ExpeditionPopulationPlanner.point(waypoint.point)
	var current := actor.world_point()
	var arrived := current.surface_id == destination.surface_id and current.position.distance_to(destination.position) <= WorldGeometry.EPS
	if arrived:
		actor.world_motion.cancel(); state.error = ""; state.retry_remaining = 0.0; actor.world_ai_failure = &""
		if not state.waiting: state.waiting = true; state.wait_remaining = float(waypoint.wait_seconds)
		state.state = "wait"
		state.wait_remaining = maxf(0.0,state.wait_remaining-delta)
		if state.wait_remaining == 0.0:
			state.waiting = false; state.state = "travel"
			if state.definition.mode == "loop": state.cursor = (int(state.cursor)+1)%state.definition.waypoints.size()
			else:
				if int(state.cursor)+int(state.direction) >= state.definition.waypoints.size() or int(state.cursor)+int(state.direction) < 0: state.direction = -int(state.direction)
				state.cursor = int(state.cursor)+int(state.direction)
		return
	state.retry_remaining = maxf(0.0,state.retry_remaining-delta)
	if not actor.world_motion.has_route():
		if state.retry_remaining > 0.0: return
		state.retry_remaining = RETRY_SECONDS
		var planned := actor.world_motion.plan(destination,actor.world_motion.geometry.geometry_revision)
		if not planned.ok: _blocked(actor,String(planned.get("error_code","patrol_blocked"))); return
		# Dynamic detours must obey the same fixed leash as the authored route.
		for p: Dictionary in planned.data.points:
			if p.position.distance_to(actor._world_home.position) > actor._mob_definition.leash_radius: _blocked(actor,"patrol_leash"); return
	state.state = "travel"; state.error = ""; actor.world_ai_failure = &""
	var before := actor.world_point()
	var moved := actor.world_motion.advance(actor.stat_breakdown.value(&"move_speed")*actor.movement_speed_multiplier()*delta)
	if not moved.ok: _blocked(actor,String(moved.get("error_code","patrol_blocked"))); return
	var after := actor.world_point()
	if before.position != after.position: actor.world_ground_walked.emit(before,after)
static func _blocked(actor: EnemyActor, code: String) -> void:
	actor.world_motion.cancel(); actor.patrol.state = "blocked"; actor.patrol.error = code; actor.patrol.retry_remaining = RETRY_SECONDS; actor.world_ai_failure = StringName(code)
