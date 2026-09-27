extends SceneTree

var checks := 0
var failures := 0
var direct_requests: Array[DamageRequest] = []
var tick_requests: Array[DamageRequest] = []
var results: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(510, 300, 40, 100)], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"berserker"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"berserker")
	snapshot.skill_ranks = {&"berserker_rupture": 1, &"berserker_blood_rift": 1}
	snapshot.active_slots = [&"berserker_rupture", &"berserker_blood_rift", null, null, null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("rift-test", snapshot))
	player.global_position = Vector2(400, 350)
	var front := _enemy(Vector2(470, 350))
	var behind_wall := _enemy(Vector2(560, 350))
	var outside := _enemy(Vector2(470, 405))
	var controller := RunController.new()
	controller.player = player
	player.berserker_rift_hit_requested.connect(controller._on_berserker_rift_hit_requested)
	player.berserker_rift_hit_requested.connect(_on_direct_request)
	for enemy: CombatActor in [front, behind_wall, outside]:
		enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
		enemy.health.damage_applied.connect(_on_damage_applied)
		enemy.status_damage_requested.connect(controller._on_attack_requested)
		enemy.status_damage_requested.connect(_on_tick_request)
	_check(is_equal_approx(player.skill_rank_definition(&"berserker_blood_rift").variable_cast_time, 0.3) and player.skill_cast_time(&"berserker_blood_rift") > 0.0 and player.skill_cast_time(&"berserker_blood_rift") <= 0.3, "R1 Rift has 0.3 s variable preparation before attribute reduction")
	_check(SkillGeometry.strip_contains(Vector2(220, 22), Vector2.RIGHT, SkillGeometry.BERSERKER_RIFT_LENGTH, SkillGeometry.BERSERKER_RIFT_HALF_WIDTH) and not SkillGeometry.strip_contains(Vector2(100, 23), Vector2.RIGHT, SkillGeometry.BERSERKER_RIFT_LENGTH, SkillGeometry.BERSERKER_RIFT_HALF_WIDTH), "shared strip geometry is 220 by 44")
	var indicators := BattleIndicators.new()
	indicators.show_aim(&"berserker_blood_rift", player, Vector2(800, 350), true)
	_check(indicators.endpoint == player.global_position + Vector2.RIGHT * SkillGeometry.BERSERKER_RIFT_LENGTH and indicators.active_range == SkillGeometry.BERSERKER_RIFT_LENGTH, "aim preview uses exact runtime length")
	_check(player.begin_skill_cast(&"berserker_blood_rift", Vector2(800, 350)) and player.has_active_cast(), "Rift enters normal cast lifecycle")
	player.cancel_active_cast()
	_check(not player.has_active_cast() and player.current_sp == player.max_sp, "cancelled preparation spends no resources")
	player.record_berserker_damage({"source_id": player.get_instance_id(), "target_id": front.get_instance_id(), "skill_id": &"berserker_rupture", "can_trigger_effects": true, "actual_damage": 1.0})
	var start_sp := player.current_sp
	_check(player.use_berserker_blood_rift(Vector2.RIGHT, [front, behind_wall, outside]) and player.current_sp < start_sp and player.skill_cooldown(&"berserker_blood_rift") > 0.0, "committed Rift spends SP and starts cooldown")
	_check(direct_requests.size() == 1 and direct_requests[0].target_id == front.get_instance_id() and is_equal_approx(direct_requests[0].physical_damage, player.stat_breakdown.value(&"melee_attack") * 0.90), "one direct hit uses ranked power, excluding wall and outside width")
	_check(player.berserker_wound_stacks(front.get_instance_id()) == 2 and front.bleed_streams.size() == 1 and behind_wall.bleed_streams.is_empty(), "real direct damage adds one existing wound and one bleed stream")
	var stream: Dictionary = front.bleed_streams.values()[0]
	var captured: DamageRequest = stream["request"]
	_check(is_equal_approx(captured.physical_damage, player.stat_breakdown.value(&"melee_attack") * 0.10) and captured.is_secondary and not captured.can_crit and captured.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "R1 bleed captures physical DPS and is secondary without HIT or crit")
	var wound_count := player.berserker_wound_stacks(front.get_instance_id())
	front.advance_statuses(1.0)
	_check(tick_requests.size() == 1 and tick_requests[0].skill_id == &"berserker_blood_rift_tick" and not bool(results[-1].get("can_trigger_effects", true)) and player.berserker_wound_stacks(front.get_instance_id()) == wound_count, "first tick applies damage but cannot add wound or cascade")
	front.advance_statuses(0.5)
	var renewed := captured.copy()
	renewed.physical_damage *= 2.0
	front.apply_bleed(renewed, 4.0)
	_check(front.bleed_streams.size() == 1 and is_equal_approx(float(front.bleed_streams.values()[0]["remaining"]), 4.0), "same owner/skill/target replaces, never stacks, the four-second bleed")
	front.advance_statuses(0.5)
	_check(tick_requests.size() == 2 and is_equal_approx(tick_requests[-1].physical_damage, renewed.physical_damage), "refresh keeps one tick cadence and uses newly captured power")
	var burn := DamageRequest.new()
	burn.source_id = player.get_instance_id()
	burn.magic_damage = 5.0
	front.apply_burn(burn, 3.0)
	front.advance_statuses(1.0)
	_check(front.is_burning() and front.bleed_streams.size() == 1 and tick_requests[-1].skill_id == &"berserker_blood_rift_tick" and tick_requests[-2].skill_id == &"burn_tick", "bleed coexists with the independent burn stream")
	var remaining := float(front.bleed_streams.values()[0]["remaining"])
	front.advance_statuses(1.0, true)
	_check(is_equal_approx(float(front.bleed_streams.values()[0]["remaining"]), remaining), "simulation pause freezes bleed duration and tick")
	front.advance_statuses(5.0)
	_check(front.bleed_streams.is_empty(), "bleed expires after four active seconds")
	player.mage_cooldowns[&"berserker_blood_rift"] = 0.0
	player.current_sp = player.max_sp
	front.health.grant_shield(10000.0)
	_check(player.use_berserker_blood_rift(Vector2.RIGHT, [front]) and front.bleed_streams.is_empty(), "fully absorbed direct Rift does not create bleed")
	front.health.clear_shield()
	player.mage_cooldowns[&"berserker_blood_rift"] = 0.0
	player.current_sp = player.max_sp
	front.health.current_hp = 1.0
	_check(player.use_berserker_blood_rift(Vector2.RIGHT, [front]) and not front.is_alive() and front.bleed_streams.is_empty(), "killing direct hit leaves no bleed on a dead target")
	var extra := _enemy(Vector2(470, 350))
	extra.apply_bleed(captured, 4.0)
	extra.clear_statuses()
	_check(extra.bleed_streams.is_empty(), "encounter cleanup removes bleed state")
	player.free()
	front.free()
	behind_wall.free()
	outside.free()
	extra.free()
	controller.free()
	indicators.free()
	print("E05 Berserker Fenda: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _on_direct_request(request: DamageRequest, _target: CombatActor, _bleed: DamageRequest) -> void:
	direct_requests.append(request)

func _on_tick_request(request: DamageRequest, _target: CombatActor) -> void:
	tick_requests.append(request)

func _on_damage_applied(result: Dictionary) -> void:
	results.append(result)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
