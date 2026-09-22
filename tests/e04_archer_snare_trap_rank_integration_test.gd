extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_and_profile_gate()
	await _check_hard_control_contract()
	await _check_snare_trigger_contract()
	await _check_ranked_player_and_controller_flow()
	print("E04 Armadilha de Laço por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_and_profile_gate() -> void:
	var definition := ClassCatalog.skill_definition(&"snare_trap")
	var expected_durations: Array[float] = [1.4, 1.8, 2.2, 2.6, 3.0]
	var expected_costs: Array[float] = [18.0, 19.0, 20.0, 21.0, 22.0]
	_check(definition != null and definition.display_name == "Armadilha de Laço" and definition.targeting == SkillDefinition.Targeting.POINT and definition.handler_id == SkillDefinition.Handler.SNARE_TRAP, "catalog publishes the typed point-targeted Snare Trap handler")
	_check(definition.is_rank_catalog_valid() and definition.ranks.size() == 5, "Snare Trap owns a valid closed five-rank catalog")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_durations[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Snare Trap R%d owns its approved root duration and SP cost" % rank)
		_check(values.cooldown == 8.0 and values.range == 360.0 and values.projectile_speed == 0.0, "Snare Trap R%d preserves fixed cooldown, placement range and no projectile" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0, "Snare Trap R%d remains instant" % rank)
		_check(values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.magic_weight == 0.0 and values.effect_ids == [&"physical_root"], "Snare Trap R%d carries control without damage weights" % rank)
	var profile := ProfileCatalog.pilot()
	_check(profile.skill_metadata(&"snare_trap").get("max_purchased_rank") == 5, "profile progression recognizes all five Snare Trap ranks")
	_check(not profile.base_class_is_available(&"archer"), "fifth Archer active does not bypass the missing-passive availability gate")
	_check(ClassCatalog.skill_definition(&"explosive_trap") != null, "Snare contract coexists with the later Explosive Trap catalog entry")

func _check_hard_control_contract() -> void:
	var normal := _actor(Vector2.ZERO, {&"vit": 50})
	var resistance := normal.stat_breakdown.value(&"physical_cc_resistance")
	_check(is_equal_approx(resistance, 0.10), "physical root reads the canonical vitality-derived CC resistance")
	_check(normal.apply_root(4.0) == 3.0 and normal.is_rooted(), "normal target applies resistance then respects the three-second hard-CC cap")
	_check(normal.apply_root(1.0) == 3.0 and normal.root_remaining() == 3.0, "same-family root never shortens or stacks its remaining duration")
	paused = true
	normal._process(1.0)
	paused = false
	_check(normal.root_remaining() == 3.0, "tree pause freezes root duration")
	normal._process(1.25)
	_check(is_equal_approx(normal.root_remaining(), 1.75), "live simulation advances root in real seconds")
	normal._process(2.0)
	_check(not normal.is_rooted() and normal.root_remaining() == 0.0, "root expires without changing actor stats")
	_check(normal.apply_root(2.0, &"unknown") == 0.0, "unknown control tag is rejected")
	_check(normal.set_unstoppable(1.5) and normal.apply_root(3.0) == 0.0 and not normal.is_rooted(), "Unstoppable rejects root before any state is applied")
	normal._process(1.5)
	_check(normal.apply_root(2.0) > 0.0, "root becomes eligible after Unstoppable expires")
	normal.clear_statuses()
	_check(not normal.is_rooted() and normal.hard_controls.unstoppable_remaining == 0.0, "status cleanup clears hard control and immunity windows")

	var boss := _actor(Vector2.ZERO, {})
	boss.configure_hard_control_profile(true)
	_check(boss.apply_root(3.0) == 1.0 and boss.hard_controls.boss_budget_remaining == 1.0, "boss root is capped at one second and charges shared budget")
	_check(boss.hard_controls.apply(&"stun", 1.0, 0.0) == 1.0 and boss.hard_controls.boss_budget_remaining == 1.0, "overlapping hard-control family does not double-charge disabled time")
	boss.hard_controls.advance(0.6)
	_check(boss.hard_controls.apply(&"fear", 1.0, 0.0) == 1.0 and is_equal_approx(boss.hard_controls.boss_budget_remaining, 0.4), "extending an overlap charges only the uncovered boss-control interval")
	boss.hard_controls.advance(1.0)
	_check(is_equal_approx(boss.apply_root(1.0), 0.4) and boss.hard_controls.boss_budget_remaining == 0.0, "last attempt is truncated to the remaining two-second boss budget")
	boss.hard_controls.advance(0.5)
	_check(boss.apply_root(1.0) == 0.0, "exhausted boss window rejects new hard control")
	boss.hard_controls.advance(10.0)
	_check(boss.apply_root(2.0) == 1.0 and boss.hard_controls.boss_budget_remaining == 1.0, "fixed ten-second window restores boss hard-CC budget")
	boss.health.current_hp = 0.0
	boss._on_health_died(boss.get_instance_id())
	_check(not boss.is_rooted(), "death synchronously clears root")
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 800, 600), [], 20.0)
	var swordsman := PlayerActor.new()
	swordsman.configure(navigation, RunState.new(&"swordsman"))
	swordsman.global_position = Vector2(100, 100)
	root.add_child(swordsman)
	swordsman.move_to(Vector2(500, 100))
	swordsman.apply_root(2.0)
	swordsman._process(0.5)
	_check(swordsman.global_position == Vector2(100, 100) and swordsman.velocity == Vector2.ZERO, "root blocks player walking and clears movement inertia")
	var dash_sp := swordsman.current_sp
	_check(not swordsman.use_dash(Vector2.RIGHT) and swordsman.current_sp == dash_sp, "root blocks Dash before its cost commits")
	var no_targets: Array[CombatActor] = []
	_check(swordsman.use_slash(Vector2.RIGHT, no_targets) and swordsman.current_sp < dash_sp, "root does not silence a non-displacement combat skill")
	var mage := PlayerActor.new()
	mage.configure(navigation, RunState.new(&"mage"))
	mage.global_position = Vector2(100, 200)
	root.add_child(mage)
	mage.apply_root(2.0)
	var teleport_sp := mage.current_sp
	_check(not mage.can_teleport(Vector2(300, 200)) and not mage.use_teleport(Vector2(300, 200)) and mage.current_sp == teleport_sp, "root blocks Teleport before its cost commits")
	for actor: CombatActor in [normal, boss]:
		actor.queue_free()
	for player: PlayerActor in [swordsman, mage]:
		player.queue_free()
	await process_frame

