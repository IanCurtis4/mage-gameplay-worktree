extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table()
	_test_ranked_emission_count_and_sp()
	await _test_preview_hud_dispatch_projectiles_and_slow()
	print("E04 Lança de Gelo por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table() -> void:
	var definition := ClassCatalog.skill_definition(&"ice_spear")
	var expected_powers: Array[float] = [1.10, 1.25, 1.40, 1.55, 1.70]
	var expected_costs: Array[float] = [14.0, 15.0, 16.0, 17.0, 18.0]
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.SPEAR, "Lança de Gelo exposes a valid explicit rank catalog and spear handler")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_powers[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Lança de Gelo R%d owns its approved projectile power and SP cost" % rank)
		_check(values.cooldown == 3.0 and values.range == 360.0 and values.projectile_speed == 760.0, "Lança de Gelo R%d preserves cooldown, range and projectile speed" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.22 and values.post_cast_time == 0.0, "Lança de Gelo R%d preserves variable cast and zero fixed/post cast" % rank)
		_check(values.magic_weight == 1.0 and values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.effect_ids == [&"slow"], "Lança de Gelo R%d preserves magic weight and typed slow" % rank)

func _test_ranked_emission_count_and_sp() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	var rank_one := _player(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("ice-spear-r5", rank_five_source)
	rank_five_source.skill_ranks[&"ice_spear"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	root.add_child(rank_one)
	root.add_child(rank_five)
	rank_one.position = Vector2(100, 100)
	rank_five.position = Vector2(100, 300)
	var target_one := _target(Vector2(300, 100))
	var target_five := _target(Vector2(300, 300))
	root.add_child(target_one)
	root.add_child(target_five)
	var rank_one_requests: Array[DamageRequest] = []
	var rank_five_requests: Array[DamageRequest] = []
	var rank_one_count := [0]
	var rank_five_count := [0]
	rank_one.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target_actor: CombatActor, _direction: Vector2, count: int) -> void:
		rank_one_requests.append(request)
		rank_one_count[0] = count
	)
	rank_five.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target_actor: CombatActor, _direction: Vector2, count: int) -> void:
		rank_five_requests.append(request)
		rank_five_count[0] = count
	)
	var rank_one_sp := rank_one.current_sp
	var rank_five_sp := rank_five.current_sp
	_check(rank_one.use_spear(&"ice_spear", target_one) and rank_five.use_spear(&"ice_spear", target_five), "R1 and R5 both emit a valid targeted spear request")
	_check(rank_one_count[0] == 1 and rank_five_count[0] == 1 and rank_five_state.projectile_count(&"ice_spear") == 1, "skill rank does not multiply the base projectile count")
	_check(rank_one_requests.size() == 1 and is_equal_approx(rank_one_requests[0].magic_damage, rank_one.stat_breakdown.value(&"magic_attack") * 1.10), "R1 captures approved projectile power in DamageRequest")
	_check(rank_five_requests.size() == 1 and is_equal_approx(rank_five_requests[0].magic_damage, rank_five.stat_breakdown.value(&"magic_attack") * 1.70), "R5 captures approved projectile power in DamageRequest")
	_check(rank_one.current_sp == rank_one_sp - 14.0 and rank_five.current_sp == rank_five_sp - 18.0, "each rank debits its approved SP cost exactly once")
	_check(rank_one.skill_cooldown(&"ice_spear") == StatCalculator.effective_cooldown(3.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"ice_spear") == StatCalculator.effective_cooldown(3.0, rank_five.stat_breakdown), "both ranks preserve authored cooldown through the shared calculator")
	_check(rank_five.skill_rank(&"ice_spear") == 5 and rank_five.skill_range(&"ice_spear") == 360.0 and rank_five.skill_projectile_speed(&"ice_spear") == 760.0, "runtime values come from the copied R5 snapshot after source mutation")
	_check(rank_five.skill_cast_time(&"ice_spear") == StatCalculator.effective_cast_time(0.0, 0.22, rank_five.stat_breakdown), "rank definition supplies the preserved variable cast time")
	rank_five_state.augment_stacks[&"extra_ice_spear"] = 2
	_check(rank_five_state.projectile_count(&"ice_spear") == 3 and rank_five_state.projectile_count(&"fire_spear") == 1, "only ice-spear augment stacks add projectiles to the migrated skill")
	rank_five.mage_cooldowns[&"ice_spear"] = 0.0
	rank_five.current_sp = 17.0
	var requests_before := rank_five_requests.size()
	_check(not rank_five.use_spear(&"ice_spear", target_five) and rank_five.current_sp == 17.0 and rank_five_requests.size() == requests_before, "R5 blocks below 18 SP without spending or emitting")
	var invalid_rank := _player(navigation, 6)
	root.add_child(invalid_rank)
	invalid_rank.position = Vector2(100, 500)
	var invalid_target := _target(Vector2(300, 500))
	root.add_child(invalid_target)
	_check(invalid_rank.skill_rank_definition(&"ice_spear") == null and invalid_rank.skill_cost(&"ice_spear") == 0.0 and invalid_rank.skill_range(&"ice_spear") == 0.0 and invalid_rank.skill_projectile_speed(&"ice_spear") == 0.0 and invalid_rank.skill_cast_time(&"ice_spear") == 0.0 and not invalid_rank.use_spear(&"ice_spear", invalid_target), "invalid runtime rank is ineligible instead of falling back to R1 values")
	for node: Node in [rank_one, rank_five, invalid_rank, target_one, target_five, invalid_target]:
		node.queue_free()

