class_name GeometerCasting
extends Node2D
## Casting, spatial candidates and underlay. Recipes belong to field consumers.

signal hit(request: DamageRequest, target: CombatActor)
signal feedback(message: String)
signal construction_closed(result: Dictionary)
## Spatial candidate only; recipes must claim effects through interaction_ledger.
signal wall_crossed(contact: Dictionary, actor: CombatActor)

var player: PlayerActor
var targets: Array[CombatActor] = []
var construction := GeometerConstructionState.new()
var preview_command: GeometerCastCommand
var preview_valid := false
var wall_contacts := GeometerWallContactState.new()
var interaction_ledger := GeometerInteractionLedger.new()
var _watched_walkers: Dictionary[int, EnemyActor] = {}
var _world_walkers: Dictionary[int, Dictionary] = {}
var wall_field := GeometerWallField.new()
var triangle_field := GeometerTriangleField.new()
var _shot_wall_snapshots: Dictionary[int, Dictionary] = {}
var _shot_triangle_snapshots: Dictionary[int, Dictionary] = {}
var _wall_reactions: Array[Dictionary] = []
var _reaction_visual := WallReactionVisual.new()
var _visual_time := 0.0

func configure(caster: PlayerActor) -> void:
	player = caster
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = -1
	_reaction_visual.z_index = 2
	add_child(_reaction_visual)
	player.geometer_cast_ready.connect(launch)
	wall_field.configure(self)
	triangle_field.configure(self)

func bind_world_construction(field_height: float = 0.0) -> Dictionary:
	if not is_finite(field_height) or field_height < 0: return WorldSkillCast.failure(&"invalid_field_height")
	if not is_instance_valid(player) or player.world_motion == null or not player.world_motion.is_current_world(): return WorldSkillCast.failure(&"spatial_binding_required")
	if construction is WorldGeometerConstruction: return {"ok":true,"error_code":&""} if (construction as WorldGeometerConstruction).field_height == field_height else WorldSkillCast.failure(&"already_bound")
	if not construction.vertices.is_empty() or construction.grammar.pending_count() > 0: return WorldSkillCast.failure(&"legacy_construction_active")
	var spatial := WorldGeometerConstruction.new()
	spatial.configure(player.world_motion.geometry,player.world_motion.profile(),field_height)
	spatial.grammar.select_element(construction.grammar.selected_element)
	construction = spatial
	return {"ok":true,"error_code":&""}

func preview_world_trace(skill: StringName, point: ExpeditionWorldPoint, victim: CombatActor, revision: int, requested_rank: int = 0) -> Dictionary:
	return player.preview_world_geometer(self,skill,point,victim,revision,requested_rank)

func begin_world_trace(skill: StringName, point: ExpeditionWorldPoint, victim: CombatActor, revision: int, requested_rank: int = 0) -> Dictionary:
	return player.request_world_geometer(self,skill,point,victim,revision,requested_rank)

func launch_world(result: Dictionary, command: WorldGeometerCast) -> void:
	var projectile := GeometerTraceProjectile.new()
	add_child(projectile)
	var bound := projectile.configure_world_trace(result,command)
	assert(bound["ok"],"Preflighted Geometer trace must bind without external callbacks")
	projectile.delivered_world.connect(_on_world_delivered.bind(projectile))
	projectile.add_to_group("player_projectiles")
	_shot_wall_snapshots[int(result["ticket"])] = result["wall_snapshot"]
	_shot_triangle_snapshots[int(result["ticket"])] = result["triangle_snapshot"]

func _on_world_delivered(ticket: int, success: bool, point: ExpeditionWorldPoint, victim: CombatActor, projectile: GeometerTraceProjectile) -> void:
	if is_instance_valid(player) and not player.is_alive(): clear_construction(); return
	if not is_instance_valid(player) or not player.is_alive() or not construction is WorldGeometerConstruction or (construction as WorldGeometerConstruction).world != projectile.world_flight.geometry or (is_inside_tree() and get_tree().paused): return
	if not construction.grammar.pending_snapshot().any(func(item: Dictionary) -> bool: return int(item["ticket"]) == ticket and not bool(item["resolved"])): return
	# Ticket resolution and anchor capture precede arbitrary damage callbacks.
	var results := (construction as WorldGeometerConstruction).resolve_world(ticket,success,point)
	var resolved_generation := (construction as WorldGeometerConstruction).generation
	var resolved_identity := construction.construction_id
	if success and is_instance_valid(victim) and victim.is_alive() and projectile.request.magic_damage > 0.0:
		projectile.request.target_id = victim.get_instance_id()
		hit.emit(projectile.request,victim)
	for result: Dictionary in results:
		if (construction as WorldGeometerConstruction).generation == resolved_generation and construction.construction_id == resolved_identity: _report_delivery(result)
		else: _shot_wall_snapshots.erase(int(result["ticket"])); _shot_triangle_snapshots.erase(int(result["ticket"]))
	_sync_world_walkers()
	_retire_invalid_flights()

