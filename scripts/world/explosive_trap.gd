class_name ExplosiveTrap
extends PlayerTrap
## Armed ground trap that consumes itself on the first living target and emits
## one captured physical hit for every living actor inside its fixed blast.

signal hit(request: DamageRequest, target: CombatActor)

const TRIGGER_RADIUS := 48.0
const BLAST_RADIUS := 105.0
const ARMING_TIME := 0.75
const ARMED_DURATION := 12.0

var damage_request: DamageRequest
var _targets: Array[CombatActor] = []

func configure_explosive(trap_owner_id: int, placement: Vector2, request: DamageRequest, targets: Array[CombatActor], armed_lifetime: float = ARMED_DURATION) -> void:
	assert(request != null)
	assert(request.skill_id == &"explosive_trap")
	damage_request = request.copy()
	_targets = targets.duplicate()
	triggered.connect(_on_triggered)
	configure(trap_owner_id, &"explosive_trap", placement, TRIGGER_RADIUS, ARMING_TIME, armed_lifetime)

func _process(delta: float) -> void:
	super._process(delta)
	if state != State.ARMED:
		return
	var selected_target := first_trigger_target(_targets)
	if selected_target != null:
		try_trigger(selected_target)

func _on_triggered(_trap: PlayerTrap, _target: CombatActor) -> void:
	var impacted: Array[CombatActor] = []
	for target: CombatActor in _targets:
		if target == null or not is_instance_valid(target) or target.get_instance_id() == owner_id or not target.is_alive():
			continue
		if global_position.distance_to(target.global_position) <= BLAST_RADIUS + target.collision_radius:
			impacted.append(target)
	impacted.sort_custom(func(first: CombatActor, second: CombatActor) -> bool: return first.get_instance_id() < second.get_instance_id())
	for target: CombatActor in impacted:
		var impact_request := damage_request.copy()
		impact_request.target_id = target.get_instance_id()
		hit.emit(impact_request, target)

func _draw() -> void:
	super._draw()
	if not is_configured() or state in [State.TRIGGERED, State.EXPIRED]:
		return
	var color := Color("ef8b58") if state == State.ARMED else Color("a96c4d")
	var core_radius := TRIGGER_RADIUS * 0.34
	draw_circle(Vector2.ZERO, core_radius, Color(color, 0.18))
	draw_arc(Vector2.ZERO, core_radius, 0.0, TAU, 28, color, 2.0, true)
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		draw_line(axis * core_radius, axis * (core_radius + 8.0), color, 2.0, true)
