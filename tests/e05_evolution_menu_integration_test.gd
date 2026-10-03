extends SceneTree

class ToggleFailStore:
	extends ProfileStore
	var failure_stage: StringName = &""

	func _should_fail(stage: StringName) -> bool:
		return stage == failure_stage

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174051"

var failures := 0
var checks := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e05_evolution_menu")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	await _check_production_unavailable_and_run_message(scene)
	await _check_confirmation_cancel_and_first_choice(scene)
	await _check_switch_retry_and_focused_alt(scene)
	await _check_cancelled_retry_is_discarded(scene)
	await _check_run_active_and_read_only_states(scene)
	_cleanup_directory(root_directory)
	print("E05-S1C seletor de evolução: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_production_unavailable_and_run_message(scene: PackedScene) -> void:
	var directory := root_directory.path_join("production_unavailable")
	_prepare_directory(directory)
	var catalog := ProfileCatalog.pilot()
	var profile := _profile_with_character(catalog, "Produção", &"defender", false)
	var character_id: String = profile.characters[0].character_id
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "production-unavailable menu fixture is durably seeded")
	var menu: CharacterMenu = await _open_menu(scene, ProfileFacade.new(ProfileStore.new(directory, catalog)))
	_check(menu.evolution_panel != null and menu.evolution_state_label.text.contains("Origem: Espadachim") and menu.evolution_state_label.text.contains("Evolução atual: Defendente"), "summary retains the chosen evolution")
	_check(menu.evolution_options_list.get_child_count() == 0 and not menu.confirm_evolution_button.get_parent().visible, "normal evolved character hides all choice and confirmation controls")
	var before_revision: int = menu.facade.current_profile().revision
	var started: Dictionary = menu.facade.start_run("production-defender", before_revision)
	_check(started["ok"] and started["run_state"].build_snapshot.evolution_id == &"defender" and menu.facade.current_profile().character_by_id(character_id).evolution_id == &"defender", "production Defender run starts with the persisted identity")
	menu.queue_free()

func _check_confirmation_cancel_and_first_choice(scene: PackedScene) -> void:
	var directory := root_directory.path_join("confirmation")
	_prepare_directory(directory)
	var catalog := _ready_catalog()
	var profile := _profile_with_character(catalog, "Confirmação", &"", false)
	var character_id: String = profile.characters[0].character_id
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "confirmation menu fixture is durably seeded")
	var menu: CharacterMenu = await _open_menu(scene, ProfileFacade.new(ProfileStore.new(directory, catalog)))
	var revision: int = menu.facade.current_profile().revision
	var opened := menu._begin_evolution_change(&"defender")
	_check(opened["ok"] and opened["pending_confirmation"] and menu.confirm_evolution_button.disabled == false and menu.evolution_confirmation_label.text.contains("Compras exclusivas") and menu.facade.current_profile().revision == revision, "choosing an available option only opens explicit confirmation and does not write")
	menu._cancel_evolution_change()
	_check(menu.confirm_evolution_button.disabled and menu.facade.current_profile().revision == revision and menu.facade.current_profile().character_by_id(character_id).evolution_id.is_empty(), "canceling evolution confirmation does not mutate the focused character")
	menu._begin_evolution_change(&"defender")
	var external: Dictionary = menu.facade.allocate_attributes("external-stale", revision, character_id, {&"str": 1})
	var stale: Dictionary = menu._confirm_evolution_change()
	_check(external["ok"] and not stale["ok"] and stale["error_code"] == &"stale_revision" and menu._evolution_pending.is_empty() and menu.facade.current_profile().character_by_id(character_id).evolution_id.is_empty(), "stale confirmation refreshes facade state and clears intent instead of retrying evolution with a newer revision")
	menu._begin_evolution_change(&"defender")
	var confirmed := menu._confirm_evolution_change()
	var after: CharacterState = menu.facade.current_profile().character_by_id(character_id)
	_check(confirmed["ok"] and after.evolution_id == &"defender" and menu.status_label.text.contains("Reembolso de evolução: 0") and menu.evolution_state_label.text.contains("Evolução atual: Defendente"), "confirmation calls the facade once and refreshes the current-evolution summary")
	_check(after.presets[0]["active_slots"] == [null, null, null, null, null] and menu.progression_skill_tree.get_node_or_null("ProgressionSkill_defender_entry") != null, "first choice refreshes progression and preserves empty presets instead of auto-equipping the free entry")
	_check(menu.get_global_rect().size.y > 0.0 and menu.evolution_panel.get_global_rect().size.y > 0.0 and menu.menu_scroll != null, "selector is built inside the scrollable menu with a visible layout footprint")
	menu.queue_free()

