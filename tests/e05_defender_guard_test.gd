extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := _player(navigation, true)
	player.global_position = Vector2(400, 350)
	root.add_child(player)
	player.set_process(false)
	var enemy := _enemy(Vector2(470, 350))
	root.add_child(enemy)
	enemy.set_process(false)
	var emitted: Array[DamageRequest] = []
	player.attack_requested.connect(func(request: DamageRequest, _target: CombatActor) -> void: emitted.append(request))
	_check(player.use_defender_counterstroke(Vector2.RIGHT, [enemy]) and emitted.size() == 1 and player.defender_counter_guard_remaining == PlayerActor.DEFENDER_COUNTER_GUARD_DURATION, "counterstroke commits one hit and captures a short guard facing")
	var base_power := player.stat_breakdown.value(&"melee_attack") * 1.05
	_check(is_equal_approx(emitted[0].physical_damage, base_power) and not player.has_defender_token(), "unempowered entry R1 uses only its base weight")
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var front := _request(enemy, player, false)
	var guarded := player.apply_damage(front, rng)
	_check(guarded["landed"] and guarded["actual_damage"] > 0.0 and player.has_defender_token(), "front direct hit grants one token after real guard mitigation")
	_check(player.defender_feedback_text().contains("CONTRA-ATAQUE PRONTO") and player.defender_feedback_text().contains("GUARDA FRONTAL"), "runtime feedback exposes token and captured frontal guard")
	var first_expiry := player.defender_token_remaining
	var back_source := _enemy(Vector2(330, 350))
	root.add_child(back_source)
	back_source.set_process(false)
	var back := player.apply_damage(_request(back_source, player, false), rng)
	_check(back["damage"] > guarded["damage"] and player.defender_token_remaining == first_expiry, "flank is not mitigated and does not renew the token")
	player.mage_cooldowns[&"defender_counterstroke"] = 0.0
	emitted.clear()
	_check(player.use_defender_counterstroke(Vector2.RIGHT, [enemy]) and emitted.size() == 1 and is_equal_approx(emitted[0].physical_damage, player.stat_breakdown.value(&"melee_attack") * 1.35) and not player.has_defender_token(), "next valid counterstroke consumes token once at commit for R1 bonus")
	_check(player.defender_feedback_text().contains("TOKEN CONSUMIDO"), "token consumption has transient runtime feedback")
	var sp_before_fail := player.current_sp
	var cooldown_before_fail := player.skill_cooldown(&"defender_counterstroke")
	_check(not player.use_defender_counterstroke(Vector2.RIGHT, [enemy]) and player.current_sp == sp_before_fail and player.skill_cooldown(&"defender_counterstroke") == cooldown_before_fail, "failed cooldown check spends neither SP nor token")
	player.clear_defender_state()
	_check(not player.has_defender_token() and not player.has_defender_anchor() and player.defender_counter_guard_remaining == 0.0, "encounter cleanup clears token and guard")
	player.queue_free()
	enemy.queue_free()
	back_source.queue_free()
	await process_frame

	var shield_player := _player(navigation, false)
	shield_player.global_position = Vector2(400, 350)
	root.add_child(shield_player)
	shield_player.set_process(false)
	shield_player.current_sp = shield_player.max_sp - 30.0
	_check(shield_player.use_shield_wall(Vector2.RIGHT), "learned entry need not be equipped to activate the base shield posture")
	var before_return := shield_player.current_sp
	_check(shield_player.absorb_shield_projectile() and shield_player.has_defender_token() and is_equal_approx(shield_player.current_sp, before_return + 2.0), "one intercepted frontal projectile grants token and equipped Resguardo SP")
	var unequipped_sp := shield_player.current_sp
	_check(not shield_player.use_defender_counterstroke(Vector2.RIGHT, []) and shield_player.has_defender_token() and shield_player.current_sp == unequipped_sp, "learned but unequipped entry cannot spend the token")
	var after_return := shield_player.current_sp
	_check(shield_player.absorb_shield_projectile() and is_equal_approx(shield_player.current_sp, after_return), "second interception in the 2s internal window renews token without duplicate SP")
	var hud := RunController.new()
	hud.player = shield_player
	hud.run_state = shield_player.run_state
	hud.health_label = Label.new()
	hud.sp_label = Label.new()
	hud.skill_label = Label.new()
	hud.defender_status_label = Label.new()
	hud.augment_button = Button.new()
	for widget: Control in [hud.health_label, hud.sp_label, hud.skill_label, hud.defender_status_label, hud.augment_button]:
		hud.add_child(widget)
	hud._update_hud()
	_check(hud.defender_status_label.visible and hud.defender_status_label.text.contains("CONTRA-ATAQUE PRONTO"), "HUD reflects live token availability without an equipped entry")
	shield_player._process(PlayerActor.DEFENDER_TOKEN_DURATION + 0.1)
	hud._update_hud()
	_check(not shield_player.has_defender_token() and hud.defender_status_label.text.contains("TOKEN EXPIROU"), "token expiry appears in the HUD")
	shield_player._process(PlayerActor.DEFENDER_TOKEN_NOTICE_DURATION + 0.1)
	hud._update_hud()
	_check(hud.defender_status_label.text.contains("CONTRA-ATAQUE SEM TOKEN"), "expiry notice returns to the neutral HUD state")
	hud.free()
	shield_player.clear_defender_state()
	var secondary_enemy := _enemy(Vector2(470, 350))
	root.add_child(secondary_enemy)
	secondary_enemy.set_process(false)
	var secondary := shield_player.apply_damage(_request(secondary_enemy, shield_player, true), rng)
	_check(secondary["landed"] and not shield_player.has_defender_token(), "secondary frontal damage cannot create a token")
	shield_player.queue_free()
	secondary_enemy.queue_free()
	await process_frame
	print("E05 Defendente guarda: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _player(navigation: ArenaNavigation, equip_counter: bool) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"defender"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"defender")
	snapshot.skill_ranks = {&"defender_counterstroke": 1, &"defender_guard_return": 1, &"shield_wall": 1}
	snapshot.active_slots = [&"defender_counterstroke" if equip_counter else &"shield_wall", null, null, null, null]
	snapshot.passive_slots = [&"defender_guard_return", null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("defender-guard", snapshot))
	return player

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Teste", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	return enemy

func _request(source: CombatActor, target: PlayerActor, secondary: bool) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = target.get_instance_id()
	request.physical_damage = 20.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.is_secondary = secondary
	return request

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
