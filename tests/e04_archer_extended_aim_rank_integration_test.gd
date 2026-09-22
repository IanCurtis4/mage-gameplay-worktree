extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table_and_gate()
	_check_ranked_buff_runtime()
	await _check_self_input_hud_preview_and_captured_ranges()
	print("E04 Mira Estendida por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table_and_gate() -> void:
	var definition := ClassCatalog.skill_definition(&"extended_aim")
	var expected_durations: Array[float] = [4.0, 5.0, 6.0, 7.0, 8.0]
	var expected_costs: Array[float] = [16.0, 17.0, 18.0, 19.0, 20.0]
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.EXTENDED_AIM and definition.targeting == SkillDefinition.Targeting.SELF, "Mira Estendida exposes the first valid self-targeted rank catalog and closed handler")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_durations[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Mira Estendida R%d owns its approved duration and SP cost" % rank)
		_check(values.cooldown == 12.0 and values.range == 0.0 and values.projectile_speed == 0.0, "Mira Estendida R%d preserves cooldown and owns no target range or projectile" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0, "Mira Estendida R%d remains instant" % rank)
		_check(values.precision_weight == 0.0 and values.physical_weight == 0.0 and values.magic_weight == 0.0 and values.effect_ids == [&"extended_aim"], "Mira Estendida R%d is a typed non-damaging buff" % rank)
	var profile := ProfileCatalog.pilot()
	_check(profile.skill_metadata(&"extended_aim").get("max_purchased_rank") == 5 and not profile.base_class_is_available(&"archer"), "profile knows the fourth Archer active but keeps the class gated until a passive exists")

func _check_ranked_buff_runtime() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(-100, -100, 1400, 900), [], 20.0)
	var rank_one := _player(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("extended-aim-r5", rank_five_source)
	rank_five_source.skill_ranks[&"extended_aim"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	root.add_child(rank_one)
	root.add_child(rank_five)
	var distant_target := _target(Vector2(450, 0))
	_check(not rank_one.can_basic_attack(distant_target) and rank_one.archer_basic_projectile_range() == 520.0 and rank_one.skill_range(&"double_shot") == 520.0 and rank_one.skill_range(&"piercing_arrow") == 600.0 and rank_one.skill_range(&"arrow_rain") == 480.0, "all ranged consumers expose their unbuffed baselines before activation")
	var rank_one_sp := rank_one.current_sp
	var rank_five_sp := rank_five.current_sp
	_check(rank_one.use_extended_aim() and rank_five.use_extended_aim(), "R1 and R5 both activate the self buff without a target point")
	_check(rank_one.extended_aim_remaining == 4.0 and rank_five.extended_aim_remaining == 8.0 and rank_five.skill_rank(&"extended_aim") == 5, "snapshot rank controls only the captured duration")
	_check(rank_one.current_sp == rank_one_sp - 16.0 and rank_five.current_sp == rank_five_sp - 20.0, "each rank debits its approved SP cost exactly once")
	_check(rank_one.skill_cooldown(&"extended_aim") == StatCalculator.effective_cooldown(12.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"extended_aim") == StatCalculator.effective_cooldown(12.0, rank_five.stat_breakdown), "both ranks apply the fixed cooldown through the shared calculator")
	_check(rank_one.can_basic_attack(distant_target) and rank_one.basic_attack_distance(distant_target) == 499.0 and rank_one.archer_basic_projectile_range() == 640.0, "buff extends both Archer engagement and basic projectile distance by the fixed amount")
	_check(rank_one.skill_range(&"double_shot") == 640.0 and rank_one.skill_range(&"piercing_arrow") == 720.0 and rank_one.skill_range(&"arrow_rain") == 600.0, "buff extends every delivered ranged Archer active by exactly 120")
	_check(rank_one.skill_range(&"extended_aim") == 0.0 and rank_one.arrow_rain_center(Vector2(1000, 0)) == Vector2(600, 0), "buff never extends itself while point placement consumes the effective range")
	paused = true
	rank_one._process(2.0)
	paused = false
	_check(rank_one.extended_aim_remaining == 4.0, "tree pause freezes the buff timer")
	rank_one._process(1.5)
	_check(is_equal_approx(rank_one.extended_aim_remaining, 2.5) and rank_one.has_extended_aim(), "live simulation advances only the remaining duration")
	rank_one._process(3.0)
	_check(not rank_one.has_extended_aim() and rank_one.archer_basic_projectile_range() == 520.0 and rank_one.skill_range(&"double_shot") == 520.0 and not rank_one.can_basic_attack(distant_target), "expiration restores every baseline without altering catalog values")
	rank_five.mage_cooldowns[&"extended_aim"] = 0.0
	rank_five.extended_aim_remaining = 3.0
	var before_refresh_sp := rank_five.current_sp
	_check(rank_five.use_extended_aim() and rank_five.extended_aim_remaining == 8.0 and rank_five.current_sp == before_refresh_sp - 20.0, "legal reactivation replaces remaining time with full ranked duration")
	_check(rank_five.skill_range(&"double_shot") == 640.0, "reactivation refreshes duration without stacking the fixed range bonus")
	rank_five.mage_cooldowns[&"extended_aim"] = 0.0
	rank_five.current_sp = 19.0
	_check(not rank_five.use_extended_aim() and rank_five.extended_aim_remaining == 8.0 and rank_five.current_sp == 19.0, "failed reactivation neither spends nor truncates the active buff")
	var invalid_rank := _player(navigation, 6)
	root.add_child(invalid_rank)
	_check(invalid_rank.skill_rank_definition(&"extended_aim") == null and invalid_rank.skill_cost(&"extended_aim") == 0.0 and not invalid_rank.use_extended_aim(), "invalid runtime rank is ineligible instead of falling back to R1 values")
	rank_five._on_health_died(rank_five.get_instance_id())
	_check(not rank_five.has_extended_aim() and rank_five.extended_aim_remaining == 0.0, "death clears the temporary buff synchronously")
	for node: Node in [rank_one, rank_five, invalid_rank, distant_target]:
		node.queue_free()

func _check_self_input_hud_preview_and_captured_ranges() -> void:
	RunController.pending_run_state = RunState.from_build("extended-aim-preview", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	_check(controller._key_skill(KEY_S) == &"extended_aim", "fourth equipped Archer active binds to S")
	controller.cast_intent.set_mode(CastIntent.Mode.CONFIRM)
	var sp_before := controller.player.current_sp
	var self_key := InputEventKey.new()
	self_key.keycode = KEY_S
	self_key.pressed = true
	controller._unhandled_input(self_key)
	_check(controller.player.has_extended_aim() and controller.player.extended_aim_remaining == 8.0 and controller.player.current_sp == sp_before - 20.0, "SELF key input activates immediately without consuming mouse position")
	_check(controller.cast_intent.active_skill.is_empty() and controller.player.skill_cooldown(&"extended_aim") == StatCalculator.effective_cooldown(12.0, controller.player.stat_breakdown), "self activation leaves no pending intent and starts one cooldown")
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"extended_aim"]
	_check(controller.skill_label.text.contains("Mira Estendida R5") and controller.skill_label.text.contains("ATIVA 8.0s") and card.text.contains("20 SP") and card.text.contains("ATIVA 8.0s"), "HUD exposes rank, cost and active duration")
	controller.battle_indicators.show_aim(&"extended_aim", controller.player, controller.player.global_position + Vector2(900, 300), true)
	_check(controller.battle_indicators.endpoint == controller.player.global_position and controller.battle_indicators.active_range == 0.0, "SELF preview anchors to the actor and owns no arbitrary ground point")
	controller.cast_intent.active_skill = &"double_shot"
	var aim_point := controller.player.global_position + Vector2(1000, 0)
	controller._update_aim(aim_point)
	_check(controller.battle_indicators.active_range == 640.0 and controller.battle_indicators.endpoint == controller.player.global_position + Vector2.RIGHT * 640.0, "directional preview consumes the buffed Double Shot range")
	controller.cast_intent.active_skill = &"arrow_rain"
	controller._update_aim(aim_point)
	_check(controller.battle_indicators.active_range == 600.0 and controller.battle_indicators.endpoint == controller.player.global_position + Vector2.RIGHT * 600.0, "point preview consumes the buffed Arrow Rain placement range")
	var basic_request := DamageRequest.new()
	basic_request.skill_id = &"basic_attack"
	controller._on_precision_projectile_requested(&"basic_attack", basic_request, null, Vector2.RIGHT, 1, 1)
	controller._execute_skill(&"double_shot", aim_point)
	var basic_projectiles: Array[PlayerProjectile] = []
	var double_projectiles: Array[PlayerProjectile] = []
	for node: Node in get_nodes_in_group("player_projectiles"):
		var projectile := node as PlayerProjectile
		if projectile.request.skill_id == &"basic_attack":
			basic_projectiles.append(projectile)
		elif projectile.request.skill_id == &"double_shot":
			double_projectiles.append(projectile)
	_check(basic_projectiles.size() == 1 and basic_projectiles[0].max_distance == 640.0, "basic arrow captures its extended maximum distance at emission")
	_check(double_projectiles.size() == 2 and double_projectiles[0].max_distance == 640.0 and double_projectiles[1].max_distance == 640.0, "both Double Shot arrows capture buffed range without changing count")
	controller.player.mage_cooldowns[&"extended_aim"] = 0.0
	controller.player.extended_aim_remaining = 3.0
	controller.player.current_sp = 40.0
	controller.cast_intent.active_skill = &"arrow_rain"
	controller._select_skill_from_bar(&"extended_aim")
	_check(controller.player.extended_aim_remaining == 8.0 and controller.player.skill_range(&"double_shot") == 640.0 and controller.cast_intent.active_skill.is_empty(), "SELF skill button refreshes immediately, cancels prior aim and never stacks range")
	controller.player._process(8.01)
	controller._update_hud()
	_check(not controller.player.has_extended_aim() and controller.player.skill_range(&"double_shot") == 520.0 and not controller.skill_label.text.contains("ATIVA"), "controller returns previews and HUD to baseline after expiration")
	controller.queue_free()
	await process_frame

func _player(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("extended-aim-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "extended-aim-test"
	snapshot.base_class_id = &"archer"
	snapshot.skill_ranks = {
		&"double_shot": 1,
		&"piercing_arrow": 1,
		&"arrow_rain": 1,
		&"extended_aim": rank,
	}
	snapshot.active_slots = [&"double_shot", &"piercing_arrow", &"arrow_rain", &"extended_aim", null]
	return snapshot

func _target(position_value: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 19.0)
	actor.position = position_value
	root.add_child(actor)
	actor.set_process(false)
	return actor

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
