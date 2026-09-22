extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_library_and_slot_boundary()
	await _check_explosion_runtime()
	await _check_ranked_player_runtime()
	await _check_controller_flow()
	print("E04 Armadilha Explosiva por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_library_and_slot_boundary() -> void:
	var definition := ClassCatalog.skill_definition(&"explosive_trap")
	var expected_powers: Array[float] = [1.35, 1.60, 1.85, 2.10, 2.35]
	var expected_costs: Array[float] = [20.0, 22.0, 24.0, 26.0, 28.0]
	_check(definition != null and definition.display_name == "Armadilha Explosiva" and definition.targeting == SkillDefinition.Targeting.POINT and definition.handler_id == SkillDefinition.Handler.EXPLOSIVE_TRAP, "catalog publishes the typed point-targeted Explosive Trap handler")
	_check(definition.is_rank_catalog_valid() and definition.ranks.size() == 5 and definition.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and definition.can_crit, "Explosive Trap owns a valid geometric critical catalog")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_powers[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Explosive Trap R%d owns its approved precision multiplier and SP cost" % rank)
		_check(values.cooldown == 9.0 and values.range == 360.0 and values.projectile_speed == 0.0, "Explosive Trap R%d preserves fixed cooldown, placement range and no projectile" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0, "Explosive Trap R%d remains instant" % rank)
		_check(values.precision_weight == 1.0 and values.physical_weight == 0.0 and values.magic_weight == 0.0 and values.effect_ids.is_empty(), "Explosive Trap R%d scales only physical precision damage without control" % rank)
	var profile := ProfileCatalog.pilot()
	_check(profile.skill_metadata(&"explosive_trap").get("max_purchased_rank") == 5, "profile progression recognizes all five Explosive Trap ranks")
	_check(profile.base_class_is_available(&"archer"), "delivered Precision passive keeps the Archer availability gate open")
	var pilot := RunState.new(&"archer")
	_check(ClassCatalog.class_definition(&"archer").skill_ids.size() == CharacterState.ACTIVE_SLOT_COUNT and pilot.build_snapshot.active_slots.size() == CharacterState.ACTIVE_SLOT_COUNT, "legacy pilot remains bounded to exactly five active slots")
	_check(not pilot.skill_levels.has(&"explosive_trap") and &"explosive_trap" not in pilot.build_snapshot.active_slots, "sixth library skill is not silently auto-equipped into a nonexistent slot")

func _check_explosion_runtime() -> void:
	var trigger := _actor(Vector2(20, 0))
	var splash := _actor(Vector2(100 + 18, 0))
	var outside := _actor(Vector2(124, 0))
	var dead := _actor(Vector2(30, 0))
	dead.health.current_hp = 0.0
	var request := DamageRequest.new()
	request.source_id = 901
	request.skill_id = &"explosive_trap"
	request.physical_damage = 77.0
	request.damage_dealt_multiplier = 1.15
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.crit_chance = 0.25
	request.crit_multiplier = 1.75
	request.can_crit = true
	var targets: Array[CombatActor] = [outside, dead, splash, trigger]
	var trap := ExplosiveTrap.new()
	trap.configure_explosive(900, Vector2.ZERO, request, targets)
	root.add_child(trap)
	request.physical_damage = 999.0
	var emitted: Array[DamageRequest] = []
	var impacted: Array[CombatActor] = []
	trap.hit.connect(func(hit_request: DamageRequest, target: CombatActor) -> void:
		emitted.append(hit_request)
		impacted.append(target)
	)
	trap._process(ExplosiveTrap.ARMING_TIME - 0.01)
	_check(trap.state == PlayerTrap.State.ARMING and emitted.is_empty(), "Explosive Trap cannot trigger before its fixed arming time")
	trap._process(0.02)
	_check(trap.state == PlayerTrap.State.TRIGGERED and trap.removal_reason == PlayerTrap.REASON_TRIGGERED, "first eligible target consumes the armed Explosive Trap once")
	_check(impacted.size() == 2 and trigger in impacted and splash in impacted and outside not in impacted and dead not in impacted, "blast samples every living target inside fixed radius plus collision and ignores dead or outside actors")
	_check(impacted[0].get_instance_id() < impacted[1].get_instance_id(), "blast emits impacts in deterministic instance order")
	_check(emitted[0].target_id == impacted[0].get_instance_id() and emitted[1].target_id == impacted[1].get_instance_id(), "each area hit captures its own target ID")
	_check(emitted[0] != emitted[1] and emitted[0].physical_damage == 77.0 and emitted[1].physical_damage == 77.0, "each target receives an independent copy of placement-time physical power")
	_check(emitted[0].source_id == 901 and emitted[0].skill_id == &"explosive_trap" and emitted[0].damage_dealt_multiplier == 1.15, "blast preserves captured source, skill and outgoing multiplier")
	_check(emitted[0].accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and emitted[0].can_crit and emitted[0].crit_chance == 0.25 and emitted[0].crit_multiplier == 1.75, "blast preserves geometric accuracy and critical snapshot")
	_check(trigger.health.current_hp == trigger.health.max_hp and splash.health.current_hp == splash.health.max_hp, "trap runtime emits requests without bypassing the canonical damage applicator")
	await process_frame

	var registry := PlayerTrapRegistry.new()
	root.add_child(registry)
	var replacement_events := {"hits": 0}
	var registered: Array[ExplosiveTrap] = []
	for index: int in range(4):
		var replacement := ExplosiveTrap.new()
		replacement.configure_explosive(902, Vector2(index * 200, 300), emitted[0], targets)
		replacement.hit.connect(func(_request: DamageRequest, _target: CombatActor) -> void: replacement_events["hits"] += 1)
		registered.append(replacement)
		registry.register_trap(replacement)
	_check(registry.active_count(902) == 3 and registered[0].removal_reason == PlayerTrap.REASON_REPLACED, "fourth explosive trap uses the shared three-instance FIFO cap")
	_check(replacement_events["hits"] == 0, "FIFO replacement never detonates the expired explosive trap")
	registry.clear_all(&"run_end")
	_check(replacement_events["hits"] == 0 and registry.active_count() == 0, "cleanup removes armed explosive traps without detonation")
	for actor: CombatActor in targets:
		actor.queue_free()
	registry.queue_free()
	await process_frame

func _check_ranked_player_runtime() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 900, 700), [Rect2(500, 250, 100, 100)], 20.0)
	var rank_one := _archer(navigation, 1)
	var rank_five := _archer(navigation, 5)
	rank_one.global_position = Vector2(100, 100)
	rank_five.global_position = Vector2(100, 180)
	root.add_child(rank_one)
	root.add_child(rank_five)
	var r1_emissions: Array = []
	var r5_emissions: Array = []
	rank_one.explosive_trap_requested.connect(func(center: Vector2, request: DamageRequest) -> void: r1_emissions.append([center, request]))
	rank_five.explosive_trap_requested.connect(func(center: Vector2, request: DamageRequest) -> void: r5_emissions.append([center, request]))
	var r1_sp := rank_one.current_sp
	var r5_sp := rank_five.current_sp
	_check(rank_one.use_explosive_trap(Vector2(700, 100)) and rank_five.use_explosive_trap(Vector2(700, 180)), "R1 and R5 place an explosive trap at a clamped valid point")
	_check(r1_emissions[0][0] == Vector2(460, 100) and r5_emissions[0][0] == Vector2(460, 180), "both ranks capture the fixed 360 placement range")
	var r1_request: DamageRequest = r1_emissions[0][1]
	var r5_request: DamageRequest = r5_emissions[0][1]
	_check(is_equal_approx(r1_request.physical_damage, rank_one.stat_breakdown.value(&"precision_attack") * 1.35) and is_equal_approx(r5_request.physical_damage, rank_five.stat_breakdown.value(&"precision_attack") * 2.35), "rank scales captured physical damage from precision attack only")
	_check(r1_request.magic_damage == 0.0 and r1_request.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and r1_request.can_crit, "explosive request contains no magic damage and uses geometric critical resolution")
	_check(rank_one.current_sp == r1_sp - 20.0 and rank_five.current_sp == r5_sp - 28.0, "each rank spends its approved SP cost once")
	_check(rank_one.skill_cooldown(&"explosive_trap") == StatCalculator.effective_cooldown(9.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"explosive_trap") == StatCalculator.effective_cooldown(9.0, rank_five.stat_breakdown), "both ranks start the fixed effective cooldown")
	rank_five.mage_cooldowns[&"extended_aim"] = 0.0
	rank_five.current_sp = rank_five.max_sp
	rank_five.use_extended_aim()
	_check(rank_five.skill_range(&"explosive_trap") == 360.0 and rank_five.explosive_trap_center(Vector2(700, 180)) == Vector2(460, 180), "Mira Estendida does not extend explosive trap placement")
	rank_one.mage_cooldowns[&"explosive_trap"] = 0.0
	rank_one.current_sp = rank_one.max_sp
	rank_one.global_position = Vector2(400, 300)
	var blocked_sp := rank_one.current_sp
	_check(not rank_one.use_explosive_trap(Vector2(550, 300)) and rank_one.current_sp == blocked_sp and rank_one.skill_cooldown(&"explosive_trap") == 0.0, "blocked placement fails before SP and cooldown commit")
	var invalid := _archer(navigation, 6)
	root.add_child(invalid)
	_check(invalid.skill_rank_definition(&"explosive_trap") == null and not invalid.use_explosive_trap(Vector2(200, 200)), "invalid runtime rank is ineligible instead of falling back")
	for actor: PlayerActor in [rank_one, rank_five, invalid]:
		actor.queue_free()
	await process_frame

