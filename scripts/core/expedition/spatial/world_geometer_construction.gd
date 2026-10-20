class_name WorldGeometerConstruction
extends GeometerConstructionState
## Spatial metadata around the unchanged finite grammar, clocks, ticket order and identities.
var world: WorldGeometry
var world_navigation := WorldGeometerNavigation.new()
var field_height := 0.0
var generation := 0
var _epoch := 0
var _actors: Dictionary[int, WeakRef] = {}
var _points: Dictionary[int, ExpeditionWorldPoint] = {}
var _last_points: Dictionary[int, ExpeditionWorldPoint] = {}
var _pending_points: Dictionary[int, ExpeditionWorldPoint] = {}
var _candidate: ExpeditionWorldPoint
func configure(geometry: WorldGeometry, traversal: Dictionary, vertical_extent: float = 0.0) -> void:
	clear()
	world = geometry
	_epoch = world.configuration_revision
	field_height = vertical_extent
	world_navigation.reset(world,traversal)
func set_actors(actors: Array[CombatActor]) -> void:
	_actors.clear()
	for actor: CombatActor in actors:
		if is_instance_valid(actor): _actors[actor.get_instance_id()] = weakref(actor)
func world_points() -> Array[ExpeditionWorldPoint]:
	var result: Array[ExpeditionWorldPoint] = []
	for anchor: GeometerAnchor in vertices: result.append(WorldGeometerNavigation.copy_point(_points.get(anchor.get_instance_id())))
	return result
func pending_world_point(ticket: int) -> ExpeditionWorldPoint:
	return WorldGeometerNavigation.copy_point(_pending_points.get(ticket))
func preview_world(point: ExpeditionWorldPoint, element: StringName, triangle_rank: int, third: bool = false) -> Dictionary:
	refresh({},world_navigation)
	_candidate = WorldGeometerNavigation.copy_point(point)
	_rebuild()
	var result := preview_shot(Vector2(point.position.x,point.position.z),third,triangle_rank,world_navigation,element) if point != null else {"ok":false,"reason":"Ponto do mundo ausente."}
	_candidate = null
	_rebuild()
	return result
func reserve_world(point: ExpeditionWorldPoint, actor_id: int, triangle_rank: int, durations: Vector2, element: StringName, fixed_ground: bool, third: bool = false) -> int:
	_candidate = WorldGeometerNavigation.copy_point(point)
	_rebuild()
	var ticket := reserve_shot(Vector2(point.position.x,point.position.z),actor_id,third,triangle_rank,world_navigation,durations.x,durations.y,element,fixed_ground)
	if ticket > 0: _pending_points[ticket] = WorldGeometerNavigation.copy_point(point)
	_candidate = null
	_rebuild()
	return ticket
func resolve_world(ticket: int, success: bool, point: ExpeditionWorldPoint) -> Array[Dictionary]:
	if not _pending_points.has(ticket): return []
	if success and point != null: _pending_points[ticket] = WorldGeometerNavigation.copy_point(point)
	refresh({},world_navigation)
	var accepted: bool = success and point != null and world.position_query(point,world_navigation.profile,world.geometry_revision)["ok"]
	var result := resolve_shot(ticket,accepted,Vector2(point.position.x,point.position.z) if point != null else Vector2.ZERO,logical_positions(),world_navigation)
	_prune()
	return result
func logical_positions() -> Dictionary[int, Vector2]:
	var result: Dictionary[int, Vector2] = {}
	for identity: int in _actors:
		var point := _actor_point(identity)
		if point != null: result[identity] = Vector2(point.position.x,point.position.z)
	return result
func refresh(_alive_positions: Dictionary[int, Vector2], _navigation: ArenaNavigation) -> void:
	if world == null: return
	if _epoch != world.configuration_revision: clear(); return
	for anchor: GeometerAnchor in vertices:
		var key := anchor.get_instance_id()
		if anchor.actor_id > 0:
			var point := _actor_point(anchor.actor_id)
			if point == null:
				anchor.actor_id = 0
				_points[key] = WorldGeometerNavigation.copy_point(_last_points[key])
			else:
				_points[key] = point
				if world.position_query(point,world_navigation.profile,world.geometry_revision)["ok"]: _last_points[key] = WorldGeometerNavigation.copy_point(point)
		var current := _points[key]
		anchor.position = Vector2(current.position.x,current.position.z)
		var last := _last_points[key]
		anchor.last_valid_ground = Vector2(last.position.x,last.position.z)
	# Use the canonical pending record layout; only spatial positions and detachment are updated.
	for delivery: Dictionary in grammar._pending:
		if not bool(delivery["resolved"]) or not bool(delivery["success"]): continue
		var ticket := int(delivery["ticket"])
		if not _pending_points.has(ticket): continue
		if not bool(delivery["context"].get("fixed_ground",false)) and int(delivery["actor_id"]) > 0:
			var point := _actor_point(int(delivery["actor_id"]))
			if point == null: delivery["actor_id"] = 0
			elif world.position_query(point,world_navigation.profile,world.geometry_revision)["ok"]: _pending_points[ticket] = point
		var current := _pending_points[ticket]
		delivery["point"] = Vector2(current.position.x,current.position.z)
		delivery["last_valid_ground"] = delivery["point"]
	_rebuild()
	suspended = not vertices.is_empty() and (not GeometerGeometry.validate(positions(),world_navigation)["ok"] or (shape in [Shape.WALL,Shape.TRIANGLE] and not region()["ok"]))
