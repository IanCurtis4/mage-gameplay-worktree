class_name BattleIndicators
extends Node2D

const IceWallScript = preload("res://scripts/world/ice_wall.gd")
const SPIRITUALIST_SIGIL: Texture2D = preload("res://assets/art/vfx/spiritualist_curse_sigil.png")
const SPIRITUALIST_BURST: Texture2D = preload("res://assets/art/vfx/spiritualist_spectral_burst.png")
const SPIRITUALIST_WISP: Texture2D = preload("res://assets/art/vfx/spiritualist_soul_wisp.png")
const SPIRITUALIST_HALO: Texture2D = preload("res://assets/art/vfx/spiritualist_ritual_halo.png")
const SPIRITUALIST_HALO_RADIUS := 58.0
const SPIRITUALIST_MAX_EVENTS := 64

signal spiritualist_ground_changed

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
const ELEMENTALIST_PULSE_DURATION := 0.65
const ELEMENTALIST_ARC_LINK_DURATION := 0.40
const ELEMENTALIST_PRISM_DURATION := 0.45
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
# Each cosmetic queue has its own explicit cap of 64. Impact pulses stay
# isolated because combat consumers count them; links/prisms are presentation
# feedback only and must never change that count.
var elementalist_pulses: Array[Dictionary] = []
var elementalist_arc_links: Array[Dictionary] = []
var elementalist_prisms: Array[Dictionary] = []
var elementalist_ember_preview := PackedVector2Array()
var spiritualist_marks: Array[int] = []
var spiritualist_mark_remaining: Dictionary[int, float] = {}
var spiritualist_pending_remaining: Dictionary[int, float] = {}
var spiritualist_weakened: Dictionary[int, Dictionary] = {}
var spiritualist_veil_members: Array[int] = []
var spiritualist_events: Array[Dictionary] = []
var spiritualist_wisps: Array[Dictionary] = []
var spiritualist_return_wisps: Array[Dictionary] = []
var spiritualist_visual_clock := 0.0
var spiritualist_drain_caster_id := 0
var spiritualist_drain_target_id := 0
var spiritualist_veil_center := Vector2.INF
var spiritualist_veil_remaining := 0.0
var spiritualist_focus_caster_id := 0
var spiritualist_focus_remaining := 0.0

func sync_spiritualist_focus(caster_id: int, remaining: float) -> void:
	if spiritualist_focus_remaining > 0.0 and remaining <= 0.0 and spiritualist_focus_caster_id > 0:
		var consumed := spiritualist_events.any(func(event: Dictionary) -> bool: return event["kind"] == &"focus_consume")
		var previous_caster := instance_from_id(spiritualist_focus_caster_id) as CombatActor
		if not consumed and previous_caster != null and is_instance_valid(previous_caster):
			show_spiritualist_event(&"focus_expire", previous_caster.global_position + Vector2(0, -25), previous_caster)
	spiritualist_focus_caster_id = caster_id if remaining > 0.0 else 0
	spiritualist_focus_remaining = maxf(0.0, remaining)
	queue_redraw()

func sync_spiritualist_veil(center: Vector2, remaining: float) -> void:
	spiritualist_veil_center = center if center.is_finite() and remaining > 0.0 else Vector2.INF
	spiritualist_veil_remaining = maxf(0.0, remaining)
	queue_redraw()

func sync_spiritualist_veil_members(member_ids: Array) -> void:
	spiritualist_veil_members.assign(member_ids)
	queue_redraw()

func sync_spiritualist_drain(caster_id: int, target_id: int) -> void:
	spiritualist_drain_caster_id = caster_id
	spiritualist_drain_target_id = target_id
	queue_redraw()

func sync_spiritualist_marks(mark_ids: Array) -> void:
	spiritualist_marks.assign(mark_ids)
	spiritualist_mark_remaining.clear()
	spiritualist_ground_changed.emit()
	queue_redraw()

func sync_spiritualist_combat_state(marks: Dictionary, pending: Array[Dictionary], weakened: Dictionary[int, Dictionary]) -> void:
	spiritualist_marks.clear()
	spiritualist_mark_remaining.clear()
	for target_id: int in marks.keys():
		spiritualist_marks.append(target_id)
		spiritualist_mark_remaining[target_id] = maxf(0.0, float(marks[target_id].get("remaining", 0.0)))
	spiritualist_pending_remaining.clear()
	for echo: Dictionary in pending:
		var target_id := int(echo["target_id"])
		spiritualist_pending_remaining[target_id] = maxf(0.0, float(echo["remaining"]))
	spiritualist_weakened = weakened.duplicate(true)
	spiritualist_ground_changed.emit()
	queue_redraw()

func show_spiritualist_procession_wisp(source: Vector2, target_id: int) -> void:
	if not source.is_finite() or target_id <= 0:
		return
	if spiritualist_wisps.size() >= 16:
		spiritualist_wisps.pop_front()
	spiritualist_wisps.append({"source": source, "target_id": target_id, "remaining": 0.22, "duration": 0.22})
	queue_redraw()

func clear_spiritualist_procession_wisps() -> void:
	spiritualist_wisps.clear()
	queue_redraw()

func show_spiritualist_return_wisp(source: Vector2, caster_id: int, kind: StringName) -> void:
	if not source.is_finite() or caster_id <= 0 or kind not in [&"drain", &"recovery"]:
		return
	if spiritualist_return_wisps.size() >= 16:
		spiritualist_return_wisps.pop_front()
	var duration := 0.24 if kind == &"recovery" else 0.32
	spiritualist_return_wisps.append({"source": source, "caster_id": caster_id, "kind": kind, "remaining": duration, "duration": duration})
	queue_redraw()

