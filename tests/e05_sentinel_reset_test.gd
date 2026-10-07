extends SceneTree
## S2 transaction: immediate special emission, paid once, no extra same-frame auto.

const HEAD := &"sentinel_headshot"
var checks := 0
var failures := 0
var special: Array[DamageRequest] = []
var autos: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _rank_transactions()
	await _invalid_commands()
	await _scene_projectile()
	await _post_launch_loss()
	await _scene_intents()
	print("Sentinel S2 reset: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _build(rank: int = 1) -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "sentinel-reset-fixture"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel"
	build.base_level = 20
	build.job_level = 40
	build.attribute_allocations = {&"dex": 20, &"luk": 10}
	build.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"archer", &"sentinel")
	build.skill_ranks = {HEAD: rank}
	build.active_slots = [HEAD, null, null, null, null]
	build.passive_slots = [null, null]
	return build

func _fixture(rank: int = 1) -> PlayerActor:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.position = Vector2(300, 300)
	player.configure(nav, RunState.from_build("", _build(rank)))
	root.add_child(player)
	player.set_process(false)
	player.sentinel_combat_active = true
	player.sentinel_state.gain(80.0)
	player.sentinel_projectile_requested.connect(func(request: DamageRequest, _actor: CombatActor, _direction: Vector2, _payload: Dictionary) -> void: special.append(request.copy()))
	player.precision_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _actor: CombatActor, _direction: Vector2, _count: int, _hits: int) -> void: autos.append(request.copy()))
	special.clear()
	autos.clear()
	return player

func _victim(player: PlayerActor) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo S2", Color.WHITE, player.stat_breakdown)
	actor.position = player.position + Vector2(180, 0)
	root.add_child(actor)
	actor.set_process(false)
	return actor

