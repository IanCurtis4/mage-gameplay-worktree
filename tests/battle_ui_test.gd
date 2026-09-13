extends SceneTree

var checks := 0
var failures := 0
var _test_pointer := Vector2.ZERO

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_intent()
	_test_targeting()
	_test_geometry()
	_test_strike_feedback()
	_test_preferences()
	await _test_controller_input()
	print("UI de batalha: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_intent() -> void:
	var intent := CastIntent.new()
	_check(intent.press(&"slash") == &"" and intent.active_skill == &"slash", "default key press only selects a skill")
	_check(intent.release(&"slash") == &"" and intent.active_skill == &"slash", "key release preserves click-confirmed aim")
	_check(intent.confirm() == &"slash" and intent.confirm() == &"", "confirmation consumes aim exactly once")
	intent.set_mode(CastIntent.Mode.RELEASE)
	intent.press(&"slash")
	intent.press(&"dash")
	_check(intent.release(&"slash") == &"" and intent.release(&"dash") == &"dash", "only release of the currently selected skill casts")
	intent.press(&"slash")
	intent.confirm()
	_check(intent.release(&"slash") == &"", "release after click never duplicates the cast")
	intent.press(&"slash")
	intent.cancel()
	_check(intent.release(&"slash") == &"", "cancel prevents release casting")
	intent.set_mode(CastIntent.Mode.INSTANT)
	_check(intent.press(&"dash") == &"dash" and intent.active_skill == &"", "smart cast emits once on key press without lingering aim")

func _test_targeting() -> void:
	var first := CombatActor.new()
	var second := CombatActor.new()
	first.setup("A", Color.WHITE, RpgStats.derive({}), 19.0)
	second.setup("B", Color.WHITE, RpgStats.derive({}), 19.0)
	root.add_child(first)
	root.add_child(second)
	first.position = Vector2(300, 300)
	second.position = Vector2(390, 300)
	var actors: Array[CombatActor] = [first, second]
	var point := Vector2(350, 282)
	_check(BattleTargeting.pick(point, actors) == second, "acquisition chooses nearest assisted body")
	_check(BattleTargeting.pick(point, actors, first) == first, "small cursor shifts retain the displayed target")
	_check(BattleTargeting.pick(Vector2(385, 282), actors, first) == second, "direct body click overrides a retained target")
	_check(BattleTargeting.pick(Vector2(221, 282), actors, first) == first and BattleTargeting.pick(Vector2(219, 282), actors, first) == null, "lock exits at a finite mouse distance")
	_check(BattleTargeting.pick(point, actors, first, false) == null, "assistance can be disabled for precise targeting")
	first.health.current_hp = 0.0
	_check(BattleTargeting.pick(point, actors, first) == second, "dead target is never retained")
	first.free()
	second.free()

func _test_geometry() -> void:
	var outline := SkillGeometry.cone_outline(Vector2.ZERO, Vector2.RIGHT, PlayerActor.SLASH_RANGE, PlayerActor.SLASH_HALF_ANGLE)
	_check(outline.size() == 35 and outline[0] == Vector2.ZERO and outline[-1] == Vector2.ZERO, "cone preview is a closed footprint")
	_check(SkillGeometry.cone_contains(Vector2(154, 0), Vector2.RIGHT, PlayerActor.SLASH_RANGE, PlayerActor.SLASH_HALF_ANGLE) and not SkillGeometry.cone_contains(Vector2(156, 0), Vector2.RIGHT, PlayerActor.SLASH_RANGE, PlayerActor.SLASH_HALF_ANGLE), "preview and damage share the range boundary")

func _test_strike_feedback() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 800), [], 22.0)
	var player := PlayerActor.new()
	player.configure(nav, RunState.new())
	root.add_child(player)
	player.set_process(false)
	player.position = Vector2(400, 400)
	var right := CombatActor.new()
	var left := CombatActor.new()
	for actor: CombatActor in [right, left]:
		actor.setup("Alvo", Color.WHITE, RpgStats.derive({"vit": 10}), 19.0)
		root.add_child(actor)
		actor.set_process(false)
	right.position = Vector2(480, 400)
	left.position = Vector2(320, 400)
	player.attack_requested.connect(func(request: DamageRequest, victim: CombatActor) -> void: victim.health.apply(request, 0.0, 0.99))
	var enemies: Array[CombatActor] = [right, left]
	var origin := player.position
	player.use_slash(player.aim_direction(origin + Vector2(1000, 0)), enemies)
	_check(right.health.current_hp < right.health.max_hp and left.health.current_hp == left.health.max_hp, "distant cursor damages enemies on its side of the cone only")
	player.pursue(left)
	player._process(0.01)
	_check(player._last_facing.x < 0.0 and player._slash_facing == Vector2.RIGHT and player._slash_origin == origin, "opposite automatic strike cannot rotate the active cone effect")
	_check(is_equal_approx(player._basic_visual_radius, 80.0), "auto effect reaches the target at a valid distance beyond the old 62 px arc")
	player.move_to(Vector2(600, 500))
	player._process(0.05)
	_check(player.position != origin and player._slash_origin == origin, "movement cannot drag an already resolved cone away from its footprint")
	var feedback := [0, 0]
	right.attack_missed.connect(func(_actor: CombatActor) -> void: feedback[0] += 1)
	right.damage_number.connect(func(_actor: CombatActor, _amount: int, _critical: bool) -> void: feedback[1] += 1)
	right._flash_time = 0.0
	var hp := right.health.current_hp
	var request := DamageRequest.new()
	request.target_id = right.get_instance_id()
	request.base_damage = 20.0
	request.hit_chance = 0.0
	right.health.apply(request, 0.5, 0.99)
	_check(right.health.current_hp == hp and feedback == [1, 0] and right._flash_time == 0.0, "miss emits distinct feedback without damage or a misleading hit flash")
	request.hit_chance = 1.0
	right.health.apply(request, 0.5, 0.99)
	_check(right.health.current_hp < hp and feedback == [1, 1] and right._flash_time > 0.0, "landed strike reduces HP and emits the damage flash and number")
	player.free()
	right.free()
	left.free()

