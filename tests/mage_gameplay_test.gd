extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_statuses()
	_test_projectile_order_and_burning()
	_test_spears_and_teleport()
	_test_cast_runtime()
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
	paused = true
	actor._process(1.0)
	paused = false
	_check(is_equal_approx(actor.burn_remaining, 3.0), "actor process defensively preserves burn during tree pause")
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
	var inside_projectile := _fireball(open_nav, [after])
	var inside_center := after.global_position + MageProjectile.BODY_OFFSET
	_check(inside_projectile._actor_fraction(after, inside_center, inside_center + Vector2.RIGHT) == 0.0, "projectile starting and ending inside a body reports immediate contact")
	inside_projectile.free()
	after.free()

	var caster := CombatActor.new()
	caster.setup("Mago", Color.WHITE, RpgStats.derive({}))
	caster.position = Vector2(100, 100)
	root.add_child(caster)
	var crossing := _target(Vector2(230, 19))
	var wall := FireWall.new()
	wall.configure(caster, Vector2.RIGHT, 5.0, [crossing])
	root.add_child(wall)
	wall._process(0.01)
	crossing.position = Vector2(330, 19)
	wall._process(0.30)
	_check(crossing.is_burning(), "fire wall catches an actor crossing a pillar between frames")
	wall.free()
	caster.free()
	crossing.free()

func _test_spears_and_teleport() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 520, 260), [Rect2(150, 40, 70, 160)], 20.0)
	var state := RunState.new(&"mage")
	state.augment_stacks[&"extra_fire_spear"] = 1
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
	_check(emitted_count[0] == 2 and state.projectile_count(&"ice_spear") == 1 and is_equal_approx(mage.mana, mana_before - mage.skill_cost(&"fire_spear")), "fire-spear augment emits two fire projectiles for one cost without changing ice")
	state.augment_stacks[&"extra_ice_spear"] = 1
	_check(state.projectile_count(&"fire_spear") == 2 and state.projectile_count(&"ice_spear") == 2 and state.skill_levels[&"fire_spear"] == 1 and state.skill_levels[&"ice_spear"] == 1, "fire and ice spear counts and levels remain independent")
	state.skill_levels[&"fire_spear"] = 3
	_check(state.projectile_count(&"fire_spear") == 4 and state.projectile_count(&"ice_spear") == 2 and ClassCatalog.skill_definition(&"fire_spear").id == &"fire_spear", "fire spear level adds only fire projectiles without mutating catalog data")
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