func clear_spiritualist_drain_wisps() -> void:
	for index: int in range(spiritualist_return_wisps.size() - 1, -1, -1):
		if spiritualist_return_wisps[index]["kind"] == &"drain":
			spiritualist_return_wisps.remove_at(index)
	queue_redraw()

func show_spiritualist_event(kind: StringName, center: Vector2, actor: CombatActor = null) -> void:
	if kind not in [&"sigil", &"break", &"burst", &"echo_hit", &"echo_ready", &"echo_absorbed", &"expire", &"focus_grant", &"focus_consume", &"focus_expire", &"ritual", &"veil_apply", &"heal_receive", &"procession_hit"] or not center.is_finite():
		return
	if spiritualist_events.size() >= SPIRITUALIST_MAX_EVENTS:
		spiritualist_events.pop_front()
	var duration := 0.62 if kind == &"expire" else 0.45 if kind == &"echo_hit" else 0.40 if kind in [&"veil_apply", &"focus_expire"] else 0.32
	var event := {"kind": kind, "center": center, "remaining": duration, "duration": duration, "target_id": actor.get_instance_id() if actor != null and is_instance_valid(actor) else 0, "actor_scale": actor.sprite_visual_scale if actor != null and is_instance_valid(actor) else 1.0}
	spiritualist_events.append(event)
	queue_redraw()

func show_spiritualist_spread(source: Vector2, destination: Vector2) -> void:
	if not source.is_finite() or not destination.is_finite():
		return
	if spiritualist_events.size() >= SPIRITUALIST_MAX_EVENTS:
		spiritualist_events.pop_front()
	spiritualist_events.append({"kind": &"spread_link", "center": source, "destination": destination, "remaining": 0.32, "duration": 0.32})
	queue_redraw()

func clear_spiritualist_visuals() -> void:
	spiritualist_marks.clear()
	spiritualist_mark_remaining.clear()
	spiritualist_pending_remaining.clear()
	spiritualist_weakened.clear()
	spiritualist_veil_members.clear()
	spiritualist_events.clear()
	spiritualist_wisps.clear()
	spiritualist_return_wisps.clear()
	spiritualist_drain_caster_id = 0
	spiritualist_drain_target_id = 0
	spiritualist_veil_center = Vector2.INF
	spiritualist_veil_remaining = 0.0
	spiritualist_focus_caster_id = 0
	spiritualist_focus_remaining = 0.0
	spiritualist_ground_changed.emit()
	queue_redraw()

func show_aim(skill_id: StringName, actor: PlayerActor, point: Vector2, can_cast: bool, selected_target: CombatActor = null) -> void:
	skill = skill_id
	elementalist_ember_preview.clear()
	origin = actor.global_position
	direction = actor.shield_facing if skill_id == &"shield_wall" and actor.has_shield_stance() else actor.aim_direction(point)
	target_actor = selected_target
	if skill == &"sentinel_piercing_shot":
		endpoint = origin + direction * actor.skill_range(skill)
	elif skill == &"sentinel_net_shot":
		endpoint = actor.sentinel_net_center(point)
	elif skill == &"elementalist_flame_burst":
		endpoint = elemental_clamped_point(origin, point, actor.skill_range(skill))
	elif skill == &"spiritualist_spectral_veil":
		endpoint = actor.spiritualist_veil_center(point)
	elif skill == &"spiritualist_dissipation":
		endpoint = actor.spiritualist_dissipation_center(point)
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
	_append_elementalist_visual(elementalist_pulses, {"skill_id": skill_id, "center": center, "radius": radius, "element": element, "remaining": ELEMENTALIST_PULSE_DURATION})

# Cosmetic chain segment; callers may submit every resolved Arc jump without
# changing targeting, damage, or chain rules.
func show_elementalist_arc_link(from: Vector2, to: Vector2) -> void:
	if not from.is_finite() or not to.is_finite() or from.distance_squared_to(to) < 1.0:
		return
	_append_elementalist_visual(elementalist_arc_links, {"from": from, "to": to, "remaining": ELEMENTALIST_ARC_LINK_DURATION})

# Cosmetic passive acknowledgement. The prism is deliberately short and small
# so resource/sequence feedback never obscures actors or masquerades as damage.
func show_elementalist_prism(center: Vector2, passive_id: StringName) -> void:
	if not center.is_finite():
		return
	_append_elementalist_visual(elementalist_prisms, {"skill_id": passive_id, "center": center, "radius": 26.0, "remaining": ELEMENTALIST_PRISM_DURATION})

