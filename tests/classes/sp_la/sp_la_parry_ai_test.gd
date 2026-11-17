extends SceneTree
## E09 K3 — the Duelista parry window against REAL enemy attacks (extra criterion of
## K3): EnemyActor instances run their own AI (_process) and commit their attacks
## through RunController._on_enemy_attack_requested, the same path as the game. The
## Duelista only casts through PlayerActor.use_kit_skill and ticks real clocks.
## Covered: inside and outside the window (with and without the Guarda Paciente),
## projectile (real arrow in flight) and area refused, back and flank refused, turn
## and sight break of the attacker, Finta and the automatic parry, and the Duelo
## against three enemies (each parried, turned and answered from behind).
## Areas: no current enemy produces them (T1 5.3, reserved), so a real claw commit
## is published as `area` through RunController._kit_publish_enemy_attack.
## Fixture profiles only (no save on disk).
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const STEP := 0.05

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var kit: ClassKit
var flank: FlankAuthority
var hostiles: Array[EnemyActor] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	_check_window_inside_and_outside()
	_check_patient_guard_window()
	_check_turn_and_sight()
	_check_back_and_flank_refused()
	_check_projectile_refused()
	_check_area_refused()
	_check_feint_and_auto_parry()
	_check_duel_against_three()
	_cleanup()
	print("E09 K3 sp_la parry vs real enemies: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixture --------------------------------------------------------------------

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	hostiles.clear()
	paused = false

func _ranks(patient_rank: int = 0) -> Dictionary:
	var ranks := {&"slash": 5, &"dash": 5, &"perseverance": 3}
	for skill: StringName in ClassKitRegistry.skill_ids(&"sp_la"):
		ranks[skill] = 3 if skill in [&"duelist_read_opponent", &"duelist_patient_guard"] else 5
	ranks[&"duelist_patient_guard"] = patient_rank
	return ranks

func _setup(ranks: Dictionary) -> void:
	_cleanup()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"sp_la"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"sp_la")
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [&"duelist_parry", &"duelist_fatal_riposte", &"duelist_feint", &"duelist_guarded_retreat", &"duelist_duel"]
	player = PlayerActor.new()
	player.configure(navigation, RunState.from_build("sp-la-ai-" + str(checks), snapshot))
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(400, 350)
	player.character_animation.state.face(Vector2.RIGHT)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 29
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	kit = player.kit
	flank = kit.get("flank") if kit != null else null

## Real enemy: its own AI decides when to strike; nothing is injected in its hit.
func _hostile(at: Vector2, archetype: StringName = &"chaser") -> EnemyActor:
	var hostile := EnemyActor.new()
	hostile.configure(archetype, controller.navigation, player)
	controller.add_child(hostile)
	hostile.set_process(false)
	hostile.global_position = at
	hostile.health.max_hp = 100000.0
	hostile.health.current_hp = 100000.0
	hostile.attack_requested.connect(controller._on_enemy_attack_requested)
	hostile.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(hostile)
	hostiles.append(hostile)
	return hostile

## One gameplay frame: player clocks first (parry window), then each enemy AI, then
## the enemy projectiles in flight.
func _frame() -> void:
	player._process(STEP)
	for hostile: EnemyActor in hostiles:
		if is_instance_valid(hostile) and hostile.is_alive(): hostile._process(STEP)
	for node: Node in controller.get_children():
		if node is ArrowProjectile and is_instance_valid(node): (node as ArrowProjectile)._process(STEP)

func _run_until_attack(hostile: EnemyActor, limit: float = 3.0) -> Dictionary:
	var commits: Array[Dictionary] = []
	var listener := func(event: Dictionary) -> void:
		if int(event.get("attacker_id", 0)) == hostile.get_instance_id(): commits.append(event)
	controller.enemy_attack_committed.connect(listener)
	var time := 0.0
	while commits.is_empty() and time < limit:
		_frame()
		time += STEP
	controller.enemy_attack_committed.disconnect(listener)
	return commits[0] if not commits.is_empty() else {}

