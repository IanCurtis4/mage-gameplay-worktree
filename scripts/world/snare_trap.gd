class_name SnareTrap
extends PlayerTrap
## Armed ground trap that consumes itself on the first living target and applies
## physical root through the shared hard-control contract.

signal root_applied(trap: SnareTrap, target: CombatActor, duration: float)

const TRIGGER_RADIUS := 52.0
const ARMING_TIME := 0.60
const ARMED_DURATION := 12.0

var root_duration := 0.0
var applied_root_duration := 0.0
var _targets: Array[CombatActor] = []

func configure_snare(trap_owner_id: int, placement: Vector2, duration: float, targets: Array[CombatActor]) -> void:
	assert(is_finite(duration) and duration > 0.0)
	root_duration = duration
	_targets = targets.duplicate()
	triggered.connect(_on_triggered)
	configure(trap_owner_id, &"snare_trap", placement, TRIGGER_RADIUS, ARMING_TIME, ARMED_DURATION)

func _process(delta: float) -> void:
	super._process(delta)
	if state != State.ARMED:
		return
	var selected_target := first_trigger_target(_targets)
	if selected_target != null:
		try_trigger(selected_target)

func _on_triggered(_trap: PlayerTrap, target: CombatActor) -> void:
	applied_root_duration = target.apply_root(root_duration, &"physical")
	root_applied.emit(self, target, applied_root_duration)

func _draw() -> void:
	super._draw()
	if not is_configured() or state in [State.TRIGGERED, State.EXPIRED]:
		return
	var color := Color("f0cf78") if state == State.ARMED else Color("a88b55")
	var extent := TRIGGER_RADIUS * 0.46
	draw_line(Vector2(-extent, -extent * 0.5), Vector2(extent, extent * 0.5), color, 2.0, true)
	draw_line(Vector2(-extent, extent * 0.5), Vector2(extent, -extent * 0.5), color, 2.0, true)
