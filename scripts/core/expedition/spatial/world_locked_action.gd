class_name WorldLockedAction
extends RefCounted
## Shared spatial guard for existing finite channels/locked schedules.
var _caster: WeakRef
var _target: WeakRef
var _origin: ExpeditionWorldPoint
var _world: WorldGeometry
var _configuration_revision := 0
var _maximum_range := 0.0
var _stationary := false

func configure(caster: CombatActor, target: CombatActor, maximum_range: float, stationary: bool, revision: int) -> Dictionary:
	if not is_instance_valid(caster) or not is_instance_valid(target) or caster.world_motion == null or target.world_motion == null or not is_finite(maximum_range) or maximum_range < 0.0: return _failure(&"invalid_locked_action")
	if not caster.world_motion.is_current_world() or not target.world_motion.is_current_world(): return _failure(&"world_reconfigured")
	if caster.world_motion.geometry.geometry_revision != revision: return _failure(&"stale_geometry")
	_caster = weakref(caster)
	_target = weakref(target)
	_world = caster.world_motion.geometry
	_configuration_revision = _world.configuration_revision
	_origin = caster.world_point()
	_maximum_range = maximum_range
	_stationary = stationary
	return validate()

func paused() -> bool:
	var caster := _caster.get_ref() as CombatActor if _caster != null else null
	return is_instance_valid(caster) and caster.is_inside_tree() and caster.get_tree().paused

func validate() -> Dictionary:
	var caster := _caster.get_ref() as CombatActor if _caster != null else null
	var target := _target.get_ref() as CombatActor if _target != null else null
	if _world == null or _configuration_revision != _world.configuration_revision: return _failure(&"world_reconfigured")
	if not is_instance_valid(caster) or not caster.is_alive() or caster.world_motion == null or not caster.world_motion.is_current_world(): return _failure(&"invalid_caster")
	if not is_instance_valid(target) or not target.is_alive() or target.world_motion == null or not target.world_motion.is_current_world() or target.world_motion.geometry != _world: return _failure(&"invalid_target")
	if _stationary:
		if caster.is_rooted() or caster.is_stunned() or caster.is_feared(): return _failure(&"caster_controlled")
		if caster.world_point().surface_id != _origin.surface_id or caster.world_point().position.distance_to(_origin.position) > PlayerActor.MOVEMENT_EPSILON: return _failure(&"caster_moved")
	if not caster.world_can_reach(target,_maximum_range): return _failure(&"out_of_range_or_occluded")
	return {"ok":true,"error_code":&""}

func _failure(code: StringName) -> Dictionary:
	return {"ok":false,"error_code":code}
