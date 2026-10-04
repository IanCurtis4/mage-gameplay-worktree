extends SceneTree
## S3: real directional reset, additive primaries, finite continuous collision.

const SHOT := &"sentinel_piercing_shot"
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_math_isolation()
	await _transactions()
	await _collision_matrix()
	await _snapshot_and_preview()
	print("Sentinel S3 piercing: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _stats(intelligence: float, dexterity: float, luck: float = 10.0) -> StatBreakdown:
	return StatCalculator.calculate({&"str": 5, &"agi": 5, &"vit": 5, &"int": int(intelligence), &"dex": int(dexterity), &"luk": int(luck)})

func _math_isolation() -> void:
	for rank: int in range(1, 6):
		var initial := _stats(10.0, 20.0)
		var more_int := _stats(20.0, 20.0)
		var more_dex := _stats(10.0, 30.0)
		var more_luck := _stats(10.0, 20.0, 30.0)
		var tuning := SentinelTuning.values(SHOT, rank)
		var power := SentinelMath.raw_power(SHOT, rank, initial)
		_close(SentinelMath.raw_power(SHOT, rank, more_int) - power, 10.0 * float(tuning["int_coefficient"]), "R%d INT contributes independently and additively" % rank)
		_close(SentinelMath.raw_power(SHOT, rank, more_dex) - power, 10.0 * float(tuning["dex_coefficient"]), "R%d DES contributes independently and additively" % rank)
		_close(SentinelMath.raw_power(SHOT, rank, more_luck), power, "R%d SOR does not inflate raw damage" % rank)
		_close(SentinelMath.cooldown(SHOT, 5.0, initial), 5.0 * (1.0 - 0.25 * 20.0 / 120.0), "R%d local cooldown factor is applied once" % rank)
		_close(SentinelMath.cooldown(SHOT, 5.0, more_int), SentinelMath.cooldown(SHOT, 5.0, initial), "R%d INT does not reduce cooldown" % rank)
		_check(SentinelMath.cooldown(SHOT, 5.0, more_dex) < SentinelMath.cooldown(SHOT, 5.0, initial), "R%d DES improves cadence separately" % rank)
		_close(SentinelMath.cooldown(&"piercing_arrow", 5.0, more_dex), StatCalculator.effective_cooldown(5.0, more_dex), "base Archer cooldown unaffected")
		_close(SentinelMath.cooldown(&"sentinel_headshot", 6.0, more_dex), StatCalculator.effective_cooldown(6.0, more_dex), "Headshot does not inherit caster cooldown reduction")
		if rank > 1:
			_check(power > SentinelMath.raw_power(SHOT, rank - 1, initial), "every purchased rank improves actual damage")
	for dex: float in [0.0, 1.0, 30.0, 60.0]:
		var cooldown := SentinelMath.cooldown(SHOT, 5.0, _stats(10.0, dex))
		_check(cooldown >= 3.75 and cooldown <= 5.0, "DES local cooldown remains bounded")

func _build(rank: int = 5) -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "sentinel-piercing-fixture"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel"
	build.base_level = 20
	build.job_level = 40
	build.attribute_allocations = {&"int": 20, &"dex": 20, &"luk": 10}
	build.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"archer", &"sentinel")
	build.skill_ranks = {SHOT: rank, &"sentinel_observe": 5}
	build.active_slots = [SHOT, &"sentinel_observe", null, null, null]
	build.passive_slots = [null, null]
	return build

func _scene(rank: int = 5) -> RunController:
	RunController.pending_run_state = RunState.from_build("", _build(rank))
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena._training_add_elapsed = -1000.0
	arena.navigation.configure(Rect2(0, 0, 1800, 1000), [], 20.0)
	arena.player.position = Vector2(200, 350)
	arena.training_boss.position = Vector2(1500, 800)
	arena.player.sentinel_state.gain(80.0)
	return arena

