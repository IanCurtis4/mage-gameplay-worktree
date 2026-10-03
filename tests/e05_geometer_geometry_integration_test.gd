extends SceneTree
## G2/G3 real adapter and death callbacks; no field combat effects or profile writes.

const A := Vector2(200, 200)
const B := Vector2(450, 200)
const C := Vector2(200, 450)
var checks := 0
var failures := 0
var closures := 0
var arena: RunController
var casting: GeometerCasting
var player: PlayerActor
var boss: EnemyActor

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g23-fixture"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.skill_ranks = {&"geometer_trace": 1, &"geometer_triangulation": 5}
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation"]
	snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", null, null, null]
	RunController.pending_run_state = RunState.from_build("g23-fixture", snapshot)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	player = arena.player
	player.set_process(false)
	boss = arena.training_boss
	boss.set_process(false)
	casting = arena.geometer_casting
	casting.triangle_field.enabled = false # Isolate the geometry/death matrix from G5 resolution.
	casting.construction_closed.connect(func(_result: Dictionary) -> void: closures += 1)
	arena._training_add_elapsed = -1000.0
	_reset()
	_ordered_impacts()
	_queued_death()
	_geometry_changes()
	_moving_figure()
	_death_and_expiration()
	_frame_rates()
	_check(not ProfileCatalog.pilot().evolution_is_ready(&"mg_ar", &"mage"), "G2/G3 still do not unlock partial production library")
	_reset()
	var flight := _shoot(&"fire", A)
	arena._show_result(false)
	_check(casting.construction.vertices.is_empty() and casting.construction.grammar.pending_count() == 0 and flight.is_queued_for_deletion(), "run end synchronously invalidates geometry and flight")
	paused = false
	arena.queue_free()
	await process_frame
	print("Geometer geometry integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _ordered_impacts() -> void:
	_reset()
	var sp := player.current_sp
	var first := _shoot(&"fire", Vector2(680, 100))
	var second := _shoot(&"ice", A)
	second._process(0.2)
	_check(casting.construction.vertices.is_empty() and casting.construction.grammar.pending_count() == 2, "near second impact waits for distant first")
	casting.advance(0.4)
	first._process(0.7)
	_check(casting.construction.elements() == [&"fire", &"ice"] and casting.construction.shape == GeometerConstructionState.Shape.WALL, "real flights commit in command order, never arrival order")
	_check(is_equal_approx(casting.construction.vertices[1].remaining, 7.6), "already impacted queued vertex does not gain a fresh lifetime when released")
	_check(player.current_sp == sp - 16.0 and player.skill_cooldown(&"geometer_trace") > 0.0, "ordered processing adds no cost or cooldown reset")
	_reset()
	first = _shoot(&"fire", Vector2(680, 100))
	second = _shoot(&"ice", A)
	second._process(0.2)
	first.queue_free() # A lost node must not wedge the grammar forever.
	casting.advance(3.0)
	_check(casting.construction.elements() == [&"ice"] and casting.construction.grammar.pending_count() == 0, "lost first flight times out and releases already impacted second")
	_check(is_equal_approx(casting.construction.vertices[0].remaining, 5.0), "queue timeout consumes elapsed vertex lifetime rather than refreshing it")

func _queued_death() -> void:
	_reset()
	var carrier := _add_target(A)
	var first := _shoot(&"fire", Vector2(680, 100))
	var second := _shoot(&"ice", carrier.global_position, &"geometer_trace", carrier)
	second._process(0.2)
	carrier.global_position = Vector2(230, 220)
	casting.advance(0.3)
	var last_ground := carrier.global_position
	_kill(carrier)
	first._process(0.7)
	_check(casting.construction.vertices.size() == 2 and casting.construction.vertices[1].actor_id == 0, "queued confirmed impact survives carrier death as ground, never corpse")
	_check(casting.construction.vertices[1].position == last_ground and is_equal_approx(casting.construction.vertices[1].remaining, 7.7), "queued death retains last valid ground and original impact clock")
	_check(arena.enemies.size() == 1 and not arena.run_finished, "real carrier death leaves boss encounter running")
	_reset()
	carrier = _add_target(A)
	first = _shoot(&"fire", Vector2(680, 100))
	second = _shoot(&"ice", A, &"geometer_trace", carrier)
	second._process(0.2)
	carrier.global_position = Vector2(230, 220)
	casting.advance(0.2)
	last_ground = carrier.global_position
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(280, 260, 40, 40)], 18.0)
	carrier.global_position = Vector2(300, 280)
	casting.advance(0.2)
	_kill(carrier)
	_finish(first)
	_check(casting.construction.vertices[1].position == last_ground and is_equal_approx(casting.construction.vertices[1].remaining, 7.6), "queued carrier death on blocked ground deposits at latest free position, with elapsed lifetime")

