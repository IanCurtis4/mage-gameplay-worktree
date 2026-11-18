extends SceneTree
## E10a C1.13 — enemy target primitives (C1.6) and enemy modifiers (C1.7): the combat-target
## override on the flat arena and in the expedition world, the boss refusal, the commit
## deflection, enemy-to-enemy damage credited once to the player (retry included), the decoy,
## the received-damage and accuracy sources composed once in CombatMath, and the movement
## disorientation refused by bosses.
const FixtureKit = preload("res://scripts/classes/fixture/fixture_kit.gd")
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const WorldFixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var navigation: ArenaNavigation
var attacks: Array[Array] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	_check_math()
	_check_modifiers()
	_check_flat_override()
	_check_relay_damage()
	_check_deflection()
	_check_disorientation()
	_check_decoy()
	_check_world_override()
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	print("E10a enemy target: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Setup --------------------------------------------------------------------------

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	attacks.clear()

func _setup() -> void:
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	ClassKitRegistry.install_fixture(&"sp_ac", FixtureKit.new(&"sp_ac"))
	navigation = ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"sp_ac"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"sp_ac")
	snapshot.skill_ranks = {}
	for skill: StringName in ClassKitRegistry.skill_ids(&"sp_ac"): snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [ClassKitRegistry.skill_ids(&"sp_ac")[0], ClassKitRegistry.skill_ids(&"sp_ac")[2], null, null, null]
	player = PlayerActor.new()
	player.configure(navigation, RunState.from_build("enemy-target-" + str(checks), snapshot))
	player.global_position = Vector2(100, 600)
	controller.add_child(player)
	player.set_process(false)
	controller.player = player
	controller.run_state = player.run_state
	controller.enemies = []

func _hostile(at: Vector2, boss: bool = false) -> EnemyActor:
	var hostile := EnemyActor.new()
	hostile.global_position = at
	hostile.configure(&"chaser", navigation, player)
	controller.add_child(hostile)
	hostile.set_process(false)
	if boss: hostile.configure_hard_control_profile(true)
	hostile.attack_requested.connect(func(request: DamageRequest, target: CombatActor, ranged: bool) -> void: attacks.append([request, target, ranged, hostile]))
	hostile.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(hostile)
	return hostile

func _landing(request: DamageRequest) -> DamageRequest:
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	return request

# --- CombatMath composition (C1.7) ----------------------------------------------------

func _check_math() -> void:
	var sources := {&"a": {"multiplier": 2.0, "owner_id": 0, "element": &""}, &"b": {"multiplier": 1.5, "owner_id": 7, "element": &""}, &"c": {"multiplier": 3.0, "owner_id": 0, "element": &"light"}}
	_check(is_equal_approx(CombatMath.received_damage_multiplier(sources, 7, &"light"), 9.0), "all matching sources multiply (2 x 1.5 x 3)")
	_check(is_equal_approx(CombatMath.received_damage_multiplier(sources, 8, &"shadow"), 2.0), "author and element filters exclude the others")
	_check(CombatMath.received_damage_multiplier({}, 1, &"") == 1.0 and CombatMath.accuracy_multiplier({}) == 1.0, "no source keeps the identity")
	_check(is_equal_approx(CombatMath.accuracy_multiplier({&"x": {"reduction": 0.5}, &"y": {"reduction": 0.2}}), 0.4) and CombatMath.accuracy_multiplier({&"z": {"reduction": 2.0}}) == 0.0, "accuracy reductions multiply, clamped to 0..1")

