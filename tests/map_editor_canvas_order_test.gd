extends SceneTree
const Ordering = preload("res://scripts/world/world_canvas_order.gd")
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ORDER_CHECK "+id+" "+str(ok))
static func mesh(id: String, vertices: Array) -> Dictionary:
	return {"id":id,"kind":"mesh","bounds":Ordering._bounds(vertices),"screen":Ordering._screen(vertices),"anchor":Ordering._bounds(vertices).get_center(),"caps":[vertices]}
static func sprite(id: String, anchor: Vector3) -> Dictionary:
	return {"id":id,"kind":"sprite","anchor":anchor,"bounds":AABB(anchor-Vector3(5,0,5),Vector3(10,40,10)),"screen":Rect2(ProjectionMath.project(anchor)-Vector2(30,40),Vector2(60,50))}
static func box(id: String, bounds: AABB) -> Dictionary:
	var vertices: Array = []
	for i: int in 8: vertices.append(bounds.get_endpoint(i))
	return {"id":id,"kind":"mesh","bounds":bounds,"screen":Ordering._screen(vertices),"anchor":bounds.get_center(),"caps":[]}
func run() -> void:
	var ramp := mesh("ramp",[Vector3(0,0,0),Vector3(100,20,0),Vector3(100,20,100),Vector3(0,0,100)])
	var actor := sprite("actor",Vector3(25,5,50)); var source: Array = [actor,ramp]; var original := source.duplicate(true)
	var ordered := Ordering.solve(source)
	check("actor_on_low_ramp_draws_after_own_ground",ordered.ok and ordered.order == ["ramp","actor"])
	check("ordering_does_not_mutate_geometry",source == original)
	var behind := box("back_wall",AABB(Vector3(0,-4,-2),Vector3(100,24,2)))
	actor = sprite("actor",Vector3(50,0,50)); ordered = Ordering.solve([actor,behind])
	check("wall_behind_sprite_is_not_overlay",ordered.ok and ordered.order == ["back_wall","actor"])
	var front := box("front_wall",AABB(Vector3(0,-4,100),Vector3(100,24,2)))
	ordered = Ordering.solve([front,actor])
	check("foreground_wall_stays_in_front",ordered.ok and ordered.order == ["actor","front_wall"])
	var bridge := mesh("bridge",[Vector3(200,160,200),Vector3(400,160,200),Vector3(400,160,400),Vector3(200,160,400)])
	var below := sprite("below",Vector3(100,0,100)); ordered = Ordering.solve([bridge,below])
	check("projected_bridge_occludes_lower_actor",ordered.ok and ordered.order == ["below","bridge"])
	var above := sprite("above",Vector3(300,160,300)); ordered = Ordering.solve([above,bridge])
	check("actor_on_bridge_draws_after_its_cap",ordered.ok and ordered.order == ["bridge","above"])
	var mixed: Array = [bridge,below,above]
	ordered = Ordering.solve(mixed); mixed.reverse()
	check("array_order_is_not_presentation_identity",ordered.ok and Ordering.solve(mixed).order == ordered.order)
	var cache := {}; ordered = Ordering.solve(mixed,cache)
	check("cold_order_tracks_all_pairs",ordered.ok and ordered.updated_pairs == 3)
	var hot := Ordering.solve(mixed,cache)
	check("stationary_order_reuses_verified_records",hot.ok and hot.unchanged and hot.updated_pairs == 0 and hot.order == ordered.order)
	var moved: Array = [bridge,sprite("below",Vector3(110,0,100)),above]
	var updated := Ordering.solve(moved,cache)
	check("movement_updates_only_affected_pairs",updated.ok and updated.updated_pairs == 2)
	check("incremental_order_matches_cold_rebuild",updated.ok and updated.order == Ordering.solve(moved).order)
	moved[1].anchor = Vector3(120,0,100); moved[1].bounds.position.x += 10; moved[1].screen.position.x += 8.5
	var mutated := Ordering.solve(moved,cache)
	check("inplace_source_change_cannot_mutate_cache_snapshot",mutated.ok and mutated.updated_pairs == 2 and mutated.order == Ordering.solve(moved).order)
	var prior := cache.duplicate(true)
	var invalid := ramp.duplicate(true); invalid.caps = [["bad","bad","bad"]]
	check("malformed_cap_returns_diagnostic",Ordering.solve([invalid],cache).get("code") == "presentation_invalid" and cache == prior)
	check("duplicate_id_rejected",Ordering.solve([ramp,ramp]).get("code") == "presentation_invalid")
	invalid = actor.duplicate(true); invalid.anchor = Vector3(NAN,0,0)
	check("nan_anchor_rejected",Ordering.solve([invalid]).get("code") == "presentation_invalid")
	var a := box("a",AABB(Vector3(0,4,0),Vector3(2,2,8)))
	var b := box("b",AABB(Vector3(4,0,0),Vector3(2,8,2)))
	var c := box("c",AABB(Vector3(0,0,4),Vector3(8,2,2)))
	# These three beams form the classic cyclic isometric overlap. It cannot be
	# made consistent by sorting whole drawables; refuse instead of hiding one.
	for item: Dictionary in [a,b,c]: item.screen = Rect2(Vector2.ZERO,Vector2(100,100))
	check("cycle_is_explicit_without_partial_cache",Ordering.solve([a,b,c],cache).get("code") == "presentation_order_ambiguous" and cache == prior)
	var excess: Array = []; excess.resize(8193); excess.fill(ramp)
	check("item_budget_rejects_whole_operation",Ordering.solve(excess,cache).get("code") == "presentation_limit" and cache == prior)
	var root := Node2D.new(); var lower_node := Node2D.new(); var upper_node := Node2D.new(); root.add_child(lower_node); root.add_child(upper_node)
	Ordering.tag_box(lower_node,AABB(Vector3.ZERO,Vector3(100,4,100))); Ordering.tag_box(upper_node,AABB(Vector3(0,160,0),Vector3(100,4,100)))
	Ordering.apply(root); var expected_z := upper_node.z_index
	lower_node.free(); upper_node.free(); lower_node = Node2D.new(); upper_node = Node2D.new(); root.add_child(lower_node); root.add_child(upper_node)
	Ordering.tag_box(lower_node,AABB(Vector3.ZERO,Vector3(100,4,100))); Ordering.tag_box(upper_node,AABB(Vector3(0,160,0),Vector3(100,4,100))); upper_node.z_index = -100
	var replaced := Ordering.apply(root)
	check("same_geometry_new_nodes_receive_cached_order",replaced.ok and upper_node.z_index == expected_z and upper_node.z_index > lower_node.z_index)
	root.free()
	broadphase_checks()
	priority_cache_checks()
	benchmark()
	benchmark_cases()
	var ok := checks.all(func(entry: Dictionary) -> bool: return entry.ok)
	print("F9_ORDER_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
func benchmark() -> void:
	var records: Array = []
	for z: int in 16:
		for x: int in 32:
			var a := Vector3(x*40,0,z*40)
			records.append(mesh("cell_%d_%d"%[x,z],[a,a+Vector3(40,0,0),a+Vector3(40,0,40),a+Vector3(0,0,40)]))
	for i: int in 64: records.append(sprite("actor_%d"%i,Vector3((i%16)*80+20,0,(i/16)*160+20)))
	var cache := {}; var tick := Time.get_ticks_usec(); var cold := Ordering.solve(records,cache); var cold_usec := Time.get_ticks_usec()-tick
	var hot: Array = []
	for i: int in 7:
		tick = Time.get_ticks_usec(); Ordering.solve(records,cache); hot.append(Time.get_ticks_usec()-tick)
	var moved: Array = records.duplicate(true); moved[-1].anchor.x += 4; moved[-1].bounds.position.x += 4; moved[-1].screen.position.x += 3.4
	tick = Time.get_ticks_usec(); var incremental := Ordering.solve(moved,cache); var update_usec := Time.get_ticks_usec()-tick
	var metrics := {"items":records.size(),"ground_items":512,"actor_items":64,"cold_ok":cold.ok,"cold_usec":cold_usec,"cold_pairs":cold.get("updated_pairs",0),"warm_samples_usec":hot,"one_actor_update_ok":incremental.ok,"one_actor_update_usec":update_usec,"one_actor_updated_pairs":incremental.get("updated_pairs",0),"cpu":OS.get_processor_name(),"scope":"CPU order only; no rendering/FPS claim"}
	print("F9_ORDER_METRICS "+JSON.stringify(metrics))
	var directory := OS.get_environment("F9_EVIDENCE")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("canvas_order_metrics.json"),FileAccess.WRITE); file.store_string(JSON.stringify(metrics,"\t",true,true)); file.close()

