extends SceneTree
const Transform = preload("res://tools/content/transform_bundle.gd")
var checks := 0
var failures := 0
var catalog: BuildEffectCatalog
var events: Array[Dictionary] = []
var passive_baseline := 0.0
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	var entries: Array[Dictionary] = Transform.entries()
	var prepared := ContentAuthoring.prepare(entries)
	if not prepared["ok"]: print(prepared); quit(1); return
	catalog = ContentAuthoring.compile_bundle(entries, prepared["text_template"], false)["catalog"]
	for condition: String in ["original", "enabled", "remove", "cancel", "dead", "lethal", "shield", "blocked", "interrupt", "pause", "expire"]: await _drain(condition)
	for skill: StringName in HunterMath.NEW_TRAP_IDS:
		for condition: String in ["original", "enabled", "missing", "dead_mark", "swap", "remove", "dead_after", "expire", "pause", "ttl"]: await _mechanism(skill, condition)
	for condition: String in ["original", "enabled", "remove", "fallback", "boundary", "outside", "tie", "blocked", "dead", "defense", "pause", "reentry", "late", "original_passives", "enabled_passives"]: await _fan(condition)
	for condition: String in ["original", "enabled", "remove", "lightning", "wall", "pause", "empty", "reentry"]: await _collapse(condition)
	print("E06 transform execution: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _scene(identity: StringName, augment: StringName = &"", passives: bool = false) -> RunController:
	var build := BuildSnapshot.new()
	build.character_id = "transform-real"
	build.base_class_id = &"archer" if identity == &"hunter" else &"mage"
	build.evolution_id = identity
	build.base_level = 30
	build.job_level = 40
	build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(build.base_class_id, identity)
	if identity == &"spiritualist": build.skill_ranks = {&"spiritualist_soul_drain": 1, &"spiritualist_echo_curse": 1, &"fire_spear": 1}
	elif identity == &"hunter": build.skill_ranks = {&"hunter_mark": 1, &"hunter_thorn_trap": 1, &"hunter_freezing_trap": 1, &"hunter_tar_trap": 1, &"hunter_covering_shot": 1}
	else: build.skill_ranks = {&"geometer_trace": 1, &"geometer_triangulation": 5, &"geometer_collapse": 1}
	if passives:
		build.skill_ranks[&"hunter_shooting_discipline"] = 1
		build.skill_ranks[&"hunter_easy_prey"] = 1
	build.action_slots = ActionBarLayout.empty()
	var state := RunState.from_build("transform-real", build)
	if not augment.is_empty(): state.augment_stacks[augment] = 1
	_check(state.set_effect_catalog(catalog)["ok"], "isolated transform catalog injects")
	RunController.pending_run_state = state
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena.training_boss.position = Vector2(1500, 850)
	arena._training_add_elapsed = -1000
	arena.enemies.clear()
	arena.navigation.configure(Rect2(0, 0, 1800, 1000), [], 0)
	arena.player.position = Vector2(400, 350)
	arena.rng.seed = 18
	if arena.geometer_casting != null: arena.geometer_casting.set_process(false)
	_check(arena.persistent_facade == null, "fixtures cannot save user profile")
	events.clear()
	return arena
func _victim(arena: RunController, point: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo de transformação", Color.WHITE, StatCalculator.calculate({}))
	actor.position = point
	actor.health.max_hp = 10000
	actor.health.current_hp = 10000
	actor.health.physical_defense = 0
	actor.health.magic_defense = 0
	actor.health.flee_rating = 0
	actor.health.damage_applied.connect(arena._on_enemy_damage_resolved)
	actor.health.damage_applied.connect(func(result: Dictionary) -> void: events.append(result.duplicate(true)))
	arena.add_child(actor)
	actor.set_process(false)
	arena.enemies.append(actor)
	return actor
func _finish(arena: RunController) -> void:
	paused = false
	arena.queue_free()
	await process_frame
func _remove(arena: RunController, id: StringName) -> void:
	arena.run_state.augment_stacks.erase(id)
	arena.run_state.runtime_revision += 1
	arena.player.apply_run_modifiers(arena.run_state)
	_check(arena.run_state.composed_build()["kit_policies"].is_empty(), "current policy removed while captured action persists")
func _drain(condition: String) -> void:
	var enabled := condition != "original"
	var arena := _scene(&"spiritualist", &"spiritualist_drain_inscription" if enabled else &"")
	var victim := _victim(arena, Vector2(500, 350))
	if condition == "cancel":
		var sp := arena.player.current_sp
		_check(arena.player.begin_skill_cast(&"spiritualist_soul_drain", victim.position, victim) and arena.player.cancel_active_cast(), "inscription preparation cancels normally")
		_check(arena.player.current_sp == sp and not arena.spiritualist_drain_state.active and arena.spiritualist_echo_state.marks.is_empty(), "cancelled preparation spends and inscribes nothing")
		await _finish(arena); return
	_check(arena.player.use_spiritualist_soul_drain(victim), "actual paid Drain starts")
	var state := arena.spiritualist_drain_state
	if condition == "remove": _remove(arena, &"spiritualist_drain_inscription")
	if condition == "pause":
		paused = true
		arena._process(2)
		_check(state.ticks_resolved == 0 and arena.spiritualist_echo_state.marks.is_empty(), "pause freezes channel and completion")
		paused = false
	for index: int in range(4):
		if index == 3:
			if condition == "dead": victim.health.current_hp = 0
			if condition == "lethal": victim.health.current_hp = 1
			if condition == "interrupt": arena.player.move_to(Vector2(420, 350))
			if condition == "shield": victim.health.shield_hp = 10000
			if condition == "blocked": arena.navigation.configure(Rect2(0, 0, 1800, 1000), [Rect2(445, 310, 10, 80)], 0)
		arena._advance_spiritualist_drain(0.5)
		if index < 3: _check(not arena.spiritualist_echo_state.has_mark(victim.get_instance_id()), "inscription never occurs before four confirmed ticks")
	var inscribed := enabled and condition not in ["dead", "lethal", "shield", "blocked", "interrupt"]
	_check(arena.spiritualist_echo_state.has_mark(victim.get_instance_id()) == inscribed, "only complete positive living final impact inscribes %s" % condition)
	_check(arena.spiritualist_echo_state.pending.is_empty(), "secondary final tick cannot start echo wave")
	var hp := victim.health.current_hp
	arena._advance_spiritualist_drain(3)
	_check(victim.health.current_hp == hp, "completion cannot repeat fifth tick")
	if inscribed:
		var mark: Dictionary = arena.spiritualist_echo_state.marks[victim.get_instance_id()]
		_check(is_equal_approx(mark["remaining"], 5) and is_equal_approx(mark["echo_power"], ClassCatalog.skill_definition(&"spiritualist_echo_curse").rank_definition(1).secondary_power), "inscription captures learned Curse potency and five seconds")
		if condition == "expire":
			arena.spiritualist_echo_state.advance(5.01)
			_check(not arena.spiritualist_echo_state.has_mark(victim.get_instance_id()), "inscription expires after finite window")
		else:
			_check(arena.player.use_spear(&"fire_spear", victim), "next actual direct action can use inscription")
			for projectile: Node in get_nodes_in_group("player_projectiles"):
				projectile.set_process(false); projectile._process(1)
			_check(not arena.spiritualist_echo_state.has_mark(victim.get_instance_id()) and arena.spiritualist_echo_state.pending.size() == 1, "next direct impact consumes new mark into one finite wave")
	await _finish(arena)
func _mechanism(skill: StringName, condition: String) -> void:
	var enabled := condition != "original"
	var arena := _scene(&"hunter", &"hunter_marked_mechanism" if enabled else &"")
	var carrier := _victim(arena, Vector2(500, 350))
	var neighbor := _victim(arena, Vector2(495, 350))
	if condition != "missing": _check(arena.player.use_hunter_mark(carrier), "actual Mark identifies captured trap trigger")
	if condition == "dead_mark": carrier.health.current_hp = 0
	var sp := arena.player.current_sp
	var rejects := condition in ["missing", "dead_mark"]
	var placed := arena.player.use_hunter_trap(skill, Vector2(500, 350))
	_check(placed != rejects, "mechanism rejects only missing/dead placement mark %s %s" % [skill, condition])
	if rejects:
		_check(arena.player.current_sp == sp and arena.player.skill_cooldown(skill) == 0 and arena.trap_registry.active_count() == 0, "rejected mark spends no SP/cooldown/trap capacity")
		await _finish(arena); return
	var active := arena.trap_registry.active_traps()
	_check(active.size() == 1 and active[0] is HunterTrap, "paid production HunterTrap exists")
	if active.is_empty(): await _finish(arena); return
	var trap := active[0] as HunterTrap
	trap.set_process(false)
	carrier.position = Vector2(600, 350)
	if condition == "swap":
		arena.player._process(arena.player.skill_cooldown(&"hunter_mark") + 0.001)
		_check(arena.player.use_hunter_mark(neighbor), "new real Mark replaces current target after placement")
	if condition == "remove": _remove(arena, &"hunter_marked_mechanism")
	if condition == "dead_after": carrier.health.current_hp = 0
	if condition == "expire": arena.player.hunter_state.advance(arena.player.hunter_state.mark_remaining + 0.001)
	if condition == "pause":
		paused = true; trap._process(5)
		_check(trap.state == PlayerTrap.State.ARMING, "paused placement does not arm or redirect")
		paused = false
	trap._process(trap.arming_duration + 0.01)
	_check((trap.state == PlayerTrap.State.TRIGGERED) == not enabled, "unmarked nearby prey triggers original only; policy ignores it")
	if enabled:
		if condition == "ttl":
			trap._process(trap.lifetime_remaining + 0.001)
			_check(trap.state == PlayerTrap.State.EXPIRED and arena.player.hunter_state.opening(neighbor.get_instance_id()).is_empty(), "finite TTL expires without replacement activation")
		elif condition == "dead_after":
			carrier.position = Vector2(500, 350); trap._process(0.01)
			_check(trap.is_active() and arena.player.hunter_state.opening(neighbor.get_instance_id()).is_empty(), "dead captured target cannot transfer trigger to survivor")
		else:
			carrier.position = Vector2(500, 350); trap._process(0.01)
			_check(trap.state == PlayerTrap.State.TRIGGERED and not arena.player.hunter_state.opening(carrier.get_instance_id()).is_empty(), "captured living ID triggers despite current mark/recipe changes")
			_check(arena.player.hunter_state.opening(neighbor.get_instance_id()).is_empty() == (skill == &"hunter_freezing_trap"), "selective trigger does not suppress existing area victims")
	await _finish(arena)
func _fan(condition: String) -> void:
	var transformed := not condition.begins_with("original")
	var passives := condition.ends_with("passives")
	var arena := _scene(&"hunter", &"hunter_covering_fan" if transformed else &"", passives)
	var first := _victim(arena, Vector2(530, 350))
	var next := _victim(arena, Vector2(530, 400))
	var farther := _victim(arena, Vector2(530, 420))
	if condition == "fallback": next.position.y = 550; farther.position.y = 560
	if condition == "boundary": next.position.y = 430; farther.position.y = 560
	if condition == "outside": next.position.y = 430.01; farther.position.y = 560
	if condition == "tie": next.position = Vector2(530, 390); farther.position = Vector2(530, 310)
	if condition == "blocked": arena.navigation.configure(Rect2(0, 0, 1800, 1000), [Rect2(515, 365, 30, 10)], 0)
	if condition == "dead": next.health.current_hp = 0
	if condition == "defense": next.health.physical_defense = 100
	if condition == "late": next.health.current_hp = 0; farther.position.y = 560
	# Real trap activation creates the opening; placement must happen before bow emission.
	_check(arena.player.use_hunter_trap(&"hunter_thorn_trap", first.position), "real trap seeds opening for real Covering Shot")
	var trap := arena.trap_registry.active_traps()[0] as HunterTrap
	trap.set_process(false); trap._process(trap.arming_duration + 0.001)
	var opening := arena.player.hunter_state.opening(first.get_instance_id())
	_check(not opening.is_empty(), "primary prey has actual trap opening")
	if opening.is_empty(): await _finish(arena); return
	var total: float = opening["request"].physical_damage
	var second_opening := arena.player.hunter_state.opening(next.get_instance_id())
	events.clear()
	_check(arena.player.use_hunter_covering_shot(Vector2.RIGHT), "actual Covering Shot launches captured projectile")
	var projectiles := get_nodes_in_group("player_projectiles")
	if condition == "late":
		next = _victim(arena, Vector2(530, 400))
		_check(not projectiles[0].request.context._budget.targets.has(next.get_instance_id()), "new eligible neighbor was outside launch causal plan")
	_check(projectiles.size() == 1, "covering policy adds no projectile")
	if condition == "remove": _remove(arena, &"hunter_covering_fan")
	var callback_count := [0]
	if condition == "reentry":
		first.health.damage_applied.connect(func(result: Dictionary) -> void:
			if result["skill_id"] == &"hunter_exploit":
				callback_count[0] += 1
				arena.player.record_hunter_damage(result)
				next.position = Vector2(900, 900)
		)
	for projectile: Node in projectiles:
		_check(bool(projectile.request.effect_snapshot["kit_policies"].get(&"hunter_covering_fan", false)) == transformed, "Covering Shot captures policy before flight/removal")
		projectile.set_process(false)
		if condition == "pause":
			paused = true; var position_before: Vector2 = projectile.position
			projectile._process(1)
			_check(projectile.position == position_before and not arena.player.hunter_state.opening(first.get_instance_id()).is_empty(), "pause freezes arrow and opening consumption")
			paused = false
		projectile._process(1)
	var exploits := events.filter(func(item: Dictionary) -> bool: return item["skill_id"] == &"hunter_exploit")
	var split := transformed and condition not in ["fallback", "outside", "blocked"]
	_check(exploits.size() == (2 if split else 1), "one opening yields expected finite parcels %s" % condition)
	if condition == "original_passives" and not exploits.is_empty():
		passive_baseline = exploits[0]["physical_component"]
		_check(passive_baseline > total, "actual untransformed exploit includes useful discipline/easy-prey")
	if passives: total = passive_baseline
	var expected_second := farther if condition == "dead" else next
	var brute := 0.0
	for item: Dictionary in exploits:
		var defended: bool = condition == "defense" and item["target_id"] == next.get_instance_id()
		var raw: float = item["physical_component"] * (2 if defended else 1)
		brute += raw
		_check(is_equal_approx(raw, total * (0.5 if split else 1)), "parcel split precedes target defense")
		_check(item["secondary"] and not item["can_trigger_effects"] and not item["critical"], "both parcels cannot crit or cascade")
		_check(item["target_id"] == first.get_instance_id() or (split and item["target_id"] == expected_second.get_instance_id()), "distance, tie identity and alive filter choose fixed pair")
	_check(is_equal_approx(brute, total), "total raw exploration unchanged")
	if passives: _check(passive_baseline > 0 and arena.run_state.build_snapshot.has_passive(&"hunter_shooting_discipline") and arena.run_state.build_snapshot.has_passive(&"hunter_easy_prey"), "passive comparison uses actually learned production powers")
	_check(arena.player.hunter_state.opening(next.get_instance_id()).is_empty() == second_opening.is_empty(), "secondary parcel never consumes nearby prey opening")
	_check(arena.player.hunter_state.opening(first.get_instance_id()).is_empty() and is_equal_approx(arena.player.hunter_state.step_remaining, HunterTuning.STEP_DURATION), "one opening consumed and one movement step")
	if condition == "reentry": _check(callback_count[0] == 1, "secondary reentrant callbacks cannot consume another opening")
	await _finish(arena)
func _launch(casting: GeometerCasting, target: CombatActor, element: StringName, third: bool = false) -> GeometerTraceProjectile:
	var skill := &"geometer_triangulation" if third else &"geometer_trace"
	var cooldown := casting.player.skill_cooldown(skill)
	if cooldown > 0: casting.player._process(cooldown + 0.001)
	var old: Array[int] = []
	for existing: Node in get_nodes_in_group("player_projectiles"): old.append(existing.get_instance_id())
	casting.construction.grammar.select_element(element)
	casting.launch(casting.capture(skill, target.position))
	for projectile: Node in get_nodes_in_group("player_projectiles"):
		if projectile is GeometerTraceProjectile and projectile.get_instance_id() not in old and not projectile.is_queued_for_deletion():
			projectile.set_process(false); return projectile
	return null
func _collapse(condition: String) -> void:
	var arena := _scene(&"mg_ar", &"geometer_collapse_first_element" if condition != "original" else &"")
	arena.player.position = Vector2(100, 100)
	var a := _victim(arena, Vector2(300, 200))
	var b := _victim(arena, Vector2(500, 200))
	var c := _victim(arena, Vector2(400, 420))
	var near_a := _victim(arena, Vector2(320, 230))
	var near_c := _victim(arena, Vector2(400, 390))
	var casting := arena.geometer_casting
	casting.targets = arena.enemies
	if condition != "empty":
		for pair: Array in [[a, &"lightning" if condition == "lightning" else &"fire", false], [b, &"ice", false]]:
			var projectile := _launch(casting, pair[0], pair[1])
			_check(projectile != null, "real Trace builds collapse construction")
			if projectile != null: projectile._process(1)
		if condition != "wall":
			var third := _launch(casting, c, &"ice", true)
			_check(third != null, "actual Triangulation closes figure")
			if third != null: third._process(1)
	var command := casting.capture(&"geometer_collapse", Vector2(400, 280), true)
	if condition == "pause":
		var sp := arena.player.current_sp; paused = true
		_check(not casting.collapse(command) and arena.player.current_sp == sp and casting.construction.has_active_figure(), "paused collapse neither spends nor consumes geometry")
		paused = false
	if condition == "empty":
		var sp := arena.player.current_sp
		_check(not casting.collapse(command) and arena.player.current_sp == sp, "missing construction cannot grant collapse")
		await _finish(arena); return
	for actor: CombatActor in arena.enemies: actor.hard_controls.clear()
	events.clear()
	var captured: Array[Dictionary] = []
	casting.hit.connect(func(request: DamageRequest, victim: CombatActor) -> void:
		if request.skill_id == &"geometer_collapse":
			captured.append({"request": request.copy(), "target": victim.get_instance_id()})
			if condition == "remove" and captured.size() == 1: _remove(arena, &"geometer_collapse_first_element")
			if condition == "reentry" and captured.size() == 1: _check(not casting.collapse(command), "callback cannot consume same figure twice")
	)
	_check(casting.collapse(command), "actual paid collapse consumes production figure")
	_check(not casting.construction.has_active_figure(), "collapse clears construction before first damage callback")
	var tuning := ClassCatalog.geometer_collapse_tuning(1)
	var element := &"wall" if condition == "wall" else (&"ice" if condition == "original" else (&"lightning" if condition == "lightning" else &"fire"))
	_check(not captured.is_empty(), "collapse actually emits damage")
	for item: Dictionary in captured:
		var request: DamageRequest = item["request"]
		_check(is_equal_approx(request.magic_damage, arena.player.stat_breakdown.value(&"magic_attack") * float(tuning[element])), "captured policy selects A element power; original C and wall unchanged")
	if condition == "lightning": _check(not captured.is_empty() and captured[0]["target"] == a.get_instance_id(), "first lightning link begins at A vertex")
	if condition != "wall": _check(near_a.is_rooted() == (condition == "original"), "A fire transformation removes C ice root without changing geometry")
	_check(not casting.collapse(command), "second collapse cannot replay captured figure")
	await _finish(arena)
