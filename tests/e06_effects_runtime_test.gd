extends SceneTree
const Fixture = preload("res://tests/e06_effects_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		_runtime_origin(origin)
	_dot_pause_and_limits()
	_mixed_kit_quota()
	_echo_and_kill_exceptions()
	_berserker_last_slot()
	_sentinel_multiple_victims()
	_nova_component_families()
	await _arena_budget()
	print("E06 effects runtime: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _runtime_origin(origin: StringName) -> void:
	var state := RunState.new(&"mage")
	var effects: Array[EffectDefinition] = [Fixture.count_effect(), Fixture.proc_effect(), Fixture.range_effect()]
	var catalog: BuildEffectCatalog = Fixture.catalog_for(origin, effects)
	var contents: Dictionary = Fixture.state_for(origin, state.build_snapshot)
	if contents.has("augment_stacks"):
		state.augment_stacks.assign(contents["augment_stacks"])
	state.card_sockets = contents.get("card_sockets", {})
	_check(state.set_effect_catalog(catalog)["ok"], "runtime fixture catalog injected")
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 1000), [], 0.0)
	var player := PlayerActor.new()
	player.configure(nav, state)
	player.global_position = Vector2(100, 100)
	root.add_child(player)
	player.set_process(false)
	var victim := CombatActor.new()
	victim.setup("Fixture", Color.WHITE, StatCalculator.calculate({}, {}, 1, [{"source_id": &"health", "flat": {&"max_hp": 900.0}}]))
	victim.global_position = Vector2(100 + ClassCatalog.skill_definition(&"fire_spear").rank_definition(1).range + 25.0, 100)
	root.add_child(victim)
	victim.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var emitted: Array[DamageRequest] = []
	var counts: Array[int] = []
	player.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, count: int) -> void:
		emitted.append(request.copy())
		counts.append(count))
	player.status_damage_requested.connect(func(request: DamageRequest, target: CombatActor) -> void: target.apply_damage(request, rng))
	victim.health.damage_applied.connect(player.resolve_build_effect_procs)
	var preview := state.skill_effect_capture(&"fire_spear")
	_check(player.can_target_skill(&"fire_spear", victim) and player.skill_range(&"fire_spear") == preview["values"]["range"], "transformed range reaches target beyond base range")
	var sp_before := player.current_sp
	_check(player.use_spear(&"fire_spear", victim) and counts == [2] and counts[0] == preview["values"]["projectile_count"], "%s preview and real emission agree" % origin)
	_check(is_equal_approx(player.current_sp, sp_before - float(preview["values"]["sp_cost"])), "one canonical cost for transformed emission")
	var captured := emitted[0]
	_check(captured.context != null and captured.context.is_active(), "real emission has live root")
	state.augment_stacks.clear()
	state.card_sockets.clear()
	state.build_snapshot.equipped.clear()
	player.apply_run_modifiers(state)
	_check(state.projectile_count(&"fire_spear") == 1 and captured.effect_snapshot["procs"].size() == 1, "later build does not replace captured effects")
	captured.can_crit = false
	captured.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var oracle := CombatMath.resolve(captured, victim.health.physical_defense, victim.health.magic_defense, 0.0, 0.0, 0.0, 1.0)
	var hp_before := victim.health.current_hp
	victim.apply_damage(captured.copy(), rng)
	victim.apply_damage(captured.copy(), rng)
	_check(is_equal_approx(hp_before - victim.health.current_hp, float(oracle["damage"]) * 2.0 + 5.0), "two impacts share one captured secondary family application")
	_check(state.effect_ledger.applications(captured.context) == 1, "old snapshot proc uses common quota once")
	player.free()
	victim.free()

