extends SceneTree
## H7 deterministic simulation of actual AI/navigation/projectile collision.
## Uses the production training boss HP/damage, never inflates player or add HP.
## Rates are simulation deltas, not renderer FPS, balance, DPS or victory claims.
## No facade/store/menu or personal settings: all builds are purchased in memory.

var checks := 0
var failures := 0
var arena: RunController
var metrics: Dictionary = {}
var observed_projectiles: Dictionary[int, bool] = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for ambusher: bool in [false, true]:
		for defense: bool in [false, true]:
			for hz: int in [30, 60, 144]:
				await _active_combat(ambusher, defense, hz)
	# Legal purchases omit both late Hunter passives. Unspent wallet is intentional.
	for ambusher: bool in [false, true]:
		for defense: bool in [false, true]:
			await _active_combat(ambusher, defense, 60, false)
	print("Hunter H7 active combat: %s (%d checks, %d failures; actual AI/flight, deterministic deltas, no balance/FPS claim)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _build(ambusher: bool, late_passives: bool) -> BuildSnapshot:
	var catalog := ProfileCatalog.pilot({}, {}, {&"hunter": {"content_ready": true}})
	var character := CharacterState.new("hunter-h7-active-ai", "Caçadora H7", &"archer")
	character.evolution_id = &"hunter"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	var purchases: Dictionary = {&"double_shot": 5, &"piercing_arrow": 5, &"arrow_rain": 5, &"archer_precision": 3, &"archer_cadence": 1}
	if ambusher:
		purchases.merge({&"hunter_tar_trap": 1, &"hunter_mark": 4, &"hunter_shooting_discipline": 3, &"hunter_covering_shot": 5, &"hunter_easy_prey": 3, &"hunter_total_cover": 4})
	else:
		purchases.merge({&"hunter_freezing_trap": 4, &"hunter_tar_trap": 4, &"hunter_thorn_trap": 4, &"hunter_mark": 2, &"hunter_shooting_discipline": 2, &"hunter_easy_prey": 2, &"hunter_covering_shot": 1, &"hunter_total_cover": 1})
	if not late_passives:
		purchases.erase(&"hunter_shooting_discipline")
		purchases.erase(&"hunter_easy_prey")
	for skill: StringName in purchases:
		for index: int in int(purchases[skill]):
			_check(CharacterProgression.learn_skill(character, catalog, skill)["ok"], "legal %s purchase %d" % [skill, index + 1])
	_check(CharacterProgression.allocate_attributes(character, {&"dex": 40, &"agi": 35, &"luk": 25} if ambusher else {&"int": 35, &"dex": 30, &"vit": 25})["ok"], "canonical legal attribute allocation")
	var summary := CharacterProgression.summary(character, catalog)
	var expected_evolution_spent := 20 if late_passives else (14 if ambusher else 16)
	_check(summary["base_skill_points_spent"] == 19 and summary["evolution_skill_points_spent"] == expected_evolution_spent and summary["evolution_skill_points_available"] >= 0, "separate legal 19/<=20 wallets")
	if not late_passives:
		_check(not summary["effective_skill_ranks"].has(&"hunter_shooting_discipline") and not summary["effective_skill_ranks"].has(&"hunter_easy_prey"), "intrinsic variant never purchases or grants late Hunter passives")
	_check(character.granted_skill_ranks.is_empty(), "no hidden grants fund combat builds")
	if ambusher:
		_check(not summary["effective_skill_ranks"].has(&"hunter_thorn_trap"), "Emboscadora does not need the whole learned kit")
	character.action_slots = ActionBarLayout.empty()
	character.action_slots[0] = &"hunter_tar_trap"
	character.action_slots[1] = &"hunter_mark"
	character.action_slots[23] = &"hunter_covering_shot"
	return BuildSnapshot.from_character(character, int(summary["base_level"]), int(summary["job_level"]), summary["effective_skill_ranks"], catalog.skill_ids_for_identity(&"archer", &"hunter"), catalog)

func _fixture(ambusher: bool, defense: bool, late_passives: bool) -> void:
	RunController.pending_run_state = RunState.from_build("", _build(ambusher, late_passives))
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	arena = (load("res://scenes/main.tscn") as PackedScene).instantiate() as RunController
	arena.control_preferences.path = "res://.godot/verification/hunter_h7_active_controls.cfg"
	root.add_child(arena)
	_freeze(arena)
	arena.rng.seed = 7407
	arena.player.global_position = Vector2(420, 520)
	arena.training_boss.global_position = Vector2(780, 520)
	# Solo is the actual training boss with scheduled adds excluded. Defense
	# retains the real production eight-second reinforcement schedule.
	if not defense:
		arena._training_add_elapsed = -1000.0
	metrics = {"hostile_attacks": 0, "hostile_hits": 0, "enemy_flight_hits": 0, "own_flight_hits": 0, "own_emissions": 0, "secondary_hits": 0, "boss_walked": 0.0, "armed_before_contact": false, "sprung": 0, "step_seen": false, "regen": 0.0, "paid": 0.0}
	observed_projectiles.clear()
	_observe_enemy(arena.training_boss)
	if defense:
		_observe_enemy(arena._spawn_enemy(&"archer", Vector2(680, 520)))
		_observe_enemy(arena._spawn_enemy(&"chaser", Vector2(820, 740)))
		_freeze(arena)
	arena.player.health.damage_applied.connect(func(result: Dictionary) -> void:
		if float(result.get("actual_damage", 0.0)) > 0.0:
			metrics["hostile_hits"] += 1
	)
	arena.player.hunter_covering_shot_requested.connect(func(_request: DamageRequest, _origin: Vector2, _direction: Vector2) -> void: metrics["own_emissions"] += 1)
	_check(arena.persistent_facade == null and arena.control_preferences.path.begins_with("res://.godot/"), "isolated runtime never opens personal persistence/settings")
	_check(arena.training_boss.health.max_hp == RunController.TRAINING_BOSS_HP and arena.training_boss.scenario_damage_multiplier == RunController.TRAINING_BOSS_DAMAGE_MULTIPLIER, "boss uses actual production training HP/damage, not test inflation")
	_check(arena.player.health.current_hp == arena.player.health.max_hp and arena.player.run_state.build_snapshot.job_level == 40, "legal full initial resources from configure, no artificial HP")
	_check(arena.player.hunter_state._openings.is_empty() and arena.player.hunter_state._emissions.is_empty() and arena.player.hunter_cover.zone_id == 0, "new run starts with clean Hunter state")

func _observe_enemy(enemy: EnemyActor) -> void:
	enemy.set_process(false)
	enemy.attack_requested.connect(func(_request: DamageRequest, _target: CombatActor, _ranged: bool) -> void: metrics["hostile_attacks"] += 1)
	enemy.health.damage_applied.connect(func(result: Dictionary) -> void:
		if StringName(result.get("skill_id", &"")) == &"hunter_exploit" and float(result.get("actual_damage", 0.0)) > 0.0:
			metrics["secondary_hits"] += 1
	)
	if enemy == arena.training_boss:
		enemy.ground_walked.connect(func(from: Vector2, to: Vector2) -> void: metrics["boss_walked"] += from.distance_to(to))

func _active_combat(ambusher: bool, defense: bool, hz: int, late_passives: bool = true) -> void:
	_fixture(ambusher, defense, late_passives)
	var player := arena.player
	var boss := arena.training_boss
	var initial_sp := player.current_sp
	var label := "%s/%s/%dHz" % ["Emboscadora" if ambusher else "Preparadora", "defesa" if defense else "solo", hz]
	if not late_passives:
		label += "/sem-passivas-tardias"
	_check(player.use_hunter_mark(boss), label + " legally marks the in-range moving boss")
	metrics["paid"] += player.skill_cost(&"hunter_mark")
	# Go through variable preparation/release, not a direct damage/trap shortcut.
	arena._commit_skill(&"hunter_tar_trap", Vector2(500, 520))
	_check(player.has_active_cast(), label + " actual preparation starts before paid placement")
	var shot_launched := false
	var trap_observed := false
	var pause_checked := false
	for frame: int in hz * 10:
		if frame % maxi(1, hz >> 1) == 0:
			await process_frame
		if not player.is_alive() or arena.run_finished:
			break
		var before_sp := player.current_sp
		var before_count := arena.trap_registry.active_count()
		var released_in_step := false
		_step(1.0 / float(hz))
		# The only action committed inside this step is initial trap release.
		var expected_regen := minf(player.max_sp, before_sp + player.stat_breakdown.value(&"sp_regen") / hz) - before_sp
		metrics["regen"] += expected_regen
		if not trap_observed and arena.trap_registry.active_count() > before_count:
			trap_observed = true
			released_in_step = true
			metrics["paid"] += player.skill_cost(&"hunter_tar_trap")
			var trap := arena.trap_registry.active_traps().back() as HunterTrap
			trap.sprung.connect(func(_trap: HunterTrap, _victims: Array[CombatActor]) -> void: metrics["sprung"] += 1)
		var frame_cost := player.skill_cost(&"hunter_tar_trap") if released_in_step else 0.0
		_close(player.current_sp, before_sp + expected_regen - frame_cost, label + " SP advances only by canonical regen/one release payment")
		for trap: PlayerTrap in arena.trap_registry.active_traps():
			if trap.state == PlayerTrap.State.ARMED:
				metrics["armed_before_contact"] = true
		if not shot_launched and not player.hunter_state.opening(boss.get_instance_id()).is_empty():
			var before := player.current_sp
			shot_launched = player.use_hunter_covering_shot(player.global_position.direction_to(boss.global_position))
			_check(shot_launched and before - player.current_sp == player.skill_cost(&"hunter_covering_shot"), label + " real paid arrow emitted toward opened moving prey")
			if shot_launched:
				metrics["paid"] += player.skill_cost(&"hunter_covering_shot")
				# This emission happens outside _step: freeze immediately so it
				# cannot take an extra automatic delta at the next process_frame.
				_freeze(arena)
		if player.hunter_state.step_remaining > 0.0:
			metrics["step_seen"] = true
		if frame == hz:
			_pause_probe(1.0 / float(hz), label)
			pause_checked = true
	_check(trap_observed and metrics["armed_before_contact"] and metrics["sprung"] == 1, label + " one armed mechanism sprung by actual approaching AI")
	_check(metrics["boss_walked"] > 200.0 and metrics["hostile_attacks"] > 0 and metrics["hostile_hits"] > 0, label + " real hostile movement/attack/damage remains active")
	_check(metrics["own_emissions"] == 1 and metrics["own_flight_hits"] == 1 and metrics["step_seen"] and player.hunter_state.opening(boss.get_instance_id()).is_empty(), label + " real projectile collision consumed opening and granted Passo exactly once")
	_check(metrics["secondary_hits"] == 1, label + " opening reward applied once through real HealthState callback")
	_close(player.current_sp, initial_sp + float(metrics["regen"]) - float(metrics["paid"]), label + " entire rotation resource ledger balances without refill")
	_check(pause_checked and player.is_alive() and boss.is_alive(), label + " bounded integration ends alive, not an artificial victory claim")
	if defense:
		_check(metrics["enemy_flight_hits"] > 0 and arena._training_wave_index > 0, label + " hostile arrows collided and actual reinforcement wave ran")
	else:
		_check(arena.enemies.size() == 1 and arena._training_wave_index == 0, label + " solo case remained one actual AI boss")
	# Leave paid coverage/mechanism state alive immediately before terminal cleanup.
	_check(player.use_hunter_total_cover(player.global_position), label + " paid cover before terminal")
	_check(player.use_hunter_trap(&"hunter_freezing_trap", Vector2(200, 520)), label + " paid untriggered mechanism before terminal")
	if defense:
		var lethal := DamageRequest.new()
		lethal.source_id = boss.get_instance_id()
		lethal.target_id = player.get_instance_id()
		lethal.skill_id = &"enemy_claw"
		lethal.physical_damage = player.health.max_hp * 10.0
		lethal.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		lethal.can_crit = false
		player.apply_damage(lethal, arena.rng)
		_check(not player.is_alive() and arena.run_finished, label + " lethal HealthState callback invokes real death/result lifecycle")
	else:
		arena._show_result(false)
	_check(player.hunter_state._openings.is_empty() and player.hunter_state._activations.is_empty() and player.hunter_state._emissions.is_empty() and player.hunter_state.marked_target_id == 0 and player.hunter_state.step_remaining == 0.0, label + " terminal clears all opening/mark/step claims")
	_check(arena.trap_registry.active_count() == 0 and not is_instance_valid(arena.hunter_tar_field) and player.hunter_cover.zone_id == 0 and player.hunter_cover.budget_remaining == 0.0, label + " terminal clears mechanisms/field/coverage")
	_check(player.hunter_presentation.events.is_empty() and player.hunter_presentation.trails.is_empty(), label + " presentation terminal cleanup stays synchronized")
	print("Hunter active %s: %.1f boss walked, %d hostile attacks/%d positive hits, %d hostile arrow hits, %d own flight hit, %.2f SP paid; production HP, no refill" % [label, metrics["boss_walked"], metrics["hostile_attacks"], metrics["hostile_hits"], metrics["enemy_flight_hits"], metrics["own_flight_hits"], metrics["paid"]])
	paused = false
	arena.queue_free()
	await process_frame

func _step(delta: float) -> void:
	_freeze(arena)
	arena._process(delta)
	arena.player._process(delta)
	for enemy: CombatActor in arena.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy._process(delta)
	for trap: PlayerTrap in arena.trap_registry.active_traps():
		if not trap.is_queued_for_deletion():
			trap._process(delta)
	for child: Node in arena.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is PlayerProjectile or child is ArrowProjectile:
			if not observed_projectiles.has(child.get_instance_id()):
				observed_projectiles[child.get_instance_id()] = true
				if child is PlayerProjectile:
					(child as PlayerProjectile).hit.connect(func(_request: DamageRequest, _target: CombatActor) -> void: metrics["own_flight_hits"] += 1)
				else:
					(child as ArrowProjectile).hit.connect(func(_request: DamageRequest, _target: CombatActor) -> void: metrics["enemy_flight_hits"] += 1)
			child.set_process(false)
			child.call("_process", delta)
		elif child is HunterTarField or child is FoliageShelter:
			child.set_process(false)
			child.call("_process", delta)
	if is_instance_valid(arena.player.hunter_presentation):
		arena.player.hunter_presentation._process(delta)
	# Scheduled waves and cosmetic callbacks can add children during this step.
	# Freeze those too before the next real engine frame is awaited.
	_freeze(arena)

func _pause_probe(delta: float, label: String) -> void:
	var boss_position := arena.training_boss.global_position
	var sp := arena.player.current_sp
	var cooldowns := arena.player.mage_cooldowns.duplicate()
	var clock := arena.player.hunter_state.mark_remaining
	var hostile := int(metrics["hostile_attacks"])
	var projectile_positions: Dictionary[int, Vector2] = {}
	for child: Node in arena.get_children():
		if child is PlayerProjectile or child is ArrowProjectile:
			projectile_positions[child.get_instance_id()] = child.global_position
	paused = true
	_step(delta * 60.0)
	_check(arena.training_boss.global_position == boss_position and arena.player.current_sp == sp and arena.player.mage_cooldowns == cooldowns and arena.player.hunter_state.mark_remaining == clock and int(metrics["hostile_attacks"]) == hostile, label + " pause freezes AI/resources/skill/opening clocks")
	for id: int in projectile_positions:
		var projectile := instance_from_id(id) as Node2D
		_check(is_instance_valid(projectile) and projectile.global_position == projectile_positions[id], label + " pause freezes actual projectile flight")
	paused = false

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child: Node in node.get_children():
		_freeze(child)

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.001, "%s (%.5f vs %.5f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
