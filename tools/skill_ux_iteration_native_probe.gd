extends SceneTree
## Real production UI with isolated profile and unchanged progression rules.
const MenuScript = preload("res://scripts/ui/character_menu.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var directory := "res://.godot/verification/e06_skill_ux_iteration/native"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for extent: Vector2i in [Vector2i(1280,720), Vector2i(1920,1080)]:
		var viewport := SubViewport.new()
		viewport.size = extent
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var store_path := ProjectSettings.globalize_path(directory + "/profile_%d_%d" % [extent.x, Time.get_ticks_usec()])
		var facade := ProfileFacade.new(ProfileStore.new(store_path, ProfileCatalog.pilot()), ProfileRewardResolver.pilot_progression())
		assert(facade.create_character("create", 0, "Leitura de habilidades", &"mage")["ok"])
		var id := facade.current_profile().characters[0].character_id
		assert(facade.grant_playtest_progression("xp", facade.current_profile().revision, id, &"prepare_evolution")["ok"])
		assert(facade.learn_skill("learn-fireball", facade.current_profile().revision, id, &"fireball")["ok"])
		assert(facade.learn_skill("learn-fireball2", facade.current_profile().revision, id, &"fireball")["ok"])
		assert(facade.learn_skill("learn-fireball3", facade.current_profile().revision, id, &"fireball")["ok"])
		assert(facade.learn_skill("learn-spear", facade.current_profile().revision, id, &"fire_spear")["ok"])
		var menu := MenuScript.new()
		menu.set_profile_facade(facade)
		menu.set_profile_directory(store_path)
		viewport.add_child(menu)
		menu.menu_tabs.current_tab = 1
		await process_frame
		await process_frame
		assert(menu.skill_window.visible)
		menu.action_editor.assign_skill(&"fireball", 0, 1)
		menu.action_editor.assign_skill(&"fireball", 2, 3)
		menu.action_editor.assign_skill(&"fire_spear", 1)
		menu.skill_window._select(&"fireball")
		var drag_button: Button = menu.skill_window.skill_entries[&"fireball"]["button"]
		await _native_drag(viewport, GuiMetrics.visual_rect(drag_button).get_center(), GuiMetrics.visual_rect(menu.action_editor.slot_buttons[8]).get_center())
		assert(ActionBarLayout.skill_id(menu.action_editor.action_slots[8]) == &"fireball" and ActionBarLayout.selected_rank(menu.action_editor.action_slots[8]) == 0)
		await _capture(viewport, directory, "lobby_tree_%d" % extent.x)
		assert(menu.skill_window.draft.add(&"ice_spear")["ok"])
		menu.skill_window._refresh()
		menu.skill_window._select(&"ice_spear")
		menu.skill_window._tree = false
		menu.skill_window._render_skills()
		await _capture(viewport, directory, "lobby_list_pending_%d" % extent.x)
		assert(not facade.current_profile().character_by_id(id).purchased_skill_ranks.has(&"ice_spear"))
		menu.skill_window.draft.reset()
		menu.skill_window._tree = true
		assert(menu.skill_window._jobs == [&""])
		menu.skill_window._choose_job(&"")
		menu.skill_window._select(&"fireball")
		await _capture(viewport, directory, "lobby_owned_jobs_%d" % extent.x)
		var tooltip := SkillTooltip.create(SkillPresentation.describe(menu.skill_window.skill_entries[&"fireball"]["option"], menu.skill_window.draft.preview["summary"]))
		viewport.add_child(tooltip)
		tooltip.position = Vector2(75,70)
		await _capture(viewport, directory, "hover_dialog_layout_%d" % extent.x)
		assert(Rect2(Vector2.ZERO, Vector2(extent)).encloses(tooltip.get_global_rect()))
		tooltip.free()
		menu.skill_window.dismiss()
		menu.menu_tabs.current_tab = 1
		assert(menu.skill_window.visible and menu.skill_window.draft.sequence.is_empty())
		menu.free()
		var started := facade.start_run("start", facade.current_profile().revision)
		assert(started["ok"])
		RunController.pending_run_state = started["run_state"]
		RunController.pending_run_facade = facade
		RunController.pending_training_mode = false
		RunController.pending_gameplay_extension = true
		var controller := RunController.new()
		viewport.add_child(controller)
		controller.player.set_process(false)
		for actor: CombatActor in controller.enemies: actor.set_process(false)
		await process_frame
		controller._open_skill_window()
		assert(controller.skill_window.visible and paused and not controller.skill_window.draft.editable)
		controller.skill_window._choose_job(&"")
		controller.skill_window._select(&"fireball")
		await _capture(viewport, directory, "game_tree_%d" % extent.x)
		controller.skill_window._tree = false
		controller.skill_window._render_skills()
		await _capture(viewport, directory, "game_list_%d" % extent.x)
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		viewport.push_input(escape)
		assert(not controller.skill_window.visible and not paused)
		await _capture(viewport, directory, "game_shared_icons_%d" % extent.x)
		controller._show_result(false)
		controller.free()
		paused = false
		viewport.free()
		print("SKILL_UX_NATIVE ", JSON.stringify({"viewport":[extent.x,extent.y], "lobby_windows":2, "views":["tree","list"], "only_owned_jobs":true,"pending_not_granted":true,"actual_escape":true,"bindings":24}))
	await _cluster_windows(directory)
	await _icon_sheet(directory, 32)
	await _icon_sheet(directory, 64)
	print("SKILL_UX_NATIVE_OK")
	quit(0)
func _capture(viewport: SubViewport, directory: String, filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(directory + "/" + filename + ".png") == OK)

func _icon_sheet(directory: String, pixels: int) -> void:
	var ids: Array[StringName] = []
	ids.assign(ClassCatalog._skills.keys())
	ids.sort()
	var cell := pixels + 32
	var viewport := SubViewport.new()
	viewport.size = Vector2i(cell * 16, cell * ceili(float(ids.size()) / 8.0))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for index: int in ids.size():
		for background: int in 2:
			var rect := ColorRect.new()
			rect.color = Color("edf0f4") if background == 0 else Color("132130")
			rect.position = Vector2((index % 8 * 2 + background) * cell, floori(float(index) / 8.0) * cell)
			rect.size = Vector2(cell-2, cell-2)
			viewport.add_child(rect)
			var icon := TextureRect.new()
			icon.texture = SkillPresentation.icon(ids[index])
			assert(icon.texture != null)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.size = Vector2(pixels, pixels)
			icon.position = Vector2(16, 10)
			rect.add_child(icon)
			var label := Label.new()
			label.text = str(index+1)
			label.add_theme_font_size_override("font_size", 10)
			label.add_theme_color_override("font_color", Color("203149") if background == 0 else Color.WHITE)
			label.position = Vector2(12, pixels+11)
			rect.add_child(label)
	await _capture(viewport, directory, "icon_contact_%d" % pixels)
	viewport.free()
	print("SKILL_ICON_NATIVE ", JSON.stringify({"icons":ids.size(),"pixels":pixels,"backgrounds":2}))

func _native_drag(viewport: SubViewport, origin: Vector2, destination: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = origin
	motion.global_position = origin
	viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = origin
	press.global_position = origin
	viewport.push_input(press, true)
	await process_frame
	var moving := InputEventMouseMotion.new()
	moving.button_mask = MOUSE_BUTTON_MASK_LEFT
	moving.position = origin + Vector2(30, 0)
	moving.global_position = moving.position
	moving.relative = Vector2(30, 0)
	viewport.push_input(moving, true)
	await process_frame
	moving = InputEventMouseMotion.new()
	moving.button_mask = MOUSE_BUTTON_MASK_LEFT
	moving.position = destination
	moving.global_position = destination
	moving.relative = destination - origin - Vector2(30, 0)
	viewport.push_input(moving, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = destination
	release.global_position = destination
	viewport.push_input(release, true)
	await process_frame
	await process_frame

func _cluster_windows(directory: String) -> void:
	for evolution: StringName in [&"defender", &"berserker"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var store_path := ProjectSettings.globalize_path(directory + "/profile_%s_%d" % [evolution, Time.get_ticks_usec()])
		var facade := ProfileFacade.new(ProfileStore.new(store_path, ProfileCatalog.pilot()), ProfileRewardResolver.pilot_progression())
		assert(facade.create_character("create", 0, "Evoluções", &"swordsman")["ok"])
		var id := facade.current_profile().characters[0].character_id
		assert(facade.grant_playtest_progression("entry", facade.current_profile().revision, id, &"prepare_evolution")["ok"])
		assert(facade.change_evolution("evolve", facade.current_profile().revision, id, evolution)["ok"])
		assert(facade.grant_playtest_progression("cap", facade.current_profile().revision, id, &"max_levels")["ok"])
		var purchases: Array[StringName] = [&"dash", &"dash"]
		if evolution == &"defender": purchases.append_array([&"shield_wall", &"shield_wall", &"defender_counterstroke", &"defender_counterstroke", &"defender_anchor", &"defender_anchor", &"defender_guard_return", &"defender_guard_return", &"defender_riposte", &"defender_retreat_guard"])
		else: purchases.append_array([&"fury", &"fury", &"fury", &"berserker_rupture", &"berserker_rupture", &"berserker_wound_leap", &"berserker_wound_leap", &"berserker_pursuit", &"berserker_pursuit", &"berserker_execution", &"berserker_blood_rift", &"berserker_blood_rift", &"berserker_blood_rift", &"berserker_pursuit_cut", &"berserker_deep_bleeding"])
		for index: int in purchases.size(): assert(facade.learn_skill("learn-%d" % index, facade.current_profile().revision, id, purchases[index])["ok"])
		var menu := MenuScript.new()
		menu.set_profile_facade(facade)
		menu.set_profile_directory(store_path)
		viewport.add_child(menu)
		menu.menu_tabs.current_tab = 1
		menu.skill_window._choose_job(evolution)
		assert(menu.skill_window._jobs == [&"", evolution])
		assert(menu.skill_window.skill_entries.size() == 9)
		menu.skill_window._select(&"defender_riposte" if evolution == &"defender" else &"berserker_pursuit_cut")
		await _capture(viewport, directory, "%s_tree" % evolution)
		menu.skill_window._scroll.scroll_vertical = 400
		await _capture(viewport, directory, "%s_tree_lower" % evolution)
		menu.skill_window._tree = false
		menu.skill_window._render_skills()
		menu.skill_window._scroll.scroll_vertical = 0
		await _capture(viewport, directory, "%s_list" % evolution)
		menu.free()
		viewport.free()
		print("SKILL_CLUSTER_NATIVE ", evolution, " owned_jobs=2 skills=9")
