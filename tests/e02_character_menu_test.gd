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
	_check(swordsman["ok"] and mage["ok"] and menu.roster_list.item_count == 2 and menu.roster_list.get_item_text(0).contains("Lina") and menu.roster_list.get_item_text(1).contains("Mago"), "creation uses facade and refreshes the real roster")
	menu._select_roster_index(1)
	_check(menu.build_summary_label.text.contains("Bola de fogo"), "roster navigation previews the chosen alt's persisted build before committing selection")
	var selected: Dictionary = menu.select_character_at(0)
	var profile: Variant = menu.facade.current_profile()
	_check(selected["ok"] and profile.selected_character_id == profile.characters[0].character_id and menu.roster_list.get_item_text(0).contains("selecionado") and menu.build_summary_label.text.contains("Corte"), "selection persists through facade and exposes the catalog-backed initial build")
	var viewport := get_root().get_viewport().get_visible_rect()
	_check(viewport.encloses(menu.get_global_rect()) and menu.select_button.get_global_rect().size.y > 0.0, "menu controls are laid out in the viewport")
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
