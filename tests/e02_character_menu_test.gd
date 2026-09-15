extends SceneTree

var failures := 0
var checks := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e02_character_menu")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu: Variant = scene.instantiate()
	menu.set_profile_directory(root_directory.path_join("profile"))
	root.add_child(menu)
	await process_frame
	_check(menu.roster_list.item_count == 0 and menu.empty_label.visible and menu.select_button.disabled, "empty roster has an explicit state and cannot select")
	menu.name_input.text = "Lina"
	var swordsman: Dictionary = menu.create_character(&"swordsman")
	var mage: Dictionary = menu.create_character(&"mage")
	_check(swordsman["ok"] and mage["ok"] and menu.status_label.text == "Personagem criado." and menu.roster_list.item_count == 2 and menu.roster_list.get_item_text(0).contains("Lina") and menu.roster_list.get_item_text(1).contains("Mago"), "creation uses facade, explains success, and refreshes the real roster")
	menu._select_roster_index(1)
	_check(menu.build_summary_label.text.contains("Bola de fogo") and menu.build_summary_label.text.contains("Vida 150") and menu.build_summary_label.text.contains("Mana 85"), "roster navigation previews the chosen alt's persisted build and central derived stats before committing selection")
	var preset_changed: Dictionary = menu._choose_preset(1)
	_check(preset_changed["ok"] and menu.status_label.text == "Preset selecionado." and menu.facade.current_profile().characters[1].selected_preset == 1, "preset selection persists through the facade without editing build fields directly")
	menu.active_slot_a.select(2)
	menu.active_slot_b.select(1)
	var build_saved: Dictionary = menu._save_build()
	var saved_mage: Variant = menu.facade.current_profile().characters[1]
	_check(build_saved["ok"] and menu.status_label.text == "Preset salvo." and saved_mage.presets[1]["active_slots"].slice(0, 2) == [&"fire_wall", &"fireball"], "legal skill choices are saved atomically through update_preset")
	var selected: Dictionary = menu.select_character_at(0)
	var profile: Variant = menu.facade.current_profile()
	_check(selected["ok"] and menu.status_label.text == "Personagem selecionado." and profile.selected_character_id == profile.characters[0].character_id and menu.roster_list.get_item_text(0).contains("selecionado") and menu.build_summary_label.text.contains("Corte") and not menu.start_run_button.disabled, "selection persists through facade, exposes the build, and enables an explicit run start")
	var viewport := get_root().get_viewport().get_visible_rect()
	var editor_fit := true
	for control: Control in [menu.preset_selector, menu.active_slot_a, menu.active_slot_b, menu.passive_slot, menu.weapon_selector, menu.armor_selector, menu.accessory_selector, menu.save_build_button]:
		editor_fit = editor_fit and viewport.encloses(control.get_global_rect())
	_check(viewport.encloses(menu.get_global_rect()) and menu.select_button.get_global_rect().size.y > 0.0 and editor_fit and menu.menu_scroll != null and viewport.encloses(menu.start_run_button.get_global_rect()), "menu editor scrolls independently and the run action stays visible in the viewport")
	_check(menu._error_text(&"invalid_loadout", false).contains("skill ativa") and menu._error_text(&"recovery_required", false).contains("gravação pendente"), "start failures explain how the player can resolve the state")
	menu.queue_free()
	var blocked_directory := root_directory.path_join("blocked_profile")
	DirAccess.make_dir_recursive_absolute(blocked_directory)
	var future_file := FileAccess.open(blocked_directory.path_join(ProfileStore.PRIMARY_FILE), FileAccess.WRITE)
	future_file.store_string(JSON.stringify({"schema_version": 99}))
	future_file.close()
	var blocked: Variant = scene.instantiate()
	blocked.set_profile_facade(ProfileFacade.new(ProfileStore.new(blocked_directory)))
	root.add_child(blocked)
	await process_frame
	_check(blocked.status_label.text.contains("somente leitura") and blocked.create_buttons[0].disabled and blocked.create_buttons[1].disabled and blocked.select_button.disabled, "read-only profile state is explained and blocks every roster mutation")
	_check(blocked.start_run_button.disabled, "read-only profile cannot start a run")
	blocked.queue_free()
	_cleanup_directory(root_directory)
	print("Menu E02.1: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _cleanup_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	for child: String in directory.get_directories():
		_cleanup_directory(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		push_error(label)
