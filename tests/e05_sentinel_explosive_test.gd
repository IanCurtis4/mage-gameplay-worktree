extends SceneTree
## S4 ammunition transaction and real scene area resolution; no personal saves.

const EXPLOSIVE := &"sentinel_explosive_shot"
const HEAD := &"sentinel_headshot"
const PIERCE := &"sentinel_piercing_shot"
var checks := 0
var failures := 0
var special: Array[DamageRequest] = []
var autos: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _reservations()
	await _invalid_prepare()
	await _invalid_launch()
	await _launch_snapshots()
	await _burst_scene()
	await _loss_and_cleanup()
	await _intents()
	print("Sentinel S4 Explosive: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _build(rank: int = 5) -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "sentinel-explosive-fixture"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel"
	build.base_level = 30
	build.job_level = 40
	build.attribute_allocations = {&"int": 35, &"dex": 20, &"luk": 15}
	build.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"archer", &"sentinel")
	build.skill_ranks = {EXPLOSIVE: rank, HEAD: 1, PIERCE: 1, &"sentinel_observe": 1, &"sentinel_opening_read": 3}
	build.active_slots = [EXPLOSIVE, HEAD, PIERCE, &"sentinel_observe", null]
	build.passive_slots = [&"sentinel_opening_read", null]
	return build

func _player(rank: int = 5) -> PlayerActor:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.position = Vector2(300, 300)
	player.configure(nav, RunState.from_build("", _build(rank)))
	root.add_child(player)
	player.set_process(false)
	player.sentinel_combat_active = true
	player.sentinel_state.gain(90.0)
	player.sentinel_projectile_requested.connect(func(request: DamageRequest, _actor: CombatActor, _direction: Vector2, _payload: Dictionary) -> void: special.append(request.copy()))
	player.precision_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _actor: CombatActor, _direction: Vector2, _count: int, _hits: int) -> void: autos.append(request.copy()))
	special.clear()
	autos.clear()
	return player

func _victim(player: PlayerActor, point: Vector2 = Vector2(480, 300)) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo Explosivo", Color.WHITE, player.stat_breakdown)
	enemy.position = point
	root.add_child(enemy)
	enemy.set_process(false)
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _fingerprint(player: PlayerActor) -> Array:
	return [player.current_sp, player.sentinel_state.focus, player.sentinel_state.reserved_sp, player.sentinel_state.reserved_focus, player.sentinel_state.explosive_prepared, player.skill_cooldown(EXPLOSIVE), player.attack_cooldown, player._attack_recovery, player._sentinel_last_launch_frame, special.size(), autos.size()]

