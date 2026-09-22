class_name FoliageShelter
extends Node2D
## Fixed concealment area. Target acquisition remains owned by actors; this
## runtime only owns area membership, lifetime and cleanup.

signal removed(shelter: FoliageShelter, reason: StringName)

const RADIUS := 110.0
const REASON_EXPIRED: StringName = &"expired"

var player_owner: PlayerActor
var remaining := 0.0
var duration := 0.0
var removal_reason: StringName = &""
var _registered := false

func configure(player: PlayerActor, center: Vector2, duration_value: float) -> void:
	assert(player != null)
	assert(is_finite(duration_value) and duration_value > 0.0)
	player_owner = player
	global_position = center
	duration = duration_value
	remaining = duration
	_registered = player_owner.register_foliage_shelter(get_instance_id(), global_position, RADIUS)
	assert(_registered)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("foliage_shelters")

func is_active() -> bool:
	return removal_reason.is_empty() and remaining > 0.0

func expire(reason: StringName = REASON_EXPIRED) -> bool:
	if not removal_reason.is_empty():
		return false
	removal_reason = reason
	remaining = 0.0
	_unregister()
	removed.emit(self, reason)
	queue_free()
	return true

func _process(delta: float) -> void:
	if player_owner == null or not is_instance_valid(player_owner) or not player_owner.is_alive():
		expire(&"owner_unavailable")
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		expire()
		return
	queue_redraw()

func _exit_tree() -> void:
	_unregister()

func _unregister() -> void:
	if not _registered:
		return
	_registered = false
	if player_owner != null and is_instance_valid(player_owner):
		player_owner.unregister_foliage_shelter(get_instance_id())

func _draw() -> void:
	var alpha := minf(1.0, remaining * 2.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.18, 0.39, 0.16, 0.16 * alpha))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 56, Color(0.04, 0.09, 0.12, 0.82 * alpha), 5.0, true)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 56, Color(0.47, 0.75, 0.34, 0.9 * alpha), 2.0, true)
	for index: int in range(12):
		var angle := TAU * float(index) / 12.0 + (duration - remaining) * 0.18
		var distance := RADIUS * (0.30 + 0.55 * float((index % 4) + 1) / 4.0)
		var leaf := Vector2.from_angle(angle) * distance
		draw_circle(leaf, 4.0, Color(0.57, 0.80, 0.35, 0.55 * alpha))
