extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table()
	_test_ranked_emission_and_sp()
	await _test_preview_hud_dispatch_and_effect()
	print("E04 Parede de Fogo por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table() -> void:
	var definition := ClassCatalog.skill_definition(&"fire_wall")
	var expected_powers: Array[float] = [0.30, 0.34, 0.38, 0.42, 0.46]
	var expected_costs: Array[float] = [24.0, 27.0, 29.0, 30.0, 32.0]
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.FIRE_WALL, "Parede de Fogo exposes a valid explicit rank catalog and handler")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_powers[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Parede de Fogo R%d owns its approved tick power and SP cost" % rank)
		_check(values.cooldown == 7.0 and values.range == 180.0 and values.projectile_speed == 0.0, "Parede de Fogo R%d preserves cooldown, placement range and no projectile" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.48 and values.post_cast_time == 0.0, "Parede de Fogo R%d preserves variable cast and zero fixed/post cast" % rank)
		_check(values.magic_weight == 1.0 and values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.effect_ids == [&"burn"], "Parede de Fogo R%d preserves magic weight and typed burn" % rank)

func _test_ranked_emission_and_sp() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	var rank_one := _player(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("fire-wall-r5", rank_five_source)
	rank_five_source.skill_ranks[&"fire_wall"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	root.add_child(rank_one)
	root.add_child(rank_five)
	var rank_one_requests: Array[DamageRequest] = []
	var rank_five_requests: Array[DamageRequest] = []
	rank_one.fire_wall_requested.connect(func(_direction: Vector2, request: DamageRequest) -> void: rank_one_requests.append(request))
	rank_five.fire_wall_requested.connect(func(_direction: Vector2, request: DamageRequest) -> void: rank_five_requests.append(request))
	var rank_one_sp := rank_one.current_sp
	var rank_five_sp := rank_five.current_sp
	_check(rank_one.use_fire_wall(Vector2.RIGHT) and rank_five.use_fire_wall(Vector2.RIGHT), "R1 and R5 both emit one persistent wall request")
	_check(rank_one_requests.size() == 1 and is_equal_approx(rank_one_requests[0].magic_damage, rank_one.stat_breakdown.value(&"magic_attack") * 0.30), "R1 captures approved tick power in DamageRequest")
	_check(rank_five_requests.size() == 1 and is_equal_approx(rank_five_requests[0].magic_damage, rank_five.stat_breakdown.value(&"magic_attack") * 0.46), "R5 captures approved tick power in DamageRequest")
	_check(rank_one.current_sp == rank_one_sp - 24.0 and rank_five.current_sp == rank_five_sp - 32.0, "each rank debits its approved SP cost exactly once")
	_check(rank_one.skill_cooldown(&"fire_wall") == StatCalculator.effective_cooldown(7.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"fire_wall") == StatCalculator.effective_cooldown(7.0, rank_five.stat_breakdown), "both ranks preserve authored cooldown through the shared calculator")
	_check(rank_five.skill_rank(&"fire_wall") == 5 and rank_five.skill_range(&"fire_wall") == 180.0, "runtime values come from the copied R5 snapshot after source mutation")
	_check(rank_five.skill_cast_time(&"fire_wall") == StatCalculator.effective_cast_time(0.0, 0.48, rank_five.stat_breakdown), "rank definition supplies the preserved variable cast time")
	rank_five.mage_cooldowns[&"fire_wall"] = 0.0
	rank_five.current_sp = 31.0
	var requests_before := rank_five_requests.size()
	_check(not rank_five.use_fire_wall(Vector2.RIGHT) and rank_five.current_sp == 31.0 and rank_five_requests.size() == requests_before, "R5 blocks below 32 SP without spending or emitting")
	var invalid_rank := _player(navigation, 6)
	root.add_child(invalid_rank)
	_check(invalid_rank.skill_rank_definition(&"fire_wall") == null and invalid_rank.skill_cost(&"fire_wall") == 0.0 and invalid_rank.skill_range(&"fire_wall") == 0.0 and invalid_rank.skill_cast_time(&"fire_wall") == 0.0 and not invalid_rank.use_fire_wall(Vector2.RIGHT), "invalid runtime rank is ineligible instead of falling back to R1 values")
	for node: Node in [rank_one, rank_five, invalid_rank]:
		node.queue_free()

func _test_preview_hud_dispatch_and_effect() -> void:
	RunController.pending_run_state = RunState.from_build("fire-wall-preview", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"fire_wall"]
	_check(controller.skill_label.text.contains("Parede de Fogo R5") and card.text.contains("R5") and card.text.contains("32 SP"), "HUD renders snapshot rank and definition cost from the same source")
	controller.cast_intent.active_skill = &"fire_wall"
	var aim_point := controller.player.global_position + Vector2(1000, 0)
	controller._update_aim(aim_point)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.origin.distance_to(controller.battle_indicators.endpoint) == 180.0, "ready preview uses the preserved ranked placement range")
	var expected_center := controller.player.global_position + Vector2.RIGHT * 180.0
	var target: CombatActor = controller.enemies[0]
	target.global_position = expected_center
	var sp_before := controller.player.current_sp
	controller._commit_skill(&"fire_wall", aim_point)
	_check(controller.player.has_active_cast() and controller.player.current_sp == sp_before and controller.player.skill_cooldown(&"fire_wall") == 0.0, "ranked preparation starts without early SP or cooldown")
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var effects := get_nodes_in_group("player_effects")
	var wall := effects.back() as FireWall if not effects.is_empty() else null
	_check(not controller.player.has_active_cast() and controller.player.current_sp == sp_before - 32.0 and controller.player.skill_cooldown(&"fire_wall") == StatCalculator.effective_cooldown(7.0, controller.player.stat_breakdown), "FIRE_WALL handler commits R5 cost and cooldown exactly once")
	_check(wall != null and wall.global_position == expected_center and wall.pillar_offsets.size() == FireWall.PILLAR_COUNT and wall.remaining == FireWall.DURATION, "spawned wall captures ranked placement while preserving geometry and duration")
	if wall != null:
		wall._process(0.0)
	_check(target.is_burning() and target.burn_remaining == FireWall.BURN_DURATION and is_equal_approx(target.burn_request.magic_damage, controller.player.stat_breakdown.value(&"magic_attack") * 0.46), "persistent wall transfers captured R5 damage into the unchanged burn stream")
	controller.queue_free()
	await process_frame

func _player(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("fire-wall-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "fire-wall-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"fire_wall": rank}
	snapshot.active_slots = [&"fire_wall", null, null, null, null]
	return snapshot

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
