@tool
extends EditorPlugin
const Preferences = preload("res://scripts/map_authoring/library/editor_preferences.gd")
const Library = preload("res://scripts/map_authoring/library/library_model.gd")
const Fixture = preload("res://tests/map_editor_biome_props_test.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_LIBRARY_UI_CHECK "+id+" "+str(ok))
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func capture(control: Control, id: String) -> void:
	await frames(); RenderingServer.force_draw(false); await frames()
	check("capture_"+id,control.get_viewport().get_texture().get_image().save_png(OS.get_environment("F9_EVIDENCE").path_join(id+".png")) == OK)
func run() -> void:
	await get_tree().create_timer(2).timeout
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = node
	check("native_shell",shell != null and shell.is_visible_in_tree())
	if shell == null: finish(); return
	var original: Variant = EditorInterface.get_editor_settings().get_project_metadata(Preferences.SECTION,Preferences.KEY,Preferences.empty())
	var original_valid: Variant = EditorInterface.get_editor_settings().get_project_metadata(Preferences.SECTION,Preferences.KEY+"_last_valid",Preferences.empty())
	var original_index: Variant = EditorInterface.get_editor_settings().get_project_metadata(Preferences.SECTION,Preferences.KEY+"_recovery_index",[])
	EditorInterface.get_editor_settings().set_project_metadata(Preferences.SECTION,Preferences.KEY,Preferences.empty())
	shell.session.replace(Fixture.source()); await frames()
	var hash: String = shell.session.document().semantic_hash(); var undo: bool = shell.session.can_undo()
	check("native_project_metadata_storage_bound",Preferences._reader.is_valid() and Preferences._writer.is_valid())
	check("editor_settings_use_discardable_profile",EditorInterface.get_editor_paths().get_config_dir().replace("\\","/").begins_with(ProjectSettings.globalize_path("res://.godot/discardable_profile").replace("\\","/")))
	shell.open_objects(); await frames(); var panel: Control = shell.objects_window.get_child(0)
	check("six_catalog_thumbnails",panel.palette.item_count == 6 and panel.palette.get_item_icon(0) != null)
	for i: int in panel.palette.item_count:
		if panel.palette.get_item_metadata(i) == "desert_cactus": panel.palette.select(i); panel.palette.item_selected.emit(i); break
	panel.favorite_button.pressed.emit()
	var prefs := Preferences.read()
	check("favorite_button_writes_project_metadata",prefs.ok and "prop:desert_cactus" in prefs.data.favorites and EditorInterface.get_editor_settings().get_project_metadata(Preferences.SECTION,Preferences.KEY).favorites == prefs.data.favorites)
	panel.favorites_only.button_pressed = true; await frames()
	check("favorite_filter_matches_current_palette",panel.palette.item_count == 1 and panel.palette.get_item_metadata(0) == "desert_cactus")
	var queried: Dictionary = panel.ax_command("objects/library/query",{"favorites_only":true})
	check("gui_and_ax_share_favorite_query",queried.ok and queried.entries.size() == 1 and queried.entries[0].definition_id == panel.palette.get_item_metadata(0))
	var object_presentation: Control = panel.get_node("AuthoringPresentation"); object_presentation.set_mode("ax")
	check("object_library_commands_bound_to_ax_presentation",object_presentation.ax_snapshot().commands.size() == 3 and object_presentation.ax_invoke("objects/library/query",{"favorites_only":true}).entries == queried.entries)
	object_presentation.set_mode("ux")
	check("library_controls_leave_source_and_history",shell.session.document().semantic_hash() == hash and shell.session.can_undo() == undo)
	await capture(panel,"library_favorite_palette")
	panel.favorites_only.button_pressed = false; panel.search.text = "Árvores"; panel.search.text_changed.emit(panel.search.text)
	check("portuguese_accent_search_in_native_palette",panel.palette.item_count == 1 and panel.palette.get_item_metadata(0) == "oak_tree")
	panel.search.text = ""; panel.search.text_changed.emit("")
	var category: int = panel.CATEGORIES.keys().find("structures")+1; panel.category_filter.select(category); panel.category_filter.item_selected.emit(category)
	check("category_control_filters_structure",panel.palette.item_count == 1 and panel.palette.get_item_metadata(0) == "broken_pillar")
	panel.category_filter.select(0); panel.category_filter.item_selected.emit(0)
	check("parameterized_selection_uses_existing_tool",panel.ax_command("objects/library/select",{"definition_id":"moss_boulder"}).ok and panel.selected_definition == "moss_boulder" and panel.mode.selected == 1)
	check("malformed_library_arguments_rejected",not panel.ax_command("objects/library/favorite",{"definition_id":"moss_boulder","enabled":true,"script":"bad"}).ok and not panel.ax_command("objects/library/query",{"favorites_only":1}).ok)
	panel.favorite_button.pressed.emit(); panel.favorite_button.pressed.emit()
	check("favorite_toggle_returns_to_previous_state",Preferences.read().data.favorites == prefs.data.favorites)
	shell.objects_window.hide(); var terrain: Control = shell.terrain
	var index := -1
	for i: int in terrain.preset_choice.item_count:
		if terrain.preset_choice.get_item_metadata(i) == "builtin_earth_path": index = i
	terrain.preset_choice.select(index); terrain.preset_choice.item_selected.emit(index)
	check("preset_control_applies_exact_brush_options",terrain.canvas.options == Library.preset("builtin_earth_path",Preferences.read().data).preset.options)
	check("preset_control_preserves_source_and_history",shell.session.document().semantic_hash() == hash and shell.session.can_undo() == undo)
	terrain.preset_name.text = "Caminho pessoal"; terrain.radius.value = 37; terrain.save_preset()
	var custom_id := "custom_"+Library.folded("Caminho pessoal").sha256_text().substr(0,24)
	check("native_named_preset_saved",Library.preset(custom_id,Preferences.read().data).preset.options.radius == 37)
	var presentation: Control = terrain.get_node("AuthoringPresentation"); presentation.set_mode("ax")
	var list: Dictionary = presentation.ax_invoke("terrain/presets/list")
	check("semantic_ax_commands_are_inspectable",presentation.ax_snapshot().commands.size() == 3 and list.ok and list.presets.size() == 4)
	terrain.radius.value = 100
	check("ax_apply_matches_gui_preset",presentation.ax_invoke("terrain/presets/apply",{"preset_id":custom_id}).ok and terrain.radius.value == 37 and terrain.canvas.options.radius == 37)
	var before: String = Preferences.read().hash
	var bad: Dictionary = terrain.canvas.options.duplicate(true); bad.mode = "execute"
	check("ax_bad_preset_preserves_preferences",not presentation.ax_invoke("terrain/presets/save",{"name":"Inválido","options":bad}).ok and Preferences.read().hash == before)
	check("ax_arguments_are_closed",not presentation.ax_invoke("terrain/presets/apply",{"preset_id":custom_id,"source":{}}).ok)
	var precise: Dictionary = terrain.canvas.options.duplicate(true); precise.radius = 37.125; precise.strength = 0.333; precise.hardness = 0.127; precise.target = 1.234; precise.end_height = 9.876
	var precise_id := "custom_"+Library.folded("Fracionado").sha256_text().substr(0,24)
	check("ax_fractional_preset_saved",presentation.ax_invoke("terrain/presets/save",{"name":"Fracionado","options":precise}).ok)
	var applied: Dictionary = presentation.ax_invoke("terrain/presets/apply",{"preset_id":precise_id})
	check("fractional_preset_applies_without_quantization",applied.ok and applied.options == precise and terrain.canvas.options == precise)
	check("fractional_strength_is_visible_in_field",terrain.strength.get_line_edit().text.contains("333"))
	presentation.ax_invoke("terrain/presets/apply",{"preset_id":custom_id})
	presentation.set_mode("ux"); await capture(terrain,"library_brush_presets")
	check("mode_switch_preserves_source_and_history",shell.session.document().semantic_hash() == hash and shell.session.can_undo() == undo)
	terrain.remove_preset()
	check("remove_custom_keeps_current_brush",not Library.preset(custom_id,Preferences.read().data).ok and terrain.canvas.options.radius == 37)
	await browser_checks(shell)
	var recovery_index: Array = EditorInterface.get_editor_settings().get_project_metadata(Preferences.SECTION,Preferences.KEY+"_recovery_index",[])
	for key: String in recovery_index:
		if key not in original_index: EditorInterface.get_editor_settings().set_project_metadata(Preferences.SECTION,key,null)
	EditorInterface.get_editor_settings().set_project_metadata(Preferences.SECTION,Preferences.KEY+"_recovery_index",original_index)
	EditorInterface.get_editor_settings().set_project_metadata(Preferences.SECTION,Preferences.KEY+"_last_valid",original_valid)
	EditorInterface.get_editor_settings().set_project_metadata(Preferences.SECTION,Preferences.KEY,original)
	check("project_metadata_restored",Preferences.read().data == original)
	finish()