func _append_elementalist_visual(queue: Array[Dictionary], visual: Dictionary) -> void:
	if queue.size() >= ELEMENTALIST_MAX_PULSES:
		queue.pop_front()
	queue.append(visual)
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
	var had_spiritualist_visuals := not spiritualist_events.is_empty() or not spiritualist_wisps.is_empty() or not spiritualist_return_wisps.is_empty()
	spiritualist_visual_clock += delta
	for index: int in range(spiritualist_events.size() - 1, -1, -1):
		var event: Dictionary = spiritualist_events[index]
		event["remaining"] = maxf(0.0, float(event["remaining"]) - delta)
		if float(event["remaining"]) <= 0.0:
			spiritualist_events.remove_at(index)
		else:
			spiritualist_events[index] = event
	for index: int in range(spiritualist_wisps.size() - 1, -1, -1):
		var wisp: Dictionary = spiritualist_wisps[index]
		wisp["remaining"] = maxf(0.0, float(wisp["remaining"]) - delta)
		if float(wisp["remaining"]) <= 0.0:
			spiritualist_wisps.remove_at(index)
		else:
			spiritualist_wisps[index] = wisp
	for index: int in range(spiritualist_return_wisps.size() - 1, -1, -1):
		var return_wisp: Dictionary = spiritualist_return_wisps[index]
		return_wisp["remaining"] = maxf(0.0, float(return_wisp["remaining"]) - delta)
		if float(return_wisp["remaining"]) <= 0.0:
			spiritualist_return_wisps.remove_at(index)
		else:
			spiritualist_return_wisps[index] = return_wisp
	if had_spiritualist_visuals or not spiritualist_events.is_empty() or not spiritualist_wisps.is_empty() or not spiritualist_return_wisps.is_empty() or not spiritualist_marks.is_empty() or not spiritualist_pending_remaining.is_empty() or not spiritualist_weakened.is_empty() or spiritualist_drain_caster_id > 0 or spiritualist_veil_remaining > 0.0 or spiritualist_focus_remaining > 0.0:
		queue_redraw()
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
	var had_elementalist_visuals := not elementalist_pulses.is_empty() or not elementalist_arc_links.is_empty() or not elementalist_prisms.is_empty()
	_advance_elementalist_visual_queue(elementalist_pulses, delta)
	_advance_elementalist_visual_queue(elementalist_arc_links, delta)
	_advance_elementalist_visual_queue(elementalist_prisms, delta)
	if had_elementalist_visuals:
		queue_redraw()

func _advance_elementalist_visual_queue(queue: Array[Dictionary], delta: float) -> void:
	for index: int in range(queue.size() - 1, -1, -1):
		var visual: Dictionary = queue[index]
		visual["remaining"] = maxf(0.0, float(visual["remaining"]) - delta)
		if float(visual["remaining"]) <= 0.0:
			queue.remove_at(index)

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
	for link: Dictionary in elementalist_arc_links:
		_draw_elementalist_arc_link(link)
	for prism: Dictionary in elementalist_prisms:
		_draw_elementalist_prism(prism)
	_draw_spiritualist_visuals()
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
		_draw_flame_burst_preview(endpoint, SkillGeometry.ELEMENTALIST_FLAME_BURST_RADIUS, available)
	elif skill == &"spiritualist_spectral_veil":
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		draw_circle(endpoint, SpiritualistVeilState.RADIUS, Color(color, 0.08))
		draw_arc(endpoint, SpiritualistVeilState.RADIUS, 0.0, TAU, 64, color, 2.0, true)
	elif skill == &"spiritualist_dissipation":
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		draw_circle(endpoint, SkillGeometry.SPIRITUALIST_DISSIPATION_RADIUS, Color(color, 0.08))
		draw_arc(endpoint, SkillGeometry.SPIRITUALIST_DISSIPATION_RADIUS, 0.0, TAU, 64, color, 2.0, true)
	elif skill == &"elementalist_glacial_ring":
		_draw_glacial_ring_preview(origin, SkillGeometry.ELEMENTALIST_GLACIAL_RING_RADIUS, available)
	elif skill == &"elementalist_lightning_arc":
		draw_dashed_line(origin, endpoint, Color("f4d35e") if available else BLOCKED_COLOR, 2.0, 10.0, true, true)
		_draw_lightning_chain(endpoint, SkillGeometry.ELEMENTALIST_LIGHTNING_CHAIN_RANGE, Color("f4d35e") if available else BLOCKED_COLOR)
	elif skill == &"elementalist_ember_path":
		_draw_ember_path_preview(available)
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
	elif skill in [&"fire_spear", &"ice_spear", &"lightning", &"electric_discharge", &"slowing_arrow", &"sentinel_headshot", &"sentinel_observe"]:
		draw_dashed_line(origin, endpoint, color, 2.0, 10.0, true, true)
		_draw_endpoint(endpoint, color)
	elif skill == &"double_shot":
		draw_dashed_line(origin, endpoint, color, 2.0, 10.0, true, true)
		draw_line(origin + direction.orthogonal() * 7.0, endpoint + direction.orthogonal() * 7.0, Color(color, 0.35), 1.0, true)
		draw_line(origin - direction.orthogonal() * 7.0, endpoint - direction.orthogonal() * 7.0, Color(color, 0.35), 1.0, true)
		_draw_endpoint(endpoint, color)
	elif skill in [&"piercing_arrow", &"sentinel_piercing_shot"]:
		draw_line(origin, endpoint, Color(0.04, 0.09, 0.12, 0.9), 5.0, true)
		draw_line(origin, endpoint, color, 2.0, true)
		for ratio: float in [0.25, 0.50, 0.75]:
			var marker := origin.lerp(endpoint, ratio)
			draw_line(marker - direction.orthogonal() * 5.0, marker + direction.orthogonal() * 5.0, Color(color, 0.7), 1.5, true)
		_draw_endpoint(endpoint, color)
	elif skill == &"sentinel_net_shot":
		var radius := float(SentinelTuning.values(skill, 1)["radius"])
		draw_dashed_line(origin, endpoint, Color(color, 0.55), 1.5, 9.0, true, true)
		draw_arc(endpoint, radius, 0.0, TAU, 48, color, 2.0, true)
		for offset: float in [-0.5, 0.0, 0.5]:
			var half := sqrt(radius * radius * (1.0 - offset * offset))
			draw_line(endpoint + Vector2(-half, offset * radius), endpoint + Vector2(half, offset * radius), Color(color, 0.4), 1.0)
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