func _cast(skill: StringName, target: CombatActor = null) -> bool:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp
	return player.use_kit_skill(skill, target.global_position if target != null else player.global_position, target)

func _serial() -> int:
	return int(kit.get("parry_serial"))

# --- Window ---------------------------------------------------------------------------

func _check_window_inside_and_outside() -> void:
	_setup(_ranks(0))
	_check(kit != null and kit.get_script().resource_path == "res://scripts/classes/sp_la/sp_la_kit.gd", "the production Duelista kit is attached")
	var hostile := _hostile(Vector2(440, 350))
	# Inside: the AI strike lands 0.30-0.35 s after the Aparo (window 0.38 s at R5).
	hostile.attack_cooldown = 0.32
	var hp := player.health.current_hp
	_check(_cast(&"duelist_parry") and flank.parry_open() and is_equal_approx(flank.parry_remaining, 0.38), "Aparo R5 opens a 0.38 s window")
	var event := _run_until_attack(hostile)
	_check(event.get("kind") == &"melee" and event.get("skill_id") == &"enemy_claw", "the real enemy commits a melee claw: " + str(event))
	_check(_serial() == 1 and is_equal_approx(player.health.current_hp, hp) and not flank.parry_open(), "a frontal melee strike inside the window is parried (no damage, charge spent)")
	_check(flank.victim(player) == hostile, "the parried attacker is the victim (último aparado)")
	_check(flank.sentence(player) == 2, "Leitura: the parry adds +2 Sentence")
	# Outside: the next strike comes 0.40-0.45 s after the Aparo, the window closed.
	_setup(_ranks(0))
	hostile = _hostile(Vector2(440, 350))
	hostile.attack_cooldown = 0.42
	hp = player.health.current_hp
	_cast(&"duelist_parry")
	_run_until_attack(hostile)
	_check(_serial() == 0 and player.health.current_hp < hp, "a strike after the window lands with full damage")
	# Too early: the strike before the Aparo is never parried retroactively.
	_setup(_ranks(0))
	hostile = _hostile(Vector2(440, 350))
	hostile.attack_cooldown = 0.0
	hp = player.health.current_hp
	_run_until_attack(hostile)
	var landed := player.health.current_hp < hp
	_cast(&"duelist_parry")
	_check(landed and _serial() == 0, "a strike before the Aparo is not parried")
	# The window is a single charge: two enemies in front, only the first is parried.
	_setup(_ranks(0))
	var first := _hostile(Vector2(440, 340))
	var second := _hostile(Vector2(440, 362))
	first.attack_cooldown = 0.10
	second.attack_cooldown = 0.20
	hp = player.health.current_hp
	_cast(&"duelist_parry")
	_run_until_attack(first)
	_run_until_attack(second)
	_check(_serial() == 1 and player.health.current_hp < hp and flank.victim(player) == first, "one charge per window: the second strike lands")

func _check_patient_guard_window() -> void:
	# Guarda Paciente R3: after 2 s without attacking the window grows to 0.56 s.
	_setup(_ranks(3))
	var hostile := _hostile(Vector2(440, 350))
	hostile.attack_cooldown = 10.0
	for step: int in 42: _frame()
	_check(kit.call(&"patient", player) and is_equal_approx(float(kit.call(&"parry_window", player)), 0.56), "2 s without attacking: window 0.38 + 0.18")
	hostile.attack_cooldown = 0.52
	var hp := player.health.current_hp
	_cast(&"duelist_parry")
	_run_until_attack(hostile)
	_check(_serial() == 1 and is_equal_approx(player.health.current_hp, hp), "with the Guarda Paciente a strike 0.50-0.55 s after the Aparo is parried")
	# The same timing without the patience: the strike lands.
	_setup(_ranks(3))
	hostile = _hostile(Vector2(440, 350))
	hostile.attack_cooldown = 0.52
	kit.set("patience", 0.0)
	hp = player.health.current_hp
	_cast(&"duelist_parry")
	_run_until_attack(hostile)
	_check(_serial() == 0 and player.health.current_hp < hp, "without the patience the same strike lands")

