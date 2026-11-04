@tool
extends EditorPlugin
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
var checks: Array[Dictionary] = []
var measurements := {}
func check(id: String, ok: bool) -> void: checks.append({"id":id,"ok":ok})
func _enter_tree() -> void: _run.call_deferred()
func _run() -> void:
	await get_tree().process_frame
	if not EditorInterface.is_plugin_enabled("ragrpg_map_editor"): EditorInterface.set_plugin_enabled("ragrpg_map_editor",true)
	await get_tree().process_frame
	EditorInterface.set_main_screen_editor("Mapas")
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == Shell: shell = node
	check("shell",shell != null)
	if shell == null: finish(); return
	var panel: Control = shell.terrain
	var fixture := TerrainPanel.large_sample_source(Document.empty("manual_field"),161)
	fixture.layers[0].surface_mode = "height_grid"
	fixture.layers[0].sample_spacing = 64.0
	var started := Time.get_ticks_usec()
	var replaced: Dictionary = shell.session.replace(fixture)
	measurements.initial_replace_usec = Time.get_ticks_usec()-started
	check("field_created",replaced.ok)
	if not replaced.ok: finish(); return
	for i: int in 3: await get_tree().process_frame
	panel.select_layer("field")
	var canvas: Control = panel.canvas
	canvas.fit(); canvas.set_process(false)
	panel.radius.value = 200.0; panel.strength.value = 6.0
	var at: Vector2 = canvas.screen(Vector3(2048,0,2048))
	var original: String = shell.session.document().semantic_hash()
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = at
	canvas._gui_input(press)
	await get_tree().process_frame
	started = Time.get_ticks_usec(); canvas._process(1.0/30.0)
	measurements.first_tick_usec = Time.get_ticks_usec()-started
	check("preview_without_commit",not canvas._preview.is_empty() and shell.session.document().semantic_hash() == original)
	var saved_count: int = canvas._saved_meshes.size()
	check("regional_mesh_update",saved_count > 0 and saved_count < canvas._terrain_meshes.size())
	var times: Array[int] = []
	for i: int in 10:
		canvas._preview_due_msec = 0
		await get_tree().process_frame
		started = Time.get_ticks_usec(); canvas._process(1.0/30.0); times.append(Time.get_ticks_usec()-started)
	measurements.tick_with_redraw_usec = times
	measurements.updated_meshes = saved_count; measurements.total_meshes = canvas._terrain_meshes.size()
	var sculpted: Dictionary = canvas.pick(at)
	check("pointer_picks_live_relief",sculpted.get("ok",false) and sculpted.position.y > 0.0)
	await get_tree().process_frame
	capture("manual_field_preview")
	canvas.mouse_exited.emit()
	check("leave_cancels",not canvas._dragging and shell.session.document().semantic_hash() == original and canvas._saved_meshes.is_empty())
	canvas._gui_input(press)
	await get_tree().process_frame
	canvas._process(1.0/30.0)
	var escape := InputEventKey.new(); escape.pressed = true; escape.keycode = KEY_ESCAPE
	canvas._gui_input(escape)
	check("escape_cancels",not canvas._dragging and shell.session.document().semantic_hash() == original)
	canvas._gui_input(press)
	await get_tree().process_frame
	canvas._process(1.0/30.0)
	canvas.get_window().focus_exited.emit()
	check("focus_cancels",not canvas._dragging and shell.session.document().semantic_hash() == original)
	canvas._gui_input(press)
	await get_tree().process_frame
	canvas._process(1.0/30.0)
	await get_tree().process_frame
	canvas._process(1.0/30.0)
	var sparse: Array = canvas._preview.layers[0].heights.duplicate()
	canvas.cancel_stroke()
	canvas._gui_input(press)
	await get_tree().process_frame
	canvas._process(1.0/30.0)
	for i: int in 20:
		var motion := InputEventMouseMotion.new(); motion.position = at; motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		canvas._gui_input(motion)
	await get_tree().process_frame
	canvas._process(1.0/30.0)
	check("event_frequency_independent",canvas._preview.layers[0].heights == sparse)
	canvas.cancel_stroke()
	canvas._gui_input(press)
	await get_tree().process_frame
	canvas._process(1.0/30.0)
	var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.position = at
	canvas._gui_input(release)
	await get_tree().process_frame
	started = Time.get_ticks_usec(); canvas._process(1.0/30.0)
	measurements.release_usec = Time.get_ticks_usec()-started
	var committed: String = shell.session.document().semantic_hash()
	check("release_commits",committed != original)
	check("one_undo",shell.session.undo() and shell.session.document().semantic_hash() == original and not shell.session.can_undo())
	check("one_redo",shell.session.redo() and shell.session.document().semantic_hash() == committed)
	await get_tree().process_frame
	capture("manual_field_committed")
	var small := TerrainPanel.sample_source(Document.empty("manual_small"))
	check("small_created",shell.session.replace(small).ok)
	panel.select_layer("lower"); canvas.fit()
	panel.radius.value = 80.0; panel.strength.value = 6.0
	var small_original: String = shell.session.document().semantic_hash()
	at = canvas.screen(Vector3(50,0,50)); press.position = at; release.position = at
	canvas._gui_input(press)
	await get_tree().process_frame
	started = Time.get_ticks_usec(); canvas._process(1.0/30.0)
	measurements.small_first_tick_usec = Time.get_ticks_usec()-started
	check("small_preview",not canvas._preview.is_empty() and shell.session.document().semantic_hash() == small_original)
	await get_tree().process_frame
	capture("manual_small_preview")
	canvas._gui_input(release)
	await get_tree().process_frame
	started = Time.get_ticks_usec(); canvas._process(1.0/30.0)
	measurements.small_release_usec = Time.get_ticks_usec()-started
	check("small_commit",shell.session.document().semantic_hash() != small_original)
	await get_tree().process_frame
	capture("manual_small_committed")
	check("small_undo",shell.session.undo() and shell.session.document().semantic_hash() == small_original and not shell.session.can_undo())
	finish()
func capture(name: String) -> void:
	var directory := OS.get_environment("F9_EVIDENCE")
	RenderingServer.force_draw(false)
	var picture := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	check("capture_"+name,not directory.is_empty() and not picture.is_empty() and picture.save_png(directory.path_join(name+".png")) == OK)
func finish() -> void:
	var ok := not checks.is_empty()
	for item: Dictionary in checks:
		if not item.ok: ok = false
	print("MANUAL_BRUSH_NATIVE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"measurements":measurements}))
	get_tree().quit(0 if ok else 1)
