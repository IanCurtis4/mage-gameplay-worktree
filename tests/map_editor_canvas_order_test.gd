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
	benchmark()
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
