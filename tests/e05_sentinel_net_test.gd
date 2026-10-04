extends SceneTree
## S4 Net: paid projectile/area, canonical root and pre-control impact ordering.

const NET := &"sentinel_net_shot"
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_math()
	await _preparation()
	await _ranks_and_controls()
	await _projectile_matrix()
	await _procs_and_positive_damage()
	print("Sentinel S4 Net: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _math() -> void:
	var low := StatCalculator.calculate({&"int": 10, &"dex": 10, &"luk": 5})
	var dex := StatCalculator.calculate({&"int": 10, &"dex": 40, &"luk": 5})
	var intelligence := StatCalculator.calculate({&"int": 40, &"dex": 10, &"luk": 5})
	for rank: int in range(1, 6):
		_close(SentinelMath.raw_power(NET, rank, low), SentinelMath.raw_power(NET, rank, dex), "R%d DES cannot leak into INT-only Net damage through MATK" % rank)
		_check(SentinelMath.raw_power(NET, rank, intelligence) > SentinelMath.raw_power(NET, rank, low), "R%d INT improves impact" % rank)
		_check(SentinelMath.cooldown(NET, 10.0, dex) < SentinelMath.cooldown(NET, 10.0, low), "R%d DES improves local cadence" % rank)
		_close(float(SentinelTuning.values(NET, rank)["root_duration"]), 1.0 + 0.25 * (rank - 1), "R%d root duration rank benefit" % rank)

func _scene(rank: int = 5, openings: bool = false) -> RunController:
	var build := BuildSnapshot.new()
	build.character_id = "sentinel-net-fixture"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel"
	build.base_level = 20
	build.job_level = 40
	build.attribute_allocations = {&"int": 20, &"dex": 20, &"luk": 10}
	build.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"archer", &"sentinel")
	build.skill_ranks = {NET: rank, &"sentinel_opening_read": 3}
	build.active_slots = [NET, null, null, null, null]
	build.passive_slots = [&"sentinel_opening_read" if openings else null, null]
	RunController.pending_run_state = RunState.from_build("", build)
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
	arena.enemies.clear()
	return arena

func _victim(arena: RunController, point: Vector2, boss: bool = false) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("S4 alvo", Color.WHITE, StatCalculator.calculate({&"vit": 0, &"int": 0}))
	actor.position = point
	actor.health.max_hp = 10000.0
	actor.health.current_hp = 10000.0
	actor.hard_controls.configure(boss)
	actor.health.damage_applied.connect(arena._on_enemy_damage_resolved)
	arena.add_child(actor)
	actor.set_process(false)
	arena.enemies.append(actor)
	return actor

func _launch(arena: RunController, point: Vector2) -> SentinelAreaProjectile:
	_check(arena.player.use_sentinel_net(point), "Net transaction emits valid paid launch")
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(projectiles.size() == 1 and projectiles[0] is SentinelAreaProjectile, "Net emits exactly one real area projectile")
	if projectiles.is_empty():
		return null
	var projectile := projectiles[0] as SentinelAreaProjectile
	projectile.set_process(false)
	return projectile

func _finish(arena: RunController) -> void:
	paused = false
	arena.queue_free()
	await process_frame

func _preparation() -> void:
	for condition: String in ["cancel", "move", "commit", "sp_revalidate", "placement_revalidate", "cooldown_revalidate", "pause"]:
		var arena := _scene()
		var player := arena.player
		var point := Vector2(450, 350)
		var sp := player.current_sp
		_check(player.begin_skill_cast(NET, point), "%s starts short Net preparation" % condition)
		_check(player.active_cast_total > 0.0 and player.active_cast_total <= 0.25 and player.current_sp == sp and player.skill_cooldown(NET) == 0.0 and player.sentinel_state.focus == 0.0, "preview/preparation is free, DES reduces cast, no Focus prerequisite")
		match condition:
			"cancel": player.cancel_active_cast()
			"move": player.move_to(Vector2(250, 350))
			"sp_revalidate": player.current_sp = 0.0
			"placement_revalidate": arena.navigation.configure(Rect2(0, 0, 1800, 1000), [Rect2(430, 310, 40, 80)], 20.0)
			"cooldown_revalidate": player.mage_cooldowns[NET] = 2.0
			"pause":
				paused = true
				var timer := player.active_cast_remaining
				player._process(1.0)
				_check(player.active_cast_remaining == timer and player.current_sp == sp and get_nodes_in_group("player_projectiles").is_empty(), "pause freezes preparation and cannot launch")
				paused = false
				player.cancel_active_cast()
		var regen := player.stat_breakdown.value(&"sp_regen")
		player._process(0.5)
		var emitted := get_nodes_in_group("player_projectiles")
		if condition == "commit":
			_check(emitted.size() == 1 and player.current_sp <= sp - player.skill_cost(NET) + regen * 0.5 and player.skill_cooldown(NET) > 0.0, "completed preparation commits once after revalidation")
			_check(not player.has_active_cast(), "release clears cast intent")
		else:
			_check(emitted.is_empty(), "%s does not launch a stale/invalid command" % condition)
			if condition in ["cancel", "move", "pause", "placement_revalidate"]:
				_check(player.current_sp == sp and player.skill_cooldown(NET) == 0.0, "%s failure/cancel costs no SP/CD" % condition)
		await _finish(arena)

