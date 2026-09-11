class_name RewardPickup
extends Node2D

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var lift := sin(_time * 3.0) * 5.0
	var center := Vector2(0, -22 + lift)
	draw_circle(Vector2.ZERO, 30.0, Color(0.85, 0.69, 0.28, 0.13))
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -17), center + Vector2(13, 0), center + Vector2(0, 17), center + Vector2(-13, 0)]), Color("e9c67b"))
	draw_polyline(PackedVector2Array([center + Vector2(0, -17), center + Vector2(13, 0), center + Vector2(0, 17), center + Vector2(-13, 0), center + Vector2(0, -17)]), Color("fff2bd"), 3.0)
