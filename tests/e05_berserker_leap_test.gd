extends SceneTree

var checks := 0
var failures := 0
var attack_roll := 0.0
var requests: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(510, 300, 40, 100)], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"berserker"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"berserker")
	snapshot.skill_ranks = {&"berserker_rupture": 1, &"berserker_wound_leap": 1, &"dash": 1}
	snapshot.active_slots = [&"berserker_wound_leap", &"dash", null, null, null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("leap-test", snapshot))
	player.global_position = Vector2(400, 350)
	var front := _enemy(Vector2(460, 350))
	var behind_wall := _enemy(Vector2(560, 350))
	var controller := RunController.new()
	controller.player = player
	player.attack_requested.connect(_on_attack_requested)
	front.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	behind_wall.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	var endpoint := player.berserker_wound_leap_destination(Vector2.RIGHT)
	_check(endpoint.x > player.global_position.x and endpoint.x < 510.0 and navigation.is_segment_walkable(player.global_position, endpoint), "Leap destination stops before the obstacle on a safe navigation segment")
	var indicators := BattleIndicators.new()
	indicators.show_aim(&"berserker_wound_leap", player, Vector2(800, 350), true)
	_check(indicators.endpoint == endpoint and indicators.active_range == 140.0, "preview uses the same navigation-cleared endpoint and rank range")
	var wound_result := {"source_id": player.get_instance_id(), "target_id": front.get_instance_id(), "skill_id": &"berserker_rupture", "can_trigger_effects": true, "actual_damage": 1.0}
	player.record_berserker_damage(wound_result)
	_check(player.berserker_wound_stacks(front.get_instance_id()) == 1, "existing wound is present before mobility hit")
	var start_sp := player.current_sp
	_check(player.use_berserker_wound_leap(Vector2.RIGHT, [behind_wall, front]) and player.current_sp < start_sp and player._dash_active, "valid offensive Leap commits SP and starts movement")
	player._process(0.20)
	_check(requests.size() == 1 and requests[0].skill_id == &"berserker_wound_leap" and requests[0].target_id == front.get_instance_id() and not player._dash_active, "Leap emits one direct hit on the reachable target, not through the wall")
	_check(player.berserker_wound_stacks(front.get_instance_id()) == 2 and player.berserker_wound_stacks(behind_wall.get_instance_id()) == 0, "positive Leap adds only the common one wound stack")
	player.global_position = Vector2(400, 350)
	player.mage_cooldowns[&"berserker_wound_leap"] = 0.0
	player.current_sp = player.max_sp
	attack_roll = 1.0
	_check(player.use_berserker_wound_leap(Vector2.RIGHT, [front]) and player._dash_active, "miss case still starts a valid Leap")
	player._process(0.20)
	_check(requests.size() == 2 and player.berserker_wound_stacks(front.get_instance_id()) == 2, "missed Leap adds no wound charge")
	player.global_position = Vector2(400, 350)
	player.mage_cooldowns[&"berserker_wound_leap"] = 0.0
	player.current_sp = player.max_sp
	var before_empty := requests.size()
	_check(player.use_berserker_wound_leap(Vector2.RIGHT, []) and player._dash_active, "empty Leap keeps valid mobility")
	player._process(0.20)
	_check(requests.size() == before_empty and player.berserker_wound_stacks(front.get_instance_id()) == 2, "empty Leap creates no request or wound")
	player.global_position = endpoint
	player.mage_cooldowns[&"berserker_wound_leap"] = 0.0
	player.current_sp = player.max_sp
	var before_blocked_sp := player.current_sp
	_check(not player.use_berserker_wound_leap(Vector2.RIGHT, [front]) and player.current_sp == before_blocked_sp and player.skill_cooldown(&"berserker_wound_leap") == 0.0, "fully blocked Leap fails before spending resources")
	player.global_position = Vector2(400, 350)
	player.current_sp = player.max_sp
	_check(player.use_berserker_wound_leap(Vector2.RIGHT, [front]) and player.use_dash(Vector2.LEFT) and not player._berserker_leap_active, "base Dash replacement clears pending Leap hit state")
	var after_cancel := requests.size()
	player._process(0.20)
	_check(requests.size() == after_cancel, "interrupted Leap cannot emit a late hit")
	player.mage_cooldowns[&"berserker_wound_leap"] = 0.0
	player.current_sp = player.max_sp
	_check(player.use_berserker_wound_leap(Vector2.RIGHT, []) and player._dash_active, "new Leap starts before cleanup")
	player.clear_berserker_state()
	_check(not player._dash_active and player.berserker_wounds.is_empty(), "encounter cleanup cancels Leap and its transient wounds")
	player.free()
	front.free()
	behind_wall.free()
	controller.free()
	indicators.free()
	print("E05 Berserker Salto: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _on_attack_requested(request: DamageRequest, target: CombatActor) -> void:
	requests.append(request)
	target.health.apply(request, attack_roll, 1.0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
