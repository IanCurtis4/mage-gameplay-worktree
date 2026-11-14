extends SceneTree
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	var f := F.make("f7_scene_flow")
	var facade: ProfileFacade = f["facade"]
	var menu := CharacterMenu.new()
	menu.set_profile_facade(facade)
	root.add_child(menu)
	current_scene = menu
	var panel := PhaseSelectionPanel.new()
	menu.add_child(panel)
	panel.configure(menu, f["a"])
	assert((panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a == 1.0, "phase selection hides the lobby text beneath it")
	panel.seed_input.text = "43" if "--seed-43" in OS.get_cmdline_user_args() else "42"
	var chosen_seed := panel.seed_input.text
	if "--capture-f7" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		var native_directory := "res://.godot/verification/e07_f7/native"
		DirAccess.make_dir_recursive_absolute(native_directory)
		assert(root.get_texture().get_image().save_png(native_directory.path_join("selection_%s.png" % chosen_seed)) == OK)
	var entered: Dictionary = await panel.start()
	assert(entered.get("ok", false), str(entered))
	var host := entered["root"] as RunController
	assert(current_scene == host and host.campaign_runtime != null)
	assert(host.visible, "published world must remain visible after staging")
	assert(host.route_camera.is_current(), "published world owns the active camera")
	assert(host.route_camera.limit_left < -10000 and host.route_camera.limit_top < -10000, "pilot flat bounds must not push the isometric player off-screen")
	assert(host.get_children().all(func(child: Node) -> bool: return not child is ArenaObstacleView), "expedition startup carries no pilot decorations")
	assert(host.run_state.pending_choices == 2 and host.enemies.size() == 2)
	var opening := facade.current_profile().expedition_for_character(f["a"])
	assert(opening.checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT, "active entry uses a compact journal base")
	var dead := host.enemies[0] as EnemyActor
	var dead_slot := host.campaign_runtime.slot_for_actor(dead)
	var generation: int = host.campaign_runtime.state.slots[dead_slot]["generation"]
	paused = true
	dead.health.current_hp = 0.0
	dead.health._death_emitted = true
	var barrier := SnapshotTickBarrier.new()
	assert(barrier.acquire(host)["ok"])
	var journal_service := ExpeditionService.new(facade)
	var event := {"kind":"mob_death","slot_id":dead_slot,"generation":generation,"event_id":"test_death_"+dead_slot}
	assert(journal_service.journal_events(host,barrier,[event],"compact_test_death",facade.current_profile().revision)["ok"])
	barrier.release()
	var journal_lock := facade.current_profile().expedition_for_character(f["a"])
	assert(journal_lock.journal.size() == 1)
	var restored := journal_service._restore(journal_lock)
	assert(restored.ok, str(restored))
	var replayed := restored.root as RunController
	assert(replayed.enemies.size() == 1 and not replayed.campaign_runtime.actors.has(dead_slot))
	assert(replayed.reward_service._queue == host.reward_service._queue and replayed.reward_service._queue.size() == 1)
	replayed.free()
	paused = false
	assert(host.ui_root.get_node_or_null("ExpeditionStatus") != null and host.expedition_view != null)
	if "--capture-f7" in OS.get_cmdline_user_args():
		paused = true
		host._select_enemy(host.enemies[0])
		(host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel).refresh()
		host.route_camera.position = Vector2(120,260)
		host.route_camera.zoom = Vector2(0.65,0.65)
		host.route_camera.reset_smoothing()
		host.route_camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		var directory := "res://.godot/verification/e07_f7/native"
		DirAccess.make_dir_recursive_absolute(directory)
		assert(root.get_texture().get_image().save_png(directory.path_join("campaign_%s.png" % chosen_seed)) == OK)
	var manifest_hash: String = host.campaign_runtime.state.manifest_data["input_hash"]
	var status := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
	var blocked: Dictionary = await status.run_action({"kind": "travel", "portal_id": "entry_to_left", "stage_id": "entry"})
	assert(blocked.get("error_code") == &"portal_closed" and current_scene == host)
	assert(host.run_state.pending_choices == 2 and not host._memory_snapshot_pending)
	host.enemies[0].health.current_hp *= 0.5
	host.player.health.current_hp *= 0.75
	host.player.attack_cooldown = 2.0
	var player_hp := host.player.health.current_hp
	var player_point := host.player.world_point().to_data()
	f["store"].lose_ack = true
	f["store"].hide_after_ack = true
	var closed: Dictionary = await status.run_action({"kind": "suspend"})
	assert(not closed.get("ok", false) and closed.get("read_only", false))
	assert(current_scene == host and paused and host._memory_snapshot_pending)
	status.refresh()
	assert(status.can_process() and status.actions.get_child(0).can_process() and not host.player.can_process(), "recovery UI remains usable while gameplay is frozen")
	var retained_service := status.service
	if "--capture-f7" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://.godot/verification/e07_f7/native/recovery.png") == OK)
	f["store"].hide_reads = false
	closed = status.retry()
	assert(retained_service.facade == facade)
	assert(closed.get("ok", false), str(closed))
	var lobby := current_scene as CharacterMenu
	assert(lobby != null and not paused)
	var lock := facade.current_profile().expedition_for_character(f["a"])
	assert(lock != null and lock.lifecycle == &"suspended")
	assert(lock.checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT, "eligible lobby suspension uses the compact checkpoint")
	assert(lobby.start_run_button.disabled and lobby.preset_selector.disabled, "suspended owner exposes the authoritative lobby lock")
	lobby._select_roster_index(1)
	assert(not lobby.start_run_button.disabled, "an unrelated alt remains free after suspension")
	var resumed_panel := PhaseSelectionPanel.new()
	lobby.add_child(resumed_panel)
	resumed_panel.configure(lobby, f["a"])
	var resumed := await resumed_panel.start()
	assert(resumed.get("ok", false), str(resumed))
	host = resumed["root"]
	assert(host.run_state.pending_choices == 2 and host.campaign_runtime.state.manifest_data["input_hash"] == manifest_hash)
	assert(host.player.world_point().to_data() == player_point and is_equal_approx(host.player.health.current_hp, player_hp) and is_equal_approx(host.player.attack_cooldown, 2.0))
	assert(host.enemies.size() == 1 and host.campaign_runtime.state.slots[dead_slot]["life_state"] == "dead")
	for enemy: EnemyActor in host.enemies:
		var id := host.campaign_runtime.slot_for_actor(enemy)
		assert(enemy.world_point().to_data() == host.campaign_runtime.state.slots[id]["home"])
		assert(is_equal_approx(enemy.health.current_hp, enemy.health.max_hp))
	assert(host.ui_root.get_node_or_null("ExpeditionStatus") != null)
	if "--capture-f7" in OS.get_cmdline_user_args():
		paused = true
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://.godot/verification/e07_f7/native/resumed.png") == OK)
	print("E07 F7 flow: PASS (23 assertions, opaque selection/visible/isometric camera/enter/lobby locks/closed portal/usable uncertain recovery/resume/install/activate)")
	host.queue_free()
	await process_frame
	quit(0)