# Exhaustive broadphase oracle: every unordered pair, then an independent stable
# zero-degree scan. It deliberately has no buckets or incremental state.
static func exhaustive(records: Array) -> Dictionary:
	var by_id := {}; var ids: Array[String] = []; var incoming := {}; var pairs := {}
	for record: Dictionary in records: by_id[record.id] = record; ids.append(record.id); incoming[record.id] = {}
	ids.sort()
	for i: int in ids.size():
		for j: int in range(i+1,ids.size()):
			var a: String = ids[i]; var b: String = ids[j]; var relation := Ordering._before(by_id[a],by_id[b])
			if relation == 0: continue
			var edge: Array = [a,b] if relation < 0 else [b,a]
			pairs[[a,b]] = edge; incoming[edge[1]][edge[0]] = true
	var output: Array[String] = []; var remaining := by_id.duplicate()
	while not remaining.is_empty():
		var choice := ""
		for id: String in ids:
			if remaining.has(id) and incoming[id].is_empty() and (choice.is_empty() or Ordering._less(id,choice,by_id)): choice = id
		if choice.is_empty(): return {"ok":false,"code":"presentation_order_ambiguous"}
		output.append(choice); remaining.erase(choice)
		for id: String in remaining: incoming[id].erase(choice)
	return {"ok":true,"order":output,"pairs":pairs}

