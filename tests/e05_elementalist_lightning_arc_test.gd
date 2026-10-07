extends SceneTree

var checks := 0
var failures := 0
var captured: DamageRequest
var hits: Array[Dictionary] = []

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
	snapshot.skill_ranks = {&"elementalist_lightning_arc": 1, &"elementalist_prismatic_focus": 1}
	snapshot.active_slots = [&"elementalist_lightning_arc", null, null, null, null]
	snapshot.passive_slots = [&"elementalist_prismatic_focus", null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("arc-test", snapshot))
	player.global_position = Vector2(200, 350)
	var targets: Array[CombatActor] = [_enemy(Vector2(300, 350)), _enemy(Vector2(390, 350)), _enemy(Vector2(480, 350)), _enemy(Vector2(570, 350))]
	var controller := RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller.enemies = targets
	for enemy: CombatActor in targets:
		enemy.health.damage_applied.connect(_capture_hit)
		enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	player.elementalist_lightning_arc_requested.connect(_capture_request)
	_check(player.begin_skill_cast(&"elementalist_lightning_arc", targets[0].global_position, targets[0]) and player.has_active_cast(), "arc uses cancellable target cast")
	player.cancel_active_cast()
	_check(player.current_sp == player.max_sp, "cancel costs no SP")
	_check(player.use_elementalist_lightning_arc(targets[0]) and player.current_sp == player.max_sp - 22.0 and captured.accuracy_mode == DamageRequest.AccuracyMode.CONTESTED, "runtime commits ranked direct contested request and SP")
	_check(is_equal_approx(captured.magic_damage, player.stat_breakdown.value(&"magic_attack") * 1.10), "primary captures magic power")
	var request := captured.copy()
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	controller._on_elementalist_lightning_arc_requested(request, targets[0], 60.0, 40.0)
	_check(hits.size() == 3 and hits[0]["can_trigger_effects"] and not hits[1]["can_trigger_effects"] and not hits[2]["can_trigger_effects"] and hits[0]["emission_id"] == captured.emission_id and hits[1]["emission_id"] == captured.emission_id, "exactly one direct root and at most two secondary jumps preserve cast identity in results")
	_check(targets[3].health.current_hp == 10000.0 and targets[0].is_electrified() and targets[1].is_electrified(), "chain never repeats or reaches fourth target, positive unmarked hits apply mark")
	_check(controller.battle_indicators.elementalist_pulses.size() == 3 and controller.battle_indicators.elementalist_pulses[0]["center"] == targets[0].global_position and controller.battle_indicators.elementalist_pulses[2]["center"] == targets[2].global_position, "real chain handler preserves all three impact pulses before first rendered frame")
	_check(controller.battle_indicators.elementalist_arc_links.size() == 3 and controller.battle_indicators.elementalist_arc_links[0]["from"] == player.global_position + Vector2(0, -24) and controller.battle_indicators.elementalist_arc_links[2]["to"] == targets[2].global_position + Vector2(0, -18), "real Arc draws caster-to-target and both resolved jumps without replacing ground impacts")
	_check(player.elementalist_focus_history.size() == 1, "secondary jumps cannot feed prism history")
	var first := targets[0]
	first.health.grant_shield(10000.0)
	hits.clear()
	controller._on_elementalist_lightning_arc_requested(request, first, 60.0, 40.0)
	_check(hits.size() == 1 and first.is_electrified(), "absorbed root preserves mark and cannot start chain")
	first.health.clear_shield()
	var before := first.health.current_hp
	controller._apply_elementalist_hit(request, first, &"lightning", 40.0)
	var marked_damage := before - first.health.current_hp
	_check(not first.is_electrified(), "positive marked hit consumes mark once")
	before = first.health.current_hp
	controller._apply_elementalist_hit(request, first, &"lightning", 40.0)
	_check(marked_damage > before - first.health.current_hp and first.is_electrified(), "mark bonus affects damage before mitigation, next hit marks again")
	first.hard_controls.configure(true)
	controller.enemies = [first]
	hits.clear()
	controller._on_elementalist_lightning_arc_requested(request, first, 60.0, 40.0)
	_check(hits.size() == 1 and float(hits[0]["actual_damage"]) > 0.0, "boss alone receives primary without requiring adds")
	for index: int in range(40):
		first.apply_electrified(4.0)
		controller._apply_elementalist_hit(request, first, &"lightning", 40.0)
	_check(first.stun_remaining() <= HardControlState.BOSS_DURATION_CAP and first.hard_controls.boss_budget_remaining >= 0.0, "stun shares boss cap and budget")
	player.mage_cooldowns[&"elementalist_lightning_arc"] = 0.0
	player.current_sp = player.max_sp
	first.global_position = Vector2(900, 350)
	_check(not player.use_elementalist_lightning_arc(first) and player.current_sp == player.max_sp, "invalid initial target is atomic")
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(430, 300, 20, 100)], 20.0)
	controller.enemies = targets
	_check(controller._elementalist_chain_target(Vector2(390, 350), [targets[0].get_instance_id(), targets[1].get_instance_id()]) == null, "chain cannot jump through obstacle")
	player.free()
	for enemy: CombatActor in targets:
		enemy.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Elementalista Arco Voltaico: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _capture_request(request: DamageRequest, _target: CombatActor, _jump: float, _bonus: float) -> void:
	captured = request.copy()

func _capture_hit(result: Dictionary) -> void:
	hits.append(result)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
