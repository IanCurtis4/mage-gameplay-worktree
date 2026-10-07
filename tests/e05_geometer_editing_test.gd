extends SceneTree
## G6 real scene transactions: edits, paid collapse, learned duration snapshot.

const A := Vector2(200, 200)
const B := Vector2(500, 200)
const C := Vector2(200, 500)
var checks := 0
var failures := 0
var arena: RunController
var casting: GeometerCasting
var hits: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(not ProfileCatalog.pilot({}, {}, {&"mg_ar": 3}).is_valid(), "invalid fixture override fails validation without a typed assignment crash")
	_edit_rank_progression()
	await _memory()
	await _edits()
	await _invalid()
	await _collapse_matrix()
	await _walls()
	await _collapse_bounds()
	await _cadence()
	await _input_and_cleanup()
	print("Geometer G6 editing: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _edit_rank_progression() -> void:
	for skill: StringName in [&"geometer_translation", &"geometer_rewrite"]:
		var definition := ClassCatalog.skill_definition(skill)
		for rank: int in range(1, 6):
			var current := definition.rank_definition(rank)
			_check(is_equal_approx(current.cooldown, definition.cooldown - 0.25 * (rank - 1)), "every paid edit rank improves cooldown")
			_check(current.sp_cost == definition.sp_cost and current.range == definition.range, "edit rank preserves cost and geometry")

func _fixture(memory_rank: int = 3, triangle_rank: int = 5, collapse_rank: int = 5) -> void:
	var build := BuildSnapshot.new()
	build.character_id = "geometer-g6-editing-fixture"
	build.base_class_id = &"mage"
	build.evolution_id = &"mg_ar"
	build.base_level = 30
	build.job_level = 40
	build.library_skill_ids = [&"geometer_trace", &"geometer_translation", &"geometer_triangulation", &"geometer_rewrite", &"geometer_collapse", &"geometer_incidence", &"geometer_vector_memory"]
	build.skill_ranks = {&"geometer_trace": 5, &"geometer_translation": 5, &"geometer_triangulation": triangle_rank, &"geometer_rewrite": 5, &"geometer_collapse": collapse_rank, &"geometer_incidence": 3}
	if memory_rank > 0:
		build.skill_ranks[&"geometer_vector_memory"] = memory_rank
	build.active_slots = [&"geometer_trace", &"geometer_triangulation", &"geometer_translation", &"geometer_collapse", &"geometer_rewrite"]
	build.passive_slots = [&"geometer_incidence", &"geometer_vector_memory" if memory_rank > 0 else null]
	RunController.pending_run_state = RunState.from_build("", build)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena._training_add_elapsed = -1000.0
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [], 18)
	arena.player.global_position = Vector2(100, 100)
	arena.training_boss.global_position = Vector2(300, 300)
	casting = arena.geometer_casting
	hits.clear()
	casting.hit.connect(func(request: DamageRequest, _actor: CombatActor) -> void: hits.append(request.copy()))

func _finish() -> void:
	paused = false
	arena.queue_free()
	await process_frame

func _shape(elements: Array[StringName], mobile_c: bool = false) -> void:
	casting.clear_construction()
	for index: int in elements.size():
		var point: Vector2 = [A, B, C][index]
		casting.construction.add_vertex(elements[index], point, arena.training_boss.get_instance_id() if index == 2 and mobile_c else 0, 5, arena.navigation)
	casting.wall_field.capture_construction()
	if elements.size() == 3:
		casting.triangle_field.form()
	hits.clear()

func _command(skill: StringName, point: Vector2 = C, carrier: int = 0, element: StringName = &"fire") -> GeometerCastCommand:
	var command := GeometerCastCommand.new()
	command.skill_id = skill
	command.point = point
	command.actor_id = carrier
	command.element = element
	return command

