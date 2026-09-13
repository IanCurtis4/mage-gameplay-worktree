class_name MageProjectile
extends Node2D
## Continuous projectile collision. Fireball resolves the first enemy/wall contact;
## spears home on one runtime target but are still stopped by arena geometry.

signal hit(request: DamageRequest, target: CombatActor)

const BODY_OFFSET := Vector2(0, -18)

var request: DamageRequest
var target: CombatActor
var targets: Array[CombatActor] = []
var navigation: ArenaNavigation
var direction := Vector2.RIGHT
var speed := 680.0
var max_distance := 700.0
var projectile_radius := 6.0
var travelled := 0.0
var homing := false
var color := Color("ff793d")

func configure_directional(
	damage_request: DamageRequest,
	origin: Vector2,
	facing: Vector2,
	potential_targets: Array[CombatActor],
	arena_navigation: ArenaNavigation,
	speed_value: float,
	range_value: float
) -> void:
	request = damage_request
	targets = potential_targets.duplicate()
	navigation = arena_navigation
	global_position = origin
	direction = facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
	speed = speed_value
	max_distance = range_value
	homing = false
	rotation = direction.angle()
	process_mode = Node.PROCESS_MODE_PAUSABLE

func configure_homing(
	damage_request: DamageRequest,
	target_actor: CombatActor,
	origin: Vector2,
	arena_navigation: ArenaNavigation,
	speed_value: float,
	range_value: float,
	visual_color: Color
) -> void:
	request = damage_request
	target = target_actor
	navigation = arena_navigation
	global_position = origin
	speed = speed_value
	max_distance = range_value
	homing = true
	color = visual_color
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if request == null or travelled >= max_distance:
		queue_free()
		return
	if homing:
		if target == null or not is_instance_valid(target) or not target.is_alive():
			queue_free()
			return
		direction = global_position.direction_to(target.global_position + BODY_OFFSET)
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
	rotation = direction.angle()
	var step := minf(speed * delta, max_distance - travelled)
	var next_position := global_position + direction * step
	var wall_fraction := _wall_fraction(global_position, next_position)
	var victim: CombatActor
	var victim_fraction := 2.0
	if homing:
		victim = target
		victim_fraction = _actor_fraction(victim, global_position, next_position)
	else:
		for actor: CombatActor in targets:
			if actor == null or not is_instance_valid(actor) or not actor.is_alive():
				continue
			var fraction := _actor_fraction(actor, global_position, next_position)
			if fraction >= 0.0 and fraction < victim_fraction:
				victim = actor
				victim_fraction = fraction
	if victim != null and victim_fraction >= 0.0 and victim_fraction <= wall_fraction:
		global_position = global_position.lerp(next_position, victim_fraction)
		_prepare_impact(victim)
		hit.emit(request, victim)
		queue_free()
		return
	if wall_fraction <= 1.0:
		global_position = global_position.lerp(next_position, wall_fraction)
		queue_free()
		return
	global_position = next_position
	travelled += step
	if travelled >= max_distance:
		queue_free()

func _prepare_impact(victim: CombatActor) -> void:
	request.target_id = victim.get_instance_id()
	if request.skill_id == &"fireball" and victim.is_burning():
		request.force_critical = true
	elif request.skill_id == &"fire_spear" and victim.is_burning():
		request.base_damage *= 1.5

func _wall_fraction(from: Vector2, to: Vector2) -> float:
	if navigation == null or navigation.is_segment_clear(from, to, projectile_radius):
		return 2.0
	var low := 0.0
	var high := 1.0
	for _iteration: int in range(20):
		var middle := (low + high) * 0.5
		if navigation.is_segment_clear(from, from.lerp(to, middle), projectile_radius):
			low = middle
		else:
			high = middle
	return low

func _actor_fraction(actor: CombatActor, from: Vector2, to: Vector2) -> float:
	if actor == null or not is_instance_valid(actor) or not actor.is_alive():
		return -1.0
	var center := actor.global_position + BODY_OFFSET
	var segment := to - from
	var combined_radius := actor.collision_radius + projectile_radius
	var offset := from - center
	var a := segment.length_squared()
	if a <= 0.0001:
		return 0.0 if offset.length() <= combined_radius else -1.0
	var b := 2.0 * offset.dot(segment)
	var c := offset.length_squared() - combined_radius * combined_radius
	if c <= 0.0:
		return 0.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var root := sqrt(discriminant)
	var near_fraction := (-b - root) / (2.0 * a)
	var far_fraction := (-b + root) / (2.0 * a)
	if near_fraction >= 0.0 and near_fraction <= 1.0:
		return near_fraction
	if far_fraction >= 0.0 and far_fraction <= 1.0:
		return 0.0
	return -1.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, projectile_radius + 2.0, Color(color, 0.25))
	draw_circle(Vector2.ZERO, projectile_radius, color)
	draw_line(Vector2(-15, 0), Vector2(-5, 0), Color(color, 0.45), 3.0)
