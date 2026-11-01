@tool
extends EditorPlugin
## Checkpoint43 (F9-05/07/09, P3a): the "Variação regional" section of the real
## editor terrain screen, on the Bosque clearing piece. GUI preview in the
## background, the same hash from GUI, AX and the CLI, one undoable apply,
## cancellation and a stale preview refused, all without touching the source.
const Synthesis = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const SELECTION := [[384,352],[1152,352],[1152,992],[384,992]]
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_SYNTH_UI_CHECK "+id+" "+str(ok))
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func capture(control: Control, id: String) -> void:
	await frames(); RenderingServer.force_draw(false); await frames()
	check("capture_"+id,control.get_viewport().get_texture().get_image().save_png(OS.get_environment("F9_EVIDENCE").path_join(id+".png")) == OK)
func button(root: Node, caption: String) -> Button:
	for node: Node in root.find_children("*","Button",true,false):
		if (node as Button).text == caption: return node
	return null
func wait_job(section: Node) -> void:
	var limit := Time.get_ticks_msec()+60000
	while section.job != null and Time.get_ticks_msec() < limit: await get_tree().process_frame
func run() -> void:
	await get_tree().create_timer(2).timeout
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = node
	check("native_shell",shell != null and shell.is_visible_in_tree())
	if shell == null: finish(); return
	var loaded := Schema.read(FileAccess.get_file_as_bytes("res://data/map_authoring/sanctuary_woods_clearing.source.json"))
	var data: Dictionary = loaded.data
	data.regions.append({"region_id":"variation_area","layer_id":"a_ground","polygon_xz":SELECTION,"purpose":"encounter"})
	shell.session.replace(data); await frames()
	var terrain: Control = shell.terrain; terrain.select_layer("a_ground"); await frames()
	var section: Node = terrain.synthesis
	var presentation: Control = terrain.get_node("AuthoringPresentation")
	var section_index := -1
	for index: int in presentation.section_choice.item_count:
		if presentation.section_choice.get_item_text(index) == "Variação regional": section_index = index
	presentation.section_choice.select(section_index); presentation.section_choice.item_selected.emit(section_index); await frames()
	check("section_is_a_terrain_tool",section_index > 0 and section.is_visible_in_tree())
	var region_index := -1
	for index: int in section.region.item_count:
		if section.region.get_item_metadata(index) == "variation_area": region_index = index
	check("regions_of_the_layer_are_listed",region_index >= 0 and section.region.item_count == 2)
	section.region.select(region_index); section.seed_text.text = "17"
	section.terrain_mode.select(1); section.amplitude.value = 48; section.feature_size.value = 256; section.roughness.value = 0.5; section.falloff.value = 96
	section.material_mode.select(1); section.coverage.value = 0.5; section.patch_size.value = 192
	for index: int in section.material_choice.item_count:
		if section.material_choice.get_item_metadata(index) == "sand": section.material_choice.select(index)
	var base_hash: String = shell.session.document().semantic_hash()
	# 1. GUI preview runs in the background and changes nothing.
	var preview_button := button(section,"Prévia regional")
	preview_button.pressed.emit()
	var started_in_background: bool = section.job != null
	await wait_job(section)
	var gui: Dictionary = section.pending
	check("gui_preview_runs_in_background",started_in_background and gui.get("ok",false) and gui.diff.terrain_samples.size() > 0 and gui.diff.material_samples.size() > 0)
	check("preview_shows_the_proposal_without_mutation",shell.session.document().semantic_hash() == base_hash and not shell.session.can_undo() and terrain.canvas.source == gui.source and terrain.status.text.begins_with("Prévia"))
	await capture(terrain,"regional_preview")
	# 2. AX reads the GUI request and gets the very same proposal.
	presentation.set_mode("ax")
	var described: Dictionary = presentation.ax_invoke("terrain/synthesis/request")
	var ax: Dictionary = presentation.ax_invoke("terrain/synthesis/preview",{"request":described.get("request",{})})
	check("ax_preview_has_the_gui_hash",described.ok and described.request.selection == {"region_id":"variation_area"} and ax.get("ok",false) and ax.proposal_hash == gui.source_hash and ax.compiled_hash == gui.compiled_hash and not ax.has("source"))
	# 3. The CLI on the same piece and request gives the same hash, never writing the input.
	var folder := ProjectSettings.globalize_path("res://.godot/f9_synthesis_cli"); DirAccess.make_dir_recursive_absolute(folder)
	var piece_path := folder.path_join("piece.source.json"); var request_path := folder.path_join("request.json"); var out_path := folder.path_join("proposal.source.json")
	for path: String in [piece_path,out_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var writer := FileAccess.open(piece_path,FileAccess.WRITE); writer.store_string(JSON.stringify(shell.session.document().to_data(),"\t",true,true)); writer.close()
	writer = FileAccess.open(request_path,FileAccess.WRITE); writer.store_string(JSON.stringify(described.request,"\t",true,true)); writer.close()
	var piece_before := FileAccess.get_sha256(piece_path)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://scripts/map_authoring/synthesis/headless.gd","--",piece_path,request_path,out_path],output,true)
	var cli: Dictionary = {}
	for line: String in "\n".join(output).split("\n"):
		if line.begins_with("MAP_SYNTHESIS_RESULT "): cli = JSON.parse_string(line.trim_prefix("MAP_SYNTHESIS_RESULT "))
	var written := Schema.read(FileAccess.get_file_as_bytes(out_path)) if FileAccess.file_exists(out_path) else {"ok":false}
	check("cli_has_the_same_hash",code == 0 and cli.get("ok",false) and cli.get("proposal_hash","") == gui.source_hash and written.ok and written.output_hash == gui.source_hash and FileAccess.get_sha256(piece_path) == piece_before)
	var again: Array = []
	OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://scripts/map_authoring/synthesis/headless.gd","--",piece_path,request_path,out_path],again,true)
	check("cli_never_overwrites","io_conflict" in "\n".join(again) and Schema.read(FileAccess.get_file_as_bytes(out_path)).output_hash == gui.source_hash)
	check("ax_apply_needs_the_previewed_hash",presentation.ax_invoke("terrain/synthesis/apply",{"proposal_hash":"0".repeat(64)}).code == "synthesis_stale_proposal" and shell.session.document().semantic_hash() == base_hash)
	presentation.set_mode("ux"); await frames()
	# 4. GUI apply: one change, one undo.
	section.pending = gui; terrain.canvas.set_source(gui.source,terrain.selected_layer)
	button(section,"Aplicar variação").pressed.emit(); await frames()
	var applied_hash: String = shell.session.document().semantic_hash()
	check("gui_apply_commits_the_preview",applied_hash != base_hash and Schema.semantic_hash(_without_revision(shell.session.document().to_data())) == Schema.semantic_hash(_without_revision(gui.source)) and section.pending.is_empty())
	# Checkpoint46 (P3d): the applied variation left one receipt; GUI, AX and the
	# CLI replay it on the stored base without touching the piece.
	var view: Node = section.receipts
	var listed: bool = view.receipts_list.item_count == 1
	button(view,"Reproduzir recibo").pressed.emit(); await frames()
	var gui_replay: bool = view.replay_status.text.begins_with("Reproduz exatamente")
	presentation.set_mode("ax")
	var ax_replay: Dictionary = presentation.ax_invoke("terrain/synthesis/replay",{"index":0})
	presentation.set_mode("ux")
	check("receipt_is_listed_and_replays",listed and gui_replay and ax_replay.get("reproduced",false) and ax_replay.get("current_is_result",false) and shell.session.document().semantic_hash() == applied_hash)
	var varied_path := folder.path_join("varied_"+Crypto.new().generate_random_bytes(4).hex_encode()+".source.json")
	var varied_writer := FileAccess.open(varied_path,FileAccess.WRITE); varied_writer.store_string(JSON.stringify(shell.session.document().to_data(),"\t",true,true)); varied_writer.close()
	var replay_output: Array = []
	OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://scripts/map_authoring/synthesis/headless.gd","--","replay",varied_path,"1"],replay_output,true)
	var cli_replay: Dictionary = {}
	for line: String in "\n".join(replay_output).split("\n"):
		if line.begins_with("MAP_SYNTHESIS_REPLAY "): cli_replay = JSON.parse_string(line.trim_prefix("MAP_SYNTHESIS_REPLAY "))
	check("cli_replays_the_same_receipt",cli_replay.get("reproduced",false) and cli_replay.get("result_content_hash","") == ax_replay.get("result_content_hash","-"))
	shell.session.undo(); await frames()
	check("one_undo_restores_the_piece",shell.session.document().semantic_hash() == base_hash and not shell.session.can_undo())
	# 5. Cancel and stale preview leave the piece alone.
	preview_button.pressed.emit(); button(section,"Cancelar variação").pressed.emit()
	await wait_job(section)
	check("cancel_leaves_no_preview",section.pending.is_empty() and terrain.status.text == "Operação cancelada." and shell.session.document().semantic_hash() == base_hash)
	preview_button.pressed.emit(); await wait_job(section)
	var previewed: bool = section.pending.get("ok",false)
	terrain.apply_operation("layer/protection",{"layer_id":"a_ground","region_ids":["woods_clearing"]}); await frames()
	var changed_hash: String = shell.session.document().semantic_hash()
	button(section,"Aplicar variação").pressed.emit(); await frames()
	check("stale_preview_is_dropped",previewed and changed_hash != base_hash and shell.session.document().semantic_hash() == changed_hash and section.pending.is_empty())
	finish()
static func _without_revision(value: Dictionary) -> Dictionary:
	var copy := value.duplicate(true); copy.erase("revision"); return copy
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(entry: Dictionary) -> bool: return entry.ok)
	print("F9_SYNTH_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
