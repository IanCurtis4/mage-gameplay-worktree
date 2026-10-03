extends SceneTree
## G5 composition matrix and actor lifecycle, using the real run/hit adapter.
## No production profile writes; projectile grammar has its own integration suite.

const A := Vector2(200, 200)
const B := Vector2(500, 200)
const C := Vector2(200, 500)
const ELEMENTS: Array[StringName] = [&"fire", &"ice", &"lightning"]
var checks := 0
var failures := 0
var arena: RunController
var casting: GeometerCasting
var boss: EnemyActor
var requests: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _matrix()
	await _gates()
	await _area_and_chain()
	await _slow_and_controls()
	await _lifecycle()
	await _mobile_area()
	await _snapshot()
	_check(not ProfileCatalog.new().evolution_is_ready(&"mg_ar", &"mage"), "triangle fixtures do not enable the partial production identity")
	print("Geometer triangle recipes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _fixture(rank: int = 5) -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g5-triangle-recipes-fixture"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.skill_ranks = {&"geometer_trace": 5, &"geometer_triangulation": rank}
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation"]
	snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", null, null, null]
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
	boss.global_position = Vector2(300, 300)
	casting = arena.geometer_casting
	requests.clear()
	casting.hit.connect(func(request: DamageRequest, _target: CombatActor) -> void: requests.append(request.copy()))

func _finish_fixture() -> void:
	paused = false
	arena.queue_free()
	await process_frame

func _triangle(recipe: Array[StringName], rank: int = 5, mobile: bool = false) -> bool:
	casting.clear_construction()
	casting.construction.add_vertex(recipe[0], A, 0, rank, arena.navigation)
	casting.construction.add_vertex(recipe[1], B, 0, rank, arena.navigation)
	var result := casting.construction.add_vertex(recipe[2], C, boss.get_instance_id() if mobile else 0, rank, arena.navigation)
	if result["ok"]:
		casting.triangle_field.form()
	return result["ok"]

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

func _secondary(request: DamageRequest) -> bool:
	return request.is_secondary and request.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and not request.can_crit and not request.force_critical and request.physical_damage == 0.0 and request.prismatic_resonance_damage == 0.0

func _resolution_power(element: StringName, rank: int) -> float:
	return (0.80 + (rank - 1) * 0.10) if element == &"fire" else ((0.30 + (rank - 1) * 0.05) if element == &"ice" else (0.60 + (rank - 1) * 0.10))

func _maintenance_power(recipe: Array[StringName], rank: int) -> float:
	return (0.12 + (rank - 1) * 0.02 if recipe[0] == &"fire" else 0.0) + (0.18 + (rank - 1) * 0.03 if recipe[1] == &"fire" else 0.0)

func _required_rank(recipe: Array[StringName]) -> int:
	if recipe[0] == recipe[1] and recipe[1] == recipe[2]:
		return 1
	return 5 if recipe[0] != recipe[1] and recipe[0] != recipe[2] and recipe[1] != recipe[2] else 3

func _matrix() -> void:
	for first: StringName in ELEMENTS:
		for second: StringName in ELEMENTS:
			for third: StringName in ELEMENTS:
				var recipe: Array[StringName] = [first, second, third]
				var minimum := _required_rank(recipe)
				_check(GeometerGeometry.triangle_rank(recipe) == minimum, "%s/%s/%s compositional rank gate" % [first, second, third])
				for rank: int in [minimum, 5]:
					_fixture(rank)
					var label := "%s/%s/%s R%d" % [first, second, third, rank]
					var hp := boss.health.current_hp
					var sp := arena.player.current_sp
					var magic := arena.player.stat_breakdown.value(&"magic_attack")
					_check(_triangle(recipe, rank), "%s permitted construction" % label)
					var closure := _for_actor(boss)
					_check(closure.size() == 1 and boss.health.current_hp < hp, "%s resolves C immediately once through canonical health" % label)
					if closure.size() == 1:
						_check(is_equal_approx(closure[0].magic_damage, magic * _resolution_power(third, rank)) and _secondary(closure[0]), "%s rank-specific C is secondary geometry without crit" % label)
					_check(boss.is_rooted() == (third == &"ice"), "%s only C-G roots" % label)
					casting.triangle_field.form()
					_check(_for_actor(boss).size() == 1, "%s repeated notification cannot replay closure" % label)
					casting.advance(0.01)
					var expected_slow := 0.20 if second == &"ice" else (0.10 if first == &"ice" else 0.0)
					_check(is_equal_approx(boss.slow_fraction, expected_slow), "%s A/B slow takes maximum, never sums" % label)
					_check(_for_actor(boss).size() == 1, "%s A/B have no initial damage tick" % label)
					casting.advance(0.99)
					var hits := _for_actor(boss)
					var maintenance := _maintenance_power(recipe, rank)
					_check(hits.size() == (2 if maintenance > 0.0 else 1), "%s shared one-second schedule only damages with A/B-F" % label)
					if maintenance > 0.0 and hits.size() == 2:
						_check(is_equal_approx(hits[1].magic_damage, magic * maintenance) and _secondary(hits[1]), "%s maintenance uses one summed request per victim" % label)
					_check(arena.player.current_sp == sp and _for_actor(arena.player).is_empty(), "%s owner neither receives own damage nor changes SP" % label)
					await _finish_fixture()

func _gates() -> void:
	_fixture()
	for first: StringName in ELEMENTS:
		for second: StringName in ELEMENTS:
			for third: StringName in ELEMENTS:
				var recipe: Array[StringName] = [first, second, third]
				var minimum := _required_rank(recipe)
				if minimum == 1:
					continue
				casting.clear_construction()
				casting.construction.add_vertex(first, A, 0, 5, arena.navigation)
				casting.construction.add_vertex(second, B, 0, 5, arena.navigation)
				var before := requests.size()
				var result := casting.construction.add_vertex(third, C, 0, minimum - 1, arena.navigation)
				_check(not result["ok"] and casting.construction.vertices.size() == 2 and requests.size() == before, "%s/%s/%s requires rank%d before formation" % [first, second, third, minimum])
	await _finish_fixture()

func _area_and_chain() -> void:
	_fixture()
	var border := _spawn(Vector2(350, 195))
	var far := _spawn(Vector2(550, 350))
	var blocked := _spawn(Vector2(300, 195))
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(290, 197, 20, 1)], 18)
	_check(_triangle([&"fire", &"fire", &"fire"]), "obstacle outside triangle does not invalidate polygon")
	_check(_for_actor(border).size() == 1 and _for_actor(far).is_empty(), "C uses circle-versus-triangle intersection rather than center-only or broad radius")
	_check(_for_actor(blocked).is_empty(), "C excludes an overlapping body hidden behind outside obstacle")
	casting.advance(1.0)
	_check(_for_actor(border).size() == 2 and _for_actor(blocked).is_empty(), "maintenance shares area and LoS eligibility with C")
	await _finish_fixture()
	_fixture()
	boss.global_position = Vector2(240, 430)
	var second := _spawn(Vector2(260, 340))
	var third := _spawn(Vector2(310, 270))
	var fourth := _spawn(Vector2(450, 220))
	_triangle([&"lightning", &"lightning", &"lightning"])
	_check(requests.size() == 3 and requests[0].target_id == boss.get_instance_id() and requests[1].target_id == second.get_instance_id() and requests[2].target_id == third.get_instance_id(), "C-R starts nearest C and follows at most three distinct visible links")
	_check(_for_actor(fourth).is_empty(), "C-R cannot hit fourth occupant or exceed link range")
	requests.clear()
	casting.advance(3.0)
	_check(requests.is_empty(), "RRR maintenance has no automatic damage without own attacks")
	await _finish_fixture()
	_fixture()
	boss.global_position = Vector2(240, 430)
	var distant := _spawn(Vector2(450, 220))
	_triangle([&"lightning", &"lightning", &"lightning"])
	_check(requests.size() == 1 and _for_actor(distant).is_empty(), "C-R stops at a disconnected occupant instead of global chaining")
	await _finish_fixture()