func _check_switch_retry_and_focused_alt(scene: PackedScene) -> void:
	var directory := root_directory.path_join("switch_retry_focus")
	_prepare_directory(directory)
	var catalog := _ready_catalog()
	var profile := ProfileState.new(PROFILE_ID)
	var first_id := _append_character(profile, catalog, "Persistido", &"", false)
	var second_id := _append_character(profile, catalog, "Em foco", &"defender", true)
	profile.selected_character_id = first_id
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "switch/retry focused-alt fixture is durably seeded")
	var store := ToggleFailStore.new(directory, catalog)
	var menu: CharacterMenu = await _open_menu(scene, ProfileFacade.new(store))
	menu._select_roster_index(1)
	var locked := menu._begin_evolution_change(&"berserker")
	_check(not locked["ok"] and locked["error_code"] == &"evolution_locked", "normal menu blocks switching an evolved character")
	menu.playtest_toggle.button_pressed = true
	_check(menu.evolution_state_label.text.contains("Modo admin") and not (menu.evolution_options_list.get_node("ChooseEvolution_berserker") as Button).disabled, "admin toggle exposes eligible alternative and labels its exceptional scope")
	var before_revision: int = menu.facade.current_profile().revision
	var opened := menu._begin_evolution_change(&"berserker")
	store.failure_stage = &"write_pending"
	var failed := menu._confirm_evolution_change()
	_check(opened["ok"] and not failed["ok"] and failed["error_code"] == &"save_failed" and not menu.confirm_evolution_button.disabled and menu.evolution_confirmation_label.text.contains("Berserker"), "definite save failure preserves evolution intent, confirmation and retry affordance")
	store.failure_stage = &""
	var retried := menu._confirm_evolution_change()
	var current: ProfileState = menu.facade.current_profile()
	var focused: CharacterState = current.character_by_id(second_id)
	_check(retried["ok"] and failed["request_id"] == retried["request_id"] and current.revision == before_revision + 1 and current.selected_character_id == first_id and menu._focused_character_id == second_id, "retry reuses the original request/revision and keeps the browsed alt separate from persisted selection")
	_check(focused.evolution_id == &"berserker" and focused.purchased_skill_ranks.is_empty() and focused.presets[0]["active_slots"] == [null, null, null, null, null] and focused.presets[1]["active_slots"] == [null, null, null, null, null], "successful branch switch refreshes both presets after removing only obsolete evolution ranks")
	var berserker_entry: Label = menu.progression_skill_tree.get_node_or_null("ProgressionSkill_berserker_entry")
	var defender_entry: Label = menu.progression_skill_tree.get_node_or_null("ProgressionSkill_defender_entry")
	_check(menu.evolution_state_label.text.contains("Evolução atual: Berserker") and berserker_entry != null and berserker_entry.text.contains("Rank 1/5") and defender_entry == null and menu.status_label.text.contains("Slots esvaziados: 4"), "selector refreshes summary, progression tree and exact cleanup feedback from the transaction response")
	menu.queue_free()

