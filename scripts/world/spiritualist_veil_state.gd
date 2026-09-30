class_name SpiritualistVeilState
extends RefCounted
## One finite ground zone; membership and debuff ownership stay in the controller.

const RADIUS := 110.0

var active := false
var center := Vector2.INF
var remaining := 0.0

func start(point: Vector2, duration: float) -> void:
	clear()
	if not point.is_finite() or not is_finite(duration) or duration <= 0.0:
		return
	active = true
	center = point
	remaining = duration

func advance(delta: float) -> bool:
	if not active or delta <= 0.0:
		return false
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		clear()
		return true
	return false

func contains(point: Vector2) -> bool:
	return active and point.is_finite() and center.distance_to(point) <= RADIUS

func clear() -> void:
	active = false
	center = Vector2.INF
	remaining = 0.0
