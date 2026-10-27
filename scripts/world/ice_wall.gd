class_name IceWall
extends Node2D
## Temporary solid segment shared by actor and projectile navigation.

const HALF_LENGTH := 105.0
const HALF_WIDTH := 10.0

var navigation: ArenaNavigation
var remaining := 0.0
var normal := Vector2.RIGHT
var axis := Vector2.DOWN
var _registered := false
var world: WorldGeometry
var _world_configuration := 0
var _world_id := ""

static func endpoints(origin: Vector2, facing: Vector2, placement_range: float) -> PackedVector2Array:
	var normal_direction := facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
	var center := origin + normal_direction * placement_range
	var wall_axis := normal_direction.orthogonal()
	return PackedVector2Array([center - wall_axis * HALF_LENGTH, center + wall_axis * HALF_LENGTH])

func configure(arena_navigation: ArenaNavigation, origin: Vector2, facing: Vector2, placement_range: float, duration: float, occupied_positions: Array[Vector2]) -> bool:
	if arena_navigation == null or duration <= 0.0:
		return false
	var points := endpoints(origin, facing, placement_range)
	if not arena_navigation.add_temporary_segment(get_instance_id(), points[0], points[1], HALF_WIDTH, occupied_positions):
		return false
	navigation = arena_navigation
	_registered = true
	normal = facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
	axis = normal.orthogonal()
	global_position = origin + normal * placement_range
	rotation = normal.angle()
	remaining = duration
	process_mode = Node.PROCESS_MODE_PAUSABLE
	return true

func configure_world(geometry: WorldGeometry, field: WorldGroundField, duration: float, id: String, revision: int) -> bool:
	if _registered or world != null or geometry == null or field == null or field.solid == null or field.geometry != geometry or not field.is_current() or not is_finite(duration) or duration <= 0: return false
	var result := geometry.insert_segment(id,field.solid,revision)
	if not result["ok"]: return false
	world = geometry; _world_configuration = geometry.configuration_revision; _world_id = id
	_registered = true; remaining = duration
	process_mode = Node.PROCESS_MODE_PAUSABLE
	return true

func _process(delta: float) -> void:
	if is_queued_for_deletion() or not is_finite(delta) or delta < 0: return
	if world != null and world.configuration_revision != _world_configuration: expire(); return
	if is_inside_tree() and get_tree().paused:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		expire()
	else:
		queue_redraw()

func expire() -> void:
	_unregister()
	if not is_queued_for_deletion():
		queue_free()

func _exit_tree() -> void:
	_unregister()

func _unregister() -> void:
	if not _registered:
		return
	_registered = false
	if world != null:
		if world.configuration_revision == _world_configuration: world.remove_obstacle(_world_id,world.geometry_revision)
	else: navigation.remove_temporary_segment(get_instance_id())

func _draw() -> void:
	if world != null: return # Shared WorldFieldView draws the committed world shape.
	var alpha := minf(1.0, remaining * 2.0)
	draw_line(Vector2(0, -HALF_LENGTH), Vector2(0, HALF_LENGTH), Color(0.19, 0.44, 0.59, 0.58 * alpha), HALF_WIDTH * 2.0, true)
	draw_line(Vector2(0, -HALF_LENGTH), Vector2(0, HALF_LENGTH), Color(0.66, 0.91, 1.0, 0.82 * alpha), 5.0, true)
	for index: int in 7:
		var y := -HALF_LENGTH + 16.0 + float(index) * 30.0
		draw_circle(Vector2(0, y), 7.0, Color(0.77, 0.96, 1.0, 0.66 * alpha))
