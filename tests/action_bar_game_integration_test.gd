extends SceneTree
## End-to-end viewport dispatch, paid APIs and isolated durable bar changes.

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174334"
var checks := 0
var failures := 0
var directory := ""
var pointer := Vector2.ZERO
var controller: RunController

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/action_game_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1280, 720)
	await _sentinel()
	await _geometer()
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file_name))
	DirAccess.remove_absolute(directory)
	print("Action bars game integration: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _snapshot(base: StringName, evolution: StringName, skills: Array[StringName]) -> BuildSnapshot:
	var catalog := ProfileCatalog.pilot()
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Input real", base)
	character.evolution_id = evolution
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	for skill: StringName in skills:
		if int(catalog.effective_skill_ranks(base, evolution, character.purchased_skill_ranks, {}).get(skill, 0)) == 0:
			_check(CharacterProgression.learn_skill(character, catalog, skill)["ok"], "input fixture buys %s legally" % skill)
	var summary := CharacterProgression.summary(character, catalog)
	return BuildSnapshot.from_character(character, summary["base_level"], summary["job_level"], summary["effective_skill_ranks"], catalog.skill_ids_for_identity(base, evolution), catalog)

func _mount(run: RunState, facade: ProfileFacade = null) -> void:
	RunController.pending_run_state = run
	RunController.pending_run_facade = facade
	RunController.pending_training_mode = false
	controller = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(controller)
	current_scene = controller
	controller.control_preferences.path = directory.path_join("controls.cfg")
	controller.control_preferences.restore_bindings()
	controller.battle_controls.set_action_bar(controller.player.available_skill_ids(), controller.action_slots, controller.control_preferences)
	controller.set_process(false)
	controller.player.set_process(false)
	controller.navigation.configure(Rect2(0, 0, 1500, 1000), [], 22.0)
	controller.player.position = Vector2(400, 420)
	for index: int in controller.enemies.size():
		controller.enemies[index].set_process(false)
		controller.enemies[index].position = Vector2(650, 420) if index == 0 else Vector2(1100, 850)
		controller.enemies[index].health.current_hp = controller.enemies[index].health.max_hp
	controller._process(0.0)
	await process_frame
	await process_frame
	_point_world(Vector2(650, 402))
	_check(controller._world_pointer_available(), "fixture mouse points to battle world")

func _unmount() -> void:
	paused = false
	controller.queue_free()
	await process_frame
	controller = null

func _reset(mode: int = CastIntent.Mode.RELEASE) -> void:
	controller._cancel_casting()
	controller.cast_intent.set_mode(mode)
	controller.player.current_sp = controller.player.max_sp
	controller.player.sentinel_state.focus = 80.0
	controller.player.mage_cooldowns.clear()
	_point_world(Vector2(650, 402))

func _sentinel() -> void:
	var snapshot := _snapshot(&"archer", &"sentinel", [&"sentinel_observe", &"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot", &"sentinel_concussion_shot", &"sentinel_absolute_focus", &"double_shot"])
	snapshot.action_slots = ActionBarLayout.empty()
	snapshot.action_slots[0] = &"sentinel_headshot"
	snapshot.action_slots[12] = &"sentinel_piercing_shot"
	snapshot.action_slots[7] = &"sentinel_concussion_shot"
	# Real durable facade + active run, not a mock of the layout signal.
	var character := CharacterState.new(snapshot.character_id, "Sentinela input", &"archer")
	character.evolution_id = &"sentinel"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	character.purchased_skill_ranks = snapshot.skill_ranks.duplicate()
	character.purchased_skill_ranks.erase(&"sentinel_headshot")
	character.action_slots = snapshot.action_slots.duplicate()
	var profile := ProfileState.new(PROFILE_ID)
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	var store := ProfileStore.new(directory, ProfileCatalog.pilot())
	_check(store.commit(profile)["ok"], "game fixture durable profile valid")
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile()["ok"], "game fixture opens actual facade")
	var started := facade.start_run("game-start", facade.current_profile().revision)
	_check(started["ok"], "game fixture starts reward-session run")
	if not started["ok"]:
		return
	await _mount(started["run_state"], facade)
	var emitted: Array[StringName] = []
	var directions: Array[Vector2] = []
	controller.player.sentinel_projectile_requested.connect(func(request: DamageRequest, _target: CombatActor, direction: Vector2, _payload: Dictionary) -> void:
		emitted.append(request.skill_id)
		directions.append(direction))
	_reset()
	var initial_sp := controller.player.current_sp
	for old_key: Key in [KEY_Q, KEY_W]:
		_key(old_key, true)
		_key(old_key, false)
		_check(controller.cast_intent.active_skill == &"" and emitted.is_empty(), "old Q/W aliases never override empty/default slots")
	var extra_modifier := _event(KEY_1, true, true)
	extra_modifier.ctrl_pressed = true
	root.push_input(extra_modifier)
	_key(KEY_1, false)
	_check(controller.cast_intent.active_skill == &"" and emitted.is_empty(), "extra Ctrl modifier never aliases Alt+1 or1")
	_key(KEY_1, true)
	_check(controller.cast_intent.active_skill == &"sentinel_headshot" and controller.action_bar_input.pending_slot == 0, "1 selects first row, not Alt row")
	_check(controller.player.current_sp == initial_sp, "release keydown does not spend")
	_key(KEY_1, false)
	_check(emitted == [&"sentinel_headshot"] and controller.player.current_sp == initial_sp - controller.player.skill_cost(&"sentinel_headshot"), "1 release launches paid Headshot exactly once")
	_key(KEY_1, false)
	_check(emitted.size() == 1, "repeated release never casts twice")
	_reset()
	emitted.clear()
	initial_sp = controller.player.current_sp
	_key(KEY_1, true, true)
	_check(controller.cast_intent.active_skill == &"sentinel_piercing_shot" and controller.action_bar_input.pending_slot == 12, "Alt+1 selects captured second-row Piercing")
	_key(KEY_ALT, false)
	_check(emitted.is_empty(), "lifting Alt alone never casts")
	_key(KEY_1, false)
	_check(emitted == [&"sentinel_piercing_shot"] and controller.player.current_sp == initial_sp - controller.player.skill_cost(&"sentinel_piercing_shot"), "lifting base key after Alt casts captured skill once")
	_check(directions[-1].x > 0.99 and absf(directions[-1].y) < 0.1, "actual directional projectile uses world mouse")
	_check(controller.player.sentinel_state.focus == 60.0, "Piercing pays20 Focus once")
	_reset(CastIntent.Mode.CONFIRM)
	emitted.clear()
	_key(KEY_1, true, true)
	_key(KEY_1, false, true)
	_check(controller.cast_intent.active_skill == &"sentinel_piercing_shot" and emitted.is_empty(), "confirm mode preserves aim after exact combo release")
	_click(MOUSE_BUTTON_LEFT)
	_key(KEY_1, false)
	_check(emitted == [&"sentinel_piercing_shot"] and controller.action_bar_input.pending_slot == -1, "world click consumes key intent and clears latch")
	_reset(CastIntent.Mode.INSTANT)
	emitted.clear()
	_key(KEY_1, true, true)
	_key(KEY_1, true, true, true)
	_key(KEY_1, false)
	_check(emitted == [&"sentinel_piercing_shot"], "instant plus repeat and release yields one paid emission")
	_reset()
	emitted.clear()
	_key(KEY_1, true, true)
	_point_screen(controller.battle_controls.skill_buttons[&"sentinel_piercing_shot"].get_global_rect().get_center())
	_click(MOUSE_BUTTON_LEFT)
	_key(KEY_1, false)
	_check(emitted.is_empty() and controller.cast_intent.active_skill == &"sentinel_piercing_shot" and controller.action_bar_input.pending_slot == -1, "UI selection replaces held release intent with mouse confirmation")
	_point_world(Vector2(650, 402))
	_click(MOUSE_BUTTON_LEFT)
	_check(emitted == [&"sentinel_piercing_shot"], "UI-selected skill then world click casts once")
	_reset()
	emitted.clear()
	_key(KEY_1, true, true)
	var sp_before := controller.player.current_sp
	var focus_before := controller.player.sentinel_state.focus
	var hp_before := controller.player.health.current_hp
	controller.battle_controls.move_skill(12, 13)
	_key(KEY_1, false)
	_check(emitted.is_empty() and controller.cast_intent.active_skill == &"", "moving slot cancels held intent and late release")
	_check(controller.player.current_sp == sp_before and controller.player.sentinel_state.focus == focus_before and controller.player.health.current_hp == hp_before and controller.player.skill_cooldown(&"sentinel_piercing_shot") == 0.0, "moving slot changes no resource, cooldown or health")
	_check(facade.current_profile().character_by_id(character.character_id).action_slots[13] == &"sentinel_piercing_shot", "main layout signal persists the active character")
	controller.battle_controls.move_skill(13, 12)
	_reset()
	_check(controller.player.prepare_sentinel_explosive(), "real ammunition reserve prepared")
	var reserve_sp := controller.player.sentinel_state.reserved_sp
	var reserve_focus := controller.player.sentinel_state.reserved_focus
	_key(KEY_1, true, true)
	controller.battle_controls.begin_binding_capture(12)
	_key(KEY_Z, true)
	_key(KEY_Z, false)
	_key(KEY_1, false)
	_check(controller.cast_intent.active_skill == &"" and controller.action_bar_input.pending_slot == -1, "rebind cancels pending cast and absorbs capture")
	_check(controller.player.sentinel_state.explosive_prepared and controller.player.sentinel_state.reserved_sp == reserve_sp and controller.player.sentinel_state.reserved_focus == reserve_focus, "rebind preserves funded ammunition reserve")
	_check(controller.control_preferences.slot_for_event(_event(KEY_Z, true)) == 12, "captured remap installed without combat cast")
	controller._cancel_casting()
	controller.battle_controls.restore_bindings()
	_reset()
	emitted.clear()
	controller._toggle_settings(true)
	_check(paused, "controls editor pauses simulation")
	controller.battle_controls.begin_binding_capture(12)
	_key(KEY_ALT, true)
	_key(KEY_Z, true, true)
	_key(KEY_Z, false)
	_check(paused and emitted.is_empty() and controller.battle_controls.capture_binding == -1, "paused modifier capture never casts")
	controller._toggle_settings(false)
	controller.battle_controls.restore_bindings()
	_reset()
	var line := LineEdit.new()
	controller.ui_root.add_child(line)
	line.position = Vector2(1050, 220)
	line.size = Vector2(150, 40)
	controller.encounter_active = false
	controller.run_state.queue_choice()
	line.grab_focus()
	await process_frame
	_unicode_key(KEY_1, "1")
	_key(KEY_1, true, true)
	_key(KEY_1, false)
	_key(KEY_F8, true)
	_check(line.text == "1" and controller.cast_intent.active_skill == &"" and emitted.is_empty() and not paused, "LineEdit receives text while blocking skill and pending-reward hotkeys")
	line.release_focus()
	line.queue_free()
	var text_edit := TextEdit.new()
	controller.ui_root.add_child(text_edit)
	text_edit.position = Vector2(1000, 250)
	text_edit.size = Vector2(200, 80)
	text_edit.grab_focus()
	await process_frame
	_unicode_key(KEY_E, "e")
	_key(KEY_E, false)
	_key(KEY_F8, true)
	_check(text_edit.text == "e" and emitted.is_empty() and controller.cast_intent.active_skill == &"" and not paused, "TextEdit receives text while no skill or pending reward launches")
	text_edit.release_focus()
	text_edit.queue_free()
	await process_frame
	controller.run_state.pending_choices = 0
	controller.encounter_active = true
	_reset()
	controller.battle_controls.clear_slot(0)
	_key(KEY_1, true)
	_key(KEY_1, false)
	_check(controller.cast_intent.active_skill == &"" and &"sentinel_headshot" in controller.player.available_skill_ids(), "empty shortcut inert but learned skill remains available")
	controller.encounter_active = false
	controller.run_state.queue_choice()
	_key(KEY_E, true)
	_check(controller.cast_intent.active_skill == &"sentinel_concussion_shot" and not controller.augment_overlay.visible and not paused, "E belongs to skill even when augment reward is pending")
	_key(KEY_E, false)
	_key(KEY_F8, true)
	_check(paused and controller.augment_overlay.visible, "F8 explicitly opens pending reward")
	# Training retry copies only the latest organization into the next run.
	controller.training_mode = true
	var old_snapshot := controller.run_state.build_snapshot.copy_snapshot()
	var disk_before := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	controller.player.health.current_hp = controller.player.health.max_hp - 2.0
	controller.player.current_sp = controller.player.max_sp - 3.0
	controller.player.mage_cooldowns[&"sentinel_piercing_shot"] = 1.5
	var current_resources := [controller.player.health.current_hp, controller.player.current_sp, controller.player.skill_cooldown(&"sentinel_piercing_shot")]
	controller.battle_controls.move_skill(12, 23)
	var retry := controller._training_restart_state()
	_check(retry.build_snapshot.action_slots == controller.action_slots and retry.build_snapshot.action_slots[23] == &"sentinel_piercing_shot", "training retry inherits latest session bar")
	_check(retry.build_snapshot != controller.run_state.build_snapshot and retry.run_id.is_empty(), "training retry owns independent run and build snapshot")
	_check(controller.run_state.build_snapshot.action_slots == old_snapshot.action_slots and controller.run_state.build_snapshot.skill_ranks == old_snapshot.skill_ranks, "training organization leaves current immutable build untouched")
	_check(current_resources == [controller.player.health.current_hp, controller.player.current_sp, controller.player.skill_cooldown(&"sentinel_piercing_shot")], "constructing retry neither heals current run nor resets cooldown")
	_check(FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == disk_before, "training organization and retry helper never write durable profile")
	retry.build_snapshot.action_slots[23] = null
	_check(controller.action_slots[23] == &"sentinel_piercing_shot", "retry layout is copied, not aliased with live controls")
	await _unmount()

