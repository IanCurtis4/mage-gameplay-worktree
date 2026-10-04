class_name SentinelAreaProjectile
extends SentinelProjectile
## The first body/terrain contact opens one net. Geometry stays world-space.

signal burst(center: Vector2, damage_request: DamageRequest, tuning: Dictionary)

var endpoint := Vector2.ZERO
var payload: Dictionary = {}
var opened := false

func _process(delta: float) -> void:
	if opened or is_queued_for_deletion() or (is_inside_tree() and get_tree().paused) or not is_finite(delta) or delta <= 0.0:
		return
	if request == null:
		queue_free()
		return
	if homing:
		# Explosivo loses its target without a refund after launch, just like autos.
		if not is_instance_valid(target) or not target.is_alive():
			queue_free()
			return
		endpoint = target.global_position + BODY_OFFSET
	direction = global_position.direction_to(endpoint)
	rotation = direction.angle()
	var distance := global_position.distance_to(endpoint)
	var step := minf(speed * delta, minf(distance, maxf(0.0, max_distance - travelled)))
	var start := global_position
	var finish := start + direction * step
	var wall := _wall_fraction(start, finish)
	var contact := _nearest_impact(start, finish)
	var fraction := minf(wall, float(contact.get("fraction", 2.0)))
	if fraction <= 1.0:
		global_position = start.lerp(finish, fraction)
		_open()
		return
	global_position = finish
	travelled += step
	if distance <= step + 0.001:
		_open()
	elif travelled >= max_distance:
		queue_free()

func _open() -> void:
	if opened:
		return
	opened = true
	burst.emit(global_position - BODY_OFFSET, request.copy(), payload.duplicate(true))
	queue_free()
