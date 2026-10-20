class_name SentinelAreaProjectile
extends SentinelProjectile
## The first body/terrain contact opens one net. Geometry stays world-space.

signal burst(center: Vector2, damage_request: DamageRequest, tuning: Dictionary)
signal world_burst(area: WorldEffectArea, center: Vector3, damage_request: DamageRequest, tuning: Dictionary)

var world_origin: WorldEffectArea
var _world_endpoint: ExpeditionWorldPoint
var _world_profile: Dictionary = {}
var _world_zero_delivery := false

func bind_world_delivery(world: WorldGeometry, spec: Dictionary, traversal: Dictionary, destination: ExpeditionWorldPoint) -> Dictionary:
	if world_origin != null: return {"ok":false,"error_code":&"already_bound"}
	var origin: Dictionary = spec["origin"]
	var source := ExpeditionWorldPoint.create(origin["stage_id"],origin["surface_id"],origin["position"])
	var area := WorldEffectArea.new()
	var valid := area.configure(world,source,traversal,&"direct_volume",world.geometry_revision)
	if not valid["ok"]: return valid
	var zero := request.skill_id == &"sentinel_net_shot" and float(spec["range"]) <= WorldGeometry.EPS
	if not zero:
		valid = bind_world_flight(world,source,spec["offset"],spec["direction"],spec["collider"],world.geometry_revision)
		if not valid["ok"]: return valid
	world_origin = area
	_world_profile = traversal.duplicate(true)
	_world_endpoint = ExpeditionWorldPoint.create(destination.stage_id,destination.surface_id,destination.position) if destination != null else null
	_world_zero_delivery = zero
	return {"ok":true,"error_code":&""}

func _advance_world_area(delta: float) -> void:
	if not world_origin.is_current_world(): world_failure = &"world_reconfigured"; queue_free(); return
	if _world_zero_delivery: _open_world(null,false); return
	var candidates: Array[CombatActor] = targets
	var distance := INF
	if homing:
		if not is_instance_valid(target) or not target.is_alive(): queue_free(); return
		if target.world_motion == null or not target.world_motion.is_current_world() or target.world_motion.geometry != world_flight.geometry: world_failure = &"incompatible_target"; queue_free(); return
		candidates = [target]
		var center := target.world_point().position+Vector3.UP*(float(target.world_motion.profile()["height"])-float(world_flight.collider["height"]))*0.5
		var heading := center-world_flight.position
		distance = heading.length()
		if not heading.is_zero_approx(): world_flight.direction = heading.normalized()
	else:
		var destination := _world_endpoint.position+Vector3.UP*(float(_world_profile["height"])-float(world_flight.collider["height"]))*0.5
		distance = world_flight.position.distance_to(destination)
	var step := minf(speed*delta,distance)
	var contact := world_flight.contact(step,candidates)
	if not contact["ok"]: world_failure = contact["error_code"]; queue_free(); return
	travelled = world_flight.travelled
	var data: Dictionary = contact["data"]
	var victim := data["actor"] as CombatActor
	if victim != null or data["terrain"] or distance <= step+WorldGeometry.EPS:
		_open_world(victim,data["terrain"])
	elif data["exhausted"]: queue_free()

func _open_world(victim: CombatActor, terrain: bool) -> void:
	if opened: return
	opened = true # Claim this delivery before damage/death callbacks can reenter.
	var area := world_origin
	var center := world_origin.anchor().position
	if request.skill_id == &"sentinel_net_shot":
		var anchor: ExpeditionWorldPoint
		if is_instance_valid(victim): anchor = victim.world_point()
		elif _world_zero_delivery or not terrain: anchor = _world_endpoint
		else:
			var exact := world_origin.geometry.ground_line_point_at(world_origin.anchor(),Vector2(world_flight.position.x,world_flight.position.z),_world_profile,world_origin.geometry.geometry_revision)
			if exact["ok"]:
				var data: Dictionary = exact["data"]["point"]
				anchor = ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
		if anchor == null: world_failure = &"unsupported_contact"; queue_free(); return
		area = WorldEffectArea.new()
		if not area.configure(world_origin.geometry,anchor,_world_profile,&"ground_connected",world_origin.geometry.geometry_revision)["ok"]: world_failure = &"unsupported_contact"; queue_free(); return
		center = anchor.position
	else: center = world_flight.position+Vector3.UP*float(world_flight.collider["height"])*0.5
	world_burst.emit(area,center,request.copy(),payload.duplicate(true))
	queue_free()


var endpoint := Vector2.ZERO
var payload: Dictionary = {}
var opened := false

func _process(delta: float) -> void:
	if opened or is_queued_for_deletion() or (is_inside_tree() and get_tree().paused) or not is_finite(delta) or delta <= 0.0:
		return
	if request == null:
		queue_free()
		return
	if world_origin != null:
		_advance_world_area(delta)
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