func is_world_bound() -> bool:
	return construction is WorldGeometerConstruction and is_instance_valid(player) and player.world_motion != null
func actor_position(actor: CombatActor) -> Vector2:
	if not is_world_bound(): return actor.global_position
	return Vector2(actor.world_point().position.x,actor.world_point().position.z) if actor.world_motion != null else Vector2.INF
func world_point_at(horizontal: Vector2, region: Dictionary = {}) -> ExpeditionWorldPoint:
	if not is_world_bound(): return null
	var spatial := construction as WorldGeometerConstruction
	var origin: ExpeditionWorldPoint
	if region.has("anchor"):
		var data: Dictionary = region["anchor"]; origin = ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
	elif not spatial.world_points().is_empty(): origin = spatial.world_points()[0]
	if origin == null: return null
	var result := spatial.world.ground_line_point_at(origin,horizontal,spatial.world_navigation.profile,spatial.world.geometry_revision)
	if not result["ok"]: return null
	var data: Dictionary = result["data"]["point"]
	return ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
func ground_visible(origin: Vector2, actor: CombatActor, limit: float = INF) -> bool:
	if not is_world_bound(): return player.navigation.is_segment_clear(origin,actor.global_position,0.0) and origin.distance_to(actor.global_position) <= limit
	var point := world_point_at(origin)
	if point == null or not is_instance_valid(actor) or actor.world_motion == null or actor.world_motion.geometry != player.world_motion.geometry or not actor.world_motion.is_current_world(): return false
	var edge := player.world_motion.geometry.ground_line_to(point,actor.world_point(),player.world_motion.profile(),player.world_motion.geometry.geometry_revision)
	return edge["ok"] and float(edge["data"]["cost"]) <= limit+WorldGeometry.EPS
func pulse_contains(origin: ExpeditionWorldPoint, actor: CombatActor, radius: float) -> bool:
	if origin == null or not is_instance_valid(actor) or actor.world_motion == null or not actor.world_motion.is_current_world() or actor.world_motion.geometry != player.world_motion.geometry: return false
	var edge := player.world_motion.geometry.ground_line_to(origin,actor.world_point(),player.world_motion.profile(),player.world_motion.geometry.geometry_revision)
	return edge["ok"] and float(edge["data"]["cost"]) <= radius+float(actor.world_motion.profile()["radius"])+WorldGeometry.EPS
func region_contains(actor: CombatActor, region: Dictionary = {}, points: PackedVector2Array = PackedVector2Array()) -> bool:
	if not is_world_bound() or not is_instance_valid(actor) or actor.world_motion == null or not actor.world_motion.is_current_world() or actor.world_motion.geometry != player.world_motion.geometry: return false
	var spatial := construction as WorldGeometerConstruction
	var data := region
	if data.is_empty():
		var query := spatial.region(points)
		if not query["ok"]: return false
		data = query["data"]
	var radius := float(actor.world_motion.profile()["radius"])
	if not WorldSupportRegion.ground_contains(data,actor.world_point(),radius): return false
	var footprint := points if not points.is_empty() else construction.positions()
	return footprint.size() != 2 or GeometerGeometry.wall_contains(footprint,actor_position(actor),radius)
func world_contact(from: Vector3, to: Vector3, collider: Dictionary, wall: bool) -> Dictionary:
	if not is_world_bound(): return {}
	var spatial := construction as WorldGeometerConstruction
	var region := spatial.region()
	if not region["ok"]: return {}
	var at: float
	if wall:
		var points := construction.positions()
		at = WorldSupportRegion.capsule_fraction(region["data"],points[0],points[1],GeometerGeometry.WALL_HALF_WIDTH,from,to,collider,spatial.field_height)
	else: at = WorldSupportRegion.fraction(region["data"],from,to,collider,spatial.field_height)
	if at < 0: return {}
	return {"fraction":at,"inside_triangle":not wall and at == 0.0}
