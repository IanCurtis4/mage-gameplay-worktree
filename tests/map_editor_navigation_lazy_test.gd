extends SceneTree
## Differential against the same canonical eager producer, plus explicit heap
## fixtures for EPS/zero-cost discovery. Synthetic heap cases are not physics.
const Fixture = preload("res://tests/map_editor_navigation_batch_test.gd")
const Ports = preload("res://tests/map_editor_port_fragments_test.gd")
const PROFILE := {"radius":8.0,"height":32.0,"connector_kinds":["walk"]}
class HeapWorld extends WorldGeometry:
	var injected: Dictionary = {}
	func _navigation_direct(_a: ExpeditionWorldPoint, _b: ExpeditionWorldPoint, _profile: Dictionary, _revision: int, _candidate: WorldSolidSegment) -> Dictionary: return _failure(&"unsupported_contact")
	func _clear_path_segment(_a: Vector3, _b: Vector3, _profile: Dictionary, _candidate: WorldSolidSegment, _surface: String = "", _mass_context: Dictionary = {}, _segment_context: Variant = null) -> bool: return false
	func _navigation_graph(_a: ExpeditionWorldPoint, _b: ExpeditionWorldPoint, _profile: Dictionary, _candidate: WorldSolidSegment, _terminals: Dictionary = {}, _pairs: Array = [], _control: Dictionary = {}, _generation: Dictionary = {}) -> Dictionary: return injected.duplicate(true)
var checks: Array[Dictionary] = []
var measurements: Array[Dictionary] = []
var moved_all := true
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_LAZY_CHECK "+id+" "+str(ok))
func compare(id: String, world: WorldGeometry, a: ExpeditionWorldPoint, b: ExpeditionWorldPoint, profile: Dictionary, candidate: WorldSolidSegment = null, physical: bool = true) -> Dictionary:
	var old_trace := {"enabled":true}; var new_trace := {"enabled":true}
	var started := Time.get_ticks_usec(); var old := world._path(a,b,profile,world.geometry_revision,candidate,false,old_trace); var old_usec := Time.get_ticks_usec()-started
	started = Time.get_ticks_usec(); var current := world._path(a,b,profile,world.geometry_revision,candidate,true,new_trace); var new_usec := Time.get_ticks_usec()-started
	check(id+"_same_points_connections_cost_or_error",current == old)
	measurements.append({"id":id,"eager_usec":old_usec,"lazy_usec":new_usec,"eager":old_trace,"lazy":new_trace})
	if physical and current.ok and candidate == null: moved_all = moved_all and Fixture.walk(world,current,profile)
	return {"old":old,"current":current,"old_trace":old_trace,"new_trace":new_trace}
