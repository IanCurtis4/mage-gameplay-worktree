extends SceneTree
const Fixture = preload("res://tests/map_editor_port_fragments_test.gd")
const Ports = preload("res://scripts/core/expedition/generation/connector_partition.gd")
const PROFILE := {"radius":8.0,"height":32.0,"connector_kinds":["walk"]}
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_BATCH_CHECK "+id+" "+str(ok))
func run() -> void:
	var manifest := fixture(); var world := WorldGeometry.new(); world.configure(manifest,"port_fixture")
	var root := Fixture.at(world,Vector3(25,0,25)); var goal := Fixture.at(world,Vector3(175,0,75)); var lower := Fixture.at(world,Vector3(175,0,25))
	var direct := request(world,root,[goal,root,goal],PROFILE)
	check("direct_batch_complete",direct.ok and direct.data.complete and direct.data.all_reachable)
	if not direct.ok: print(direct); finish(); return
	check("duplicate_inputs_keep_result_indices",direct.data.targets.size() == 3 and direct.data.targets[0].node_id == direct.data.targets[2].node_id and direct.data.targets[2].input_index == 2)
	check("stationary_root_witness",world.connectivity_witness(direct,1,true,world.geometry_revision).data.points.size() == 1)
	check("direct_forward_witness_walks",walk(world,world.connectivity_witness(direct,0,true,world.geometry_revision),PROFILE))
	check("direct_reverse_witness_walks",walk(world,world.connectivity_witness(direct,0,false,world.geometry_revision),PROFILE))
	var original_witness := world.connectivity_witness(direct,0,true,world.geometry_revision)
	var forged := direct.duplicate(true); var goal_id: String = forged.data.targets[0].node_id
	forged.data.outward_previous[goal_id].edge.cost += 10000.0
	forged.data.outward_previous[goal_id].edge.connection_ids = ["invented_link"]
	var corrected := world.connectivity_witness(forged,0,true,world.geometry_revision)
	check("witness_recomputes_geometry_cost_and_links",corrected.ok and corrected.data == original_witness.data and corrected.data.cost_kind == "witness_only")
	forged.data.outward_previous[goal_id].edge.cost = -1.0
	check("negative_certificate_cost_is_rejected",not world.connectivity_witness(forged,0,true,world.geometry_revision).ok)
	forged = direct.duplicate(true); forged.data.targets[0].point.position.x += 1.0
	check("witness_is_bound_to_requested_terminal",not world.connectivity_witness(forged,0,true,world.geometry_revision).ok)
	var no_storage := request(world,root,[goal],PROFILE,Callable(),{"max_storage_bytes":1})
	check("snapshot_storage_budget_is_enforced",not no_storage.ok and no_storage.error_code == &"navigation_budget_exceeded" and no_storage.data.phase == "prepare")
	world.insert_obstacle("middle",AABB(Vector3(98,-1,46),Vector3(4,60,8)),world.geometry_revision)
	check("fixture_needs_a_real_detour",not world.ground_line_to(root,goal,PROFILE,world.geometry_revision).ok)
	var blocked := request(world,root,[goal,lower],PROFILE)
	check("batch_finds_fragmented_detour",blocked.ok and blocked.data.all_reachable)
	print("F9_BATCH_METRICS "+JSON.stringify({"direct":direct.data.metrics,"detour":blocked.data.metrics}))
	check("storage_accounts_for_graph_and_proof_growth",blocked.ok and blocked.data.metrics.storage_bytes > blocked.data.metrics.snapshot_storage_units and blocked.data.metrics.storage_bytes > direct.data.metrics.storage_bytes)
	var bounded := request(world,root,[goal,lower],PROFILE,Callable(),{"max_storage_bytes":int(direct.data.metrics.storage_bytes)})
	check("construction_storage_exhaustion_has_no_certificate",not bounded.ok and bounded.error_code == &"navigation_budget_exceeded" and bounded.data.phase != "prepare" and not bounded.data.has("complete"))
	check("individual_graphs_embed_in_batch_union",graphs_embed(world,root,[goal,lower]))
	check("individual_success_included_and_witness_walks",world.path(root,goal,PROFILE,world.geometry_revision).ok and blocked.ok and walk(world,world.connectivity_witness(blocked,0,true,world.geometry_revision),PROFILE) and walk(world,world.connectivity_witness(blocked,0,false,world.geometry_revision),PROFILE))
	var reordered := request(world,root,[lower,goal],PROFILE)
	check("target_order_does_not_change_witness",reordered.ok and world.connectivity_witness(reordered,1,true,world.geometry_revision).data == world.connectivity_witness(blocked,0,true,world.geometry_revision).data)
	var limited := request(world,root,[goal,lower],PROFILE,Callable(),{"max_expansions":0})
	check("budget_failure_has_no_partial_certificate",not limited.ok and limited.error_code == &"navigation_budget_exceeded" and not limited.data.has("all_reachable"))
	var calls := [0]
	var cancel := func() -> bool: calls[0] += 1; return calls[0] >= 3
	var cancelled := request(world,root,[goal,lower],PROFILE,cancel)
	check("cancellation_has_no_partial_certificate",not cancelled.ok and cancelled.error_code == &"cancelled" and not cancelled.data.has("complete"))
	var mutate := func() -> bool:
		world.insert_obstacle("callback",AABB(Vector3(60,0,70),Vector3(2,50,2)),world.geometry_revision); return false
	var stale := request(world,root,[goal],PROFILE,mutate)
	check("callback_mutation_invalidates_batch",not stale.ok and stale.error_code == &"stale_geometry" and not stale.data.has("all_reachable"))
	world.configure(manifest,"port_fixture")
	check("certificate_rejected_after_reconfigure",not world.connectivity_witness(direct,0,true,world.geometry_revision).ok)
	var empty := request(world,root,[],PROFILE)
	check("empty_targets_validate_only_root",empty.ok and empty.data.all_reachable and empty.data.targets.is_empty())
	var bad_profile := PROFILE.duplicate(true); bad_profile.radius = NAN
	check("invalid_profile_rejected",request(world,root,[goal],bad_profile).error_code == &"invalid_profile")
	check("invalid_support_rejected",request(world,root,[ExpeditionWorldPoint.create("port_fixture","missing",Vector3.ZERO)],PROFILE).error_code == &"invalid_support")
	var old_revision := world.geometry_revision
	world.insert_obstacle("revision",AABB(Vector3(60,0,70),Vector3(2,50,2)),world.geometry_revision)
	var typed: Array[ExpeditionWorldPoint] = [goal]
	check("stale_request_revision_rejected",world.connectivity_batch(root,typed,PROFILE,old_revision).error_code == &"stale_geometry")
	world.configure(manifest,"port_fixture")
	var before := request(world,root,[goal],PROFILE)
	world._temporary["speculative"] = AABB(Vector3(98,-1,9),Vector3(4,60,82))
	var speculative := request(world,root,[goal],PROFILE)
	check("same_revision_effective_obstacle_is_seen",speculative.ok and not speculative.data.all_reachable and not world.connectivity_witness(before,0,true,world.geometry_revision).ok)
	world._temporary.erase("speculative")
	check("rollback_does_not_poison_next_batch",request(world,root,[goal],PROFILE).data.all_reachable)
	world.insert_obstacle("closed",AABB(Vector3(98,-1,9),Vector3(4,60,82)),world.geometry_revision)
	var closed := request(world,root,[goal],PROFILE)
	check("closed_opening_is_complete_negative",closed.ok and closed.data.complete and not closed.data.all_reachable)
	world.configure(fixture(true),"port_fixture")
	var one_way := request(world,root,[goal],PROFILE)
	check("transposed_search_preserves_one_way",one_way.ok and one_way.data.targets[0].outward_reachable and not one_way.data.targets[0].inward_reachable and not one_way.data.all_reachable)
	world.configure(manifest,"port_fixture")
	var large := PROFILE.duplicate(true); large.radius = 41.0
	var a := Fixture.at(world,Vector3(50,0,50)); var b := Fixture.at(world,Vector3(150,0,50))
	var wide := request(world,a,[b],large)
	check("larger_body_does_not_reuse_smaller_profile",wide.ok and not wide.data.all_reachable)
	check("profile_change_back_is_clean",request(world,a,[b],PROFILE).data.all_reachable)
	var segment := WorldSolidSegment.new(); segment.configure(root,Vector3(1,0,1),10,2,24,PROFILE)
	var captured := segment.geometry_record()
	for k: int in 20: segment = segment.snapshot()
	check("segment_snapshot_keeps_exact_geometry",segment.geometry_record() == captured)
	check("segment_roundtrip_has_same_contacts",segment.contact(Vector3(10,0,25),Vector3(40,0,25),PROFILE) == segment.snapshot().contact(Vector3(10,0,25),Vector3(40,0,25),PROFILE))
	world.insert_segment("diagonal",segment,world.geometry_revision)
	var segment_root := Fixture.at(world,Vector3(25,0,80)); var segment_goal := Fixture.at(world,Vector3(175,0,80))
	var with_segment := request(world,segment_root,[segment_goal],PROFILE)
	check("snapshot_preserves_segment_geometry",with_segment.ok and with_segment.data.all_reachable and walk(world,world.connectivity_witness(with_segment,0,true,world.geometry_revision),PROFILE))
	var stacked := ExpeditionManifest.new(); stacked._data = {"input":{"parts":[]},"stages":[{"stage_id":"stacked","surfaces":[],"connectors":[],"connections":[],"sockets":[],"volumes":[],"part_instances":[]}]}
	for id: String in ["a","b"]: stacked._data.stages[0].surfaces.append({"surface_id":id,"vertices":[Vector3(0,0,0),Vector3(100,0,0),Vector3(100,0,100),Vector3(0,0,100)],"headroom":100.0})
	world.configure(stacked,"stacked")
	var coincident := request(world,ExpeditionWorldPoint.create("stacked","a",Vector3(50,0,50)),[ExpeditionWorldPoint.create("stacked","b",Vector3(50,0,50))],PROFILE)
	check("coincident_disconnected_supports_are_not_merged",coincident.ok and not coincident.data.all_reachable)
	finish()