func equivalent(records: Array, cache: Dictionary) -> bool:
	var expected := exhaustive(records); var actual := Ordering.solve(records,cache)
	return actual.ok == expected.ok and (actual.get("code") == expected.get("code") if not actual.ok else actual.order == expected.order and cache.pairs == expected.pairs)

func broadphase_checks() -> void:
	var keys := Ordering._bucket_keys(Rect2(Vector2(-128,-128),Vector2(256,256)))
	check("closed_negative_and_positive_bucket_boundaries",keys.size() == 9 and Vector2i(-1,-1) in keys and Vector2i(1,1) in keys)
	check("large_and_distant_rectangles_use_bounded_overflow",Ordering._bucket_keys(Rect2(Vector2.ZERO,Vector2(128*300,128))).is_empty() and Ordering._bucket_keys(Rect2(Vector2(1e20,1e20),Vector2(1,1))).is_empty())
	var records: Array = []; var rng := RandomNumberGenerator.new(); rng.seed = 971302
	for i: int in 96:
		var item := sprite("sample_%03d"%i,Vector3(i*4,0,i*2))
		item.screen = Rect2(Vector2(rng.randf_range(-500,500),rng.randf_range(-400,400)),Vector2(rng.randf_range(0,200),rng.randf_range(0,160))); records.append(item)
	var giant := sprite("overflow",Vector3(20,0,20)); giant.screen = Rect2(Vector2(-5000,-5000),Vector2(10000,10000)); records.append(giant)
	var cache := {}
	check("seeded_projected_pairs_equal_exhaustive_oracle",equivalent(records,cache))
	var before := cache.duplicate(true); records.reverse()
	var hot := Ordering.solve(records,cache)
	check("reordered_input_reuses_spatial_index",hot.ok and hot.unchanged and hot.updated_pairs == 0 and cache == before)
	for i: int in range(0,records.size(),7): records[i].screen.position += Vector2(513,-277); records[i].anchor.x += 1; records[i].bounds.position.x += 1
	check("many_moving_items_equal_exhaustive_oracle",equivalent(records,cache))
	var a := sprite("a",Vector3(0,0,0)); var b := sprite("b",Vector3(50,0,50))
	a.screen = Rect2(Vector2.ZERO,Vector2(128,128)); b.screen = Rect2(Vector2(128,0),Vector2(128,128))
	var pair: Array = [a,b]; cache = {}
	check("touching_rectangles_keep_closed_constraint",equivalent(pair,cache) and cache.pairs.size() == 1)
	b.screen.position += Vector2(4096,4096)
	check("leaving_neighbor_removes_stale_constraint",equivalent(pair,cache) and cache.pairs.is_empty())
	b.screen.position = Vector2.ZERO
	check("entering_neighbor_adds_new_constraint",equivalent(pair,cache) and cache.pairs.size() == 1)
	pair.pop_back(); pair.append(sprite("replacement",Vector3(-10,0,-10)))
	check("removed_and_added_ids_rebuild_spatial_index",equivalent(pair,cache))
	var snapshot := cache.duplicate(true); var bad := a.duplicate(true); bad.screen.size.x = -1
	check("invalid_update_keeps_all_spatial_cache_atomic",not Ordering.solve([bad],cache).ok and cache == snapshot)
	var sparse: Array = []
	for i: int in 8192: sparse.append(sprite("sparse_%05d"%i,Vector3(i*1000,0,0)))
	var tick := Time.get_ticks_usec(); cache = {}; var cold := Ordering.solve(sparse,cache); var elapsed := Time.get_ticks_usec()-tick
	check("8192_separated_items_avoid_exhaustive_pair_budget",cold.ok and cold.order.size() == 8192 and cold.updated_pairs < 8192)
	print("F9_ORDER_SPARSE_METRICS "+JSON.stringify({"items":8192,"pairs":cold.get("updated_pairs",-1),"cold_usec":elapsed,"ok":cold.ok,"scope":"CPU only"}))

