class_name ArenaNavigation
extends RefCounted
## Grid navigation over a walkable region with obstacles inflated by actor radius.

const CELL_SIZE := 32.0

var _grid := AStarGrid2D.new()
var _bounds := Rect2()
var _obstacles: Array[Rect2] = []
var _actor_radius := 18.0

func configure(bounds: Rect2, obstacles: Array[Rect2], actor_radius: float) -> void:
	_bounds = bounds
	_obstacles = obstacles.duplicate()
	_actor_radius = actor_radius
	_grid.region = Rect2i(0, 0, ceili(bounds.size.x / CELL_SIZE), ceili(bounds.size.y / CELL_SIZE))
	_grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	_grid.offset = bounds.position + Vector2.ONE * CELL_SIZE * 0.5
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for y: int in range(_grid.region.size.y):
		for x: int in range(_grid.region.size.x):
			var cell := Vector2i(x, y)
			var point := _grid.get_point_position(cell)
			_grid.set_point_solid(cell, not is_walkable(point))

func get_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var from_id := _nearest_walkable(_world_to_cell(from))
	var to_id := _nearest_walkable(_world_to_cell(to))
	if from_id.x < 0 or to_id.x < 0:
		return PackedVector2Array()
	var path := _grid.get_point_path(from_id, to_id)
	if not path.is_empty() and is_walkable(to):
		path.append(to)
	return path

func is_walkable(point: Vector2) -> bool:
	var inset := _bounds.grow(-_actor_radius)
	if not inset.has_point(point):
		return false
	for obstacle: Rect2 in _obstacles:
		if obstacle.grow(_actor_radius).has_point(point):
			return false
	return true

func move_until_blocked(from: Vector2, to: Vector2) -> Vector2:
	var distance := from.distance_to(to)
	if distance <= 0.0:
		return from
	var direction := from.direction_to(to)
	var result := from
	var steps := ceili(distance / 8.0)
	for step: int in range(1, steps + 1):
		var candidate := from + direction * minf(distance, float(step) * 8.0)
		if not is_walkable(candidate):
			break
		result = candidate
	return result

func _world_to_cell(point: Vector2) -> Vector2i:
	var local := point - _bounds.position
	return Vector2i(clampi(floori(local.x / CELL_SIZE), 0, _grid.region.size.x - 1), clampi(floori(local.y / CELL_SIZE), 0, _grid.region.size.y - 1))

func _nearest_walkable(origin: Vector2i) -> Vector2i:
	if _grid.is_in_boundsv(origin) and not _grid.is_point_solid(origin):
		return origin
	for radius: int in range(1, 8):
		for y: int in range(origin.y - radius, origin.y + radius + 1):
			for x: int in range(origin.x - radius, origin.x + radius + 1):
				var candidate := Vector2i(x, y)
				if _grid.is_in_boundsv(candidate) and not _grid.is_point_solid(candidate):
					return candidate
	return Vector2i(-1, -1)
