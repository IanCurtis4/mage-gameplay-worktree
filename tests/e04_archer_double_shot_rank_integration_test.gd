extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table()
	_check_ranked_emission_and_sp()
	await _check_preview_hud_dispatch_and_projectiles()
	print("E04 Disparo Duplo por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table() -> void:
	var definition := ClassCatalog.skill_definition(&"double_shot")
	var expected_powers: Array[float] = [0.70, 0.80, 0.90, 1.00, 1.10]
	var expected_costs: Array[float] = [14.0, 16.0, 17.0, 18.0, 19.0]
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.DOUBLE_SHOT and definition.targeting == SkillDefinition.Targeting.DIRECTION, "Disparo Duplo exposes a valid directional rank catalog and handler")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_powers[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Disparo Duplo R%d owns its approved per-arrow power and SP cost" % rank)
		_check(values.cooldown == 4.0 and values.range == 520.0 and values.projectile_speed == 880.0, "Disparo Duplo R%d preserves cooldown, range and projectile speed" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0, "Disparo Duplo R%d remains instant" % rank)
		_check(values.precision_weight == 1.0 and values.physical_weight == 0.0 and values.magic_weight == 0.0 and values.effect_ids.is_empty(), "Disparo Duplo R%d preserves pure precision scaling without added effects" % rank)

func _check_ranked_emission_and_sp() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 700), [], 20.0)
	var rank_one := _player(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("double-shot-r5", rank_five_source)
	rank_five_source.skill_ranks[&"double_shot"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	root.add_child(rank_one)
	root.add_child(rank_five)
	var rank_one_requests: Array[DamageRequest] = []
	var rank_five_requests: Array[DamageRequest] = []
	var rank_one_count := [0]
	var rank_five_count := [0]
	rank_one.precision_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, count: int, hit_limit: int) -> void:
		rank_one_requests.append(request)
		rank_one_count[0] = count
		_check(hit_limit == 1, "Disparo Duplo keeps the one-hit policy on each arrow")
	)
	rank_five.precision_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, count: int, hit_limit: int) -> void:
		rank_five_requests.append(request)
		rank_five_count[0] = count
		_check(hit_limit == 1, "Disparo Duplo R5 keeps the one-hit policy on each arrow")
	)
	var rank_one_sp := rank_one.current_sp
	var rank_five_sp := rank_five.current_sp
	_check(rank_one.use_double_shot(Vector2.RIGHT) and rank_five.use_double_shot(Vector2.RIGHT), "R1 and R5 both emit a valid directional double shot")
	_check(rank_one_count[0] == 2 and rank_five_count[0] == 2, "every rank emits exactly two projectiles")
	_check(rank_one_requests.size() == 1 and is_equal_approx(rank_one_requests[0].physical_damage, rank_one.stat_breakdown.value(&"precision_attack") * 0.70), "R1 captures approved per-arrow precision power")
	_check(rank_five_requests.size() == 1 and is_equal_approx(rank_five_requests[0].physical_damage, rank_five.stat_breakdown.value(&"precision_attack") * 1.10), "R5 captures approved per-arrow precision power")
	_check(rank_one.current_sp == rank_one_sp - 14.0 and rank_five.current_sp == rank_five_sp - 19.0, "each rank debits its approved SP cost once rather than per projectile")
	_check(rank_one.skill_cooldown(&"double_shot") == StatCalculator.effective_cooldown(4.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"double_shot") == StatCalculator.effective_cooldown(4.0, rank_five.stat_breakdown), "both ranks apply the fixed cooldown through the shared calculator")
	_check(rank_five.skill_rank(&"double_shot") == 5 and rank_five.skill_range(&"double_shot") == 520.0 and rank_five.skill_projectile_speed(&"double_shot") == 880.0 and rank_five.skill_cast_time(&"double_shot") == 0.0, "runtime values come from the copied R5 snapshot after source mutation")
	rank_five.mage_cooldowns[&"double_shot"] = 0.0
	rank_five.current_sp = 18.0
	var requests_before := rank_five_requests.size()
	_check(not rank_five.use_double_shot(Vector2.RIGHT) and rank_five.current_sp == 18.0 and rank_five_requests.size() == requests_before, "R5 blocks below 19 SP without spending or emitting")
	var invalid_rank := _player(navigation, 6)
	root.add_child(invalid_rank)
	_check(invalid_rank.skill_rank_definition(&"double_shot") == null and invalid_rank.skill_cost(&"double_shot") == 0.0 and invalid_rank.skill_range(&"double_shot") == 0.0 and invalid_rank.skill_projectile_speed(&"double_shot") == 0.0 and not invalid_rank.use_double_shot(Vector2.RIGHT), "invalid runtime rank is ineligible instead of falling back to R1 values")
	for node: Node in [rank_one, rank_five, invalid_rank]:
		node.queue_free()