func _ranks_and_controls() -> void:
	for rank: int in range(1, 6):
		var arena := _scene(rank)
		var victim := _victim(arena, Vector2(440, 350))
		var sp := arena.player.current_sp
		var projectile := _launch(arena, Vector2(440, 350))
		if projectile != null:
			_check(projectile.request.magic_damage > 0.0 and projectile.request.physical_damage == 0.0 and projectile.request.can_crit and not projectile.request.force_critical and projectile.request.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "R%d Net direct magical normal crit contract" % rank)
			_close(arena.player.current_sp, sp - arena.player.skill_cost(NET), "R%d SP paid once" % rank)
			_check(arena.player.sentinel_state.focus == 0.0, "R%d Net costs zero Focus" % rank)
			projectile._process(1.0)
			_close(victim.root_remaining(), 1.0 + 0.25 * (rank - 1), "R%d real Net applies magic-channel root" % rank)
			_check(victim.health.current_hp < 10000.0 and not victim.is_stunned(), "R%d Net damages and roots without stun" % rank)
		var boss := _victim(arena, Vector2(500, 500), true)
		var request := DamageRequest.new()
		request.source_id = arena.player.get_instance_id()
		request.skill_id = NET
		request.emission_id = 300 + rank
		request.magic_damage = 10.0
		request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		request.can_crit = false
		for application: int in range(3):
			arena._on_sentinel_burst(boss.position, request, SentinelTuning.values(NET, rank))
			_close(boss.root_remaining(), 1.0 if application < 2 else 0.0, "R%d boss cap/budget application%d" % [rank, application])
			boss.hard_controls.advance(1.01)
		_check(boss.hard_controls.boss_budget_remaining == 0.0 and boss.health.current_hp < 10000.0, "exhausted boss CC budget does not cancel damage")
		await _finish(arena)
	var arena := _scene()
	var archer := EnemyActor.new()
	archer.configure(&"archer", arena.navigation, arena.player)
	archer.position = arena.player.position + Vector2(200, 0)
	arena.add_child(archer)
	archer.set_process(false)
	archer.apply_root(2.0, &"magic")
	var shots: Array[DamageRequest] = []
	archer.attack_requested.connect(func(request: DamageRequest, _target: CombatActor, _ranged: bool) -> void: shots.append(request.copy()))
	var start := archer.position
	archer._process(0.1)
	_check(archer.position == start and shots.size() == 1 and archer.is_rooted(), "rooted real enemy cannot move but still fires ordinary attack")
	await _finish(arena)

