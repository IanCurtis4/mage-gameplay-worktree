extends "res://tests/action_bar_game_integration_test.gd"
## Independent review regressions: hidden capture and rejected RELEASE retarget.

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/action_review_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1280, 720)
	await _hidden_capture()
	await _release_over_ui()
	print("Action bar review: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _hidden_capture() -> void:
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_directory(directory.path_join("profile"))
	menu.action_preferences.path = directory.path_join("controls.cfg")
	root.add_child(menu)
	await process_frame
	menu.create_character(&"mage")
	menu.menu_tabs.current_tab = 1
	await process_frame
	_check(menu.action_editor.is_visible_in_tree(), "capture starts in visible Skills tab")
	var before := menu.action_preferences.bindings.duplicate(true)
	menu.action_editor.begin_binding_capture(0)
	menu.menu_tabs.current_tab = 0
	menu.create_panel.show()
	await process_frame
	_check(not menu.action_editor.is_visible_in_tree(), "tab switch hides capture editor")
	menu.name_input.text = ""
	menu.name_input.grab_focus()
	_unicode_key(KEY_Z, "z")
	_key(KEY_Z, false)
	_check(menu.action_preferences.bindings == before, "typing on another tab must not rebind a hidden editor")
	_check(menu.name_input.text == "z", "first letter reaches name field after tab switch")
	_check(menu.action_editor.capture_binding == -1, "hiding editor cancels capture")
	menu.queue_free()
	await process_frame

func _release_over_ui() -> void:
	var snapshot := _snapshot(&"archer", &"sentinel", [&"sentinel_piercing_shot"])
	snapshot.action_slots = ActionBarLayout.empty()
	snapshot.action_slots[0] = &"sentinel_headshot"
	snapshot.action_slots[1] = &"sentinel_piercing_shot"
	await _mount(RunState.from_build("", snapshot))
	_reset()
	_key(KEY_1, true)
	_check(controller.cast_intent.active_skill == &"sentinel_headshot", "first held key starts RELEASE aim")
	_point_screen(controller.battle_controls.slot_buttons[0].get_global_rect().get_center())
	_check(not controller._world_pointer_available(), "second key occurs over action bar")
	_key(KEY_2, true)
	_key(KEY_2, false)
	_point_world(Vector2(650, 402))
	_key(KEY_1, false)
	_check(controller.cast_intent.active_skill == &"", "rejected UI retarget cannot leave RELEASE aim stuck")
	_check(controller.action_bar_input.pending_skill == &"", "release latch cleared after both keys released")
	await _unmount()
