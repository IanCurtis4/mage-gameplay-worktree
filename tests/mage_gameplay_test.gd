extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_statuses()
	_test_projectile_order_and_burning()
	_test_spears_and_teleport()
	_test_visible_dash()
	await _test_class_reset_and_ui()
	print("Gameplay do Mago: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_statuses() -> void:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, RpgStats.derive({"vit": 20}))
	root.add_child(actor)
	actor.set_process(false)
	var tick_count := [0]
	var all_secondary := [true]
	actor.status_damage_requested.connect(func(request: DamageRequest, _target: CombatActor) -> void:
		tick_count[0] += 1
		all_secondary[0] = all_secondary[0] and request.is_secondary and not request.can_crit
	)
	for _pillar: int in range(4):
		actor.apply_burn(42, 9.0, 3.0)
	actor.advance_statuses(3.0)
	_check(tick_count[0] == 3 and all_secondary[0], "four overlapping pillars renew one three-tick secondary burn")
	actor.apply_burn(42, 9.0, 3.0)
	actor.advance_statuses(1.0, true)
	_check(is_equal_approx(actor.burn_remaining, 3.0), "pause freezes burn duration and ticks")
	var base_stats := actor.stats.duplicate(true)
	actor.apply_slow(0.30, 2.0)
	actor.apply_slow(0.30, 2.0)
	_check(is_equal_approx(actor.movement_speed_multiplier(), 0.70) and actor.stats == base_stats, "slow is non-stacking runtime state and does not mutate base stats")
	actor.advance_statuses(2.1)
	_check(is_equal_approx(actor.movement_speed_multiplier(), 1.0), "slow expires back to the original movement multiplier")
	actor.free()

func _test_projectile_order_and_burning() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 440, 240), [Rect2(220, 40, 24, 160)], 4.0)
	var before := _target(Vector2(150, 118))
	var after := _target(Vector2(300, 118))
	var hits: Array[CombatActor] = []
	var fireball := _fireball(nav, [before, after])
	fireball.hit.connect(func(_request: DamageRequest, actor: CombatActor) -> void: hits.append(actor))
	root.add_child(fireball)
	fireball._process(1.0)
	_check(hits.size() == 1 and hits[0] == before, "fireball hits the first enemy before a later wall")
	before.free()
	hits.clear()
	var blocked := _fireball(nav, [after])
	blocked.hit.connect(func(_request: DamageRequest, actor: CombatActor) -> void: hits.append(actor))
	root.add_child(blocked)
	blocked._process(1.0)
	_check(hits.is_empty() and blocked.is_queued_for_deletion(), "wall before target stops fireball without damage")

	var open_nav := ArenaNavigation.new()
	open_nav.configure(Rect2(0, 0, 440, 240), [], 4.0)
	after.apply_burn(7, 2.0, 3.0)
	var burning_hit := [false]
	var critical_ball := _fireball(open_nav, [after])
	critical_ball.hit.connect(func(request: DamageRequest, _actor: CombatActor) -> void: burning_hit[0] = request.force_critical)
	root.add_child(critical_ball)
	critical_ball._process(1.0)
	_check(burning_hit[0], "fireball marks guaranteed critical only when burn is active at impact")
	var spear_request := DamageRequest.new()
	spear_request.skill_id = &"fire_spear"
	spear_request.base_damage = 40.0
	spear_request.hit_chance = 1.0
	spear_request.target_id = after.get_instance_id()
	var spear := MageProjectile.new()
	spear.configure_homing(spear_request, after, Vector2(50, 100), open_nav, 760.0, 360.0, Color("ff793d"))
	var boosted_power := [0.0]
	spear.hit.connect(func(request: DamageRequest, _actor: CombatActor) -> void: boosted_power[0] = request.base_damage)
	root.add_child(spear)
	spear._process(1.0)
	_check(is_equal_approx(boosted_power[0], 60.0), "fire spear gains exactly 50 percent when burn is active at impact")
	after.clear_statuses()
	var expired_hit := [true]
	var normal_ball := _fireball(open_nav, [after])
	normal_ball.hit.connect(func(request: DamageRequest, _actor: CombatActor) -> void: expired_hit[0] = request.force_critical)
	root.add_child(normal_ball)
	normal_ball._process(1.0)
	_check(not expired_hit[0], "fireball uses normal critical chance after burn expires")
	after.free()

func _test_spears_and_teleport() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 520, 260), [Rect2(150, 40, 70, 160)], 20.0)
	var state := RunState.new(&"mage")
	state.augment_stacks[&"extra_spear"] = 1
	var mage := PlayerActor.new()
	mage.configure(nav, state)
	mage.position = Vector2(80, 118)
	root.add_child(mage)
	mage.set_process(false)
	var target := _target(Vector2(380, 118))
	var emitted_count := [0]
	mage.mage_projectile_requested.connect(func(_skill: StringName, _request: DamageRequest, _target_actor: CombatActor, _direction: Vector2, count: int) -> void: emitted_count[0] = count)
	var mana_before := mage.mana
	_check(mage.use_spear(&"fire_spear", target), "valid assisted-range target accepts fire spear")
	_check(emitted_count[0] == 2 and is_equal_approx(mage.mana, mana_before - mage.skill_cost(&"fire_spear")), "extra-spear augment emits two projectiles for one mana cost")
	var spent := mage.mana
	target.health.current_hp = 0.0
	mage.mage_cooldowns[&"fire_spear"] = 0.0
	_check(not mage.use_spear(&"fire_spear", target) and mage.mana == spent, "dead target rejects spear without spending resources")

	mage.target = target
	mage._path = PackedVector2Array([Vector2(100, 118)])
	mage.velocity = Vector2(50, 0)
	var teleport_cost := mage.skill_cost(&"teleport")
	var teleport_mana := mage.mana
	_check(mage.use_teleport(Vector2(300, 118)), "teleport crosses an obstacle when its destination is free")
	_check(mage.position.is_equal_approx(Vector2(300, 118)) and mage.target == null and mage._path.is_empty() and mage.velocity == Vector2.ZERO and is_equal_approx(mage.mana, teleport_mana - teleport_cost), "teleport clears prior walking and pursuit state")
	mage.mage_cooldowns[&"teleport"] = 0.0
	var rejected_mana := mage.mana
	_check(not mage.use_teleport(Vector2(180, 118)) and mage.mana == rejected_mana and mage.position == Vector2(300, 118), "solid teleport destination is rejected without cost or movement")
	mage.free()
	target.free()

