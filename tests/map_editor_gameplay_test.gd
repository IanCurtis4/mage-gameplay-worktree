extends SceneTree
## Shared renderer producer checks. This is not proof of the full gameplay app.
const MapView = preload("res://scripts/world/map_package_view.gd")
const SourceFixture = preload("res://tests/map_editor_viewport_test.gd")
const MapFixture = preload("res://tests/map_editor_borders_test.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_RUNTIME_VIEW_CHECK "+id+" "+str(ok))
static func node_ids(view: Node) -> Array:
	return view.get_children().map(func(node: Node) -> int: return node.get_instance_id())
static func only_drawables(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is Control or child is Window or not only_drawables(child): return false
	return true
func run() -> void:
	var source := SourceFixture.source(); var recipe := MapFixture.map_source(source,"ruin_envelope_v1")
	var built := Compiler.compile(recipe); check("actual_map_package_compiles",built.ok)
	if not built.ok: print(built); finish(); return
	var package: Dictionary = built.package; var fingerprint := Canonical.digest(package)
	var renderer := MapView.new(); root.add_child(renderer)
	var prepared := renderer.configure(package)
	check("shared_renderer_constructs_world_and_drawables",prepared.ok and renderer.geometry != null and renderer.get_child_count() > 0)
	check("renderer_does_not_mutate_passive_package",Canonical.digest(package) == fingerprint)
	var world := WorldGeometry.new(); world.configure(Compiler.manifest(package),"map_preview")
	var owner := Node2D.new(); root.add_child(owner)
	var actor := CombatActor.new(); actor.setup("Invariante de apresentação",Color.WHITE,StatCalculator.calculate({&"vit":10})); owner.add_child(actor); actor.set_process(false)
	var point := SourceFixture.at(world,Vector3(50,0,50)); var bound := actor.bind_world_geometry(world,point,package.profile,"renderer_actor"); actor.set_process(false)
	check("real_actor_binds_original_world",bound.ok)
	actor.health._hp_deficit = 7.25; var hp := actor.health.current_hp; var actor_point := actor.world_point().to_data(); var parent := actor.get_parent(); var index := actor.get_index()
	paused = true; var barrier := SnapshotTickBarrier.new(); barrier.acquire(actor)
	var before := SnapshotRegistry.new().capture(actor,barrier)
	prepared = renderer.configure(package,world)
	check("renderer_accepts_existing_world_with_matching_geometry",prepared.ok and renderer.geometry == world)
	check("renderer_keeps_actor_hierarchy_point_and_health",actor.get_parent() == parent and actor.get_index() == index and actor.world_point().to_data() == actor_point and actor.health.current_hp == hp)
	var after := SnapshotRegistry.new().capture(actor,barrier)
	if not before.ok: print(before)
	if not after.ok: print(after)
	check("renderer_stays_out_of_simulated_snapshot_graph",before.ok and after.ok and before.snapshot == after.snapshot)
	barrier.release(); paused = false
	var existing := node_ids(renderer)
	var wrong_manifest := Compiler.manifest(package); wrong_manifest._data.stages[0].volumes.append(AABB(Vector3(1000,0,1000),Vector3(10,20,10)))
	var wrong_world := WorldGeometry.new(); wrong_world.configure(wrong_manifest,"map_preview")
	var refused := renderer.configure(package,wrong_world)
	check("mismatched_world_rejected_without_losing_previous_view",not refused.ok and refused.code == "renderer_world_mismatch" and node_ids(renderer) == existing and renderer.geometry == world)
	var bad := package.duplicate(true); bad.format_version = 999; refused = renderer.configure(bad,world)
	check("malformed_package_rejected_without_partial_view",not refused.ok and node_ids(renderer) == existing and Canonical.digest(renderer.package) == fingerprint)
	var inserted := world.insert_obstacle("runtime_wall",AABB(Vector3(1000,0,1000),Vector3(10,20,10)),world.geometry_revision)
	prepared = renderer.configure(package,world)
	check("temporary_world_state_does_not_rewrite_base_skin",inserted.ok and prepared.ok and renderer.geometry.geometry_revision == 2 and Canonical.digest(package) == fingerprint)
	check("shared_view_creates_no_authoring_controls",only_drawables(renderer))
	renderer.clear()
	check("clear_releases_only_presentation",renderer.get_child_count() == 0 and renderer.package.is_empty() and renderer.geometry == null and actor.get_parent() == parent and actor.world_point().to_data() == actor_point and actor.health.current_hp == hp)
	actor.world_motion.release(); renderer.free(); owner.free(); finish()
func finish() -> void:
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_RUNTIME_VIEW_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