func _rank_transactions() -> void:
	for rank: int in range(1, 6):
		var player := _fixture(rank)
		var enemy := _victim(player)
		player.pursue(enemy)
		player._process(0.01)
		_check(autos.size() == 1 and player.attack_cooldown > 0.0, "R%d ordinary auto starts recovery" % rank)
		var sp := player.current_sp
		var focus := player.sentinel_state.focus
		_check(player.use_sentinel_reset(HEAD, enemy.position, enemy), "R%d special releases during previous auto recovery" % rank)
		_check(special.size() == 1 and autos.size() == 1, "R%d reset emits only one special, no simultaneous ordinary shot" % rank)
		_close(player.current_sp, sp - player.skill_cost(HEAD), "R%d SP charged once" % rank)
		_close(player.sentinel_state.focus, focus - 30.0, "R%d Focus charged once at launch" % rank)
		_close(player.attack_cooldown, 1.0 / player.attacks_per_second(), "R%d special starts normal APS recovery" % rank)
		_check(player._attack_recovery > 0.0 and player.skill_cooldown(HEAD) > 0.0, "R%d both recovery and skill CD started" % rank)
		var committed := _fingerprint(player)
		_check(not player.use_sentinel_reset(HEAD, enemy.position, enemy) and _fingerprint(player) == committed, "R%d immediate duplicate command is completely free and emits nothing" % rank)
		if not special.is_empty():
			var shot := special[0]
			_close(shot.physical_damage, SentinelMath.raw_power(HEAD, rank, player.stat_breakdown), "R%d physical power is canonical precision helper" % rank)
			_check(shot.magic_damage == 0.0 and shot.can_crit and not shot.force_critical and shot.accuracy_mode == DamageRequest.AccuracyMode.CONTESTED, "R%d physical accuracy and normal crit retained" % rank)
			_check(shot.emission_id != autos[0].emission_id and shot.source_id == player.get_instance_id() and shot.target_id == enemy.get_instance_id(), "R%d reset has its own immutable emission identity" % rank)
			var noncrit := CombatMath.resolve(shot, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0)
			var crit := CombatMath.resolve(shot, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
			_check(not noncrit["critical"] and crit["critical"] and crit["damage"] > noncrit["damage"], "R%d central crit rolls are neither guaranteed nor disabled" % rank)
		player._process(10.0)
		_check(autos.size() == 1, "R%d even large same-frame delta cannot grant extra auto" % rank)
		await process_frame
		await process_frame
		player._process(0.001)
		_check(autos.size() == 2, "R%d recovery resumes autos on subsequent frame" % rank)
		player.queue_free()
		enemy.queue_free()
		await process_frame

func _fingerprint(player: PlayerActor) -> Array:
	return [player.current_sp, player.sentinel_state.focus, player.sentinel_state.reserved_focus, player.sentinel_state.reserved_sp, player.skill_cooldown(HEAD), player.attack_cooldown, player._attack_recovery, player._sentinel_last_launch_frame, special.size(), autos.size()]

func _invalid_commands() -> void:
	for reason: String in ["focus", "reserved_focus", "sp", "reserved_sp", "cooldown", "dead_target", "range", "obstacle", "stun", "fear", "pause", "dead_player", "unlearned", "invalid_point", "null_target"]:
		var player := _fixture()
		var enemy := _victim(player)
		var point := enemy.position
		match reason:
			"focus": player.sentinel_state.focus = 29.0
			"reserved_focus":
				player.sentinel_state.focus = 50.0
				player.sentinel_state.reserved_focus = 25.0
			"sp": player.current_sp = player.skill_cost(HEAD) - 1.0
			"reserved_sp":
				player.current_sp = player.skill_cost(HEAD) + 5.0
				player.sentinel_state.reserved_sp = 6.0
			"cooldown": player.mage_cooldowns[HEAD] = 1.0
			"dead_target": enemy.health.current_hp = 0.0
			"range": enemy.position = player.position + Vector2(player.skill_range(HEAD) + 1.0, 0)
			"obstacle": player.navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(380, 250, 30, 100)], 20.0)
			"stun": player.apply_stun(1.0)
			"fear": player.apply_fear(1.0)
			"pause": paused = true
			"dead_player": player.health.current_hp = 0.0
			"unlearned": player.run_state.build_snapshot.skill_ranks.erase(HEAD)
			"invalid_point": point = Vector2.INF
		var before := _fingerprint(player)
		_check(not player.use_sentinel_reset(HEAD, point, null if reason == "null_target" else enemy), "%s invalid command rejected" % reason)
		_check(_fingerprint(player) == before, "%s rejection preserves all resource/recovery/emission state" % reason)
		paused = false
		player.queue_free()
		enemy.queue_free()
		await process_frame
	var player := _fixture()
	var enemy := _victim(player)
	player.sentinel_state.reserved_focus = 25.0
	player.sentinel_state.reserved_sp = 5.0
	player.sentinel_state.explosive_prepared = true
	_check(player.use_sentinel_reset(HEAD, enemy.position, enemy), "enough free resources permit reset while ammunition is reserved")
	_check(player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_focus == 25.0 and player.sentinel_state.reserved_sp == 5.0, "reset never consumes or cancels Explosive preparation")
	player.queue_free()
	enemy.queue_free()
	await process_frame
	var rooted := _fixture()
	var rooted_enemy := _victim(rooted)
	rooted.apply_root(1.0, &"magic")
	_check(rooted.use_sentinel_reset(HEAD, rooted_enemy.position, rooted_enemy), "root blocks movement, not valid ranged attacks")
	rooted.queue_free()
	rooted_enemy.queue_free()
	await process_frame

func _scene() -> RunController:
	RunController.pending_run_state = RunState.from_build("", _build(5))
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.sentinel_combat_active = arena.encounter_active
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena._training_add_elapsed = -1000.0
	arena.navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	arena.player.position = Vector2(300, 300)
	arena.training_boss.position = Vector2(480, 300)
	arena.player.sentinel_state.gain(80.0)
	return arena

