@tool
extends EditorPlugin
## Checkpoint45 (F9-07/09, P3c): three-way exchange in the real editor (piece
## screen). The piece moved after the request was exported; the review lists the
## sample conflict, the explicit choice revalidates, GUI, AX and the CLI give the
## same merged source, and applying is one undo.
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const Rooms = preload("res://tests/map_editor_root_synthesis_test.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const CONFLICT := "/layers/@ground/heights/20"
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_MERGE_UI_CHECK "+id+" "+str(ok))
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func wait_job(panel: Control) -> void:
	var limit := Time.get_ticks_msec()+120000
	while panel.job != null and Time.get_ticks_msec() < limit: await get_tree().process_frame
	await frames()
func capture(window: Window, id: String) -> void:
	await frames(); RenderingServer.force_draw(false); await frames()
	var target: Viewport = window
	while target is Window and (target as Window).is_embedded() and target.get_parent() != null: target = target.get_parent().get_viewport()
	var texture := target.get_texture()
	var image := texture.get_image() if texture != null else null
	check("capture_"+id,image != null and image.save_png(OS.get_environment("F9_EVIDENCE").path_join(id+".png")) == OK)
func heights(piece: Dictionary, values: Dictionary) -> Dictionary:
	var copy := piece.duplicate(true)
	for index: int in values: copy.layers[0].heights[index] = float(values[index])
	return copy
func run() -> void:
	await get_tree().create_timer(2).timeout
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = node
	check("native_shell",shell != null and shell.is_visible_in_tree())
	if shell == null: finish(); return
	var base: Dictionary = Rooms.piece_source()
	shell.session.replace(base); await frames()
	var panel: Control = shell.exchange_panel
	var folder := ProjectSettings.globalize_path("res://.godot/f9_exchange_merge"); DirAccess.make_dir_recursive_absolute(folder)
	var request_path := folder.path_join("request_"+Crypto.new().generate_random_bytes(4).hex_encode()+".rpx")
	var presentation: Control = shell.get_node("AuthoringPresentation"); presentation.set_mode("ax")
	var exported: Dictionary = presentation.ax_invoke("piece/exchange/export",{"path":request_path,"sections":["layers"],"ids":[],"protected_paths":[],"max_changes":256,"brief":"Ajustar o relevo"})
	presentation.set_mode("ux")
	check("ax_exports_a_request",exported.get("ok",false) and FileAccess.file_exists(request_path) and not panel.request.is_empty())
	var request: Dictionary = Exchange.load_json(request_path).data
	var proposed := Exchange.propose(request,heights(base,{20:-6.0,100:12.0}))
	var proposal_path := request_path+".proposal.rpx"; Exchange.save_json(proposal_path,proposed.bundle)
	# The piece moves before the proposal comes back.
	shell.session.apply(heights(shell.session.document().to_data(),{20:8.0})); await frames()
	var local_hash: String = shell.session.document().semantic_hash()
	panel.get_parent().popup_centered(); await frames()
	panel.action = "request"; panel.file_selected(request_path)
	panel.action = "proposal"; panel.file_selected(proposal_path); await wait_job(panel)
	check("conflict_is_listed_without_mutation",panel.conflicts.size() == 1 and panel.conflicts[0].path == CONFLICT and panel.differences.item_count == 1 and panel.prepared.is_empty() and panel.apply_button.disabled and shell.session.document().semantic_hash() == local_hash)
	panel.differences.select(0); panel.select_difference(0)
	check("conflict_shows_three_values_and_choices","Versão atual" in panel.details.text and "Proposta" in panel.details.text and not panel.choice.disabled and not panel.choice.is_item_disabled(2))
	panel.choice.select(2); panel.set_choice(2)
	var revalidate: Button
	for node: Node in panel.find_children("*","Button",true,false):
		if (node as Button).text == "Revalidar com as escolhas": revalidate = node
	revalidate.pressed.emit(); await wait_job(panel)
	var gui: Dictionary = panel.prepared
	check("choice_revalidates_the_merge",gui.get("ok",false) and gui.has("merge") and "combinada" in panel.status.text and gui.source.layers[0].heights[20] == -6.0 and gui.source.layers[0].heights[100] == 12.0 and not panel.apply_button.disabled)
	await capture(panel.get_parent(),"exchange_merge_review")
	presentation.set_mode("ax")
	var ax: Dictionary = presentation.ax_invoke("piece/exchange/review",{"request_path":request_path,"proposal_path":proposal_path,"resolutions":{CONFLICT:"proposal"}})
	check("ax_review_has_the_gui_hash",ax.get("ok",false) and ax.source_hash == gui.source_hash and ax.output_hash == gui.output_hash and not ax.has("source"))
	var current_path := folder.path_join("current.json"); var choices_path := folder.path_join("choices.json"); var out_path := folder.path_join("merged_"+Crypto.new().generate_random_bytes(4).hex_encode()+".json")
	for path: String in [current_path,choices_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	Exchange.save_json(current_path,shell.session.document().to_data()); Exchange.save_json(choices_path,{CONFLICT:"proposal"})
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://scripts/map_authoring/exchange/headless.gd","--","merge",request_path,proposal_path,current_path,out_path,choices_path],output,true)
	var written := Schema.read(FileAccess.get_file_as_bytes(out_path)) if FileAccess.file_exists(out_path) else {"ok":false}
	check("cli_merge_has_the_gui_hash",code == 0 and written.ok and written.output_hash == gui.source_hash)
	var stale: Dictionary = presentation.ax_invoke("piece/exchange/apply",{"request_path":request_path,"proposal_path":proposal_path,"resolutions":{CONFLICT:"proposal"},"expected_current_hash":"0".repeat(64)})
	check("ax_apply_refuses_a_stale_source",stale.get("code","") == "stale_source" and shell.session.document().semantic_hash() == local_hash)
	presentation.set_mode("ux")
	# AX loaded the files into the same panel state; the GUI reviews again before applying.
	panel.review(); await wait_job(panel)
	var applied: Dictionary = panel.apply_result()
	var after: Dictionary = shell.session.document().to_data()
	var undone: bool = shell.session.undo()
	check("gui_apply_is_one_undo",applied.get("ok",false) and after.layers[0].heights[20] == -6.0 and after.layers[0].heights[100] == 12.0 and undone and shell.session.document().semantic_hash() == local_hash)
	panel.get_parent().hide()
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(entry: Dictionary) -> bool: return entry.ok)
	print("F9_MERGE_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
