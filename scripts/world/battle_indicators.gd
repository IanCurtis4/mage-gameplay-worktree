class_name BattleIndicators
extends Node2D

const IceWallScript = preload("res://scripts/world/ice_wall.gd")

const READY_COLOR := Color("81dfd0")
const BLOCKED_COLOR := Color("ff9a85")
const TARGET_COLOR := Color("f5cc77")

var skill: StringName = &""
var origin := Vector2.ZERO
var direction := Vector2.RIGHT
var endpoint := Vector2.ZERO
var body_radius := 20.0
var active_range := 0.0
var available := true
var click_position := Vector2.ZERO
var click_lifetime := 0.0
var click_is_target := false
var target_actor: CombatActor

func show_aim(skill_id: StringName, actor: PlayerActor, point: Vector2, can_cast: bool, selected_target: CombatActor = null) -> void:
	skill = skill_id
	origin = actor.global_position
	direction = actor.shield_facing if skill_id == &"shield_wall" and actor.has_shield_stance() else actor.aim_direction(point)
	target_actor = selected_target
	if skill == &"dash":
		endpoint = actor.dash_destination(direction)
	elif skill == &"teleport":
		endpoint = actor.teleport_destination(point)
	elif skill == &"extended_aim":
		endpoint = origin
	elif skill == &"arrow_rain":
		endpoint = actor.arrow_rain_center(point)
	elif skill == &"snare_trap":
		endpoint = actor.snare_trap_center(point)
	elif skill == &"explosive_trap":
		endpoint = actor.explosive_trap_center(point)
	elif skill == &"foliage_shelter":
		endpoint = actor.foliage_shelter_center(point)
	elif selected_target != null:
		endpoint = selected_target.global_position
	else:
		endpoint = origin + direction * actor.skill_range(skill)
	body_radius = actor.collision_radius
	active_range = actor.skill_range(skill_id)
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
		var skill_range := origin.distance_to(endpoint)
		var outline := SkillGeometry.cone_outline(origin, direction, skill_range, PlayerActor.SLASH_HALF_ANGLE)
		# Drop the closing duplicate for triangulation.
		var fill := outline.slice(0, outline.size() - 1)
		draw_colored_polygon(fill, Color(color, 0.16))
		draw_polyline(outline, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
		draw_polyline(outline, color, 2.0, true)
		var inner := SkillGeometry.cone_outline(origin, direction, skill_range * 0.55, PlayerActor.SLASH_HALF_ANGLE)
		draw_polyline(inner.slice(1, inner.size() - 1), Color(color, 0.35), 1.0, true)
	elif skill == &"shield_wall":
		var center := origin + Vector2(0, -18)
		var angle := direction.angle()
		draw_arc(center, PlayerActor.SHIELD_RADIUS, angle - PlayerActor.SHIELD_HALF_ANGLE, angle + PlayerActor.SHIELD_HALF_ANGLE, 26, Color(color, 0.18), 12.0, true)
		draw_arc(center, PlayerActor.SHIELD_RADIUS, angle - PlayerActor.SHIELD_HALF_ANGLE, angle + PlayerActor.SHIELD_HALF_ANGLE, 26, color, 3.0, true)
	elif skill == &"dash":
		var side := direction.orthogonal() * body_radius
		var corridor := PackedVector2Array([origin + side, endpoint + side, endpoint - side, origin - side])
		if origin.distance_to(endpoint) > 0.1:
			draw_colored_polygon(corridor, Color(color, 0.13))
			draw_line(origin + side, endpoint + side, color, 2.0, true)
			draw_line(origin - side, endpoint - side, color, 2.0, true)
			draw_dashed_line(origin, endpoint, Color(color, 0.65), 1.5, 9.0, true, true)
		_draw_endpoint(endpoint, color)
		var full_endpoint := origin + direction * active_range
		if endpoint.distance_to(full_endpoint) > 1.0:
			draw_line(endpoint, full_endpoint, Color(BLOCKED_COLOR, 0.3), 1.0, true)
			draw_line(endpoint + side, endpoint - side, BLOCKED_COLOR, 4.0, true)
	elif skill == &"fireball":
		draw_dashed_line(origin, endpoint, color, 3.0, 12.0, true, true)
		_draw_endpoint(endpoint, color)
	elif skill == &"fire_wall":
		var center := endpoint
		var wall_axis := direction.orthogonal()
		draw_dashed_line(origin, center, Color(color, 0.55), 1.5, 9.0, true, true)
		for index: int in range(FireWall.PILLAR_COUNT):
			var pillar := center + wall_axis * ((float(index) - 1.5) * FireWall.PILLAR_SPACING)
			draw_circle(pillar, FireWall.PILLAR_RADIUS, Color(color, 0.13))
			draw_arc(pillar, FireWall.PILLAR_RADIUS, 0.0, TAU, 24, color, 2.0, true)
	elif skill == &"lightning_wall":
		var wall_axis := direction.orthogonal()
		var wall_start := endpoint - wall_axis * LightningWall.HALF_LENGTH
		var wall_end := endpoint + wall_axis * LightningWall.HALF_LENGTH
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		draw_line(wall_start, wall_end, Color(color, 0.15), LightningWall.HALF_WIDTH * 2.0, true)
		draw_line(wall_start, wall_end, color, 2.0, true)
	elif skill == &"phantom_barrier":
		var wall_axis := direction.orthogonal()
		var wall_start := endpoint - wall_axis * PhantomBarrier.HALF_LENGTH
		var wall_end := endpoint + wall_axis * PhantomBarrier.HALF_LENGTH
		var spirit_color := Color("c39bef") if available else BLOCKED_COLOR
		draw_dashed_line(origin, endpoint, Color(spirit_color, 0.55), 1.5, 9.0, true, true)
		draw_line(wall_start, wall_end, Color(spirit_color, 0.16), PhantomBarrier.HALF_WIDTH * 2.0, true)
		draw_line(wall_start, wall_end, spirit_color, 2.0, true)
	elif skill == &"ice_wall":
		var wall_axis := direction.orthogonal()
		var wall_start := endpoint - wall_axis * IceWallScript.HALF_LENGTH
		var wall_end := endpoint + wall_axis * IceWallScript.HALF_LENGTH
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		draw_line(wall_start, wall_end, Color(color, 0.17), IceWallScript.HALF_WIDTH * 2.0, true)
		draw_line(wall_start, wall_end, color, 2.0, true)
	elif skill == &"soul_impact":
		draw_dashed_line(origin, endpoint, Color(color, 0.65), 1.5, 9.0, true, true)
		for index: int in 3:
			draw_arc(endpoint + Vector2(0, -18), 13.0 + float(index) * 8.0, 0.0, TAU, 32, Color(color, 0.85 - float(index) * 0.2), 1.5, true)
	elif skill == &"provoke":
		draw_dashed_line(origin, endpoint, Color(color, 0.65), 2.0, 10.0, true, true)
		_draw_endpoint(endpoint, color)
		draw_arc(endpoint + Vector2(0, -18), body_radius + 10.0, 0.0, TAU, 28, Color("efb453") if available else BLOCKED_COLOR, 2.0, true)
	elif skill == &"haunt":
		var outline := SkillGeometry.cone_outline(origin, direction, active_range, PlayerActor.HAUNT_HALF_ANGLE)
		draw_colored_polygon(outline.slice(0, outline.size() - 1), Color(color, 0.16))
		draw_polyline(outline, color, 2.0, true)
		draw_arc(origin, active_range * 0.55, direction.angle() - PlayerActor.HAUNT_HALF_ANGLE, direction.angle() + PlayerActor.HAUNT_HALF_ANGLE, 22, Color(color, 0.5), 1.0, true)
	elif skill in [&"fire_spear", &"ice_spear", &"lightning", &"electric_discharge", &"slowing_arrow"]:
		draw_dashed_line(origin, endpoint, color, 2.0, 10.0, true, true)
		_draw_endpoint(endpoint, color)
	elif skill == &"double_shot":
		draw_dashed_line(origin, endpoint, color, 2.0, 10.0, true, true)
		draw_line(origin + direction.orthogonal() * 7.0, endpoint + direction.orthogonal() * 7.0, Color(color, 0.35), 1.0, true)
		draw_line(origin - direction.orthogonal() * 7.0, endpoint - direction.orthogonal() * 7.0, Color(color, 0.35), 1.0, true)
		_draw_endpoint(endpoint, color)
	elif skill == &"piercing_arrow":
		draw_line(origin, endpoint, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
		draw_line(origin, endpoint, color, 2.0, true)
		for ratio: float in [0.25, 0.50, 0.75]:
			var marker := origin.lerp(endpoint, ratio)
			draw_line(marker - direction.orthogonal() * 5.0, marker + direction.orthogonal() * 5.0, Color(color, 0.7), 1.5, true)
		_draw_endpoint(endpoint, color)
	elif skill == &"arrow_rain":
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		draw_circle(endpoint, ArrowRain.RADIUS, Color(color, 0.13))
		draw_arc(endpoint, ArrowRain.RADIUS, 0.0, TAU, 56, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
		draw_arc(endpoint, ArrowRain.RADIUS, 0.0, TAU, 56, color, 2.0, true)
	elif skill == &"extended_aim":
		draw_circle(origin, body_radius + 15.0, Color(color, 0.13))
		draw_arc(origin, body_radius + 15.0, 0.0, TAU, 40, color, 2.0, true)
	elif skill == &"snare_trap":
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		draw_circle(endpoint, SnareTrap.TRIGGER_RADIUS, Color(color, 0.13))
		draw_arc(endpoint, SnareTrap.TRIGGER_RADIUS, 0.0, TAU, 48, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
		draw_arc(endpoint, SnareTrap.TRIGGER_RADIUS, 0.0, TAU, 48, color, 2.0, true)
	elif skill == &"explosive_trap":
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		draw_circle(endpoint, ExplosiveTrap.BLAST_RADIUS, Color(color, 0.10))
		draw_arc(endpoint, ExplosiveTrap.BLAST_RADIUS, 0.0, TAU, 56, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
		draw_arc(endpoint, ExplosiveTrap.BLAST_RADIUS, 0.0, TAU, 56, color, 2.0, true)
		draw_arc(endpoint, ExplosiveTrap.TRIGGER_RADIUS, 0.0, TAU, 40, Color(color, 0.65), 1.5, true)
	elif skill == &"foliage_shelter":
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		draw_circle(endpoint, FoliageShelter.RADIUS, Color(color, 0.10))
		draw_arc(endpoint, FoliageShelter.RADIUS, 0.0, TAU, 56, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
		draw_arc(endpoint, FoliageShelter.RADIUS, 0.0, TAU, 56, color, 2.0, true)
	elif skill == &"teleport":
		draw_dashed_line(origin, endpoint, Color(color, 0.65), 2.0, 10.0, true, true)
		_draw_endpoint(endpoint, color)

func _draw_endpoint(point: Vector2, color: Color) -> void:
	draw_circle(point, body_radius, Color(color, 0.13))
	draw_arc(point, body_radius, 0.0, TAU, 48, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
	draw_arc(point, body_radius, 0.0, TAU, 48, color, 2.0, true)
	draw_line(point - Vector2(5, 0), point + Vector2(5, 0), color, 1.5, true)
	draw_line(point - Vector2(0, 5), point + Vector2(0, 5), color, 1.5, true)
