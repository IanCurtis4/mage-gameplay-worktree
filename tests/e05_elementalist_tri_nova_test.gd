extends SceneTree

var checks := 0
var failures := 0
var requests: Array[DamageRequest] = []
var results: Array[Dictionary] = []

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
	snapshot.skill_ranks = {&"elementalist_tri_nova": 1, &"elementalist_prismatic_focus": 1, &"elementalist_prismatic_resonance": 1}
	snapshot.active_slots = [&"elementalist_tri_nova", null, null, null, null]
	snapshot.passive_slots = [&"elementalist_prismatic_focus", &"elementalist_prismatic_resonance"]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("nova-test", snapshot))
	player.global_position = Vector2(300, 350)
	root.add_child(player)
	var enemy := _enemy(Vector2(420, 350))
	var outside := _enemy(Vector2(490, 350))
	var controller := RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller.enemies = [enemy, outside]
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	enemy.health.damage_applied.connect(_capture_result)
	player.elementalist_tri_nova_requested.connect(_capture_requests)
	player.elementalist_tri_nova_requested.connect(controller._on_elementalist_tri_nova_requested)
	_check(player.begin_skill_cast(&"elementalist_tri_nova", player.global_position) and player.has_active_cast(), "nova uses shared cancellable cast")
	player.cancel_active_cast()
	_check(player.current_sp == player.max_sp and player.use_elementalist_tri_nova() and player.current_sp == player.max_sp - 30.0, "cancel free, valid R1 costs 30 SP")
	var magic := player.stat_breakdown.value(&"magic_attack")
	_check(requests.size() == 3 and is_equal_approx(requests[0].magic_damage, magic * 0.70) and is_equal_approx(requests[1].magic_damage, magic * 0.55) and is_equal_approx(requests[2].magic_damage, magic * 0.60), "three components capture fire ice lightning powers")
	_check(not requests[0].is_secondary and requests[1].is_secondary and requests[2].is_secondary, "only fire pulse is root")
	_check(results.size() == 1 and enemy.slow_remaining == 0.0 and not enemy.is_electrified(), "fire pulse immediate and damage-only")
	var effect := controller.get_child(0)
	controller.remove_child(effect)
	root.add_child(effect)
	paused = true
	effect.call("_process", 1.0)
	_check(results.size() == 1, "pause freezes delayed nova pulses")
	paused = false
	player.global_position = Vector2(800, 350)
	effect.call("_process", 0.25)
	_check(results.size() == 2 and not results[1]["can_trigger_effects"] and enemy.slow_fraction == 0.40, "ice pulse after 0.25 at captured center applies slow but cannot proc")
	effect.call("_process", 0.25)
	_check(results.size() == 3 and not results[2]["can_trigger_effects"] and enemy.is_electrified() and effect.is_queued_for_deletion(), "lightning at 0.50 applies mark and terminates")
	_check(player.current_sp == player.max_sp - 30.0 and player.elementalist_resonance_history[enemy.get_instance_id()]["elements"] == [&"fire"], "nova cannot self-trigger prism refund or third-element bonus")
	_check(outside.health.current_hp == 10000.0, "radial radius excludes outside target")
	snapshot.skill_ranks[&"elementalist_tri_nova"] = 5
	var max_player := PlayerActor.new()
	max_player.configure(nav, RunState.from_build("nova-r5", snapshot))
	_check(max_player.skill_cost(&"elementalist_tri_nova") == 36.0 and max_player.skill_rank_definition(&"elementalist_tri_nova").power == 1.01, "R5 catalog power and cost captured")
	snapshot.skill_ranks[&"elementalist_tri_nova"] = 0
	var zero := PlayerActor.new()
	zero.configure(nav, RunState.from_build("nova-r0", snapshot))
	_check(not zero.use_elementalist_tri_nova() and zero.current_sp == zero.max_sp, "R0 cannot spend or emit")
	player.free()
	max_player.free()
	zero.free()
	enemy.free()
	outside.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Elementalista Nova Tríplice: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _capture_requests(_center: Vector2, captured: Array[DamageRequest], _bonus: float) -> void:
	requests = captured

func _capture_result(result: Dictionary) -> void:
	results.append(result)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
