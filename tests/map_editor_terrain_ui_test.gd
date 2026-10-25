@tool
extends EditorPlugin
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Compiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
var checks: Array[Dictionary] = []
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok})
	print("M2_UI_CHECK "+id+" "+str(ok))
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
	var panel: Control = shell.terrain
	var oversized: Dictionary = shell.session.document().to_data()
	oversized.layers = [{"rows":258,"columns":258}]
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
	panel.connector_id.text = "west_test"; panel.connector_surface.select(0)
	panel.connector_x.value = 0; panel.connector_y.value = 0; panel.connector_z.value = 50
	panel.connector_width.value = 32; panel.connector_side.select(0); panel.connector_direction.select(0)
	panel.save_connector()
	check("connector_add_and_compile",shell.session.document().to_data().connectors.size() == 1 and Compiler.compile(shell.session.document().to_data()).ok)
	panel.connector_direction.select(2); panel.connector_width.value = 24; panel.save_connector()
	check("connector_update_same_identity",shell.session.document().to_data().connectors.size() == 1 and shell.session.document().to_data().connectors[0].direction == "out" and shell.session.document().to_data().connectors[0].width == 24)
	shell.session.undo()
	check("connector_update_undo",shell.session.document().to_data().connectors[0].width == 32)
	shell.session.redo(); panel._select_connector(0)
	check("connector_form_reselection",panel.connector_direction.selected == 2 and panel.connector_width.value == 24)
	shell.layers.select(0); shell.toggle_layer_lock()
	var connector_locked: String = shell.session.document().semantic_hash()
	panel.connector_width.value = 40; panel.save_connector(); panel.remove_connector()
	check("locked_connector_update_remove_rejected",shell.session.document().semantic_hash() == connector_locked)
	shell.session.undo(); panel.remove_connector()
	check("connector_remove",shell.session.document().to_data().connectors.is_empty())
	shell.session.undo()
	check("connector_remove_undo",shell.session.document().to_data().connectors.size() == 1)
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
		RenderingServer.force_draw(false)
		var image := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		check("native_capture",image.save_png(OS.get_environment("M2_CAPTURE")) == OK)
	shell.session.replace(Document.empty("native_large_piece")); panel.create_large_sample()
	for _i: int in 3: await get_tree().process_frame
	canvas.fit()
	check("native_large_piece_not_subdivided_into_pieces",shell.session.document().to_data().layers.size() == 1 and shell.session.document().to_data().layers[0].heights.size() == 4225)
	check("native_textured_meshes",canvas._mesh_root.get_child_count() == 3 and canvas._mesh_root.get_child(0) is MeshInstance2D and canvas._mesh_root.get_child(0).material is ShaderMaterial)
	var grass_texture: Texture2D = canvas._mesh_root.get_child(0).material.get_shader_parameter("grass_tile")
	check("native_mipmaps_for_zoomed_out_terrain",grass_texture.get_image().has_mipmaps())
	var large_pick: Dictionary = canvas.pick(canvas.screen(Vector3(7000,128,3500)))
	check("native_large_pick_on_plateau",large_pick.ok and large_pick.position.distance_to(Vector3(7000,128,3500)) < 0.1)
	check("native_stroke_overlay_tracks_height",canvas._stroke_screen(Vector2(7000,3500)).distance_to(canvas.screen(Vector3(7000,128,3500))) < 0.01)
	var large_before: String = shell.session.document().semantic_hash()
	panel.radius.value = 200; panel.strength.value = 8
	var large_edit: Dictionary = panel.apply_stroke([Vector2(2560,2560)],canvas.options)
	check("native_large_brush",large_edit.ok and shell.session.document().to_data().layers[0].heights[20*65+20] == 8)
	check("native_large_atomic_undo",shell.session.undo() and shell.session.document().semantic_hash() == large_before)
	var large_path: String = shell.recovery_root.path_join("f2_large_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json")
	check("native_large_save_reopen",shell.save_path(large_path).ok and shell.open_path(large_path).ok and shell.session.document().semantic_hash() == large_before)
	panel.bake()
	for _i: int in 1200:
		await get_tree().process_frame
		if panel.job == null: break
	check("native_large_bake",panel.job == null and panel.result.get("ok",false) and panel.result.package.part.surfaces.size() == 3)
	canvas.fit()
	if DisplayServer.get_name() != "headless":
		for _i: int in 3: await get_tree().process_frame
		RenderingServer.force_draw(false)
		var large_image := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		check("native_large_capture",large_image.save_png(OS.get_environment("M2_CAPTURE").get_base_dir().path_join("large_terrain.png")) == OK)
		var detail_center := Vector3(3500,53.5,3500)
		canvas._scale *= 18.0; canvas._origin = canvas.size*0.5-Vector2((detail_center.x-detail_center.z),(detail_center.x+detail_center.z)*0.5-detail_center.y)*canvas._scale; canvas._pan = Vector2.ZERO
		canvas.queue_redraw()
		for _i: int in 3: await get_tree().process_frame
		RenderingServer.force_draw(false)
		var detail_image := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		check("native_terrain_detail_capture",detail_image.save_png(OS.get_environment("M2_CAPTURE").get_base_dir().path_join("terrain_detail.png")) == OK)
	var steep: Dictionary = TerrainPanel.sample_source(Document.empty("native_steep"))
	steep.layers[0].heights.fill(100); steep.layers[1].heights = [100,0,100,0]; steep.layers[2].heights.fill(0)
	steep.special_surfaces.clear()
	shell.session.replace(steep); panel.select_layer("ramp"); panel.bake()
	for _i: int in 600:
		await get_tree().process_frame
		if panel.job == null: break
	check("native_steep_valid_support",panel.job == null and panel.result.get("ok",false))
	canvas.fit()
	if DisplayServer.get_name() != "headless":
		for _i: int in 3: await get_tree().process_frame
		RenderingServer.force_draw(false)
		var steep_image := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		check("native_steep_capture",steep_image.save_png(OS.get_environment("M2_CAPTURE").get_base_dir().path_join("steep_terrain.png")) == OK)
	var weak: WeakRef = weakref(shell)
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
