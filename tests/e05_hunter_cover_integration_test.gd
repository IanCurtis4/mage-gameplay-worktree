extends SceneTree
## H4 directed transactions plus active enemy pursuit. Not a gameplay/FPS claim.

var checks := 0
var failures := 0

class HunterInputController extends RunController:
	func _world_mouse_point() -> Vector2:
		return Vector2(410, 300)
	func _world_pointer_available() -> bool:
		return true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_mark_snapshots()
	_cover_clocks()
	await _mark_runtime()
	await _shot_runtime()
	await _cover_runtime()
	await _input_modes()
	await _enemy_pursuit_and_projectile()
	await _lifecycle()
	print("Hunter H4 cover integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _build(rank: int = 1) -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "hunter-h4-directed"
	build.base_class_id = &"archer"
	build.evolution_id = &"hunter"
	build.base_level = 30
	build.job_level = 40
	build.attribute_allocations = {&"int": 20, &"dex": 10}
	build.skill_ranks = {&"hunter_mark": rank, &"hunter_covering_shot": rank, &"hunter_total_cover": rank, &"foliage_shelter": 1, &"hunter_freezing_trap": 1, &"double_shot": 1}
	return build

func _controller(rank: int = 1, input_fixture: bool = false) -> RunController:
	RunController.pending_run_state = RunState.from_build("", _build(rank))
	RunController.pending_run_facade = null
	RunController.pending_training_mode = false
	var controller: RunController = HunterInputController.new() if input_fixture else RunController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	controller.navigation.configure(Rect2(0, 0, 1600, 1000), [], 20.0)
	controller.player.global_position = Vector2(300, 300)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.global_position = Vector2(1400, 900)
		enemy.clear_statuses()
		enemy.health.max_hp = 10000.0
		enemy.health.current_hp = 10000.0
	return controller

func _mark_snapshots() -> void:
	var stats := StatCalculator.calculate({&"int": 20})
	var raw := HunterMath.opening_request(1, &"snare_trap", 1, stats, 1.2)
	for rank: int in range(1, 6):
		var state := HunterOpeningState.new()
		state.configure(1)
		var tuning := HunterTuning.values(&"hunter_mark", rank)
		_check(state.mark(2, rank) and state.is_marked(2) and not state.is_marked(3), "one priority per owner")
		_check(state.mark_remaining == float(tuning["duration"]), "ranked mark duration")
		_check(state.activate(10, 2, raw), "marked trap activation")
		var opening := state.opening(2)
		_check(is_equal_approx(opening["remaining"], 4.0 + float(tuning["opening_extension"])), "mark extends captured window up to six")
		var request: DamageRequest = opening["request"]
		_check(is_equal_approx(request.physical_damage, raw.physical_damage * (1.0 + float(tuning["reward_bonus"]))) and request.damage_dealt_multiplier == 1.2 and request.is_secondary and not request.can_crit, "mark changes only raw INT reward")
		state.mark(3, 1)
		_check(not state.is_marked(2) and state.is_marked(3) and state.opening(2)["remaining"] == opening["remaining"], "replacing mark cannot mutate live opening")
		_check((state.opening(2)["request"] as DamageRequest).physical_damage == request.physical_damage, "reward retains activation snapshot")
		_check(not state.activate(10, 2, raw), "duplicate trap cannot refresh marked opening")
		state.advance(3.0, true)
		_check(state.mark_remaining == 6.0, "pause preserves mark")
		state.advance(6.0)
		_check(state.marked_target_id == 0 and state.mark_rank == 0, "expiry removes mark")
		state.mark(2, rank)
		state.discard_target(2)
		_check(not state.is_marked(2) and state.opening(2).is_empty(), "target death clears priority and opening")
		_check(raw.target_id == 0 and is_equal_approx(raw.physical_damage, 36.0), "mark never mutates placement snapshot")
	var state := HunterOpeningState.new()
	state.configure(1)
	_check(not state.mark(1, 1) and not state.mark(2, 0) and not state.mark(2, 6) and not state.mark(0, 1), "invalid mark rejected")
	state.activate(1, 2, raw)
	state.mark(2, 5)
	_check(state.opening(2)["remaining"] == 4.0 and (state.opening(2)["request"] as DamageRequest).physical_damage == raw.physical_damage, "late mark does not upgrade existing opening")

func _cover_clocks() -> void:
	for hz: int in [30, 60, 144]:
		var state := HunterCoverState.new()
		state.bind_zone(1, Vector2.ZERO, 125.0, 1.0)
		_check(not state.is_hidden(Vector2.ZERO), "registration alone cannot grant budget")
		state.begin_cycle()
		state.reveal()
		for frame: int in range(hz * 2):
			state.advance(1.0 / hz, Vector2.ZERO)
		_check(is_equal_approx(state.budget_remaining, 2.25) and state.reveal_remaining == 0.0, "partial reveal boundary integrated at %dHz" % hz)
		state.is_hidden(Vector2(200, 0))
		for frame: int in range(hz):
			state.advance(1.0 / hz, Vector2(200, 0))
		_check(is_equal_approx(state.budget_remaining, 1.25) and state.grace_remaining == 0.0 and not state.is_hidden(Vector2(200, 0)), "exit grace spends same budget at %dHz" % hz)
		state.is_hidden(Vector2.ZERO)
		state.is_hidden(Vector2(200, 0))
		state.reveal(1.25)
		for frame: int in range(hz):
			state.advance(1.0 / hz, Vector2(200, 0))
		_check(is_equal_approx(state.budget_remaining, 1.25) and state.grace_remaining == 0.0, "revealed grace does not consume or extend budget")
		state.advance(0.25, Vector2.ZERO)
		state.advance(1.25, Vector2.ZERO)
		_check(state.budget_remaining == 0.0 and not state.is_hidden(Vector2.ZERO), "three actual seconds exhaust at %dHz" % hz)
		state.bind_zone(2, Vector2.ZERO, 125.0, 1.0)
		_check(not state.is_hidden(Vector2.ZERO), "replacement cannot renew exhaustion")
		state.reveal()
		state.unbind_zone(2)
		state.bind_zone(3, Vector2.ZERO, 110.0, 0.0)
		_check(state.reveal_remaining == 1.25 and state.budget_remaining == 0.0, "remove/re-register cannot clear reveal or renew budget")
		state.advance(100.0, Vector2.ZERO, true)
		state.advance(NAN, Vector2.ZERO)
		state.advance(-1.0, Vector2.ZERO)
		_check(state.reveal_remaining == 1.25, "pause/non-finite/negative clock ignored")
		state.begin_cycle()
		_check(not state.is_hidden(Vector2.ZERO), "paid renewal preserves pending offensive reveal")
		state.clear()
		_check(state.zone_id == 0 and state.budget_remaining == 0.0 and state.reveal_remaining == 0.0, "terminal clear is complete")

func _mark_runtime() -> void:
	for rank: int in range(1, 6):
		var controller := _controller(rank)
		var player := controller.player
		var victim := controller.enemies[0]
		victim.global_position = Vector2(410, 300)
		var sp := player.current_sp
		controller._commit_skill(&"hunter_mark", victim.global_position)
		_check(player.hunter_state.is_marked(victim.get_instance_id()) and player.current_sp == sp - player.skill_cost(&"hunter_mark"), "mark dispatch pays ranked cost once")
		_check(player.skill_cooldown(&"hunter_mark") == StatCalculator.effective_cooldown(10.0, player.stat_breakdown) and player.hunter_cover.reveal_remaining == 1.25, "mark starts canonical cooldown and reveal outside cover")
		_check(not player.use_hunter_mark(victim) and player.current_sp == sp - player.skill_cost(&"hunter_mark"), "mark duplicate commit rejected")
		player.use_hunter_trap(&"hunter_freezing_trap", victim.global_position)
		var trap := controller.trap_registry.active_traps()[0] as HunterTrap
		trap.set_process(false)
		trap._process(0.61)
		_check(not player.hunter_state.opening(victim.get_instance_id()).is_empty(), "real trap activates marked prey")
		player.mage_cooldowns[&"hunter_mark"] = 0.0
		controller.navigation.configure(Rect2(0, 0, 1600, 1000), [Rect2(345, 240, 30, 100)], 20.0)
		sp = player.current_sp
		_check(not player.use_hunter_mark(victim) and player.current_sp == sp and player.skill_cooldown(&"hunter_mark") == 0.0, "mark LoS invalidation has no cost")
		controller.navigation.configure(Rect2(0, 0, 1600, 1000), [], 20.0)
		victim.global_position = Vector2(800, 300)
		_check(not player.use_hunter_mark(victim), "mark range revalidated")
		victim.global_position = Vector2(410, 300)
		paused = true
		_check(not player.use_hunter_mark(victim), "paused mark rejected")
		paused = false
		controller.queue_free()
		await process_frame

func _shot_runtime() -> void:
	for rank: int in range(1, 6):
		var controller := _controller(rank)
		var player := controller.player
		player.attack_cooldown = 0.75
		player._attack_recovery = 0.2
		var sp := player.current_sp
		controller.battle_indicators.show_aim(&"hunter_covering_shot", player, Vector2(410, 300), true)
		_check(controller.battle_indicators.hunter_recoil_endpoint == Vector2(220, 300) and controller.battle_indicators.endpoint == Vector2(820, 300), "preview owns shot and full recoil geometry")
		controller._commit_skill(&"hunter_covering_shot", Vector2(410, 300))
		var shots := get_nodes_in_group("player_projectiles")
		_check(shots.size() == 1 and player.global_position == Vector2(220, 300) and player.current_sp == sp - player.skill_cost(&"hunter_covering_shot"), "covering shot and recoil commit once")
		if shots.is_empty():
			controller.queue_free()
			await process_frame
			continue
		var shot := shots[0] as PlayerProjectile
		shot.set_process(false)
		_check(shot.global_position == Vector2(300, 282) and shot.speed == 880.0 and shot.max_distance == 520.0, "projectile captures pre-recoil origin and catalog trajectory")
		var tuning := HunterTuning.values(&"hunter_covering_shot", rank)
		_check(is_equal_approx(shot.request.physical_damage, player.stat_breakdown.value(&"precision_attack") * float(tuning["power"])) and shot.request.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and shot.request.can_crit and shot.request.emission_id > 0, "ranked precision arrow has normal critical contract and emission")
		_check(player.attack_cooldown == 0.75 and player._attack_recovery == 0.2, "covering shot cannot reset basic attack clocks")
		var victim := controller.enemies[0]
		victim.global_position = Vector2(410, 300)
		player.hunter_state.mark(victim.get_instance_id(), rank)
		player.activate_hunter_opening(10, victim, player.hunter_opening_snapshot(&"hunter_freezing_trap"))
		var results: Array[Dictionary] = []
		victim.health.damage_applied.connect(func(result: Dictionary) -> void: results.append(result))
		# Deterministic resolver roll only; the production request owns normal crit.
		shot.request.force_critical = true
		shot._process(1.0)
		_check(results.size() == 2 and results.any(func(result: Dictionary) -> bool: return bool(result.get("critical", false))) and results.any(func(result: Dictionary) -> bool: return not bool(result.get("can_trigger_effects", true))), "real covering projectile resolves critical primary and non-looping exploit")
		_check(player.hunter_state.opening(victim.get_instance_id()).is_empty() and player.hunter_state.step_remaining == 1.5 and player.attack_cooldown == 0.75, "covering shot consumes opening and grants step without auto reset")
		_check(not player.use_hunter_covering_shot(Vector2.RIGHT), "shot cooldown blocks duplicate")
		player.mage_cooldowns[&"hunter_covering_shot"] = 0.0
		controller.navigation.configure(Rect2(0, 0, 1600, 1000), [Rect2(165, 200, 15, 200)], 20.0)
		sp = player.current_sp
		_check(not player.use_hunter_covering_shot(Vector2.RIGHT) and player.global_position == Vector2(220, 300) and player.current_sp == sp and player.skill_cooldown(&"hunter_covering_shot") == 0.0, "clear destination beyond wall cannot bypass whole recoil segment")
		controller.navigation.configure(Rect2(0, 0, 1600, 1000), [], 20.0)
		player.apply_root(1.0)
		_check(not player.use_hunter_covering_shot(Vector2.RIGHT), "root prevents recoil/action")
		player.clear_statuses()
		_check(not player.use_hunter_covering_shot(Vector2(NAN, 0)), "non-finite shot rejected")
		paused = true
		_check(not player.use_hunter_covering_shot(Vector2.RIGHT), "paused shot rejected")
		paused = false
		controller.queue_free()
		await process_frame

func _cover_runtime() -> void:
	for rank: int in range(1, 6):
		var controller := _controller(rank)
		var player := controller.player
		var sp := player.current_sp
		var hp := player.health.current_hp
		controller._commit_skill(&"hunter_total_cover", player.global_position)
		var fields := get_nodes_in_group("foliage_shelters")
		_check(fields.size() == 1 and player.is_concealed() and player.current_sp == sp - player.skill_cost(&"hunter_total_cover"), "total cover creates one paid area")
		if fields.is_empty():
			controller.queue_free()
			await process_frame
			continue
		var field := fields[0] as FoliageShelter
		field.set_process(false)
		var tuning := HunterTuning.values(&"hunter_total_cover", rank)
		_check(field.radius == 125.0 and field.duration == float(tuning["duration"]), "ranked field geometry/lifetime")
		var cd := StatCalculator.effective_cooldown(18.0, player.stat_breakdown)
		_check(player.skill_cooldown(&"foliage_shelter") == cd and player.skill_cooldown(&"hunter_total_cover") == cd and not player.use_foliage_shelter(player.global_position), "base shelter and total cover share canonical cooldown")
		_check(not player.can_be_acquired_by(Vector2(800, 300)) and player.can_be_acquired_by(Vector2(310, 300)), "same-zone observer still acquires")
		player.hunter_cover.advance(1.0, player.global_position)
		player.global_position = Vector2(440, 300)
		_check(player.is_concealed(), "total-cover exit immediately starts one-second grace")
		player.hunter_cover.advance(0.5, player.global_position)
		_check(is_equal_approx(player.hunter_cover.budget_remaining, 1.5), "grace uses same three-second budget")
		player.reveal_from_offense()
		_check(not player.is_concealed(), "offense outside field reveals during grace")
		field.expire()
		_check(player.hunter_cover.reveal_remaining == 1.25 and player.hunter_cover.budget_remaining == 1.5 and not player.is_concealed(), "field expiry neither refunds nor clears reveal and grants no exit grace")
		controller._on_foliage_shelter_requested(player.global_position, 4.0)
		_check(player.hunter_cover.budget_remaining == 1.5 and not player.is_concealed(), "replacement registration cannot renew budget/reveal")
		player.hunter_cover.advance(2.75, player.global_position)
		_check(player.hunter_cover.budget_remaining == 0.0 and not player.is_concealed() and not player.use_hunter_total_cover(player.global_position), "exhaustion cannot renew before shared cooldown")
		player.mage_cooldowns[&"hunter_total_cover"] = 0.0
		_check(not player.use_hunter_total_cover(player.global_position), "clearing one cooldown cannot exploit other cover action")
		player.mage_cooldowns[&"foliage_shelter"] = 0.0
		player.current_sp = player.max_sp
		_check(player.use_foliage_shelter(player.global_position) and player.is_concealed() and player.hunter_cover.budget_remaining == 3.0, "paid base shelter renews shared cycle after both clocks expire")
		player.global_position += Vector2(120, 0)
		_check(not player.is_concealed(), "base shelter has no added exit grace")
		_check(player.health.current_hp == hp, "cover never heals player")
		controller.battle_indicators.show_aim(&"hunter_total_cover", player, Vector2(1400, 300), true)
		_check(controller.battle_indicators.endpoint == player.hunter_total_cover_center(Vector2(1400, 300)) and controller.battle_indicators.cover_preview_radius == 125.0, "total cover preview shares placement and radius")
		controller.queue_free()
		await process_frame
	var controller := _controller()
	var player := controller.player
	controller.navigation.configure(Rect2(0, 0, 1600, 1000), [Rect2(345, 240, 30, 100)], 20.0)
	var sp := player.current_sp
	_check(not player.use_hunter_total_cover(Vector2(410, 300)) and not player.use_foliage_shelter(Vector2(410, 300)) and player.current_sp == sp, "Hunter cover LoS fails atomically")
	_check(not player.use_hunter_total_cover(Vector2(NAN, 0)), "non-finite cover rejected")
	controller.navigation.configure(Rect2(0, 0, 1600, 1000), [], 20.0)
	paused = true
	_check(not player.use_hunter_total_cover(player.global_position) and not player.use_foliage_shelter(player.global_position), "paused cover rejects payment")
	paused = false
	controller.queue_free()
	await process_frame
	# Closed availability boundaries remain closed even in this isolated fixture.
	for invalid_rank: int in [0, 6]:
		controller = _controller(invalid_rank)
		player = controller.player
		controller.enemies[0].global_position = Vector2(410, 300)
		_check(not player.use_hunter_mark(controller.enemies[0]) and not player.use_hunter_covering_shot(Vector2.RIGHT) and not player.use_hunter_total_cover(player.global_position), "unlearned/invalid ranks cannot execute H4 skills")
		controller.queue_free()
		await process_frame

func _input_modes() -> void:
	for mode: CastIntent.Mode in [CastIntent.Mode.CONFIRM, CastIntent.Mode.RELEASE, CastIntent.Mode.INSTANT]:
		for skill_id: StringName in [&"hunter_mark", &"hunter_covering_shot", &"hunter_total_cover"]:
			var controller := _controller(1, true)
			controller.enemies[0].global_position = Vector2(410, 300)
			controller.control_preferences = ControlPreferences.new()
			controller.action_slots.fill(null)
			controller.action_slots[0] = skill_id
			controller.cast_intent.set_mode(mode)
			var player := controller.player
			var sp := player.current_sp
			var key := InputEventKey.new()
			key.keycode = KEY_1
			key.physical_keycode = KEY_1
			key.pressed = true
			controller._unhandled_input(key)
			_check((player.current_sp < sp) == (mode == CastIntent.Mode.INSTANT), "instant commits, other modes only aim")
			if mode == CastIntent.Mode.CONFIRM:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				click.position = controller.get_canvas_transform() * Vector2(410, 300)
				controller._unhandled_input(click)
			elif mode == CastIntent.Mode.RELEASE:
				key.pressed = false
				controller._input(key)
			key.pressed = false
			controller._input(key)
			_check(player.current_sp == sp - player.skill_cost(skill_id) and not player.has_active_cast(), "all input modes commit instant H4 action exactly once")
			controller.queue_free()
			await process_frame

func _enemy_pursuit_and_projectile() -> void:
	for hz: int in [30, 60, 144]:
		var controller := _controller()
		var player := controller.player
		var enemy := controller.enemies[0] as EnemyActor
		enemy.global_position = Vector2(800, 300)
		enemy.configure_hard_control_profile(true)
		enemy._refresh_player_acquisition()
		var seen := enemy.hunter_last_seen_position
		var enemy_hp := enemy.health.current_hp
		var count := controller.enemies.size()
		player.use_hunter_total_cover(player.global_position)
		player.global_position = Vector2(350, 300)
		var before := enemy.global_position
		var attacks := [0]
		enemy.attack_requested.connect(func(_request: DamageRequest, _victim: CombatActor, _ranged: bool) -> void: attacks[0] += 1)
		for frame: int in range(hz):
			enemy._process(1.0 / hz)
		_check(not enemy.player_target_acquired and enemy.hunter_last_seen_position == seen and enemy.global_position != before and attacks[0] == 0, "active AI follows last seen, not hidden player, at %dHz" % hz)
		_check(enemy.health.current_hp == enemy_hp and controller.enemies.size() == count, "boss HP and encounter count preserved")
		var arrow_request := DamageRequest.new()
		arrow_request.source_id = enemy.get_instance_id()
		arrow_request.target_id = player.get_instance_id()
		arrow_request.skill_id = &"enemy_arrow"
		arrow_request.physical_damage = 20.0
		arrow_request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		var arrow := ArrowProjectile.new()
		controller.add_child(arrow)
		arrow.configure(arrow_request, player, Vector2(500, 282), controller.navigation)
		arrow.set_process(false)
		var hits := [0]
		arrow.hit.connect(func(request: DamageRequest, target: CombatActor) -> void: hits[0] += 1; target.apply_damage(request, controller.rng))
		var hp := player.health.current_hp
		arrow._process(1.0)
		_check(player.is_concealed() and hits[0] == 1 and player.health.current_hp < hp, "in-flight projectile hits concealed actor without invulnerability")
		player.reveal_from_offense()
		enemy._process(0.01)
		_check(enemy.player_target_acquired and enemy.hunter_last_seen_position == player.global_position, "offense reacquires current position")
		controller.queue_free()
		await process_frame

func _lifecycle() -> void:
	var controller := _controller()
	var player := controller.player
	player.use_hunter_total_cover(player.global_position)
	var field := get_nodes_in_group("foliage_shelters")[0] as FoliageShelter
	field.set_process(false)
	var remaining := field.remaining
	paused = true
	field._process(3.0)
	player._advance_player(3.0)
	_check(field.remaining == remaining and player.hunter_cover.budget_remaining == 3.0, "tree pause freezes field and actor clocks")
	paused = false
	var hp := player.health.current_hp
	var sp := player.current_sp
	var cd := player.skill_cooldown(&"hunter_total_cover")
	player.hunter_state.mark(controller.enemies[0].get_instance_id(), 1)
	controller._show_result(false)
	_check(player.hunter_cover.zone_id == 0 and player.hunter_cover.budget_remaining == 0.0 and player.hunter_state.marked_target_id == 0 and not field.is_active(), "result clears marks, cover and field")
	_check(player.health.current_hp == hp and player.current_sp == sp and player.skill_cooldown(&"hunter_total_cover") == cd, "cleanup cannot refill HP/SP/cooldowns")
	paused = false
	controller.queue_free()
	await process_frame
	controller = _controller()
	player = controller.player
	player.use_hunter_total_cover(player.global_position)
	player.hunter_state.mark(controller.enemies[0].get_instance_id(), 1)
	player.health.current_hp = 0.0
	player._on_health_died(player.get_instance_id())
	_check(not player.is_concealed() and player.hunter_cover.zone_id == 0 and player.hunter_state.marked_target_id == 0, "owner death clears all cover authority and mark")
	paused = false
	controller.queue_free()
	await process_frame
	controller = _controller()
	player = controller.player
	player.use_hunter_total_cover(player.global_position)
	field = get_nodes_in_group("foliage_shelters")[0] as FoliageShelter
	field.set_process(false)
	field.removed.connect(func(_field: FoliageShelter, _reason: StringName) -> void: controller._show_result(false))
	controller._on_foliage_shelter_requested(player.global_position, 4.0)
	_check(controller.run_finished and player.hunter_cover.zone_id == 0 and player.hunter_cover.budget_remaining == 0.0, "replacement revalidates terminal callbacks before registering new cover")
	paused = false
	controller.queue_free()
	await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