func world_edited() -> void:
	wall_contacts.sync(0,false)
	wall_field.capture_construction()
	_sync_world_walkers()
func collapse_world(captured: Dictionary) -> void:
	clear_construction()
	var points: PackedVector2Array = captured["points"]
	if captured["shape"] == GeometerConstructionState.Shape.TRIANGLE:
		triangle_field.resolve_world_captured(points,captured["world_region"],captured["resolution_element"],captured["request"],int(captured["resolution_vertex"]))
	else:
		for actor: CombatActor in targets.duplicate():
			if not player.is_alive() or (is_inside_tree() and get_tree().paused): break
			if not is_instance_valid(actor) or not actor.is_alive() or not region_contains(actor,captured["world_region"],points): continue
			var request := (captured["request"] as DamageRequest).copy(); request.target_id = actor.get_instance_id(); hit.emit(request,actor)
func _sync_world_walkers() -> void:
	var ids: Array[int] = []
	for candidate: Variant in targets:
		if not is_instance_valid(candidate): continue
		var actor := candidate as CombatActor
		if actor == null or not actor.is_alive() or actor.world_motion == null or actor.world_motion.geometry != player.world_motion.geometry: continue
		var id := actor.get_instance_id(); ids.append(id)
		if not _world_walkers.has(id):
			var callback := Callable(self,"_on_world_walked").bind(weakref(actor))
			actor.world_motion.traversed.connect(callback)
			_world_walkers[id] = {"motion":actor.world_motion,"callback":callback}
	for id: int in _world_walkers.keys():
		if id not in ids:
			var item := _world_walkers[id]; var motion := item["motion"] as WorldActorMotion
			if motion.traversed.is_connected(item["callback"]): motion.traversed.disconnect(item["callback"])
			_world_walkers.erase(id)
	wall_contacts.sync(construction.construction_id,construction.shape == GeometerConstructionState.Shape.WALL and construction.has_active_figure())
	wall_contacts.prune(ids)
func _on_world_walked(segments: Array[Dictionary], reference: WeakRef) -> void:
	var actor := reference.get_ref() as CombatActor
	if not is_world_bound() or not is_instance_valid(actor) or not actor.is_alive() or not player.is_alive() or (is_inside_tree() and get_tree().paused): return
	construction.refresh(alive_positions(),player.navigation)
	_sync_world_walkers()
	if construction.shape != GeometerConstructionState.Shape.WALL or not construction.has_active_figure(): return
	var points := construction.positions()
	for segment: Dictionary in segments:
		if segment.get("kind",&"walk") != &"walk": continue
		var a: Vector3 = segment["from"]["position"]; var b: Vector3 = segment["to"]["position"]
		var contact := wall_contacts.observe(actor.get_instance_id(),Vector2(a.x,a.z),Vector2(b.x,b.z),points[0],points[1],float(actor.world_motion.profile()["radius"]))
		if contact.is_empty(): continue
		var at: Vector3 = a.lerp(b,float(contact["fraction"]))
		var support := world_point_at(contact["wall_point"])
		if support == null or absf(support.position.y-at.y) > WorldGeometry.EPS: continue
		wall_crossed.emit(contact,actor)

func alive_positions() -> Dictionary[int, Vector2]:
	if construction is WorldGeometerConstruction: return (construction as WorldGeometerConstruction).logical_positions()
	var positions: Dictionary[int, Vector2] = {}
	for actor: CombatActor in targets:
		if is_instance_valid(actor) and actor.is_alive():
			positions[actor.get_instance_id()] = actor.global_position
	return positions

func capture(skill: StringName, point: Vector2, force_ground: bool = false) -> GeometerCastCommand:
	var command := GeometerCastCommand.new()
	command.skill_id = skill
	command.element = construction.grammar.selected_element
	command.point = point
	var enemy := BattleTargeting.pick(point, targets, null, false) if not force_ground else null
	command.actor_id = enemy.get_instance_id() if enemy != null else 0
	return command

