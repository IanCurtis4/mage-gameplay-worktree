extends SceneTree
## Actual actor transactions and HealthState callbacks with deterministic rolls.
## Moving rotations apply emitted requests immediately, not real flight/AI/input;
## they measure paid resource supply, not DPS, global speed or human game feel.

const HEAD := &"sentinel_headshot"
const PIERCE := &"sentinel_piercing_shot"
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _real_emissions()
	await _eligibility()
	await _additional_and_area()
	for hz: int in [30, 60, 144]:
		await _moving_rotation(hz)
	print("Sentinel solo integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _build(additional: bool = false) -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "sentinel-solo-integration"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel"
	build.base_level = 30
	build.job_level = 40
	build.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"archer", &"sentinel")
	build.attribute_allocations = {&"agi": 20, &"int": 20, &"dex": 20}
	build.skill_ranks = {HEAD: 1, PIERCE: 1}
	if additional:
		build.skill_ranks[&"sentinel_observe"] = 5
		build.skill_ranks[&"sentinel_opening_read"] = 3
	# Both legacy selection arrays deliberately empty: learned/legal skills and
	# automatic passives, not the old five-plus-two array, are authoritative.
	return build

func _fixture(additional: bool = false) -> PlayerActor:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 800), [], 20.0)
	var player := PlayerActor.new()
	player.position = Vector2(400, 300)
	player.configure(navigation, RunState.from_build("", _build(additional)))
	root.add_child(player)
	player.set_process(false)
	player.sentinel_combat_active = true
	return player

func _victim(player: PlayerActor, offset := Vector2(0, 100)) -> CombatActor:
	var victim := CombatActor.new()
	victim.setup("Alvo solo", Color.WHITE, player.stat_breakdown)
	victim.position = player.position + offset
	root.add_child(victim)
	victim.set_process(false)
	victim.health.max_hp = 100000.0
	victim.health.current_hp = 100000.0
	victim.health.damage_applied.connect(player.record_sentinel_damage)
	return victim

func _request(player: PlayerActor, victim: CombatActor, emission: int = 100) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = player.get_instance_id()
	request.target_id = victim.get_instance_id()
	request.emission_id = emission
	request.physical_damage = 10.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	return request

func _apply(request: DamageRequest, victim: CombatActor, missed: bool = false, critical: bool = false) -> Dictionary:
	var copy := request.copy()
	copy.target_id = victim.get_instance_id()
	return victim.health.apply(copy, 1.0 if missed else 0.0, 0.0 if critical else 1.0)

func _real_emissions() -> void:
	var player := _fixture()
	var victim := _victim(player)
	var autos: Array[DamageRequest] = []
	var specials: Array[DamageRequest] = []
	player.precision_projectile_requested.connect(func(_id: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int, _hits: int) -> void: autos.append(request.copy()))
	player.sentinel_projectile_requested.connect(func(request: DamageRequest, _target: CombatActor, _direction: Vector2, _payload: Dictionary) -> void: specials.append(request.copy()))
	_check(player.available_skill_ids().has(HEAD) and player.available_skill_ids().has(PIERCE), "learned legal actives work without legacy loadout entries")
	player.target = victim
	player._try_basic_attack()
	_check(autos.size() == 1, "real basic transaction emits one canonical request")
	if not autos.is_empty():
		var result := _apply(autos[0], victim)
		_check(float(result["actual_damage"]) > 0.0 and result["can_trigger_effects"], "real own auto applies positive direct damage")
		_close(player.sentinel_state.focus, 4.0, "real auto recovers intrinsic Focus without passives")
		_apply(autos[0], victim)
		_close(player.sentinel_state.focus, 4.0, "repeated damage callback cannot pay auto again")
	player.sentinel_state.gain(36.0)
	player._process(0.5)
	var sp := player.current_sp
	_check(player.use_sentinel_reset(PIERCE, victim.position), "real Piercing commits its paid skill")
	_close(player.current_sp, sp - player.skill_cost(PIERCE), "real Piercing costs SP once")
	_close(player.sentinel_state.focus, 20.0, "real Piercing pays twenty Focus at launch")
	if not specials.is_empty():
		_apply(specials[0], victim)
		_close(player.sentinel_state.focus, 24.0, "real skill request earns four only when damage applies")
	player.sentinel_state.gain(16.0)
	player._process(0.5)
	sp = player.current_sp
	var head_focus := player.sentinel_state.focus
	_check(player.use_sentinel_reset(HEAD, victim.position, victim), "real Headshot commits while its Focus is funded")
	_close(player.current_sp, sp - player.skill_cost(HEAD), "real Headshot costs SP once")
	_close(player.sentinel_state.focus, head_focus - 30.0, "real Headshot pays thirty Focus at launch")
	if specials.size() > 1:
		_apply(specials[1], victim)
		_close(player.sentinel_state.focus, head_focus - 26.0, "real Headshot impact returns intrinsic four, not an arbitrary full refund")
	player.queue_free()
	victim.queue_free()
	await process_frame

