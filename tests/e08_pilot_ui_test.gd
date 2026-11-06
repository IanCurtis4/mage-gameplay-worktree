extends SceneTree
## Real published forest UI, disposable profile; also runs under the native
## renderer with --capture-dir=<absolute path> to preserve filled screenshots.
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
var checks := 0
var failures := 0
var capture_dir := ""
var records: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func settle() -> void:
	for index: int in 5: await process_frame
func rect(control: Control) -> Rect2: return GuiMetrics.visual_rect(control)
func inside(control: Control, bounds: Rect2) -> bool:
	return bounds.grow(0.5).encloses(rect(control)) and control.size.x > 0 and control.size.y > 0
func scroll_of(node: Node) -> ScrollContainer:
	for child: Node in node.get_children():
		if child is ScrollContainer: return child
		var found := scroll_of(child)
		if found != null: return found
	return null
func buttons_of(node: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button: buttons.append(child)
		buttons.append_array(buttons_of(child))
	return buttons
func mouse_button(position: Vector2, index: MouseButton) -> void:
	var event := InputEventMouseButton.new(); event.position = position; event.global_position = position
	event.button_index = index; event.pressed = true; root.push_input(event,true)
	event = event.duplicate(); event.pressed = false; root.push_input(event,true)
	await settle()
func shot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name+".png")) == OK, "native filled capture "+name)
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1280,720)
	var fixture := F.make("e08_p1_pilot_ui")
	var menu := CharacterMenu.new(); menu.set_profile_facade(fixture.facade); root.add_child(menu); current_scene = menu
	var choice := PhaseSelectionPanel.new(); menu.add_child(choice); choice.configure(menu,fixture.a)
	choice.seed_input.text = "42"
	var selected := -1
	for index: int in choice.phase_choice.item_count:
		if choice.phase_choice.get_item_text(index) == "Floresta do Santuário": selected = index
	check(selected >= 0, "published forest available")
	if selected < 0: quit(1); return
	choice.phase_choice.select(selected); choice.phase_choice.item_selected.emit(selected)
	var entered: Dictionary = await choice.start()
	check(entered.get("ok",false), "real forest entered with isolated profile: "+str(entered.get("error_code","")))
	if not entered.get("ok",false): quit(1); return
	var host := entered.root as RunController
	host.set_process(false); paused = true
	host.control_preferences.ui_scale = 1.2; host._apply_interface_preferences()
	host.route_camera.zoom = Vector2.ONE
	host.route_camera.position_smoothing_enabled = false
	host._update_hud()
	var panel := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
	panel.refresh()
	var scroll := panel.get_node("ContentScroll") as ScrollContainer
	var initial_connections := host.ui_root.resized.get_connections().size()
	for size_index: int in 3:
		var viewport_size: Vector2i = [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1280,720)][size_index]
		root.size = viewport_size
		host._apply_interface_preferences(); host._update_hud(); panel.refresh()
		await settle(); host._layout_stage_minimap(); panel.fit_available_space(); await settle()
		var bounds := host.ui_root.get_viewport_rect()
		check(host.ui_root.scale == Vector2.ONE*1.2 and host.control_preferences.ui_scale == 1.2, "effective UI preference/root remains 120% "+str(viewport_size))
		check(not host.health_label.text.is_empty() and not host.sp_label.text.is_empty() and not panel.summary.text.is_empty(), "filled HUD and real campaign summary "+str(viewport_size))
		check(inside(panel,bounds) and inside(host.hud_panel,bounds) and inside(host.bottom_controls,bounds) and inside(host.battle_controls.skill_bar,bounds), "all major rectangles inside viewport "+str(viewport_size))
		check(not rect(panel).intersects(rect(host.hud_panel)) and not rect(panel).intersects(rect(host.bottom_controls)) and not rect(panel).intersects(rect(host.battle_controls.skill_bar)), "stage panel clears filled HUD/footer/action bar "+str(viewport_size))
		check(panel.get_index() < host.battle_controls.get_index(), "campaign panel stays below modal/input shield")
		check(host.hud_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and host.help_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and panel.mouse_filter == Control.MOUSE_FILTER_STOP and scroll.mouse_filter == Control.MOUSE_FILTER_STOP, "information click-through and interactive capture preserved")
		check(host.battle_controls.slot_buttons.size() == 24 and buttons_of(host.bottom_controls).filter(func(button: Button)->bool:return button.visible).size() >= 3, "full action bar and footer controls retained")
		scroll.scroll_vertical = 0; await settle()
		var old_zoom := host.control_preferences.camera_zoom
		await mouse_button(rect(scroll).get_center(),MOUSE_BUTTON_WHEEL_DOWN)
		check(scroll.scroll_vertical > 0 and host.control_preferences.camera_zoom == old_zoom, "mouse wheel scrolls campaign content without zooming world")
		scroll.scroll_vertical = 0; await settle()
		if size_index < 2: await shot("forest_%d_top_120" % viewport_size.x)
		var action_buttons := buttons_of(panel.actions)
		check(action_buttons.size() >= 3 and scroll.get_v_scroll_bar().max_value > scroll.size.y, "real portal/objective/suspend content overflows through scrolling")
		for button: Button in action_buttons:
			if button.disabled: scroll.ensure_control_visible(button)
			else: button.grab_focus()
			await settle()
			check(rect(scroll).grow(0.5).encloses(rect(button)), "every campaign action reachable via scrolling/focus: "+button.text+button.accessibility_name)
		if size_index < 2: await shot("forest_%d_actions_120" % viewport_size.x)
		# Open through the actual settings button, then close with the actual
		# Cancel key. This exercises existing routing and pause semantics.
		paused = false
		await mouse_button(rect(host.battle_controls.settings_button).get_center(),MOUSE_BUTTON_LEFT)
		check(paused and host.battle_controls.settings_overlay.visible and inside(host.battle_controls.settings_panel,bounds), "settings opens paused and bounded "+str(viewport_size))
		var modal_scroll := scroll_of(host.battle_controls.settings_panel)
		check(modal_scroll != null and modal_scroll.follow_focus, "settings keeps focus-following scroll")
		var close_button: Button
		for button: Button in buttons_of(host.battle_controls.settings_panel):
			if button.text.begins_with("Voltar"): close_button = button
		check(close_button != null, "settings close control retained")
		if close_button != null:
			close_button.grab_focus(); await settle()
			check(rect(modal_scroll).grow(0.5).encloses(rect(close_button)), "settings final control reachable by focus")
		if size_index < 2: await shot("forest_%d_settings_120" % viewport_size.x)
		var cancel := InputEventKey.new(); cancel.keycode = KEY_ESCAPE; cancel.physical_keycode = KEY_ESCAPE; cancel.pressed = true
		root.push_input(cancel,true); await settle()
		check(not host.battle_controls.settings_overlay.visible and not paused, "Escape closes modal and resumes "+str(viewport_size))
		paused = true
		records.append({"viewport":str(viewport_size),"ui_scale":host.ui_root.scale.x,"logical_viewport":str(bounds),"panel":str(rect(panel)),"footer":str(rect(host.bottom_controls)),"bar":str(rect(host.battle_controls.skill_bar)),"hud":host.health_label.text+" / "+host.sp_label.text,"stage":panel.summary.text,"scroll_max":scroll.get_v_scroll_bar().max_value,"scroll_page":scroll.get_v_scroll_bar().page,"action_count":action_buttons.size(),"root_resize_handlers":host.ui_root.resized.get_connections().size()})
	check(host.ui_root.resized.get_connections().size() == initial_connections, "resize/reopen cycle does not accumulate handlers")
	# Rebuild the disposable panel as install/restore does; subscriptions must
	# return to exactly the same count after the old instance exits.
	panel.free(); await settle()
	var replacement := ExpeditionStatusPanel.new(); replacement.host = host; host.ui_root.add_child(replacement)
	replacement.refresh(); await settle()
	check(host.ui_root.resized.get_connections().size() == initial_connections and not rect(replacement).intersects(rect(host.bottom_controls)), "rebuilt presentation panel binds once and fits after resume")
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("native_ui.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info(),"phase":"forest_sanctuary","seed":42,"records":records},"  ",true)); file.close()
	paused = false; host.queue_free(); await settle()
	print("E08 pilot UI %s: %d checks, failures=%d" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
