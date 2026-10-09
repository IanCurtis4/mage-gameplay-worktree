class_name LightningWall
extends Node2D
## A traversable line: swept entry produces one hit, never a standing-area tick.

signal crossed(request: DamageRequest, target: CombatActor)

const HALF_LENGTH := 120.0
const HALF_WIDTH := 12.0
const DURATION := 5.0
const TARGET_INTERVAL := 0.9

var request: DamageRequest
var targets: Array[CombatActor] = []
var remaining := DURATION
var normal := Vector2.RIGHT
var axis := Vector2.DOWN
var _previous_positions: Dictionary[int, Vector2] = {}
var _inside: Dictionary[int, bool] = {}
var _cooldowns: Dictionary[int, float] = {}

func configure(caster: CombatActor, facing: Vector2, damage_request: DamageRequest, potential_targets: Array[CombatActor], placement_range: float) -> void:
	assert(caster != null and damage_request != null)
	assert(is_finite(placement_range) and placement_range >= 0.0)
	request = damage_request.copy()
	targets = potential_targets.duplicate()
	normal = facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
	axis = normal.orthogonal()
	global_position = caster.global_position + normal * placement_range
	rotation = normal.angle()
	remaining = DURATION
	for actor: CombatActor in targets:
		if actor != null and is_instance_valid(actor) and actor.is_alive():
			var actor_id := actor.get_instance_id()
			_previous_positions[actor_id] = actor.global_position
			_inside[actor_id] = _within_band(actor.global_position, actor.collision_radius)
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		queue_free()
		return
	for actor_id: int in _cooldowns.keys():
		_cooldowns[actor_id] = maxf(0.0, _cooldowns[actor_id] - delta)
	for actor: CombatActor in targets:
		if actor == null or not is_instance_valid(actor):
			continue
		var actor_id := actor.get_instance_id()
		if not actor.is_alive():
			_previous_positions.erase(actor_id)
			_inside.erase(actor_id)
			_cooldowns.erase(actor_id)
			continue
		var current := actor.global_position
		var previous: Vector2 = _previous_positions.get(actor_id, current)
		var inside_now := _within_band(current, actor.collision_radius)
		if not _inside.get(actor_id, inside_now) and current.distance_squared_to(previous) > 0.0001 and _swept_contact(previous, current, actor.collision_radius) and _cooldowns.get(actor_id, 0.0) <= 0.0:
			var impact := request.scheduled_tick()
			impact.target_id = actor_id
			crossed.emit(impact, actor)
			_cooldowns[actor_id] = TARGET_INTERVAL
		_inside[actor_id] = inside_now
		_previous_positions[actor_id] = current
	queue_redraw()

func _within_band(point: Vector2, radius: float) -> bool:
	var wall_start := global_position - axis * HALF_LENGTH
	var wall_end := global_position + axis * HALF_LENGTH
	var closest := Geometry2D.get_closest_point_to_segment(point, wall_start, wall_end)
	return point.distance_to(closest) <= radius + HALF_WIDTH

func _swept_contact(previous: Vector2, current: Vector2, radius: float) -> bool:
	var wall_start := global_position - axis * HALF_LENGTH
	var wall_end := global_position + axis * HALF_LENGTH
	if Geometry2D.segment_intersects_segment(previous, current, wall_start, wall_end) != null:
		return true
	var distance := minf(
		previous.distance_to(Geometry2D.get_closest_point_to_segment(previous, wall_start, wall_end)),
		current.distance_to(Geometry2D.get_closest_point_to_segment(current, wall_start, wall_end))
	)
	distance = minf(distance, wall_start.distance_to(Geometry2D.get_closest_point_to_segment(wall_start, previous, current)))
	distance = minf(distance, wall_end.distance_to(Geometry2D.get_closest_point_to_segment(wall_end, previous, current)))
	return distance <= radius + HALF_WIDTH

func _draw() -> void:
	var alpha := minf(1.0, remaining * 2.0)
	draw_rect(Rect2(-HALF_WIDTH, -HALF_LENGTH, HALF_WIDTH * 2.0, HALF_LENGTH * 2.0), Color(0.94, 0.80, 0.24, 0.10 * alpha))
	draw_line(Vector2(0, -HALF_LENGTH), Vector2(0, HALF_LENGTH), Color(1.0, 0.88, 0.38, 0.78 * alpha), 3.0, true)
	for index: int in 6:
		var y := -HALF_LENGTH + 20.0 + float(index) * 40.0
		draw_polyline(PackedVector2Array([Vector2(-8, y - 14), Vector2(4, y - 5), Vector2(-2, y + 3), Vector2(10, y + 14)]), Color(1.0, 0.94, 0.58, 0.9 * alpha), 2.0, true)
