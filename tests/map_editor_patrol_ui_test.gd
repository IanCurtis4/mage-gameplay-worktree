@tool
extends EditorPlugin
const PatrolPanel = preload("res://scripts/map_authoring/patrol/patrol_panel.gd")
const PopulationPanel = preload("res://scripts/map_authoring/population/population_panel.gd")
const Fixture = preload("res://tests/map_editor_patrol_test.gd")
const Compiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const Store = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
var checks: Array = []
## Checkpoint49 (P6d): "Testar" opens the real game process (the in-editor
## technical circle was retired in checkpoints 30-40); waits on its state.
func test_active(tools: Control) -> Dictionary:
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		var current: Dictionary = tools.inspect()
		if not current.ok or current.state.state not in ["starting","ready","active"]: return current
		if current.state.state == "active" and current.state.get("gameplay",{}).get("ready",false): return current
		await get_tree().create_timer(0.1).timeout
	return {"ok":false,"code":"test_start_timeout"}
func test_closed(tools: Control) -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		var current: Dictionary = tools.inspect()
		if current.ok and current.state.state == "closed": return true
		await get_tree().create_timer(0.1).timeout
	return false
func _enter_tree() -> void: run.call_deferred()
func check(id: String, value: bool) -> void:
	checks.append({"id":id,"ok":value}); print("M5_UI_CHECK "+id+" "+str(value))
func wait_job(panel: Control) -> void:
	var start := Time.get_ticks_msec()
	while panel.job != null and Time.get_ticks_msec()-start < 180000: await get_tree().process_frame
func wait_preview(panel: Control) -> bool:
	var start := Time.get_ticks_msec()
	while panel.preview_pid > 0 and OS.is_process_running(panel.preview_pid) and Time.get_ticks_msec()-start < 90000: await get_tree().process_frame
	if panel.preview_pid > 0 and OS.is_process_running(panel.preview_pid): OS.kill(panel.preview_pid); return false
	var log_path: String = panel.preview_package.get_base_dir().path_join("preview.log")
	var output := FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else "ERROR: missing preview log"
	return "ERROR:" not in output and "SCRIPT ERROR:" not in output
func run() -> void:
	await get_tree().process_frame
	var parent := PopulationPanel.new(); EditorInterface.get_editor_main_screen().add_child(parent)
	var source := Fixture.fixture(); parent.session.replace(source.population[0]); parent.open_patrols(); await get_tree().process_frame
	var panel: Control = parent.patrol_window.get_child(0)
	check("opens_from_encounters",panel.get_script() == PatrolPanel and parent.patrol_window.visible)
	check("snapshot_imported",panel.session.data.population == source.population)
	panel.add_route(); check("new_route",panel.session.data.patrols.size() == 1)
	panel.wait_time.value = 2
	panel.add_point({"surface_id":source.patrols[0].waypoints[0].surface_id,"position_xyz":[240,0,200],"unknown":true})
	# GUI paint emits only an anchor. Recreate the action without serialized metadata.
	check("reject_unknown_paint_fields",panel.session.data.patrols[0].waypoints.is_empty())
	for p: Dictionary in source.patrols[0].waypoints: panel.add_point({"surface_id":p.surface_id,"position_xyz":p.position_xyz})
	check("paints_ordered_waypoints",panel.session.data.patrols[0].waypoints.size() == 3)
	panel.slots.select(0); panel.assign_slots(); check("assigns_existing_slot",panel.session.data.patrols[0].slot_ids == ["guard"])
	panel.mode.select(1); panel.apply_mode(); check("mode_changes",panel.session.data.patrols[0].mode == "ping_pong")
	panel.points.select(1); panel.wait_time.value = 1.5; panel.apply_wait(); check("edits_wait",panel.session.data.patrols[0].waypoints[1].wait_seconds == 1.5)
	var hash := PatrolPanel.Document.hash_source(panel.session.data); panel.session.undo(); panel.session.redo(); check("undo_redo",PatrolPanel.Document.hash_source(panel.session.data) == hash)
	panel.points.select(2); panel.move_point(-1); check("reorders_points",panel.points.get_selected_items()[0] == 1)
	panel.bake(); await wait_job(panel); check("native_compile_completed",panel.result.get("ok",false))
	if not panel.result.get("ok",false): print(panel.result); parent.free(); finish(); return
	check("gui_headless_same_compiler",Compiler.compile(panel.session.data).output_hash == panel.result.output_hash)
	panel.action = "save"; var path := ProjectSettings.globalize_path("res://.godot/native_patrols_"+Crypto.new().generate_random_bytes(4).hex_encode()+".json"); panel.file_selected(path)
	check("native_save_reopens",Store.load_source(path).ok)
	panel.preserve_draft(); panel.action = "publish"; var directory := ProjectSettings.globalize_path("res://.godot/native_patrol_publications"); panel.file_selected(directory)
	check("local_package",FileAccess.file_exists(directory.path_join(panel.result.output_hash+".rpp")))
	# Checkpoint49 (P6d): the test is the real game process (gameplay_tools), suspended and resumed.
	var started: Dictionary = panel.gameplay_tools.launch("",true)
	var running: Dictionary = await test_active(panel.gameplay_tools)
	check("test_uses_separate_real_process",started.get("ok",false) and running.get("ok",false) and running.state.state == "active" and running.state.get("gameplay",{}).get("ready",false))
	panel.gameplay_tools.stop()
	check("native_preview_suspends_checkpoint",await test_closed(panel.gameplay_tools))
	panel.test(true)
	running = await test_active(panel.gameplay_tools)
	check("native_preview_resumes_checkpoint",running.get("ok",false) and running.state.state == "active")
	panel.gameplay_tools.stop(); await test_closed(panel.gameplay_tools)
	var original := PatrolPanel.Document.hash_source(panel.session.data); panel.points.select(0); panel.request_remove("point"); panel.confirmation.hide(); panel.confirm_remove()
	check("removes_with_confirmation",PatrolPanel.Document.hash_source(panel.session.data) != original); panel.session.undo()
	panel.canvas.patrol_source = panel.session.data.duplicate(true); panel.canvas.redraw()
	await get_tree().process_frame; await get_tree().process_frame
	var image := parent.patrol_window.get_texture().get_image(); image.save_png(OS.get_environment("M5_EVIDENCE").path_join("patrols.png"))
	check("capture_saved",not image.is_empty())
	parent.free(); finish()
func finish() -> void:
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("M5_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
