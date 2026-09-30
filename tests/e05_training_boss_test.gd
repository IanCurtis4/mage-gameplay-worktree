extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174171"

var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_training_boss")
	_cleanup(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	var profile := ProfileState.new(PROFILE_ID)
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Defendente de Treino", &"swordsman")
	character.evolution_id = &"defender"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "training fixture commits only to isolated verification profile")
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := facade.open_profile()
	var before_revision: int = opened["profile"].revision
	var before_text := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	var prepared := facade.prepare_playtest_training(character_id)
	_check(prepared["ok"] and prepared["run_state"].build_snapshot.evolution_id == &"defender" and prepared["run_state"].build_snapshot.job_level == 40, "training copies the focused job-40 build")
	_check(facade.current_profile().revision == before_revision and facade.current_profile().reward_session == null and facade.current_profile().lifetime_stats[&"runs_started"] == 0 and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == before_text, "training preparation never opens a reward session or writes profile")
	var menu := load("res://scenes/character_menu.tscn").instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu.playtest_toggle.button_pressed = true
	var training_button := menu.playtest_panel.get_node("PlaytestTrainingBoss") as Button
	_check(training_button != null and not training_button.disabled, "training entry is available for the focused character in admin mode")
	var launched := menu._start_playtest_training()
	await scene_changed
	menu.queue_free()
	var arena := current_scene as RunController
	_check(launched["ok"] and arena != null, "menu launches the real training scene")
	await process_frame
	_check(arena.training_mode and arena.persistent_facade == null and arena.training_boss != null and arena.training_boss.health.max_hp == RunController.TRAINING_BOSS_HP and arena.training_boss.sprite_visual_scale > 1.0 and arena.training_boss.scenario_damage_multiplier == RunController.TRAINING_BOSS_DAMAGE_MULTIPLIER, "real arena creates large durable boss with training-only damage tuning")
	_check(arena.enemies.size() == 1 and arena.reward == null and arena.run_state.run_id.is_empty(), "training starts with only boss, no pickup and no persistent run ID")
	var elapsed := arena._training_add_elapsed
	paused = true
	arena._process(9.0)
	_check(arena._training_add_elapsed == elapsed and arena.enemies.size() == 1, "paused tree cannot advance the add scheduler")
	paused = false
	arena._advance_training_adds(RunController.TRAINING_ADD_INTERVAL)
	_check(arena.enemies.size() == 3 and arena.enemies[1].health.max_hp == RunController.TRAINING_ADD_HP and arena.enemies[2].health.max_hp == RunController.TRAINING_ADD_HP and arena.enemies[1].scenario_damage_multiplier == RunController.TRAINING_ADD_DAMAGE_MULTIPLIER, "first wave creates two moderate-damage 1500-HP adds")
	for index: int in range(5):
		arena._spawn_training_add_wave()
	_check(arena.enemies.size() <= 1 + RunController.TRAINING_ADD_CAP and arena.enemies.size() >= 3, "waves remain capped at six living adds")
	var positions_valid := true
	for enemy: CombatActor in arena.enemies:
		if not arena.navigation.is_walkable(enemy.global_position):
			positions_valid = false
		if enemy != arena.training_boss and enemy.global_position.distance_to(arena.player.global_position) < 130.0:
			positions_valid = false
	for left_index: int in range(arena.enemies.size()):
		for right_index: int in range(left_index + 1, arena.enemies.size()):
			if arena.enemies[left_index].global_position.distance_to(arena.enemies[right_index].global_position) < 90.0:
				positions_valid = false
	_check(positions_valid, "boss and add positions remain navigable and non-overlapping")
	var boss := arena.training_boss
	arena._on_enemy_died(boss)
	_check(arena.run_finished and arena.reward == null and arena.training_boss == null and arena._training_add_elapsed == 0.0 and paused, "boss death stops scheduling and ends training without reward")
	_check(facade.current_profile().revision == before_revision and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == before_text, "boss result cannot grant XP or modify profile")
	arena._restart_run()
	await scene_changed
	var restarted := current_scene as RunController
	_check(restarted != null and restarted.training_mode and restarted.run_state.build_snapshot.character_id == character_id and restarted.training_boss.health.current_hp == RunController.TRAINING_BOSS_HP, "restart preserves the saved build and creates a fresh boss without committing a run")
	_check(not paused and RunController.pending_run_state == null and not RunController.pending_training_mode and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == before_text, "restart clears launch state and never touches the profile")
	restarted._on_player_died(restarted.player)
	restarted._spawn_training_add_wave()
	_check(restarted.run_finished and restarted.enemies.size() == 1 and restarted.reward == null and paused, "player death stops spawning and leaves no reward")
	paused = false
	restarted.queue_free()
	current_scene = null
	await process_frame
	var returned_menu := load("res://scenes/character_menu.tscn").instantiate() as CharacterMenu
	returned_menu.set_profile_facade(facade)
	root.add_child(returned_menu)
	await process_frame
	_check(returned_menu._focused_character_id == character_id and CharacterMenu.pending_focus_character_id.is_empty(), "a fresh menu restores focus to the trained character without selecting or saving it")
	returned_menu.queue_free()
	_cleanup(directory)
	print("E05 treino de boss: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var access := DirAccess.open(path)
	if access == null:
		return
	for entry: String in access.get_files():
		DirAccess.remove_absolute(path.path_join(entry))
	for entry: String in access.get_directories():
		_cleanup(path.path_join(entry))
		DirAccess.remove_absolute(path.path_join(entry))

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
