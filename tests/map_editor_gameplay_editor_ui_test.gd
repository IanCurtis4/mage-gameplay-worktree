@tool
extends EditorPlugin
const MapPanel = preload("res://scripts/map_authoring/composition/map_panel.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const Tools = preload("res://scripts/map_authoring/preview/gameplay_tools.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
var checks: Array[Dictionary] = []
var window: Window
var panel: Control
func _enter_tree() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_GAMEPLAY_EDITOR_CHECK "+id+" "+str(ok))
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func state(tools: Control) -> Dictionary: return tools.inspect()
func active(tools: Control) -> Dictionary:
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		var current: Dictionary = tools.inspect()
		if not current.ok or current.state.state not in ["starting","ready"]: return current
		await get_tree().create_timer(0.1).timeout
	return {"ok":false,"code":"test_start_timeout"}
func closed(tools: Control) -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		var current: Dictionary = tools.inspect()
		if current.ok and current.state.state == "closed": return true
		await get_tree().create_timer(0.1).timeout
	return false
func run() -> void:
	await get_tree().create_timer(2).timeout
	window = Window.new(); window.title = "Controles de gameplay F9"; window.size = Vector2i(1240,900); get_tree().root.add_child(window)
	panel = MapPanel.new(); window.add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.popup_centered(); await frames()
	check("actual_map_panel_has_gameplay_controls",panel.get_node_or_null("GameplayTools") == panel.gameplay_tools)
	panel.sample(); panel.bake()
	var deadline := Time.get_ticks_msec()+90000
	while panel.job != null and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	check("human_two_room_example_compiles_for_test",panel.result.get("ok",false))
	if not panel.result.get("ok",false): print(panel.result); await finish(); return
	var before := MapDocument.hash_source(panel.session.data)
	var presentation: Control = panel.get_node("AuthoringPresentation")
	var commands: Array = presentation.ax_snapshot().commands.filter(func(value: Dictionary) -> bool: return value.id.begins_with("map/gameplay/"))
	check("seven_shared_gameplay_commands_are_inspectable",commands.size() == 7)
	presentation.set_mode("ax")
	var selected: Dictionary = presentation.ax_invoke("map/gameplay/select_class",{"class_id":"mage"})
	check("ax_class_selection_uses_same_visible_selector",selected.ok and panel.gameplay_tools.selected_class() == "mage")
	var opened: Dictionary = presentation.ax_invoke("map/gameplay/launch",{"headless":true})
	check("ax_launch_uses_actual_fixed_game_scene",opened.ok and not String(opened.window_path).is_empty())
	if not opened.ok: print(opened); await finish(); return
	check("launch_preserves_authored_source",MapDocument.hash_source(panel.session.data) == before)
	check("human_test_does_not_start_technical_circle",not panel.canvas.testing)
	var running := await active(panel.gameplay_tools)
	check("editor_launch_boots_real_player_process",running.ok and running.state.state == "active" and running.state.gameplay.ready)
	if not running.ok or running.state.state != "active": print(running); await finish(); return
	var run_id: String = running.state.gameplay.run_id
	var posted: Dictionary = presentation.ax_invoke("map/gameplay/action",{"action":{"kind":"move","position_xyz":[150,0,50],"geometry_revision":running.state.gameplay.geometry_revision}})
	check("ax_move_posts_to_shared_game_authority",posted.ok)
	deadline = Time.get_ticks_msec()+15000
	while Time.get_ticks_msec() < deadline:
		running = panel.gameplay_tools.inspect()
		if running.ok and running.state.gameplay.get("ready",false) and running.state.gameplay.player.point.position_xyz[0] >= 120: break
		await get_tree().create_timer(0.1).timeout
	check("real_player_crosses_example_door",running.ok and running.state.gameplay.player.point.position_xyz[0] >= 120)
	var stopping: Dictionary = presentation.ax_invoke("map/gameplay/stop")
	check("ax_stop_uses_stable_window_token",stopping.ok)
	check("editor_stop_suspends_before_closing",await closed(panel.gameplay_tools))
	var host := VBoxContainer.new(); window.add_child(host)
	var restored: Control = Tools.mount(host,"map_saved","map",func() -> Dictionary: return panel.session.data,func() -> Dictionary: return panel.result.package,func() -> String: return MapDocument.hash_source(panel.session.data))
	check("new_panel_recovers_last_test_reference",restored.launcher.window_path == panel.gameplay_tools.launcher.window_path)
	var old_window: String = restored.launcher.window_path
	var resumed: Dictionary = restored.resume(true)
	check("resume_uses_new_window_over_saved_revision",resumed.ok and restored.launcher.window_path != old_window)
	running = await active(restored)
	check("resumed_test_keeps_same_run_identity",running.ok and running.state.state == "active" and running.state.gameplay.run_id == run_id)
	restored.stop(); await closed(restored); host.free()
	var changed: Dictionary = panel.session.data.duplicate(true); changed.name += " editado"; panel.session.apply(changed)
	var refused: Dictionary = panel.gameplay_tools.launch("mage",true)
	check("source_change_requires_recompile",not refused.ok and refused.code == "compile_required")
	check("game_controls_do_not_hide_source_undo_history",panel.session.undo() and MapDocument.hash_source(panel.session.data) == before)
	for entry: Array in [["population","res://scripts/map_authoring/population/population_panel.gd"],["patrol","res://scripts/map_authoring/patrol/patrol_panel.gd"]]:
		var screen: Control = load(entry[1]).new(); window.add_child(screen); await frames()
		var tools: Control = screen.get_node_or_null("GameplayTools")
		check(entry[0]+"_has_same_gameplay_tools",tools != null and tools.kind == entry[0])
		var surface: Control = screen.get_node("AuthoringPresentation")
		check(entry[0]+"_has_seven_same_semantic_commands",surface.ax_snapshot().commands.filter(func(value: Dictionary) -> bool: return value.id.begins_with(entry[0]+"/gameplay/")).size() == 7)
		screen.free()
	presentation.set_mode("ux"); await frames(); RenderingServer.force_draw(false); await frames()
	check("capture_real_editor_gameplay_controls",panel.get_viewport().get_texture().get_image().save_png(OS.get_environment("F9_EVIDENCE").path_join("gameplay_editor.png")) == OK)
	await finish()
func finish() -> void:
	if is_instance_valid(panel) and panel.gameplay_tools.launcher.running():
		panel.gameplay_tools.stop(); await closed(panel.gameplay_tools)
	if is_instance_valid(window): window.queue_free()
	var ok := checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("F9_GAMEPLAY_EDITOR_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
