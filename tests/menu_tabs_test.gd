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
	_check(menu.create_panel.visible and not menu.create_toggle.visible and menu.action_editor.library.get_child_count() == 0 and menu.action_editor.slot_buttons.size() == 24, "empty profile exposes creation and an empty action library")
	menu.name_input.text = "Iara"
	_check(menu.create_character(&"mage")["ok"], "create isolated mage")
	menu.name_input.text = "Téo"
	_check(menu.create_character(&"swordsman")["ok"], "create isolated alternate")
	menu._select_roster_index(0)
	_check(not menu.create_panel.visible and menu.create_toggle.visible, "creation collapses once a character exists")
	_check(menu.evolution_options_list.get_child_count() == 0, "evolution choices hidden before gate")
	var spiritualist_metadata := _skill_option(menu.skill_window, &"spiritualist_echo_curse")
	_check(not spiritualist_metadata.is_empty() and not menu.skill_window.skill_entries.has(&"spiritualist_echo_curse"), "all published branches are in the dataset while the base-job view remains focused")
	menu.skill_window._choose_job(&"spiritualist")
	var locked_branch: Dictionary = menu.skill_window.skill_entries[&"spiritualist_echo_curse"]
	_check(not locked_branch.is_empty() and locked_branch["plus"].disabled, "an unselected evolution branch stays visible on its job tab with purchase blocked")
	menu.skill_window._choose_job(&"")
	var fireball_entry: Dictionary = menu.skill_window.skill_entries[&"fireball"]
	_check(not fireball_entry.is_empty() and fireball_entry["plus"].disabled, "base-job skills remain visible while their rank purchase is blocked for lack of points")
	menu.playtest_toggle.button_pressed = true
	_check(menu._apply_playtest_progression(&"prepare_evolution")["ok"], "admin progression uses facade")
	menu.playtest_toggle.button_pressed = false
	_check(menu.evolution_options_list.get_node_or_null("ChooseEvolution_spiritualist") != null and menu.evolution_options_list.get_node_or_null("ChooseEvolution_mg_ar") != null and menu.evolution_options_list.get_node_or_null("ChooseEvolution_mg_sw") == null, "gate exposes implemented choices, including Geometer, but not remaining placeholders")
	_check(menu._begin_evolution_change(&"spiritualist")["ok"] and menu.menu_tabs.current_tab == 2, "confirmation opens in the class tab")
	_check(menu._confirm_evolution_change()["ok"], "choose evolution")
	_check(menu.evolution_options_list.get_child_count() == 0 and not menu.confirm_evolution_button.get_parent().visible, "evolution selection disappears after choice")
	menu.skill_window._choose_job(&"spiritualist")
	var entry_skill: Dictionary = menu.skill_window.skill_entries[&"spiritualist_echo_curse"]
	var late_skill: Dictionary = menu.skill_window.skill_entries[&"spiritualist_dissipation"]
	_check(entry_skill["option"]["rank"] == 1 and late_skill["option"]["rank"] == 0 and late_skill["plus"].disabled, "entry rank and future job-gated skills are all visible with their canonical states")
	menu.menu_tabs.current_tab = 1
	menu.skill_window.skill_entries[&"spiritualist_echo_curse"]["button"].grab_focus()
	var navigation := InputEventAction.new()
	navigation.action = &"ui_down"
	navigation.pressed = true
	menu._unhandled_key_input(navigation)
	_check(menu._selected_index == 0, "keyboard navigation focused on a skill cannot change the selected character")
	var view_switch := menu.skill_window.skill_panel.get_node("ViewSwitch") as Button
	view_switch.pressed.emit()
	_check(not menu.skill_window._tree and menu.skill_window.skill_entries.has(&"spiritualist_dissipation"), "list view preserves visible future skills on the selected job tab")
	view_switch.pressed.emit()
	_check(menu._learn_skill(&"fireball")["ok"], "learn base skill through menu")
	menu.action_editor.assign_skill(&"fireball", 0)
	var profile: ProfileState = facade.current_profile()
	var mage_id: String = profile.characters[0].character_id
	_check(profile.character_by_id(mage_id).action_slots[0] == &"fireball", "action layout persists independently of legacy presets")
	store.fail = true
	menu.action_editor.clear_slot(0)
	_check(menu.action_editor.action_slots[0] == &"fireball" and menu.status_label.text.contains("Nenhuma alteração"), "save failure restores committed shortcut and reports error")
	store.fail = false
	menu._choose_preset(1)
	_check(menu.action_editor.action_slots[0] == &"fireball", "changing equipment preset preserves the character action layout")
	menu._choose_preset(0)
	_check(menu.action_editor.action_slots[0] == &"fireball", "returning to equipment preset retains learned shortcut")
	menu._select_roster_index(1)
	_check(menu.menu_tabs.current_tab == 1 and menu.identity_label.text.contains("Téo") and menu.skill_window.skill_entries.has(&"slash") and not menu.skill_window.skill_entries.has(&"fireball"), "alternate updates the current job library without losing the selected menu tab")
	menu._select_roster_index(0)
	menu.playtest_toggle.button_pressed = true
	_check(menu.evolution_options_list.get_node_or_null("ChooseEvolution_elementalist") != null, "admin exposes alternative evolution")
	menu._apply_playtest_progression(&"max_levels")
	menu.playtest_toggle.button_pressed = false
	_check(menu.evolution_options_list.get_child_count() == 0 and not menu.playtest_panel.visible, "leaving admin restores normal disclosure")
	menu.skill_window._choose_job(&"spiritualist")
	_check(menu.skill_window.skill_entries.has(&"spiritualist_dissipation") and not menu.skill_window.skill_entries[&"spiritualist_dissipation"]["plus"].disabled, "later job gate enables the already visible exclusive skill")
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

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _skill_option(window: SkillWindow, skill_id: StringName) -> Dictionary:
	for option: Dictionary in window._options:
		if StringName(option["skill_id"]) == skill_id:
			return option
	return {}