func _draw_flame_burst_preview(center: Vector2, radius: float, is_available: bool) -> void:
	var fire := Color("ef6a54") if is_available else BLOCKED_COLOR
	_draw_elementalist_circle(center, radius, fire)
	for index: int in range(8):
		var angle := TAU * float(index) / 8.0
		var inner := center + Vector2.from_angle(angle) * radius * 0.45
		var tip := center + Vector2.from_angle(angle + sin(float(index)) * 0.08) * radius * 0.88
		draw_line(inner, tip, Color("ffc35d", 0.78) if is_available else fire, 2.0, true)
	draw_arc(center, radius * 0.56, 0.0, TAU, 32, Color(fire, 0.55), 2.0, true)

func _draw_glacial_ring_preview(center: Vector2, radius: float, is_available: bool) -> void:
	var ice := Color("82cdf4") if is_available else BLOCKED_COLOR
	draw_arc(center, radius, 0.0, TAU, 56, Color(ice, 0.18), 8.0, true)
	draw_arc(center, radius, 0.0, TAU, 56, ice, 2.0, true)
	draw_arc(center, radius * 0.82, 0.0, TAU, 48, Color(ice, 0.42), 1.0, true)
	for index: int in range(12):
		var angle := TAU * float(index) / 12.0
		var root := center + Vector2.from_angle(angle) * radius * 0.86
		var tangent := Vector2.from_angle(angle).orthogonal() * 6.0
		var tip := center + Vector2.from_angle(angle) * (radius + 13.0)
		draw_colored_polygon(PackedVector2Array([root - tangent, tip, root + tangent]), Color(ice, 0.28))
		draw_polyline(PackedVector2Array([root - tangent, tip, root + tangent]), Color("d7f4ff", 0.75) if is_available else ice, 1.0, true)

func _draw_lightning_chain(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, Color(color, 0.06))
	draw_arc(center, radius, 0.0, TAU, 16, color, 2.0, true)
	for angle: float in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		_draw_jitter_bolt(center + Vector2.from_angle(angle) * 18.0, center + Vector2.from_angle(angle) * radius, 3.0, Color(color, 0.58), 1.3)

func _draw_ember_path_preview(is_available: bool) -> void:
	var fire := Color("ef6a54") if is_available else BLOCKED_COLOR
	var core := Color("ffc35d") if is_available else Color(BLOCKED_COLOR, 0.55)
	for index: int in range(elementalist_ember_preview.size()):
		var center := elementalist_ember_preview[index]
		var radius := SkillGeometry.ELEMENTALIST_EMBER_PATH_RADIUS
		var alpha := 0.10 + float(index) * 0.035
		draw_circle(center, radius, Color(fire, alpha))
		draw_arc(center, radius, 0.0, TAU, 32, fire, 1.8, true)
		for flame_index: int in range(5):
			var angle := TAU * float(flame_index) / 5.0
			draw_line(center + Vector2.from_angle(angle) * radius * 0.25, center + Vector2.from_angle(angle) * radius * 0.72, Color(core, 0.72), 1.7, true)

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
	for index: int in range(3):
		var angle := -PI * 0.5 + TAU * float(index) / 3.0
		var branch_center := center + Vector2.from_angle(angle) * radius * 0.55
		if index == 0:
			draw_arc(branch_center, 16.0, 0.0, TAU, 18, Color(colors[index], 0.8), 2.0, true)
		elif index == 1:
			_draw_crystal(branch_center, 16.0, colors[index], 0.8)
		else:
			_draw_jitter_bolt(center, branch_center, 3.0, Color(colors[index], 0.85), 1.8)

func _draw_elementalist_pulse(pulse: Dictionary) -> void:
	var center: Vector2 = pulse["center"]
	var maximum_radius: float = pulse["radius"]
	var element: StringName = pulse["element"]
	var progress := 1.0 - float(pulse["remaining"]) / ELEMENTALIST_PULSE_DURATION
	var radius := lerpf(maximum_radius * 0.32, maximum_radius, progress)
	var alpha := _elementalist_visual_alpha(pulse)
	if element == &"fire":
		_draw_fire_pulse(center, radius, alpha, progress, pulse["skill_id"] == &"elementalist_ember_path")
	elif element == &"ice":
		_draw_ice_pulse(center, radius, alpha, progress)
	else:
		_draw_lightning_pulse(center, radius, alpha, progress)

func _elementalist_visual_alpha(visual: Dictionary) -> float:
	var duration: float = ELEMENTALIST_PULSE_DURATION
	if visual.has("from"):
		duration = ELEMENTALIST_ARC_LINK_DURATION
	elif visual.get("skill_id", &"") in [&"elementalist_prismatic_focus", &"elementalist_prismatic_resonance"]:
		duration = ELEMENTALIST_PRISM_DURATION
	# Hold a bright readable body, then fade the tail. No wall-clock or combat RNG.
	var remaining_ratio := clampf(float(visual["remaining"]) / duration, 0.0, 1.0)
	return minf(1.0, remaining_ratio / 0.42) * 0.94

