class_name BattleIndicators
extends Node2D

const READY_COLOR := Color("81dfd0")
const BLOCKED_COLOR := Color("ff9a85")
const TARGET_COLOR := Color("f5cc77")

var skill: StringName = &""
var origin := Vector2.ZERO
var direction := Vector2.RIGHT
var endpoint := Vector2.ZERO
var body_radius := 20.0
var available := true
var click_position := Vector2.ZERO
var click_lifetime := 0.0
var click_is_target := false

func show_aim(skill_id: StringName, actor: PlayerActor, point: Vector2, can_cast: bool) -> void:
	skill = skill_id
	origin = actor.global_position
	direction = actor.aim_direction(point)
	endpoint = actor.dash_destination(direction) if skill == &"dash" else origin + direction * PlayerActor.SLASH_RANGE
	body_radius = actor.collision_radius
	available = can_cast
	queue_redraw()

func clear_aim() -> void:
	skill = &""
	queue_redraw()

func show_click(point: Vector2, is_target: bool = false) -> void:
	click_position = point
	click_lifetime = 0.65
	click_is_target = is_target
	queue_redraw()

func _process(delta: float) -> void:
	if click_lifetime > 0.0:
		click_lifetime = maxf(0.0, click_lifetime - delta)
		queue_redraw()

func _draw() -> void:
	if click_lifetime > 0.0:
		var progress := 1.0 - click_lifetime / 0.65
		var color := TARGET_COLOR if click_is_target else READY_COLOR
		color.a = 1.0 - progress
		var radius := lerpf(11.0, 29.0, progress)
		draw_arc(click_position, radius, 0.0, TAU, 40, color, 2.0, true)
		draw_arc(click_position, radius + 5.0, 0.0, TAU, 40, Color(color, color.a * 0.35), 1.0, true)
		for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			draw_line(click_position + axis * (radius + 4), click_position + axis * (radius + 9), color, 2.0, true)
	if skill == &"":
		return
	var color := READY_COLOR if available else BLOCKED_COLOR
	draw_arc(origin, body_radius + 5.0, 0.0, TAU, 40, Color(color, 0.6), 1.5, true)
	if skill == &"slash":
		var outline := SkillGeometry.cone_outline(origin, direction, PlayerActor.SLASH_RANGE, PlayerActor.SLASH_HALF_ANGLE)
		# Drop the closing duplicate for triangulation.
		var fill := outline.slice(0, outline.size() - 1)
		draw_colored_polygon(fill, Color(color, 0.16))
		draw_polyline(outline, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
		draw_polyline(outline, color, 2.0, true)
		var inner := SkillGeometry.cone_outline(origin, direction, PlayerActor.SLASH_RANGE * 0.55, PlayerActor.SLASH_HALF_ANGLE)
		draw_polyline(inner.slice(1, inner.size() - 1), Color(color, 0.35), 1.0, true)
	elif skill == &"dash":
		var side := direction.orthogonal() * body_radius
		var corridor := PackedVector2Array([origin + side, endpoint + side, endpoint - side, origin - side])
		if origin.distance_to(endpoint) > 0.1:
			draw_colored_polygon(corridor, Color(color, 0.13))
			draw_line(origin + side, endpoint + side, color, 2.0, true)
			draw_line(origin - side, endpoint - side, color, 2.0, true)
			draw_dashed_line(origin, endpoint, Color(color, 0.65), 1.5, 9.0, true, true)
		_draw_endpoint(endpoint, color)
		var full_endpoint := origin + direction * PlayerActor.DASH_DISTANCE
		if endpoint.distance_to(full_endpoint) > 1.0:
			draw_line(endpoint, full_endpoint, Color(BLOCKED_COLOR, 0.3), 1.0, true)
			draw_line(endpoint + side, endpoint - side, BLOCKED_COLOR, 4.0, true)

func _draw_endpoint(point: Vector2, color: Color) -> void:
	draw_circle(point, body_radius, Color(color, 0.13))
	draw_arc(point, body_radius, 0.0, TAU, 48, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
	draw_arc(point, body_radius, 0.0, TAU, 48, color, 2.0, true)
	draw_line(point - Vector2(5, 0), point + Vector2(5, 0), color, 1.5, true)
	draw_line(point - Vector2(0, 5), point + Vector2(0, 5), color, 1.5, true)
