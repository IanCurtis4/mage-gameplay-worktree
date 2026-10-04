class_name SentinelBurst
extends Node2D
## Bounded cosmetic pulse, never owns damage or control.

var skill_id: StringName
var radius := 90.0
var remaining := 0.45
const DURATION := 0.45

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 1

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var progress := 1.0 - remaining / DURATION
	if skill_id == &"sentinel_headshot":
		for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			draw_line(axis * 6.0, axis * lerpf(10.0, radius, progress), Color("e4f5e8", 1.0 - progress), 1.5)
		return
	if skill_id == &"sentinel_concussion_shot":
		draw_arc(Vector2.ZERO, lerpf(7.0, radius, progress), -PI * 0.8, PI * 0.8, 20, Color("eedb9f", 1.0 - progress), 2.0)
		return
	if skill_id == &"sentinel_piercing_shot":
		draw_line(Vector2(-7, -5), Vector2(7, 5), Color("a6e3ee", 1.0 - progress), 1.5)
		return
	var color := Color("bddfd1") if skill_id == &"sentinel_net_shot" else Color("ffbf69")
	color.a = 1.0 - progress
	draw_arc(Vector2.ZERO, radius * lerpf(0.25, 1.0, progress), 0.0, TAU, 48, color, 2.0, true)
	if skill_id == &"sentinel_net_shot":
		for offset: float in [-0.6, -0.3, 0.0, 0.3, 0.6]:
			var y := offset * radius
			var half := sqrt(radius * radius - y * y)
			draw_line(Vector2(-half, y), Vector2(half, y), Color(color, color.a * 0.55), 1.0)
			draw_line(Vector2(y, -half), Vector2(y, half), Color(color, color.a * 0.55), 1.0)
	else:
		for index: int in range(8):
			var facing := Vector2.from_angle(float(index) * TAU / 8.0)
			draw_line(facing * radius * progress * 0.6, facing * radius * progress, color, 2.0)
