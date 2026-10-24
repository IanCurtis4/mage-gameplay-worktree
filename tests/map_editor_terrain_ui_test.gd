@tool
extends EditorPlugin
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Compiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
var checks: Array[Dictionary] = []
func check(id: String, ok: bool) -> void: checks.append({"id":id,"ok":ok})
func _enter_tree() -> void: _run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	EditorInterface.set_plugin_enabled("ragrpg_map_editor",true)
	await get_tree().process_frame
	EditorInterface.set_main_screen_editor("Mapas")
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == Shell: shell = node
	check("native_shell_visible",shell != null and shell.visible)
	if shell == null: finish(); return
	var panel: Control = shell.terrain
	var oversized: Dictionary = shell.session.document().to_data()
	oversized.layers = [{"rows":257,"columns":257}]
	check("oversized_preview_preflight",not panel.canvas.preview_supported(oversized) and panel.canvas._triangles(oversized).is_empty())
	panel.create_sample()
	for _i: int in 5: await get_tree().process_frame
	panel.canvas.fit()
	check("sample_three_layers",shell.session.document().to_data().layers.size() == 3)
	check("sample_bridge",shell.session.document().to_data().special_surfaces.size() == 1)
	panel.bake()
	for _i: int in 600:
		await get_tree().process_frame
		if panel.job == null: break
	check("native_bake_completed",panel.job == null and panel.result.get("ok",false))
	if panel.result.get("ok",false):
		check("native_headless_equivalent",panel.result.output_hash == Compiler.compile(shell.session.document().to_data()).output_hash)
		check("native_compiled_boundaries",not panel.canvas.package.boundaries.is_empty())
	var before: String = shell.session.document().semantic_hash()
	panel.create_sample()
	check("example_preserves_nonempty_piece",shell.session.document().semantic_hash() == before)
	panel.select_layer("lower")
	var canvas: Control = panel.canvas
	var at: Vector2 = canvas.screen(Vector3(50,0,50))
	var picked: Dictionary = canvas.pick(at)
	check("isometric_pick_matches_support",picked.ok and picked.point.distance_to(Vector2(50,50)) < 0.001)
	panel.radius.value = 80.0; panel.strength.value = 4.0
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = at
	canvas._gui_input(press)
	check("stroke_preview_without_source_mutation",canvas._dragging and not canvas._preview.is_empty() and shell.session.document().semantic_hash() == before)
	canvas.cancel_stroke()
	check("cancel_preserves_source",shell.session.document().semantic_hash() == before and not canvas._dragging)
	canvas._gui_input(press)
	var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.position = at
	canvas._gui_input(release)
	check("release_applies_one_action",shell.session.document().semantic_hash() != before)
	shell.session.undo()
	check("one_undo_restores_whole_stroke",shell.session.document().semantic_hash() == before)
	shell.session.redo(); shell.session.undo()
	panel.select_layer("lower")
	canvas._gui_input(press)
	canvas.mouse_exited.emit()
	check("leave_canvas_discards_stroke",not canvas._dragging and shell.session.document().semantic_hash() == before)
	shell.layers.select(0); shell.toggle_layer_lock()
	var locked_hash: String = shell.session.document().semantic_hash()
	var rejected: Dictionary = panel.apply_stroke([Vector2(50,50)],canvas.options)
	check("locked_layer_rejected_in_ui",not rejected.ok and shell.session.document().semantic_hash() == locked_hash)
	shell.session.undo()
	panel.select_layer("plateau")
	check("explicit_layer_selection",canvas.selected_layer == "plateau")
	check("selection_tree_matches_target",shell.layers.get_selected_items() == PackedInt32Array([2]))
	panel.hide_layer.button_pressed = true
	check("hide_layer_explicit", "plateau" in canvas.hidden_layers)
	panel.hide_layer.button_pressed = false
	var path: String = shell.recovery_root.path_join("f2_native_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json")
	check("native_save",shell.save_path(path).ok)
	var expected: String = Compiler.compile(shell.session.document().to_data()).output_hash
	check("native_reopen",shell.open_path(path).ok and Compiler.compile(shell.session.document().to_data()).output_hash == expected)
	panel.bake(); panel.job.cancel()
	for _i: int in 600:
		await get_tree().process_frame
		if panel.job == null: break
	check("native_cancel_discarded",panel.job == null and panel.result.get("code") == "cancelled")
	panel.bake()
	shell.rename_document("Fonte alterada durante compilação")
	for _i: int in 600:
		await get_tree().process_frame
		if panel.job == null: break
	check("native_stale_result_discarded",panel.job == null and panel.result.get("code") == "stale_source" and canvas.package.is_empty())
	shell.session.undo()
	panel.select_layer("lower"); panel.bake()
	for _i: int in 600:
		await get_tree().process_frame
		if panel.job == null: break
	canvas.fit()
	check("native_final_bake",panel.result.get("ok",false))
	if DisplayServer.get_name() != "headless":
		for _i: int in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		check("native_capture",image.save_png(OS.get_environment("M2_CAPTURE")) == OK)
	var weak := weakref(shell)
	EditorInterface.set_plugin_enabled("ragrpg_map_editor",false)
	await get_tree().process_frame
	check("native_unload_frees_shell",weak.get_ref() == null)
	finish()

func finish() -> void:
	var ok := not checks.is_empty()
	for entry: Dictionary in checks:
		if not entry.ok: ok = false
	print("M2_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	get_tree().quit(0 if ok else 1)
