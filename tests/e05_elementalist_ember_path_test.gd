extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"elementalist"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"elementalist")
	snapshot.skill_ranks = {&"elementalist_ember_path": 1}
	snapshot.active_slots = [&"elementalist_ember_path", null, null, null, null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("ember-test", snapshot))
	player.global_position = Vector2(200, 350)
	root.add_child(player)
	var overlap := _enemy(Vector2(320, 350))
	var third := _enemy(Vector2(440, 350))
	var outside := _enemy(Vector2(440, 430))
	var controller := RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller.enemies = [overlap, third, outside]
	player.elementalist_ember_path_requested.connect(controller._on_elementalist_ember_path_requested)
	var centers := player.elementalist_ember_centers(Vector2.RIGHT)
	_check(centers == [Vector2(280, 350), Vector2(360, 350), Vector2(440, 350)], "three centers at 80/160/240 from frozen origin")
	_check(player.begin_skill_cast(&"elementalist_ember_path", Vector2(600, 350)), "direction cast uses common cast pipeline")
	player.cancel_active_cast()
	_check(player.current_sp == player.max_sp and player.use_elementalist_ember_path(Vector2.RIGHT) and player.current_sp == player.max_sp - 24.0, "cancel free then valid R1 commit spends 24 SP")
	var effect := controller.get_child(0)
	controller.remove_child(effect)
	root.add_child(effect)
	var first_hp := overlap.health.current_hp
	_check(first_hp < 10000.0 and third.health.current_hp == 10000.0, "first circle erupts immediately, third waits")
	paused = true
	effect.call("_process", 1.0)
	_check(third.health.current_hp == 10000.0, "pause freezes delayed eruptions")
	paused = false
	effect.call("_process", 0.15)
	_check(overlap.health.current_hp == first_hp and third.health.current_hp == 10000.0, "overlap is hit at most once per cast")
	player.global_position = Vector2(800, 350)
	effect.call("_process", 0.15)
	_check(third.health.current_hp < 10000.0 and outside.health.current_hp == 10000.0 and effect.is_queued_for_deletion(), "third uses captured origin and radius, sequence terminates")
	player.global_position = Vector2(200, 350)
	nav.configure(Rect2(0, 0, 1000, 700), [Rect2(315, 300, 20, 100)], 20.0)
	_check(player.elementalist_ember_centers(Vector2.RIGHT) == [Vector2(280, 350)], "wall truncates trail before later eruptions")
	nav.configure(Rect2(0, 0, 1000, 700), [Rect2(230, 300, 20, 100)], 20.0)
	player.mage_cooldowns[&"elementalist_ember_path"] = 0.0
	player.current_sp = player.max_sp
	_check(not player.use_elementalist_ember_path(Vector2.RIGHT) and player.current_sp == player.max_sp and player.skill_cooldown(&"elementalist_ember_path") == 0.0, "fully blocked trail fails atomically")
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	player.use_elementalist_ember_path(Vector2.RIGHT)
	var abandoned := controller.get_child(0)
	player.health.current_hp = 0.0
	abandoned.call("_process", 1.0)
	_check(abandoned.is_queued_for_deletion(), "dead caster cancels pending eruptions")
	snapshot.skill_ranks[&"elementalist_ember_path"] = 5
	var max_player := PlayerActor.new()
	max_player.configure(nav, RunState.from_build("ember-r5", snapshot))
	_check(max_player.skill_cost(&"elementalist_ember_path") == 30.0 and max_player.skill_rank_definition(&"elementalist_ember_path").power == 1.58, "R5 captures catalog power and cost")
	player.free()
	max_player.free()
	for enemy: CombatActor in [overlap, third, outside]:
		enemy.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Elementalista Trilha de Brasas: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
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
