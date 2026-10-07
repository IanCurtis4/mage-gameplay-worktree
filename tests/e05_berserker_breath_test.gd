extends SceneTree

var checks := 0
var failures := 0
var requests: Array[DamageRequest] = []
var results: Array[Dictionary] = []
var force_hits := true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(510, 300, 40, 100)], 20.0)
	var snapshot := _snapshot(1)
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("breath-test", snapshot))
	player.global_position = Vector2(400, 350)
	var enemy := _enemy(Vector2(470, 350))
	var controller := RunController.new()
	controller.player = player
	player.berserker_breath_hit_requested.connect(_force_hit_for_healing_checks)
	player.berserker_breath_hit_requested.connect(controller._on_berserker_breath_hit_requested)
	player.berserker_breath_hit_requested.connect(_on_breath_request)
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	enemy.health.damage_applied.connect(_on_damage_applied)
	player.health.current_hp = player.health.max_hp - 100.0
	var hp_before := player.health.current_hp
	_check(player.use_berserker_breath_steal(enemy) and requests.size() == 1 and results[-1]["actual_damage"] > 0.0 and player.health.current_hp == hp_before, "unmarked target takes direct hit but gives no healing")
	_check(player.berserker_wound_stacks(enemy.get_instance_id()) == 0 and player.skill_cooldown(&"berserker_breath_steal") > 0.0, "Breath alone cannot create first wound and spends its cooldown")
	player.record_berserker_damage({"source_id": player.get_instance_id(), "target_id": enemy.get_instance_id(), "skill_id": &"berserker_rupture", "can_trigger_effects": true, "actual_damage": 1.0})
	_check(player.berserker_wound_stacks(enemy.get_instance_id()) == 1, "Rupture establishes a prior wound")
	player.mage_cooldowns[&"berserker_breath_steal"] = 0.0
	player.current_sp = player.max_sp
	var previous_hp := player.health.current_hp
	_check(player.use_berserker_breath_steal(enemy) and requests.size() == 2 and is_equal_approx(requests[-1].physical_damage, player.stat_breakdown.value(&"melee_attack") * 1.0), "R1 Breath emits one ranked direct melee request")
	var expected_heal := minf(minf(float(results[-1]["actual_damage"]) * 0.15, player.health.max_hp * 0.05), player.health.max_hp - previous_hp)
	_check(is_equal_approx(player.health.current_hp, previous_hp + expected_heal) and expected_heal > 0.0 and player.berserker_wound_stacks(enemy.get_instance_id()) == 2, "surviving wounded target heals from real HP damage, capped per cast, and gains one wound stack")
	player.mage_cooldowns[&"berserker_breath_steal"] = 0.0
	player.current_sp = 0.0
	var before_count := requests.size()
	var before_hp := player.health.current_hp
	_check(not player.use_berserker_breath_steal(enemy) and requests.size() == before_count and player.health.current_hp == before_hp and player.skill_cooldown(&"berserker_breath_steal") == 0.0, "insufficient SP fails atomically")
	player.current_sp = player.max_sp
	enemy.global_position = Vector2(800, 350)
	_check(not player.use_berserker_breath_steal(enemy) and requests.size() == before_count and player.current_sp == player.max_sp, "out-of-range failure spends nothing")
	enemy.global_position = Vector2(560, 350)
	_check(not player.use_berserker_breath_steal(enemy) and player.current_sp == player.max_sp, "melee Breath does not pass through a wall")
	enemy.global_position = Vector2(470, 350)
	enemy.health.flee_rating = 1000000.0
	force_hits = false
	player.berserker_breath_hit_requested.disconnect(controller._on_berserker_breath_hit_requested)
	player.berserker_breath_hit_requested.connect(_resolve_forced_miss)
	_check(player.use_berserker_breath_steal(enemy) and not bool(results[-1]["landed"]) and player.health.current_hp == before_hp and player.berserker_wound_stacks(enemy.get_instance_id()) == 2, "missed Breath gives no heal or wound")
	player.berserker_breath_hit_requested.disconnect(_resolve_forced_miss)
	player.berserker_breath_hit_requested.connect(controller._on_berserker_breath_hit_requested)
	force_hits = true
	enemy.health.flee_rating = 0.0
	player.mage_cooldowns[&"berserker_breath_steal"] = 0.0
	player.current_sp = player.max_sp
	enemy.health.grant_shield(10000.0)
	_check(player.use_berserker_breath_steal(enemy) and float(results[-1]["actual_damage"]) == 0.0 and player.health.current_hp == before_hp, "fully absorbed Breath gives no heal")
	enemy.health.clear_shield()
	player.mage_cooldowns[&"berserker_breath_steal"] = 0.0
	player.current_sp = player.max_sp
	enemy.health.current_hp = 1.0
	var kill_hp_before := player.health.current_hp
	_check(player.use_berserker_breath_steal(enemy) and bool(results[-1]["killed"]) and is_equal_approx(player.health.current_hp, kill_hp_before + player.health.max_hp * ClassCatalog.blood_thirst_heal_fraction(1)), "killing hit grants only Blood Thirst kill healing, never Breath healing")
	var synthetic := {"source_id": player.get_instance_id(), "skill_id": &"berserker_breath_steal", "can_trigger_effects": true, "actual_damage": 10000.0, "killed": false}
	player.health.current_hp = player.health.max_hp - 100.0
	_check(is_equal_approx(player.heal_from_berserker_breath_steal(synthetic, 0.27), player.health.max_hp * 0.05), "one cast cannot heal above five percent of maximum HP")
	player.health.current_hp = player.health.max_hp - 1.0
	_check(is_equal_approx(player.heal_from_berserker_breath_steal(synthetic, 0.27), 1.0) and player.health.current_hp == player.health.max_hp, "healing also respects missing HP")
	var zero_snapshot := _snapshot(0)
	var zero_player := PlayerActor.new()
	zero_player.configure(navigation, RunState.from_build("breath-r0", zero_snapshot))
	zero_player.global_position = Vector2(400, 350)
	var zero_enemy := _enemy(Vector2(470, 350))
	_check(not zero_player.use_berserker_breath_steal(zero_enemy), "R0 cannot use the skill")
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, RunState.from_build("breath-r5", _snapshot(5)))
	rank_five.global_position = Vector2(400, 350)
	var rank_five_enemy := _enemy(Vector2(470, 350))
	var rank_five_controller := RunController.new()
	rank_five_controller.player = rank_five
	rank_five.berserker_breath_hit_requested.connect(_force_hit_for_healing_checks)
	rank_five.berserker_breath_hit_requested.connect(rank_five_controller._on_berserker_breath_hit_requested)
	rank_five.berserker_breath_hit_requested.connect(_on_breath_request)
	rank_five_enemy.health.damage_applied.connect(rank_five_controller._on_enemy_damage_resolved)
	rank_five_enemy.health.damage_applied.connect(_on_damage_applied)
	rank_five.record_berserker_damage({"source_id": rank_five.get_instance_id(), "target_id": rank_five_enemy.get_instance_id(), "skill_id": &"berserker_rupture", "can_trigger_effects": true, "actual_damage": 1.0})
	rank_five.health.current_hp = rank_five.health.max_hp - 100.0
	var r5_before := rank_five.health.current_hp
	_check(rank_five.use_berserker_breath_steal(rank_five_enemy) and is_equal_approx(requests[-1].physical_damage, rank_five.stat_breakdown.value(&"melee_attack") * 1.30), "R5 direct weight is 1.30 times melee attack")
	var r5_expected := minf(minf(float(results[-1]["actual_damage"]) * 0.27, rank_five.health.max_hp * 0.05), rank_five.health.max_hp - r5_before)
	_check(is_equal_approx(rank_five.health.current_hp, r5_before + r5_expected) and r5_expected > 0.0, "R5 healing is 27 percent of real damage under the cap")
	player.free()
	enemy.free()
	controller.free()
	zero_player.free()
	zero_enemy.free()
	rank_five.free()
	rank_five_enemy.free()
	rank_five_controller.free()
	print("E05 Berserker Arrancar Fôlego: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"berserker"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"berserker")
	snapshot.skill_ranks = {&"berserker_rupture": 1, &"berserker_breath_steal": rank, &"blood_thirst": 1}
	snapshot.active_slots = [&"berserker_rupture", &"berserker_breath_steal", null, null, null]
	snapshot.passive_slots = [&"blood_thirst", null]
	return snapshot

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _on_breath_request(request: DamageRequest, _target: CombatActor, _fraction: float, _marked: bool) -> void:
	requests.append(request)

func _force_hit_for_healing_checks(request: DamageRequest, _target: CombatActor, _fraction: float, _marked: bool) -> void:
	if force_hits:
		request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		request.can_crit = false

func _resolve_forced_miss(request: DamageRequest, target: CombatActor, _fraction: float, _marked: bool) -> void:
	target.health.apply(request, 1.0, 1.0)

func _on_damage_applied(result: Dictionary) -> void:
	results.append(result)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
