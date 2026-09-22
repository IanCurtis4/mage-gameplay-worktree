class_name PlayerTrap
extends Node2D
## Shared trap lifecycle. Concrete traps subscribe to `triggered` to apply their
## own effect; replacement and cleanup never synthesize a trigger.

signal armed(trap: PlayerTrap)
signal triggered(trap: PlayerTrap, target: CombatActor)
signal expired(trap: PlayerTrap, reason: StringName)
signal removed(trap: PlayerTrap, reason: StringName)

enum State { ARMING, ARMED, TRIGGERED, EXPIRED }

const REASON_TRIGGERED: StringName = &"triggered"
const REASON_DURATION: StringName = &"duration"
const REASON_REPLACED: StringName = &"replaced"
const REASON_CLEANUP: StringName = &"cleanup"

var owner_id := 0
var source_skill_id: StringName = &""
var radius := 0.0
var arming_duration := 0.0
var armed_duration := 0.0
var arming_remaining := 0.0
var lifetime_remaining := 0.0
var state: State = State.EXPIRED
var removal_reason: StringName = &""
var registration_order := 0
var _configured := false

func configure(
	trap_owner_id: int,
	skill_id: StringName,
	placement: Vector2,
	radius_value: float,
	arming_time: float,
	lifetime: float
) -> void:
	assert(not _configured)
	assert(trap_owner_id > 0)
	assert(not skill_id.is_empty())
	assert(is_finite(radius_value) and radius_value >= 0.0)
	assert(is_finite(arming_time) and arming_time >= 0.0)
	assert(is_finite(lifetime) and lifetime > 0.0)
	owner_id = trap_owner_id
	source_skill_id = skill_id
	global_position = placement
	radius = radius_value
	arming_duration = arming_time
	armed_duration = lifetime
	arming_remaining = arming_duration
	lifetime_remaining = armed_duration
	state = State.ARMING if arming_remaining > 0.0 else State.ARMED
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_configured = true
	queue_redraw()

func is_configured() -> bool:
	return _configured

func is_active() -> bool:
	return _configured and state in [State.ARMING, State.ARMED]

func can_trigger(target: CombatActor) -> bool:
	return (
		state == State.ARMED
		and target != null
		and is_instance_valid(target)
		and target.is_alive()
		and global_position.distance_to(target.global_position) <= radius + target.collision_radius
	)

func try_trigger(target: CombatActor) -> bool:
	if not can_trigger(target):
		return false
	state = State.TRIGGERED
	removal_reason = REASON_TRIGGERED
	triggered.emit(self, target)
	removed.emit(self, removal_reason)
	queue_redraw()
	queue_free()
	return true

func expire(reason: StringName = REASON_DURATION) -> bool:
	if not is_active():
		return false
	state = State.EXPIRED
	removal_reason = reason if not reason.is_empty() else REASON_CLEANUP
	expired.emit(self, removal_reason)
	removed.emit(self, removal_reason)
	queue_redraw()
	queue_free()
	return true

func _process(delta: float) -> void:
	if not is_active() or delta <= 0.0:
		return
	if is_inside_tree() and get_tree().paused:
		return
	var remaining_delta := delta
	if state == State.ARMING:
		var arming_step := minf(arming_remaining, remaining_delta)
		arming_remaining = maxf(0.0, arming_remaining - arming_step)
		remaining_delta = maxf(0.0, remaining_delta - arming_step)
		if arming_remaining <= 0.0:
			state = State.ARMED
			armed.emit(self)
	if state == State.ARMED and remaining_delta > 0.0:
		lifetime_remaining = maxf(0.0, lifetime_remaining - remaining_delta)
		if lifetime_remaining <= 0.0:
			expire(REASON_DURATION)
	queue_redraw()

func _draw() -> void:
	if not _configured:
		return
	var color := Color("e8bb58") if state == State.ARMING else Color("7ecf78")
	if state in [State.TRIGGERED, State.EXPIRED]:
		color = Color("8a96a3")
	draw_circle(Vector2.ZERO, radius, Color(color, 0.10))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, color, 2.0, true)
	if state == State.ARMING and arming_duration > 0.0:
		var progress := 1.0 - arming_remaining / arming_duration
		draw_arc(Vector2.ZERO, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color("f5df8a"), 3.0, true)
