extends SceneTree
## Checkpoint36: background path requests give the synchronous answer, never block
## the main loop, and are discarded when stale or cancelled.
const Fixture = preload("res://tests/map_editor_navigation_batch_test.gd")
const Ports = preload("res://tests/map_editor_port_fragments_test.gd")
const Organic = preload("res://tests/map_editor_organic_test.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const PROFILE := {"radius":8.0,"height":32.0,"connector_kinds":["walk"]}
const ORGANIC_PROFILE := {"radius":20.0,"height":32.0,"connector_kinds":["walk"]}
var checks: Array[Dictionary] = []
var metrics: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ASYNC_CHECK "+id+" "+str(ok))
static func same(a: Dictionary, b: Dictionary) -> bool:
	return a.ok == b.ok and String(a.get("error_code","")) == String(b.get("error_code","")) and a.get("data",{}) == b.get("data",{})
static func port_world() -> WorldGeometry:
	var world := WorldGeometry.new(); world.configure(Fixture.fixture(),"port_fixture")
	world.insert_obstacle("middle",AABB(Vector3(98,-1,46),Vector3(4,60,8)),world.geometry_revision)
	return world
# Pump like main._process does, one frame at a time; record the longest pump.
func settle(world: WorldGeometry, limit_ms: int = 60000) -> Dictionary:
	var started := Time.get_ticks_msec(); var worst := 0; var frames := 0
	while world.navigation_pending() > 0 and Time.get_ticks_msec()-started < limit_ms:
		await process_frame
		var t := Time.get_ticks_usec(); world.navigation_pump(); worst = maxi(worst,Time.get_ticks_usec()-t); frames += 1
	return {"settled":world.navigation_pending() == 0,"worst_pump_usec":worst,"frames":frames,"ms":Time.get_ticks_msec()-started}
class Owner extends RefCounted:
	var delivered: Array = []
	func _navigation_delivered(request: WorldGeometry.PathRequest) -> void: delivered.append(request)
func run() -> void:
	var sync := port_world(); var world := port_world(); world.navigation_async = true
	var a := Ports.at(world,Vector3(25,0,25)); var b := Ports.at(world,Vector3(175,0,75))
	# 1. Off by default: answered at once with path().
	var plain := sync.request_path(a,b,PROFILE,sync.geometry_revision)
	check("sync_default_answers_immediately_with_path",not sync.navigation_async and plain.done() and same(plain.result,port_world().path(a,b,PROFILE,sync.geometry_revision)))
	# 2. Background answer equals the synchronous one; the call itself is short.
	var owner := Owner.new()
	var t := Time.get_ticks_usec(); var request := world.request_path(a,b,PROFILE,world.geometry_revision,owner,0); var call_usec := Time.get_ticks_usec()-t
	check("detour_is_searched_in_background",not request.done() and world.navigation_pending() == 1)
	var settled: Dictionary = await settle(world)
	check("background_answer_equals_path",settled.settled and request.done() and same(request.result,sync.path(a,b,PROFILE,sync.geometry_revision)))
	check("owner_receives_the_delivery_once",owner.delivered.size() == 1 and owner.delivered[0] == request)
	metrics["port"] = {"call_usec":call_usec,"compute_usec":request.compute_usec,"settle":settled}
	# 3. A straight route is answered on the spot.
	var near: ExpeditionWorldPoint
	var direct := world.request_path(a,Ports.at(world,Vector3(30,0,40)),PROFILE,world.geometry_revision); near = Ports.at(world,Vector3(30,0,40))
	check("straight_route_is_immediate",direct.done() and same(direct.result,sync.path(a,near,PROFILE,sync.geometry_revision)))
	# 4. Invalid input is answered on the spot like path().
	var bad := world.request_path(a,b,{"radius":-1.0},world.geometry_revision)
	check("invalid_input_is_immediate",bad.done() and same(bad.result,sync.path(a,b,{"radius":-1.0},sync.geometry_revision)))
	# 5. Priority and cancellation: while one task runs, the player's request
	# jumps the queue and a cancelled request never runs.
	var order: Array = []
	var first := world.request_path(b,a,PROFILE,world.geometry_revision)
	# Sources on the line from b through the middle obstacle: all need a detour.
	var low := world.request_path(Ports.at(world,Vector3(40,0,30)),b,PROFILE,world.geometry_revision)
	var dropped := world.request_path(Ports.at(world,Vector3(55,0,35)),b,PROFILE,world.geometry_revision)
	var high := world.request_path(Ports.at(world,Vector3(62.5,0,37.5)),b,PROFILE,world.geometry_revision,null,10)
	var queued := not first.done() and not low.done() and not dropped.done() and not high.done()
	dropped.cancel()
	while world.navigation_pending() > 0:
		await process_frame; world.navigation_pump()
		for item: WorldGeometry.PathRequest in [first,low,high]:
			if item.done() and not order.has(item): order.append(item)
	check("higher_priority_runs_before_queued_lower",queued and order.size() == 3 and order.find(high) < order.find(low))
	check("cancelled_request_is_never_answered",dropped.state == &"cancelled" and dropped.result.is_empty())
	# 6. A mutation on the main thread while the task runs: no shared state, and
	# the answer for the old revision is reported stale.
	var stale := world.request_path(a,b,PROFILE,world.geometry_revision)
	var running := world.navigation_pending() == 1 and stale.state == &"running"
	world.insert_obstacle("late",AABB(Vector3(60,-1,80),Vector3(4,60,4)),world.geometry_revision)
	sync.insert_obstacle("late",AABB(Vector3(60,-1,80),Vector3(4,60,4)),sync.geometry_revision)
	await settle(world)
	check("mutation_during_task_reports_stale",running and stale.done() and String(stale.result.get("error_code","")) == "stale_geometry")
	var fresh := world.request_path(a,b,PROFILE,world.geometry_revision); await settle(world)
	check("next_request_sees_the_mutation",fresh.done() and same(fresh.result,sync.path(a,b,PROFILE,sync.geometry_revision)))
	# 7. Actor: plan_async keeps the old route meanwhile and joins the answer at
	# the point it walked to; the joined route walks to the destination.
	var motion := WorldActorMotion.new(); motion.configure(world,a,PROFILE,"async_actor")
	var first_leg := motion.plan(Ports.at(world,Vector3(60,0,25)),world.geometry_revision)
	var asked := motion.plan_async(b,world.geometry_revision)
	var kept: bool = first_leg.ok and asked.get("pending",false) and motion.plan_pending() and motion.has_route()
	motion.advance(10.0)
	var moved_to := motion.point().position
	await settle(world)
	var joined: bool = not motion.plan_pending() and motion.has_route() and Vector3(motion._route[0].position).distance_to(moved_to) <= WorldGeometry.EPS
	var budget := 4000
	while motion.has_route() and budget > 0:
		budget -= 1
		if not motion.advance(3.0).ok: break
	check("actor_keeps_route_then_joins_answer_where_it_stands",kept and joined and moved_to.distance_to(a.position) > 1.0)
	check("joined_route_walks_to_destination",not motion.has_route() and motion.point().position.distance_to(b.position) < 0.001)
	var c := Ports.at(world,Vector3(40,0,30))
	motion.plan_async(c,world.geometry_revision); var pending_before_cancel := motion.plan_pending(); motion.cancel()
	await settle(world)
	check("cancel_drops_the_pending_route",pending_before_cancel and not motion.plan_pending() and not motion.has_route())
	var finished: Array = []
	var callback := func(result: Dictionary) -> void: finished.append(result)
	var back := motion.plan_async(a,world.geometry_revision,0,callback); await settle(world)
	check("finished_callback_gets_the_adopted_route",back.get("pending",false) and finished.size() == 1 and finished[0].ok and motion.has_route())
	motion.release()
	# 8. A long search on real terrain does not block the main loop.
	var built := Maps.compile(Organic.map_source(Organic.gaussian(5)))
	if built.ok:
		var manifest := Maps.manifest(built.package)
		for index: int in 2: manifest._data.stages[0].volumes.append(AABB(Vector3(500,150,500),Vector3(200,200,200)))
		var organic := WorldGeometry.new(); organic.configure(manifest,"map_preview"); organic.navigation_async = true
		var reference := WorldGeometry.new(); reference.configure(manifest,"map_preview")
		var cells: Array = organic._stage.surfaces
		var oa := ExpeditionWorldPoint.create("map_preview",cells[0].surface_id,Maps._center(cells[0])); var ob := ExpeditionWorldPoint.create("map_preview",cells[-1].surface_id,Maps._center(cells[-1]))
		t = Time.get_ticks_usec(); var long := organic.request_path(oa,ob,ORGANIC_PROFILE,organic.geometry_revision); var long_call := Time.get_ticks_usec()-t
		var long_settle: Dictionary = await settle(organic)
		metrics["organic"] = {"call_usec":long_call,"compute_usec":long.compute_usec,"settle":long_settle}
		check("long_search_answer_equals_path",long.done() and same(long.result,reference.path(oa,ob,ORGANIC_PROFILE,reference.geometry_revision)))
		check("main_loop_never_waits_for_the_search",long.compute_usec > 100000 and long_call < 20000 and long_settle.worst_pump_usec < 20000 and long_settle.frames > 1)
	else:
		check("long_search_answer_equals_path",false); check("main_loop_never_waits_for_the_search",false)
	# 9. Snapshot schema covers the new transient fields.
	var registry := SnapshotRegistry.new(); var probe_motion := WorldActorMotion.new(); probe_motion.configure(sync,a,PROFILE,"schema_actor")
	registry._fields(sync); registry._fields(probe_motion)
	check("snapshot_schema_covers_transient_fields",registry._error.is_empty())
	probe_motion.release()
	# 10. Freeing a geometry with a task in flight waits for it.
	var doomed := port_world(); doomed.navigation_async = true
	var orphan := doomed.request_path(a,b,PROFILE,doomed.geometry_revision)
	var was_running := orphan.state == &"running"
	doomed = null
	check("freeing_geometry_with_task_in_flight_is_safe",was_running)
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_ASYNC_METRICS "+JSON.stringify(metrics))
	print("F9_ASYNC_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
