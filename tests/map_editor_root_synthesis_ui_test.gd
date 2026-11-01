@tool
extends EditorPlugin
## Checkpoint44 (F9-05/07/08/09, P3b): "Variação regional" on the real encounter,
## map and patrol screens, on the two-room fixture. Background GUI preview, the
## same hash from GUI, AX and the CLI, one undo, and the tool on every root screen.
const Root = preload("res://scripts/map_authoring/synthesis/root_synthesis.gd")
const Fixture = preload("res://tests/map_editor_root_synthesis_test.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ROOT_SYNTH_UI_CHECK "+id+" "+str(ok))
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func capture(window: Window, id: String) -> void:
	await frames(); RenderingServer.force_draw(false); await frames()
	# An embedded window is drawn by its embedder; a native one has its own texture.
	var target: Viewport = window
	while target is Window and (target as Window).is_embedded() and target.get_parent() != null: target = target.get_parent().get_viewport()
	var texture := target.get_texture()
	var image := texture.get_image() if texture != null else null
	check("capture_"+id,image != null and image.save_png(OS.get_environment("F9_EVIDENCE").path_join(id+".png")) == OK)
func button(root: Node, caption: String) -> Button:
	for node: Node in root.find_children("*","Button",true,false):
		if (node as Button).text == caption: return node
	return null
func wait_job(section: Node) -> void:
	var limit := Time.get_ticks_msec()+120000
	while section.job != null and Time.get_ticks_msec() < limit: await get_tree().process_frame
func ids(presentation: Control) -> Array:
	var result: Array = []
	for command: Dictionary in presentation.ax_snapshot().commands: result.append(str(command.id))
	return result
func run() -> void:
	await get_tree().create_timer(2).timeout
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = node
	check("native_shell",shell != null and shell.is_visible_in_tree())
	if shell == null: finish(); return
	var built := Fixture.fixture()
	shell.open_composition(); await frames()
	var map_panel: Control = shell.composition_window.get_child(0)
	map_panel.session.replace(built.map); await frames()
	check("map_screen_offers_the_tool",map_panel.synthesis != null and map_panel.synthesis.instance_choice.item_count == 2 and "map/synthesis/preview" in ids(map_panel.get_node("AuthoringPresentation")))
	map_panel.open_population(); await frames()
	var panel: Control = map_panel.population_window.get_child(0)
	panel.session.replace(built.population); await frames()
	var section: Node = panel.synthesis
	# The real button of the screen (the AX overlay has a copy with the same text).
	section.open_button.pressed.emit(); await frames()
	var opened: bool = section.window.visible
	for index: int in section.instance_choice.item_count:
		if section.instance_choice.get_item_metadata(index) == "west_room": section.instance_choice.select(index); section.instance_choice.item_selected.emit(index)
	check("instance_layer_and_region_are_listed",opened and section.instance_choice.item_count == 2 and section.layer_choice.get_item_metadata(section.layer_choice.selected) == "ground" and section.region.get_item_metadata(section.region.selected) == "variation_area")
	section.seed_text.text = "17"; section.terrain_mode.select(1)
	section.amplitude.value = 32; section.feature_size.value = 192; section.roughness.value = 0.5; section.falloff.value = 32
	var base_hash := PopulationDocument.hash_source(panel.session.data)
	button(section,"Prévia regional").pressed.emit()
	var background: bool = section.job != null
	await wait_job(section)
	var gui: Dictionary = section.pending
	check("gui_preview_runs_in_background",background and gui.get("ok",false) and gui.diff.instance_id == "west_room" and gui.diff.snapshots_added.size() == 1)
	check("preview_changes_nothing",PopulationDocument.hash_source(panel.session.data) == base_hash and not panel.session.can_undo() and section.preview_canvas.visible and section.status.text.begins_with("Prévia"))
	await capture(section.window,"root_variation_preview")
	section.window.hide()
	var presentation: Control = panel.get_node("AuthoringPresentation"); presentation.set_mode("ax")
	var described: Dictionary = presentation.ax_invoke("population/synthesis/request")
	var ax: Dictionary = presentation.ax_invoke("population/synthesis/preview",{"request":described.get("request",{})})
	check("ax_preview_has_the_gui_hash",described.get("ok",false) and ax.get("ok",false) and ax.proposal_hash == gui.source_hash and ax.compiled_hash == gui.compiled_hash and not ax.has("source"))
	var folder := ProjectSettings.globalize_path("res://.godot/f9_root_synthesis_cli"); DirAccess.make_dir_recursive_absolute(folder)
	var root_path := folder.path_join("encounters.json"); var request_path := folder.path_join("request.json"); var out_path := folder.path_join("proposal.json")
	for path: String in [root_path,request_path,out_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var writer := FileAccess.open(root_path,FileAccess.WRITE); writer.store_string(JSON.stringify(panel.session.data,"\t",true,true)); writer.close()
	writer = FileAccess.open(request_path,FileAccess.WRITE); writer.store_string(JSON.stringify(described.request,"\t",true,true)); writer.close()
	var before := FileAccess.get_sha256(root_path); var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://scripts/map_authoring/synthesis/headless.gd","--",root_path,request_path,out_path],output,true)
	var cli: Dictionary = {}
	for line: String in "\n".join(output).split("\n"):
		if line.begins_with("MAP_SYNTHESIS_RESULT "): cli = JSON.parse_string(line.trim_prefix("MAP_SYNTHESIS_RESULT "))
	check("cli_has_the_same_hash",code == 0 and cli.get("ok",false) and cli.get("proposal_hash","") == gui.source_hash and cli.get("written",false) and FileAccess.get_sha256(root_path) == before)
	presentation.set_mode("ux"); await frames()
	section.pending = gui
	button(section,"Aplicar variação").pressed.emit(); await frames()
	var applied: bool = PopulationDocument.hash_source(panel.session.data) == gui.source_hash and panel.session.can_undo()
	# Checkpoint46 (P3d): the receipt is at the encounter root and replays.
	presentation.set_mode("ax")
	var receipts: Dictionary = presentation.ax_invoke("population/synthesis/receipts")
	var replay: Dictionary = presentation.ax_invoke("population/synthesis/replay",{"index":0})
	presentation.set_mode("ux")
	check("root_receipt_replays",receipts.get("ok",false) and receipts.receipts.size() == 1 and receipts.receipts[0].kind == "population" and replay.get("reproduced",false) and replay.get("current_is_result",false))
	panel.session.undo(); await frames()
	check("gui_apply_is_one_undo",applied and PopulationDocument.hash_source(panel.session.data) == base_hash and not panel.session.can_undo())
	panel.session.replace(built.population); await frames()
	panel.open_patrols(); await frames()
	var patrol_panel: Control = panel.patrol_window.get_child(0)
	check("patrol_screen_offers_the_tool",patrol_panel.synthesis != null and patrol_panel.synthesis.encounter_mode != null and "patrol/synthesis/preview" in ids(patrol_panel.get_node("AuthoringPresentation")))
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(entry: Dictionary) -> bool: return entry.ok)
	print("F9_ROOT_SYNTH_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
