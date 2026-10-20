class_name WorldGeometerNavigation
extends ArenaNavigation
## Adapter for the canonical grammar: x/z keys resolve only explicitly supplied WorldPoints.
var world: WorldGeometry
var profile: Dictionary = {}
var points: Dictionary[Vector2, ExpeditionWorldPoint] = {}
var ambiguous := false
func reset(geometry: WorldGeometry, traversal: Dictionary) -> void:
	world = geometry
	profile = traversal.duplicate(true)
	points.clear()
	ambiguous = false
func include(point: ExpeditionWorldPoint) -> void:
	if point == null: return
	var key := Vector2(point.position.x,point.position.z)
	if points.has(key) and points[key].to_data() != point.to_data(): ambiguous = true
	points[key] = copy_point(point)
func point_at(key: Vector2) -> ExpeditionWorldPoint:
	return copy_point(points.get(key)) if not ambiguous else null
func is_segment_clear(from: Vector2, to: Vector2, clearance: float) -> bool:
	if world == null or ambiguous or not points.has(from) or not points.has(to): return false
	var source := points[from]; var destination := points[to]
	var traversal := profile.duplicate(true)
	traversal["radius"] = maxf(float(traversal["radius"]),clearance)
	if not world.position_query(source,traversal,world.geometry_revision)["ok"] or not world.position_query(destination,traversal,world.geometry_revision)["ok"]: return false
	if source.to_data() == destination.to_data(): return true
	# A figure edge follows connected support in a straight x/z line, never a detouring path.
	var edge := world.ground_line_to(source,destination,traversal,world.geometry_revision)
	return edge["ok"] and float(edge["data"]["cost"]) <= GeometerGeometry.MAX_EDGE_LENGTH+WorldGeometry.EPS

func is_polygon_clear(_polygon: PackedVector2Array, _clearance: float = 0.0) -> bool:
	return false # Triangle consumers are deliberately not admitted by this checkpoint.
static func copy_point(point: ExpeditionWorldPoint) -> ExpeditionWorldPoint:
	return ExpeditionWorldPoint.create(point.stage_id,point.surface_id,point.position) if point != null else null