func _check_controller_flow() -> void:
	RunController.pending_run_state = RunState.from_build("explosive-controller", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.global_position = Vector2(1450, 850)
	_check(controller._key_skill(KEY_D) == &"explosive_trap" and controller.battle_controls.skill_buttons.has(&"explosive_trap"), "equipped fifth slot binds Explosive Trap to D and publishes its HUD card")
	var placement := controller.player.global_position + Vector2(180, 0)
	controller.battle_indicators.show_aim(&"explosive_trap", controller.player, placement, true)
	_check(controller.battle_indicators.endpoint == placement and controller.battle_indicators.active_range == 360.0, "preview uses the same point and fixed placement range as execution")
	var sp_before := controller.player.current_sp
	controller._commit_skill(&"explosive_trap", placement)
	var active := controller.trap_registry.active_traps(controller.player.get_instance_id())
	_check(active.size() == 1 and active[0] is ExplosiveTrap and active[0].global_position == placement, "controller materializes Explosive Trap in the shared registry")
	var explosive := active[0] as ExplosiveTrap
	_check(is_equal_approx(explosive.damage_request.physical_damage, controller.player.stat_breakdown.value(&"precision_attack") * 2.35) and controller.player.current_sp == sp_before - 28.0, "controller trap captures R5 precision damage and spends one cost")
	_check(controller.player.skill_cooldown(&"explosive_trap") == StatCalculator.effective_cooldown(9.0, controller.player.stat_breakdown), "controller starts one ranked cooldown")
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"explosive_trap"]
	_check(card.text.contains("ARMADILHA EXPLOSIVA R5") and card.text.contains("28 SP") and card.text.contains("RECARGA"), "HUD exposes Explosive Trap rank, cost and cooldown in pt-BR")
	var first := controller.enemies[0]
	var second := controller.enemies[1]
	first.global_position = placement
	second.global_position = placement + Vector2(ExplosiveTrap.BLAST_RADIUS, 0)
	var first_hp := first.health.current_hp
	var second_hp := second.health.current_hp
	controller.rng.seed = 404
	explosive._process(ExplosiveTrap.ARMING_TIME)
	_check(first.health.current_hp < first_hp and second.health.current_hp < second_hp, "integrated detonation applies canonical physical damage to every target in the blast")
	_check(not first.is_rooted() and not second.is_rooted(), "explosive detonation adds no hidden control")
	_check(controller.trap_registry.active_count() == 0, "integrated detonation leaves the shared registry exactly once")
	controller.queue_free()
	await process_frame

func _archer(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("explosive-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "explosive-test"
	snapshot.base_class_id = &"archer"
	snapshot.skill_ranks = {
		&"double_shot": 1,
		&"piercing_arrow": 1,
		&"arrow_rain": 1,
		&"extended_aim": 1,
		&"explosive_trap": rank,
	}
	snapshot.active_slots = [&"double_shot", &"piercing_arrow", &"arrow_rain", &"extended_aim", &"explosive_trap"]
	return snapshot

func _actor(position_value: Vector2) -> CombatActor:
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
