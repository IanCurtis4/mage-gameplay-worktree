class_name ExpeditionGeometryView
extends Node2D
## Approved D05 adapter. Projection is presentation only; all picks return WorldPoints.
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")
const FieldViews = preload("res://scripts/world/world_field_view.gd")
const AXIS := ProjectionMath.AXIS
const PICK_PADDING := 6.0
const ASSIST_RADIUS := 68.0
const LOCK_RADIUS := 80.0
var field_views := FieldViews.new()
var geometry: WorldGeometry
var _epoch := 0
var _surfaces: Array = []
var _hidden: Array[String] = []
var _decks: Array[Polygon2D] = []
var _solids: Array[Polygon2D] = []
var _actors: Array[WeakRef] = []
var marker: ExpeditionWorldPoint
var marker_valid := false
var attack_preview: Dictionary = {}
var controller: RunController
var _effects: Node2D

static func project(point: Vector3) -> Vector2: return ProjectionMath.project(point)
static func ray(canvas_point: Vector2) -> Dictionary: return ProjectionMath.ray(canvas_point)
func configure(world: WorldGeometry) -> Dictionary:
	var result := world.presentation_snapshot(world.geometry_revision)
	if not result["ok"]: return result
	field_views.clear()
	geometry = world; _epoch = world.configuration_revision
	_surfaces = result["data"]["surfaces"]
	for deck: Polygon2D in _decks: deck.queue_free()
	_decks.clear()
	for side: Polygon2D in _solids: side.queue_free()
	_solids.clear()
	for volume: AABB in result["data"]["volumes"]:
		var corners: Array[Vector3] = [volume.position,Vector3(volume.end.x,volume.position.y,volume.position.z),Vector3(volume.end.x,volume.position.y,volume.end.z),Vector3(volume.position.x,volume.position.y,volume.end.z)]
		for index: int in 4:
			var a := corners[index]; var b := corners[(index+1)%4]; var top := Vector3.UP*volume.size.y
			var side := Polygon2D.new(); side.polygon = PackedVector2Array([project(a),project(b),project(b+top),project(a+top)])
			side.color = Color("3d4e65"); side.z_index = clampi(floori(volume.end.y*4)-1,-4000,4000); add_child(side); _solids.append(side)
	for cell: Dictionary in _surfaces:
		var deck := Polygon2D.new(); var polygon := PackedVector2Array(); var y := 0.0
		for point: Vector3 in cell["vertices"]: polygon.append(project(point)); y += point.y
		deck.polygon = polygon; deck.z_index = floori(y/float(cell["vertices"].size())*4)
		var ramp := absf(Vector3(cell["vertices"][0]).y-Vector3(cell["vertices"][1]).y) > WorldGeometry.EPS
		deck.color = Color("779781") if ramp else (Color("61728b") if y > 0 else Color("333f51"))
		add_child(deck); _decks.append(deck)
		var line := Line2D.new(); line.points = polygon; line.add_point(polygon[0]); line.width = 2; line.default_color = Color("b3c8d2"); deck.add_child(line)
		var label := Label.new(); label.text = "RAMPA" if ramp else (("PONTE / ANDAR SUPERIOR" if "/bridge/" in cell["surface_id"] else "PATAMAR SUPERIOR") if y > 0 else "CHÃO / PASSAGEM INFERIOR")
		label.position = polygon[0]+Vector2(12,8); label.add_theme_font_size_override("font_size",14); deck.add_child(label)
	clear_world_pulses()
	if _effects == null:
		_effects = Node2D.new(); _effects.z_index = 4090; add_child(_effects); _effects.draw.connect(_draw_effects)
	return result
func current() -> bool:
	return geometry != null and geometry.configuration_revision == _epoch

