@tool
extends EditorPlugin
## Checkpoint49 (F9-06/07/08, P6a): the step bar on the real terrain, map,
## encounter and patrol screens of the editor. The person follows "Próximo passo"
## from compiling the map to the game test; a changed piece is carried to the map,
## the encounters and the patrols in the background, each reviewed and applied as
## one undo; a refused carry opens the screen that owns the marker with it
## focused; AX reads the same state. P6b: after a real game test the map is
## published in the game's list of maps (a scratch registry folder) after the
## person confirms; a new revision keeps the previous package file.
const Fixture = preload("res://tests/map_editor_root_synthesis_test.gd")
const Headless = preload("res://tests/map_editor_workflow_test.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const Release = preload("res://scripts/map_authoring/release/map_release.gd")
const FOLDER := "res://.godot/f9_workflow_release/"
var checks: Array[Dictionary] = []
var shell: Control
var flow: RefCounted
func _enter_tree() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_WORKFLOW_UI_CHECK "+id+" "+str(ok))
func frames(count: int = 2) -> void:
	for i: int in count: await get_tree().process_frame
func capture(window: Window, id: String) -> void:
	await frames(); RenderingServer.force_draw(false); await frames()
	var target: Viewport = window
	while target is Window and (target as Window).is_embedded() and target.get_parent() != null: target = target.get_parent().get_viewport()
	var texture := target.get_texture()
	var image := texture.get_image() if texture != null else null
	check("capture_"+id,image != null and image.save_png(OS.get_environment("F9_EVIDENCE").path_join(id+".png")) == OK)
func settle(limit_ms: int = 180000) -> void:
	# Waits for every job of the screens and of the flow.
	var limit := Time.get_ticks_msec()+limit_ms
	await frames()
	while Time.get_ticks_msec() < limit:
		var busy: bool = flow.job != null
		for kind: String in ["piece","map","population","patrol"]: busy = busy or flow._busy(kind)
		if not busy: break
		await get_tree().process_frame
	await frames(3)
func next_action() -> String: return String(flow.next_step().get("action",""))
func press_next(bar: Node) -> void:
	bar.next_button.pressed.emit(); await settle()
func confirm(bar: Node) -> bool:
	var dialog: ConfirmationDialog = bar.confirmation
	var shown := dialog.visible
	dialog.get_ok_button().pressed.emit(); await settle()
	return shown
func game_closed(tools: Control) -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		var current: Dictionary = tools.inspect()
		if current.ok and current.state.state == "closed": return true
		await get_tree().create_timer(0.1).timeout
	return false
func game_active(tools: Control) -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		var current: Dictionary = tools.inspect()
		if current.ok and current.state.state == "active": return true
		if not current.ok or current.state.state not in ["starting","ready"]: return false
		await get_tree().create_timer(0.1).timeout
	return false
## Runs the game test through the bar and closes the game again.
func play(patrol_panel: Control) -> bool:
	await press_next(patrol_panel.workflow_bar)
	var active := await game_active(patrol_panel.gameplay_tools)
	patrol_panel.gameplay_tools.stop()
	var closed := await game_closed(patrol_panel.gameplay_tools)
	await frames(3)
	return active and closed
func publish_through_the_dialog(patrol_panel: Control, id: String, name: String) -> Dictionary:
	patrol_panel.workflow_bar.next_button.pressed.emit(); await frames(3)
	var dialog: ConfirmationDialog = patrol_panel.workflow_bar.publish_dialog
	var shown := dialog.visible
	patrol_panel.workflow_bar.publish_id.text = id; patrol_panel.workflow_bar.publish_id.text_changed.emit(id)
	patrol_panel.workflow_bar.publish_name.text = name; patrol_panel.workflow_bar.publish_name.text_changed.emit(name)
	var summary: String = patrol_panel.workflow_bar.publish_summary.text
	dialog.get_ok_button().pressed.emit(); await frames(2)
	var limit := Time.get_ticks_msec()+180000
	while flow.job != null and Time.get_ticks_msec() < limit: await get_tree().process_frame
	await frames(3)
	return {"shown":shown,"summary":summary}
func run() -> void:
	await get_tree().create_timer(2).timeout
	var scratch := ProjectSettings.globalize_path(FOLDER)
	if DirAccess.dir_exists_absolute(scratch):
		for file: String in DirAccess.get_files_at(scratch): DirAccess.remove_absolute(scratch.path_join(file))
	DirAccess.make_dir_recursive_absolute(scratch)
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = node
	check("native_shell",shell != null and shell.is_visible_in_tree())
	if shell == null: finish(); return
	flow = shell.flow; flow.release_folder = FOLDER
	var built := Fixture.fixture()
	var room: Dictionary = built.map.pieces[0].source
	shell.session.replace(room); await frames()
	var bar: Node = shell.workflow_bar
	check("bar_on_the_terrain_screen",bar != null and bar.is_visible_in_tree() and bar.step_buttons.size() == 6 and bar.get_index() <= 1 and next_action() == "open_map")
	# The person starts from the terrain screen.
	await press_next(bar)
	var map_panel: Control = shell.composition_window.get_child(0) if shell.composition_window != null else null
	check("next_opens_the_composition",map_panel != null and shell.composition_window.visible and map_panel.flow == flow and map_panel.workflow_bar.is_visible_in_tree())
	if map_panel == null: finish(); return
	map_panel.session.replace(built.map); await settle()
	check("map_step_asks_to_compile",next_action() == "compile_map" and flow.steps()[1].state == "todo")
	await press_next(map_panel.workflow_bar)
	check("map_compiled_through_the_bar",map_panel.result.get("ok",false) and flow.steps()[1].state == "ready" and next_action() == "open_population")
	await press_next(map_panel.workflow_bar)
	var population_panel: Control = map_panel.population_window.get_child(0) if map_panel.population_window != null else null
	check("encounters_open_with_the_map",population_panel != null and population_panel.flow == flow and not population_panel.session.data.map.is_empty() and MapDocument.hash_source(population_panel.session.data.map[0]) == MapDocument.hash_source(map_panel.session.data))
	if population_panel == null: finish(); return
	check("empty_encounters_ask_for_marks",next_action() == "mark_population")
	population_panel.session.replace(built.population); await settle()
	await press_next(population_panel.workflow_bar)
	check("encounters_compiled_through_the_bar",population_panel.result.get("ok",false) and next_action() == "open_patrols")
	await press_next(population_panel.workflow_bar)
	var patrol_panel: Control = population_panel.patrol_window.get_child(0) if population_panel.patrol_window != null else null
	if patrol_panel == null: finish(); return
	var patrols: Dictionary = built.patrols.duplicate(true); patrols.population = [population_panel.session.data.duplicate(true)]
	patrol_panel.session.replace(patrols); await settle()
	await press_next(patrol_panel.workflow_bar)
	check("flow_reaches_the_game_test",patrol_panel.result.get("ok",false) and next_action() == "test" and flow.steps().slice(1,4).all(func(step: Dictionary) -> bool: return step.state == "ready"))
	await capture(map_panel.population_window.get_child(0).patrol_window,"workflow_patrols_ready")
	# P6b: test in the real game, then publish after confirmation.
	check("publish_waits_for_a_test",flow.steps()[5].state == "waiting")
	var played := await play(patrol_panel)
	check("real_game_test_marks_the_revision",played and flow.steps()[4].state == "ready" and next_action() == "publish")
	var first := await publish_through_the_dialog(patrol_panel,"workflow_rooms","Duas salas")
	var listed := Release.load_package("workflow_rooms",{},FOLDER)
	var first_path: String = listed.get("entry",{}).get("path","")
	check("publication_is_reviewed_and_pinned",first.shown and first.summary.begins_with("Novo mapa no jogo") and listed.get("ok",false) and listed.package.package_hash == patrol_panel.result.package.package_hash and flow.steps()[5].state == "ready" and FileAccess.file_exists(FOLDER+"workflow_rooms.patrol.json"))
	# A changed piece is carried forward, step by step.
	var map_before := MapDocument.hash_source(map_panel.session.data)
	shell.session.apply(Headless.raised(room,16.0)); await settle()
	check("changed_piece_marks_the_map_stale",flow.steps()[1].state == "stale" and next_action() == "carry_piece" and flow.steps()[2].state == "waiting")
	bar.next_button.pressed.emit(); await frames()
	await frames(2)
	var background: bool = flow.job != null and bar.next_button.disabled
	await settle()
	check("carry_runs_in_the_background",background and next_action() == "confirm_carry" and MapDocument.hash_source(map_panel.session.data) == map_before)
	bar.next_button.pressed.emit(); await frames(3)
	await capture(shell.composition_window,"workflow_review_piece")
	var shown := await confirm(map_panel.workflow_bar)
	check("piece_carry_is_reviewed_and_one_undo",shown and MapDocument.hash_source(map_panel.session.data) != map_before and map_panel.session.can_undo() and next_action() == "compile_map")
	await press_next(map_panel.workflow_bar)
	var population_before: Dictionary = population_panel.session.data.duplicate(true)
	check("encounters_become_stale",next_action() == "carry_map")
	await press_next(map_panel.workflow_bar)
	map_panel.workflow_bar.next_button.pressed.emit(); await frames(3)
	var population_shown := await confirm(population_panel.workflow_bar)
	var lifted: bool = population_shown and is_equal_approx(float(population_panel.session.data.entrance[0].position_xyz[1]),float(population_before.entrance[0].position_xyz[1])+16.0)
	await press_next(population_panel.workflow_bar)
	check("map_carried_into_encounters",lifted and population_panel.result.get("ok",false) and next_action() == "carry_population")
	await press_next(population_panel.workflow_bar)
	population_panel.workflow_bar.next_button.pressed.emit(); await frames(3)
	var patrol_shown := await confirm(patrol_panel.workflow_bar)
	await press_next(patrol_panel.workflow_bar)
	var revision_waits: bool = flow.steps()[4].state == "todo" and flow.steps()[5].state == "waiting"
	check("encounters_carried_into_patrols",revision_waits and patrol_shown and patrol_panel.result.get("ok",false) and next_action() == "test" and is_equal_approx(float(patrol_panel.session.data.patrols[0].waypoints[0].position_xyz[1]),float(built.patrols.patrols[0].waypoints[0].position_xyz[1])+16.0))
	# A new revision: test again, publish; the previous package file stays.
	var replayed := await play(patrol_panel)
	var second := await publish_through_the_dialog(patrol_panel,"workflow_rooms","Duas salas")
	var relisted := Release.load_package("workflow_rooms",{},FOLDER)
	check("new_revision_keeps_the_previous_package",replayed and second.shown and second.summary.begins_with("Nova revisão") and relisted.get("ok",false) and relisted.entry.path != first_path and FileAccess.file_exists(first_path) and Release.registry(FOLDER).registry.packages.size() == 1)
	await capture(map_panel.population_window.get_child(0).patrol_window,"workflow_published")
	# A refused carry names the marker and opens its screen.
	var renamed: Dictionary = map_panel.session.data.duplicate(true)
	for instance: Dictionary in renamed.instances:
		if instance.instance_id == "east_room": instance.instance_id = "east_wing"
	for link: Dictionary in renamed.links:
		if link.a_instance == "east_room": link.a_instance = "east_wing"
		if link.b_instance == "east_room": link.b_instance = "east_wing"
	map_panel.session.apply(renamed); await settle()
	await press_next(map_panel.workflow_bar)
	await press_next(map_panel.workflow_bar)
	var problem: Dictionary = map_panel.workflow_bar._problem()
	check("refused_carry_names_the_marker",problem.get("code","") == "flow_instance_missing" and problem.get("entity_id","") == "finish" and map_panel.workflow_bar.show_button.visible)
	map_panel.population_window.hide()
	map_panel.workflow_bar.show_button.pressed.emit(); await frames(3)
	var selected: PackedInt32Array = population_panel.problems.get_selected_items()
	check("problem_opens_the_owning_screen",map_panel.population_window.visible and not selected.is_empty() and population_panel.problems.get_item_metadata(selected[0]).get("entity_id","") == "finish" and population_panel.status.text == problem.message)
	await capture(map_panel.population_window,"workflow_problem_focused")
	# AX reads and drives the same flow.
	var presentation: Control = map_panel.get_node("AuthoringPresentation"); presentation.set_mode("ax"); await frames()
	var state: Dictionary = presentation.ax_invoke("map/workflow/state")
	var states: Array = flow.steps().map(func(step: Dictionary) -> String: return step.state)
	check("ax_reads_the_same_state",state.get("ok",false) and state.steps.map(func(step: Dictionary) -> String: return step.state) == states and state.next == next_action())
	var wrong: Dictionary = presentation.ax_invoke("map/workflow/next",{"action":"test"})
	var shown_ax: Dictionary = population_panel.get_node("AuthoringPresentation").ax_invoke("population/workflow/show",{"step":"population"})
	check("ax_refuses_other_steps_and_shows",wrong.get("code","") == "flow_action_unavailable" and shown_ax.get("ok",false) and shown_ax.entity_id == "finish")
	presentation.set_mode("ux"); await frames()
	map_panel.session.undo(); await settle()
	# The bar is never folded into the screen menus.
	var menus_clean := true
	var map_presentation: Control = map_panel.get_node("AuthoringPresentation")
	for id: String in map_presentation.actions:
		if map_presentation.actions[id].control.get_parent().get_parent() == map_panel.workflow_bar: menus_clean = false
	check("bar_stays_visible_in_ux_and_out_of_menus",menus_clean and map_panel.workflow_bar.next_button.is_visible_in_tree())
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_WORKFLOW_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	EditorInterface.get_base_control().get_tree().quit(0 if ok else 1)