func _check_cancelled_retry_is_discarded(scene: PackedScene) -> void:
	var catalog := _ready_catalog()
	var directory := root_directory.path_join("cancelled_retry")
	_prepare_directory(directory)
	var profile := _profile_with_character(catalog, "Cancelar", &"", false)
	var character_id: String = profile.characters[0].character_id
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "cancelled-retry fixture is durably seeded")
	var store := ToggleFailStore.new(directory, catalog)
	var menu: CharacterMenu = await _open_menu(scene, ProfileFacade.new(store))
	menu._begin_evolution_change(&"defender")
	store.failure_stage = &"write_pending"
	var failed: Dictionary = menu._confirm_evolution_change()
	store.failure_stage = &""
	menu._cancel_evolution_change()
	var advanced: Dictionary = menu.facade.allocate_attributes("advance-after-cancel", menu.facade.current_profile().revision, character_id, {&"str": 1})
	menu._begin_evolution_change(&"defender")
	var fresh: Dictionary = menu._confirm_evolution_change()
	_check(not failed["ok"] and failed["error_code"] == &"save_failed" and advanced["ok"] and fresh["ok"] and fresh["request_id"] != failed["request_id"] and menu.facade.current_profile().character_by_id(character_id).evolution_id == &"defender", "canceling a failed confirmation discards its retry so a later explicit choice captures the new revision")
	menu.queue_free()

	var alt_directory := root_directory.path_join("cancelled_retry_alt")
	_prepare_directory(alt_directory)
	var alt_profile := ProfileState.new(PROFILE_ID)
	var first_id := _append_character(alt_profile, catalog, "Primeiro", &"", false)
	var second_id := _append_character(alt_profile, catalog, "Segundo", &"", false)
	alt_profile.selected_character_id = first_id
	_check(ProfileStore.new(alt_directory, catalog).commit(alt_profile)["ok"], "alternate focused-retry fixture is durably seeded")
	var alt_store := ToggleFailStore.new(alt_directory, catalog)
	var alt_menu: CharacterMenu = await _open_menu(scene, ProfileFacade.new(alt_store))
	alt_menu._select_roster_index(1)
	alt_menu._begin_evolution_change(&"defender")
	alt_store.failure_stage = &"write_pending"
	var alt_failed: Dictionary = alt_menu._confirm_evolution_change()
	alt_store.failure_stage = &""
	alt_menu._select_roster_index(0)
	var alt_advanced: Dictionary = alt_menu.facade.allocate_attributes("advance-alt-after-cancel", alt_menu.facade.current_profile().revision, second_id, {&"str": 1})
	alt_menu._select_roster_index(1)
	alt_menu._begin_evolution_change(&"defender")
	var alt_fresh: Dictionary = alt_menu._confirm_evolution_change()
	_check(not alt_failed["ok"] and alt_advanced["ok"] and alt_fresh["ok"] and alt_fresh["request_id"] != alt_failed["request_id"] and alt_menu.facade.current_profile().selected_character_id == first_id and alt_menu.facade.current_profile().character_by_id(second_id).evolution_id == &"defender", "changing focused alt and returning also drops a canceled retry while preserving the persisted selection")
	alt_menu.queue_free()

func _check_run_active_and_read_only_states(scene: PackedScene) -> void:
	var directory := root_directory.path_join("run_active")
	_prepare_directory(directory)
	var catalog := _ready_catalog()
	var profile := _profile_with_character(catalog, "Run", &"", false)
	var character_id: String = profile.characters[0].character_id
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "run-active menu fixture is durably seeded")
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var menu: CharacterMenu = await _open_menu(scene, facade)
	var started := facade.start_run("s1c-run", facade.current_profile().revision)
	menu._refresh()
	var run_button: Button = menu.evolution_options_list.get_node("ChooseEvolution_defender")
	var run_attempt := menu._begin_evolution_change(&"defender")
	_check(started["ok"] and run_button.disabled and not run_attempt["ok"] and run_attempt["error_code"] == &"run_active" and menu.status_label.text.contains("run ativa"), "active run makes every option read-only through facade state and explains the blocked attempt")
	menu.queue_free()

	var blocked_directory := root_directory.path_join("read_only")
	_prepare_directory(blocked_directory)
	var future_file := FileAccess.open(blocked_directory.path_join(ProfileStore.PRIMARY_FILE), FileAccess.WRITE)
	future_file.store_string(JSON.stringify({"schema_version": 99}))
	future_file.close()
	var blocked: CharacterMenu = await _open_menu(scene, ProfileFacade.new(ProfileStore.new(blocked_directory)))
	_check(blocked.evolution_state_label.text.contains("indisponível") and blocked.confirm_evolution_button.disabled and blocked.cancel_evolution_button.disabled and blocked.status_label.text.contains("somente leitura"), "read-only profile disables the evolution confirmation controls and reports the state in pt-BR")
	menu = null
	blocked.queue_free()

