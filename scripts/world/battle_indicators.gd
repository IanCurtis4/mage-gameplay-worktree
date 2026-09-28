class_name BattleIndicators
extends Node2D

const IceWallScript = preload("res://scripts/world/ice_wall.gd")

const READY_COLOR := Color("81dfd0")
const BLOCKED_COLOR := Color("ff9a85")
const TARGET_COLOR := Color("f5cc77")

# Closed Defender geometry. These values are presentation-only; the combat
# resolver remains the authority for valid targets and navigation.
const DEFENDER_COUNTERSTROKE_RANGE := SkillGeometry.DEFENDER_COUNTERSTROKE_RANGE
const DEFENDER_COUNTERSTROKE_HALF_ANGLE := SkillGeometry.DEFENDER_COUNTERSTROKE_HALF_ANGLE
const DEFENDER_ANCHOR_RANGE := SkillGeometry.DEFENDER_ANCHOR_RANGE
const DEFENDER_ANCHOR_RADIUS := SkillGeometry.DEFENDER_ANCHOR_RADIUS
const DEFENDER_LINE_LOCK_LENGTH := SkillGeometry.DEFENDER_LINE_LOCK_LENGTH
const DEFENDER_LINE_LOCK_HALF_WIDTH := SkillGeometry.DEFENDER_LINE_LOCK_HALF_WIDTH
const DEFENDER_WALL_ADVANCE_MAX_DISTANCE := 130.0
const DEFENDER_REPRISAL_WAVE_RADIUS := SkillGeometry.DEFENDER_REPRISAL_WAVE_RADIUS
const ELEMENTALIST_PULSE_DURATION := 0.30
const ELEMENTALIST_MAX_PULSES := 64

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
var defender_anchor_position := Vector2.INF
var defender_anchor_remaining := 0.0
var defender_wave_position := Vector2.INF
var defender_wave_lifetime := 0.0
var elementalist_pulses: Array[Dictionary] = []
var elementalist_ember_preview := PackedVector2Array()

func show_aim(skill_id: StringName, actor: PlayerActor, point: Vector2, can_cast: bool, selected_target: CombatActor = null) -> void:
	skill = skill_id
	elementalist_ember_preview.clear()
	origin = actor.global_position
	direction = actor.shield_facing if skill_id == &"shield_wall" and actor.has_shield_stance() else actor.aim_direction(point)
	target_actor = selected_target
	if skill == &"elementalist_flame_burst":
		endpoint = elemental_clamped_point(origin, point, actor.skill_range(skill))
	elif skill in [&"elementalist_glacial_ring", &"elementalist_tri_nova"]:
		endpoint = origin
	elif skill == &"elementalist_lightning_arc":
		endpoint = selected_target.global_position if selected_target != null else elemental_clamped_point(origin, point, actor.skill_range(skill))
	elif skill == &"elementalist_ember_path":
		elementalist_ember_preview = PackedVector2Array(actor.elementalist_ember_centers(direction))
		endpoint = elementalist_ember_preview[-1] if not elementalist_ember_preview.is_empty() else origin
	elif skill == &"dash":
		endpoint = actor.dash_destination(direction)
	elif skill == &"berserker_wound_leap":
		endpoint = actor.berserker_wound_leap_destination(direction)
	elif skill == &"teleport":
		endpoint = actor.teleport_destination(point)
	elif skill in [&"extended_aim", &"perseverance", &"fury"]:
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

static func elemental_clamped_point(origin_value: Vector2, point: Vector2, maximum_range: float) -> Vector2:
	return origin_value + (point - origin_value).limit_length(maxf(0.0, maximum_range))

static func elementalist_ember_centers(origin_value: Vector2, direction_value: Vector2) -> PackedVector2Array:
	var normalized := direction_value.normalized()
	if normalized.is_zero_approx():
		normalized = Vector2.RIGHT
	var step := SkillGeometry.ELEMENTALIST_EMBER_PATH_STEP
	return PackedVector2Array([origin_value + normalized * step, origin_value + normalized * step * 2.0, origin_value + normalized * step * 3.0])

