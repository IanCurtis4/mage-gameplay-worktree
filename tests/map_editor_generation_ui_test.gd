@tool
extends EditorPlugin
const Parent = preload("res://scripts/map_authoring/composition/map_panel.gd")
const GenerationPanel = preload("res://scripts/map_authoring/generation/generation_panel.gd")
const Fixture = preload("res://tests/map_editor_generation_test.gd")
const Document = preload("res://scripts/map_authoring/generation/generation_document.gd")
const Solver = preload("res://scripts/map_authoring/generation/generation_solver.gd")
const Store = preload("res://scripts/map_authoring/generation/generation_store.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
var checks: Array = []
func _enter_tree() -> void: run.call_deferred()
func check(id: String, value: bool) -> void:
	checks.append({"id":id,"ok":value}); print("M6_UI_CHECK "+id+" "+str(value))
func wait_job(panel: Control) -> void:
	var start := Time.get_ticks_msec()
	while (panel.job != null or panel.comparison_thread != null) and Time.get_ticks_msec()-start < 120000: await get_tree().process_frame
func run() -> void:
	await get_tree().process_frame
	var parent := Parent.new(); EditorInterface.get_editor_main_screen().add_child(parent)
	var source := Fixture.fixture(); parent.session.replace(source.map); parent.open_generation(); await get_tree().process_frame
	var panel: Control = parent.generation_window.get_child(0)
	check("opens_from_composition",parent.generation_window.visible and panel.get_script() == GenerationPanel)
	check("snapshot_import",panel.source.map == source.map)
	check("experimental_default_off",not panel.enabled.button_pressed)
	panel.generate(); await wait_job(panel); check("opt_in_ui",panel.result.get("code","") == "experimental_disabled" and panel.apply_button.disabled)
	panel.slots.select(1); panel.refresh_slot(); panel.pieces.select(2); panel.add_candidate()
	check("candidate_ui",panel.source.domains[1].options.size() == 2)
	panel.slots.select(0); panel.refresh_slot(); panel.pin.button_pressed = true
	check("pin_ui","left" in panel.source.pins)
	var hash_value := Document.hash_source(panel.source); panel.undo(); panel.redo(); check("request_undo_redo",Document.hash_source(panel.source) == hash_value)
	panel.seed.text = "-9223372036854775808"; panel.seed.text_submitted.emit(panel.seed.text); check("seed_text_exact",panel.source.seed_text == "-9223372036854775808")
	panel.pieces.select(2); panel.quota_min.value = 1; panel.quota_max.value = 1; panel.set_quota()
	check("quota_ui",panel.source.quotas.size() == 1)
	panel.enabled.button_pressed = true; panel.generate(); await wait_job(panel)
	check("native_completed",panel.result.get("ok",false) and panel.job == null)
	if not panel.result.get("ok",false): print(panel.result); parent.free(); finish(); return
	check("gui_headless_equivalent",Solver.new().solve(panel.source,true).output_hash == panel.result.output_hash)
	check("before_after_preview",not panel.before_canvas.package.is_empty() and not panel.after_canvas.package.is_empty())
	check("diff_visible",panel.differences.item_count == 1 and not panel.apply_button.disabled)
	var before := Map.hash_source(parent.session.data); check("preview_not_applied",before == Map.hash_source(source.map))
	check("native_apply",panel.apply_result().ok and parent.session.data.instances[1].piece_hash == source.map.pieces[2].piece_hash)
	check("native_undo",parent.session.undo() and Map.hash_source(parent.session.data) == before)
	check("native_redo",parent.session.redo() and Map.hash_source(parent.session.data) != before)
	check("stale_reapply",panel.apply_result().code == "stale_source")
	panel._file_action = "save"; var path := ProjectSettings.globalize_path("res://.godot/m6_native_"+Crypto.new().generate_random_bytes(4).hex_encode()+".json"); panel.file_selected(path)
	check("native_save",Store.load_source(path).ok and Store.load_source(path).output_hash == Document.hash_source(panel.source))
	panel.preserve(); panel.seed.text = "2"; panel.seed.text_submitted.emit(panel.seed.text); panel.recover(); check("draft_recovery",panel.source.seed_text == "-9223372036854775808")
	var prior_draft: String = panel._draft
	panel._file_action = "open"; panel.file_selected(path); check("native_open",panel.source.seed_text == "-9223372036854775808")
	panel.preserve(); check("open_preserves_prior_draft",panel._draft != prior_draft and Store.load_source(prior_draft).ok)
	panel.generate(); panel.cancel(); await wait_job(panel); check("native_cancel",panel.result.get("code","") == "cancelled" and panel.apply_button.disabled)
	panel.compare_assembler(); await wait_job(panel); check("assembler_completes",not panel.comparison.is_empty() and panel.comparison_thread == null)
	panel.seed.text = "1"; panel.seed.text_submitted.emit(panel.seed.text); panel.generate(); await wait_job(panel)
	check("seed_history",panel.history_list.item_count >= 2)
	check("history_keeps_distinct_seeds",panel.history.back().source.seed_text == "1" and panel.history[0].source.seed_text == "-9223372036854775808")
	panel.select_history(0); check("history_restores_request",panel.source.seed_text == "-9223372036854775808" and panel.result.get("ok",false))
	await get_tree().process_frame; await get_tree().process_frame
	parent.generation_window.get_texture().get_image().save_png(OS.get_environment("M6_EVIDENCE").path_join("before.png"))
	panel.after_canvas.get_parent().current_tab = 1
	await get_tree().process_frame; await get_tree().process_frame
	var image := parent.generation_window.get_texture().get_image(); image.save_png(OS.get_environment("M6_EVIDENCE").path_join("generation.png"))
	check("capture_saved",not image.is_empty())
	parent.free(); finish()
func finish() -> void:
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("M6_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)

