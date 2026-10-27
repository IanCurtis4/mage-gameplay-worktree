extends SceneTree
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Store = preload("res://scripts/map_authoring/composition/map_store.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
var checks: Array[Dictionary] = []
var serial := 0
var current_window := ""
var current_pid := -1
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_GAMEPLAY_CLI_CHECK "+id+" "+str(ok))
func run_cli(request: Dictionary) -> Dictionary:
	serial += 1
	var directory := OS.get_environment("F9_EVIDENCE")
	var path := directory.path_join("request_%02d.json"%serial)
	var output := FileAccess.open(path,FileAccess.WRITE); output.store_string(JSON.stringify(request,"",true,true)); output.close()
	var lines: Array = []
	var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://scripts/map_authoring/preview/gameplay_cli.gd","--",path])
	var exit_code := OS.execute(OS.get_executable_path(),args,lines,true,false)
	var text := "".join(lines)
	output = FileAccess.open(directory.path_join("cli_%02d.output.log"%serial),FileAccess.WRITE); output.store_string(text); output.close()
	var result: Dictionary = {"ok":false,"code":"cli_missing_result"}
	for line: String in text.split("\n"):
		if line.begins_with("F9_GAMEPLAY_CLI_RESULT "):
			var decoded: Variant = JSON.parse_string(line.trim_prefix("F9_GAMEPLAY_CLI_RESULT "))
			if decoded is Dictionary: result = decoded
	result["cli_exit_code"] = exit_code
	result["cli_errors"] = "SCRIPT ERROR:" in text or "Parse Error:" in text or "ERROR:" in text
	return result
func active(path: String) -> Dictionary:
	var client := Launcher.new(); client.window_path = path
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		var value := client.state()
		if not value.ok or value.state.state not in ["starting","ready"]: return value
		await create_timer(0.1).timeout
	return {"ok":false,"code":"test_start_timeout"}
func released() -> bool:
	var client := Launcher.new(); client.window_path = current_window
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		var state := client.state(); var window := Launcher.window_header(current_window)
		if state.ok and window.ok and state.state.state == "closed" and not DirAccess.dir_exists_absolute(String(window.directory).path_join("active.lock")): return true
		await create_timer(0.1).timeout
	return false
func run() -> void:
	var directory := OS.get_environment("F9_EVIDENCE")
	var source := Maps.Document.sample()
	var saved := Store.save_source(directory.path_join("map_source.json"),source,"")
	var compiled := Maps.compile(source)
	check("same_canonical_sample_source_and_package",saved.ok and compiled.ok)
	if not compiled.ok: print(compiled); await finish(); return
	var published := Store.publish(directory.path_join("published"),compiled.package,Maps.Document.hash_source(source))
	check("published_package_is_immutable_input",published.ok)
	var request := {"command":"launch","kind":"map","source_path":directory.path_join("map_source.json"),"package_path":published.path,"class_id":"swordsman","headless":true}
	var launched := run_cli(request)
	check("actual_cli_process_launches_fixed_preview_scene",launched.ok and launched.cli_exit_code == 0 and not launched.cli_errors)
	if not launched.ok: print(launched); await finish(); return
	current_window = launched.window_path; current_pid = int(launched.process_id)
	var running := await active(current_window)
	check("cli_launched_game_is_active",running.ok and running.state.state == "active" and running.state.gameplay.ready)
	if not running.ok: print(running); await finish(); return
	var run_id: String = running.state.gameplay.run_id
	var inspected := run_cli({"command":"inspect","window_path":current_window})
	check("cli_inspection_matches_live_actor",inspected.ok and inspected.state.gameplay.run_id == run_id and not inspected.cli_errors)
	var moved := run_cli({"command":"action","window_path":current_window,"action":{"kind":"move","position_xyz":[150,0,50],"geometry_revision":running.state.gameplay.geometry_revision}})
	check("cli_action_gets_shared_command_reply",moved.ok and not moved.pending and moved.reply.result.ok and not moved.cli_errors)
	var deadline := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec() < deadline:
		var client := Launcher.new(); client.window_path = current_window; running = client.state()
		if running.ok and running.state.gameplay.player.point.position_xyz[0] >= 120: break
		await create_timer(0.1).timeout
	check("cli_movement_crosses_real_example_door",running.ok and running.state.gameplay.player.point.position_xyz[0] >= 120)
	var stale := run_cli({"command":"action","window_path":current_window,"action":{"kind":"move","position_xyz":[50,0,50],"geometry_revision":999}})
	check("cli_stale_geometry_reports_canonical_failure",not stale.ok and stale.cli_exit_code != 0 and stale.reply.result.code == "command_stale" and not stale.cli_errors)
	var changed := source.duplicate(true); changed.name += " alterado"
	var replaced := Store.save_source(request.source_path,changed,saved.byte_hash)
	check("authored_source_change_is_saved_canonically",replaced.ok)
	var refused := run_cli(request)
	check("cli_refuses_package_stale_against_current_source",not refused.ok and refused.code == "candidate_stale" and refused.cli_exit_code != 0 and not refused.cli_errors)
	var alive := run_cli({"command":"action","window_path":current_window,"action":{"kind":"inspect"}})
	check("refused_launch_preserves_existing_game",alive.ok and alive.reply.result.ok and alive.reply.result.state.run_id == run_id)
	var foreign_client := Launcher.new(); foreign_client.window_path = current_window
	check("reloaded_client_keeps_foreign_process_lease",foreign_client.running())
	var duplicate := run_cli({"command":"resume","window_path":current_window,"headless":true})
	check("another_cli_cannot_claim_live_run",not duplicate.ok and duplicate.code == "preview_busy" and duplicate.cli_exit_code != 0)
	var stopped := run_cli({"command":"stop","window_path":current_window})
	check("cli_stop_requests_canonical_suspend",stopped.ok and await released())
	var previous_window := current_window
	var resumed := run_cli({"command":"resume","window_path":current_window,"headless":true})
	check("cli_explicit_resume_preserves_old_revision",resumed.ok and resumed.window_path != previous_window and not resumed.cli_errors)
	if not resumed.ok: print(resumed); await finish(); return
	current_window = resumed.window_path; current_pid = int(resumed.process_id)
	running = await active(current_window)
	check("cli_resume_keeps_same_run",running.ok and running.state.state == "active" and running.state.gameplay.run_id == run_id)
	var unknown := run_cli({"command":"inspect","window_path":current_window,"script":"res://scripts/main.gd"})
	check("cli_unknown_fields_never_execute_sender_code",not unknown.ok and unknown.cli_exit_code != 0 and not unknown.cli_errors)
	var closed := run_cli({"command":"action","window_path":current_window,"action":{"kind":"close"}})
	check("cli_close_ack_and_release_are_confirmed",closed.ok and closed.reply.result.ok and await released() and not closed.cli_errors)
	await finish()
func finish() -> void:
	if not current_window.is_empty():
		var client := Launcher.new(); client.window_path = current_window; client.stop()
		await released()
	var ok := checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("F9_GAMEPLAY_CLI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
