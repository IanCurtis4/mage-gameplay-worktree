@tool
extends EditorPlugin
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const CompositionPanel = preload("res://scripts/map_authoring/composition/map_panel.gd")
const Document = preload("res://scripts/map_authoring/composition/map_document.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Store = preload("res://scripts/map_authoring/composition/map_store.gd")
var checks: Array = []
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("M3_UI_CHECK "+id+" "+str(ok))
func _enter_tree() -> void: _run.call_deferred()
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
func _run() -> void:
	await get_tree().process_frame
	if not EditorInterface.is_plugin_enabled("ragrpg_map_editor"): EditorInterface.set_plugin_enabled("ragrpg_map_editor",true)
	await get_tree().process_frame
	EditorInterface.set_main_screen_editor("Mapas")
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == Shell: shell = node
	check("native_shell_visible",shell != null and shell.visible)
	if shell == null: finish(); return
	shell.open_composition()
	await get_tree().process_frame
	var panel: Control = shell.composition_window.get_child(0)
	check("composition_window_visible",shell.composition_window.visible and panel.get_script() == CompositionPanel)
	panel.sample(); var original := Document.hash_source(panel.session.data)
	panel.sample(); check("sample_preserves_nonempty_map",Document.hash_source(panel.session.data) == original)
	panel.bake()
	for i: int in 900:
		await get_tree().process_frame
		if panel.job == null: break
	check("native_worker_completed",panel.job == null and panel.result.get("ok",false))
	if not panel.result.get("ok",false): print(panel.result); finish(); return
	check("native_headless_same_package",panel.result.output_hash == Compiler.compile(panel.session.data).output_hash)
	check("render_two_piece_layers",panel.canvas._meshes.package.get("render_instances",[]).size() == 2 and panel.canvas._meshes.get_children().filter(func(node: Node) -> bool: return node is MeshInstance2D).size() >= 2)
	check("visible_closed_perimeter",panel.result.package.barriers.size() == 8)
	panel.select_id("right"); panel.x.value = 150; panel.apply_placement()
	check("ui_placement_edit",panel.session.data.instances[1].position_xyz[0] == 150)
	check("edit_invalidates_preview",panel.result.is_empty() and panel.canvas.package.is_empty())
	panel.session.undo(); check("ui_undo_restores_links",Document.hash_source(panel.session.data) == original)
	panel.session.redo(); panel.session.undo()
	panel.bake()
	for i: int in 900:
		await get_tree().process_frame
		if panel.job == null: break
	check("recompile_after_undo",panel.result.get("ok",false))
	check("wall_occludes_hidden_floor",not panel.canvas.pick(panel.canvas.screen(Vector3(180,0,50))).ok)
	var hit: Dictionary = panel.canvas.pick(panel.canvas.screen(Vector3(150,0,50)))
	check("click_resolves_canonical_support",hit.ok and hit.data.point.position.distance_to(Vector3(150,0,50)) < 0.001)
	# The real game test of the screen, through the same commands as the buttons.
	var presentation: Control = panel.get_node("AuthoringPresentation"); presentation.set_mode("ax")
	var opened: Dictionary = presentation.ax_invoke("map/gameplay/launch",{"headless":true})
	var running: Dictionary = await test_active(panel.gameplay_tools)
	check("discardable_profile_starts",opened.get("ok",false) and running.get("ok",false) and running.state.state == "active" and running.state.get("gameplay",{}).get("ready",false) and not panel.canvas.testing)
	print("M3_GAME_STATE "+JSON.stringify({"opened":opened,"state":running.get("state",{}).get("state",""),"ready":running.get("state",{}).get("gameplay",{}).get("ready",false),"testing":panel.canvas.testing,"code":running.get("code","")}))
	var target := Vector3(150,0,50)
	var posted: Dictionary = presentation.ax_invoke("map/gameplay/action",{"action":{"kind":"move","position_xyz":[target.x,target.y,target.z],"geometry_revision":running.state.gameplay.geometry_revision}}) if running.get("ok",false) and running.state.state == "active" else {"ok":false}
	check("click_plans_real_actor",posted.get("ok",false))
	var reached := false
	var deadline := Time.get_ticks_msec()+20000
	while posted.get("ok",false) and Time.get_ticks_msec() < deadline:
		running = panel.gameplay_tools.inspect()
		if running.ok and running.state.get("gameplay",{}).get("ready",false):
			var at: Array = running.state.gameplay.player.point.position_xyz
			if Vector3(float(at[0]),float(at[1]),float(at[2])).distance_to(target) < 2.0: reached = true; break
		await get_tree().create_timer(0.1).timeout
	check("native_actor_crosses_seam",reached)
	var stopping: Dictionary = presentation.ax_invoke("map/gameplay/stop")
	var closed: bool = await test_closed(panel.gameplay_tools)
	presentation.set_mode("ux")
	check("test_preserves_draft",stopping.get("ok",false) and closed and not panel.canvas.testing and Document.hash_source(panel.session.data) == original)
	panel._file_action = "save"; var source_path := ProjectSettings.globalize_path("res://.godot/native_map.json"); panel.file_selected(source_path)
	check("ui_save_reopen_exact",Store.load_source(source_path).ok and Document.hash_source(Store.load_source(source_path).data) == original)
	panel._file_action = "publish"; var publication := ProjectSettings.globalize_path("res://.godot/native_publication"); panel.file_selected(publication)
	check("ui_local_publication",FileAccess.file_exists(publication.path_join(panel.result.output_hash+".rmp")))
	panel.preserve_draft()
	panel.links.select(0); panel.remove_link(); panel.bake()
	for i: int in 900:
		await get_tree().process_frame
		if panel.job == null: break
	check("localized_opening_diagnostic",panel.result.code == "opening_unlinked" and panel.problems.item_count == 1)
	panel.focus_problem(0); check("diagnostic_selects_instance",panel.instances.get_selected_items().size() == 1)
	panel.session.undo(); panel.bake()
	for i: int in 900:
		await get_tree().process_frame
		if panel.job == null: break
	panel.select_id("right")
	for i: int in 4: await get_tree().process_frame
	RenderingServer.force_draw()
	var capture_path := OS.get_environment("M3_CAPTURE")
	var image: Image = shell.composition_window.get_texture().get_image()
	if capture_path != "": image.save_png(capture_path)
	check("native_capture",capture_path != "" and FileAccess.file_exists(capture_path))
	var prior: Dictionary = panel.session.data.duplicate(true); prior.name = "Mapa anterior"; panel.session.apply(prior); panel.preserve_draft()
	var prior_path: String = panel._autosave
	panel.new_map(); panel.sample(); panel.preserve_draft(); panel.preserve_draft()
	check("switch_map_preserves_prior_draft",panel._autosave != prior_path and Store.load_source(prior_path).data.name == "Mapa anterior")
	var recover_hash := Document.hash_source(panel.session.data); var edited: Dictionary = panel.session.data.duplicate(true); edited.instances[1].position_xyz[0] = 180; panel.session.apply(edited); panel.recover()
	check("recover_current_draft",Document.hash_source(panel.session.data) == recover_hash)
	panel.canvas.stop_test(); shell.composition_window.hide(); finish()
func finish() -> void:
	var ok := true
	for item: Dictionary in checks:
		if not item.ok: ok = false
	print("M3_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