func _dot_pause_and_limits() -> void:
	var state := RunState.new()
	var actor := CombatActor.new()
	actor.setup("Fixture", Color.WHITE, StatCalculator.calculate({}))
	root.add_child(actor)
	actor.set_process(false)
	var stream := DamageRequest.new()
	stream.source_id = 10
	stream.physical_damage = 3.0
	stream.skill_id = &"bleed"
	stream.context = state.effect_ledger.new_root(10)
	actor.apply_bleed(stream, 4.0)
	actor.apply_bleed(stream, 1.0)
	_check(actor.bleed_streams.size() == 1 and actor.bleed_streams["10:bleed"]["remaining"] == 4.0, "same owner/skill renews larger deadline without stacking")
	var roots: Array[String] = []
	actor.status_damage_requested.connect(func(request: DamageRequest, _target: CombatActor) -> void:
		roots.append(request.context.root_event_id)
		_check(request.is_secondary and not request.can_crit, "ticks preserve secondary/no critical"))
	actor.advance_statuses(2.0, true)
	_check(roots.is_empty(), "pause freezes ticks")
	actor.advance_statuses(2.0)
	_check(roots.size() == 2 and roots[0] != roots[1] and roots[0] != stream.context.root_event_id, "each scheduled tick has root, immutable ancestor")
	for index: int in range(2, 6):
		var next := stream.copy()
		next.skill_id = StringName("stream%d" % index)
		actor.apply_bleed(next, 4.0)
	_check(actor.bleed_streams.size() == 4, "fifth DoT stream rejected")
	actor.clear_statuses()
	_check(actor.bleed_streams.is_empty() and actor.burn_request == null, "removal releases captured states")
	for owner_id: int in [10, 11, 12, 13, 14]:
		var burn := stream.copy()
		burn.source_id = owner_id
		burn.context = state.effect_ledger.new_root(owner_id)
		burn.physical_damage = 0.0
		burn.magic_damage = 3.0
		actor.apply_burn(burn, 4.0)
	_check(actor.burn_streams.size() == 4, "burn owner isolation shares four-stream DoT cap")
	actor.apply_bleed(stream, 4.0)
	_check(actor.bleed_streams.is_empty(), "burn and bleed compete for same target cap")
	actor.clear_statuses()
	actor.apply_bleed(stream, 4.0)
	actor.health.current_hp = 0.0
	actor.advance_statuses(1.0)
	_check(roots.size() == 2, "dead actor emits no tick")
	actor.free()

