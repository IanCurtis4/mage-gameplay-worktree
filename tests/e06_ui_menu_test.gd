extends SceneTree
## T4: published exemplars are edited through the normal character menu/facade.
const Historical = preload("res://tests/e06_tx_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_ui/menu_%d" % Time.get_ticks_usec())
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store)
	var first: Dictionary = facade.create_character("ui-menu-first", 0, "Primeiro", &"swordsman")
	var second: Dictionary = facade.create_character("ui-menu-second", facade.current_profile().revision, "Segundo", &"mage")
	_check(first["ok"] and second["ok"], "two independent characters created by facade")
	var profile: ProfileState = facade.current_profile()
	var published := 0
	for id: StringName in catalog.equipment_ids():
		if id not in Historical.HISTORICAL_EQUIPMENT_IDS:
			published += 1
		if profile.first_instance_for_definition(id).is_empty():
			var metadata := catalog.equipment_metadata(id)
			metadata["item_level"] = metadata.get("min_item_level", metadata["item_level"])
			_check(profile.add_equipment_instance(id, metadata)["ok"], "own published exemplar %s" % id)
	_check(published == 73 and profile.equipment_instance_ids().size() == 85, "all seventy-three added pieces coexist with historical collection")
	_check(store.commit(profile)["ok"], "isolated published collection persisted")
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu: CharacterMenu = scene.instantiate()
	menu.set_profile_facade(ProfileFacade.new(store))
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var slots := IdentityIds.equipment_slots()
	_check(menu.equipment_selectors.size() == 14 and slots.size() == 14, "menu constructs fourteen selectors")
	_check(menu.equipment_selectors[&"main_hand"] == menu.weapon_selector and menu.equipment_selectors[&"torso"] == menu.armor_selector and menu.equipment_selectors[&"accessory_1"] == menu.accessory_selector, "historic aliases point to current selectors")
	var first_id: String = menu.facade.current_profile().characters[0].character_id
	var second_id: String = menu.facade.current_profile().characters[1].character_id
	var options: Dictionary = menu.facade.available_build_options(first_id)
	_check(options["ok"] and options["equipment_by_slot"].size() == 14, "facade publishes candidates for every position")
	for slot: StringName in slots:
		var selector: OptionButton = menu.equipment_selectors.get(slot)
		_check(selector != null and selector.item_count == options["equipment_by_slot"][slot].size() + 1 and selector.get_item_metadata(0) == null, "selector %s reflects facade and allows empty" % slot)
	var head: Variant = _first_candidate(options["equipment_by_slot"][&"head"])
	var second_accessory: Variant = _other_definition(options["equipment_by_slot"][&"accessory_2"], menu.facade.current_profile().characters[0].presets[0]["equipped"][&"accessory_1"], menu.facade.current_profile())
	_check(head != null and second_accessory != null, "published head and separate accessory available")
	if head != null and second_accessory != null:
		_select_value(menu.equipment_selectors[&"head"], head)
		_select_value(menu.equipment_selectors[&"accessory_2"], second_accessory)
		var saved: Dictionary = menu._save_build()
		var after: ProfileState = menu.facade.current_profile()
		_check(saved["ok"] and after.character_by_id(first_id).presets[0]["equipped"].size() == 14, "preset saves all fourteen positions")
		_check(after.character_by_id(first_id).presets[0]["equipped"][&"head"] == head and after.character_by_id(first_id).presets[0]["equipped"][&"accessory_2"] == second_accessory, "new positions save exact exemplar identities")
		_check(after.character_by_id(second_id).presets[0]["equipped"][&"head"] == null and after.character_by_id(second_id).presets[0]["equipped"][&"accessory_2"] == null, "editing first character leaves alt unchanged")
		menu._choose_preset(1)
		var alternate: ProfileState = menu.facade.current_profile()
		_check(alternate.character_by_id(first_id).presets[0]["equipped"][&"head"] == head and alternate.character_by_id(first_id).presets[1]["equipped"][&"head"] == null, "preset switch keeps layout independent")
		menu._choose_preset(0)
		_check(_selected_value(menu.equipment_selectors[&"head"]) == head and _selected_value(menu.equipment_selectors[&"accessory_2"]) == second_accessory, "returning to preset restores exact exemplars")
		menu._select_roster_index(1)
		_check(_selected_value(menu.equipment_selectors[&"head"]) == null and _selected_value(menu.equipment_selectors[&"accessory_2"]) == null, "browsing alt does not show first character's equipment")
		menu._select_roster_index(0)
		_check(_selected_value(menu.equipment_selectors[&"head"]) == head, "browsing back restores saved selection")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	print("UI menu phase: reopen")
	var opened: Dictionary = reloaded.open_profile()
	_check(opened["ok"] and reloaded.current_profile().character_by_id(first_id).presets[0]["equipped"][&"head"] == head, "selection survives reopening isolated save")
	print("UI menu phase: dimensions")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		print("UI menu dimension: ", size)
		root.size = size
		menu._layout_panel()
		var viewport := root.get_visible_rect()
		_check(menu.menu_panel.position.x >= 0 and menu.menu_panel.position.y >= 0 and menu.menu_panel.position.x + menu.menu_panel.size.x <= viewport.size.x + 1 and menu.menu_panel.position.y + menu.menu_panel.size.y <= viewport.size.y + 1, "menu container remains inside %dx%d viewport" % [size.x, size.y])
	menu.queue_free()
	print("UI menu phase: cleanup")
	await process_frame
	print("E06 UI menu: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _first_candidate(values: Array) -> Variant:
	return null if values.is_empty() else values[0]

func _other_definition(values: Array, occupied: Variant, profile: ProfileState) -> Variant:
	var occupied_definition: StringName = &"" if occupied == null else profile.equipment_instances[StringName(occupied)].definition_id
	for id: Variant in values:
		if profile.equipment_instances[StringName(id)].definition_id != occupied_definition:
			return id
	return null

func _select_value(selector: OptionButton, value: Variant) -> void:
	for index: int in selector.item_count:
		if selector.get_item_metadata(index) == value:
			selector.select(index)
			return

func _selected_value(selector: OptionButton) -> Variant:
	return null if selector.selected < 0 else selector.get_item_metadata(selector.selected)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
