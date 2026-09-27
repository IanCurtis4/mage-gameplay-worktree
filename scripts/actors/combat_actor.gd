class_name CombatActor
extends Node2D
## Shared runtime presentation and health ownership for combat actors.

const MAX_SLOW_FRACTION := 0.50
const MAX_WEAKEN_FRACTION := 0.50

signal actor_died(actor: CombatActor)
signal damage_number(actor: CombatActor, amount: int, critical: bool)
signal attack_missed(actor: CombatActor)
signal status_damage_requested(request: DamageRequest, target: CombatActor)
signal presentation_action(action: StringName, direction: Vector2, duration: float)

var actor_name := "Ator"
var actor_color := Color.WHITE
var stat_breakdown: StatBreakdown
var health: HealthState
var collision_radius := 18.0
var is_hovered := false
var is_selected := false
var _flash_time := 0.0
var sprite_texture: Texture2D
var sprite_rect := Rect2()
var _sprite_visible_height := 0.0
var burn_remaining := 0.0
var burn_tick_remaining := 0.0
var burn_request: DamageRequest
var bleed_streams: Dictionary[String, Dictionary] = {}
var berserker_wound_visual_stacks := 0
var berserker_wound_visual_remaining := 0.0
var _berserker_wound_visual_pulse := 0.0
var slow_remaining := 0.0
var slow_fraction := 0.0
var electrified_remaining := 0.0
var weaken_remaining := 0.0
var weaken_fraction := 0.0
var attribute_debuffs := AttributeDebuffState.new()
var hard_controls := HardControlState.new()
var character_animation: CharacterAnimation

func set_animation_kind(kind: StringName) -> void:
	character_animation = CharacterAnimation.new()
	character_animation.configure(kind)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_visible_height = 52.0
	if not presentation_action.is_connected(_animate_action):
		presentation_action.connect(_animate_action)
	queue_redraw()

func _animate_action(action: StringName, direction: Vector2, duration: float) -> void:
	if character_animation != null:
		character_animation.play(action, direction, duration)

func set_pilot_sprite(texture: Texture2D) -> void:
	sprite_texture = texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var size := texture.get_size()
	var used := texture.get_image().get_used_rect()
	var display_scale := 52.0 / maxf(1.0, float(used.size.y))
	# The lowest opaque row touches the actor's existing ground origin.
	sprite_rect = Rect2(Vector2(-size.x * 0.5, -float(used.end.y)) * display_scale, size * display_scale)
	_sprite_visible_height = float(used.size.y) * display_scale
	queue_redraw()

func setup(display_name: String, color: Color, derived_stats: StatBreakdown, radius: float = 18.0) -> void:
	assert(derived_stats != null)
	hard_controls.configure(false)
	actor_name = display_name
	actor_color = color
	stat_breakdown = derived_stats
	collision_radius = radius
	health = HealthState.new(get_instance_id(), stat_breakdown)
	health.damage_applied.connect(_on_damage_applied)
	health.actor_died.connect(_on_health_died)
	queue_redraw()

func apply_damage(request: DamageRequest, rng: RandomNumberGenerator) -> Dictionary:
	if health == null or request == null:
		return {}
	var received_increase := attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_RECEIVED)
	var effective_request := request
	if received_increase > 0.0:
		effective_request = request.copy()
		effective_request.damage_dealt_multiplier *= 1.0 + received_increase
	return health.apply(effective_request, rng.randf(), rng.randf(), attribute_debuffs)

func is_alive() -> bool:
	return health != null and health.is_alive()

func is_burning() -> bool:
	return burn_remaining > 0.0

func is_electrified() -> bool:
	return electrified_remaining > 0.0

func consume_electrified() -> bool:
	if not is_electrified():
		return false
	electrified_remaining = 0.0
	queue_redraw()
	return true

func apply_electrified(duration: float) -> void:
	if not is_alive() or duration <= 0.0:
		return
	electrified_remaining = duration
	queue_redraw()

func apply_burn(request: DamageRequest, duration: float = 3.0) -> void:
	if not is_alive() or request == null or duration <= 0.0 or request.physical_damage + request.magic_damage <= 0.0:
		return
	var was_burning := is_burning()
	burn_request = request.copy()
	burn_request.target_id = get_instance_id()
	burn_request.skill_id = &"burn_tick"
	burn_request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	burn_request.can_crit = false
	burn_request.force_critical = false
	burn_request.is_secondary = true
	burn_remaining = duration
	if not was_burning:
		burn_tick_remaining = minf(1.0, duration)
	queue_redraw()