func _test_cast_runtime() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 700, 300), [], 20.0)
	var mage := PlayerActor.new()
	mage.configure(nav, RunState.new(&"mage"))
	mage.position = Vector2(80, 100)
	root.add_child(mage)
	mage.set_process(false)
	var completed := [0]
	mage.skill_cast_ready.connect(func(_skill: StringName, _point: Vector2, _target_id: int) -> void: completed[0] += 1)
	var mana_before := mage.mana
	var expected_time := ClassCatalog.skill_definition(&"fireball").cast_time * float(mage.stats["cast_multiplier"])
	_check(mage.begin_skill_cast(&"fireball", Vector2(400, 100)) and is_equal_approx(mage.active_cast_total, expected_time), "fireball begins a short DEX-scaled preparation")
	mage._process(expected_time * 0.5)
	_check(completed[0] == 0 and mage.mana == mana_before and mage.skill_cooldown(&"fireball") == 0.0, "preparation does not spend mana or start cooldown early")
	paused = true
	var paused_remaining := mage.active_cast_remaining
	mage._process(expected_time)
	paused = false
	_check(is_equal_approx(mage.active_cast_remaining, paused_remaining), "tree pause freezes active cast time")
	mage.move_to(Vector2(120, 100))
	_check(not mage.has_active_cast() and mage.mana == mana_before, "movement cancels cast preparation without spending")
	mage.begin_skill_cast(&"fireball", Vector2(400, 100))
	mage._process(expected_time + 0.01)
	_check(completed[0] == 1 and not mage.has_active_cast() and mage.mana == mana_before, "completed preparation requests one revalidated commit and still owns no resource spending")
	mage.begin_skill_cast(&"fire_wall", Vector2(400, 100))
	var lethal := DamageRequest.new()
	lethal.target_id = mage.get_instance_id()
	lethal.base_damage = 9999.0
	lethal.hit_chance = 1.0
	lethal.can_crit = false
	mage.health.apply(lethal, 0.0, 0.99)
	_check(not mage.has_active_cast(), "death cancels active cast synchronously")
	mage.free()

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
	controller.augment_overlay.visible = true
	controller.get_tree().paused = true
	controller._open_class_menu()
	_check(controller.augment_overlay.visible and not controller.class_overlay.visible and paused, "class menu cannot stack over a pending augment choice")
	controller.augment_overlay.visible = false
	controller.get_tree().paused = false
	controller._toggle_settings(true)
	controller._open_class_menu()
	_check(paused and controller.class_overlay.visible and not controller.battle_controls.settings_overlay.visible, "class menu replaces controls instead of stacking pause overlays")
	controller._close_class_menu()
	_check(not paused and not controller.class_overlay.visible, "class menu can return without resetting the active run")
	var first_enemy := controller.enemies[0]
	var second_enemy := controller.enemies[1]
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	first_enemy.position = controller.player.position + Vector2(240, 0)
	controller._select_enemy(first_enemy)
	controller.player.pursue(first_enemy)
	controller.player._process(0.01)
	_check(get_nodes_in_group("player_projectiles").size() == 1, "mage basic attack emits a ranged projectile at the selected target")
	controller.player.mage_cooldowns[&"teleport"] = 0.0
	controller.player.mana = controller.player.max_mana
	var teleport_point := controller.player.position + Vector2(0, 100)
	controller._execute_skill(&"teleport", teleport_point)
	_check(controller.player.target == null and not first_enemy.is_selected and controller._selected_enemy == null, "successful teleport clears pending pursuit and its visible selection")
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
	for projectile: Node in get_nodes_in_group("player_projectiles"):
		projectile.free()
	controller.player.mana = controller.player.max_mana
	controller.player.mage_cooldowns[&"fireball"] = 0.0
	var fireball_mana := controller.player.mana
	var fireball_point := controller.player.position + Vector2(300, 0)
	controller._commit_skill(&"fireball", fireball_point)
	_check(controller.player.has_active_cast() and controller.player.mana == fireball_mana and controller.player.skill_cooldown(&"fireball") == 0.0, "controller starts fireball preparation without early mana or cooldown")
	controller.cast_intent.cancel()
	controller._update_hud()
	controller._update_aim(fireball_point)
	_check(controller.battle_controls.aim_label.text.contains("Conjurando") and controller.skill_label.text.contains("CONJURANDO"), "HUD exposes remaining cast time after target confirmation")
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(not controller.player.has_active_cast() and is_equal_approx(controller.player.mana, fireball_mana - controller.player.skill_cost(&"fireball")) and controller.player.skill_cooldown(&"fireball") == ClassCatalog.skill_definition(&"fireball").cooldown, "completed fireball spends and starts base cooldown exactly once")

	controller.player.mage_cooldowns[&"fire_wall"] = 0.0
	controller.player.mana = controller.player.max_mana
	var wall_mana := controller.player.mana
	controller._commit_skill(&"fire_wall", controller.player.position + Vector2.RIGHT * 300.0)
	controller._toggle_settings(true)
	_check(not controller.player.has_active_cast() and controller.player.mana == wall_mana and controller.player.skill_cooldown(&"fire_wall") == 0.0, "opening controls cancels preparation without spending")
	controller._toggle_settings(false)
	controller.player.use_fire_wall(Vector2.RIGHT)
	_check(not get_nodes_in_group("player_projectiles").is_empty() and not get_nodes_in_group("player_effects").is_empty(), "mage runtime owns projectiles and persistent walls before reset")

	controller.player.mage_cooldowns[&"fire_spear"] = 0.0
	controller.player.mana = controller.player.max_mana
	var invalid_mana := controller.player.mana
	first_enemy.position = controller.player.position + Vector2(240, 0)
	var target_point := first_enemy.position + RunController.ACTOR_BODY_OFFSET
	controller._commit_skill(&"fire_spear", target_point)
	first_enemy.position = controller.player.position + Vector2(500, 0)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(controller.player.mana == invalid_mana and controller.player.skill_cooldown(&"fire_spear") == 0.0 and get_nodes_in_group("player_projectiles").size() == 1, "spear revalidates target after cast and spends nothing when it leaves range")
	var dead_during_cast := _target(controller.player.position + Vector2(180, 0))
	controller.player.mage_cooldowns[&"fire_spear"] = 0.0
	controller.player.mana = controller.player.max_mana
	var dead_cast_mana := controller.player.mana
	controller.player.begin_skill_cast(&"fire_spear", dead_during_cast.position, dead_during_cast)
	dead_during_cast.health.current_hp = 0.0
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(controller.player.mana == dead_cast_mana and controller.player.skill_cooldown(&"fire_spear") == 0.0, "target dying during preparation cancels spear commit without spending")
	dead_during_cast.free()
	var freed_during_cast := _target(controller.player.position + Vector2(180, 0))
	controller.player.begin_skill_cast(&"fire_spear", freed_during_cast.position, freed_during_cast)
	freed_during_cast.queue_free()
	await process_frame
	var freed_cast_mana := controller.player.mana
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(not controller.player.has_active_cast() and controller.player.mana == freed_cast_mana and controller.player.skill_cooldown(&"fire_spear") == 0.0, "freed target crosses typed cast signal safely and cancels without spending")

	for projectile: Node in get_nodes_in_group("player_projectiles"):
		projectile.free()
	for effect: Node in get_nodes_in_group("player_effects"):
		effect.free()
	first_enemy.position = controller.player.position + Vector2(240, 0)
	second_enemy.health.current_hp = 1.0
	var lethal := DamageRequest.new()
	lethal.source_id = controller.player.get_instance_id()
	lethal.target_id = first_enemy.get_instance_id()
	lethal.base_damage = 9999.0
	lethal.hit_chance = 1.0
	lethal.can_crit = false
	first_enemy.apply_damage(lethal, controller.rng)
	controller.run_state.augment_stacks[&"extra_fire_spear"] = 1
	controller.player.mage_cooldowns[&"fire_spear"] = 0.0
	controller.player.mana = controller.player.max_mana
	var last_target_point := second_enemy.position + RunController.ACTOR_BODY_OFFSET
	second_enemy.position = controller.player.position + Vector2(220, 0)
	last_target_point = second_enemy.position + RunController.ACTOR_BODY_OFFSET
	controller._commit_skill(&"fire_spear", last_target_point)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var twin_projectiles := get_nodes_in_group("player_projectiles")
	_check(twin_projectiles.size() == 2, "successful fire spear uses its own +1 augment after preparation")
	for projectile: MageProjectile in twin_projectiles:
		projectile._process(0.5)
	await process_frame
	_check(controller.enemies.is_empty() and controller.reward != null and get_nodes_in_group("player_projectiles").is_empty(), "twin projectiles kill the last enemy once and clean remaining shots")

	controller.player.mage_cooldowns[&"fire_wall"] = 0.0
	controller.player.mana = controller.player.max_mana
	controller._commit_skill(&"fire_wall", controller.player.position + Vector2.RIGHT * 300.0)
	controller._select_class(&"swordsman")
	await scene_changed
	await process_frame
	controller = current_scene as RunController
	_check(controller.run_state.class_id == &"swordsman" and controller.battle_controls.skill_buttons.size() == 2 and not controller.run_state.skill_levels.has(&"fireball"), "switching back starts an isolated swordsman run")
	_check(not controller.player.has_active_cast() and get_nodes_in_group("player_projectiles").is_empty() and get_nodes_in_group("player_effects").is_empty(), "class reset removes active casts, mage projectiles and walls")
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