func _open_menu(scene: PackedScene, facade: ProfileFacade) -> CharacterMenu:
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	return menu

func _ready_catalog() -> ProfileCatalog:
	return ProfileCatalog.pilot({}, {
		&"defender_entry": _evolution_skill(ProfileCatalog.ACTIVE, 1, 4, &"defender", {1: {"job_level": 20, "skill_ranks": {}}}),
		&"defender_guard": _evolution_skill(ProfileCatalog.ACTIVE, 0, 5, &"defender"),
		&"defender_anchor": _evolution_skill(ProfileCatalog.PASSIVE, 0, 3, &"defender"),
		&"berserker_entry": _evolution_skill(ProfileCatalog.ACTIVE, 1, 4, &"berserker", {1: {"job_level": 20, "skill_ranks": {}}}),
		&"berserker_rage": _evolution_skill(ProfileCatalog.ACTIVE, 0, 5, &"berserker"),
	}, {
		&"defender": {"entry_skill_id": &"defender_entry", "exclusive_skill_ids": [&"defender_entry", &"defender_guard", &"defender_anchor"], "content_ready": true},
		&"berserker": {"entry_skill_id": &"berserker_entry", "exclusive_skill_ids": [&"berserker_entry", &"berserker_rage"], "content_ready": true},
	})

func _evolution_skill(category: StringName, free_rank: int, max_purchased_rank: int, evolution_id: StringName, requirements: Dictionary = {}) -> Dictionary:
	return {
		"allowed_base_classes": [&"swordsman"],
		"category": category,
		"wallet": ProfileCatalog.EVOLUTION_WALLET,
		"free_rank": free_rank,
		"max_purchased_rank": max_purchased_rank,
		"required_evolution_id": evolution_id,
		"rank_requirements": requirements,
	}

func _profile_with_character(catalog: ProfileCatalog, display_name: String, evolution_id: StringName, branch_build: bool) -> ProfileState:
	var profile := ProfileState.new(PROFILE_ID)
	var character_id := _append_character(profile, catalog, display_name, evolution_id, branch_build)
	profile.selected_character_id = character_id
	return profile

func _append_character(profile: ProfileState, catalog: ProfileCatalog, display_name: String, evolution_id: StringName, branch_build: bool) -> String:
	var character_id := IdentityIds.character_id(profile.profile_id, profile.next_character_counter)
	var character := CharacterState.new(character_id, display_name, &"swordsman")
	character.evolution_id = evolution_id
	character.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP if branch_build else ProgressionRules.EVOLUTION_MIN_JOB_XP
	if branch_build:
		character.purchased_skill_ranks[&"defender_entry"] = 1
		character.purchased_skill_ranks[&"defender_guard"] = 1
		character.purchased_skill_ranks[&"defender_anchor"] = 1
		character.presets[0]["active_slots"][0] = &"defender_entry"
		character.presets[0]["active_slots"][1] = &"defender_guard"
		character.presets[0]["passive_slots"][0] = &"defender_anchor"
		character.presets[1]["active_slots"][0] = &"defender_guard"
	profile.characters.append(character)
	profile.next_character_counter += 1
	return character_id

func _prepare_directory(path: String) -> void:
	_cleanup_directory(path)
	DirAccess.make_dir_recursive_absolute(path)

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

