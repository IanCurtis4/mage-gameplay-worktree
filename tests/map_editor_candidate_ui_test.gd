@tool
extends EditorPlugin
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")
const Fixture = preload("res://tests/map_editor_candidate_test.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
var checks: Array = []
func _enter_tree() -> void: run.call_deferred()
func check(id: String, value: bool) -> void:
	checks.append({"id":id,"ok":value}); print("M8_UI_CHECK "+id+" "+str(value))
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func capture(control: Control, filename: String) -> void:
	await frames()
	var image: Image = control.get_viewport().get_texture().get_image()
	check("capture_"+filename,image.save_png(OS.get_environment("M8_EVIDENCE").path_join(filename+".png")) == OK)
func wait_job(panel: Control) -> void:
	var start := Time.get_ticks_msec()
	while panel.job != null and Time.get_ticks_msec()-start < 120000: await get_tree().process_frame
func run() -> void:
	await get_tree().create_timer(3.0).timeout
	await frames()
	var root := EditorInterface.get_editor_main_screen()
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	var shell: Control
	for child: Node in root.get_children():
		if child.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = child
	check("real_main_screen_host",shell != null and shell.is_visible_in_tree())
	if shell == null: get_tree().quit(1); return
	var source: Dictionary = Fixture.representative_map().pieces[0].source
	shell.session.replace(source); shell.terrain.canvas.fit(); await frames()
	var host: Control = shell.get_node("AuthoringPresentation")
	var terrain_host: Control = shell.terrain.get_node("AuthoringPresentation")
	host.set_mode("ux")
	check("ux_default",host.ax_snapshot().mode == "ux" and host.mode_choice.selected == 0)
	check("ux_menus_grouped",host.menus.Arquivo.visible and host.menus.Criar.visible)
	check("ux_original_actions_hidden",host.actions["piece/new_piece"].control.visible == false)
	check("ux_terrain_dropdown",terrain_host.section_choice.visible and terrain_host.section_choice.item_count == 5)
	check("ux_terrain_noise_reduced",not shell.terrain.grid_columns.is_visible_in_tree())
	var before: Dictionary = shell.session.document().to_data(); var generation: int = shell.session.generation
	var undo: bool = shell.session.can_undo()
	var hash_before: String = shell.session.document().semantic_hash()
	var validation_before: Array = shell.session.document().diagnostics()
	var dirty_before: bool = shell.session.dirty(); var redo_before: bool = shell.session.can_redo()
	check("ax_action_requires_mode",host.ax_invoke("piece/apply_name").code == "ax_mode_required")
	host.set_mode("ax"); await frames()
	check("ax_flat_actions",host.overlay.visible and host.actions["piece/new_piece"].control.visible)
	check("ax_overlay_on_viewport",host.overlay.get_parent() == shell.terrain.canvas and host.overlay_buttons.size() == host.actions.size())
	check("ax_snapshot_source",host.ax_snapshot().source == before)
	check("ax_shared_mode",terrain_host.mode_choice.selected == 1)
	check("ax_missing_action",host.ax_invoke("missing").code == "action_missing")
	var control: Button = host.actions["piece/apply_name"].control; control.disabled = true
	check("ax_disabled_action",host.ax_invoke("piece/apply_name").code == "action_disabled"); control.disabled = false
	check("ax_existing_command_dispatch",host.ax_invoke("piece/apply_name").ok)
	host.set_mode("ux"); await frames()
	check("toggle_preserves_document_history",shell.session.document().to_data() == before and shell.session.generation == generation and shell.session.can_undo() == undo)
	check("toggle_preserves_hash_validation_dirty",shell.session.document().semantic_hash() == hash_before and shell.session.document().diagnostics() == validation_before and shell.session.dirty() == dirty_before and shell.session.can_redo() == redo_before)
	check("invalid_mode_rejected",not host.set_mode("invalid").ok and host.ax_snapshot().mode == "ux")
	await capture(shell,"piece_ux")
	var menu: PopupMenu = host.menus.Arquivo.get_popup(); host._update_menu("Arquivo")
	check("menu_metadata_stable",menu.get_item_metadata(0) == "piece/open" and host.actions.has("piece/open"))
	var saved: Dictionary = host.ax_snapshot(); saved.source.name = "Snapshot alterado"
	check("snapshot_is_copy",shell.session.document().to_data().name == before.name)
	var context_window: Window
	for child: Node in shell.get_children():
		if child is Window and child.title.begins_with("Contexto da peça"): context_window = child
	var context: Control = context_window.get_child(0).get_child(0)
	context.refresh(); context_window.popup_centered(); await frames()
	context.biomes.text = "ruin, forest"; context.rare.button_pressed = true; context.save_piece()
	check("piece_context_gui_saves_biomes",shell.session.document().to_data().context.biome_ids == ["ruin","forest"])
	context.area_id.text = "gui_area"; context.layer.select(0); context.bounds[0].value = 128; context.bounds[1].value = 80; context.bounds[2].value = 320; context.bounds[3].value = 320
	context.reserved.button_pressed = true; context.encounter.text = "gui_guardian"; context.quest.text = "gui_quest"; context.save_area()
	var authored: Dictionary = shell.session.document().to_data()
	check("piece_context_gui_saves_area_reservation",authored.context.areas.size() == 1 and authored.context.areas[0].reserved[0].quest_id == "gui_quest" and authored.regions[0].region_id == "gui_area")
	check("piece_context_undo",shell.session.undo() and shell.session.document().to_data().context.areas.is_empty())
	context_window.hide()
	shell.open_composition(); await frames()
	var map_panel: Control = shell.composition_window.get_child(0)
	check("real_composition_window",shell.composition_window.visible)
	map_panel.session.replace(Fixture.representative_map()); map_panel.bake(); await wait_job(map_panel); await frames()
	check("native_map_compiles",map_panel.result.get("ok",false))
	var map_host: Control = map_panel.get_node("AuthoringPresentation")
	check("context_action_exposed",map_host.actions.has("map/map_context"))
	var map_context_window: Window
	for child: Node in map_panel.get_children():
		if child is Window and child.title.begins_with("Contexto do mapa"): map_context_window = child
	var map_context: Control = map_context_window.get_child(0)
	map_context.refresh(); map_context.instances.select(0); map_context.rules.select(0); map_context.reason.text = "Exceção GUI revisada"; map_context.save_context()
	check("map_context_gui_exception",map_panel.session.data.context.overrides.size() == 1 and map_panel.session.data.context.overrides[0].reason == "Exceção GUI revisada")
	check("map_context_gui_warning","Exceção GUI revisada" in map_context.warnings.text and map_panel.problems.item_count > 0)
	map_panel.mode.select(1); map_panel.mode.item_selected.emit(1)
	check("rejected_recipe_restores_selector",map_panel.session.data.mode == "manual" and map_panel.mode.selected == 0)
	map_panel.session.undo(); map_panel.bake(); await wait_job(map_panel)
	await capture(map_panel,"map_ux")
	map_host.set_mode("ax"); await capture(map_panel,"map_ax"); map_host.set_mode("ux")
	var map_hash := Map.hash_source(map_panel.session.data)
	map_host.ax_invoke("map/toggle_test")
	check("ux_ax_call_refused",not map_panel.canvas.testing and Map.hash_source(map_panel.session.data) == map_hash)
	map_host.set_mode("ax"); check("ax_test_calls_real_authority",map_host.ax_invoke("map/toggle_test").ok and map_panel.canvas.testing)
	map_host.ax_invoke("map/toggle_test"); check("ax_test_stops",not map_panel.canvas.testing)
	map_host.set_mode("ux"); shell.composition_window.hide()
	var population_screen: Control
	for entry: Array in [["population","res://scripts/map_authoring/population/population_panel.gd"],["patrol","res://scripts/map_authoring/patrol/patrol_panel.gd"],["generation","res://scripts/map_authoring/generation/generation_panel.gd"]]:
		var screen: Control
		if entry[0] == "population": map_panel.open_population(); screen = map_panel.population_window.get_child(0); population_screen = screen
		elif entry[0] == "patrol": population_screen.open_patrols(); screen = population_screen.patrol_window.get_child(0)
		else: map_panel.open_generation(); screen = map_panel.generation_window.get_child(0)
		await frames()
		check("real_window_"+entry[0],screen.get_parent() is Window and screen.get_parent().visible)
		var file := FileAccess.open("res://.godot/m8_samples/"+("population" if entry[0] == "generation" else entry[0])+".json",FileAccess.READ)
		var data: Dictionary = JSON.parse_string(file.get_as_text()); file.close()
		if entry[0] == "generation": screen.source = screen.Document.from_map(data.map[0]); screen.refresh()
		else: screen.session.replace(data)
		var presentation: Control = screen.get_node("AuthoringPresentation")
		var snapshot: Dictionary = presentation.ax_snapshot().source
		presentation.set_mode("ax"); await frames()
		check("native_ax_"+entry[0],presentation.overlay.visible and not presentation.actions.is_empty())
		presentation.set_mode("ux"); await frames()
		check("native_switch_pure_"+entry[0],presentation.ax_snapshot().source == snapshot)
		check("exchange_binding_"+entry[0],screen.exchange_panel.kind == entry[0])
		if entry[0] == "population":
			check("test_tools_hidden_in_ux",presentation.actions["population/simulate_death"].ax_only and not presentation.actions["population/simulate_death"].control.visible)
			screen.bake(); await wait_job(screen); check("native_population_compiles",screen.result.get("ok",false)); await capture(screen,"population_ux")
		screen.get_parent().hide()
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("M8_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
