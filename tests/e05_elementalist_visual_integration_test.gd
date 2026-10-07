extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = 40 # Legal fixture: all purchased evolution entry gates are satisfied.
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"elementalist"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"elementalist")
	snapshot.skill_ranks = {&"elementalist_prismatic_focus": 1, &"elementalist_prismatic_resonance": 1}
	snapshot.passive_slots = [&"elementalist_prismatic_focus", &"elementalist_prismatic_resonance"]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("visual-integration", snapshot))
	player.current_sp = 10.0
	var target := CombatActor.new()
	target.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	target.global_position = Vector2(300, 350)
	var controller := RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller._on_enemy_damage_resolved(_hit(player, target, &"fire_spear"))
	_check(controller.battle_indicators.elementalist_prisms.is_empty(), "first element has no fake passive proc")
	controller._on_enemy_damage_resolved(_hit(player, target, &"ice_spear"))
	var feedback := controller.battle_indicators.elementalist_prisms
	_check(player.current_sp == 12.0 and feedback.size() == 1 and feedback[0]["skill_id"] == &"elementalist_prismatic_focus" and feedback[0]["center"] == player.global_position, "actual Focus refund acknowledges the caster")
	controller._on_enemy_damage_resolved(_hit(player, target, &"lightning"))
	_check(feedback.size() == 2 and feedback[1]["skill_id"] == &"elementalist_prismatic_resonance" and feedback[1]["center"] == target.global_position, "third distinct positive element acknowledges Resonance on the target")
	var secondary := _hit(player, target, &"fire_spear")
	secondary["can_trigger_effects"] = false
	controller._on_enemy_damage_resolved(secondary)
	var zero := _hit(player, target, &"ice_spear")
	zero["actual_damage"] = 0.0
	controller._on_enemy_damage_resolved(zero)
	_check(feedback.size() == 2, "secondary and zero hits never display false passives")
	player.clear_elementalist_state()
	player.current_sp = player.max_sp
	controller._on_enemy_damage_resolved(_hit(player, target, &"fire_spear"))
	controller._on_enemy_damage_resolved(_hit(player, target, &"ice_spear"))
	_check(feedback.size() == 2, "capped SP displays no nonexistent refund")
	player.run_state.build_snapshot.passive_slots = [null, null]
	controller._on_enemy_damage_resolved(_hit(player, target, &"lightning"))
	_check(feedback.size() == 3 and feedback[2]["skill_id"] == &"elementalist_prismatic_resonance", "learned resonance remains automatic after clearing legacy equipped slots")
	player.run_state.build_snapshot.skill_ranks.erase(&"elementalist_prismatic_focus")
	player.run_state.build_snapshot.skill_ranks.erase(&"elementalist_prismatic_resonance")
	player.clear_elementalist_state()
	for skill_id: StringName in [&"fire_spear", &"ice_spear", &"lightning"]:
		controller._on_enemy_damage_resolved(_hit(player, target, skill_id))
	_check(feedback.size() == 3, "unlearned passives produce no feedback")
	player.free()
	target.free()
	controller.battle_indicators.free()
	controller.free()
	print("Elementalista integração visual: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _hit(player: PlayerActor, target: CombatActor, skill_id: StringName) -> Dictionary:
	return {"source_id": player.get_instance_id(), "target_id": target.get_instance_id(), "skill_id": skill_id, "actual_damage": 10.0, "can_trigger_effects": true}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
