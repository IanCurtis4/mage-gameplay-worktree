class_name CombatActor
extends Node2D
## Shared runtime presentation and health ownership for combat actors.

signal actor_died(actor: CombatActor)
signal damage_number(actor: CombatActor, amount: int, critical: bool)

var actor_name := "Ator"
var actor_color := Color.WHITE
var stats: Dictionary = {}
var health: HealthState
var collision_radius := 18.0
var is_hovered := false
var is_selected := false
var _flash_time := 0.0

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
	draw_circle(Vector2(0, -18), collision_radius, color)
	draw_circle(Vector2(0, -22), collision_radius * 0.55, color.lightened(0.14))
	if health != null:
		var bar_width := 52.0
		var ratio := health.current_hp / health.max_hp
		draw_rect(Rect2(-bar_width * 0.5, -54, bar_width, 6), Color(0.08, 0.09, 0.12, 0.9))
		draw_rect(Rect2(-bar_width * 0.5, -54, bar_width * ratio, 6), Color("dc5757"))

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
	_flash_time = 0.10
	damage_number.emit(self, ceili(float(result["actual_damage"])), bool(result["critical"]))
	queue_redraw()

func _on_health_died(_actor_id: int) -> void:
	actor_died.emit(self)
	queue_redraw()