func priority_cache_checks() -> void:
	var ramp := mesh("ramp",[Vector3(0,0,0),Vector3(100,20,0),Vector3(100,20,100),Vector3(0,0,100)])
	var cache := {}; Ordering.solve([ramp,sprite("actor",Vector3(25,5,50))],cache)
	var source: Array = [ramp,sprite("actor",Vector3(26,5.2,50))]; var moved := Ordering.solve(source,cache)
	check("unchanged_constraints_and_priority_reuse_order",moved.ok and moved.reused_order and not moved.order_changed and equivalent(source,cache))
	var a := sprite("a",Vector3.ZERO); var b := sprite("b",Vector3(10,0,10))
	a.screen = Rect2(Vector2(-1000,-1000),Vector2(20,20)); b.screen = Rect2(Vector2(1000,1000),Vector2(20,20)); cache = {}; Ordering.solve([a,b],cache)
	a.anchor = Vector3(30,0,30); a.bounds.position = a.anchor-Vector3(5,0,5); moved = Ordering.solve([a,b],cache)
	check("priority_crossing_rebuilds_exact_order",moved.ok and not moved.reused_order and moved.order_changed and moved.order == ["b","a"] and equivalent([a,b],cache))
	a = sprite("a",Vector3.ZERO); b = sprite("b",Vector3(50,0,50)); a.screen = Rect2(Vector2.ZERO,Vector2(128,128)); b.screen = a.screen; cache = {}; Ordering.solve([a,b],cache)
	b.screen.position = Vector2(4096,4096); moved = Ordering.solve([a,b],cache)
	check("changed_constraints_same_result_skip_node_reordering",moved.ok and not moved.reused_order and not moved.order_changed and cache.pairs.is_empty() and equivalent([a,b],cache))
	var records: Array = []
	for i: int in 32: records.append(sprite("actor_%03d"%i,Vector3(i*40,0,i*20)))
	cache = {}; Ordering.solve(records,cache)
	var reversed: Array = records.duplicate(true); reversed.reverse()
	for i: int in records.size(): records[i].anchor = reversed[i].anchor; records[i].bounds = reversed[i].bounds; records[i].screen = reversed[i].screen
	check("many_priority_inversions_equal_exhaustive_oracle",equivalent(records,cache))

