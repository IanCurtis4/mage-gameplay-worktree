extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := _player(navigation, 1, true, true)
	var target_id := 101
	player.current_sp = 10.0
	player.record_berserker_damage(_result(player, target_id, &"berserker_rupture", true))
	_check(player.berserker_wound_stacks(target_id) == 1 and player.current_sp == 10.0, "first hit creates wound without Pursuit SP")
	player.record_berserker_damage(_result(player, target_id, &"basic_attack", true))
	_check(player.berserker_wound_stacks(target_id) == 2 and player.current_sp == 12.0 and player.berserker_pursuit_cooldown == 1.0, "first later direct melee hit grants R1 SP once")
	player.record_berserker_damage(_result(player, target_id, &"brutal_strike", true))
	_check(player.berserker_wound_stacks(target_id) == 3 and player.current_sp == 12.0, "second hit inside one-second player window adds wound but not SP")
	player.record_berserker_damage(_result(player, target_id, &"basic_attack", false))
	player.record_berserker_damage(_result(player, target_id, &"berserker_blood_rift", false))
	_check(player.current_sp == 12.0 and player.berserker_wound_stacks(target_id) == 3, "miss and secondary tick cannot grant SP or another charge")
	root.add_child(player)
	paused = true
	player._process(2.0)
	_check(player.berserker_pursuit_cooldown == 1.0, "pause freezes Pursuit internal cooldown")
	paused = false
	player._process(1.01)
	player.current_sp = 10.0
	player.record_berserker_damage(_result(player, target_id, &"berserker_execution", true))
	_check(player.current_sp == 12.0 and player.berserker_wound_stacks(target_id) == 0, "positive direct Execution on a pre-wounded target grants SP before consuming wound")
	player.record_berserker_damage(_result(player, target_id, &"basic_attack", true))
	_check(player.current_sp == 12.0 and player.berserker_wound_stacks(target_id) == 0, "ordinary hit after wound consumption grants no SP or free mark")
	player.clear_berserker_state()
	_check(player.berserker_pursuit_cooldown == 0.0 and player.berserker_wounds.is_empty(), "encounter cleanup clears mark and cooldown")
	player.free()
	var unequipped := _player(navigation, 3, false, true)
	unequipped.current_sp = 10.0
	unequipped.record_berserker_damage(_result(unequipped, target_id, &"berserker_rupture", true))
	unequipped.record_berserker_damage(_result(unequipped, target_id, &"basic_attack", true))
	_check(unequipped.current_sp == 14.0 and unequipped.berserker_wound_stacks(target_id) == 2, "learned Pursuit automatically returns R3 SP without legacy passive slots")
	unequipped.free()
	var unlearned := _player(navigation, 0, false, true)
	unlearned.current_sp = 10.0
	unlearned.record_berserker_damage(_result(unlearned, target_id, &"berserker_rupture", true))
	unlearned.record_berserker_damage(_result(unlearned, target_id, &"basic_attack", true))
	_check(unlearned.current_sp == 10.0, "unlearned Pursuit grants no SP")
	unlearned.free()
	var rank_three := _player(navigation, 3, true, true)
	rank_three.current_sp = 10.0
	rank_three.record_berserker_damage(_result(rank_three, target_id, &"berserker_rupture", true))
	rank_three.record_berserker_damage(_result(rank_three, target_id, &"berserker_wound_leap", true))
	_check(rank_three.current_sp == 14.0 and rank_three.berserker_wound_stacks(target_id) == 2, "R3 returns approved four SP and Leap adds only one charge")
	rank_three.free()
	var no_entry := _player(navigation, 3, true, false)
	no_entry.current_sp = 10.0
	no_entry.record_berserker_damage(_result(no_entry, target_id, &"berserker_rupture", true))
	no_entry.record_berserker_damage(_result(no_entry, target_id, &"basic_attack", true))
	_check(no_entry.berserker_wound_stacks(target_id) == 0 and no_entry.current_sp == 10.0, "Pursuit without learned Rupture cannot invent a mark")
	no_entry.free()
	print("E05 Berserker Caça: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _player(navigation: ArenaNavigation, pursuit_rank: int, equipped: bool, learned_rupture: bool) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"berserker"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"berserker")
	snapshot.skill_ranks = {&"berserker_pursuit": pursuit_rank}
	if learned_rupture:
		snapshot.skill_ranks[&"berserker_rupture"] = 1
	snapshot.passive_slots = [&"berserker_pursuit" if equipped else null, null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("pursuit-test", snapshot))
	return player

func _result(player: PlayerActor, target_id: int, skill_id: StringName, direct: bool) -> Dictionary:
	return {"source_id": player.get_instance_id(), "target_id": target_id, "skill_id": skill_id, "can_trigger_effects": direct, "actual_damage": 12.0}

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
