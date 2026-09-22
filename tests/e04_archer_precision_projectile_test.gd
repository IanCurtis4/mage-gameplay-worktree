extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_minimal_catalog_and_gate()
	_check_archer_basic_emission()
	_check_shared_projectile_collision()
	await _check_controller_wiring()
	print("E04 Arqueiro projétil de precisão: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_minimal_catalog_and_gate() -> void:
	var definition := ClassCatalog.class_definition(&"archer")
	_check(definition != null and definition.display_name == "Arqueiro" and definition.attributes == IdentityIds.initial_attributes(&"archer"), "catalog exposes the accepted Archer identity and attributes")
	_check(definition.skill_ids == [&"double_shot", &"piercing_arrow"] and definition.passive_id.is_empty() and definition.basic_power == 1.0 and definition.basic_range == 340.0, "Archer definition preserves basic tuning while exposing both delivered skills")
	var state := RunState.new(&"archer")
	_check(state.class_id == &"archer" and state.skill_levels == {&"double_shot": 1, &"piercing_arrow": 1} and state.build_snapshot.active_slots == [&"double_shot", &"piercing_arrow"] and state.build_snapshot.passive_slots.is_empty(), "pilot run equips both delivered Archer skills")
	_check(not ProfileCatalog.pilot().base_class_is_available(&"archer"), "persistent profile keeps Archer unavailable before two active skills and one passive")

func _check_archer_basic_emission() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 600), [], 20.0)
	var archer := PlayerActor.new()
	archer.configure(navigation, RunState.new(&"archer"))
	archer.position = Vector2(100, 200)
	root.add_child(archer)
	archer.set_process(false)
	var target := _target(Vector2(400, 200))
	var emitted: Array[DamageRequest] = []
	var emitted_targets: Array[CombatActor] = []
	var directions: Array[Vector2] = []
	var immediate_hits := [0]
	archer.precision_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, target_actor: CombatActor, direction: Vector2, _count: int, _hit_limit: int) -> void:
		emitted.append(request)
		emitted_targets.append(target_actor)
		directions.append(direction)
	)
	archer.attack_requested.connect(func(_request: DamageRequest, _target_actor: CombatActor) -> void: immediate_hits[0] += 1)
	archer.pursue(target)
	archer._process(0.01)
	_check(emitted.size() == 1 and emitted_targets == [target] and immediate_hits[0] == 0, "Archer basic emits one projectile request instead of applying an immediate melee hit")
	var request := emitted[0]
	_check(is_equal_approx(request.physical_damage, archer.stat_breakdown.value(&"precision_attack")) and request.physical_damage != archer.stat_breakdown.value(&"melee_attack") and request.magic_damage == 0.0, "basic damage snapshots precision attack as physical damage without melee or magic scaling")
	_check(request.accuracy_mode == DamageRequest.AccuracyMode.CONTESTED and request.can_crit and request.hit_rating == archer.stat_breakdown.value(&"hit_rating"), "basic request preserves canonical contested HIT and critical data")
	_check(directions == [Vector2.RIGHT] and is_equal_approx(archer.attack_cooldown, 1.0 / archer.stat_breakdown.value(&"attacks_per_second")), "emission captures fixed direction and canonical attack cadence")
	_check(archer.basic_attack_distance(target) == archer.collision_radius + target.collision_radius + 340.0 and PlayerActor.ARCHER_BASIC_SPEED == 880.0 and PlayerActor.ARCHER_BASIC_MAX_DISTANCE == 520.0, "runtime exposes the approved engagement range, projectile speed and maximum distance")
	archer.queue_free()
	target.queue_free()

