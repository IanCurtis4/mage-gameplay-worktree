extends SceneTree
## Checkpoint51 (F9-12, P7): the final area. Every item of the validation sample
## (validation.md "Amostra de aceite humano") is checked on the committed Bosque do
## Santuário sources and its released package, and a skill proposal is reviewed,
## applied and refused on a clone of a Bosque piece without touching the originals.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const PieceStore = preload("res://scripts/map_authoring/io/source_store.gd")
const MapStore = preload("res://scripts/map_authoring/composition/map_store.gd")
const PopulationStore = preload("res://scripts/map_authoring/population/population_store.gd")
const PatrolStore = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const Release = preload("res://scripts/map_authoring/release/map_release.gd")
const Props = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const DocumentSession = preload("res://scripts/map_authoring/document/document_session.gd")
const FOLDER := "res://data/map_authoring/"
const FILES := ["sanctuary_woods_clearing.source.json","sanctuary_woods_overpass.source.json","sanctuary_woods.map.json","sanctuary_woods.population.json","sanctuary_woods.patrol.json","sanctuary_woods.rpp","release_packages.json"]
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_AREA_CHECK "+id+" "+str(ok))
static func layer(piece: Dictionary, id: String) -> Dictionary:
	for item: Dictionary in piece.layers:
		if item.layer_id == id: return item
	return {}
static func bounds(item: Dictionary) -> Rect2:
	var spacing := float(item.sample_spacing)
	return Rect2(float(item.origin_xz[0]),float(item.origin_xz[1]),(int(item.columns)-1)*spacing,(int(item.rows)-1)*spacing)
