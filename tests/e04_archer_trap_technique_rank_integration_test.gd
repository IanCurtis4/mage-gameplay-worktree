extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_and_rule_sources()
	_check_snapshot_boundaries()
	await _check_controller_traps()
	print("E04 Técnica de Armadilhas por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_and_rule_sources() -> void:
	var definition := ClassCatalog.skill_definition(&"trap_technique")
	var expected_bonuses: Array[float] = [3.0, 6.0, 9.0]
	_check(definition != null and definition.display_name == "Técnica de Armadilhas" and definition.category == SkillDefinition.Category.PASSIVE and definition.handler_id == SkillDefinition.Handler.TRAP_TECHNIQUE and definition.is_rank_catalog_valid(), "catalog publishes a valid three-rank passive rule handler")
	for rank: int in range(1, 4):
		var values := definition.rank_definition(rank)
		var source := ClassCatalog.passive_rule_source(&"trap_technique", rank)
		_check(values.power == expected_bonuses[rank - 1] and values.effect_ids == [&"trap_armed_duration_flat"], "R%d owns its authored armed permanence bonus" % rank)
		_check(values.sp_cost == 0.0 and values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0 and values.cooldown == 0.0 and values.range == 0.0 and values.projectile_speed == 0.0 and values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.magic_weight == 0.0, "R%d adds no active execution or damage parameter" % rank)
		_check(source.get("source_id") == &"passive_trap_technique" and source.get("armed_duration_bonus") == expected_bonuses[rank - 1], "R%d emits one identified rule source" % rank)
	var copied := definition.rank_definition(3)
	copied.power = 99.0
	_check(definition.rank_definition(3).power == 9.0, "rank lookup isolates catalog data")
	_check(ClassCatalog.passive_rule_source(&"trap_technique", 0).is_empty() and ClassCatalog.passive_rule_source(&"trap_technique", 4).is_empty() and ClassCatalog.passive_modifier_source(&"trap_technique", 3).is_empty(), "invalid ranks and stat modifier lookup cannot apply the trap rule")
	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"trap_technique")
	_check(metadata.get("category") == ProfileCatalog.PASSIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 3, "profile sells R1–R3 for base job points with no free rank")
	_check(catalog.base_class_is_available(&"archer") and catalog.initial_skill_slots(&"archer")["passive_slots"] == [null, null] and ClassCatalog.class_definition(&"archer").passive_id == &"archer_precision", "third passive preserves Archer creation and the rank-zero persistent build")

func _check_snapshot_boundaries() -> void:
	var expected_armed: Array[float] = [15.0, 18.0, 21.0]
	for rank: int in range(1, 4):
		var snapshot := _snapshot(rank, true)
		var sources := snapshot.intrinsic_rule_sources()
		_check(sources.size() == 1 and sources[0]["source_id"] == &"passive_trap_technique" and snapshot.intrinsic_modifier_sources().is_empty(), "R%d remains a rule source outside the stat calculator" % rank)
		_check(snapshot.trap_armed_duration(SnareTrap.ARMED_DURATION) == expected_armed[rank - 1] and snapshot.trap_armed_duration(ExplosiveTrap.ARMED_DURATION) == expected_armed[rank - 1], "R%d extends both concrete armed lifetimes equally" % rank)
		var stats := snapshot.stat_breakdown()
		_check(is_equal_approx(stats.value(&"precision_attack"), 31.2) and is_equal_approx(stats.value(&"attacks_per_second"), 1.155) and is_equal_approx(stats.value(&"hit_rating"), 121.6), "R%d does not change adjacent combat stats" % rank)
	var duplicate := _snapshot(3, true)
	duplicate.passive_slots = [&"trap_technique", &"trap_technique"]
	_check(duplicate.intrinsic_rule_sources().size() == 1 and duplicate.trap_armed_duration(12.0) == 21.0, "duplicate slots do not double the rule")
	var unequipped := _snapshot(3, false)
	_check(unequipped.intrinsic_rule_sources().size() == 1 and unequipped.trap_armed_duration(12.0) == 21.0, "learned passive activates once without legacy equipped slots")
	var invalid := _snapshot(4, true)
	_check(invalid.intrinsic_rule_sources().is_empty() and invalid.trap_armed_duration(12.0) == 12.0, "invalid rank has no fallback bonus")
	var zero := _snapshot(0, true)
	_check(zero.intrinsic_rule_sources().is_empty() and zero.trap_armed_duration(12.0) == 12.0, "R0 has baseline permanence")
	var combined := _snapshot(3, true)
	combined.skill_ranks[&"archer_precision"] = 3
	combined.passive_slots = [&"archer_precision", &"trap_technique"]
	_check(combined.intrinsic_rule_sources().size() == 1 and combined.trap_armed_duration(12.0) == 21.0 and is_equal_approx(combined.stat_breakdown().value(&"hit_rating"), 137.6), "Technique and Precision activate automatically and affect separate authorities")