func _victim(arena: RunController, point: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("S3 alvo", Color.WHITE, arena.player.stat_breakdown)
	actor.position = point
	actor.health.max_hp = 10000.0
	actor.health.current_hp = 10000.0
	actor.health.damage_applied.connect(arena._on_enemy_damage_resolved)
	arena.add_child(actor)
	actor.set_process(false)
	return actor

func _launch(arena: RunController, point: Vector2, selected: CombatActor = null) -> SentinelProjectile:
	_check(arena.player.use_sentinel_reset(SHOT, point, selected), "paid directional launch succeeds")
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(projectiles.size() == 1 and projectiles[0] is SentinelProjectile, "exactly one real directional projectile emitted")
	if projectiles.is_empty():
		return null
	var projectile := projectiles[0] as SentinelProjectile
	projectile.set_process(false)
	return projectile

func _transactions() -> void:
	for rank: int in range(1, 6):
		var arena := _scene(rank)
		var player := arena.player
		player.attack_cooldown = 0.5
		player._attack_recovery = 0.14
		var sp := player.current_sp
		var projectile := _launch(arena, player.position + Vector2(100, 0))
		if projectile != null:
			_check(not projectile.homing and projectile.direction == Vector2.RIGHT and projectile.target == null, "R%d directional reset does not need an enemy" % rank)
			_check(projectile.request.magic_damage > 0.0 and projectile.request.physical_damage == 0.0 and projectile.request.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "R%d direct magical collision does not contest FLEE" % rank)
			_check(projectile.request.can_crit and not projectile.request.force_critical and not projectile.request.is_secondary, "R%d normal SOR critical, no guaranteed crit or secondary damage" % rank)
			_close(projectile.request.magic_damage, SentinelMath.raw_power(SHOT, rank, player.stat_breakdown), "R%d frozen raw INT+DES helper" % rank)
			_close(projectile.max_distance, player.skill_range(SHOT), "R%d finite skill range" % rank)
			_close(player.sentinel_state.focus, 60.0, "R%d pays twenty Focus" % rank)
			_close(player.current_sp, sp - player.skill_cost(SHOT), "R%d pays SP once" % rank)
			_close(player.skill_cooldown(SHOT), SentinelMath.cooldown(SHOT, 5.0, player.stat_breakdown), "R%d commit captures local CD" % rank)
			_close(player.attack_cooldown, 1.0 / player.attacks_per_second(), "R%d resets normal recovery" % rank)
			var noncrit := CombatMath.resolve(projectile.request, 0.0, 0.0, 1000.0, 0.0, 0.999, 1.0)
			var crit := CombatMath.resolve(projectile.request, 0.0, 0.0, 1000.0, 0.0, 0.999, 0.0)
			_check(noncrit["landed"] and not noncrit["critical"] and crit["critical"], "geometry bypasses FLEE while normal crit still rolls")
			arena.training_boss.position = player.position + Vector2(180, 0)
			player.pursue(arena.training_boss)
			player._process(10.0)
			_check(get_nodes_in_group("player_projectiles").size() == 1, "same-frame large delta cannot emit free ordinary auto after reset")
		arena.queue_free()
		await process_frame
	var arena := _scene()
	var before := [arena.player.current_sp, arena.player.sentinel_state.focus, arena.player.attack_cooldown]
	_check(not arena.player.use_sentinel_reset(SHOT, arena.player.position), "zero-length directional command rejected")
	_check([arena.player.current_sp, arena.player.sentinel_state.focus, arena.player.attack_cooldown] == before and get_nodes_in_group("player_projectiles").is_empty(), "invalid direction leaves all transaction state unchanged")
	arena.queue_free()
	await process_frame

func _collision_matrix() -> void:
	for hz: int in [0, 30, 60, 144]:
		for blocked: bool in [false, true]:
			var arena := _scene()
			var actors: Array[CombatActor] = []
			for x: float in [300.0, 460.0, 620.0, 900.0]:
				actors.append(_victim(arena, Vector2(x, 350)))
			var off_line := _victim(arena, Vector2(420, 400))
			arena.enemies = actors.duplicate()
			arena.enemies.append(actors[1]) # Duplicate lookup must not produce duplicate impact.
			arena.enemies.append(off_line)
			if blocked:
				arena.navigation.configure(Rect2(0, 0, 1800, 1000), [Rect2(500, 280, 30, 140)], 20.0)
			arena.player.sentinel_state.observe(actors[1].get_instance_id(), 5)
			var projectile := _launch(arena, arena.player.position + Vector2(10, 0))
			if projectile != null:
				var impacts: Array[int] = []
				projectile.hit.connect(func(_request: DamageRequest, actor: CombatActor) -> void: impacts.append(actor.get_instance_id()))
				for _frame: int in (hz * 2 if hz > 0 else 1):
					projectile._process(1.0 / hz if hz > 0 else 2.0)
				_check(projectile.is_queued_for_deletion(), "%d Hz projectile terminates at finite wall/range" % hz)
				_check(impacts.size() == (2 if blocked else 3), "%d Hz continuous collision hits each pre-wall/in-range body exactly once" % hz)
				for index: int in actors.size():
					var expected_hit := index < (2 if blocked else 3)
					_check((actors[index].health.current_hp < 10000.0) == expected_hit, "%d Hz body %d obeys obstacle and range" % [hz, index])
				_check(off_line.health.current_hp == 10000.0, "%d Hz off-axis body outside combined radii untouched" % hz)
				_close(arena.player.sentinel_state.focus, 70.0, "%d Hz marked direct target returns Focus once despite multiple victims/duplicate list" % hz)
				_check(arena.player.sentinel_state.observation_charges == 2 and arena.player.sentinel_state.observation_cooldown == 0.5, "mark charge and shared cadence consumed once")
				_check(projectile.travelled <= projectile.max_distance and (not blocked or projectile.position.x < 500.0), "projectile never crosses obstacle or exceeds range budget")
			arena.queue_free()
			await process_frame

func _snapshot_and_preview() -> void:
	var arena := _scene()
	var actor := _victim(arena, Vector2(700, 350))
	var selected := _victim(arena, Vector2(400, 500))
	arena.enemies = [actor, selected]
	var point := arena.player.position + Vector2(20, 0)
	arena.battle_indicators.show_aim(SHOT, arena.player, point, true, selected)
	_check(arena.battle_indicators.direction == Vector2.RIGHT and arena.battle_indicators.endpoint == arena.player.position + Vector2(arena.player.skill_range(SHOT), 0), "preview shows full cursor-direction range even when an unrelated body is selected")
	var projectile := _launch(arena, point, selected)
	if projectile != null:
		var frozen := projectile.request.copy()
		var frozen_cd := arena.player.skill_cooldown(SHOT)
		_check(projectile.position == arena.player.position + PlayerProjectile.BODY_OFFSET and projectile.direction == arena.battle_indicators.direction, "projectile body-height origin preserves preview ground direction")
		arena.player.run_state.build_snapshot.attribute_allocations[&"int"] = 40
		arena.player.run_state.build_snapshot.attribute_allocations[&"dex"] = 40
		arena.player.run_state.build_snapshot.attribute_allocations[&"luk"] = 30
		arena.player.apply_run_modifiers(arena.player.run_state)
		_check(projectile.request.magic_damage == frozen.magic_damage and projectile.request.crit_chance == frozen.crit_chance and projectile.request.hit_rating == frozen.hit_rating and arena.player.skill_cooldown(SHOT) == frozen_cd, "in-flight damage/crit and committed CD frozen despite attribute changes")
		var hit: Array[DamageRequest] = []
		projectile.hit.connect(func(request: DamageRequest, _actor: CombatActor) -> void: hit.append(request.copy()))
		projectile._process(2.0)
		_check(hit.size() == 1 and actor.health.current_hp < 10000.0 and selected.health.current_hp == 10000.0, "selected target cannot redirect directional shot off cursor line")
		if not hit.is_empty():
			_check(hit[0].magic_damage == frozen.magic_damage and hit[0].emission_id == frozen.emission_id, "impact retains launch power and action identity")
	arena.queue_free()
	await process_frame
	_check(get_nodes_in_group("player_projectiles").is_empty(), "scene cleanup removes finite shot")

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (%.6f vs %.6f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Sentinel S3: " + label)
