extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var menu: Node = (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	var facade: Variant = menu.get("facade")
	var initially_writable := not bool(menu.get("_read_only")) and facade.current_profile() != null
	(menu.get("name_input") as LineEdit).text = "Verificação F10"
	var created: Dictionary = menu.call("create_character", &"swordsman")
	var persisted := FileAccess.file_exists("user://profile.json")
	var reopened: Dictionary = facade.open_profile()
	var profile: Variant = facade.current_profile()
	var has_character: bool = profile != null and profile.characters.size() == 1
	var forest_listed := false
	if has_character:
		var panel: Node = load("res://scripts/ui/expedition/phase_selection_panel.gd").new()
		menu.add_child(panel)
		panel.call("configure", menu, profile.characters[0].character_id)
		var selector: OptionButton = panel.get("phase_choice")
		for index: int in selector.item_count:
			if selector.get_item_text(index) == "Floresta do Santuário":
				forest_listed = true
				selector.select(index)
				panel.call("_describe")
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png(OS.get_environment("F10_EVIDENCE").path_join("normal_lobby.png"))
	var result := {"menu_writable": initially_writable, "character_created": bool(created.get("ok", false)), "profile_persisted": persisted, "profile_reopened": bool(reopened.get("ok", false)), "one_character": has_character, "forest_listed": forest_listed, "user_data_dir": OS.get_user_data_dir()}
	var ok := initially_writable and bool(created.get("ok", false)) and persisted and bool(reopened.get("ok", false)) and has_character and forest_listed
	result["ok"] = ok
	print("F10_NORMAL_MENU ", JSON.stringify(result))
	menu.queue_free()
	await process_frame
	quit(0 if ok else 1)