extends SceneTree
## Real App and separately launched normal Godot process; no EditorPlugin.
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const App = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Fixture = preload("res://tests/map_editor_population_test.gd")
var checks: Array[Dictionary] = []
var app: App
var launcher: Launcher
var evidence: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_WINDOW_CHECK "+id+" "+str(ok))
func run() -> void:
	var source: Dictionary = Fixture.fixture().map[0]
	var compiled := Maps.compile(source)
	check("actual_wide_map_compiles",compiled.ok)
	if not compiled.ok: print(compiled); finish(); return
	var made := Candidate.create("map",compiled.package,compiled.package.source_hash)
	var created := Launcher.create_session(made.candidate)
	check("run_session_created",made.ok and created.ok)
	if not created.ok: print(created); finish(); return
	var window := Launcher.create_window(created.path)
	check("window_descriptor_is_independent_from_run",window.ok and window.path != created.path and window.window.window_id != created.session.session_id)
	check("window_header_roundtrips_closed_namespace",Launcher.window_header(window.path) == window)
	check("foreign_window_path_refused",not Launcher.window_header(ProjectSettings.globalize_path("user://window.bin")).ok)
	check("run_header_has_no_loaded_payload",not Launcher.session_header(created.path).has("candidate"))
	app = App.new(); app.quit_on_close = false; root.add_child(app); current_scene = app
	var opened := app.open_window(window.path)
	check("app_claims_window_and_run",opened.ok and app.claimed and app.window_claimed)
	check("second_window_owner_refused",not Launcher.claim_window(window).ok)
	check("second_run_owner_refused",not Launcher.claim(Launcher.session_header(created.path)).ok)
	var started := app.start()
	check("window_boots_actual_campaign",started.ok and is_instance_valid(app.host) and app.host.player is PlayerActor)
	if not started.ok: print(started); finish(); return
	var state := Launcher.window_state(window.path)
	check("window_status_names_current_run",state.ok and state.state.current_session_path == created.path and state.state.state == "active")
	check("native_window_title_identifies_candidate",root.title.contains("Teste descartável") and root.title.contains(String(made.candidate.candidate_hash).substr(0,10)))
	var restarted := await app.restart()
	check("restart_keeps_window_identity",restarted.ok and app.window.path == window.path and app.window_claimed)
	check("restart_creates_new_run_identity",app.session.path != created.path and app.claimed)
	var current_path: String = app.session.path
	state = Launcher.window_state(window.path)
	check("stable_window_tracks_restarted_run",state.ok and state.state.current_session_path == current_path and state.state.state == "active")
	check("old_profile_is_preserved",FileAccess.file_exists(String(created.directory).path_join("profile/profile.json")))
	var old_hash := FileAccess.get_sha256(String(created.directory).path_join("profile/profile.json"))
	check("restart_releases_old_run_lease",not DirAccess.dir_exists_absolute(String(created.directory).path_join("active.lock")))
	check("restart_holds_new_run_lease",DirAccess.dir_exists_absolute(String(app.session.directory).path_join("active.lock")))
	var stop_path: String = String(window.directory).path_join("stop.request")
	Launcher.write_atomic(stop_path,"wrong_window_token".to_utf8_buffer())
	await create_timer(0.6).timeout
	check("foreign_stop_token_does_not_suspend",app.status == "active" and is_instance_valid(app.host))
	launcher = Launcher.new(); launcher.window_path = window.path; launcher.session_path = created.path; launcher.process_id = OS.get_process_id()
	var stopped := launcher.stop()
	check("stop_targets_window_after_internal_restart",stopped.ok and FileAccess.get_file_as_string(stop_path) == window.window.window_id)
	var deadline := Time.get_ticks_msec()+90000
	while app.status != "closed" and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
	check("stable_stop_suspends_restarted_campaign",app.status == "closed" and not is_instance_valid(app.host))
	check("both_owned_leases_released",not app.claimed and not app.window_claimed and not DirAccess.dir_exists_absolute(String(window.directory).path_join("active.lock")))
	check("previous_profile_unchanged_by_new_run_stop",FileAccess.get_sha256(String(created.directory).path_join("profile/profile.json")) == old_hash)
	state = launcher.state()
	check("launcher_follows_current_run_without_pid_kill",state.ok and state.state.state == "closed" and launcher.session_path == current_path)
	app.free(); app = null
	var refused := App.new(); refused.quit_on_close = false; root.add_child(refused)
	var consumed := refused.open_window(window.path)
	check("used_window_is_not_replayed",not consumed.ok and consumed.code == "window_consumed" and not refused.claimed and not refused.window_claimed)
	refused.free()
	check("rejected_replay_preserves_closed_window_status",Launcher.window_state(window.path).state.state == "closed")
	var launched := launcher.open_session(current_path,true)
	check("launcher_starts_separate_normal_godot_process",launched.ok and launcher.process_id > 0 and launcher.process_id != OS.get_process_id())
	if not launched.ok: print(launched); finish(); return
	check("reopen_creates_fresh_window",launcher.window_path != window.path)
	deadline = Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		state = launcher.state()
		if not state.ok or state.state.state not in ["starting","ready"]: break
		await create_timer(0.1).timeout
	if not state.ok or state.state.state != "active": print("F9_WINDOW_LAUNCH_STATE "+JSON.stringify(state))
	check("separate_process_resumes_same_saved_run",state.ok and state.state.state == "active" and state.state.current_session_path == current_path)
	check("separate_process_keeps_candidate_identity",state.ok and state.state.candidate_hash == made.candidate.candidate_hash)
	var external_window := Launcher.window_header(launcher.window_path)
	evidence = {"window_path":window.path,"run_before":created.path,"run_after":current_path,"process_window":launcher.window_path,"process_id":launcher.process_id}
	var requested := launcher.stop()
	check("separate_process_accepts_tokened_stop",requested.ok)
	deadline = Time.get_ticks_msec()+90000
	while OS.is_process_running(launcher.process_id) and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
	state = launcher.state()
	check("owned_process_exits_after_canonical_suspend",not OS.is_process_running(launcher.process_id) and state.ok and state.state.state == "closed")
	var log_path: String = String(external_window.directory).path_join("engine.log")
	var log := FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else "missing"
	check("separate_process_log_has_no_engine_or_script_errors",log != "missing" and "SCRIPT ERROR:" not in log and "Parse Error:" not in log and "ERROR:" not in log)
	evidence["engine_log"] = log_path; evidence["engine_log_sha256"] = FileAccess.get_sha256(log_path)
	var destination := OS.get_environment("F9_EVIDENCE")
	var output := FileAccess.open(destination.path_join("separate_process.engine.log"),FileAccess.WRITE); output.store_string(log); output.close()
	output = FileAccess.open(destination.path_join("window_identity.json"),FileAccess.WRITE); output.store_string(JSON.stringify(evidence,"\t")); output.close()
	finish()

func finish() -> void:
	if is_instance_valid(app): app.free()
	paused = false
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_WINDOW_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
