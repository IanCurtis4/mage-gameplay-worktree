extends SceneTree
## G4 actor recipes exercised through real walking and the canonical hit adapter.
## Fixture-only identity; no profile writes or triangle combat implementation.

const A := Vector2(200, 200)
const B := Vector2(500, 200)
var checks := 0
var failures := 0
var arena: RunController
var casting: GeometerCasting
var boss: EnemyActor
var requests: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _recipes()
	await _incidence()
	await _pulse_and_dedup()
	await _lifecycle()
	await _snapshot()
	_check(not ProfileCatalog.new().evolution_is_ready(&"mg_ar", &"mage"), "fixture does not enable production identity")
	print("Geometer wall effects: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _fixture(trace_rank: int = 1, incidence_rank: int = 0, equipped: bool = true) -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g4-wall-effects-fixture"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.skill_ranks = {&"geometer_trace": trace_rank, &"geometer_triangulation": 5}
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation"]
	snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", null, null, null]
	if incidence_rank > 0:
		snapshot.skill_ranks[&"geometer_incidence"] = incidence_rank
		snapshot.library_skill_ids.append(&"geometer_incidence")
		if equipped:
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
	boss = arena.training_boss
	boss.global_position = Vector2(300, 100)
	casting = arena.geometer_casting
	requests.clear()
	casting.hit.connect(func(request: DamageRequest, _target: CombatActor) -> void: requests.append(request.copy()))

func _finish_fixture() -> void:
	paused = false
	arena.queue_free()
	await process_frame

func _wall(first: StringName, second: StringName, mobile: bool = false) -> void:
	casting.clear_construction()
	casting.construction.add_vertex(first, A, 0, 5, arena.navigation)
	casting.construction.add_vertex(second, B, boss.get_instance_id() if mobile else 0, 5, arena.navigation)
	casting.advance(0.01)
	requests.clear()

func _walk(actor: EnemyActor, x: float = 300.0, backwards: bool = false, end_y: float = 220.0) -> void:
	actor.global_position = Vector2(x, 300 if backwards else 100)
	actor._path = PackedVector2Array([Vector2(x, 180 if backwards else end_y)])
	actor._path_index = 0
	actor._move_along_path(3.0)

func _spawn(point: Vector2) -> EnemyActor:
	var actor := arena._spawn_enemy(&"chaser", point)
	actor.set_process(false)
	return actor

func _for_actor(actor: CombatActor) -> Array[DamageRequest]:
	var matches: Array[DamageRequest] = []
	for request: DamageRequest in requests:
		if request.target_id == actor.get_instance_id():
			matches.append(request)
	return matches

func _recipes() -> void:
	var recipes: Array[Array] = [[&"fire", &"ice"], [&"fire", &"lightning"], [&"ice", &"fire"], [&"ice", &"lightning"], [&"lightning", &"fire"], [&"lightning", &"ice"]]
	for rank: int in [1, 5]:
		for recipe: Array in recipes:
			_fixture(rank)
			_wall(recipe[0], recipe[1])
			var hp := boss.health.current_hp
			var sp := arena.player.current_sp
			_walk(boss)
			var hits := _for_actor(boss)
			var damaging: bool = recipe[0] == &"fire" or recipe[1] == &"fire"
			var slowing: bool = recipe[0] == &"ice"
			var label := "%s -> %s rank%d" % [recipe[0], recipe[1], rank]
			_check(hits.size() == (1 if damaging else 0), "%s one composite victim interaction" % label)
			_check((boss.health.current_hp < hp) == damaging, "%s canonical health application" % label)
			_check(is_equal_approx(boss.slow_fraction, (0.20 if rank == 1 else 0.30) if slowing else 0.0), "%s only ice entry slows" % label)
			_check(arena.player.current_sp == sp, "%s traversal neither spends nor refunds SP" % label)
			if damaging and not hits.is_empty():
				var coefficient: float = (0.35 if rank == 1 else 0.55) if recipe[0] == &"fire" else (0.30 if rank == 1 else 0.50)
				_check(is_equal_approx(hits[0].magic_damage, arena.player.stat_breakdown.value(&"magic_attack") * coefficient), "%s rank scales snapshotted magic" % label)
				_check(hits[0].is_secondary and hits[0].accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and not hits[0].can_crit and hits[0].physical_damage == 0.0, "%s secondary geometry request cannot recurse or crit" % label)
			if slowing:
				_check(is_equal_approx(boss.slow_remaining, 2.0) and boss.attribute_debuffs.fraction(AttributeDebuffState.ATTACK_SPEED) == 0.0, "%s two-second movement slow without ASPD reduction" % label)
			casting.advance(0.5)
			_walk(boss, 300, true)
			_check(_for_actor(boss).size() == hits.size(), "%s reverse crossing respects shared two-second window" % label)
			await _finish_fixture()

func _incidence() -> void:
	for rank: int in [1, 2, 3]:
		for equipped: bool in [true, false]:
			_fixture(1, rank, equipped)
			_wall(&"fire", &"ice")
			_walk(boss)
			var expected := arena.player.stat_breakdown.value(&"magic_attack") * 0.35 * (1.0 + (0.05 + rank * 0.05 if equipped else 0.0))
			var hits := _for_actor(boss)
			_check(hits.size() == 1 and is_equal_approx(hits[0].magic_damage, expected), "Incidence rank%d bonus requires passive slot (%s)" % [rank, equipped])
			await _finish_fixture()

func _pulse_and_dedup() -> void:
	_fixture()
	_wall(&"ice", &"fire")
	var neighbor := _spawn(Vector2(315, 220))
	var far := _spawn(Vector2(420, 220))
	var blocked := _spawn(Vector2(350, 230))
	var second := _spawn(Vector2(280, 100))
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(324, 212, 8, 8)], 18)
	casting.advance(0.01)
	_walk(boss)
	_check(_for_actor(neighbor).size() == 1 and _for_actor(far).is_empty(), "fire exit pulse includes nearby victims and rejects distant bodies")
	_check(_for_actor(blocked).is_empty(), "fire exit pulse cannot pass through obstacle outside valid wall")
	_check(neighbor.slow_fraction == 0.0, "exit pulse does not copy crosser-only slow to nearby victims")
	var neighbor_hits := _for_actor(neighbor).size()
	_walk(second, 280)
	_check(_for_actor(neighbor).size() == neighbor_hits and _for_actor(boss).size() == 1, "separate crossing explosions share victim cadence")
	_check(_for_actor(second).size() == 1 and is_equal_approx(second.slow_fraction, 0.20), "new crossing victim receives combined slow and pulse")
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [], 18)
	casting.advance(2.0)
	_walk(boss)
	_check(_for_actor(neighbor).size() == neighbor_hits + 1 and _for_actor(boss).size() == 2, "victims eligible again at two-second boundary")
	await _finish_fixture()
	_fixture()
	_wall(&"lightning", &"fire")
	_walk(boss, 300, false, 450)
	_check(_for_actor(boss).size() == 1, "large real walking delta retains crosser at actual pulse intersection")
	await _finish_fixture()