func _check_modifiers() -> void:
	_setup()
	var target := _hostile(Vector2(500, 300))
	target.health.max_hp = 100000.0
	target.health.current_hp = 100000.0
	var rng := RandomNumberGenerator.new()
	var request := DamageRequest.new()
	request.source_id = player.get_instance_id()
	request.target_id = target.get_instance_id()
	request.skill_id = &"paladin_consecrated_impact" # A light skill of the production Paladin.
	request.magic_damage = 100.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	_check(CombatActor.request_element(request) == &"light", "the element of a request comes from its SkillDefinition")
	var base_damage := float(target.apply_damage(request.copy(), rng)["damage"])
	_check(target.add_received_damage_source(&"fixture_exposed", 2.0, 3.0, player.get_instance_id(), &"light"), "a received-damage source with author and element filters is accepted")
	_check(not target.add_received_damage_source(&"", 2.0, 1.0) and not target.add_received_damage_source(&"bad", -1.0, 1.0) and not target.add_received_damage_source(&"bad", 2.0, 0.0), "invalid sources are refused")
	var boosted := float(target.apply_damage(request.copy(), rng)["damage"])
	_check(is_equal_approx(boosted, float(roundi(base_damage * 2.0))) or absf(boosted - base_damage * 2.0) <= 1.0, "matching author and element double the damage (%s -> %s)" % [base_damage, boosted])
	var other := request.copy()
	other.source_id = target.get_instance_id() + 99
	_check(absf(float(target.apply_damage(other, rng)["damage"]) - base_damage) <= 1.0, "another author is not affected")
	var shadow := request.copy()
	shadow.skill_id = &"enemy_claw"
	shadow.magic_damage = 0.0
	shadow.physical_damage = 100.0
	var plain_claw := float(target.apply_damage(shadow.copy(), rng)["damage"])
	target.add_received_damage_source(&"fixture_any", 1.5, 3.0)
	_check(absf(float(target.apply_damage(shadow.copy(), rng)["damage"]) - plain_claw * 1.5) <= 1.0, "an unfiltered source applies to every hit")
	_check(is_equal_approx(target.received_damage_multiplier(player.get_instance_id(), &"light"), 3.0), "the actor reports the composed multiplier")
	target.advance_statuses(5.0, true)
	_check(target.received_damage_sources.size() == 2, "pause freezes the source clocks")
	target.advance_statuses(3.1)
	_check(target.received_damage_sources.is_empty(), "sources expire on the gameplay clock")
	_check(target.add_accuracy_source(&"fixture_seal", 0.5, 2.0, player.get_instance_id()) and is_equal_approx(target.outgoing_hit_rating(100.0), 50.0), "an accuracy reduction scales the actor's own hit rating")
	var claw := target._basic_attack_request(player, false)
	_check(is_equal_approx(claw.hit_rating, target.stat_breakdown.value(&"hit_rating") * 0.5), "the enemy basic request carries the reduced hit rating")
	target.add_received_damage_source(&"fixture_mark", 2.0, 5.0)
	target._on_health_died(target.get_instance_id())
	_check(target.accuracy_sources.is_empty() and target.received_damage_sources.is_empty(), "death clears the modifier sources")

# --- Combat-target override on the flat arena (C1.6) ----------------------------------

