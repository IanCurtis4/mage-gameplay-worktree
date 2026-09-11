class_name ArenaView
extends Node2D

var bounds := Rect2()
var obstacles: Array[Rect2] = []
var destination_marker := Vector2.ZERO
var marker_visible := false

func configure(arena_bounds: Rect2, arena_obstacles: Array[Rect2]) -> void:
	bounds = arena_bounds
	obstacles = arena_obstacles.duplicate()
	queue_redraw()

func set_destination(point: Vector2) -> void:
	destination_marker = point
	marker_visible = true
	queue_redraw()

func _draw() -> void:
	draw_rect(bounds.grow(36.0), Color("101827"), true)
	draw_rect(bounds, Color("203b43"), true)
	var tile_width := 96.0
	var tile_height := 48.0
	for y: float in range(int(bounds.position.y), int(bounds.end.y + tile_height), int(tile_height)):
		for x: float in range(int(bounds.position.x), int(bounds.end.x + tile_width), int(tile_width)):
			var center := Vector2(x + (tile_width * 0.5 if int(y / tile_height) % 2 else 0.0), y)
			var diamond := PackedVector2Array([center + Vector2(0, -tile_height * 0.5), center + Vector2(tile_width * 0.5, 0), center + Vector2(0, tile_height * 0.5), center + Vector2(-tile_width * 0.5, 0)])
			draw_polyline(diamond, Color(0.24, 0.42, 0.44, 0.35), 1.0)
	for obstacle: Rect2 in obstacles:
		var top := obstacle.position
		var face := PackedVector2Array([top, Vector2(obstacle.end.x, top.y), obstacle.end, Vector2(top.x, obstacle.end.y)])
		draw_colored_polygon(face, Color("314452"))
		draw_polyline(PackedVector2Array([face[0], face[1], face[2], face[3], face[0]]), Color("78909c"), 3.0)
		var cap_center := Vector2(obstacle.get_center().x, obstacle.position.y)
		draw_colored_polygon(PackedVector2Array([Vector2(obstacle.position.x, obstacle.position.y), cap_center + Vector2(0, -28), Vector2(obstacle.end.x, obstacle.position.y), cap_center + Vector2(0, 28)]), Color("49636d"))
	if marker_visible:
		draw_arc(destination_marker, 13.0, 0.0, TAU, 24, Color("8de0cf"), 3.0)
		draw_circle(destination_marker, 3.0, Color("e9c67b"))