func _memory() -> void:
	for rank: int in range(4):
		_fixture(rank)
		var expected := Vector2(8, 6) + Vector2([0, 1, 2, 4][rank], rank)
		_check(arena.player.geometer_durations() == expected, "learned automatic memory rank%d supplies exact durations with ceiling12" % rank)
		casting.launch(_command(&"geometer_trace", A))
		var flight: GeometerTraceProjectile
		for child: Node in casting.get_children():
			if child is GeometerTraceProjectile: flight = child
		flight.set_process(false)
		arena.player.run_state.build_snapshot.passive_slots = [null, null]
		arena.player.run_state.build_snapshot.skill_ranks.erase(&"geometer_vector_memory")
		flight._process(1.0)
		_check(casting.construction.vertices.size() == 1 and casting.construction.vertices[0].remaining == expected.x, "paid shot captures learned duration before impact/unlearning")
		_check(arena.player.geometer_durations() == Vector2(8, 6), "unlearned memory cannot extend new vertices")
		await _finish()

func _edits() -> void:
	_fixture()
	arena.training_boss.global_position = C
	_shape([&"fire", &"ice", &"lightning"], true)
	casting.advance(0.4)
	var identity := casting.construction.construction_id
	var remaining := casting.construction.figure_remaining
	var first := casting.construction.vertices[0]
	var second := casting.construction.vertices[1]
	casting.interaction_ledger.claim_victim(123)
	var before := arena.player.current_sp
	var translation := _command(&"geometer_translation", Vector2(200, 480), 0, &"fire")
	_check(casting.check(translation)["ok"] and casting.construction.vertices[2].actor_id != 0 and arena.player.current_sp == before, "preview leaves binding, resources and state untouched")
	_check(casting.begin(translation), "valid translation executes instantly")
	_check(is_equal_approx(arena.player.skill_cooldown(&"geometer_translation"), StatCalculator.effective_cooldown(3.0, arena.player.stat_breakdown)), "rank five translation applies improved central cooldown")
	_check(arena.player.current_sp == before - 12 and arena.player.skill_cooldown(&"geometer_translation") > 0 and not arena.player.has_active_cast(), "translation charges exactly once with central cooldown")
	_check(casting.construction.vertices[2].element == &"lightning" and casting.construction.vertices[2].actor_id == 0 and casting.construction.vertices[2].remaining == 12, "translation preserves element but explicit ground detaches and refreshes only changed vertex")
	_check(casting.construction.vertices[0] == first and casting.construction.vertices[1] == second and casting.construction.figure_remaining == remaining and casting.construction.construction_id == identity, "translation preserves retained anchors, deadline and identity")
	_check(not casting.interaction_ledger.claim_victim(123) and hits.is_empty() and is_equal_approx(casting.triangle_field._elapsed, 0.4), "translation preserves victim ledger/cadence and cannot replay C")
	arena.player.mage_cooldowns[&"geometer_translation"] = 0
	arena.training_boss.global_position = Vector2(200, 460)
	_check(casting.begin(_command(&"geometer_translation", Vector2.ZERO, arena.training_boss.get_instance_id())), "translation resolves explicit live actor feet, not command point")
	_check(casting.construction.vertices[2].actor_id == arena.training_boss.get_instance_id() and casting.construction.positions()[2] == arena.training_boss.global_position, "translated point attaches to selected actor")
	arena.training_boss.global_position = Vector2(210, 450)
	casting.advance(0.1)
	_check(casting.construction.positions()[2] == arena.training_boss.global_position, "edited mobile anchor follows real current feet")
	before = arena.player.current_sp
	var rewrite := _command(&"geometer_rewrite", Vector2(500, 480), 0, &"fire")
	casting.select(&"ice")
	_check(casting.begin(rewrite), "rewrite revalidates full candidate and uses captured element")
	_check(is_equal_approx(arena.player.skill_cooldown(&"geometer_rewrite"), StatCalculator.effective_cooldown(4.0, arena.player.stat_breakdown)), "rank five rewrite applies improved central cooldown")
	_check(casting.construction.elements() == [&"ice", &"lightning", &"fire"] and casting.construction.vertices[0] == second and arena.player.current_sp == before - 14, "rewrite removes A and appends D as B/C/D without mutating retained vertices")
	_check(casting.construction.construction_id == identity and hits.is_empty() and is_equal_approx(casting.construction.figure_remaining, remaining - 0.1), "rewrite does not renew figure, identity or C")
	arena.training_boss.health.current_hp = 0
	casting.advance(0.1)
	_check(casting.construction.vertices[1].actor_id == 0 and casting.construction.vertices[1].position == Vector2(210, 450) and casting.construction.vertices[1].remaining < 12, "death after edit deposits last valid feet without renewing lifetime")
	await _finish()

