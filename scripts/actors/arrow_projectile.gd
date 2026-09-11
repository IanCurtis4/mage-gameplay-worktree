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
	if target == null or not is_instance_valid(target) or not target.is_alive() or travelled >= max_distance:
		queue_free()
		return
	var step := minf(speed * delta, max_distance - travelled)
	var next_position := global_position + direction * step
	if navigation == null or not navigation.is_segment_clear(global_position, next_position, projectile_radius):
		queue_free()
		return
	var target_center := target.global_position + BODY_OFFSET
	if _distance_to_segment(target_center, global_position, next_position) <= target.collision_radius + projectile_radius:
		global_position = target_center
		hit.emit(request, target)
		queue_free()
		return
	global_position = next_position
	travelled += step
	if travelled >= max_distance:
		queue_free()

func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(segment_start)
	var projection := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_start + segment * projection)

func _draw() -> void:
	draw_line(Vector2(-13, 0), Vector2(12, 0), Color("f6dfad"), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(5, -5), Vector2(5, 5)]), Color("d29a4a"))