static func touches(a: Rect2, b: Rect2) -> bool: return a.grow(1.0).intersects(b)
static func inside(polygon: Array, x: float, z: float) -> bool:
	var points := PackedVector2Array()
	for pair: Array in polygon: points.append(Vector2(float(pair[0]),float(pair[1])))
	var at := Vector2(x,z)
	if Geometry2D.is_point_in_polygon(at,points): return true
	for i: int in points.size():
		if Geometry2D.get_closest_point_to_segment(at,points[i],points[(i+1)%points.size()]).distance_to(at) < 0.5: return true
	return false
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var before := {}
	for file: String in FILES: before[file] = FileAccess.get_sha256(FOLDER+file)
	var clearing := PieceStore.load_source(FOLDER+FILES[0]); var overpass := PieceStore.load_source(FOLDER+FILES[1])
	var map := MapStore.load_source(FOLDER+FILES[2]); var population := PopulationStore.load_source(FOLDER+FILES[3]); var patrol := PatrolStore.load_source(FOLDER+FILES[4])
	var fresh := Release.freshness("sanctuary_woods")
	check("sources_open_and_release_is_current",clearing.ok and overpass.ok and map.ok and population.ok and patrol.ok and fresh.get("current",false))
	if not (clearing.ok and overpass.ok and map.ok and population.ok and patrol.ok): finish(); return
	var a: Dictionary = clearing.data; var b: Dictionary = overpass.data
	# 1. Clearing with a curved path: earth samples that do not lie on one line.
	var ground := layer(a,"a_ground")
	var earth: Array = ground.get("material_masks",{}).get("earth",[])
	var points: Array[Vector2] = []
	for i: int in earth.size():
		if float(earth[i]) >= 0.5: points.append(Vector2(i%int(ground.columns),i/int(ground.columns)))
	# The trail bows: the mean row of each column leaves the chord between its two ends.
	var columns := {}
	for p: Vector2 in points:
		if not columns.has(p.x): columns[p.x] = []
		columns[p.x].append(p.y)
	var xs: Array = columns.keys(); xs.sort()
	var bow := 0.0
	if xs.size() >= 4:
		var mean := func(x: float) -> float:
			var sum := 0.0
			for z: float in columns[x]: sum += z
			return sum/columns[x].size()
		var first: float = mean.call(xs[0]); var last: float = mean.call(xs[xs.size()-1])
		for x: float in xs:
			var t: float = (x-float(xs[0]))/(float(xs[xs.size()-1])-float(xs[0]))
			bow = maxf(bow,absf(float(mean.call(x))-lerpf(first,last,t)))
	var curved: bool = points.size() >= 8 and xs.size() >= ground.columns/2 and bow >= 1.0
	check("clearing_with_two_materials_and_a_curved_path",ground.get("material_masks",{}).has_all(["earth","grass"]) and curved)
	# 2. Plateau reached by a ramp (0 → 128) and a bridge over the lower route.
	var ramp := layer(b,"b_north_ramp"); var top := layer(b,"b_north_top"); var low := layer(b,"b_low"); var west := layer(b,"b_west")
	check("plateau_reached_by_ramps",not ramp.is_empty() and ramp.heights.min() == 0.0 and ramp.heights.max() == 128.0 and top.heights.min() == 128.0 and touches(bounds(ramp),bounds(top)) and not layer(b,"b_south_ramp").is_empty())
	var bridge: Dictionary = b.special_surfaces[0] if not b.special_surfaces.is_empty() else {}
	var span := Rect2(); var bridge_y := 0.0
	if not bridge.is_empty():
		span = Rect2(Vector2(bridge.vertices_xyz[0][0],bridge.vertices_xyz[0][2]),Vector2.ZERO)
		for v: Array in bridge.vertices_xyz: span = span.expand(Vector2(v[0],v[2])); bridge_y = maxf(bridge_y,float(v[1]))
	check("bridge_over_the_lower_route",not bridge.is_empty() and span.intersects(bounds(low)) and bridge_y-float(low.heights.max()) >= 100.0)
	# 3. Fork at the west wood (lower route and both ramps) and the lower route is a dead end.
	var fork: bool = touches(bounds(west),bounds(low)) and touches(bounds(west),bounds(ramp)) and touches(bounds(west),bounds(layer(b,"b_south_ramp")))
	var low_rect := bounds(low)
	var dead_end := true
	for other: Dictionary in b.layers:
		if other.layer_id in ["b_low","b_west"]: continue
		var rect := bounds(other)
		# Touching only along x (above/below in z) is the ramp/plateau side, not a way out east.
		if rect.grow(1.0).intersects(low_rect) and rect.end.x > low_rect.end.x: dead_end = false
	check("fork_and_dead_end",fork and dead_end and low_rect.end.x >= bounds(top).end.x)
	# 4. Shrine: region, broken pillars and the completion interaction inside it.
	var shrine: Dictionary = {}
	for region: Dictionary in b.regions:
		if region.region_id == "woods_shrine": shrine = region
	var overpass_at := Vector3.ZERO
	for instance: Dictionary in map.data.instances:
		if instance.instance_id == "overpass": overpass_at = Vector3(instance.position_xyz[0],instance.position_xyz[1],instance.position_xyz[2])
	var pillars: Array = b.placements.filter(func(p: Dictionary) -> bool: return p.definition_id == "broken_pillar" and inside(shrine.get("polygon_xz",[]),float(p.position_xyz[0]),float(p.position_xyz[2])))
	var completion: Array = population.data.interactions.filter(func(i: Dictionary) -> bool: return i.kind == "phase_completion")
	var goal: Array = completion[0].position_xyz if not completion.is_empty() else [0,0,0]
	check("shrine_with_pillars_and_completion",not shrine.is_empty() and pillars.size() >= 3 and completion.size() == 1 and inside(shrine.polygon_xz,float(goal[0])-overpass_at.x,float(goal[2])-overpass_at.z))
	# 5. Seam between the two pieces, in the released package too.
	var loaded := Release.load_package("sanctuary_woods")
	var instances: Array = loaded.get("package",{}).get("population_package",{}).get("map_package",{}).get("render_instances",[])
	check("seam_between_two_pieces",map.data.links.size() == 1 and map.data.links[0].a_instance == "clearing" and map.data.links[0].b_instance == "overpass" and instances.size() == 2)
	# 6. Decorative vegetation, blocking rock and occluding trees from the passive catalog.
	var catalog := Props.load_catalog()
	var counts := {}
	for piece: Dictionary in [a,b]:
		for placement: Dictionary in piece.placements: counts[placement.definition_id] = int(counts.get(placement.definition_id,0))+1
	var caps: Dictionary = {}
	for id: String in counts: caps[id] = catalog.definitions[id].capabilities if catalog.ok and catalog.definitions.has(id) else {}
	check("vegetation_rock_and_trees",counts.get("woodland_shrub",0) > 0 and caps.get("woodland_shrub",{}).get("decoration",false) and not caps.get("woodland_shrub",{}).get("body",true) and counts.get("moss_boulder",0) > 0 and caps.moss_boulder.body and counts.get("oak_tree",0) > 0 and caps.oak_tree.camera_occlusion)
	# 7. Dispersed population, a concentrated group and a patrol with its fixed slot.
	var modes: Array = population.data.brushes.map(func(brush: Dictionary) -> String: return brush.mode)
	var route: Dictionary = patrol.data.patrols[0] if not patrol.data.patrols.is_empty() else {}
	var patrolled: Array = loaded.get("package",{}).get("manifest",{}).get("population",{}).get("slots",[]).filter(func(slot: Dictionary) -> bool: return slot.has("patrol"))
	var fixed: Array = population.data.slots.filter(func(slot: Dictionary) -> bool: return slot.fixed and slot.slot_id in route.get("slot_ids",[]))
	check("dispersed_group_and_patrol",modes.has("dispersed") and modes.has("concentrated") and not route.is_empty() and route.waypoints.size() >= 2 and fixed.size() == 1 and patrolled.size() == 1)
	# 8. Entrance and objective use the existing mechanics.
	var entrance: bool = a.sockets.any(func(s: Dictionary) -> bool: return s.kind == "entrance") and population.data.entrance.size() == 1
	check("entrance_and_existing_objective",entrance and loaded.get("package",{}).get("manifest",{}).get("objectives",[]).size() == 1)
	# 9. A skill proposal on a clone of the clearing: reviewed, applied once, refused out of scope.
	var clone := a.duplicate(true); clone.document_id = "sanctuary_woods_clearing_clone"; clone.name = "Clareira · cópia de aceite"
	var exported := Exchange.export_bundle("piece",clone,Exchange.policy(["placements"]),"Girar uma rocha da clareira")
	var candidate := clone.duplicate(true)
	var rock := -1
	for i: int in candidate.placements.size():
		if candidate.placements[i].definition_id == "moss_boulder" and rock < 0: rock = i
	candidate.placements[rock].rotation_y = 90.0
	var proposed: Dictionary = Exchange.propose(exported.get("bundle",{}),candidate) if exported.get("ok",false) else {"ok":false}
	var prepared: Dictionary = Exchange.prepare(exported.bundle,proposed.bundle,clone) if proposed.get("ok",false) else {"ok":false}
	var named: bool = prepared.get("ok",false) and JSON.stringify(prepared.get("diff",[])).contains(String(clone.placements[rock].placement_id))
	var session := DocumentSession.new(); session.replace(clone)
	var start := Schema.semantic_hash(session.document().to_data())
	var applied: Dictionary = session.apply(prepared.source) if prepared.get("ok",false) else {"ok":false}
	var rotated: bool = applied.get("ok",false) and float(session.document().to_data().placements[rock].rotation_y) == 90.0
	var undone: bool = session.undo() and Schema.semantic_hash(session.document().to_data()) == start
	check("proposal_reviewed_and_applied_once_on_a_clone",exported.get("ok",false) and named and rotated and undone)
	var reach := clone.duplicate(true); reach.layers[0].heights[0] = float(reach.layers[0].heights[0])+16.0
	var outside: Dictionary = Exchange.propose(exported.bundle,reach) if exported.get("ok",false) else {"ok":true}
	var refused: bool = not outside.get("ok",true) or not Exchange.prepare(exported.bundle,outside.bundle,clone).get("ok",true)
	check("out_of_scope_proposal_is_refused_without_loss",refused and Schema.semantic_hash(session.document().to_data()) == start)
	var after := {}
	for file: String in FILES: after[file] = FileAccess.get_sha256(FOLDER+file)
	check("committed_bosque_untouched",after == before)
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_AREA_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
