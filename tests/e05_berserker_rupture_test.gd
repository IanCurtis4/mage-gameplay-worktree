extends SceneTree

var checks := 0
var failures := 0
var attack_roll := 0.0
var requests: Array[DamageRequest] = []
var results: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"berserker"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"berserker")
	snapshot.skill_ranks = {&"berserker_rupture": 1}
	snapshot.active_slots = [&"berserker_rupture", null, null, null, null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("rupture-test", snapshot))
	player.global_position = Vector2(400, 350)
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = Vector2(470, 350)
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	var controller := RunController.new()
	controller.player = player
	controller.enemies = [enemy]
	player.attack_requested.connect(_on_attack_requested)
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	_check(player.use_berserker_rupture(enemy) and requests.size() == 1 and not requests[0].is_secondary and player.berserker_wound_stacks(enemy.get_instance_id()) == 1, "first direct Rupture creates exactly one wound stack after real HP damage")
	controller._sync_berserker_wound_visuals()
	_check(enemy.berserker_wound_visual_stacks == 1 and is_equal_approx(enemy.berserker_wound_visual_remaining, PlayerActor.BERSERKER_WOUND_DURATION), "wound indicator exposes a count and expiry for the first charge")
	_check(player.skill_cooldown(&"berserker_rupture") > 0.0 and player.current_sp < player.max_sp, "valid Rupture commit spends SP and starts cooldown")
	_resolve_direct(player, enemy, &"basic_attack", false, 0.0)
	_check(player.berserker_wound_stacks(enemy.get_instance_id()) == 2, "direct melee adds exactly one wound stack")
	_resolve_direct(player, enemy, &"brutal_strike", false, 0.0)
	_resolve_direct(player, enemy, &"concentrated_rage", false, 0.0)
	_check(player.berserker_wound_stacks(enemy.get_instance_id()) == 3, "wound stacks cap at three across direct melee attacks")
	controller._sync_berserker_wound_visuals()
	_check(enemy.berserker_wound_visual_stacks == 3, "indicator has three discrete marks at the wound cap")
	_resolve_direct(player, enemy, &"basic_attack", false, 1.0)
	_resolve_direct(player, enemy, &"basic_attack", true, 0.0)
	_check(player.berserker_wound_stacks(enemy.get_instance_id()) == 3, "misses and secondary damage cannot add wound stacks")
	player.mage_cooldowns[&"berserker_rupture"] = 0.0
	attack_roll = 1.0
	var previous_sp := player.current_sp
	_check(player.use_berserker_rupture(enemy) and requests[-1].is_secondary and requests[-1].accuracy_mode == DamageRequest.AccuracyMode.CONTESTED and player.current_sp < previous_sp and player.berserker_wound_stacks(enemy.get_instance_id()) == 3, "missed detonation spends committed resources but preserves mark and stacks")
	player.mage_cooldowns[&"berserker_rupture"] = 0.0
	attack_roll = 0.0
	player.current_sp = player.max_sp
	enemy.health.grant_shield(10000.0)
	_check(player.use_berserker_rupture(enemy) and player.berserker_wound_stacks(enemy.get_instance_id()) == 3, "fully absorbed detonation preserves wound")
	enemy.health.clear_shield()
	player.mage_cooldowns[&"berserker_rupture"] = 0.0
	player.current_sp = player.max_sp
	_check(player.use_berserker_rupture(enemy) and player.berserker_wound_stacks(enemy.get_instance_id()) == 0 and not results[-1]["can_trigger_effects"], "positive secondary detonation consumes wound once without proc cascade")
	var sp_after := player.current_sp
	var cooldown_after := player.skill_cooldown(&"berserker_rupture")
	enemy.global_position = Vector2(800, 350)
	_check(not player.use_berserker_rupture(enemy) and player.current_sp == sp_after and player.skill_cooldown(&"berserker_rupture") == cooldown_after, "out-of-range failure spends no resources")
	enemy.global_position = Vector2(470, 350)
	player.mage_cooldowns[&"berserker_rupture"] = 0.0
	player.current_sp = player.max_sp
	_check(player.use_berserker_rupture(enemy) and player.berserker_wound_stacks(enemy.get_instance_id()) == 1, "Rupture can create a new wound after detonation")
	root.add_child(player)
	paused = true
	player._process(PlayerActor.BERSERKER_WOUND_DURATION + 0.1)
	_check(player.berserker_wound_stacks(enemy.get_instance_id()) == 1, "pause freezes the wound deadline")
	paused = false
	player._process(PlayerActor.BERSERKER_WOUND_DURATION + 0.1)
	_check(player.berserker_wound_stacks(enemy.get_instance_id()) == 0, "wound expires on simulation time")
	controller._sync_berserker_wound_visuals()
	_check(enemy.berserker_wound_visual_stacks == 0 and enemy.berserker_wound_visual_remaining == 0.0, "expired wound clears its visual indicator")
	player.clear_berserker_state()
	_check(player.berserker_wounds.is_empty(), "encounter/run cleanup removes all wounds")
	player.free()
	enemy.free()
	controller.free()
	print("E05 Berserker Ruptura: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _on_attack_requested(request: DamageRequest, target: CombatActor) -> void:
	requests.append(request)
	results.append(target.health.apply(request, attack_roll, 1.0))

func _resolve_direct(player: PlayerActor, target: CombatActor, skill_id: StringName, secondary: bool, roll: float) -> void:
	var request := DamageRequest.new()
	request.source_id = player.get_instance_id()
	request.target_id = target.get_instance_id()
	request.skill_id = skill_id
	request.physical_damage = 20.0
	request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
	request.is_secondary = secondary
	results.append(target.health.apply(request, roll, 1.0))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