func _check_flat_override() -> void:
	_setup()
	var a := _hostile(Vector2(200, 300))
	var b := _hostile(Vector2(500, 300))
	var boss := _hostile(Vector2(800, 300), true)
	_check(a.combat_target() == player and not a.has_target_override(), "the default combat target is the player")
	_check(boss.set_target_override(a, player.get_instance_id(), 3.0, &"fixture")["error_code"] == &"boss_refuses_target" and boss.combat_target() == player, "a boss refuses the override")
	_check(a.set_target_override(player, player.get_instance_id(), 3.0, &"fixture")["error_code"] == &"invalid_target" and a.set_target_override(a, 0, 3.0, &"fixture")["error_code"] == &"invalid_target", "the player and the enemy itself are not override targets")
	_check(a.set_target_override(b, player.get_instance_id(), 0.0, &"fixture")["error_code"] == &"invalid_payload" and a.set_target_override(b, player.get_instance_id(), 1.0, &"")["error_code"] == &"invalid_payload", "duration and reason are required")
	_check(a.set_target_override(b, player.get_instance_id(), 3.0, &"fixture_delirium")["ok"] and a.combat_target() == b and a.target_override_reason() == &"fixture_delirium" and a.target_override_owner_id() == player.get_instance_id(), "the override points at another enemy with owner and reason")
	var start := a.global_position.distance_to(b.global_position)
	for step: int in 5: a._process(0.2)
	_check(a.global_position.distance_to(b.global_position) < start - 10.0, "the overridden enemy chases its new target")
	_check(is_equal_approx(a.target_override_remaining(), 2.0), "the override runs on the gameplay clock")
	a.global_position = b.global_position + Vector2(-40, 0)
	a.attack_cooldown = 0.0
	attacks.clear()
	a._process(0.05)
	_check(attacks.size() == 1 and attacks[0][1] == b and attacks[0][3] == a, "in reach it attacks the override target with its own attack")
	paused = true
	a._process(1.0)
	_check(is_equal_approx(a.target_override_remaining(), 1.95), "pause freezes the override")
	paused = false
	a._process(2.0)
	_check(not a.has_target_override() and a.combat_target() == player, "the override expires and the player is the target again")
	a.set_target_override(b, player.get_instance_id(), 5.0, &"fixture_delirium")
	b.health.current_hp = 0.0
	b._on_health_died(b.get_instance_id())
	a._process(0.05)
	_check(not a.has_target_override(), "the override drops when its target dies")
	var c := _hostile(Vector2(300, 300))
	a.set_target_override(c, player.get_instance_id(), 5.0, &"fixture_delirium")
	controller.remove_child(c)
	a._process(0.05)
	_check(not a.has_target_override(), "the override drops when its target leaves the world")
	controller.add_child(c)
	a.set_target_override(c, player.get_instance_id(), 5.0, &"fixture_delirium")
	a._on_health_died(a.get_instance_id())
	_check(a.target_override.is_empty(), "the override ends with the statuses (death)")

# --- Enemy-to-enemy damage authored by the player ------------------------------------

func _check_relay_damage() -> void:
	_setup()
	var a := _hostile(Vector2(400, 300))
	var b := _hostile(Vector2(440, 300))
	var kit := player.kit
	a.set_target_override(b, player.get_instance_id(), 5.0, &"fixture_delirium")
	a.attack_cooldown = 0.0
	attacks.clear()
	a._process(0.05)
	_check(attacks.size() == 1, "the delirious enemy commits one attack")
	if attacks.size() != 1: return
	var request: DamageRequest = _landing(attacks[0][0])
	var relay: Dictionary = request.effect_snapshot.get(EnemyActor.RELAY_KEY, {})
	_check(request.source_id == player.get_instance_id() and request.target_id == b.get_instance_id() and int(relay.get("actor_id", 0)) == a.get_instance_id() and EnemyActor.attacker_id(request) == a.get_instance_id(), "the hit is authored by the player and delivered by the enemy")
	_check(request.context != null and request.context.ledger() == player.run_state.effect_ledger, "the hit roots in the player's EffectProcLedger")
	_check(request.physical_damage > 0.0 and request.skill_id == &"enemy_claw", "the damage is the enemy's own attack")
	var threat_before := b.threat.amounts.duplicate(true)
	var mode_before := b.engagement_mode
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var result := b.apply_damage(request, rng)
	_check(float(result.get("actual_damage", 0.0)) > 0.0 and EnemyActor.is_relay_result(result), "the relayed hit lands on the other enemy")
	_check(b.threat.amounts == threat_before and b.engagement_mode == mode_before, "the victim's threat and engagement do not change")
	_check(kit.get("calls").has("dealt:enemy_claw"), "the player's damage callbacks see the relayed hit")
	_check(b.apply_damage(request, rng).is_empty(), "a retried request is applied once (EffectProcLedger)")
	# Kill: credited once to the player, retry included.
	b.health.current_hp = 1.0
	a.attack_cooldown = 0.0
	attacks.clear()
	a._process(0.05)
	var lethal: DamageRequest = _landing(attacks[0][0])
	var kill := b.apply_damage(lethal, rng)
	_check(bool(kill.get("killed", false)) and kit.get("calls").count("kill") == 1, "a kill between enemies is the player's")
	controller._on_enemy_damage_resolved(kill)
	_check(kit.get("calls").count("kill") == 1 and controller._credited_kills.has(b.get_instance_id()), "the kill is credited once, even on a retry")
	# Without a live author the hit stays the attacking enemy's.
	var c := _hostile(Vector2(400, 360))
	var orphan := a._basic_attack_request(c, false)
	a.relay_authorship(orphan, c, 0)
	_check(orphan.source_id == a.get_instance_id() and not orphan.effect_snapshot.has(EnemyActor.RELAY_KEY) and orphan.target_id == c.get_instance_id(), "without an owner the damage keeps the enemy authorship")

