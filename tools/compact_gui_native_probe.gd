extends "res://tools/skill_ux_iteration_native_probe.gd"
## Retains real drag/Escape checks and exercises actual tooltip popups at screen edges.
var hover_checks_done := false
func _capture(viewport: SubViewport, directory: String, file_name: String) -> void:
	await super._capture(viewport, directory, file_name)
	if file_name != "lobby_tree_1280" or hover_checks_done: return
	hover_checks_done = true
	viewport.gui_embed_subwindows = true
	viewport.notify_mouse_entered()
	var menu := viewport.get_child(0) as Control
	assert(menu.scale.is_equal_approx(Vector2.ONE * 0.85))
	var skill_window: SkillWindow = menu.skill_window
	var entry: Dictionary = skill_window.skill_entries[&"fireball"]
	var plus: Button = entry["plus"]
	var minus: Button = entry["minus"]
	assert(GuiMetrics.visual_rect(plus).size.x < 24.0 and not GuiMetrics.visual_rect(plus).intersects(GuiMetrics.visual_rect(minus)))
	await _click(viewport, GuiMetrics.visual_rect(plus).get_center())
	assert(skill_window.draft.sequence.size() == 1)
	minus = skill_window.skill_entries[&"fireball"]["minus"]
	await _click(viewport, GuiMetrics.visual_rect(minus).get_center())
	assert(skill_window.draft.sequence.is_empty())
	var root_control := Control.new()
	viewport.add_child(root_control)
	GuiMetrics.configure_root(root_control)
	var button := SkillWindow.SkillButton.new()
	button.size = Vector2(36,36)
	button.tooltip_text = skill_window.skill_entries[&"fireball"]["button"].tooltip_text
	root_control.add_child(button)
	for corner: Vector2 in [Vector2(8,8), Vector2(1230,8), Vector2(8,670), Vector2(1230,670)]:
		button.position = corner / GuiMetrics.SCALE
		var move := InputEventMouseMotion.new()
		move.position = GuiMetrics.visual_rect(button).get_center()
		move.global_position = move.position
		viewport.push_input(move, true)
		await create_timer(0.85).timeout
		var popups: Array[PopupPanel] = []
		_find_popups(root,popups)
		print("COMPACT_TOOLTIP_VISIBLE ", popups.size(), " at ", corner)
		assert(not popups.is_empty())
		for popup: PopupPanel in popups:
			assert(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(Rect2(Vector2(popup.position), Vector2(popup.size))))
		await super._capture(viewport,directory,"compact_hover_%d_%d" % [int(corner.x),int(corner.y)])
	root_control.free()
	print("COMPACT_GUI_NATIVE_OK actual_plus_minus=true hover_edges=4 scale=0.85")

func _click(viewport: SubViewport, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = true
	viewport.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)
	await process_frame

func _find_popups(node: Node, result: Array[PopupPanel]) -> void:
	for child: Node in node.get_children(true):
		if child is PopupPanel and child.visible: result.append(child)
		_find_popups(child,result)

func _cluster_windows(directory: String) -> void:
	await super._cluster_windows(directory)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960,540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var store_path := ProjectSettings.globalize_path(directory + "/compact_small_%d" % Time.get_ticks_usec())
	var facade := ProfileFacade.new(ProfileStore.new(store_path, ProfileCatalog.pilot()), ProfileRewardResolver.pilot_progression())
	assert(facade.create_character("compact-create",0,"Interface compacta",&"mage")["ok"])
	var menu := MenuScript.new()
	menu.set_profile_facade(facade)
	menu.set_profile_directory(store_path)
	viewport.add_child(menu)
	menu.menu_tabs.current_tab = 1
	for frame: int in 4: await process_frame
	assert(Rect2(Vector2.ZERO,Vector2(viewport.size)).encloses(GuiMetrics.visual_rect(menu.skill_window._body)))
	await super._capture(viewport,directory,"compact_960")
	viewport.size = Vector2i(1280,720)
	for frame: int in 4: await process_frame
	assert(GuiMetrics.visual_rect(menu).size.is_equal_approx(Vector2(viewport.size)))
	assert(Rect2(Vector2.ZERO,Vector2(viewport.size)).encloses(GuiMetrics.visual_rect(menu.skill_window._body)))
	await super._capture(viewport,directory,"compact_resized_1280")
	var inventory := RunInventoryPanel.new()
	menu.add_child(inventory)
	inventory.configure_profile(facade,facade.current_profile().characters[0].character_id)
	for frame: int in 3: await process_frame
	await super._capture(viewport,directory,"compact_inventory_1280")
	var header := inventory.equipment_window.find_child("DragHeader",true,false) as Control
	var before := GuiMetrics.visual_rect(inventory.equipment_window)
	await _native_drag(viewport,GuiMetrics.visual_rect(header).get_center(),GuiMetrics.visual_rect(header).get_center()+Vector2(80,30))
	var after := GuiMetrics.visual_rect(inventory.equipment_window)
	print("COMPACT_INVENTORY_DRAG before=",before.position," after=",after.position," delta=",after.position-before.position)
	assert(after.position.is_equal_approx(before.position+Vector2(80,30)))
	assert(Rect2(Vector2.ZERO,Vector2(viewport.size)).encloses(after))
	await _click(viewport,GuiMetrics.visual_rect(inventory.close_buttons[0]).get_center())
	assert(not inventory.visible)
	inventory.free()
	print("COMPACT_INVENTORY_INPUT_OK physical_drag=80,30 actual_close=true")
	menu.free()
	viewport.free()
	print("COMPACT_GUI_RESIZE_OK small=960x540 resized=1280x720")
