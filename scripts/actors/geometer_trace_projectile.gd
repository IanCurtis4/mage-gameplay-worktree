class_name GeometerTraceProjectile
extends PlayerProjectile
## Explicit point/actor delivery. Never collides with an unselected actor.

signal delivered(ticket: int, success: bool, point: Vector2, victim: CombatActor)
signal delivered_world(ticket: int, success: bool, point: ExpeditionWorldPoint, victim: CombatActor)
var _world_ground: ExpeditionWorldPoint
var _world_goal_offset := Vector3.ZERO

var ticket := 0
var element: StringName = &"fire"
var ground_point := Vector2.ZERO
var remaining := 3.0
var _completed := false

func configure_trace(launch: Dictionary, command: GeometerCastCommand, origin: Vector2, arena_navigation: ArenaNavigation) -> void:
	configure_directional(launch["request"], origin, origin.direction_to(launch["point"]), [], arena_navigation, launch["speed"], launch["range"])
	ticket = launch["ticket"]
	element = command.element
	ground_point = launch["point"]
	target = launch["target"]
	homing = command.actor_id > 0
	rotation = 0.0

func configure_world_trace(launch: Dictionary, command: WorldGeometerCast) -> Dictionary:
	request = launch["request"]
	ticket = int(launch["ticket"])
	element = command.element
	target = launch["target"]
	homing = is_instance_valid(target)
	speed = float(launch["speed"])
	max_distance = float(launch["range"])
	_world_ground = WorldGeometerNavigation.copy_point(launch["point"])
	var plan: Dictionary = launch["flight"]
	_world_goal_offset = plan["goal_offset"]
	return bind_world_flight(command.construction.world,command.source(),plan["offset"],plan["direction"],plan["collider"],command.revision)

func _advance_world_trace(delta: float) -> void:
	remaining = maxf(0.0,remaining-delta)
	if remaining <= 0.0 or request == null:
		_finish_world(false,null); return
	if homing and (not is_instance_valid(target) or not target.is_alive() or target.world_motion == null or not target.world_motion.is_current_world() or target.world_motion.geometry != world_flight.geometry):
		_finish_world(false,null); return
	var point := target.world_point() if homing else _world_ground
	var goal := point.position+_world_goal_offset
	var delta_position := goal-world_flight.position
	if not delta_position.is_zero_approx(): world_flight.direction = delta_position.normalized()
	var actors: Array[CombatActor] = []
	if homing: actors.append(target)
	var step := minf(speed*delta,delta_position.length())
	var result := world_flight.contact(step,actors)
	if not result["ok"]:
		world_failure = result["error_code"]; _finish_world(false,null); return
	var data: Dictionary = result["data"]
	travelled = world_flight.travelled
	if data["actor"] != null: _finish_world(true,target.world_point(),target)
	elif data["terrain"]: _finish_world(false,null)
	elif not homing and world_flight.position.distance_to(goal) <= WorldGeometry.EPS: _finish_world(true,_world_ground)
	elif data["exhausted"]: _finish_world(false,null)

func _finish_world(success: bool, point: ExpeditionWorldPoint, victim: CombatActor = null) -> void:
	if _completed: return
	_completed = true
	delivered_world.emit(ticket,success,WorldGeometerNavigation.copy_point(point),victim)
	queue_free()

func _process(delta: float) -> void:
	if _completed or is_queued_for_deletion() or (is_inside_tree() and get_tree().paused) or not is_finite(delta) or delta <= 0.0:
		return
	if world_flight != null:
		_advance_world_trace(delta)
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0 or request == null:
		_finish(false, global_position)
		return
	if homing and (not is_instance_valid(target) or not target.is_alive()):
		_finish(false, global_position)
		return
	var goal := target.global_position if homing else ground_point
	var distance := global_position.distance_to(goal)
	direction = global_position.direction_to(goal)
	var step := minf(minf(speed * delta, max_distance - travelled), distance)
	var from := global_position
	var to := from + direction * step
	var wall_fraction := _wall_fraction(from, to)
	# Shared quadratic collision in ground space; visual body offset cancels.
	var victim_fraction := _actor_fraction(target, from + BODY_OFFSET, to + BODY_OFFSET) if homing else -1.0
	if homing and victim_fraction >= 0.0 and victim_fraction <= wall_fraction:
		global_position = from.lerp(to, victim_fraction)
		travelled += step * victim_fraction
		_finish(true, goal, target)
		return
	if wall_fraction <= 1.0:
		global_position = from.lerp(to, wall_fraction)
		travelled += step * wall_fraction
		_finish(false, global_position)
		return
	global_position = to
	travelled += step
	if not homing and global_position.distance_to(goal) <= 0.001:
		_finish(true, goal)
	elif travelled >= max_distance:
		_finish(false, global_position)
	queue_redraw()

func _finish(success: bool, point: Vector2, victim: CombatActor = null) -> void:
	if _completed:
		return
	_completed = true
	delivered.emit(ticket, success, point, victim)
	queue_free()

func _draw() -> void:
	if world_flight != null: return
	var tint := Color("ffac68") if element == &"fire" else (Color("a9e9ff") if element == &"ice" else Color("ebe29b"))
	draw_set_transform(BODY_OFFSET, direction.angle())
	draw_line(Vector2(-14, 0), Vector2(10, 0), tint, 2.0)
	if element == &"fire":
		draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(-4, -5), Vector2(0, 0), Vector2(-4, 5)]), tint)
	elif element == &"ice":
		draw_colored_polygon(PackedVector2Array([Vector2(13, 0), Vector2(5, -5), Vector2(0, 0), Vector2(5, 5)]), tint)
	else:
		draw_polyline(PackedVector2Array([Vector2(-12, -3), Vector2(-3, 3), Vector2(1, -3), Vector2(12, 0)]), tint, 2.0)
