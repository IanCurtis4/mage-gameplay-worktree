@tool
extends EditorPlugin
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
var checks: Array[Dictionary] = []
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
	var window := EditorInterface.get_base_control().get_window()
	window.size = Vector2i(1440,1000)
	for i: int in 5: await get_tree().process_frame
	var sample := TerrainPanel.sample_source(Document.empty("q5_usability"))
	check("sample_created",shell.session.replace(sample).ok)
	shell.terrain.select_layer("lower")
	var canvas: Control = shell.terrain.canvas
	canvas.fit()
	var presentation: Control = shell.get_node("AuthoringPresentation")
	var previous_mode: String = Presentation.active_mode
	presentation.set_mode("ux")
	for i: int in 5: await get_tree().process_frame
	var visible_rect := clipped_canvas(canvas,window)
	check("ux_visible_canvas_300px",visible_rect.size.y >= 300.0 and visible_rect.size.x > 0.0)
	var source_hash: String = shell.session.document().semantic_hash()
	check("next_step_visible",shell.workflow_bar.next_button.is_visible_in_tree())
	shell.workflow_bar.steps_toggle.button_pressed = true
	shell.metadata_toggle.button_pressed = true
	await get_tree().process_frame
	check("folds_open",shell.workflow_bar.steps_row.is_visible_in_tree() and shell.metadata_panel.is_visible_in_tree())
	check("folds_preserve_source",shell.session.document().semantic_hash() == source_hash)
	shell.workflow_bar.steps_toggle.button_pressed = false
	shell.metadata_toggle.button_pressed = false
	presentation.set_mode("ax")
	for i: int in 5: await get_tree().process_frame
	var ax_rect := clipped_canvas(canvas,window)
	check("ax_visible_canvas_300px",ax_rect.size.y >= 300.0 and ax_rect.size.x > 0.0)
	check("ax_preserves_source",shell.session.document().semantic_hash() == source_hash)
	presentation.set_mode("ux")
	for i: int in 5: await get_tree().process_frame
	check("ux_preserves_source",shell.session.document().semantic_hash() == source_hash)
	check("controls_reachable",shell.workflow_bar.steps_toggle.focus_mode != Control.FOCUS_NONE and shell.workflow_bar.next_button.focus_mode != Control.FOCUS_NONE and shell.metadata_toggle.focus_mode != Control.FOCUS_NONE)
	shell.workflow_bar.steps_toggle.grab_focus()
	check("keyboard_focus",shell.workflow_bar.steps_toggle.has_focus())
	var evidence := OS.get_environment("F9_EVIDENCE")
	RenderingServer.force_draw(false)
	var picture := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	check("capture",not evidence.is_empty() and not picture.is_empty() and picture.save_png(evidence.path_join("q5_editor_usability.png")) == OK)
	presentation.set_mode(previous_mode)
	print("Q5_USABILITY_VISIBLE "+JSON.stringify({"ux_height":visible_rect.size.y,"ux_width":visible_rect.size.x,"ax_height":ax_rect.size.y,"ax_width":ax_rect.size.x,"window":str(window.size)}))
	finish()
func clipped_canvas(canvas: Control, window: Window) -> Rect2:
	var result := canvas.get_global_rect()
	var parent := canvas.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents: result = result.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	result = result.intersection(Rect2(Vector2.ZERO,Vector2(window.size)))
	var overlay := canvas.get_node_or_null("AgentActionsOverlay") as Control
	if overlay != null and overlay.is_visible_in_tree():
		var covered := result.intersection(overlay.get_global_rect())
		if covered.size.x >= result.size.x - 1.0 and covered.size.y > 0.0 and covered.position.y <= result.position.y + 1.0:
			var bottom := result.end.y
			result.position.y = covered.end.y
			result.size.y = maxf(0.0,bottom - covered.end.y)
	return result

func finish() -> void:
	var ok := not checks.is_empty()
	for item: Dictionary in checks:
		if not item.ok: ok = false
	print("Q5_USABILITY_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	get_tree().quit(0 if ok else 1)
