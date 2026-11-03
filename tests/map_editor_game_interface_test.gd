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
	await app.suspend()
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_INTERFACE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	quit(0 if ok else 1)
