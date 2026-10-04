extends SceneTree
## Continuous triangle entry, once-only projectile components and paid formation.

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
	_geometry()
	await _matrix()
	await _finite_payloads()
	await _lifecycle()
	await _ordering()
	await _paid_formation()
	await _solo_auto()
	await _overlapping_auto()
	print("Geometer triangle projectiles: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _fixture(rank: int = 5) -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g5-projectile-fixture"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation", &"geometer_incidence"]
	snapshot.skill_ranks = {&"geometer_trace": 1, &"geometer_triangulation": rank, &"geometer_incidence": 3}
	snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", null, null, null]
	snapshot.passive_slots = [&"geometer_incidence", null]
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
	casting.hit.connect(func(request: DamageRequest, _target: CombatActor) -> void: hits.append(request.copy()))

func _finish() -> void:
	paused = false
	arena.queue_free()
	await process_frame

func _triangle(first: StringName = &"lightning", second: StringName = &"lightning", third: StringName = &"lightning") -> void:
	casting.clear_construction()
	casting.construction.add_vertex(first, A, 0, 5, arena.navigation)
	casting.construction.add_vertex(second, B, 0, 5, arena.navigation)
	casting.construction.add_vertex(third, C, 0, 5, arena.navigation)
	casting.triangle_field.form()
	casting.advance(0.01)
	hits.clear()

func _target(point: Vector2) -> EnemyActor:
	var actor := arena._spawn_enemy(&"chaser", point)
	actor.set_process(false)
	actor.health.max_hp = 10000.0
	actor.health.current_hp = 10000.0
	return actor

func _owned(origin: Vector2 = Vector2(300, 100), range_value: float = 700.0) -> PlayerProjectile:
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.skill_id = &"basic_attack"
	request.magic_damage = 100.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	var projectile := PlayerProjectile.new()
	arena.add_child(projectile)
	projectile.configure_directional(request, origin + PlayerProjectile.BODY_OFFSET, Vector2.DOWN, arena.enemies, arena.navigation, 100.0, range_value, 3)
	projectile.geometer_field = casting.wall_field
	projectile.hit.connect(arena._on_attack_requested)
	projectile.set_process(false)
	return projectile

func _geometry() -> void:
	var polygon := PackedVector2Array([A, B, C])
	var forward := GeometerGeometry.triangle_contact(polygon, Vector2(300, 100), Vector2(300, 500), 4)
	_check(not forward.is_empty() and is_equal_approx(forward["fraction"], 0.24), "fast crossing has exact circle entry at ground y196, no wall band")
	_check(GeometerGeometry.triangle_contact(polygon, Vector2(300, 300), Vector2(300, 301))["fraction"] == 0.0, "projectile born inside can claim field")
	_check(GeometerGeometry.triangle_contact(polygon, Vector2(300, 180), Vector2(350, 180), 4).is_empty(), "parallel motion outside never inherits twelve-unit wall thickness")
	_check(not GeometerGeometry.triangle_contact(PackedVector2Array([C, B, A]), Vector2(300, 100), Vector2(300, 500), 4).is_empty(), "winding does not change entry")
	_check(GeometerGeometry.triangle_contact(PackedVector2Array([A, B, Vector2(NAN, 500)]), Vector2(300, 100), Vector2(300, 500)).is_empty(), "nonfinite geometry cannot produce partial edge contact")
	_check(GeometerGeometry.triangle_contact(polygon, Vector2(300, 100), Vector2(300, 500), -1).is_empty(), "invalid radius cannot transform")
	for first: StringName in GeometerGeometry.ELEMENTS:
		for second: StringName in GeometerGeometry.ELEMENTS:
			for third: StringName in GeometerGeometry.ELEMENTS:
				var description := ClassCatalog.geometer_triangle_description([first, second, third])
				_check(description.contains("Fundação") and description.contains("Regra") and description.contains("Resolução") and description.contains("R%d" % GeometerGeometry.triangle_rank([first, second, third])), "recipe description exposes three composed roles and gate")

func _matrix() -> void:
	for first: StringName in GeometerGeometry.ELEMENTS:
		for second: StringName in GeometerGeometry.ELEMENTS:
			for third: StringName in GeometerGeometry.ELEMENTS:
				_fixture()
				_triangle(first, second, third)
				var primary := _target(Vector2(300, 300))
				var neighbor := _target(Vector2(340, 300))
				var projectile := _owned()
				projectile._process(1.0)
				_check((projectile.geometer_triangle_foundation_request != null) == (first == &"lightning") and (projectile.geometer_triangle_arc_request != null) == (second == &"lightning"), "%s/%s/%s claims exactly A/B lightning roles" % [first, second, third])
				_check(projectile.direction == Vector2.DOWN and not projectile.geometer_conduction_endpoint.is_finite() and projectile.geometer_fire_request == null and projectile.geometer_bonus_request == null, "triangle never inherits wall transport/fire/theorem")
				projectile._process(1.0)
				_check(primary.health.current_hp < primary.health.max_hp and hits.size() == (int(first == &"lightning") + int(second == &"lightning")), "first real impact applies only eligible field additions")
				for request: DamageRequest in hits:
					_check(request.is_secondary and not request.can_crit and request.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and request.skill_id != &"geometer_incidence", "field additions cannot crit, cascade or earn wall theorem")
				_check((neighbor.health.current_hp < neighbor.health.max_hp) == (second == &"lightning") and projectile.geometer_triangle_arc_request == null and projectile.geometer_triangle_foundation_request == null, "arc affects another occupant once and consumes both components")
				await _finish()

func _finite_payloads() -> void:
	_fixture()
	_triangle()
	var primary := _target(Vector2(300, 300))
	var first := _target(Vector2(340, 300))
	_target(Vector2(260, 300))
	var second := _target(Vector2(300, 350))
	var projectile := _owned()
	projectile._process(2.0)
	_check(hits.size() == 2 and hits[1].target_id == first.get_instance_id(), "B-R chooses one deterministic nearest neighbor, never returns to primary")
	projectile._process(1.0)
	_check(second.health.current_hp < second.health.max_hp and hits.size() == 2 and projectile.max_hits == 3 and projectile.max_distance == 700.0, "piercing later impact cannot recursively reacquire bonuses or renew budgets")
	projectile.global_position = Vector2(300, 150) + PlayerProjectile.BODY_OFFSET
	projectile._process(0.5)
	_check(projectile.geometer_triangle_arc_request == null and projectile.geometer_triangle_foundation_request == null, "leaving/reentering same construction never renews components")
	_check(primary.health.current_hp < primary.health.max_hp, "base damage remains independent")
	await _finish()
	_fixture()
	_triangle()
	var target := _target(Vector2(300, 300))
	projectile = _owned(Vector2(300, 260))
	projectile._process(1.0)
	_check(hits.size() == 1 and hits[0].target_id == target.get_instance_id(), "born-inside RRR applies foundation but cannot invent solo arc neighbor")
	await _finish()
	_fixture()
	_triangle()
	_target(Vector2(300, 300))
	_target(Vector2(415, 300)) # Circle touches area; link center distance115 exceeds110.
	projectile = _owned()
	projectile._process(2.0)
	_check(hits.size() == 1, "B-R respects strict center link range110")
	await _finish()

func _lifecycle() -> void:
	for state: String in ["clear", "expiry", "triangle_suspend", "new_construction", "outside"]:
		_fixture()
		_triangle()
		var target := _target(Vector2(300, 300))
		var projectile := _owned()
		projectile._process(1.0)
		match state:
			"clear": casting.clear_construction()
			"expiry": casting.advance(6.0)
			"triangle_suspend": casting.construction.vertices[2].position = A
			"new_construction":
				_triangle()
				for anchor: GeometerAnchor in casting.construction.vertices:
					anchor.position += Vector2(600, 0)
			"outside": target.global_position = Vector2(300, 480)
		projectile._process(4.0)
		_check(hits.is_empty() and target.health.current_hp < target.health.max_hp, state + " cannot resolve old/invalid/outside field bonus but preserves base projectile")
		await _finish()
	_fixture()
	_triangle()
	var target := _target(Vector2(300, 300))
	var projectile := _owned()
	paused = true
	projectile._process(1.0)
	_check(projectile.travelled == 0.0 and projectile.geometer_triangle_foundation_request == null, "pause freezes contact and claims")
	paused = false
	projectile._process(1.0)
	var identity := casting.construction.construction_id
	casting.construction.edit(Vector2(200, 510), 0, false, 5, arena.navigation)
	casting.advance(0.01)
	projectile._process(1.0)
	_check(hits.size() == 1 and identity == casting.construction.construction_id and hits[0].target_id == target.get_instance_id(), "valid edit retains snapshot and instance claims through impact")
	await _finish()

func _ordering() -> void:
	_fixture()
	_triangle()
	var before := _target(Vector2(300, 150))
	var projectile := _owned()
	projectile.max_hits = 1
	projectile._process(2.0)
	_check(before.health.current_hp < before.health.max_hp and hits.is_empty(), "earlier victim prevents late field transformation")
	await _finish()
	_fixture()
	_triangle()
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(280, 145, 40, 12)], 18)
	projectile = _owned()
	projectile._process(2.0)
	_check(projectile.is_queued_for_deletion() and projectile.geometer_triangle_foundation_request == null, "terrain before field prevents transformation")
	await _finish()
	_fixture()
	_triangle()
	for kind: int in range(4):
		projectile = _owned()
		if kind == 0: projectile.request.is_secondary = true
		elif kind == 1: projectile.request.source_id = arena.training_boss.get_instance_id()
		elif kind == 2: projectile.request.skill_id = &"geometer_trace"
		else: projectile.request.skill_id = &"geometer_triangulation"
		projectile._process(1.0)
		_check(projectile.geometer_triangle_arc_request == null and projectile.geometer_triangle_foundation_request == null, "secondary/foreign/construction projectiles never receive field roles")
	await _finish()

