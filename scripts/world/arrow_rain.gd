class_name ArrowRain
extends Node2D
## Announced fixed-area physical damage. Targets are sampled independently on
## each volley, allowing movement during the warning and between impacts.

signal hit(request: DamageRequest, target: CombatActor)

const RADIUS := 80.0
const WARNING_DURATION := 0.45
const VOLLEY_COUNT := 3
const VOLLEY_INTERVAL := 0.18

var damage_request: DamageRequest
var targets: Array[CombatActor] = []
var elapsed := 0.0
var volleys_emitted := 0

func configure(center: Vector2, request: DamageRequest, potential_targets: Array[CombatActor]) -> void:
	assert(request != null)
	damage_request = request.copy()
	targets = potential_targets.duplicate()
	global_position = center
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if damage_request == null:
		queue_free()
		return
	elapsed += delta
	while volleys_emitted < VOLLEY_COUNT and elapsed >= WARNING_DURATION + float(volleys_emitted) * VOLLEY_INTERVAL:
		_emit_volley()
		volleys_emitted += 1
	if volleys_emitted >= VOLLEY_COUNT:
		queue_free()
	queue_redraw()

func _emit_volley() -> void:
	var volley := damage_request.scheduled_tick()
	for actor: CombatActor in targets:
		if actor == null or not is_instance_valid(actor) or not actor.is_alive():
			continue
		if global_position.distance_to(actor.global_position) > RADIUS + actor.collision_radius:
			continue
		var impact_request := volley.copy()
		impact_request.target_id = actor.get_instance_id()
		hit.emit(impact_request, actor)

func _draw() -> void:
	var warning_progress := clampf(elapsed / WARNING_DURATION, 0.0, 1.0)
	var pulse_alpha := 0.10 + warning_progress * 0.12
	draw_circle(Vector2.ZERO, RADIUS, Color(0.44, 0.74, 0.36, pulse_alpha))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 56, Color(0.04, 0.09, 0.12, 0.85), 5.0, true)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 56, Color(0.72, 0.92, 0.45, 0.9), 2.0, true)
	for index: int in range(9):
		var angle := float(index) * 2.399963
		var distance := sqrt(float(index) / 9.0) * RADIUS * 0.75
		var base := Vector2.from_angle(angle) * distance
		var fall := fmod(elapsed * 220.0 + float(index) * 17.0, 34.0)
		draw_line(base + Vector2(8, -28 + fall), base + Vector2(-3, -8 + fall), Color(0.89, 0.76, 0.38, 0.85), 2.0, true)
