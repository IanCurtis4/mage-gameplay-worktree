extends SceneTree
## S1: run-only Focus clocks/procs and actual conditional stat integration.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_clock_matrix()
	_resources()
	_observation()
	_openings()
	_absolute_boundaries()
	await _player_clock_matrix()
	await _player_stance()
	await _movement_before_auto()
	await _player_observation()
	print("Sentinel S1 Focus: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _clock_matrix() -> void:
	for hz: int in [30, 60, 144]:
		var state := SentinelFocusState.new()
		for _frame: int in hz * 2:
			state.advance(1.0 / hz, false, true)
		_close(state.focus, 15.0, "%d Hz generates 10/s only after 0.5 s" % hz)
		_close(state.stable_time, 2.0, "%d Hz stability is time, not frames" % hz)
		state.advance(1.0 / hz, true, true)
		_close(state.focus, 15.0, "%d Hz walking preserves resource" % hz)
		_close(state.stable_time, 0.0, "%d Hz actual movement resets preparation" % hz)
		for _frame: int in hz:
			state.advance(1.0 / hz, false, true)
		_close(state.focus, 20.0, "%d Hz stops and prepares again" % hz)
		state.observe(11, 3)
		state.absolute_remaining = 4.0
		state.observation_cooldown = 0.5
		state.opening_cooldown = 1.0
		state.advance(5.0, false, false, true)
		_close(state.focus, 20.0, "%d Hz pause does not generate/decay" % hz)
		_close(state.stable_time, 1.0, "%d Hz pause freezes stability" % hz)
		_check(state.inactive_time == 0.0 and state.absolute_remaining == 4.0 and state.observation_remaining == 8.0 and state.observation_cooldown == 0.5 and state.opening_cooldown == 1.0, "%d Hz pause freezes all clocks" % hz)
		state.advance(3.0, true, false)
		_close(state.focus, 20.0, "%d Hz out of combat grace is 3 seconds" % hz)
		for _frame: int in hz:
			state.advance(1.0 / hz, true, false)
		_close(state.focus, 10.0, "%d Hz decay is 10/s" % hz)
		state.advance(10.0, false, false)
		_check(state.focus == 0.0, "%d Hz decay clamps at zero" % hz)
		state.advance(2.0, true, true)
		_check(state.inactive_time == 0.0 and state.focus == 0.0, "%d Hz combat resets inactivity but walking cannot generate" % hz)
		state.advance(0.5, false, true)
		_check(state.focus == 0.0, "%d Hz preparation boundary is not an initial tick" % hz)
		state.advance(0.5, false, true)
		_close(state.focus, 5.0, "%d Hz ordinary gain resumes" % hz)

func _resources() -> void:
	var state := SentinelFocusState.new()
	_check(state.focus == 0.0 and state.free_focus() == 0.0, "run starts with zero Focus")
	_close(state.gain(120.0), 100.0, "gain reports actual cap-limited amount")
	_close(state.gain(4.0), 0.0, "full Focus cannot overflow")
	state.advance(100.0, false, true)
	_check(state.focus == 100.0, "long stationary delta respects cap")
	for invalid: float in [-1.0, NAN, INF]:
		_check(state.gain(invalid) == 0.0 and not state.spend(invalid), "invalid amount is rejected")
	for invalid: float in [-1.0, 0.0, NAN, INF]:
		state.advance(invalid, true, false)
		_check(state.focus == 100.0 and state.stable_time == 100.0, "invalid delta cannot change clocks or Focus")
	state.reserved_focus = 25.0
	state.reserved_sp = 15.0
	state.explosive_prepared = true
	_check(state.free_focus() == 75.0 and not state.can_pay(76.0), "prepared ammunition excludes reserved Focus")
	_check(state.spend(75.0) and state.focus == 25.0 and not state.spend(1.0), "cannot spend another action's reservation")
	state.cancel_preparation()
	_check(state.free_focus() == 25.0 and state.reserved_sp == 0.0 and not state.explosive_prepared, "cancel releases rather than duplicates resource")
	state.reserved_focus = 25.0
	state.reserved_sp = 15.0
	state.explosive_prepared = true
	state.advance(3.0, false, false)
	_check(state.focus == 25.0 and state.explosive_prepared, "outside combat grace preserves funded reservation")
	state.advance(0.1, false, false)
	_check(absf(state.focus - 24.0) < 0.00001 and not state.explosive_prepared and state.reserved_sp == 0.0 and state.reserved_focus == 0.0, "natural decay releases underfunded reservation without a resource floor")
	state.advance(10.0, false, false)
	_check(state.focus == 0.0, "prepared ammunition cannot prevent out-of-combat decay reaching zero")
	state.observe(10, 5)
	state.direct_impact(1, 10, true, true, true, 3)
	state.absolute_remaining = 4.0
	state.clear()
	_check(state.focus == 0.0 and state.stable_time == 0.0 and state.inactive_time == 0.0 and state.absolute_remaining == 0.0, "cleanup clears Focus and clocks")
	_check(state.observed_target_id == 0 and state.observation_charges == 0 and state.observation_cooldown == 0.0 and state.opening_cooldown == 0.0, "cleanup clears marks and shared cooldowns")
	_check(not state.explosive_prepared and state.reserved_focus == 0.0 and state.reserved_sp == 0.0, "cleanup clears reservations")

func _observation() -> void:
	for rank: int in range(1, 6):
		var state := SentinelFocusState.new()
		_check(state.observe(100, rank), "Observar R%d creates mark" % rank)
		_check(state.observation_remaining == 8.0 and state.observation_charges == 3, "Observar R%d duration/charges fixed" % rank)
		_close(state.direct_impact(1, 101, true, false, false, 0), 0.0, "another victim is not marked")
		_close(state.direct_impact(1, 100, false, true, true, 3), 0.0, "miss/nonpositive/secondary hit cannot proc")
		_close(state.direct_impact(0, 100, true, false, false, 0), 0.0, "missing emission identity cannot proc")
		for charge: int in range(3):
			_close(state.direct_impact(10 + charge, 100, true, false, false, 0), 5.0 + rank, "Observar R%d charge %d actual gain" % [rank, charge])
			_check(state.observation_charges == 2 - charge, "one accepted event consumes one charge")
			_close(state.direct_impact(20 + charge, 100, true, false, false, 0), 0.0, "shared 0.5s cadence prevents extra shot")
			state.advance(0.5, true, true)
			_close(state.direct_impact(10 + charge, 100, true, false, false, 0), 0.0, "same AoE emission cannot consume a second charge after ICD")
		_close(state.direct_impact(1000, 100, true, false, false, 0), 0.0, "three charges exhausted")
		_check(state.observe(101, rank), "new mark replaces old")
		_close(state.direct_impact(1001, 100, true, false, false, 0), 0.0, "replacement removes old target")
		state.advance(8.0, true, true)
		_check(state.observed_target_id == 0 and state.observation_charges == 0, "expired mark is removed without gain")
		_close(state.direct_impact(1002, 101, true, false, false, 0), 0.0, "expired mark cannot grant Focus")
	var state := SentinelFocusState.new()
	for rank: int in [0, 6]:
		_check(not state.observe(20, rank), "invalid observation rank rejected")
	_check(not state.observe(0, 1), "invalid observation target rejected")

func _openings() -> void:
	for rank: int in range(1, 4):
		for flags: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var state := SentinelFocusState.new()
			_close(state.direct_impact(1, 1, true, flags.x == 1, flags.y == 1, rank), 1.0 + rank, "opening R%d is critical OR preexisting CC, not two payments" % rank)
			_close(state.direct_impact(2, 2, true, true, true, rank), 0.0, "opening shared ICD applies across victims and actions")
			state.advance(0.999, true, true)
			_close(state.direct_impact(3, 3, true, true, true, rank), 0.0, "opening cannot recover before 1 second")
			state.advance(0.002, true, true)
			_close(state.direct_impact(1, 4, true, true, true, rank), 0.0, "same AoE cannot pay later for second victim")
			_close(state.direct_impact(4, 4, true, true, true, rank), 1.0 + rank, "new action pays after shared ICD")
	var state := SentinelFocusState.new()
	for rank: int in [0, 4]:
		_close(state.direct_impact(1, 1, true, true, true, rank), 0.0, "unequipped/invalid opening rank cannot proc")
	_close(state.direct_impact(2, 1, true, false, false, 3), 0.0, "newly applied control is not a pre-hit opening")
	state.observe(1, 5)
	_close(state.direct_impact(3, 1, true, true, true, 3), 14.0, "independent mark and opening each pay once")
	state.focus = 98.0
	state.advance(1.0, true, true)
	_close(state.direct_impact(4, 1, true, true, true, 3), 2.0, "combined procs respect resource cap")

func _absolute_boundaries() -> void:
	for hz: int in [30, 60, 144]:
		var state := SentinelFocusState.new()
		state.absolute_remaining = 0.2
		for _frame: int in hz:
			state.advance(1.0 / hz, false, true)
		_close(state.focus, 8.0, "%d Hz short buff splits expired interval and ordinary preparation" % hz)
		var lump := SentinelFocusState.new()
		lump.absolute_remaining = 0.2
		lump.advance(1.0, false, true)
		_close(lump.focus, state.focus, "%d Hz and coarse delta agree across both boundaries" % hz)
		var moving := SentinelFocusState.new()
		moving.absolute_remaining = 4.0
		moving.advance(1.0, true, true)
		_check(moving.focus == 0.0 and moving.absolute_remaining == 3.0, "Absolute never generates while moving")
	var stable := SentinelFocusState.new()
	stable.advance(0.6, false, true)
	stable.absolute_remaining = 0.2
	stable.advance(0.5, false, true)
	_close(stable.focus, 7.0, "buff expiring while stable splits 15/s and 10/s")
	var immediate := SentinelFocusState.new()
	immediate.absolute_remaining = 0.1
	immediate.advance(0.1, false, true)
	_close(immediate.focus, 1.5, "Absolute skips only Focus preparation, no free initial gain")
	_check(immediate.stable_time < SentinelFocusState.STANCE_DELAY, "Absolute does not skip passive stance preparation")

func _fixture(stance_rank: int = 3, stance_equipped: bool = true) -> PlayerActor:
	var build := BuildSnapshot.new()
	build.character_id = "sentinel-focus-fixture"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel"
	build.base_level = 20
	build.job_level = 40
	build.library_skill_ids = [&"sentinel_observe", &"sentinel_precision_stance", &"sentinel_opening_read"]
	build.skill_ranks = {&"sentinel_observe": 5, &"sentinel_precision_stance": stance_rank, &"sentinel_opening_read": 3}
	build.active_slots = [&"sentinel_observe", null, null, null, null]
	build.passive_slots = [&"sentinel_precision_stance" if stance_equipped else null, &"sentinel_opening_read"]
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 20.0)
	var player := PlayerActor.new()
	player.position = Vector2(300, 300)
	player.configure(nav, RunState.from_build(build.character_id, build))
	root.add_child(player)
	player.set_process(false)
	player.sentinel_combat_active = true
	return player