static func graphs_embed(world: WorldGeometry, root: ExpeditionWorldPoint, goals: Array) -> bool:
	var terminals := {"@root":root.to_data()}; var pairs: Array = []
	var close := ExpeditionWorldPoint.create(goals[0].stage_id,goals[0].surface_id,goals[0].position+Vector3(0,0,0.00005))
	var all: Array = goals.duplicate(); all.append(close)
	for k: int in all.size():
		var goal: ExpeditionWorldPoint = all[k]; terminals["terminal_"+str(k)] = goal.to_data()
		pairs.append({"from":root,"to":goal}); pairs.append({"from":goal,"to":root})
	var union := world._navigation_graph(root,root,PROFILE,null,terminals,pairs)
	if not union.ok: return false
	var union_points := {}; var union_edges := {}
	for value: Dictionary in union.nodes.values(): union_points[ExpeditionCanonical.encode(value)] = true
	for id: String in union.edges:
		for edge: Dictionary in union.edges[id]: union_edges[ExpeditionCanonical.encode([union.nodes[id],union.nodes[edge.to],edge.via,edge.connection_id,edge.cost])] = true
	for pair: Dictionary in pairs:
		var single := world._navigation_graph(pair.from,pair.to,PROFILE,null)
		if not single.ok: return false
		for value: Dictionary in single.nodes.values():
			if not union_points.has(ExpeditionCanonical.encode(value)): return false
		for id: String in single.edges:
			for edge: Dictionary in single.edges[id]:
				if not union_edges.has(ExpeditionCanonical.encode([single.nodes[id],single.nodes[edge.to],edge.via,edge.connection_id,edge.cost])): return false
	return true