# --- Turn and sight -----------------------------------------------------------------------

func _check_turn_and_sight() -> void:
	_setup(_ranks(0))
	var hostile := _hostile(Vector2(440, 350))
	hostile.attack_cooldown = 0.15
	if hostile.character_animation != null: hostile.character_animation.state.face(Vector2.LEFT)
	_check(FlankRules.side_between(hostile, player)["side"] == &"front", "before the parry the attacker faces the Duelista")
	_cast(&"duelist_parry")
	_run_until_attack(hostile)
	_check(_serial() == 1, "parried")
	_check(hostile.gameplay_facing_override_owner() == FlankRules.TURN_OWNER and is_equal_approx(hostile.gameplay_facing_override_remaining(), FlankRules.TURN_DURATION), "the attacker is turned for 1.5 s (gameplay facing override)")
	_check(FlankRules.side_between(hostile, player)["side"] == &"back", "the turned attacker shows its back to the Duelista")
	_check(hostile.gameplay_facing().dot(Vector2.RIGHT) > 0.99, "the turned attacker looks away (the sprite uses the same facing)")
	var threat_id := hostile.threat_id_for(player)
	_check(hostile.threat.sight_broken(threat_id) and is_equal_approx(hostile.threat.sight_break_remaining(threat_id), FlankRules.SIGHT_BREAK_DURATION), "the attacker loses sight of the Duelista for 1.2 s")
	# The basic attack on the turned victim is a strike from behind: +2.
	var target := hostile as CombatActor
	var request := player.kit.compose_basic_attack(player, target, player.kit_make_request(target, &"basic_attack", 10.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false))
	_check(FlankRules.flags_of(request.effect_snapshot).get("side") == &"back" and is_equal_approx(request.damage_dealt_multiplier, 1.20 * player.kit_make_request(target, &"basic_attack", 1.0, 0.0).damage_dealt_multiplier), "the basic attack is marked from behind with the Leitura R3 bonus (× 1.20)")
	controller._on_attack_requested(request, target)
	_check(flank.sentence(player) == 4, "parry +2 and the basic attack from behind +2")
	paused = true
	var turn_before := hostile.gameplay_facing_override_remaining()
	hostile._process(1.0)
	_check(is_equal_approx(hostile.gameplay_facing_override_remaining(), turn_before), "pause freezes the turn")
	paused = false
	hostile.attack_cooldown = 100.0
	for step: int in 40: hostile._process(STEP)
	_check(hostile.gameplay_facing_override_remaining() <= 0.0 and not hostile.threat.sight_broken(threat_id), "turn and sight break expire on the gameplay clock")

# --- Refusals --------------------------------------------------------------------------------

func _check_back_and_flank_refused() -> void:
	for spot: Vector2 in [Vector2(360, 350), Vector2(400, 390), Vector2(400, 310)]:
		_setup(_ranks(0))
		var hostile := _hostile(spot)
		hostile.attack_cooldown = 0.10
		var side: StringName = FlankRules.side_between(player, hostile)["side"]
		var hp := player.health.current_hp
		_cast(&"duelist_parry")
		var event := _run_until_attack(hostile)
		_check(event.get("kind") == &"melee" and _serial() == 0 and player.health.current_hp < hp and flank.parry_open(), "a %s melee strike is not parried and keeps the charge" % side)
		_check(hostile.gameplay_facing_override_remaining() <= 0.0, "the %s attacker is not turned" % side)