func _slow_and_controls() -> void:
	_fixture()
	_triangle([&"ice", &"ice", &"ice"])
	var expected_root := 0.7 * (1.0 - clampf(boss.stat_breakdown.value(&"magic_cc_resistance"), 0.0, 0.5))
	_check(is_equal_approx(boss.root_remaining(), expected_root), "containment uses magic resistance in canonical hard-control state")
	casting.advance(0.01)
	_check(is_equal_approx(boss.slow_fraction, 0.20) and is_equal_approx(boss.slow_remaining, 0.6), "GG layers refresh strongest movement slow with 0.6-second residual")
	boss.global_position = Vector2(600, 600)
	casting.advance(0.2)
	boss.advance_statuses(0.59)
	_check(boss.slow_fraction > 0.0, "leaving field retains residual slow until duration elapses")
	boss.advance_statuses(0.02)
	_check(boss.slow_fraction == 0.0, "residual slow expires without permanent debuff")
	await _finish_fixture()
	_fixture()
	boss.hard_controls.boss_budget_remaining = 0.0
	var before := boss.health.current_hp
	_triangle([&"ice", &"ice", &"ice"])
	_check(not boss.is_rooted() and boss.health.current_hp < before, "exhausted boss hard-control budget rejects root without suppressing magical damage")
	await _finish_fixture()

