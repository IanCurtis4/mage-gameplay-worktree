extends SceneTree
## S5 Concussion: real reset and damage-first, source-keyed canonical support.

const CONC := &"sentinel_concussion_shot"
const DEALT := AttributeDebuffState.DAMAGE_DEALT
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_math()
	await _ranks()
	await _negative_matrix()
	await _control_and_proc()
	await _reservations()
	await _snapshot()
	print("Sentinel S5 Concussion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _math() -> void:
	var low := StatCalculator.calculate({&"int": 10, &"dex": 20, &"luk": 10})
	var intelligence := StatCalculator.calculate({&"int": 40, &"dex": 20, &"luk": 10})
	var dex := StatCalculator.calculate({&"int": 10, &"dex": 40, &"luk": 10})
	for rank: int in range(1, 6):
		_close(SentinelMath.raw_power(CONC, rank, intelligence), SentinelMath.raw_power(CONC, rank, low), "R%d INT cannot scale physical Concussion" % rank)
		_check(SentinelMath.raw_power(CONC, rank, dex) > SentinelMath.raw_power(CONC, rank, low), "R%d precision DES improves low support damage" % rank)
		_close(SentinelMath.cooldown(CONC, 12.0, dex), StatCalculator.effective_cooldown(12.0, dex), "Concussion does not inherit caster-local CD reduction")

func _scene(rank: int = 5, openings: bool = false) -> RunController:
	var build := BuildSnapshot.new()
	build.character_id = "sentinel-concussion-fixture"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel"
	build.base_level = 20
	build.job_level = 40
	build.attribute_allocations = {&"dex": 20, &"luk": 10}
	build.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"archer", &"sentinel")
	build.skill_ranks = {CONC: rank, &"sentinel_headshot": 1, &"sentinel_piercing_shot": 1, &"sentinel_explosive_shot": 1, &"sentinel_opening_read": 3}
	if not openings:
		build.skill_ranks.erase(&"sentinel_opening_read")
	build.active_slots = [CONC, &"sentinel_headshot", &"sentinel_piercing_shot", &"sentinel_explosive_shot", null]
	build.passive_slots = [&"sentinel_opening_read" if openings else null, null]
	RunController.pending_run_state = RunState.from_build("", build)
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.sentinel_combat_active = arena.encounter_active
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena._training_add_elapsed = -1000.0
	arena.navigation.configure(Rect2(0, 0, 1800, 1000), [], 20.0)
	arena.player.position = Vector2(200, 350)
	arena.training_boss.position = Vector2(1500, 800)
	arena.enemies.clear()
	return arena

func _victim(arena: RunController, boss: bool = false, resistance: bool = false) -> CombatActor:
	var actor := CombatActor.new()
	var sources: Array[Dictionary] = []
	if resistance:
		sources.append({"source_id": &"fixture_cc", "flat": {&"magic_cc_resistance": 0.5}})
	actor.setup("S5 alvo", Color.WHITE, StatCalculator.calculate({}, {}, 1, sources))
	actor.position = arena.player.position + Vector2(180, 0)
	actor.health.max_hp = 10000.0
	actor.health.current_hp = 10000.0
	actor.hard_controls.configure(boss)
	actor.health.damage_applied.connect(arena._on_enemy_damage_resolved)
	arena.add_child(actor)
	actor.set_process(false)
	arena.enemies.append(actor)
	return actor

func _launch(arena: RunController, actor: CombatActor) -> SentinelProjectile:
	_check(arena.player.use_sentinel_reset(CONC, actor.position, actor), "Concussion paid reset commits")
	var nodes := get_nodes_in_group("player_projectiles")
	_check(nodes.size() == 1 and nodes[0] is SentinelProjectile, "one special projectile, no common auto")
	if nodes.is_empty():
		return null
	var projectile := nodes[0] as SentinelProjectile
	projectile.set_process(false)
	return projectile

func _request(arena: RunController, actor: CombatActor, emission: int = 100) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.target_id = actor.get_instance_id()
	request.skill_id = CONC
	request.emission_id = emission
	request.physical_damage = 10.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	return request

func _finish(arena: RunController) -> void:
	paused = false
	arena.queue_free()
	await process_frame