func _arena_budget() -> void:
	var player := PlayerActor.new()
	var state := RunState.new(&"mage")
	state.augment_stacks[&"extra_fire_spear"] = 1
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 1000), [], 0.0)
	player.configure(nav, state)
	root.add_child(player)
	player.set_process(false)
	var nodes: Array[Node] = []
	for index: int in 127:
		var node := Node.new()
		root.add_child(node)
		node.add_to_group("enemy_projectiles")
		nodes.append(node)
	var victim := CombatActor.new()
	victim.setup("Fixture", Color.WHITE, StatCalculator.calculate({}))
	victim.position = Vector2(50, 0)
	root.add_child(victim)
	var sp := player.current_sp
	_check(not player.use_spear(&"fire_spear", victim) and player.current_sp == sp and player.skill_cooldown(&"fire_spear") == 0.0, "projectile slots rejected before resources/cooldown")
	_check(nodes.size() == 127, "hostile projectiles preserved")
	for node: Node in nodes:
		node.free()
	player.free()
	victim.free()
	await process_frame

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _mixed_kit_quota() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "quota-fixture"
	snapshot.base_class_id = &"archer"
	snapshot.evolution_id = &"hunter"
	snapshot.job_level = 40
	snapshot.skill_ranks = {&"snare_trap": 1}
	var state := RunState.from_build("mixed", snapshot)
	var registry := BuildEffectCatalog.new()
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		registry.register_definition(origin, Fixture.definition(origin, origin, [Fixture.proc_effect(StringName("recipe_" + String(origin)), StringName("z_" + String(origin)))]))
	state.augment_stacks = {&"augment": 1}
	state.build_snapshot.equipped = {&"weapon": &"equipment"}
	state.card_sockets = {&"equipment": &"card"}
	_check(state.set_effect_catalog(registry)["ok"], "mixed kit and three origins compose")
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 1000), [], 0.0)
	var player := PlayerActor.new()
	player.configure(nav, state)
	root.add_child(player)
	player.set_process(false)
	var victim := CombatActor.new()
	victim.setup("Fixture", Color.WHITE, StatCalculator.calculate({}))
	victim.position = Vector2(80, 0)
	victim.health.max_hp = 5000.0
	victim.health.current_hp = 5000.0
	root.add_child(victim)
	victim.set_process(false)
	player.activate_hunter_opening(1, victim, player.hunter_opening_snapshot(&"snare_trap"))
	player._begin_effect_emission()
	var request := player._make_physical_request(victim, &"basic_attack", 20.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var fillers: Array[Dictionary] = []
	for index: int in 15:
		fillers.append({"family_id": StringName("a_%02d" % index), "source_id": &"fixture", "target_id": victim.get_instance_id()})
	state.effect_ledger.claim_batch(request.context, fillers)
	var result := victim.health.apply(request, 0.0, 1.0)
	player.prepare_effect_claims(result)
	_check(result["_effect_claims"].size() == 1 and result["_effect_claims"][0]["family_id"] == &"hunter_exploit", "intrinsic sorts with all three origins for last shared slot")
	player.resolve_build_effect_procs(result)
	player.record_hunter_damage(result)
	_check(player.hunter_state.opening(victim.get_instance_id()).is_empty() and player.hunter_state.step_remaining > 0.0 and state.effect_ledger.applications(request.context) == 16, "Hunter consumes reserved claim once at common cap")
	player.record_hunter_damage(result)
	_check(state.effect_ledger.applications(request.context) == 16, "reentrant kit callback cannot spend or refund")
	player.free()
	victim.free()

	# Paid Rupture is the explicit E05 contested exception; generic children never inherit it.
	var actor := CombatActor.new()
	actor.setup("Fixture", Color.WHITE, StatCalculator.calculate({}))
	root.add_child(actor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var secondary := DamageRequest.new()
	secondary.source_id = 10
	secondary.target_id = actor.get_instance_id()
	secondary.physical_damage = 3.0
	secondary.is_secondary = true
	var rng_before := rng.state
	actor.apply_damage(secondary, rng)
	_check(rng.state == rng_before, "generic secondary uses neither HIT nor critical RNG")
	actor.free()

func _echo_and_kill_exceptions() -> void:
	var build := BuildSnapshot.new()
	build.character_id = "echo-budget"
	build.base_class_id = &"mage"
	build.evolution_id = &"spiritualist"
	build.job_level = 40
	var state := RunState.from_build("echo-mixed", build)
	var registry := BuildEffectCatalog.new()
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		registry.register_definition(origin, Fixture.definition(origin, origin, [Fixture.proc_effect(StringName("recipe_" + String(origin)), StringName("generic_" + String(origin)))]))
	state.augment_stacks = {&"augment": 1}
	state.build_snapshot.equipped = {&"weapon": &"equipment"}
	state.card_sockets = {&"equipment": &"card"}
	state.set_effect_catalog(registry)
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 1000), [], 0.0)
	var player := PlayerActor.new()
	player.configure(nav, state)
	root.add_child(player)
	player.set_process(false)
	var controller := RunController.new()
	controller.player = player
	controller.navigation = nav
	controller.run_state = state
	controller.spiritualist_echo_state = SpiritualistEchoState.new(player.get_instance_id())
	var actors: Array[CombatActor] = []
	for index: int in 3:
		var actor := CombatActor.new()
		actor.setup("Fixture", Color.WHITE, StatCalculator.calculate({}))
		actor.position = Vector2(100 + index * 20, 100)
		actor.health.max_hp = 5000.0
		actor.health.current_hp = 5000.0
		root.add_child(actor)
		actor.set_process(false)
		actor.health.damage_applied.connect(controller._on_enemy_damage_resolved)
		actors.append(actor)
		controller.spiritualist_echo_state.mark(actor.get_instance_id(), 0.35)
	controller.enemies.assign(actors)
	player.status_damage_requested.connect(func(request: DamageRequest, target: CombatActor) -> void: target.apply_damage(request, controller.rng))
	player._begin_effect_emission()
	var request := player._make_magic_request(actors[0], &"soul_impact", 20.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var fillers: Array[Dictionary] = []
	for index: int in 12:
		fillers.append({"family_id": StringName("f_%d" % index), "source_id": &"fixture", "target_id": actors[0].get_instance_id()})
	state.effect_ledger.claim_batch(request.context, fillers)
	actors[0].apply_damage(request, controller.rng)
	_check(state.effect_ledger.applications(request.context) == 15 and controller.spiritualist_echo_state.pending.size() == 1, "real Echo trigger shares root with all three proc origins")
	var before := 0.0
	for actor: CombatActor in actors:
		before += actor.health.current_hp
	for echo: Dictionary in controller.spiritualist_echo_state.advance(0.36):
		controller._apply_spiritualist_echo(echo)
	var after := 0.0
	for actor: CombatActor in actors:
		after += actor.health.current_hp
	_check(before > after and state.effect_ledger.applications(request.context) == 16, "one remaining Echo pair spends original shared slot")
	for echo: Dictionary in controller.spiritualist_echo_state.advance(0.36):
		controller._apply_spiritualist_echo(echo)
	controller.spiritualist_echo_state.finish_resolution()
	_check(state.effect_ledger.applications(request.context) == 16 and controller.spiritualist_echo_state.pending.is_empty(), "finite delayed wave cannot reset budget or loop")
	for actor: CombatActor in actors:
		actor.free()
	controller.free()
	player.free()

	build = BuildSnapshot.new()
	build.character_id = "blood-budget"
	build.base_class_id = &"swordsman"
	build.skill_ranks = {&"blood_thirst": 1}
	build.passive_slots = [&"blood_thirst"]
	state = RunState.from_build("blood", build)
	player = PlayerActor.new()
	player.configure(nav, state)
	player.health.current_hp -= 20.0
	root.add_child(player)
	player.set_process(false)
	controller = RunController.new()
	controller.player = player
	controller.run_state = state
	var victim := CombatActor.new()
	victim.setup("Fixture", Color.WHITE, StatCalculator.calculate({}))
	victim.health.current_hp = 1.0
	root.add_child(victim)
	victim.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	var dot := DamageRequest.new()
	dot.context = state.effect_ledger.new_root(player.get_instance_id()).secondary_prototype()
	dot = dot.scheduled_tick()
	dot.source_id = player.get_instance_id()
	dot.target_id = victim.get_instance_id()
	dot.skill_id = &"bleed_tick"
	dot.physical_damage = 5.0
	dot.is_secondary = true
	var hp := player.health.current_hp
	var killed := victim.health.apply(dot, 0.0, 1.0)
	_check(killed["killed"] and player.health.current_hp > hp and state.effect_ledger.applications(dot.context) == 2, "Blood Thirst DoT exception heals with shared claim")
	hp = player.health.current_hp
	controller._on_enemy_damage_resolved(killed)
	_check(player.health.current_hp == hp and state.effect_ledger.applications(dot.context) == 2, "kill callback replay cannot recover twice")
	victim.free()
	player.free()
	controller.free()

func _berserker_last_slot() -> void:
	var build := BuildSnapshot.new()
	build.character_id = "pursuit-budget"
	build.base_class_id = &"swordsman"
	build.evolution_id = &"berserker"
	build.job_level = 40
	build.skill_ranks = {&"berserker_rupture": 1, &"berserker_pursuit": 1}
	var state := RunState.from_build("pursuit", build)
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 1000), [], 0.0)
	var player := PlayerActor.new()
	player.configure(nav, state)
	root.add_child(player)
	player.set_process(false)
	var victim := CombatActor.new()
	victim.setup("Fixture", Color.WHITE, StatCalculator.calculate({}))
	root.add_child(victim)
	victim.set_process(false)
	player.berserker_wounds[victim.get_instance_id()] = {"stacks": 1, "remaining": 4.0}
	player.current_sp -= 5.0
	var sp := player.current_sp
	player._begin_effect_emission()
	var request := player._make_physical_request(victim, &"basic_attack", 5.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var fillers: Array[Dictionary] = []
	for index: int in 15:
		fillers.append({"family_id": StringName("a_%d" % index), "source_id": &"fixture", "target_id": victim.get_instance_id()})
	state.effect_ledger.claim_batch(request.context, fillers)
	var result := victim.health.apply(request, 0.0, 1.0)
	player.prepare_effect_claims(result)
	player.record_berserker_damage(result)
	_check(player.current_sp > sp and player.berserker_wound_stacks(victim.get_instance_id()) == 1 and state.effect_ledger.applications(request.context) == 16, "accepted Pursuit applies even when later Wound candidate is discarded")
	player.free()
	victim.free()

func _sentinel_multiple_victims() -> void:
	var build := BuildSnapshot.new()
	build.character_id = "focus-budget"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel"
	build.job_level = 40
	build.skill_ranks = {&"sentinel_observe": 5, &"sentinel_piercing_shot": 1}
	var state := RunState.from_build("focus", build)
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 1000), [], 0.0)
	var player := PlayerActor.new()
	player.configure(nav, state)
	root.add_child(player)
	player.set_process(false)
	player.sentinel_combat_active = true
	player.sentinel_state.focus = 60.0
	var actors: Array[CombatActor] = []
	for index: int in 3:
		var actor := CombatActor.new()
		actor.setup("Fixture", Color.WHITE, StatCalculator.calculate({}))
		root.add_child(actor)
		actor.set_process(false)
		actors.append(actor)
	player.sentinel_state.observe(actors[1].get_instance_id(), 5)
	player._begin_effect_emission()
	var prototype := player._make_magic_request(actors[0], &"sentinel_piercing_shot", 1.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var second_result: Dictionary = {}
	for index: int in 2:
		var request := prototype.copy()
		request.target_id = actors[index].get_instance_id()
		var result := actors[index].health.apply(request, 0.0, 1.0)
		player.prepare_effect_claims(result)
		player.record_sentinel_damage(result)
		second_result = result
	_check(is_equal_approx(player.sentinel_state.focus, 74.0) and player.sentinel_state.observation_charges == 2 and state.effect_ledger.applications(prototype.context) == 2, "first unmarked victim does not suppress later marked victim; intrinsic return remains once per emission")
	player.record_sentinel_damage(second_result)
	_check(is_equal_approx(player.sentinel_state.focus, 74.0) and state.effect_ledger.applications(prototype.context) == 2, "replayed marked result cannot recover Focus twice")
	var fillers: Array[Dictionary] = []
	for index: int in 14:
		fillers.append({"family_id": StringName("fill_%d" % index), "source_id": &"fixture", "target_id": actors[0].get_instance_id()})
	state.effect_ledger.claim_batch(prototype.context, fillers)
	player.sentinel_state.observe(actors[2].get_instance_id(), 5)
	player.sentinel_state.observation_cooldown = 0.0
	var request := prototype.copy()
	request.target_id = actors[2].get_instance_id()
	var result := actors[2].health.apply(request, 0.0, 1.0)
	player.prepare_effect_claims(result)
	player.record_sentinel_damage(result)
	_check(is_equal_approx(player.sentinel_state.focus, 74.0) and player.sentinel_state.observation_charges == 3 and state.effect_ledger.applications(prototype.context) == 16, "later marked victim cannot recover beyond shared root cap")
	for actor: CombatActor in actors:
		actor.free()
	player.free()

func _nova_component_families() -> void:
	var build := BuildSnapshot.new()
	build.character_id = "nova-budget"
	build.base_class_id = &"mage"
	build.evolution_id = &"elementalist"
	build.job_level = 40
	build.skill_ranks = {&"elementalist_tri_nova": 1}
	var state := RunState.from_build("nova", build)
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 1000), [], 0.0)
	var player := PlayerActor.new()
	player.configure(nav, state)
	root.add_child(player)
	player.set_process(false)
	var victim := CombatActor.new()
	victim.setup("Fixture", Color.WHITE, StatCalculator.calculate({}))
	victim.health.max_hp = 10000.0
	victim.health.current_hp = 10000.0
	root.add_child(victim)
	victim.set_process(false)
	var requests: Array[DamageRequest] = []
	player.elementalist_tri_nova_requested.connect(func(_center: Vector2, captured: Array[DamageRequest], _bonus: float) -> void: requests.assign(captured))
	player.use_elementalist_tri_nova()
	var fillers: Array[Dictionary] = []
	for index: int in 14:
		fillers.append({"family_id": StringName("fill_%d" % index), "source_id": &"fixture", "target_id": victim.get_instance_id()})
	state.effect_ledger.claim_batch(requests[0].context, fillers)
	var children: Array[DamageRequest] = []
	for index: int in [1, 2]:
		var child := requests[index].copy()
		child.target_id = victim.get_instance_id()
		children.append(child)
		var result := victim.health.apply(child, 0.0, 1.0)
		_check(not result.is_empty() and not result["can_trigger_effects"] and child.context.root_event_id == requests[0].context.root_event_id, "distinct Nova element component applies without fresh root or cascades")
	_check(state.effect_ledger.applications(requests[0].context) == 16 and victim.health.apply(children[0].copy(), 0.0, 1.0).is_empty() and victim.health.apply(children[1].copy(), 0.0, 1.0).is_empty(), "both Nova components share cap16 and reject replay")
	player.free()
	victim.free()