func present_campaign(host: RunController) -> void:
	if host.campaign_runtime == null or _effects == null: return
	var state := host.campaign_runtime.state
	for portal: Dictionary in state.manifest_data["portals"]:
		if portal["from_stage"] != state.current_stage_id: continue
		var marker_name := "Portal_" + String(portal["portal_id"])
		var marker_node := _effects.get_node_or_null(marker_name) as ExpeditionPortal
		if marker_node == null:
			marker_node = ExpeditionPortal.new()
			marker_node.name = marker_name
			_effects.add_child(marker_node)
		marker_node.configure(state.portal_view(portal["portal_id"]), state.manifest_data)
	for objective: Dictionary in state.manifest_data["objectives"]:
		if objective["stage_id"] != state.current_stage_id: continue
		var marker_name := "Objective_" + String(objective["objective_id"])
		var caption := _effects.get_node_or_null(marker_name) as Label
		if caption == null:
			caption = Label.new(); caption.name = marker_name
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption.add_theme_color_override("font_color", Color("ffe49d"))
			_effects.add_child(caption)
		caption.text = "◆ SAÍDA FINAL" if objective["outcome"] == "phase_completion" else ("◆ OBJETIVO DO ESTÁGIO" if objective["outcome"] == "stage_unlock" else "◆ REFÚGIO — SUSPENDER")
		caption.position = project(objective["point"]["position"]) + Vector2(-80,-36)
func visible_surfaces() -> Array[String]:
	var result: Array[String] = []
	for cell: Dictionary in _surfaces:
		if cell["surface_id"] not in _hidden: result.append(cell["surface_id"])
	return result
func hide_surfaces(ids: Array[String]) -> void:
	_hidden = ids.duplicate()
	if marker != null and marker.surface_id in _hidden: indicate(null,false)
	for index: int in _decks.size(): _decks[index].visible = _surfaces[index]["surface_id"] not in _hidden
func pick(canvas_point: Vector2, revision: int) -> Dictionary:
	if not current(): return WorldSkillCast.failure(&"world_reconfigured")
	var cast := ray(canvas_point)
	return geometry.resolve_surface(cast["origin"],cast["direction"],visible_surfaces(),revision)
func observe(actor: CombatActor) -> void:
	for reference: WeakRef in _actors:
		if reference.get_ref() == actor: return
	_actors.append(weakref(actor)); sync()
func sync() -> void:
	if not current(): return
	for reference: WeakRef in _actors:
		var actor := reference.get_ref() as CombatActor
		if not is_instance_valid(actor) or actor.world_motion == null or actor.world_motion.geometry != geometry or not actor.world_motion.is_current_world(): continue
		actor.global_position = to_global(project(actor.world_point().position))
		actor.z_index = clampi(floori(actor.world_point().position.y*4)+2,-4000,4000)
		actor.visible = actor.world_point().surface_id not in _hidden
	field_views.sync(self,controller,geometry,_hidden)
	for entry: Dictionary in field_views.entries.values():
		for part: Node2D in entry.parts:
			var record: Dictionary = part.get_meta("canvas_order_record")
			part.z_index = clampi(floori(float(record.anchor.y)*4)+2,-4000,4000)
	if _effects != null: _effects.queue_redraw()