func _check_preview_hud_dispatch_and_projectiles() -> void:
	RunController.pending_run_state = RunState.from_build("double-shot-preview", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	var target: CombatActor = controller.enemies[0]
	target.global_position = controller.player.global_position + Vector2(260, 0)
	for index: int in range(1, controller.enemies.size()):
		controller.enemies[index].global_position = controller.player.global_position + Vector2(700, 100 * index)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"double_shot"]
	_check(controller.skill_label.text.contains("Disparo Duplo R5") and card.tooltip_text.contains("R5") and card.tooltip_text.contains("19 SP"), "HUD renders snapshot rank and definition cost from the same source")
	controller.cast_intent.active_skill = &"double_shot"
	var aim_point := controller.player.global_position + Vector2(1000, 0)
	controller._update_aim(aim_point)
	var expected_endpoint := controller.player.global_position + Vector2.RIGHT * 520.0
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == expected_endpoint and controller.battle_indicators.active_range == 520.0, "ready preview uses the ranked directional range")
	var sp_before := controller.player.current_sp
	controller._execute_skill(&"double_shot", aim_point)
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(projectiles.size() == 2 and controller.player.current_sp == sp_before - 19.0 and controller.player.skill_cooldown(&"double_shot") == StatCalculator.effective_cooldown(4.0, controller.player.stat_breakdown), "DOUBLE_SHOT handler spends once and creates exactly two R5 projectiles")
	var valid_projectiles := true
	var y_positions: Array[float] = []
	for node: Node in projectiles:
		var projectile := node as PlayerProjectile
		valid_projectiles = valid_projectiles and projectile != null and projectile.max_hits == 1 and projectile.speed == 880.0 and projectile.max_distance == 520.0 and is_equal_approx(projectile.request.physical_damage, controller.player.stat_breakdown.value(&"precision_attack") * 1.10)
		y_positions.append(projectile.global_position.y)
	_check(valid_projectiles and is_equal_approx(absf(y_positions[0] - y_positions[1]), 14.0), "both arrows capture ranked damage and fixed parallel offsets without rank-based copies")
	var request := (projectiles[0] as PlayerProjectile).request
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	var expected_hit := CombatMath.resolve(request, target.stat_breakdown.value(&"physical_defense"), target.stat_breakdown.value(&"magic_defense"), target.stat_breakdown.value(&"flee_rating"), target.stat_breakdown.value(&"crit_resistance"), 0.0, 0.99)
	for node: Node in projectiles:
		var projectile := node as PlayerProjectile
		projectile.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		projectile.request.can_crit = false
	var hp_before := target.health.current_hp
	for node: Node in projectiles:
		(node as PlayerProjectile)._process(1.0)
	_check(is_equal_approx(target.health.current_hp, hp_before - float(expected_hit["damage"]) * 2.0), "two landed arrows apply their independent captured damage exactly once each")
	controller.queue_free()
	await process_frame

func _player(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("double-shot-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "double-shot-test"
	snapshot.base_class_id = &"archer"
	snapshot.skill_ranks = {&"double_shot": rank}
	snapshot.active_slots = [&"double_shot", null, null, null, null]
	return snapshot

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
