extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table()
	_test_ranked_emission_and_sp()
	await _test_preview_hud_dispatch_and_projectile()
	print("E04 Bola de Fogo por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table() -> void:
	var definition := ClassCatalog.skill_definition(&"fireball")
	var expected_powers: Array[float] = [1.80, 2.05, 2.30, 2.55, 2.80]
	var expected_costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.FIREBALL, "Bola de Fogo exposes a valid explicit rank catalog and handler")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_powers[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Bola de Fogo R%d owns its approved power and SP cost" % rank)
		_check(values.cooldown == 2.5 and values.range == 700.0 and values.projectile_speed == 680.0, "Bola de Fogo R%d preserves cooldown, range and projectile speed" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.32 and values.post_cast_time == 0.0, "Bola de Fogo R%d preserves variable cast and zero fixed/post cast" % rank)
		_check(values.magic_weight == 1.0 and values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.effect_ids.is_empty(), "Bola de Fogo R%d preserves pure magic weight and adds no effect" % rank)

func _test_ranked_emission_and_sp() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	var rank_one := _player(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("fireball-r5", rank_five_source)
	rank_five_source.skill_ranks[&"fireball"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	root.add_child(rank_one)
	root.add_child(rank_five)
	var rank_one_requests: Array[DamageRequest] = []
	var rank_five_requests: Array[DamageRequest] = []
	rank_one.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int) -> void: rank_one_requests.append(request))
	rank_five.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int) -> void: rank_five_requests.append(request))
	var rank_one_sp := rank_one.current_sp
	var rank_five_sp := rank_five.current_sp
	_check(rank_one.use_fireball(Vector2.RIGHT) and rank_five.use_fireball(Vector2.RIGHT), "R1 and R5 both emit one directional projectile request")
	_check(rank_one_requests.size() == 1 and is_equal_approx(rank_one_requests[0].magic_damage, rank_one.stat_breakdown.value(&"magic_attack") * 1.80), "R1 captures approved magic power in DamageRequest")
	_check(rank_five_requests.size() == 1 and is_equal_approx(rank_five_requests[0].magic_damage, rank_five.stat_breakdown.value(&"magic_attack") * 2.80), "R5 captures approved magic power in DamageRequest")
	_check(rank_one.current_sp == rank_one_sp - 18.0 and rank_five.current_sp == rank_five_sp - 24.0, "each rank debits its approved SP cost exactly once")
	_check(rank_one.skill_cooldown(&"fireball") == StatCalculator.effective_cooldown(2.5, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"fireball") == StatCalculator.effective_cooldown(2.5, rank_five.stat_breakdown), "both ranks preserve authored cooldown through the shared calculator")
	_check(rank_five.skill_rank(&"fireball") == 5 and rank_five.skill_range(&"fireball") == 700.0 and rank_five.skill_projectile_speed(&"fireball") == 680.0, "runtime values come from the copied R5 snapshot after source mutation")
	_check(rank_five.skill_cast_time(&"fireball") == StatCalculator.effective_cast_time(0.0, 0.32, rank_five.stat_breakdown), "rank definition supplies the preserved variable cast time")
	rank_five.mage_cooldowns[&"fireball"] = 0.0
	rank_five.current_sp = 23.0
	var requests_before := rank_five_requests.size()
	_check(not rank_five.use_fireball(Vector2.RIGHT) and rank_five.current_sp == 23.0 and rank_five_requests.size() == requests_before, "R5 blocks below 24 SP without spending or emitting")
	var invalid_rank := _player(navigation, 6)
	root.add_child(invalid_rank)
	_check(invalid_rank.skill_rank_definition(&"fireball") == null and invalid_rank.skill_cost(&"fireball") == 0.0 and invalid_rank.skill_range(&"fireball") == 0.0 and invalid_rank.skill_projectile_speed(&"fireball") == 0.0 and invalid_rank.skill_cast_time(&"fireball") == 0.0 and not invalid_rank.use_fireball(Vector2.RIGHT), "invalid runtime rank is ineligible instead of falling back to R1 values")
	for node: Node in [rank_one, rank_five, invalid_rank]:
		node.queue_free()

func _test_preview_hud_dispatch_and_projectile() -> void:
	RunController.pending_run_state = RunState.from_build("fireball-preview", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"fireball"]
	_check(controller.skill_label.text.contains("Bola de Fogo R5") and card.tooltip_text.contains("R5") and card.tooltip_text.contains("24 SP"), "HUD renders snapshot rank and definition cost from the same source")
	controller.cast_intent.active_skill = &"fireball"
	var aim_point := controller.player.global_position + Vector2(1000, 0)
	controller._update_aim(aim_point)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.origin.distance_to(controller.battle_indicators.endpoint) == 700.0, "ready preview uses the preserved ranked range")
	var sp_before := controller.player.current_sp
	controller._commit_skill(&"fireball", aim_point)
	_check(controller.player.has_active_cast() and controller.player.current_sp == sp_before and controller.player.skill_cooldown(&"fireball") == 0.0, "ranked preparation starts without early SP or cooldown")
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var projectiles := get_nodes_in_group("player_projectiles")
	var projectile := projectiles.back() as MageProjectile if not projectiles.is_empty() else null
	_check(not controller.player.has_active_cast() and controller.player.current_sp == sp_before - 24.0 and controller.player.skill_cooldown(&"fireball") == StatCalculator.effective_cooldown(2.5, controller.player.stat_breakdown), "FIREBALL handler commits R5 cost and cooldown exactly once")
	_check(projectile != null and projectile.speed == 680.0 and projectile.max_distance == 700.0 and is_equal_approx(projectile.request.magic_damage, controller.player.stat_breakdown.value(&"magic_attack") * 2.80), "spawned projectile captures ranked speed, range and damage")
	controller.queue_free()
	await process_frame

func _player(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("fireball-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "fireball-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"fireball": rank}
	snapshot.active_slots = [&"fireball", null, null, null, null]
	return snapshot

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