func _ranks() -> void:
	for rank: int in range(1, 6):
		for critical: bool in [false, true]:
			var arena := _scene(rank)
			var actor := _victim(arena)
			var player := arena.player
			player.attack_cooldown = 0.5
			var sp := player.current_sp
			var projectile := _launch(arena, actor)
			if projectile != null:
				_check(projectile.homing and projectile.target == actor and projectile.request.physical_damage > 0.0 and projectile.request.magic_damage == 0.0 and projectile.request.accuracy_mode == DamageRequest.AccuracyMode.CONTESTED and projectile.request.can_crit and not projectile.request.force_critical, "R%d physical ST uses canonical accuracy/normal crit" % rank)
				_close(player.current_sp, sp - player.skill_cost(CONC), "R%d charges SP once" % rank)
				_check(player.sentinel_state.focus == 0.0 and player.skill_cooldown(CONC) == 12.0 and player.attack_cooldown > 0.0, "R%d zero Focus, own12sCD and ordinary recovery" % rank)
				player.pursue(actor)
				player._process(0.01)
				_check(get_nodes_in_group("player_projectiles").size() == 1, "no common auto after reset in same frame")
				projectile.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
				projectile.request.can_crit = critical
				projectile.request.force_critical = critical # Control-duration comparison only.
				var observed: Array[bool] = []
				actor.health.damage_applied.connect(func(_result: Dictionary) -> void: observed.append(actor.is_stunned()))
				projectile._process(1.0)
				_check(observed == [false] and actor.health.current_hp < 10000.0, "damage signal precedes newly applied stun")
				_close(actor.stun_remaining(), 0.4 + 0.1 * (rank - 1), "R%d stun exact rank duration, critical=%s never extends it" % [rank, critical])
				_close(actor.attribute_debuffs.fraction(DEALT), 0.10, "Concussion applies ten percent canonical DamageDealt")
				_close(actor.attribute_debuffs.remaining(DEALT, CONC), 2.0 + 0.5 * (rank - 1), "R%d debuff exact rank duration" % rank)
				_close(actor.outgoing_damage_multiplier(), 0.9, "DamageDealt channel reduces outgoing canonical multiplier")
				actor.apply_attribute_debuff(DEALT, &"stronger_fixture", 0.30, 0.1)
				_close(actor.attribute_debuffs.fraction(DEALT), 0.30, "same channel takes strongest source rather than summing")
				actor.attribute_debuffs.advance(0.11)
				_close(actor.attribute_debuffs.fraction(DEALT), 0.10, "Concussion reappears after stronger source expires")
			var boss := _victim(arena, true)
			var request := _request(arena, boss, 1000 + rank)
			request.can_crit = critical
			request.force_critical = critical
			for application: int in range(6):
				var before_budget := boss.hard_controls.boss_budget_remaining
				var duration := 0.4 + 0.1 * (rank - 1)
				arena._on_sentinel_direct_hit(request, boss, SentinelTuning.values(CONC, rank))
				_close(boss.stun_remaining(), minf(duration, before_budget), "R%d boss stun%s application%d obeys remaining shared budget" % [rank, critical, application])
				_close(boss.hard_controls.boss_budget_remaining, maxf(0.0, before_budget - duration), "R%d boss budget charged only disabled interval" % rank)
				boss.hard_controls.advance(duration + 0.01)
			_check(boss.hard_controls.boss_budget_remaining <= 0.0001 and boss.attribute_debuffs.fraction(DEALT) == 0.1, "each rank eventually exhausts boss control, not independent weaken")
			await _finish(arena)

func _negative_matrix() -> void:
	for reason: String in ["miss", "shield", "dead", "lethal"]:
		var arena := _scene()
		var actor := _victim(arena)
		var request := _request(arena, actor)
		match reason:
			"miss":
				request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
				request.hit_rating = 0.0
				actor.health.flee_rating = 1000.0
				for seed: int in range(100):
					var probe := RandomNumberGenerator.new()
					probe.seed = seed
					if probe.randf() > 0.10:
						arena.rng.seed = seed
						break
			"shield": actor.health.grant_shield(100.0)
			"dead": actor.health.current_hp = 0.0
			"lethal": actor.health.current_hp = 1.0
		arena._on_sentinel_direct_hit(request, actor, SentinelTuning.values(CONC, 5))
		_check(not actor.is_stunned() and actor.attribute_debuffs.remaining(DEALT, CONC) == 0.0, "%s impact cannot apply control/debuff without a living damaged victim" % reason)
		if reason in ["miss", "shield"]:
			_check(actor.health.current_hp == 10000.0, "%s causes no actual HP loss" % reason)
		await _finish(arena)
	for reason: String in ["range", "wall", "dead", "stun", "sp"]:
		var arena := _scene()
		var actor := _victim(arena)
		match reason:
			"range": actor.position.x = arena.player.position.x + arena.player.skill_range(CONC) + 1.0
			"wall": arena.navigation.configure(Rect2(0, 0, 1800, 1000), [Rect2(280, 290, 20, 120)], 20.0)
			"dead": actor.health.current_hp = 0.0
			"stun": arena.player.apply_stun(1.0)
			"sp": arena.player.current_sp = 0.0
		var before := [arena.player.current_sp, arena.player.sentinel_state.focus, arena.player.skill_cooldown(CONC), arena.player.attack_cooldown]
		_check(not arena.player.use_sentinel_reset(CONC, actor.position, actor), "%s invalid Concussion refused" % reason)
		_check(before == [arena.player.current_sp, arena.player.sentinel_state.focus, arena.player.skill_cooldown(CONC), arena.player.attack_cooldown] and get_nodes_in_group("player_projectiles").is_empty(), "invalid reset changes no cost/CD/recovery/emission")
		await _finish(arena)