func _reservations() -> void:
	for rank: int in range(1, 6):
		var player := _player(rank)
		player.attack_cooldown = 0.7
		player._attack_recovery = 0.1
		var before := _fingerprint(player)
		_check(player.prepare_sentinel_explosive(), "R%d prepares one ammunition reservation" % rank)
		_check(player.current_sp == before[0] and player.sentinel_state.focus == before[1] and player.skill_cooldown(EXPLOSIVE) == 0.0 and player.attack_cooldown == before[6] and player._attack_recovery == before[7] and special.is_empty() and autos.is_empty(), "R%d prepare pays/emits/resets nothing" % rank)
		_close(player.sentinel_state.reserved_sp, player.skill_cost(EXPLOSIVE), "R%d exact reserved SP" % rank)
		_close(player.sentinel_state.reserved_focus, 25.0, "R%d exact reserved Focus" % rank)
		_close(player.sentinel_free_sp(), player.current_sp - player.skill_cost(EXPLOSIVE), "R%d free SP excludes reserve" % rank)
		_close(player.sentinel_state.free_focus(), 65.0, "R%d free Focus excludes reserve" % rank)
		_check(player.prepare_sentinel_explosive() and _fingerprint(player) == before, "R%d repeated activation cancels without stack or refund inflation" % rank)
		_check(not player.cancel_sentinel_preparation() and _fingerprint(player) == before, "R%d second cancellation cannot create resources" % rank)
		_check(player.prepare_sentinel_explosive(), "R%d can prepare again without cooldown" % rank)
		player._process(60.0)
		_check(player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_sp == player.skill_cost(EXPLOSIVE) and player.skill_cooldown(EXPLOSIVE) == 0.0, "R%d preparation does not expire during combat" % rank)
		player.cancel_sentinel_preparation()
		player.queue_free()
		await process_frame
	for id: StringName in [HEAD, PIERCE]:
		var player := _player()
		var enemy := _victim(player)
		_check(player.prepare_sentinel_explosive() and player.use_sentinel_reset(id, enemy.position, enemy), "reset %s usable alongside sufficient free ammunition resources" % id)
		_check(player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_sp == player.skill_cost(EXPLOSIVE) and player.sentinel_state.reserved_focus == 25.0 and player.skill_cooldown(EXPLOSIVE) == 0.0, "reset %s neither consumes nor combines ammunition" % id)
		_check(special.size() == 1 and special[0].skill_id == id, "reset %s remains a separate damage request" % id)
		player.queue_free()
		enemy.queue_free()
		await process_frame
	var player := _player()
	var enemy := _victim(player)
	player.current_sp = player.skill_cost(EXPLOSIVE) + player.skill_cost(HEAD) - 1.0
	player.sentinel_state.focus = 54.0
	player.prepare_sentinel_explosive()
	var reserved := _fingerprint(player)
	_check(not player.use_sentinel_reset(HEAD, enemy.position, enemy) and _fingerprint(player) == reserved, "reset cannot spend reserved SP or Focus")
	player.cancel_sentinel_preparation()
	_check(player.use_sentinel_reset(HEAD, enemy.position, enemy), "cancel restores spendability, not a synthetic refund")
	player.queue_free()
	enemy.queue_free()
	await process_frame

func _invalid_prepare() -> void:
	for reason: String in ["sp", "focus", "cooldown", "stun", "fear", "paused", "dead", "unlearned", "wrong_identity"]:
		var player := _player()
		match reason:
			"sp": player.current_sp = player.skill_cost(EXPLOSIVE) - 1.0
			"focus": player.sentinel_state.focus = 24.0
			"cooldown": player.mage_cooldowns[EXPLOSIVE] = 1.0
			"stun": player.apply_stun(1.0)
			"fear": player.apply_fear(1.0)
			"paused": paused = true
			"dead": player.health.current_hp = 0.0
			"unlearned": player.run_state.build_snapshot.skill_ranks.erase(EXPLOSIVE)
			"wrong_identity": player.run_state.build_snapshot.evolution_id = &"hunter"
		var before := _fingerprint(player)
		_check(not player.prepare_sentinel_explosive() and _fingerprint(player) == before, "invalid prepare %s is atomic" % reason)
		paused = false
		player.queue_free()
		await process_frame

func _invalid_launch() -> void:
	for reason: String in ["sp", "focus", "cooldown", "stun", "fear", "paused", "dead", "unlearned", "dead_target", "null_target", "range", "obstacle"]:
		var player := _player()
		var enemy := _victim(player)
		player.prepare_sentinel_explosive()
		match reason:
			"sp": player.current_sp = player.sentinel_state.reserved_sp - 1.0
			"focus": player.sentinel_state.focus = player.sentinel_state.reserved_focus - 1.0
			"cooldown": player.mage_cooldowns[EXPLOSIVE] = 1.0
			"stun": player.apply_stun(1.0)
			"fear": player.apply_fear(1.0)
			"paused": paused = true
			"dead": player.health.current_hp = 0.0
			"unlearned": player.run_state.build_snapshot.skill_ranks.erase(EXPLOSIVE)
			"dead_target": enemy.health.current_hp = 0.0
			"range": enemy.position = player.position + Vector2(player.basic_attack_distance(enemy) + 30.0, 0)
			"obstacle": player.navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(380, 240, 30, 120)], 20.0)
		var before := _fingerprint(player)
		_check(not player._launch_sentinel_explosive(null if reason == "null_target" else enemy) and _fingerprint(player) == before, "invalid launch %s keeps reservation/resources/clocks" % reason)
		paused = false
		player.queue_free()
		enemy.queue_free()
		await process_frame

