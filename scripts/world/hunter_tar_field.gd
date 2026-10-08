class_name HunterTarField
extends Node2D
## One bounded field per owner (managed by RunController). No damage or opening
## ticks. Owner-specific slow source survives the short expiry residue so end
## cleanup can remove it even after the visual field node has been freed.

const RADIUS := 100.0
var owner_id := 0
var owner_actor: CombatActor
var duration := 0.0
var remaining := 0.0
var slow_fraction := 0.0
var residual_duration := 0.4
var source_id: StringName
var target_filter: Callable
var active := false
var _targets: Array[CombatActor] = []

static func slow_source(runtime_owner_id: int) -> StringName:
	return StringName("hunter_tar_%d" % runtime_owner_id)

func configure_tar(owner: CombatActor, center: Vector2, tuning: Dictionary, targets: Array[CombatActor]) -> void:
	assert(not active and owner != null)
	owner_actor = owner
	owner_id = owner.get_instance_id()
	global_position = center
	duration = float(tuning["field_duration"])
	remaining = duration
	slow_fraction = float(tuning["slow_fraction"])
	residual_duration = float(tuning["residual_duration"])
	source_id = slow_source(owner_id)
	_targets.clear()
	active = true
	for victim: CombatActor in targets:
		track_target(victim)
	owner.actor_died.connect(_on_owner_died)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = -1

func track_target(victim: CombatActor) -> void:
	for index: int in range(_targets.size() - 1, -1, -1):
		if not is_instance_valid(_targets[index]):
			_targets.remove_at(index)
	if active and victim != null and is_instance_valid(victim) and victim.get_instance_id() != owner_id and victim not in _targets and _targets.size() < HunterTuning.OPENING_CAP:
		_targets.append(victim)

func _on_owner_died(_owner: CombatActor) -> void:
	expire()

func refresh_occupants() -> void:
	if not active or not is_instance_valid(owner_actor) or not owner_actor.is_alive() or (is_inside_tree() and get_tree().paused):
		return
	for victim: CombatActor in _targets.duplicate():
		if victim == null or not is_instance_valid(victim) or not victim.is_alive():
			continue
		if global_position.distance_to(victim.global_position) <= RADIUS + victim.collision_radius and (not target_filter.is_valid() or bool(target_filter.call(victim))):
			victim.apply_slow(slow_fraction, residual_duration, source_id)

func consume_for_explosion(center: Vector2, blast_radius: float, navigation: ArenaNavigation) -> float:
	if not active or remaining <= 0.0 or not is_instance_valid(owner_actor) or not owner_actor.is_alive() or navigation == null or (is_inside_tree() and get_tree().paused):
		return 0.0
	if global_position.distance_to(center) > RADIUS + blast_radius or not navigation.is_segment_clear(center, global_position, 0.0):
		return 0.0
	var bonus := 0.25 * clampf(remaining / duration, 0.0, 1.0)
	# Claim and remove every own slow BEFORE any damage callback.
	expire(true)
	return bonus

func expire(remove_slow: bool = true) -> void:
	if not active:
		return
	active = false
	remaining = 0.0
	if remove_slow:
		_remove_own_slow()
	queue_redraw()
	queue_free()

func _remove_own_slow() -> void:
	for victim: CombatActor in _targets:
		if victim != null and is_instance_valid(victim):
			victim.remove_attribute_debuff(AttributeDebuffState.MOVE_SPEED, source_id)

func _exit_tree() -> void:
	# External cleanup/retry must not leave the field's source behind.
	if active:
		active = false
		_remove_own_slow()

func _process(delta: float) -> void:
	if not active or not is_finite(delta) or delta <= 0.0 or (is_inside_tree() and get_tree().paused):
		return
	if not is_instance_valid(owner_actor) or not owner_actor.is_alive():
		expire()
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.000001:
		expire(false) # Normal exit/expiry keeps at most the captured 0.4s residue.
		return
	refresh_occupants()
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	draw_circle(Vector2.ZERO, RADIUS, Color(0.13, 0.16, 0.09, 0.26))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color("b7aa73"), 1.5, true)
	for index: int in range(7):
		var point := Vector2.from_angle(TAU * index / 7.0) * 58.0
		draw_arc(point, 9.0, 0.0, PI, 12, Color(0.54, 0.52, 0.31, 0.5), 2.0, true)
