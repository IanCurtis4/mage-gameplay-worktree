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
	_check(player.use_defender_anchor(Vector2(470, 350)), "anchor places within range")
	_check(player.has_defender_anchor() and player.defender_anchor_center == Vector2(470, 350), "anchor records one center")
	controller._sync_defender_anchor()
	_check(enemy.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) >= 0.20, "anchor slows enemies inside")
	enemy.global_position = Vector2(700, 350)
	controller._sync_defender_anchor()
	_check(enemy.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) == 0.0, "anchor slow clears immediately on leaving")
	player.global_position = Vector2(470, 350)
	player._update_defender_anchor_presence()
	_check(player._defender_inside_anchor, "anchor grants owner defense only inside")
	player.clear_defender_state()
	_check(not player._defender_inside_anchor and not player.has_defender_anchor(), "cleanup removes anchor defense and zone")
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
	player.queue_free()
	enemy.queue_free()
	blocked_player.queue_free()
	controller.free()
	await process_frame
	print("E05 Defendente skills: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