func _projectile_matrix() -> void:
	for hz: int in [0, 30, 60, 144]:
		for collision: String in ["endpoint", "first_body", "wall"]:
			var arena := _scene()
			var near := _victim(arena, Vector2(350, 350))
			var far := _victim(arena, Vector2(490, 350))
			if collision == "endpoint":
				near.position = Vector2(450, 500)
				far.position = Vector2(550, 450)
			elif collision == "wall":
				near.position = Vector2(310, 410)
				far.position = Vector2(410, 350)
				arena.navigation.configure(Rect2(0, 0, 1800, 1000), [Rect2(360, 290, 20, 140)], 20.0)
			var projectile := _launch(arena, Vector2(500, 350))
			if projectile != null:
				var bursts: Array[Vector2] = []
				projectile.burst.connect(func(center: Vector2, _request: DamageRequest, _payload: Dictionary) -> void: bursts.append(center))
				for _frame: int in (hz if hz > 0 else 1):
					projectile._process(1.0 / hz if hz > 0 else 1.0)
				_check(bursts.size() == 1 and projectile.opened and projectile.is_queued_for_deletion(), "%dHz %s opens once at first contact or endpoint" % [hz, collision])
				if not bursts.is_empty():
					if collision == "endpoint":
						_check(bursts[0].distance_to(Vector2(500, 350)) < 0.001, "empty flight reaches ground endpoint exactly")
					elif collision == "first_body":
						_check(bursts[0].x < near.position.x and near.is_rooted() and far.health.current_hp == 10000.0, "first body opens early, far endpoint actor outside actual area unaffected")
					else:
						_check(bursts[0].x < 360.0 and far.health.current_hp == 10000.0 and not far.is_rooted(), "terrain contact opens on near side, radial LoS prevents through-wall damage/root")
			await _finish(arena)
	var arena := _scene()
	var projectile := _launch(arena, Vector2(1500, 350))
	if projectile != null:
		var frozen_power := projectile.request.magic_damage
		var frozen_crit := projectile.request.crit_chance
		var frozen_cd := arena.player.skill_cooldown(NET)
		arena.player.run_state.build_snapshot.attribute_allocations[&"int"] = 40
		arena.player.run_state.build_snapshot.attribute_allocations[&"dex"] = 40
		arena.player.run_state.build_snapshot.attribute_allocations[&"luk"] = 30
		arena.player.apply_run_modifiers(arena.player.run_state)
		_check(projectile.request.magic_damage == frozen_power and projectile.request.crit_chance == frozen_crit and arena.player.skill_cooldown(NET) == frozen_cd, "in-flight Net damage/crit and committed CD retain the launch snapshot")
		_check(projectile.endpoint == arena.player.position + Vector2(arena.player.skill_range(NET), 0) + PlayerProjectile.BODY_OFFSET, "far cursor is clamped to finite range with body-height offset")
		var start := projectile.position
		paused = true
		projectile._process(1.0)
		_check(projectile.position == start and not projectile.opened, "pause freezes actual area projectile")
		paused = false
		projectile._process(1.0)
		_check(projectile.opened and projectile.travelled <= projectile.max_distance, "clamped endpoint opens within its finite travel budget")
		arena._show_result(false)
		_check(arena.player.sentinel_state.focus == 0.0 and paused, "result cleans Focus while pausing visual/projectile clocks")
	await _finish(arena)
	_check(get_nodes_in_group("player_projectiles").is_empty() and get_nodes_in_group("player_effects").is_empty(), "scene cleanup leaves no Net projectile/burst orphans")

func _procs_and_positive_damage() -> void:
	var arena := _scene(5, true)
	var victim := _victim(arena, Vector2(430, 350))
	var other := _victim(arena, Vector2(460, 350))
	var shielded := _victim(arena, Vector2(430, 390))
	shielded.health.grant_shield(1000.0)
	arena.enemies.append(victim)
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.skill_id = NET
	request.emission_id = 100
	request.magic_damage = 10.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	var hits: Array[Dictionary] = []
	victim.health.damage_applied.connect(func(result: Dictionary) -> void: hits.append(result.duplicate()))
	arena._on_sentinel_burst(victim.position, request, SentinelTuning.values(NET, 5))
	_check(hits.size() == 1 and victim.health.current_hp == 9990.0 and other.health.current_hp == 9990.0, "radial dedup damages each victim once, including primary contact")
	_check(victim.is_rooted() and other.is_rooted() and not shielded.is_rooted() and shielded.health.current_hp == 10000.0, "only positive actual HP damage applies root, not a fully absorbed hit")
	_check(arena.player.sentinel_state.focus == 0.0, "newly applied root cannot qualify its own noncritical impact")
	request.emission_id = 101
	arena._on_sentinel_burst(victim.position, request, SentinelTuning.values(NET, 5))
	_check(arena.player.sentinel_state.focus == 4.0, "later AoE sees preexisting root but opening pays once for whole emission")
	victim.hard_controls.clear()
	other.hard_controls.clear()
	arena.player.sentinel_state.advance(1.0, true, true)
	request.emission_id = 102
	request.can_crit = true
	request.force_critical = true # Isolated proc fixture; real launch retains normal crit.
	arena._on_sentinel_burst(victim.position, request, SentinelTuning.values(NET, 5))
	_check(arena.player.sentinel_state.focus == 8.0, "critical Net can proc without preexisting root, once per AoE")
	var immune := _victim(arena, Vector2(900, 600), true)
	immune.hard_controls.boss_budget_remaining = 0.0
	request.emission_id = 103
	request.force_critical = false
	request.can_crit = false
	arena.player.sentinel_state.advance(1.0, true, true)
	arena._on_sentinel_burst(immune.position, request, SentinelTuning.values(NET, 5))
	_check(not immune.is_rooted() and immune.health.current_hp < 10000.0 and arena.player.sentinel_state.focus == 8.0, "boss control failure grants neither root nor fictitious control proc")
	var edge := _victim(arena, Vector2(1107, 800))
	var outside := _victim(arena, Vector2(1109, 800))
	request.emission_id = 104
	arena._on_sentinel_burst(Vector2(1000, 800), request, SentinelTuning.values(NET, 5))
	_check(edge.is_rooted() and edge.health.current_hp < 10000.0, "radial area includes body that overlaps 90 radius with its collider")
	_check(not outside.is_rooted() and outside.health.current_hp == 10000.0, "body beyond radius plus collider remains unaffected")
	await _finish(arena)

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (%.6f vs %.6f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Sentinel S4 Net: " + label)
