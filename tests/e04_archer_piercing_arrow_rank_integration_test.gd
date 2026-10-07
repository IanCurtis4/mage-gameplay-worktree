extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table_and_gate()
	_check_ranked_emission_and_sp()
	_check_piercing_collision_policy()
	await _check_preview_hud_dispatch_and_projectile()
	print("E04 Flecha Perfurante por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table_and_gate() -> void:
	var definition := ClassCatalog.skill_definition(&"piercing_arrow")
	var expected_powers: Array[float] = [1.05, 1.20, 1.35, 1.50, 1.65]
	var expected_costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.PIERCING_ARROW and definition.targeting == SkillDefinition.Targeting.DIRECTION, "Flecha Perfurante exposes a valid directional rank catalog and closed handler")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_powers[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Flecha Perfurante R%d owns its approved per-target power and SP cost" % rank)
		_check(values.cooldown == 5.0 and values.range == 600.0 and values.projectile_speed == 920.0, "Flecha Perfurante R%d preserves cooldown, range and projectile speed" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0, "Flecha Perfurante R%d remains instant" % rank)
		_check(values.precision_weight == 1.0 and values.physical_weight == 0.0 and values.magic_weight == 0.0 and values.effect_ids.is_empty(), "Flecha Perfurante R%d preserves pure precision scaling without added effects" % rank)
	var profile := ProfileCatalog.pilot()
	_check(profile.skill_metadata(&"piercing_arrow").get("max_purchased_rank") == 5 and profile.base_class_is_available(&"archer"), "profile keeps Piercing Arrow progression while the delivered passive opens the Archer gate")

func _check_ranked_emission_and_sp() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 700), [], 20.0)
	var rank_one := _player(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("piercing-arrow-r5", rank_five_source)
	rank_five_source.skill_ranks[&"piercing_arrow"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	root.add_child(rank_one)
	root.add_child(rank_five)
	var rank_one_requests: Array[DamageRequest] = []
	var rank_five_requests: Array[DamageRequest] = []
	var emission_policies: Array[Vector2i] = []
	rank_one.precision_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, count: int, hit_limit: int) -> void:
		rank_one_requests.append(request)
		emission_policies.append(Vector2i(count, hit_limit))
	)
	rank_five.precision_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, count: int, hit_limit: int) -> void:
		rank_five_requests.append(request)
		emission_policies.append(Vector2i(count, hit_limit))
	)
	var rank_one_sp := rank_one.current_sp
	var rank_five_sp := rank_five.current_sp
	_check(rank_one.use_piercing_arrow(Vector2.RIGHT) and rank_five.use_piercing_arrow(Vector2.RIGHT), "R1 and R5 both emit a valid directional piercing arrow")
	_check(emission_policies == [Vector2i(1, 3), Vector2i(1, 3)], "every rank emits one projectile with exactly three allowed impacts")
	_check(rank_one_requests.size() == 1 and is_equal_approx(rank_one_requests[0].physical_damage, rank_one.stat_breakdown.value(&"precision_attack") * 1.05), "R1 captures approved per-target precision power")
	_check(rank_five_requests.size() == 1 and is_equal_approx(rank_five_requests[0].physical_damage, rank_five.stat_breakdown.value(&"precision_attack") * 1.65), "R5 captures approved per-target precision power")
	_check(rank_one_requests[0].accuracy_mode == DamageRequest.AccuracyMode.CONTESTED and rank_one_requests[0].can_crit, "each impact remains contested and critical-capable")
	_check(rank_one.current_sp == rank_one_sp - 18.0 and rank_five.current_sp == rank_five_sp - 24.0, "each rank debits its approved SP cost once rather than per impact")
	_check(rank_one.skill_cooldown(&"piercing_arrow") == StatCalculator.effective_cooldown(5.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"piercing_arrow") == StatCalculator.effective_cooldown(5.0, rank_five.stat_breakdown), "both ranks apply the fixed cooldown through the shared calculator")
	_check(rank_five.skill_rank(&"piercing_arrow") == 5 and rank_five.skill_range(&"piercing_arrow") == 600.0 and rank_five.skill_projectile_speed(&"piercing_arrow") == 920.0 and rank_five.skill_cast_time(&"piercing_arrow") == 0.0, "runtime values come from the copied R5 snapshot after source mutation")
	rank_five.mage_cooldowns[&"piercing_arrow"] = 0.0
	rank_five.current_sp = 23.0
	var requests_before := rank_five_requests.size()
	_check(not rank_five.use_piercing_arrow(Vector2.RIGHT) and rank_five.current_sp == 23.0 and rank_five_requests.size() == requests_before, "R5 blocks below 24 SP without spending or emitting")
	var invalid_rank := _player(navigation, 6)
	root.add_child(invalid_rank)
	_check(invalid_rank.skill_rank_definition(&"piercing_arrow") == null and invalid_rank.skill_cost(&"piercing_arrow") == 0.0 and invalid_rank.skill_range(&"piercing_arrow") == 0.0 and invalid_rank.skill_projectile_speed(&"piercing_arrow") == 0.0 and not invalid_rank.use_piercing_arrow(Vector2.RIGHT), "invalid runtime rank is ineligible instead of falling back to R1 values")
	for node: Node in [rank_one, rank_five, invalid_rank]:
		node.queue_free()

