extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table()
	_test_ranked_dash_and_sp()
	await _test_preview_hud_and_dispatch()
	print("E04 Investida por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table() -> void:
	var definition := ClassCatalog.skill_definition(&"dash")
	var expected_cooldowns: Array[float] = [6.0, 5.7, 5.4, 5.1, 4.8]
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.DASH, "Investida exposes a valid explicit rank catalog and handler")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.sp_cost == 20.0 and values.cooldown == expected_cooldowns[rank - 1] and values.range == 270.0, "Investida R%d owns its approved SP, cooldown and range" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0 and values.power == 0.0, "Investida R%d preserves zero cast timings and power" % rank)
		_check(values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.magic_weight == 0.0 and values.projectile_speed == 0.0 and values.effect_ids.is_empty(), "Investida R%d adds no damage weight, projectile or effect" % rank)

func _test_ranked_dash_and_sp() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 800), [], 20.0)
	var rank_one := _player(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("dash-r5", rank_five_source)
	rank_five_source.skill_ranks[&"dash"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	root.add_child(rank_one)
	root.add_child(rank_five)
	rank_one.position = Vector2(100, 100)
	rank_five.position = Vector2(100, 300)
	var durations: Array[float] = []
	rank_five.presentation_action.connect(func(action: StringName, _direction: Vector2, duration: float) -> void:
		if action == &"dash":
			durations.append(duration)
	)
	_check(rank_one.skill_rank(&"dash") == 1 and rank_five.skill_rank(&"dash") == 5, "runtime rank comes from the copied snapshot after source mutation")
	_check(rank_one.skill_cost(&"dash") == 20.0 and rank_five.skill_cost(&"dash") == 20.0 and rank_five.skill_range(&"dash") == 270.0, "rank definitions expose preserved cost and range")
	_check(rank_one.dash_destination(Vector2.RIGHT) == Vector2(370, 100) and rank_five.dash_destination(Vector2.RIGHT) == Vector2(370, 300), "R1 and R5 preserve the 270-unit navigation destination")
	var rank_one_sp := rank_one.current_sp
	var rank_five_sp := rank_five.current_sp
	_check(rank_one.use_dash(Vector2.RIGHT) and rank_five.use_dash(Vector2.RIGHT), "R1 and R5 both dispatch through the existing dash movement")
	_check(rank_one.current_sp == rank_one_sp - 20.0 and rank_five.current_sp == rank_five_sp - 20.0, "each rank debits the preserved SP cost exactly once")
	_check(rank_one.dash_cooldown == StatCalculator.effective_cooldown(6.0, rank_one.stat_breakdown) and rank_five.dash_cooldown == StatCalculator.effective_cooldown(4.8, rank_five.stat_breakdown), "each rank applies its authored cooldown through the shared calculator")
	_check(rank_five._dash_endpoint == Vector2(370, 300) and is_equal_approx(rank_five._dash_speed, 270.0 / PlayerActor.DASH_DURATION) and durations == [PlayerActor.DASH_DURATION], "movement preserves endpoint and fixed duration")
	rank_five.dash_cooldown = 0.0
	rank_five.current_sp = 19.0
	var endpoint_before := rank_five._dash_endpoint
	_check(not rank_five.use_dash(Vector2.RIGHT) and rank_five.current_sp == 19.0 and rank_five._dash_endpoint == endpoint_before, "R5 blocks below 20 SP without spending or replacing movement")
	var invalid_rank := _player(navigation, 6)
	root.add_child(invalid_rank)
	invalid_rank.position = Vector2(100, 500)
	_check(invalid_rank.skill_rank_definition(&"dash") == null and invalid_rank.skill_cost(&"dash") == 0.0 and invalid_rank.skill_range(&"dash") == 0.0 and invalid_rank.dash_destination(Vector2.RIGHT) == invalid_rank.position and not invalid_rank.use_dash(Vector2.RIGHT), "invalid runtime rank is ineligible instead of falling back to R1 values")
	for node: Node in [rank_one, rank_five, invalid_rank]:
		node.queue_free()

func _test_preview_hud_and_dispatch() -> void:
	RunController.pending_run_state = RunState.from_build("dash-preview", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"dash"]
	_check(controller.skill_label.text.contains("Investida R5") and card.text.contains("R5") and card.text.contains("20 SP"), "HUD renders snapshot rank and definition cost from the same source")
	controller.player.current_sp = 20.0
	controller.cast_intent.active_skill = &"dash"
	var aim_point := controller.player.global_position + Vector2(1000, 0)
	controller._update_aim(aim_point)
	var expected_endpoint := controller.player.dash_destination(controller.player.aim_direction(aim_point))
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == expected_endpoint, "ready preview uses the same ranked navigation destination as execution")
	var sp_before := controller.player.current_sp
	controller._execute_skill(&"dash", aim_point)
	_check(controller.player._dash_active and controller.player.current_sp == sp_before - 20.0 and controller.player.dash_cooldown == StatCalculator.effective_cooldown(4.8, controller.player.stat_breakdown), "DASH handler dispatches R5 with its authored cost and cooldown")
	controller.queue_free()
	await process_frame

func _player(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("dash-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "dash-test"
	snapshot.base_class_id = &"swordsman"
	snapshot.skill_ranks = {&"dash": rank}
	snapshot.active_slots = [&"dash", null, null, null, null]
	return snapshot

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