## Picks what the player sees: the drawn body, then (assist) the nearest body or the held lock.
## Same radii as flat BattleTargeting so both modes honor the "Trava inteligente" preference alike.
func actor_at(canvas_point: Vector2, candidates: Array[CombatActor], previous: CombatActor = null, assist: bool = false) -> CombatActor:
	var direct: CombatActor; var direct_distance := INF; var direct_tie := false
	var nearby: CombatActor; var nearby_distance := INF
	var lock_ok := false; var previous_inside := false
	for actor: CombatActor in candidates:
		if not _pickable(actor): continue
		var body := actor.pick_body_rect()
		var foot := to_global(project(actor.world_point().position))
		var center := foot+Vector2(0,body.position.y*0.5)
		var distance := canvas_point.distance_to(center)
		var inside := Rect2(foot+body.position,body.size).grow(PICK_PADDING).has_point(canvas_point)
		if not inside and not (assist and distance <= LOCK_RADIUS): continue
		if not _actor_visible(actor,foot): continue
		if inside:
			# Exact ties (stacked bodies) resolve to the one drawn in front, then the lower id.
			if distance < direct_distance-WorldGeometry.EPS or (absf(distance-direct_distance) <= WorldGeometry.EPS and _in_front(actor,direct)):
				direct_tie = direct != null and absf(distance-direct_distance) <= WorldGeometry.EPS; direct = actor; direct_distance = distance
			elif absf(distance-direct_distance) <= WorldGeometry.EPS: direct_tie = true
		if actor == previous: lock_ok = distance <= LOCK_RADIUS; previous_inside = inside
		if assist and distance <= ASSIST_RADIUS:
			if distance < nearby_distance-WorldGeometry.EPS or (absf(distance-nearby_distance) <= WorldGeometry.EPS and _in_front(actor,nearby)): nearby = actor; nearby_distance = distance
	if direct != null: return direct if not direct_tie or not previous_inside else previous
	if not assist: return null
	if lock_ok: return previous
	return nearby
func _in_front(actor: CombatActor, other: CombatActor) -> bool:
	if other == null: return true
	if actor.global_position.y != other.global_position.y: return actor.global_position.y > other.global_position.y
	return actor.get_instance_id() < other.get_instance_id()
func _pickable(actor: CombatActor) -> bool:
	return is_instance_valid(actor) and actor.is_alive() and actor.visible and actor.world_motion != null and actor.world_motion.geometry == geometry and actor.world_motion.is_current_world()
func _actor_visible(actor: CombatActor, foot: Vector2) -> bool:
	# Seams between authored cells can resolve the foot pixel to a neighbour cell; fall back to an occlusion sweep.
	var seen := pick(to_local(foot),geometry.geometry_revision)
	if seen["ok"] and seen["data"]["point"]["surface_id"] == actor.world_point().surface_id: return true
	return point_visible(actor.world_point().position+Vector3.UP*float(actor.world_motion.profile().get("height",0.0))*0.5)
## P7-C5: only the destination marker is kept; the planned path is no longer drawn nor stored (`_path_points` is accepted for old callers and ignored).
func indicate(point: ExpeditionWorldPoint, valid: bool, _path_points: Array = []) -> void:
	marker = ExpeditionWorldPoint.create(point.stage_id,point.surface_id,point.position) if point != null else null
	marker_valid = valid
	if _effects != null: _effects.queue_redraw()
func _process(_delta: float) -> void: sync()
func _draw_effects() -> void:
	if not current(): return
	if not attack_preview.is_empty():
		var tint := Color("79e5ba") if attack_preview["valid"] else Color("ff807d")
		_effects.draw_line(project(attack_preview["from"]),project(attack_preview["to"]),tint,3,true)
	var tint := Color("79e5ba") if marker_valid else Color("ff807d")
	if marker != null:
		var center := project(marker.position)
		_effects.draw_arc(center,14,0,TAU,40,tint,2,true)
		_effects.draw_line(center-Vector2(20,0),center+Vector2(20,0),tint,1,true)
		_effects.draw_line(center-Vector2(0,10),center+Vector2(0,10),tint,1,true)
	if controller == null: return
	_draw_objective_rings(controller)
	_draw_flights(controller)
	if controller.geometer_casting != null and controller.geometer_casting.is_world_bound():
		var spatial := controller.geometer_casting.construction as WorldGeometerConstruction
		var vertices := spatial.world_points()
		for index: int in vertices.size():
			_effects.draw_circle(project(vertices[index].position),5,Color("ffe49d"))
			if index > 0: _effects.draw_line(project(vertices[index-1].position),project(vertices[index].position),Color("ffe49d"),3,true)
		if vertices.size() == 3: _draw_triangle_closing_edge(vertices)
