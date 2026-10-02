class_name GeometerAnchor
extends RefCounted
## Run-local ground or actor anchor, with an independent lifetime.

var element: StringName = &"fire"
var position := Vector2.ZERO
var last_valid_ground := Vector2.ZERO
var actor_id := 0
var remaining := 8.0

static func create(token: StringName, point: Vector2, carrier_id: int, duration: float = 8.0) -> GeometerAnchor:
	var anchor := GeometerAnchor.new()
	anchor.element = token
	anchor.position = point
	anchor.last_valid_ground = point
	anchor.actor_id = carrier_id
	anchor.remaining = clampf(duration, 0.0, 12.0)
	return anchor

func refresh(alive_positions: Dictionary[int, Vector2], navigation: ArenaNavigation) -> void:
	if actor_id == 0:
		return
	if not alive_positions.has(actor_id):
		actor_id = 0
		position = last_valid_ground
		return
	position = alive_positions[actor_id]
	if position.is_finite() and navigation != null and navigation.is_segment_clear(position, position, 0.0):
		last_valid_ground = position

func advance(delta: float) -> void:
	if is_finite(delta) and delta > 0.0:
		remaining = maxf(0.0, remaining - delta)

func snapshot() -> GeometerAnchor:
	var copy := GeometerAnchor.create(element, position, actor_id, remaining)
	copy.last_valid_ground = last_valid_ground
	return copy