func advance(delta: float, _alive_positions: Dictionary[int, Vector2], _navigation: ArenaNavigation) -> Array[Dictionary]:
	var result := super.advance(delta,logical_positions(),world_navigation)
	_prune()
	return result
func add_vertex(element: StringName, point: Vector2, carrier_id: int, triangle_rank: int, _navigation: ArenaNavigation, vertex_duration: float = 8.0, figure_duration: float = 6.0) -> Dictionary:
	var explicit_point := world_navigation.point_at(point)
	if explicit_point == null: return {"ok":false,"reason":"Suporte do vértice ausente ou ambíguo.","formation":false}
	var result := super.add_vertex(element,point,carrier_id,triangle_rank,world_navigation,vertex_duration,figure_duration)
	if result["ok"]:
		var key := vertices[-1].get_instance_id()
		_points[key] = WorldGeometerNavigation.copy_point(explicit_point)
		_last_points[key] = WorldGeometerNavigation.copy_point(explicit_point)
	return result
func _validate_candidate(points: PackedVector2Array, tokens: Array[StringName], triangle_rank: int, _navigation: ArenaNavigation) -> Dictionary:
	var figure := tokens.size() == 3 or (tokens.size() == 2 and tokens[0] != tokens[1])
	if figure and (not is_finite(field_height) or field_height <= 0): return {"ok":false,"reason":"Altura explícita da figura necessária.","error_code":&"authored_field_height_required"}
	var valid := super._validate_candidate(points,tokens,triangle_rank,world_navigation)
	if not valid["ok"] or not figure: return valid
	var placed := region(points)
	return valid if placed["ok"] else {"ok":false,"reason":"Figura sem suporte livre contínuo.","error_code":placed["error_code"]}
func region(points: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	var footprint := points if not points.is_empty() else positions()
	if footprint.size() < 2: return WorldSkillCast.failure(&"invalid_region")
	var polygon := footprint
	if footprint.size() == 2:
		var axis := (footprint[1]-footprint[0]).normalized(); var side := axis.orthogonal()*GeometerGeometry.WALL_HALF_WIDTH
		var cap := axis*GeometerGeometry.WALL_HALF_WIDTH
		polygon = PackedVector2Array([footprint[0]-cap-side,footprint[1]+cap-side,footprint[1]+cap+side,footprint[0]-cap+side])
	var anchor := world_navigation.point_at(footprint[0])
	if anchor == null: return WorldSkillCast.failure(&"ambiguous_support")
	var profile := world_navigation.profile.duplicate(true)
	profile["height"] = maxf(float(profile["height"]),field_height)
	return world.ground_region(anchor,polygon,profile,world.geometry_revision)
func preview_world_edit(point: ExpeditionWorldPoint, actor_id: int, rewrite: bool, triangle_rank: int, durations: Vector2, element: StringName) -> Dictionary:
	refresh({},world_navigation)
	_candidate = WorldGeometerNavigation.copy_point(point); _rebuild()
	var result := preview_edit(Vector2(point.position.x,point.position.z),actor_id,rewrite,triangle_rank,world_navigation,durations.x,durations.y,element)
	result.erase("candidate")
	_candidate = null; _rebuild()
	return result
func edit_world(point: ExpeditionWorldPoint, actor_id: int, rewrite: bool, triangle_rank: int, durations: Vector2, element: StringName) -> Dictionary:
	_candidate = WorldGeometerNavigation.copy_point(point); _rebuild()
	var result := edit(Vector2(point.position.x,point.position.z),actor_id,rewrite,triangle_rank,world_navigation,durations.x,durations.y,element)
	if result["ok"]:
		var kept: Dictionary[int, ExpeditionWorldPoint] = {}; var last: Dictionary[int, ExpeditionWorldPoint] = {}
		for anchor: GeometerAnchor in vertices:
			var id := anchor.get_instance_id()
			kept[id] = _points[id] if _points.has(id) else WorldGeometerNavigation.copy_point(point)
			last[id] = _last_points[id] if _last_points.has(id) else WorldGeometerNavigation.copy_point(point)
		_points = kept; _last_points = last
	_candidate = null; _rebuild()
	return result
func capture_collapse() -> Dictionary:
	var captured_region := region()
	var points := world_points()
	var captured := consume_collapse()
	if not captured.is_empty(): captured["world_points"] = points; captured["world_region"] = captured_region["data"] if captured_region["ok"] else {}; captured["height"] = field_height
	return captured

func clear() -> void:
	super.clear()
	generation += 1
	_points.clear(); _last_points.clear(); _pending_points.clear()
	_candidate = null
func _actor_point(identity: int) -> ExpeditionWorldPoint:
	var actor := _actors[identity].get_ref() as CombatActor if _actors.has(identity) else null
	if not is_instance_valid(actor) or not actor.is_alive() or actor.world_motion == null or not actor.world_motion.is_current_world() or actor.world_motion.geometry != world: return null
	return actor.world_point()
func _rebuild() -> void:
	world_navigation.reset(world,world_navigation.profile)
	for point: ExpeditionWorldPoint in _points.values(): world_navigation.include(point)
	for point: ExpeditionWorldPoint in _pending_points.values(): world_navigation.include(point)
	world_navigation.include(_candidate)
func _prune() -> void:
	var tickets: Array[int] = []
	for delivery: Dictionary in grammar.pending_snapshot(): tickets.append(int(delivery["ticket"]))
	for ticket: int in _pending_points.keys():
		if ticket not in tickets: _pending_points.erase(ticket)
	_rebuild()
