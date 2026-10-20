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
var geometer_field: GeometerWallField
var world_flight: WorldProjectileMotion
var world_failure: StringName = &""

func bind_world_flight(world: WorldGeometry, origin: ExpeditionWorldPoint, offset: Vector3, facing: Vector3, collider: Dictionary, revision: int) -> Dictionary:
	if world_flight != null: return {"ok":false,"error_code":&"already_bound"}
	if geometer_field != null and not geometer_field.supports_world(world): return {"ok":false,"error_code":&"spatial_interceptor_required"}
	var flight := WorldProjectileMotion.new()
	var result := flight.configure(world,origin,offset,facing,collider,max_distance,revision)
	if not result["ok"]: return result
	result = flight.validate_targets([target])
	if result["ok"]: world_flight = flight
	return result

func _advance_world_flight(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_alive(): queue_free(); return
	if geometer_field != null and not geometer_field.supports_world(world_flight.geometry): world_failure = &"spatial_interceptor_required"; queue_free(); return
	var step := minf(speed*delta,max_distance-world_flight.travelled)
	var start := world_flight.position
	var finish := start+world_flight.direction*step
	var impact := world_flight.contact(step,[target])
	if not impact["ok"]: world_failure = impact["error_code"]; queue_free(); return
	var data: Dictionary = impact["data"]
	var first_fraction := minf(1.0,float(data["fraction"]))
	var shielded := target as PlayerActor
	var shield := shielded.world_shield_interception_fraction(start,finish,world_flight.collider) if shielded != null else -1.0
	var barrier_hit: PhantomBarrier
	var barrier_fraction := 2.0
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("phantom_barriers"):
			var barrier := node as PhantomBarrier
			if barrier == null or not barrier.is_active(): continue
			if barrier.world_volume == null: world_failure = &"spatial_interceptor_required"; queue_free(); return
			var fraction := barrier.world_interception_fraction(start,finish,world_flight.collider,world_flight.geometry)
			if fraction >= 0.0 and (fraction < barrier_fraction or (is_equal_approx(fraction,barrier_fraction) and (barrier_hit == null or barrier.get_instance_id() < barrier_hit.get_instance_id()))): barrier_hit = barrier; barrier_fraction = fraction
	var terrain_limit := float(data["fraction"]) if data["terrain"] else 2.0
	var contact := geometer_field.hostile_world_contact(self,start,finish) if geometer_field != null else {}
	var fraction := float(contact.get("fraction",2.0))
	if not contact.is_empty() and fraction <= first_fraction and fraction < terrain_limit and (shield < 0 or fraction < shield) and fraction < barrier_fraction:
		world_flight.position = start.lerp(finish,fraction); world_flight.travelled = travelled+step*fraction; travelled = world_flight.travelled
		geometer_field.intercept_hostile(Vector2(world_flight.position.x,world_flight.position.z),request.context)
		queue_free(); return
	if shield >= 0.0 and shield <= first_fraction and shield <= barrier_fraction and shield < terrain_limit and shielded.absorb_shield_projectile():
		world_flight.position = start.lerp(finish,shield)
		world_flight.travelled = travelled+step*shield
		travelled = world_flight.travelled
		queue_free(); return
	if barrier_hit != null and barrier_fraction <= first_fraction and barrier_fraction < terrain_limit and (shield < 0.0 or barrier_fraction < shield) and barrier_hit.absorb_projectile():
		world_flight.position = start.lerp(finish,barrier_fraction)
		world_flight.travelled = travelled+step*barrier_fraction
		travelled = world_flight.travelled
		queue_free(); return
	travelled = world_flight.travelled
	if data["actor"] != null:
		request.target_id = target.get_instance_id()
		hit.emit(request,target)
		queue_free(); return
	if data["terrain"] or data["exhausted"]: queue_free()


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
	if is_queued_for_deletion() or (is_inside_tree() and get_tree().paused) or not is_finite(delta) or delta <= 0.0:
		return
	if world_flight != null:
		_advance_world_flight(delta)
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
	var shielded_player := target as PlayerActor
	var shield_fraction := shielded_player.shield_interception_fraction(global_position, next_position, projectile_radius) if shielded_player != null else -1.0
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
	var geometer_contact := geometer_field.hostile_contact(self, global_position, next_position) if geometer_field != null else {}
	if not geometer_contact.is_empty():
		var fraction: float = geometer_contact["fraction"]
		if (target_fraction < 0.0 or fraction <= target_fraction) and (shield_fraction < 0.0 or fraction < shield_fraction) and fraction < first_barrier_fraction:
			var point := global_position.lerp(next_position, fraction)
			if navigation.is_segment_clear(global_position, point, projectile_radius):
				travelled += step * fraction
				global_position = point
				geometer_field.intercept_hostile(point - BODY_OFFSET, request.context)
				queue_free()
				return
	if shield_fraction >= 0.0 and (target_fraction < 0.0 or shield_fraction <= target_fraction) and shield_fraction <= first_barrier_fraction:
		var shield_point := global_position.lerp(next_position, shield_fraction)
		if navigation.is_segment_clear(global_position, shield_point, projectile_radius) and shielded_player.absorb_shield_projectile():
			global_position = shield_point
			queue_free()
			return
	if first_barrier != null and (target_fraction < 0.0 or first_barrier_fraction <= target_fraction) and (shield_fraction < 0.0 or first_barrier_fraction < shield_fraction):
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
