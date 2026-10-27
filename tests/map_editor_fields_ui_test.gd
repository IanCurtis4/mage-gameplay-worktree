extends SceneTree
## Actual canonical casts, native pixels, support provenance and snapshot exclusion.
const Views = preload("res://scripts/world/world_field_view.gd")
const Authored = preload("res://scripts/world/authored_expedition_view.gd")
const Fixture = preload("res://tests/map_editor_viewport_test.gd")
const MapFixture = preload("res://tests/map_editor_borders_test.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
var checks: Array[Dictionary] = []
var package: Dictionary = {}
var owner_host: RunController
var view: Authored
var camera: Camera2D
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_FIELDS_UI_CHECK "+id+" "+str(ok))
func frames() -> void:
	await process_frame; RenderingServer.force_draw(false); await process_frame; await process_frame
func run() -> void:
	root.size = Vector2i(1400,900)
	var source := Fixture.source()
	for layer: Dictionary in source.layers:
		layer.origin_xz[0] *= 4; layer.origin_xz[1] *= 4; layer.sample_spacing *= 4
	for surface: Dictionary in source.special_surfaces:
		for point: Array in surface.vertices_xyz: point[0] *= 4; point[2] *= 4
	var built := Maps.compile(MapFixture.map_source(source,"ruin_envelope_v1"))
	check("authored_ramp_and_bridge_keep_height_and_real_scale",built.ok)
	if not built.ok: print(built); finish(); return
	package = built.package
	for location: String in ["under_bridge","on_bridge","ramp"]:
		for id: StringName in [&"fire_wall",&"lightning_wall",&"phantom_barrier",&"ice_wall"]:
			await scenario(id,location)
	finish()
func scenario(id: StringName, location: String) -> void:
	var prefix := String(id)+"_"+location+"_"
	var world := WorldGeometry.new(); world.configure(Maps.manifest(package),"map_preview")
	owner_host = RunController.new(); owner_host.snapshot_passive = true; root.add_child(owner_host); owner_host.snapshot_passive = false; owner_host.set_process(false); owner_host.navigation.configure(Rect2(0,0,2000,2000),[],0)
	var build := BuildSnapshot.new(); build.character_id = "visual_fields"; build.base_class_id = &"mage"; build.base_level = ProgressionRules.MAX_BASE_LEVEL; build.job_level = 40; build.attribute_allocations = {&"int":20,&"dex":20}; build.skill_ranks = {id:1}; build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(&"mage",&""); Dependencies.complete_snapshot(build)
	owner_host.run_state = RunState.from_build("visual_fields",build); owner_host.player = PlayerActor.new(); owner_host.add_child(owner_host.player); owner_host.player.configure(owner_host.navigation,owner_host.run_state)
	var position := Vector3(80,40 if location == "on_bridge" else 0,600)
	var normal := Vector3.RIGHT
	if location == "ramp": position = Vector3(600,20,80); normal = Vector3.BACK
	var point := Fixture.at(world,position)
	var bound := owner_host.player.bind_world_geometry(world,point,{"radius":20.0,"height":32.0,"connector_kinds":["walk"]},"field_player")
	owner_host.player.set_process(false)
	owner_host.player.fire_wall_requested.connect(owner_host._on_fire_wall_requested); owner_host.player.lightning_wall_requested.connect(owner_host._on_lightning_wall_requested); owner_host.player.phantom_barrier_requested.connect(owner_host._on_phantom_barrier_requested); owner_host.player.ice_wall_requested.connect(owner_host._on_ice_wall_requested)
	view = Authored.new(); root.add_child(view); view.set_process(false); view.controller = owner_host
	var made := view.configure_package(package,world); view.observe(owner_host.player)
	camera = Camera2D.new(); root.add_child(camera); camera.position = ExpeditionGeometryView.project(Vector3(600,20,400)); camera.zoom = Vector2.ONE*0.7; camera.make_current()
	var sp := owner_host.player.current_sp
	var cast := owner_host.cast_world_skill(id,null,normal,null,world.geometry_revision,0,32.0) if bound.ok else bound
	if cast.ok and owner_host.player.has_active_cast(): owner_host.player._advance_world_cast(10)
	var emitted: Node
	for node: Node in owner_host.get_children():
		if (node is FireWall or node is LightningWall or node is PhantomBarrier or node is IceWall) and not node.is_queued_for_deletion(): emitted = node; break
	check(prefix+"real_cast_emits_field_and_pays_canonical_cost",bound.ok and made.ok and cast.ok and emitted != null and owner_host.player.current_sp < sp)
	if emitted == null: print(cast); cleanup(); return
	emitted.set_process(false); paused = true
	var geometry_revision := world.geometry_revision; var actor_before := owner_host.player.world_point().to_data(); var parent := emitted.get_parent(); var index := emitted.get_index(); var remaining: float = emitted.remaining
	var field_before := ExpeditionCanonical.digest(Views.describe(emitted,world))
	await frames(); var without := root.get_texture().get_image()
	view.sync(); await frames(); var with_fields := root.get_texture().get_image()
	var parts: Array = view.field_views.entries[str(emitted.get_instance_id())].parts
	var changed := 0
	for y: int in with_fields.get_height():
		for x: int in with_fields.get_width():
			if with_fields.get_pixel(x,y) != without.get_pixel(x,y): changed += 1
	# Under the bridge the field can be completely occluded; reveal only the
	# bridge skin for this pixel proof. Geometry and field remain untouched.
	if location == "under_bridge":
		check(prefix+"actual_bridge_occludes_field_below",changed == 0 and with_fields.save_png(OS.get_environment("F9_EVIDENCE").path_join(prefix+"occluded.png")) == OK)
		for child: Node in view.skin.get_children():
			if child is MeshInstance2D and not child.has_meta("world_vertices"):
				var record: Dictionary = child.get_meta("canvas_order_record",{})
				if record.get("kind") == "mesh" and record.anchor.y >= 34: child.hide()
		for part: Node2D in parts: part.hide()
		await frames(); without = root.get_texture().get_image()
		for part: Node2D in parts: part.show()
		await frames(); with_fields = root.get_texture().get_image(); changed = 0
		for y: int in with_fields.get_height():
			for x: int in with_fields.get_width():
				if with_fields.get_pixel(x,y) != without.get_pixel(x,y): changed += 1
	check(prefix+"native_field_changes_pixels_on_its_support",changed > 8 and with_fields.save_png(OS.get_environment("F9_EVIDENCE").path_join(prefix+"field.png")) == OK)
	var grounded := not parts.is_empty()
	for part: Node2D in parts:
		var record: Dictionary = part.get_meta("canvas_order_record")
		grounded = grounded and record.anchor.y >= -WorldGeometry.EPS and not part.receivers.is_empty()
		if location == "on_bridge": grounded = grounded and absf(record.anchor.y-40) <= WorldGeometry.EPS
		elif location == "under_bridge": grounded = grounded and absf(record.anchor.y) <= WorldGeometry.EPS
		else: grounded = grounded and absf(record.anchor.y-(record.anchor.x-400)*0.1) <= 0.001
	check(prefix+"visual_anchor_keeps_actual_floor_and_slope",grounded and view.ordering.ok)
	check(prefix+"presentation_preserves_field_actor_cost_and_geometry",world.geometry_revision == geometry_revision and owner_host.player.world_point().to_data() == actor_before and emitted.get_parent() == parent and emitted.get_index() == index and emitted.remaining == remaining and ExpeditionCanonical.digest(Views.describe(emitted,world)) == field_before)
	if location == "ramp":
		var ids: Array = parts.map(func(part: Node2D) -> int: return part.get_instance_id())
		view.sync()
		check(prefix+"warm_sync_reuses_fragments_and_order",ids == view.field_views.entries[str(emitted.get_instance_id())].parts.map(func(part: Node2D) -> int: return part.get_instance_id()) and view.ordering.unchanged)
		var barrier := SnapshotTickBarrier.new(); barrier.acquire(owner_host)
		var before := SnapshotRegistry.new().capture(owner_host,barrier)
		view.field_views.clear(); view.sync()
		var after := SnapshotRegistry.new().capture(owner_host,barrier); barrier.release()
		if not before.ok: print("F9_FIELDS_CUT_BEFORE "+str(before))
		if not after.ok: print("F9_FIELDS_CUT_AFTER "+str(after))
		if before.ok and after.ok and before.snapshot != after.snapshot: print("F9_FIELDS_CUT_DIFFERENT "+prefix)
		check(prefix+"visuals_stay_out_of_actor_snapshot",before.ok and after.ok and before.snapshot == after.snapshot)
	emitted.queue_free(); view.sync()
	check(prefix+"expiration_removes_only_derived_visuals",view.field_views.entries.is_empty() and world.geometry_revision == geometry_revision)
	cleanup(); await process_frame
func cleanup() -> void:
	paused = false
	if is_instance_valid(view): view.free()
	if is_instance_valid(camera): camera.free()
	if is_instance_valid(owner_host): owner_host.free()
func finish() -> void:
	var ok := checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("F9_FIELDS_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
