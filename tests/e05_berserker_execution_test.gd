extends SceneTree

var checks := 0
var failures := 0
var attack_roll := 0.0
var self_damage_events := 0
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
	snapshot.skill_ranks = {&"berserker_rupture": 1, &"berserker_execution": 1}
	snapshot.active_slots = [&"berserker_rupture", &"berserker_execution", null, null, null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("execution-test", snapshot))
	player.global_position = Vector2(400, 350)
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = Vector2(470, 350)
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	var controller := RunController.new()
	controller.player = player
	player.attack_requested.connect(_on_attack_requested)
	player.health.damage_applied.connect(_on_self_damage_applied)
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	var target_id := enemy.get_instance_id()
	_check(player.use_berserker_rupture(enemy) and player.berserker_wound_stacks(target_id) == 1, "Rupture creates the first wound stack for Execution")
	_resolve_direct(player, enemy, &"basic_attack")
	_resolve_direct(player, enemy, &"brutal_strike")
	_check(player.berserker_wound_stacks(target_id) == 3, "setup captures three previous stacks")
	var hp_cost := maxf(1.0, ceilf(player.health.max_hp * PlayerActor.BERSERKER_EXECUTION_HP_COST_FRACTION))
	player.current_sp = 0.0
	var hp_before := player.health.current_hp
	_check(not player.use_berserker_execution(enemy) and player.health.current_hp == hp_before and player.berserker_wound_stacks(target_id) == 3 and player.skill_cooldown(&"berserker_execution") == 0.0, "SP failure changes neither HP, cooldown nor wound")
	player.current_sp = player.max_sp
	player.health.current_hp = hp_cost
	var sp_before := player.current_sp
	_check(not player.use_berserker_execution(enemy) and player.health.current_hp == hp_cost and player.current_sp == sp_before and player.berserker_wound_stacks(target_id) == 3, "nonlethal HP gate is atomic")
	player.health.current_hp = player.health.max_hp
	enemy.global_position = Vector2(800, 350)
	_check(not player.use_berserker_execution(enemy) and player.health.current_hp == player.health.max_hp and player.current_sp == sp_before, "invalid range spends no HP or SP")
	enemy.global_position = Vector2(470, 350)
	var before_requests := requests.size()
	_check(player.use_berserker_execution(enemy) and requests.size() == before_requests + 1 and player.health.current_hp == player.health.max_hp - hp_cost and self_damage_events == 0, "valid commit charges HP exactly once without damage events and emits one request")
	var expected_power := player.stat_breakdown.value(&"melee_attack") * (1.20 + 3.0 * 0.40)
	_check(is_equal_approx(requests[-1].physical_damage, expected_power) and not requests[-1].is_secondary and player.berserker_wound_stacks(target_id) == 0, "three prior stacks join the single direct hit and are consumed after positive HP damage")
	player.mage_cooldowns[&"berserker_execution"] = 0.0
	player.current_sp = player.max_sp
	player.health.current_hp = player.health.max_hp
	enemy.health.current_hp = enemy.health.max_hp * 0.35
	_check(player.use_berserker_execution(enemy) and is_equal_approx(requests[-1].physical_damage, player.stat_breakdown.value(&"melee_attack") * 1.20 * 1.20), "inclusive 35% pre-impact target HP grants bonus even without wound")
	enemy.health.current_hp = enemy.health.max_hp
	player.mage_cooldowns[&"berserker_rupture"] = 0.0
	player.current_sp = player.max_sp
	_check(player.use_berserker_rupture(enemy) and player.berserker_wound_stacks(target_id) == 1, "new wound can be opened for miss and shield cases")
	player.mage_cooldowns[&"berserker_execution"] = 0.0
	player.current_sp = player.max_sp
	attack_roll = 1.0
	_check(player.use_berserker_execution(enemy) and player.berserker_wound_stacks(target_id) == 1, "missed Execution keeps previous wound")
	player.mage_cooldowns[&"berserker_execution"] = 0.0
	player.current_sp = player.max_sp
	attack_roll = 0.0
	enemy.health.grant_shield(10000.0)
	_check(player.use_berserker_execution(enemy) and player.berserker_wound_stacks(target_id) == 1, "fully absorbed Execution keeps previous wound")
	enemy.health.clear_shield()
	player.mage_cooldowns[&"berserker_execution"] = 0.0
	player.current_sp = player.max_sp
	_check(player.use_berserker_execution(enemy) and player.berserker_wound_stacks(target_id) == 0, "next positive Execution consumes the wound once")
	player.free()
	enemy.free()
	controller.free()
	print("E05 Berserker Execução: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _on_attack_requested(request: DamageRequest, target: CombatActor) -> void:
	requests.append(request)
	results.append(target.health.apply(request, attack_roll, 1.0))

func _on_self_damage_applied(_result: Dictionary) -> void:
	self_damage_events += 1

func _resolve_direct(player: PlayerActor, target: CombatActor, skill_id: StringName) -> void:
	var request := DamageRequest.new()
	request.source_id = player.get_instance_id()
	request.target_id = target.get_instance_id()
	request.skill_id = skill_id
	request.physical_damage = 20.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	results.append(target.health.apply(request, 0.0, 1.0))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