# --- Commit deflection (C1.6) -------------------------------------------------------

func _check_deflection() -> void:
	_setup()
	var boss := _hostile(Vector2(300, 300), true)
	player.global_position = Vector2(340, 300)
	var minion := _hostile(Vector2(300, 350))
	var other_boss := _hostile(Vector2(250, 300), true)
	var far := _hostile(Vector2(700, 300))
	_check(boss.register_commit_deflection(&"fixture_disorientation", player.get_instance_id(), 1.0, 100.0, 5.0)["ok"], "a deflection is registered on the boss")
	_check(boss.register_commit_deflection(&"", 1, 1.0, 1.0, 1.0)["error_code"] == &"invalid_payload" and boss.register_commit_deflection(&"x", 1, 1.5, 1.0, 1.0)["error_code"] == &"invalid_payload", "invalid deflections are refused")
	boss.player_target_acquired = true
	boss.attack_cooldown = 0.0
	attacks.clear()
	boss._try_attack(false)
	_check(attacks.size() == 1 and attacks[0][1] == minion, "at the commit the hit goes to the minion in reach (never another boss or a far enemy)")
	if attacks.size() == 1:
		var request: DamageRequest = attacks[0][0]
		_check(request.target_id == minion.get_instance_id() and request.source_id == player.get_instance_id() and EnemyActor.attacker_id(request) == boss.get_instance_id(), "the deflected hit is authored by the deflection owner")
	_check(boss.combat_target() == player, "the boss never changes its combat target")
	minion.global_position = Vector2(300, 600)
	var state := boss.combat_rng_state
	boss.attack_cooldown = 0.0
	attacks.clear()
	boss._try_attack(false)
	_check(attacks.size() == 1 and attacks[0][1] == player and boss.combat_rng_state == state, "with no minion in reach the hit stays on the player (no roll spent)")
	minion.global_position = Vector2(300, 350)
	boss.register_commit_deflection(&"fixture_disorientation", player.get_instance_id(), 0.0, 100.0, 5.0)
	boss.attack_cooldown = 0.0
	attacks.clear()
	boss._try_attack(false)
	_check(attacks.size() == 1 and attacks[0][1] == player and boss.combat_rng_state != state, "a failed roll keeps the hit on the player")
	boss.register_commit_deflection(&"fixture_disorientation", player.get_instance_id(), 1.0, 100.0, 1.0)
	boss._process(0.5)
	_check(boss.commit_deflections.has(&"fixture_disorientation"), "the deflection runs on the gameplay clock")
	boss._process(0.6)
	_check(boss.commit_deflections.is_empty(), "the deflection expires")
	# Determinism: the same occurrence draws the same sequence.
	var twin_a := _hostile(Vector2(100, 100))
	var twin_b := _hostile(Vector2(100, 150))
	twin_b.combat_rng_state = twin_a.combat_rng_state
	_check(twin_a._roll() == twin_b._roll() and twin_a._roll() == twin_b._roll(), "the enemy RNG is deterministic from its state")
	far.free()
	other_boss.free()

# --- Movement disorientation (C1.7) ---------------------------------------------------