func _check_snare_trigger_contract() -> void:
	var farther := _actor(Vector2(24, 0), {})
	var nearest := _actor(Vector2(12, 0), {})
	var trap := SnareTrap.new()
	trap.configure_snare(999, Vector2.ZERO, 2.2, [farther, nearest])
	root.add_child(trap)
	var events := {"roots": 0, "duration": 0.0}
	trap.root_applied.connect(func(_trap: SnareTrap, _target: CombatActor, duration: float) -> void:
		events["roots"] += 1
		events["duration"] = duration
	)
	var nearest_hp := nearest.health.current_hp
	trap._process(0.59)
	_check(trap.state == PlayerTrap.State.ARMING and not nearest.is_rooted(), "Snare Trap cannot trigger before its fixed arming time")
	trap._process(0.02)
	_check(trap.state == PlayerTrap.State.TRIGGERED and nearest.is_rooted() and not farther.is_rooted(), "armed Snare Trap consumes itself on the nearest eligible target deterministically")
	var expected_duration := 2.2 * (1.0 - nearest.stat_breakdown.value(&"physical_cc_resistance"))
	_check(is_equal_approx(nearest.root_remaining(), expected_duration) and is_equal_approx(events["duration"], expected_duration), "trap applies captured ranked duration through physical CC resistance")
	_check(events["roots"] == 1 and nearest.health.current_hp == nearest_hp, "trigger emits one root result and causes no damage")
	await process_frame

	var immune := _actor(Vector2.ZERO, {})
	immune.set_unstoppable(2.0)
	var immune_trap := SnareTrap.new()
	immune_trap.configure_snare(998, Vector2.ZERO, 3.0, [immune])
	root.add_child(immune_trap)
	immune_trap._process(SnareTrap.ARMING_TIME)
	_check(immune_trap.state == PlayerTrap.State.TRIGGERED and immune_trap.applied_root_duration == 0.0 and not immune.is_rooted(), "Unstoppable target still consumes the physical trap but receives no root")
	var outside := _actor(Vector2(200, 0), {})
	var waiting_trap := SnareTrap.new()
	waiting_trap.configure_snare(997, Vector2.ZERO, 1.4, [outside])
	root.add_child(waiting_trap)
	waiting_trap._process(SnareTrap.ARMING_TIME + 0.1)
	_check(waiting_trap.state == PlayerTrap.State.ARMED and not outside.is_rooted(), "armed trap remains until a target actually enters its radius")
	outside.global_position = Vector2(SnareTrap.TRIGGER_RADIUS + outside.collision_radius, 0)
	waiting_trap._process(0.01)
	_check(waiting_trap.state == PlayerTrap.State.TRIGGERED and outside.is_rooted(), "collision radius participates in boundary trigger")
	for actor: CombatActor in [farther, nearest, immune, outside]:
		actor.queue_free()
	await process_frame

