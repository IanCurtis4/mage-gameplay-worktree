class_name StageMinimapData
extends RefCounted
## Presentation-only copies. No geometry, visibility or navigation queries per tick.
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")
const HeightGrid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const LOW_TERRAIN := Color("668b72")
const HIGH_TERRAIN := Color("c5d5a2")
const STEEP_TERRAIN := Color("b66b50")
const BLOCKED_TERRAIN := Color("303b42")

static func world_map(snapshot: Dictionary, body_height: float = 0.0) -> Dictionary:
	var surfaces: Array[PackedVector2Array] = []
	var obstacles: Array[PackedVector2Array] = []
	var triangles: Array = []
	var low := INF; var high := -INF
	var walkable := 0; var steep := 0; var blocked := 0
	for cell: Dictionary in snapshot.get("surfaces", []):
		var polygon := PackedVector2Array()
		for point: Vector3 in cell["vertices"]:
			polygon.append(ProjectionMath.project(point))
		if polygon.size() >= 3: surfaces.append(polygon)
		var clear: bool = float(cell.get("headroom",INF)) + WorldGeometry.EPS >= body_height
		if cell.has("height_grid"):
			var grid := HeightGrid.view(cell.height_grid)
			for t: int in int(grid.qx)*int(grid.qz)*2:
				var points := HeightGrid.triangle_vertices(grid,t)
				var supported := HeightGrid.triangle_walkable(grid,t)
				triangles.append({"points":points,"normal":HeightGrid.triangle_normal(grid,t),"kind":0 if clear and supported else (1 if not supported else 2)})
		else:
			for k: int in range(2,cell.vertices.size()):
				var points: Array = [cell.vertices[0],cell.vertices[k-1],cell.vertices[k]]
				var normal := Kernel.plane_normal(points)
				triangles.append({"points":points,"normal":normal if normal.y >= 0 else -normal,"kind":0 if clear else 2})
	var terrain_vertices := PackedVector2Array(); var terrain_colors := PackedColorArray()
	for triangle: Dictionary in triangles:
		triangle["height"] = _mean_height(triangle.points)
		for point: Vector3 in triangle.points: low = minf(low,point.y); high = maxf(high,point.y)
	# Upper surfaces paint after lower ones, matching the isometric view of decks.
	triangles.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.height) < float(b.height))
	for triangle: Dictionary in triangles:
		var kind: int = triangle.kind
		if kind == 0: walkable += 1
		elif kind == 1: steep += 1
		else: blocked += 1
		var shade := clampf(0.62+0.38*Vector3(triangle.normal).dot(Vector3(-0.4,1,-0.3).normalized()),0.45,1.0)
		for point: Vector3 in triangle.points:
			var height_color := LOW_TERRAIN.lerp(HIGH_TERRAIN,clampf((point.y-low)/maxf(1.0,high-low),0.0,1.0))
			var color: Color = (height_color if kind == 0 else (STEEP_TERRAIN if kind == 1 else BLOCKED_TERRAIN)) * Color(shade,shade,shade,1)
			terrain_vertices.append(ProjectionMath.project(point)); terrain_colors.append(color)
	obstacles = world_obstacles(snapshot.get("volumes", []))
	var result := _map_data(surfaces, obstacles)
	for point: Vector2 in terrain_vertices: result.bounds = result.bounds.expand(point)
	result["terrain"] = {"vertices":terrain_vertices,"colors":terrain_colors,"walkable":walkable,"steep":steep,"blocked":blocked}
	return result

static func world_obstacles(volumes: Array) -> Array[PackedVector2Array]:
	var obstacles: Array[PackedVector2Array] = []
	for volume: AABB in volumes:
		var corners := PackedVector2Array()
		for x: float in [volume.position.x, volume.end.x]:
			for y: float in [volume.position.y, volume.end.y]:
				for z: float in [volume.position.z, volume.end.z]:
					corners.append(ProjectionMath.project(Vector3(x, y, z)))
		var polygon := Geometry2D.convex_hull(corners)
		if polygon.size() > 1 and polygon[0].is_equal_approx(polygon[-1]): polygon.resize(polygon.size() - 1)
		if polygon.size() >= 3: obstacles.append(polygon)
	return obstacles

static func _mean_height(points: Array) -> float:
	return (Vector3(points[0]).y+Vector3(points[1]).y+Vector3(points[2]).y)/3.0

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
