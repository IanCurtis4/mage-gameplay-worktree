extends SceneTree
## E09 T6 (C3) — costas, ocultação própria e Sentença. Invariants of C3 and the numbers
## of docs/epics/e09/t6_contract.md. A fixture kit outside the production registry
## (scripts/systems/flank/fixture/) is installed over sp_la and forwards the T1 seam
## hooks to a FlankAuthority. Fixture profiles only; no save or profile is written.
const FlankFixtureKit = preload("res://scripts/systems/flank/fixture/flank_fixture_kit.gd")
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const WorldFixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var kit: ClassKit
var flank: FlankAuthority
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	rng.seed = 29
	_check_side_matrix()
	_check_actor_sides_and_turn()
	_check_categories_and_thresholds()
	_check_concealment_rules()
	_check_concealment_against_acquisition()
	_check_victim_and_sentence()
	_check_execution_lethal_and_single_kill()
	_check_execution_refusals()
	_check_parry_window()
	_check_back_point_flat()
	_check_death_and_pause()
	_check_snapshot_formats()
	_check_world_geometry()
	_check_sources_stay_seam_only()
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	print("E09 T6 flank: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixture ------------------------------------------------------------------------

func _cleanup() -> void:
	paused = false
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()

func _slot(index: int) -> StringName:
	return ClassKitRegistry.SKILL_IDS[&"sp_la"][index]

func _make_player(navigation: ArenaNavigation) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"sp_la"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"sp_la")
	snapshot.skill_ranks = {}
	for skill: StringName in ClassKitRegistry.skill_ids(&"sp_la"): snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	var ids := ClassKitRegistry.skill_ids(&"sp_la")
	snapshot.active_slots = [ids[0], ids[2], ids[3], null, null]
	var actor := PlayerActor.new()
	actor.configure(navigation, RunState.from_build("flank-" + str(checks), snapshot))
	return actor

func _navigation() -> ArenaNavigation:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	return navigation

func _setup(position: Vector2 = Vector2(400, 350)) -> void:
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	ClassKitRegistry.install_fixture(&"sp_la", FlankFixtureKit.new(&"sp_la"))
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = _navigation()
	player = _make_player(controller.navigation)
	controller.add_child(player)
	player.set_process(false)
	player.global_position = position
	player.character_animation.state.face(Vector2.RIGHT)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 17
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	kit = player.kit
	flank = kit.get("flank")

func _face(actor: CombatActor, direction: Vector2) -> void:
	if actor.character_animation == null: actor.set_animation_kind(&"warrior")
	actor.character_animation.state.face(direction)

func _enemy(at: Vector2, facing: Vector2 = Vector2.RIGHT, hp: float = 100000.0) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	controller.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position = at
	_face(enemy, facing)
	enemy.health.max_hp = hp
	enemy.health.current_hp = hp
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(enemy)
	return enemy

func _hostile(at: Vector2, category: StringName = &"normal", hp: float = 100000.0) -> EnemyActor:
	var hostile := EnemyActor.new()
	hostile.configure(&"chaser", controller.navigation, player)
	controller.add_child(hostile)
	hostile.set_process(false)
	hostile.global_position = at
	hostile.occurrence.category_id = category
	hostile.hard_controls.boss = category == &"boss"
	_face(hostile, Vector2.RIGHT)
	hostile.health.max_hp = hp
	hostile.health.current_hp = hp
	hostile.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(hostile)
	return hostile