func _check_controller_traps() -> void:
	var source := _snapshot(3, true)
	var state := RunState.from_build("trap-technique-r3", source)
	source.skill_ranks[&"trap_technique"] = 1
	RunController.pending_run_state = state
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.global_position = Vector2(1450, 850)
	var owner_id := controller.player.get_instance_id()
	var snare_point := controller.player.global_position + Vector2(180, 0)
	var explosive_point := controller.player.global_position + Vector2(180, 80)
	controller._commit_skill(&"snare_trap", snare_point)
	controller._commit_skill(&"explosive_trap", explosive_point)
	var traps := controller.trap_registry.active_traps(owner_id)
	_check(traps.size() == 2 and traps[0] is SnareTrap and traps[1] is ExplosiveTrap, "controller registers both placed trap types from the copied R3 build")
	if traps.size() != 2:
		controller.queue_free()
		await process_frame
		return
	var snare := traps[0] as SnareTrap
	var explosive := traps[1] as ExplosiveTrap
	snare.set_process(false)
	explosive.set_process(false)
	_check(snare.armed_duration == 21.0 and explosive.armed_duration == 21.0 and snare.lifetime_remaining == 21.0 and explosive.lifetime_remaining == 21.0, "both traps capture the authored R3 armed permanence at placement")
	_check(snare.arming_duration == SnareTrap.ARMING_TIME and explosive.arming_duration == ExplosiveTrap.ARMING_TIME and snare.radius == SnareTrap.TRIGGER_RADIUS and explosive.radius == ExplosiveTrap.TRIGGER_RADIUS, "arming clocks and trigger geometry keep their base values")
	_check(snare.root_duration == 1.4 and is_equal_approx(explosive.damage_request.physical_damage, controller.player.stat_breakdown.value(&"precision_attack") * 1.35), "root duration and explosion damage remain those of the equipped active ranks")
	_check(controller.player.skill_cooldown(&"snare_trap") == 8.0 and controller.player.skill_cooldown(&"explosive_trap") == 9.0, "skill cooldowns do not inherit the permanence bonus")
	controller.player.apply_run_modifiers(RunState.from_build("trap-technique-r1-after-placement", _snapshot(1, true)))
	_check(controller.player.trap_armed_duration(12.0) == 15.0 and snare.armed_duration == 21.0 and explosive.armed_duration == 21.0, "existing traps keep captured R3 permanence after the actor changes to R1")
	snare._process(SnareTrap.ARMING_TIME)
	explosive._process(ExplosiveTrap.ARMING_TIME)
	_check(snare.state == PlayerTrap.State.ARMED and explosive.state == PlayerTrap.State.ARMED and snare.lifetime_remaining == 21.0 and explosive.lifetime_remaining == 21.0, "arming completes without consuming armed permanence")
	snare._process(12.0)
	explosive._process(12.0)
	_check(snare.state == PlayerTrap.State.ARMED and explosive.state == PlayerTrap.State.ARMED and controller.trap_registry.active_count(owner_id) == 2, "both R3 traps survive the unmodified twelve-second armed baseline")
	snare._process(9.0)
	explosive._process(9.0)
	_check(snare.state == PlayerTrap.State.EXPIRED and explosive.state == PlayerTrap.State.EXPIRED and controller.trap_registry.active_count(owner_id) == 0, "both traps expire once at the captured twenty-one-second armed limit")
	controller.queue_free()
	await process_frame

func _snapshot(rank: int, equipped: bool) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "trap-technique-test"
	snapshot.base_class_id = &"archer"
	snapshot.skill_ranks = {&"snare_trap": 1, &"explosive_trap": 1, &"trap_technique": rank}
	snapshot.active_slots = [&"snare_trap", &"explosive_trap", null, null, null]
	snapshot.passive_slots = [&"trap_technique", null] if equipped else [null, null]
	return snapshot

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