## Ground circle where an objective accepts the player (ExpeditionService._at_point: 48).
const OBJECTIVE_REACH := 48.0
func _draw_objective_rings(host: RunController) -> void:
	if host.campaign_runtime == null: return
	var state := host.campaign_runtime.state
	for objective: Dictionary in state.manifest_data["objectives"]:
		if objective["stage_id"] != state.current_stage_id: continue
		var center: Vector3 = objective["point"]["position"]
		var ring := PackedVector2Array()
		for index: int in 33:
			var angle := TAU*index/32.0
			ring.append(project(center+Vector3(cos(angle),0,sin(angle))*OBJECTIVE_REACH))
		_effects.draw_polyline(ring,Color("ffe49d"),2.0,true)
func _draw_triangle_closing_edge(vertices: Array) -> void:
	_effects.draw_line(project(vertices[2].position),project(vertices[0].position),Color("ffe49d"),3,true)
func point_visible(point: Vector3) -> bool:
	if not current(): return false
	var camera_ray := ray(project(point))
	var contact := geometry.sweep(camera_ray["origin"],point,{"radius":0.0,"height":0.0},geometry.geometry_revision)
	return contact["ok"] and (not contact["data"]["hit"] or float(contact["data"]["fraction"]) >= 1.0-WorldGeometry.EPS)
func _draw_flights(node: Node) -> void:
	for child: Node in node.get_children():
		if child is PlayerProjectile or child is ArrowProjectile or child is GeometerTraceProjectile:
			var flight: WorldProjectileMotion = child.world_flight
			if flight != null and flight.geometry == geometry and point_visible(flight.position):
				# P6-A2: silhouette by recipe (family/element/skill); same position, collider and flight data.
				var head := project(flight.position)
				var heading := project(flight.position+flight.direction*20.0)-head
				var angle := heading.angle() if heading.length_squared() > 0.0001 else 0.0
				WorldProjectileArt.draw(_effects,WorldProjectileArt.spec(child),head,angle,flight.travelled)
		elif child is GeometerCasting: _draw_flights(child)

## P6-A2: Elementalist pulses/arc in the spatial world. A BattleIndicators instance is reused as
## the painter (same fire/ice/lightning identity as the flat arena), parented to the effects layer,
## fed projected coordinates and aged by its own pausable process. Presentation only.
const GROUND_SCREEN_SCALE := 1.2 # Ground radius -> projected half-width (AXIS: 0.85*sqrt(2)).
var _world_pulses: BattleIndicators

func _ensure_world_pulses() -> BattleIndicators:
	if _effects == null: return null
	if not is_instance_valid(_world_pulses):
		_world_pulses = BattleIndicators.new()
		_world_pulses.name = "WorldElementalistPulses"
		_world_pulses.process_mode = Node.PROCESS_MODE_PAUSABLE
		_effects.add_child(_world_pulses)
	return _world_pulses

func _can_present(point: Vector3) -> bool:
	if not current() or (controller != null and bool(controller.get("snapshot_passive"))): return false
	return point.is_finite() and point_visible(point)

func show_elementalist_pulse(skill_id: StringName, center: Vector3, radius: float, element: StringName) -> void:
	if not _can_present(center): return
	var painter := _ensure_world_pulses()
	if painter != null: painter.show_elementalist_pulse(skill_id,project(center),radius*GROUND_SCREEN_SCALE,element)

func show_elementalist_arc_link(from: Vector3, to: Vector3) -> void:
	if not _can_present(from) and not _can_present(to): return
	var painter := _ensure_world_pulses()
	if painter != null: painter.show_elementalist_arc_link(project(from),project(to))

func clear_world_pulses() -> void:
	if is_instance_valid(_world_pulses):
		_world_pulses.elementalist_pulses.clear(); _world_pulses.elementalist_arc_links.clear(); _world_pulses.queue_redraw()

func _exit_tree() -> void:
	field_views.clear()
