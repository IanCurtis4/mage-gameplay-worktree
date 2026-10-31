extends SceneTree
## Checkpoint35: A* order and the cross-query predicate memo against the
## original Dijkstra order and a fresh world. No cap, body or budget change.
const Fixture = preload("res://tests/map_editor_navigation_batch_test.gd")
const Ports = preload("res://tests/map_editor_port_fragments_test.gd")
const Organic = preload("res://tests/map_editor_organic_test.gd")
const Lazy = preload("res://tests/map_editor_navigation_lazy_test.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const PROFILE := {"radius":8.0,"height":32.0,"connector_kinds":["walk"]}
const ORGANIC_PROFILE := {"radius":20.0,"height":32.0,"connector_kinds":["walk"]}
var checks: Array[Dictionary] = []
var metrics: Array[Dictionary] = []
var walked := {}
var same_outcome := true; var cost_close := true; var routes_walk := true; var no_more_expansions := true; var fewer_somewhere := false
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ASTAR_CHECK "+id+" "+str(ok))
func usec(started: int) -> int: return Time.get_ticks_usec()-started
# Results carry the world's geometry_revision counter; compare the answer only.
static func same(a: Dictionary, b: Dictionary) -> bool:
	return a.ok == b.ok and String(a.get("error_code","")) == String(b.get("error_code","")) and a.get("data",{}) == b.get("data",{})
# Same lazy producer, no memo: only the frontier order differs.
func differential(id: String, world: WorldGeometry, a: ExpeditionWorldPoint, b: ExpeditionWorldPoint, profile: Dictionary, walker: Callable) -> void:
	var dt := {"enabled":true}; var at := {"enabled":true}
	var started := Time.get_ticks_usec(); var dijkstra := world._path(a,b,profile,world.geometry_revision,null,true,dt,false,false); var d_usec := usec(started)
	started = Time.get_ticks_usec(); var astar := world._path(a,b,profile,world.geometry_revision,null,true,at,false,true); var a_usec := usec(started)
	var outcome: bool = dijkstra.ok == astar.ok and String(dijkstra.get("error_code","")) == String(astar.get("error_code",""))
	same_outcome = same_outcome and outcome
	if astar.ok and dijkstra.ok:
		cost_close = cost_close and absf(float(astar.data.cost)-float(dijkstra.data.cost)) <= 0.001
		var astar_walks: bool = walker.call(world,astar,profile); var dijkstra_walks: bool = walker.call(world,dijkstra,profile)
		# The A* route must walk wherever the original route walks.
		routes_walk = routes_walk and (astar_walks or not dijkstra_walks)
		walked[id] = {"astar":astar_walks,"dijkstra":dijkstra_walks,"same_points":astar.data.points == dijkstra.data.points}
	if not at.get("direct",false):
		no_more_expansions = no_more_expansions and int(at.get("expansions",0)) <= int(dt.get("expansions",0))
		fewer_somewhere = fewer_somewhere or int(at.get("expansions",0)) < int(dt.get("expansions",0))
	metrics.append({"id":id,"ok":astar.ok,"walk":walked.get(id,{}),"dijkstra_usec":d_usec,"astar_usec":a_usec,"dijkstra_expansions":dt.get("expansions",0),"astar_expansions":at.get("expansions",0),"dijkstra_edge_tests":dt.get("edge_tests",0),"astar_edge_tests":at.get("edge_tests",0),"direct":at.get("direct",false),"fallback":at.get("heuristic_fallback",false)})
	print("F9_ASTAR_CASE "+JSON.stringify(metrics[-1]))
static func port_walk(world: WorldGeometry, result: Dictionary, profile: Dictionary) -> bool: return Fixture.walk(world,result,profile)
static func organic_walk(world: WorldGeometry, result: Dictionary, profile: Dictionary) -> bool: return Organic.walk(world,result.data,profile)
static func port_world(directional: bool = false) -> WorldGeometry:
	var world := WorldGeometry.new(); world.configure(Fixture.fixture(directional),"port_fixture")
	world.insert_obstacle("middle",AABB(Vector3(98,-1,46),Vector3(4,60,8)),world.geometry_revision)
	return world
func run() -> void:
	# 1. Differential on the port fixture (all radii, both directions, one-way).
	for radius: float in [0.25,2.0,8.0,20.0]:
		var world := port_world(); var profile := PROFILE.duplicate(true); profile.radius = radius
		var a := Ports.at(world,Vector3(25,0,25)); var b := Ports.at(world,Vector3(175,0,75))
		differential("port_r%s_forward"%radius,world,a,b,profile,port_walk); differential("port_r%s_reverse"%radius,world,b,a,profile,port_walk)
	var one_way := port_world(true)
	differential("one_way_forward",one_way,Ports.at(one_way,Vector3(25,0,25)),Ports.at(one_way,Vector3(175,0,75)),PROFILE,port_walk)
	differential("one_way_reverse",one_way,Ports.at(one_way,Vector3(175,0,75)),Ports.at(one_way,Vector3(25,0,25)),PROFILE,port_walk)
	# 2. Differential on real curved terrain with masses (the NavigationContext world).
	var built := Maps.compile(Organic.map_source(Organic.gaussian(5)))
	check("organic_terrain_publishes",built.ok)
	var organic_manifest: ExpeditionManifest = Maps.manifest(built.package) if built.ok else null
	var organic := WorldGeometry.new()
	if built.ok:
		for index: int in 2: organic_manifest._data.stages[0].volumes.append(AABB(Vector3(500,150,500),Vector3(200,200,200)))
		organic.configure(organic_manifest,"map_preview")
		var surfaces: Array = organic._stage.surfaces; var count := surfaces.size()
		for pair: Array in [[0,count-1],[count-1,0],[0,count/2],[count/4,(3*count)/4],[count/3,count-2]]:
			var a := ExpeditionWorldPoint.create("map_preview",surfaces[pair[0]].surface_id,Maps._center(surfaces[pair[0]]))
			var b := ExpeditionWorldPoint.create("map_preview",surfaces[pair[1]].surface_id,Maps._center(surfaces[pair[1]]))
			differential("organic_%d_%d"%[pair[0],pair[1]],organic,a,b,ORGANIC_PROFILE,organic_walk)
	check("astar_keeps_dijkstra_outcome_and_error",same_outcome)
	check("astar_cost_matches_dijkstra",cost_close)
	check("astar_routes_walk_with_canonical_body",routes_walk)
	check("astar_never_expands_more_states",no_more_expansions)
	check("astar_expands_fewer_states_on_real_detours",fewer_somewhere)
	# 3. Synthetic graphs cheaper than their chords fall back to the original order.
	var heap := Lazy.heap_world(false,WorldGeometry.EPS*2.0); var heap_trace := {"enabled":true}
	var heap_result := heap._path(Lazy.heap_point("@from"),Lazy.heap_point("@to"),{"radius":0.25,"height":1.0,"connector_kinds":["walk"]},heap.geometry_revision,null,true,heap_trace)
	check("inconsistent_synthetic_graph_falls_back_to_dijkstra",heap_trace.get("heuristic_fallback",false) and heap_result.ok and heap_result.data.points[1].position == Vector3(10,0,2))
	# 4. Shared memo: a repeated query only hits, and equals a fresh world.
	var warm := port_world(); var fresh := port_world()
	var from := Ports.at(warm,Vector3(25,0,25)); var to := Ports.at(warm,Vector3(175,0,75))
	var t1 := {"enabled":true}; var t2 := {"enabled":true}
	var started := Time.get_ticks_usec(); var first := warm._path(from,to,PROFILE,warm.geometry_revision,null,true,t1); var cold_usec := usec(started)
	started = Time.get_ticks_usec(); var second := warm._path(from,to,PROFILE,warm.geometry_revision,null,true,t2); var warm_usec := usec(started)
	check("shared_memo_second_query_is_identical",first.ok and same(second,first) and same(second,fresh.path(from,to,PROFILE,fresh.geometry_revision)))
	check("shared_memo_second_query_only_hits",int(t2.memo_misses) == int(t1.memo_misses) and int(t2.memo_hits) > int(t1.memo_hits))
	metrics.append({"id":"shared_memo_repeat","cold_usec":cold_usec,"warm_usec":warm_usec,"entries":t2.memo_entries})
	var reverse_ok := same(warm.path(to,from,PROFILE,warm.geometry_revision),fresh.path(to,from,PROFILE,fresh.geometry_revision))
	var other := PROFILE.duplicate(true); other.radius = 20.0
	check("other_query_and_profile_equal_fresh_world",reverse_ok and same(warm.path(from,to,other,warm.geometry_revision),fresh.path(from,to,other,fresh.geometry_revision)))
	# 5. Every mutation invalidates the shared memo.
	var wall := AABB(Vector3(90,-50,-500),Vector3(20,200,1000))
	check("wall_inserts_without_occupants",warm.insert_obstacle("wall",wall,warm.geometry_revision).ok and fresh.insert_obstacle("wall",wall,fresh.geometry_revision).ok)
	var blocked := warm.path(from,to,PROFILE,warm.geometry_revision)
	check("obstacle_insert_invalidates_shared_memo",not blocked.ok and same(blocked,fresh.path(from,to,PROFILE,fresh.geometry_revision)))
	warm.remove_obstacle("wall",warm.geometry_revision); fresh.remove_obstacle("wall",fresh.geometry_revision)
	check("obstacle_remove_invalidates_shared_memo",same(warm.path(from,to,PROFILE,warm.geometry_revision),first) and same(first,fresh.path(from,to,PROFILE,fresh.geometry_revision)))
	var segment := WorldSolidSegment.new(); segment.configure(Ports.at(warm,Vector3(60,0,25)),Vector3.BACK,12,3,40,PROFILE)
	var inserted := warm.insert_segment("segment",segment,warm.geometry_revision); var inserted_fresh := fresh.insert_segment("segment",segment,fresh.geometry_revision)
	check("segment_insert_invalidates_shared_memo",same(inserted,inserted_fresh) and same(warm.path(from,to,PROFILE,warm.geometry_revision),fresh.path(from,to,PROFILE,fresh.geometry_revision)))
	var candidate := WorldSolidSegment.new(); candidate.configure(Ports.at(warm,Vector3(100,0,50)),Vector3.RIGHT,12,3,40,PROFILE)
	var entries_before: int = warm._navigation_shared.get("memo",{}).get("entries",0)
	var speculative := warm._path(from,to,PROFILE,warm.geometry_revision,candidate)
	check("speculative_segment_never_reads_or_writes_shared_memo",same(speculative,fresh._path(from,to,PROFILE,fresh.geometry_revision,candidate,false)) and int(warm._navigation_shared.get("memo",{}).get("entries",0)) == entries_before)
	if built.ok:
		warm.configure(organic_manifest,"map_preview"); var organic_fresh := WorldGeometry.new(); organic_fresh.configure(organic_manifest,"map_preview")
		var surfaces: Array = organic_fresh._stage.surfaces
		var oa := ExpeditionWorldPoint.create("map_preview",surfaces[0].surface_id,Maps._center(surfaces[0])); var ob := ExpeditionWorldPoint.create("map_preview",surfaces[-1].surface_id,Maps._center(surfaces[-1]))
		check("reconfigure_invalidates_shared_memo",same(warm.path(oa,ob,ORGANIC_PROFILE,warm.geometry_revision),organic_fresh.path(oa,ob,ORGANIC_PROFILE,organic_fresh.geometry_revision)))
	else: check("reconfigure_invalidates_shared_memo",false)
	# 6. insert_obstacle protection paths run at the same revision with the new
	# volume; a warm memo must not keep the pre-insert visibility.
	var guarded := port_world(); var guarded_fresh := port_world()
	var socket := {"socket_id":"astar_probe","surface_id":to.surface_id,"position":to.position}
	guarded._stage.sockets.append(socket.duplicate(true)); guarded_fresh._stage.sockets.append(socket.duplicate(true))
	for item: WorldGeometry in [guarded,guarded_fresh]: item.set_occupant("probe_actor",from,PROFILE,item.geometry_revision)
	var warmed := guarded.path(from,to,PROFILE,guarded.geometry_revision)
	var refused := guarded.insert_obstacle("wall",wall,guarded.geometry_revision)
	check("protection_refuses_disconnecting_wall_with_warm_memo",warmed.ok and not refused.ok and String(refused.get("error_code","")) == "would_disconnect" and same(refused,guarded_fresh.insert_obstacle("wall",wall,guarded_fresh.geometry_revision)))
	check("refused_wall_leaves_route_identical",same(guarded.path(from,to,PROFILE,guarded.geometry_revision),warmed))
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	var evidence := OS.get_environment("F9_EVIDENCE")
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("astar_metrics.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify({"metrics":metrics},"\t",true,true)); file.close()
	print("F9_ASTAR_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