func wait_browser(panel: Control) -> bool:
	var deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec() < deadline:
		if panel._job == null and not panel._rendering and panel._pending.is_empty() and panel._queue.is_empty(): return true
		await get_tree().create_timer(0.05).timeout
	return false

func browser_checks(shell: Control) -> void:
	var directory := OS.get_environment("F9_EVIDENCE")
	var piece_path := directory.path_join("browser_piece.json"); var map_path := directory.path_join("browser_map.json")
	var piece: Dictionary = Fixture.source(); piece.document_id = "browser_piece"; piece.name = "Clareira da biblioteca"
	var piece_bytes := JSON.stringify(piece,"",true,true).to_utf8_buffer(); IO._write(piece_path,piece_bytes); IO._write(map_path,JSON.stringify(MapDocument.sample(),"",true,true).to_utf8_buffer())
	var a := Library.register_source(piece_path,"piece"); var b := Library.register_source(map_path,"map")
	check("browser_sources_registered_passively",a.ok and b.ok and Preferences.read().data.sources.size() == 2)
	var hash: String = shell.session.document().semantic_hash()
	shell.open_library(); await frames(); var browser: Control = shell.library_window.get_child(0)
	check("native_library_window_and_categories",shell.library_window.visible and browser.palette.item_count == 17 and browser.category.item_count == 9)
	var library_presentation: Control = browser.get_node("AuthoringPresentation"); library_presentation.set_mode("ax")
	check("browser_commands_bound_to_ax_presentation",library_presentation.ax_snapshot().commands.size() == 8 and library_presentation.ax_invoke("library/query",{"category":"pieces"}).entries.size() == 1)
	library_presentation.set_mode("ux")
	var generation: int = browser._generation
	Preferences.transact({"operation":"favorite","id":"prop:moss_boulder","enabled":true}); await frames()
	var objects: Control = shell.objects_window.get_child(0); var star := false
	for i: int in objects.palette.item_count:
		if objects.palette.get_item_metadata(i) == "moss_boulder": star = objects.palette.get_item_text(i).begins_with("★")
	check("favorite_update_reaches_existing_objects_window",star and objects._preferences_seen == Preferences.read().hash and browser._generation == generation)
	var options_before: Dictionary = shell.terrain.canvas.options.duplicate(true)
	Preferences.transact({"operation":"preset_save","preset":{"id":"custom_shared","name":"Na outra janela","options":Library.builtin_presets()[0].options}}); await frames()
	var preset_found := false
	for i: int in shell.terrain.preset_choice.item_count:
		if shell.terrain.preset_choice.get_item_metadata(i) == "custom_shared": preset_found = true
	check("shared_presets_refresh_without_applying_or_restarting_preview",preset_found and shell.terrain.canvas.options == options_before and browser._generation == generation)
	var completed: bool = await wait_browser(browser)
	check("background_thumbnails_complete",completed)
	var cached_a := Library.cached_thumbnail(a.entry.source_hash,browser._environment); var cached_b := Library.cached_thumbnail(b.entry.source_hash,browser._environment)
	check("piece_and_map_have_validated_thumbnail_stamps",cached_a.ok and cached_b.ok)
	check("thumbnail_dimensions_are_bounded",cached_a.ok and cached_a.image.get_size() == Vector2i(256,192) and cached_b.ok and cached_b.image.get_size() == Vector2i(256,192))
	check("thumbnail_jobs_preserve_editor_source",shell.session.document().semantic_hash() == hash and IO.disk_hash(piece_path) == a.entry.byte_hash)
	check("library_ax_query_matches_source_registry",browser.ax_command("library/query",{"category":"pieces"}).entries.size() == 1)
	browser.select_entry(b.entry.id); await wait_browser(browser)
	check("selected_source_gets_real_preview",browser.preview.texture != null and browser.preview.texture.get_size() == Vector2(512,384))
	await capture(browser,"library_browser")
	browser.select_entry(a.entry.id); browser._process(0.0)
	check("preview_job_started_before_external_change",browser._job != null)
	var changed := piece.duplicate(true); changed.name = "Alterada durante a prévia"; IO._write(piece_path,JSON.stringify(changed,"",true,true).to_utf8_buffer())
	completed = await wait_browser(browser)
	check("obsolete_source_result_is_discarded",completed and browser.ax_command("library/jobs/status",{}).diagnostic_code == "stale_source" and not Library.cached_thumbnail(Schema.semantic_hash(changed),browser._environment).ok)
	IO._write(piece_path,piece_bytes)
	var prefs_hash: String = Preferences.read().hash
	browser.select_entry(a.entry.id); browser._process(0.0); browser.cancel_preview(); completed = await wait_browser(browser)
	check("cancel_drains_worker_without_partial_preferences",completed and browser._job == null and Preferences.read().hash == prefs_hash and IO.disk_hash(piece_path) == a.entry.byte_hash)
	var editing := piece.duplicate(true); editing.document_id = "unsaved_library_case_"+str(Time.get_ticks_usec()); editing.name = "Rascunho a preservar"; shell.session.replace(editing)
	var draft_path: String = shell._draft_path()
	browser.select_entry(a.entry.id)
	var requested: Dictionary = browser.activate_selected(true)
	check("copy_uses_existing_dirty_document_confirmation",requested.ok and requested.state == "confirmation_pending" and shell._dialog.visible and shell.session.document().to_data() == editing)
	shell._dialog.confirmed.emit(); await frames()
	var copied: Dictionary = shell.session.document().to_data(); var recovered := IO.recover(draft_path,"autosave")
	check("copy_preserves_previous_unsaved_document",recovered.ok and recovered.data == editing)
	check("copy_is_detached_with_new_identity",copied.document_id != piece.document_id and copied.document_id != editing.document_id and copied.revision == 1 and shell.source_path.is_empty() and shell.expected_hash.is_empty())
	check("copy_does_not_overwrite_library_source",IO.disk_hash(piece_path) == a.entry.byte_hash)
	browser.cancel_preview(); await wait_browser(browser)
	var loaded: Dictionary = shell._library_source(map_path,"map",false); await frames()
	var composition: Control = shell.composition_window.get_child(0)
	print("F9_LIBRARY_MAP_OPEN_STATE "+JSON.stringify({"request":loaded,"actual_document_id":composition.session.data.document_id,"actual_source_path":composition.source_path,"expected_source_path":map_path,"autosave":composition._autosave,"status":composition.status.text}))
	var normalized_map_path := map_path.replace("\\","/").simplify_path()
	check("saved_map_opens_in_its_existing_producer",loaded.ok and composition.session.data.document_id == "two_rooms" and composition.session.data.instances.size() == 2 and composition.source_path.replace("\\","/").simplify_path() == normalized_map_path and composition.expected_hash == IO.disk_hash(map_path))
	var map_before: Dictionary = composition.session.data.duplicate(true); var saved_hash: String = composition.session.saved_hash; var autosave: String = composition._autosave
	composition.session.saved_hash = ""; composition._autosave = ProjectSettings.globalize_path("res://.godot/missing_library_parent/block/draft.json")
	composition.new_map()
	check("failed_draft_preservation_refuses_replacement",composition.session.data == map_before and composition.source_path.replace("\\","/").simplify_path() == normalized_map_path)
	composition._autosave = autosave; composition.session.saved_hash = saved_hash; shell.composition_window.hide(); shell.library_window.hide()
	var valid: Dictionary = Preferences.read().data; var invalid := valid.duplicate(true); invalid.version = 99
	EditorInterface.get_editor_settings().set_project_metadata(Preferences.SECTION,Preferences.KEY,invalid)
	browser.refresh_preferences(); var content_hash: String = shell.session.document().semantic_hash()
	check("invalid_project_metadata_is_preserved_until_recovery",not Preferences.read().ok and not browser._recovery_button.disabled and EditorInterface.get_editor_settings().get_project_metadata(Preferences.SECTION,Preferences.KEY) == invalid)
	shell.library_window.popup_centered(); browser._recovery_button.pressed.emit()
	check("recovery_dialog_reviews_last_valid_counts_without_writing",browser._recovery_dialog.visible and not Preferences.read().ok and browser._recovery_dialog.dialog_text.contains(str(valid.favorites.size())))
	browser._recovery_dialog.confirmed.emit(); await frames()
	var index: Array = EditorInterface.get_editor_settings().get_project_metadata(Preferences.SECTION,Preferences.KEY+"_recovery_index",[])
	var backup: Variant = EditorInterface.get_editor_settings().get_project_metadata(Preferences.SECTION,index[-1]) if not index.is_empty() else null
	check("native_recovery_restores_valid_preferences_and_preserves_bad_copy",Preferences.read().ok and Preferences.read().data == valid and backup == invalid and shell.session.document().semantic_hash() == content_hash)
	browser.cancel_preview(); await wait_browser(browser); shell.library_window.hide()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(entry: Dictionary) -> bool: return entry.ok)
	print("F9_LIBRARY_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
