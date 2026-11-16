class_name KitWorldSkillCast
extends WorldSkillCast
## E09 C1.4: one captured world intention for a kit skill. The WorldSkillCast
## lists stay closed for the existing identities; here the targeting comes from
## the kit SkillDefinition (SINGLE_TARGET, DIRECTION, POINT or SELF). Geometry,
## stale-build/world checks and payment order are the inherited ones.

var targeting: int = SkillDefinition.Targeting.DIRECTION

func capture_kit(actor: PlayerActor, skill: StringName, anchor_point: ExpeditionWorldPoint, facing: Vector3, victim: CombatActor, candidates: Array[CombatActor], geometry_revision: int, selected_rank: Dictionary) -> void:
	var definition := ClassKitRegistry.skill_definition(skill)
	targeting = definition.targeting if definition != null else SkillDefinition.Targeting.DIRECTION
	capture(actor, skill, anchor_point, facing, victim, candidates, geometry_revision, selected_rank)

func anchor() -> ExpeditionWorldPoint:
	var point := _source if targeting == SkillDefinition.Targeting.SELF else _anchor
	return ExpeditionWorldPoint.create(point.stage_id, point.surface_id, point.position) if point != null else null

func direction(actor: PlayerActor) -> Vector3:
	if targeting == SkillDefinition.Targeting.SINGLE_TARGET and is_instance_valid(target()) and target().world_motion != null:
		var offset := target().world_point().position - actor.world_point().position
		return offset.normalized() if not offset.is_zero_approx() else _direction
	return _direction

func geometry_check(actor: PlayerActor) -> Dictionary:
	if actor.run_state.composition_revision() != composition_revision: return failure(&"stale_build")
	var world := actor.world_motion.geometry
	if not actor.world_motion.is_current_world() or configuration_revision != world.configuration_revision: return failure(&"world_reconfigured")
	if revision != world.geometry_revision: return failure(&"stale_geometry")
	if actor.world_point().surface_id != _source.surface_id or actor.world_point().position.distance_to(_source.position) > PlayerActor.MOVEMENT_EPSILON: return failure(&"caster_moved")
	if not world.position_query(_source, actor.world_motion.profile(), revision)["ok"]: return failure(&"invalid_support")
	for candidate: CombatActor in actors():
		if candidate.world_motion == null or not candidate.world_motion.is_current_world() or candidate.world_motion.geometry != world: return failure(&"incompatible_target")
	if targeting == SkillDefinition.Targeting.SINGLE_TARGET:
		if not is_instance_valid(target()) or not target().is_alive() or not actor.world_can_reach(target(), actor.skill_range(skill_id)): return failure(&"invalid_target")
	elif targeting == SkillDefinition.Targeting.POINT:
		if _anchor == null: return failure(&"invalid_world_intent")
		var placement := world.position_query(_anchor, actor.world_motion.profile(), revision)
		if not placement["ok"]: return placement
		var propagation := world.query_attack({"geometry_rule_id": &"ground_connected", "range": actor.skill_range(skill_id), "traversal": actor.world_motion.profile()}, _source, _anchor, revision)
		if not propagation["ok"]: return propagation
		if not propagation["data"]["hit"]: return failure(&"out_of_range_or_occluded")
	return {"ok": true, "error_code": &""}