func _draw_fire_pulse(center: Vector2, radius: float, alpha: float, progress: float, trail: bool) -> void:
	var flicker := 0.82 + 0.18 * sin(progress * TAU * 3.0)
	draw_circle(center + Vector2(0, -radius * 0.10), radius * 0.32, Color("ef6a54", alpha * 0.16))
	draw_set_transform(center, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, radius * 0.82, Color("da4525", alpha * 0.2))
	draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 40, Color("ffae48", alpha * 0.8), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	var count := 5 if trail else 11
	for index: int in range(count):
		var angle := TAU * float(index) / float(count - 1)
		var normalized := (float(index) - 2.0) / 2.0 if trail else cos(angle)
		var base := center + Vector2(normalized * radius * (0.52 if trail else 0.76), radius * 0.15 if trail else sin(angle) * radius * 0.42)
		if not trail and index == count - 1:
			base = center
		var height := radius * (0.54 + 0.27 * sin(progress * TAU * 2.0 + float(index) * 1.7)) * flicker
		var width := radius * (0.13 + 0.035 * float(abs(index - 2)))
		var tip := base + Vector2(normalized * radius * 0.16, -height)
		var outer := PackedVector2Array([base + Vector2(-width, 0), base + Vector2(-width * 0.8, -height * 0.38), base + Vector2(-width * 0.28, -height * 0.24), tip, base + Vector2(width * 0.4, -height * 0.3), base + Vector2(width, -height * 0.48), base + Vector2(width, 0)])
		draw_colored_polygon(outer, Color("f4772d", alpha))
		var core_tip := base.lerp(tip, 0.78)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-width * 0.5, 0), core_tip, base + Vector2(width * 0.5, 0)]), Color("ffd66a", alpha))
	for ember_index: int in range(8):
		var rise := fmod(progress * 1.6 + float(ember_index) * 0.19, 1.0)
		var x := sin(float(ember_index) * 4.9 + progress * TAU) * radius * 0.52
		var ember := center + Vector2(x, -radius * (0.20 + rise * 0.95))
		draw_circle(ember, 1.5 + fmod(float(ember_index), 2.0), Color("ffc35d", alpha * (1.0 - rise)))

func _draw_ice_pulse(center: Vector2, radius: float, alpha: float, progress: float) -> void:
	var growth := sin(progress * PI)
	draw_arc(center, radius * 0.48 * growth, 0.0, TAU, 40, Color("82cdf4", alpha * 0.65), 1.6, true)
	for index: int in range(6):
		var angle := TAU * float(index) / 6.0
		var normalized := cos(angle)
		var base := center + Vector2(normalized * radius * 0.85, sin(angle) * radius * 0.48)
		var height := radius * (0.48 + 0.16 * fmod(float(index), 2.0)) * growth
		var half_width := radius * 0.11
		var tip := base + Vector2(normalized * radius * 0.10, -height)
		var left := base + Vector2(-half_width, 0)
		var right := base + Vector2(half_width, 0)
		draw_colored_polygon(PackedVector2Array([left, tip, base]), Color("4f9fc9", alpha * 0.85))
		draw_colored_polygon(PackedVector2Array([base, tip, right]), Color("bcecff", alpha * 0.95))
		draw_line(base, tip, Color("ffffff", alpha * 0.75), 1.0, true)
		draw_polyline(PackedVector2Array([left, tip, right]), Color("e7fbff", alpha), 1.5, true)
	for shard_index: int in range(5):
		var shard_progress := clampf((progress - 0.24) * 1.8, 0.0, 1.0)
		var shard := center + Vector2((float(shard_index) - 2.0) * radius * 0.23, -radius * (0.15 + shard_progress * 0.52))
		draw_line(shard, shard + Vector2(3.0, -7.0), Color("d7f4ff", alpha * (1.0 - shard_progress)), 1.2, true)

func _draw_lightning_pulse(center: Vector2, radius: float, alpha: float, progress: float) -> void:
	for index: int in range(5):
		var angle := TAU * float(index) / 5.0 + progress * 0.23
		_draw_jitter_bolt(center + Vector2.from_angle(angle) * radius * 0.12, center + Vector2.from_angle(angle) * radius, 4.0, Color("f4d35e", alpha), 2.3, progress + float(index) * 0.11)
	draw_arc(center, radius * 0.30, 0.0, TAU, 16, Color("fff0a0", alpha), 1.2, true)

func _draw_jitter_bolt(from: Vector2, to: Vector2, segments: float, color: Color, width: float, phase: float = 0.0) -> void:
	var offset := to - from
	var normal := offset.normalized().orthogonal()
	if offset.is_zero_approx():
		return
	var points := PackedVector2Array([from])
	var count: int = maxi(1, int(segments))
	for index: int in range(1, count):
		var ratio := float(index) / float(count)
		var wobble := sin(ratio * 19.0 + offset.length() * 0.071 + phase * 37.0) * minf(10.0, offset.length() * 0.10)
		points.append(from.lerp(to, ratio) + normal * wobble)
	points.append(to)
	draw_polyline(points, Color("fff4a8", color.a * 0.42), width + 2.0, true)
	draw_polyline(points, color, width, true)

func _draw_crystal(center: Vector2, radius: float, color: Color, alpha: float) -> void:
	var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.62, 0), center + Vector2(0, radius), center + Vector2(-radius * 0.62, 0), center + Vector2(0, -radius)])
	draw_colored_polygon(diamond.slice(0, 4), Color(color, alpha * 0.18))
	draw_polyline(diamond, Color("d7f4ff", alpha), 1.7, true)