func _player_stance() -> void:
	for rank: int in range(1, 4):
		var player := _fixture(rank)
		var base_dex := player.stat_breakdown.primary_value(&"dex")
		var base_luk := player.stat_breakdown.primary_value(&"luk")
		player._process(0.74)
		_close(player.stat_breakdown.primary_value(&"dex"), base_dex, "R%d stance not active before 0.75s" % rank)
		player._process(0.011)
		_close(player.stat_breakdown.primary_value(&"dex"), base_dex + 3.0 * rank, "R%d stance effective DES via canonical calculator" % rank)
		_close(player.stat_breakdown.primary_value(&"luk"), base_luk + 2.0 * rank, "R%d stance effective SOR via canonical calculator" % rank)
		player.health.current_hp -= 20.0
		player.current_sp -= 10.0
		player.mage_cooldowns[&"sentinel_observe"] = 4.0
		var hp_before := player.health.current_hp
		var sp_before := player.current_sp
		for _recalculation: int in range(4):
			player.apply_run_modifiers(player.run_state)
			_close(player.stat_breakdown.primary_value(&"dex"), base_dex + 3.0 * rank, "recalculations cannot stack stance")
			_check(player.stat_breakdown.sources().filter(func(source: Dictionary) -> bool: return source["source_id"] == &"sentinel_precision_stance").size() == 1, "one identified temporary source")
			_check(player.health.current_hp == hp_before and player.current_sp == sp_before and player.skill_cooldown(&"sentinel_observe") == 4.0, "recalculation does not heal, refill, or reset cooldown")
		player._last_facing = Vector2.LEFT
		player._process(0.01)
		_check(player._sentinel_stance_active, "turning alone is not movement")
		var focus_before := player.sentinel_state.focus
		player.move_to(Vector2(500, 300))
		player._process(0.03)
		_check(player.position.x > 300.0 and not player._sentinel_stance_active, "effective walk removes posture immediately")
		_close(player.stat_breakdown.primary_value(&"dex"), base_dex, "moving removes temporary DES")
		_close(player.sentinel_state.focus, focus_before, "walking preserves Focus without generating")
		player.velocity = Vector2.ZERO
		player._path.clear()
		player._has_path_goal = false
		player._process(0.8)
		_check(player._sentinel_stance_active, "stop restores posture after delay")
		player.position += Vector2(10, 0)
		player._process(0.01)
		_check(not player._sentinel_stance_active and player.sentinel_state.stable_time == 0.0, "external reposition/teleport resets posture and preparation")
		player.sentinel_state.observe(100, 5)
		player.sentinel_state.absolute_remaining = 4.0
		var clock_before := player.sentinel_state.focus
		paused = true
		player._process(4.0)
		_check(player.sentinel_state.focus == clock_before and player.sentinel_state.absolute_remaining == 4.0 and player.sentinel_state.observation_remaining == 8.0, "actual player pause freezes Focus and mark")
		paused = false
		player.clear_sentinel_state()
		_check(player.sentinel_state.focus == 0.0 and not player._sentinel_stance_active, "player cleanup removes resource and posture")
		player.queue_free()
		await process_frame
	var unequipped := _fixture(3, false)
	unequipped._process(1.0)
	_check(not unequipped._sentinel_stance_active, "learned but unequipped posture contributes no source")
	unequipped.queue_free()
	await process_frame

