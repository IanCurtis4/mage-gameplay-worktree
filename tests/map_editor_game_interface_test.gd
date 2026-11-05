extends SceneTree
## F10 Q3 (contracts/f10_insertions.md): the seven interface problems of the
## gameplay synthesis, driven through real events on a real expedition. The same
## checks reproduce each problem on the code before the fix and prove the fix.
const App = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Fixture = preload("res://tests/map_editor_population_test.gd")
var app: App
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"id":id,"ok":ok,"detail":str(detail)}); print("F10_INTERFACE_CHECK "+id+" "+str(ok)+" "+str(detail))
func frames(count: int = 3) -> void:
	for _index: int in count: await process_frame
func point_at(position: Vector2) -> void:
	var move := InputEventMouseMotion.new(); move.position = position; move.global_position = position
	root.push_input(move,true); await frames(1)
func click(position: Vector2) -> void:
	await point_at(position)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = position; event.global_position = position
		root.push_input(event,true); await frames(1)
func wheel(position: Vector2, button: MouseButton) -> void:
	await point_at(position)
	# A wheel press without its release leaves GUI mouse capture on the map.
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button; event.pressed = pressed; event.position = position; event.global_position = position
		root.push_input(event, true)
		await frames(1)
func visual(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)
func run() -> void:
	root.size = Vector2i(1280,720)
	var source := Fixture.fixture(); source.brushes = []; source.slots = []; source.exclusions = []
	source.plan_hash = Population.Document.recipe_hash(source)
	var built := Population.compile(source)
	if not built.ok: print(built); finish(); return
	var candidate := Candidate.create("population",built.package,built.package.source_hash)
	var created := Launcher.create_session(candidate.candidate,"mage")
	var seed := ProfileFacade.new(ProfileStore.new(String(created.directory).path_join("profile"),ProfileCatalog.pilot()))
	var made := seed.create_character("interface_character",0,"Teste de interface",&"mage")
	var profile := seed.current_profile()
	var robe := seed.grant_playtest_admin("interface_robe",profile.revision,profile.selected_character_id,&"equipment",&"channeler_robe",{})
	profile = seed.current_profile()
	var skills := seed.grant_playtest_admin("interface_skills",profile.revision,profile.selected_character_id,&"unlock_skills",&"",{})
	check("fixture_character_has_a_robe_and_skills",made.ok and robe.ok and skills.ok,[made.get("error_code",""),robe.get("error_code",""),skills.get("error_code","")])
	var window := Launcher.create_window(created.path)
	app = App.new(); app.quit_on_close = false; root.add_child(app); current_scene = app
	var opened := app.open_window(window.path); var started := app.start() if opened.ok else opened
	if not started.ok: print(started); finish(); return
	var host := app.host
	await frames(6)
	# 1. A click on the expedition status panel does not move the character.
	# Control: a walkable point near the player that a click moves to with the
	# panel hidden; then the panel is placed over it and the same click repeated.
	var status := host.ui_root.get_node_or_null("ExpeditionStatus") as Control
	var target := Vector2.INF
	var geometry: WorldGeometry = host.player.world_motion.geometry
	var origin: ExpeditionWorldPoint = host.player.world_point()
	for offset: Vector2 in [Vector2(90,40),Vector2(-90,40),Vector2(60,-80),Vector2(-60,-80),Vector2(140,0)]:
		var support := geometry.support_at(origin.surface_id,Vector2(origin.position.x,origin.position.z)+offset,geometry.geometry_revision)
		if not support.ok or status == null: continue
		var at: Vector2 = host.get_canvas_transform()*ExpeditionGeometryView.project(support.data.point.position)
		status.visible = false; status.set_process(false)
		var start := host.player.world_point().position
		await click(at); await frames(10)
		var moved := host.player.world_motion.has_route() or host.player.world_point().position.distance_to(start) > 0.5
		host.player.world_motion.cancel(); await frames(2)
		status.visible = true; status.set_process(true); await frames(2)
		if moved: target = at; break
	if target.is_finite():
		# Put the panel's summary text right under the pointer.
		var local := status.get_parent_control().get_global_transform_with_canvas().affine_inverse()*target
		status.position = local-Vector2(60,20); await frames(3)
	var before := host.player.world_point().position
	if target.is_finite():
		await click(target); await frames(10)
	check("status_panel_click_does_not_move",target.is_finite() and visual(status).has_point(target) and not host.player.world_motion.has_route() and host.player.world_point().position.distance_to(before) < 0.5,[target,host.player.world_point().position.distance_to(before)])
	host.player.world_motion.cancel()
	# 2. The inventory windows and their confirmation stay above the action bar.
	host._open_inventory(); await frames(4)
	var inventory: RunInventoryPanel = host.inventory_panel
	var bar := visual(host.bottom_controls)
	var overlap := visual(inventory.equipment_window).intersects(bar) or visual(inventory.bag_window).intersects(bar) or visual(inventory.confirm_button).intersects(bar)
	check("inventory_clears_the_action_bar",inventory.visible and not overlap,[visual(inventory.confirm_button),bar,inventory.bottom_reserved if "bottom_reserved" in inventory else -1.0,inventory.equipment_window.get_combined_minimum_size(),inventory.equipment_window.size,inventory.bag_window.get_combined_minimum_size(),inventory.equipment_window.get_child(0).get_children().map(func(c: Node) -> String: return c.get_class()+":"+str((c as Control).get_combined_minimum_size().y))])
	# 3. The bag filter is explicit and can show every piece.
	var filter := inventory.find_child("BagFilter",true,false) as OptionButton
	var hidden_robe := true
	for index: int in inventory.equipment_list.item_count:
		if "Manto" in inventory.equipment_list.get_item_text(index) or "manto" in inventory.equipment_list.get_item_text(index): hidden_robe = false
	var robe_index := -1
	if filter != null:
		filter.select(1); filter.item_selected.emit(1); await frames(2)
		for index: int in inventory.equipment_list.item_count:
			if not inventory.equipment_list.is_item_disabled(index) and inventory.equipment_list.get_item_metadata(index) == StringName(robe.get("equipment_instance_id","")): robe_index = index
	check("bag_filter_is_explicit",filter != null and robe_index >= 0,[filter != null,hidden_robe,robe_index])
	# 4. A double click equips the piece.
	if robe_index < 0:
		for index: int in inventory.equipment_list.item_count:
			if inventory.equipment_list.get_item_metadata(index) == StringName(robe.get("equipment_instance_id","")): robe_index = index
	if robe_index >= 0:
		inventory.equipment_list.select(robe_index)
		inventory.equipment_list.item_activated.emit(robe_index); await frames(4)
	var equipped := false
	var after := host.persistent_facade.current_profile().character_by_id(host.run_state.character_id) if host.persistent_facade != null else null
	if after != null:
		for value: Variant in after.equipped.values():
			if value != null and String(value) == String(robe.get("equipment_instance_id","-")): equipped = true
	check("double_click_equips",equipped,robe_index)
	inventory.dismiss(); host._close_inventory(); await frames(2)
	# 5. A clicked skill description stays while the pointer moves over others.
	host._open_skill_window(); await frames(4)
	var skills_window: SkillWindow = host.skill_window
	var ids: Array = skills_window.skill_entries.keys()
	var pinned := false
	if ids.size() >= 2:
		var first: Button = skills_window.skill_entries[ids[0]]["button"]
		var second: Button = skills_window.skill_entries[ids[1]]["button"]
		first.pressed.emit(); await frames(1)
		second.mouse_entered.emit(); await frames(1)
		pinned = skills_window._selected == ids[0]
	check("clicked_skill_description_is_pinned",pinned,ids.slice(0,2))
	skills_window.dismiss(); await frames(2)
	# 6-7. Settings offer an interface scale and an optional cursor capture.
	var controls: Control = host.battle_controls
	var scale_found := false; var cursor_found := false
	for node: Node in controls.find_children("*","",true,false):
		if node is Label and node.text == "Escala da interface": scale_found = true
		if node is CheckBox and node.text == "Manter o cursor dentro da janela": cursor_found = true
	check("interface_scale_is_offered",scale_found)
	check("cursor_capture_is_offered",cursor_found)
	if scale_found and host.has_method("change_interface_preferences"):
		host.call("change_interface_preferences",1.1,false); await frames(2)
		check("interface_scale_applies_and_persists",is_equal_approx(host.ui_root.scale.x,1.1) and host.control_preferences.ui_scale == 1.1)
		host.call("change_interface_preferences",GuiMetrics.SCALE,false)
	else: check("interface_scale_applies_and_persists",false)
	await check_minimap(host)
	var suspended: Dictionary = await app.suspend()
	check("minimap_does_not_prevent_checkpoint", suspended.get("ok", false), suspended.get("error_code", suspended.get("code", "")))
	await frames(3)
	var resumed := app.resume()
	check("minimap_checkpoint_resumes", resumed.get("ok", false), resumed.get("error_code", resumed.get("code", "")))
	await frames(4)
	var restored: RunController = app.host
	check("minimap_rebuilt_after_resume", is_instance_valid(restored) and is_instance_valid(restored.stage_minimap) and restored.stage_minimap._markers.has_player)
	check("camera_zoom_survives_resume", is_instance_valid(restored) and restored.route_camera.zoom.is_equal_approx(Vector2.ONE * 0.7))
	if is_instance_valid(restored): await app.suspend()
	finish()