func _check_projectile_refused() -> void:
	_setup(_ranks(0))
	var archer := _hostile(Vector2(620, 350), &"archer")
	archer.attack_cooldown = 0.05
	var hp := player.health.current_hp
	var event := _run_until_attack(archer)
	_check(event.get("kind") == &"projectile" and event.get("skill_id") == &"enemy_arrow", "the real archer looses an arrow (projectile): " + str(event))
	# Duelo (unlimited frontal parries) and a fresh Aparo while the arrow flies.
	_check(_cast(&"duelist_duel"), "Duelo during the flight")
	var time := 0.0
	while is_equal_approx(player.health.current_hp, hp) and time < 2.0:
		_frame()
		time += STEP
	_check(player.health.current_hp < hp and _serial() == 0 and flank.parry_open(), "a frontal arrow is never parried, not even in the Duelo")
	_check(archer.gameplay_facing_override_remaining() <= 0.0, "the archer is not turned")

func _check_area_refused() -> void:
	_setup(_ranks(0))
	var hostile := _hostile(Vector2(440, 350))
	hostile.attack_cooldown = 0.10
	# The real AI commit is republished as an area attack (no area producer exists yet).
	hostile.attack_requested.disconnect(controller._on_enemy_attack_requested)
	var area := func(request: DamageRequest, target: CombatActor, _ranged: bool) -> void:
		controller._kit_publish_enemy_attack(request, target, &"area", false)
		controller._on_attack_requested(request, target)
	hostile.attack_requested.connect(area)
	var kinds: Array[StringName] = []
	controller.enemy_attack_committed.connect(func(event: Dictionary) -> void: kinds.append(StringName(event.get("kind"))))
	var hp := player.health.current_hp
	_cast(&"duelist_parry")
	_run_until_attack(hostile)
	_check(kinds == [&"area"] and _serial() == 0 and player.health.current_hp < hp and flank.parry_open(), "a frontal area hit inside the window is not parried")

# --- Finta and automatic parry ------------------------------------------------------------

func _check_feint_and_auto_parry() -> void:
	_setup(_ranks(0))
	var hostile := _hostile(Vector2(440, 350))
	hostile.attack_cooldown = 10.0
	var before := player.global_position
	_check(_cast(&"duelist_feint", hostile), "Finta on the enemy")
	_check(hostile.marks.owner_of(&"duelist_feint") == player.get_instance_id() and is_equal_approx(hostile.marks.remaining(&"duelist_feint"), 3.5), "Finta R5 marks the enemy for 3.5 s")
	_check(is_equal_approx(player.global_position.distance_to(before), 48.0) and is_zero_approx((player.global_position - before).dot(Vector2.RIGHT)), "side step of 48 px, perpendicular to the enemy")
	# The Duelista turns away: the feinted enemy now strikes from behind, still parried.
	player.character_animation.state.face(Vector2.LEFT)
	var side: StringName = FlankRules.side_between(player, hostile)["side"]
	hostile.attack_cooldown = 0.10
	var hp := player.health.current_hp
	_run_until_attack(hostile)
	_check(side != &"front" and _serial() == 1 and is_equal_approx(player.health.current_hp, hp) and not hostile.marks.has_mark(&"duelist_feint"), "the next melee strike of the feinted enemy counts as parried from the %s" % side)
	_check(hostile.gameplay_facing_override_owner() == FlankRules.TURN_OWNER and flank.victim(player) == hostile, "the feinted enemy is turned and becomes the victim")
	hostile.attack_cooldown = 0.10
	hp = player.health.current_hp
	_run_until_attack(hostile)
	_check(_serial() == 1 and player.health.current_hp < hp, "the Finta counts once")
	# Automatic parry armed by a Riposte kill: the next frontal strike is parried without casting.
	_setup(_ranks(0))
	var doomed := _hostile(Vector2(440, 350))
	var next := _hostile(Vector2(440, 362))
	doomed.attack_cooldown = 10.0
	next.attack_cooldown = 10.0
	flank.mark_victim(player, doomed)
	for index: int in 3: flank.gain(player, doomed, FlankRules.SOURCE_COMBO, "fill_%d" % index)
	doomed.health.current_hp = doomed.health.max_hp * 0.2
	_check(_cast(&"duelist_fatal_riposte", doomed) and not doomed.is_alive(), "a full Sentence under the threshold: the Riposte kills")
	_check(is_equal_approx(float(kit.get("auto_parry_remaining")), 8.0) and not flank.parry_open(), "the kill arms the automatic parry (8 s) without opening a window")
	next.attack_cooldown = 0.5
	hp = player.health.current_hp
	_run_until_attack(next)
	_check(_serial() == 1 and is_equal_approx(player.health.current_hp, hp) and is_zero_approx(float(kit.get("auto_parry_remaining"))) and next.gameplay_facing_override_owner() == FlankRules.TURN_OWNER, "the next frontal strike is parried automatically (and turns the attacker)")
	next.attack_cooldown = 0.10
	hp = player.health.current_hp
	_run_until_attack(next)
	_check(_serial() == 1 and player.health.current_hp < hp, "the automatic parry is used once")