func check(command: GeometerCastCommand) -> Dictionary:
	construction.refresh(alive_positions(), player.navigation)
	return player.geometer_action_check(command, construction, targets)

func begin(command: GeometerCastCommand) -> bool:
	var result := check(command)
	if not result["ok"]:
		feedback.emit(result["reason"])
		return false
	if GeometerCastCommand.is_edit_skill(command.skill_id):
		return edit(command)
	if command.skill_id == &"geometer_collapse":
		return collapse(command)
	if player.skill_cast_time(command.skill_id) > 0.0:
		return player.begin_geometer_cast(command, construction, targets)
	launch(command)
	return true

func edit(command: GeometerCastCommand) -> bool:
	construction.refresh(alive_positions(), player.navigation)
	var result := player.commit_geometer_edit(command, construction, targets)
	if not result["ok"]:
		feedback.emit(result["reason"])
		return false
	# Preserve ledger/cadence and snapshots, but never infer a walk from the edit.
	wall_contacts.sync(0, false)
	_sync_wall_observers()
	wall_field.capture_construction()
	queue_redraw()
	return true

func collapse(command: GeometerCastCommand) -> bool:
	construction.refresh(alive_positions(), player.navigation)
	var captured := player.commit_geometer_collapse(command, construction, targets)
	if not captured["ok"]:
		feedback.emit(captured["reason"])
		return false
	# Construction is already empty: cleanup cannot erase a new construction created by a hit callback.
	clear_construction()
	player.presentation_action.emit(&"cast_release", player._last_facing, 0.12)
	player.resources_changed.emit()
	var points: PackedVector2Array = captured["points"]
	var request: DamageRequest = captured["request"]
	if captured["shape"] == GeometerConstructionState.Shape.TRIANGLE:
		triangle_field.resolve_captured(points, captured["resolution_element"], request, 0, int(captured["resolution_vertex"]))
	else:
		for actor: CombatActor in targets.duplicate():
			if not player.is_alive() or (is_inside_tree() and get_tree().paused):
				break
			if not is_instance_valid(actor) or not actor.is_alive() or actor == player:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(actor.global_position, points[0], points[1])
			if GeometerGeometry.wall_contains(points, actor.global_position, actor.collision_radius) and player.navigation.is_segment_clear(closest, actor.global_position, 0.0):
				var hit_request := request.copy()
				hit_request.target_id = actor.get_instance_id()
				hit.emit(hit_request, actor)
		# One finite line accent, not a chain of wall crossing detonations.
		if player.is_alive() and not (is_inside_tree() and get_tree().paused):
			if _wall_reactions.size() >= 12:
				_wall_reactions.pop_front()
			_wall_reactions.append({"line": points, "element": captured["elements"][1], "remaining": 0.25})
			_redraw_wall_reactions()
	queue_redraw()
	return true

func launch(command: GeometerCastCommand) -> void:
	if player.world_motion != null: return
	construction.refresh(alive_positions(), player.navigation)
	var result := player.commit_geometer_shot(command, construction, targets)
	if not result["ok"]:
		feedback.emit(result["reason"])
		return
	var projectile := GeometerTraceProjectile.new()
	add_child(projectile)
	projectile.z_index = 2
	projectile.configure_trace(result, command, player.global_position, player.navigation)
	_shot_wall_snapshots[int(result["ticket"])] = result["wall_snapshot"]
	_shot_triangle_snapshots[int(result["ticket"])] = result["triangle_snapshot"]
	projectile.delivered.connect(_on_delivered.bind(projectile))
	projectile.add_to_group("player_projectiles")
	queue_redraw()

func _on_delivered(ticket: int, success: bool, point: Vector2, victim: CombatActor, projectile: GeometerTraceProjectile) -> void:
	if is_instance_valid(player) and player.world_motion != null: return
	# Validate ticket before damage: clear/timeout cannot leave a damaging late shot.
	if not construction.grammar.pending_snapshot().any(func(item: Dictionary) -> bool: return int(item["ticket"]) == ticket and not bool(item["resolved"])) or not player.is_alive():
		return
	if success and is_instance_valid(victim) and victim.is_alive() and projectile.request.magic_damage > 0.0:
		projectile.request.target_id = victim.get_instance_id()
		hit.emit(projectile.request, victim)
	for result: Dictionary in construction.resolve_shot(ticket, success, point, alive_positions(), player.navigation):
		_report_delivery(result)
	_retire_invalid_flights()
	_sync_wall_observers()
	queue_redraw()