func _geometry_changes() -> void:
	_reset()
	_finish(_shoot(&"fire", A))
	_finish(_shoot(&"ice", B))
	var state := casting.construction
	var identity := state.construction_id
	var deadline := state.figure_remaining
	casting.select(&"lightning")
	var command := casting.capture(&"geometer_triangulation", C, true)
	_check(casting.check(command)["ok"], "third point preview initially valid")
	var flight := _shoot(&"lightning", C, &"geometer_triangulation")
	var sp := player.current_sp
	# This obstacle is wholly inside the triangle, not on any edge or shot path.
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(270, 270, 20, 20)], 18.0)
	_finish(flight)
	_check(state.shape == GeometerConstructionState.Shape.WALL and state.positions() == PackedVector2Array([A, B]) and state.construction_id == identity, "obstacle entering interior during third flight preserves existing wall")
	_check(closures == 0 and state.figure_remaining == deadline and player.current_sp == sp, "failed third cannot close, refresh figure or charge at impact")
	_check(not casting.check(command)["ok"], "same obstacle rejected by current preview")
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(420, 420, 20, 20)], 18.0)
	player.mage_cooldowns.clear()
	_check(casting.check(command)["ok"], "obstacle inside bounding box but outside real triangle does not invalidate preview")
	_finish(_shoot(&"lightning", C, &"geometer_triangulation"))
	_check(state.shape == GeometerConstructionState.Shape.TRIANGLE and closures == 1, "valid third closes once using same geometry as preview")
	_check(arena.navigation.add_temporary_segment(123, Vector2(270, 270), Vector2(300, 270), 6.0, []), "real navigation accepts enclosed temporary barrier fixture")
	casting.advance(0.1)
	_check(state.suspended and closures == 1, "temporary barrier inside area suspends without wall effects or closure replay")
	arena.navigation.remove_temporary_segment(123)
	casting.advance(0.1)
	_check(state.has_active_figure() and closures == 1, "temporary barrier removal resumes original triangle")
	_reset()
	boss.global_position = B
	_finish(_shoot(&"fire", A))
	_finish(_shoot(&"ice", B, &"geometer_trace", boss))
	flight = _shoot(&"lightning", C, &"geometer_triangulation")
	boss.global_position = Vector2(200, 300)
	_finish(flight)
	_check(state.shape == GeometerConstructionState.Shape.WALL and state.positions()[1] == boss.global_position and closures == 0, "carrier movement during third flight revalidates current points and preserves wall")
	_reset()
	_finish(_shoot(&"fire", A))
	_finish(_shoot(&"fire", B))
	_check(casting.construction.shape == GeometerConstructionState.Shape.PREPARATION and not casting.construction.has_active_figure(), "identical pair remains inert in real runtime")
	_finish(_shoot(&"fire", C, &"geometer_triangulation"))
	_check(casting.construction.has_active_figure() and closures == 1, "pure recipe forms from inert pair only on third impact")