## A kit request through the shared factory, marked at commit, applied on the target.
func _strike(target: CombatActor, amount: float = 5.0) -> Dictionary:
	var request := player.kit_make_request(target, _slot(3), amount, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	flank.mark_request(player, request, target)
	return target.apply_damage(request, rng)

func _enemy_hit(source: CombatActor, amount: float, skill: StringName = &"enemy_claw") -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = skill
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	return request

func _tick(delta: float) -> void:
	player._process(delta)

func _full_sentence(target: CombatActor) -> void:
	for index: int in 3: flank.gain(player, target, FlankRules.SOURCE_COMBO, "fill_%d_%d" % [target.get_instance_id(), index])

# --- Sides --------------------------------------------------------------------------

func _point_at(degrees: float, height: float = 0.0) -> Vector3:
	var radians := deg_to_rad(degrees)
	return Vector3(cos(radians) * 50.0, height, sin(radians) * 50.0)

func _check_side_matrix() -> void:
	var origin := Vector3.ZERO
	var facing := Vector3(1, 0, 0)
	var expected := {0.0: &"front", 45.0: &"front", 59.9: &"front", 60.0: &"front", 60.1: &"flank", 90.0: &"flank", 119.9: &"flank", 120.0: &"back", 120.1: &"back", 180.0: &"back", -60.0: &"front", -60.1: &"flank", -119.9: &"flank", -120.0: &"back", -150.0: &"back"}
	for degrees: float in expected:
		for height: float in [0.0, 40.0, -25.0]:
			var side: StringName = FlankRules.classify(origin, facing, _point_at(degrees, height))["side"]
			_check(side == expected[degrees], "side matrix %.1f° at height %.0f is %s (got %s)" % [degrees, height, expected[degrees], side])
	_check(FlankRules.classify(Vector3(0, 10, 0), facing, Vector3(-50, -30, 0))["side"] == &"back", "height of the target and the attacker is ignored")
	_check(FlankRules.classify(origin, facing, Vector3(0.0001, 0, 0))["side"] == &"front" and FlankRules.classify(origin, facing, Vector3(0.0001, 0, 0))["overlap"], "an overlapping attacker counts as front")
	_check(FlankRules.classify(origin, Vector3(0, 0, -1), Vector3(0, 0, 50))["side"] == &"back" and FlankRules.classify(origin, Vector3(0, 7, -1), Vector3(0, 0, -50))["side"] == &"front", "the facing is read on the ground plane only")
	_check(not FlankRules.classify(origin, Vector3.ZERO, Vector3(10, 0, 0))["valid"], "a zero facing is invalid and never yields back")

func _check_actor_sides_and_turn() -> void:
	_setup()
	var enemy := _enemy(Vector2(500, 350), Vector2.RIGHT)
	_check(FlankRules.side_between(enemy, player)["side"] == &"back", "player behind an enemy that faces away")
	_face(enemy, Vector2.LEFT)
	_check(FlankRules.side_between(enemy, player)["side"] == &"front", "player in front of an enemy that faces it")
	_face(enemy, Vector2.DOWN)
	_check(FlankRules.side_between(enemy, player)["side"] == &"flank", "player on the flank")
	_face(enemy, Vector2.LEFT)
	_check(flank.turn_away(player, enemy) and enemy.gameplay_facing_override_owner() == FlankRules.TURN_OWNER and is_equal_approx(enemy.gameplay_facing_override_remaining(), FlankRules.TURN_DURATION), "forced turn uses the T1 override for 1.5 s")
	_check(FlankRules.side_between(enemy, player)["side"] == &"back" and enemy.gameplay_facing().is_equal_approx(Vector2.RIGHT), "a turned enemy shows its back to the owner (rule and drawn facing)")
	_check(is_equal_approx(FlankRules.side_between(enemy, player)["cos"], -1.0), "the owner ends exactly behind the turned enemy")
	enemy.advance_statuses(1.0, true)
	_check(is_equal_approx(enemy.gameplay_facing_override_remaining(), 1.5), "pause freezes the turn")
	enemy.advance_statuses(1.0)
	_check(is_equal_approx(enemy.gameplay_facing_override_remaining(), 0.5) and FlankRules.side_between(enemy, player)["side"] == &"back", "the turn runs on the gameplay clock")
	_face(enemy, Vector2.LEFT)
	_check(FlankRules.side_between(enemy, player)["side"] == &"back", "while turned, the enemy's own facing does not win")
	enemy.advance_statuses(0.6)
	_check(enemy.gameplay_facing_override_remaining() == 0.0 and enemy.gameplay_facing_override_owner() == &"", "the turn expires on the gameplay clock")
	_face(enemy, Vector2.LEFT)
	_check(FlankRules.side_between(enemy, player)["side"] == &"front", "after the turn the enemy's own facing rules again")
	_check(flank.turn_away(player, enemy, 9.0) and is_equal_approx(enemy.gameplay_facing_override_remaining(), FlankRules.TURN_RANGE.y), "turn duration is clamped to its range")
	var boss := _hostile(Vector2(300, 350), &"boss")
	_check(flank.turn_away(player, boss) and is_equal_approx(boss.gameplay_facing_override_remaining(), FlankRules.TURN_DURATION * FlankRules.BOSS_DURATION_FACTOR), "bosses turn for 0.6x the duration")
	var sight := flank.break_sight(player, boss)
	_check(sight["ok"] and boss.threat.sight_broken("player") and is_equal_approx(boss.threat.sight_break_remaining("player"), FlankRules.SIGHT_BREAK_DURATION * FlankRules.BOSS_DURATION_FACTOR), "sight break through the seam, 0.6x on bosses")
	var normal := _hostile(Vector2(600, 350))
	var exposed := flank.expose(player, normal)
	_check(exposed["turned"] and exposed["sight"]["ok"] and is_equal_approx(normal.threat.sight_break_remaining("player"), FlankRules.SIGHT_BREAK_DURATION) and FlankRules.side_between(normal, player)["side"] == &"back", "expose turns the enemy and makes it lose sight")
	_check(flank.break_sight(player, enemy)["error_code"] == &"invalid_target", "sight break needs an enemy threat ledger")
	enemy.health.current_hp = 0.0
	enemy._on_health_died(enemy.get_instance_id())
	_check(not flank.turn_away(player, enemy), "a dead enemy is not turned")

# --- Categories -------------------------------------------------------------------------

func _check_categories_and_thresholds() -> void:
	_setup()
	_check(FlankRules.execution_threshold(&"normal") == 0.30 and FlankRules.execution_threshold(&"rare") == 0.24 and FlankRules.execution_threshold(&"elite") == 0.18 and FlankRules.execution_threshold(&"rare_elite") == 0.12, "thresholds per category")
	_check(FlankRules.execution_threshold(&"boss") < 0.0, "the boss has no threshold")
	var previous := 1.0
	for category: StringName in [&"normal", &"rare", &"elite", &"rare_elite"]:
		_check(FlankRules.execution_threshold(category) < previous, "the threshold decreases with the category: " + String(category))
		previous = FlankRules.execution_threshold(category)
	for category: StringName in MobCatalog.CATEGORIES:
		var hostile := _hostile(Vector2(500, 300), category)
		_check(FlankRules.category_of(hostile) == category, "category read from the occurrence: " + String(category))
	var plain := _enemy(Vector2(500, 400))
	_check(FlankRules.category_of(plain) == &"normal", "an actor without occurrence is normal")
	plain.hard_controls.boss = true
	_check(FlankRules.category_of(plain) == &"boss", "an actor without occurrence with the boss control profile is a boss")

# --- Own concealment ---------------------------------------------------------------------

func _check_concealment_rules() -> void:
	_setup()
	var enemy := _enemy(Vector2(470, 350), Vector2.LEFT)
	_check(not player.is_concealed() and flank.enter_concealment(player) and player.is_concealed() and player.kit_concealed() and is_equal_approx(flank.concealment_remaining, FlankRules.CONCEALMENT_DURATION), "entering the own concealment hides the owner for 4 s")
	_check(flank.enter_concealment(player, 2.0) and is_equal_approx(flank.concealment_remaining, FlankRules.CONCEALMENT_DURATION), "renewing keeps the longer deadline")
	_tick(1.0)
	_check(is_equal_approx(flank.hidden_seconds, 1.0) and is_equal_approx(flank.concealment_remaining, 3.0), "hidden time and deadline run on the gameplay clock")
	paused = true
	_tick(1.0)
	_check(is_equal_approx(flank.concealment_remaining, 3.0) and is_equal_approx(flank.hidden_seconds, 1.0), "pause freezes the concealment")
	paused = false
	var opened := _strike(enemy)
	var flags := FlankRules.result_flags(opened)
	_check(not player.is_concealed() and not flank.concealment_armed and player.concealment_reveal_remaining > 0.0, "attacking reveals (seam reveal) and ends the concealment")
	_check(bool(flags.get("from_concealment", false)) and is_equal_approx(float(flags.get("hidden_seconds", 0.0)), 1.0), "the first strike out of concealment is marked on the request")
	var second := FlankRules.result_flags(_strike(enemy))
	_check(not bool(second.get("from_concealment", true)) and flank.openings_total == 1, "only the first strike opens from concealment")
	# Re-entry inside the seam reveal window: armed, effective when the window ends.
	_check(flank.enter_concealment(player) and flank.concealment_armed and not player.kit_concealed(), "entering during the reveal window arms the concealment")
	_tick(PlayerActor.CONCEALMENT_REVEAL_DURATION + 0.05)
	_check(player.kit_concealed() and flank.concealment_remaining < FlankRules.CONCEALMENT_DURATION, "the armed concealment becomes effective when the window ends; its deadline kept running")
	# Attacking with an armed (not yet effective) concealment cancels it without opening.
	_strike(enemy)
	_check(flank.enter_concealment(player) and not player.kit_concealed(), "re-armed during the new reveal window")
	var cancelled := FlankRules.result_flags(_strike(enemy))
	_check(not flank.concealment_armed and not bool(cancelled.get("from_concealment", true)), "an attack inside the reveal window cancels the armed concealment")
	_tick(PlayerActor.CONCEALMENT_REVEAL_DURATION + 0.05)
	_check(not player.kit_concealed(), "a cancelled concealment does not come back")
	# Opening window expires.
	flank.enter_concealment(player)
	player.reveal_from_offense()
	_check(flank.opening_ready(), "a reveal opens the opening window")
	_tick(FlankRules.OPENING_WINDOW + 0.05)
	_check(not flank.opening_ready() and not bool(FlankRules.result_flags(_strike(enemy)).get("from_concealment", true)), "an unused opening expires after 0.25 s")
	# Natural expiry: no opening.
	_tick(PlayerActor.CONCEALMENT_REVEAL_DURATION + 0.05)
	flank.enter_concealment(player, 1.5)
	_tick(1.6)
	_check(not flank.concealment_armed and not player.is_concealed() and not flank.opening_ready(), "an expired concealment ends without an opening strike")
	_check(flank.enter_concealment(player, 0.1) and is_equal_approx(flank.concealment_remaining, FlankRules.CONCEALMENT_RANGE.x), "concealment duration is clamped to its range")
	flank.end_concealment()
	_check(not player.is_concealed(), "end_concealment ends it")

func _check_concealment_against_acquisition() -> void:
	_setup()
	var hostile := _hostile(Vector2(520, 350))
	hostile.threat.observe("flank_seed", &"damage", "player", 10.0)
	hostile._advance_threat(0.1)
	_check(hostile._player_acquirable() and hostile.threat.current_id == "player", "before the concealment the enemy acquires and targets the owner")
	flank.enter_concealment(player)
	_check(not player.can_be_acquired_by(hostile.global_position) and not hostile._player_acquirable(), "the own concealment blocks acquisition, even next to the enemy")
	hostile._advance_threat(0.1)
	_check(hostile.threat.current_id.is_empty() and float(hostile.threat.amounts.get("player", 0.0)) == 10.0, "the threat loses the concealed owner and keeps the amounts")
	_strike(hostile)
	hostile._advance_threat(0.1)
	_check(hostile._player_acquirable() and hostile.threat.current_id == "player", "attacking reveals: the enemy acquires the owner again")
	flank.break_sight(player, hostile)
	hostile._advance_threat(0.1)
	_check(hostile.threat.sight_broken("player") and hostile.threat.current_id.is_empty(), "losing sight removes the owner from the threat choice")

# --- Victim and Sentence --------------------------------------------------------------------

func _check_victim_and_sentence() -> void:
	_setup()
	var victim := _enemy(Vector2(470, 350), Vector2.LEFT)
	var other := _enemy(Vector2(400, 420), Vector2.LEFT)
	_check(flank.mark_victim(player, victim)["ok"] and flank.victim(player) == victim and FlankRules.see_through(victim) and victim.marks.owner_of(FlankRules.VICTIM_MARK) == player.get_instance_id(), "the victim mark is visible through obstacles and owned by the player")
	var front := _strike(victim)
	_check(flank.sentence(player) == 1, "a direct frontal hit gives +1")
	controller._on_enemy_damage_resolved(front)
	kit.on_damage_dealt(player, front)
	_check(flank.sentence(player) == 1, "the same result never gains twice (ledger identity)")
	_face(victim, Vector2.DOWN)
	_strike(victim)
	_check(flank.sentence(player) == 2, "a flank hit is a direct hit (+1)")
	_face(victim, Vector2.RIGHT)
	_strike(victim)
	_check(flank.sentence(player) == 4, "a back hit gives +2")
	_strike(other)
	_check(flank.sentence(player, other) == 0 and flank.sentence(player) == 4, "only the victim accumulates")
	_strike(victim)
	_check(flank.sentence(player) == 5, "the Sentence caps at 5")
	_check(flank.gain(player, victim, FlankRules.SOURCE_COMBO, "cap") == 0 and flank.sentence(player) == 5, "a gain on a full Sentence adds nothing")
	# Marking another victim moves the mark; the old Sentence disappears with it.
	_check(flank.mark_victim(player, other)["changed"] and not victim.marks.has_mark(FlankRules.VICTIM_MARK) and flank.victim(player) == other and flank.sentence(player) == 0, "one victim per owner: marking another removes the previous")
	_check(flank.gain(player, other, FlankRules.SOURCE_COMBO, "parry_1") == 2 and flank.gain(player, other, FlankRules.SOURCE_COMBO, "parry_1") == 0 and flank.sentence(player) == 2, "a kit combo gives +2 once per key")
	_check(flank.gain(player, victim, FlankRules.SOURCE_COMBO, "parry_2") == 0, "a combo on a non-victim gives nothing")
	# Sources do not add up on one hit: back + concealment is still +2.
	_face(other, Vector2.RIGHT)
	other.global_position = Vector2(470, 350)
	flank.enter_concealment(player)
	var ambush := _strike(other)
	var flags := FlankRules.result_flags(ambush)
	_check(flags.get("side") == &"back" and bool(flags.get("from_concealment", false)) and flank.sentence(player) == 4, "a back strike out of concealment gives +2, not +4")
	# The kit decides which sources count.
	kit.set("counted", {&"direct": false, &"back": true, &"concealment": true})
	_face(other, Vector2.LEFT)
	_strike(other)
	_check(flank.sentence(player) == 4, "a kit that does not count direct hits gets nothing from a frontal hit")
	kit.set("counted", {})
	var secondary := player.kit_make_request(other, _slot(3), 5.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	flank.mark_request(player, secondary, other)
	secondary.is_secondary = true
	other.apply_damage(secondary, rng)
	_check(flank.sentence(player) == 4, "secondary ticks (DoT) give no Sentence")
	# Basic attack through the seam from behind: compose marks the request.
	_face(other, Vector2.RIGHT)
	player.target = other
	player.attack_cooldown = 0.0
	player._try_basic_attack()
	player.target = null
	_check(flank.sentence(player) == 5 and kit.get("calls").has("basic"), "the basic attack composed by the kit is marked and counts from behind")
	_check(FlankAuthority.event_key({"target_id": 3, "application_sequence": 0}).is_empty(), "a hit without ledger identity nor sequence has no event key")

# --- Execution ----------------------------------------------------------------------------------

func _check_execution_lethal_and_single_kill() -> void:
	_setup()
	var victim := _hostile(Vector2(470, 350), &"normal", 100000.0)
	victim.health.physical_defense = 800.0
	flank.mark_victim(player, victim)
	_full_sentence(victim)
	_check(flank.sentence(player) == 5, "the victim holds a full Sentence")
	victim.health.current_hp = 29000.0
	var requests: Array[DamageRequest] = []
	player.attack_requested.connect(func(request: DamageRequest, _target: CombatActor) -> void: requests.append(request))
	var results: Array[Dictionary] = []
	victim.health.damage_applied.connect(func(result: Dictionary) -> void: results.append(result))
	player.current_sp = player.max_sp
	_check(player.use_kit_skill(_slot(2), victim.global_position, victim), "the execution casts through the seam")
	var execution: Dictionary = kit.get("last_execution")
	_check(execution.get("ok", false) and execution.get("lethal", false) and int(execution.get("charges", 0)) == 5 and execution.get("category") == &"normal", "full Sentence under the normal threshold (30%) is certain death")
	_check(requests.size() == 1 and requests[0].context != null and requests[0].accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and not requests[0].can_crit, "certain death is a DamageRequest with a causal context, geometric accuracy and no crit")
	var flags := FlankRules.flags_of(requests[0].effect_snapshot)
	_check(bool(flags.get("execution", false)) and bool(flags.get("lethal", false)) and int(flags.get("charges", 0)) == 5, "the request is marked as an execution")
	_check(not victim.is_alive() and results.size() == 1 and bool(results[0].get("killed", false)) and float(results[0].get("actual_damage", 0.0)) == 29000.0, "the target dies through HealthState (no direct HP write), despite 800 DEF")
	_check(int(kit.get("kill_callbacks")) == 1 and int(kit.get("execution_callbacks")) == 1 and flank.execution_kills == 1, "the kill calls the kit once as an execution kill")
	_check(flank.concealment_armed, "the execution kill returned the concealment (fixture kit)")
	controller._on_enemy_damage_resolved(results[0])
	kit.on_kill_confirmed(player, results[0])
	_check(int(kit.get("kill_callbacks")) == 1 and int(kit.get("execution_callbacks")) == 1 and kit.get("calls").count("kill") == 2, "a retry never calls the kill callback again")
	_check(flank.victim(player) == null and flank.sentence(player) == 0, "the victim disappears with its death")
	_check(flank.executions_total == 1 and flank.lethal_total == 1 and flank.spend_amount == 5, "the execution spent the five charges once")
	# A kill that is not an execution is reported once, without the execution flag.
	var plain := _enemy(Vector2(470, 420), Vector2.LEFT, 10.0)
	_strike(plain, 1000.0)
	_check(not plain.is_alive() and int(kit.get("kill_callbacks")) == 2 and int(kit.get("execution_callbacks")) == 1, "an ordinary kill calls the kit once, not as an execution")

func _execute_on(target: CombatActor, hp_fraction: float, charges: int) -> Dictionary:
	flank.mark_victim(player, target)
	var mark := FlankRules.victim_mark(target).duplicate()
	mark["sentence"] = charges
	target.marks.update_value(FlankRules.VICTIM_MARK, mark)
	target.health.current_hp = target.health.max_hp * hp_fraction
	player.kit_time += 0.1
	return flank.execute(player, target, _slot(2), 100.0, 0.0)

func _check_execution_refusals() -> void:
	_setup()
	for row: Array in [[&"normal", 0.31, 0.29], [&"rare", 0.25, 0.23], [&"elite", 0.19, 0.17], [&"rare_elite", 0.13, 0.11]]:
		var above := _hostile(Vector2(470, 300), row[0])
		var refused := _execute_on(above, row[1], 5)
		_check(refused["ok"] and not refused["lethal"] and above.is_alive(), "%s above its threshold: no certain death" % row[0])
		_check(is_equal_approx(refused["request"].physical_damage, 100.0 * 3.0) and refused["charges"] == 5 and flank.sentence(player, above) == 0, "%s: damage scales 3.0x with five charges and spends them" % row[0])
		var below := _hostile(Vector2(470, 400), row[0])
		var killed := _execute_on(below, row[2], 5)
		_check(killed["ok"] and killed["lethal"] and not below.is_alive(), "%s under its threshold: certain death" % row[0])
	var partial := _hostile(Vector2(470, 300))
	var four := _execute_on(partial, 0.05, 4)
	_check(four["ok"] and not four["lethal"] and partial.is_alive() and is_equal_approx(four["multiplier"], 1.0 + 0.4 * 4.0), "four charges are never certain death")
	var boss := _hostile(Vector2(470, 300), &"boss")
	var on_boss := _execute_on(boss, 0.01, 5)
	_check(on_boss["ok"] and not on_boss["lethal"] and boss.is_alive() and on_boss["category"] == &"boss" and is_equal_approx(on_boss["request"].physical_damage, 300.0), "no certain death on a boss: only the scaled damage")
	_check(not bool(FlankRules.flags_of(on_boss["request"].effect_snapshot).get("lethal", true)) and flank.lethal_total == 4, "only the four under-threshold executions were lethal")
	var not_victim := _hostile(Vector2(470, 400))
	player.kit_time += 0.1
	var bare := flank.execute(player, not_victim, _slot(2), 100.0, 0.0)
	_check(bare["ok"] and bare["charges"] == 0 and is_equal_approx(bare["request"].physical_damage, 100.0), "an execution on a non-victim spends nothing and scales by 1.0")
	_check(flank.execute(player, not_victim, _slot(2), 100.0, 0.0)["error_code"] == &"already_executed", "one execution per commit (no double spend)")
	player.kit_time += 0.1
	_check(flank.execute(player, not_victim, _slot(2), -1.0, 0.0)["error_code"] == &"invalid_payload" and flank.execute(player, player, _slot(2), 1.0, 0.0)["error_code"] == &"invalid_target", "invalid executions are refused")

# --- Parry --------------------------------------------------------------------------------

func _check_parry_window() -> void:
	_setup()
	var attacker := _hostile(Vector2(460, 350))
	var hp := player.health.current_hp
	_check(flank.open_parry(player) and flank.parry_open() and is_equal_approx(flank.parry_remaining, FlankRules.PARRY_WINDOW), "the parry window opens for 0.35 s")
	var parried := player.apply_damage(_enemy_hit(attacker, 50.0), rng)
	_check(bool(parried.get("cancelled", false)) and player.health.current_hp == hp and kit.get("last_parry")["parried"], "a frontal melee hit inside the window is parried")
	_check(FlankRules.side_between(attacker, player)["side"] == &"back" and attacker.threat.sight_broken("player"), "the parried attacker is turned and loses sight")
	_check(not flank.parry_open(), "one parry spends the window")
	player.apply_damage(_enemy_hit(attacker, 5.0), rng)
	_check(player.health.current_hp < hp and kit.get("last_parry")["reason"] == &"no_window", "without a window the hit lands")
	flank.open_parry(player)
	var arrow := player.apply_damage(_enemy_hit(attacker, 5.0, &"enemy_arrow"), rng)
	_check(not bool(arrow.get("cancelled", false)) and kit.get("last_parry")["reason"] == &"not_melee", "projectiles are never parried")
	var behind := _hostile(Vector2(340, 350))
	player.apply_damage(_enemy_hit(behind, 5.0), rng)
	_check(kit.get("last_parry")["reason"] == &"not_front", "a melee hit from behind is not parried")
	var side := _hostile(Vector2(400, 420))
	player.apply_damage(_enemy_hit(side, 5.0), rng)
	_check(kit.get("last_parry")["reason"] == &"not_front", "a melee hit from the flank is not parried")
	_tick(FlankRules.PARRY_WINDOW + 0.05)
	_check(not flank.parry_open(), "the window closes on the gameplay clock")
	_check(flank.open_parry_mode(player, 3.0), "unlimited parries for a span (Duelo)")
	var first := _hostile(Vector2(460, 340))
	var second := _hostile(Vector2(460, 360))
	player.apply_damage(_enemy_hit(first, 5.0), rng)
	var again := player.apply_damage(_enemy_hit(second, 5.0), rng)
	_check(bool(again.get("cancelled", false)) and flank.parry_open() and flank.parried_total == 3, "every frontal melee hit is parried during the mode")
	_check(not flank.open_parry(player, 0.3, 0), "a window needs at least one charge")
	_check(flank.open_parry(player, 5.0) and is_equal_approx(flank.parry_remaining, FlankRules.PARRY_RANGE.y), "the window is clamped to its range")

# --- Behind the victim (flat arena) ----------------------------------------------------------

func _check_back_point_flat() -> void:
	_setup(Vector2(200, 350))
	var victim := _enemy(Vector2(500, 350), Vector2.LEFT)
	var point := flank.back_point(player, victim)
	var reach := victim.collision_radius + player.collision_radius + FlankRules.BACK_GAP
	_check(point["ok"] and point["position"].is_equal_approx(Vector2(500 + reach, 350)) and point["angle"] == 0.0, "back point opposite the victim facing")
	_check(FlankRules.side_of(victim, point["ground"])["side"] == &"back", "the back point classifies as back")
	_check(flank.teleport_behind(player, victim, 100.0)["error_code"] == &"out_of_range", "teleport behind respects the maximum range")
	var moved := flank.teleport_behind(player, victim, 600.0)
	_check(moved["ok"] and moved["side"] == &"back" and player.global_position.is_equal_approx(point["position"]) and FlankRules.side_between(player, victim)["side"] == &"front", "teleport behind: owner behind the victim and facing it")
	var request := player.kit_make_request(victim, _slot(3), 5.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_check(FlankRules.flags_of(flank.mark_request(player, request, victim).effect_snapshot).get("side") == &"back", "the strike after the teleport counts as a back strike")
	var wall := ArenaNavigation.new()
	wall.configure(Rect2(0, 0, 1000, 700), [Rect2(520, 300, 60, 100)], 20.0)
	player.navigation = wall
	_check(flank.back_point(player, victim)["error_code"] == &"back_point_blocked", "a blocked back point is refused (0°, +30° and -30°)")
	player.navigation = controller.navigation

# --- Death and pause -------------------------------------------------------------------------

func _check_death_and_pause() -> void:
	_setup()
	var victim := _enemy(Vector2(470, 350), Vector2.RIGHT)
	flank.mark_victim(player, victim)
	flank.gain(player, victim, FlankRules.SOURCE_COMBO, "pause")
	flank.enter_concealment(player)
	flank.open_parry(player)
	var concealment := flank.concealment_remaining
	var parry := flank.parry_remaining
	var clock := player.kit_time
	paused = true
	_tick(1.0)
	_check(flank.concealment_remaining == concealment and flank.parry_remaining == parry and player.kit_time == clock, "pause freezes every flank clock")
	paused = false
	flank.close_parry()
	var killer := _enemy(Vector2(460, 350), Vector2.LEFT)
	player.apply_damage(_enemy_hit(killer, 1.0e7), rng)
	_check(not player.is_alive() and not flank.concealment_armed and not flank.parry_open() and not victim.marks.has_mark(FlankRules.VICTIM_MARK) and flank.victim(player) == null, "the owner's death ends concealment, parry and the victim")

# --- Snapshot ---------------------------------------------------------------------------------

func _find_enemy(owner: Node) -> CombatActor:
	for child: Node in owner.get_children():
		if child is CombatActor and not child is PlayerActor: return child
	return null

func _check_snapshot_formats() -> void:
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	ClassKitRegistry.install_fixture(&"sp_la", FlankFixtureKit.new(&"sp_la"))
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty() and registry.schemas.has("res://scripts/systems/flank/flank_authority.gd") and registry.schemas.has("res://scripts/systems/flank/fixture/flank_fixture_kit.gd"), "the flank fragments merge without errors")
	_check("res://scripts/systems/flank/snapshot_manifest.json" in SnapshotRegistry.fragment_paths(), "the system fragment is discovered by folder")
	var standalone := _make_player(_navigation())
	standalone.global_position = Vector2(400, 350)
	owned.append(standalone)
	var authority: FlankAuthority = standalone.kit.get("flank")
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = Vector2(480, 350)
	enemy.health.max_hp = 1000.0
	enemy.health.current_hp = 1000.0
	standalone.add_child(enemy)
	_check(authority.mark_victim(standalone, enemy)["ok"], "victim marked before the save")
	authority.gain(standalone, enemy, FlankRules.SOURCE_COMBO, "before_save")
	authority.gain(standalone, enemy, FlankRules.SOURCE_DIRECT, "before_save_direct")
	authority.turn_away(standalone, enemy)
	authority.enter_concealment(standalone)
	authority.concealment_remaining = 2.5
	authority.hidden_seconds = 1.5
	authority.open_parry(standalone, 0.4, 1)
	standalone.kit_time = 7.25
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(standalone)["ok"], "barrier acquired")
	var captured := SnapshotRegistry.new().capture(standalone, barrier)
	_check(captured.get("ok", false), "exact capture with victim, Sentence and concealment: " + str(captured.get("detail", captured.get("error_code", ""))))
	if captured.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(captured["snapshot"])))
		_check(restored.get("ok", false), "exact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied: FlankAuthority = copy.kit.get("flank")
			var copied_enemy := _find_enemy(copy)
			_check(copied != null and copied._victim_hint == 0 and copied_enemy != null and copied.victim(copy) == copied_enemy and copied.sentence(copy) == 3, "exact format preserves the victim and its Sentence (rebuilt from the mark)")
			_check(copied_enemy != null and copied_enemy.marks.owner_of(FlankRules.VICTIM_MARK) == copy.get_instance_id() and FlankRules.see_through(copied_enemy), "the victim mark rebinds its owner to the restored player")
			_check(copied != null and copied.concealment_armed and copied.concealment_remaining == 2.5 and copied.hidden_seconds == 1.5 and copy.kit_concealed(), "exact format preserves the own concealment")
			_check(copied != null and copied.parry_open() and copied.parry_remaining == 0.4 and copied.has_claimed("combo@before_save") and copied.gain(copy, copied_enemy, FlankRules.SOURCE_COMBO, "before_save") == 0, "exact format preserves the parry window and the event memory")
			_check(copied_enemy != null and copied_enemy.gameplay_facing_override_owner() == FlankRules.TURN_OWNER and is_equal_approx(copied_enemy.gameplay_facing_override_remaining(), FlankRules.TURN_DURATION), "exact format keeps the turn with the enemy")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	_check(standalone.kit_compact_blocker().is_empty(), "the flank system never blocks the compact cut")
	var projection := {"fields": {}, "excluded": {enemy.get_instance_id(): true}}
	var compact := SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("ok", false), "the compact cut with a living victim is eligible (no entity reference): " + str(compact.get("detail", compact.get("error_code", ""))))
	if compact.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(compact["snapshot"])))
		_check(restored.get("ok", false), "compact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied: FlankAuthority = copy.kit.get("flank")
			_check(copied != null and copied.concealment_armed and copied.concealment_remaining == 2.5 and copied.parry_remaining == 0.4 and copied.victim_serial == authority.victim_serial, "compact format preserves the owner state")
			_check(copied != null and _find_enemy(copy) == null and copied.victim(copy) == null and copied.sentence(copy) == 0, "compact format: the enemy returns to its origin without marks, so victim and Sentence are gone")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	barrier.release()

# --- World geometry ------------------------------------------------------------------------------

func _world_actor(world: WorldGeometry, profile: Dictionary, point: ExpeditionWorldPoint, facing: Vector3) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}))
	controller.add_child(actor)
	actor.set_process(false)
	actor.health.max_hp = 100000.0
	actor.health.current_hp = 100000.0
	_check(actor.bind_world_geometry(world, point, profile, str(actor.get_instance_id()))["ok"], "world actor bound")
	actor.set_process(false)
	actor.override_gameplay_ground_facing(facing, 60.0, &"test")
	controller.enemies.append(actor)
	return actor