func apply_bleed(request: DamageRequest, duration: float = 4.0) -> void:
	if not is_alive() or request == null or duration <= 0.0 or request.physical_damage <= 0.0 or request.source_id <= 0 or request.skill_id.is_empty():
		return
	var key := "%d:%s" % [request.source_id, request.skill_id]
	var tick_remaining := float(bleed_streams[key].get("tick_remaining", 1.0)) if bleed_streams.has(key) else 1.0
	var captured := request.copy()
	captured.target_id = get_instance_id()
	captured.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	captured.can_crit = false
	captured.force_critical = false
	captured.is_secondary = true
	bleed_streams[key] = {"request": captured, "remaining": duration, "tick_remaining": tick_remaining}
	queue_redraw()

func set_berserker_wound_visual(stacks: int, remaining: float) -> void:
	var normalized_stacks := clampi(stacks, 0, 3)
	var normalized_remaining := maxf(0.0, remaining) if normalized_stacks > 0 else 0.0
	if normalized_stacks > berserker_wound_visual_stacks:
		_berserker_wound_visual_pulse = 0.25
	if normalized_stacks == berserker_wound_visual_stacks and is_equal_approx(normalized_remaining, berserker_wound_visual_remaining):
		return
	berserker_wound_visual_stacks = normalized_stacks
	berserker_wound_visual_remaining = normalized_remaining
	queue_redraw()

func apply_attribute_debuff(attribute: StringName, source: StringName, fraction: float, duration: float) -> bool:
	if not is_alive() or not attribute_debuffs.apply(attribute, source, fraction, duration):
		return false
	_sync_debuff_display()
	queue_redraw()
	return true

func remove_attribute_debuff(attribute: StringName, source: StringName) -> bool:
	if not attribute_debuffs.remove(attribute, source):
		return false
	_sync_debuff_display()
	queue_redraw()
	return true

func apply_slow(fraction: float, duration: float, source: StringName = &"") -> void:
	# Legacy direct callers use the magnitude as identity; skill callers provide an ID.
	var resolved_source := source if not source.is_empty() else StringName("slow_%d" % roundi(fraction * 1000.0))
	apply_attribute_debuff(AttributeDebuffState.MOVE_SPEED, resolved_source, fraction, duration)

func configure_hard_control_profile(is_boss: bool) -> void:
	hard_controls.configure(is_boss)
	queue_redraw()

func apply_root(base_duration: float, control_tag: StringName = &"physical") -> float:
	if not is_alive() or control_tag not in [&"physical", &"magic"]:
		return 0.0
	var resistance_id := &"physical_cc_resistance" if control_tag == &"physical" else &"magic_cc_resistance"
	var applied_duration := hard_controls.apply(&"root", base_duration, stat_breakdown.value(resistance_id))
	if applied_duration > 0.0:
		queue_redraw()
	return applied_duration

func is_rooted() -> bool:
	return hard_controls.is_active(&"root")

func root_remaining() -> float:
	return hard_controls.remaining(&"root")

func apply_stun(base_duration: float) -> float:
	if not is_alive():
		return 0.0
	var applied_duration := hard_controls.apply(&"stun", base_duration, stat_breakdown.value(&"magic_cc_resistance"))
	if applied_duration > 0.0:
		queue_redraw()
	return applied_duration

func is_stunned() -> bool:
	return hard_controls.is_active(&"stun")

func stun_remaining() -> float:
	return hard_controls.remaining(&"stun")

func apply_fear(base_duration: float) -> float:
	if not is_alive():
		return 0.0
	var applied_duration := hard_controls.apply(&"fear", base_duration, stat_breakdown.value(&"magic_cc_resistance"))
	if applied_duration > 0.0:
		queue_redraw()
	return applied_duration

func is_feared() -> bool:
	return hard_controls.is_active(&"fear")

func fear_remaining() -> float:
	return hard_controls.remaining(&"fear")

func apply_weaken(fraction: float, duration: float, source: StringName = &"") -> void:
	var resolved_source := source if not source.is_empty() else StringName("weaken_%d" % roundi(fraction * 1000.0))
	apply_attribute_debuff(AttributeDebuffState.DAMAGE_DEALT, resolved_source, fraction, duration)

func outgoing_damage_multiplier() -> float:
	return StatCalculator.runtime_reduced_value(&"damage_dealt_multiplier", stat_breakdown.value(&"damage_dealt_multiplier"), attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT))

func attacks_per_second() -> float:
	return StatCalculator.runtime_reduced_value(&"attacks_per_second", stat_breakdown.value(&"attacks_per_second"), attribute_debuffs.fraction(AttributeDebuffState.ATTACK_SPEED))

func set_unstoppable(duration: float) -> bool:
	var changed := hard_controls.set_unstoppable(duration)
	if changed:
		queue_redraw()
	return changed