func _launch_snapshots() -> void:
	for rank: int in range(1, 6):
		var player := _player(rank)
		var enemy := _victim(player)
		var alternate := _victim(player, Vector2(500, 320))
		player.prepare_sentinel_explosive()
		var old_power := SentinelMath.raw_power(EXPLOSIVE, rank, player.stat_breakdown)
		player.run_state.build_snapshot.attribute_allocations[&"int"] = 45
		player.apply_run_modifiers(player.run_state)
		var sp := player.current_sp
		var focus := player.sentinel_state.focus
		player.target = alternate
		player.attack_cooldown = 0.5
		player._try_basic_attack()
		_check(special.is_empty() and player.sentinel_state.explosive_prepared, "R%d preparation never resets previous auto cooldown" % rank)
		player.attack_cooldown = 0.0
		player._try_basic_attack()
		_check(special.size() == 1 and special[0].target_id == alternate.get_instance_id() and autos.is_empty(), "R%d target swap launches exactly one explosive instead of physical auto" % rank)
		_check(not player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_focus == 0.0 and player.sentinel_state.reserved_sp == 0.0, "R%d successful launch consumes reservation once" % rank)
		_close(player.current_sp, sp - player.skill_cost(EXPLOSIVE), "R%d SP paid only at actual launch" % rank)
		_close(player.sentinel_state.focus, focus - 25.0, "R%d Focus paid only at actual launch" % rank)
		_close(player.skill_cooldown(EXPLOSIVE), SentinelMath.cooldown(EXPLOSIVE, SentinelTuning.values(EXPLOSIVE, rank)["cooldown"], player.stat_breakdown), "R%d local CD captured at actual launch" % rank)
		_close(player.attack_cooldown, 1.0 / player.attacks_per_second(), "R%d begins one normal attack recovery" % rank)
		if not special.is_empty():
			var shot := special[0]
			_close(shot.magic_damage, SentinelMath.raw_power(EXPLOSIVE, rank, player.stat_breakdown), "R%d attributes captured at launch, not preparation" % rank)
			_check(shot.magic_damage > old_power and shot.physical_damage == 0.0 and shot.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and shot.can_crit and not shot.force_critical and not shot.is_secondary, "R%d exclusively INT magic/direct/geometry/normal crit" % rank)
			var noncrit := CombatMath.resolve(shot, 0, 0, 1000, 0, 0.99, 1.0)
			var crit := CombatMath.resolve(shot, 0, 0, 1000, 0, 0.99, 0.0)
			_check(noncrit["landed"] and not noncrit["critical"] and crit["critical"] and crit["damage"] > noncrit["damage"], "R%d central accuracy ignores FLEE but crit stays normal" % rank)
		var committed := _fingerprint(player)
		player.attack_cooldown = 0.0
		player._try_basic_attack()
		_check(special.size() == 1 and autos.is_empty(), "R%d same-frame callback cannot add a free ordinary auto" % rank)
		player.attack_cooldown = committed[6]
		await process_frame
		player.attack_cooldown = 0.0
		player._try_basic_attack()
		_check(autos.size() == 1 and special.size() == 1, "R%d subsequent ordinary auto resumes without extra explosive" % rank)
		player.queue_free()
		enemy.queue_free()
		alternate.queue_free()
		await process_frame

func _scene() -> RunController:
	RunController.pending_run_state = RunState.from_build("", _build())
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.sentinel_combat_active = arena.encounter_active
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena._training_add_elapsed = -1000.0
	arena.navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	arena.player.position = Vector2(300, 300)
	arena.training_boss.position = Vector2(480, 300)
	arena.training_boss.health.max_hp = 10000.0
	arena.training_boss.health.current_hp = 10000.0
	arena.player.sentinel_state.gain(90.0)
	return arena

