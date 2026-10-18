class_name FlatWorldGeometry
extends RefCounted
## Explicit E06 adapter. Never accepts a multi-height point by dropping y/surface.
const STAGE := "legacy_arena"
const SURFACE := "legacy_arena/floor"
var navigation: ArenaNavigation
func _init(nav: ArenaNavigation) -> void:
	navigation = nav
func world_point(point: Vector2) -> ExpeditionWorldPoint:
	return ExpeditionWorldPoint.create(STAGE,SURFACE,Vector3(point.x,0,point.y))
func _valid(point: ExpeditionWorldPoint) -> bool:
	return point != null and point.stage_id == STAGE and point.surface_id == SURFACE and point.position.is_finite() and point.position.y == 0.0
func _result(code: StringName, data: Dictionary = {}) -> Dictionary:
	return {"ok": code == &"", "error_code": code, "geometry_revision": navigation.revision, "data": data.duplicate(true)}
func path(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, revision: int) -> Dictionary:
	if revision != navigation.revision: return _result(&"stale_geometry")
	if not _valid(from) or not _valid(to): return _result(&"invalid_support")
	var origin := Vector2(from.position.x,from.position.z)
	var destination := Vector2(to.position.x,to.position.z)
	var legacy := navigation.get_path(origin,destination)
	if legacy.is_empty(): return _result(&"unreachable")
	var points: Array[Dictionary] = []
	var cost := 0.0
	var previous := origin
	for point: Vector2 in legacy:
		points.append(world_point(point).to_data())
		cost += previous.distance_to(point)
		previous = point
	# E06's clamped/nearest destination remains explicit in this adapter's DTO.
	return _result(&"",{"points":points,"cost":cost,"requested_destination":to.to_data(),"resolved_destination":points[-1],"destination_adjusted":previous.distance_to(destination)>0.00001})
func query_attack(source: ExpeditionWorldPoint, target: ExpeditionWorldPoint, maximum_range: float, teleport: bool, revision: int) -> Dictionary:
	if revision != navigation.revision: return _result(&"stale_geometry")
	if not _valid(source) or not _valid(target): return _result(&"invalid_support")
	if not is_finite(maximum_range) or maximum_range < 0.0: return _result(&"invalid_range")
	var origin := Vector2(source.position.x,source.position.z)
	var destination := Vector2(target.position.x,target.position.z)
	var range_ok := origin.distance_to(destination) <= maximum_range
	var los_ok := navigation.is_walkable(destination) if teleport else navigation.is_segment_clear(origin,destination,0.0)
	return _result(&"",{"range_ok":range_ok,"los_ok":los_ok,"hit":range_ok and los_ok})