func _paid_formation() -> void:
	_fixture(3)
	casting.construction.add_vertex(&"fire", A, 0, 3, arena.navigation)
	casting.construction.add_vertex(&"fire", B, 0, 3, arena.navigation)
	var target := _target(Vector2(300, 300))
	var captured := arena.player.geometer_triangle_snapshot()
	casting.select(&"fire")
	var sp := arena.player.current_sp
	casting.launch(casting.capture(&"geometer_triangulation", C, true))
	var flight: GeometerTraceProjectile = casting.get_child(casting.get_child_count() - 1)
	flight.set_process(false)
	_check(arena.player.current_sp == sp - 16.0, "third shot charges only Triangulation once at launch")
	arena.player._apply_derived_stats(StatCalculator.calculate(IdentityIds.initial_attributes(&"mage"), {&"int": 20}, 10))
	flight._process(1.0)
	_check(hits.size() == 1 and is_equal_approx(hits[0].magic_damage, (captured[&"resolution_fire"] as DamageRequest).magic_damage) and target.health.current_hp < target.health.max_hp, "actual paid C resolves captured launch MAG, not impact-time stats")
	_check(casting._shot_triangle_snapshots.is_empty(), "actual third shot retires snapshot ticket after impact")
	casting.advance(1.0)
	_check(hits.size() == 2 and is_equal_approx(hits[1].magic_damage, (captured[&"foundation_fire"] as DamageRequest).magic_damage + (captured[&"rule_fire"] as DamageRequest).magic_damage), "maintenance uses same paid Triangulation rank/MAG snapshot")
	arena._update_hud()
	_check(arena.battle_controls.skill_buttons[&"geometer_triangulation"].tooltip_text.contains("Brasas") and arena.battle_controls.skill_buttons[&"geometer_triangulation"].tooltip_text.contains("Explosão"), "real battle tooltip describes current composed recipe")
	await _finish()

