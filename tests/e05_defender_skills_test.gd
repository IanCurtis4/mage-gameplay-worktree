extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"defender"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"defender")
	snapshot.skill_ranks = {&"defender_counterstroke": 1, &"defender_anchor": 1, &"defender_line_lock": 1, &"defender_wall_advance": 1, &"defender_reprisal_wave": 1, &"defender_watch": 1}
	snapshot.active_slots = [&"defender_counterstroke", &"defender_anchor", &"defender_line_lock", &"defender_wall_advance", &"defender_reprisal_wave"]
	snapshot.passive_slots = [&"defender_watch", null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("defender-skills", snapshot))
	player.global_position = Vector2(400, 350)
	root.add_child(player)
	player.set_process(false)
	var enemy := EnemyActor.new()
	enemy.configure(&"chaser", nav, player)
	enemy.global_position = Vector2(480, 350)
	root.add_child(enemy)
	enemy.set_process(false)
	var controller := RunController.new()
	controller.player = player
	controller.navigation = nav
	controller.enemies = [enemy]
	controller.rng.seed = 9
	player.defender_hit_requested.connect(controller._on_defender_hit_requested)
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	var hp := enemy.health.current_hp
	player.current_sp = player.max_sp
	_check(player.use_defender_line_lock(Vector2.RIGHT, [enemy]), "line lock commits")
	_check(enemy.health.current_hp < hp and enemy.root_remaining() > 0.0, "line lock roots only after HP damage")
	_check(enemy.attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_DEALT, &"defender_watch") > 0.0, "equipped Watch applies from direct melee HP damage")
	player.mage_cooldowns[&"defender_anchor"] = 0.0
	player.current_sp = player.max_sp
	_check(player.use_defender_anchor(Vector2(550, 350)), "anchor places within range")
	_check(player.has_defender_anchor() and player.defender_anchor_center == Vector2(550, 350), "anchor records one center")
	controller._sync_defender_anchor()
	_check(enemy.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) >= 0.20, "anchor slows enemies inside")
	enemy.global_position = Vector2(700, 350)
	controller._sync_defender_anchor()
	_check(enemy.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) == 0.0, "anchor slow clears immediately on leaving")
	player.global_position = Vector2(550, 350)
	var base_defense := player.stat_breakdown.value(&"physical_defense")
	player._update_defender_anchor_presence()
	_check(player._defender_inside_anchor and player.stat_breakdown.value(&"physical_defense") > base_defense, "anchor grants owner defense only inside through derived stats")
	player.defender_token_remaining = 5.0
	paused = true
	player._process(1.0)
	paused = false
	_check(player.defender_token_remaining == 5.0, "pause freezes Defender token and zone timers")
	enemy.global_position = Vector2(550, 350)
	controller._sync_defender_anchor()
	player.clear_defender_state()
	_check(not player._defender_inside_anchor and not player.has_defender_anchor(), "cleanup removes anchor defense and zone")
	controller._sync_defender_anchor()
	_check(enemy.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) == 0.0, "controller cleanup leaves no anchor debuff")
	player.global_position = Vector2(400, 350)
	enemy.global_position = Vector2(450, 350)
	enemy.health.current_hp = enemy.health.max_hp
	player.current_sp = player.max_sp
	var before_advance := player.current_sp
	_check(player.use_defender_wall_advance(Vector2.RIGHT, [enemy]) and player.current_sp < before_advance and player.defender_advance_guard_active, "advance spends only for a valid displacement")
	player._advance_dash(PlayerActor.DASH_DURATION)
	_check(enemy.health.current_hp < enemy.health.max_hp and enemy.global_position.x > 450.0 and not player.defender_advance_guard_active, "advance hits once and pushes a normal enemy along navigation")
	player.mage_cooldowns[&"defender_reprisal_wave"] = 0.0
	player.current_sp = player.max_sp
	player.defender_token_remaining = 8.0
	enemy.global_position = player.global_position + Vector2(70, 0)
	enemy.health.current_hp = enemy.health.max_hp
	_check(player.use_defender_reprisal_wave([enemy]) and not player.has_defender_token(), "wave consumes one token at commit")
	_check(enemy.health.current_hp < enemy.health.max_hp and enemy.global_position.x > player.global_position.x + 70.0, "empowered wave damages and pushes normal enemy")
	enemy.clear_statuses()
	enemy.configure_hard_control_profile(true)
	enemy.global_position = player.global_position + Vector2(80, 0)
	enemy.health.current_hp = enemy.health.max_hp
	player.mage_cooldowns[&"defender_line_lock"] = 0.0
	player.current_sp = player.max_sp
	var boss_hp := enemy.health.current_hp
	_check(player.use_defender_line_lock(Vector2.RIGHT, [enemy]) and enemy.health.current_hp < boss_hp and enemy.root_remaining() > 0.0 and enemy.root_remaining() <= HardControlState.BOSS_DURATION_CAP, "boss receives line damage with canonical physical CC cap")
	enemy.health.current_hp = enemy.health.max_hp
	player.mage_cooldowns[&"defender_reprisal_wave"] = 0.0
	player.current_sp = player.max_sp
	player.defender_token_remaining = 8.0
	var boss_position := enemy.global_position
	_check(player.use_defender_reprisal_wave([enemy]) and enemy.health.current_hp < enemy.health.max_hp and enemy.global_position == boss_position, "single boss takes empowered wave damage without adds or displacement")
	enemy.clear_statuses()
	enemy.health.current_hp = enemy.health.max_hp
	var secondary := DamageRequest.new()
	secondary.source_id = player.get_instance_id()
	secondary.target_id = enemy.get_instance_id()
	secondary.skill_id = &"defender_counterstroke"
	secondary.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	secondary.physical_damage = 10.0
	secondary.is_secondary = true
	enemy.apply_damage(secondary, controller.rng)
	_check(enemy.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0, "secondary HP damage never triggers Watch")
	enemy.health.current_hp = enemy.health.max_hp
	enemy.health.shield_hp = 100.0
	secondary.is_secondary = false
	enemy.apply_damage(secondary, controller.rng)
	_check(enemy.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0, "shield-only damage never triggers Watch")
	enemy.health.shield_hp = 0.0
	var blocked_nav := ArenaNavigation.new()
	blocked_nav.configure(Rect2(0, 0, 1000, 700), [Rect2(425, 300, 100, 100)], 20.0)
	var blocked_player := PlayerActor.new()
	blocked_player.configure(blocked_nav, RunState.from_build("defender-blocked", snapshot))
	blocked_player.global_position = Vector2(400, 350)
	root.add_child(blocked_player)
	blocked_player.set_process(false)
	var before_block := blocked_player.current_sp
	blocked_player.apply_root(2.0)
	_check(not blocked_player.use_defender_wall_advance(Vector2.RIGHT, []) and blocked_player.current_sp == before_block, "rooted advance leaves SP and cooldown unchanged")
	_check(not blocked_player.use_defender_anchor(Vector2(500, 350)) and blocked_player.current_sp == before_block, "blocked anchor does not spend")
	player._last_facing = Vector2.LEFT
	player.defender_wall_advance_destination(Vector2.RIGHT)
	_check(player._last_facing == Vector2.LEFT, "aim preview does not alter the actor's captured facing")
	var rank_zero := snapshot.copy_snapshot()
	rank_zero.skill_ranks.erase(&"defender_anchor")
	var zero_player := PlayerActor.new()
	zero_player.configure(nav, RunState.from_build("defender-r0", rank_zero))
	zero_player.global_position = Vector2(400, 350)
	root.add_child(zero_player)
	zero_player.set_process(false)
	_check(&"defender_anchor" not in zero_player.available_skill_ids() and not zero_player.use_defender_anchor(Vector2(500, 350)), "rank-zero Anchor cannot appear or cast")
	var rank_five := snapshot.copy_snapshot()
	for skill_id: StringName in [&"defender_counterstroke", &"defender_anchor", &"defender_line_lock", &"defender_wall_advance", &"defender_reprisal_wave"]:
		rank_five.skill_ranks[skill_id] = 5
	var max_player := PlayerActor.new()
	max_player.configure(nav, RunState.from_build("defender-r5", rank_five))
	max_player.global_position = Vector2(400, 350)
	root.add_child(max_player)
	max_player.set_process(false)
	_check(max_player.use_defender_anchor(Vector2(550, 350)) and is_equal_approx(max_player.defender_anchor_remaining, 6.0) and is_equal_approx(max_player.skill_range(&"defender_wall_advance"), 130.0), "R5 uses rank-specific Anchor duration and Advance range")
	var rank_five_hits: Array[DamageRequest] = []
	max_player.defender_hit_requested.connect(func(request: DamageRequest, _target: CombatActor, _root: float, _push: Vector2) -> void: rank_five_hits.append(request))
	max_player.current_sp = max_player.max_sp
	max_player.defender_token_remaining = 8.0
	enemy.global_position = Vector2(550, 350)
	_check(max_player.use_defender_reprisal_wave([enemy]) and rank_five_hits.size() == 1 and is_equal_approx(rank_five_hits[0].physical_damage, max_player.stat_breakdown.value(&"melee_attack") * 1.35), "R5 empowered Wave uses rank power plus the catalog token bonus")
	player.queue_free()
	enemy.queue_free()
	blocked_player.queue_free()
	zero_player.queue_free()
	max_player.queue_free()
	controller.free()
	await process_frame
	await _test_advance_interruptions(nav)
	print("E05 Defendente skills: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_advance_interruptions(nav: ArenaNavigation) -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"defender"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"defender")
	snapshot.skill_ranks = {&"defender_counterstroke": 1, &"defender_wall_advance": 1, &"concentrated_rage": 1, &"dash": 1}
	snapshot.active_slots = [&"defender_wall_advance", &"concentrated_rage", &"dash", null, null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("defender-interrupt", snapshot))
	player.global_position = Vector2(400, 350)
	root.add_child(player)
	player.set_process(false)
	_check(player.use_defender_wall_advance(Vector2.RIGHT, []) and player._dash_active and player.defender_advance_guard_active, "advance opens moving frontal guard")
	player.current_sp = player.max_sp
	_check(player.use_concentrated_rage(Vector2.RIGHT, []) and not player._dash_active and not player.defender_advance_guard_active and player._defender_advance_targets.is_empty(), "Concentrated Rage cancels the advance and its guard")
	var source := CombatActor.new()
	source.setup("Fonte", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	source.global_position = Vector2(500, 350)
	root.add_child(source)
	source.set_process(false)
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.physical_damage = 35.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	var unguarded := CombatMath.resolve(request, player.health.physical_defense, player.health.magic_defense, player.health.flee_rating, player.health.crit_resistance, 0.0, 1.0)
	var applied := player.apply_damage(request, RandomNumberGenerator.new())
	_check(applied["damage"] == unguarded["damage"], "frontal damage after Rage cancellation has no stale 20 percent mitigation")
	player.current_sp = player.max_sp
	player.mage_cooldowns[&"defender_wall_advance"] = 0.0
	_check(player.use_defender_wall_advance(Vector2.RIGHT, []) and player.defender_advance_guard_active, "advance can be started again")
	player.current_sp = player.max_sp
	_check(player.use_dash(Vector2.UP) and player._dash_active and not player.defender_advance_guard_active and player._defender_advance_targets.is_empty(), "base Dash replaces advance without retaining its guard")
	player.current_sp = player.max_sp
	player.mage_cooldowns[&"defender_wall_advance"] = 0.0
	_check(player.use_defender_wall_advance(Vector2.RIGHT, []) and player.defender_advance_guard_active, "advance can replace base Dash")
	player.clear_defender_state()
	_check(not player._dash_active and not player.defender_advance_guard_active, "encounter cleanup cancels displacement and guard together")
	player.queue_free()
	source.queue_free()
	await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
