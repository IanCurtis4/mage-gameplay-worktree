extends SceneTree
## S5 finite Absolute Focus: clocks, local range and actual scene dispatch.

const ABSOLUTE := &"sentinel_absolute_focus"
var checks := 0
var failures := 0
var emissions := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _activation_ranks()
	await _invalid_commands()
	await _clock_matrix()
	await _stability_movement_recalculation()
	await _real_projectile_ranges()
	await _terminal_cleanup()
	print("Sentinel S5 Absolute: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _build(rank: int = 5) -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "sentinel-absolute-fixture"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel"
	build.base_level = 30
	build.job_level = 40
	build.attribute_allocations = {&"int": 25, &"dex": 25, &"luk": 15}
	build.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"archer", &"sentinel")
	build.skill_ranks = {ABSOLUTE: rank, &"sentinel_headshot": 1, &"sentinel_piercing_shot": 1, &"sentinel_net_shot": 1, &"sentinel_observe": 1, &"sentinel_precision_stance": 3}
	build.active_slots = [ABSOLUTE, &"sentinel_headshot", &"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_observe"]
	build.passive_slots = [&"sentinel_precision_stance", null]
	return build

func _player(rank: int = 5) -> PlayerActor:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	var player := PlayerActor.new()
	player.position = Vector2(300, 300)
	player.configure(navigation, RunState.from_build("", _build(rank)))
	root.add_child(player)
	player.set_process(false)
	player.sentinel_combat_active = true
	player.sentinel_projectile_requested.connect(func(_request: DamageRequest, _actor: CombatActor, _direction: Vector2, _payload: Dictionary) -> void: emissions += 1)
	player.precision_projectile_requested.connect(func(_id: StringName, _request: DamageRequest, _actor: CombatActor, _direction: Vector2, _count: int, _hits: int) -> void: emissions += 1)
	return player

func _victim(player: PlayerActor) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo Absoluto", Color.WHITE, player.stat_breakdown)
	enemy.position = Vector2(690, 300)
	root.add_child(enemy)
	enemy.set_process(false)
	return enemy

func _fingerprint(player: PlayerActor) -> Array:
	return [player.current_sp, player.sentinel_state.focus, player.sentinel_state.absolute_remaining, player.skill_cooldown(ABSOLUTE), player.attack_cooldown, player._attack_recovery, player.sentinel_state.stable_time, player.sentinel_state.reserved_sp, player.sentinel_state.reserved_focus, emissions]

func _activation_ranks() -> void:
	for rank: int in range(1, 6):
		var player := _player(rank)
		var enemy := _victim(player)
		var basic := player.basic_attack_distance(enemy)
		var body_radii := player.collision_radius + enemy.collision_radius
		var projectile_range := player.archer_basic_projectile_range()
		player.attack_cooldown = 0.7
		player._attack_recovery = 0.1
		var sp := player.current_sp
		var before_emissions := emissions
		_check(player.use_sentinel_absolute_focus(), "R%d activation succeeds without Focus reserve" % rank)
		_close(player.sentinel_state.absolute_remaining, 3.5 + 0.5 * rank, "R%d exact duration" % rank)
		_close(player.current_sp, sp - player.skill_cost(ABSOLUTE), "R%d SP charged once on activation" % rank)
		_close(player.skill_cooldown(ABSOLUTE), StatCalculator.effective_cooldown(30.0, player.stat_breakdown), "R%d canonical CD starts on activation" % rank)
		_check(player.attack_cooldown == 0.7 and player._attack_recovery == 0.1 and player.sentinel_state.focus == 0.0 and emissions == before_emissions, "R%d buff neither resets auto, emits shot nor grants instant Focus" % rank)
		_close(player.sentinel_range_multiplier(), 1.2, "R%d single nonstacking range multiplier" % rank)
		for id: StringName in [&"sentinel_headshot", &"sentinel_observe", &"sentinel_net_shot"]:
			_close(player.skill_range(id), 408.0, "R%d ST/point range340 grows20%%: %s" % [rank, id])
		_close(player.skill_range(&"sentinel_piercing_shot"), 720.0, "R%d directional range600 grows20%%" % rank)
		_close(player.basic_attack_distance(enemy), body_radii + (basic - body_radii) * 1.2, "R%d scales attack reach, not collider radii" % rank)
		_close(player.archer_basic_projectile_range(), projectile_range * 1.2, "R%d outgoing ordinary projectile reach grows20%%" % rank)
		_check(player.can_target_skill(&"sentinel_headshot", enemy), "R%d actual target validator accepts added reach" % rank)
		var active := _fingerprint(player)
		_check(not player.use_sentinel_absolute_focus() and _fingerprint(player) == active, "R%d recast on CD cannot renew duration/stack/pay twice" % rank)
		player.sentinel_state.absolute_remaining = 0.0
		_close(player.sentinel_range_multiplier(), 1.0, "R%d expiration removes multiplier" % rank)
		_close(player.skill_range(&"sentinel_headshot"), 340.0, "R%d expiration restores skill range" % rank)
		_close(player.basic_attack_distance(enemy), basic, "R%d expiration restores basic reach without altering bodies" % rank)
		_check(not player.can_target_skill(&"sentinel_headshot", enemy), "R%d validator rejects same target after expiration" % rank)
		player.mage_cooldowns[ABSOLUTE] = 0.0
		player.sentinel_state.absolute_remaining = 1.0
		_check(player.use_sentinel_absolute_focus() and is_equal_approx(player.sentinel_state.absolute_remaining, 3.5 + 0.5 * rank), "R%d forced reapplication replaces finite duration, never adds old remainder" % rank)
		player.queue_free()
		enemy.queue_free()
		await process_frame

