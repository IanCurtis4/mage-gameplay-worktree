class_name ActorDeathVisual
extends Node2D
## Noninteractive presentation copy; enemy removal and rewards are immediate.

var animation: CharacterAnimation
var _elapsed := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	_elapsed += delta
	animation.state.advance(delta, Vector2.ZERO)
	queue_redraw()
	if _elapsed >= 0.70:
		queue_free()

func _draw() -> void:
	var opacity := 1.0 - clampf((_elapsed - 0.40) / 0.30, 0.0, 1.0)
	animation.draw_on(self, Color(1, 1, 1, opacity))
