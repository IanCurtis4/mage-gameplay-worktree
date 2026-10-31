class_name WorldEffectArea
extends RefCounted
## Captured, copied surface anchor for ground effects and explicit aerial volumes.
var geometry: WorldGeometry
var _anchor: ExpeditionWorldPoint
var _profile: Dictionary = {}
var _rule: StringName = &"ground_connected"
var _configuration_revision := 0

func configure(world: WorldGeometry, anchor: ExpeditionWorldPoint, traversal: Dictionary, rule: StringName, revision: int) -> Dictionary:
	if world == null: return {"ok":false,"error_code":&"invalid_geometry"}
	if rule not in [&"ground_connected",&"direct_volume"]: return {"ok":false,"error_code":&"unknown_geometry_rule"}
	var checked := world.position_query(anchor,traversal,revision)
	if not checked["ok"]: return checked
	geometry = world
	_configuration_revision = world.configuration_revision
	_anchor = ExpeditionWorldPoint.create(anchor.stage_id,anchor.surface_id,anchor.position)
	_profile = traversal.duplicate(true)
	_rule = rule
	return {"ok":true,"error_code":&""}

func is_current_world() -> bool:
	return geometry != null and _configuration_revision == geometry.configuration_revision

func anchor() -> ExpeditionWorldPoint:
	return ExpeditionWorldPoint.create(_anchor.stage_id,_anchor.surface_id,_anchor.position) if _anchor != null else null

func query(target: CombatActor, radius: float, shape: Dictionary = {}) -> Dictionary:
	if geometry != null and _configuration_revision != geometry.configuration_revision: return {"ok":false,"error_code":&"world_reconfigured","data":{}}
	if geometry == null or not is_instance_valid(target) or not target.is_alive() or target.world_motion == null or not target.world_motion.is_current_world() or target.world_motion.geometry != geometry: return {"ok":false,"error_code":&"incompatible_target","data":{}}
	var captured := shape.duplicate(true)
	captured["geometry_rule_id"] = _rule
	captured["range"] = radius
	if _rule == &"ground_connected": captured["traversal"] = _profile.duplicate(true)
	return geometry.query_attack(captured,_anchor,target.world_point(),geometry.geometry_revision)

## Exact pre-filter: any route or line costs at least the straight distance, so a
## target farther than the range can never hit. Avoids a full path per poll.
func may_reach(target: CombatActor, radius: float) -> bool:
	if _anchor == null or not is_instance_valid(target) or target.world_motion == null: return false
	var point := target.world_point()
	return point != null and point.stage_id == _anchor.stage_id and _anchor.position.distance_to(point.position) <= radius + WorldGeometry.EPS

func contains_actor(target: CombatActor, radius: float) -> bool:
	if not is_instance_valid(target) or target.world_motion == null: return false
	if not may_reach(target,radius+float(target.world_motion.profile()["radius"])): return false
	var result := query(target,radius+float(target.world_motion.profile()["radius"]))
	return result["ok"] and result["data"]["hit"]

func distance_to(target: CombatActor) -> float:
	var result := query(target,1.0e20)
	return float(result["data"]["distance"]) if result["ok"] and result["data"]["los_ok"] else INF

func query_point(target: ExpeditionWorldPoint, radius: float) -> Dictionary:
	if geometry != null and _configuration_revision != geometry.configuration_revision: return {"ok":false,"error_code":&"world_reconfigured","data":{}}
	if geometry == null: return {"ok":false,"error_code":&"invalid_geometry","data":{}}
	var shape := {"geometry_rule_id":_rule,"range":radius}
	if _rule == &"ground_connected": shape["traversal"] = _profile.duplicate(true)
	return geometry.query_attack(shape,_anchor,target,geometry.geometry_revision)