func _lifecycle() -> void:
	_fixture()
	_wall(&"fire", &"ice")
	paused = true
	var remaining := casting.construction.figure_remaining
	var elapsed := casting.interaction_ledger.elapsed
	_walk(boss)
	casting.advance(2.0)
	_check(requests.is_empty() and casting.construction.figure_remaining == remaining and casting.interaction_ledger.elapsed == elapsed, "pause blocks recipes and freezes figure and claims")
	paused = false
	_walk(boss)
	_check(_for_actor(boss).size() == 1, "first real traversal after pause remains eligible")
	casting.construction.edit(Vector2(1000, 200), 0, false, 5, arena.navigation)
	_check(_for_actor(boss).size() == 1, "invalid edit produces no damage or catch-up")
	casting.construction.add_vertex(&"lightning", Vector2(200, 450), 0, 5, arena.navigation)
	casting.advance(2.0)
	_walk(boss)
	_check(_for_actor(boss).size() == 1, "triangle inherits no wall traversal effects after cadence expires")
	casting.clear_construction()
	_walk(boss)
	_check(_for_actor(boss).size() == 1, "cleanup invalidates wall effects synchronously")
	await _finish_fixture()
	_fixture()
	boss.global_position = B
	_wall(&"fire", &"ice", true)
	var stationary := _spawn(Vector2(350, 300))
	boss.global_position = Vector2(500, 400)
	casting.advance(0.01)
	_check(requests.is_empty(), "moving wall does not sweep damage across stationary victim")
	boss.global_position = Vector2(1100, 200)
	casting.advance(0.1)
	var clock := casting.construction.figure_remaining
	_walk(stationary, 300)
	_check(casting.construction.suspended and requests.is_empty(), "invalid mobile geometry suspends traversal damage")
	boss.global_position = B
	casting.advance(0.1)
	_check(casting.construction.has_active_figure() and casting.construction.figure_remaining < clock and requests.is_empty(), "resume consumes time without retrospective hit")
	_walk(stationary, 300)
	_check(_for_actor(stationary).size() == 1, "new real traversal after resume applies one recipe")
	casting.advance(casting.construction.figure_remaining + 0.01)
	_walk(stationary, 300)
	_check(_for_actor(stationary).size() == 1 and casting.interaction_ledger.construction_id == 0, "expiration removes wall and shared claims")
	await _finish_fixture()

func _snapshot() -> void:
	_fixture(1, 1)
	_wall(&"fire", &"ice")
	var initial_magic := arena.player.stat_breakdown.value(&"magic_attack")
	arena.player.run_state.skill_levels[&"geometer_trace"] = 5
	arena.player.run_state.skill_levels[&"geometer_incidence"] = 3
	arena.player._apply_derived_stats(StatCalculator.calculate(IdentityIds.initial_attributes(&"mage"), {&"int": 20}, 10))
	casting.construction.edit(Vector2(500, 220), 0, false, 5, arena.navigation)
	casting.advance(0.01)
	_walk(boss)
	var hits := _for_actor(boss)
	_check(hits.size() == 1 and is_equal_approx(hits[0].magic_damage, initial_magic * 0.35 * 1.10), "editing does not recapture magic, trace rank or Incidence bonus")
	casting.advance(2.0)
	_walk(boss, 300, true)
	_check(_for_actor(boss).size() == 2, "edited instance preserves shared cadence without permanently suppressing traversal")
	await _finish_fixture()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
