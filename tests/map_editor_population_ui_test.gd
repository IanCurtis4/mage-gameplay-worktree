@tool
extends EditorPlugin
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const PopulationPanel = preload("res://scripts/map_authoring/population/population_panel.gd")
const Document = preload("res://scripts/map_authoring/population/population_document.gd")
const Compiler = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Store = preload("res://scripts/map_authoring/population/population_store.gd")
const Fixture = preload("res://tests/map_editor_population_test.gd")
var checks: Array = []
func check(id: String, value: bool) -> void:
	checks.append({"id":id,"ok":value}); print("M4_UI_CHECK "+id+" "+str(value))
func _enter_tree() -> void: _run.call_deferred()
func wait_job(panel: Control) -> void:
	for i: int in 3000:
		await get_tree().process_frame
		if panel.job == null: return
func _run() -> void:
	await get_tree().process_frame
	if not EditorInterface.is_plugin_enabled("ragrpg_map_editor"): EditorInterface.set_plugin_enabled("ragrpg_map_editor",true)
	await get_tree().process_frame; EditorInterface.set_main_screen_editor("Mapas")
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == Shell: shell = node
	check("native_shell_visible",shell != null and shell.visible)
	if shell == null: finish(); return
	shell.open_composition(); await get_tree().process_frame
	var composition: Control = shell.composition_window.get_child(0); composition.open_population(); await get_tree().process_frame
	var panel: Control = composition.population_window.get_child(0)
	check("population_window_from_composition",panel.get_script() == PopulationPanel and composition.population_window.visible)
	var source := Fixture.fixture(); var applied: Dictionary = panel.import_map(source.map[0])
	check("imports_snapshot",applied.ok and not panel.canvas.package.is_empty())
	check("catalog_populates_ui",panel.species.item_count > 0)
	panel.paint.select(1); panel.paint_at(source.entrance[0]); check("paint_entry",panel.session.data.entrance == source.entrance)
	# Apply deterministic sample recipes through the same session used by GUI edits.
	panel.session.apply(source); panel.prepare_plan(); await wait_job(panel); check("gui_prepares_diff",panel.proposal.ok and panel.proposal.diff.added.size() == 7 and panel.session.data.slots.is_empty())
	check("unapplied_spatial_preview",panel.canvas.source.slots.size() == 7 and panel.showing_proposal)
	panel.toggle_proposal(); check("compare_current_before_apply",panel.canvas.source.slots.is_empty()); panel.toggle_proposal()
	panel.request_apply(); check("diff_confirmation_visible",panel._confirmation.visible and panel._pending == "plan"); panel._confirmation.hide(); panel.confirm_action()
	check("apply_plan_one_undo_step",panel.session.data.slots.size() == 7)
	var realized: Dictionary = panel.session.data.duplicate(true); var original := Document.hash_source(realized)
	panel.session.undo(); check("undo_whole_plan",panel.session.data.slots.is_empty()); panel.session.redo(); check("redo_whole_plan",Document.hash_source(panel.session.data) == original)
	panel.bake(); await wait_job(panel); check("native_compile_complete",panel.job == null and panel.result.get("ok",false))
	if not panel.result.get("ok",false): print(panel.result); finish(); return
	check("gui_headless_equal",panel.result.output_hash == Compiler.compile(panel.session.data).output_hash)
	panel.slots.select(0); panel.pin_slot(); check("pin_ui",panel.session.data.slots[0].fixed and panel.result.is_empty())
	var pin: Dictionary = panel.session.data.slots[0].duplicate(true); var reroll: Dictionary = panel.session.data.duplicate(true)
	for brush: Dictionary in reroll.brushes: brush.round = 1
	panel.session.apply(reroll); panel.prepare_plan(); await wait_job(panel); check("reroll_diff_preserves_pin",panel.proposal.ok and panel.proposal.diff.preserved.has(pin.slot_id))
	panel.request_apply(); panel._confirmation.hide(); panel.confirm_action(); check("pin_home_preserved",panel.session.data.slots.has(pin))
	# Checkpoint49 (P6d): "Testar" opens the real game; the canonical simulation is the canvas technical test.
	panel.bake(); await wait_job(panel); var simulated: Dictionary = panel.canvas.start_test(); check("canonical_discardable_test",simulated.get("ok",false) and panel.canvas.testing and panel.canvas.campaign.valid())
	for i: int in panel.session.data.slots.size(): panel.slots.select(i); panel.simulate_death()
	check("canonical_clear_from_ui",panel.canvas.campaign.stages.map_preview.cleared_once)
	panel.simulate_wave(); check("canonical_respawn_from_ui",panel.canvas.campaign.slots.values().filter(func(s: Dictionary) -> bool: return s.generation == 1 and s.life_state == "alive").size() == 7)
	panel.canvas.stop_test(); check("test_preserves_source",not panel.canvas.testing and panel.session.data.slots.has(pin))
	panel._action = "save"; var path := ProjectSettings.globalize_path("res://.godot/native_encounters.json"); panel.file_selected(path)
	check("native_save_roundtrip",Store.load_source(path).ok and Document.hash_source(Store.load_source(path).data) == Document.hash_source(panel.session.data))
	# Checkpoint52: a saved document is clean and has no draft to keep; edit it first so the
	# draft exists whether or not the 10 s autosave timer already ran.
	var unsaved: Dictionary = panel.session.data.duplicate(true); unsaved.name = "Encontros antes do novo"; panel.session.apply(unsaved)
	panel.preserve_draft(); var draft: String = panel._autosave; var draft_hash := Document.hash_source(panel.session.data)
	panel.new_document(); panel.preserve_draft(); check("new_preserves_prior_draft",panel._autosave != draft and Document.hash_source(Store.load_source(draft).data) == draft_hash)
	panel._action = "open"; panel.file_selected(path); panel.bake(); await wait_job(panel)
	check("reopen_compiles_existing_plan",panel.result.get("ok",false))
	panel._action = "publish"; var published := ProjectSettings.globalize_path("res://.godot/native_population_publication"); panel.file_selected(published)
	check("ui_local_immutable_package",FileAccess.file_exists(published.path_join(panel.result.output_hash+".rpe")))
	# A real projected click invokes the paint operation on a canonical support.
	panel.paint.select(3); panel.canvas.paint_enabled = true; panel.radius.value = 16
	var press := InputEventMouseButton.new(); press.pressed = true; press.button_index = MOUSE_BUTTON_LEFT; press.position = panel.canvas.screen(Vector3(300,0,300)); panel.canvas._gui_input(press)
	check("native_click_paints_exclusion",panel.session.data.exclusions.size() == 2 and panel.result.is_empty())
	panel.session.undo(); panel.bake(); await wait_job(panel)
	panel.canvas.selected_slot = pin.slot_id
	for i: int in 4: await get_tree().process_frame
	RenderingServer.force_draw()
	var capture := OS.get_environment("M4_CAPTURE"); var image: Image = composition.population_window.get_texture().get_image()
	if capture != "": image.save_png(capture)
	check("native_capture",capture != "" and FileAccess.file_exists(capture))
	panel.prepare_plan(); panel.job.cancel(); await wait_job(panel); check("cancelled_native_worker",panel.proposal.code == "cancelled")
	panel.brushes.select(0); panel.select_brush(0); panel.quantity.value = 128; panel.apply_brush(); panel.prepare_plan(); await wait_job(panel)
	if panel.problems.item_count > 0: panel.focus_problem(0)
	check("localized_brush_deficit",panel.proposal.code == "population_deficit" and panel.brushes.get_selected_items().size() == 1 and panel.session.data.brushes[panel.brushes.get_selected_items()[0]].brush_id == "field")
	composition.population_window.hide(); shell.composition_window.hide(); finish()
func finish() -> void:
	var ok := true
	for item: Dictionary in checks:
		if not item.ok: ok = false
	print("M4_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