func _projectile() -> SentinelAreaProjectile:
	for node: Node in get_nodes_in_group("player_projectiles"):
		if node is SentinelAreaProjectile and not node.is_queued_for_deletion():
			return node as SentinelAreaProjectile
	return null

func _burst_scene() -> void:
	var arena := _scene()
	var player := arena.player
	var primary := arena.training_boss
	var near := _victim(player, Vector2(480, 350))
	var outside := _victim(player, Vector2(480, 430))
	var protected := _victim(player, Vector2(520, 320))
	arena.enemies.append_array([near, outside, protected, primary])
	for actor: CombatActor in [near, outside, protected]:
		actor.health.damage_applied.connect(player.record_sentinel_damage)
	var events: Dictionary[int, Array] = {}
	for actor: CombatActor in [primary, near, outside, protected]:
		events[actor.get_instance_id()] = []
		actor.health.damage_applied.connect(func(result: Dictionary) -> void: events[actor.get_instance_id()].append(result.duplicate(true)))
	primary.apply_root(4.0, &"magic")
	near.apply_root(4.0, &"magic")
	player.sentinel_state.observe(primary.get_instance_id(), 1)
	player.prepare_sentinel_explosive()
	player.target = primary
	player._try_basic_attack()
	var projectile := _projectile()
	_check(projectile != null and projectile.homing and projectile.target == primary and projectile.payload["radius"] == 80.0, "real scene emits one homing explosive with radius80")
	if projectile != null:
		projectile.set_process(false)
		var frozen := projectile.request.copy()
		var paid_cd := player.skill_cooldown(EXPLOSIVE)
		player.run_state.build_snapshot.attribute_allocations[&"int"] = 45
		player.run_state.build_snapshot.attribute_allocations[&"dex"] = 25
		player.apply_run_modifiers(player.run_state)
		var impact_sp := player.current_sp
		_check(projectile.request.magic_damage == frozen.magic_damage and projectile.request.crit_chance == frozen.crit_chance and player.skill_cooldown(EXPLOSIVE) == paid_cd, "in-flight damage/crit/CD snapshot ignores later INT/DES")
		var position := projectile.position
		paused = true
		projectile._process(1.0)
		_check(projectile.position == position and not projectile.opened, "real explosive projectile pauses")
		paused = false
		# Cover is added after valid launch; burst checks each radial segment.
		arena.navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(502, 292, 8, 48)], 20.0)
		projectile._process(1.0)
		_check(projectile.opened and projectile.is_queued_for_deletion(), "real first contact opens finite burst")
		_check(events[primary.get_instance_id()].size() == 1 and events[near.get_instance_id()].size() == 1, "primary and nearby victim damaged exactly once despite duplicate actor listing")
		_check(events[outside.get_instance_id()].is_empty() and events[protected.get_instance_id()].is_empty(), "fixed radial range and per-victim terrain LoS exclude invalid victims")
		for actor: CombatActor in [primary, near]:
			if not events[actor.get_instance_id()].is_empty():
				var result: Dictionary = events[actor.get_instance_id()][0]
				_check(result["skill_id"] == EXPLOSIVE and result["physical_component"] == 0.0 and result["emission_id"] == frozen.emission_id and result["can_trigger_effects"], "one direct pure-magic damage result per victim")
		_close(player.sentinel_state.focus, 90.0 - 25.0 + 6.0 + 4.0 + 4.0, "area grants Observar, Aberturas and intrinsic4 once, not per root victim")
		_check(player.sentinel_state.observation_charges == 2 and player.current_sp == impact_sp and player.skill_cooldown(EXPLOSIVE) == paid_cd, "impact consumes only one observation and no additional SP/CD")
		var amounts := events[primary.get_instance_id()].size()
		projectile._open()
		_check(events[primary.get_instance_id()].size() == amounts, "repeated projectile open cannot replay area")
	arena.queue_free()
	for actor: CombatActor in [near, outside, protected]:
		actor.queue_free()
	await process_frame
	_check(get_nodes_in_group("player_projectiles").is_empty() and get_nodes_in_group("player_effects").is_empty(), "scene removal leaves no burst/projectile orphan")

