class_name WorldSkillCast
extends RefCounted
## One captured intention. Geometry/rank are validated before the canonical payment.
const TARGETED: Array[StringName] = [&"brutal_strike",&"berserker_rupture",&"berserker_execution",&"berserker_breath_steal",&"berserker_pursuit_cut",&"provoke",&"hunter_mark",&"sentinel_observe",&"fire_spear",&"ice_spear",&"lightning",&"spiritualist_soul_drain",&"spiritualist_procession"]
const DIRECTIONAL: Array[StringName] = [&"slash",&"defender_counterstroke",&"defender_line_lock",&"defender_riposte",&"concentrated_rage",&"fireball",&"electric_discharge",&"double_shot",&"piercing_arrow",&"slowing_arrow"]
const POINT_AREAS: Array[StringName] = [&"arrow_rain",&"snare_trap",&"explosive_trap",&"elementalist_flame_burst",&"spiritualist_spectral_veil"]
const SELF_AREAS: Array[StringName] = [&"elementalist_glacial_ring",&"elementalist_tri_nova"]
const SELF_STATE: Array[StringName] = [&"perseverance",&"fury",&"extended_aim",&"sentinel_absolute_focus"]
const PROJECTILES: Array[StringName] = [&"fireball",&"fire_spear",&"ice_spear",&"lightning",&"electric_discharge",&"double_shot",&"piercing_arrow",&"slowing_arrow"]
var skill_id: StringName
var revision := 0
var configuration_revision := 0
var composition_revision := 0
var rank_context: Dictionary = {}
var projectiles: Array[Dictionary] = []
var committed := false
var action_kind := -1
var _source: ExpeditionWorldPoint
var _anchor: ExpeditionWorldPoint
var _direction := Vector3.RIGHT
var _target: WeakRef
var _actors: Array[WeakRef] = []

static func supports(skill: StringName) -> bool:
	return skill in TARGETED or skill in DIRECTIONAL or skill in POINT_AREAS or skill in SELF_AREAS or skill in SELF_STATE

func capture(actor: PlayerActor, skill: StringName, anchor: ExpeditionWorldPoint, facing: Vector3, victim: CombatActor, actors: Array[CombatActor], geometry_revision: int, selected_rank: Dictionary) -> void:
	skill_id = skill
	revision = geometry_revision
	configuration_revision = actor.world_motion.geometry.configuration_revision
	composition_revision = actor.run_state.composition_revision()
	_source = actor.world_point()
	_anchor = ExpeditionWorldPoint.create(anchor.stage_id,anchor.surface_id,anchor.position) if anchor != null else null
	_direction = facing.normalized()
	_target = weakref(victim) if is_instance_valid(victim) else null
	rank_context = selected_rank.duplicate(true)
	set_actors(actors)

func set_actors(actors: Array[CombatActor]) -> void:
	_actors.clear()
	for value: Variant in actors:
		if is_instance_valid(value): _actors.append(weakref(value))
func actors() -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	for reference: WeakRef in _actors:
		var actor := reference.get_ref() as CombatActor
		if is_instance_valid(actor) and actor.is_alive(): result.append(actor)
	return result
func target() -> CombatActor:
	return _target.get_ref() as CombatActor if _target != null else null
func anchor() -> ExpeditionWorldPoint:
	var point := _source if skill_id in SELF_AREAS or skill_id in SELF_STATE else _anchor
	return ExpeditionWorldPoint.create(point.stage_id,point.surface_id,point.position) if point != null else null
func direction(actor: PlayerActor) -> Vector3:
	if skill_id in TARGETED and is_instance_valid(target()) and target().world_motion != null:
		var offset := target().world_point().position-actor.world_point().position
		return offset.normalized() if not offset.is_zero_approx() else _direction
	return _direction
func source() -> ExpeditionWorldPoint:
	return ExpeditionWorldPoint.create(_source.stage_id,_source.surface_id,_source.position)

func geometry_check(actor: PlayerActor) -> Dictionary:
	if actor.run_state.composition_revision() != composition_revision: return failure(&"stale_build")
	var world := actor.world_motion.geometry
	if not actor.world_motion.is_current_world() or configuration_revision != world.configuration_revision: return failure(&"world_reconfigured")
	if revision != world.geometry_revision: return failure(&"stale_geometry")
	if actor.world_point().surface_id != _source.surface_id or actor.world_point().position.distance_to(_source.position) > PlayerActor.MOVEMENT_EPSILON: return failure(&"caster_moved")
	if not world.position_query(_source,actor.world_motion.profile(),revision)["ok"]: return failure(&"invalid_support")
	for candidate: CombatActor in actors():
		if candidate.world_motion == null or not candidate.world_motion.is_current_world() or candidate.world_motion.geometry != world: return failure(&"incompatible_target")
	if skill_id in TARGETED:
		if not is_instance_valid(target()) or not target().is_alive() or not actor.world_can_reach(target(),actor.skill_range(skill_id)): return failure(&"invalid_target")
	elif skill_id in POINT_AREAS:
		var placement := world.position_query(_anchor,actor.world_motion.profile(),revision)
		if not placement["ok"]: return placement
		var propagation := world.query_attack({"geometry_rule_id":&"ground_connected","range":actor.skill_range(skill_id),"traversal":actor.world_motion.profile()},_source,_anchor,revision)
		if not propagation["ok"]: return propagation
		if not propagation["data"]["hit"]: return failure(&"out_of_range_or_occluded")
	return {"ok":true,"error_code":&""}

static func failure(code: StringName) -> Dictionary:
	return {"ok":false,"error_code":code,"data":{}}
