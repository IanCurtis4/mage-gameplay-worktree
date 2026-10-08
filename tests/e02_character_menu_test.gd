extends SceneTree

class ToggleFailStore:
	extends ProfileStore
	var failure_stage: StringName = &""

	func _should_fail(stage: StringName) -> bool:
		return stage == failure_stage

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
	_check(menu.roster_list.item_count == 0 and menu.empty_label.visible and menu.select_button.disabled and menu.progression_state_label.text.contains("Crie ou selecione") and menu.progression_skill_tree.get_child_count() == 0 and menu.create_buttons.size() == 3 and menu.create_buttons[2].text == "Criar Arqueiro", "empty roster has an explicit state, cannot select or render a progression tree, and exposes all available base classes")
	menu.name_input.text = "Lina"
	var swordsman: Dictionary = menu.create_character(&"swordsman")
	var mage: Dictionary = menu.create_character(&"mage")
	_check(swordsman["ok"] and mage["ok"] and menu.status_label.text == "Personagem criado." and menu.roster_list.item_count == 2 and menu.roster_list.get_item_text(0).contains("Lina") and menu.roster_list.get_item_text(1).contains("Mago"), "creation uses facade, explains success, and refreshes the real roster")
	menu._select_roster_index(1)
	_check(not menu.build_summary_label.text.contains("Bola de fogo") and menu.build_summary_label.text.contains("Vida 150") and menu.build_summary_label.text.contains("SP 85"), "roster navigation previews the chosen alt's empty skill bar and central derived stats before committing selection")
	_check(menu.progression_state_label.text.contains("XP base: 0") and menu.progression_wallets_label.text.contains("Atributos: 0/0 livres") and menu.progression_attributes_label.tooltip_text.contains("INT: base 9 · investido 0 · base + investido: teto 60 · efetivo 9 · limite efetivo 120") and menu.progression_skill_tree.get_node("ProgressionSkill_fire_spear").text.contains("Rank 0/5") and menu.progression_skill_tree.get_node("ProgressionSkill_fire_spear").tooltip_text.contains("arraste para organizar atalhos"), "progression panel reads XP, wallet, caps, rank-zero skills, and action library guidance")
	var preset_changed: Dictionary = menu._choose_preset(1)
	_check(preset_changed["ok"] and menu.status_label.text == "Preset selecionado." and menu.facade.current_profile().characters[1].selected_preset == 1, "preset selection persists through the facade without editing build fields directly")
	var build_saved: Dictionary = menu._save_build()
	var saved_mage: Variant = menu.facade.current_profile().characters[1]
	_check(build_saved["ok"] and menu.status_label.text == "Preset salvo." and saved_mage.presets[1]["active_slots"] == [null, null, null, null, null], "an empty skill bar is saved atomically through update_preset")
	var selected: Dictionary = menu.select_character_at(0)
	var profile: Variant = menu.facade.current_profile()
	_check(selected["ok"] and menu.status_label.text == "Personagem selecionado." and profile.selected_character_id == profile.characters[0].character_id and menu.roster_list.get_item_text(0).contains("padrão") and not menu.build_summary_label.text.contains("Corte") and not menu.start_run_button.disabled, "selection persists through facade, exposes the empty build, and enables an explicit run start")
	_check(menu.progression_attributes_label.tooltip_text.contains("FOR: base 8 · investido 0 · base + investido: teto 60 · efetivo 8 · limite efetivo 120") and menu.progression_skill_tree.get_node_or_null("ProgressionSkill_slash") != null and menu.progression_skill_tree.get_node_or_null("ProgressionSkill_fireball") == null, "progression panel follows the browsed character instead of retaining another alt's class tree")
	var running_profile: ProfileState = menu.facade.current_profile()
	running_profile.reward_session = {"run_id": "test"}
	menu._refresh_progression_panel(running_profile.characters[0], running_profile)
	_check(menu.progression_state_label.text.contains("Run ativa") and menu.progression_skill_tree.get_child_count() > 0, "active-run progression remains visible as a read-only consultation")
	menu._refresh()
	var viewport := get_root().get_viewport().get_visible_rect()
	var editor_initialized := true
	var editor_controls: Array[Control] = [menu.preset_selector, menu.weapon_selector, menu.armor_selector, menu.accessory_selector, menu.save_build_button]
	for button: Button in menu.action_editor.slot_buttons:
		editor_controls.append(button)
	for control: Control in editor_controls:
		editor_initialized = editor_initialized and control.get_global_rect().size.y > 0.0
	_check(menu.active_selectors.is_empty() and menu.passive_selectors.is_empty() and menu.action_editor.slot_buttons.size() == 24 and menu.automatic_passives_label.text.contains("todas automáticas") and viewport.encloses(menu.get_global_rect()) and menu.roster_list.get_global_rect().size.y >= 96.0 and menu.select_button.get_global_rect().size.y > 0.0 and editor_initialized and menu.menu_scroll != null and viewport.encloses(menu.start_run_button.get_global_rect()), "menu exposes 24 action slots and automatic passive state without old equip selectors, preserving scroll and run access")
	_check(menu._error_text(&"invalid_loadout", false).contains("build") and menu._error_text(&"recovery_required", false).contains("gravação pendente"), "start failures explain how the player can resolve the state")
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
	_check(blocked.status_label.text.contains("somente leitura") and blocked.create_buttons[0].disabled and blocked.create_buttons[1].disabled and blocked.create_buttons[2].disabled and blocked.select_button.disabled and blocked.progression_state_label.text.contains("indisponível"), "read-only profile state is explained and blocks every roster mutation or progression consultation")
	_check(blocked.start_run_button.disabled, "read-only profile cannot start a run")
	blocked.queue_free()
	await _check_attribute_controls(scene)
	await _check_skill_controls(scene)
	await _check_focused_alt_progression(scene)
	_cleanup_directory(root_directory)
	print("Menu E02.1: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_attribute_controls(scene: PackedScene) -> void:
	var directory := root_directory.path_join("attribute_controls")
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	var profile := ProfileState.new("123e4567-e89b-42d3-a456-426614174000")
	var character_id := IdentityIds.character_id(profile.profile_id, 1)
	var character := CharacterState.new(character_id, "Pontos", &"swordsman")
	character.base_xp_total = 100
	var slots := catalog.initial_skill_slots(&"swordsman")
	for preset: Dictionary in character.presets:
		preset["active_slots"] = slots["active_slots"].duplicate(true)
		preset["passive_slots"] = slots["passive_slots"].duplicate(true)
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	var seeded := ProfileStore.new(directory, catalog).commit(profile)
	var store := ToggleFailStore.new(directory, catalog)
	var menu: Variant = scene.instantiate()
	menu.set_profile_facade(ProfileFacade.new(store))
	root.add_child(menu)
	await process_frame
	_check(menu.attribute_increment_buttons.size() == 6 and menu.respec_attributes_button != null and not menu.attribute_increment_buttons[&"str"].disabled, "attribute controls expose one facade-backed action for each canonical primary stat")
	store.failure_stage = &"write_pending"
	var failed: Dictionary = menu._allocate_attribute(&"str")
	store.failure_stage = &""
	var retried: Dictionary = menu._allocate_attribute(&"str")
	var after_retry: ProfileState = menu.facade.current_profile()
	_check(not failed["ok"] and failed["error_code"] == &"save_failed" and retried["ok"] and failed["request_id"] == retried["request_id"] and after_retry.revision == seeded["new_revision"] + 1 and after_retry.character_by_id(character_id).attribute_allocations[&"str"] == 1, "a definite attribute-save failure retries the original request ID and revision exactly once")
	var respec: Dictionary = menu._respec_attributes()
	_check(respec["ok"] and menu.status_label.text == "Atributos redistribuídos." and menu.facade.current_profile().character_by_id(character_id).attribute_allocations[&"str"] == 0 and menu.progression_attributes_label.tooltip_text.contains("FOR: base 8 · investido 0 · base + investido: teto 60"), "attribute respec uses the facade and refreshes the canonical preview")
	# FOR8 ->13 costs12 of the 13 points at base2; next increment costs3.
	for _index: int in 5:
		menu._allocate_attribute(&"str")
	var no_points: Dictionary = menu._allocate_attribute(&"str")
	_check(not no_points["ok"] and no_points["error_code"] == &"insufficient_points" and menu.status_label.text.contains("pontos") and menu.facade.current_profile().character_by_id(character_id).attribute_allocations[&"str"] == 5, "attribute errors remain pt-BR UI messages and never mutate the character directly")
	menu.queue_free()

func _check_skill_controls(scene: PackedScene) -> void:
	var directory := root_directory.path_join("skill_controls")
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot({}, {
		&"heavy_slash": {
			"allowed_base_classes": [&"swordsman"],
			"category": ProfileCatalog.ACTIVE,
			"wallet": ProfileCatalog.BASE_WALLET,
			"free_rank": 0,
			"max_purchased_rank": 5,
			"rank_requirements": {1: {"job_level": 5, "skill_ranks": {&"slash": 3}}},
		},
	})
	var profile := ProfileState.new("123e4567-e89b-42d3-a456-426614174001")
	var character_id := IdentityIds.character_id(profile.profile_id, 1)
	var character := CharacterState.new(character_id, "Ranks", &"swordsman")
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	var slots := catalog.initial_skill_slots(&"swordsman")
	for preset: Dictionary in character.presets:
		preset["active_slots"] = slots["active_slots"].duplicate(true)
		preset["passive_slots"] = slots["passive_slots"].duplicate(true)
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	var seeded := ProfileStore.new(directory, catalog).commit(profile)
	var store := ToggleFailStore.new(directory, catalog)
	var menu: Variant = scene.instantiate()
	menu.set_profile_facade(ProfileFacade.new(store))
	root.add_child(menu)
	await process_frame
	var slash_button: Button = menu.progression_skill_tree.get_node("Learn_slash")
	_check(menu.respec_skills_button != null and not slash_button.disabled and menu.progression_skill_tree.get_node_or_null("ProgressionSkill_heavy_slash") == null, "unmet skill prerequisites hide the skill even when job and point wallet are sufficient")
	store.failure_stage = &"write_pending"
	var failed: Dictionary = menu._learn_skill(&"slash")
	store.failure_stage = &""
	var retried: Dictionary = menu._learn_skill(&"slash")
	var after_retry: ProfileState = menu.facade.current_profile()
	_check(not failed["ok"] and failed["error_code"] == &"save_failed" and retried["ok"] and failed["request_id"] == retried["request_id"] and after_retry.revision == seeded["new_revision"] + 1 and after_retry.character_by_id(character_id).purchased_skill_ranks[&"slash"] == 1, "a definite skill-save failure retries the original request ID and revision exactly once")
	var respec: Dictionary = menu._respec_skills()
	_check(respec["ok"] and menu.status_label.text == "Skills redistribuídas." and menu.facade.current_profile().character_by_id(character_id).purchased_skill_ranks.is_empty() and menu.progression_skill_tree.get_node("ProgressionSkill_slash").text.contains("Rank 0/5"), "skill respec uses the facade and returns purchased ranks to zero in the rendered tree")
	menu._learn_skill(&"slash")
	menu._learn_skill(&"slash")
	menu._learn_skill(&"slash")
	var unlocked: Button = menu.progression_skill_tree.get_node_or_null("Learn_heavy_slash")
	_check(unlocked != null and not unlocked.disabled, "fulfilling the prerequisite reveals the skill without reopening the menu")
	var unchanged_bar: Array[Variant] = menu.action_editor.action_slots.duplicate()
	menu.action_editor.assign_skill(&"heavy_slash", 1)
	_check(menu.action_editor.action_slots == unchanged_bar and menu.facade.current_profile().character_by_id(character_id).purchased_skill_ranks.get(&"heavy_slash", 0) == 0, "visible but unlearned skill cannot enter the shortcut library or gain rank by assignment")
	var learned_passive: Dictionary = menu._learn_skill(&"vigor")
	_check(learned_passive["ok"] and menu.progression_skill_tree.get_node("ProgressionSkill_vigor").text.contains("Passiva automática") and menu.automatic_passives_label.text.contains("Vigor") and menu.facade.current_profile().character_by_id(character_id).presets[0]["passive_slots"] == [null, null], "learned passive activates automatically without changing legacy selected-passive arrays")
	_check(menu._error_text(&"requirements_unmet", false).contains("requisitos") and menu._error_text(&"rank_cap_reached", false).contains("máximo"), "rank failures have pt-BR menu messages without new progression rules")
	menu.queue_free()

func _check_focused_alt_progression(scene: PackedScene) -> void:
	var directory := root_directory.path_join("focused_alt_progression")
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	var profile := ProfileState.new("123e4567-e89b-42d3-a456-426614174003")
	var first_id := _append_progression_character(profile, catalog, "Primeiro")
	var second_id := _append_progression_character(profile, catalog, "Segundo")
	profile.selected_character_id = first_id
	var seeded := ProfileStore.new(directory, catalog).commit(profile)
	var store := ToggleFailStore.new(directory, catalog)
	var menu: Variant = scene.instantiate()
	menu.set_profile_facade(ProfileFacade.new(store))
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(1)
	store.failure_stage = &"write_pending"
	var failed_attribute: Dictionary = menu._allocate_attribute(&"str")
	store.failure_stage = &""
	var retried_attribute: Dictionary = menu._allocate_attribute(&"str")
	var learned: Dictionary = menu._learn_skill(&"slash")
	var reset_attributes: Dictionary = menu._respec_attributes()
	var reset_skills: Dictionary = menu._respec_skills()
	var current: ProfileState = menu.facade.current_profile()
	_check(not failed_attribute["ok"] and retried_attribute["ok"] and failed_attribute["request_id"] == retried_attribute["request_id"] and learned["ok"] and reset_attributes["ok"] and reset_skills["ok"] and menu._focused_character_id == second_id and menu._selected_index == 1 and current.selected_character_id == first_id and current.character_by_id(first_id).attribute_allocations[&"str"] == 0 and current.character_by_id(first_id).purchased_skill_ranks.is_empty() and current.character_by_id(second_id).attribute_allocations[&"str"] == 0 and current.character_by_id(second_id).purchased_skill_ranks.is_empty(), "progression success, failure retry, and both respecs keep the browsed alt focused without mutating the persisted selected alt")
	menu.queue_free()
	await process_frame
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var reopened := reloaded.open_profile()
	var durable: ProfileState = reloaded.current_profile()
	_check(seeded["ok"] and reopened["ok"] and durable.selected_character_id == first_id and durable.character_by_id(first_id).attribute_allocations[&"str"] == 0 and durable.character_by_id(first_id).purchased_skill_ranks.is_empty() and durable.character_by_id(second_id).attribute_allocations[&"str"] == 0 and durable.character_by_id(second_id).purchased_skill_ranks.is_empty(), "reload preserves both independent characters after focused-alt progression actions")

func _append_progression_character(profile: ProfileState, catalog: ProfileCatalog, display_name: String) -> String:
	var character_id := IdentityIds.character_id(profile.profile_id, profile.next_character_counter)
	var character := CharacterState.new(character_id, display_name, &"swordsman")
	character.base_xp_total = 100
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	var slots := catalog.initial_skill_slots(&"swordsman")
	for preset: Dictionary in character.presets:
		preset["active_slots"] = slots["active_slots"].duplicate(true)
		preset["passive_slots"] = slots["passive_slots"].duplicate(true)
	profile.characters.append(character)
	profile.next_character_counter += 1
	return character_id

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
		failures += 1
		push_error(label)
