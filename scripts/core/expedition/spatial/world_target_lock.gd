class_name WorldTargetLock
extends RefCounted
## An emitted locked packet follows one body. It never becomes a fresh cast/LoS query.
var geometry: WorldGeometry
var _configuration_revision := 0
var _stage_id := ""
var _target: WeakRef

func configure(caster: CombatActor, target: CombatActor, maximum_range: float, revision: int) -> Dictionary:
	if geometry != null: return {"ok":false,"error_code":&"already_bound"}
	var admission := WorldLockedAction.new()
	var result := admission.configure(caster,target,maximum_range,false,revision)
	if not result["ok"]: return result
	geometry = caster.world_motion.geometry
	_configuration_revision = geometry.configuration_revision
	_stage_id = target.world_point().stage_id
	_target = weakref(target)
	return validate()

func validate() -> Dictionary:
	if geometry == null or _configuration_revision != geometry.configuration_revision: return {"ok":false,"error_code":&"world_reconfigured"}
	var actor := _target.get_ref() as CombatActor if _target != null else null
	if not is_instance_valid(actor) or not actor.is_alive(): return {"ok":false,"error_code":&"invalid_target"}
	if actor.world_motion == null or not actor.world_motion.is_current_world() or actor.world_motion.geometry != geometry or actor.world_point().stage_id != _stage_id: return {"ok":false,"error_code":&"world_reconfigured"}
	return geometry.position_query(actor.world_point(),actor.world_motion.profile(),geometry.geometry_revision)

func point() -> ExpeditionWorldPoint:
	if not validate()["ok"]: return null
	return (_target.get_ref() as CombatActor).world_point()

func paused() -> bool:
	var actor := _target.get_ref() as CombatActor if _target != null else null
	return is_instance_valid(actor) and actor.is_inside_tree() and actor.get_tree().paused