func _geometer() -> void:
	var snapshot := _snapshot(&"mage", &"mg_ar", [&"geometer_trace", &"geometer_translation", &"fireball"])
	snapshot.action_slots = ActionBarLayout.empty()
	snapshot.action_slots[0] = &"geometer_trace"
	snapshot.action_slots[1] = &"geometer_translation"
	await _mount(RunState.from_build("", snapshot))
	_reset(CastIntent.Mode.CONFIRM)
	controller.geometer_casting.set_process(false)
	_key(KEY_F2, true)
	var element := controller.geometer_casting.construction.grammar.selected_element
	_check(element == GeometerGeometry.ELEMENTS[1], "F2 chooses explicit Geometer element")
	_key(KEY_1, true)
	_check(controller.cast_intent.active_skill == &"geometer_trace" and controller.geometer_casting.construction.grammar.selected_element == element, "Geometer1 selects skill and never seizes element")
	_key(KEY_1, false)
	controller._cancel_casting()
	_key(KEY_2, true)
	_check(controller.cast_intent.active_skill == &"geometer_translation" and controller.geometer_casting.construction.grammar.selected_element == element, "Geometer2 selects second slot, no element change")
	controller._cancel_casting()
	_key(KEY_F1, true)
	_check(controller.geometer_casting.construction.grammar.selected_element == GeometerGeometry.ELEMENTS[0], "F1 chooses first element")
	for button: Button in controller.geometer_element_buttons.values():
		_check(button.is_visible_in_tree(), "element buttons remain visible")
	controller.geometer_element_buttons[GeometerGeometry.ELEMENTS[2]].pressed.emit()
	_check(controller.geometer_casting.construction.grammar.selected_element == GeometerGeometry.ELEMENTS[2], "visible element button remains usable")
	await _unmount()

func _point_world(point: Vector2) -> void:
	_point_screen(controller.get_global_transform_with_canvas() * point)

func _point_screen(point: Vector2) -> void:
	pointer = point
	var event := InputEventMouseMotion.new()
	event.position = pointer
	root.push_input(event, true)

func _unicode_key(code: Key, glyph: String) -> void:
	var event := _event(code, true)
	event.unicode = glyph.unicode_at(0)
	root.push_input(event)

func _event(code: Key, pressed: bool, alt := false, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.alt_pressed = alt
	event.echo = echo
	return event

func _key(code: Key, pressed: bool, alt := false, echo := false) -> void:
	root.push_input(_event(code, pressed, alt, echo))
	for node: Node in get_nodes_in_group("player_projectiles"):
		node.set_process(false)

func _click(button: MouseButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = down
		event.position = pointer
		root.push_input(event, true)
	for node: Node in get_nodes_in_group("player_projectiles"):
		node.set_process(false)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
