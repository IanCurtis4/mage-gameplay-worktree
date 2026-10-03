extends SceneTree
## Real shared projectile paths, physical distances, impact order and finite procs.

const A := Vector2(200, 200)
const B := Vector2(500, 200)
var checks := 0
var failures := 0
var arena: RunController
var casting: GeometerCasting
var hits: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _conduction()
	await _redirect()
	await _payload()
	await _hostile()
	await _ordering_and_lifecycle()
	await _active_transport_lifecycle()
	await _launch_snapshot()
	await _real_emissions()
	print("Geometer wall projectiles: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _fixture(incidence_rank: int = 0) -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g4-projectile-fixture"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.skill_ranks = {&"geometer_trace": 1, &"geometer_triangulation": 5, &"fireball": 1}
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation", &"fireball"]
	snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", &"fireball", null, null]
	if incidence_rank > 0:
		snapshot.skill_ranks[&"geometer_incidence"] = incidence_rank
		snapshot.library_skill_ids.append(&"geometer_incidence")
		snapshot.passive_slots = [&"geometer_incidence", null, null]
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena._training_add_elapsed = -1000.0
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [], 18)
	arena.player.global_position = Vector2(100, 100)
	arena.training_boss.global_position = Vector2(1100, 700)
	casting = arena.geometer_casting
	hits.clear()
	casting.hit.connect(func(request: DamageRequest, _actor: CombatActor) -> void: hits.append(request.copy()))

func _finish() -> void:
	paused = false
	arena.queue_free()
	await process_frame

func _wall(first: StringName, second: StringName) -> void:
	casting.clear_construction()
	casting.construction.add_vertex(first, A, 0, 5, arena.navigation)
	casting.construction.add_vertex(second, B, 0, 5, arena.navigation)
	casting.advance(0.01)
	hits.clear()

func _target(point: Vector2) -> EnemyActor:
	var actor := arena._spawn_enemy(&"chaser", point)
	actor.health.max_hp = 10000.0
	actor.health.current_hp = 10000.0
	actor.set_process(false)
	return actor

func _owned(origin: Vector2 = Vector2(300, 100), facing: Vector2 = Vector2.DOWN, range_value: float = 1000.0) -> PlayerProjectile:
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.magic_damage = 100.0
	request.skill_id = &"basic_attack"
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	var projectile := PlayerProjectile.new()
	arena.add_child(projectile)
	projectile.configure_directional(request, origin + PlayerProjectile.BODY_OFFSET, facing, arena.enemies, arena.navigation, 100.0, range_value, 3)
	projectile.geometer_field = casting.wall_field
	projectile.hit.connect(arena._on_attack_requested)
	projectile.set_process(false)
	return projectile

func _hostile_arrow() -> ArrowProjectile:
	var request := DamageRequest.new()
	request.source_id = arena.training_boss.get_instance_id()
	request.target_id = arena.player.get_instance_id()
	request.skill_id = &"enemy_arrow"
	request.physical_damage = 1.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	arena.player.global_position = Vector2(300, 300)
	var projectile := ArrowProjectile.new()
	arena.add_child(projectile)
	projectile.configure(request, arena.player, Vector2(300, 100) + ArrowProjectile.BODY_OFFSET, arena.navigation)
	projectile.geometer_field = casting.wall_field
	projectile.hit.connect(arena._on_attack_requested)
	projectile.set_process(false)
	return projectile