# --- Duelo against three -----------------------------------------------------------------

func _check_duel_against_three() -> void:
	_setup(_ranks(0))
	var trio: Array[EnemyActor] = [_hostile(Vector2(442, 350)), _hostile(Vector2(432, 322)), _hostile(Vector2(432, 378))]
	var cooldowns: Array[float] = [0.10, 0.45, 0.80]
	var thrusts: Array[Dictionary] = []
	for index: int in trio.size():
		trio[index].attack_cooldown = cooldowns[index]
		_check(FlankRules.side_between(player, trio[index])["side"] == &"front", "enemy %d is in front of the Duelista" % index)
		trio[index].health.damage_applied.connect(func(result: Dictionary) -> void:
			if result.get("skill_id") == &"duelist_duel": thrusts.append(result))
	var commits: Array[Dictionary] = []
	controller.enemy_attack_committed.connect(func(event: Dictionary) -> void: commits.append(event))
	var hp := player.health.current_hp
	_check(_cast(&"duelist_duel") and kit.call(&"duel_active") and is_equal_approx(float(kit.get("duel_remaining")), 6.0), "Duelo R5 for 6 s")
	_check(not _cast(&"duelist_parry"), "Aparo is refused during the Duelo")
	var time := 0.0
	while time < 5.5:
		_frame()
		time += STEP
	var attackers := {}
	for event: Dictionary in commits: attackers[int(event["attacker_id"])] = true
	_check(commits.size() >= 6 and attackers.size() == 3, "the three enemies really attack during the Duelo (%d strikes)" % commits.size())
	_check(_serial() == commits.size() and is_equal_approx(player.health.current_hp, hp), "every frontal strike of the three is parried: no damage (%d parries)" % _serial())
	_check(thrusts.size() == commits.size(), "each parry returns one back thrust (%d)" % thrusts.size())
	var all_back := true
	var all_landed := true
	for result: Dictionary in thrusts:
		all_back = all_back and FlankRules.result_flags(result).get("side") == &"back"
		all_landed = all_landed and bool(result.get("landed", false)) and float(result.get("actual_damage", 0.0)) > 0.0
	_check(all_back and all_landed, "every thrust lands from behind the turned attacker")
	var struck := {}
	for result: Dictionary in thrusts: struck[int(result["target_id"])] = true
	_check(struck.size() == 3, "the three enemies are answered")
	for step: int in 20: _frame()
	_check(not kit.call(&"duel_active") and not flank.parry_open(), "the Duelo ends with its clock")
	hp = player.health.current_hp
	for hostile: EnemyActor in trio: hostile.attack_cooldown = 0.05
	for step: int in 4: _frame()
	_check(player.health.current_hp < hp, "after the Duelo the strikes land again")