func _control_and_proc() -> void:
	var arena := _scene(5, true)
	var resistant := _victim(arena, false, true)
	var request := _request(arena, resistant)
	arena._on_sentinel_direct_hit(request, resistant, SentinelTuning.values(CONC, 5))
	_close(resistant.stun_remaining(), 0.4, "canonical magic CC resistance halves stun")
	_check(arena.player.sentinel_state.focus == 4.0, "new noncritical stun does not qualify OpeningRead, intrinsic earns4")
	request.emission_id += 1
	arena._on_sentinel_direct_hit(request, resistant, SentinelTuning.values(CONC, 5))
	_check(arena.player.sentinel_state.focus == 8.0, "next action sees preexisting stun and returns one opening, intrinsic still in ICD")
	var boss := _victim(arena, true)
	request = _request(arena, boss, 200)
	for _hit: int in range(3):
		arena._on_sentinel_direct_hit(request, boss, SentinelTuning.values(CONC, 5))
		boss.hard_controls.advance(0.81)
	_check(boss.hard_controls.boss_budget_remaining == 0.0, "repeated boss stun consumes only canonical2s budget")
	request.emission_id = 201
	arena._on_sentinel_direct_hit(request, boss, SentinelTuning.values(CONC, 5))
	_check(not boss.is_stunned() and boss.health.current_hp < 10000.0 and boss.attribute_debuffs.fraction(DEALT) == 0.1, "budget exhaustion suppresses stun but preserves damage and independent weaken")
	resistant.hard_controls.clear()
	arena.player.sentinel_state.advance(1.0, true, true)
	request = _request(arena, resistant, 300)
	request.can_crit = true
	request.force_critical = true
	resistant.apply_root(1.0, &"magic")
	arena._on_sentinel_direct_hit(request, resistant, SentinelTuning.values(CONC, 5))
	_check(arena.player.sentinel_state.focus == 16.0, "critical OR preexisting root pays Opening once plus intrinsic4 after ICD")
	request.emission_id += 1
	arena._on_sentinel_direct_hit(request, resistant, SentinelTuning.values(CONC, 5))
	_check(arena.player.sentinel_state.focus == 16.0, "both opening and intrinsic ICD are shared across later support shots")
	await _finish(arena)

func _reservations() -> void:
	for id: StringName in [&"sentinel_headshot", &"sentinel_piercing_shot", CONC]:
		var arena := _scene()
		var actor := _victim(arena)
		arena.player.sentinel_state.gain(80.0)
		_check(arena.player.prepare_sentinel_explosive(), "actual Explosive reservation prepares")
		var reserved_sp := arena.player.sentinel_state.reserved_sp
		_check(arena.player.use_sentinel_reset(id, actor.position, actor), "%s reset permitted with sufficient free resources" % id)
		_check(arena.player.sentinel_state.explosive_prepared and arena.player.sentinel_state.reserved_focus == 25.0 and arena.player.sentinel_state.reserved_sp == reserved_sp, "%s never consumes/resets prepared ammunition" % id)
		await _finish(arena)

func _snapshot() -> void:
	var arena := _scene(1)
	var actor := _victim(arena)
	var projectile := _launch(arena, actor)
	if projectile != null:
		var power := projectile.request.physical_damage
		arena.player.run_state.skill_levels[CONC] = 5
		arena.player.run_state.build_snapshot.skill_ranks[CONC] = 5
		arena.player._capture_rank_definitions()
		arena.player.run_state.build_snapshot.attribute_allocations[&"dex"] = 40
		arena.player.apply_run_modifiers(arena.player.run_state)
		_check(projectile.request.physical_damage == power, "in-flight physical snapshot never recaptures new rank/stats")
		projectile.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		projectile._process(1.0)
		_close(actor.stun_remaining(), 0.4, "bound launch payload preserves R1 stun after rank changes")
		_close(actor.attribute_debuffs.remaining(DEALT, CONC), 2.0, "bound launch payload preserves R1 weaken duration")
	await _finish(arena)
	_check(get_nodes_in_group("player_projectiles").is_empty() and get_nodes_in_group("player_effects").is_empty(), "cleanup leaves no support projectile/VFX orphan")

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (%.6f vs %.6f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Sentinel S5 Concussion: " + label)
