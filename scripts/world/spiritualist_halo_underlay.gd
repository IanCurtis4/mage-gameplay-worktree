class_name SpiritualistHaloUnderlay
extends Node2D
## Ground-only Echo presentation. All membership and timing come from BattleIndicators.

const WISP: Texture2D = preload("res://assets/art/vfx/spiritualist_soul_wisp.png")

var indicators: BattleIndicators
var _was_active := false

func _ready() -> void:
	if indicators == null:
		push_error("SpiritualistHaloUnderlay requires BattleIndicators")
		return
	indicators.spiritualist_ground_changed.connect(queue_redraw)
	queue_redraw()

func _process(_delta: float) -> void:
	if indicators == null:
		return
	var active := not indicators.spiritualist_marks.is_empty() or not indicators.spiritualist_pending_remaining.is_empty()
	if active or _was_active:
		queue_redraw()
	_was_active = active

func _draw() -> void:
	if indicators == null:
		return
	for group: Dictionary in indicators.spiritualist_halo_groups():
		for actor: CombatActor in group["members"]:
			var target_id := actor.get_instance_id()
			var convergence := 0.0
			if indicators.spiritualist_pending_remaining.has(target_id):
				convergence = 1.0 - clampf(indicators.spiritualist_pending_remaining[target_id] / SpiritualistEchoState.ECHO_DELAY, 0.0, 1.0)
			_draw_halo(actor, convergence)

func _draw_halo(actor: CombatActor, convergence: float) -> void:
	var radius := BattleIndicators.SPIRITUALIST_HALO_RADIUS * sqrt(actor.sprite_visual_scale)
	var center := actor.global_position + Vector2(0, -3.0 * actor.sprite_visual_scale)
	var clock := indicators.spiritualist_visual_clock
	var pulse := 0.5 + 0.5 * sin(clock * 3.0 + float(actor.get_instance_id() % 7))
	var compression := 1.0 - convergence * 0.25
	draw_set_transform(center, 0.0, Vector2(compression, 0.64 * compression))
	draw_circle(Vector2.ZERO, radius, Color("e9f5ff", 0.15 + convergence * 0.11))
	draw_circle(Vector2.ZERO, radius * 0.72, Color("ffffff", 0.065 + convergence * 0.08))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color("f5fbff", 0.17 + pulse * 0.06 + convergence * 0.30), 1.3, true)
	draw_arc(Vector2.ZERO, radius * (0.76 - convergence * 0.18), -PI * 0.7, PI * 0.6, 26, Color("ccbce5", 0.23 + convergence * 0.35), 1.1, true)
	draw_set_transform(Vector2.ZERO)
	# A small spirit stays at each actual carrier's edge, below actor sprites.
	var phase := clock * (1.4 + convergence * 2.0) + float(actor.get_instance_id() % 11)
	var spirit := center + Vector2(cos(phase) * radius * 0.76, sin(phase) * radius * 0.29)
	_draw_ground_spirit(spirit, 18.0 * sqrt(actor.sprite_visual_scale), cos(phase) < 0.0, 0.58 + convergence * 0.25, int(clock * 5.0) % 4)

func _draw_ground_spirit(center: Vector2, size: float, face_right: bool, alpha: float, frame: int) -> void:
	var source := Rect2(float(posmod(frame, 4) * 96 + 13), 8, 80, 72)
	draw_set_transform(center, 0.0, Vector2.ONE if face_right else Vector2(-1, 1))
	draw_texture_rect_region(WISP, Rect2(-size * 0.54, -size * 0.47, size * 1.08, size * 0.94), source, Color(0.29, 0.18, 0.40, alpha * 0.75))
	draw_texture_rect_region(WISP, Rect2(-size * 0.5, -size * 0.43, size, size * 0.86), source, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO)