func _invalid() -> void:
	for reason: String in ["empty", "pending", "degenerate", "outside", "obstacle", "invalid_actor", "pause", "no_sp", "cooldown", "unlearned", "other_identity", "recipe_rank"]:
		_fixture(3, 1 if reason == "recipe_rank" else 5)
		_shape([&"fire", &"fire", &"fire"])
		var command := _command(&"geometer_translation", Vector2(200, 480))
		match reason:
			"empty": casting.clear_construction()
			"pending": casting.construction.grammar.reserve(Vector2(250, 250), 0, 2)
			"degenerate": command.point = B
			"outside": command.point = Vector2(1300, 900)
			"obstacle": arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(210, 350, 30, 20)], 18)
			"invalid_actor": command.actor_id = 123
			"pause": paused = true
			"no_sp": arena.player.current_sp = 0
			"cooldown": arena.player.mage_cooldowns[command.skill_id] = 3
			"unlearned": arena.player.run_state.build_snapshot.skill_ranks.erase(&"geometer_translation")
			"other_identity": arena.player.run_state.build_snapshot.evolution_id = &"elementalist"
			"recipe_rank": command = _command(&"geometer_rewrite", Vector2(200, 480), 0, &"ice")
		var before := arena.player.current_sp
		var points := casting.construction.positions()
		var durations := casting.construction.vertices.map(func(anchor: GeometerAnchor) -> float: return anchor.remaining)
		var identity := casting.construction.construction_id
		_check(not casting.begin(command), reason + " rejects editing")
		_check(arena.player.current_sp == before and casting.construction.positions() == points and identity == casting.construction.construction_id and casting.construction.vertices.map(func(anchor: GeometerAnchor) -> float: return anchor.remaining) == durations and hits.is_empty(), reason + " preserves exact anchors/resources/deadline without replay")
		await _finish()

func _collapse_matrix() -> void:
	for first: StringName in GeometerGeometry.ELEMENTS:
		for second: StringName in GeometerGeometry.ELEMENTS:
			for third: StringName in GeometerGeometry.ELEMENTS:
				for rank: int in [1, 5]:
					_fixture(3, 5, rank)
					_shape([first, second, third])
					var closed_damage: float = ClassCatalog.geometer_triangle_tuning(5)[StringName("resolution_" + String(third))]
					var before := arena.player.current_sp
					var observed_empty: Array[bool] = []
					casting.hit.connect(func(_request: DamageRequest, _actor: CombatActor) -> void: observed_empty.append(casting.construction.shape == GeometerConstructionState.Shape.EMPTY))
					var command := _command(&"geometer_collapse")
					_check(casting.begin(command), "27 recipes support explicit paid collapse with independent rank%d" % rank)
					var expected := (0.80 + 0.10 * (rank - 1)) if third == &"fire" else ((0.30 + 0.05 * (rank - 1)) if third == &"ice" else (0.60 + 0.10 * (rank - 1)))
					_check(hits.size() == 1 and is_equal_approx(hits[0].magic_damage, arena.player.stat_breakdown.value(&"magic_attack") * expected) and hits[0].skill_id == &"geometer_collapse" and hits[0].is_secondary and not hits[0].can_crit, "collapse uses its own rank/MAG, not cached C%s" % closed_damage)
					_check(observed_empty == [true] and arena.player.current_sp == before - 18 and casting.construction.vertices.is_empty() and casting.interaction_ledger.construction_id == 0 and casting.triangle_field._identity == 0, "consume and cleanup precede damage; exactly one charge")
					arena.player.mage_cooldowns[&"geometer_collapse"] = 0
					_check(not casting.begin(command) and arena.player.current_sp == before - 18 and hits.size() == 1, "empty repeat cannot finalize or charge twice")
					casting.advance(1.0)
					_check(hits.size() == 1, "consumed figure has no maintenance/expiry resolution")
					await _finish()

