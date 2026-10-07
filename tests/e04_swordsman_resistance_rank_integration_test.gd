extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table()
	_check_ranked_sources_and_stats()
	_check_preview_runtime_and_mitigation()
	print("E04 Resistência por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table() -> void:
	var definition := ClassCatalog.skill_definition(&"swordsman_resistance")
	var expected_increases: Array[float] = [0.50, 0.75, 1.00]
	_check(definition != null and definition.category == SkillDefinition.Category.PASSIVE and definition.handler_id == SkillDefinition.Handler.SWORDSMAN_RESISTANCE and definition.is_rank_catalog_valid(), "Resistência exposes a valid passive rank catalog and closed handler")
	for rank: int in range(1, 4):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_increases[rank - 1] and values.effect_ids == [&"physical_defense_increased"], "Resistência R%d owns its approved physical defense magnitude" % rank)
		_check(values.sp_cost == 0.0 and values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0 and values.cooldown == 0.0 and values.range == 0.0 and values.projectile_speed == 0.0, "Resistência R%d adds no active execution parameter" % rank)
		_check(values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.magic_weight == 0.0, "Resistência R%d adds no damage weight" % rank)
	var copied_rank := definition.rank_definition(3)
	copied_rank.power = 9.0
	_check(definition.rank_definition(3).power == 1.0, "passive rank lookup returns an isolated catalog copy")

func _check_ranked_sources_and_stats() -> void:
	var expected_defenses: Array[float] = [30.0, 35.0, 40.0]
	for rank: int in range(1, 4):
		var snapshot := _snapshot(rank, true)
		var sources := snapshot.intrinsic_modifier_sources()
		var stats := snapshot.stat_breakdown()
		_check(sources.size() == 1 and sources[0]["source_id"] == &"passive_swordsman_resistance" and sources[0]["increased"][&"physical_defense"] == [0.50, 0.75, 1.00][rank - 1], "R%d emits one identified modifier source with its authored magnitude" % rank)
		_check(stats.value(&"physical_defense") == expected_defenses[rank - 1] and stats.value(&"magic_defense") == 8.0, "R%d changes only canonical physical defense" % rank)
	var composed := _snapshot(3, true).stat_breakdown([{
		"source_id": &"test_armor",
		"increased": {&"physical_defense": 0.25},
	}])
	_check(composed.value(&"physical_defense") == 45.0, "passive rank composes additively inside StatCalculator instead of multiplying in the snapshot")
	var unequipped := _snapshot(3, false)
	_check(unequipped.intrinsic_modifier_sources().size() == 1 and unequipped.stat_breakdown().value(&"physical_defense") == 40.0, "learned passive is automatic despite empty legacy slots")
	var unlearned := _snapshot(3, false)
	unlearned.skill_ranks.erase(&"swordsman_resistance")
	_check(unlearned.intrinsic_modifier_sources().is_empty() and unlearned.stat_breakdown().value(&"physical_defense") == 20.0, "unlearned passive applies no source")
	var invalid := _snapshot(4, true)
	_check(invalid.intrinsic_modifier_sources().is_empty() and invalid.stat_breakdown().value(&"physical_defense") == 20.0, "invalid passive rank is ineligible instead of falling back to R1")

func _check_preview_runtime_and_mitigation() -> void:
	var snapshot := _snapshot(3, true)
	var preview := snapshot.stat_breakdown()
	var state := RunState.from_build("resistance-r3", snapshot)
	snapshot.skill_ranks[&"swordsman_resistance"] = 1
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 800), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, state)
	root.add_child(player)
	_check(preview.value(&"physical_defense") == 40.0 and player.stat_breakdown.value(&"physical_defense") == 40.0 and player.health.physical_defense == 40.0, "preview, copied run snapshot and runtime health consume the same R3 defense")
	var rank_one_stats := _snapshot(1, true).stat_breakdown()
	var physical := DamageRequest.new()
	physical.physical_damage = 100.0
	physical.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var magic := DamageRequest.new()
	magic.magic_damage = 100.0
	magic.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var physical_r1 := CombatMath.resolve(physical, rank_one_stats.value(&"physical_defense"), rank_one_stats.value(&"magic_defense"), 0.0, 0.0, 0.0, 0.0)
	var physical_r3 := CombatMath.resolve(physical, preview.value(&"physical_defense"), preview.value(&"magic_defense"), 0.0, 0.0, 0.0, 0.0)
	var magic_r1 := CombatMath.resolve(magic, rank_one_stats.value(&"physical_defense"), rank_one_stats.value(&"magic_defense"), 0.0, 0.0, 0.0, 0.0)
	var magic_r3 := CombatMath.resolve(magic, preview.value(&"physical_defense"), preview.value(&"magic_defense"), 0.0, 0.0, 0.0, 0.0)
	_check(physical_r1["damage"] == 77 and physical_r3["damage"] == 71, "R1 and R3 mitigate physical damage through CombatMath at their canonical defense")
	_check(magic_r1["damage"] == 93 and magic_r3["damage"] == 93, "passive ranks do not change magic mitigation")
	player.queue_free()

func _snapshot(rank: int, equipped: bool) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "resistance-test"
	snapshot.base_class_id = &"swordsman"
	snapshot.job_level = 20
	snapshot.skill_ranks = {&"swordsman_resistance": rank}
	snapshot.passive_slots = [&"swordsman_resistance", null] if equipped else [null, null]
	return snapshot

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
