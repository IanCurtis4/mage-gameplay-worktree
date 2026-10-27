extends SceneTree
const Shadow = preload("res://scripts/world/ground_shadow.gd")
const Patch = preload("res://scripts/core/expedition/spatial/world_support_patch.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const ProjectionView = preload("res://scripts/world/expedition_geometry_view.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_SHADOW_CHECK "+id+" "+str(ok))
static func cell(id: String, x0: float, x1: float, y0: float = 0.0, y1: float = 0.0) -> Dictionary:
	return {"surface_id":id,"headroom":100.0,"vertices":[Vector3(x0,y0,0),Vector3(x1,y1,0),Vector3(x1,y1,100),Vector3(x0,y0,100)]}
static func stage() -> Dictionary:
	return {"surfaces":[cell("left",0,50),cell("right",50,100)],"connectors":[{"connector_id":"a","surface_id":"left","position":Vector3(50,0,50),"outward":Vector3.RIGHT,"width":100.0,"headroom":100.0,"kind":"walk"},{"connector_id":"b","surface_id":"right","position":Vector3(50,0,50),"outward":Vector3.LEFT,"width":100.0,"headroom":100.0,"kind":"walk"}],"connections":[{"connection_id":"join","a_connector":"a","b_connector":"b","forward":true,"backward":true}]}
static func area(data: Dictionary) -> float:
	var vertices: Array = data.world_vertices; var ids: PackedInt32Array = data.arrays[Mesh.ARRAY_INDEX]; var total := 0.0
	for k: int in range(0,ids.size(),3):
		var a: Vector3 = vertices[ids[k]]; var b: Vector3 = vertices[ids[k+1]]; var c: Vector3 = vertices[ids[k+2]]
		total += absf((float(b.x)-float(a.x))*(float(c.z)-float(a.z))-(float(b.z)-float(a.z))*(float(c.x)-float(a.x)))*0.5
	return total
func run() -> void:
	var source := stage(); var snapshot := Canonical.digest(source); var index := Patch.index(source)
	var anchor := Vector3(50,0,50); var built := Shadow.mesh_data(anchor,Vector2(20,20),index,"left",ProjectionView.project)
	check("connected_receiver_mesh_builds",built.ok)
	if not built.ok: print(built); finish(); return
	check("seam_uses_both_actual_receivers",built.receivers == ["left","right"])
	check("seam_projected_footprint_area1600",absf(area(built)-1600.0) < 0.00001)
	var projection_ok := true; var uv_ok := true
	for k: int in built.world_vertices.size():
		if built.arrays[Mesh.ARRAY_VERTEX][k] != ProjectionView.project(built.world_vertices[k])-ProjectionView.project(anchor): projection_ok = false
		var uv: Vector2 = built.arrays[Mesh.ARRAY_TEX_UV][k]
		if not uv.is_finite() or uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1: uv_ok = false
	check("world_projection_applied_once",projection_ok)
	check("radial_texture_uvs_bounded",uv_ok)
	check("source_and_index_not_mutated",Canonical.digest(source) == snapshot and Canonical.encode(index) == Canonical.encode(Patch.index(source)))
	var edge := Shadow.mesh_data(Vector3(4,0,50),Vector2(20,20),index,"left",ProjectionView.project)
	check("edge_shadow_clips_to_real_ground",edge.ok and edge.world_vertices.all(func(p: Vector3) -> bool: return p.x >= 0 and p.x <= 24))
	check("edge_shadow_area960",edge.ok and absf(area(edge)-960.0) < 0.00001)
	var ramp_stage := {"surfaces":[cell("ramp",0,100,0,20),cell("lower",0,100,-100,-100)],"connectors":[],"connections":[]}
	var ramp_index := Patch.index(ramp_stage)
	var ramp := Shadow.mesh_data(Vector3(50,10,50),Vector2(20,20),ramp_index,"ramp",ProjectionView.project)
	check("ramp_receiver_preserves_real_height",ramp.ok and ramp.world_vertices.all(func(p: Vector3) -> bool: return absf(float(p.y)-float(p.x)*0.2) < 0.00001))
	check("ramp_does_not_shadow_lower_floor",ramp.ok and ramp.receivers == ["ramp"])
	check("explicit_wrong_surface_does_not_fall_to_lower_floor",Shadow.receiver(Vector3(50,10,50),ramp_index,"lower").is_empty())
	check("automatic_receiver_uses_contact_height",Shadow.receiver(Vector3(50,10,50),ramp_index) == "ramp")
	var bridge_index := Patch.index({"surfaces":[cell("bridge",0,100,160,160),cell("floor",0,100)],"connectors":[],"connections":[]})
	var bridge := Shadow.mesh_data(Vector3(50,160,50),Vector2(20,20),bridge_index,"bridge",ProjectionView.project)
	check("bridge_shadow_stays_at160",bridge.ok and bridge.world_vertices.all(func(p: Vector3) -> bool: return p.y == 160.0) and bridge.receivers == ["bridge"])
	var gap_index := Patch.index({"surfaces":[cell("left",0,40),cell("right",60,100)],"connectors":[],"connections":[]})
	var gap := Shadow.mesh_data(Vector3(40,0,50),Vector2(30,30),gap_index,"left",ProjectionView.project)
	check("real_gap_and_unlinked_neighbor_remain_unshadowed",gap.ok and gap.receivers == ["left"] and gap.world_vertices.all(func(p: Vector3) -> bool: return p.x <= 40))
	check("missing_receiver_is_explicit",Shadow.mesh_data(anchor,Vector2.ONE,index,"absent",ProjectionView.project).code == "shadow_invalid")
	check("negative_radius_rejected",not Shadow.mesh_data(anchor,Vector2(-1,2),index,"left",ProjectionView.project).ok)
	check("nan_anchor_rejected",not Shadow.mesh_data(Vector3(NAN,0,0),Vector2.ONE,index,"left",ProjectionView.project).ok)
	check("missing_projection_rejected",not Shadow.mesh_data(anchor,Vector2.ONE,index,"left",Callable()).ok)
	check("false_support_height_rejected",Shadow.mesh_data(Vector3(50,20,50),Vector2.ONE,index,"left",ProjectionView.project).code == "shadow_receiver_missing")
	check("unbounded_radius_rejected",not Shadow.mesh_data(anchor,Vector2(1024,1024),index,"left",ProjectionView.project).ok)
	var sprite := Sprite2D.new(); sprite.scale = Vector2(0.25,0.25); sprite.z_index = 1
	var attached := Shadow.attach(sprite,anchor,Vector2(20,20),index,"left",ProjectionView.project)
	check("shadow_stays_positive_at_lowest_sprite_depth",attached.ok and attached.node.z_index == 0 and attached.node.show_behind_parent and attached.node.scale == Vector2(4,4))
	sprite.free()
	snapshot_cases()
	finish()
func snapshot_cases() -> void:
	var input := preload("res://tests/fixtures/e07/f1/fixture_input.gd").make()
	var assembled := ExpeditionAssembler.build(input)
	if not assembled.ok: check("shadow_snapshot_bound_to_real_ramp",false); print(assembled); return
	var world := WorldGeometry.new(); world.configure(assembled.data.manifest,"sample")
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,800,800),[],18)
	var actor := PlayerActor.new(); actor.configure(nav,RunState.new(&"mage"))
	var point := ExpeditionWorldPoint.create("sample","sample/slope/surface/floor",Vector3(150,20,50))
	var binding := actor.bind_world_geometry(world,point,input.traversal.to_data(),"shadow_snapshot_player")
	check("shadow_snapshot_bound_to_real_ramp",binding.ok)
	if not binding.ok: actor.free(); return
	actor.health._hp_deficit = 7.25; actor.attack_cooldown = 0.375
	var expected_hp := actor.health.current_hp
	var data := Shadow.mesh_data(point.position,Vector2(10,10),world._support_index,point.surface_id,ProjectionView.project)
	if not data.ok: check("snapshot_cache_contains_real_mesh",false); actor.free(); return
	var cached_mesh := Shadow.mesh(data)
	actor._ground_shadow_cache = {"mesh":cached_mesh,"anchor":point.position,"radii":Vector2(10,10),"surface_id":point.surface_id,"epoch":[world.get_instance_id(),world.configuration_revision,world.geometry_revision]}
	actor.contact_shadows_enabled = false
	check("snapshot_cache_contains_real_mesh",cached_mesh.get_surface_count() == 1 and data.receivers == [point.surface_id])
	var barrier := SnapshotTickBarrier.new(); barrier.acquire(actor)
	var captured := SnapshotRegistry.new().capture(actor,barrier)
	check("snapshot_with_visual_cache_captures",captured.ok)
	if not captured.ok: print(captured); barrier.release(); actor.free(); return
	var payload: Dictionary = bytes_to_var(var_to_bytes(captured.snapshot))
	check("snapshot_binary_roundtrip_valid",SnapshotRegistry.new().validate(payload).ok)
	actor.contact_shadows_enabled = true; actor._ground_shadow_cache.clear()
	var without_cache := SnapshotRegistry.new().capture(actor,barrier)
	check("visual_toggles_do_not_change_snapshot",without_cache.ok and without_cache.snapshot == captured.snapshot)
	barrier.release()
	var restored := SnapshotRegistry.new().restore(payload)
	var gameplay_ok := false; var rebuilt_ok := false
	if restored.ok:
		var copy: PlayerActor = restored.root
		gameplay_ok = copy.world_point().to_data() == point.to_data() and copy.health.current_hp == expected_hp and copy.attack_cooldown == 0.375 and copy.contact_shadows_enabled and copy._ground_shadow_cache.is_empty()
		# CombatActor._draw lazily reconstructs this derived index after hydration.
		copy.world_motion.geometry._ensure_support_index()
		var rebuilt := Shadow.mesh_data(copy.world_point().position,Vector2(10,10),copy.world_motion.geometry._support_index,copy.world_point().surface_id,ProjectionView.project)
		rebuilt_ok = rebuilt.ok and rebuilt.world_vertices == data.world_vertices and Shadow.mesh(rebuilt) != cached_mesh
		copy.free()
	else: print(restored)
	check("snapshot_restores_gameplay_and_default_presentation",gameplay_ok)
	check("restored_shadow_rebuilds_from_preserved_support",rebuilt_ok)
	actor.free()
func finish() -> void:
	var ok := checks.all(func(entry: Dictionary) -> bool: return entry.ok)
	print("F9_SHADOW_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
