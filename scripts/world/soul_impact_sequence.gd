class_name SoulImpactSequence
extends Node2D
## Three locked-target pulses share one captured emission and one total damage budget.

signal impact(request: DamageRequest, target: CombatActor)

const IMPACT_COUNT := 3
const IMPACT_INTERVAL := 0.12
const VISUAL_TAIL := 0.16

var target_id := 0
var impact_request: DamageRequest
var emitted := 0
var time_to_next := 0.0
var visual_remaining := VISUAL_TAIL

func configure(total_request: DamageRequest, target: CombatActor) -> void:
	assert(total_request != null and target != null)
	target_id = target.get_instance_id()
	impact_request = total_request.copy()
	impact_request.target_id = target_id
	impact_request.magic_damage /= float(IMPACT_COUNT)
	impact_request.physical_damage /= float(IMPACT_COUNT)
	global_position = target.global_position
	emitted = 0
	time_to_next = 0.0
	visual_remaining = VISUAL_TAIL
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if is_queued_for_deletion() or (is_inside_tree() and get_tree().paused):
		return
	var target := instance_from_id(target_id) as CombatActor
	if target == null or not target.is_alive():
		queue_free()
		return
	global_position = target.global_position
	if emitted == IMPACT_COUNT:
		visual_remaining = maxf(0.0, visual_remaining - delta)
		if visual_remaining <= 0.0:
			queue_free()
		else:
			queue_redraw()
		return
	time_to_next -= delta
	while time_to_next <= 0.0 and emitted < IMPACT_COUNT:
		var pulse := impact_request.copy()
		pulse.is_secondary = emitted > 0
		emitted += 1
		impact.emit(pulse, target)
		if is_queued_for_deletion() or not is_instance_valid(target) or not target.is_alive():
			queue_free()
			return
		time_to_next += IMPACT_INTERVAL
		visual_remaining = VISUAL_TAIL
	queue_redraw()

func _draw() -> void:
	if emitted <= 0:
		return
	var alpha := clampf(visual_remaining / VISUAL_TAIL, 0.0, 1.0)
	var radius := 14.0 + float(emitted) * 5.0 + (1.0 - alpha) * 8.0
	draw_circle(Vector2(0, -18), radius * 0.55, Color(0.74, 0.55, 0.95, 0.10 * alpha))
	draw_arc(Vector2(0, -18), radius, 0.0, TAU, 32, Color(0.84, 0.71, 1.0, 0.85 * alpha), 2.5, true)
	draw_arc(Vector2(0, -18), radius * 0.55, 0.0, TAU, 24, Color(0.96, 0.87, 1.0, 0.55 * alpha), 1.5, true)