func _draw_prism_pulse(pulse: Dictionary) -> void:
	var center: Vector2 = pulse["center"]
	var radius: float = float(pulse["radius"]) * (0.72 + 0.28 * (1.0 - float(pulse["remaining"]) / ELEMENTALIST_PULSE_DURATION))
	var color := Color("f4d35e") if pulse["skill_id"] == &"elementalist_prismatic_focus" else Color("c39bef")
	_draw_crystal(center, radius, color, _elementalist_visual_alpha(pulse))

func _draw_elementalist_arc_link(link: Dictionary) -> void:
	var progress := 1.0 - float(link["remaining"]) / ELEMENTALIST_ARC_LINK_DURATION
	var alpha := _elementalist_visual_alpha(link)
	var from: Vector2 = link["from"]
	var to: Vector2 = link["to"]
	_draw_jitter_bolt(from, to, 6.0, Color("f4d35e", alpha), 2.7, progress)
	var branch_origin := from.lerp(to, 0.52)
	var normal := (to - from).normalized().orthogonal()
	_draw_jitter_bolt(branch_origin, branch_origin + normal * 14.0, 2.0, Color("b9e9ff", alpha * 0.75), 1.2, progress + 0.27)

func _draw_elementalist_prism(prism: Dictionary) -> void:
	_draw_prism_pulse(prism)

func _draw_spiritualist_visuals() -> void:
	for wisp: Dictionary in spiritualist_wisps:
		var wisp_target := instance_from_id(int(wisp["target_id"])) as CombatActor
		if wisp_target == null or not is_instance_valid(wisp_target) or not wisp_target.is_alive():
			continue
		var source: Vector2 = wisp["source"]
		var destination := wisp_target.global_position + Vector2(0, -18)
		var progress := 1.0 - float(wisp["remaining"]) / float(wisp["duration"])
		var head := source.lerp(destination, progress) + Vector2(0, -15.0 * sin(progress * PI))
		var frame := mini(3, int(progress * 4.0))
		_draw_spiritualist_soul(head, 49.0, destination.x >= source.x, 0.96, frame, sin(progress * PI) * 0.12)
	for return_wisp: Dictionary in spiritualist_return_wisps:
		var return_caster := instance_from_id(int(return_wisp["caster_id"])) as CombatActor
		if return_caster == null or not is_instance_valid(return_caster) or not return_caster.is_alive():
			continue
		var source: Vector2 = return_wisp["source"]
		var destination := return_caster.global_position + Vector2(0, -24)
		var progress := 1.0 - float(return_wisp["remaining"]) / float(return_wisp["duration"])
		var head := source.lerp(destination, progress) + Vector2(0, -20.0 * sin(progress * PI))
		var frame := mini(3, int(progress * 4.0))
		var size := 40.0 if return_wisp["kind"] == &"recovery" else 47.0
		_draw_spiritualist_soul(head, size, destination.x >= source.x, 0.84, frame)
	if spiritualist_focus_remaining > 0.0 and spiritualist_focus_caster_id > 0:
		var focus_caster := instance_from_id(spiritualist_focus_caster_id) as CombatActor
		if focus_caster != null and is_instance_valid(focus_caster) and focus_caster.is_alive():
			var focus_side := -1.0 if focus_caster.character_animation != null and focus_caster.character_animation.state.flip_h else 1.0
			var focus_center := focus_caster.global_position + Vector2(focus_side * 32.0, -43.0 + sin(spiritualist_visual_clock * 3.0) * 5.0)
			_draw_spiritualist_soul(focus_center, 38.0, focus_side < 0.0, 0.94, int(spiritualist_visual_clock * 7.0) % 4)
			draw_arc(focus_center, 17.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(spiritualist_focus_remaining / 5.0, 0.0, 1.0), 24, Color("d9e6f2", 0.55), 1.5, true)
	if spiritualist_veil_remaining > 0.0 and spiritualist_veil_center.is_finite():
		var veil_frame := int(spiritualist_visual_clock * 6.0) % 4
		_draw_spiritualist_frame(SPIRITUALIST_HALO, veil_frame, spiritualist_veil_center, 135.0, 0.68, Vector2(48, 63))
		draw_circle(spiritualist_veil_center, SpiritualistVeilState.RADIUS, Color("b9cfda", 0.045))
		draw_arc(spiritualist_veil_center, SpiritualistVeilState.RADIUS, 0.0, TAU, 64, Color("cfe5e9", 0.65), 1.5, true)
		for index: int in range(3):
			var phase := spiritualist_visual_clock * 0.9 + TAU * float(index) / 3.0
			var ground := spiritualist_veil_center + Vector2(cos(phase) * 64.0, sin(phase) * 47.0)
			_draw_spiritualist_soul(ground, 34.0, cos(phase) >= 0.0, 0.50, veil_frame)
	if spiritualist_drain_caster_id > 0 and spiritualist_drain_target_id > 0:
		var caster := instance_from_id(spiritualist_drain_caster_id) as CombatActor
		var drain_target := instance_from_id(spiritualist_drain_target_id) as CombatActor
		if caster != null and is_instance_valid(caster) and caster.is_alive() and drain_target != null and is_instance_valid(drain_target) and drain_target.is_alive():
			var from := _spiritualist_torso(caster)
			var to := _spiritualist_torso(drain_target)
			var direction := (to - from).normalized()
			var normal := Vector2(-direction.y, direction.x)
			var strand := PackedVector2Array()
			for segment: int in range(13):
				var t := float(segment) / 12.0
				strand.append(from.lerp(to, t) + normal * sin(t * TAU * 1.5 + spiritualist_visual_clock * 7.0) * sin(t * PI) * 7.0)
			draw_polyline(strand, Color("8a779f", 0.58), 7.0, true)
			draw_polyline(strand, Color("e4edf6", 0.82), 2.0, true)
	for group: Dictionary in spiritualist_halo_groups():
		_draw_spiritualist_group_soul(group)
	for target_id: int in spiritualist_weakened.keys():
		var target := instance_from_id(target_id) as CombatActor
		if target == null or not is_instance_valid(target) or not target.is_alive():
			continue
		_draw_spiritualist_weaken_souls(target, spiritualist_veil_members.has(target_id), spiritualist_marks.has(target_id) or spiritualist_pending_remaining.has(target_id))
	for event: Dictionary in spiritualist_events:
		_draw_spiritualist_soul_event(event)