func _check_disorientation() -> void:
	_setup()
	var boss := _hostile(Vector2(700, 300), true)
	_check(boss.apply_disorient(2.0) == 0.0 and not boss.is_disoriented(), "a boss refuses the movement disorientation")
	var common := _hostile(Vector2(400, 300))
	player.global_position = Vector2(440, 300)
	_check(common.apply_disorient(1.0, Vector2(0, -1)) > 0.0 and common.is_disoriented(), "a common enemy is disoriented")
	common.attack_cooldown = 0.0
	common.player_target_acquired = true
	attacks.clear()
	var before := common.global_position
	for step: int in 3: common._process(0.1)
	_check(attacks.is_empty(), "a disoriented enemy does not attack, even next to the player")
	_check(common.global_position.y < before.y - 5.0 and absf(common.global_position.x - before.x) < 5.0, "it walks in the given wrong direction")
	for step: int in 10: common._process(0.1)
	_check(not common.is_disoriented(), "the disorientation expires on the gameplay clock")
	var rolled := _hostile(Vector2(400, 200))
	rolled.apply_disorient(1.0)
	rolled._process(0.05)
	var toward := rolled.global_position.direction_to(player.global_position)
	_check(not rolled.disorient_heading.is_zero_approx() and rolled.disorient_heading.dot(toward) <= 0.01, "without a heading it rolls one away from its target")

# --- Decoy (C1.6) ---------------------------------------------------------------------

