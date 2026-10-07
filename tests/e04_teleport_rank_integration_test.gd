extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table()
	_test_ranked_teleport_and_sp()
	await _test_preview_hud_and_dispatch()
	print("E04 Teleporte por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table() -> void:
	var definition := ClassCatalog.skill_definition(&"teleport")
	var expected_cooldowns: Array[float] = [6.0, 5.7, 5.4, 5.1, 4.8]
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.TELEPORT, "Teleporte exposes a valid explicit rank catalog and handler")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.sp_cost == 22.0 and values.cooldown == expected_cooldowns[rank - 1] and values.range == 320.0, "Teleporte R%d owns its approved SP, cooldown and range" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0 and values.power == 0.0, "Teleporte R%d remains instant and preserves zero power" % rank)
		_check(values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.magic_weight == 0.0 and values.projectile_speed == 0.0 and values.effect_ids.is_empty(), "Teleporte R%d adds no damage weight, projectile or effect" % rank)

func _test_ranked_teleport_and_sp() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 800), [Rect2(200, 40, 80, 500)], 20.0)
	var rank_one := _player(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("teleport-r5", rank_five_source)
	rank_five_source.skill_ranks[&"teleport"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	root.add_child(rank_one)
	root.add_child(rank_five)
	rank_one.position = Vector2(100, 100)
	rank_five.position = Vector2(100, 400)
	_check(rank_one.skill_rank(&"teleport") == 1 and rank_five.skill_rank(&"teleport") == 5, "runtime rank comes from the copied snapshot after source mutation")
	_check(rank_one.skill_cost(&"teleport") == 22.0 and rank_five.skill_cost(&"teleport") == 22.0 and rank_five.skill_range(&"teleport") == 320.0 and rank_five.skill_cast_time(&"teleport") == 0.0, "rank definitions expose preserved cost, range and instant cast")
	_check(rank_one.teleport_destination(Vector2(900, 100)) == Vector2(420, 100) and rank_five.teleport_destination(Vector2(900, 400)) == Vector2(420, 400), "R1 and R5 clamp distant destinations to the preserved 320-unit range")
	_check(rank_one.can_teleport(Vector2(420, 100)) and rank_five.can_teleport(Vector2(420, 400)), "both ranks accept a free endpoint beyond an intermediate obstacle")
	var target_one := _target(Vector2(700, 100))
	var target_five := _target(Vector2(700, 400))
	rank_one.target = target_one
	rank_five.target = target_five
	rank_one._path = PackedVector2Array([Vector2(150, 100)])
	rank_five._path = PackedVector2Array([Vector2(150, 400)])
	rank_one.velocity = Vector2(50, 0)
	rank_five.velocity = Vector2(50, 0)
	var rank_one_sp := rank_one.current_sp
	var rank_five_sp := rank_five.current_sp
	_check(rank_one.use_teleport(Vector2(900, 100)) and rank_five.use_teleport(Vector2(900, 400)), "R1 and R5 both teleport across the obstacle to a free ranked destination")
	_check(rank_one.current_sp == rank_one_sp - 22.0 and rank_five.current_sp == rank_five_sp - 22.0, "each rank debits the preserved SP cost exactly once")
	_check(rank_one.skill_cooldown(&"teleport") == StatCalculator.effective_cooldown(6.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"teleport") == StatCalculator.effective_cooldown(4.8, rank_five.stat_breakdown), "each rank applies its authored cooldown through the shared calculator")
	_check(rank_one.position == Vector2(420, 100) and rank_five.position == Vector2(420, 400) and rank_one.target == null and rank_five.target == null and rank_one._path.is_empty() and rank_five._path.is_empty() and rank_one.velocity == Vector2.ZERO and rank_five.velocity == Vector2.ZERO, "successful teleport preserves destination and clears pursuit, path and momentum")
	rank_five.mage_cooldowns[&"teleport"] = 0.0
	var blocked_sp := rank_five.current_sp
	_check(not rank_five.use_teleport(Vector2(250, 400)) and rank_five.current_sp == blocked_sp and rank_five.position == Vector2(420, 400), "solid destination is rejected without cost, cooldown or movement")
	var invalid_rank := _player(navigation, 6)
	root.add_child(invalid_rank)
	invalid_rank.position = Vector2(600, 650)
	_check(invalid_rank.skill_rank_definition(&"teleport") == null and invalid_rank.skill_cost(&"teleport") == 0.0 and invalid_rank.skill_range(&"teleport") == 0.0 and invalid_rank.teleport_destination(Vector2(800, 650)) == invalid_rank.position and not invalid_rank.can_teleport(Vector2(800, 650)) and not invalid_rank.use_teleport(Vector2(800, 650)), "invalid runtime rank is ineligible instead of falling back to R1 values")
	for node: Node in [rank_one, rank_five, invalid_rank, target_one, target_five]:
		node.queue_free()

func _test_preview_hud_and_dispatch() -> void:
	RunController.pending_run_state = RunState.from_build("teleport-preview", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"teleport"]
	_check(controller.skill_label.text.contains("Teleporte R5") and card.tooltip_text.contains("R5") and card.tooltip_text.contains("22 SP"), "HUD renders snapshot rank and definition cost from the same source")
	controller.cast_intent.active_skill = &"teleport"
	var aim_point := controller.player.global_position + Vector2(1000, 0)
	controller._update_aim(aim_point)
	var expected_endpoint := controller.player.teleport_destination(aim_point)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == expected_endpoint and controller.battle_indicators.active_range == 320.0, "ready preview uses the same ranked destination and range as execution")
	var sp_before := controller.player.current_sp
	controller._execute_skill(&"teleport", aim_point)
	_check(controller.player.global_position == expected_endpoint and controller.player.current_sp == sp_before - 22.0 and controller.player.skill_cooldown(&"teleport") == StatCalculator.effective_cooldown(4.8, controller.player.stat_breakdown), "TELEPORT handler dispatches R5 with its authored destination, cost and cooldown")
	controller.queue_free()
	await process_frame

func _player(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("teleport-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "teleport-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"teleport": rank}
	snapshot.active_slots = [&"teleport", null, null, null, null]
	return snapshot

func _target(position: Vector2) -> CombatActor:
	var target := CombatActor.new()
	target.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 19.0)
	target.position = position
	root.add_child(target)
	return target

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
