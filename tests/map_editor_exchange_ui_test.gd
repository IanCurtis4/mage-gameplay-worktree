@tool
extends EditorPlugin
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const Parent = preload("res://scripts/map_authoring/composition/map_panel.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
var checks: Array = []
func _enter_tree() -> void: run.call_deferred()
func check(id: String, value: bool) -> void:
	checks.append({"id":id,"ok":value}); print("M7_UI_CHECK "+id+" "+str(value))
func wait_job(panel: Control) -> void:
	var start := Time.get_ticks_msec()
	while panel.job != null and Time.get_ticks_msec()-start < 120000: await get_tree().process_frame
func run() -> void:
	await get_tree().process_frame
	var root := ProjectSettings.globalize_path("res://.godot/m7_samples")
	var parent := Parent.new(); EditorInterface.get_editor_main_screen().add_child(parent); parent.session.replace(Map.sample())
	var panel: Control = parent.exchange_panel; panel.get_parent().popup_centered(); await get_tree().process_frame
	check("mounted_native",panel.is_node_ready() and panel.get_parent().visible)
	panel.sections.text = "name"; panel.brief.text = "Renomear preservando geometria"
	var exported := root.path_join("native_"+Crypto.new().generate_random_bytes(4).hex_encode()+".rpx")
	panel.export_current(exported); await wait_job(panel)
	check("native_export",not panel.request.is_empty() and FileAccess.file_exists(exported))
	check("safe_default",panel.request.ticket.policy.sections == ["name"])
	var candidate: Dictionary = parent.session.data.duplicate(true); candidate.name = "Proposta nativa"
	var proposed := Exchange.propose(panel.request,candidate)
	check("native_proposal_compiles",proposed.ok)
	if not proposed.ok: parent.free(); finish(); return
	var incoming := exported+".proposal.rpx"; Exchange.save_json(incoming,proposed.bundle)
	panel.action = "request"; panel.file_selected(exported)
	check("trusted_request_open",panel.request.ticket.base_hash == Map.hash_source(Map.sample()))
	panel.action = "proposal"; panel.file_selected(incoming); await wait_job(panel)
	check("import_completed",panel.prepared.get("ok",false) and not panel.apply_button.disabled)
	check("diff_visible",panel.differences.item_count == 1 and panel.prepared.diff[0].path == "/name")
	panel.differences.select(0); panel.select_difference(0)
	check("before_after_values","Duas peças" in panel.details.text and "Proposta nativa" in panel.details.text)
	check("before_after_preview",not panel.before_canvas.package.is_empty() and not panel.after_canvas.package.is_empty())
	check("gui_cli_authority_hash",panel.prepared.output_hash == Exchange.prepare(panel.request,proposed.bundle,parent.session.data).output_hash)
	check("preview_no_mutation",parent.session.data.name == Map.sample().name)
	panel.apply_button.pressed.emit(); await get_tree().process_frame
	check("confirmation_required",panel.confirmation.visible and parent.session.data.name == Map.sample().name)
	panel.confirmation.hide(); var result: Dictionary = panel.apply_result()
	check("native_apply",result.ok and parent.session.data.name == "Proposta nativa")
	check("native_undo",parent.session.undo() and parent.session.data.name == Map.sample().name)
	check("native_redo",parent.session.redo() and parent.session.data.name == "Proposta nativa")
	panel.review(); await wait_job(panel); check("idempotent_disabled",panel.prepared.get("already_applied",false) and panel.apply_button.disabled)
	parent.session.undo(); panel.review(); await wait_job(panel)
	var changed: Dictionary = parent.session.data.duplicate(true); changed.name = "Edição humana"; parent.session.apply(changed)
	check("stale_commit",panel.apply_result().code == "stale_source" and parent.session.data.name == "Edição humana")
	parent.session.undo(); panel.review(); await wait_job(panel); panel.cancel()
	check("reject_no_mutation",panel.prepared.is_empty() and panel.apply_button.disabled and parent.session.data.name == Map.sample().name)
	panel.review(); panel.cancel(); check("cancel_no_commit",panel.job == null and panel.prepared.is_empty())
	# Native attachment/lifecycle for all producer screens (separate fixtures test all compilers).
	for entry: Array in [["piece","res://addons/ragrpg_map_editor/shell.gd"],["population","res://scripts/map_authoring/population/population_panel.gd"],["patrol","res://scripts/map_authoring/patrol/patrol_panel.gd"],["generation","res://scripts/map_authoring/generation/generation_panel.gd"]]:
		var screen: Control = load(entry[1]).new(); EditorInterface.get_editor_main_screen().add_child(screen); await get_tree().process_frame
		check("binding_"+entry[0],screen.exchange_panel.kind == entry[0] and screen.exchange_panel.get_source.is_valid() and screen.exchange_panel.commit_source.is_valid())
		var loaded := Exchange.load_json(root.path_join(entry[0]+".json"))
		if entry[0] == "generation": screen.source = loaded.data; screen.refresh()
		else: screen.session.replace(loaded.data)
		var child: Control = screen.exchange_panel
		child.request = Exchange.load_json(root.path_join(entry[0]+".rpx")).data
		child.proposal = Exchange.load_json(root.path_join(entry[0]+"_proposal.rpx")).data
		child.review(); await wait_job(child)
		check("review_"+entry[0],child.prepared.get("ok",false) and not child.apply_button.disabled)
		if child.prepared.get("ok",false):
			var expected: String = child.prepared.source_hash
			check("apply_"+entry[0],child.apply_result().ok)
			check("source_hash_"+entry[0],Exchange.read(entry[0],child.get_source.call()).output_hash == expected)
		screen.free()
	panel.review(); await wait_job(panel); panel.tabs.current_tab = 1; panel.select_difference(0)
	await get_tree().process_frame; await get_tree().process_frame
	var image: Image = panel.get_parent().get_texture().get_image(); image.save_png(OS.get_environment("M7_EVIDENCE").path_join("exchange.png")); check("capture_saved",not image.is_empty())
	parent.free(); finish()
func finish() -> void:
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("M7_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
