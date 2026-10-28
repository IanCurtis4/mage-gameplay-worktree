extends "res://tests/map_editor_ax_content_test.gd"
## Same semantic suite plus real form interaction and native object view.
var capturing := false

func expected_count() -> int: return 30
func marker() -> String: return "F9_AX_CONTENT_UI_RESULT"

func finish() -> void:
	if capturing: return
	capturing = true
	if checks.size() != 28 or not checks.all(func(item: Dictionary) -> bool: return item.ok):
		super.finish(); return
	reset_pair(flat_source())
	gui_panel.selected_definition = "oak_tree"
	gui_panel.x.value = 200; gui_panel.z.value = 200; gui_panel.snap.value = 0
	for index: int in gui_panel.surfaces.item_count:
		if gui_panel.surfaces.get_item_metadata(index) == "floor": gui_panel.surfaces.select(index)
	var gui_result: Dictionary = gui_panel.place_at_fields()
	var ax_result: Dictionary = invoke("objects/place",{"definition_id":"oak_tree","surface_id":"floor","position_xz":[200,200],"snap":0})
	check("native_place_form_matches_parameterized_ax_identity",gui_result.ok and ax_result.ok and same_sources() and gui_result.added_ids == ax_result.added_ids)
	gui_shell.objects_window.hide(); gui_shell.hide()
	ax_shell.objects_window.position = Vector2i.ZERO
	ax_shell.objects_window.size = root.size
	ax_panel.canvas.custom_minimum_size.y = 440
	await frames(3)
	ax_panel.canvas.fit()
	await frames(3)
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var directory := OS.get_environment("F9_EVIDENCE")
	var written: bool = not directory.is_empty() and picture.save_png(directory.path_join("ax_content_objects.png")) == OK
	var details := {"written":written,"image_size":str(picture.get_size()),"window_size":str(DisplayServer.window_get_size()),"canvas_size":str(ax_panel.canvas.size),"visible":ax_panel.canvas.is_visible_in_tree(),"mesh_count":ax_panel.canvas._mesh_root.get_child_count()}
	check("native_objects_window_renders_real_prop_and_terrain",written and picture.get_width() >= 1280 and picture.get_height() >= 850 and ax_panel.canvas.is_visible_in_tree() and ax_panel.canvas._mesh_root.get_child_count() >= 2,details)
	super.finish()