func _loss_and_cleanup() -> void:
	var arena := _scene()
	var player := arena.player
	var enemy := arena.training_boss
	player.prepare_sentinel_explosive()
	enemy.health.current_hp = 0.0
	var reserved := _fingerprint(player)
	_check(not player._launch_sentinel_explosive(enemy) and _fingerprint(player) == reserved, "target lost before launch is unpaid with reusable reservation")
	enemy.health.current_hp = 10000.0
	_check(player._launch_sentinel_explosive(enemy), "valid replacement/live target can consume preparation later")
	var projectile := _projectile()
	if projectile != null:
		projectile.set_process(false)
		var paid := _fingerprint(player)
		enemy.health.current_hp = 0.0
		projectile._process(1.0)
		_check(projectile.is_queued_for_deletion() and not projectile.opened and _fingerprint(player) == paid, "target loss after launch removes projectile without resource/CD refund")
	player.mage_cooldowns[EXPLOSIVE] = 0.0
	player.sentinel_state.gain(35.0)
	player.prepare_sentinel_explosive()
	arena._show_result(false)
	_check(arena.run_finished and paused and not player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_sp == 0.0 and player.sentinel_state.focus == 0.0, "result synchronously clears reservation/resource even while paused")
	paused = false
	arena.queue_free()
	await process_frame
	arena = _scene()
	player = arena.player
	player.prepare_sentinel_explosive()
	player.health.current_hp = 0.0
	player._on_health_died(player.get_instance_id())
	_check(arena.run_finished and paused and not player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_focus == 0.0 and player.sentinel_state.reserved_sp == 0.0, "real player death clears ammunition before result")
	paused = false
	arena.queue_free()
	await process_frame

func _intents() -> void:
	for mode: int in [CastIntent.Mode.CONFIRM, CastIntent.Mode.RELEASE, CastIntent.Mode.INSTANT]:
		var arena := _scene()
		var player := arena.player
		arena.cast_intent.set_mode(mode)
		var sp := player.current_sp
		var command := arena.cast_intent.press(EXPLOSIVE)
		if mode == CastIntent.Mode.CONFIRM:
			command = arena.cast_intent.confirm()
		elif mode == CastIntent.Mode.RELEASE:
			command = arena.cast_intent.release(EXPLOSIVE)
		arena._commit_skill(command, arena.training_boss.position)
		_check(player.sentinel_state.explosive_prepared and player.current_sp == sp and get_nodes_in_group("player_projectiles").is_empty(), "input mode%d commits reservation only" % mode)
		arena._cancel_casting()
		_check(not player.sentinel_state.explosive_prepared and player.sentinel_free_sp() == sp and player.sentinel_state.focus == 90.0, "input mode%d cancel returns reserve without launching" % mode)
		arena.queue_free()
		await process_frame
	for id: StringName in [HEAD, PIERCE]:
		var arena := _scene()
		var player := arena.player
		arena._commit_skill(EXPLOSIVE, player.position)
		arena._commit_skill(id, arena.training_boss.position + PlayerProjectile.BODY_OFFSET)
		_check(player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_focus == 25.0 and player.skill_cooldown(EXPLOSIVE) == 0.0, "actual dispatcher %s preserves ammunition while launching its own shot" % id)
		_check(get_nodes_in_group("player_projectiles").size() == 1 and get_nodes_in_group("player_projectiles")[0].request.skill_id == id, "actual dispatcher %s emits no extra Explosive or ordinary auto" % id)
		arena.queue_free()
		await process_frame

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (%.6f vs %.6f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Sentinel S4 Explosive: " + label)
