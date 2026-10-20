class_name WorldProjectileMotion
extends RefCounted
## Continuous logical cylinder sweep. Coordinates are never projected pixels.
var geometry: WorldGeometry
var position := Vector3.ZERO
var direction := Vector3.RIGHT
var stage_id := ""
var collider: Dictionary = {}
var travelled := 0.0
var max_distance := 0.0
var _configuration_revision := 0
var _excluded: Dictionary[int, bool] = {}

func configure(world: WorldGeometry, origin: ExpeditionWorldPoint, offset: Vector3, facing: Vector3, body: Dictionary, maximum_distance: float, revision: int) -> Dictionary:
	if world == null: return _failure(&"invalid_geometry")
	if revision != world.geometry_revision: return _failure(&"stale_geometry")
	if origin == null or not offset.is_finite() or not facing.is_finite() or facing.is_zero_approx() or not is_finite(maximum_distance) or maximum_distance <= 0.0: return _failure(&"invalid_projectile")
	var check := world.support_at(origin.surface_id, Vector2(origin.position.x,origin.position.z),revision)
	if not check["ok"] or check["data"]["point"] != origin.to_data(): return _failure(&"invalid_support")
	var start := world.sweep(origin.position+offset,origin.position+offset,body,revision)
	if not start["ok"]: return start
	if start["data"]["hit"]: return _failure(&"blocked_origin")
	geometry = world
	_configuration_revision = world.configuration_revision
	position = origin.position + offset
	stage_id = origin.stage_id
	direction = facing.normalized()
	collider = body.duplicate(true)
	max_distance = maximum_distance
	travelled = 0.0
	_excluded.clear()
	return {"ok":true,"error_code":&""}

func validate_targets(actors: Array[CombatActor]) -> Dictionary:
	for candidate_actor: Variant in actors:
		if not is_instance_valid(candidate_actor): continue
		var actor := candidate_actor as CombatActor
		if actor == null or not actor.is_alive(): continue
		if actor.world_motion == null or not actor.world_motion.is_current_world() or actor.world_motion.geometry != geometry or actor.world_point().stage_id != stage_id: return _failure(&"incompatible_target")
	return {"ok":true,"error_code":&""}

func peek(distance: float, actors: Array[CombatActor]) -> Dictionary:
	var previous_position := position; var previous_travelled := travelled; var previous_excluded := _excluded.duplicate()
	var result := contact(distance,actors)
	position = previous_position; travelled = previous_travelled; _excluded = previous_excluded
	return result

func contact(distance: float, actors: Array[CombatActor]) -> Dictionary:
	if geometry == null or not is_finite(distance) or distance < 0.0: return _failure(&"invalid_distance")
	if _configuration_revision != geometry.configuration_revision: return _failure(&"world_reconfigured")
	var valid := validate_targets(actors)
	if not valid["ok"]: return valid
	var step := minf(distance,maxf(0.0,max_distance-travelled))
	var finish := position + direction * step
	# An in-flight delivery always sweeps CURRENT geometry; a new wall can intercept it.
	var terrain := geometry.sweep(position,finish,collider,geometry.geometry_revision)
	if not terrain["ok"]: return terrain
	var data: Dictionary = terrain["data"]
	var fraction := float(data["fraction"]) if data["hit"] else 2.0
	var victim: CombatActor
	for candidate_actor: Variant in actors:
		if not is_instance_valid(candidate_actor): continue
		var actor := candidate_actor as CombatActor
		if actor == null or not actor.is_alive() or _excluded.has(actor.get_instance_id()): continue
		var body := actor.world_motion.profile()
		var candidate := cylinder_fraction(position,finish,actor.world_point().position,float(body["radius"])+float(collider["radius"]),float(body["height"]),float(collider["height"]))
		if candidate < 0.0: continue
		# Preserve the legacy owned-projectile body/terrain tie policy and stable actor IDs.
		if candidate < fraction or (is_equal_approx(candidate,fraction) and (victim == null or actor.get_instance_id() < victim.get_instance_id())):
			fraction = candidate
			victim = actor
	var consumed := step * minf(1.0,fraction)
	position += direction * consumed
	travelled += consumed
	if victim != null: _excluded[victim.get_instance_id()] = true
	return {"ok":true,"error_code":&"","geometry_revision":geometry.geometry_revision,"data":{"actor":victim,"terrain":victim == null and data["hit"],"distance":consumed,"fraction":fraction,"position":position,"volume_id":data["volume_id"] if victim == null else "","exhausted":travelled >= max_distance-WorldGeometry.EPS}}

static func cylinder_fraction(from: Vector3, to: Vector3, feet: Vector3, radius: float, height: float, moving_height: float) -> float:
	# Minkowski sum of vertical cylinders: radial quadratic intersected with a y interval.
	var delta := to-from
	var offset := Vector2(from.x-feet.x,from.z-feet.z)
	var horizontal := Vector2(delta.x,delta.z)
	var low := 0.0
	var high := 1.0
	var a := horizontal.length_squared()
	var c := offset.length_squared()-radius*radius
	if a <= WorldGeometry.EPS*WorldGeometry.EPS:
		if c > 0.0: return -1.0
	else:
		var b := 2.0*offset.dot(horizontal)
		var discriminant := b*b-4.0*a*c
		if discriminant < 0.0: return -1.0
		var root := sqrt(discriminant)
		low = maxf(low,(-b-root)/(2.0*a))
		high = minf(high,(-b+root)/(2.0*a))
	var bottom := feet.y-moving_height
	var top := feet.y+height
	if absf(delta.y) <= WorldGeometry.EPS:
		if from.y < bottom or from.y > top: return -1.0
	else:
		var first := (bottom-from.y)/delta.y
		var last := (top-from.y)/delta.y
		low = maxf(low,minf(first,last))
		high = minf(high,maxf(first,last))
	return low if low <= high else -1.0

func _failure(code: StringName) -> Dictionary:
	return {"ok":false,"error_code":code,"data":{}}