func show_elementalist_pulse(skill_id: StringName, center: Vector2, radius: float, element: StringName) -> void:
	if not center.is_finite() or not is_finite(radius) or radius <= 0.0:
		return
	if elementalist_pulses.size() >= ELEMENTALIST_MAX_PULSES:
		elementalist_pulses.pop_front()
	elementalist_pulses.append({"skill_id": skill_id, "center": center, "radius": radius, "element": element, "remaining": ELEMENTALIST_PULSE_DURATION})
	queue_redraw()

# Defender call-site contract for RunController. For wall advance, pass the
# endpoint already cleared by navigation and its current rank distance; this
# view deliberately does not perform a second navigation decision.
func show_defender_aim(skill_id: StringName, actor: PlayerActor, point: Vector2, can_cast: bool, wall_advance_destination: Vector2 = Vector2.INF, wall_advance_range: float = DEFENDER_WALL_ADVANCE_MAX_DISTANCE, active_anchor: Vector2 = Vector2.INF) -> void:
	show_aim(skill_id, actor, point, can_cast)
	if skill_id == &"defender_counterstroke":
		active_range = DEFENDER_COUNTERSTROKE_RANGE
		endpoint = origin + direction * active_range
	elif skill_id == &"defender_anchor":
		active_range = DEFENDER_ANCHOR_RANGE
		endpoint = defender_clamped_point(origin, point, active_range)
	elif skill_id == &"defender_line_lock":
		active_range = DEFENDER_LINE_LOCK_LENGTH
		endpoint = origin + direction * active_range
	elif skill_id == &"defender_wall_advance":
		active_range = clampf(wall_advance_range, 0.0, DEFENDER_WALL_ADVANCE_MAX_DISTANCE)
		endpoint = defender_wall_advance_endpoint(origin, direction, wall_advance_destination, active_range)
	elif skill_id == &"defender_reprisal_wave":
		active_range = DEFENDER_REPRISAL_WAVE_RADIUS
		endpoint = active_anchor if active_anchor.is_finite() else origin
	queue_redraw()

func show_defender_anchor(center: Vector2, remaining: float) -> void:
	defender_anchor_position = center
	defender_anchor_remaining = maxf(0.0, remaining)
	queue_redraw()

func clear_defender_anchor() -> void:
	defender_anchor_position = Vector2.INF
	defender_anchor_remaining = 0.0
	queue_redraw()

func show_defender_reprisal_wave(center: Vector2) -> void:
	defender_wave_position = center
	defender_wave_lifetime = 0.32
	queue_redraw()

static func defender_clamped_point(origin_value: Vector2, point: Vector2, maximum_range: float) -> Vector2:
	var offset := point - origin_value
	return origin_value + offset.limit_length(maxf(0.0, maximum_range))

static func defender_wall_advance_endpoint(origin_value: Vector2, direction_value: Vector2, safe_destination: Vector2, maximum_distance: float) -> Vector2:
	var direction_normalized := direction_value.normalized()
	if direction_normalized.is_zero_approx():
		direction_normalized = Vector2.RIGHT
	var requested := origin_value + direction_normalized * maxf(0.0, maximum_distance)
	if not safe_destination.is_finite():
		return requested
	var safe_offset := safe_destination - origin_value
	# A supplied destination may only shorten the requested rank distance.
	if safe_offset.length() > maximum_distance or safe_offset.dot(direction_normalized) < 0.0:
		return requested
	return safe_destination

func clear_aim() -> void:
	skill = &""
	queue_redraw()

func show_click(point: Vector2, is_target: bool = false) -> void:
	click_position = point
	click_lifetime = 0.65
	click_is_target = is_target
	queue_redraw()

