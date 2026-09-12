class_name ArenaObstacleView
extends Node2D
## Low stone platform pilot. Its ground footprint remains the navigation rectangle.

const STONE: Texture2D = preload("res://assets/art/pilot/stone.png")
const HEIGHT := 26.0
var footprint := Rect2()

func configure(rect: Rect2) -> void:
	position = Vector2(rect.position.x, rect.end.y)
	footprint = Rect2(Vector2(0, -rect.size.y), rect.size)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	queue_redraw()

func _draw() -> void:
	var top := Rect2(footprint.position - Vector2(0, HEIGHT), footprint.size)
	draw_rect(Rect2(-5, -10, footprint.size.x + 15, 22), Color(0.03, 0.05, 0.06, 0.25))
	draw_texture_rect(STONE, top, true, Color("b5c2bf"))
	var front := Rect2(0, -HEIGHT, footprint.size.x, HEIGHT)
	draw_texture_rect(STONE, front, true, Color("687770"))
	draw_rect(top, Color("697971"), false, 2.0)
	draw_line(Vector2(0, -HEIGHT), Vector2(footprint.size.x, -HEIGHT), Color("c2cbb0"), 2.0)
	draw_line(Vector2.ZERO, Vector2(footprint.size.x, 0), Color("36483f"), 3.0)
