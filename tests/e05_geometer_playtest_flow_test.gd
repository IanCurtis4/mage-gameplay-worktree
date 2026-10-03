extends SceneTree
## Production catalog/menu/run path, using only an isolated verification profile.

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174207"
var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_geometer_playtest_flow")
	_cleanup()
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid() and catalog.evolution_is_ready(&"mg_ar", &"mage"), "integrated production catalog exposes the completed Mage hybrid")
	var profile := ProfileState.new(PROFILE_ID)
	var first_id := IdentityIds.character_id(PROFILE_ID, 1)
	var geometer_id := IdentityIds.character_id(PROFILE_ID, 2)
	var first := CharacterState.new(first_id, "Primeiro Mago", &"mage")
	var candidate := CharacterState.new(geometer_id, "Geômetra candidato", &"mage")
	candidate.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	candidate.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	profile.characters = [first, candidate]
	profile.selected_character_id = first_id
	profile.next_character_counter = 3
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "isolated profile seeds two Mages with the candidate at base10/job20")
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var menu := load("res://scenes/character_menu.tscn").instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(1)
	_check(facade.current_profile().selected_character_id == first_id and menu.start_run_button.text.contains("Geômetra candidato"), "browsed candidate is distinct from durable selection and named in the start action")
	var opened := menu._begin_evolution_change(&"mg_ar")
	await process_frame
	await process_frame
	_check(opened["ok"] and facade.current_profile().character_by_id(geometer_id).evolution_id.is_empty(), "Geometer selection opens confirmation without prematurely saving identity")
	_check(menu.status_label.text.contains("Confirm") and menu.menu_scroll.get_global_rect().intersects(menu.confirm_evolution_button.get_global_rect()), "explicit confirmation is announced and scrolled into view")
	var capped := facade.grant_playtest_progression("g7-pending-cap", facade.current_profile().revision, geometer_id, &"job_xp", 1000)
	_check(capped["ok"] and capped["already_applied"] and facade.current_profile().character_by_id(geometer_id).job_xp_total == 4940, "unconfirmed Mage still has job20 cap")
	var confirmed := menu._confirm_evolution_change()
	var evolved: CharacterState = facade.current_profile().character_by_id(geometer_id)
	_check(confirmed["ok"] and evolved.evolution_id == &"mg_ar" and evolved.base_class_id == &"mage" and evolved.base_xp_total == 1800 and evolved.job_xp_total == 4940, "confirmed evolution preserves Mage origin and exact earned XP")
	_check(menu.roster_list.get_item_text(1).contains("Mago → Geômetra") and menu.evolution_state_label.text.contains("Evolução atual: Geômetra"), "menu distinguishes persistent origin from Geometer identity")
	var entry := facade.progression_summary(geometer_id)
	_check(entry["effective_skill_ranks"] == {&"geometer_trace": 1} and entry["evolution_skill_points_available"] == 0 and evolved.presets[0]["active_slots"].find(&"geometer_trace") < 0, "Trace R1 is free, not auto-equipped, and job20 grants no paid evolution points")
	menu.playtest_toggle.button_pressed = true
	var thousand := menu._apply_playtest_progression(&"job_xp", 1000)
	_check(thousand["ok"] and facade.progression_summary(geometer_id)["job_level"] == 22 and facade.current_profile().character_by_id(geometer_id).job_xp_total == 5940, "one +1000 job button moves evolved job20 to job22")
	var early := menu._learn_skill(&"geometer_incidence")
	_check(not early["ok"] and early["error_code"] == &"requirements_unmet" and menu.progression_skill_tree.get_node_or_null("Learn_geometer_incidence") == null, "job22 points do not bypass Incidence job23 gate or falsely expose its purchase button")
	var advanced := menu._apply_playtest_progression(&"job_xp", 500)
	_check(advanced["ok"] and facade.progression_summary(geometer_id)["job_level"] == 23 and facade.current_profile().character_by_id(geometer_id).job_xp_total == 6440, "another +500 job reaches the actual passive gate")
	var learned := menu._learn_skill(&"geometer_incidence")
	_check(learned["ok"] and facade.current_profile().character_by_id(geometer_id).purchased_skill_ranks == {&"geometer_incidence": 1}, "Incidence is purchased once its actual gate opens")
	menu._populate_build_editor(facade.current_profile().character_by_id(geometer_id))
	_select_option(menu.active_selectors[0], &"geometer_trace")
	_select_option(menu.passive_selectors[0], &"geometer_incidence")
	var saved := menu._save_build()
	_check(saved["ok"] and facade.current_profile().character_by_id(geometer_id).presets[0]["active_slots"] == [&"geometer_trace", null, null, null, null] and facade.current_profile().character_by_id(geometer_id).presets[0]["passive_slots"] == [&"geometer_incidence", null], "menu saves free Trace and paid Incidence into their distinct slot types")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var reopened := reloaded.open_profile()
	var durable: CharacterState = reopened["profile"].character_by_id(geometer_id)
	_check(reopened["ok"] and durable.evolution_id == &"mg_ar" and durable.job_xp_total == 6440 and durable.presets[0]["active_slots"][0] == &"geometer_trace" and durable.presets[0]["passive_slots"][0] == &"geometer_incidence", "identity, XP and exact build survive durable reload")
	var before_training := facade.current_profile().revision
	var training := facade.prepare_playtest_training(geometer_id)
	_check(training["ok"] and training["run_state"].build_snapshot.evolution_id == &"mg_ar" and facade.current_profile().revision == before_training and facade.current_profile().reward_session == null, "training preparation consumes the focused build without writing XP or opening a reward session")
	var started := menu._start_run()
	if started["ok"]:
		await scene_changed
		await process_frame
	var controller := current_scene as RunController
	_check(started["ok"] and started["run_state"].class_id == &"mage" and started["run_state"].build_snapshot.evolution_id == &"mg_ar" and facade.current_profile().selected_character_id == geometer_id, "normal start selects the focused Geometer and preserves Mage origin in the run")
	_check(controller != null and not controller.training_mode and controller.player.available_skill_ids() == [&"geometer_trace"] and controller.battle_controls.skill_buttons.has(&"geometer_trace"), "production dispatch/HUD expose only the equipped active")
	if controller != null:
		controller.set_process(false)
		controller.player.set_process(false)
		for enemy: CombatActor in controller.enemies:
			enemy.set_process(false)
		_check(controller.player.character_animation.actor_kind == &"geometer" and controller.player.character_animation.atlas != null and controller.player.character_animation.atlas.resource_path.ends_with("/geometer.png"), "persistent Geometer selects its own imported atlas, not the Mage fallback")
		_check(controller.geometer_casting != null and controller.geometer_element_buttons.size() == 3 and controller.geometer_onboarding != null and controller.geometer_onboarding.status_label.text.contains("Vazio"), "actual run builds geometric input and the contextual empty-state guide")
		var initial_sp := controller.player.current_sp
		controller.geometer_element_buttons[&"ice"].pressed.emit()
		_check(controller.geometer_casting.construction.grammar.selected_element == &"ice" and controller.player.current_sp == initial_sp and controller.geometer_casting.construction.vertices.is_empty(), "actual element button changes selection without spending or constructing")
		controller.battle_controls.skill_buttons[&"geometer_trace"].pressed.emit()
		_check(controller.cast_intent.active_skill == &"geometer_trace" and controller.player.current_sp == initial_sp, "HUD active button arms the proper intent without charging")
		controller.geometer_onboarding.toggle_button.pressed.emit()
		_check(controller.geometer_onboarding.help_label.visible and controller.geometer_onboarding.help_label.text.contains("job 28") and controller.cast_intent.active_skill == &"geometer_trace" and controller.player.current_sp == initial_sp, "guide expands without canceling input or affecting SP and explains the later triangle gate")
		controller._cancel_aim()
		_check(controller.cast_intent.active_skill.is_empty() and controller.geometer_casting.construction.vertices.is_empty(), "cancel aim does not silently create or collapse construction")
	if started["ok"]:
		var reward := facade.grant_reward("g7-flow-reward", facade.current_profile().revision, started["run_id"], 1, &"encounter_one")
		_check(reward["ok"] and facade.current_profile().character_by_id(geometer_id).job_xp_total == 6520 and facade.current_profile().character_by_id(first_id).job_xp_total == 0, "normal reward advances the actual run owner, never the previously selected Mage")
		var ended := facade.end_run("g7-flow-end", facade.current_profile().revision, started["run_id"], &"abandoned")
		var final_reload := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
		var final_open := final_reload.open_profile()
		_check(ended["ok"] and final_open["ok"] and final_open["profile"].reward_session == null and final_open["profile"].character_by_id(geometer_id).job_xp_total == 6520 and final_open["profile"].character_by_id(geometer_id).evolution_id == &"mg_ar", "post-run progress and Geometer identity persist after terminal save and restart")
	if controller != null:
		controller.queue_free()
	menu.queue_free()
	await process_frame
	_cleanup()
	print("E05 Geômetra playtest flow: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _select_option(selector: OptionButton, skill_id: StringName) -> void:
	for index: int in selector.item_count:
		if selector.get_item_metadata(index) == skill_id:
			selector.select(index)
			return
	_check(false, "build selector contains learned skill %s" % skill_id)

func _cleanup() -> void:
	assert(directory == ProjectSettings.globalize_path("res://.godot/verification/e05_geometer_playtest_flow"))
	if DirAccess.dir_exists_absolute(directory):
		for file_name: String in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file_name))
		DirAccess.remove_absolute(directory)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
