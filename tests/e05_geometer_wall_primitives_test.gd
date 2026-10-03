extends SceneTree
## G4 first batch: real walking candidates, finite contact and shared claims.
## No recipes, damage, redirection, conduction or production profile writes yet.

const A := Vector2(100, 200)
const B := Vector2(400, 200)
var checks := 0
var failures := 0
var crossings: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_geometry()
	_tracking()
	_ledger()
	await _real_walking()
	print("Geometer wall primitives: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _geometry() -> void:
	var contact := GeometerGeometry.wall_contact(Vector2(250, 100), Vector2(250, 300), A, B)
	_check(not contact.is_empty() and is_equal_approx(contact["fraction"], 0.44) and contact["position"].is_equal_approx(Vector2(250, 188)), "first strip contact is on real motion, at 12-unit half width")
	_check(contact["wall_point"] == Vector2(250, 200), "wall center projection distinct from physical contact, not teleport")
	contact = GeometerGeometry.wall_contact(Vector2(250, 300), Vector2(250, 100), A, B)
	_check(is_equal_approx(contact["fraction"], 0.44) and contact["position"].is_equal_approx(Vector2(250, 212)), "reverse contact symmetric, recipe A to B unchanged")
	contact = GeometerGeometry.wall_contact(Vector2(250, 100), Vector2(250, 300), A, B, 10.0)
	_check(is_equal_approx(contact["fraction"], 0.39), "contact incorporates body/projectile radius without infinite strip")
	_check(not GeometerGeometry.wall_contact(Vector2(411, 100), Vector2(411, 300), A, B).is_empty(), "rounded finite end cap contacts")
	_check(not GeometerGeometry.wall_contact(Vector2(412, 100), Vector2(412, 300), A, B).is_empty(), "end cap tangent counts as contact")
	_check(GeometerGeometry.wall_contact(Vector2(412.1, 100), Vector2(412.1, 300), A, B).is_empty(), "beyond end cap cannot hit infinite extension")
	_check(GeometerGeometry.wall_contact(Vector2(250, 100), Vector2(250, 170), A, B).is_empty(), "short motion that never reaches band misses")
	_check(GeometerGeometry.wall_contact(Vector2(250, 200), Vector2(260, 200), A, B)["fraction"] == 0.0, "moving projectile already inside has immediate contact")
	_check(GeometerGeometry.wall_contact(A, A, A, B).is_empty(), "no movement is not a contact event")
	_check(GeometerGeometry.wall_contact(Vector2(NAN, 100), B, A, B).is_empty() and GeometerGeometry.wall_contact(A, B, A, B, INF).is_empty(), "nonfinite input rejected")
	_check(GeometerGeometry.wall_contact(A, B, A, A).is_empty() and GeometerGeometry.wall_contact(A, B, A, B, -1).is_empty(), "degenerate wall and negative radius rejected")
	contact = GeometerGeometry.wall_contact(Vector2(300, 350), Vector2(100, 350), Vector2(200, 200), Vector2(200, 500))
	_check(is_equal_approx(contact["fraction"], 0.44) and contact["wall_point"] == Vector2(200, 350), "vertical orientation uses same finite capsule")
	var crossing := GeometerGeometry.wall_crossing(Vector2(250, 100), Vector2(250, 300), A, B)
	_check(crossing["fraction"] == 0.5 and crossing["position"] == Vector2(250, 200), "continuous actor crossing finds actual centerline intersection")
	_check(GeometerGeometry.wall_crossing(Vector2(250, 100), Vector2(250, 190), A, B).is_empty(), "contact is not yet actor traversal")
	_check(GeometerGeometry.wall_crossing(Vector2(250, 100), Vector2(250, 200), A, B).is_empty(), "stopping on line alone is not traversal")
	_check(GeometerGeometry.wall_crossing(Vector2(250, 200), Vector2(250, 300), A, B)["fraction"] == 0.0, "continuous traversal may complete from exact line on next step")
	_check(GeometerGeometry.wall_crossing(Vector2(420, 100), Vector2(420, 300), A, B).is_empty() and not GeometerGeometry.wall_crossing(Vector2(420, 100), Vector2(420, 300), A, B, 10).is_empty(), "finite crossing includes body overlap at endpoint, not infinite extension")
	_check(not GeometerGeometry.wall_contact(Vector2(250, -5000), Vector2(250, 5000), A, B).is_empty(), "large continuous step cannot tunnel through wall")

func _tracking() -> void:
	var state := GeometerWallContactState.new()
	state.sync(1, true)
	_check(state.observe(10, Vector2(250, 199), Vector2(250, 201), A, B, 0).is_empty(), "birth inside band is not an armed passage")
	state.observe(10, Vector2(250, 201), Vector2(250, 250), A, B, 0)
	_check(not state.observe(10, Vector2(250, 250), Vector2(250, 199), A, B, 0).is_empty(), "leaving band arms a real reverse passage")
	for step: int in range(8):
		var from := Vector2(250, 199 if step % 2 == 0 else 201)
		var to := Vector2(250, 201 if step % 2 == 0 else 199)
		_check(state.observe(10, from, to, A, B, 0).is_empty(), "inside-band oscillation %d does not rearm" % step)
	state.sync(1, false)
	_check(state.observe(10, Vector2(250, 100), Vector2(250, 300), A, B, 0).is_empty(), "inactive wall never detects traversal even with retained construction identity")
	state.sync(1, true)
	_check(state.observe(10, Vector2(250, 199), Vector2(250, 201), A, B, 0).is_empty(), "suspension/resume drops spatial history, not a free passage")
	state.sync(2, true)
	_check(not state.observe(11, Vector2(413, 210), Vector2(400, 190), A, B, 0).is_empty(), "entering rounded endpoint from outside capsule arms real finite crossing")
	state.observe(10, Vector2(250, 100), Vector2(250, 190), A, B, 0)
	_check(state.observe(10, Vector2(250, 190), Vector2(250, 200), A, B, 0).is_empty(), "segmented walk waits until actual side change")
	_check(not state.observe(10, Vector2(250, 200), Vector2(250, 210), A, B, 0).is_empty(), "segmented walk fires once after line crossing")
	state.sync(3, true)
	state.observe(10, Vector2(250, 100), Vector2(250, 190), A, B, 0)
	_check(state.observe(10, Vector2(250, 190), Vector2(250, 190), A + Vector2(0, -30), B + Vector2(0, -30), 0).is_empty(), "moving wall over stationary actor cannot create passage")
	_check(state.observe(10, Vector2(250, 190), Vector2(250, 191), A + Vector2(0, -30), B + Vector2(0, -30), 0).is_empty(), "tiny later walk cannot consume stale side from wall motion")
	state.prune([])
	_check(state.observe(10, Vector2(250, 199), Vector2(250, 201), A, B, 0).is_empty(), "removed actor has no residual spatial history")
	for hz: int in [30, 60, 144]:
		state.sync(hz, true)
		var count := 0
		for frame: int in range(hz):
			var from := Vector2(250, 100 + 200.0 * frame / hz)
			var to := Vector2(250, 100 + 200.0 * (frame + 1) / hz)
			if not state.observe(10, from, to, A, B, 18).is_empty():
				count += 1
		_check(count == 1, "%d Hz: one candidate for whole walking passage" % hz)

func _ledger() -> void:
	var ledger := GeometerInteractionLedger.new()
	_check(not ledger.claim_victim(10), "empty construction has no effect claims")
	ledger.sync(1)
	_check(ledger.claim_victim(10) and not ledger.claim_victim(10), "entry/exit share one victim claim")
	_check(ledger.claim_victim(11) and not ledger.claim_victim(10), "another crossing source cannot bypass shared victim window")
	ledger.advance(1.99)
	ledger.sync(1) # Edit or transition to triangle is not a new construction.
	_check(not ledger.claim_victim(10), "editing/suspension/wall to triangle preserve existing cooldown")
	ledger.advance(0.01)
	_check(ledger.claim_victim(10), "victim eligible again at two-second boundary")
	var time := ledger.elapsed
	for delta: float in [0.0, -1.0, NAN, INF]:
		ledger.advance(delta)
	_check(ledger.elapsed == time, "invalid time cannot advance shared claims")
	var request := DamageRequest.new()
	request.source_id = 100
	request.skill_id = &"fireball"
	_check(ledger.claim_owned_projectile(20, GeometerInteractionLedger.Component.TRANSPORT, request, 100), "own primary projectile can claim transport once")
	ledger.sync(1)
	_check(not ledger.claim_owned_projectile(20, GeometerInteractionLedger.Component.TRANSPORT, request, 100), "conduction and redirect cannot transform same projectile twice, including transition")
	_check(ledger.claim_owned_projectile(20, GeometerInteractionLedger.Component.FIRE_EXIT, request, 100) and not ledger.claim_owned_projectile(20, GeometerInteractionLedger.Component.FIRE_EXIT, request, 100), "fire payload has its own one-shot component")
	_check(ledger.claim_owned_projectile(20, GeometerInteractionLedger.Component.LIGHTNING_FOUNDATION, request, 100) and ledger.claim_owned_projectile(20, GeometerInteractionLedger.Component.LIGHTNING_RULE, request, 100), "triangle components compose without resetting prior wall claims")
	request.is_secondary = true
	_check(not ledger.claim_owned_projectile(21, GeometerInteractionLedger.Component.TRANSPORT, request, 100), "secondary projectile excluded")
	request.is_secondary = false
	for skill: StringName in [&"geometer_trace", &"geometer_triangulation"]:
		request.skill_id = skill
		_check(not ledger.claim_owned_projectile(21, GeometerInteractionLedger.Component.TRANSPORT, request, 100), "construction flight %s excluded" % skill)
	request.skill_id = &"fireball"
	_check(not ledger.claim_owned_projectile(21, GeometerInteractionLedger.Component.TRANSPORT, request, 101), "other caster cannot claim own transformation")
	_check(ledger.claim_owned_projectile(21, GeometerInteractionLedger.Component.TRANSPORT, request, 100), "rejected eligibility does not consume valid later claim")
	_check(not ledger.claim_interception_refund(false) and ledger.claim_interception_refund(true) and not ledger.claim_interception_refund(true), "full SP does not consume interception reward; real recovery has shared two-second window")
	ledger.advance(2.0)
	_check(ledger.claim_interception_refund(true), "interception reward becomes eligible after interval")
	ledger.sync(2)
	_check(ledger.elapsed == 0.0 and ledger.claim_victim(10) and ledger.claim_owned_projectile(20, GeometerInteractionLedger.Component.TRANSPORT, request, 100), "new construction gets fresh finite claims")
	ledger.sync(0)
	_check(not ledger.claim_victim(10) and not ledger.claim_interception_refund(true), "cleanup invalidates all claims")
	for hz: int in [30, 60, 144]:
		ledger.sync(hz)
		ledger.claim_victim(10)
		for frame: int in range(hz * 2):
			ledger.advance(1.0 / hz)
		_check(ledger.claim_victim(10), "%d Hz: victim window expires after two seconds, not one frame later" % hz)

func _real_walking() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g4-fixture"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.skill_ranks = {&"geometer_trace": 1, &"geometer_triangulation": 5}
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation"]
	snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", null, null, null]
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [], 18)
	var boss := arena.training_boss
	var casting := arena.geometer_casting
	casting.wall_field.enabled = false # Isolate spatial primitives from recipe effects.
	var state := casting.construction
	state.add_vertex(&"fire", Vector2(200, 200), 0, 5, arena.navigation)
	state.add_vertex(&"ice", Vector2(500, 200), 0, 5, arena.navigation)
	casting.wall_crossed.connect(func(contact: Dictionary, _actor: CombatActor) -> void: crossings.append(contact))
	casting.advance(0.1)
	_check(casting.interaction_ledger.claim_victim(boss.get_instance_id()), "real adapter ledger starts at active construction")
	var hp := boss.health.current_hp
	var sp := arena.player.current_sp
	boss.global_position = Vector2(300, 100)
	boss._path = PackedVector2Array([Vector2(300, 300)])
	boss._path_index = 0
	boss._move_along_path(2.0)
	_check(crossings.size() == 1 and crossings[0]["position"] == Vector2(300, 200), "real boss walking emits one candidate from applied ground segment")
	_check(boss.health.current_hp == hp and arena.player.current_sp == sp, "candidate alone does not deal damage, reward SP or consume proc")
	boss.global_position = Vector2(300, 100)
	casting.advance(0.1)
	_check(crossings.size() == 1, "direct reposition across wall is not walking")
	paused = true
	boss._path = PackedVector2Array([Vector2(300, 300)])
	boss._path_index = 0
	boss._process(1.0)
	casting.advance(1.0)
	_check(crossings.size() == 1 and boss.global_position == Vector2(300, 100), "paused real actor and observer emit no motion candidate")
	paused = false
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [Rect2(260, 150, 80, 20)], 18)
	boss._move_along_path(2.0)
	_check(crossings.size() == 1 and boss.global_position.y < 150, "blocked path reports only applied travel, not desired travel through wall")
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [], 18)
	boss.global_position = Vector2(500, 200)
	state.edit(boss.global_position, boss.get_instance_id(), false, 5, arena.navigation)
	var stationary := arena._spawn_enemy(&"chaser", Vector2(350, 300))
	stationary.set_process(false)
	casting.advance(0.1)
	_check(not casting.interaction_ledger.claim_victim(boss.get_instance_id()), "real edit preserves shared victim window")
	boss.global_position = Vector2(500, 400)
	casting.advance(0.1)
	_check(state.has_active_figure() and crossings.size() == 1, "real mobile wall passes over stationary enemy without candidate")
	stationary._path = PackedVector2Array([Vector2(351, 300)])
	stationary._path_index = 0
	stationary._move_along_path(0.1)
	_check(crossings.size() == 1, "small walking after mobile wall sweep cannot generate stale passage")
	boss.global_position = Vector2(300, 100)
	state.add_vertex(&"fire", Vector2(200, 400), 0, 5, arena.navigation)
	casting.advance(0.1)
	boss._path = PackedVector2Array([Vector2(300, 300)])
	boss._path_index = 0
	boss._move_along_path(2.0)
	_check(crossings.size() == 1, "triangle inherits no wall crossing events")
	casting.clear_construction()
	_check(casting.interaction_ledger.construction_id == 0 and casting.wall_contacts.construction_id == 0, "explicit cleanup invalidates tracking and shared ledger")
	var listener := casting._on_ground_walked.bind(boss)
	casting.free()
	_check(not boss.ground_walked.is_connected(listener), "observer removal disconnects surviving actors")
	arena.geometer_casting = null
	arena.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
