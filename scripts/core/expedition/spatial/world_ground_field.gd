class_name WorldGroundField
extends RefCounted
## Finite authored-height planar field. No projected coordinates or reconstructed walking paths.
var geometry: WorldGeometry
var volume: WorldEffectVolume
var solid: WorldSolidSegment
var kind: StringName
var height := 0.0
var half_length := 0.0
var half_width := 0.0
var _point: ExpeditionWorldPoint
var _normal := Vector3.RIGHT
var _axis := Vector3.BACK
var _configuration := 0
var _profile: Dictionary = {}
var _areas: Array[WorldEffectArea] = []
var _centers: Array[ExpeditionWorldPoint] = []
var _actors: Array[WeakRef] = []
var _pending: Dictionary[int, Array] = {}
var _connections: Array[Dictionary] = []
func configure(world: WorldGeometry, source: ExpeditionWorldPoint, facing: Vector3, placement_range: float, traversal: Dictionary, field_kind: StringName, vertical_extent: float, revision: int, layout: Dictionary) -> Dictionary:
	if world == null: return WorldSkillCast.failure(&"invalid_geometry")
	if not is_finite(vertical_extent) or vertical_extent <= 0: return WorldSkillCast.failure(&"authored_field_height_required")
	if not facing.is_finite() or facing.is_zero_approx() or absf(facing.y) > WorldGeometry.EPS: return WorldSkillCast.failure(&"invalid_field_direction")
	if field_kind not in [&"fire_wall",&"lightning_wall",&"phantom_barrier",&"ice_wall"]: return WorldSkillCast.failure(&"invalid_field_kind")
	var placed := world.ground_line_samples(source,facing,placement_range,1,traversal,revision)
	if not placed["ok"]: return placed
	if placed["data"]["points"].is_empty(): return WorldSkillCast.failure(&"blocked_field_placement")
	var data: Dictionary = placed["data"]["points"][0]
	_point = ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
	kind = field_kind; height = vertical_extent; geometry = world; _configuration = world.configuration_revision
	_normal = facing.normalized(); _axis = Vector3(-_normal.z,0,_normal.x); _profile = traversal.duplicate(true)
	if not layout.has_all(["half_length","half_width","centers"]): return WorldSkillCast.failure(&"invalid_field_layout")
	half_length = float(layout["half_length"])
	half_width = float(layout["half_width"])
	if not is_finite(half_length) or not is_finite(half_width) or minf(half_length,half_width) <= 0: return WorldSkillCast.failure(&"invalid_field_layout")
	var footprint := traversal.duplicate(true); footprint["radius"] = half_width; footprint["height"] = height
	for distance: float in [-half_length,half_length]:
		var endpoint := _supported_axis(distance,footprint,revision)
		if not endpoint["ok"]: return endpoint
		if absf(float(endpoint["data"]["point"]["position"].y)-_point.position.y) > WorldGeometry.EPS: return WorldSkillCast.failure(&"non_planar_field_support")
	var distances: Array[float] = []
	distances.assign(layout["centers"])
	if distances.is_empty(): return WorldSkillCast.failure(&"invalid_field_layout")
	for distance: float in distances:
		var supported := _supported_axis(distance,footprint,revision)
		if not supported["ok"]: return supported
		var point: Dictionary = supported["data"]["point"]
		var center := ExpeditionWorldPoint.create(point["stage_id"],point["surface_id"],point["position"])
		if absf(center.position.y-_point.position.y) > WorldGeometry.EPS: return WorldSkillCast.failure(&"non_planar_field_support")
		var area := WorldEffectArea.new()
		var bound := area.configure(world,center,footprint,&"ground_connected",revision)
		if not bound["ok"]: return bound
		_centers.append(center); _areas.append(area)
	if kind == &"ice_wall":
		solid = WorldSolidSegment.new()
		if not solid.configure(_point,_normal,half_length,half_width,height,traversal): return WorldSkillCast.failure(&"invalid_volume")
	if kind != &"fire_wall":
		volume = WorldEffectVolume.new()
		var bound := volume.configure_oriented(world,_point,footprint,_normal,half_length,half_width,height,revision)
		if not bound["ok"]: return bound
	return {"ok":true,"error_code":&""}
func _supported_axis(distance: float, profile: Dictionary, revision: int) -> Dictionary:
	var position := _point.position+_axis*distance
	return geometry.ground_line_point_at(_point,Vector2(position.x,position.z),profile,revision)
