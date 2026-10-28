extends SceneTree
## Resume the real persisted rounded-hill gameplay in a fresh process.
const App = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const View = preload("res://scripts/world/authored_expedition_view.gd")
const CheckpointCodec = preload("res://scripts/core/expedition/persistence/expedition_checkpoint_codec.gd")
var checks: Array[Dictionary] = []
var app: App
var timings: Dictionary = {}
var evidence_dir := ""

func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ROUNDED_RESUME_CHECK "+id+" "+str(ok))
func frames(count: int = 2) -> void:
	for _index: int in count:
		await process_frame
		RenderingServer.force_draw(false)

func run() -> void:
	root.size = Vector2i(1600,1000)
	DisplayServer.window_set_size(Vector2i(1600,1000))
	evidence_dir = OS.get_environment("F9_EVIDENCE")
	if evidence_dir.is_empty(): evidence_dir = ProjectSettings.globalize_path("res://.godot/rounded_hill_resume_evidence")
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var session_file := OS.get_environment("F9_RESUME_SESSION")
	check("persisted_resume_session_path_is_provided",not session_file.is_empty() and FileAccess.file_exists(session_file))
	if session_file.is_empty() or not FileAccess.file_exists(session_file): finish(); return
	app = App.new(); app.quit_on_close = false; root.add_child(app); current_scene = app
	var open_started := Time.get_ticks_usec()
	var opened: Dictionary = app.open(session_file)
	timings.app_open_ms = float(Time.get_ticks_usec()-open_started)/1000.0
	check("existing_candidate_session_opens_in_fresh_app",opened.get("ok",false))
	if not opened.get("ok",false): await close_app(); finish(); return
	var candidate_hash: String = app.session.session.candidate_hash
	var candidate_package_hash: String = app.session.candidate.package.package_hash
	var start_started := Time.get_ticks_usec()
	var started: Dictionary = app.start()
	timings.resume_start_ms = float(Time.get_ticks_usec()-start_started)/1000.0
	check("existing_suspended_run_resumes_in_new_process",started.get("ok",false) and is_instance_valid(app.host))
	if not started.get("ok",false) or not is_instance_valid(app.host):
		print("F9_ROUNDED_RESUME_START "+JSON.stringify(started)); await close_app(); finish(); return
	var host := app.host
	var world: WorldGeometry = host.player.world_motion.geometry
	var world_point: ExpeditionWorldPoint = host.player.world_point()
	var profile: Dictionary = host.player.world_motion.profile()
	check("same_candidate_and_dense_geometry_are_restored",host.campaign_runtime.state.manifest_data.input.get("preview_candidate_hash","") == candidate_hash and app.prepared.map_package.package_hash == candidate_package_hash and world._stage.surfaces.size() == 536 and world._stage.connections.size() == 828)
	check("player_resumes_on_saved_raised_hill_position",world_point != null and Vector2(world_point.position.x,world_point.position.z).distance_to(Vector2(760,780)) <= 5.0 and world_point.position.y > 100.0)
	check("restored_player_keeps_original_20_by_32_body",host.player.get_parent() == host and host.player.collision_radius == 20.0 and profile.radius == 20.0 and profile.height == 32.0 and world.position_query(world_point,profile,world.geometry_revision).ok)
	var target := support_point(world,Vector2(780,780))
	check("resumed_game_has_nearby_raised_support",target != null and target.position.y > 100.0 and Vector2(target.position.x,target.position.z).distance_to(Vector2(780,780)) <= 5.0)
	if target == null: await close_app(); finish(); return
	var target_screen := View.project(target.position)
	var picked: Dictionary = host.expedition_view.pick(target_screen,world.geometry_revision)
	var picked_point: ExpeditionWorldPoint = point_from(picked.get("data",{}).get("point",{})) if picked.get("ok",false) else null
	check("resumed_authored_view_picks_raised_support",picked_point != null and picked_point.surface_id == target.surface_id and absf(picked_point.position.y-target.position.y) < 0.1)
	var movement_started := Time.get_ticks_usec()
	var moved: Dictionary = host.spatial_pointer_move(target_screen)
	timings.movement_request_ms = float(Time.get_ticks_usec()-movement_started)/1000.0
	check("resumed_player_accepts_canonical_short_walk",moved.get("ok",false))
	if not moved.get("ok",false):
		print("F9_ROUNDED_RESUME_MOVE "+JSON.stringify(moved)); await close_app(); finish(); return
	var start_point: Vector3 = world_point.position
	var frame_samples: Array[float] = []
	var movement_deadline := Time.get_ticks_msec()+45000
	while Time.get_ticks_msec() < movement_deadline and host.player.world_point().position.distance_to(target.position) > 5.0:
		var frame_started := Time.get_ticks_usec()
		await process_frame
		var frame_ms := float(Time.get_ticks_usec()-frame_started)/1000.0
		if frame_samples.size() < 120: frame_samples.append(frame_ms)
	var finish_point: ExpeditionWorldPoint = host.player.world_point()
	var arrived: bool = finish_point != null and finish_point.position.distance_to(target.position) <= 5.0
	timings.short_hill_walk_ms = float(Time.get_ticks_usec()-movement_started)/1000.0
	timings.in_game_frame_sample = summarize_frames(frame_samples)
	timings.scope = "fresh-process persisted resume, one saved rounded-hill session, one nearby walk; no general FPS claim"
	check("resumed_player_walks_across_raised_hill",arrived and start_point.distance_to(finish_point.position) > 5.0 and finish_point.position.y > 100.0)
	check("resumed_player_remains_inside_original_body_clearance",host.player.get_parent() == host and host.player.collision_radius == 20.0 and profile.height == 32.0 and world.position_query(finish_point,profile,world.geometry_revision).ok)
	await frames(2)
	var gameplay_image := root.get_texture().get_image()
	var capture_error: Error = gameplay_image.save_png(evidence_dir.path_join("rounded_hill_resumed_gameplay.png")) if gameplay_image != null else FAILED
	check("fresh_process_gameplay_capture_written",capture_error == OK and gameplay_image.get_size().x >= 1280 and gameplay_image.get_size().y >= 720 and app.host == host)
	var suspended: Dictionary = await app.suspend()
	await frames(2)
	var current_profile: Variant = app.facade.current_profile() if app.facade != null else null
	var lock: Variant = current_profile.expedition_for_character(current_profile.selected_character_id) if current_profile != null else null
	var checkpoint: Dictionary = lock.checkpoint if lock != null else {}
	check("resuspend_saves_format_two_checkpoint_under_original_four_mib",suspended.get("ok",false) and checkpoint.get("format",0) == CheckpointCodec.FORMAT and checkpoint.get("byte_count",CheckpointCodec.MAX_BYTES+1) <= CheckpointCodec.MAX_BYTES)
	timings.resuspend_checkpoint_bytes = checkpoint.get("byte_count",0)
	print("F9_ROUNDED_RESUME_TIMING "+JSON.stringify(timings))
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

func point_from(raw: Dictionary) -> ExpeditionWorldPoint:
	if raw.size() != 3 or not raw.has_all(["stage_id","surface_id","position"]) or not raw.position is Vector3: return null
	return ExpeditionWorldPoint.create(raw.stage_id,raw.surface_id,raw.position)

func summarize_frames(samples: Array[float]) -> Dictionary:
	var ordered := samples.duplicate(); ordered.sort()
	if ordered.is_empty(): return {"count":0,"p50_ms":0.0,"p95_ms":0.0,"max_ms":0.0}
	return {"count":ordered.size(),"p50_ms":ordered[int(floor((ordered.size()-1)*0.50))],"p95_ms":ordered[int(floor((ordered.size()-1)*0.95))],"max_ms":ordered[-1]}

func close_app() -> void:
	if not is_instance_valid(app): return
	if is_instance_valid(app.host):
		await app.suspend()
		await process_frame
	app.request_close()
	await process_frame
	app.free(); app = null

func finish() -> void:
	var ok: bool = checks.all(func(entry: Dictionary) -> bool: return entry.ok)
	print("F9_ROUNDED_RESUME_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"timings":timings}))
	quit(0 if ok else 1)
