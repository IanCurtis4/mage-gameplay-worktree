extends SceneTree

var checks := 0
var failures := 0
var requests: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(510, 300, 40, 100)], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = 40 # Legal fixture: all purchased evolution entry gates are satisfied.
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"elementalist"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"elementalist")
	snapshot.skill_ranks = {&"elementalist_flame_burst": 1}
	snapshot.active_slots = [&"elementalist_flame_burst", null, null, null, null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("flame-test", snapshot))
	player.global_position = Vector2(400, 350)
	var inside := _enemy(Vector2(485, 350))
	var behind_wall := _enemy(Vector2(560, 350))
	var outside := _enemy(Vector2(480, 470))
	var controller := RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(510, 300, 40, 100)], 20.0)
	controller.enemies = [inside, behind_wall, outside]
	player.elementalist_flame_burst_requested.connect(controller._on_elementalist_flame_burst_requested)
	player.elementalist_flame_burst_requested.connect(_on_request)
	_check(player.character_animation.actor_kind == &"elementalist", "evolved Mage uses Elementalist atlas")
	_check(is_equal_approx(player.skill_cast_time(&"elementalist_flame_burst"), StatCalculator.effective_cast_time(0.0, 0.45, player.stat_breakdown)), "R1 cast uses shared DEX formula")
	_check(player.begin_skill_cast(&"elementalist_flame_burst", Vector2(480, 350)) and player.has_active_cast(), "Flame Burst uses cancellable normal cast")
	player.cancel_active_cast()
	_check(player.current_sp == player.max_sp and player.skill_cooldown(&"elementalist_flame_burst") == 0.0, "cancelled cast costs no SP or cooldown")
	_check(player.can_place_elementalist_flame_burst(Vector2(480, 350)) and not player.can_place_elementalist_flame_burst(Vector2(600, 350)), "point placement uses range and blocked-segment validation")
	var sp_before := player.current_sp
	var hp_inside := inside.health.current_hp
	var hp_behind := behind_wall.health.current_hp
	var hp_outside := outside.health.current_hp
	_check(player.use_elementalist_flame_burst(Vector2(480, 350)) and player.current_sp == sp_before - 20.0 and player.skill_cooldown(&"elementalist_flame_burst") > 0.0, "valid commit spends ranked SP and starts cooldown")
	_check(requests.size() == 1 and is_equal_approx(requests[0].magic_damage, player.stat_breakdown.value(&"magic_attack") * 1.30) and not requests[0].is_secondary and requests[0].accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "one direct root request captures R1 magic attack")
	_check(inside.health.current_hp < hp_inside and behind_wall.health.current_hp == hp_behind and outside.health.current_hp == hp_outside, "circle hits only visible overlap, never through wall or outside area")
	player.mage_cooldowns[&"elementalist_flame_burst"] = 0.0
	player.current_sp = player.max_sp
	var sp_blocked := player.current_sp
	_check(not player.use_elementalist_flame_burst(Vector2(600, 350)) and player.current_sp == sp_blocked and player.skill_cooldown(&"elementalist_flame_burst") == 0.0, "blocked location fails atomically")
	var base_snapshot := snapshot.copy_snapshot()
	base_snapshot.evolution_id = &""
	var base_mage := PlayerActor.new()
	base_mage.configure(navigation, RunState.from_build("base-mage", base_snapshot))
	base_mage.global_position = player.global_position
	_check(base_mage.character_animation.actor_kind == &"mage" and not base_mage.use_elementalist_flame_burst(Vector2(480, 350)), "base Mage cannot use exclusive skill or atlas")
	player.free()
	base_mage.free()
	inside.free()
	behind_wall.free()
	outside.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Elementalista Explosão de Chamas: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _on_request(_center: Vector2, request: DamageRequest) -> void:
	requests.append(request.copy())

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
