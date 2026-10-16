extends SceneTree
const Spatial = preload("res://tools/content/spatial_bundle.gd")
var checks := 0
var failures := 0
var catalog: BuildEffectCatalog
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	var entries: Array[Dictionary] = Spatial.entries()
	var prepared := ContentAuthoring.prepare(entries)
	if not prepared["ok"]: push_error(str(prepared)); quit(1); return
	catalog = ContentAuthoring.compile_bundle(entries, prepared["text_template"], false)["catalog"]
	for condition: String in ["follow", "fixed", "remove", "dead", "blocked", "pause", "cancel", "propagate"]: await _echo(condition)
	for condition: String in ["follow", "fixed", "remove", "moving", "dead_before", "dead_after", "miss", "pause", "fifo", "triangle"]: await _ground(condition)
	print("E06 spatial execution: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _scene(evolution: StringName, enabled: bool) -> RunController:
	var build := BuildSnapshot.new()
	build.character_id = "spatial-real"
	build.base_class_id = &"mage"
	build.evolution_id = evolution
	build.base_level = 30
	build.job_level = 40
	build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(&"mage", evolution)
	if evolution == &"spiritualist": build.skill_ranks = {&"spiritualist_echo_curse": 1, &"fire_wall": 2, &"fire_spear": 1}
	else: build.skill_ranks = {&"geometer_trace": 1, &"geometer_triangulation": 5}
	build.action_slots = ActionBarLayout.empty()
	var state := RunState.from_build("spatial-real", build)
	if enabled: state.augment_stacks[&"spiritualist_echo_fixed_origin" if evolution == &"spiritualist" else &"geometer_ground_anchor"] = 1
	_check(state.set_effect_catalog(catalog)["ok"], "spatial catalog injects with correct learned kit")
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
	_check(arena.persistent_facade == null, "no user profile save in fixture")
	return arena
func _victim(arena: RunController, point: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo espacial", Color.WHITE, StatCalculator.calculate({}))
	actor.position = point
	actor.health.max_hp = 5000
	actor.health.current_hp = 5000
	actor.health.physical_defense = 0
	actor.health.magic_defense = 0
	actor.health.flee_rating = 0
	actor.health.damage_applied.connect(arena._on_enemy_damage_resolved)
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
	_check(not arena.run_state.composed_build()["kit_policies"].values().has(true), "current build loses policy while in-flight capture stays")
func _resolve_echo(arena: RunController, delta: float) -> void:
	for echo: Dictionary in arena.spiritualist_echo_state.advance(delta): arena._apply_spiritualist_echo(echo)
	arena.spiritualist_echo_state.finish_resolution()
func _echo(condition: String) -> void:
	var fixed := condition != "follow"
	var arena := _scene(&"spiritualist", fixed)
	var carrier := _victim(arena, Vector2(500, 350))
	var neighbor := _victim(arena, Vector2(520, 350))
	_check(arena.player.use_spiritualist_echo_curse(carrier), "real curse applies finite marks")
	_check(arena.spiritualist_echo_state.has_mark(carrier.get_instance_id()) and arena.spiritualist_echo_state.has_mark(neighbor.get_instance_id()), "curse marks real neighboring targets")
	if condition == "cancel":
		var sp := arena.player.current_sp
		_check(arena.player.begin_skill_cast(&"fire_spear", carrier.position, carrier) and arena.player.cancel_active_cast(), "real preparation cancels")
		_check(arena.player.current_sp == sp and arena.spiritualist_echo_state.pending.is_empty(), "cancelled action costs nothing and schedules no wave")
		await _finish(arena); return
	_check(arena.player.use_spear(&"fire_spear", carrier), "real inherited spear triggers wave after actual collision")
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(projectiles.size() == 1, "one actual spear projectile")
	if condition == "remove": _remove(arena, &"spiritualist_echo_fixed_origin")
	for projectile: Node in projectiles:
		projectile.set_process(false)
		projectile._process(1)
	var state := arena.spiritualist_echo_state
	_check(state.pending.size() == 1, "real primary impact schedules carrier once")
	if state.pending.is_empty(): await _finish(arena); return
	_check(bool(state.pending[0].get("fixed_origin", false)) == fixed, "wave policy captured from emitted action")
	_check(not fixed or state.pending[0]["center"] == Vector2(500, 350), "scheduled origin stores carrier position")
	carrier.position = Vector2(850, 350)
	var carrier_hp := carrier.health.current_hp
	var neighbor_hp := neighbor.health.current_hp
	if condition == "dead": carrier.health.current_hp = 0
	if condition == "blocked": arena.navigation.configure(Rect2(0, 0, 1800, 1000), [Rect2(507, 310, 8, 80)], 0)
	if condition == "pause":
		paused = true
		var remaining: float = state.pending[0]["remaining"]
		arena._process(1)
		_check(state.pending.size() == 1 and state.pending[0]["remaining"] == remaining, "scene pause freezes scheduled echo")
		paused = false
	_resolve_echo(arena, 0.36)
	if condition in ["dead", "blocked"]:
		_check(neighbor.health.current_hp == neighbor_hp, "dead carrier or blocked ray produces no phantom hit")
	elif not fixed:
		_check(carrier.health.current_hp < carrier_hp and neighbor.health.current_hp == neighbor_hp, "original wave follows moving carrier")
	else:
		_check(carrier.health.current_hp == carrier_hp and neighbor.health.current_hp < neighbor_hp, "fixed wave hits original area and allows carrier to escape")
	if condition == "propagate":
		_check(state.pending.size() == 1 and state.pending[0]["center"] == neighbor.position, "finite propagation captures next carrier at its own scheduling point")
		_resolve_echo(arena, 0.36)
		_check(state.pending.is_empty() and state.waves.is_empty(), "finite carrier wave ends without generic cascade")
	await _finish(arena)
func _launch(casting: GeometerCasting, target: CombatActor, element: StringName, third: bool = false) -> GeometerTraceProjectile:
	var skill := &"geometer_triangulation" if third else &"geometer_trace"
	var cooldown := casting.player.skill_cooldown(skill)
	if cooldown > 0: casting.player._process(cooldown + 0.001)
	var before: Array[int] = []
	for existing: Node in get_nodes_in_group("player_projectiles"): before.append(existing.get_instance_id())
	casting.construction.grammar.select_element(element)
	var command := casting.capture(&"geometer_triangulation" if third else &"geometer_trace", target.position)
	casting.launch(command)
	for projectile: Node in get_nodes_in_group("player_projectiles"):
		if projectile is GeometerTraceProjectile and not projectile.is_queued_for_deletion() and projectile.get_instance_id() not in before:
			projectile.set_process(false)
			return projectile
	return null
func _ground(condition: String) -> void:
	var fixed := condition != "follow"
	var arena := _scene(&"mg_ar", fixed)
	arena.player.position = Vector2(100, 100)
	var first := _victim(arena, Vector2(300, 200))
	var second := _victim(arena, Vector2(500, 200))
	var third := _victim(arena, Vector2(400, 420))
	var casting := arena.geometer_casting
	casting.targets = arena.enemies
	var projectile := _launch(casting, first, &"fire")
	_check(projectile != null, "real Trace launches paid production projectile")
	if projectile == null: await _finish(arena); return
	_check(bool(projectile.request.effect_snapshot["kit_policies"].get(&"geometer_ground_anchor", false)) == fixed, "ground mode captured in real emission")
	if condition == "remove": _remove(arena, &"geometer_ground_anchor")
	if condition == "miss": arena.navigation.configure(Rect2(0, 0, 1800, 1000), [Rect2(190, 120, 20, 200)], 0)
	if condition == "pause":
		paused = true
		var point := projectile.position
		projectile._process(1)
		_check(projectile.position == point and casting.construction.vertices.is_empty(), "pause freezes real Trace flight")
		paused = false
	var later: GeometerTraceProjectile
	if condition == "fifo":
		later = _launch(casting, second, &"ice")
		_check(later != null and later != projectile, "second real ticket reserved while first flies")
		if later != null:
			later._process(1)
			_check(casting.construction.vertices.is_empty(), "out-of-order real impact awaits FIFO")
			second.position = Vector2(550, 200)
			casting.advance(0.5)
	if condition == "moving": first.position = Vector2(450, 200)
	if condition == "dead_before": first.health.current_hp = 0
	var impact_point := first.position
	projectile._process(1)
	if condition in ["miss", "dead_before"]:
		_check(casting.construction.vertices.is_empty(), "failed collision cannot invent ground vertex")
		await _finish(arena); return
	_check(not casting.construction.vertices.is_empty(), "actual impact creates first vertex")
	if casting.construction.vertices.is_empty(): await _finish(arena); return
	_check(casting.construction.vertices[0].actor_id == (0 if fixed else first.get_instance_id()), "ground vertex has no carrier; original keeps selected actor")
	if condition == "dead_after": first.health.current_hp = 0
	first.position = Vector2(350, 300)
	casting.advance(0.01)
	_check(casting.construction.vertices[0].position == (impact_point if fixed else first.position), "real vertex spatial difference survives moving target")
	if condition == "fifo":
		_check(casting.construction.vertices.size() == 2 and casting.construction.vertices[1].position == Vector2(500, 200), "confirmed later impact stays fixed while waiting for first")
	if condition == "triangle":
		var second_shot := _launch(casting, second, &"ice")
		if second_shot != null: second_shot._process(1)
		var closing := _launch(casting, third, &"lightning", true)
		_check(closing != null, "real learned Triangulation can close fixed-ground figure")
		if closing != null: closing._process(1)
		_check(casting.construction.vertices.size() == 3 and casting.construction.vertices[2].actor_id == 0 and casting.construction.shape == GeometerConstructionState.Shape.TRIANGLE, "Triangulation keeps legal grammar and ground anchoring")
	await _finish(arena)
