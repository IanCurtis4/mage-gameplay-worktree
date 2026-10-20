class_name WorldGeometerCast
extends WorldSkillCast
## Captured explicit intent; selection, support and grammar revalidate before canonical payment.
var element: StringName
var construction: WorldGeometerConstruction
var flight: Dictionary = {}
var _owner: WeakRef
var _generation := 0
func bind_owner(casting: GeometerCasting, token: StringName) -> void:
	_owner = weakref(casting)
	construction = casting.construction as WorldGeometerConstruction
	element = token
	_generation = construction.generation
func owner() -> GeometerCasting:
	return _owner.get_ref() as GeometerCasting if _owner != null else null
func destination() -> ExpeditionWorldPoint:
	return target().world_point() if is_instance_valid(target()) and target().world_motion != null else anchor()
func geometry_check(actor: PlayerActor) -> Dictionary:
	var common := super.geometry_check(actor)
	if not common["ok"]: return common
	var casting := owner()
	if not is_instance_valid(casting) or casting.is_queued_for_deletion() or casting.player != actor or casting.construction != construction or construction.generation != _generation: return failure(&"stale_construction")
	if skill_id != &"geometer_trace": return failure(&"spatial_recipe_pending")
	if not actor.is_geometer() or element not in GeometerGeometry.ELEMENTS: return failure(&"invalid_world_intent")
	if target() != null and (not is_instance_valid(target()) or not target().is_alive() or target() not in actors()): return failure(&"invalid_target")
	# A freed selected actor must not silently become a ground shot.
	if _target != null and not is_instance_valid(target()): return failure(&"invalid_target")
	var point := destination()
	if point == null: return failure(&"invalid_support")
	var geometry := actor.world_motion.geometry
	var placement := geometry.position_query(point,actor.world_motion.profile(),revision)
	if not placement["ok"]: return placement
	var grounded := geometry.query_attack({"geometry_rule_id":&"ground_connected","range":actor.skill_range(skill_id),"traversal":actor.world_motion.profile()},source(),point,revision)
	if not grounded["ok"]: return grounded
	if not grounded["data"]["hit"]: return failure(&"out_of_range_or_occluded")
	var radius := PlayerProjectile.DEFAULT_RADIUS
	var offset := Vector3.UP*maxf(0.0,(float(actor.world_motion.profile()["height"])-radius*2.0)*0.5)
	var target_offset := Vector3.UP*maxf(0.0,(float(target().world_motion.profile()["height"])-radius*2.0)*0.5) if is_instance_valid(target()) else offset
	var from := source().position+offset
	var goal := point.position+target_offset
	if from.distance_to(goal) > actor.skill_range(skill_id)+WorldGeometry.EPS: return failure(&"out_of_range_or_occluded")
	var body := {"radius":radius,"height":radius*2.0}
	var clear := geometry.sweep(from,goal,body,revision)
	if not clear["ok"]: return clear
	if clear["data"]["hit"]: return failure(&"out_of_range_or_occluded")
	if actor.is_inside_tree() and not EffectProcLedger.projectile_slots_available(actor.get_tree(),1): return failure(&"skill_unavailable")
	construction.set_actors(actors())
	var preview := construction.preview_world(point,element,actor.skill_rank(&"geometer_triangulation"))
	if not preview["ok"]:
		var rejected := failure(preview.get("error_code",&"invalid_construction"))
		rejected["reason"] = preview["reason"]
		return rejected
	flight = {"origin":source().to_data(),"offset":offset,"goal_offset":target_offset,"collider":body,"direction":(goal-from).normalized() if not goal.is_equal_approx(from) else Vector3.RIGHT,"range":actor.skill_range(skill_id)}
	return {"ok":true,"error_code":&"","data":{"point":point.to_data(),"element":element}}
