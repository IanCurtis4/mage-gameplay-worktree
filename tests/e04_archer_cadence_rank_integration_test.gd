extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table_and_progression()
	_check_ranked_sources_and_stats()
	_check_preview_runtime_and_auto_interval()
	print("E04 Cadência por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table_and_progression() -> void:
	var definition := ClassCatalog.skill_definition(&"archer_cadence")
	var expected_increases: Array[float] = [0.10, 0.15, 0.20]
	_check(definition != null and definition.display_name == "Cadência" and definition.category == SkillDefinition.Category.PASSIVE and definition.handler_id == SkillDefinition.Handler.ARCHER_CADENCE and definition.is_rank_catalog_valid(), "Cadência exposes a valid passive rank catalog and closed handler")
	for rank: int in range(1, 4):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_increases[rank - 1] and values.effect_ids == [&"attacks_per_second_increased"], "Cadência R%d owns its approved APS increase" % rank)
		_check(values.sp_cost == 0.0 and values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0 and values.cooldown == 0.0 and values.range == 0.0 and values.projectile_speed == 0.0, "Cadência R%d adds no active execution parameter" % rank)
		_check(values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.magic_weight == 0.0, "Cadência R%d adds no damage weight" % rank)
	var copied_rank := definition.rank_definition(3)
	copied_rank.power = 9.0
	_check(definition.rank_definition(3).power == 0.20, "passive rank lookup returns an isolated catalog copy")
	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"archer_cadence")
	var initial_slots := catalog.initial_skill_slots(&"archer")
	_check(metadata.get("category") == ProfileCatalog.PASSIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 3, "profile progression publishes Cadência as three purchased base-job ranks")
	_check(catalog.base_class_is_available(&"archer") and initial_slots["passive_slots"] == [null, null] and ClassCatalog.class_definition(&"archer").passive_id == &"archer_precision", "Cadência preserves the open Archer gate, empty persistent slots and Precision as the legacy pilot default")

func _check_ranked_sources_and_stats() -> void:
	var expected_aps: Array[float] = [1.2705, 1.32825, 1.386]
	var expected_increases: Array[float] = [0.10, 0.15, 0.20]
	for rank: int in range(1, 4):
		var snapshot := _snapshot(rank, true)
		var sources := snapshot.intrinsic_modifier_sources()
		var stats := snapshot.stat_breakdown()
		_check(sources.size() == 1 and sources[0]["source_id"] == &"passive_archer_cadence" and sources[0]["increased"][&"attacks_per_second"] == expected_increases[rank - 1], "R%d emits one identified increased-APS source with its authored magnitude" % rank)
		_check(is_equal_approx(stats.value(&"attacks_per_second"), expected_aps[rank - 1]) and is_equal_approx(stats.value(&"attack_speed_index"), expected_aps[rank - 1] * 100.0), "R%d drives APS and its derived display index from the same effective value" % rank)
		_check(is_equal_approx(stats.value(&"precision_attack"), 31.2) and is_equal_approx(stats.value(&"hit_rating"), 121.6) and is_equal_approx(stats.value(&"flee_rating"), 112.1) and is_equal_approx(stats.value(&"crit_chance"), 0.064), "R%d changes no adjacent Archer offense or evasion stat" % rank)
	var rhythm_state := RunState.from_build("cadence-battle-rhythm", _snapshot(3, true))
	rhythm_state.augment_stacks[&"battle_rhythm"] = 1
	var composed := rhythm_state.build_snapshot.stat_breakdown(rhythm_state.stat_modifier_sources())
	_check(is_equal_approx(composed.value(&"attacks_per_second"), 1.55925), "Cadência and Battle Rhythm compose additively before one APS multiplication")
	var dual_passives := _snapshot(3, true)
	dual_passives.skill_ranks[&"archer_precision"] = 3
	dual_passives.passive_slots = [&"archer_precision", &"archer_cadence"]
	_check(dual_passives.intrinsic_modifier_sources().size() == 2 and is_equal_approx(dual_passives.stat_breakdown().value(&"hit_rating"), 137.6) and is_equal_approx(dual_passives.stat_breakdown().value(&"attacks_per_second"), 1.386), "Precision and Cadence coexist independently in the two passive slots")
	var duplicate_slots := _snapshot(3, true)
	duplicate_slots.passive_slots = [&"archer_cadence", &"archer_cadence"]
	_check(duplicate_slots.intrinsic_modifier_sources().size() == 1 and is_equal_approx(duplicate_slots.stat_breakdown().value(&"attacks_per_second"), 1.386), "duplicate passive slots cannot apply Cadência twice")
	var unequipped := _snapshot(3, false)
	_check(unequipped.intrinsic_modifier_sources().is_empty() and is_equal_approx(unequipped.stat_breakdown().value(&"attacks_per_second"), 1.155), "learned but unequipped Cadência applies no source")
	var invalid := _snapshot(4, true)
	_check(invalid.intrinsic_modifier_sources().is_empty() and is_equal_approx(invalid.stat_breakdown().value(&"attacks_per_second"), 1.155), "invalid passive rank is ineligible instead of falling back to R1")

func _check_preview_runtime_and_auto_interval() -> void:
	var rank_one_source := _snapshot(1, true)
	var rank_one_state := RunState.from_build("archer-cadence-r1", rank_one_source)
	rank_one_source.skill_ranks[&"archer_cadence"] = 3
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 800), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, rank_one_state)
	player.position = Vector2(100, 200)
	root.add_child(player)
	player.set_process(false)
	var target := CombatActor.new()
	target.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 19.0)
	target.position = Vector2(300, 200)
	root.add_child(target)
	target.set_process(false)
	var requests: Array[DamageRequest] = []
	player.precision_projectile_requested.connect(func(_skill_id: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int, _hit_limit: int) -> void: requests.append(request))
	_check(is_equal_approx(rank_one_state.build_snapshot.stat_breakdown().value(&"attacks_per_second"), 1.2705) and is_equal_approx(player.stat_breakdown.value(&"attacks_per_second"), 1.2705), "preview, copied run snapshot and runtime actor consume the same R1 cadence")
	player.pursue(target)
	player._process(0.01)
	var armed_r1 := player.attack_cooldown
	_check(requests.size() == 1 and is_equal_approx(armed_r1, 1.0 / 1.2705), "R1 auto emission arms exactly the reciprocal canonical APS interval")
	_check(is_equal_approx(requests[0].physical_damage, 31.2) and is_equal_approx(requests[0].hit_rating, 121.6) and is_equal_approx(requests[0].crit_chance, 0.064), "Cadência changes the auto interval without changing captured damage, HIT or critical chance")
	var rank_three_state := RunState.from_build("archer-cadence-r3", _snapshot(3, true))
	player.apply_run_modifiers(rank_three_state)
	_check(is_equal_approx(player.stat_breakdown.value(&"attacks_per_second"), 1.386) and player.attack_cooldown == armed_r1, "changing effective APS preserves an auto cooldown already in progress")
	player.attack_cooldown = 0.0
	player._try_basic_attack()
	_check(requests.size() == 2 and is_equal_approx(player.attack_cooldown, 1.0 / 1.386), "the next auto after recalculation uses the new R3 reciprocal interval")
	player.queue_free()
	target.queue_free()

func _snapshot(rank: int, equipped: bool) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "archer-cadence-test"
	snapshot.base_class_id = &"archer"
	snapshot.skill_ranks = {&"archer_cadence": rank}
	snapshot.passive_slots = [&"archer_cadence", null] if equipped else [null, null]
	return snapshot

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