func _invalid_commands() -> void:
	for reason: String in ["sp", "reserved_sp", "cooldown", "stun", "fear", "pause", "dead", "unequipped", "identity"]:
		var player := _player()
		match reason:
			"sp": player.current_sp = player.skill_cost(ABSOLUTE) - 1.0
			"reserved_sp":
				player.current_sp = player.skill_cost(ABSOLUTE) + 10.0
				player.sentinel_state.reserved_sp = 11.0
			"cooldown": player.mage_cooldowns[ABSOLUTE] = 1.0
			"stun": player.apply_stun(1.0)
			"fear": player.apply_fear(1.0)
			"pause": paused = true
			"dead": player.health.current_hp = 0.0
			"unequipped": player.run_state.build_snapshot.active_slots[0] = null
			"identity": player.run_state.build_snapshot.evolution_id = &"hunter"
		var before := _fingerprint(player)
		_check(not player.use_sentinel_absolute_focus() and _fingerprint(player) == before, "%s invalid activation is atomic" % reason)
		paused = false
		player.queue_free()
		await process_frame

func _clock_matrix() -> void:
	for hz: int in [30, 60, 144]:
		for rank: int in range(1, 6):
			var player := _player(rank)
			_check(player.use_sentinel_absolute_focus(), "%dHz R%d clock activation" % [hz, rank])
			var duration := 3.5 + 0.5 * rank
			var total := duration + 0.237
			var remaining := total
			while remaining > 0.0000001:
				var delta := minf(1.0 / hz, remaining)
				player._process(delta)
				remaining -= delta
			_close(player.sentinel_state.focus, duration * 15.0 + 0.237 * 10.0, "%dHz R%d expiry splits15/s to10/s inside frame" % [hz, rank])
			_close(player.sentinel_state.absolute_remaining, 0.0, "%dHz R%d finite buff expires" % [hz, rank])
			_close(player.skill_cooldown(ABSOLUTE), 30.0 - total, "%dHz R%d CD started before expiry, not after" % [hz, rank])
			_check(player.sentinel_range_multiplier() == 1.0 and player._sentinel_stance_active, "%dHz R%d buff ends independently of stationary posture" % [hz, rank])
			player._process(30.0)
			_check(player.sentinel_state.absolute_remaining == 0.0 and player.skill_cooldown(ABSOLUTE) == 0.0 and player.sentinel_state.focus == 100.0, "%dHz R%d ready cooldown does not auto-renew buff or overflow Focus" % [hz, rank])
			player.queue_free()
			await process_frame
	var state := SentinelFocusState.new()
	state.absolute_remaining = 0.2
	state.advance(1.0, false, true)
	_close(state.focus, 8.0, "coarse cold interval splits buff expiry and ordinary0.5s preparation")
	state = SentinelFocusState.new()
	state.advance(0.6, false, true)
	state.absolute_remaining = 0.2
	state.advance(0.5, false, true)
	_close(state.focus, 7.0, "coarse already-stable interval splits15/s and10/s")

