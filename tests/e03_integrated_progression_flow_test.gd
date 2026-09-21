extends SceneTree

class ToggleFailStore:
	extends ProfileStore
	var failure_stage: StringName = &""

	func _should_fail(stage: StringName) -> bool:
		return not failure_stage.is_empty() and stage == failure_stage

var checks := 0
var failures := 0
var root_directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e03_integrated_flow")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	await _check_menu_reward_investment_new_run_reload()
	await _check_reward_save_retry()
	_cleanup_directory(root_directory)
	print("E03 fluxo integrado: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_menu_reward_investment_new_run_reload() -> void:
	var directory := root_directory.path_join("complete_flow")
	var catalog := ProfileCatalog.pilot()
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("flow-create", 0, "Integração", &"swordsman")
	var menu := await _menu_for(facade)
	menu._select_roster_index(0)
	var started := menu._start_run()
	await scene_changed
	await process_frame
	var controller := current_scene as RunController
	_freeze_controller(controller)
	var initial_stats: StatBreakdown = started["run_state"].build_snapshot.stat_breakdown()
	_check(created["ok"] and started["ok"] and controller != null, "character menu starts the real persistent arena flow")

	_prepare_reward(controller, 1)
	var first_reward := controller._collect_reward()
	var after_first := facade.progression_summary(created["character_id"])
	_check(first_reward["ok"] and first_reward["applied_reward"]["base_xp"] == 100 and first_reward["applied_reward"]["job_xp"] == 80, "first pilot encounter commits its declared XP before consuming the pickup")
	_check(after_first["base_level"] == 2 and after_first["job_level"] == 2 and after_first["attribute_points_available"] == 3 and after_first["base_skill_points_available"] == 1, "first reward derives both levels and separate point wallets")
	_check(_same_values(initial_stats, controller.player.stat_breakdown), "XP gained during the run does not mutate its value snapshot")

	_prepare_reward(controller, 2)
	var second_reward := controller._collect_reward()
	var after_second := facade.progression_summary(created["character_id"])
	_check(second_reward["ok"] and after_second["base_level"] == 3 and after_second["job_level"] == 3, "second reward crosses multiple cumulative level thresholds in the real run")
	_check(after_second["attribute_points_available"] == 6 and after_second["base_skill_points_available"] == 2 and controller.status_label.text.contains("+150 base") and controller.status_label.text.contains("+100 job"), "second reward exposes the derived wallets and saved XP feedback")
	_check(_same_values(initial_stats, controller.player.stat_breakdown), "both persistent rewards leave current combat stats unchanged")

	var closed := controller._close_persistent_run(&"completed")
	_check(closed["ok"] and facade.current_profile().reward_session == null, "completed run closes before menu investment")
	controller.queue_free()
	menu.queue_free()
	await process_frame

	var investment_menu := await _menu_for(facade)
	investment_menu._select_roster_index(0)
	var allocated := investment_menu._allocate_attribute(&"str")
	var learned := investment_menu._learn_skill(&"slash")
	var invested_preview := facade.build_preview(created["character_id"])
	var invested_summary := facade.progression_summary(created["character_id"])
	_check(allocated["ok"] and learned["ok"] and invested_summary["attribute_points_available"] == 5 and invested_summary["base_skill_points_available"] == 1 and invested_summary["effective_skill_ranks"][&"slash"] == 1, "menu spends one attribute point and learns slash rank one through persistent transactions")

	var next_started := investment_menu._start_run()
	await scene_changed
	await process_frame
	var next_controller := current_scene as RunController
	_freeze_controller(next_controller)
	var expected_stats: StatBreakdown = invested_preview["stat_breakdown"]
	_check(next_started["ok"] and _same_values(expected_stats, next_controller.player.stat_breakdown) and next_controller.run_state.skill_levels[&"slash"] == 1, "new run consumes the invested preview and learned rank")
	next_controller._update_hud()
	_check(next_controller.health_label.text.contains("%d" % int(expected_stats.value(&"max_hp"))) and next_controller.sp_label.text.contains("%d" % int(expected_stats.value(&"max_sp"))), "new-run HUD reads the same canonical HP and SP values")
	var combat_request := next_controller.player._make_physical_request(next_controller.enemies[0], &"basic_attack", expected_stats.value(&"melee_attack"), DamageRequest.AccuracyMode.CONTESTED, true)
	_check(is_equal_approx(combat_request.physical_damage, expected_stats.value(&"melee_attack")) and is_equal_approx(combat_request.hit_rating, expected_stats.value(&"hit_rating")), "combat request reads offense and HIT from the same new-run stats")

	var second_close := next_controller._close_persistent_run(&"abandoned")
	next_controller.queue_free()
	investment_menu.queue_free()
	await process_frame
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var reopened := reloaded.open_profile()
	var reloaded_character: CharacterState = reopened["profile"].character_by_id(created["character_id"])
	var reloaded_summary := reloaded.progression_summary(created["character_id"])
	_check(second_close["ok"] and reopened["ok"] and reloaded_character.base_xp_total == 250 and reloaded_character.job_xp_total == 180, "reload preserves both real encounter rewards")
	_check(reloaded_character.attribute_allocations[&"str"] == 1 and reloaded_summary["effective_skill_ranks"][&"slash"] == 1, "reload preserves attribute investment and learned rank")

func _check_reward_save_retry() -> void:
	var store := ToggleFailStore.new(root_directory.path_join("reward_retry"), ProfileCatalog.pilot())
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("retry-create", 0, "Retry", &"swordsman")
	var started := facade.start_run("retry-start", created["new_revision"])
	RunController.pending_run_state = started["run_state"]
	RunController.pending_run_facade = facade
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	_freeze_controller(controller)
	_prepare_reward(controller, 1)
	store.failure_stage = &"replace"
	var failed := controller._collect_reward()
	_check(not failed["ok"] and failed["error_code"] == &"save_failed" and controller.reward != null and controller.run_state.pending_choices == 0 and controller._reward_retry_pending, "failed XP save retains the pickup, blocks progression, and offers an explicit retry")
	_check(facade.current_profile().character_by_id(created["character_id"]).base_xp_total == 0 and facade.current_profile().reward_session["last_committed_seq"] == 0, "failed collection publishes neither XP nor reward cursor")
	store.failure_stage = &""
	controller._reward_retry_pending = false
	var retried := controller._collect_reward()
	_check(retried["ok"] and controller.reward == null and controller.run_state.pending_choices == 1 and facade.current_profile().character_by_id(created["character_id"]).base_xp_total == 100, "retry commits the same encounter once and only then unlocks the augment choice")
	controller._close_persistent_run(&"abandoned")
	controller.queue_free()
	await process_frame

func _menu_for(facade: ProfileFacade) -> CharacterMenu:
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	return menu

func _prepare_reward(controller: RunController, encounter_number: int) -> void:
	controller.encounter_index = encounter_number
	controller.encounter_active = false
	controller._reward_retry_pending = false
	controller.reward = RewardPickup.new()
	controller.add_child(controller.reward)

func _freeze_controller(controller: RunController) -> void:
	if controller == null:
		return
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)

func _same_values(left: StatBreakdown, right: StatBreakdown) -> bool:
	if left == null or right == null:
		return false
	var left_values := left.values()
	var right_values := right.values()
	if left_values.keys() != right_values.keys():
		return false
	for stat_id: StringName in left_values:
		if not is_equal_approx(left_values[stat_id], right_values[stat_id]):
			return false
	return true

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