func _lifecycle() -> void:
	_fixture()
	_triangle([&"fire", &"fire", &"fire"])
	requests.clear()
	casting.advance(0.5)
	var identity := casting.construction.construction_id
	var remaining := casting.construction.figure_remaining
	paused = true
	casting.advance(3.0)
	casting.triangle_field.form()
	_check(requests.is_empty() and casting.construction.figure_remaining == remaining, "pause freezes deadlines and does not replay or tick")
	paused = false
	casting.advance(0.5)
	_check(_for_actor(boss).size() == 1, "resume continues one-second schedule rather than catch-up")
	casting.construction.edit(Vector2(200, 480), 0, false, 5, arena.navigation)
	casting.triangle_field.form()
	_check(requests.size() == 1 and casting.construction.construction_id == identity, "valid edit preserves identity and never repeats C")
	casting.advance(2.5)
	_check(requests.size() == 2, "large valid advance has at most one maintenance tick")
	casting.clear_construction()
	casting.advance(1.0)
	_check(requests.size() == 2, "cleanup synchronously disables maintenance")
	await _finish_fixture()
	_fixture()
	boss.global_position = C
	_triangle([&"fire", &"fire", &"fire"], 5, true)
	var occupant := _spawn(Vector2(300, 300))
	requests.clear()
	casting.advance(0.5)
	boss.global_position = Vector2(1100, 500)
	casting.advance(2.0)
	_check(casting.construction.suspended and requests.is_empty(), "invalid mobile area suspends effects while figure ages")
	boss.global_position = C
	casting.advance(0.01)
	_check(casting.construction.has_active_figure() and requests.is_empty(), "resume does not replay C or retroactively tick suspension")
	casting.advance(1.0)
	_check(_for_actor(occupant).size() == 1, "resumed area damages only on a new valid schedule")
	casting.advance(casting.construction.figure_remaining + 0.01)
	_check(casting.construction.shape == GeometerConstructionState.Shape.EMPTY and _for_actor(occupant).size() == 1, "expiration removes triangle without resolving C again")
	await _finish_fixture()
	_fixture()
	_triangle([&"fire", &"fire", &"fire"])
	requests.clear()
	boss.global_position = Vector2(350, 400)
	casting.construction.grammar.select_element(&"ice")
	var rewrite := casting.construction.edit(Vector2(500, 500), 0, true, 5, arena.navigation)
	_check(rewrite["ok"], "rewrite fixture preserves valid current polygon")
	casting.triangle_field.form()
	casting.advance(1.0)
	_check(requests.size() == 1, "rewrite changes maintenance functions without replaying new C")
	if requests.size() == 1:
		_check(is_equal_approx(requests[0].magic_damage, arena.player.stat_breakdown.value(&"magic_attack") * 0.50), "rewritten F/F/G retains one summed maintenance request")
	await _finish_fixture()

func _snapshot() -> void:
	_fixture(1)
	_triangle([&"fire", &"fire", &"fire"], 1)
	var initial_magic := arena.player.stat_breakdown.value(&"magic_attack")
	requests.clear()
	arena.player.run_state.skill_levels[&"geometer_triangulation"] = 5
	arena.player._apply_derived_stats(StatCalculator.calculate(IdentityIds.initial_attributes(&"mage"), {&"int": 20}, 10))
	casting.construction.edit(Vector2(200, 480), 0, false, 5, arena.navigation)
	casting.triangle_field.form()
	casting.advance(1.0)
	_check(requests.size() == 1 and is_equal_approx(requests[0].magic_damage, initial_magic * 0.30), "editing keeps captured MAG and rank instead of recalculating maintenance")
	await _finish_fixture()

func _mobile_area() -> void:
	_fixture()
	boss.global_position = C
	var old_occupant := _spawn(Vector2(240, 430))
	var new_occupant := _spawn(Vector2(450, 400))
	_triangle([&"fire", &"fire", &"fire"], 5, true)
	_check(_for_actor(old_occupant).size() == 1 and _for_actor(new_occupant).is_empty(), "mobile area initially resolves current polygon only")
	requests.clear()
	boss.global_position = Vector2(500, 500)
	casting.advance(1.0)
	_check(not casting.construction.suspended and _for_actor(old_occupant).is_empty() and _for_actor(new_occupant).size() == 1, "valid mobile field affects current area, not swept or previous occupants")
	var before := requests.size()
	var remaining := casting.construction.figure_remaining
	for invalid_delta: float in [0.0, -1.0, NAN, INF]:
		casting.advance(invalid_delta)
	_check(requests.size() == before and casting.construction.figure_remaining == remaining, "invalid deltas cannot advance or duplicate triangle effects")
	await _finish_fixture()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
