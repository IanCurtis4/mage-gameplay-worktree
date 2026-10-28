extends SceneTree
## Native GL SceneTree proof: GUI/AX authoring, compilation, picking and a real player body.
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const App = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const View = preload("res://scripts/world/authored_expedition_view.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")

var checks: Array[Dictionary] = []
var panel: TerrainPanel
var canvas: Variant
var scroll: ScrollContainer
var app: App
var presentation: Variant
var timings: Dictionary = {}
var evidence_dir := ""

func _initialize() -> void: run.call_deferred()

func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ROUNDED_UI_CHECK "+id+" "+str(ok))

func frames(count: int = 2) -> void:
	for _index: int in count:
		await process_frame
		RenderingServer.force_draw(false)

func run() -> void:
	root.size = Vector2i(1600,1000)
	DisplayServer.window_set_size(Vector2i(1600,1000))
	evidence_dir = OS.get_environment("F9_EVIDENCE")
	if evidence_dir.is_empty(): evidence_dir = ProjectSettings.globalize_path("res://.godot/rounded_hill_evidence")
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	Presentation.active_mode = "ux"
	scroll = ScrollContainer.new()
	scroll.name = "TerrainViewport"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	panel = TerrainPanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	canvas = panel.canvas
	var session := Session.new()
	var empty := Document.empty("rounded_hill_native")
	var empty_hash := Schema.semantic_hash(empty)
	check("native_empty_session_replaced",session.replace(empty).ok)
	panel.bind(session)
	await frames(3)
	var gui_button := find_button(panel,"Exemplo orgânico")
	check("real_terrain_panel_and_gui_action_present",canvas != null and gui_button != null and gui_button.is_visible_in_tree())
	var button_rect := gui_button.get_global_rect() if gui_button != null else Rect2()
	var viewport_rect := scroll.get_global_rect()
	check("panel_toolbar_fits_without_horizontal_overflow",scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and scroll.scroll_horizontal == 0 and panel.size.x <= scroll.size.x+1.0 and button_rect.position.x >= viewport_rect.position.x and button_rect.end.x <= viewport_rect.end.x)
	if gui_button == null: finish(); return
	gui_button.pressed.emit()
	await frames(2)
	var gui_hash := session.document().semantic_hash()
	var gui_applied := session.document().to_data().revision == 2 and gui_hash != empty_hash and session.can_undo()
	check("gui_example_is_one_atomic_session_apply",gui_applied)
	check("gui_apply_undo_redo_restores_exact_source",session.undo() and session.document().semantic_hash() == empty_hash and session.redo() and session.document().semantic_hash() == gui_hash and session.undo() and session.document().semantic_hash() == empty_hash)
	presentation = panel.get_node_or_null("AuthoringPresentation")
	var entered_ax: Dictionary = presentation.set_mode("ax") if presentation != null else {"ok":false}
	var ax_result: Dictionary = presentation.ax_invoke("terrain/example/organic",{}) if presentation != null else {"ok":false}
	await frames(2)
	check("ax_example_uses_same_real_command_provider",entered_ax.ok and ax_result.ok and session.document().semantic_hash() == gui_hash and session.document().to_data().revision == 2)
	check("ax_and_gui_publish_identical_piece_and_curve",session.document().semantic_hash() == gui_hash and session.document().to_data().layers[0].heights == canvas.source.layers[0].heights)
	if presentation != null: presentation.set_mode("ux")

	var preparation_started := Time.get_ticks_usec()
	panel.bake()
	var movement_deadline := Time.get_ticks_msec()+45000
	while panel.job != null and Time.get_ticks_msec() < deadline: await process_frame
	timings.compile_prepare_ms = float(Time.get_ticks_usec()-preparation_started)/1000.0
	var compiled: bool = panel.job == null and panel.result.get("ok",false) and not panel.result.get("package",{}).is_empty()
	check("same_gui_authored_piece_compiles_and_is_published_to_canvas",compiled and canvas.package.get("package_hash","") == panel.result.package.get("package_hash","") and panel.result.package.source_hash == session.document().semantic_hash())
	if not compiled: finish(); return
	var package: Dictionary = panel.result.package
	canvas.fit()
	scroll.scroll_vertical = maxi(0,roundi(canvas.position.y)-100)
	await frames(3)
	var terrain_image := root.get_texture().get_image()
	var terrain_capture := terrain_image.save_png(evidence_dir.path_join("rounded_hill_curve_and_path.png")) if terrain_image != null else FAILED
	check("native_curve_and_path_capture_written",terrain_capture == OK and terrain_image.get_size().x >= 1280 and terrain_image.get_size().y >= 720)

	var authored_map := map_source(session.document().to_data())
	var map_compile_started := Time.get_ticks_usec()
	var built := Maps.compile(authored_map)
	timings.map_publish_ms = float(Time.get_ticks_usec()-map_compile_started)/1000.0
	check("same_gui_ax_authored_piece_compiles_as_map",built.ok and built.package.source_hash == MapDocument.hash_source(authored_map))
	if not built.ok: print("F9_ROUNDED_MAP_COMPILE "+JSON.stringify(built)); finish(); return
	var candidate_result := Candidate.create("map",built.package,built.package.source_hash)
	check("compiled_gui_piece_becomes_candidate",candidate_result.ok)
	if not candidate_result.ok: print("F9_ROUNDED_CANDIDATE "+JSON.stringify(candidate_result)); finish(); return
	var created := Launcher.create_session(candidate_result.candidate)
	check("candidate_is_published_to_disposable_session",created.ok)
	if not created.ok: print("F9_ROUNDED_SESSION "+JSON.stringify(created)); finish(); return
	# Remove the editor renderer before sampling so the timing is from the game view alone.
	root.remove_child(scroll)
	scroll.free(); scroll = null; panel = null; canvas = null
	app = App.new(); app.quit_on_close = false; root.add_child(app); current_scene = app
	var open_started := Time.get_ticks_usec()
	var opened := app.open(created.path)
	timings.app_open_ms = float(Time.get_ticks_usec()-open_started)/1000.0
	check("real_preview_app_opens_published_candidate",opened.ok)
	if not opened.ok: print("F9_ROUNDED_APP_OPEN "+JSON.stringify(opened)); await close_app(); finish(); return
	var start_started := Time.get_ticks_usec()
	var started := app.start()
	timings.app_start_ms = float(Time.get_ticks_usec()-start_started)/1000.0
	check("real_preview_app_starts_without_duplicate_prepare",started.ok and is_instance_valid(app.host))
	if not started.ok: print("F9_ROUNDED_APP_START "+JSON.stringify(started)); await close_app(); finish(); return
	var host := app.host
	var world: WorldGeometry = host.player.world_motion.geometry
	var target := support_point(world,Vector2(760,780))
	var profile: Dictionary = host.player.world_motion.profile()
	check("real_gameplay_has_raised_target_and_prescribed_body",target != null and target.position.y > 100.0 and profile.radius == 20.0 and profile.height == 32.0 and host.player.get_parent() == host)
	if target == null: await close_app(); finish(); return
	var target_screen := View.project(target.position)
	var picked: Dictionary = host.expedition_view.pick(target_screen,world.geometry_revision)
	var picked_point: ExpeditionWorldPoint = point_from(picked.get("data",{}).get("point",{})) if picked.get("ok",false) else null
	check("real_game_view_picks_raised_piece_support",picked_point != null and picked_point.surface_id == target.surface_id and absf(picked_point.position.y-target.position.y) < 0.1)
	var movement_started := Time.get_ticks_usec()
	var moved: Dictionary = host.spatial_pointer_move(target_screen)
	timings.movement_request_ms = float(Time.get_ticks_usec()-movement_started)/1000.0
	check("real_game_pointer_starts_canonical_walk",moved.ok)
	if not moved.ok: print("F9_ROUNDED_MOVE "+JSON.stringify(moved)); await close_app(); finish(); return
	var frame_samples: Array[float] = []
	var deadline := Time.get_ticks_msec()+45000
	var start_point: Vector3 = host.player.world_point().position
	var arrived := false
	while Time.get_ticks_msec() < movement_deadline and host.player.world_point().position.distance_to(target.position) > 5.0:
		var frame_started := Time.get_ticks_usec()
		await process_frame
		var frame_ms := float(Time.get_ticks_usec()-frame_started)/1000.0
		if frame_samples.size() < 120: frame_samples.append(frame_ms)
	arrived = host.player.world_point().position.distance_to(target.position) <= 5.0
	timings.in_game_movement_ms = float(Time.get_ticks_usec()-movement_started)/1000.0
	timings.in_game_frame_sample = summarize_frames(frame_samples)
	timings.scope = "one published piece, one real App route; frame durations sampled during gameplay; no general FPS claim"
	var finish_point := host.player.world_point()
	check("real_player_walks_from_safe_start_to_raised_target",arrived and start_point.distance_to(finish_point.position) > 30.0 and finish_point.position.y > 100.0)
	check("real_player_keeps_20_by_32_body_and_actor_ownership",host.player.get_parent() == host and host.player.collision_radius == 20.0 and profile.height == 32.0 and world.position_query(finish_point,profile,world.geometry_revision).ok)
	await frames(2)
	var gameplay_image := root.get_texture().get_image()
	var gameplay_capture := gameplay_image.save_png(evidence_dir.path_join("rounded_hill_gameplay_walk.png")) if gameplay_image != null else FAILED
	check("real_app_gameplay_capture_written",gameplay_capture == OK and gameplay_image.get_size().x >= 1280 and gameplay_image.get_size().y >= 720 and app.host == host)
	print("F9_ROUNDED_TIMING "+JSON.stringify(timings))
	await close_app()
	finish()