func _solo_auto() -> void:
	for hz: int in [30, 60, 144]:
		_fixture(1)
		_triangle()
		arena.player.global_position = Vector2(300, 100)
		arena.training_boss.global_position = Vector2(300, 320)
		arena.player.target = arena.training_boss
		arena.player._try_basic_attack()
		var projectile: MageProjectile
		for child: Node in arena.get_children():
			if child is MageProjectile: projectile = child
		_check(projectile != null and projectile.geometer_field == casting.wall_field, "solo RRR real Mage auto emission has spatial hook")
		if projectile != null:
			projectile.set_process(false)
			for frame: int in range(hz):
				if projectile.is_queued_for_deletion(): break
				projectile._process(1.0 / hz)
			_check(hits.size() == 1 and hits[0].skill_id == &"geometer_foundation_lightning" and arena.training_boss.health.current_hp < arena.training_boss.health.max_hp, "%d Hz solo RRR adds foundation once without duplicate self arc" % hz)
			_check(casting.construction.vertices.size() == 3 and projectile.travelled < projectile.max_distance, "auto never constructs anchors or renews range")
		await _finish()

func _overlapping_auto() -> void:
	for hz: int in [30, 60, 144]:
		_fixture(1)
		_triangle()
		arena.training_boss.global_position = Vector2(300, 320)
		arena.player.global_position = Vector2(300, 310)
		arena.player.target = arena.training_boss
		arena.player._try_basic_attack()
		var projectile: MageProjectile
		for child: Node in arena.get_children():
			if child is MageProjectile:
				projectile = child
		_check(projectile != null, "overlapping real auto spawns")
		if projectile != null:
			projectile.set_process(false)
			projectile._process(1.0 / hz)
			_check(hits.size() == 1 and hits[0].skill_id == &"geometer_foundation_lightning", "inside triangle immediate hit receives foundation exactly once at %d Hz" % hz)
			_check(projectile.is_queued_for_deletion(), "immediate hit completes without zero-distance loop")
		await _finish()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
