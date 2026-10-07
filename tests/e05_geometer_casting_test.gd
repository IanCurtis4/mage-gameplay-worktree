extends SceneTree
## G1 real controller/player/projectile integration, on a non-persisted fixture.

var checks := 0
var failures := 0
var arena: RunController
var casting: GeometerCasting
var player: PlayerActor
var boss: CombatActor
var pointer := Vector2.ZERO

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(not ProfileCatalog.pilot({}, {}, {&"mg_ar": {"content_ready": false}}).evolution_is_ready(&"mg_ar", &"mage"), "partial-library fixture stays unavailable even with the complete runtime library")
	for skill: StringName in [&"geometer_trace", &"geometer_triangulation"]:
		var definition := ClassCatalog.skill_definition(skill)
		_check(definition.is_rank_catalog_valid() and definition.targeting == SkillDefinition.Targeting.POINT, "execution-only typed catalog for " + String(skill))
		for rank: int in range(1, 6):
			var values := definition.rank_definition(rank)
			_check(values.range == 600.0 and values.projectile_speed == 900.0 and values.sp_cost == (8.0 if skill == &"geometer_trace" else 16.0), "rank %d has finite authored launch values" % rank)
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g1-fixture"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.skill_ranks = {&"geometer_trace": 1, &"geometer_triangulation": 5}
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation"]
	snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", null, null, null]
	RunController.pending_run_state = RunState.from_build("g1-fixture", snapshot)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	player = arena.player
	player.set_process(false)
	boss = arena.training_boss
	boss.set_process(false)
	casting = arena.geometer_casting
	arena.navigation.configure(Rect2(0, 0, 1000, 800), [], 18.0)
	player.global_position = Vector2(100, 100)
	boss.global_position = Vector2(300, 100)
	_check(casting != null and casting.z_index < player.z_index and arena.geometer_element_buttons.size() == 3, "real scene wires casting and underlay plus three intrinsic buttons")
	_check(arena.battle_controls.skill_buttons.size() == 2, "intrinsic selectors consume no active slots")
	var initial_sp := player.current_sp
	arena._select_geometer_element(&"ice")
	_check(player.current_sp == initial_sp and player.skill_cooldown(&"geometer_trace") == 0.0 and casting.construction.vertices.is_empty(), "element selection creates no shot, cost or vertex")
	var direct := casting.capture(&"geometer_trace", boss.global_position + BattleTargeting.BODY_OFFSET)
	var near := casting.capture(&"geometer_trace", boss.global_position + BattleTargeting.BODY_OFFSET + Vector2(50, 0))
	var forced := casting.capture(&"geometer_trace", boss.global_position + BattleTargeting.BODY_OFFSET, true)
	_check(direct.actor_id == boss.get_instance_id() and near.actor_id == 0 and forced.actor_id == 0, "direct body vs ground is explicit; assistance cannot bind nearby floor and Shift forces floor")
	arena._select_geometer_element(&"fire")
	var command := casting.capture(&"geometer_trace", Vector2(200, 200), true)
	_check(casting.begin(command) and player.has_active_cast() and player.current_sp == initial_sp and casting.construction.grammar.pending_count() == 0, "preparation reserves no slot and spends no SP")
	command.element = &"lightning"
	arena._select_geometer_element(&"ice")
	player._advance_active_cast(player.active_cast_remaining + 0.001)
	var first := _projectile()
	_check(first != null and first.element == &"fire" and player.current_sp == initial_sp - 8.0 and casting.construction.grammar.pending_count() == 1, "release spends once and freezes copied command, not current selection")
	_check(is_equal_approx(player.skill_cooldown(&"geometer_trace"), StatCalculator.effective_cooldown(0.4, player.stat_breakdown)), "cooldown uses central calculator")
	first._process(0.5)
	_check(casting.construction.elements() == [&"fire"] and casting.construction.vertices[0].actor_id == 0 and player.current_sp == initial_sp - 8.0, "ground arrival creates static anchor without impact debit")
	var count := casting.construction.vertices.size()
	first._finish(true, Vector2(200, 200))
	_check(casting.construction.vertices.size() == count, "duplicate delivery cannot repeat anchor")
	_reset()
	initial_sp = player.current_sp
	arena._commit_skill(&"geometer_trace", boss.global_position + BattleTargeting.BODY_OFFSET)
	_check(player.has_active_cast(), "normal controller commit captures dynamic target")
	arena._select_geometer_element(&"lightning")
	player._advance_active_cast(player.active_cast_remaining + 0.001)
	first = _projectile()
	var hp := boss.health.current_hp
	boss.global_position = Vector2(350, 120)
	first._process(0.5)
	_check(boss.health.current_hp < hp and casting.construction.vertices[0].actor_id == boss.get_instance_id() and casting.construction.vertices[0].position == boss.global_position, "selected moving actor receives central damage and anchors at real impact")
	_check(player.current_sp == initial_sp - 8.0, "dynamic impact also spends once")
	casting.advance(1.0)
	var deadline := casting.construction.vertices[0].remaining
	boss.global_position = Vector2(390, 160)
	casting.advance(0.5)
	_check(casting.construction.vertices[0].position == boss.global_position and casting.construction.vertices[0].remaining == deadline - 0.5, "run adapter advances and follows actual actor")
	_reset()
	initial_sp = player.current_sp
	_check(casting.begin(casting.capture(&"geometer_trace", Vector2(240, 200), true)), "cancel fixture starts cast")
	arena._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(not player.has_active_cast() and player.current_sp == initial_sp and _flight_count() == 0, "focus loss cancels before charge or flight")
	casting.begin(casting.capture(&"geometer_trace", Vector2(240, 200), true))
	player.move_to(Vector2(120, 100))
	_check(not player.has_active_cast() and player.current_sp == initial_sp, "movement cancels frozen preparation without cost")
	_check(not casting.begin(casting.capture(&"geometer_trace", Vector2(900, 100), true)) and player.current_sp == initial_sp, "out-of-range preflight rejects without charge")
	arena.navigation.configure(Rect2(0, 0, 1000, 800), [Rect2(180, 70, 25, 65)], 18.0)
	_check(not casting.begin(casting.capture(&"geometer_trace", Vector2(300, 100), true)) and player.current_sp == initial_sp, "blocked preflight rejects without charge")
	arena.navigation.configure(Rect2(0, 0, 1000, 800), [], 18.0)
	casting.begin(casting.capture(&"geometer_trace", Vector2(300, 100), true))
	player._advance_active_cast(player.active_cast_remaining + 0.001)
	first = _projectile()
	arena.navigation.configure(Rect2(0, 0, 1000, 800), [Rect2(180, 70, 25, 65)], 18.0)
	first._process(0.5)
	_check(casting.construction.vertices.is_empty() and player.current_sp == initial_sp - 8.0, "new obstacle during paid flight misses without refund")
	_reset()
	arena.navigation.configure(Rect2(0, 0, 1000, 800), [], 18.0)
	boss.global_position = Vector2(300, 100)
	casting.begin(casting.capture(&"geometer_trace", boss.global_position + BattleTargeting.BODY_OFFSET))
	player._advance_active_cast(player.active_cast_remaining + 0.001)
	first = _projectile()
	boss.health.current_hp = 0.0
	first._process(0.5)
	_check(casting.construction.vertices.is_empty(), "carrier dying before impact creates no anchor")
	boss.health.current_hp = boss.health.max_hp
	_reset()
	casting.begin(casting.capture(&"geometer_trace", Vector2(240, 200), true))
	var prepare_remaining := player.active_cast_remaining
	paused = true
	player._process(1.0)
	arena._select_geometer_element(&"fire")
	_check(player.active_cast_remaining == prepare_remaining and casting.construction.grammar.selected_element == &"lightning", "pause freezes preparation and intrinsic selection")
	paused = false
	player._advance_active_cast(prepare_remaining + 0.001)
	first = _projectile()
	var origin := first.global_position
	paused = true
	first._process(1.0)
	casting.advance(1.0)
	_check(first.global_position == origin and first.remaining == 3.0 and casting.construction.grammar.pending_count() == 1, "pause freezes projectile and reservations")
	paused = false
	first._process(0.5)
	var construction_id := casting.construction.construction_id
	arena._cancel_casting()
	_check(casting.construction.construction_id == construction_id and not casting.construction.vertices.is_empty(), "Esc/right cancel intent but preserve existing construction")
	arena._clear_geometer_construction()
	_check(casting.construction.vertices.is_empty(), "explicit clear removes construction")
	_reset()
	casting.begin(casting.capture(&"geometer_trace", Vector2(240, 200), true))
	player._advance_active_cast(player.active_cast_remaining + 0.001)
	first = _projectile()
	var ticket := first.ticket
	var request := first.request
	arena._clear_geometer_construction()
	hp = boss.health.current_hp
	casting._on_delivered(ticket, true, boss.global_position, boss, first)
	_check(casting.construction.vertices.is_empty() and boss.health.current_hp == hp and request != null, "clear invalidates late damage and anchor, not only presentation")
	_reset()
	casting.construction.add_vertex(&"fire", Vector2(180, 150), 0, 0, arena.navigation)
	casting.construction.add_vertex(&"ice", Vector2(360, 150), 0, 0, arena.navigation)
	initial_sp = player.current_sp
	_check(not casting.begin(casting.capture(&"geometer_trace", Vector2(180, 350), true)) and player.current_sp == initial_sp, "two vertices require explicit Triangulation, not automatic skill switch")
	casting.select(&"lightning")
	_check(casting.begin(casting.capture(&"geometer_triangulation", Vector2(180, 350), true)), "learned third shot prepares independent of legacy slots")
	player._advance_active_cast(player.active_cast_remaining + 0.001)
	first = _projectile()
	_check(player.current_sp == initial_sp - 16.0 and first.request.magic_damage == 0.0, "third pays only Triangulation and leaves field resolution to G5")
	first._process(0.5)
	_check(casting.construction.shape == GeometerConstructionState.Shape.TRIANGLE, "third actual impact closes triangle")
	_reset()
	player.target = boss
	var auto_count_before := arena.get_children().filter(func(node: Node) -> bool: return node is MageProjectile).size()
	player._try_basic_attack()
	var auto_count_after := arena.get_children().filter(func(node: Node) -> bool: return node is MageProjectile).size()
	_check(auto_count_after > auto_count_before and casting.construction.vertices.is_empty() and casting.construction.grammar.pending_count() == 0, "real inherited Mage auto emits eligible projectile but never constructs anchors")
	_reset()
	initial_sp = player.current_sp
	player.current_sp = 0.0
	_check(not casting.begin(casting.capture(&"geometer_trace", Vector2(240, 200), true)) and casting.construction.grammar.pending_count() == 0, "no SP cannot prepare or reserve")
	player.current_sp = initial_sp
	player.mage_cooldowns[&"geometer_trace"] = 4.0
	_check(not casting.begin(casting.capture(&"geometer_trace", Vector2(240, 200), true)), "cooldown prevents new prepare")
	player.mage_cooldowns.clear()
	player.run_state.build_snapshot.active_slots = [null, null, null, null, null]
	_check(casting.begin(casting.capture(&"geometer_trace", Vector2(240, 200), true)), "learned trace casts without legacy equipped slots")
	arena._cancel_casting()
	player.run_state.build_snapshot.skill_ranks.erase(&"geometer_trace")
	_check(not casting.begin(casting.capture(&"geometer_trace", Vector2(240, 200), true)), "unlearned trace cannot cast even if assigned")
	player.run_state.build_snapshot.skill_ranks[&"geometer_trace"] = 1
	player.run_state.build_snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", null, null, null]
	player.run_state.build_snapshot.evolution_id = &""
	_check(not casting.begin(casting.capture(&"geometer_trace", Vector2(240, 200), true)), "base Mage cannot use exclusive trace even in malformed fixture")
	player.run_state.build_snapshot.evolution_id = &"mg_ar"
	await _input_modes()
	arena._show_result(false)
	_check(casting.construction.vertices.is_empty() and casting.construction.grammar.pending_count() == 0, "terminal run cleans grammar and flights")
	paused = false
	arena.queue_free()
	await process_frame
	print("Geometer casting: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _input_modes() -> void:
	_reset()
	player.global_position = Vector2(700, 500)
	boss.global_position = Vector2(900, 500)
	for child: Node in player.get_children():
		if child is Camera2D:
			child.position_smoothing_enabled = false
			child.force_update_scroll()
	await process_frame
	await process_frame
	# Aim above the new two-row bar, not through its interactive lower screen area.
	var aim := arena.get_global_transform_with_canvas() * Vector2(900, 400)
	_mouse(aim)
	arena.cast_intent.set_mode(CastIntent.Mode.CONFIRM)
	var sp := player.current_sp
	var selected_element := casting.construction.grammar.selected_element
	_key(KEY_2, true)
	_key(KEY_2, false)
	_check(arena.cast_intent.active_skill == &"geometer_triangulation" and casting.construction.grammar.selected_element == selected_element and player.current_sp == sp, "number 2 selects action slot, not the old intrinsic ice selector")
	_key(KEY_1, true)
	_key(KEY_1, false)
	_check(arena.cast_intent.active_skill == &"geometer_trace" and not player.has_active_cast() and player.current_sp == sp, "real CONFIRM key waits for world click without cost")
	_click(MOUSE_BUTTON_LEFT)
	_check(player.has_active_cast() and arena.cast_intent.active_skill == &"", "real world click starts frozen preparation without movement")
	_key(KEY_1, false)
	player._advance_active_cast(player.active_cast_remaining + 0.001)
	_check(_flight_count() == 1 and player.current_sp == sp - 8.0, "late key-up cannot double confirmed launch")
	_reset()
	arena.cast_intent.set_mode(CastIntent.Mode.RELEASE)
	_key(KEY_1, true)
	_key(KEY_1, false)
	_check(player.has_active_cast() and arena.cast_intent.active_skill == &"", "real RELEASE key-up starts preparation")
	arena._cancel_casting()
	_key(KEY_1, true)
	_mouse(arena.geometer_element_buttons[&"ice"].get_global_rect().get_center())
	_key(KEY_1, false)
	_check(not player.has_active_cast() and casting.construction.grammar.pending_count() == 0, "release over intrinsic UI cannot launch into world")
	_click(MOUSE_BUTTON_LEFT)
	_check(casting.construction.grammar.selected_element == &"ice" and not player.has_active_cast(), "actual intrinsic button selects without triggering world cast")
	_mouse(aim)
	arena.cast_intent.set_mode(CastIntent.Mode.INSTANT)
	_key(KEY_1, true)
	_check(player.has_active_cast() and arena.cast_intent.active_skill == &"", "real INSTANT key-down starts cast immediately")
	var remaining := player.active_cast_remaining
	_key(KEY_1, true, true)
	_key(KEY_1, false)
	_check(player.active_cast_remaining == remaining, "key repeat and release cannot restart instant preparation")
	_key(KEY_F3, true)
	_key(KEY_F3, false)
	_check(casting.construction.grammar.selected_element == &"lightning", "real intrinsic hotkey changes next-shot selection")
	player._advance_active_cast(remaining + 0.001)
	var flight := _projectile()
	_check(flight != null and flight.element == &"ice", "intrinsic hotkey during prepare does not rewrite captured element")
	_key(KEY_F6, true)
	_key(KEY_F6, false)
	_check(casting.construction.grammar.pending_count() == 0 and (flight == null or flight.is_queued_for_deletion()), "real F6 clears paid in-flight construction")
	_reset()
	paused = true
	_key(KEY_F1, true)
	_key(KEY_1, true)
	_check(casting.construction.grammar.selected_element == &"lightning" and not player.has_active_cast(), "real paused key events mutate neither grammar nor casts")
	paused = false
	_key(KEY_1, false)
	arena.cast_intent.set_mode(CastIntent.Mode.CONFIRM)
	_key(KEY_1, true)
	_key(KEY_ESCAPE, true)
	_check(not paused and arena.cast_intent.active_skill == &"", "real Escape cancels aim without erasing figures or opening settings")

func _key(code: Key, pressed: bool, repeat: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = repeat
	root.push_input(event)

func _mouse(point: Vector2) -> void:
	pointer = point
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func _click(button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = pointer
		root.push_input(event, true)

func _projectile() -> GeometerTraceProjectile:
	for child: Node in casting.get_children():
		if child is GeometerTraceProjectile and not child.is_queued_for_deletion():
			child.set_process(false)
			return child as GeometerTraceProjectile
	return null

func _reset() -> void:
	casting.clear_construction()
	for child: Node in casting.get_children():
		if child is GeometerTraceProjectile:
			child.free()
	player.mage_cooldowns.clear()
	player.target = null
	player.velocity = Vector2.ZERO

func _flight_count() -> int:
	return casting.get_children().filter(func(child: Node) -> bool: return child is GeometerTraceProjectile).size()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
