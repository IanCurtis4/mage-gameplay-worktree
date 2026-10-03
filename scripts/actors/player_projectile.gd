class_name PlayerProjectile
extends Node2D
## Shared continuous collision for player-owned directional and homing projectiles.

signal hit(request: DamageRequest, target: CombatActor)

const BODY_OFFSET := Vector2(0, -18)

var request: DamageRequest
var target: CombatActor
var targets: Array[CombatActor] = []
var navigation: ArenaNavigation
var direction := Vector2.RIGHT
var speed := 680.0
var max_distance := 700.0
var projectile_radius := 4.0
var travelled := 0.0
var homing := false
var max_hits := 1
var color := Color("f6dfad")
var _hit_actor_ids: Dictionary[int, bool] = {}
var geometer_field: GeometerWallField
var geometer_conduction_endpoint := Vector2.INF
var geometer_resume_direction := Vector2.RIGHT
var geometer_transport_identity := 0
var geometer_fire_request: DamageRequest
var geometer_bonus_request: DamageRequest
var geometer_payload_identity := 0

func start_geometer_conduction(endpoint: Vector2, identity: int) -> void:
	geometer_resume_direction = direction
	geometer_conduction_endpoint = endpoint
	geometer_transport_identity = identity
	if homing:
		targets = [target] if is_instance_valid(target) else []
	homing = false

func configure_directional(
	damage_request: DamageRequest,
	origin: Vector2,
	facing: Vector2,
	potential_targets: Array[CombatActor],
	arena_navigation: ArenaNavigation,
	speed_value: float,
	range_value: float,
	hit_limit: int = 1,
	visual_color: Color = Color("f6dfad")
) -> void:
	request = damage_request
	targets = potential_targets.duplicate()
	navigation = arena_navigation
	global_position = origin
	direction = facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
	speed = speed_value
	max_distance = range_value
	max_hits = maxi(1, hit_limit)
	color = visual_color
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
	max_hits = 1
	homing = true
	color = visual_color
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if is_queued_for_deletion() or (is_inside_tree() and get_tree().paused) or not is_finite(delta) or delta <= 0.0:
		return
	if request == null or travelled >= max_distance:
		queue_free()
		return
	if geometer_conduction_endpoint.is_finite() and (geometer_field == null or not geometer_field.conduction_active(geometer_transport_identity)):
		geometer_conduction_endpoint = Vector2.INF
		direction = geometer_resume_direction
	if homing:
		if target == null or not is_instance_valid(target) or not target.is_alive():
			queue_free()
			return
		direction = global_position.direction_to(target.global_position + BODY_OFFSET)
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
	rotation = direction.angle()
	var remaining_step := minf(speed * delta, max_distance - travelled)
	while remaining_step > 0.0:
		var segment_step := remaining_step
		if geometer_conduction_endpoint.is_finite():
			var distance := global_position.distance_to(geometer_conduction_endpoint)
			if distance <= 0.001:
				geometer_conduction_endpoint = Vector2.INF
				direction = geometer_resume_direction
			else:
				direction = global_position.direction_to(geometer_conduction_endpoint)
				segment_step = minf(segment_step, distance)
		rotation = direction.angle()
		var segment_start := global_position
		var segment_end := segment_start + direction * segment_step
		var wall_fraction := _wall_fraction(segment_start, segment_end)
		var impact := _nearest_impact(segment_start, segment_end)
		var victim: CombatActor = impact.get("actor") as CombatActor
		var victim_fraction: float = impact.get("fraction", 2.0)
		var contact := geometer_field.owned_contact(self, segment_start, segment_end) if geometer_field != null else {}
		if not contact.is_empty() and float(contact["fraction"]) < minf(wall_fraction, victim_fraction):
			var distance := segment_step * float(contact["fraction"])
			global_position = segment_start.lerp(segment_end, float(contact["fraction"]))
			travelled += distance
			remaining_step -= distance
			geometer_field.apply_owned_contact(self)
			continue
		if victim != null and victim_fraction <= wall_fraction:
			var distance_to_victim := segment_step * victim_fraction
			global_position = segment_start.lerp(segment_end, victim_fraction)
			travelled += distance_to_victim
			remaining_step -= distance_to_victim
			_hit_actor_ids[victim.get_instance_id()] = true
			_prepare_impact(victim)
			hit.emit(request, victim)
			if geometer_field != null:
				geometer_field.projectile_impact(self, victim)
			if is_queued_for_deletion():
				return
			if _hit_actor_ids.size() >= max_hits:
				queue_free()
				return
			continue
		if wall_fraction <= 1.0:
			global_position = segment_start.lerp(segment_end, wall_fraction)
			travelled += segment_step * wall_fraction
			queue_free()
			return
		global_position = segment_end
		travelled += segment_step
		remaining_step = maxf(0.0, remaining_step - segment_step)
	if travelled >= max_distance:
		queue_free()

func _nearest_impact(from: Vector2, to: Vector2) -> Dictionary:
	var victim: CombatActor
	var victim_fraction := 2.0
	var candidates: Array[CombatActor] = []
	if homing:
		candidates.append(target)
	else:
		candidates = targets
	for actor: CombatActor in candidates:
		if actor == null or not is_instance_valid(actor) or not actor.is_alive() or _hit_actor_ids.has(actor.get_instance_id()):
			continue
		var fraction := _actor_fraction(actor, from, to)
		if fraction < 0.0:
			continue
		if fraction < victim_fraction or (is_equal_approx(fraction, victim_fraction) and (victim == null or actor.get_instance_id() < victim.get_instance_id())):
			victim = actor
			victim_fraction = fraction
	return {"actor": victim, "fraction": victim_fraction}

func _prepare_impact(victim: CombatActor) -> void:
	request.target_id = victim.get_instance_id()

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
	draw_line(Vector2(-13, 0), Vector2(12, 0), color, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(5, -5), Vector2(5, 5)]), Color("d29a4a"))