func _conduction() -> void:
	for second: StringName in [&"fire", &"ice"]:
		_fixture()
		_wall(&"lightning", second)
		var projectile := _owned()
		projectile._process(1.0)
		_check(is_equal_approx(projectile.travelled, 100.0) and projectile.global_position.distance_to(B + PlayerProjectile.BODY_OFFSET) > 170.0, "R/%s conduction starts at actual contact and cannot teleport to B" % second)
		_check(projectile.geometer_conduction_endpoint == B + PlayerProjectile.BODY_OFFSET and not projectile.homing, "conduction captures B without homing reset")
		projectile._process(2.2)
		_check(is_equal_approx(projectile.travelled, 320.0) and not projectile.geometer_conduction_endpoint.is_finite() and projectile.direction == Vector2.DOWN and is_equal_approx(projectile.global_position.x, B.x), "transport consumes physical distance and resumes original direction after B")
		_check(projectile.max_distance == 1000.0 and projectile.max_hits == 3, "conduction retains range and piercing budget")
		_check((projectile.geometer_fire_request != null) == (second == &"fire"), "only R/F grants fire exit payload")
		await _finish()
	_fixture()
	_wall(&"lightning", &"ice")
	var short := _owned(Vector2(300, 100), Vector2.DOWN, 150.0)
	short._process(5.0)
	_check(short.is_queued_for_deletion() and is_equal_approx(short.travelled, 150.0) and short.global_position.distance_to(B + PlayerProjectile.BODY_OFFSET) > 100.0, "range expires during transport without renewing life or reaching B")
	await _finish()
	_fixture()
	_wall(&"lightning", &"ice")
	var blocked := _owned()
	blocked._process(1.0)
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(380, 160, 20, 25)], 18)
	# Obstacle clips the visual projectile path, not the ground grammar edge.
	blocked._process(2.0)
	_check(blocked.is_queued_for_deletion() and blocked.global_position.x < 380.0 and blocked.travelled < 300.0, "actual obstacle still collides during conduction")
	await _finish()
	for hz: int in [30, 60, 144]:
		_fixture()
		_wall(&"lightning", &"ice")
		var projectile := _owned()
		for frame: int in range(hz * 3):
			projectile._process(1.0 / hz)
		_check(is_equal_approx(projectile.travelled, 300.0) and is_equal_approx(projectile.global_position.x, B.x) and projectile.direction == Vector2.DOWN, "%d Hz transport keeps path length and original direction" % hz)
		await _finish()

func _redirect() -> void:
	for first: StringName in [&"fire", &"ice"]:
		_fixture()
		_wall(first, &"lightning")
		var near := _target(Vector2(490, 245))
		_target(Vector2(510, 245))
		var projectile := _owned()
		projectile._process(1.0)
		var facing := projectile.direction
		_check(facing.x > 0.9 and facing.y > 0.0 and not projectile.homing and not projectile.geometer_conduction_endpoint.is_finite(), "F/G to R redirects once toward nearest B target with deterministic tie")
		near.global_position = Vector2(490, 350)
		projectile._process(0.2)
		_check(projectile.direction.is_equal_approx(facing) and projectile.max_distance == 1000.0 and projectile.max_hits == 3, "redirect is fixed, not homing/recursive or renewed piercing")
		_check(casting.interaction_ledger.projectile_claimed(projectile.get_instance_id(), GeometerInteractionLedger.Component.TRANSPORT), "redirect claims shared transport component")
		await _finish()
	_fixture()
	_wall(&"fire", &"lightning")
	_target(Vector2(490, 245))
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(490, 216, 15, 12)], 18)
	var projectile := _owned()
	projectile._process(1.0)
	_check(projectile.direction == Vector2.DOWN and not casting.interaction_ledger.projectile_claimed(projectile.get_instance_id(), GeometerInteractionLedger.Component.TRANSPORT), "hidden target cannot redirect or consume interaction")
	await _finish()

func _payload() -> void:
	for first: StringName in [&"ice", &"lightning"]:
		_fixture(3)
		_wall(first, &"fire")
		var target := _target(Vector2(500 if first == &"lightning" else 300, 320))
		var neighbor := _target(target.global_position + Vector2(40, 0))
		var projectile := _owned()
		projectile._process(1.0)
		_check(projectile.geometer_fire_request != null and projectile.geometer_bonus_request != null and hits.is_empty(), "fire exit and theorem wait for real next impact, no preview reward")
		projectile._process(4.0)
		_check(hits.filter(func(request: DamageRequest) -> bool: return request.skill_id == &"geometer_incidence").size() == 1, "transformed impact gets one captured secondary theorem bonus")
		_check(hits.filter(func(request: DamageRequest) -> bool: return request.skill_id == &"geometer_wall_exit").size() == 2, "next impact emits finite pulse once for hit victim and nearby neighbor")
		_check(projectile.geometer_fire_request == null and projectile.geometer_bonus_request == null and neighbor.health.current_hp < neighbor.health.max_hp, "payload consumed once, even on piercing projectile")
		for request: DamageRequest in hits:
			_check(request.is_secondary and not request.can_crit and request.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "additional damage is secondary through canonical resolver")
		await _finish()
	_fixture()
	_wall(&"ice", &"fire")
	var target := _target(Vector2(300, 320))
	var projectile := _owned()
	projectile._process(1.0)
	casting.clear_construction()
	projectile._process(4.0)
	_check(hits.is_empty() and target.health.current_hp < target.health.max_hp, "clear invalidates pending construction payload but not independent base projectile")
	await _finish()

