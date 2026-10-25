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
	check("render_two_piece_layers",panel.canvas._meshes.get_child_count() == 2)
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
	panel.toggle_test(); check("discardable_profile_starts",panel.canvas.testing and panel.canvas.motion != null)
	check("wall_occludes_hidden_floor",not panel.canvas.pick(panel.canvas.screen(Vector3(180,0,50))).ok)
	var hit: Dictionary = panel.canvas.pick(panel.canvas.screen(Vector3(150,0,50)))
	check("click_resolves_canonical_support",hit.ok and hit.data.point.position.distance_to(Vector3(150,0,50)) < 0.001)
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = panel.canvas.screen(Vector3(150,0,50)); panel.canvas._gui_input(press)
	check("click_plans_real_actor",panel.canvas.motion.has_route())
	for i: int in 100:
		panel.canvas._process(0.05)
		if not panel.canvas.motion.has_route(): break
	check("native_actor_crosses_seam",panel.canvas.motion.point().position.distance_to(Vector3(150,0,50)) < 0.001)
	panel.toggle_test(); check("test_preserves_draft",not panel.canvas.testing and Document.hash_source(panel.session.data) == original)
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
	panel.select_id("right"); panel.toggle_test()
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