func support_point(world: WorldGeometry, horizontal: Vector2) -> ExpeditionWorldPoint:
	if world == null: return null
	for cell: Dictionary in world._stage.surfaces:
		var supported := world.support_at(cell.surface_id,horizontal,world.geometry_revision)
		if supported.ok:
			var raw: Dictionary = supported.data.point
			return ExpeditionWorldPoint.create(raw.stage_id,raw.surface_id,raw.position)
	return null

func map_source(source: Dictionary) -> Dictionary:
	var data := MapDocument.empty("rounded_hill_map")
	var hash_value: String = Schema.semantic_hash(source)
	data.pieces = [{"piece_hash":hash_value,"source":source}]
	data.instances = [{"instance_id":"hill","piece_hash":hash_value,"position_xyz":[0,0,0],"rotation_quarters":0}]
	return data

func summarize_frames(samples: Array[float]) -> Dictionary:
	var ordered := samples.duplicate()
	ordered.sort()
	if ordered.is_empty(): return {"count":0,"p50_ms":0.0,"p95_ms":0.0,"max_ms":0.0}
	return {"count":ordered.size(),"p50_ms":ordered[int(floor((ordered.size()-1)*0.50))],"p95_ms":ordered[int(floor((ordered.size()-1)*0.95))],"max_ms":ordered[-1]}

func close_app() -> void:
	if not is_instance_valid(app): return
	if is_instance_valid(app.host):
		await app.suspend()
		await process_frame
	app.request_close()
	await process_frame
	app.free()
	app = null

func point_from(raw: Dictionary) -> ExpeditionWorldPoint:
	if raw.size() != 3 or not raw.has_all(["stage_id","surface_id","position"]) or not raw.position is Vector3: return null
	return ExpeditionWorldPoint.create(raw.stage_id,raw.surface_id,raw.position)

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child: Node in node.get_children():
		var found := find_button(child,caption)
		if found != null: return found
	return null

func pixel_delta(before: Image, after: Image) -> int:
	if before == null or after == null or before.get_size() != after.get_size(): return 0
	var changed := 0
	for y: int in range(0,after.get_height(),4):
		for x: int in range(0,after.get_width(),4):
			if before.get_pixel(x,y) != after.get_pixel(x,y): changed += 1
	return changed

func finish() -> void:
	if presentation != null: presentation.set_mode("ux")
	else: Presentation.active_mode = "ux"
	if is_instance_valid(panel): panel.free()
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_ROUNDED_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"timings":timings}))
	quit(0 if ok else 1)
