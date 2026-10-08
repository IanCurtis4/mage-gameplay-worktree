extends SceneTree
## Real actor/controller/HealthState transactions; directed, with AI disabled.
## H2 proves invariants only, not the class's later live-AI solo viability.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _actor_flow()
	await _controller_flow()
	await _defensive_and_lethal()
	await _destructive_area_callback()
	print("Hunter core integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _build() -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "hunter-core-isolated"
	build.base_class_id = &"archer"
	build.evolution_id = &"hunter"
	build.base_level = 30
	build.job_level = 40
	build.attribute_allocations = {&"int": 20, &"dex": 10}
	build.skill_ranks = {&"snare_trap": 1, &"explosive_trap": 1, &"double_shot": 1}
	return build

func _player() -> PlayerActor:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 800), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("", _build()))
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

func _actor_flow() -> void:
	var player := _player()
	var victim := _victim(player)
	var snapshots: Array[DamageRequest] = []
	var extras: Array[DamageRequest] = []
	player.precision_projectile_requested.connect(func(_id: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int, _limit: int) -> void: snapshots.append(request.copy()))
	player.status_damage_requested.connect(func(request: DamageRequest, target: CombatActor) -> void:
		extras.append(request.copy())
		target.health.apply(request, 0.0, 0.0)
	)
	_check(player.is_hunter() and not player.is_sentinel(), "runtime identity is isolated")
	var opening := player.hunter_opening_snapshot(&"snare_trap")
	_check(player.activate_hunter_opening(1, victim, opening), "owned legal trap snapshot opens target")
	player.health.current_hp -= 23.0
	player.current_sp -= 17.0
	player.mage_cooldowns[&"snare_trap"] = 4.0
	var hp := player.health.current_hp
	var sp := player.current_sp
	var ordinary_speed := player.stat_breakdown.value(&"move_speed")
	player.target = victim
	player._try_basic_attack()
	_check(snapshots.size() == 1 and snapshots[0].emission_id > 0, "real auto assigns own action identity")
	var direct := snapshots[0]
	direct.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	direct.target_id = victim.get_instance_id()
	victim.health.apply(direct, 0.0, 0.0)
	_check(extras.size() == 1 and player.hunter_state.opening(victim.get_instance_id()).is_empty(), "real damage callback consumes and emits bonus once")
	_check(extras[0].is_secondary and not extras[0].can_crit, "secondary callback cannot recurse")
	_check(player.stat_breakdown.value(&"move_speed") > ordinary_speed, "step source reaches canonical derived speed")
	_check(player.health.current_hp == hp and player.current_sp == sp and player.skill_cooldown(&"snare_trap") == 4.0, "step grant preserves HP/SP deficits and cooldowns")
	_check(player.activate_hunter_opening(2, victim, opening), "second mechanism opens replacement")
	victim.health.apply(direct, 0.0, 0.0)
	_check(extras.size() == 1 and not player.hunter_state.opening(victim.get_instance_id()).is_empty(), "same action cannot exploit replacement via second projectile")
	paused = true
	player._process(10.0)
	_check(player.hunter_state.step_remaining == 1.5 and player.skill_cooldown(&"snare_trap") == 4.0, "pause freezes actor state and resource timers")
	paused = false
	player._process(1.5)
	_check(player.stat_breakdown.value(&"move_speed") == ordinary_speed and player.health.current_hp == hp, "step expiry restores speed without healing")
	var after_tick_sp := player.current_sp
	player.clear_hunter_state()
	_check(player.current_sp == after_tick_sp and player.hunter_state._openings.is_empty(), "explicit end cleanup preserves resources")
	player.navigation.configure(Rect2(0, 0, 1000, 800), [Rect2(410, 250, 45, 100)], 20.0)
	var blocked := Vector2(500, 300)
	player.mage_cooldowns[&"snare_trap"] = 0.0
	_check(player.navigation.is_walkable(blocked) and not player.can_place_snare_trap(blocked), "Hunter refuses a valid endpoint beyond a blocked line of sight")
	_check(not player.use_snare_trap(blocked) and player.current_sp == after_tick_sp and player.skill_cooldown(&"snare_trap") == 0.0, "blocked line of sight charges neither SP nor cooldown")
	player.activate_hunter_opening(9, victim, opening)
	var lethal_to_owner := DamageRequest.new()
	lethal_to_owner.source_id = victim.get_instance_id()
	lethal_to_owner.target_id = player.get_instance_id()
	lethal_to_owner.physical_damage = 100000.0
	lethal_to_owner.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	lethal_to_owner.can_crit = false
	player.health.apply(lethal_to_owner, 0.0, 1.0)
	_check(not player.is_alive() and player.hunter_state._openings.is_empty() and player.hunter_state._activations.is_empty() and player.hunter_state._emissions.is_empty(), "canonical owner death clears all Hunter claims synchronously")
	player.queue_free()
	victim.queue_free()
	await process_frame

