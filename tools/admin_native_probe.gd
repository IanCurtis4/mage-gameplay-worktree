extends SceneTree
## Production admin windows with a disposable profile; no user save access.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := "res://.godot/verification/e06_admin_native"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var facade := ProfileFacade.new(ProfileStore.new(ProjectSettings.globalize_path(directory + "/profile_%d" % Time.get_ticks_usec()), ProfileCatalog.pilot()), ProfileRewardResolver.pilot_progression())
	assert(facade.create_character("admin-native-create", 0, "Teste do admin", &"mage")["ok"])
	var id := facade.current_profile().selected_character_id
	var menu := CharacterMenu.new()
	menu.set_profile_facade(facade)
	viewport.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	menu.playtest_toggle.button_pressed = true
	menu._open_admin_tools()
	await _capture(viewport, directory, "lobby")
	assert(menu.admin_panel.visible and menu.admin_panel._runtime_buttons[0].disabled)
	var count := facade.current_profile().equipment_instances.size()
	menu.admin_panel._grant_equipment()
	assert(facade.current_profile().equipment_instances.size() == count + 1)
	menu.admin_panel._command(&"card", menu.admin_panel._selected(menu.admin_panel.cards))
	assert(facade.current_profile().card_inventory.describe()["owned"].size() == 1)
	menu.admin_panel._command(&"max_levels")
	menu.admin_panel._command(&"unlock_skills")
	assert(facade.current_profile().character_by_id(id).admin_skills_unlocked)
	var slots := ActionBarLayout.for_character(facade.current_profile().character_by_id(id))
	slots[0] = {"skill_id": "fireball", "rank": 5}
	assert(facade.update_action_slots("admin-native-bind", facade.current_profile().revision, id, slots)["ok"])
	menu.queue_free()
	await process_frame
	var started := facade.start_run("admin-native-run", facade.current_profile().revision)
	assert(started["ok"])
	RunController.pending_run_state = started["run_state"]
	RunController.pending_run_facade = facade
	RunController.pending_gameplay_extension = true
	var game := RunController.new()
	viewport.add_child(game)
	await process_frame
	var hotkey := InputEventKey.new()
	hotkey.keycode = KEY_F10
	hotkey.physical_keycode = KEY_F10
	hotkey.pressed = true
	viewport.push_input(hotkey, true)
	await process_frame
	await _capture(viewport, directory, "run")
	assert(paused and game.admin_panel.visible)
	game.admin_panel._runtime_buttons[3].grab_focus()
	await _capture(viewport, directory, "run_commands")
	var hp := game.player.health.hp_deficit()
	var sp := game.player.sp_deficit()
	game.admin_panel._command(&"card", game.admin_panel._selected(game.admin_panel.cards))
	assert(is_equal_approx(game.player.health.hp_deficit(), hp) and is_equal_approx(game.player.sp_deficit(), sp))
	assert(game.run_state.card_inventory.describe()["owned"].size() == 2)
	game.admin_panel._command(&"offer")
	await _capture(viewport, directory, "offer")
	assert(game.augment_overlay.visible and game.encounter_active and game._admin_offer_override)
	if not game.run_state.current_offer.is_empty():
		game._confirm_augment(game.run_state.current_offer[0].id)
	assert(game.encounter_active and not game.next_button.visible and not game._admin_offer_override)
	print("ADMIN_NATIVE_OK lobby_collection=true live_card=true max_skills=true live_offer=true deficits_preserved=true")
	paused = false
	game.queue_free()
	await process_frame
	quit(0)

func _capture(viewport: SubViewport, directory: String, name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	assert(capture.save_png(directory + "/" + name + ".png") == OK)