func _walls() -> void:
	for first: StringName in GeometerGeometry.ELEMENTS:
		for second: StringName in GeometerGeometry.ELEMENTS:
			if first == second: continue
			_fixture()
			arena.training_boss.global_position = Vector2(300, 200)
			_shape([first, second])
			var far := arena._spawn_enemy(&"chaser", Vector2(300, 245))
			far.set_process(false)
			var hp := far.health.current_hp
			var magic := arena.player.stat_breakdown.value(&"magic_attack")
			_check(casting.begin(_command(&"geometer_collapse")), "six ordered walls permit collapse")
			_check(hits.size() == 1 and hits[0].magic_damage == magic and hits[0].skill_id == &"geometer_collapse" and far.health.current_hp == hp, "wall collapse is a single bounded strip pulse without theorem, crossing, slow or neighbor detonation")
			await _finish()
	for size: int in range(3):
		_fixture()
		var elements: Array[StringName] = []
		for index: int in size: elements.append(&"fire")
		_shape(elements)
		var before := arena.player.current_sp
		_check(not casting.begin(_command(&"geometer_collapse")) and arena.player.current_sp == before and hits.is_empty(), "empty/one vertex/equal preparation cannot collapse")
		await _finish()

func _input_and_cleanup() -> void:
	for mode: CastIntent.Mode in [CastIntent.Mode.CONFIRM, CastIntent.Mode.RELEASE, CastIntent.Mode.INSTANT]:
		_fixture()
		_shape([&"fire", &"fire", &"fire"])
		arena.cast_intent.mode = mode
		var before := arena.player.current_sp
		arena._select_skill_from_bar(&"geometer_translation")
		arena._update_aim(Vector2(200, 480))
		_check(arena.cast_intent.active_skill == &"geometer_translation" and casting.preview_valid and arena.player.current_sp == before, "bar edit selection/preview is free in every cast mode")
		arena._commit_skill(arena.cast_intent.confirm(), Vector2(200, 480))
		_check(arena.player.current_sp == before - 12 and casting.construction.positions()[2] == Vector2(200, 480), "real main commit routes editing instead of generic spell")
		arena._select_skill_from_bar(&"geometer_collapse")
		_check(arena.cast_intent.active_skill == &"" and casting.construction.vertices.is_empty() and arena.player.current_sp == before - 30, "SELF collapse button commits current figure once without target")
		arena._update_hud()
		await process_frame
		var viewport_rect := arena.battle_controls.get_viewport_rect()
		for skill: StringName in arena.battle_controls.skill_buttons:
			var button := arena.battle_controls.skill_buttons[skill]
			_check(viewport_rect.encloses(button.get_global_rect()) and not button.tooltip_text.is_empty(), "five long skill buttons stay visible with full hover description: viewport=%s button=%s tooltip=%s" % [viewport_rect, button.get_global_rect(), not button.tooltip_text.is_empty()])
		await _finish()
	_fixture()
	_shape([&"fire", &"fire", &"fire"])
	casting.construction.vertices[2].position = A
	var before := arena.player.current_sp
	_check(not casting.begin(_command(&"geometer_collapse")) and arena.player.current_sp == before, "suspended figure cannot collapse")
	_check(casting.begin(_command(&"geometer_translation", C)), "valid edit can repair suspended figure")
	_check(hits.is_empty() and casting.construction.has_active_figure(), "repair resumes maintenance without replaying C")
	await _finish()

