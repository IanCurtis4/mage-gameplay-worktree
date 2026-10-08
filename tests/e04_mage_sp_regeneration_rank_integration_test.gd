extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table()
	_check_ranked_sources_and_stats()
	_check_preview_runtime_and_regeneration()
	print("E04 Regeneração de SP por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table() -> void:
	var definition := ClassCatalog.skill_definition(&"mage_mana_regeneration")
	var expected_increases: Array[float] = [0.50, 0.75, 1.00]
	_check(definition != null and definition.category == SkillDefinition.Category.PASSIVE and definition.handler_id == SkillDefinition.Handler.MAGE_SP_REGENERATION and definition.is_rank_catalog_valid(), "Regeneração de SP exposes a valid passive rank catalog and closed handler")
	for rank: int in range(1, 4):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_increases[rank - 1] and values.effect_ids == [&"sp_regen_increased"], "Regeneração de SP R%d owns its approved magnitude" % rank)
		_check(values.sp_cost == 0.0 and values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0 and values.cooldown == 0.0 and values.range == 0.0 and values.projectile_speed == 0.0, "Regeneração de SP R%d adds no active execution parameter" % rank)
		_check(values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.magic_weight == 0.0, "Regeneração de SP R%d adds no damage weight" % rank)
	var copied_rank := definition.rank_definition(3)
	copied_rank.power = 9.0
	_check(definition.rank_definition(3).power == 1.0, "passive rank lookup returns an isolated catalog copy")

func _check_ranked_sources_and_stats() -> void:
	var expected_regeneration: Array[float] = [4.92, 5.74, 6.56]
	var expected_increases: Array[float] = [0.50, 0.75, 1.00]
	for rank: int in range(1, 4):
		var snapshot := _snapshot(rank, true)
		var sources := snapshot.intrinsic_modifier_sources()
		var stats := snapshot.stat_breakdown()
		_check(sources.size() == 1 and sources[0]["source_id"] == &"passive_mage_sp_regeneration" and sources[0]["increased"][&"sp_regen"] == expected_increases[rank - 1], "R%d emits one identified modifier source with its authored magnitude" % rank)
		_check(is_equal_approx(stats.value(&"sp_regen"), expected_regeneration[rank - 1]) and stats.value(&"max_sp") == 85.0 and stats.value(&"magic_attack") == 31.3, "R%d changes only canonical SP regeneration among its adjacent mage stats" % rank)
	var composed := _snapshot(3, true).stat_breakdown([{
		"source_id": &"test_regeneration",
		"increased": {&"sp_regen": 0.25},
	}])
	_check(is_equal_approx(composed.value(&"sp_regen"), 7.38), "passive rank composes additively inside StatCalculator instead of multiplying in the snapshot")
	var duplicate_slots := _snapshot(3, true)
	duplicate_slots.passive_slots = [&"mage_mana_regeneration", &"mage_mana_regeneration"]
	_check(duplicate_slots.intrinsic_modifier_sources().size() == 1 and is_equal_approx(duplicate_slots.stat_breakdown().value(&"sp_regen"), 6.56), "duplicate passive slots cannot apply the same identified source twice")
	var unequipped := _snapshot(3, false)
	_check(unequipped.intrinsic_modifier_sources().size() == 1 and is_equal_approx(unequipped.stat_breakdown().value(&"sp_regen"), 6.56), "learned passive is automatic despite empty legacy slots")
	var unlearned := _snapshot(3, false)
	unlearned.skill_ranks.erase(&"mage_mana_regeneration")
	_check(unlearned.intrinsic_modifier_sources().is_empty() and is_equal_approx(unlearned.stat_breakdown().value(&"sp_regen"), 3.28), "unlearned passive applies no source")
	var invalid := _snapshot(4, true)
	_check(invalid.intrinsic_modifier_sources().is_empty() and is_equal_approx(invalid.stat_breakdown().value(&"sp_regen"), 3.28), "invalid passive rank is ineligible instead of falling back to R1")

func _check_preview_runtime_and_regeneration() -> void:
	var snapshot := _snapshot(3, true)
	var preview := snapshot.stat_breakdown()
	var state := RunState.from_build("mage-sp-regen-r3", snapshot)
	snapshot.skill_ranks[&"mage_mana_regeneration"] = 1
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 800), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, state)
	root.add_child(player)
	_check(is_equal_approx(preview.value(&"sp_regen"), 6.56) and is_equal_approx(player.stat_breakdown.value(&"sp_regen"), 6.56), "preview, copied run snapshot and runtime actor consume the same R3 regeneration")
	player.current_sp = 10.0
	_check(player._regenerate_sp(1.0, false) and is_equal_approx(player.current_sp, 16.56), "living unpaused actor regenerates exactly one second from the canonical breakdown")
	var before_pause := player.current_sp
	_check(not player._regenerate_sp(1.0, true) and player.current_sp == before_pause, "paused simulation does not regenerate SP")
	player.current_sp = player.max_sp - 1.0
	_check(player._regenerate_sp(1.0, false) and player.current_sp == player.max_sp, "regeneration remains clamped to max SP")
	player.current_sp = 10.0
	player.health.current_hp = 0.0
	_check(not player._regenerate_sp(1.0, false) and player.current_sp == 10.0, "dead actor does not regenerate SP")
	player.queue_free()

func _snapshot(rank: int, equipped: bool) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "mage-sp-regeneration-test"
	snapshot.base_class_id = &"mage"
	snapshot.job_level = 20
	snapshot.skill_ranks = {&"mage_mana_regeneration": rank}
	snapshot.passive_slots = [&"mage_mana_regeneration", null] if equipped else [null, null]
	return snapshot

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