func _moving_figure() -> void:
	_reset()
	boss.global_position = B
	_finish(_shoot(&"fire", A))
	_finish(_shoot(&"ice", B, &"geometer_trace", boss))
	_finish(_shoot(&"lightning", C, &"geometer_triangulation"))
	var state := casting.construction
	var identity := state.construction_id
	_check(closures == 1 and state.vertices[1].actor_id == boss.get_instance_id(), "mixed static/mobile triangle binds real boss")
	boss.global_position = Vector2(200, 300)
	arena._process(0.5)
	_check(state.suspended and not state.has_active_figure() and state.shape == GeometerConstructionState.Shape.TRIANGLE and closures == 1, "collinear boss position suspends without reopening triangle")
	var outline := casting.outline_segments()
	_check(outline.size() == 3 and outline[2] == PackedVector2Array([C, A]), "suspended triangle underlay keeps all three actual edges, including closing C to A")
	var deadline := state.figure_remaining
	paused = true
	boss.global_position = B
	arena._process(2.0)
	_check(state.suspended and state.figure_remaining == deadline and state.positions()[1] == Vector2(200, 300), "paused real controller freezes geometry and clocks")
	paused = false
	arena._process(0.5)
	_check(state.has_active_figure() and state.construction_id == identity and closures == 1 and is_equal_approx(state.figure_remaining, deadline - 0.5), "resume keeps identity, remaining time and single closure")
	# The boss crosses orientation around static A/C; token sequence must stay A/B/C.
	boss.global_position = Vector2(100, 300)
	arena._process(0.1)
	_check(state.has_active_figure() and state.elements() == [&"fire", &"ice", &"lightning"] and closures == 1, "winding inversion neither reorders recipe nor resolves again")
	boss.global_position = Vector2(1200, 300)
	arena._process(0.1)
	_check(state.suspended and state.figure_remaining > 0.0, "overlong mobile edge suspends")
	boss.global_position = B
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(270, 270, 20, 20)], 18.0)
	arena._process(0.1)
	_check(state.suspended and closures == 1, "obstacle newly enclosed by existing mobile area suspends")
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [], 18.0)
	arena._process(0.1)
	_check(state.has_active_figure() and closures == 1, "removing obstacle resumes without formation event")
	boss.global_position = Vector2(NAN, 300)
	casting.advance(0.1)
	_check(state.suspended and casting.outline_segments() == [PackedVector2Array([C, A])], "nonfinite carrier suspends and drawing omits only invalid segments")
	boss.global_position = B
	casting.advance(0.1)
	_check(state.has_active_figure() and casting.outline_segments().size() == 3 and closures == 1, "finite carrier restoration restores outline without resolving again")
	boss.global_position = Vector2(1200, 300)
	arena._process(state.figure_remaining + 0.01)
	_check(state.vertices.is_empty() and state.grammar.pending_count() == 0, "suspended real controller still expires whole figure")

func _death_and_expiration() -> void:
	_reset()
	var first_carrier := _add_target(A)
	var second_carrier := _add_target(B)
	_finish(_shoot(&"fire", A, &"geometer_trace", first_carrier))
	_finish(_shoot(&"ice", B, &"geometer_trace", second_carrier))
	_finish(_shoot(&"lightning", C, &"geometer_triangulation"))
	var state := casting.construction
	first_carrier.global_position = Vector2(220, 220)
	arena._process(0.5)
	var position_before_death := first_carrier.global_position
	var vertex_time := state.vertices[0].remaining
	var figure_time := state.figure_remaining
	_kill(first_carrier)
	casting.advance(0.1)
	_check(state.vertices.size() == 3 and state.vertices[0].actor_id == 0 and state.vertices[0].position == position_before_death and state.vertices[1].actor_id == second_carrier.get_instance_id(), "actual death deposits one anchor and preserves remaining mobile carrier")
	_check(is_equal_approx(state.vertices[0].remaining, vertex_time - 0.1) and is_equal_approx(state.figure_remaining, figure_time - 0.1) and closures == 1, "actual death does not reset clocks or closure")
	var last_ground := second_carrier.global_position
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(480, 250, 40, 40)], 18.0)
	second_carrier.global_position = Vector2(500, 270)
	casting.advance(0.1)
	_check(state.suspended, "carrier on blocked ground suspends")
	_kill(second_carrier)
	casting.advance(0.1)
	_check(state.vertices[1].actor_id == 0 and state.vertices[1].position == last_ground and state.has_active_figure(), "death on blocked ground falls back to last free ground, never obstacle")
	_reset()
	_finish(_shoot(&"fire", A))
	casting.advance(7.8)
	var flight := _shoot(&"ice", B)
	casting.advance(0.21)
	_check(state.vertices.is_empty() and state.grammar.pending_count() == 0 and flight.is_queued_for_deletion(), "vertex expiry also retires uncommitted flight synchronously")
	var hp := boss.health.current_hp
	casting._on_delivered(flight.ticket, true, boss.global_position, boss, flight)
	_check(boss.health.current_hp == hp and state.vertices.is_empty(), "callback after vertex expiry cannot damage or reconstruct")
	_reset()
	_finish(_shoot(&"fire", A))
	_finish(_shoot(&"ice", B))
	casting.advance(5.8)
	flight = _shoot(&"lightning", C, &"geometer_triangulation")
	casting.advance(0.21)
	_check(state.vertices.is_empty() and state.grammar.pending_count() == 0 and flight.is_queued_for_deletion() and closures == 0, "figure deadline wins over outstanding third and clears its visual")

