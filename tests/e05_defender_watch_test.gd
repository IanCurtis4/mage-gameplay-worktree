extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"defender"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"defender")
	snapshot.skill_ranks = {&"defender_counterstroke": 1, &"defender_watch": 1, &"brutal_strike": 1, &"concentrated_rage": 1}
	snapshot.active_slots = [&"brutal_strike", &"concentrated_rage", null, null, null]
	snapshot.passive_slots = [&"defender_watch", null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("watch-equipped", snapshot))
	player.global_position = Vector2(300, 350)
	root.add_child(player)
	player.set_process(false)
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 50}), 18.0)
	enemy.global_position = Vector2(380, 350)
	root.add_child(enemy)
	enemy.set_process(false)
	var controller := RunController.new()
	controller.player = player
	controller.rng.seed = 11
	player.attack_requested.connect(controller._on_attack_requested)
	player.brutal_strike_requested.connect(controller._on_brutal_strike_requested)
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	var before_hp := enemy.health.current_hp
	_check(player.use_brutal_strike(enemy) and enemy.health.current_hp < before_hp and is_equal_approx(enemy.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT), 0.08), "Brutal Strike direct HP damage triggers equipped Watch")
	enemy.clear_statuses()
	enemy.health.current_hp = enemy.health.max_hp
	player.current_sp = player.max_sp
	_check(player.use_concentrated_rage(Vector2.RIGHT, [enemy]) and enemy.health.current_hp < enemy.health.max_hp and is_equal_approx(enemy.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT), 0.08), "Concentrated Rage direct HP damage triggers equipped Watch")
	enemy.clear_statuses()
	enemy.health.current_hp = enemy.health.max_hp
	var inactive_snapshot := snapshot.copy_snapshot()
	inactive_snapshot.passive_slots = [null, null]
	var inactive_player := PlayerActor.new()
	inactive_player.configure(nav, RunState.from_build("watch-unequipped", inactive_snapshot))
	inactive_player.global_position = Vector2(300, 350)
	root.add_child(inactive_player)
	inactive_player.set_process(false)
	controller.player = inactive_player
	inactive_player.attack_requested.connect(controller._on_attack_requested)
	_check(inactive_player.use_concentrated_rage(Vector2.RIGHT, [enemy]) and enemy.health.current_hp < enemy.health.max_hp and enemy.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0, "learned but unequipped Watch never applies")
	controller.player = player
	enemy.clear_statuses()
	enemy.health.current_hp = enemy.health.max_hp
	var request := DamageRequest.new()
	request.source_id = player.get_instance_id()
	request.target_id = enemy.get_instance_id()
	request.skill_id = &"brutal_strike"
	request.physical_damage = 10.0
	request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
	var missed := enemy.health.apply(request, 1.0, 1.0)
	_check(not missed["landed"] and enemy.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0, "miss cannot trigger Watch")
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	enemy.health.shield_hp = 100.0
	var absorbed := enemy.health.apply(request, 0.0, 1.0)
	_check(absorbed["actual_damage"] == 0.0 and enemy.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0, "shield-only Brutal Strike cannot trigger Watch")
	enemy.health.shield_hp = 0.0
	request.skill_id = &"concentrated_rage"
	request.is_secondary = true
	var secondary := enemy.health.apply(request, 0.0, 1.0)
	_check(secondary["actual_damage"] > 0.0 and enemy.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0, "secondary Concentrated Rage cannot trigger Watch")
	request.is_secondary = false
	request.skill_id = &"piercing_shout"
	var shout := enemy.health.apply(request, 0.0, 1.0)
	_check(shout["actual_damage"] > 0.0 and enemy.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0, "direct shout is not a melee Watch trigger")
	player.queue_free()
	inactive_player.queue_free()
	enemy.queue_free()
	controller.free()
	await process_frame
	print("E05 Defendente Vigília: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