func _scene_projectile() -> void:
	var arena := _scene()
	var player := arena.player
	var enemy := arena.training_boss
	_check(player.use_sentinel_reset(HEAD, enemy.position, enemy), "actual scene dispatches reset")
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(projectiles.size() == 1 and projectiles[0] is PlayerProjectile, "scene spawns one real PlayerProjectile")
	if projectiles.size() == 1:
		var projectile := projectiles[0] as PlayerProjectile
		projectile.set_process(false)
		var frozen := projectile.request.copy()
		_check(projectile.homing and projectile.target == enemy and projectile.max_hits == 1, "Headshot single-target homing, never AoE or piercing")
		player.run_state.build_snapshot.attribute_allocations[&"dex"] = 40
		player.run_state.build_snapshot.attribute_allocations[&"luk"] = 30
		player.apply_run_modifiers(player.run_state)
		_check(projectile.request.physical_damage == frozen.physical_damage and projectile.request.hit_rating == frozen.hit_rating and projectile.request.crit_chance == frozen.crit_chance, "in-flight power/accuracy/crit do not recapture changed stats")
		var position := projectile.position
		paused = true
		projectile._process(1.0)
		_check(projectile.position == position and not projectile.is_queued_for_deletion(), "real projectile pauses without premature collision")
		paused = false
		var impacts: Array[DamageRequest] = []
		projectile.hit.connect(func(request: DamageRequest, _actor: CombatActor) -> void: impacts.append(request.copy()))
		projectile._process(1.0)
		_check(impacts.size() == 1 and projectile.is_queued_for_deletion(), "continuous collision resolves one impact and removes projectile")
		if not impacts.is_empty():
			_check(impacts[0].physical_damage == frozen.physical_damage and impacts[0].emission_id == frozen.emission_id, "impact retains launched snapshot")
		_close(player.sentinel_state.focus, 54.0, "impact returns intrinsic4 without charging additional Focus")
	arena._show_result(false)
	_check(arena.run_finished and paused and player.sentinel_state.focus == 0.0 and player.sentinel_state.observed_target_id == 0, "actual result clears Sentinel state synchronously while paused")
	paused = false
	arena.queue_free()
	await process_frame
	_check(get_nodes_in_group("player_projectiles").is_empty(), "scene removal leaves no projectile orphans")

func _post_launch_loss() -> void:
	var arena := _scene()
	var player := arena.player
	var enemy := arena.training_boss
	_check(player.use_sentinel_reset(HEAD, enemy.position, enemy), "launch commits before target later dies")
	var projectile := get_nodes_in_group("player_projectiles")[0] as PlayerProjectile
	projectile.set_process(false)
	var paid_sp := player.current_sp
	var paid_cd := player.skill_cooldown(HEAD)
	enemy.health.current_hp = 0.0
	projectile._process(0.1)
	_check(projectile.is_queued_for_deletion() and player.current_sp == paid_sp and player.sentinel_state.focus == 50.0 and player.skill_cooldown(HEAD) == paid_cd, "target death after launch removes shot without resource/CD refund")
	player.sentinel_state.observe(enemy.get_instance_id(), 5)
	player.sentinel_state.reserved_focus = 25.0
	player.sentinel_state.reserved_sp = 5.0
	player.sentinel_state.explosive_prepared = true
	player.health.current_hp = 0.0
	player._on_health_died(player.get_instance_id())
	_check(arena.run_finished and paused and player.sentinel_state.focus == 0.0 and player.sentinel_state.reserved_focus == 0.0 and player.sentinel_state.observed_target_id == 0, "actual actor death reaches result and synchronously clears Focus/mark/reservation")
	paused = false
	arena.queue_free()
	await process_frame

func _scene_intents() -> void:
	for mode: int in [CastIntent.Mode.CONFIRM, CastIntent.Mode.RELEASE, CastIntent.Mode.INSTANT]:
		var arena := _scene()
		var player := arena.player
		arena.cast_intent.set_mode(mode)
		var before_sp := player.current_sp
		var immediate := arena.cast_intent.press(HEAD)
		_check(player.current_sp == before_sp and player.sentinel_state.focus == 80.0, "input mode %d selection does not charge resources" % mode)
		var command := immediate
		if mode == CastIntent.Mode.CONFIRM:
			command = arena.cast_intent.confirm()
		elif mode == CastIntent.Mode.RELEASE:
			command = arena.cast_intent.release(HEAD)
		arena._commit_skill(command, arena.training_boss.position + PlayerProjectile.BODY_OFFSET)
		_check(get_nodes_in_group("player_projectiles").size() == 1 and player.sentinel_state.focus == 50.0, "input mode %d commits exactly one reset through real dispatcher" % mode)
		arena._commit_skill(arena.cast_intent.release(HEAD), arena.training_boss.position)
		_check(get_nodes_in_group("player_projectiles").size() == 1, "input mode %d later release cannot duplicate committed shot" % mode)
		arena.queue_free()
		await process_frame
	var arena := _scene()
	arena.cast_intent.press(HEAD)
	arena._cancel_casting()
	_check(arena.cast_intent.active_skill == &"" and arena.player.sentinel_state.focus == 80.0 and arena.player.skill_cooldown(HEAD) == 0.0, "canceling preview does not reset recovery or charge anything")
	arena.queue_free()
	await process_frame

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (%.6f vs %.6f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Sentinel S2: " + label)
