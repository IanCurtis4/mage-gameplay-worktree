@tool
extends EditorPlugin
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
var checks: Array[Dictionary] = []
var _sentinel := 0

func _enter_tree() -> void: _run.call_deferred()
func check(id: String, ok: bool) -> void: checks.append({"id": id, "ok": ok})

func _run() -> void:
	await get_tree().process_frame
	var history := get_undo_redo()
	history.create_action("Ação alheia ao documento")
	history.add_do_property(self, "_sentinel", 1)
	history.add_undo_property(self, "_sentinel", 0)
	history.commit_action()
	check("global_sentinel_committed", _sentinel == 1)
	for cycle: int in 2:
		EditorInterface.set_plugin_enabled("ragrpg_map_editor", true)
		await get_tree().process_frame
		EditorInterface.set_main_screen_editor("Mapas")
		await get_tree().process_frame
		var shell: Control
		for child: Node in EditorInterface.get_editor_main_screen().get_children():
			if child.get_script() == Shell: shell = child
		check("plugin_enabled_" + str(cycle), shell != null and shell.visible)
		if shell == null: break
		shell.focus_primary()
		check("focus_" + str(cycle), shell.title_edit.has_focus())
		shell.add_layer()
		var data: Dictionary = shell.session.document().to_data()
		check("shell_add_" + str(cycle), data.layers.size() == 1 and shell.layers.item_count == 1)
		shell.layers.select(0)
		shell.duplicate_layer()
		data = shell.session.document().to_data()
		check("shell_duplicate_" + str(cycle), data.layers.size() == 2 and data.layers[0].layer_id != data.layers[1].layer_id)
		shell.layers.select(0)
		shell.toggle_layer_lock()
		check("shell_lock_" + str(cycle), shell.session.document().to_data().layers[0].locked)
		shell.rename_document("Clareira de teste")
		check("shell_rename_" + str(cycle), shell.title_edit.text == "Clareira de teste")
		shell.session.undo()
		shell.session.redo()
		check("shell_history_" + str(cycle), shell.session.document().to_data().name == "Clareira de teste" and _sentinel == 1)
		shell.undo_button.pressed.emit()
		check("undo_button_" + str(cycle), shell.session.document().to_data().name != "Clareira de teste")
		shell.redo_button.pressed.emit()
		check("redo_button_" + str(cycle), shell.title_edit.text == "Clareira de teste")
		var path: String = shell.recovery_root.path_join("ui_" + str(cycle) + ".json")
		check("shell_save_" + str(cycle), shell.save_path(path).ok and not shell.session.dirty())
		shell.rename_document("Rascunho recuperável")
		check("shell_autosave_" + str(cycle), shell.preserve_draft() and Store.recover(path, "autosave").data.name == "Rascunho recuperável")
		var before: String = shell.session.document().semantic_hash()
		check("shell_reject_open_" + str(cycle), not shell.open_path(path + ".missing").ok and shell.session.document().semantic_hash() == before)
		check("shell_reopen_" + str(cycle), shell.open_path(path).ok and shell.title_edit.text == "Clareira de teste")
		shell.title_edit.text = "Nome ainda em edição"
		check("save_commits_name_" + str(cycle), shell.save_path(path).ok and Store.load_source(path).data.name == "Nome ainda em edição")
		shell.title_edit.text = "Trabalho não salvo"
		shell.request_new()
		check("new_requires_preservation_" + str(cycle), shell._dialog.visible and shell.session.document().to_data().name == "Trabalho não salvo")
		shell._dialog.hide()
		shell._dialog.confirmed.emit()
		check("new_preserves_draft_" + str(cycle), Store.recover(path, "autosave").data.name == "Trabalho não salvo" and shell.session.document().to_data().name == "Peça sem título")
		shell.open_path(path)
		var recovered := Store.recover(path, "autosave")
		shell._recover_result(recovered)
		check("recovery_copy_" + str(cycle), shell.source_path.is_empty() and shell.session.document().to_data().name == "Trabalho não salvo" and Store.load_source(path).data.name == "Nome ainda em edição")
		if cycle == 1 and not OS.get_environment("M1_CAPTURE").is_empty():
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
			check("native_capture", image.save_png(OS.get_environment("M1_CAPTURE")) == OK)
		var weak: WeakRef = weakref(shell)
		EditorInterface.set_plugin_enabled("ragrpg_map_editor", false)
		await get_tree().process_frame
		check("plugin_freed_" + str(cycle), weak.get_ref() == null)
	var global_history := history.get_history_undo_redo(0)
	check("global_history_preserved", global_history.has_undo())
	global_history.undo()
	check("global_undo_preserved", _sentinel == 0)
	global_history.redo()
	check("global_redo_preserved", _sentinel == 1)
	var ok := true
	for entry: Dictionary in checks:
		if not entry.ok: ok = false
	print("M1_UI_RESULT " + JSON.stringify({"ok": ok, "checks": checks, "count": checks.size()}))
	get_tree().quit(0 if ok else 1)
