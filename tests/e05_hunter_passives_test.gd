extends SceneTree
## H5 directed transactions, not a live-AI or visual acceptance test.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_math_and_claims()
	await _runtime_snapshots()
	await _control_timing()
	print("Hunter passives: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _math_and_claims() -> void:
	var stats := StatCalculator.calculate(IdentityIds.initial_attributes(&"archer"), {&"dex": 30, &"int": 35}, 30)
	for rank: int in [1, 2, 3]:
		var precision := HunterMath.discipline_raw(rank, stats)
		var easy := HunterMath.easy_prey_bonus(rank)
		_check(is_equal_approx(precision, stats.value(&"precision_attack") * [0.05, 0.10, 0.15][rank - 1]), "discipline exact legal rank scalar")
		_check(is_equal_approx(easy, [0.08, 0.12, 0.16][rank - 1]), "easy prey exact legal rank scalar")
		for bow_id: StringName in HunterOpeningState.BOW_SKILLS:
			for marked: bool in [false, true]:
				for controlled: bool in [false, true]:
					var state := HunterOpeningState.new()
					state.configure(1)
					if marked:
						_check(state.mark(2, 5), "mark fixture")
					var opening := HunterMath.opening_request(1, &"snare_trap", 2, stats, 1.3)
					_check(state.activate(10, 2, opening), "opening activation")
					var result := _result(bow_id, precision, easy)
					var payload := state.consume(result, controlled)
					_check(not payload.is_empty(), "all six direct bow actions exploit")
					if payload.is_empty(): continue
					var request: DamageRequest = payload["request"]
					var expected := opening.physical_damage * (1.25 if marked else 1.0) * (1.0 + easy if marked or controlled else 1.0) + precision
					_check(is_equal_approx(request.physical_damage, expected), "mark/easy affect INT only, not discipline")
					_check(request.damage_dealt_multiplier == 1.3 and request.is_secondary and not request.can_crit and request.magic_damage == 0.0, "one secondary retains captured multiplier and no crit")
					var resolved := CombatMath.resolve(request, 100.0, 999.0, 999.0, 0.0, 0.0, 0.0)
					_check(resolved["damage"] == maxi(1, floori(expected * 0.5 * 1.3 + 0.5)) and not resolved["critical"] and not resolved["can_trigger_effects"], "single canonical defense/rounding, no cascade")
					_check(state.consume(result, true).is_empty(), "same emission/victim never duplicates reward")
					_check(state.activate(11, 2, opening) and state.consume(result, true).is_empty() and not state.opening(2).is_empty(), "replacement cannot bypass emission claim")
	for rank: int in [-1, 0, 4, 99]:
		_check(HunterMath.discipline_raw(rank, stats) == 0.0 and HunterMath.easy_prey_bonus(rank) == 0.0, "invalid passive ranks confer no power")
	_check(HunterMath.discipline_raw(3, null) == 0.0, "null stats confer no discipline")
	for bad: Dictionary in [
		{"hunter_precision_damage": NAN}, {"hunter_precision_damage": -1.0},
		{"hunter_easy_prey_bonus": INF}, {"hunter_easy_prey_bonus": -0.01}, {"hunter_easy_prey_bonus": 0.17},
		{"source_id": 99}, {"actual_damage": 0.0}, {"can_trigger_effects": false},
		{"skill_id": &"hunter_thorn_trap"}, {"skill_id": &"hunter_exploit"},
	]:
		var state := HunterOpeningState.new()
		state.configure(1)
		state.activate(1, 2, HunterMath.opening_request(1, &"snare_trap", 1, stats, 1.0))
		var invalid := _result(&"basic_attack", 20.0, 0.16)
		invalid.merge(bad, true)
		_check(state.consume(invalid, true).is_empty() and not state.opening(2).is_empty() and state._emissions.is_empty(), "invalid snapshot/trigger leaves opening and ledgers untouched")
	var expired := HunterOpeningState.new()
	expired.configure(1)
	expired.mark(2, 1)
	expired.activate(1, 2, HunterMath.opening_request(1, &"snare_trap", 1, stats, 1.0))
	expired.mark_remaining = 0.01
	expired.advance(0.02)
	var captured: DamageRequest = expired.opening(2)["request"]
	var claim := expired.consume(_result(&"basic_attack", 10.0, 0.16))
	_check(is_equal_approx(claim["request"].physical_damage, captured.physical_damage + 10.0), "expired live mark cannot qualify Easy Prey; captured mark bonus remains")

func _result(skill_id: StringName, precision: float, easy: float) -> Dictionary:
	return {"source_id": 1, "target_id": 2, "emission_id": 20, "skill_id": skill_id, "actual_damage": 10.0, "can_trigger_effects": true, "hunter_precision_damage": precision, "hunter_easy_prey_bonus": easy}

func _build(job: int = 40, evolution: StringName = &"hunter", passive_rank: int = 3) -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "hunter-passives-isolated"
	build.base_class_id = &"archer"
	build.evolution_id = evolution
	build.base_level = 30
	build.job_level = job
	build.attribute_allocations = {&"dex": 30, &"int": 35}
	build.skill_ranks = {&"double_shot": 1, &"piercing_arrow": 1, &"arrow_rain": 1, &"slowing_arrow": 1, &"snare_trap": 1, &"hunter_covering_shot": 1, &"hunter_shooting_discipline": passive_rank, &"hunter_easy_prey": passive_rank}
	return build

func _player(build: BuildSnapshot) -> PlayerActor:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 800), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("", build))
	player.position = Vector2(300, 300)
	root.add_child(player)
	player.set_process(false)
	return player

