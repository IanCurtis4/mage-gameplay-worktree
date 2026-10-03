class_name GeometerWallContactState
extends RefCounted
## Movement provenance is supplied by the adapter, never inferred from snapshots.

var construction_id := 0
var _actors: Dictionary[int, Dictionary] = {}
var _active_wall := false

func sync(identity: int, active_wall: bool) -> void:
	if identity != construction_id or not active_wall:
		_actors.clear()
	construction_id = identity
	_active_wall = active_wall and identity > 0

func prune(alive_ids: Array[int]) -> void:
	for actor_id: int in _actors.keys():
		if actor_id not in alive_ids:
			_actors.erase(actor_id)

func observe(actor_id: int, from: Vector2, to: Vector2, first: Vector2, second: Vector2, radius: float) -> Dictionary:
	if not _active_wall or actor_id <= 0 or not GeometerGeometry.valid_wall_motion(from, to, first, second, radius):
		return {}
	var normal := Vector2(-(second - first).y, (second - first).x).normalized()
	var before := (from - first).dot(normal)
	var after := (to - first).dot(normal)
	var before_side := int(signf(before)) if absf(before) > GeometerGeometry.CONTACT_EPSILON else 0
	var after_side := int(signf(after)) if absf(after) > GeometerGeometry.CONTACT_EPSILON else 0
	var width := GeometerGeometry.WALL_HALF_WIDTH + radius
	var tracking: Dictionary = _actors.get(actor_id, {"point": from, "side": 0})
	# Discontinuity or wall movement changing sides invalidates the old arm.
	if tracking["point"] != from or (before_side != 0 and int(tracking["side"]) != before_side):
		tracking["side"] = 0
	if from.distance_to(Geometry2D.get_closest_point_to_segment(from, first, second)) > width:
		tracking["side"] = before_side
	var crossing := GeometerGeometry.wall_crossing(from, to, first, second, radius)
	var armed_side := int(tracking["side"])
	var triggered := not crossing.is_empty() and armed_side != 0 and after_side != armed_side
	if triggered:
		tracking["side"] = 0
	# Leaving the band rearms a subsequent passage; jitter inside never rearms.
	if to.distance_to(Geometry2D.get_closest_point_to_segment(to, first, second)) > width:
		tracking["side"] = after_side
	tracking["point"] = to
	_actors[actor_id] = tracking
	if not triggered:
		return {}
	crossing["construction_id"] = construction_id
	crossing["actor_id"] = actor_id
	return crossing