func _player_clock_matrix() -> void:
	for hz: int in [30, 60, 144]:
		var player := _fixture()
		for _frame: int in hz * 2:
			player._process(1.0 / hz)
		_close(player.sentinel_state.focus, 15.0, "actual player %d Hz uses stable clocks" % hz)
		_check(player._sentinel_stance_active, "actual player %d Hz posture activates" % hz)
		player.sentinel_combat_active = false
		for _frame: int in hz * 4:
			player._process(1.0 / hz)
		_close(player.sentinel_state.focus, 5.0, "actual player %d Hz reads canonical combat inactive" % hz)
		player.sentinel_combat_active = true
		# Root blocks actual displacement; a movement intention is not walking.
		player.apply_root(10.0, &"magic")
		player.move_to(Vector2(500, 300))
		var start := player.position
		var before := player.sentinel_state.focus
		player._process(1.0)
		_check(player.position == start and player._sentinel_stance_active, "blocked movement intent preserves posture")
		_close(player.sentinel_state.focus, before + 10.0, "blocked intent can still generate stationary Focus")
		player.queue_free()
		await process_frame

func _movement_before_auto() -> void:
	var player := _fixture()
	var base_precision := player.stat_breakdown.value(&"precision_attack")
	player._process(0.8)
	var shots: Array[DamageRequest] = []
	player.precision_projectile_requested.connect(func(_id: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int, _hits: int) -> void: shots.append(request.copy()))
	var actor := _victim(player, Vector2(350, 0))
	actor.position = player.position + Vector2(player.basic_attack_distance(actor) + 30.0, 0)
	player.pursue(actor)
	player._process(0.5)
	_check(player.position.x > 300.0 and shots.size() == 1, "actual walk into range emits one auto in same update")
	if not shots.is_empty():
		_close(shots[0].physical_damage, base_precision * player.class_definition.basic_power, "moving posture is removed before same-frame auto snapshot")
		_check(shots[0].emission_id > 0, "ordinary Sentinel auto has a distinct emission identity")
	player.target = null
	player.velocity = Vector2.ZERO
	player._path.clear()
	player._has_path_goal = false
	player._process(0.8)
	_check(player._sentinel_stance_active, "posture returns without an attack interrupting stability")
	player.position += Vector2(1, 0)
	player.pursue(actor)
	player.attack_cooldown = 0.0
	shots.clear()
	player._process(0.01)
	_check(shots.size() == 1, "external reposition can attack without a duplicate auto")
	if not shots.is_empty():
		_close(shots[0].physical_damage, base_precision * player.class_definition.basic_power, "teleport removes posture before any auto snapshot")
	player.queue_free()
	actor.queue_free()
	await process_frame