func _check_decoy() -> void:
	_setup()
	var spawned := KitDecoy.spawn(controller, player, Vector2(500, 300), 50.0, 2.0, &"fixture_idol", &"fixture_system")
	_check(spawned["ok"], "a decoy is created with owner, point, HP and deadline")
	var decoy: KitDecoy = spawned["decoy"]
	_check(decoy.owner_id == player.get_instance_id() and decoy.global_position == Vector2(500, 300) and is_equal_approx(decoy.health.max_hp, 50.0) and decoy.is_in_group("player_effects") and decoy.get_parent() == controller, "decoy data and the compact-cut group (player_effects)")
	_check(decoy not in controller.enemies and KitDecoy.decoys_of(controller, player.get_instance_id(), &"fixture_system") == [decoy], "the player never targets it (outside enemies); systems find it by owner")
	_check(KitDecoy.spawn(controller, player, Vector2.ZERO, 0.0, 1.0, &"x")["error_code"] == &"invalid_payload" and KitDecoy.spawn(controller, null, Vector2.ZERO, 1.0, 1.0, &"x")["error_code"] == &"invalid_owner", "invalid decoys are refused")
	_check(KitDecoy.register_drawer(&"fixture_idol", func(_canvas: CanvasItem, _decoy: KitDecoy, _t: float) -> void: pass) and not KitDecoy.register_drawer(&"", Callable()), "the owning system registers a drawer")
	var hostile := _hostile(Vector2(460, 300))
	_check(hostile.set_target_override(decoy, player.get_instance_id(), 5.0, &"fixture_idol")["ok"] and hostile.combat_target() == decoy, "enemies may target the decoy")
	hostile.attack_cooldown = 0.0
	attacks.clear()
	hostile._process(0.05)
	_check(attacks.size() == 1 and attacks[0][1] == decoy and (attacks[0][0] as DamageRequest).source_id == hostile.get_instance_id() and not (attacks[0][0] as DamageRequest).effect_snapshot.has(EnemyActor.RELAY_KEY), "a hit on the decoy is the enemy's own (no player credit)")
	var rng := RandomNumberGenerator.new()
	var hit := _landing(attacks[0][0])
	hit.physical_damage = 1000.0
	decoy.apply_damage(hit, rng)
	_check(decoy.removal_reason == &"destroyed" and not decoy.is_active(), "the decoy is destroyed at 0 HP")
	hostile._process(0.05)
	_check(not hostile.has_target_override(), "the enemy falls back to the player once the decoy is gone")
	var timed: KitDecoy = KitDecoy.spawn(controller, player, Vector2(520, 300), 50.0, 1.0, &"fixture_idol")["decoy"]
	paused = true
	timed._process(2.0)
	_check(timed.is_active() and is_equal_approx(timed.remaining, 1.0), "pause freezes the decoy deadline")
	paused = false
	timed._process(1.1)
	_check(timed.removal_reason == &"expired", "the decoy expires on the gameplay clock")
	# Exact snapshot keeps the decoy and rebinds its owner.
	var kept: KitDecoy = KitDecoy.spawn(player, player, Vector2(540, 300), 30.0, 4.0, &"fixture_idol")["decoy"]
	kept.remaining = 2.5
	var barrier := SnapshotTickBarrier.new()
	paused = true # The tick barrier needs the paused tree.
	_check(barrier.acquire(player)["ok"], "barrier acquired with a decoy")
	var captured := SnapshotRegistry.new().capture(player, barrier)
	_check(captured.get("ok", false), "exact capture with a decoy: " + str(captured.get("detail", captured.get("error_code", ""))))
	if captured.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(captured["snapshot"])))
		_check(restored.get("ok", false), "exact restore with a decoy: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied: KitDecoy
			for child: Node in copy.get_children():
				if child is KitDecoy: copied = child
			_check(copied != null and copied.owner_id == copy.get_instance_id() and is_equal_approx(copied.remaining, 2.5) and copied.drawer_id == &"fixture_idol" and is_equal_approx(copied.health.max_hp, 30.0), "the decoy survives the exact format with its owner rebound")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	barrier.release()
	paused = false
	kept.remove()
	KitDecoy.unregister_drawer(&"fixture_idol")

# --- Expedition world (C1.6 second path) ---------------------------------------------

func _check_world_override() -> void:
	_setup()
	var input := WorldFixture.make()
	var built := ExpeditionAssembler.build(input)
	var world := WorldGeometry.new()
	_check(built["ok"] and world.configure(built["data"]["manifest"], "sample")["ok"], "F1 fixture geometry configured")
	if not built["ok"]: return
	var profile := input.traversal.to_data()
	# Root floor of the F1 fixture: x 0..100, z 0..200 (the bridge slab is above z 100..200).
	_check(player.bind_world_geometry(world, WorldFixture.point("root", Vector3(20, 0, 20)), profile, str(player.get_instance_id()))["ok"], "player bound to the world")
	player.set_process(false)
	var a := _hostile(Vector2.ZERO)
	var b := _hostile(Vector2.ZERO)
	var boss := _hostile(Vector2.ZERO, true)
	for row: Array in [[a, Vector3(20, 0, 190)], [b, Vector3(80, 0, 60)], [boss, Vector3(80, 0, 20)]]:
		var hostile: EnemyActor = row[0]
		_check(hostile.bind_world_geometry(world, WorldFixture.point("root", row[1]), profile, str(hostile.get_instance_id()))["ok"], "world enemy bound")
		hostile.set_process(false)
	var flat := _hostile(Vector2(10, 10))
	_check(a.set_target_override(flat, player.get_instance_id(), 3.0, &"fixture")["error_code"] == &"incompatible_target", "a flat actor is not a world target")
	_check(boss.set_target_override(a, player.get_instance_id(), 3.0, &"fixture")["error_code"] == &"boss_refuses_target", "the boss refuses the override in the world too")
	_check(a.set_target_override(b, player.get_instance_id(), 6.0, &"fixture_delirium")["ok"] and a.combat_target() == b, "world override accepted")
	var start := a.world_distance_to(b)
	for step: int in 10: a._process(0.2)
	_check(a.world_distance_to(b) < start - 20.0, "in the world the enemy chases the override target (%s -> %s)" % [start, a.world_distance_to(b)])
	for step: int in 40:
		if a.world_can_reach(b, 55.0): break
		a._process(0.2)
	a.attack_cooldown = 0.0
	attacks.clear()
	a._process(0.05)
	_check(a.world_can_reach(b, 55.0) and attacks.size() == 1 and attacks[0][1] == b and (attacks[0][0] as DamageRequest).source_id == player.get_instance_id(), "in reach it attacks the world target with the player's authorship")
	paused = true
	var remaining := a.target_override_remaining()
	a._process(1.0)
	_check(is_equal_approx(a.target_override_remaining(), remaining), "pause freezes the world override")
	paused = false
	_check(a.apply_disorient(1.0, Vector2(0, 1)) > 0.0, "a world enemy can be disoriented")
	var before := a.world_point().position
	attacks.clear()
	for step: int in 5: a._process(0.2)
	_check(attacks.is_empty() and a.world_point().position.z > before.z + 5.0, "the disoriented world enemy walks the wrong way without attacking (%s -> %s)" % [before, a.world_point().position])
	_check(boss.apply_disorient(1.0) == 0.0, "the world boss refuses the disorientation")