func _test_visible_dash() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 420, 240), [Rect2(180, 40, 50, 160)], 20.0)
	var warrior := PlayerActor.new()
	warrior.configure(nav, RunState.new())
	warrior.position = Vector2(80, 118)
	root.add_child(warrior)
	warrior.set_process(false)
	var endpoint := warrior.dash_destination(Vector2.RIGHT)
	var origin := warrior.position
	_check(warrior.use_dash(Vector2.RIGHT) and warrior.position == origin and warrior._dash_active, "dash starts without teleporting the swordsman")
	warrior._process(PlayerActor.DASH_DURATION * 0.5)
	_check(warrior.position.x > origin.x and warrior.position.x < endpoint.x, "dash produces visible intermediate displacement")
	warrior._process(PlayerActor.DASH_DURATION)
	_check(warrior.position.distance_to(endpoint) < 0.01 and endpoint.x < 160.0 and not warrior._dash_active, "dash finishes at the obstacle-clipped preview endpoint")
	warrior.free()

func _test_class_reset_and_ui() -> void:
	RunController.selected_class_id = &"swordsman"
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	await process_frame
	var controller := current_scene as RunController
	var old_player := controller.player
	controller.player.mana = 1.0
	controller.run_state.augment_stacks[&"vitality"] = 2
	controller._select_class(&"mage")
	await scene_changed
	await process_frame
	controller = current_scene as RunController
	_check(controller.player != old_player and controller.run_state.class_id == &"mage" and controller.player.is_mage(), "class selection rebuilds the run with a new player instance")
	_check(controller.run_state.augment_stacks.is_empty() and controller.player.mana == controller.player.max_mana and controller.encounter_index == 1, "class change clears augments, resources, cooldowns and encounter progress")
	_check(is_equal_approx(controller.player.stats["mana_regen_per_second"], 9.0), "mage passive increases mana regeneration through the shared stat pipeline")
	_check(controller.battle_controls.skill_buttons.size() == 5 and controller.battle_controls.skill_buttons.has(&"teleport") and not controller.battle_controls.skill_buttons.has(&"slash"), "mage UI exposes only Q/W/A/S/D mage actions")
	_check(controller._key_skill(KEY_A) == &"fire_spear" and controller._key_skill(KEY_D) == &"teleport" and controller._key_skill(KEY_E) == &"", "mage input mapping preserves E for augments")
	var first_enemy := controller.enemies[0]
	first_enemy.position = controller.player.position + Vector2(240, 0)
	controller._select_enemy(first_enemy)
	controller.player.pursue(first_enemy)
	controller.player._process(0.01)
	_check(get_nodes_in_group("player_projectiles").size() == 1, "mage basic attack emits a ranged projectile at the selected target")
	var ice_request := DamageRequest.new()
	ice_request.source_id = controller.player.get_instance_id()
	ice_request.target_id = first_enemy.get_instance_id()
	ice_request.skill_id = &"ice_spear"
	ice_request.kind = DamageRequest.Kind.MAGIC
	ice_request.base_damage = 5.0
	ice_request.hit_chance = 1.0
	ice_request.can_crit = false
	controller._on_mage_projectile_hit(ice_request, first_enemy)
	_check(is_equal_approx(first_enemy.movement_speed_multiplier(), 0.70), "landed ice spear applies the typed 30 percent slow")
	controller.player.mage_cooldowns[&"fireball"] = 0.0
	controller.player.mage_cooldowns[&"fire_wall"] = 0.0
	controller.player.use_fireball(Vector2.RIGHT)
	controller.player.use_fire_wall(Vector2.RIGHT)
	_check(not get_nodes_in_group("player_projectiles").is_empty() and not get_nodes_in_group("player_effects").is_empty(), "mage runtime owns projectiles and persistent walls before reset")
	controller._select_class(&"swordsman")
	await scene_changed
	await process_frame
	controller = current_scene as RunController
	_check(controller.run_state.class_id == &"swordsman" and controller.battle_controls.skill_buttons.size() == 2 and not controller.run_state.skill_levels.has(&"fireball"), "switching back starts an isolated swordsman run")
	_check(get_nodes_in_group("player_projectiles").is_empty() and get_nodes_in_group("player_effects").is_empty(), "class reset removes mage projectiles and walls")
	RunController.selected_class_id = &"swordsman"

func _fireball(nav: ArenaNavigation, actors: Array[CombatActor]) -> MageProjectile:
	var request := DamageRequest.new()
	request.skill_id = &"fireball"
	request.kind = DamageRequest.Kind.MAGIC
	request.base_damage = 50.0
	request.hit_chance = 1.0
	var projectile := MageProjectile.new()
	projectile.configure_directional(request, Vector2(50, 100), Vector2.RIGHT, actors, nav, 680.0, 700.0)
	return projectile

func _target(position_value: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, RpgStats.derive({"vit": 20}), 18.0)
	actor.position = position_value
	root.add_child(actor)
	actor.set_process(false)
	return actor

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
