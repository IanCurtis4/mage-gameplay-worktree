class_name HauntConeVisual
extends Node2D
## Short-lived presentation only; hit geometry is resolved at cast emission.

const DURATION := 0.28

var remaining := DURATION
var cone_range := 230.0
var half_angle := PlayerActor.HAUNT_HALF_ANGLE

func configure(origin: Vector2, direction: Vector2, radius: float, angle: float) -> void:
	global_position = origin
	rotation = direction.angle()
	cone_range = radius
	half_angle = angle
	remaining = DURATION
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var alpha := remaining / DURATION
	var outline := SkillGeometry.cone_outline(Vector2.ZERO, Vector2.RIGHT, cone_range, half_angle)
	draw_colored_polygon(outline.slice(0, outline.size() - 1), Color(0.48, 0.23, 0.68, 0.19 * alpha))
	draw_polyline(outline, Color(0.79, 0.58, 0.94, 0.80 * alpha), 2.5, true)
	for fraction: float in [0.35, 0.65, 0.90]:
		draw_arc(Vector2.ZERO, cone_range * fraction, -half_angle, half_angle, 22, Color(0.88, 0.72, 1.0, 0.42 * alpha), 1.5, true)
