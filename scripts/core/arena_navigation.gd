class_name ArenaNavigation
extends RefCounted
## Grid navigation over a walkable region with clearance-aware segments.

const CELL_SIZE := 32.0
const EDGE_EPSILON := 0.5

var _grid := AStar2D.new()
var _bounds := Rect2()
var _obstacles: Array[Rect2] = []
var _actor_radius := 18.0
var _columns := 0
var _rows := 0

func configure(bounds: Rect2, obstacles: Array[Rect2], actor_radius: float) -> void:
	_bounds = bounds
	_obstacles = obstacles.duplicate()
	_actor_radius = maxf(0.0, actor_radius)
	_columns = ceili(bounds.size.x / CELL_SIZE)
	_rows = ceili(bounds.size.y / CELL_SIZE)
	_grid.clear()
	for y: int in range(_rows):
		for x: int in range(_columns):
			var cell := Vector2i(x, y)
			var point := _cell_position(cell)
			if is_walkable(point):
				_grid.add_point(_cell_id(cell), point)
	for y: int in range(_rows):
		for x: int in range(_columns):
			var cell := Vector2i(x, y)
			var point_id := _cell_id(cell)
			if not _grid.has_point(point_id):
				continue
			for neighbor: Vector2i in [cell + Vector2i.LEFT, cell + Vector2i.UP, cell + Vector2i(-1, -1), cell + Vector2i(1, -1)]:
				var neighbor_id := _cell_id(neighbor)
				if _cell_in_bounds(neighbor) and _grid.has_point(neighbor_id) and is_segment_walkable(_cell_position(cell), _cell_position(neighbor)):
					_grid.connect_points(point_id, neighbor_id, true)

func get_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not is_walkable(from):
		return result
	var destination_is_walkable := is_walkable(to)
	var to_id := _nearest_walkable(_world_to_cell(to), to, destination_is_walkable)
	if to_id < 0:
		return result
	var resolved_destination := to if destination_is_walkable else _grid.get_point_position(to_id)
	if is_segment_walkable(from, resolved_destination):
		result.append(resolved_destination)
		return result
	var from_id := _nearest_walkable(_world_to_cell(from), from, true)
	if from_id < 0:
		return result
	var raw_path := _grid.get_point_path(from_id, to_id)
	var candidates := PackedVector2Array()
	for point: Vector2 in raw_path:
		if from.distance_squared_to(point) >= 0.01:
			candidates.append(point)
	if candidates.is_empty() or candidates[-1].distance_squared_to(resolved_destination) >= 0.01:
		candidates.append(resolved_destination)
	return _simplify_path(from, candidates)

func _simplify_path(from: Vector2, candidates: PackedVector2Array) -> PackedVector2Array:
	var simplified := PackedVector2Array()
	var current := from
	var next_index := 0
	while next_index < candidates.size():
		var farthest_visible := -1
		for candidate_index: int in range(candidates.size() - 1, next_index - 1, -1):
			if is_segment_walkable(current, candidates[candidate_index]):
				farthest_visible = candidate_index
				break
		if farthest_visible < 0:
			return PackedVector2Array()
		simplified.append(candidates[farthest_visible])
		current = candidates[farthest_visible]
		next_index = farthest_visible + 1
	return simplified

func is_walkable(point: Vector2) -> bool:
	return _is_point_clear(point, _actor_radius + EDGE_EPSILON)

func is_segment_walkable(from: Vector2, to: Vector2) -> bool:
	return is_segment_clear(from, to, _actor_radius)

func is_segment_clear(from: Vector2, to: Vector2, clearance: float) -> bool:
	var safe_clearance := maxf(0.0, clearance) + EDGE_EPSILON
	if not _is_point_clear(from, safe_clearance) or not _is_point_clear(to, safe_clearance):
		return false
	for obstacle: Rect2 in _obstacles:
		if _segment_intersects_rect(from, to, obstacle.grow(safe_clearance)):
			return false
	return true

func move_until_blocked(from: Vector2, to: Vector2) -> Vector2:
	if not is_walkable(from):
		return from
	if is_segment_walkable(from, to):
		return to
	var low := 0.0
	var high := 1.0
	for _iteration: int in range(20):
		var middle := (low + high) * 0.5
		var candidate := from.lerp(to, middle)
		if is_segment_walkable(from, candidate):
			low = middle
		else:
			high = middle
	return from.lerp(to, low)

func _is_point_clear(point: Vector2, clearance: float) -> bool:
	var inset := _bounds.grow(-clearance)
	if not inset.has_point(point):
		return false
	for obstacle: Rect2 in _obstacles:
		if obstacle.grow(clearance).has_point(point):
			return false
	return true

func _segment_intersects_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	if rect.has_point(from) or rect.has_point(to):
		return true
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_right := rect.end
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	return (
		Geometry2D.segment_intersects_segment(from, to, top_left, top_right) != null
		or Geometry2D.segment_intersects_segment(from, to, top_right, bottom_right) != null
		or Geometry2D.segment_intersects_segment(from, to, bottom_right, bottom_left) != null
		or Geometry2D.segment_intersects_segment(from, to, bottom_left, top_left) != null
	)

func _world_to_cell(point: Vector2) -> Vector2i:
	var local := point - _bounds.position
	return Vector2i(
		clampi(floori(local.x / CELL_SIZE), 0, _columns - 1),
		clampi(floori(local.y / CELL_SIZE), 0, _rows - 1)
	)

func _nearest_walkable(origin: Vector2i, visibility_origin: Vector2, require_visibility: bool) -> int:
	for radius: int in range(0, maxi(_columns, _rows)):
		for y: int in range(origin.y - radius, origin.y + radius + 1):
			for x: int in range(origin.x - radius, origin.x + radius + 1):
				if radius > 0 and x > origin.x - radius and x < origin.x + radius and y > origin.y - radius and y < origin.y + radius:
					continue
				var candidate := Vector2i(x, y)
				var candidate_id := _cell_id(candidate)
				if not _cell_in_bounds(candidate) or not _grid.has_point(candidate_id):
					continue
				if require_visibility and not is_segment_clear(visibility_origin, _cell_position(candidate), _actor_radius):
					continue
				return candidate_id
	return -1

func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _columns and cell.y < _rows

func _cell_id(cell: Vector2i) -> int:
	return cell.y * _columns + cell.x

func _cell_position(cell: Vector2i) -> Vector2:
	return _bounds.position + Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5