func _spiritualist_torso(actor: CombatActor) -> Vector2:
	return actor.global_position + Vector2(0, -26.0 * actor.sprite_visual_scale)

func _draw_spiritualist_soul(center: Vector2, size: float, face_right: bool, alpha: float, frame: int, angle: float = 0.0) -> void:
	var facing_scale := Vector2.ONE if face_right else Vector2(-1, 1)
	# The 96px cell has generous transparent gutters. Crop to the painted body so
	# the face remains legible at gameplay scale; the dark first pass is a contour.
	var source := Rect2(float(posmod(frame, 4) * 96 + 13), 8, 80, 72)
	draw_set_transform(center, angle, facing_scale)
	draw_texture_rect_region(SPIRITUALIST_WISP, Rect2(-size * 0.54, -size * 0.47, size * 1.08, size * 0.94), source, Color(0.29, 0.18, 0.40, clampf(alpha * 0.75, 0.0, 1.0)))
	draw_texture_rect_region(SPIRITUALIST_WISP, Rect2(-size * 0.5, -size * 0.43, size, size * 0.86), source, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO)

func spiritualist_halo_groups() -> Array[Dictionary]:
	# Cosmetic connected components only. Authoritative marks/pending decide who
	# receives a halo; proximity merely shares the elevated silhouette.
	var ids: Array[int] = spiritualist_marks.duplicate()
	for target_id: int in spiritualist_pending_remaining.keys():
		if not ids.has(target_id):
			ids.append(target_id)
	ids.sort()
	var actors: Array[CombatActor] = []
	for target_id: int in ids:
		var actor := instance_from_id(target_id) as CombatActor
		if actor != null and is_instance_valid(actor) and actor.is_alive():
			actors.append(actor)
	var visited: Array[bool] = []
	visited.resize(actors.size())
	var groups: Array[Dictionary] = []
	for start: int in range(actors.size()):
		if visited[start]:
			continue
		visited[start] = true
		var members: Array[CombatActor] = [actors[start]]
		var cursor := 0
		while cursor < members.size():
			var member := members[cursor]
			for candidate_index: int in range(actors.size()):
				if visited[candidate_index]:
					continue
				var candidate := actors[candidate_index]
				var reach_x := SPIRITUALIST_HALO_RADIUS * (sqrt(member.sprite_visual_scale) + sqrt(candidate.sprite_visual_scale))
				var reach_y := reach_x * 0.64
				var distance := member.global_position - candidate.global_position
				if pow(distance.x / reach_x, 2.0) + pow(distance.y / reach_y, 2.0) <= 1.0:
					visited[candidate_index] = true
					members.append(candidate)
			cursor += 1
		groups.append({"members": members})
	return groups

func _draw_spiritualist_group_soul(group: Dictionary) -> void:
	var members: Array[CombatActor] = group["members"]
	var sum_x := 0.0
	var top := INF
	var largest_scale := 1.0
	var has_pending := false
	for actor: CombatActor in members:
		sum_x += actor.global_position.x
		top = minf(top, actor.global_position.y - 70.0 * actor.sprite_visual_scale)
		largest_scale = maxf(largest_scale, actor.sprite_visual_scale)
		has_pending = has_pending or spiritualist_pending_remaining.has(actor.get_instance_id())
	var center := Vector2(sum_x / float(members.size()), top - 5.0 + sin(spiritualist_visual_clock * 2.4) * 5.0)
	var size := 48.0 * sqrt(largest_scale)
	var frame := int(spiritualist_visual_clock * (9.0 if has_pending else 5.0)) % 4
	_draw_spiritualist_soul(center, size, true, 0.88, frame, sin(spiritualist_visual_clock * 1.7) * 0.08)
	if has_pending:
		draw_arc(center, size * 0.61, -PI * 0.8, PI * 0.4, 28, Color("ffffff", 0.58), 1.5, true)

func _draw_spiritualist_weaken_souls(actor: CombatActor, from_veil: bool, with_mark: bool) -> void:
	var scale_factor := actor.sprite_visual_scale
	var center := actor.global_position + Vector2(0, -7.0 * scale_factor)
	var size := (18.0 if with_mark else 25.0) * sqrt(scale_factor)
	var frame := int(spiritualist_visual_clock * 4.0) % 4
	var phase := spiritualist_visual_clock * 1.25 + float(actor.get_instance_id() % 13)
	var pull := 6.0 + 5.0 * sin(phase)
	var position := center + Vector2(24.0 * scale_factor + pull, 5.0 + 4.0 * cos(phase))
	var alpha := 0.42 if with_mark else 0.62 if from_veil else 0.54
	_draw_spiritualist_soul(position, size, true, alpha, frame, 0.20)

