class_name ArrowProjectile
extends Node2D
## Fixed-direction projectile: it can be dodged and is destroyed by arena geometry.

signal hit(request: DamageRequest, target: CombatActor)

const BODY_OFFSET := Vector2(0, -18)

var request: DamageRequest
var target: CombatActor
var navigation: ArenaNavigation
var direction := Vector2.RIGHT
var speed := 430.0
var max_distance := 680.0
var projectile_radius := 4.0
var travelled := 0.0

func configure(damage_request: DamageRequest, target_actor: CombatActor, origin: Vector2, arena_navigation: ArenaNavigation) -> void:
	request = damage_request
	target = target_actor
	navigation = arena_navigation
	global_position = origin
	direction = origin.direction_to(target_actor.global_position + BODY_OFFSET)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	rotation = direction.angle()
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	if target == null or not is_instance_valid(target) or not target.is_alive() or travelled >= max_distance:
		queue_free()
		return
	if navigation == null:
		queue_free()
		return
	var step := minf(speed * delta, max_distance - travelled)
	var next_position := global_position + direction * step
	var target_center := target.global_position + BODY_OFFSET
	var target_fraction := _target_hit_fraction(target_center, global_position, next_position, target.collision_radius + projectile_radius)
	var first_barrier: PhantomBarrier
	var first_barrier_fraction := 2.0
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("phantom_barriers"):
			var barrier := node as PhantomBarrier
			if barrier == null or not barrier.is_active():
				continue
			var fraction := barrier.interception_fraction(global_position - BODY_OFFSET, next_position - BODY_OFFSET, projectile_radius)
			if fraction >= 0.0 and fraction < first_barrier_fraction:
				first_barrier = barrier
				first_barrier_fraction = fraction
	if first_barrier != null and (target_fraction < 0.0 or first_barrier_fraction <= target_fraction):
		var intercept_point := global_position.lerp(next_position, first_barrier_fraction)
		if navigation.is_segment_clear(global_position, intercept_point, projectile_radius) and first_barrier.absorb_projectile():
			global_position = intercept_point
			queue_free()
			return
	if target_fraction >= 0.0 and navigation.is_segment_clear(global_position, global_position.lerp(next_position, target_fraction), projectile_radius):
		global_position = target_center
		hit.emit(request, target)
		queue_free()
		return
	if not navigation.is_segment_clear(global_position, next_position, projectile_radius):
		queue_free()
		return
	global_position = next_position
	travelled += step
	if travelled >= max_distance:
		queue_free()

func _target_hit_fraction(center: Vector2, segment_start: Vector2, segment_end: Vector2, radius: float) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return 0.0 if segment_start.distance_to(center) <= radius else -1.0
	if segment_start.distance_squared_to(center) <= radius * radius:
		return 0.0
	# Solve against the infinite line first; clamping before the root moves
	# contact forward when the target center lies beyond this frame's endpoint.
	var projection := (center - segment_start).dot(segment) / length_squared
	var distance_squared := center.distance_squared_to(segment_start + segment * projection)
	if distance_squared > radius * radius:
		return -1.0
	var half_chord := sqrt(maxf(0.0, radius * radius - distance_squared) / length_squared)
	var entry := projection - half_chord
	var exit := projection + half_chord
	return maxf(0.0, entry) if entry <= 1.0 and exit >= 0.0 else -1.0

func _draw() -> void:
	draw_line(Vector2(-13, 0), Vector2(12, 0), Color("f6dfad"), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(5, -5), Vector2(5, 5)]), Color("d29a4a"))