func _report_delivery(result: Dictionary) -> void:
	if result["ok"]:
		wall_field.capture_construction(_shot_wall_snapshots.get(int(result.get("ticket", 0)), {}))
	_shot_wall_snapshots.erase(int(result.get("ticket", 0)))
	if result.get("formation", false):
		triangle_field.form(_shot_triangle_snapshots.get(int(result.get("ticket", 0)), {}))
	_shot_triangle_snapshots.erase(int(result.get("ticket", 0)))
	if not result["ok"]:
		feedback.emit(result["reason"])
	elif result.get("formation", false):
		construction_closed.emit(result)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or not is_instance_valid(player) or not player.is_alive() or (is_inside_tree() and get_tree().paused):
		return
	if player.world_motion != null:
		if not construction is WorldGeometerConstruction: return
		var spatial := construction as WorldGeometerConstruction
		spatial.set_actors(targets)
		interaction_ledger.sync(construction.construction_id)
		interaction_ledger.advance(delta)
		for result: Dictionary in spatial.advance(delta,{},spatial.world_navigation): _report_delivery(result)
		wall_field.capture_construction()
		_sync_world_walkers()
		triangle_field.advance(delta)
		_retire_invalid_flights()
		return
	_visual_time = fmod(_visual_time + delta, TAU * 10.0)
	interaction_ledger.sync(construction.construction_id)
	interaction_ledger.advance(delta)
	for reaction: Dictionary in _wall_reactions:
		reaction["remaining"] = float(reaction["remaining"]) - delta
	_wall_reactions = _wall_reactions.filter(func(reaction: Dictionary) -> bool: return float(reaction["remaining"]) > 0.0)
	_redraw_wall_reactions()
	for result: Dictionary in construction.advance(delta, alive_positions(), player.navigation):
		_report_delivery(result)
	_retire_invalid_flights()
	_sync_wall_observers()
	wall_field.capture_construction()
	triangle_field.advance(delta)
	var pending_ids: Array[int] = []
	for pending: Dictionary in construction.grammar.pending_snapshot():
		pending_ids.append(int(pending["ticket"]))
	for ticket: int in _shot_wall_snapshots.keys():
		if ticket not in pending_ids:
			_shot_wall_snapshots.erase(ticket)
			_shot_triangle_snapshots.erase(ticket)
	queue_redraw()

func show_wall_reaction(point: Vector2, element: StringName) -> void:
	if is_world_bound(): return
	if point.is_finite():
		if _wall_reactions.size() >= 12:
			_wall_reactions.pop_front()
		_wall_reactions.append({"point": point, "element": element, "remaining": 0.25})
		_redraw_wall_reactions()

func show_triangle_reaction(points: PackedVector2Array, element: StringName, links: PackedVector2Array = PackedVector2Array(), duration: float = 0.4) -> void:
	if is_world_bound(): return
	if points.size() != 3 or not is_finite(duration) or duration <= 0.0:
		return
	for point: Vector2 in points + links:
		if not point.is_finite():
			return
	if _wall_reactions.size() >= 12:
		_wall_reactions.pop_front()
	_wall_reactions.append({"points": points, "links": links, "element": element, "remaining": duration, "duration": duration})
	_redraw_wall_reactions()

func _redraw_wall_reactions() -> void:
	_reaction_visual.reactions = _wall_reactions
	_reaction_visual.queue_redraw()

func _sync_wall_observers() -> void:
	if is_instance_valid(player) and player.world_motion != null: return
	interaction_ledger.sync(construction.construction_id)
	wall_contacts.sync(construction.construction_id, construction.shape == GeometerConstructionState.Shape.WALL and construction.has_active_figure())
	var alive_ids: Array[int] = []
	for actor: CombatActor in targets:
		if is_instance_valid(actor) and actor is EnemyActor and actor.is_alive():
			var identity := actor.get_instance_id()
			alive_ids.append(identity)
			if not _watched_walkers.has(identity):
				actor.ground_walked.connect(_on_ground_walked.bind(actor))
				_watched_walkers[identity] = actor
	for identity: int in _watched_walkers.keys():
		if identity not in alive_ids:
			var actor := _watched_walkers[identity]
			if is_instance_valid(actor):
				actor.ground_walked.disconnect(_on_ground_walked.bind(actor))
			_watched_walkers.erase(identity)
	wall_contacts.prune(alive_ids)

