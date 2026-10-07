extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174088"

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e05_defender_playtest_flow")
	if DirAccess.dir_exists_absolute(directory):
		for file_name: String in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file_name))
	else:
		DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	var profile := ProfileState.new(PROFILE_ID)
	var first_id := IdentityIds.character_id(PROFILE_ID, 1)
	var defender_id := IdentityIds.character_id(PROFILE_ID, 2)
	var first := CharacterState.new(first_id, "Primeiro", &"swordsman")
	var defender := CharacterState.new(defender_id, "Candidato", &"swordsman")
	defender.base_xp_total = 7500
	defender.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	profile.characters = [first, defender]
	profile.selected_character_id = first_id
	profile.next_character_counter = 3
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "isolated candidate is at job 20 while another character is selected")
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var menu := load("res://scenes/character_menu.tscn").instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(1)
	var opened := menu._begin_evolution_change(&"defender")
	await process_frame
	await process_frame
	_check(opened["ok"] and facade.current_profile().character_by_id(defender_id).evolution_id.is_empty(), "choosing opens a pending confirmation without mutating the save")
	_check(menu.status_label.text.contains("Confirm") and menu.menu_scroll.get_global_rect().intersects(menu.confirm_evolution_button.get_global_rect()), "pending confirmation is announced and scrolled into the visible menu")
	var capped := facade.grant_playtest_progression("pending-job-cap", facade.current_profile().revision, defender_id, &"job_xp", 1000)
	_check(capped["ok"] and capped["already_applied"] and facade.current_profile().character_by_id(defender_id).job_xp_total == 4940, "an unconfirmed evolution still has the unevolved job-20 cap")
	var confirmed := menu._confirm_evolution_change()
	var evolved: CharacterState = facade.current_profile().character_by_id(defender_id)
	_check(confirmed["ok"] and evolved.evolution_id == &"defender" and evolved.job_xp_total == 4940, "confirmation persists Defender without changing earned job XP")
	_check(menu.roster_list.get_item_text(1).contains("Espadachim → Defendente") and menu.evolution_state_label.text.contains("Evolução atual: Defendente"), "roster and evolution panel distinguish the persistent branch from its base origin")
	var at_entry := facade.progression_summary(defender_id)
	_check(at_entry["effective_skill_ranks"].get(&"defender_counterstroke", 0) == 1 and at_entry["evolution_skill_points_available"] == 0 and evolved.presets[0]["active_slots"].find(&"defender_counterstroke") < 0, "entry R1 is free but not automatically equipped and no evolution points exist at job 20")
	var too_early := menu._learn_skill(&"defender_watch")
	_check(not too_early["ok"] and too_early["error_code"] == &"insufficient_points", "job-gated passive cannot be purchased at job 20")
	menu.playtest_toggle.button_pressed = true
	var xp := menu._apply_playtest_progression(&"job_xp", 1500)
	var after_xp: CharacterState = facade.current_profile().character_by_id(defender_id)
	_check(xp["ok"] and after_xp.job_xp_total == 6440 and facade.progression_summary(defender_id)["job_level"] >= 23, "evolved character can gain job XP past the unevolved cap")
	var learned := menu._learn_skill(&"defender_watch")
	_check(learned["ok"] and facade.current_profile().character_by_id(defender_id).purchased_skill_ranks.get(&"defender_watch", 0) == 1, "Defender passive can be purchased once job requirement is met")
	menu._populate_build_editor(facade.current_profile().character_by_id(defender_id))
	_check(menu.action_editor.slot_buttons.size() == 24 and menu.action_editor.learned_skills == [&"defender_counterstroke"], "editor has24 slots and only learned legal actives")
	menu.action_editor.assign_skill(&"defender_counterstroke", 0)
	var saved := menu._save_build()
	_check(saved["ok"] and facade.current_profile().character_by_id(defender_id).action_slots[0] == &"defender_counterstroke" and facade.build_preview(defender_id)["snapshot"].has_passive(&"defender_watch") and menu.automatic_passives_label.text.contains("automáticas"), "free active shortcut is saved; purchased passive operates automatically")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var reopened := reloaded.open_profile()
	var durable: CharacterState = reopened["profile"].character_by_id(defender_id)
	_check(reopened["ok"] and durable.evolution_id == &"defender" and durable.job_xp_total == 6440 and durable.action_slots.size() == 24 and durable.action_slots[0] == &"defender_counterstroke" and durable.presets[0]["active_slots"] == [null, null, null, null, null] and durable.presets[0]["passive_slots"] == [null, null], "identity, XP and action shortcut survive reload while legacy arrays stay unchanged")
	_check(menu.start_run_button.text.contains("Candidato"), "start action names the focused character instead of an implicit prior selection")
	var started := menu._start_run()
	if started["ok"]:
		await scene_changed
		await process_frame
	var controller := current_scene as RunController
	_check(started["ok"] and started["run_state"].class_id == &"swordsman" and started["run_state"].build_snapshot.evolution_id == &"defender" and started["run_state"].build_snapshot.action_slots[0] == &"defender_counterstroke" and started["run_state"].build_snapshot.has_passive(&"defender_watch") and facade.current_profile().selected_character_id == defender_id, "start action launches focused Defender with base origin, learned passives and copied shortcuts")
	_check(controller != null and controller.player.available_skill_ids().has(&"defender_counterstroke") and controller.battle_controls.skill_buttons.has(&"defender_counterstroke"), "runtime dispatch and action bar expose the learned Defender active")
	if started["ok"]:
		var reward := facade.grant_reward("flow-reward", facade.current_profile().revision, started["run_id"], 1, &"encounter_one")
		_check(reward["ok"] and facade.current_profile().character_by_id(defender_id).job_xp_total == 6520 and facade.current_profile().character_by_id(first_id).job_xp_total == 0, "run reward advances the actual Defender above job 20, not the previous selected character")
		var ended := facade.end_run("flow-end", facade.current_profile().revision, started["run_id"], &"abandoned")
		var final_reload := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
		var final_open := final_reload.open_profile()
		_check(ended["ok"] and final_open["ok"] and final_open["profile"].character_by_id(defender_id).job_xp_total == 6520, "post-run job XP persists after end and reload")
	if controller != null:
		controller.queue_free()
	menu.queue_free()
	await process_frame
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file_name))
	DirAccess.remove_absolute(directory)
	print("E05 Defendente playtest flow: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