func _check_piercing_collision_policy() -> void:
	var open_navigation := ArenaNavigation.new()
	open_navigation.configure(Rect2(0, 0, 900, 500), [], 4.0)
	var first := _target(Vector2(240, 100))
	var second := _target(Vector2(330, 100))
	var third := _target(Vector2(420, 100))
	var fourth := _target(Vector2(510, 100))
	var hits: Array[CombatActor] = []
	var target_ids: Array[int] = []
	var projectile := PlayerProjectile.new()
	projectile.configure_directional(_request(), Vector2(100, 82), Vector2.RIGHT, [third, first, second, first, fourth], open_navigation, 920.0, 600.0, 3)
	projectile.hit.connect(func(request: DamageRequest, actor: CombatActor) -> void:
		hits.append(actor)
		target_ids.append(request.target_id)
	)
	root.add_child(projectile)
	projectile._process(1.0)
	_check(hits == [first, second, third], "one frame resolves piercing impacts in nearest-first geometric order rather than target-list order")
	_check(target_ids == [first.get_instance_id(), second.get_instance_id(), third.get_instance_id()], "every synchronous impact carries its own current target id")
	_check(projectile._hit_actor_ids.size() == 3 and not fourth.get_instance_id() in projectile._hit_actor_ids and projectile.is_queued_for_deletion(), "fixed hit limit stops at three distinct actors and never repeats a duplicated target")
	_check(projectile.global_position.x < fourth.global_position.x, "projectile ends on the third impact instead of crossing the capped fourth target")

	var blocked_navigation := ArenaNavigation.new()
	blocked_navigation.configure(Rect2(0, 0, 900, 500), [Rect2(365, 40, 45, 140)], 4.0)
	var blocked_hits: Array[CombatActor] = []
	var blocked := PlayerProjectile.new()
	blocked.configure_directional(_request(), Vector2(100, 82), Vector2.RIGHT, [third, first, second], blocked_navigation, 920.0, 600.0, 3)
	blocked.hit.connect(func(_request_value: DamageRequest, actor: CombatActor) -> void: blocked_hits.append(actor))
	root.add_child(blocked)
	blocked._process(1.0)
	_check(blocked_hits == [first, second] and blocked.is_queued_for_deletion(), "wall preserves prior impacts but blocks every target behind it")
	_check(blocked.global_position.x < 365.0 and blocked.travelled < 600.0, "wall terminates the remaining movement before maximum range")

	var one_hit := PlayerProjectile.new()
	one_hit.configure_directional(_request(&"double_shot"), Vector2(100, 82), Vector2.RIGHT, [first, second], open_navigation, 880.0, 520.0)
	var one_hit_targets: Array[CombatActor] = []
	one_hit.hit.connect(func(_request_value: DamageRequest, actor: CombatActor) -> void: one_hit_targets.append(actor))
	root.add_child(one_hit)
	one_hit._process(1.0)
	_check(one_hit_targets == [first] and one_hit.max_hits == 1 and one_hit.is_queued_for_deletion(), "default policy preserves one impact for basic attacks, Double Shot and Mage projectiles")
	for actor: CombatActor in [first, second, third, fourth]:
		actor.queue_free()

func _check_preview_hud_dispatch_and_projectile() -> void:
	RunController.pending_run_state = RunState.from_build("piercing-arrow-preview", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	var extra_target := _target(controller.player.global_position + Vector2(440, 0))
	controller.enemies.append(extra_target)
	for index: int in controller.enemies.size():
		controller.enemies[index].global_position = controller.player.global_position + Vector2(220 + 110 * index, 0)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"piercing_arrow"]
	_check(controller.skill_label.text.contains("Flecha Perfurante R5") and card.tooltip_text.contains("R5") and card.tooltip_text.contains("24 SP"), "HUD renders snapshot rank and definition cost from the same source")
	controller.cast_intent.active_skill = &"piercing_arrow"
	var aim_point := controller.player.global_position + Vector2(1000, 0)
	controller._update_aim(aim_point)
	var expected_endpoint := controller.player.global_position + Vector2.RIGHT * 600.0
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == expected_endpoint and controller.battle_indicators.active_range == 600.0, "ready preview uses the ranked directional range")
	var sp_before := controller.player.current_sp
	controller._execute_skill(&"piercing_arrow", aim_point)
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(projectiles.size() == 1 and controller.player.current_sp == sp_before - 24.0 and controller.player.skill_cooldown(&"piercing_arrow") == StatCalculator.effective_cooldown(5.0, controller.player.stat_breakdown), "PIERCING_ARROW handler spends once and creates exactly one R5 projectile")
	var projectile := projectiles[0] as PlayerProjectile
	_check(projectile != null and projectile.max_hits == 3 and projectile.speed == 920.0 and projectile.max_distance == 600.0 and is_equal_approx(projectile.request.physical_damage, controller.player.stat_breakdown.value(&"precision_attack") * 1.65), "spawned arrow captures ranked damage and the fixed piercing policy")
	projectile.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	projectile.request.can_crit = false
	var hp_before: Array[float] = []
	for enemy: CombatActor in controller.enemies:
		hp_before.append(enemy.health.current_hp)
	projectile._process(1.0)
	var all_three_damaged := true
	for index: int in controller.enemies.size():
		all_three_damaged = all_three_damaged and controller.enemies[index].health.current_hp < hp_before[index]
	_check(all_three_damaged and projectile.is_queued_for_deletion(), "controller applies one independent impact to each of three aligned targets in the same frame")
	controller.enemies.erase(extra_target)
	extra_target.queue_free()
	controller.queue_free()
	await process_frame

func _player(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("piercing-arrow-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "piercing-arrow-test"
	snapshot.base_class_id = &"archer"
	snapshot.skill_ranks = {&"piercing_arrow": rank}
	snapshot.active_slots = [&"piercing_arrow", null, null, null, null]
	return snapshot

func _request(skill_id: StringName = &"piercing_arrow") -> DamageRequest:
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