func movement_speed_multiplier() -> float:
	return 1.0 - attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED)

func _sync_debuff_display() -> void:
	slow_fraction = attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED)
	slow_remaining = attribute_debuffs.remaining(AttributeDebuffState.MOVE_SPEED)
	weaken_fraction = attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT)
	weaken_remaining = attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_DEALT)

func clear_statuses() -> void:
	burn_remaining = 0.0
	burn_tick_remaining = 0.0
	burn_request = null
	bleed_streams.clear()
	berserker_wound_visual_stacks = 0
	berserker_wound_visual_remaining = 0.0
	_berserker_wound_visual_pulse = 0.0
	attribute_debuffs.clear()
	_sync_debuff_display()
	electrified_remaining = 0.0
	hard_controls.clear()
	queue_redraw()

func advance_statuses(delta: float, simulation_paused: bool = false) -> void:
	if simulation_paused or not is_alive() or delta <= 0.0:
		return
	var was_rooted := is_rooted()
	var was_stunned := is_stunned()
	var was_feared := is_feared()
	hard_controls.advance(delta)
	if was_rooted != is_rooted() or was_stunned != is_stunned() or was_feared != is_feared():
		queue_redraw()
	var previous_slow := slow_fraction
	var previous_weaken := weaken_fraction
	attribute_debuffs.advance(delta)
	_sync_debuff_display()
	if previous_slow != slow_fraction or previous_weaken != weaken_fraction:
		queue_redraw()
	if electrified_remaining > 0.0:
		electrified_remaining = maxf(0.0, electrified_remaining - delta)
		queue_redraw()
	var remaining_delta := delta
	while burn_remaining > 0.0 and remaining_delta > 0.0:
		var step := minf(remaining_delta, minf(burn_remaining, burn_tick_remaining))
		burn_remaining = maxf(0.0, burn_remaining - step)
		burn_tick_remaining = maxf(0.0, burn_tick_remaining - step)
		remaining_delta = maxf(0.0, remaining_delta - step)
		if burn_tick_remaining <= 0.0001:
			var request := burn_request.copy()
			status_damage_requested.emit(request, self)
			if not is_alive():
				break
			burn_tick_remaining = 1.0
	if burn_remaining <= 0.0:
		burn_request = null
		queue_redraw()
	for key: String in bleed_streams.keys():
		if not bleed_streams.has(key) or not is_alive():
			break
		var stream: Dictionary = bleed_streams[key]
		var bleed_delta := delta
		while float(stream["remaining"]) > 0.0 and bleed_delta > 0.0:
			var step := minf(bleed_delta, minf(float(stream["remaining"]), float(stream["tick_remaining"])))
			stream["remaining"] = maxf(0.0, float(stream["remaining"]) - step)
			stream["tick_remaining"] = maxf(0.0, float(stream["tick_remaining"]) - step)
			bleed_delta = maxf(0.0, bleed_delta - step)
			if float(stream["tick_remaining"]) <= 0.0001:
				var tick: DamageRequest = (stream["request"] as DamageRequest).copy()
				status_damage_requested.emit(tick, self)
				if not is_alive():
					break
				stream["tick_remaining"] = 1.0
		if not is_alive():
			break
		if float(stream["remaining"]) <= 0.0:
			bleed_streams.erase(key)
			queue_redraw()

func set_hovered(value: bool) -> void:
	if is_hovered == value:
		return
	is_hovered = value
	queue_redraw()

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	queue_redraw()

func _process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	if character_animation != null:
		character_animation.observe(global_position, delta)
		queue_redraw()
	advance_statuses(delta)
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		queue_redraw()
	if _berserker_wound_visual_pulse > 0.0:
		_berserker_wound_visual_pulse = maxf(0.0, _berserker_wound_visual_pulse - delta)
		queue_redraw()