func _on_ground_walked(from: Vector2, to: Vector2, actor: EnemyActor) -> void:
	if is_instance_valid(player) and player.world_motion != null: return
	if not is_instance_valid(player) or not player.is_alive() or not actor.is_alive() or actor not in targets or (is_inside_tree() and get_tree().paused):
		return
	construction.refresh(alive_positions(), player.navigation)
	_sync_wall_observers()
	if construction.shape != GeometerConstructionState.Shape.WALL or not construction.has_active_figure():
		return
	var points := construction.positions()
	var contact := wall_contacts.observe(actor.get_instance_id(), from, to, points[0], points[1], actor.collision_radius)
	if not contact.is_empty():
		wall_crossed.emit(contact, actor)

func _retire_invalid_flights() -> void:
	var active_tickets: Array[int] = []
	for pending: Dictionary in construction.grammar.pending_snapshot():
		if not bool(pending["resolved"]):
			active_tickets.append(int(pending["ticket"]))
	for child: Node in get_children():
		if child is GeometerTraceProjectile and child.ticket not in active_tickets:
			child.queue_free()

func select(element: StringName) -> bool:
	if not is_instance_valid(player) or not player.is_geometer() or not player.is_alive() or (is_inside_tree() and get_tree().paused):
		return false
	return construction.grammar.select_element(element)

func clear_construction() -> void:
	player.cancel_active_cast()
	construction.clear()
	interaction_ledger.sync(0)
	wall_contacts.sync(0, false)
	wall_field.capture_construction()
	_shot_wall_snapshots.clear()
	_shot_triangle_snapshots.clear()
	triangle_field.clear()
	_wall_reactions.clear()
	_redraw_wall_reactions()
	preview_command = null
	for child: Node in get_children():
		if child is GeometerTraceProjectile:
			child.queue_free()
	queue_redraw()

func _exit_tree() -> void:
	for item: Dictionary in _world_walkers.values():
		var motion := item["motion"] as WorldActorMotion
		if motion.traversed.is_connected(item["callback"]): motion.traversed.disconnect(item["callback"])
	_world_walkers.clear()
	for actor: EnemyActor in _watched_walkers.values():
		if is_instance_valid(actor):
			actor.ground_walked.disconnect(_on_ground_walked.bind(actor))
	_watched_walkers.clear()

func outline_segments() -> Array[PackedVector2Array]:
	var points := construction.positions()
	var segments: Array[PackedVector2Array] = []
	if points.size() < 2:
		return segments
	for index: int in range(3 if points.size() == 3 else 1):
		var next := (index + 1) % points.size()
		if points[index].is_finite() and points[next].is_finite():
			segments.append(PackedVector2Array([points[index], points[next]]))
	return segments

