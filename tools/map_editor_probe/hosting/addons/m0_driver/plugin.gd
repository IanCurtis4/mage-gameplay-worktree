@tool
extends EditorPlugin

var checks: Array[Dictionary] = []
var timings: Array[int] = []
var failed := false

func _enter_tree() -> void:
	Engine.set_meta("m0_state", {"entries": 0, "exits": 0})
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks.append({"name": label, "ok": condition})
	if not condition:
		failed = true
		push_error("M0: " + label)

func frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame

func _run() -> void:
	await frames(30)
	check(Engine.is_editor_hint(), "real_editor_process")
	check(ProjectSettings.get_property_list().filter(func(p: Dictionary) -> bool: return String(p.name).begins_with("autoload/")).is_empty(), "no_game_autoloads")
	for cycle: int in range(2):
		var start := Time.get_ticks_usec()
		EditorInterface.set_plugin_enabled("m0_subject", true)
		await frames(3)
		timings.append(Time.get_ticks_usec() - start)
		check(Engine.has_meta("m0_subject"), "plugin_enabled_%d" % cycle)
		if not Engine.has_meta("m0_subject"):
			finish()
			return
		var subject: EditorPlugin = Engine.get_meta("m0_subject") as EditorPlugin
		var panel: Control = subject.get("panel")
		var document: Resource = subject.get("document")
		check(document.get_script().is_tool(), "transitive_resource_tool_%d" % cycle)
		EditorInterface.set_main_screen_editor("Mapas F0")
		await frames(3)
		check(panel.is_visible_in_tree(), "own_main_screen_visible_%d" % cycle)
		var button: Button = subject.get("focus_button")
		button.grab_focus()
		check(button.has_focus(), "control_focus_%d" % cycle)
		var manager := subject.get_undo_redo()
		manager.create_action("Elevar amostra F0", UndoRedo.MERGE_DISABLE, document)
		manager.add_do_property(document, &"elevation", 2.0)
		manager.add_undo_property(document, &"elevation", 0.0)
		manager.commit_action()
		check(document.get("elevation") == 2.0, "editor_commit_%d" % cycle)
		var history_id := manager.get_object_history_id(document)
		check(history_id == 0, "external_document_history_%d" % cycle)
		var history := manager.get_history_undo_redo(history_id)
		check(history.undo() and document.get("elevation") == 0.0, "editor_undo_%d" % cycle)
		check(history.redo() and document.get("elevation") == 2.0, "editor_redo_%d" % cycle)
		if cycle == 0 and not OS.get_environment("M0_CAPTURE").is_empty():
			await RenderingServer.frame_post_draw
			var screenshot := get_window().get_texture().get_image()
			check(screenshot.save_png(OS.get_environment("M0_CAPTURE")) == OK, "native_capture_saved")
		EditorInterface.set_main_screen_editor("Script")
		await frames(2)
		check(not panel.visible, "main_screen_hidden_%d" % cycle)
		var panel_ref := weakref(panel)
		var plugin_ref := weakref(subject)
		EditorInterface.set_plugin_enabled("m0_subject", false)
		await frames(3)
		check(not Engine.has_meta("m0_subject"), "plugin_disabled_%d" % cycle)
		check(panel_ref.get_ref() == null, "panel_freed_%d" % cycle)
		check(plugin_ref.get_ref() == null, "plugin_freed_%d" % cycle)
		check(not history.has_undo() and not history.has_redo(), "history_cleanup_%d" % cycle)
	var state: Dictionary = Engine.get_meta("m0_state")
	check(state.entries == 2 and state.exits == 2, "balanced_lifecycle")
	check(EditorInterface.get_editor_main_screen().find_child("M0HostingPanel", true, false) == null, "no_orphan_panel")
	finish()

func finish() -> void:
	print("M0_RESULT " + JSON.stringify({"ok": not failed, "engine": Engine.get_version_info().string, "checks": checks, "enable_including_three_frames_us": timings, "mode": DisplayServer.get_name()}))
	get_tree().quit(1 if failed else 0)
