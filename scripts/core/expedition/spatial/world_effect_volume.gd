class_name WorldEffectVolume
extends RefCounted
## Explicit authored gameplay volume, anchored to a supported WorldPoint.
## Extents are supplied by the caller, never inferred from sprites or tuning.
var geometry: WorldGeometry
var _anchor: ExpeditionWorldPoint
var bounds := AABB()
var _configuration_revision := 0

func configure(world: WorldGeometry, point: ExpeditionWorldPoint, profile: Dictionary, volume: AABB, revision: int) -> Dictionary:
	if world == null: return {"ok":false,"error_code":&"invalid_geometry"}
	var checked := world.position_query(point,profile,revision)
	if not checked["ok"]: return checked
	if not volume.position.is_finite() or not volume.size.is_finite() or volume.size.x <= 0.0 or volume.size.y <= 0.0 or volume.size.z <= 0.0 or not volume.has_point(point.position): return {"ok":false,"error_code":&"invalid_volume"}
	geometry = world
	_configuration_revision = world.configuration_revision
	_anchor = ExpeditionWorldPoint.create(point.stage_id,point.surface_id,point.position)
	bounds = volume
	return {"ok":true,"error_code":&""}

func fraction(from: Vector3, to: Vector3, collider: Dictionary) -> float:
	if geometry == null or _configuration_revision != geometry.configuration_revision or not from.is_finite() or not to.is_finite() or not collider.has_all(["radius","height"]): return -1.0
	if not WorldGeometry._finite_number(collider["radius"]) or not WorldGeometry._finite_number(collider["height"]) or float(collider["radius"]) < 0.0 or float(collider["height"]) < 0.0: return -1.0
	var radius := float(collider["radius"])
	var height := float(collider["height"])
	var expanded := AABB(bounds.position-Vector3(radius,height,radius),bounds.size+Vector3(2.0*radius,height,2.0*radius))
	var hit := WorldGeometry._segment_box(from,to,expanded)
	return float(hit["fraction"]) if not hit.is_empty() else -1.0

func actor_fraction(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, actor: CombatActor) -> float:
	if not is_instance_valid(actor) or actor.world_motion == null or not actor.world_motion.is_current_world() or actor.world_motion.geometry != geometry or from == null or to == null or from.stage_id != _anchor.stage_id or to.stage_id != _anchor.stage_id: return -1.0
	return fraction(from.position,to.position,actor.world_motion.profile())