func run() -> void:
	for radius: float in [0.25,2.0,8.0,20.0]:
		var world := WorldGeometry.new(); world.configure(Fixture.fixture(),"port_fixture")
		world.insert_obstacle("middle",AABB(Vector3(98,-1,46),Vector3(4,60,8)),world.geometry_revision)
		var profile := PROFILE.duplicate(true); profile.radius = radius
		var a := Ports.at(world,Vector3(25,0,25)); var b := Ports.at(world,Vector3(175,0,75))
		compare("radius_%s_forward"%radius,world,a,b,profile); compare("radius_%s_reverse"%radius,world,b,a,profile)
	var world := WorldGeometry.new(); world.configure(Fixture.fixture(true),"port_fixture")
	world.insert_obstacle("middle",AABB(Vector3(98,-1,46),Vector3(4,60,8)),world.geometry_revision)
	var a := Ports.at(world,Vector3(25,0,25)); var b := Ports.at(world,Vector3(175,0,75))
	compare("one_way_forward",world,a,b,PROFILE); compare("one_way_reverse",world,b,a,PROFILE)
	world.configure(Fixture.fixture(),"port_fixture"); a = Ports.at(world,Vector3(25,0,25)); b = Ports.at(world,Vector3(175,0,75))
	var candidate := WorldSolidSegment.new(); candidate.configure(Ports.at(world,Vector3(100,0,50)),Vector3.RIGHT,12,3,40,PROFILE)
	compare("speculative_segment",world,a,b,PROFILE,candidate)
	var full := world._navigation_graph(a,b,PROFILE,candidate)
	var graph := {"ok":true,"nodes":{},"edges":{},"by_surface":{}}; var context := world._navigation_index(PROFILE)
	var ids: Array = world._support_index.cells.keys(); ids.sort(); ids.reverse()
	var stable := true; var prepared := {}
	for id: String in ids:
		var made := world._navigation_surface(graph,context,id,a,b,PROFILE,candidate)
		stable = stable and made.ok
		for known: String in prepared:
			stable = stable and prepared[known] == {"ids":graph.by_surface[known],"nodes":graph.by_surface[known].map(func(state: String) -> Dictionary: return graph.nodes[state]),"edges":graph.by_surface[known].map(func(state: String) -> Array: return graph.edges[state])}
		prepared[id] = {"ids":graph.by_surface[id].duplicate(),"nodes":graph.by_surface[id].map(func(state: String) -> Dictionary: return graph.nodes[state].duplicate(true)),"edges":graph.by_surface[id].map(func(state: String) -> Array: return graph.edges[state].duplicate(true))}
	check("every_materialized_surface_matches_eager_content_and_order",graph.nodes == full.nodes and graph.edges == full.edges and graph.by_surface == full.by_surface)
	check("completed_surfaces_never_gain_later_candidates_or_edges",stable)
	var manifest := Fixture.fixture()
	for index: int in 16:
		var x := 400+index*150
		manifest._data.stages[0].surfaces.append({"surface_id":"detached_"+str(index),"vertices":[Vector3(x,0,0),Vector3(x+100,0,0),Vector3(x+100,0,100),Vector3(x,0,100)],"headroom":100.0})
	world.configure(manifest,"port_fixture"); a = Ports.at(world,Vector3(25,0,25)); b = Ports.at(world,Vector3(425,0,25))
	var disconnected := compare("disconnected_negative",world,a,b,PROFILE)
	check("unreachable_regions_are_not_constructed",not disconnected.current.ok and disconnected.new_trace.surfaces < disconnected.old_trace.surfaces)
	check("all_real_positive_routes_walk_with_canonical_body",moved_all)
	for delta: float in [WorldGeometry.EPS*0.5,WorldGeometry.EPS,WorldGeometry.EPS*2.0]:
		var heap := heap_world(false,delta); var result := compare("epsilon_%s"%delta,heap,heap_point("@from"),heap_point("@to"),{"radius":0.25,"height":1.0,"connector_kinds":["walk"]},null,false)
		var expected := Vector3(10,0,1) if delta <= WorldGeometry.EPS else Vector3(10,0,2)
		check("epsilon_%s_preserves_first_discovery_rule"%delta,result.current.ok and result.current.data.points[1].position == expected)
	var zero := heap_world(true); var zero_result := compare("zero_cost_late_discovery",zero,heap_point("@from"),heap_point("@to"),{"radius":0.25,"height":1.0,"connector_kinds":["walk"]},null,false)
	check("zero_cost_preserves_dynamic_heap_discovery",zero_result.current.ok and zero_result.current.data.points[1].position == Vector3(10,0,4))
	finish()
static func heap_point(id: String) -> ExpeditionWorldPoint:
	var coordinates := {"@from":Vector3(1,0,1),"@to":Vector3(20,0,1),"a":Vector3(10,0,1),"b":Vector3(10,0,2),"z":Vector3(10,0,3),"m":Vector3(10,0,4)}
	return ExpeditionWorldPoint.create("heap","floor",coordinates[id])
static func heap_edge(id: String, cost: float) -> Dictionary: return {"to":id,"via":[],"connection_id":"","cost":cost}
static func heap_world(zero: bool, delta: float = 0.0) -> HeapWorld:
	var manifest := ExpeditionManifest.new(); manifest._data = {"input":{"parts":[]},"stages":[{"stage_id":"heap","surfaces":[{"surface_id":"floor","vertices":[Vector3.ZERO,Vector3(100,0,0),Vector3(100,0,100),Vector3(0,0,100)],"headroom":100.0}],"connectors":[],"connections":[],"sockets":[],"volumes":[],"part_instances":[]}]}
	var world := HeapWorld.new(); world.configure(manifest,"heap")
	var nodes := {}; var edges := {}; var ids: Array = ["@from","@to","a","z","m"] if zero else ["@from","@to","a","b"]
	for id: String in ids: nodes[id] = heap_point(id).to_data(); edges[id] = []
	if zero:
		edges["@from"] = [heap_edge("z",0),heap_edge("m",0)]; edges.z = [heap_edge("a",0)]; edges.m = [heap_edge("@to",1)]; edges.a = [heap_edge("@to",1)]
	else:
		edges["@from"] = [heap_edge("a",1),heap_edge("b",1.25)]; edges.a = [heap_edge("@to",2)]; edges.b = [heap_edge("@to",1.75-delta)]
	ids.sort(); world.injected = {"ok":true,"nodes":nodes,"edges":edges,"by_surface":{"floor":ids}}; return world
func finish() -> void:
	var ok := checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("F9_LAZY_METRICS "+JSON.stringify(measurements,"",true,true))
	print("F9_LAZY_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
