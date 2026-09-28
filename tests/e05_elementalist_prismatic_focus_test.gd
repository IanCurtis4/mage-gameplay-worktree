extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"elementalist"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"elementalist")
	snapshot.skill_ranks = {&"elementalist_prismatic_focus": 1}
	snapshot.passive_slots = [&"elementalist_prismatic_focus", null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("focus-test", snapshot))
	player.current_sp = 10.0
	var actor_id := player.get_instance_id()
	player.record_elementalist_damage(_hit(actor_id, 101, &"fire_spear"))
	_check(player.current_sp == 10.0, "first element does not refund")
	player.record_elementalist_damage(_hit(actor_id, 102, &"ice_spear"))
	player.record_elementalist_damage(_hit(actor_id, 101, &"fireball"))
	_check(player.current_sp == 10.0, "same element or other target does not refund")
	player.record_elementalist_damage(_hit(actor_id, 101, &"ice_spear"))
	_check(player.current_sp == 12.0 and player.elementalist_focus_cooldown == 1.0, "alternation on same target refunds R1 once")
	player.record_elementalist_damage(_hit(actor_id, 101, &"lightning"))
	_check(player.current_sp == 12.0, "one-second player gate blocks repeated refund")
	player._process(1.0)
	player.current_sp = 12.0
	player.record_elementalist_damage(_hit(actor_id, 101, &"elementalist_flame_burst"))
	_check(player.current_sp == 14.0, "new alternation after gate refunds again")
	var sp_before := player.current_sp
	var secondary := _hit(actor_id, 101, &"ice_spear")
	secondary["can_trigger_effects"] = false
	player.record_elementalist_damage(secondary)
	var zero := _hit(actor_id, 101, &"ice_spear")
	zero["actual_damage"] = 0.0
	player.record_elementalist_damage(zero)
	player.record_elementalist_damage(_hit(999, 101, &"ice_spear"))
	_check(is_equal_approx(player.current_sp, sp_before), "secondary, zero damage and other source cannot refund")
	player._process(5.1)
	player.current_sp = sp_before
	player.record_elementalist_damage(_hit(actor_id, 101, &"lightning"))
	_check(player.current_sp == sp_before, "expired history starts new sequence")
	player.remove_elementalist_target(101)
	_check(not player.elementalist_focus_history.has(101), "dead target history removed")
	player.clear_elementalist_state()
	_check(player.elementalist_focus_history.is_empty() and player.elementalist_focus_cooldown == 0.0, "encounter cleanup clears state")
	player.current_sp = player.max_sp - 1.0
	player.record_elementalist_damage(_hit(actor_id, 101, &"fire_spear"))
	player.record_elementalist_damage(_hit(actor_id, 101, &"ice_spear"))
	_check(player.current_sp == player.max_sp, "refund respects max SP")
	root.add_child(player)
	paused = true
	player._process(6.0)
	_check(player.elementalist_focus_cooldown == 1.0 and player.elementalist_focus_history.has(101), "pause freezes both timers")
	paused = false
	player.clear_elementalist_state()
	player.current_sp = 10.0
	player.record_elementalist_damage(_hit(actor_id, 101, &"fire_spear", 1))
	player.record_elementalist_damage(_hit(actor_id, 101, &"ice_spear", 10))
	player._process(1.2)
	player.current_sp = 20.0
	player.record_elementalist_damage(_hit(actor_id, 202, &"fire_spear", 2))
	player.record_elementalist_damage(_hit(actor_id, 202, &"ice_spear", 10))
	_check(player.current_sp == 20.0, "late hit from same emission cannot refund again after cooldown")
	player.record_elementalist_damage(_hit(actor_id, 202, &"lightning", 11))
	_check(player.current_sp == 22.0, "new emission can refund after player cooldown")
	var unequipped := snapshot.copy_snapshot()
	unequipped.passive_slots = [null, null]
	var inactive := PlayerActor.new()
	inactive.configure(navigation, RunState.from_build("focus-inactive", unequipped))
	inactive.current_sp = 10.0
	inactive.record_elementalist_damage(_hit(inactive.get_instance_id(), 101, &"fire_spear"))
	inactive.record_elementalist_damage(_hit(inactive.get_instance_id(), 101, &"ice_spear"))
	_check(inactive.current_sp == 10.0, "un-equipped passive has no effect")
	var capped := snapshot.copy_snapshot()
	capped.skill_ranks[&"elementalist_prismatic_focus"] = 3
	var ranked := PlayerActor.new()
	ranked.configure(navigation, RunState.from_build("focus-r3", capped))
	ranked.current_sp = 10.0
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	var controller := RunController.new()
	controller.player = ranked
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	for skill_id: StringName in [&"fire_spear", &"ice_spear"]:
		var request := DamageRequest.new()
		request.source_id = ranked.get_instance_id()
		request.target_id = enemy.get_instance_id()
		request.skill_id = skill_id
		request.magic_damage = 20.0
		request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		enemy.health.apply(request, 0.0, 1.0)
	_check(ranked.current_sp == 14.0, "real damage callback grants R3 refund of four SP")
	player.free()
	inactive.free()
	ranked.free()
	enemy.free()
	controller.free()
	print("E05 Elementalista Foco Prismático: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _hit(source_id: int, target_id: int, skill_id: StringName, emission_id: int = 0) -> Dictionary:
	return {"source_id": source_id, "target_id": target_id, "skill_id": skill_id, "emission_id": emission_id, "can_trigger_effects": true, "actual_damage": 1.0}

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