func _process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	if click_lifetime > 0.0:
		click_lifetime = maxf(0.0, click_lifetime - delta)
		queue_redraw()
	if defender_anchor_remaining > 0.0:
		defender_anchor_remaining = maxf(0.0, defender_anchor_remaining - delta)
		if defender_anchor_remaining <= 0.0:
			defender_anchor_position = Vector2.INF
		queue_redraw()
	if defender_wave_lifetime > 0.0:
		defender_wave_lifetime = maxf(0.0, defender_wave_lifetime - delta)
		queue_redraw()
	if not elementalist_pulses.is_empty():
		for index: int in range(elementalist_pulses.size() - 1, -1, -1):
			var pulse: Dictionary = elementalist_pulses[index]
			pulse["remaining"] = maxf(0.0, float(pulse["remaining"]) - delta)
			if float(pulse["remaining"]) <= 0.0:
				elementalist_pulses.remove_at(index)
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
	_draw_defender_anchor()
	_draw_defender_wave()
	for pulse: Dictionary in elementalist_pulses:
		_draw_elementalist_pulse(pulse)
	if skill == &"":
		return
	var color := READY_COLOR if available else BLOCKED_COLOR
	draw_arc(origin, body_radius + 5.0, 0.0, TAU, 40, Color(color, 0.6), 1.5, true)
	if skill == &"defender_counterstroke":
		_draw_defender_cone(color)
	elif skill == &"defender_anchor":
		draw_dashed_line(origin, endpoint, Color(color, 0.60), 1.5, 9.0, true, true)
		draw_circle(endpoint, DEFENDER_ANCHOR_RADIUS, Color(color, 0.11))
		draw_arc(endpoint, DEFENDER_ANCHOR_RADIUS, 0.0, TAU, 56, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
		draw_arc(endpoint, DEFENDER_ANCHOR_RADIUS, 0.0, TAU, 56, color, 2.0, true)
		draw_line(endpoint - Vector2(9, 0), endpoint + Vector2(9, 0), Color(color, 0.75), 1.5, true)
		draw_line(endpoint - Vector2(0, 9), endpoint + Vector2(0, 9), Color(color, 0.75), 1.5, true)
	elif skill == &"defender_line_lock":
		_draw_defender_strip(color)
	elif skill == &"berserker_blood_rift":
		_draw_strip(color, SkillGeometry.BERSERKER_RIFT_HALF_WIDTH)
	elif skill == &"defender_wall_advance":
		_draw_defender_wall_advance(color)
	elif skill == &"defender_reprisal_wave":
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		draw_circle(endpoint, DEFENDER_REPRISAL_WAVE_RADIUS, Color(color, 0.11))
		draw_arc(endpoint, DEFENDER_REPRISAL_WAVE_RADIUS, 0.0, TAU, 56, color, 2.0, true)
	elif skill == &"elementalist_flame_burst":
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		_draw_elementalist_circle(endpoint, SkillGeometry.ELEMENTALIST_FLAME_BURST_RADIUS, Color("ef6a54") if available else BLOCKED_COLOR)
	elif skill == &"elementalist_glacial_ring":
		_draw_elementalist_ring(origin, SkillGeometry.ELEMENTALIST_GLACIAL_RING_RADIUS, Color("82cdf4") if available else BLOCKED_COLOR)
	elif skill == &"elementalist_lightning_arc":
		draw_dashed_line(origin, endpoint, Color("f4d35e") if available else BLOCKED_COLOR, 2.0, 10.0, true, true)
		_draw_lightning_chain(endpoint, SkillGeometry.ELEMENTALIST_LIGHTNING_CHAIN_RANGE, Color("f4d35e") if available else BLOCKED_COLOR)
	elif skill == &"elementalist_ember_path":
		for center: Vector2 in elementalist_ember_preview:
			draw_circle(center, SkillGeometry.ELEMENTALIST_EMBER_PATH_RADIUS, Color("ef6a54", 0.09))
			draw_arc(center, SkillGeometry.ELEMENTALIST_EMBER_PATH_RADIUS, 0.0, TAU, 36, Color("ef6a54") if available else BLOCKED_COLOR, 1.8, true)
			draw_line(center - direction.orthogonal() * 8.0, center + direction.orthogonal() * 8.0, Color("f4d35e", 0.75), 1.0, true)
	elif skill == &"elementalist_tri_nova":
		_draw_tri_nova(origin, SkillGeometry.ELEMENTALIST_TRI_NOVA_RADIUS, available)
	elif skill == &"slash":
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
	elif skill in [&"dash", &"berserker_wound_leap"]:
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
	elif skill == &"brutal_strike":
		draw_line(origin, endpoint, color, 3.0, true)
		_draw_endpoint(endpoint, color)
	elif skill == &"concentrated_rage":
		var side := direction.orthogonal() * PlayerActor.CONCENTRATED_RAGE_HALF_WIDTH
		var corridor := PackedVector2Array([origin + side, endpoint + side, endpoint - side, origin - side])
		draw_colored_polygon(corridor, Color(color, 0.15))
		draw_polyline(PackedVector2Array([origin + side, endpoint + side, endpoint - side, origin - side, origin + side]), color, 2.0, true)
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
	elif skill == &"perseverance":
		draw_circle(origin + Vector2(0, -18), body_radius + 11.0, Color(color, 0.12))
		draw_arc(origin + Vector2(0, -18), body_radius + 11.0, 0.0, TAU, 40, color, 2.0, true)
	elif skill == &"fury":
		draw_circle(origin + Vector2(0, -18), body_radius + 14.0, Color(color, 0.12))
		draw_arc(origin + Vector2(0, -18), body_radius + 14.0, 0.0, TAU, 40, color, 2.0, true)
	elif skill == &"piercing_shout":
		draw_circle(origin, active_range, Color(color, 0.10))
		draw_arc(origin, active_range, 0.0, TAU, 48, color, 2.0, true)
	elif skill == &"terrifying_shout":
		draw_circle(origin, active_range, Color(color, 0.10))
		draw_arc(origin, active_range, 0.0, TAU, 48, color, 2.0, true)
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

func _draw_defender_cone(color: Color) -> void:
	var outline := SkillGeometry.cone_outline(origin, direction, DEFENDER_COUNTERSTROKE_RANGE, DEFENDER_COUNTERSTROKE_HALF_ANGLE)
	draw_colored_polygon(outline.slice(0, outline.size() - 1), Color(color, 0.16))
	draw_polyline(outline, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
	draw_polyline(outline, color, 2.0, true)
	draw_arc(origin, DEFENDER_COUNTERSTROKE_RANGE * 0.58, direction.angle() - DEFENDER_COUNTERSTROKE_HALF_ANGLE, direction.angle() + DEFENDER_COUNTERSTROKE_HALF_ANGLE, 18, Color(color, 0.42), 1.0, true)

func _draw_defender_strip(color: Color) -> void:
	_draw_strip(color, DEFENDER_LINE_LOCK_HALF_WIDTH)

func _draw_strip(color: Color, half_width: float) -> void:
	var side := direction.orthogonal() * half_width
	var outline := PackedVector2Array([origin + side, endpoint + side, endpoint - side, origin - side, origin + side])
	draw_colored_polygon(outline.slice(0, outline.size() - 1), Color(color, 0.15))
	draw_polyline(outline, color, 2.0, true)
	draw_dashed_line(origin, endpoint, Color(color, 0.58), 1.5, 9.0, true, true)

func _draw_defender_wall_advance(color: Color) -> void:
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

func _draw_defender_anchor() -> void:
	if not defender_anchor_position.is_finite() or defender_anchor_remaining <= 0.0:
		return
	var pulse := 0.55 + 0.15 * sin(defender_anchor_remaining * 5.0)
	var color := Color("7faeeb")
	draw_circle(defender_anchor_position, DEFENDER_ANCHOR_RADIUS, Color(color, 0.07))
	draw_arc(defender_anchor_position, DEFENDER_ANCHOR_RADIUS, 0.0, TAU, 56, Color(color, pulse), 2.0, true)
	draw_arc(defender_anchor_position, DEFENDER_ANCHOR_RADIUS * 0.42, 0.0, TAU, 40, Color(color, 0.32), 1.0, true)

func _draw_defender_wave() -> void:
	if not defender_wave_position.is_finite() or defender_wave_lifetime <= 0.0:
		return
	var progress := 1.0 - defender_wave_lifetime / 0.32
	var radius := lerpf(22.0, DEFENDER_REPRISAL_WAVE_RADIUS, progress)
	var color := Color("f5cc77", 1.0 - progress)
	draw_arc(defender_wave_position, radius, 0.0, TAU, 56, color, 3.0, true)
	draw_arc(defender_wave_position, maxf(0.0, radius - 10.0), 0.0, TAU, 48, Color(color, 0.34), 1.0, true)

func _draw_elementalist_circle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, Color(color, 0.10))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
	draw_arc(center, radius, 0.0, TAU, 48, color, 2.0, true)

func _draw_elementalist_ring(center: Vector2, radius: float, color: Color) -> void:
	draw_arc(center, radius, 0.0, TAU, 56, Color(color, 0.20), 7.0, true)
	draw_arc(center, radius, 0.0, TAU, 56, color, 2.0, true)
	draw_arc(center, radius * 0.82, 0.0, TAU, 48, Color(color, 0.35), 1.0, true)

func _draw_lightning_chain(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, Color(color, 0.06))
	draw_arc(center, radius, 0.0, TAU, 16, color, 2.0, true)
	for angle: float in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var point := center + Vector2.from_angle(angle) * radius
		draw_line(center + Vector2.from_angle(angle) * 18.0, point, Color(color, 0.45), 1.0, true)

func _draw_tri_nova(center: Vector2, radius: float, is_available: bool) -> void:
	var colors := [Color("ef6a54"), Color("82cdf4"), Color("f4d35e")] if is_available else [BLOCKED_COLOR, BLOCKED_COLOR, BLOCKED_COLOR]
	for index: int in range(3):
		var angle := -PI * 0.5 + TAU * float(index) / 3.0
		var point := center + Vector2.from_angle(angle) * radius
		var color: Color = colors[index]
		draw_line(center, point, Color(color, 0.35), 1.0, true)
		draw_arc(point, 12.0, 0.0, TAU, 16, color, 1.5, true)
	draw_arc(center, radius, 0.0, TAU, 56, Color(colors[0], 0.72), 2.0, true)
	draw_arc(center, radius * 0.67, 0.0, TAU, 48, Color(colors[1], 0.62), 1.5, true)
	draw_arc(center, radius * 0.34, 0.0, TAU, 32, Color(colors[2], 0.72), 1.0, true)

func _draw_elementalist_pulse(pulse: Dictionary) -> void:
	var center: Vector2 = pulse["center"]
	var maximum_radius: float = pulse["radius"]
	var element: StringName = pulse["element"]
	var progress := 1.0 - float(pulse["remaining"]) / ELEMENTALIST_PULSE_DURATION
	var radius := lerpf(maximum_radius * 0.32, maximum_radius, progress)
	var alpha := (1.0 - progress) * 0.78
	if element == &"fire":
		var flame := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.60, radius * 0.52), center + Vector2(0, radius * 0.28), center + Vector2(-radius * 0.60, radius * 0.52), center + Vector2(0, -radius)])
		draw_polyline(flame, Color("ef6a54", alpha), 2.5, true)
	elif element == &"ice":
		var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)])
		draw_polyline(diamond, Color("82cdf4", alpha), 2.5, true)
	else:
		var bolt := PackedVector2Array([center + Vector2(-radius, -radius * 0.18), center + Vector2(-radius * 0.18, -radius * 0.18), center + Vector2(-radius * 0.42, radius * 0.42), center + Vector2(radius, -radius * 0.18)])
		draw_polyline(bolt, Color("f4d35e", alpha), 3.0, true)