func _eligibility() -> void:
	for reason: String in ["foreign", "secondary", "zero", "shield", "miss", "paused", "outcombat", "dead_player", "dead_target"]:
		var player := _fixture()
		var victim := _victim(player)
		var request := _request(player, victim)
		match reason:
			"foreign": request.source_id = victim.get_instance_id()
			"secondary": request.is_secondary = true
			"zero": request.physical_damage = 0.0
			"shield": victim.health.shield_hp = 100.0
			"miss": request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
			"paused": paused = true
			"outcombat": player.sentinel_combat_active = false
			"dead_player": player.health.current_hp = 0.0
			"dead_target": victim.health.current_hp = 0.0
		_apply(request, victim, reason == "miss")
		_close(player.sentinel_state.focus, 0.0, reason + " real HealthState result cannot grant intrinsic Focus")
		_check(player.sentinel_state._intrinsic_emissions.is_empty(), reason + " does not consume intrinsic identity or cooldown")
		paused = false
		player.queue_free()
		victim.queue_free()
		await process_frame
	var player := _fixture()
	var victim := _victim(player)
	var source := _request(player, victim)
	victim.status_damage_requested.connect(func(request: DamageRequest, target: CombatActor) -> void: _apply(request, target))
	victim.apply_burn(source, 3.0)
	victim._process(1.1)
	_check(victim.health.current_hp < victim.health.max_hp, "real burning timer applied damage through status signal")
	_close(player.sentinel_state.focus, 0.0, "actual DoT tick remains secondary and cannot recover intrinsic Focus")
	victim.health.current_hp = 1.0
	var result := _apply(_request(player, victim, 101), victim)
	_check(bool(result["killed"]) and not victim.is_alive(), "real damage applied a lethal direct action")
	_close(player.sentinel_state.focus, 4.0, "lethal direct own hit recovers before target death callback")
	player.record_sentinel_damage(result)
	_close(player.sentinel_state.focus, 4.0, "lethal notification repetition cannot pay twice")
	player.sentinel_state.reserved_focus = 4.0
	player.sentinel_state.reserved_sp = 3.0
	player.sentinel_state.explosive_prepared = true
	player.health.current_hp = 0.0
	player._on_health_died(player.get_instance_id())
	_check(player.sentinel_state.focus == 0.0 and player.sentinel_state.intrinsic_cooldown == 0.0 and player.sentinel_state._intrinsic_emissions.is_empty(), "actual player death clears intrinsic resource/timers/ledger")
	_check(player.sentinel_state.reserved_focus == 0.0 and player.sentinel_state.reserved_sp == 0.0, "actual death also clears reservations")
	player.queue_free()
	victim.queue_free()
	await process_frame

func _additional_and_area() -> void:
	var player := _fixture(true)
	var victims: Array[CombatActor] = []
	for index: int in 20:
		victims.append(_victim(player, Vector2(100 + index, 0)))
	var marked := victims[0]
	_check(player.run_state.build_snapshot.has_passive(&"sentinel_opening_read"), "learned Opening is automatic despite empty passive slots")
	_check(player.use_sentinel_observe(marked), "actual Observe marks a legal in-range target")
	for victim: CombatActor in victims:
		victim.apply_root(2.0, &"magic")
		_apply(_request(player, victim, 100), victim)
	_close(player.sentinel_state.focus, 18.0, "twenty actual HP applications pay Observe10 + Opening4 + intrinsic4 once")
	_check(player.sentinel_state.observation_charges == 2, "same emission spends only one mark charge")
	player.sentinel_state.advance(0.5, true, true)
	_apply(_request(player, marked, 100), marked)
	_close(player.sentinel_state.focus, 18.0, "delayed piercing victim after ICD retains emission dedup")
	_apply(_request(player, marked, 101), marked)
	_close(player.sentinel_state.focus, 32.0, "new action gets Observe10 + intrinsic4 while Opening's one-second ICD remains")
	player.sentinel_state.advance(0.5, true, true)
	_apply(_request(player, marked, 102), marked)
	_close(player.sentinel_state.focus, 50.0, "third action earns all three independent channels once")
	_check(player.sentinel_state.observation_charges == 0, "exactly three marked actions exhaust Observe")
	player.queue_free()
	for victim: CombatActor in victims:
		victim.queue_free()
	await process_frame