func _draw() -> void:
	if is_instance_valid(player) and player.world_motion != null: return
	var points := construction.positions()
	if construction.shape == GeometerConstructionState.Shape.TRIANGLE and construction.has_active_figure():
		var polygon := PackedVector2Array()
		for point: Vector2 in points:
			polygon.append(to_local(point))
		var elements := construction.elements()
		var tint := Color("ffac68", 0.045) if elements[0] == &"fire" else (Color("a9e9ff", 0.055) if elements[0] == &"ice" else Color("ebe29b", 0.045))
		draw_colored_polygon(polygon, tint)
		_draw_foundation(polygon, elements[0])
		var center := (polygon[0] + polygon[1] + polygon[2]) / 3.0
		var mark := Color("cde6ed", 0.45)
		if elements[1] == &"fire":
			draw_arc(center, 10.0, 0.0, TAU, 16, Color("ffac68", 0.5), 1.0)
		elif elements[1] == &"ice":
			draw_polyline(PackedVector2Array([center + Vector2(0, -9), center + Vector2(7, 0), center + Vector2(0, 9), center + Vector2(-7, 0), center + Vector2(0, -9)]), mark, 1.0)
		else:
			draw_polyline(PackedVector2Array([center + Vector2(-8, 0), center + Vector2(-2, -6), center + Vector2(2, 6), center + Vector2(8, 0)]), Color("ebe29b", 0.5), 1.0)
	var tint := Color("b5dce8", 0.75) if not construction.suspended else Color("a4adb2", 0.40)
	for segment: PackedVector2Array in outline_segments():
		if construction.suspended or construction.shape == GeometerConstructionState.Shape.PREPARATION:
			draw_dashed_line(to_local(segment[0]), to_local(segment[1]), tint, 1.5, 8.0)
		else:
			if construction.shape == GeometerConstructionState.Shape.WALL:
				draw_line(to_local(segment[0]), to_local(segment[1]), Color(tint, 0.055), GeometerGeometry.WALL_HALF_WIDTH * 2.0)
			draw_line(to_local(segment[0]), to_local(segment[1]), tint, 1.5)
			if construction.shape == GeometerConstructionState.Shape.WALL:
				var center := to_local(segment[0].lerp(segment[1], 0.5))
				var axis := (segment[1] - segment[0]).normalized()
				var side := axis.orthogonal()
				draw_polyline(PackedVector2Array([center - axis * 6 + side * 4, center + axis * 4, center - axis * 6 - side * 4]), tint, 1.5)
	for index: int in range(points.size()):
		if points[index].is_finite():
			_draw_vertex(to_local(points[index]), construction.vertices[index].element, construction.vertices[index].actor_id > 0)
			draw_string(ThemeDB.fallback_font, to_local(points[index]) + Vector2(14, 4), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, tint)
	if preview_command != null:
		if preview_command.skill_id == &"geometer_collapse":
			return
		var point := preview_command.point
		for actor: CombatActor in targets:
			if is_instance_valid(actor) and actor.is_alive() and actor.get_instance_id() == preview_command.actor_id:
				point = actor.global_position
		if point.is_finite():
			var preview_tint := Color("87e0cf") if preview_valid else Color("ff8b8b")
			draw_arc(to_local(point), 15.0, 0.0, TAU, 24, preview_tint, 1.5)
			var candidate := points.duplicate()
			if GeometerCastCommand.is_edit_skill(preview_command.skill_id) and not candidate.is_empty():
				candidate.remove_at(0 if preview_command.skill_id == &"geometer_rewrite" else candidate.size() - 1)
			candidate.append(point)
			for index: int in range(candidate.size() if candidate.size() == 3 else candidate.size() - 1):
				var next := (index + 1) % candidate.size()
				if candidate[index].is_finite() and candidate[next].is_finite():
					draw_dashed_line(to_local(candidate[index]), to_local(candidate[next]), preview_tint, 1.0, 7.0)

func _draw_vertex(point: Vector2, element: StringName, mobile: bool) -> void:
	var tint := Color("ffac68") if element == &"fire" else (Color("a9e9ff") if element == &"ice" else Color("ebe29b"))
	if construction.suspended:
		tint = Color("a4adb2", 0.45)
	var glyph := PackedVector2Array([point + Vector2(0, -10), point + Vector2(7, 2), point + Vector2(4, 7), point + Vector2(-4, 7), point + Vector2(-7, 2), point + Vector2(-3, -3), point + Vector2(-2, 3), point + Vector2(0, -10)])
	if element == &"ice":
		glyph = PackedVector2Array([point + Vector2(0, -8), point + Vector2(7, 0), point + Vector2(0, 8), point + Vector2(-7, 0), point + Vector2(0, -8)])
	elif element == &"lightning":
		glyph = PackedVector2Array([point + Vector2(5, -8), point + Vector2(-4, 0), point + Vector2(4, 0), point + Vector2(-5, 8)])
	draw_polyline(glyph, tint, 2.0)
	if mobile:
		draw_arc(point, 12.0, 0.0, TAU, 20, tint, 1.0)
		draw_line(point + Vector2(0, -12), point + Vector2(0, -19), tint, 1.0)
		draw_circle(point + Vector2(0, -20), 2, tint)
	else:
		var base := PackedVector2Array()
		for index: int in range(17):
			base.append(point + Vector2(cos(index * TAU / 16) * 12, sin(index * TAU / 16) * 5 + 6))
		draw_polyline(base, Color(tint, tint.a * 0.65), 1.0)