func _check_shared_projectile_collision() -> void:
	var open_navigation := ArenaNavigation.new()
	open_navigation.configure(Rect2(0, 0, 900, 500), [], 4.0)
	var near_target := _target(Vector2(280, 100))
	var far_target := _target(Vector2(420, 100))
	var first_hit: Array[CombatActor] = []
	var projectile := PlayerProjectile.new()
	projectile.configure_directional(_request(), Vector2(100, 82), Vector2.RIGHT, [far_target, near_target], open_navigation, 880.0, 520.0)
	projectile.hit.connect(func(_request_value: DamageRequest, actor: CombatActor) -> void: first_hit.append(actor))
	root.add_child(projectile)
	projectile._process(1.0)
	_check(first_hit == [near_target] and projectile.request.target_id == near_target.get_instance_id() and projectile.is_queued_for_deletion(), "directional projectile resolves only the nearest first impact and captures its target id")

	var blocked_navigation := ArenaNavigation.new()
	blocked_navigation.configure(Rect2(0, 0, 900, 500), [Rect2(200, 40, 50, 140)], 4.0)
	var blocked_hits := [0]
	var blocked := PlayerProjectile.new()
	blocked.configure_directional(_request(), Vector2(100, 82), Vector2.RIGHT, [far_target], blocked_navigation, 880.0, 520.0)
	blocked.hit.connect(func(_request_value: DamageRequest, _actor: CombatActor) -> void: blocked_hits[0] += 1)
	root.add_child(blocked)
	blocked._process(1.0)
	_check(blocked_hits[0] == 0 and blocked.is_queued_for_deletion() and blocked.global_position.x < 200.0, "arena geometry stops the precision projectile before the target")

	var dodging_target := _target(Vector2(300, 100))
	var dodged_hits := [0]
	var dodged := PlayerProjectile.new()
	dodged.configure_directional(_request(), Vector2(100, 82), Vector2.RIGHT, [dodging_target], open_navigation, 880.0, 520.0)
	dodged.hit.connect(func(_request_value: DamageRequest, _actor: CombatActor) -> void: dodged_hits[0] += 1)
	root.add_child(dodged)
	dodging_target.position = Vector2(300, 190)
	dodged._process(1.0)
	_check(dodged_hits[0] == 0 and dodged.is_queued_for_deletion() and dodged.travelled == 520.0, "target movement can dodge the fixed trajectory before range expiration")
	_check(projectile.process_mode == Node.PROCESS_MODE_PAUSABLE and blocked.process_mode == Node.PROCESS_MODE_PAUSABLE and dodged.process_mode == Node.PROCESS_MODE_PAUSABLE, "all player projectiles remain governed by tree pause")

	var mage_projectile := MageProjectile.new()
	mage_projectile.configure_directional(_request(&"fireball"), Vector2(100, 82), Vector2.RIGHT, [near_target], open_navigation, 680.0, 700.0)
	_check(mage_projectile is PlayerProjectile and mage_projectile.max_hits == 1 and mage_projectile.projectile_radius == 6.0, "Mage projectile keeps its radius over shared collision with an explicit one-hit policy")
	mage_projectile.free()
	near_target.queue_free()
	far_target.queue_free()
	dodging_target.queue_free()

func _check_controller_wiring() -> void:
	RunController.pending_run_state = RunState.new(&"archer")
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	var target: CombatActor = controller.enemies[0]
	target.global_position = controller.player.global_position + Vector2(250, 0)
	for index: int in range(1, controller.enemies.size()):
		controller.enemies[index].global_position = controller.player.global_position + Vector2(700, 100 * index)
	controller.player.pursue(target)
	controller.player._process(0.01)
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(projectiles.size() == 1 and projectiles[0] is PlayerProjectile and not (projectiles[0] is MageProjectile), "real controller wires Archer basic emission to the shared precision projectile")
	var projectile := projectiles[0] as PlayerProjectile
	_check(projectile.speed == 880.0 and projectile.max_distance == 520.0 and is_equal_approx(projectile.request.physical_damage, controller.player.stat_breakdown.value(&"precision_attack")), "spawned projectile keeps approved speed, range and captured precision damage")
	projectile.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	projectile.request.can_crit = false
	var hp_before := target.health.current_hp
	projectile._process(1.0)
	_check(target.health.current_hp < hp_before and projectile.is_queued_for_deletion(), "controller applies a deterministic first impact and cleans the Archer projectile")
	controller.queue_free()
	await process_frame

func _request(skill_id: StringName = &"basic_attack") -> DamageRequest:
	var request := DamageRequest.new()
	request.skill_id = skill_id
	request.physical_damage = 10.0
	request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
	request.can_crit = true
	return request

func _target(position_value: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 19.0)
	actor.position = position_value
	root.add_child(actor)
	actor.set_process(false)
	return actor

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