func anchor() -> ExpeditionWorldPoint: return ExpeditionWorldPoint.create(_point.stage_id,_point.surface_id,_point.position)
func is_current() -> bool: return geometry != null and geometry.configuration_revision == _configuration
func describe() -> Dictionary: return {"kind":kind,"anchor":anchor().to_data(),"normal":_normal,"height":height,"half_length":half_length,"half_width":half_width}
func track(owner: Node, targets: Array[CombatActor]) -> void:
	var seen: Dictionary[int,bool] = {}
	for candidate: Variant in targets:
		if not is_instance_valid(candidate): continue
		var actor := candidate as CombatActor
		if actor == null or actor.world_motion == null or actor.world_motion.geometry != geometry: continue
		if seen.has(actor.get_instance_id()): continue
		seen[actor.get_instance_id()] = true
		_actors.append(weakref(actor))
		var callback := Callable(owner,"_on_world_field_motion").bind(weakref(actor))
		actor.world_motion.traversed.connect(callback)
		_connections.append({"motion":actor.world_motion,"callback":callback})
func close() -> void:
	for connection: Dictionary in _connections:
		var motion := connection["motion"] as WorldActorMotion
		var callback: Callable = connection["callback"]
		if callback.is_valid() and motion.traversed.is_connected(callback): motion.traversed.disconnect(callback)
	_connections.clear(); _actors.clear(); _pending.clear()
func queue_motion(segments: Array[Dictionary], reference: WeakRef) -> void:
	var actor := reference.get_ref() as CombatActor
	if not is_instance_valid(actor) or not is_current(): return
	var id := actor.get_instance_id()
	if not _pending.has(id): _pending[id] = []
	_pending[id].append_array(segments.duplicate(true))
func actors() -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	for reference: WeakRef in _actors:
		var actor := reference.get_ref() as CombatActor
		if is_instance_valid(actor) and actor.is_alive() and actor.world_motion != null and actor.world_motion.is_current_world() and actor.world_motion.geometry == geometry: result.append(actor)
	return result
func take_motion(actor: CombatActor) -> Array:
	var id := actor.get_instance_id(); var segments: Array = _pending.get(id,[])
	_pending.erase(id)
	return segments
func _ground_contact(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, position: Vector3, actor: CombatActor) -> ExpeditionWorldPoint:
	for surface: String in [from.surface_id,to.surface_id]:
		var point := ExpeditionWorldPoint.create(from.stage_id,surface,position)
		if geometry.position_query(point,actor.world_motion.profile(),geometry.geometry_revision)["ok"]: return point
	return null
func fraction(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, actor: CombatActor) -> float:
	if not is_current() or not is_instance_valid(actor) or actor.world_motion == null or not actor.world_motion.is_current_world() or actor.world_motion.geometry != geometry or from == null or to == null or from.stage_id != _point.stage_id or to.stage_id != _point.stage_id: return -1.0
	var body := actor.world_motion.profile(); var radius := float(body["radius"]); var body_height := float(body["height"])
	var candidates: Array[Dictionary] = []
	if kind == &"fire_wall":
		for i: int in _centers.size():
			candidates.append({"fraction":WorldProjectileMotion.cylinder_fraction(from.position,to.position,_centers[i].position,radius+half_width,height,body_height),"area":i})
	else:
		if kind == &"lightning_wall":
			var start := from.position-_point.position; var finish := to.position-_point.position
			var hit := WorldGeometry._segment_box(Vector3(start.dot(_normal),start.y,start.dot(_axis)),Vector3(finish.dot(_normal),finish.y,finish.dot(_axis)),AABB(Vector3(-half_width-radius,-body_height,-half_length),Vector3(2*(half_width+radius),height+body_height,2*half_length)))
			candidates.append({"fraction":float(hit["fraction"]) if not hit.is_empty() else -1.0,"area":0})
		else: candidates.append({"fraction":volume.fraction(from.position,to.position,body),"area":0})
		if kind == &"lightning_wall":
			for side: float in [-1.0,1.0]: candidates.append({"fraction":WorldProjectileMotion.cylinder_fraction(from.position,to.position,_point.position+_axis*half_length*side,radius+half_width,height,body_height),"area":0})
	var first := 2.0
	for candidate: Dictionary in candidates:
		var at := float(candidate["fraction"])
		if at < 0 or at >= first: continue
		var point := _ground_contact(from,to,from.position.lerp(to.position,at),actor)
		if point == null: continue
		var area := _areas[int(candidate["area"])]
		var query := area.query_point(point,(half_width if kind == &"fire_wall" else half_length+half_width)+radius)
		if query["ok"] and query["data"]["hit"]: first = at
	return first if first <= 1.0 else -1.0
func contains(actor: CombatActor) -> bool: return fraction(actor.world_point(),actor.world_point(),actor) >= 0
func contains_point(actor: CombatActor, data: Dictionary) -> bool:
	var point := ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
	return fraction(point,point,actor) >= 0
func crossed(actor: CombatActor, segment: Dictionary) -> bool:
	var a: Dictionary = segment["from"]; var b: Dictionary = segment["to"]
	return fraction(ExpeditionWorldPoint.create(a["stage_id"],a["surface_id"],a["position"]),ExpeditionWorldPoint.create(b["stage_id"],b["surface_id"],b["position"]),actor) >= 0