static func fixture(directional: bool = false) -> ExpeditionManifest:
	var a := Fixture.part("a",false,12.5); var b := Fixture.part("b",true,20)
	if directional: Fixture.alter_group(a,"direction","out"); Fixture.alter_group(b,"direction","in")
	var split := Ports.partition_link(Ports.resolve_port(a,"a/opening"),Ports.resolve_port(b,"b/opening"),"bridge",PROFILE)
	return Fixture.realized(a,b,split)
static func request(world: WorldGeometry, root: ExpeditionWorldPoint, points: Array, profile: Dictionary, cancellation: Callable = Callable(), budget: Dictionary = {}) -> Dictionary:
	var typed: Array[ExpeditionWorldPoint] = []
	for point: ExpeditionWorldPoint in points: typed.append(point)
	return world.connectivity_batch(root,typed,profile,world.geometry_revision,cancellation,budget)
static func walk(world: WorldGeometry, witness: Dictionary, profile: Dictionary) -> bool:
	if not witness.ok or witness.data.points.is_empty(): return false
	var points: Array = witness.data.points; var first: Dictionary = points[0]; var last: Dictionary = points[-1]
	var motion := WorldActorMotion.new()
	if not motion.configure(world,ExpeditionWorldPoint.create(first.stage_id,first.surface_id,first.position),profile,"batch_actor").ok: return false
	motion._route = points.duplicate(true); motion._cursor = 1; motion._route_revision = world.geometry_revision
	var budget := 1000
	while motion.has_route() and budget > 0:
		budget -= 1
		if not motion.advance(3.0).ok: motion.release(); return false
	var ok: bool = budget > 0 and motion.point().surface_id == last.surface_id and motion.point().position.distance_to(last.position) < 0.001
	motion.release(); return ok
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_BATCH_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