func _victim(player: PlayerActor) -> CombatActor:
	var victim := CombatActor.new()
	victim.setup("Presa", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 20.0)
	victim.position = player.position + Vector2(100, 0)
	root.add_child(victim)
	victim.set_process(false)
	victim.health.max_hp = 10000.0
	victim.health.current_hp = 10000.0
	victim.health.damage_applied.connect(player.record_hunter_damage)
	return victim

func _runtime_snapshots() -> void:
	for job: int in [27, 28, 33, 34, 40]:
		var player := _player(_build(job))
		var request := player._make_physical_request(null, &"basic_attack", 30.0, DamageRequest.AccuracyMode.GEOMETRY, true)
		_check(is_equal_approx(request.hunter_precision_damage, HunterMath.discipline_raw(3, player.stat_breakdown) if job >= 28 else 0.0), "discipline gate and automatic learned passive")
		_check(request.hunter_easy_prey_bonus == (0.16 if job >= 34 else 0.0), "easy prey gate and automatic learned passive")
		_check(player.run_state.build_snapshot.passive_slots.is_empty(), "passives do not need legacy slots")
		player.queue_free()
	await process_frame
	for evolution: StringName in [&"", &"sentinel"]:
		var foreign := _player(_build(40, evolution))
		var request := foreign._make_physical_request(null, &"basic_attack", 30.0, DamageRequest.AccuracyMode.GEOMETRY, true)
		_check(request.hunter_precision_damage == 0.0 and request.hunter_easy_prey_bonus == 0.0, "other archer identities never gain Hunter passives")
		foreign.queue_free()
	await process_frame
	var player := _player(_build())
	var victim := _victim(player)
	var emitted: Array[DamageRequest] = []
	var extras: Array[DamageRequest] = []
	player.precision_projectile_requested.connect(func(_id: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int, _limit: int) -> void: emitted.append(request.copy()))
	player.arrow_rain_requested.connect(func(_point: Vector2, request: DamageRequest) -> void: emitted.append(request.copy()))
	player.slowing_arrow_requested.connect(func(request: DamageRequest, _direction: Vector2, _fraction: float, _duration: float) -> void: emitted.append(request.copy()))
	player.hunter_covering_shot_requested.connect(func(request: DamageRequest, _origin: Vector2, _direction: Vector2) -> void: emitted.append(request.copy()))
	player.status_damage_requested.connect(func(request: DamageRequest, target: CombatActor) -> void:
		extras.append(request.copy())
		target.health.apply(request, 0.0, 0.0)
	)
	player.target = victim
	player._try_basic_attack()
	player.use_double_shot(Vector2.RIGHT)
	player.use_piercing_arrow(Vector2.RIGHT)
	player.use_arrow_rain(victim.position)
	player.use_slowing_arrow(Vector2.RIGHT)
	player.use_hunter_covering_shot(Vector2.RIGHT)
	_check(emitted.size() == 6, "six real emissions use the shared snapshot boundary")
	var precision := HunterMath.discipline_raw(3, player.stat_breakdown)
	for request: DamageRequest in emitted:
		_check(is_equal_approx(request.hunter_precision_damage, precision) and request.hunter_easy_prey_bonus == 0.16 and request.emission_id > 0, "real skill payload keeps both passive powers")
	var trap := player._make_physical_request(null, &"explosive_trap", 30.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_check(trap.hunter_precision_damage == 0.0 and trap.hunter_easy_prey_bonus == 0.0, "trap snapshot has no bow payload")
	var opening := player.hunter_opening_snapshot(&"snare_trap")
	player.activate_hunter_opening(1, victim, opening)
	victim.apply_root(1.0)
	# Mutate only this isolated fixture after emission: no late stat/rank read.
	player.stat_breakdown.derived[&"precision_attack"]["effective"] = 9999.0
	player.run_state.build_snapshot.skill_ranks[&"hunter_easy_prey"] = 1
	var direct := emitted[0].copy()
	direct.target_id = victim.get_instance_id()
	direct.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	direct.force_critical = true
	victim.health.physical_defense = 100.0
	victim.health.shield_hp = 5.0
	var primary := victim.health.apply(direct, 0.0, 0.0)
	_check(primary["critical"] and extras.size() == 1, "critical direct hit emits exactly one noncritical secondary")
	if not extras.is_empty():
		_check(is_equal_approx(extras[0].physical_damage, opening.physical_damage * 1.16 + precision), "flight copies retain emission precision and passive rank")
		_check(not extras[0].can_crit and extras[0].hunter_precision_damage == 0.0 and extras[0].hunter_easy_prey_bonus == 0.0, "secondary payload cannot cascade")
	player.activate_hunter_opening(2, victim, opening)
	victim.health.apply(direct, 0.0, 0.0)
	_check(extras.size() == 1 and not player.hunter_state.opening(victim.get_instance_id()).is_empty(), "projectile duplicates cannot consume a replacement")
	for kind: StringName in [&"miss", &"zero", &"shield", &"secondary"]:
		var blocked := player._make_physical_request(victim, &"basic_attack", 30.0, DamageRequest.AccuracyMode.GEOMETRY, false)
		victim.health.shield_hp = 1000.0 if kind == &"shield" else 0.0
		if kind == &"miss": blocked.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
		if kind == &"zero": blocked.physical_damage = 0.0
		if kind == &"secondary": blocked.is_secondary = true
		victim.health.apply(blocked, 1.0 if kind == &"miss" else 0.0, 1.0)
		_check(extras.size() == 1 and not player.hunter_state.opening(victim.get_instance_id()).is_empty(), "miss/zero/full shield/secondary cannot claim")
	victim.health.shield_hp = 0.0
	var terminal := player._make_physical_request(victim, &"basic_attack", 100000.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	player.hunter_state.step_cooldown = 0.0
	victim.health.apply(terminal, 0.0, 0.0)
	_check(not victim.is_alive() and player.hunter_state.opening(victim.get_instance_id()).is_empty() and extras.size() == 1 and player.hunter_state.step_remaining > 0.0, "lethal direct hit claims step without damaging corpse")
	player.queue_free()
	victim.queue_free()
	await process_frame

func _control_timing() -> void:
	RunController.pending_run_state = RunState.from_build("", _build())
	RunController.pending_run_facade = null
	RunController.pending_training_mode = false
	var controller := RunController.new()
	root.add_child(controller)
	controller.set_process(false)
	var player := controller.player
	player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.clear_statuses()
		enemy.health.max_hp = 10000.0
		enemy.health.current_hp = 10000.0
	var victim := controller.enemies[0]
	victim.configure_hard_control_profile(false)
	var extras: Array[DamageRequest] = []
	player.status_damage_requested.connect(func(request: DamageRequest, _target: CombatActor) -> void: extras.append(request.copy()))
	for condition: StringName in [&"own_slow", &"slow", &"root", &"stun", &"fear", &"weaken", &"boss", &"mark"]:
		victim.clear_statuses()
		victim.configure_hard_control_profile(condition == &"boss")
		player.hunter_state.clear()
		if condition == &"slow": victim.apply_slow(0.2, 1.0)
		if condition == &"root": victim.apply_root(1.0)
		if condition == &"stun": victim.apply_stun(1.0)
		if condition == &"fear": victim.apply_fear(1.0)
		if condition == &"weaken": victim.apply_weaken(0.2, 1.0)
		if condition == &"boss":
			victim.set_unstoppable(10.0)
			_check(victim.apply_root(1.0) == 0.0, "boss control resisted fixture")
		var opening := player.hunter_opening_snapshot(&"snare_trap")
		player.activate_hunter_opening(100 + extras.size(), victim, opening)
		if condition == &"mark": player.hunter_state.mark(victim.get_instance_id(), 1)
		var arrow := player._make_physical_request(victim, &"slowing_arrow", 20.0, DamageRequest.AccuracyMode.GEOMETRY, false)
		controller._on_slowing_arrow_hit(arrow, victim, 0.2, 2.0)
		var qualified := condition not in [&"own_slow", &"weaken"]
		_check(extras.size() > 0 and is_equal_approx(extras[-1].physical_damage, opening.physical_damage * (1.16 if qualified else 1.0) + arrow.hunter_precision_damage), "preexisting control/mark or boss qualify; own new slow and weaken do not: " + str(condition))
		_check(victim.slow_fraction > 0.0, "real slowing arrow applies control only after damage")
	controller.queue_free()
	await process_frame

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