func _hostile() -> void:
	for first: StringName in GeometerGeometry.ELEMENTS:
		for second: StringName in GeometerGeometry.ELEMENTS:
			if first == second:
				continue
			_fixture(1)
			_wall(first, second)
			arena.player.current_sp = arena.player.max_sp - 10.0
			var projectile := _hostile_arrow()
			projectile._process(1.0)
			_check(projectile.is_queued_for_deletion(), "hostile arrow resolves within real path")
			_check(is_equal_approx(arena.player.current_sp, arena.player.max_sp - 8.0 if second == &"ice" else arena.player.max_sp - 10.0), "only G exit intercepts and rewards actual recovery in %s/%s" % [first, second])
			_check((projectile.global_position.y < 190.0) == (second == &"ice"), "intercept happens at contact before reaching player")
			await _finish()
	for rank: int in [1, 2, 3]:
		_fixture(rank)
		_wall(&"fire", &"ice")
		arena.player.current_sp = arena.player.max_sp
		_hostile_arrow()._process(1.0)
		arena.player.current_sp -= 10.0
		_hostile_arrow()._process(1.0)
		var sp := arena.player.current_sp
		_check(is_equal_approx(sp, arena.player.max_sp - 10.0 + rank + 1.0), "full SP consumes no window; incidence rank scales refund")
		_hostile_arrow()._process(1.0)
		_check(arena.player.current_sp == sp, "multiple hostile arrows share two-second reward window")
		casting.advance(2.0)
		_hostile_arrow()._process(1.0)
		_check(is_equal_approx(arena.player.current_sp, sp + rank + 1.0), "actual intercept becomes reward-eligible again after two seconds")
		await _finish()

func _ordering_and_lifecycle() -> void:
	_fixture()
	_wall(&"lightning", &"fire")
	var before := _target(Vector2(300, 160))
	var projectile := _owned()
	projectile.max_hits = 1
	projectile._process(2.0)
	_check(projectile.is_queued_for_deletion() and before.health.current_hp < before.health.max_hp and projectile.geometer_fire_request == null, "earlier victim wins over wall contact, no late transformation")
	await _finish()
	_fixture()
	_wall(&"lightning", &"fire")
	for kind: int in range(3):
		projectile = _owned()
		if kind == 0:
			projectile.request.is_secondary = true
		elif kind == 1:
			projectile.request.source_id = arena.training_boss.get_instance_id()
		else:
			projectile.request.skill_id = &"geometer_trace"
		projectile._process(1.0)
		_check(projectile.direction == Vector2.DOWN and projectile.geometer_fire_request == null and not projectile.geometer_conduction_endpoint.is_finite(), "secondary, other owner and construction shots cannot transform")
	paused = true
	projectile = _owned()
	projectile._process(1.0)
	_check(projectile.travelled == 0.0 and projectile.geometer_fire_request == null, "pause freezes movement and claims")
	paused = false
	casting.construction.add_vertex(&"ice", Vector2(200, 400), 0, 5, arena.navigation)
	casting.advance(0.1)
	projectile._process(1.0)
	_check(projectile.direction == Vector2.DOWN and projectile.geometer_fire_request == null, "triangle receives no wall transformation")
	await _finish()

func _real_emissions() -> void:
	_fixture(1)
	_wall(&"lightning", &"fire")
	arena.player.global_position = Vector2(500, 100)
	arena.training_boss.global_position = Vector2(500, 300)
	arena.player.target = arena.training_boss
	arena.player._try_basic_attack()
	var own: MageProjectile
	for child: Node in arena.get_children():
		if child is MageProjectile:
			own = child
	_check(own != null and own.geometer_field == casting.wall_field and casting.construction.vertices.size() == 2, "actual Mage auto emission attaches wall hook without creating anchor")
	if own != null:
		own.set_process(false)
		own._process(1.0)
		_check(own.is_queued_for_deletion() and own._hit_actor_ids.has(arena.training_boss.get_instance_id()) and arena.training_boss.health.current_hp < arena.training_boss.health.max_hp, "actual solo-boss auto crosses wall and impacts through canonical resolver")
		_check(hits.size() == 2 and hits[0].skill_id == &"geometer_incidence" and hits[1].skill_id == &"geometer_wall_exit" and casting.construction.vertices.size() == 2, "real auto gets theorem and one fire pulse without placing anchors")
	var enemy_request := DamageRequest.new()
	enemy_request.source_id = arena.training_boss.get_instance_id()
	enemy_request.physical_damage = 1.0
	arena._on_enemy_attack_requested(enemy_request, arena.player, true)
	var hostile: ArrowProjectile
	for child: Node in arena.get_children():
		if child is ArrowProjectile:
			hostile = child
	_check(hostile != null and hostile.geometer_field == casting.wall_field, "actual enemy arrow emission attaches interception hook")
	await _finish()