func _controller_flow() -> void:
	RunController.pending_run_state = RunState.from_build("", _build())
	RunController.pending_run_facade = null
	RunController.pending_training_mode = false
	var controller := RunController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.global_position = Vector2(1450, 850)
		# Some debug dummy archetypes grant themselves effects before H2. Remove
		# those deliberately and make health high for directed geometry assertions.
		enemy.clear_statuses()
		enemy.health.max_hp = 10000.0
		enemy.health.current_hp = 10000.0
	var player := controller.player
	var victim := controller.enemies[0]
	var placement := player.global_position + Vector2(100, 0)
	victim.global_position = placement
	victim.configure_hard_control_profile(true)
	victim.set_unstoppable(10.0)
	var sp := player.current_sp
	controller._commit_skill(&"snare_trap", placement)
	var traps := controller.trap_registry.active_traps(player.get_instance_id())
	_check(traps.size() == 1 and traps[0] is SnareTrap, "base trap action still creates reusable runtime")
	_check(player.current_sp == sp - player.skill_cost(&"snare_trap"), "placement spends once")
	var trap := traps[0] as SnareTrap
	trap.set_process(false)
	trap._process(SnareTrap.ARMING_TIME - 0.01)
	_check(player.hunter_state.opening(victim.get_instance_id()).is_empty(), "stationary boss not opened before arming")
	trap._process(0.02)
	_check(not victim.is_rooted() and not player.hunter_state.opening(victim.get_instance_id()).is_empty(), "stationary boss opens after arming despite resisted CC")
	_check(controller.trap_registry.active_count() == 0, "trigger removes mechanism synchronously")
	controller._commit_skill(&"explosive_trap", placement)
	traps = controller.trap_registry.active_traps()
	var explosive := traps[0] as ExplosiveTrap
	explosive.set_process(false)
	_check(explosive.damage_request.physical_damage == HunterMath.explosive_raw(1, player.stat_breakdown) and not explosive.damage_request.can_crit, "Hunter explosive uses INT snapshot without changing base skill")
	explosive._process(ExplosiveTrap.ARMING_TIME)
	_check(victim.health.current_hp < 10000.0 and not player.hunter_state.opening(victim.get_instance_id()).is_empty(), "trap direct damage opens but cannot consume its own opening")
	var hp := player.health.current_hp
	var sp_invalid := player.current_sp
	player.mage_cooldowns[&"snare_trap"] = 0.0
	_check(not player.use_snare_trap(Vector2(NAN, 0)) and player.current_sp == sp_invalid, "invalid point rejected atomically")
	player.clear_hunter_state()
	_check(player.health.current_hp == hp, "controller cleanup does not refill HP")
	controller.queue_free()
	await process_frame

func _defensive_and_lethal() -> void:
	for reason: String in ["miss", "zero", "shield", "secondary", "foreign", "paused", "lethal", "death"]:
		var player := _player()
		var victim := _victim(player)
		player.activate_hunter_opening(1, victim, player.hunter_opening_snapshot(&"snare_trap"))
		var request := player._make_physical_request(victim, &"basic_attack", 20.0, DamageRequest.AccuracyMode.GEOMETRY, false)
		var extras: Array[DamageRequest] = []
		player.status_damage_requested.connect(func(extra: DamageRequest, _target: CombatActor) -> void: extras.append(extra))
		match reason:
			"miss": request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
			"zero": request.physical_damage = 0.0
			"shield": victim.health.shield_hp = 100.0
			"secondary": request.is_secondary = true
			"foreign": request.source_id = victim.get_instance_id()
			"paused": paused = true
			"lethal": victim.health.current_hp = 1.0
			"death": player.health.current_hp = 0.0
		victim.health.apply(request, 1.0 if reason == "miss" else 0.0, 1.0)
		_check(extras.is_empty(), reason + " emits no invalid extra to victim")
		if reason == "lethal":
			_check(player.hunter_state.step_remaining == 1.5 and player.hunter_state.opening(victim.get_instance_id()).is_empty(), "lethal arrow claims intrinsic mobility before death callbacks")
		else:
			_check(player.hunter_state.step_remaining == 0.0 and not player.hunter_state.opening(victim.get_instance_id()).is_empty(), reason + " does not consume opening")
		paused = false
		player.queue_free()
		victim.queue_free()
		await process_frame

func _destructive_area_callback() -> void:
	var player := _player()
	var first := _victim(player)
	var second := _victim(player)
	var victims: Array[CombatActor] = [first, second]
	var request := player._make_physical_request(null, &"explosive_trap", 20.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var explosive := ExplosiveTrap.new()
	explosive.configure_explosive(player.get_instance_id(), first.global_position, request, victims)
	root.add_child(explosive)
	explosive.set_process(false)
	var hits := []
	explosive.hit.connect(func(_request: DamageRequest, target: CombatActor) -> void:
		hits.append(target.get_instance_id())
		if target == first:
			second.free()
	)
	explosive._process(ExplosiveTrap.ARMING_TIME)
	_check(hits.size() == 1, "explosion revalidates victim freed by earlier callback")
	player.queue_free()
	first.queue_free()
	await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