func benchmark_cases() -> void:
	var measurements: Array = []
	for scenario: Array in [["small",8,8,8],["representative",32,16,64],["stress",64,32,128]]:
		var records: Array = []; var width: int = scenario[1]; var height: int = scenario[2]; var actors: int = scenario[3]
		for z: int in height:
			for x: int in width:
				var a := Vector3(x*40,0,z*40)
				records.append(mesh("cell_%03d_%03d"%[x,z],[a,a+Vector3(40,0,0),a+Vector3(40,0,40),a+Vector3(0,0,40)]))
		for i: int in actors: records.append(sprite("actor_%03d"%i,Vector3((i%width)*40+20,0,(i/width)*40+20)))
		var cache := {}; var cold: Array = []; var warm: Array = []; var motion: Array = []; var pairs: Array = []; var one_actor: Array = []; var one_pairs: Array = []; var passed := true; var tick: int
		for i: int in 3:
			cache = {}; tick = Time.get_ticks_usec(); var result := Ordering.solve(records,cache); cold.append(Time.get_ticks_usec()-tick); passed = passed and result.ok
		for i: int in 7:
			tick = Time.get_ticks_usec(); var result := Ordering.solve(records,cache); warm.append(Time.get_ticks_usec()-tick); passed = passed and result.ok and result.unchanged
		var single := records.duplicate(true)
		for frame: int in 7:
			single[-1].anchor.x += 1; single[-1].bounds.position.x += 1; single[-1].screen.position.x += 0.85
			tick = Time.get_ticks_usec(); var result := Ordering.solve(single,cache); one_actor.append(Time.get_ticks_usec()-tick); one_pairs.append(result.get("updated_pairs",-1)); passed = passed and result.ok
		var moving := records.duplicate(true)
		for frame: int in 7:
			for i: int in range(moving.size()-actors,moving.size()):
				moving[i].anchor.x += 1; moving[i].bounds.position.x += 1; moving[i].screen.position.x += 0.85
			tick = Time.get_ticks_usec(); var result := Ordering.solve(moving,cache); motion.append(Time.get_ticks_usec()-tick); pairs.append(result.get("updated_pairs",-1)); passed = passed and result.ok
		var rebuilt := Ordering.solve(moving)
		passed = passed and rebuilt.ok and rebuilt.order == cache.order
		check("benchmark_"+str(scenario[0])+"_cold_warm_moving_orders_valid",passed)
		measurements.append({"scenario":scenario[0],"items":records.size(),"terrain_items":width*height,"actor_items":actors,"cold_samples_usec":cold,"warm_samples_usec":warm,"one_actor_move_samples_usec":one_actor,"one_actor_move_pairs":one_pairs,"all_actors_move_samples_usec":motion,"all_actors_move_pairs":pairs,"ok":passed})
	var metrics := {"cpu":OS.get_processor_name(),"engine":Engine.get_version_info().string,"scope":"CPU order only; inputs prebuilt, no render/FPS/whole-UI latency claim","scenarios":measurements}
	print("F9_ORDER_SCALING_METRICS "+JSON.stringify(metrics))
	var directory := OS.get_environment("F9_EVIDENCE")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("canvas_order_scaling_metrics.json"),FileAccess.WRITE); file.store_string(JSON.stringify(metrics,"\t",true,true)); file.close()