func _collapse_bounds() -> void:
	_fixture()
	arena.training_boss.global_position = Vector2(240, 430)
	var second := arena._spawn_enemy(&"chaser", Vector2(260, 340))
	var third := arena._spawn_enemy(&"chaser", Vector2(310, 270))
	var fourth := arena._spawn_enemy(&"chaser", Vector2(450, 220))
	for actor: CombatActor in [second, third, fourth]:
		actor.set_process(false)
		actor.health.max_hp = 10000
		actor.health.current_hp = 10000
	_shape([&"lightning", &"lightning", &"lightning"])
	_check(casting.begin(_command(&"geometer_collapse")) and hits.size() == 3 and hits[0].target_id == arena.training_boss.get_instance_id() and hits[1].target_id == second.get_instance_id() and hits[2].target_id == third.get_instance_id(), "consumed R triangle still resolves bounded unique three-link chain nearest C")
	await _finish()
	_fixture()
	arena.training_boss.hard_controls.boss_budget_remaining = 0
	_shape([&"ice", &"ice", &"ice"])
	_check(casting.begin(_command(&"geometer_collapse")) and hits.size() == 1 and not arena.training_boss.is_rooted(), "collapse ice still deals secondary damage with exhausted boss CC budget")
	await _finish()
	_fixture()
	_shape([&"fire", &"fire", &"fire"])
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(280, 280, 20, 20)], 18)
	var before := arena.player.current_sp
	_check(not casting.begin(_command(&"geometer_collapse")) and hits.is_empty() and arena.player.current_sp == before, "obstacle inside entire polygon invalidates collapse without charge")
	await _finish()
	_fixture()
	_shape([&"fire", &"ice"])
	casting.launch(_command(&"geometer_triangulation"))
	before = arena.player.current_sp
	_check(not casting.begin(_command(&"geometer_collapse")) and casting.construction.grammar.pending_count() == 1 and arena.player.current_sp == before, "paid third flight prevents collapse from bypassing ordered reservation")
	await _finish()
	_fixture()
	_shape([&"lightning", &"lightning", &"lightning"])
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.skill_id = &"basic_attack"
	request.magic_damage = 50
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	var projectile := PlayerProjectile.new()
	arena.add_child(projectile)
	projectile.configure_directional(request, Vector2(300, 250) + PlayerProjectile.BODY_OFFSET, Vector2.DOWN, arena.enemies, arena.navigation, 100, 600)
	projectile.geometer_field = casting.wall_field
	projectile.hit.connect(arena._on_attack_requested)
	projectile.set_process(false)
	projectile._process(0.01)
	_check(projectile.geometer_triangle_foundation_request != null, "collapse lifecycle fixture has a real pending field payload")
	casting.begin(_command(&"geometer_collapse"))
	var hp := arena.training_boss.health.current_hp
	var count := hits.size()
	projectile._process(1.0)
	_check(hits.size() == count and arena.training_boss.health.current_hp < hp and projectile.geometer_triangle_foundation_request == null, "collapse invalidates pending field bonuses while retaining independent base projectile")
	await _finish()
	_fixture()
	_shape([&"lightning", &"fire"])
	request = DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.skill_id = &"basic_attack"
	projectile = PlayerProjectile.new()
	arena.add_child(projectile)
	projectile.configure_directional(request, Vector2(300, 200) + PlayerProjectile.BODY_OFFSET, Vector2.DOWN, arena.enemies, arena.navigation, 100, 600)
	projectile.geometer_field = casting.wall_field
	projectile.set_process(false)
	projectile._process(0.01)
	_check(projectile.travelled > 0 and projectile.geometer_fire_request != null and projectile.geometer_conduction_endpoint.is_finite(), "wall born-inside contact initializes ledger before next advance and makes finite physical progress")
	await _finish()

func _cadence() -> void:
	for hz: int in [30, 60, 144]:
		_fixture()
		_shape([&"fire", &"fire", &"fire"])
		var identity := casting.construction.construction_id
		for frame: int in range(hz / 2):
			casting.advance(1.0 / hz)
		_check(casting.begin(_command(&"geometer_translation", Vector2(200, 480))), "cadence fixture performs real translation")
		for frame: int in range(hz * 3 / 2):
			casting.advance(1.0 / hz)
		_check(hits.size() == 2 and casting.construction.construction_id == identity and is_equal_approx(casting.construction.figure_remaining, 4), "%dHz edit preserves exactly two shared ticks and original figure deadline" % hz)
		await _finish()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
