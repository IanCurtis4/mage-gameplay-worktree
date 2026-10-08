class_name HunterCoverState
extends RefCounted
## Pure run clock. Registration/re-entry never grant budget; only a paid cast
## after the actor's canonical shared cooldown can begin a new cover cycle.

var budget_remaining := 0.0
var reveal_remaining := 0.0
var grace_remaining := 0.0
var zone_id := 0
var center := Vector2.ZERO
var radius := 0.0
var exit_grace := 0.0
var _inside := false

func begin_cycle() -> void:
	budget_remaining = HunterTuning.COVER_BUDGET
	grace_remaining = 0.0
	_inside = false
	# An attack immediately before placement must still reveal its owner.

func bind_zone(id: int, point: Vector2, zone_radius: float, grace: float) -> bool:
	if id <= 0 or not point.is_finite() or not is_finite(zone_radius) or zone_radius <= 0.0 or not is_finite(grace) or grace < 0.0 or grace > 1.0:
		return false
	zone_id = id
	center = point
	radius = zone_radius
	exit_grace = grace
	_inside = false
	grace_remaining = 0.0
	return true

func unbind_zone(id: int) -> void:
	if id != zone_id:
		return
	zone_id = 0
	_inside = false
	grace_remaining = 0.0

func sync_position(point: Vector2) -> void:
	var inside := zone_id > 0 and point.is_finite() and point.distance_to(center) <= radius
	if _inside and not inside:
		grace_remaining = exit_grace
	elif inside:
		grace_remaining = 0.0
	_inside = inside

func is_hidden(point: Vector2) -> bool:
	sync_position(point)
	return budget_remaining > 0.0 and reveal_remaining <= 0.0 and (_inside or grace_remaining > 0.0)

func reveal(duration: float = HunterTuning.COVER_REVEAL) -> bool:
	if not is_finite(duration) or duration <= 0.0:
		return false
	reveal_remaining = maxf(reveal_remaining, duration)
	return true

func advance(delta: float, point: Vector2, paused: bool = false) -> void:
	if paused or not is_finite(delta) or delta <= 0.0:
		return
	sync_position(point)
	# Integrate partial reveal/grace boundaries, not just the flag at frame end.
	var covered_time := delta if _inside else minf(delta, grace_remaining)
	var hidden_time := maxf(0.0, covered_time - minf(delta, reveal_remaining))
	budget_remaining = _remaining(budget_remaining, hidden_time)
	reveal_remaining = _remaining(reveal_remaining, delta)
	grace_remaining = _remaining(grace_remaining, delta)

func clear() -> void:
	budget_remaining = 0.0
	reveal_remaining = 0.0
	grace_remaining = 0.0
	zone_id = 0
	center = Vector2.ZERO
	radius = 0.0
	exit_grace = 0.0
	_inside = false

static func _remaining(value: float, delta: float) -> float:
	var result := maxf(0.0, value - delta)
	return 0.0 if result < 0.000001 else result