func check_minimap(host: RunController) -> void:
	var minimap := host.stage_minimap
	# The preview normally hides this control; ordinary gameplay displays it.
	host.class_button.show()
	host._layout_stage_minimap()
	host.player.world_motion.cancel()
	host._update_stage_minimap(0.1)
	await frames(3)
	var square := visual(minimap._background)
	check("minimap_is_visible_square", minimap.visible and is_equal_approx(square.size.x, square.size.y) and square.size.x > 100.0, square)
	check("minimap_clears_class_button", not visual(minimap).intersects(visual(host.class_button)), [visual(minimap), visual(host.class_button)])
	var inside := true
	for polygon: PackedVector2Array in minimap._background.surfaces:
		for point: Vector2 in polygon:
			var mapped := StageMinimap.map_point(minimap._background.bounds, point, minimap._background.size)
			inside = inside and mapped.x >= 9.9 and mapped.y >= 9.9 and mapped.x <= minimap._background.size.x - 9.9 and mapped.y <= minimap._background.size.y - 9.9
	check("minimap_fits_entire_map", inside and not minimap._background.surfaces.is_empty())
	check("minimap_player_matches_world_projection", minimap._markers.player.is_equal_approx(ExpeditionGeometryView.project(host.player.world_point().position)))
	host.player.character_animation.state.face(Vector2.UP)
	host._update_stage_minimap(0.1)
	check("minimap_tracks_player_heading", minimap._markers.heading.is_equal_approx(Vector2.UP))
	var initial_origin := host.player.world_point().position
	await click(square.get_center())
	check("minimap_click_does_not_move", not host.player.world_motion.has_route() and host.player.world_point().position.distance_to(initial_origin) < 0.1)
	host.reset_camera_zoom()
	var hud_scale := host.ui_root.scale
	var map_bounds := minimap._background.bounds
	var status := host.ui_root.get_node("ExpeditionStatus") as Control
	status.hide(); status.set_process(false)
	var world_pointer := Vector2(640, 330)
	await wheel(world_pointer, MOUSE_BUTTON_WHEEL_UP)
	check("world_wheel_zooms_in", is_equal_approx(host.route_camera.zoom.x, 1.1), host.route_camera.zoom)
	await wheel(world_pointer, MOUSE_BUTTON_WHEEL_DOWN)
	check("world_wheel_zooms_out", is_equal_approx(host.route_camera.zoom.x, 1.0), host.route_camera.zoom)
	await click(visual(minimap._zoom_in).get_center())
	check("minimap_zoom_button_changes_camera", is_equal_approx(host.route_camera.zoom.x, 1.1), host.route_camera.zoom)
	await wheel(square.get_center(), MOUSE_BUTTON_WHEEL_UP)
	check("minimap_wheel_does_not_reach_world", is_equal_approx(host.route_camera.zoom.x, 1.1))
	check("camera_zoom_leaves_hud_and_minimap_unchanged", host.ui_root.scale == hud_scale and minimap._background.bounds == map_bounds and visual(minimap._background).is_equal_approx(square))
	host.change_camera_zoom(100)
	check("camera_zoom_upper_limit", is_equal_approx(host.route_camera.zoom.x, 1.6))
	host.change_camera_zoom(-100)
	check("camera_zoom_lower_limit", is_equal_approx(host.route_camera.zoom.x, 0.5))
	await frames(3)
	var reset_enabled := not minimap._zoom_reset.disabled and host._camera_zoom_available()
	var reset_presses: Array[bool] = []
	var reset_requests: Array[bool] = []
	var reset_edges: Array[Dictionary] = []
	minimap._zoom_reset.pressed.connect(func() -> void: reset_presses.append(true))
	minimap.zoom_reset_requested.connect(func() -> void: reset_requests.append(true))
	minimap._zoom_reset.button_down.connect(func() -> void: reset_edges.append({"edge": "down", "disabled": minimap._zoom_reset.disabled, "pending": host._memory_snapshot_pending, "paused": paused}))
	minimap._zoom_reset.button_up.connect(func() -> void: reset_edges.append({"edge": "up", "disabled": minimap._zoom_reset.disabled, "pending": host._memory_snapshot_pending, "paused": paused}))
	await click(visual(minimap._zoom_reset).get_center())
	var hovered := root.gui_get_hovered_control()
	check("camera_zoom_reset", host.route_camera.zoom.is_equal_approx(Vector2.ONE), [reset_enabled, host.route_camera.zoom, visual(minimap._zoom_reset), reset_presses.size(), reset_requests.size(), str(hovered.get_path()) if hovered != null else "no_hover", minimap.zoom_reset_requested.get_connections().size(), reset_edges])
	# Give the next independent modal/persistence case a known starting zoom.
	host.reset_camera_zoom()
	host._toggle_settings(true)
	await wheel(world_pointer, MOUSE_BUTTON_WHEEL_UP)
	host.change_camera_zoom(1)
	check("modal_blocks_camera_zoom", host.route_camera.zoom.is_equal_approx(Vector2.ONE))
	host._toggle_settings(false)
	host.change_camera_zoom(-3)
	var stored := ControlPreferences.new()
	stored.path = host.control_preferences.path
	stored.load_settings()
	check("camera_zoom_preference_saved", is_equal_approx(stored.camera_zoom, 0.7))
	var anchor := host.player.world_point()
	var world := host.player.world_motion.geometry
	var destination := world.support_at(anchor.surface_id, Vector2(anchor.position.x + 70.0, anchor.position.z), world.geometry_revision)
	if destination.get("ok", false):
		await click(host.get_canvas_transform() * ExpeditionGeometryView.project(destination["data"]["point"]["position"]))
		await frames(20)
	check("world_click_moves_after_camera_zoom", destination.get("ok", false) and host.player.world_point().position.distance_to(anchor.position) > 0.5)
	host.player.world_motion.cancel()
	host.change_interface_preferences(1.2, false)
	await frames(3)
	check("minimap_clears_action_bar_at_large_ui_scale", not visual(minimap).intersects(visual(host.bottom_controls)), [visual(minimap), visual(host.bottom_controls)])
	host.change_interface_preferences(GuiMetrics.SCALE, false)
	status.show(); status.set_process(true)
	await frames(3)
	var evidence := OS.get_environment("F9_EVIDENCE")
	if evidence.is_empty(): evidence = "res://.godot/verification"
	root.get_texture().get_image().save_png(evidence.path_join("minimap_interface.png"))
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_INTERFACE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	quit(0 if ok else 1)