func _draw() -> void:
	# Compact contact shadow centered under the soles; no detached tile diamond.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.30))
	draw_circle(Vector2.ZERO, 15.0, Color(0.02, 0.03, 0.04, 0.14))
	draw_circle(Vector2.ZERO, 11.0, Color(0.02, 0.03, 0.04, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var color := Color.WHITE if _flash_time > 0.0 else actor_color
	if is_selected:
		_draw_target_ring(collision_radius + 14.0, Color("f5cc77"), 3.0)
	elif is_hovered:
		_draw_target_ring(collision_radius + 11.0, Color("81dfd0"), 2.0)
	if character_animation != null:
		character_animation.draw_on(self, Color(2.0, 2.0, 2.0) if _flash_time > 0.0 else Color.WHITE)
	elif sprite_texture != null:
		var tint := Color(2.0, 2.0, 2.0) if _flash_time > 0.0 else Color.WHITE
		draw_texture_rect(sprite_texture, sprite_rect, false, tint)
	else:
		draw_circle(Vector2(0, -18), collision_radius, color)
		draw_circle(Vector2(0, -22), collision_radius * 0.55, color.lightened(0.14))
	if health != null:
		var bar_width := 52.0
		var ratio := health.current_hp / health.max_hp
		var bar_y := -_sprite_visible_height - 8.0 if sprite_texture != null else -54.0
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 6), Color(0.08, 0.09, 0.12, 0.9))
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * ratio, 6), Color("dc5757"))
	if berserker_wound_visual_stacks > 0:
		var wound_y := -_sprite_visible_height - 15.0
		for index: int in range(3):
			var center := Vector2((float(index) - 1.0) * 11.0, wound_y)
			var diamond := PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 0), center + Vector2(0, 4), center + Vector2(-4, 0)])
			draw_colored_polygon(diamond, Color("f6dfc0") if index < berserker_wound_visual_stacks else Color("3e3440"))
			draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("4b2434"), 1.0, true)
		var expiry_ratio := clampf(berserker_wound_visual_remaining / 8.0, 0.0, 1.0)
		draw_arc(Vector2(0, wound_y), 21.0, -PI * 0.5, -PI * 0.5 + TAU * expiry_ratio, 32, Color("f6dfc0"), 1.5, true)
		if _berserker_wound_visual_pulse > 0.0:
			var alpha := _berserker_wound_visual_pulse / 0.25
			draw_line(Vector2(-12, -32), Vector2(5, -17), Color(0.98, 0.93, 0.79, alpha), 2.5, true)
			draw_line(Vector2(1, -32), Vector2(16, -21), Color(0.88, 0.30, 0.37, alpha), 2.5, true)
	if is_burning():
		draw_arc(Vector2(0, 3), collision_radius + 6.0, 0.0, TAU, 24, Color("ff7a3d"), 2.0, true)
	if not bleed_streams.is_empty():
		draw_arc(Vector2(0, 4), collision_radius + 7.0, -PI * 0.75, PI * 0.25, 20, Color("d65572"), 2.0, true)
	if slow_remaining > 0.0:
		draw_arc(Vector2(0, 6), collision_radius + 9.0, 0.0, TAU, 24, Color("72c9ff"), 2.0, true)
	if is_electrified():
		for side: float in [-1.0, 1.0]:
			var x := side * (collision_radius + 8.0)
			draw_polyline(PackedVector2Array([Vector2(x, -34), Vector2(x - side * 5.0, -24), Vector2(x + side * 2.0, -24), Vector2(x - side * 4.0, -13)]), Color("e9d76a"), 2.5, true)
	if is_rooted():
		draw_arc(Vector2(0, 7), collision_radius + 12.0, 0.0, TAU, 24, Color("d9bd72"), 3.0, true)
	if is_stunned():
		draw_arc(Vector2(0, -18), collision_radius + 13.0, -PI * 0.9, -PI * 0.1, 20, Color("f9e585"), 3.0, true)
	if is_feared():
		draw_arc(Vector2(0, -18), collision_radius + 16.0, -PI * 0.8, PI * 0.8, 28, Color("ba8de9"), 3.0, true)
	if weaken_remaining > 0.0:
		draw_arc(Vector2(0, 8), collision_radius + 17.0, 0.0, TAU, 28, Color("a889c4", 0.8), 1.5, true)

func _draw_target_ring(radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index: int in range(49):
		var angle := TAU * index / 48.0
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.55 + 4.0))
	draw_polyline(points, Color(0.03, 0.07, 0.09, 0.85), width + 3.0, true)
	draw_polyline(points, color, width, true)
	for sign_value: float in [-1.0, 1.0]:
		var edge := Vector2(sign_value * (radius + 5.0), 4.0)
		draw_line(edge - Vector2(0, 5), edge + Vector2(0, 5), color, 2.0, true)

func _on_damage_applied(result: Dictionary) -> void:
	if not bool(result["landed"]):
		attack_missed.emit(self)
		return
	if float(result["actual_damage"]) <= 0.0:
		return
	_flash_time = 0.10
	if character_animation != null:
		character_animation.play(&"hurt")
	damage_number.emit(self, ceili(float(result["actual_damage"])), bool(result["critical"]))
	queue_redraw()

func _on_health_died(_actor_id: int) -> void:
	if character_animation != null:
		character_animation.play(&"death")
	clear_statuses()
	actor_died.emit(self)
	queue_redraw()
