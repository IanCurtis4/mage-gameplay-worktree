class_name CombatActor
extends Node2D
## Shared runtime presentation and health ownership for combat actors.

signal actor_died(actor: CombatActor)
signal damage_number(actor: CombatActor, amount: int, critical: bool)
signal attack_missed(actor: CombatActor)
signal status_damage_requested(request: DamageRequest, target: CombatActor)
signal presentation_action(action: StringName, direction: Vector2, duration: float)

var actor_name := "Ator"
var actor_color := Color.WHITE
var stats: Dictionary = {}
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
var burn_source_id: int = 0
var burn_damage_per_tick := 0.0
var slow_remaining := 0.0
var slow_fraction := 0.0

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

func setup(display_name: String, color: Color, derived_stats: Dictionary, radius: float = 18.0) -> void:
	actor_name = display_name
	actor_color = color
	stats = derived_stats.duplicate(true)
	collision_radius = radius
	health = HealthState.new(get_instance_id(), float(stats["max_hp"]), float(stats["defense"]))
	health.damage_applied.connect(_on_damage_applied)
	health.actor_died.connect(_on_health_died)
	queue_redraw()

func apply_damage(request: DamageRequest, rng: RandomNumberGenerator) -> Dictionary:
	if health == null:
		return {}
	return health.apply(request, rng.randf(), rng.randf())

func is_alive() -> bool:
	return health != null and health.is_alive()

func is_burning() -> bool:
	return burn_remaining > 0.0

func apply_burn(source_id: int, damage_per_tick: float, duration: float = 3.0) -> void:
	if not is_alive() or duration <= 0.0 or damage_per_tick <= 0.0:
		return
	var was_burning := is_burning()
	burn_source_id = source_id
	burn_damage_per_tick = damage_per_tick
	burn_remaining = duration
	if not was_burning:
		burn_tick_remaining = minf(1.0, duration)
	queue_redraw()

func apply_slow(fraction: float, duration: float) -> void:
	if not is_alive() or duration <= 0.0:
		return
	slow_fraction = maxf(slow_fraction, clampf(fraction, 0.0, 0.95))
	slow_remaining = maxf(slow_remaining, duration)
	queue_redraw()

func movement_speed_multiplier() -> float:
	return 1.0 - slow_fraction if slow_remaining > 0.0 else 1.0

func clear_statuses() -> void:
	burn_remaining = 0.0
	burn_tick_remaining = 0.0
	burn_source_id = 0
	burn_damage_per_tick = 0.0
	slow_remaining = 0.0
	slow_fraction = 0.0
	queue_redraw()

func advance_statuses(delta: float, simulation_paused: bool = false) -> void:
	if simulation_paused or not is_alive() or delta <= 0.0:
		return
	if slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining <= 0.0:
			slow_fraction = 0.0
			queue_redraw()
	var remaining_delta := delta
	while burn_remaining > 0.0 and remaining_delta > 0.0:
		var step := minf(remaining_delta, minf(burn_remaining, burn_tick_remaining))
		burn_remaining = maxf(0.0, burn_remaining - step)
		burn_tick_remaining = maxf(0.0, burn_tick_remaining - step)
		remaining_delta = maxf(0.0, remaining_delta - step)
		if burn_tick_remaining <= 0.0001:
			var request := DamageRequest.new()
			request.source_id = burn_source_id
			request.target_id = get_instance_id()
			request.skill_id = &"burn_tick"
			request.kind = DamageRequest.Kind.MAGIC
			request.base_damage = burn_damage_per_tick
			request.hit_chance = 1.0
			request.can_crit = false
			request.is_secondary = true
			status_damage_requested.emit(request, self)
			if not is_alive():
				break
			burn_tick_remaining = 1.0
	if burn_remaining <= 0.0:
		burn_damage_per_tick = 0.0
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
	advance_statuses(delta)
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		queue_redraw()

func _draw() -> void:
	var shadow := PackedVector2Array([Vector2(-22, 4), Vector2(0, 14), Vector2(22, 4), Vector2(0, -6)])
	draw_colored_polygon(shadow, Color(0.02, 0.03, 0.05, 0.5))
	var color := Color.WHITE if _flash_time > 0.0 else actor_color
	if is_selected:
		_draw_target_ring(collision_radius + 14.0, Color("f5cc77"), 3.0)
	elif is_hovered:
		_draw_target_ring(collision_radius + 11.0, Color("81dfd0"), 2.0)
	if sprite_texture != null:
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
	if is_burning():
		draw_arc(Vector2(0, 3), collision_radius + 6.0, 0.0, TAU, 24, Color("ff7a3d"), 2.0, true)
	if slow_remaining > 0.0:
		draw_arc(Vector2(0, 6), collision_radius + 9.0, 0.0, TAU, 24, Color("72c9ff"), 2.0, true)

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
	damage_number.emit(self, ceili(float(result["actual_damage"])), bool(result["critical"]))
	queue_redraw()

func _on_health_died(_actor_id: int) -> void:
	clear_statuses()
	actor_died.emit(self)
	queue_redraw()
