extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174100"

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e05_berserker_playtest_flow")
	if DirAccess.dir_exists_absolute(directory):
		for file_name: String in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file_name))
	else:
		DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	var profile := ProfileState.new(PROFILE_ID)
	var first_id := IdentityIds.character_id(PROFILE_ID, 1)
	var berserker_id := IdentityIds.character_id(PROFILE_ID, 2)
	var first := CharacterState.new(first_id, "Primeiro", &"swordsman")
	var berserker := CharacterState.new(berserker_id, "Candidato", &"swordsman")
	berserker.base_xp_total = 7500
	berserker.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	profile.characters = [first, berserker]
	profile.selected_character_id = first_id
	profile.next_character_counter = 3
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "isolated candidate starts at job 20 while another character is selected")
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var menu := load("res://scenes/character_menu.tscn").instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(1)
	var opened := menu._begin_evolution_change(&"berserker")
	await process_frame
	await process_frame
	_check(opened["ok"] and facade.current_profile().character_by_id(berserker_id).evolution_id.is_empty() and menu.status_label.text.contains("Confirm"), "selecting Berserker opens explicit confirmation without changing save")
	var confirmed := menu._confirm_evolution_change()
	var evolved: CharacterState = facade.current_profile().character_by_id(berserker_id)
	_check(confirmed["ok"] and evolved.evolution_id == &"berserker" and evolved.job_xp_total == 4940, "confirmation persists Berserker with earned job XP unchanged")
	_check(menu.roster_list.get_item_text(1).contains("Espadachim → Berserker") and menu.evolution_state_label.text.contains("Evolução atual: Berserker"), "roster and evolution panel expose Berserker identity")
	var at_entry := facade.progression_summary(berserker_id)
	_check(at_entry["effective_skill_ranks"].get(&"berserker_rupture", 0) == 1 and at_entry["evolution_skill_points_available"] == 0 and evolved.presets[0]["active_slots"].find(&"berserker_rupture") < 0, "Rupture R1 is free but not auto-equipped at job 20")
	menu.playtest_toggle.button_pressed = true
	var thousand := menu._apply_playtest_progression(&"job_xp", 1000)
	var at_22 := facade.progression_summary(berserker_id)
	_check(thousand["ok"] and facade.current_profile().character_by_id(berserker_id).job_xp_total == 5940 and at_22["job_level"] == 22 and at_22["evolution_skill_points_available"] == 2 and menu.progression_state_label.text.contains("Nível de job: 22"), "one +1000 XP job click shows job 22 and two free evolution points")
	var gated := menu._learn_skill(&"berserker_obstinacy")
	_check(not gated["ok"] and gated["error_code"] == &"requirements_unmet", "job-23 skill remains gated at job 22 despite free points")
	var next_xp := menu._apply_playtest_progression(&"job_xp", 500)
	_check(next_xp["ok"] and facade.progression_summary(berserker_id)["job_level"] >= 23, "additional earned XP opens job-23 gate")
	var learned := menu._learn_skill(&"berserker_obstinacy")
	_check(learned["ok"] and facade.current_profile().character_by_id(berserker_id).purchased_skill_ranks.get(&"berserker_obstinacy", 0) == 1, "Berserker passive can be bought after reaching its gate")
	menu._populate_build_editor(facade.current_profile().character_by_id(berserker_id))
	_check(menu.action_editor.slot_buttons.size() == 24 and menu.action_editor.learned_skills == [&"berserker_rupture"], "editor has24 slots and only learned legal actives")
	menu.action_editor.assign_skill(&"berserker_rupture", 0)
	var saved := menu._save_build()
	_check(saved["ok"] and facade.current_profile().character_by_id(berserker_id).action_slots[0] == &"berserker_rupture" and facade.build_preview(berserker_id)["snapshot"].has_passive(&"berserker_obstinacy") and menu.automatic_passives_label.text.contains("automáticas"), "free active shortcut is saved; purchased passive operates automatically")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var reopened := reloaded.open_profile()
	var durable: CharacterState = reopened["profile"].character_by_id(berserker_id)
	_check(reopened["ok"] and durable.evolution_id == &"berserker" and durable.job_xp_total == 6440 and durable.action_slots.size() == 24 and durable.action_slots[0] == &"berserker_rupture" and durable.presets[0]["active_slots"] == [null, null, null, null, null] and durable.presets[0]["passive_slots"] == [null, null], "identity, XP and action shortcut survive durable reload while legacy arrays stay unchanged")
	_check(menu.start_run_button.text.contains("Candidato"), "start button still names the focused character")
	var started := menu._start_run()
	if started["ok"]:
		await scene_changed
		await process_frame
	var controller := current_scene as RunController
	_check(started["ok"] and started["run_state"].class_id == &"swordsman" and started["run_state"].build_snapshot.evolution_id == &"berserker" and started["run_state"].build_snapshot.action_slots[0] == &"berserker_rupture" and started["run_state"].build_snapshot.has_passive(&"berserker_obstinacy") and facade.current_profile().selected_character_id == berserker_id, "start action launches focused Berserker learned build and copied shortcuts")
	_check(controller != null and controller.player.available_skill_ids().has(&"berserker_rupture") and controller.battle_controls.skill_buttons.has(&"berserker_rupture") and controller.player.character_animation.actor_kind == &"berserker", "runtime dispatch, action bar and exclusive atlas show the learned skill")
	if started["ok"]:
		var reward := facade.grant_reward("flow-reward", facade.current_profile().revision, started["run_id"], 1, &"encounter_one")
		_check(reward["ok"] and facade.current_profile().character_by_id(berserker_id).job_xp_total == 6520 and facade.current_profile().character_by_id(first_id).job_xp_total == 0, "run reward advances focused Berserker, not prior roster selection")
		var ended := facade.end_run("flow-end", facade.current_profile().revision, started["run_id"], &"abandoned")
		var final_reload := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
		var final_open := final_reload.open_profile()
		_check(ended["ok"] and final_open["ok"] and final_reload.current_profile().character_by_id(berserker_id).job_xp_total == 6520, "post-run job XP persists after end and reload")
	if controller != null:
		controller.queue_free()
	menu.queue_free()
	await process_frame
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file_name))
	DirAccess.remove_absolute(directory)
	print("E05 Berserker playtest flow: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
