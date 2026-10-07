extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table_and_gate()
	_check_ranked_emission_and_sp()
	_check_announced_area_runtime()
	await _check_preview_hud_dispatch_and_effect()
	print("E04 Chuva de Flechas por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table_and_gate() -> void:
	var definition := ClassCatalog.skill_definition(&"arrow_rain")
	var expected_powers: Array[float] = [1.80, 2.10, 2.40, 2.70, 3.00]
	var expected_costs: Array[float] = [22.0, 24.0, 26.0, 28.0, 30.0]
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.ARROW_RAIN and definition.targeting == SkillDefinition.Targeting.POINT, "Chuva de Flechas exposes a valid point rank catalog and closed handler")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_powers[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Chuva de Flechas R%d owns its approved total power and SP cost" % rank)
		_check(values.cooldown == 7.0 and values.range == 480.0 and values.projectile_speed == 0.0, "Chuva de Flechas R%d preserves cooldown, placement range and no projectile" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0, "Chuva de Flechas R%d remains instant before its telegraph" % rank)
		_check(values.precision_weight == 1.0 and values.physical_weight == 0.0 and values.magic_weight == 0.0 and values.effect_ids.is_empty(), "Chuva de Flechas R%d preserves pure precision scaling without control" % rank)
	var profile := ProfileCatalog.pilot()
	_check(profile.skill_metadata(&"arrow_rain").get("max_purchased_rank") == 5 and profile.base_class_is_available(&"archer"), "profile keeps Arrow Rain progression while the delivered passive opens the Archer gate")

func _check_ranked_emission_and_sp() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(-100, -100, 1400, 900), [], 20.0)
	var rank_one := _player(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("arrow-rain-r5", rank_five_source)
	rank_five_source.skill_ranks[&"arrow_rain"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	rank_five.global_position = Vector2(50, 40)
	root.add_child(rank_one)
	root.add_child(rank_five)
	var rank_one_centers: Array[Vector2] = []
	var rank_five_centers: Array[Vector2] = []
	var rank_one_requests: Array[DamageRequest] = []
	var rank_five_requests: Array[DamageRequest] = []
	rank_one.arrow_rain_requested.connect(func(center: Vector2, request: DamageRequest) -> void:
		rank_one_centers.append(center)
		rank_one_requests.append(request)
	)
	rank_five.arrow_rain_requested.connect(func(center: Vector2, request: DamageRequest) -> void:
		rank_five_centers.append(center)
		rank_five_requests.append(request)
	)
	var rank_one_sp := rank_one.current_sp
	var rank_five_sp := rank_five.current_sp
	_check(rank_one.use_arrow_rain(Vector2(900, 0)) and rank_five.use_arrow_rain(Vector2(140, 80)), "R1 and R5 both emit a valid point-targeted arrow rain")
	_check(rank_one_centers == [Vector2(480, 0)] and rank_five_centers == [Vector2(140, 80)], "placement clamps only distant points and preserves nearby cursor coordinates")
	_check(rank_one_requests.size() == 1 and is_equal_approx(rank_one_requests[0].physical_damage, rank_one.stat_breakdown.value(&"precision_attack") * 0.60), "R1 captures approved per-volley precision power")
	_check(rank_five_requests.size() == 1 and is_equal_approx(rank_five_requests[0].physical_damage, rank_five.stat_breakdown.value(&"precision_attack") * 1.00), "R5 captures approved per-volley precision power")
	_check(rank_one_requests[0].accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and rank_one_requests[0].can_crit, "each volley uses confirmed area geometry and remains critical-capable")
	_check(rank_one.current_sp == rank_one_sp - 22.0 and rank_five.current_sp == rank_five_sp - 30.0, "each rank debits its approved SP cost once rather than per volley or target")
	_check(rank_one.skill_cooldown(&"arrow_rain") == StatCalculator.effective_cooldown(7.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"arrow_rain") == StatCalculator.effective_cooldown(7.0, rank_five.stat_breakdown), "both ranks apply the fixed cooldown through the shared calculator")
	_check(rank_five.skill_rank(&"arrow_rain") == 5 and rank_five.skill_range(&"arrow_rain") == 480.0 and rank_five.skill_cast_time(&"arrow_rain") == 0.0, "runtime values come from the copied R5 snapshot after source mutation")
	rank_five.mage_cooldowns[&"arrow_rain"] = 0.0
	rank_five.current_sp = 29.0
	var requests_before := rank_five_requests.size()
	_check(not rank_five.use_arrow_rain(Vector2(140, 80)) and rank_five.current_sp == 29.0 and rank_five_requests.size() == requests_before, "R5 blocks below 30 SP without spending or emitting")
	var invalid_rank := _player(navigation, 6)
	root.add_child(invalid_rank)
	_check(invalid_rank.skill_rank_definition(&"arrow_rain") == null and invalid_rank.skill_cost(&"arrow_rain") == 0.0 and invalid_rank.skill_range(&"arrow_rain") == 0.0 and not invalid_rank.use_arrow_rain(Vector2.ZERO), "invalid runtime rank is ineligible instead of falling back to R1 values")
	for node: Node in [rank_one, rank_five, invalid_rank]:
		node.queue_free()

func _check_announced_area_runtime() -> void:
	var center := Vector2(300, 200)
	var steady := _target(center)
	var dodger := _target(center + Vector2(20, 0))
	var entrant := _target(center + Vector2(180, 0))
	var outside := _target(center + Vector2(220, 0))
	var counts: Dictionary[int, int] = {}
	var requests: Array[DamageRequest] = []
	var rain := ArrowRain.new()
	rain.configure(center, _request(), [outside, entrant, dodger, steady])
	rain.hit.connect(func(request: DamageRequest, actor: CombatActor) -> void:
		counts[actor.get_instance_id()] = int(counts.get(actor.get_instance_id(), 0)) + 1
		requests.append(request)
	)
	root.add_child(rain)
	rain._process(ArrowRain.WARNING_DURATION - 0.01)
	_check(counts.is_empty() and rain.volleys_emitted == 0 and not rain.is_queued_for_deletion(), "warning window deals no early damage")
	_check(rain.process_mode == Node.PROCESS_MODE_PAUSABLE and rain.global_position == center and ArrowRain.RADIUS == 80.0, "area owns fixed geometry and follows tree pause")
	dodger.global_position = center + Vector2(200, 0)
	rain._process(0.02)
	_check(counts.get(steady.get_instance_id(), 0) == 1 and not counts.has(dodger.get_instance_id()), "movement during the warning dodges the first volley")
	_check(not counts.has(entrant.get_instance_id()) and not counts.has(outside.get_instance_id()), "actors outside the fixed radius receive no first-volley impact")
	entrant.global_position = center + Vector2(10, 0)
	rain._process(ArrowRain.VOLLEY_INTERVAL * 2.0)
	_check(counts.get(steady.get_instance_id(), 0) == 3 and counts.get(entrant.get_instance_id(), 0) == 2, "current position is sampled independently on all three volleys without retroactive hits")
	_check(not counts.has(dodger.get_instance_id()) and not counts.has(outside.get_instance_id()), "remaining outside avoids every later volley")
	var requests_are_isolated := requests.size() == 5
	for request: DamageRequest in requests:
		requests_are_isolated = requests_are_isolated and request.target_id != 0 and request.skill_id == &"arrow_rain" and request.physical_damage == 10.0
	_check(requests_are_isolated, "each target and volley receives an independent captured DamageRequest")
	_check(rain.volleys_emitted == ArrowRain.VOLLEY_COUNT and rain.is_queued_for_deletion(), "effect cleans itself immediately after the fixed third volley")
	for actor: CombatActor in [steady, dodger, entrant, outside]:
		actor.queue_free()

func _check_preview_hud_dispatch_and_effect() -> void:
	RunController.pending_run_state = RunState.from_build("arrow-rain-preview", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"arrow_rain"]
	_check(controller.skill_label.text.contains("Chuva de Flechas R5") and card.tooltip_text.contains("R5") and card.tooltip_text.contains("30 SP"), "HUD renders snapshot rank and definition cost from the same source")
	controller.cast_intent.active_skill = &"arrow_rain"
	var near_point := controller.player.global_position + Vector2(180, 40)
	controller._update_aim(near_point)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == near_point and controller.battle_indicators.active_range == 480.0, "ready preview preserves a nearby point and exposes ranked placement range")
	var far_point := controller.player.global_position + Vector2(1000, 0)
	controller._update_aim(far_point)
	var expected_center := controller.player.global_position + Vector2.RIGHT * 480.0
	_check(controller.battle_indicators.endpoint == expected_center, "preview clamps a distant cursor to the same center used by execution")
	var inside: CombatActor = controller.enemies[0]
	var outside: CombatActor = controller.enemies[1]
	inside.global_position = expected_center
	outside.global_position = expected_center + Vector2(160, 0)
	var sp_before := controller.player.current_sp
	controller._execute_skill(&"arrow_rain", far_point)
	var effects := get_nodes_in_group("player_effects")
	var rain := effects.back() as ArrowRain if not effects.is_empty() else null
	_check(rain != null and controller.player.current_sp == sp_before - 30.0 and controller.player.skill_cooldown(&"arrow_rain") == StatCalculator.effective_cooldown(7.0, controller.player.stat_breakdown), "ARROW_RAIN handler spends once and creates exactly one ranked area")
	_check(rain != null and rain.global_position == expected_center and rain.targets.size() == controller.enemies.size() and is_equal_approx(rain.damage_request.physical_damage, controller.player.stat_breakdown.value(&"precision_attack")), "spawned area captures center, targets and R5 per-volley damage")
	var inside_hp := inside.health.current_hp
	var outside_hp := outside.health.current_hp
	if rain != null:
		rain.damage_request.can_crit = false
		rain._process(ArrowRain.WARNING_DURATION - 0.01)
	_check(inside.health.current_hp == inside_hp and outside.health.current_hp == outside_hp, "controller applies no damage before the warning completes")
	if rain != null:
		rain._process(0.02)
	_check(inside.health.current_hp < inside_hp and outside.health.current_hp == outside_hp, "first volley damages only actors currently inside the announced area")
	if rain != null:
		rain._process(ArrowRain.VOLLEY_INTERVAL * 2.0)
	_check(rain != null and rain.volleys_emitted == 3 and rain.is_queued_for_deletion(), "controller-connected effect delivers all volleys and cleans itself")
	controller.queue_free()
	await process_frame

func _player(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("arrow-rain-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "arrow-rain-test"
	snapshot.base_class_id = &"archer"
	snapshot.skill_ranks = {&"arrow_rain": rank}
	snapshot.active_slots = [&"arrow_rain", null, null, null, null]
	return snapshot

func _request() -> DamageRequest:
	var request := DamageRequest.new()
	request.skill_id = &"arrow_rain"
	request.physical_damage = 10.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = true
	return request

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
