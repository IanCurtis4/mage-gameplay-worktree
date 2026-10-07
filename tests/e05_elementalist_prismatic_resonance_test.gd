extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = 40 # Legal fixture: all purchased evolution entry gates are satisfied.
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"elementalist"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"elementalist")
	snapshot.skill_ranks = {&"elementalist_prismatic_resonance": 1}
	snapshot.passive_slots = [&"elementalist_prismatic_resonance", null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("resonance-test", snapshot))
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	var controller := RunController.new()
	controller.player = player
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	var target_id := enemy.get_instance_id()
	var fire := _request(player, enemy, &"fire_spear")
	var ice := _request(player, enemy, &"ice_spear")
	var lightning := _request(player, enemy, &"lightning")
	var captured_bonus := player.stat_breakdown.value(&"magic_attack") * 0.25
	_check(is_equal_approx(lightning.prismatic_resonance_damage, captured_bonus) and lightning.copy().prismatic_resonance_damage == captured_bonus and lightning.emission_id > 0 and lightning.copy().emission_id == lightning.emission_id, "passive bonus and cast identity captured at commit and copied through projectile")
	controller._on_mage_projectile_hit(fire, enemy)
	controller._on_mage_projectile_hit(fire, enemy)
	_check(not player.elementalist_resonance_ready(target_id, &"lightning"), "same element cannot fill second slot")
	controller._on_mage_projectile_hit(ice, enemy)
	_check(player.elementalist_resonance_ready(target_id, &"lightning") and not player.elementalist_resonance_ready(target_id, &"ice_spear"), "two distinct direct hits prime only missing third element")
	var resolved := controller._elementalist_resonance_request(lightning, enemy)
	_check(is_equal_approx(resolved.magic_damage, lightning.magic_damage + captured_bonus) and lightning.magic_damage == 20.0, "bonus added to copied raw magic before mitigation")
	var secondary := lightning.copy()
	secondary.is_secondary = true
	_check(controller._elementalist_resonance_request(secondary, enemy).magic_damage == 20.0, "secondary hit never receives bonus")
	enemy.health.grant_shield(10000.0)
	controller._on_mage_projectile_hit(lightning, enemy)
	_check(player.elementalist_resonance_ready(target_id, &"lightning"), "fully absorbed third hit preserves sequence")
	enemy.health.clear_shield()
	var hp_before := enemy.health.current_hp
	var expected := CombatMath.resolve(resolved, enemy.health.physical_defense, enemy.health.magic_defense, enemy.health.flee_rating, enemy.health.crit_resistance, 0.0, 1.0)
	controller._on_mage_projectile_hit(lightning, enemy)
	_check(is_equal_approx(hp_before - enemy.health.current_hp, float(expected["damage"])) and player.elementalist_resonance_history.is_empty(), "third positive hit receives mitigated bonus and resets sequence")
	controller._on_mage_projectile_hit(secondary, enemy)
	_check(player.elementalist_resonance_history.is_empty(), "secondary cannot start next sequence")
	controller._on_mage_projectile_hit(fire, enemy)
	player._process(3.0)
	controller._on_mage_projectile_hit(ice, enemy)
	_check(float(player.elementalist_resonance_history[target_id]["remaining"]) == 3.0, "window starts at first hit, not extended by second")
	root.add_child(player)
	paused = true
	player._process(7.0)
	_check(player.elementalist_resonance_ready(target_id, &"lightning"), "pause freezes six-second sequence window")
	paused = false
	player._process(3.1)
	_check(not player.elementalist_resonance_ready(target_id, &"lightning"), "sequence expires in simulation time")
	controller._on_mage_projectile_hit(fire, enemy)
	player.remove_elementalist_target(target_id)
	_check(player.elementalist_resonance_history.is_empty(), "target cleanup removes resonance history")
	snapshot.skill_ranks[&"elementalist_prismatic_resonance"] = 3
	var max_player := PlayerActor.new()
	max_player.configure(nav, RunState.from_build("resonance-r3", snapshot))
	_check(is_equal_approx(_request(max_player, enemy, &"lightning").prismatic_resonance_damage, max_player.stat_breakdown.value(&"magic_attack") * 0.45), "R3 captures correct bonus")
	snapshot.passive_slots = [null, null]
	var inactive := PlayerActor.new()
	inactive.configure(nav, RunState.from_build("resonance-inactive", snapshot))
	_check(is_equal_approx(_request(inactive, enemy, &"lightning").prismatic_resonance_damage, inactive.stat_breakdown.value(&"magic_attack") * 0.45), "learned resonance captures R3 automatically without legacy slots")
	snapshot.skill_ranks.erase(&"elementalist_prismatic_resonance")
	var unlearned := PlayerActor.new()
	unlearned.configure(nav, RunState.from_build("resonance-unlearned", snapshot))
	_check(_request(unlearned, enemy, &"lightning").prismatic_resonance_damage == 0.0, "unlearned passive cannot capture bonus")
	player.free()
	max_player.free()
	inactive.free()
	unlearned.free()
	enemy.free()
	controller.free()
	print("E05 Elementalista Ressonância Prismática: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _request(player: PlayerActor, enemy: CombatActor, skill_id: StringName) -> DamageRequest:
	return player._make_magic_request(enemy, skill_id, 20.0, DamageRequest.AccuracyMode.GEOMETRY, false)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