func _victim(player: PlayerActor, offset: Vector2 = Vector2(100, 0)) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("S1 alvo", Color.WHITE, player.stat_breakdown)
	actor.position = player.position + offset
	root.add_child(actor)
	actor.set_process(false)
	return actor

func _hit(player: PlayerActor, actor: CombatActor, emission: int, critical: bool = false, secondary: bool = false, missed: bool = false) -> Dictionary:
	var request := DamageRequest.new()
	request.source_id = player.get_instance_id()
	request.target_id = actor.get_instance_id()
	request.emission_id = emission
	request.physical_damage = 1.0
	request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED if missed else DamageRequest.AccuracyMode.GEOMETRY
	request.crit_chance = 0.75 if critical else 0.0
	request.is_secondary = secondary
	var result := actor.health.apply(request, 1.0 if missed else 0.0, 0.0 if critical else 1.0)
	player.record_sentinel_damage(result)
	return result

func _player_observation() -> void:
	var player := _fixture()
	var actor := _victim(player)
	var other := _victim(player, Vector2(110, 10))
	var sp := player.current_sp
	_check(player.use_sentinel_observe(actor), "actual observe commits on valid target")
	_check(player.current_sp == sp - player.skill_cost(&"sentinel_observe") and player.skill_cooldown(&"sentinel_observe") > 0.0, "observe charges one SP cost/CD and no Focus")
	_check(not player.use_sentinel_observe(other) and player.sentinel_state.observed_target_id == actor.get_instance_id(), "cooldown refusal does not replace mark")
	_hit(player, actor, 1, false, true)
	_hit(player, actor, 2, false, false, true)
	_check(player.sentinel_state.focus == 0.0 and player.sentinel_state.observation_charges == 3, "real resolver secondary and miss cannot recover Focus")
	_hit(player, actor, 3)
	_check(player.sentinel_state.focus == 10.0 and player.sentinel_state.observation_charges == 2, "real direct hit grants mark Focus")
	player.sentinel_state.advance(1.0, true, true)
	_hit(player, actor, 4, true)
	_hit(player, other, 4, true)
	_check(player.sentinel_state.focus == 24.0 and player.sentinel_state.observation_charges == 1, "one AoE action recovers mark and opening once")
	player.sentinel_state.advance(1.0, true, true)
	_hit(player, other, 5)
	other.apply_root(1.0, &"magic")
	_check(player.sentinel_state.focus == 24.0, "noncritical hit followed by new root cannot retroactively qualify")
	_hit(player, other, 6)
	_check(player.sentinel_state.focus == 28.0, "later direct hit sees preexisting root")
	player.sentinel_state.advance(1.0, true, true)
	other.health.current_hp = 0.0
	_hit(player, other, 7, true)
	_check(player.sentinel_state.focus == 28.0, "already dead target cannot emit a valid damage event")
	actor.health.current_hp = 0.0
	player._process(0.001)
	_check(player.sentinel_state.observed_target_id == 0 and player.sentinel_state.observation_charges == 0, "observed target death clears its mark")
	var unreachable := _victim(player, Vector2(1000, 0))
	player.mage_cooldowns[&"sentinel_observe"] = 0.0
	sp = player.current_sp
	_check(not player.use_sentinel_observe(unreachable) and player.current_sp == sp and player.skill_cooldown(&"sentinel_observe") == 0.0, "invalid observe range costs nothing")
	player.sentinel_state.gain(20.0)
	player.sentinel_state.reserved_focus = 25.0
	player.sentinel_state.reserved_sp = 12.0
	player.sentinel_state.explosive_prepared = true
	player.health.current_hp = 0.0
	player._on_health_died(player.get_instance_id())
	_check(player.sentinel_state.focus == 0.0 and player.sentinel_state.reserved_focus == 0.0 and player.sentinel_state.reserved_sp == 0.0 and not player.sentinel_state.explosive_prepared, "actual player death cleans resource/reservations")
	for node: Node in [player, actor, other, unreachable]:
		node.queue_free()
	await process_frame

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) <= 0.0001, "%s (got %.6f expected %.6f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Sentinel S1: " + label)
