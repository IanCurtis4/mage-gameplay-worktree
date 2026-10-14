extends SceneTree
## The preparation menu uses the same reviewable inventory transaction as a run.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var base_directory := OS.get_environment("RAGRPG_TEST_DIRECTORY")
	if base_directory.is_empty():
		base_directory = ProjectSettings.globalize_path("res://.godot/verification")
	var directory := base_directory.path_join("e06_ui_profile_%d" % Time.get_ticks_usec())
	var facade := ProfileFacade.new(ProfileStore.new(directory, ProfileCatalog.pilot()))
	var opened := facade.open_profile()
	_check(opened.get("ok", false), "isolated profile opens")
	if not opened.get("ok", false):
		_finish()
		return
	var created := facade.create_character("ui-profile-create", facade.current_profile().revision, "Heroína", &"swordsman")
	if not created.get("ok", false): print("Profile setup error: ", created)
	_check(created.get("ok", false), "character with starter equipment is created")
	if not created.get("ok", false):
		_finish()
		return
	var character_id: String = created["character_id"]
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	menu._open_inventory_panel()
	await process_frame
	await process_frame
	var panel := menu.inventory_panel
	_check(panel != null and panel.visible and panel.bag_tabs.get_tab_count() == 4, "menu opens four-tab inventory")
	_check(panel.slots.item_count == 14 and panel.slot_buttons.size() == 14, "menu inventory shows fourteen positions")
	var described := BuildPresentation.describe_profile(facade, character_id)
	_check(described.get("ok", false) and described["inventory_label"] == "Cartas permanentes" and described["inventory"]["owned"].is_empty(), "empty permanent card inventory is explicit")
	var before := facade.current_profile()
	var previous_revision := before.revision
	var result := panel.propose({"kind": &"unequip", "slot": &"main_hand"})
	_check(result.get("ok", false) and result["intent"]["profile_revision"] == previous_revision and not result["intent"].has("character_id"), "captured profile intent has only permitted keys")
	_check(facade.current_profile().revision == previous_revision, "preview does not save")
	if result.get("ok", false):
		var committed := panel.confirm_change()
		_check(committed.get("ok", false) and facade.current_profile().revision == previous_revision + 1 and facade.current_profile().character_by_id(character_id).equipped[&"main_hand"] == null, "confirm persists exact unequip")
	panel.dismiss()
	_check(not panel.visible and menu.equipment_selectors[&"main_hand"].get_item_metadata(menu.equipment_selectors[&"main_hand"].selected) == null, "closing refreshes legacy preset selector")
	menu.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	print("E06 inventory profile panel: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