func _check_world_geometry() -> void:
	_setup()
	var input := WorldFixture.make()
	var built := ExpeditionAssembler.build(input)
	var world := WorldGeometry.new()
	_check(built["ok"] and world.configure(built["data"]["manifest"], "sample")["ok"], "F1 fixture geometry configured")
	if not built["ok"]: return
	var profile: Dictionary = input.traversal.to_data()
	_check(player.bind_world_geometry(world, WorldFixture.point("root", Vector3(20, 0, 150)), profile, str(player.get_instance_id()))["ok"], "kit player bound to the world")
	player.set_process(false)
	var victim := _world_actor(world, profile, WorldFixture.point("root", Vector3(60, 0, 150)), Vector3(1, 0, 0))
	var upper := _world_actor(world, profile, WorldFixture.point("bridge", Vector3(60, 40, 150)), Vector3(1, 0, 0))
	_check(FlankRules.side_between(victim, player)["side"] == &"back" and FlankRules.side_between(upper, player)["side"] == &"back", "world sides use the ground plane; the slab above does not change the side")
	upper.override_gameplay_ground_facing(Vector3(-1, 0, 0), 60.0, &"test")
	_check(FlankRules.side_between(upper, player)["side"] == &"front", "world sides follow the gameplay ground facing")
	# Own concealment against the world acquisition.
	_check(player.can_be_acquired_by_world(victim), "visible owner is acquired in the world")
	flank.enter_concealment(player)
	_check(not player.can_be_acquired_by_world(victim), "the own concealment blocks the world acquisition")
	flank.end_concealment()
	var hostile := EnemyActor.new()
	hostile.configure(&"chaser", controller.navigation, player)
	controller.add_child(hostile)
	hostile.set_process(false)
	_check(hostile.bind_world_geometry(world, WorldFixture.point("root", Vector3(40, 0, 120)), profile, str(hostile.get_instance_id()))["ok"], "world enemy bound")
	hostile.set_process(false)
	_check(player.can_be_acquired_by_world(hostile) and flank.break_sight(player, hostile)["ok"] and not player.can_be_acquired_by_world(hostile), "losing sight also blocks the world acquisition")
	# Behind the victim, validated by the world geometry.
	var point := flank.back_point(player, victim)
	var bodies := float(profile["radius"]) * 2.0
	_check(point["ok"] and point["world_point"] is ExpeditionWorldPoint and is_equal_approx(point["ground"].x, 60.0 - bodies - FlankRules.BACK_GAP) and is_equal_approx(point["ground"].z, 150.0), "world back point traced on the ground behind the victim")
	var moved := flank.teleport_behind(player, victim, 200.0)
	_check(moved["ok"] and moved["side"] == &"back" and player.world_point().position.distance_to(point["ground"]) < 0.01, "teleport behind through WorldActorMotion.teleport")
	var edge := _world_actor(world, profile, WorldFixture.point("root", Vector3(3, 0, 150)), Vector3(1, 0, 0))
	_check(flank.back_point(player, edge)["error_code"] == &"back_point_blocked", "no ground behind the victim: the back point is refused")
	var far := _world_actor(world, profile, WorldFixture.point("root", Vector3(80, 0, 60)), Vector3(0, 0, 1))
	_check(not flank.teleport_behind(player, far, 1.0)["ok"] and player.world_point().position.distance_to(point["ground"]) < 0.01, "teleport behind respects the legal range and leaves the owner in place")

# --- Seam only ---------------------------------------------------------------------------------

func _check_sources_stay_seam_only() -> void:
	var typed_enemy := RegEx.create_from_string("(as|:|->)\\s*EnemyActor\\b|EnemyActor\\.")
	var hp_write := RegEx.create_from_string("current_hp\\s*[-+*/]?=[^=]|_hp_deficit")
	for path: String in ["res://scripts/systems/flank/flank_rules.gd", "res://scripts/systems/flank/flank_authority.gd"]:
		var source := FileAccess.get_file_as_string(path)
		_check(not source.is_empty() and typed_enemy.search(source) == null, "%s never names EnemyActor as a type" % path)
		_check(hp_write.search(source) == null, "%s never writes HP directly" % path)
	var player_source := FileAccess.get_file_as_string("res://scripts/actors/player_actor.gd")
	_check(typed_enemy.search(player_source) == null, "player_actor.gd still does not name EnemyActor (A10)")
