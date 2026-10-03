extends SceneTree
## Real menu fixtures, isolated saves; optional renderer captures with -- --capture-menu.
var failures := 0
var checks := 0

class FailingStore:
	extends ProfileStore
	var fail := false
	func _should_fail(stage: StringName) -> bool:
		return fail and stage == &"write_pending"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var directory := ProjectSettings.globalize_path("res://.godot/verification/menu_tabs_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var store := FailingStore.new(directory, ProfileCatalog.pilot())
	var facade := ProfileFacade.new(store)
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	_check(menu.menu_tabs.get_tab_count() == 3, "three preparation tabs")
	_check(menu.create_panel.visible and not menu.create_toggle.visible and menu.active_slot_a.disabled, "empty profile exposes creation and blocks build controls")
	menu.name_input.text = "Iara"
	_check(menu.create_character(&"mage")["ok"], "create isolated mage")
	menu.name_input.text = "Téo"
	_check(menu.create_character(&"swordsman")["ok"], "create isolated alternate")
	menu._select_roster_index(0)
	_check(not menu.create_panel.visible and menu.create_toggle.visible, "creation collapses once a character exists")
	_check(menu.evolution_options_list.get_child_count() == 0, "evolution choices hidden before gate")
	_check(menu.progression_skill_tree.get_node_or_null("ProgressionSkill_spiritualist_echo_curse") == null, "other branch skill hidden")
	_check(menu.progression_skill_tree.get_node_or_null("ProgressionSkill_fireball") != null and (menu.progression_skill_tree.get_node("Learn_fireball") as Button).disabled, "unlocked skills remain visible without points")
	menu.playtest_toggle.button_pressed = true
	_check(menu._apply_playtest_progression(&"prepare_evolution")["ok"], "admin progression uses facade")
	menu.playtest_toggle.button_pressed = false
	_check(menu.evolution_options_list.get_node_or_null("ChooseEvolution_spiritualist") != null and menu.evolution_options_list.get_node_or_null("ChooseEvolution_mg_ar") == null, "gate exposes implemented choices only")
	_check(menu._begin_evolution_change(&"spiritualist")["ok"] and menu.menu_tabs.current_tab == 2, "confirmation opens in the class tab")
	_check(menu._confirm_evolution_change()["ok"], "choose evolution")
	_check(menu.evolution_options_list.get_child_count() == 0 and not menu.confirm_evolution_button.get_parent().visible, "evolution selection disappears after choice")
	_check(menu.progression_skill_tree.get_node_or_null("ProgressionSkill_spiritualist_echo_curse") != null and menu.progression_skill_tree.get_node_or_null("ProgressionSkill_spiritualist_dissipation") == null, "only entry skill exposed at evolution job gate")
	menu.menu_tabs.current_tab = 1
	menu.skill_search.grab_focus()
	var navigation := InputEventAction.new()
	navigation.action = &"ui_down"
	navigation.pressed = true
	menu._unhandled_key_input(navigation)
	_check(menu._selected_index == 0, "arrow input in skill search cannot change the selected character")
	menu.skill_search.text = "zzzz"
	menu.skill_search.text_changed.emit("zzzz")
	_check(menu.skill_empty_label.visible and menu.progression_skill_tree.get_child_count() == 0, "search shows explicit empty state without revealing locked skills")
	menu.skill_search.text = ""
	menu.skill_search.text_changed.emit("")
	_check(menu._learn_skill(&"fireball")["ok"], "learn base skill through menu")
	var index := _index_of(menu.active_slot_a, &"fireball")
	menu.active_slot_a.select(index)
	menu.active_slot_a.item_selected.emit(index)
	var profile: ProfileState = facade.current_profile()
	var mage_id: String = profile.characters[0].character_id
	_check(profile.character_by_id(mage_id).presets[0]["active_slots"][0] == &"fireball", "slot selection persists without leaving an unsaved draft")
	store.fail = true
	menu.active_slot_a.select(0)
	menu.active_slot_a.item_selected.emit(0)
	_check(menu._selected_option(menu.active_slot_a) == &"fireball" and menu.status_label.text.contains("Nenhuma alteração"), "save failure restores committed slot and reports error")
	store.fail = false
	menu._choose_preset(1)
	_check(menu._selected_option(menu.active_slot_a) == null, "changing preset shows its own slots")
	menu._choose_preset(0)
	_check(menu._selected_option(menu.active_slot_a) == &"fireball", "returning to saved preset retains skill")
	menu._select_roster_index(1)
	_check(menu.menu_tabs.current_tab == 1 and menu.identity_label.text.contains("Téo") and menu.progression_skill_tree.get_node_or_null("ProgressionSkill_fireball") == null, "alternate updates all tabs without losing current tab")
	menu._select_roster_index(0)
	menu.playtest_toggle.button_pressed = true
	_check(menu.evolution_options_list.get_node_or_null("ChooseEvolution_elementalist") != null, "admin exposes alternative evolution")
	menu._apply_playtest_progression(&"max_levels")
	menu.playtest_toggle.button_pressed = false
	_check(menu.evolution_options_list.get_child_count() == 0 and not menu.playtest_panel.visible, "leaving admin restores normal disclosure")
	_check(menu.progression_skill_tree.get_node_or_null("ProgressionSkill_spiritualist_dissipation") != null, "later job gate reveals exclusive skill")
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = extent
		for tab: int in 3:
			menu.menu_tabs.current_tab = tab
			await process_frame
			await process_frame
			_check(menu.get_global_rect().encloses(menu.start_run_button.get_global_rect()), "run button inside viewport at %s tab %d" % [extent, tab])
			_check(menu.get_global_rect().encloses(menu.menu_tabs.get_global_rect()), "tabs fit at %s tab %d" % [extent, tab])
			if "--capture-menu" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				var target := "res://.godot/verification/menu_%dx%d_tab%d.png" % [extent.x, extent.y, tab]
				_check(root.get_texture().get_image().save_png(target) == OK, "capture %s" % target)
	var opened: Dictionary = ProfileFacade.new(ProfileStore.new(directory, ProfileCatalog.pilot())).open_profile()
	_check(opened["ok"], "saved profile reopens after all UI actions")
	menu.queue_free()
	await process_frame
	print("Menu tabs: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _index_of(selector: OptionButton, id: StringName) -> int:
	for index: int in selector.item_count:
		if selector.get_item_metadata(index) == id:
			return index
	return -1

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
