class_name StageMinimapData
extends RefCounted
## Presentation-only copies. No geometry, visibility or navigation queries per tick.
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")

static func world_map(snapshot: Dictionary) -> Dictionary:
	var surfaces: Array[PackedVector2Array] = []
	var obstacles: Array[PackedVector2Array] = []
	for cell: Dictionary in snapshot.get("surfaces", []):
		var polygon := PackedVector2Array()
		for point: Vector3 in cell["vertices"]:
			polygon.append(ProjectionMath.project(point))
		if polygon.size() >= 3: surfaces.append(polygon)
	for volume: AABB in snapshot.get("volumes", []):
		var corners := PackedVector2Array()
		for x: float in [volume.position.x, volume.end.x]:
			for y: float in [volume.position.y, volume.end.y]:
				for z: float in [volume.position.z, volume.end.z]:
					corners.append(ProjectionMath.project(Vector3(x, y, z)))
		var polygon := Geometry2D.convex_hull(corners)
		if polygon.size() > 1 and polygon[0].is_equal_approx(polygon[-1]): polygon.resize(polygon.size() - 1)
		if polygon.size() >= 3: obstacles.append(polygon)
	return _map_data(surfaces, obstacles)

static func flat_map(bounds: Rect2, rectangles: Array[Rect2]) -> Dictionary:
	var surfaces: Array[PackedVector2Array] = [_rect_polygon(bounds)]
	var obstacles: Array[PackedVector2Array] = []
	for rectangle: Rect2 in rectangles: obstacles.append(_rect_polygon(rectangle))
	return _map_data(surfaces, obstacles)

static func _rect_polygon(rectangle: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)])

static func _map_data(surfaces: Array[PackedVector2Array], obstacles: Array[PackedVector2Array]) -> Dictionary:
	var bounds := Rect2()
	var first := true
	for polygons: Array[PackedVector2Array] in [surfaces, obstacles]:
		for polygon: PackedVector2Array in polygons:
			for point: Vector2 in polygon:
				if first:
					bounds = Rect2(point, Vector2.ZERO)
					first = false
				else: bounds = bounds.expand(point)
	return {"bounds": bounds, "surfaces": surfaces, "obstacles": obstacles}

static func actor_markers(player: CombatActor, enemies: Array[CombatActor]) -> Dictionary:
	if not is_instance_valid(player): return {"ok": false}
	var world := player.world_motion.geometry if player.world_motion != null else null
	if player.world_motion != null and not player.world_motion.is_current_world(): return {"ok": false}
	var anchor := player.world_point() if world != null else null
	var player_point := ProjectionMath.project(anchor.position) if anchor != null else player.global_position
	var points := PackedVector2Array()
	for enemy: CombatActor in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_alive(): continue
		if world != null:
			if enemy.world_motion == null or enemy.world_motion.geometry != world or not enemy.world_motion.is_current_world(): continue
			var enemy_anchor := enemy.world_point()
			if enemy_anchor.stage_id != anchor.stage_id: continue
			points.append(ProjectionMath.project(enemy_anchor.position))
		elif enemy.world_motion == null: points.append(enemy.global_position)
	var heading := player.character_animation.state.facing if player.character_animation != null else Vector2.RIGHT
	return {"ok": true, "player": player_point, "heading": heading, "enemies": points}