func _draw_foundation(polygon: PackedVector2Array, element: StringName) -> void:
	# Six small interior motifs, never a second region or an opaque carpet.
	var center := (polygon[0] + polygon[1] + polygon[2]) / 3.0
	for index: int in range(6):
		var point := center.lerp(polygon[index % 3].lerp(polygon[(index + 1) % 3], 0.35 if index < 3 else 0.65), 0.50)
		if element == &"fire":
			var size := 2.0 + sin(_visual_time * 7 + index) * 0.6
			draw_line(point + Vector2(-size, 1), point + Vector2(0, -size), Color("ffac68", 0.32), 1.5)
			draw_line(point + Vector2(0, -size), point + Vector2(size, 1), Color("ffac68", 0.32), 1.0)
		elif element == &"ice":
			draw_polyline(PackedVector2Array([point + Vector2(0, -4), point + Vector2(3, 0), point + Vector2(0, 4), point + Vector2(-3, 0), point + Vector2(0, -4)]), Color("a9e9ff", 0.28), 1.0)
		else:
			draw_polyline(PackedVector2Array([point + Vector2(-4, 1), point + Vector2(-1, -2), point + Vector2(1, 2), point + Vector2(4, -1)]), Color("ebe29b", 0.28), 1.0)

class WallReactionVisual extends Node2D:
	## Sparse, short actual-interaction accents above bodies, separate from underlay.
	var reactions: Array[Dictionary] = []

	func _draw() -> void:
		for reaction: Dictionary in reactions:
			var alpha := float(reaction["remaining"]) / float(reaction.get("duration", 0.25))
			var element: StringName = reaction["element"]
			var color := Color("ffb574", alpha) if element == &"fire" else (Color("a9e9ff", alpha) if element == &"ice" else Color("f4e48b", alpha))
			if reaction.has("line"):
				var points: PackedVector2Array = reaction["line"]
				draw_line(to_local(points[0]), to_local(points[1]), Color(color, alpha * 0.20), GeometerGeometry.WALL_HALF_WIDTH * 2.0)
				draw_line(to_local(points[0]), to_local(points[1]), color, 2.0)
				continue
			if reaction.has("points"):
				var polygon := PackedVector2Array()
				for point: Vector2 in reaction["points"]:
					polygon.append(to_local(point))
				polygon.append(polygon[0])
				draw_polyline(polygon, Color(color, alpha * 0.55), 2.0)
				var centroid := (polygon[0] + polygon[1] + polygon[2]) / 3.0
				if element == &"fire":
					for index: int in range(3):
						var edge_center := (polygon[index] + polygon[index + 1]) / 2.0
						draw_line(centroid.lerp(edge_center, 0.2), centroid.lerp(edge_center, 0.2 + 0.5 * (1.0 - alpha)), color, 1.5)
				elif element == &"ice":
					for index: int in range(3):
						draw_line(polygon[index].lerp(centroid, 0.15), polygon[index].lerp(centroid, 0.35 + 0.4 * (1.0 - alpha)), color, 1.5)
				var links: PackedVector2Array = reaction["links"]
				for index: int in range(0, links.size() - 1, 2):
					var first := to_local(links[index])
					var second := to_local(links[index + 1])
					draw_polyline(PackedVector2Array([first, first.lerp(second, 0.4) + Vector2(4, -4), first.lerp(second, 0.6) + Vector2(-4, 4), second]), color, 1.5)
				continue
			var center := to_local(reaction["point"])
			if element == &"fire":
				draw_arc(center, 45.0 * (1.0 - alpha * 0.65), 0.0, TAU, 24, color, 2.0)
				for index: int in range(6):
					var axis := Vector2.from_angle(index * TAU / 6.0)
					draw_line(center + axis * 8.0, center + axis * 24.0, color, 1.5)
			elif element == &"ice":
				draw_polyline(PackedVector2Array([center + Vector2(0, -22), center + Vector2(14, 0), center + Vector2(0, 22), center + Vector2(-14, 0), center + Vector2(0, -22)]), color, 2.0)
			else:
				draw_polyline(PackedVector2Array([center + Vector2(-24, -5), center + Vector2(-9, 6), center + Vector2(0, -5), center + Vector2(11, 6), center + Vector2(24, -5)]), color, 2.0)
