extends SceneTree
## Human start gate, async preparation and window diagnostics (checkpoint31).
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const App = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Protocol = preload("res://scripts/map_authoring/preview/gameplay_protocol.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Fixture = preload("res://tests/map_editor_population_test.gd")
const EXPECTED_CHECKS := 24
var checks: Array[Dictionary] = []
var app: App
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = null) -> void:
	checks.append({"id":id,"ok":ok,"detail":detail}); print("F9_GATE_CHECK "+id+" "+str(ok))
func run() -> void:
	check("protocol_accepts_closed_begin",Protocol.action_valid({"kind":"begin"}))
	check("protocol_rejects_begin_with_payload",not Protocol.action_valid({"kind":"begin","now":true}))
	var compiled := Maps.compile(Fixture.fixture().map[0])
	var made := Candidate.create("map",compiled.package,compiled.package.source_hash) if compiled.ok else {"ok":false}
	var created := Launcher.create_session(made.candidate) if made.ok else {"ok":false}
	var window := Launcher.create_window(created.path) if created.ok else {"ok":false}
	check("fixture_candidate_session_and_window",compiled.ok and made.ok and created.ok and window.ok)
	if not window.ok: finish(); return
	app = App.new(); app.quit_on_close = false; app.hold_start = true; root.add_child(app); current_scene = app
	var opened: Dictionary = await app.open_window_async(window.path)
	check("async_open_claims_window_and_run",opened.ok and app.claimed and app.window_claimed and app.status == "ready")
	check("async_open_records_prepare_time",app.timings.get("prepare_ms",-1.0) is float and float(app.timings.prepare_ms) >= 0.0 and app.timings.get("resolve_ms",-1.0) is float and float(app.timings.resolve_ms) >= 0.0)
	check("async_open_releases_busy",not app.busy)
	var started: Dictionary = await app._start_with_gate()
	check("gate_start_boots_campaign",started.ok and is_instance_valid(app.host))
	if not started.ok: print(started); finish(); return
	check("gate_holds_status_and_pauses_tree",app.status == "held" and paused)
	check("gate_shows_start_button",app.gate_layer.visible and app.gate_button.visible)
	var state := Launcher.window_state(window.path)
	check("window_status_reports_held",state.ok and state.state.state == "held")
	var timings_path: String = String(window.directory).path_join("timings.json")
	var timings: Variant = JSON.parse_string(FileAccess.get_file_as_string(timings_path)) if FileAccess.file_exists(timings_path) else null
	check("timings_file_has_phases",timings is Dictionary and timings.has_all(["prepare_ms","start_ms","first_frame_after_start_ms","boot_to_world_ms"]))
	var before: Dictionary = app.describe_gameplay()
	await create_timer(1.5,true).timeout
	var after: Dictionary = app.describe_gameplay()
	check("held_world_does_not_advance_actors",before.get("enemies",[]) == after.get("enemies",[]) and before.get("player") == after.get("player"))
	var metrics_path: String = String(window.directory).path_join("metrics.jsonl")
	var lines: PackedStringArray = FileAccess.get_file_as_string(metrics_path).strip_edges().split("\n") if FileAccess.file_exists(metrics_path) else PackedStringArray()
	var first: Variant = JSON.parse_string(lines[0]) if lines.size() > 0 else null
	check("metrics_lines_are_written_while_held",lines.size() >= 1 and first is Dictionary and first.has_all(["t_s","status","paused","frames","max_frame_ms","fps","process_ms","physics_ms"]))
	var begun := app.begin()
	check("begin_unpauses_active_campaign",begun.ok and app.status == "active" and not paused and not app.gate_layer.visible)
	check("second_begin_is_refused",not app.begin().ok and app.begin().code == "preview_not_held")
	check("begin_records_time",app.timings.has("begin_after_boot_ms"))
	var restarted: Dictionary = await app.restart()
	check("restart_is_async_and_holds_again",restarted.ok and app.status == "held" and paused and is_instance_valid(app.host))
	var suspended: Dictionary = await app.suspend()
	check("suspend_from_held_gate_completes",suspended.ok)
	var deadline := Time.get_ticks_msec()+30000
	while is_instance_valid(app.host) and Time.get_ticks_msec() < deadline: await create_timer(0.1,true).timeout
	check("held_suspend_returns_to_lobby",not is_instance_valid(app.host) and app.status == "suspended")
	app.free(); app = null
	paused = false
	var plain := App.new(); plain.quit_on_close = false; root.add_child(plain)
	check("default_app_does_not_hold",not plain.hold_start)
	plain.free()
	var external := Launcher.create_session(made.candidate)
	var launcher := Launcher.new()
	var launched := launcher.open_session(external.path,true,true) if external.ok else {"ok":false}
	check("launcher_passes_hold_to_separate_process",launched.ok and launcher.process_id > 0)
	if not launched.ok: finish(); return
	deadline = Time.get_ticks_msec()+120000
	while Time.get_ticks_msec() < deadline:
		state = launcher.state()
		if not state.ok or state.state.state not in ["starting","ready"]: break
		await create_timer(0.1).timeout
	check("separate_process_reaches_held",state.ok and state.state.state == "held",state)
	var stop := launcher.stop()
	deadline = Time.get_ticks_msec()+90000
	while OS.is_process_running(launcher.process_id) and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
	state = launcher.state()
	check("held_separate_process_closes_on_stop",stop.ok and not OS.is_process_running(launcher.process_id) and state.ok and state.state.state == "closed")
	var external_window := Launcher.window_header(launcher.window_path)
	var log_path: String = String(external_window.directory).path_join("engine.log") if external_window.ok else ""
	var log := FileAccess.get_file_as_string(log_path) if not log_path.is_empty() and FileAccess.file_exists(log_path) else "missing"
	check("separate_process_log_clean",log != "missing" and "SCRIPT ERROR:" not in log and "Parse Error:" not in log and "ERROR:" not in log)
	finish()

func finish() -> void:
	if is_instance_valid(app): app.free()
	paused = false
	var ok := checks.size() == EXPECTED_CHECKS and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_GATE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"expected_count":EXPECTED_CHECKS})); quit(0 if ok else 1)