func _frame_rates() -> void:
	for hz: int in [30, 60, 144]:
		_reset()
		boss.global_position = B
		_finish(_shoot(&"fire", A))
		_finish(_shoot(&"ice", B, &"geometer_trace", boss))
		_finish(_shoot(&"lightning", C, &"geometer_triangulation"))
		var state := casting.construction
		var hp := boss.health.current_hp
		for frame: int in range(hz):
			boss.global_position = Vector2(200, 300) if frame < hz / 2 else B
			arena._process(1.0 / float(hz))
		_check(state.has_active_figure() and is_equal_approx(state.figure_remaining, 5.0) and closures == 1 and boss.health.current_hp == hp, "%d Hz: suspension/resume consumes one second, no resolution replay or swept damage" % hz)

func _shoot(element: StringName, point: Vector2, skill: StringName = &"geometer_trace", target: CombatActor = null) -> GeometerTraceProjectile:
	player.mage_cooldowns[skill] = 0.0 # Closed fixture choreography, not production cooldown bypass.
	casting.select(element)
	var command := casting.capture(skill, point + BattleTargeting.BODY_OFFSET if target != null else point, target == null)
	if not casting.begin(command):
		_check(false, "fixture launch must be valid: %s at %s" % [element, point])
		return null
	player._advance_active_cast(player.active_cast_remaining + 0.001)
	for child: Node in casting.get_children():
		if child is GeometerTraceProjectile and not child.is_queued_for_deletion() and child.ticket == casting.construction.grammar.pending_snapshot()[-1]["ticket"]:
			child.set_process(false)
			return child as GeometerTraceProjectile
	_check(false, "fixture produces an actual flight")
	return null

func _finish(flight: GeometerTraceProjectile) -> void:
	if flight != null:
		flight._process(0.7)

func _add_target(point: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Portador de teste", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	actor.health.max_hp = 10000.0
	actor.health.current_hp = 10000.0
	actor.position = point
	arena.add_child(actor)
	actor.set_process(false)
	actor.actor_died.connect(arena._on_enemy_died)
	arena.enemies.append(actor)
	return actor

func _kill(actor: CombatActor) -> void:
	var request := DamageRequest.new()
	request.source_id = player.get_instance_id()
	request.target_id = actor.get_instance_id()
	request.magic_damage = 1000000.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	arena._on_attack_requested(request, actor)

func _reset() -> void:
	casting.clear_construction()
	for child: Node in casting.get_children():
		if child is GeometerTraceProjectile:
			child.free()
	for actor: CombatActor in arena.enemies.duplicate():
		if actor != boss:
			arena.enemies.erase(actor)
			actor.free()
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [], 18.0)
	player.global_position = Vector2(100, 100)
	player.current_sp = player.max_sp
	player.mage_cooldowns.clear()
	boss.global_position = Vector2(850, 650)
	closures = 0

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