func _check_ranked_player_and_controller_flow() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 900, 700), [Rect2(500, 250, 100, 100)], 20.0)
	var rank_one := _archer(navigation, 1)
	var rank_five := _archer(navigation, 5)
	root.add_child(rank_one)
	root.add_child(rank_five)
	rank_one.global_position = Vector2(100, 100)
	rank_five.global_position = Vector2(100, 180)
	var rank_one_emissions: Array = []
	var rank_five_emissions: Array = []
	rank_one.snare_trap_requested.connect(func(center: Vector2, duration: float) -> void: rank_one_emissions.append([center, duration]))
	rank_five.snare_trap_requested.connect(func(center: Vector2, duration: float) -> void: rank_five_emissions.append([center, duration]))
	var r1_sp := rank_one.current_sp
	var r5_sp := rank_five.current_sp
	_check(rank_one.use_snare_trap(Vector2(700, 100)) and rank_five.use_snare_trap(Vector2(700, 180)), "R1 and R5 place a trap at a clamped valid point")
	_check(rank_one_emissions[0][0] == Vector2(460, 100) and rank_five_emissions[0][0] == Vector2(460, 180), "placement captures the fixed 360 range for both ranks")
	_check(rank_one_emissions[0][1] == 1.4 and rank_five_emissions[0][1] == 3.0, "rank changes only the root duration captured at placement")
	_check(rank_one.current_sp == r1_sp - 18.0 and rank_five.current_sp == r5_sp - 22.0, "each rank spends its approved SP cost once")
	_check(rank_one.skill_cooldown(&"snare_trap") == StatCalculator.effective_cooldown(8.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"snare_trap") == StatCalculator.effective_cooldown(8.0, rank_five.stat_breakdown), "both ranks start the fixed effective cooldown")
	rank_five.mage_cooldowns[&"extended_aim"] = 0.0
	rank_five.current_sp = rank_five.max_sp
	rank_five.use_extended_aim()
	_check(rank_five.skill_range(&"snare_trap") == 360.0 and rank_five.snare_trap_center(Vector2(700, 180)) == Vector2(460, 180), "Mira Estendida does not extend trap placement")
	rank_one.mage_cooldowns[&"snare_trap"] = 0.0
	rank_one.current_sp = rank_one.max_sp
	rank_one.global_position = Vector2(400, 300)
	var blocked_sp := rank_one.current_sp
	_check(not rank_one.use_snare_trap(Vector2(550, 300)) and rank_one.current_sp == blocked_sp and rank_one.skill_cooldown(&"snare_trap") == 0.0, "blocked placement fails before SP and cooldown commit")
	var invalid := _archer(navigation, 6)
	root.add_child(invalid)
	_check(invalid.skill_rank_definition(&"snare_trap") == null and not invalid.use_snare_trap(Vector2(200, 200)), "invalid runtime rank is ineligible instead of falling back")
	for actor: PlayerActor in [rank_one, rank_five, invalid]:
		actor.queue_free()
	await process_frame

	RunController.pending_run_state = RunState.from_build("snare-controller", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.global_position = Vector2(1450, 850)
	_check(controller._key_skill(KEY_D) == &"snare_trap" and controller.battle_controls.skill_buttons.has(&"snare_trap"), "fifth active binds Snare Trap to D and publishes its HUD card")
	var placement := controller.player.global_position + Vector2(180, 0)
	controller.battle_indicators.show_aim(&"snare_trap", controller.player, placement, true)
	_check(controller.battle_indicators.endpoint == placement and controller.battle_indicators.active_range == 360.0, "preview uses the same point and fixed placement range as execution")
	var sp_before := controller.player.current_sp
	controller._commit_skill(&"snare_trap", placement)
	var active := controller.trap_registry.active_traps(controller.player.get_instance_id())
	_check(active.size() == 1 and active[0] is SnareTrap and active[0].global_position == placement, "controller materializes the emitted Snare Trap in the shared registry")
	_check((active[0] as SnareTrap).root_duration == 3.0 and controller.player.current_sp == sp_before - 22.0, "controller trap captures R5 duration and spends one cost")
	_check(controller.player.skill_cooldown(&"snare_trap") == StatCalculator.effective_cooldown(8.0, controller.player.stat_breakdown), "controller starts one ranked cooldown")
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"snare_trap"]
	_check(card.text.contains("ARMADILHA DE LAÇO R5") and card.text.contains("22 SP") and card.text.contains("RECARGA"), "HUD exposes Snare Trap rank, cost and cooldown in pt-BR")
	var enemy := controller.enemies[0]
	var hp_before := enemy.health.current_hp
	enemy.global_position = placement
	(active[0] as SnareTrap)._process(SnareTrap.ARMING_TIME)
	_check(enemy.is_rooted() and is_equal_approx(enemy.root_remaining(), 3.0 * (1.0 - enemy.stat_breakdown.value(&"physical_cc_resistance"))), "integrated trap roots the enemy using its live physical resistance")
	_check(enemy.health.current_hp == hp_before and controller.trap_registry.active_count() == 0, "integrated trigger deals no damage and leaves the registry once")
	controller.queue_free()
	await process_frame

func _archer(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("snare-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "snare-test"
	snapshot.base_class_id = &"archer"
	snapshot.skill_ranks = {
		&"double_shot": 1,
		&"piercing_arrow": 1,
		&"arrow_rain": 1,
		&"extended_aim": 1,
		&"snare_trap": rank,
	}
	snapshot.active_slots = [&"double_shot", &"piercing_arrow", &"arrow_rain", &"extended_aim", &"snare_trap"]
	return snapshot

func _actor(position_value: Vector2, attributes: Dictionary) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, StatCalculator.calculate(attributes), 18.0)
	actor.global_position = position_value
	root.add_child(actor)
	actor.set_process(false)
	return actor

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
