extends SceneTree
## This probe intentionally uses no assert: it must execute in release templates.
var failures := 0
func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
	return condition

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not check(args.size() == 1, "isolated profile directory required"):
		quit(2); return
	var directory: String = args[0]
	var catalog := ProfileCatalog.pilot()
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var opened := facade.open_profile()
	if not check(opened.get("ok", false), "export profile opens: " + str(opened.get("error_code", &""))):
		quit(1); return
	var initial_count := facade.current_profile().characters.size()
	if initial_count == 0:
		var created := facade.create_character("release-create", facade.current_profile().revision, "Teste exportado", &"mage")
		if not check(created.get("ok", false), "export creates character"):
			quit(1); return
	var character_id := facade.current_profile().selected_character_id
	for cycle: int in range(3):
		var started := facade.start_run("release-start-%d" % cycle, facade.current_profile().revision)
		if not check(started.get("ok", false), "export starts run " + str(started.get("error_code", &""))):
			quit(1); return
		RunController.pending_run_state = started["run_state"]
		RunController.pending_run_facade = facade
		RunController.pending_gameplay_extension = true
		var game := RunController.new()
		root.add_child(game)
		game.set_process(false)
		game.player.set_process(false)
		if not check(not game._startup_error and game.enemies.size() > 0, "release initializes real enemies"):
			quit(1); return
		for enemy: CombatActor in game.enemies:
			enemy.set_process(false)
			enemy.set_physics_process(false)
			check(enemy.is_alive(), "release enemy has valid HP")
		check(game.run_state.effect_catalog().mob_catalog().ids().size() == 11, "release installs extended mob catalog")
		check(game.reward_service._mob_actors.size() == game.enemies.size(), "release registers every mob for loot")
		var victim := game.enemies[0] as EnemyActor
		victim.health.current_hp = 0.0
		var issued := game.reward_service.issue_mob_drop(victim)
		check(issued.get("ok", false), "release issues registered mob reward")
		if cycle != 1:
			var ended := facade.end_run("release-end-%d" % cycle, facade.current_profile().revision, game.run_state.run_id, &"abandoned")
			check(ended.get("ok", false), "release closes run durably")
		game.queue_free()
		await process_frame
		paused = false
		facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
		var reopened := facade.open_profile()
		if not check(reopened.get("ok", false), "export reopens/recovers interrupted run: " + str(reopened.get("error_code", &""))):
			quit(1); return
		check(facade.current_profile().character_by_id(character_id) != null, "export preserves character across restarts")
		check(facade.current_profile().reward_session == null, "export clears unfinished session")
	print("EXPORT_GAMEPLAY_OK failures=", failures, " release=", not OS.is_debug_build(), " initial_characters=", initial_count, " cycles=3 mobs=true loot=true reopen=true")
	quit(0 if failures == 0 else 1)