func _moving_rotation(hz: int) -> void:
	var player := _fixture()
	var boss := _victim(player)
	var totals := {"autos": 0, "headshots": 0, "applied": 0, "returned": 0.0, "spent": 0.0, "sp_spent": 0.0, "distance": 0.0}
	player.precision_projectile_requested.connect(func(_id: StringName, request: DamageRequest, target: CombatActor, _direction: Vector2, _count: int, _hits: int) -> void:
		totals["autos"] += 1
		var before := player.sentinel_state.focus
		var result := _apply(request, target)
		if float(result.get("actual_damage", 0.0)) > 0.0:
			totals["applied"] += 1
		totals["returned"] += player.sentinel_state.focus - before
	)
	player.sentinel_projectile_requested.connect(func(request: DamageRequest, _target: CombatActor, _direction: Vector2, _payload: Dictionary) -> void:
		totals["headshots"] += 1
		var before := player.sentinel_state.focus
		var result := _apply(request, boss)
		if float(result.get("actual_damage", 0.0)) > 0.0:
			totals["applied"] += 1
		totals["returned"] += player.sentinel_state.focus - before
	)
	var goals: Array[Vector2] = [Vector2(250, 250), Vector2(550, 250), Vector2(550, 550), Vector2(250, 550)]
	var goal := goals[0]
	var motionless_frames := 0
	var initial_speed := player.stat_breakdown.value(&"move_speed")
	for frame: int in hz * 60:
		if frame % (hz >> 1) == 0:
			await process_frame
			goal = goals[(frame / (hz >> 1)) % goals.size()]
			player.move_to(goal)
		var before_position := player.position
		player._process(1.0 / hz)
		var walked := player.position.distance_to(before_position)
		totals["distance"] += walked
		if walked < SentinelFocusState.MOVEMENT_EPSILON:
			motionless_frames += 1
		# Real actor auto checks range, APS recovery and same-frame launch guard.
		# Its target is cleared afterwards so navigation stays player-selected.
		player.target = boss
		player._try_basic_attack()
		player.target = null
		if frame % hz == 0 and player.sentinel_state.can_pay(30.0) and player.skill_cooldown(HEAD) <= 0.0:
			var sp := player.current_sp
			if player.use_sentinel_reset(HEAD, boss.position, boss):
				totals["spent"] += 30.0
				totals["sp_spent"] += sp - player.current_sp
				player.move_to(goal)
	_check(totals["autos"] > 20 and totals["headshots"] >= 4, "%d Hz moving solo actor actually emitted basic attacks and funded repeated Headshots" % hz)
	_check(totals["distance"] > 2000.0 and player.sentinel_state.stable_time < 0.5, "%d Hz actual navigation displacement prevents stationary resource supply" % hz)
	_check(motionless_frames <= 10, "%d Hz controlled moving baseline did not hide long stationary generation windows" % hz)
	_close(player.sentinel_state.focus, float(totals["returned"]) - float(totals["spent"]), "%d Hz final resource equals real applied returns minus real skill payments" % hz)
	_check(float(totals["returned"]) <= 4.0 * float(totals["applied"]), "%d Hz intrinsic resource is bounded per applied emission" % hz)
	_check(float(totals["spent"]) <= float(totals["returned"]) and player.sentinel_state.focus >= 0.0, "%d Hz no resource borrowing or infinite reset funding" % hz)
	_close(float(totals["sp_spent"]), float(totals["headshots"]) * player.skill_cost(HEAD), "%d Hz actual SP transaction is paid for every successful reset" % hz)
	_close(player.stat_breakdown.value(&"move_speed"), initial_speed, "%d Hz global movement speed was not modified" % hz)
	_check(boss.is_alive() and boss.health.current_hp < boss.health.max_hp, "%d Hz real HP applications kept one high-HP solo target alive" % hz)
	print("Actual moving actor %d Hz: %d autos, %d Headshots, %d applied, %.0f Focus returned, %.0f paid, %.0f remaining, %.1f distance; immediate deterministic impacts, not flight/AI/DPS" % [hz, totals["autos"], totals["headshots"], totals["applied"], totals["returned"], totals["spent"], player.sentinel_state.focus, totals["distance"]])
	player.queue_free()
	boss.queue_free()
	await process_frame

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (%.6f vs %.6f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Sentinel solo integration: " + label)