func _test_preferences() -> void:
	var preferences := ControlPreferences.new()
	preferences.path = "res://.godot/verification/controls_test_%d.cfg" % Time.get_ticks_usec()
	preferences.cast_mode = CastIntent.Mode.RELEASE
	preferences.smart_lock = false
	_check(preferences.save_settings() == OK, "control preferences save successfully")
	var restored := ControlPreferences.new()
	restored.path = preferences.path
	restored.load_settings()
	_check(restored.cast_mode == CastIntent.Mode.RELEASE and not restored.smart_lock, "control preferences survive a new instance")
	var config := ConfigFile.new()
	config.set_value("battle", "cast_mode", "bad")
	config.save(preferences.path)
	var invalid := ControlPreferences.new()
	invalid.path = preferences.path
	invalid.load_settings()
	_check(invalid.cast_mode == CastIntent.Mode.CONFIRM, "invalid preferences fall back to confirmed casting")
	DirAccess.remove_absolute(preferences.path)

func _test_controller_input() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	var controller := current_scene as RunController
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	controller.control_preferences.path = "res://.godot/verification/ui_controls_%d.cfg" % Time.get_ticks_usec()
	await process_frame
	await process_frame
	var world_aim := controller.player.position + Vector2(300, 0)
	_move_mouse(controller.get_global_transform_with_canvas() * world_aim)
	controller.cast_intent.set_mode(CastIntent.Mode.CONFIRM)
	_key(KEY_Q, true)
	_check(controller.cast_intent.active_skill == &"slash" and controller.player.mana == 50.0 and controller.battle_indicators.skill == &"slash", "real Q event opens cone preview without spending mana")
	_key(KEY_Q, false)
	_check(controller.cast_intent.active_skill == &"slash" and controller.player.mana == 50.0, "confirm mode waits for a mouse click after release")
	_click(MOUSE_BUTTON_LEFT)
	_check(controller.player.mana == 35.0 and controller.cast_intent.active_skill == &"" and controller.player._path.is_empty(), "world click casts once without issuing movement")
	_check(controller.player._slash_facing.dot(Vector2.RIGHT) > 0.999, "mouse confirmation beyond cone range keeps the clicked direction through camera transform")
	_key(KEY_Q, false)
	_check(controller.player.mana == 35.0, "late key release does not double cast")
	controller.player.mana = 50.0
	controller.player.slash_cooldown = 0.0
	controller.cast_intent.set_mode(CastIntent.Mode.RELEASE)
	_key(KEY_Q, true)
	_key(KEY_Q, false)
	_check(controller.player.mana == 35.0 and controller.cast_intent.active_skill == &"", "release mode launches through actual key-up dispatch")
	controller.player.mana = 50.0
	controller.player.slash_cooldown = 0.0
	_key(KEY_Q, true)
	_click(MOUSE_BUTTON_RIGHT)
	_key(KEY_Q, false)
	_check(controller.player.mana == 50.0 and controller.cast_intent.active_skill == &"", "right-click cancels and suppresses later key-up casting")
	_key(KEY_Q, true)
	_key(KEY_ESCAPE, true)
	_key(KEY_Q, false)
	_check(controller.player.mana == 50.0 and not paused, "Escape cancels aim without opening settings or spending resources")
	_key(KEY_Q, true)
	_move_mouse(controller.battle_controls.settings_button.get_global_rect().get_center())
	_key(KEY_Q, false)
	_check(controller.player.mana == 50.0 and controller.cast_intent.active_skill == &"", "release over interactive UI cancels instead of casting into the world")
	_move_mouse(controller.get_global_transform_with_canvas() * world_aim)
	controller.cast_intent.set_mode(CastIntent.Mode.INSTANT)
	_key(KEY_Q, true)
	_check(controller.player.mana == 35.0 and controller.cast_intent.active_skill == &"", "smart cast acts immediately through real input")
	controller.player.slash_cooldown = 0.0
	_key(KEY_Q, true, true)
	_key(KEY_Q, false)
	_check(controller.player.mana == 35.0, "key repeat and release never recast smart cast")
	controller.player.mana = 50.0
	controller.cast_intent.set_mode(CastIntent.Mode.CONFIRM)
	_key(KEY_W, true)
	_move_mouse(controller.battle_controls.settings_button.get_global_rect().get_center())
	_click(MOUSE_BUTTON_LEFT)
	_check(paused and controller.battle_controls.settings_overlay.visible and controller.player.mana == 50.0 and controller.cast_intent.active_skill == &"", "settings click consumes input, cancels aim, and pauses without casting")
	controller.battle_controls.mode_option.select(CastIntent.Mode.RELEASE)
	controller.battle_controls.mode_option.item_selected.emit(CastIntent.Mode.RELEASE)
	_check(controller.cast_intent.mode == CastIntent.Mode.RELEASE and controller.control_preferences.cast_mode == CastIntent.Mode.RELEASE, "visible mode selector applies the chosen preference")
	controller.encounter_active = false
	controller.run_state.queue_choice()
	controller._open_augment_menu()
	_check(not controller.augment_overlay.visible and controller.battle_controls.settings_overlay.visible and paused, "reward hotkey cannot stack another pause menu over controls")
	controller.run_state.reset()
	controller.encounter_active = true
	_key(KEY_ESCAPE, true)
	_check(not paused and not controller.battle_controls.settings_overlay.visible, "Escape resumes battle from controls")
	_move_mouse(controller.get_global_transform_with_canvas() * world_aim)
	_key(KEY_Q, true)
	controller.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_key(KEY_Q, false)
	_check(controller.cast_intent.active_skill == &"" and controller.player.mana == 50.0, "window focus loss discards held aim")
	controller.player.position = Vector2(500, 350)
	controller.battle_indicators.show_aim(&"dash", controller.player, Vector2(900, 350), true)
	var preview_endpoint := controller.battle_indicators.endpoint
	controller.player.use_dash(Vector2.RIGHT)
	controller.player._process(PlayerActor.DASH_DURATION)
	_check(controller.player.position.distance_to(preview_endpoint) < 0.01 and preview_endpoint.x < 610.0, "dash endpoint indicator exactly matches obstacle-clipped skill movement")
	controller.player.mana = 0.0
	controller.cast_intent.active_skill = &"slash"
	_move_mouse(Vector2(700, 450))
	controller._update_aim(world_aim)
	_check(not controller.battle_indicators.available and controller.battle_controls.aim_label.text.contains("SEM MANA"), "unavailable preview communicates a blocked skill")
	_click(MOUSE_BUTTON_LEFT)
	_check(controller.player.mana == 0.0 and controller.status_label.text.contains("indisponível"), "confirmation revalidates mana and reports failure without movement")
	controller.player.mana = 50.0
	controller.player.slash_cooldown = 0.0
	_move_mouse(controller.battle_controls.skill_buttons[&"slash"].get_global_rect().get_center())
	_click(MOUSE_BUTTON_LEFT)
	_check(controller.cast_intent.active_skill == &"slash" and controller.player.mana == 50.0, "clicking a skill card selects without casting through the card")
	controller.encounter_active = false
	controller.run_state.queue_choice()
	controller._open_augment_menu()
	_check(paused and controller.cast_intent.active_skill == &"", "reward pause clears outstanding targeting intent")
	_key(KEY_Q, false)
	_check(controller.player.mana == 50.0, "release during reward pause never queues a delayed cast")
	controller._confirm_augment(controller.run_state.current_offer[0].id)
	controller.cast_intent.active_skill = &"slash"
	var lethal := DamageRequest.new()
	lethal.target_id = controller.player.get_instance_id()
	lethal.base_damage = 9999.0
	lethal.hit_chance = 1.0
	controller.player.health.apply(lethal, 0.0, 0.99)
	_check(controller.run_finished and controller.cast_intent.active_skill == &"" and controller.battle_indicators.skill == &"", "death removes pending aim and preview")
	paused = false
	DirAccess.remove_absolute(controller.control_preferences.path)
	controller.queue_free()
	await process_frame

func _key(code: Key, pressed: bool, repeat: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = repeat
	root.push_input(event)

func _move_mouse(point: Vector2) -> void:
	_test_pointer = point
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event, true)

func _click(button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = _test_pointer
		root.push_input(event, true)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
