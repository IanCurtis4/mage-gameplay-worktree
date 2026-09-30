extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	var definition := ClassCatalog.skill_definition(&"spiritualist_echo_recovery")
	var metadata := catalog.skill_metadata(&"spiritualist_echo_recovery")
	_check(catalog.is_valid() and metadata["rank_requirements"][1]["job_level"] == 23 and metadata["free_rank"] == 0 and metadata["max_purchased_rank"] == 3, "passive unlocks at job 23 with three paid ranks")
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.SPIRITUALIST_ECHO_RECOVERY and definition.category == SkillDefinition.Category.PASSIVE, "passive has typed rank catalog")
	for rank: int in range(1, 4):
		_check(is_equal_approx(definition.rank_definition(rank).power, float(rank + 1)), "R%d returns approved SP" % rank)
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_echo_recovery": 1}
	snapshot.active_slots = [&"spiritualist_echo_curse", null, null, null, null]
	snapshot.passive_slots = [&"spiritualist_echo_recovery", null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("recovery", snapshot))
	player.current_sp = 10.0
	var controller := RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.spiritualist_echo_state.source_id = player.get_instance_id()
	var state := controller.spiritualist_echo_state
	state.mark(101, 0.35)
	controller._on_enemy_damage_resolved(_hit(player.get_instance_id(), 101, 7))
	_check(player.current_sp == 12.0 and state.pending.size() == 1 and player.spiritualist_recovery_cooldown == 1.0, "real mark trigger grants R1 SP once")
	_check(controller.battle_indicators.spiritualist_return_wisps.size() == 1 and controller.battle_indicators.spiritualist_return_wisps[0]["kind"] == &"recovery" and controller.battle_indicators.spiritualist_return_wisps[0]["caster_id"] == player.get_instance_id(), "actual SP return creates one traveling wisp to caster")
	state.mark(102, 0.35)
	controller._on_enemy_damage_resolved(_hit(player.get_instance_id(), 102, 7))
	_check(player.current_sp == 12.0 and state.pending.size() == 2, "same emission may echo another target but cannot refund again")
	player._process(1.1)
	player.current_sp = 12.0
	state.mark(103, 0.35)
	controller._on_enemy_damage_resolved(_hit(player.get_instance_id(), 103, 7))
	_check(player.current_sp == 12.0, "emission remains deduplicated after one-second gate")
	state.mark(104, 0.35)
	controller._on_enemy_damage_resolved(_hit(player.get_instance_id(), 104, 8))
	_check(player.current_sp == 14.0, "new emission refunds after gate")
	player._process(1.1)
	player.current_sp = player.max_sp - 0.5
	state.mark(105, 0.35)
	controller._on_enemy_damage_resolved(_hit(player.get_instance_id(), 105, 9))
	_check(player.current_sp == player.max_sp, "refund caps at maximum SP")
	player._process(1.1)
	state.mark(106, 0.35)
	var visual_count := controller.battle_indicators.spiritualist_return_wisps.size()
	controller._on_enemy_damage_resolved(_hit(player.get_instance_id(), 106, 10))
	_check(controller.battle_indicators.spiritualist_return_wisps.size() == visual_count, "full SP creates no fictional recovery wisp")
	player.current_sp = 10.0
	state.mark(107, 0.35)
	var pending_before_lethal := state.pending.size()
	var lethal := _hit(player.get_instance_id(), 107, 11)
	lethal["killed"] = true
	controller._on_enemy_damage_resolved(lethal)
	_check(player.current_sp == 10.0 and not state.has_mark(107) and state.pending.size() == pending_before_lethal, "lethal trigger cannot create orphan echo or SP refund")
	player.clear_spiritualist_state()
	_check(player.spiritualist_recovery_cooldown == 0.0 and player._spiritualist_refunded_emissions.is_empty(), "encounter cleanup resets gate and emission history")
	var unequipped := snapshot.copy_snapshot()
	unequipped.passive_slots = [null, null]
	var inactive := PlayerActor.new()
	inactive.configure(nav, RunState.from_build("inactive", unequipped))
	inactive.current_sp = 10.0
	_check(inactive.recover_spiritualist_echo_sp(1) == 0.0 and inactive.current_sp == 10.0, "owned but unequipped passive does nothing")
	var ranked := snapshot.copy_snapshot()
	ranked.skill_ranks[&"spiritualist_echo_recovery"] = 3
	var high := PlayerActor.new()
	high.configure(nav, RunState.from_build("rank3", ranked))
	high.current_sp = 10.0
	_check(high.recover_spiritualist_echo_sp(1) == 4.0 and high.current_sp == 14.0, "R3 grants four SP")
	player.free()
	inactive.free()
	high.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Espiritualista Recolhimento: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _hit(source_id: int, target_id: int, emission_id: int) -> Dictionary:
	return {"source_id": source_id, "target_id": target_id, "skill_id": &"basic_attack", "emission_id": emission_id, "can_trigger_effects": true, "actual_damage": 5.0, "killed": false}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