func _stability_movement_recalculation() -> void:
	var player := _player()
	var base_dex := player.stat_breakdown.primary_value(&"dex")
	player.use_sentinel_absolute_focus()
	player._process(0.01)
	_close(player.sentinel_state.focus, 0.15, "actual player generates15/s immediately without ordinary0.5s delay")
	_check(not player._sentinel_stance_active and player.stat_breakdown.primary_value(&"dex") == base_dex, "resource buff does not waive passive0.75s preparation")
	player._process(0.73)
	_check(not player._sentinel_stance_active, "Posture still absent at0.74s while Absolute is active")
	player._process(0.011)
	_close(player.stat_breakdown.primary_value(&"dex"), base_dex + 9.0, "Posture activates normally after0.75s")
	player.health.current_hp -= 20.0
	player.current_sp -= 10.0
	var hp := player.health.current_hp
	var sp := player.current_sp
	var remaining := player.sentinel_state.absolute_remaining
	var cd := player.skill_cooldown(ABSOLUTE)
	for iteration: int in range(4):
		player.apply_run_modifiers(player.run_state)
		_check(player.health.current_hp == hp and player.current_sp == sp and player.sentinel_state.absolute_remaining == remaining and player.skill_cooldown(ABSOLUTE) == cd, "recalculation%d cannot heal/refill/renew duration/CD" % iteration)
		_check(player.stat_breakdown.sources().filter(func(source: Dictionary) -> bool: return source["source_id"] == &"sentinel_precision_stance").size() == 1 and player.sentinel_range_multiplier() == 1.2, "recalculation%d preserves exactly one posture source and one range multiplier" % iteration)
	var focus := player.sentinel_state.focus
	player.move_to(Vector2(500, 300))
	player._process(0.03)
	_check(player.position.x > 300.0 and player.sentinel_state.focus == focus and not player._sentinel_stance_active and player.sentinel_state.absolute_remaining > 0.0, "real movement preserves Focus/buff but removes posture and generates nothing")
	var before_pause := _fingerprint(player)
	var position := player.position
	paused = true
	player._process(10.0)
	_check(_fingerprint(player) == before_pause and player.position == position, "actual player pause freezes buff/CD/resource/recovery/movement")
	paused = false
	player.velocity = Vector2.ZERO
	player._path.clear()
	player._has_path_goal = false
	player.sentinel_combat_active = false
	player._process(3.0)
	_close(player.sentinel_state.focus, focus, "outside combat no generation during3s grace despite Absolute")
	player._process(0.2)
	_close(player.sentinel_state.focus, focus - 2.0, "outside combat decays10/s even while buff remains")
	player.configure(player.navigation, RunState.from_build("", _build()))
	_check(player.sentinel_state.absolute_remaining == 0.0 and player.sentinel_state.focus == 0.0 and not player._sentinel_stance_active and player.sentinel_range_multiplier() == 1.0, "reconfiguration clears buff/resource/source for fresh run")
	player.queue_free()
	await process_frame

func _scene() -> RunController:
	RunController.pending_run_state = RunState.from_build("", _build())
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena._training_add_elapsed = -1000.0
	arena.navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	arena.player.position = Vector2(300, 300)
	arena.training_boss.position = Vector2(690, 300)
	return arena

func _real_projectile_ranges() -> void:
	for skill: StringName in [&"basic_attack", &"sentinel_headshot", &"sentinel_piercing_shot"]:
		var arena := _scene()
		var player := arena.player
		arena._commit_skill(ABSOLUTE, player.position)
		_check(player.sentinel_state.absolute_remaining == 6.0 and player.skill_cooldown(ABSOLUTE) == 30.0 and get_nodes_in_group("player_projectiles").is_empty(), "actual dispatcher activates buff without projectile")
		player.sentinel_state.gain(80.0)
		if skill == &"basic_attack":
			player.target = arena.training_boss
			player._try_basic_attack()
		else:
			arena._commit_skill(skill, arena.training_boss.position + PlayerProjectile.BODY_OFFSET)
		var nodes := get_nodes_in_group("player_projectiles")
		_check(nodes.size() == 1 and nodes[0] is PlayerProjectile, "%s actual scene emits one projectile in buffed reach" % skill)
		if nodes.size() == 1:
			var projectile := nodes[0] as PlayerProjectile
			projectile.set_process(false)
			var expected := 624.0 if skill == &"basic_attack" else 720.0 if skill == &"sentinel_piercing_shot" else 408.0
			_close(projectile.max_distance, expected, "%s real projectile uses buffed launch range" % skill)
			player.sentinel_state.absolute_remaining = 0.0
			_close(projectile.max_distance, expected, "%s emitted range remains snapshotted after buff expires" % skill)
		arena.queue_free()
		await process_frame

func _terminal_cleanup() -> void:
	for terminal: String in ["result", "death"]:
		var arena := _scene()
		var player := arena.player
		player.use_sentinel_absolute_focus()
		player._process(0.8)
		if terminal == "result":
			arena._show_result(false)
		else:
			player.health.current_hp = 0.0
			player._on_health_died(player.get_instance_id())
		_check(arena.run_finished and paused and player.sentinel_state.absolute_remaining == 0.0 and player.sentinel_state.focus == 0.0 and not player._sentinel_stance_active and player.sentinel_range_multiplier() == 1.0, "%s synchronously removes buff/resource/range/source before paused result" % terminal)
		paused = false
		arena.queue_free()
		await process_frame
	_check(get_nodes_in_group("player_effects").is_empty() and get_nodes_in_group("player_projectiles").is_empty(), "terminal scene teardown leaves no visual/projectile orphan")

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (%.6f vs %.6f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Sentinel S5 Absolute: " + label)
