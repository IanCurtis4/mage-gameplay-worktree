extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table()
	_test_ranked_emission_and_sp()
	await _test_preview_and_hud()
	print("E04 Corte por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table() -> void:
	var definition := ClassCatalog.skill_definition(&"slash")
	var expected_powers: Array[float] = [1.45, 1.65, 1.85, 2.05, 2.25]
	var expected_costs: Array[float] = [15.0, 17.0, 18.0, 19.0, 20.0]
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.SLASH, "Corte exposes a valid explicit rank catalog and handler")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_powers[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Corte R%d owns its approved power and SP cost" % rank)
		_check(values.cooldown == 4.0 and values.range == 155.0 and values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0, "Corte R%d preserves cooldown, range and zero cast timings" % rank)
		_check(values.physical_weight == 1.0 and values.precision_weight == 0.0 and values.magic_weight == 0.0 and values.projectile_speed == 0.0 and values.effect_ids.is_empty(), "Corte R%d preserves melee weight and adds no projectile or effect" % rank)

func _test_ranked_emission_and_sp() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 800), [], 20.0)
	var rank_one := _player(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("slash-r5", rank_five_source)
	rank_five_source.skill_ranks[&"slash"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	root.add_child(rank_one)
	root.add_child(rank_five)
	rank_one.position = Vector2(100, 100)
	rank_five.position = Vector2(100, 300)
	var target_one := _target(Vector2(200, 100))
	var target_five := _target(Vector2(200, 300))
	root.add_child(target_one)
	root.add_child(target_five)
	var rank_one_request: Array[DamageRequest] = []
	var rank_five_request: Array[DamageRequest] = []
	rank_one.attack_requested.connect(func(request: DamageRequest, _target_actor: CombatActor) -> void: rank_one_request.append(request))
	rank_five.attack_requested.connect(func(request: DamageRequest, _target_actor: CombatActor) -> void: rank_five_request.append(request))
	var rank_one_sp := rank_one.current_sp
	var rank_five_sp := rank_five.current_sp
	_check(rank_one.use_slash(Vector2.RIGHT, [target_one]) and rank_five.use_slash(Vector2.RIGHT, [target_five]), "R1 and R5 both dispatch through the existing cone emission")
	_check(rank_one_request.size() == 1 and is_equal_approx(rank_one_request[0].physical_damage, rank_one.stat_breakdown.value(&"melee_attack") * 1.45), "R1 captures approved power in DamageRequest")
	_check(rank_five_request.size() == 1 and is_equal_approx(rank_five_request[0].physical_damage, rank_five.stat_breakdown.value(&"melee_attack") * 2.25), "R5 captures approved power in DamageRequest")
	_check(rank_one.current_sp == rank_one_sp - 15.0 and rank_five.current_sp == rank_five_sp - 20.0, "each rank debits its approved SP cost exactly once")
	_check(rank_one.skill_rank(&"slash") == 1 and rank_five.skill_rank(&"slash") == 5 and rank_five.skill_cost(&"slash") == 20.0, "runtime rank comes from the copied snapshot after source mutation")
	_check(rank_five.skill_range(&"slash") == 155.0 and rank_five.skill_cast_time(&"slash") == 0.0 and rank_five.slash_cooldown == StatCalculator.effective_cooldown(4.0, rank_five.stat_breakdown), "rank definition supplies preserved range, cast and cooldown")
	rank_five.slash_cooldown = 0.0
	rank_five.current_sp = 19.0
	var requests_before := rank_five_request.size()
	_check(not rank_five.use_slash(Vector2.RIGHT, [target_five]) and rank_five.current_sp == 19.0 and rank_five_request.size() == requests_before, "R5 blocks below 20 SP without spending or emitting")
	var invalid_rank := _player(navigation, 6)
	root.add_child(invalid_rank)
	_check(invalid_rank.skill_rank_definition(&"slash") == null and invalid_rank.skill_cost(&"slash") == 0.0 and invalid_rank.skill_range(&"slash") == 0.0 and not invalid_rank.use_slash(Vector2.RIGHT, [target_five]), "invalid runtime rank is ineligible instead of falling back to R1 values")
	for node: Node in [rank_one, rank_five, invalid_rank, target_one, target_five]:
		node.queue_free()

func _test_preview_and_hud() -> void:
	var state := RunState.from_build("slash-preview", _snapshot(5))
	RunController.pending_run_state = state
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"slash"]
	_check(controller.skill_label.text.contains("Corte em cone R5") and card.text.contains("R5") and card.text.contains("20 SP"), "HUD renders snapshot rank and definition cost from the same source")
	controller.player.current_sp = 19.0
	controller.cast_intent.active_skill = &"slash"
	var aim_point := controller.player.global_position + Vector2(300, 0)
	controller._update_aim(aim_point)
	_check(controller.battle_controls.aim_label.text.contains("SEM SP"), "aim preview uses the R5 cost for availability")
	controller.player.current_sp = 20.0
	controller._update_aim(aim_point)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.origin.distance_to(controller.battle_indicators.endpoint) == 155.0, "ready preview uses the approved ranked range")
	controller.queue_free()
	await process_frame

func _player(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("slash-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "slash-test"
	snapshot.base_class_id = &"swordsman"
	snapshot.skill_ranks = {&"slash": rank, &"dash": 1, &"swordsman_resistance": 1}
	snapshot.active_slots = [&"slash", &"dash", null, null, null]
	snapshot.passive_slots = [&"swordsman_resistance", null]
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
