extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [Rect2(510, 300, 20, 100)], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"elementalist"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"elementalist")
	snapshot.skill_ranks = {&"elementalist_glacial_ring": 1}
	snapshot.active_slots = [&"elementalist_glacial_ring", null, null, null, null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("ring-test", snapshot))
	player.global_position = Vector2(400, 350)
	var inside := _enemy(Vector2(470, 350))
	var blocked := _enemy(Vector2(540, 350))
	var outside := _enemy(Vector2(400, 520))
	var absorbed := _enemy(Vector2(400, 450))
	absorbed.health.grant_shield(10000.0)
	var controller := RunController.new()
	controller.player = player
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(510, 300, 20, 100)], 20.0)
	controller.battle_indicators = BattleIndicators.new()
	controller.enemies = [inside, blocked, outside, absorbed]
	player.elementalist_area_requested.connect(controller._on_elementalist_area_requested)
	_check(player.begin_skill_cast(&"elementalist_glacial_ring", player.global_position) and player.has_active_cast(), "radial self skill uses shared cast")
	player.cancel_active_cast()
	_check(player.current_sp == player.max_sp and player.skill_cooldown(&"elementalist_glacial_ring") == 0.0, "cancel is free")
	var before := inside.health.current_hp
	_check(player.use_elementalist_glacial_ring() and player.current_sp == player.max_sp - 19.0, "rank one costs 19 SP")
	_check(inside.health.current_hp < before and inside.slow_fraction == 0.40 and inside.slow_remaining == 2.5, "positive visible hit guarantees 40 percent slow")
	_check(blocked.health.current_hp == 10000.0 and outside.health.current_hp == 10000.0 and blocked.slow_remaining == 0.0, "radius and obstacle exclude hits")
	_check(absorbed.health.current_hp == 10000.0 and absorbed.slow_remaining == 0.0, "fully absorbed damage cannot apply slow")
	inside.apply_slow(0.40, 3.0, &"other_slow")
	_check(inside.slow_fraction <= 0.50, "shared slow cap preserved")
	root.add_child(inside)
	paused = true
	inside._process(3.0)
	_check(inside.slow_remaining == 3.0, "pause freezes slow")
	paused = false
	inside._process(3.1)
	_check(inside.slow_remaining == 0.0, "slow expires in simulation time")
	var max_snapshot := snapshot.copy_snapshot()
	max_snapshot.skill_ranks[&"elementalist_glacial_ring"] = 5
	var max_player := PlayerActor.new()
	max_player.configure(nav, RunState.from_build("ring-r5", max_snapshot))
	_check(max_player.skill_cost(&"elementalist_glacial_ring") == 25.0 and max_player.skill_rank_definition(&"elementalist_glacial_ring").power == 1.38, "R5 runtime captures rank cost and power")
	snapshot.skill_ranks[&"elementalist_glacial_ring"] = 0
	var zero := PlayerActor.new()
	zero.configure(nav, RunState.from_build("ring-r0", snapshot))
	_check(not zero.use_elementalist_glacial_ring() and zero.current_sp == zero.max_sp, "R0 cannot cast or spend")
	player.free()
	max_player.free()
	zero.free()
	for enemy: CombatActor in [inside, blocked, outside, absorbed]:
		enemy.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Elementalista Anel Glacial: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
