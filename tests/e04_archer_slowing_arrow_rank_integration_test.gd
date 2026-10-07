extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_library_and_slot_boundary()
	await _check_ranked_player_runtime()
	await _check_shared_slow_contract()
	await _check_controller_projectile_and_hud()
	print("E04 Flecha Entorpecente por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_library_and_slot_boundary() -> void:
	var definition := ClassCatalog.skill_definition(&"slowing_arrow")
	var expected_durations: Array[float] = [1.4, 1.8, 2.2, 2.6, 3.0]
	var expected_costs: Array[float] = [15.0, 16.0, 17.0, 18.0, 19.0]
	_check(definition != null and definition.display_name == "Flecha Entorpecente" and definition.targeting == SkillDefinition.Targeting.DIRECTION and definition.handler_id == SkillDefinition.Handler.SLOWING_ARROW, "catalog publishes the typed directional Slowing Arrow handler")
	_check(definition.is_rank_catalog_valid() and definition.ranks.size() == 5 and definition.accuracy_mode == DamageRequest.AccuracyMode.CONTESTED and definition.can_crit, "Slowing Arrow owns a valid contested critical catalog")
	_check(definition.power == 0.90, "Slowing Arrow keeps its fixed direct-damage multiplier outside the duration rank axis")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_durations[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Slowing Arrow R%d owns its approved slow duration and SP cost" % rank)
		_check(values.cooldown == 5.0 and values.range == 560.0 and values.projectile_speed == 880.0, "Slowing Arrow R%d preserves fixed cooldown, range and projectile speed" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0, "Slowing Arrow R%d remains instant" % rank)
		_check(values.precision_weight == 1.0 and values.physical_weight == 0.0 and values.magic_weight == 0.0 and values.effect_ids == [&"slow"], "Slowing Arrow R%d exposes precision damage plus typed slow" % rank)
	var profile := ProfileCatalog.pilot()
	_check(profile.skill_metadata(&"slowing_arrow").get("max_purchased_rank") == 5, "profile progression recognizes all five Slowing Arrow ranks")
	_check(profile.base_class_is_available(&"archer"), "delivered Precision passive keeps the Archer availability gate open")
	var pilot := RunState.new(&"archer")
	_check(ClassCatalog.class_definition(&"archer").skill_ids.size() == CharacterState.ACTIVE_SLOT_COUNT and pilot.build_snapshot.active_slots.size() == CharacterState.ACTIVE_SLOT_COUNT, "legacy pilot remains bounded to exactly five active slots")
	_check(not pilot.skill_levels.has(&"slowing_arrow") and &"slowing_arrow" not in pilot.build_snapshot.active_slots, "seventh library skill is not silently auto-equipped")

func _check_ranked_player_runtime() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 700), [], 20.0)
	var rank_one := _archer(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("slowing-arrow-r5", rank_five_source)
	rank_five_source.skill_ranks[&"slowing_arrow"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	root.add_child(rank_one)
	root.add_child(rank_five)
	var r1_emissions: Array = []
	var r5_emissions: Array = []
	rank_one.slowing_arrow_requested.connect(func(request: DamageRequest, direction: Vector2, slow_fraction: float, slow_duration: float) -> void: r1_emissions.append([request, direction, slow_fraction, slow_duration]))
	rank_five.slowing_arrow_requested.connect(func(request: DamageRequest, direction: Vector2, slow_fraction: float, slow_duration: float) -> void: r5_emissions.append([request, direction, slow_fraction, slow_duration]))
	var r1_sp := rank_one.current_sp
	var r5_sp := rank_five.current_sp
	_check(rank_one.use_slowing_arrow(Vector2.RIGHT) and rank_five.use_slowing_arrow(Vector2.DOWN), "R1 and R5 both emit one valid fixed-direction slowing arrow")
	_check(r1_emissions.size() == 1 and r5_emissions.size() == 1 and r1_emissions[0][1] == Vector2.RIGHT and r5_emissions[0][1] == Vector2.DOWN, "each cast captures its normalized emission direction once")
	var r1_request: DamageRequest = r1_emissions[0][0]
	var r5_request: DamageRequest = r5_emissions[0][0]
	_check(is_equal_approx(r1_request.physical_damage, rank_one.stat_breakdown.value(&"precision_attack") * 0.90) and is_equal_approx(r5_request.physical_damage, rank_five.stat_breakdown.value(&"precision_attack") * 0.90), "R1 and R5 keep fixed precision damage while rank grows only control duration")
	_check(r1_request.magic_damage == 0.0 and r1_request.skill_id == &"slowing_arrow" and r1_request.accuracy_mode == DamageRequest.AccuracyMode.CONTESTED and r1_request.can_crit, "emission captures canonical physical contested critical damage")
	_check(r1_emissions[0][2] == 0.35 and r5_emissions[0][2] == 0.35 and r1_emissions[0][3] == 1.4 and r5_emissions[0][3] == 3.0, "slow intensity remains moderate and fixed while snapshot rank controls captured duration")
	_check(rank_one.current_sp == r1_sp - 15.0 and rank_five.current_sp == r5_sp - 19.0, "each rank spends its approved SP cost once")
	_check(rank_one.skill_cooldown(&"slowing_arrow") == StatCalculator.effective_cooldown(5.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"slowing_arrow") == StatCalculator.effective_cooldown(5.0, rank_five.stat_breakdown), "both ranks start the fixed effective cooldown")
	_check(rank_five.skill_rank(&"slowing_arrow") == 5 and rank_five.skill_range(&"slowing_arrow") == 560.0 and rank_five.skill_projectile_speed(&"slowing_arrow") == 880.0 and rank_five.skill_cast_time(&"slowing_arrow") == 0.0, "runtime values come from the isolated R5 snapshot")
	rank_five.mage_cooldowns[&"extended_aim"] = 0.0
	rank_five.current_sp = rank_five.max_sp
	_check(rank_five.use_extended_aim() and rank_five.skill_range(&"slowing_arrow") == 680.0, "Mira Estendida applies its fixed range bonus to Slowing Arrow")
	rank_five.mage_cooldowns[&"slowing_arrow"] = 0.0
	rank_five.current_sp = 18.0
	var emissions_before := r5_emissions.size()
	_check(not rank_five.use_slowing_arrow(Vector2.RIGHT) and rank_five.current_sp == 18.0 and r5_emissions.size() == emissions_before, "R5 blocks below 19 SP without spending or emitting")
	var invalid := _archer(navigation, 6)
	root.add_child(invalid)
	_check(invalid.skill_rank_definition(&"slowing_arrow") == null and invalid.skill_cost(&"slowing_arrow") == 0.0 and invalid.skill_range(&"slowing_arrow") == 0.0 and not invalid.use_slowing_arrow(Vector2.RIGHT), "invalid runtime rank is ineligible instead of falling back")
	for actor: PlayerActor in [rank_one, rank_five, invalid]:
		actor.queue_free()
	await process_frame

func _check_shared_slow_contract() -> void:
	var actor := _target(Vector2.ZERO)
	var base_stats := actor.stat_breakdown.values()
	actor.apply_slow(0.35, 1.4)
	_check(is_equal_approx(actor.movement_speed_multiplier(), 0.65) and actor.slow_remaining == 1.4 and actor.stat_breakdown.values() == base_stats, "slowing runtime changes movement multiplicatively without mutating stats")
	actor.apply_slow(0.20, 3.0)
	_check(is_equal_approx(actor.movement_speed_multiplier(), 0.65) and actor.slow_remaining == 3.0, "same-family reapplication never stacks intensity and preserves the longer duration")
	actor.apply_slow(0.90, 1.0)
	_check(is_equal_approx(actor.movement_speed_multiplier(), 0.50) and actor.slow_fraction == CombatActor.MAX_SLOW_FRACTION, "shared slow obeys the documented global 50 percent cap")
	actor.advance_statuses(2.0, true)
	_check(actor.slow_remaining == 3.0, "simulation pause freezes slow duration")
	actor.advance_statuses(3.0)
	_check(actor.slow_remaining == 0.0 and actor.slow_fraction == 0.0 and actor.movement_speed_multiplier() == 1.0, "slow expiration restores the unmodified movement multiplier")
	actor.apply_slow(0.35, 3.0)
	var lethal := DamageRequest.new()
	lethal.source_id = 99
	lethal.target_id = actor.get_instance_id()
	lethal.physical_damage = 99999.0
	lethal.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	actor.apply_damage(lethal, rng)
	_check(not actor.is_alive() and actor.slow_remaining == 0.0 and actor.slow_fraction == 0.0, "death clears slow synchronously")
	actor.queue_free()
	await process_frame

func _check_controller_projectile_and_hud() -> void:
	RunController.pending_run_state = RunState.from_build("slowing-arrow-controller", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.global_position = Vector2(1450, 850)
	var target := controller.enemies[0]
	target.global_position = controller.player.global_position + Vector2(260, 0)
	_check(controller._key_skill(KEY_R) == &"slowing_arrow" and controller.battle_controls.skill_buttons.has(&"slowing_arrow"), "equipped fifth slot binds Slowing Arrow to R and publishes its HUD card")
	var aim_point := controller.player.global_position + Vector2(1000, 0)
	controller.battle_indicators.show_aim(&"slowing_arrow", controller.player, aim_point, true)
	_check(controller.battle_indicators.endpoint == controller.player.global_position + Vector2.RIGHT * 560.0 and controller.battle_indicators.active_range == 560.0, "directional preview consumes the same unbuffed range as execution")
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"slowing_arrow"]
	_check(controller.skill_label.text.contains("Flecha Entorpecente R5") and card.tooltip_text.contains("R5") and card.tooltip_text.contains("19 SP"), "HUD exposes Slowing Arrow rank and cost in pt-BR")
	controller.player.mage_cooldowns[&"extended_aim"] = 0.0
	controller.player.current_sp = controller.player.max_sp
	controller.player.use_extended_aim()
	controller.player.current_sp = controller.player.max_sp
	var sp_before := controller.player.current_sp
	controller._execute_skill(&"slowing_arrow", aim_point)
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(projectiles.size() == 1 and projectiles[0] is PlayerProjectile, "SLOWING_ARROW handler materializes exactly one shared precision projectile")
	var projectile := projectiles[0] as PlayerProjectile
	_check(projectile.max_hits == 1 and projectile.speed == 880.0 and projectile.max_distance == 680.0 and projectile.direction == Vector2.RIGHT and projectile.color == Color("72c9ff"), "projectile captures one-hit policy, fixed direction, speed, buffed range and distinct slow presentation")
	_check(is_equal_approx(projectile.request.physical_damage, controller.player.stat_breakdown.value(&"precision_attack") * 0.90) and controller.player.current_sp == sp_before - 19.0, "controller captures fixed R5 precision damage and spends one cost")
	_check(controller.player.skill_cooldown(&"slowing_arrow") == StatCalculator.effective_cooldown(5.0, controller.player.stat_breakdown), "controller starts one ranked cooldown")
	projectile.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	projectile.request.can_crit = false
	var hp_before := target.health.current_hp
	projectile._process(1.0)
	_check(target.health.current_hp < hp_before and is_equal_approx(target.movement_speed_multiplier(), 0.65), "landed integrated projectile resolves physical damage and applies the fixed 35 percent slow")
	_check(target.slow_remaining == 3.0, "integrated R5 impact applies the captured three-second duration")
	target.clear_statuses()
	var harmless := DamageRequest.new()
	harmless.source_id = controller.player.get_instance_id()
	harmless.target_id = target.get_instance_id()
	harmless.skill_id = &"slowing_arrow"
	harmless.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	controller._on_slowing_arrow_hit(harmless, target, 0.35, 3.0)
	_check(target.slow_remaining == 0.0 and target.movement_speed_multiplier() == 1.0, "zero-damage impact cannot apply slow")
	controller.queue_free()
	await process_frame

func _archer(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("slowing-arrow-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "slowing-arrow-test"
	snapshot.base_class_id = &"archer"
	snapshot.skill_ranks = {
		&"double_shot": 1,
		&"piercing_arrow": 1,
		&"arrow_rain": 1,
		&"extended_aim": 1,
		&"slowing_arrow": rank,
	}
	snapshot.active_slots = [&"double_shot", &"piercing_arrow", &"arrow_rain", &"extended_aim", &"slowing_arrow"]
	return snapshot

func _target(position_value: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	actor.global_position = position_value
	root.add_child(actor)
	actor.set_process(false)
	return actor

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