func _active_transport_lifecycle() -> void:
	for transition: String in ["clear", "expiry", "triangle", "suspend"]:
		_fixture(1)
		_wall(&"lightning", &"fire")
		var projectile := _owned()
		projectile._process(1.0)
		var point := projectile.global_position
		match transition:
			"clear": casting.clear_construction()
			"expiry": casting.advance(6.0)
			"triangle": casting.construction.add_vertex(&"ice", Vector2(200, 400), 0, 5, arena.navigation)
			"suspend": casting.construction.vertices[1].position = A
		projectile._process(0.1)
		_check(not projectile.geometer_conduction_endpoint.is_finite() and projectile.direction == Vector2.DOWN and projectile.global_position.is_equal_approx(point + Vector2(0, 10)), transition + " stops active conduction without teleport/range renewal")
		if transition == "suspend":
			casting.construction.vertices[1].position = B
			casting.advance(0.01)
			projectile._process(0.1)
			_check(not projectile.geometer_conduction_endpoint.is_finite(), "resume cannot grant same projectile another conduction")
		var target := _target(projectile.global_position - PlayerProjectile.BODY_OFFSET + Vector2(0, 45))
		projectile.targets.append(target)
		projectile._process(0.5)
		_check(target.health.current_hp < target.health.max_hp, "base projectile survives ended transport: " + transition)
		_check((not hits.is_empty()) == (transition == "suspend"), "wall payload requires active wall at impact: " + transition)
		await _finish()
	for obstacle: bool in [false, true]:
		_fixture(1)
		_wall(&"fire", &"ice")
		arena.player.current_sp -= 10.0
		var arrow := _hostile_arrow()
		if obstacle:
			arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(280, 145, 40, 12)], 18)
		else:
			arena.player.global_position = Vector2(300, 150)
		arrow._process(1.0)
		_check(arrow.is_queued_for_deletion() and is_equal_approx(arena.player.current_sp, arena.player.max_sp - 10.0) and casting._wall_reactions.is_empty(), "earlier target/terrain wins before hostile interception")
		await _finish()

func _launch_snapshot() -> void:
	_fixture(1)
	casting.show_wall_reaction(A, &"fire")
	for delta: float in [0.0, -1.0, NAN]:
		casting.advance(delta)
		_check(casting._wall_reactions.size() == 1 and casting._wall_reactions[0]["remaining"] == 0.25, "invalid delta cannot age or corrupt reactions")
	_check(casting._reaction_visual.z_index + casting.z_index > arena.training_boss.z_index, "actual impacts draw above bodies while geometry stays below")
	var initial := arena.player.geometer_wall_snapshot()
	casting.launch(casting.capture(&"geometer_trace", A, true))
	var first: GeometerTraceProjectile = casting.get_child(casting.get_child_count() - 1)
	first.set_process(false)
	arena.player._apply_derived_stats(StatCalculator.calculate(IdentityIds.initial_attributes(&"mage"), {&"int": 20}, 10))
	arena.player.mage_cooldowns[&"geometer_trace"] = 0.0
	casting.construction.grammar.select_element(&"ice")
	casting.launch(casting.capture(&"geometer_trace", B, true))
	var second: GeometerTraceProjectile = casting.get_child(casting.get_child_count() - 1)
	second.set_process(false)
	second._process(1.0)
	_check(casting.construction.vertices.is_empty() and casting._shot_wall_snapshots.size() == 2, "out-of-order impact retains paid-launch snapshots until FIFO delivery")
	first._process(1.0)
	_check(casting.construction.elements() == [&"fire", &"ice"] and casting._shot_wall_snapshots.is_empty(), "FIFO consumes captured launch snapshots exactly once")
	_check(is_equal_approx((casting.wall_field._snapshot["entry_request"] as DamageRequest).magic_damage, (initial["entry_request"] as DamageRequest).magic_damage), "wall freezes first successful paid launch MAG, not impact-time stats")
	await _finish()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