func _test_preview_hud_dispatch_projectiles_and_slow() -> void:
	RunController.pending_run_state = RunState.from_build("ice-spear-preview", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	controller.run_state.augment_stacks[&"extra_ice_spear"] = 1
	var target: CombatActor = controller.enemies[0]
	target.global_position = controller.player.global_position + Vector2(200, 0)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"ice_spear"]
	_check(controller.skill_label.text.contains("Lança de Gelo R5") and card.text.contains("R5") and card.text.contains("18 SP"), "HUD renders snapshot rank and definition cost from the same source")
	controller.cast_intent.active_skill = &"ice_spear"
	controller._update_aim(target.global_position)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == target.global_position, "ready preview accepts the target inside ranked range")
	var sp_before := controller.player.current_sp
	controller._commit_skill(&"ice_spear", target.global_position)
	_check(controller.player.has_active_cast() and controller.player.current_sp == sp_before and controller.player.skill_cooldown(&"ice_spear") == 0.0, "ranked preparation starts without early SP or cooldown")
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(not controller.player.has_active_cast() and controller.player.current_sp == sp_before - 18.0 and controller.player.skill_cooldown(&"ice_spear") == StatCalculator.effective_cooldown(3.0, controller.player.stat_breakdown), "SPEAR handler commits R5 cost and cooldown exactly once")
	_check(projectiles.size() == 2 and controller.run_state.projectile_count(&"ice_spear") == 2, "one augment creates exactly two R5 projectiles without rank-based copies")
	var valid_projectiles := true
	for node: Node in projectiles:
		var projectile := node as MageProjectile
		valid_projectiles = valid_projectiles and projectile != null and projectile.homing and projectile.target == target and projectile.speed == 760.0 and projectile.max_distance == 360.0 and is_equal_approx(projectile.request.magic_damage, controller.player.stat_breakdown.value(&"magic_attack") * 1.70)
	_check(valid_projectiles, "spawned homing projectiles capture ranked target, speed, range and damage")
	var first_projectile := projectiles[0] as MageProjectile
	first_projectile.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	first_projectile.request.can_crit = false
	controller._on_mage_projectile_hit(first_projectile.request, target)
	_check(is_equal_approx(target.movement_speed_multiplier(), 0.70) and target.slow_remaining == 2.0, "positive ranked ice-spear damage preserves the fixed 30 percent slow for two seconds")
	controller.queue_free()
	await process_frame

func _player(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("ice-spear-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "ice-spear-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"ice_spear": rank}
	snapshot.active_slots = [&"ice_spear", null, null, null, null]
	return snapshot

func _target(position: Vector2) -> CombatActor:
	var target := CombatActor.new()
	target.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 19.0)
	target.position = position
	return target

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
