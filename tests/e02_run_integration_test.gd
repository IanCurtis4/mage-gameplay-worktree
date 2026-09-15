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
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e02_run_integration")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	await _check_persistent_preset_runtime_flow()
	await _check_terminal_restart_and_class_switch()
	await _check_close_failure_retry()
	_cleanup_directory(root_directory)
	print("Integração E02 menu/run: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_persistent_preset_runtime_flow() -> void:
	var facade := ProfileFacade.new(ProfileStore.new(root_directory.path_join("preset_runtime")))
	var created := facade.create_character("create-mage", 0, "Lina", &"mage")
	var mage: CharacterState = created["profile"].character_by_id(created["character_id"])
	var active: Array[Variant] = mage.presets[1]["active_slots"].duplicate(true)
	active[0] = &"fire_wall"
	active[1] = &"fireball"
	var passive: Array[Variant] = mage.presets[1]["passive_slots"].duplicate(true)
	passive[0] = null
	var equipped: Dictionary[StringName, Variant] = mage.presets[1]["equipped"].duplicate(true)
	var preset := facade.update_preset("save-reordered", 1, mage.character_id, 1, active, passive, equipped)
	var menu_scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu: CharacterMenu = menu_scene.instantiate()
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var started := menu._start_run()
	await scene_changed
	await process_frame
	var controller := current_scene as RunController
	_check(created["ok"] and preset["ok"] and started["ok"] and controller != null and controller.player.class_id == &"mage", "menu-selected persistent mage reaches the real arena controller")
	_check(controller.player.available_skill_ids() == [&"fire_wall", &"fireball"] and controller._key_skill(KEY_Q) == &"fire_wall" and controller._key_skill(KEY_W) == &"fireball" and controller._key_skill(KEY_A) == &"", "equipped active slots determine persistent HUD order and Q/W/A bindings")
	_check(controller.battle_controls.skill_buttons.keys() == [&"fire_wall", &"fireball"] and is_equal_approx(float(controller.player.stats["mana_regen_per_second"]), 6.0), "persistent loadout hides unselected mage skills and only applies an equipped passive")
	var closed := controller._close_persistent_run(&"death")
	_check(closed["ok"] and facade.current_profile().reward_session == null and facade.current_profile().lifetime_stats[&"deaths"] == 1, "closing a persistent run records the terminal outcome once")
	controller.queue_free()
	menu.queue_free()
	current_scene.queue_free()
	await process_frame

	var selected := facade.select_preset("select-default", facade.current_profile().revision, mage.character_id, 0)
	var restarted := facade.start_run("start-default", selected["new_revision"])
	controller = await _persistent_controller(facade, restarted["run_state"])
	_check(selected["ok"] and restarted["ok"] and controller.player.available_skill_ids() == [&"fireball", &"fire_wall"] and is_equal_approx(float(controller.player.stats["mana_regen_per_second"]), 9.0), "another preset changes persistent skill order and restores only its equipped passive")
	controller._close_persistent_run(&"abandoned")
	controller.queue_free()
	await process_frame

func _check_terminal_restart_and_class_switch() -> void:
	var facade := ProfileFacade.new(ProfileStore.new(root_directory.path_join("terminal_flow")))
	var mage := facade.create_character("create-mage", 0, "Maga", &"mage")
	var swordsman := facade.create_character("create-swordsman", 1, "Espada", &"swordsman")
	var selected_mage := facade.select_character("select-mage", 2, mage["character_id"])
	var started := facade.start_run("start-mage", selected_mage["new_revision"])
	var controller := await _persistent_controller(facade, started["run_state"])
	controller._show_result(false)
	controller._restart_run()
	await scene_changed
	await process_frame
	_check(facade.current_profile().reward_session == null and facade.current_profile().lifetime_stats[&"deaths"] == 1 and current_scene is CharacterMenu, "persistent terminal restart closes the mage run and returns to the character menu instead of reloading a legacy class")
	controller.queue_free()
	current_scene.queue_free()
	await process_frame

	var select_swordsman := facade.select_character("select-swordsman", facade.current_profile().revision, swordsman["character_id"])
	var next_run := facade.start_run("start-swordsman", select_swordsman["new_revision"])
	controller = await _persistent_controller(facade, next_run["run_state"])
	controller._select_class(&"mage")
	await scene_changed
	await process_frame
	_check(select_swordsman["ok"] and next_run["ok"] and facade.current_profile().reward_session == null and facade.current_profile().selected_character_id == swordsman["character_id"], "persistent class selection closes the active run and never silently changes the selected character")
	controller.queue_free()
	current_scene.queue_free()
	await process_frame

func _check_close_failure_retry() -> void:
	var store := ToggleFailStore.new(root_directory.path_join("close_retry"))
	var facade := ProfileFacade.new(store)
	var created := facade.create_character("create-close", 0, "Nina", &"swordsman")
	var started := facade.start_run("start-close", created["new_revision"])
	var controller := await _persistent_controller(facade, started["run_state"])
	controller._show_result(false)
	store.failure_stage = &"replace"
	controller._restart_run()
	_check(controller.result_overlay.visible and paused and controller.result_body.text.contains("continua aberta") and controller.persistent_facade != null and facade.current_profile().reward_session != null, "failed terminal close preserves the run, blocks navigation, and explains retry")
	store.failure_stage = &""
	var retried := controller._close_persistent_run(&"death")
	_check(retried["ok"] and controller.persistent_facade == null and facade.current_profile().reward_session == null and facade.current_profile().lifetime_stats[&"deaths"] == 1, "retry closes the same run without duplicating terminal counters")
	controller.queue_free()
	await process_frame

func _persistent_controller(facade: ProfileFacade, state: RunState) -> RunController:
	RunController.pending_run_state = state
	RunController.pending_run_facade = facade
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	return controller

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