func _draw_spiritualist_soul_event(event: Dictionary) -> void:
	var kind: StringName = event["kind"]
	var center: Vector2 = event["center"]
	var progress := 1.0 - float(event["remaining"]) / float(event["duration"])
	var actor_scale := sqrt(float(event.get("actor_scale", 1.0)))
	var frame := mini(3, int(progress * 4.0))
	match kind:
		&"spread_link":
			var destination: Vector2 = event["destination"]
			var head := center.lerp(destination, progress) + Vector2(0, -20.0 * sin(progress * PI))
			var tail := center.lerp(destination, maxf(0.0, progress - 0.17)) + Vector2(0, -20.0 * sin(maxf(0.0, progress - 0.17) * PI))
			draw_line(tail, head, Color("b9a9d4", 0.60 * (1.0 - progress)), 2.0, true)
			_draw_spiritualist_soul(head + Vector2(0, -20), 23.0, destination.x >= center.x, 0.74 * (1.0 - progress * 0.45), frame)
		&"echo_hit":
			var flash_center := center + Vector2(0, -12.0 * actor_scale)
			draw_circle(flash_center, lerpf(12.0, 27.0, progress) * actor_scale, Color("f5fbff", 0.16 * (1.0 - progress)))
			draw_arc(flash_center, lerpf(18.0, 48.0, progress) * actor_scale, 0.0, TAU, 32, Color("e4ecfa", 0.72 * (1.0 - progress)), 2.0, true)
			draw_arc(flash_center, lerpf(13.0, 38.0, progress) * actor_scale, -PI * 0.7, PI * 0.4, 24, Color("b9a9d4", 0.65 * (1.0 - progress)), 1.5, true)
		&"echo_absorbed":
			for side: int in [-1, 1]:
				var head := center + Vector2(float(side) * lerpf(44.0, 26.0, progress) * actor_scale, -16.0)
				_draw_spiritualist_soul(head, 34.0 * (1.0 - progress * 0.35), side < 0, 0.62 * (1.0 - progress), frame)
			draw_arc(center, 23.0, -PI * 0.8, PI * 0.8, 22, Color("abb8c9", 0.55 * (1.0 - progress)), 2.0, true)
		&"expire":
			for side: int in [-1, 1]:
				var head := center + Vector2(float(side) * (31.0 + progress * 25.0) * actor_scale, -progress * 65.0)
				_draw_spiritualist_soul(head, 37.0, side < 0, 0.72 * (1.0 - progress), frame)
		&"break":
			for side: int in [-1, 1]:
				var direction := Vector2(float(side), -0.45).normalized()
				var head := center + direction * lerpf(30.0, 140.0, progress) * actor_scale
				_draw_spiritualist_soul(head, 43.0, side > 0, 0.92 * (1.0 - progress * 0.85), frame)
			draw_arc(center, lerpf(12.0, 45.0, progress), 0, TAU, 32, Color("efdcf1", 0.60 * (1.0 - progress)), 2.0, true)
		&"veil_apply":
			var head := center + Vector2(0, lerpf(22.0, -10.0, progress))
			_draw_spiritualist_soul(head, 35.0, true, 0.84 * (1.0 - progress * 0.65), frame)
		&"heal_receive":
			_draw_spiritualist_soul(center + Vector2(0, -progress * 8.0), lerpf(34.0, 13.0, progress), false, 0.90 * (1.0 - progress), frame)
		&"procession_hit":
			var head := center + Vector2(lerpf(0.0, 25.0, progress), -12.0 - progress * 15.0)
			_draw_spiritualist_soul(head, 41.0, true, 0.88 * (1.0 - progress), frame)
		&"focus_grant", &"focus_consume", &"focus_expire":
			var size := lerpf(17.0, 38.0, progress) if kind == &"focus_grant" else lerpf(38.0, 12.0, progress)
			var alpha := 0.92 * (1.0 - progress) if kind == &"focus_expire" else 0.88
			_draw_spiritualist_soul(center + Vector2(lerpf(15.0, 0.0, progress), -10.0), size, false, alpha, frame)
		&"ritual":
			_draw_spiritualist_frame(SPIRITUALIST_HALO, frame, center, 112.0, 0.55 * (1.0 - progress), Vector2(48, 63))
		&"burst":
			_draw_spiritualist_frame(SPIRITUALIST_BURST, frame, center, 65.0, 0.55 * (1.0 - progress))
		_:
			pass # Persistent bound souls carry sigil/echo_ready; no duplicate flash.

func _draw_spiritualist_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.72, 0), center + Vector2(0, radius), center + Vector2(-radius * 0.72, 0)])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("6e7294", color.a), 1.0, true)

func spiritualist_frame_rect(anchor: Vector2, size: float, pivot: Vector2 = Vector2(48, 48)) -> Rect2:
	return Rect2(anchor - pivot * (size / 96.0), Vector2.ONE * size)

func _draw_spiritualist_frame(texture: Texture2D, frame: int, center: Vector2, size: float, alpha: float, pivot: Vector2 = Vector2(48, 48)) -> void:
	var source := Rect2(float(frame * 96), 0.0, 96.0, 96.0)
	var destination := spiritualist_frame_rect(center, size, pivot)
	draw_texture_rect_region(texture, destination, source, Color(1.0, 1.0, 1.0, alpha))
