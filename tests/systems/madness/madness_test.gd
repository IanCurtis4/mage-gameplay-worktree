extends SceneTree
## E10a T4 (C2) — Madness family authority: Loucura, Delírio, Desorientação, Êxtase, Ídolo
## and contágio. Invariants of C2 §3 and the numbers of docs/epics/e10a/t4_contract.md.
## A fixture kit outside the production registry (scripts/systems/madness/fixture/) is
## installed over sp_ac and forwards the T1 seam hooks to a MadnessAuthority. The enemies
## are real catalog mobs of the forest phase (wolf, boar, Ancient Warden boss) on the flat
## arena and in the expedition world. Fixture profiles only.
const MadnessFixtureKit = preload("res://scripts/systems/madness/fixture/madness_fixture_kit.gd")
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
var authority: MadnessAuthority
var navigation: ArenaNavigation
var attacks: Array[Array] = []
var mob_serial := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	_check_script_cycles()
	_check_rules()
	_check_madness_add_and_dedupe()
	_check_decay_and_pause()
	_check_delirium()
	_check_delirium_cap()
	_check_delirium_without_target()
	_check_combat_hold()
	_check_delirium_kill_credit()
	_check_boss_disorientation()
	_check_ecstasy()
	_check_idol()
	_check_contagion()
	_check_describe_and_tick_dedupe()
	_check_snapshot_formats()
	_check_world_path()
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	KitDecoy.unregister_drawer(MadnessRules.IDOL_DRAWER)
	print("E10a T4 madness: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixture ---------------------------------------------------------------------------

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	attacks.clear()
	paused = false

func _make_player(nav: ArenaNavigation) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"sp_ac"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"sp_ac")
	snapshot.skill_ranks = {}
	for skill: StringName in ClassKitRegistry.skill_ids(&"sp_ac"): snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	var ids := ClassKitRegistry.skill_ids(&"sp_ac")
	snapshot.active_slots = [ids[0], ids[2], ids[3], null, null]
	var actor := PlayerActor.new()
	actor.configure(nav, RunState.from_build("madness-" + str(checks), snapshot))
	return actor

func _setup(position: Vector2 = Vector2(100, 600)) -> void:
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	ClassKitRegistry.install_fixture(&"sp_ac", MadnessFixtureKit.new(&"sp_ac"))
	navigation = ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	player = _make_player(navigation)
	controller.add_child(player)
	player.set_process(false)
	player.global_position = position
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 17
	controller.enemies = []
	kit = player.kit
	authority = kit.get("madness")

## A real catalog mob of the forest phase (C2 fixture rule: real mobs on both paths).
func _mob(mob_id: StringName, at: Vector2, category: StringName = &"normal") -> EnemyActor:
	mob_serial += 1
	var hostile := EnemyActor.new()
	hostile.global_position = at
	var spawn := MobOccurrence.new()
	spawn.occurrence_id = "t4_%s_%03d" % [mob_id, mob_serial]
	spawn.mob_base_id = mob_id
	spawn.category_id = category
	spawn.origin_id = &"trial_stage_1"
	var configured := hostile.configure_occurrence(spawn, BuildContentLoader.pilot().mob_catalog(), navigation, player)
	_check(configured.get("ok", false), "real mob %s configured: %s" % [mob_id, configured])
	controller.add_child(hostile)
	hostile.set_process(false)
	hostile.attack_requested.connect(func(request: DamageRequest, target: CombatActor, ranged: bool) -> void: attacks.append([request, target, ranged, hostile]))
	hostile.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(hostile)
	return hostile

func _boss(at: Vector2) -> EnemyActor:
	return _mob(&"forest_ancient_warden", at, &"boss")

## Gameplay clock of the fixture: enemy statuses and override clocks, then the owner's
## kit tick (as PlayerActor._process does, outside pause).
func _advance(delta: float, enemies: Array = []) -> void:
	for candidate: Variant in (enemies if not enemies.is_empty() else controller.enemies):
		var hostile := candidate as EnemyActor
		if is_instance_valid(hostile) and hostile.is_alive():
			hostile.advance_statuses(delta)
			hostile._advance_target_override(delta)
	player.kit_time += delta
	authority.tick(player, delta)

func _kill(hostile: EnemyActor) -> void:
	hostile.health.current_hp = 0.0
	hostile._on_health_died(hostile.get_instance_id())
	controller.enemies.erase(hostile)

func _enemy_request(source: CombatActor, amount: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.context = player.run_state.effect_ledger.new_root(source.get_instance_id(), false, "", false, {})
	return request

func _taken(source: CombatActor, amount: float) -> Dictionary:
	player.health.current_hp = player.health.max_hp
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return player.apply_damage(_enemy_request(source, amount), rng)

# --- A7: script cycles -----------------------------------------------------------------

func _check_script_cycles() -> void:
	for row: Array in [["res://scripts/systems/madness/madness_authority.gd", "MadnessAuthority"], ["res://scripts/systems/madness/madness_helpers.gd", "MadnessHelpers"], ["res://scripts/systems/madness/madness_rules.gd", "MadnessRules"], ["res://scripts/systems/madness/madness_ecstasy.gd", "MadnessEcstasy"]]:
		var count := 0
		var regex := RegEx.create_from_string("(^|[^A-Za-z0-9_])%s([^A-Za-z0-9_]|$)" % row[1])
		for line: String in FileAccess.get_file_as_string(row[0]).split(char(10)):
			var code := line.strip_edges()
			if code.begins_with("#") or code.begins_with("class_name"): continue
			if regex.search(code.split("#")[0]) != null: count += 1
		_check(count == 0, "%s never names its own class (%d references)" % [row[0], count])
	var named := 0
	for line: String in FileAccess.get_file_as_string("res://scripts/systems/madness/madness_helpers.gd").split(char(10)):
		var code := line.strip_edges()
		if not code.begins_with("#") and code.split("#")[0].contains("MadnessAuthority"): named += 1
	_check(named == 0, "the helpers never name the authority (no cycle between the two)")

# --- Rules as data ---------------------------------------------------------------------

func _check_rules() -> void:
	_check(MadnessRules.DELIRIUM_CAP == 3 and MadnessRules.ECSTASY_CAP == 5 and MadnessRules.ECSTASY_ONUS_FROM == 3, "D4 limits are constants (Delirium 3, Ecstasy 0..5, onus from 3)")
	_check(MadnessRules.validate("idol", {})["ok"] and MadnessRules.validate("idol", {"duration": 10.0})["options"]["duration"] == 10.0, "defaults merge with valid overrides")
	_check(MadnessRules.validate("idol", {"duration": 99.0})["error_code"] == &"invalid_options" and MadnessRules.validate("idol", {"count": 2})["error_code"] == &"invalid_options", "out-of-range values and unknown keys refuse (no second Idol by option)")
	_check(MadnessRules.validate("disorient", {"bypass_immunity": 1})["error_code"] == &"invalid_options" and MadnessRules.validate("contagion", {"fraction": 0.05})["error_code"] == &"invalid_options", "booleans and fractions are validated")
	var fresh := MadnessAuthority.new()
	_check(fresh.configure(null, {"cap": 5})["error_code"] == &"invalid_options" and fresh.configure(null, {"delirium_duration": 30.0})["error_code"] == &"invalid_options", "the authority refuses unknown or out-of-range options (the cap is not one)")

# --- Madness: add, dedupe, refusals -----------------------------------------------------

func _check_madness_add_and_dedupe() -> void:
	_setup()
	var wolf := _mob(&"forest_wolf", Vector2(500, 300))
	_check(authority != null and MadnessAuthority.of(player) == authority, "the fixture module holds the authority; of(player) finds it")
	var first := authority.add(wolf, 30.0, "cast:test@1", player)
	_check(first["ok"] and is_equal_approx(MadnessAuthority.madness_of(wolf), 30.0) and wolf.marks.owner_of(MadnessRules.MARK_MADNESS) == player.get_instance_id(), "Madness is a mark on the enemy with the player as owner")
	_check(authority.add(wolf, 30.0, "cast:test@1", player)["error_code"] == &"duplicate_event" and is_equal_approx(MadnessAuthority.madness_of(wolf), 30.0), "the same event never gives Madness twice")
	var context := player.run_state.effect_ledger.new_root(player.get_instance_id(), false, "", false, {})
	_check(authority.add(wolf, 10.0, {"context": context}, player)["ok"] and authority.add(wolf, 10.0, {"context": context, "key": "other"}, player)["error_code"] == &"duplicate_event", "a ledger context is the event identity (a retry of the same result is refused)")
	_check(authority.add(wolf, 10.0, context, player)["error_code"] == &"duplicate_event", "the context alone has the same identity")
	var boar := _mob(&"forest_boar", Vector2(520, 340))
	_check(authority.add(boar, 10.0, {"context": context}, player)["ok"], "the same event on another enemy counts once for that enemy (area skills)")
	_check(is_equal_approx(MadnessAuthority.madness_of(wolf), 40.0), "Madness accumulates per event")
	var relay := {"effect_snapshot": {EnemyActor.RELAY_KEY: {"actor_id": 1, "owner_id": 2}}, "context": context}
	_check(MadnessHelpers.result_event(relay).is_empty() and authority.add(wolf, 10.0, MadnessHelpers.result_event(relay), player)["error_code"] == &"missing_event", "a hit between enemies is never a Madness event")
	_check(authority.add(wolf, 0.0, "a", player)["error_code"] == &"invalid_amount" and authority.add(wolf, 101.0, "b", player)["error_code"] == &"invalid_amount" and authority.add(wolf, INF, "c", player)["error_code"] == &"invalid_amount", "amounts are finite, positive and at most the threshold")
	_check(authority.add(wolf, 5.0, "", player)["error_code"] == &"missing_event", "an event without identity is refused")
	var dummy := CombatActor.new()
	dummy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	controller.add_child(dummy)
	dummy.set_process(false)
	_check(authority.add(dummy, 5.0, "d", player)["error_code"] == &"invalid_target", "only enemies carry Madness")
	var idol: CombatActor = KitDecoy.spawn(controller, player, Vector2(600, 300), 10.0, 5.0, &"x")["decoy"]
	_check(authority.add(idol, 5.0, "e", player)["error_code"] == &"invalid_target", "a decoy never carries Madness")
	idol.call(&"remove")
	dummy.free()
	_check(authority.has_claimed("madness@cast:test@1:" + MadnessHelpers.enemy_key(wolf)), "accepted keys join the event ring with the stable enemy key")

func _check_decay_and_pause() -> void:
	_setup()
	var wolf := _mob(&"forest_wolf", Vector2(500, 300))
	authority.add(wolf, 50.0, "cast:decay@1", player)
	_advance(3.9)
	_check(is_equal_approx(MadnessAuthority.madness_of(wolf), 50.0), "no decay during the hold (4 s)")
	_advance(0.2)
	_advance(1.0)
	_check(absf(MadnessAuthority.madness_of(wolf) - 26.0) <= 0.01, "then -20 per second once the hold ends (%s)" % MadnessAuthority.madness_of(wolf))
	_advance(1.6)
	_check(not wolf.marks.has_mark(MadnessRules.MARK_MADNESS), "the mark leaves at 0")
	# Pause: no system clock advances (C2 invariant).
	_mob(&"forest_boar", Vector2(560, 300))
	authority.add(wolf, 100.0, "cast:pause@1", player)
	var boss := _boss(Vector2(800, 200))
	authority.add(boss, 100.0, "cast:pause@2", player)
	authority.place_idol(player, Vector2(500, 330))
	var idol := authority.idol(player)
	var before := {"delirium": wolf.marks.remaining(MadnessRules.MARK_DELIRIUM), "override": wolf.target_override_remaining(), "disoriented": boss.marks.remaining(MadnessRules.MARK_DISORIENTED), "immune": boss.marks.remaining(MadnessRules.MARK_IMMUNE), "ecstasy": authority.ecstasy.charges, "idle": authority.ecstasy.idle_time, "idol": float(idol.get(&"remaining")), "idol_tick": authority.idol_tick_remaining, "kit_ticks": float(kit.get("ticks"))}
	paused = true
	for step: int in 5:
		wolf._process(1.0)
		boss._process(1.0)
		idol._process(1.0)
		player._process(1.0)
	var after := {"delirium": wolf.marks.remaining(MadnessRules.MARK_DELIRIUM), "override": wolf.target_override_remaining(), "disoriented": boss.marks.remaining(MadnessRules.MARK_DISORIENTED), "immune": boss.marks.remaining(MadnessRules.MARK_IMMUNE), "ecstasy": authority.ecstasy.charges, "idle": authority.ecstasy.idle_time, "idol": float(idol.get(&"remaining")), "idol_tick": authority.idol_tick_remaining, "kit_ticks": float(kit.get("ticks"))}
	paused = false
	_check(before == after, "pause freezes Madness, Delirium, Disorientation, immunity, Ecstasy and the Idol: %s vs %s" % [before, after])
	_check(before["delirium"] > 0.0 and before["disoriented"] > 0.0 and before["ecstasy"] == 2 and before["idol"] > 0.0, "the frozen states were active")

# --- Delirium --------------------------------------------------------------------------

func _check_delirium() -> void:
	_setup()
	var boss := _boss(Vector2(470, 300))
	var a := _mob(&"forest_wolf", Vector2(440, 300))
	var b := _mob(&"forest_boar", Vector2(560, 300))
	var c := _mob(&"forest_wolf", Vector2(700, 300))
	var entered := authority.add(a, 100.0, "cast:delirium@1", player)
	_check(entered["entered"] == MadnessRules.STATE_DELIRIUM and MadnessAuthority.state_of(a) == MadnessRules.STATE_DELIRIUM and MadnessAuthority.madness_of(a) == 0.0, "at the threshold a common enemy enters Delirium and its Madness returns to 0")
	_check(a.combat_target() == b and a.target_override_reason() == MadnessRules.DELIRIUM_REASON and a.target_override_owner_id() == player.get_instance_id(), "it targets the nearest non-boss enemy (the closer boss is skipped)")
	_check(is_equal_approx(a.target_override_remaining(), MadnessRules.DELIRIUM_DURATION) and is_equal_approx(a.marks.remaining(MadnessRules.MARK_DELIRIUM), MadnessRules.DELIRIUM_DURATION), "for the Delirium duration (5 s)")
	_check(authority.add(a, 10.0, "cast:delirium@2", player)["error_code"] == &"already_maddened", "a delirious enemy gains no Madness")
	_check(authority.ecstasy.charges == 1, "the entry gives one Ecstasy charge")
	a.global_position = b.global_position + Vector2(-40, 0)
	a.attack_cooldown = 0.0
	attacks.clear()
	a._process(0.05)
	_check(attacks.size() == 1 and attacks[0][1] == b and (attacks[0][0] as DamageRequest).source_id == player.get_instance_id() and EnemyActor.attacker_id(attacks[0][0]) == a.get_instance_id(), "the delirious enemy attacks the other enemy with its own attack, authored by the player")
	_kill(b)
	a._advance_target_override(0.05)
	_advance(0.05)
	_check(a.combat_target() == c and a.target_override_reason() == MadnessRules.DELIRIUM_REASON, "when its target dies it picks another one")
	_check(a.combat_target() != boss and a.combat_target() != player, "never the boss, never the player")
	_advance(5.0)
	_check(MadnessAuthority.state_of(a) == MadnessRules.STATE_NONE and not a.has_target_override() and a.combat_target() == player, "the Delirium ends on the gameplay clock and the player is the target again")
	_check(boss.set_target_override(a, player.get_instance_id(), 3.0, MadnessRules.DELIRIUM_REASON)["error_code"] == &"boss_refuses_target", "the boss refuses any redirect")

func _check_delirium_cap() -> void:
	_setup()
	var mobs: Array[EnemyActor] = []
	for index: int in 6: mobs.append(_mob(&"forest_wolf" if index % 2 == 0 else &"forest_boar", Vector2(300 + index * 60, 300)))
	for index: int in 3: authority.add(mobs[index], 100.0, "cast:cap@%d" % index, player)
	_check(authority.delirium_count(player) == 3, "three delirious enemies")
	var fourth := authority.add(mobs[3], 100.0, "cast:cap@3", player)
	_check(fourth["entered"] == MadnessRules.STATE_PENDING and MadnessAuthority.state_of(mobs[3]) == MadnessRules.STATE_PENDING and is_equal_approx(MadnessAuthority.madness_of(mobs[3]), MadnessRules.THRESHOLD), "with the cap full the Madness stays at the threshold (D4)")
	authority.add(mobs[4], 100.0, "cast:cap@4", player)
	_advance(4.5)
	_check(authority.delirium_count(player) == 3 and MadnessAuthority.state_of(mobs[3]) == MadnessRules.STATE_PENDING and MadnessAuthority.state_of(mobs[4]) == MadnessRules.STATE_PENDING, "never more than three; the waiting Madness does not decay")
	_check(authority.ecstasy.charges == 3, "only entries give Ecstasy (pending gives none)")
	_advance(0.6)
	_check(authority.delirium_count(player) <= MadnessRules.DELIRIUM_CAP, "the cap holds while slots open")
	_advance(0.05)
	_check(MadnessAuthority.state_of(mobs[3]) == MadnessRules.STATE_DELIRIUM and MadnessAuthority.state_of(mobs[4]) == MadnessRules.STATE_DELIRIUM and authority.delirium_count(player) == 2, "open slots are filled in arrival order")
	for index: int in 3: _check(MadnessAuthority.state_of(mobs[index]) == MadnessRules.STATE_NONE, "the first three left the Delirium")

func _check_delirium_without_target() -> void:
	_setup()
	var boss := _boss(Vector2(520, 300))
	var lone := _mob(&"forest_wolf", Vector2(480, 300))
	authority.add(lone, 100.0, "cast:lone@1", player)
	_check(lone.combat_target() != boss and lone.combat_target() == player and not lone.has_target_override(), "a delirious enemy never targets the boss, even as the only other enemy")
	_check(MadnessAuthority.state_of(lone) == MadnessRules.STATE_DELIRIUM and lone.has_combat_hold() and is_equal_approx(lone.combat_hold_remaining(), MadnessRules.DELIRIUM_DURATION), "without a target it stays in Delirium under a combat hold (A8)")
	lone.global_position = player.global_position + Vector2(30, 0)
	var at := lone.global_position
	lone.attack_cooldown = 0.0
	lone.player_target_acquired = true
	attacks.clear()
	for step: int in 5: lone._process(0.1)
	_check(attacks.is_empty() and lone.global_position.distance_to(at) < 0.5, "it holds still and never attacks the player, even beside it")
	_check(authority.ecstasy.charges == 1, "the entry still counted once")
	# A new enemy appears: the next tick gives the delirious enemy a target and lifts the hold.
	var newcomer := _mob(&"forest_boar", Vector2(200, 600))
	_advance(0.1)
	_check(lone.combat_target() == newcomer and not lone.has_combat_hold(), "a target in range lifts the hold")
	_kill(newcomer)
	lone._advance_target_override(0.05)
	_advance(0.05)
	_check(lone.has_combat_hold() and lone.combat_target() == player and not lone.has_target_override(), "and the hold returns when no target is left")
	_advance(5.0)
	_check(MadnessAuthority.state_of(lone) == MadnessRules.STATE_NONE and not lone.has_combat_hold(), "the hold ends with the Delirium")

## A8: the combat hold primitive of EnemyActor (added by T4).
func _check_combat_hold() -> void:
	_setup(Vector2(400, 330))
	var boss := _boss(Vector2(700, 300))
	var wolf := _mob(&"forest_wolf", Vector2(430, 330))
	_check(boss.set_combat_hold(player.get_instance_id(), 2.0, &"test")["error_code"] == &"boss_refuses_hold" and not boss.has_combat_hold(), "a boss refuses the hold")
	_check(wolf.set_combat_hold(player.get_instance_id(), 0.0, &"test")["error_code"] == &"invalid_payload" and wolf.set_combat_hold(player.get_instance_id(), 1.0, &"")["error_code"] == &"invalid_payload" and wolf.set_combat_hold(-1, 1.0, &"test")["error_code"] == &"invalid_payload", "duration, reason and owner are required")
	_check(wolf.set_combat_hold(player.get_instance_id(), 2.0, &"test")["ok"] and wolf.has_combat_hold() and is_equal_approx(wolf.combat_hold_remaining(), 2.0), "a common enemy accepts the hold")
	_check(not wolf.is_stunned() and not wolf.is_rooted() and not wolf.is_feared() and wolf.hard_controls.longest_remaining() == 0.0, "the hold is not a control (no HardControlState)")
	# The "controlled" readers of the player (Hunter opening, PlayerActor:422; Sentinel focus,
	# PlayerActor:657) read root, stun, fear and slow: none of them sees the hold.
	var hunter_controlled := wolf.hard_controls.boss or wolf.is_rooted() or wolf.is_stunned() or wolf.is_feared() or wolf.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) > 0.0
	_check(not hunter_controlled and not (wolf.is_rooted() or wolf.is_stunned()) and not wolf.is_disoriented(), "no controlled bonus reads the hold (Hunter and Sentinel criteria)")
	var at := wolf.global_position
	wolf.attack_cooldown = 0.0
	wolf.player_target_acquired = true
	attacks.clear()
	for step: int in 5: wolf._process(0.1)
	_check(attacks.is_empty() and wolf.global_position.distance_to(at) < 0.5, "held beside the player: no attack and no movement")
	_check(absf(wolf.combat_hold_remaining() - 1.5) <= 0.001, "the hold runs on the gameplay clock")
	paused = true
	wolf._process(1.0)
	paused = false
	_check(absf(wolf.combat_hold_remaining() - 1.5) <= 0.001, "pause freezes the hold")
	for step: int in 16: wolf._process(0.1)
	_check(not wolf.has_combat_hold(), "the hold expires")
	wolf.attack_cooldown = 0.0
	attacks.clear()
	for step: int in 3: wolf._process(0.1)
	_check(not attacks.is_empty() and attacks[0][1] == player, "without the hold the enemy fights the player again")
	wolf.set_combat_hold(player.get_instance_id(), 5.0, &"test")
	wolf.clear_statuses()
	_check(not wolf.has_combat_hold(), "the hold leaves with the statuses")
	wolf.set_combat_hold(player.get_instance_id(), 5.0, &"test")
	wolf.clear_combat_hold()
	_check(not wolf.has_combat_hold(), "clear_combat_hold removes it")
	wolf.set_combat_hold(player.get_instance_id(), 5.0, &"test")
	_kill(wolf)
	_check(not wolf.has_combat_hold(), "the hold ends with death")

func _check_delirium_kill_credit() -> void:
	_setup()
	kit.set("madness_per_hit", 15.0)
	var a := _mob(&"forest_wolf", Vector2(400, 300))
	var b := _mob(&"forest_boar", Vector2(440, 300))
	b.health.max_hp = 100000.0
	b.health.current_hp = 100000.0
	authority.add(a, 100.0, "cast:kill@1", player)
	a.attack_cooldown = 0.0
	attacks.clear()
	a._process(0.05)
	_check(attacks.size() == 1 and attacks[0][1] == b, "the delirious enemy commits on the other enemy")
	if attacks.size() != 1: return
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var request: DamageRequest = attacks[0][0]
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var hit := b.apply_damage(request, rng)
	_check(EnemyActor.is_relay_result(hit) and float(hit.get("actual_damage", 0.0)) > 0.0 and kit.get("calls").has("dealt:enemy_claw"), "the relayed hit lands and reaches the player's damage hook")
	_check(MadnessAuthority.madness_of(b) == 0.0 and int(kit.get("hit_gains")) == 0, "damage by Delirium gives no Madness")
	b.health.current_hp = 1.0
	a.attack_cooldown = 0.0
	attacks.clear()
	a._process(0.05)
	var lethal: DamageRequest = attacks[0][0]
	lethal.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var kill := b.apply_damage(lethal, rng)
	_check(bool(kill.get("killed", false)) and kit.get("calls").count("kill") == 1 and controller._credited_kills.has(b.get_instance_id()), "the Delirium kill is the player's")
	controller._on_enemy_damage_resolved(kill)
	_check(b.apply_damage(lethal, rng).is_empty() and kit.get("calls").count("kill") == 1, "credited once, retry included")
	_check(int(kit.get("hit_gains")) == 0, "the kill gives no Madness either")

# --- Boss Disorientation -----------------------------------------------------------------

func _check_boss_disorientation() -> void:
	_setup(Vector2(340, 300))
	var boss := _boss(Vector2(300, 300))
	var minion := _mob(&"forest_wolf", Vector2(300, 360))
	var far := _mob(&"forest_boar", Vector2(800, 300))
	var entered := authority.add(boss, 100.0, "cast:boss@1", player)
	_check(entered["entered"] == MadnessRules.STATE_DISORIENTED and MadnessAuthority.state_of(boss) == MadnessRules.STATE_DISORIENTED and MadnessAuthority.madness_of(boss) == 0.0, "at the threshold the boss enters Disorientation, never Delirium")
	_check(not boss.marks.has_mark(MadnessRules.MARK_DELIRIUM) and not boss.has_target_override() and boss.combat_target() == player, "the boss never changes its combat target")
	_check(is_equal_approx(float(boss.received_damage_sources.get(MadnessRules.DISORIENT_SOURCE, {}).get("multiplier", 0.0)), 1.20) and is_equal_approx(boss.received_damage_multiplier(player.get_instance_id()), 1.20), "it takes x1.20 damage (C1.7 source)")
	_check(is_equal_approx(boss.outgoing_hit_rating(100.0), 75.0), "it misses more (accuracy -25%)")
	var deflection: Dictionary = boss.commit_deflections.get(MadnessRules.DISORIENT_SOURCE, {})
	_check(is_equal_approx(float(deflection.get("chance", 0.0)), 0.35) and is_equal_approx(float(deflection.get("radius", 0.0)), 110.0) and int(deflection.get("owner_id", 0)) == player.get_instance_id(), "minion hits registered as the commit deflection (35%, reach 110)")
	_check(is_equal_approx(boss.marks.remaining(MadnessRules.MARK_IMMUNE), MadnessRules.DISORIENT_DURATION + MadnessRules.IMMUNITY), "immunity covers the window and 12 s after it")
	_check(authority.ecstasy.charges == 1, "the boss entry gives one Ecstasy charge")
	_check(boss.apply_disorient(1.0) == 0.0, "no movement disorientation on the boss (T1)")
	# Hits of the boss during the window: some land on the minion beside it, never the far one.
	boss.player_target_acquired = true
	var on_minion := 0
	var on_player := 0
	for attempt: int in 60:
		boss.attack_cooldown = 0.0
		attacks.clear()
		boss._try_attack(false)
		if attacks.size() != 1: continue
		if attacks[0][1] == minion: on_minion += 1
		elif attacks[0][1] == player: on_player += 1
		_check(attacks[0][1] != far, "a far enemy is never hit")
	_check(on_minion >= 8 and on_minion <= 35 and on_minion + on_player == 60, "about 35%% of the boss hits land on the minion (%d of 60)" % on_minion)
	_check(boss.combat_target() == player, "still the player after the deflected hits")
	# Immunity after the window.
	_advance(MadnessRules.DISORIENT_DURATION + 0.1)
	_check(MadnessAuthority.state_of(boss) == MadnessRules.STATE_IMMUNE and boss.commit_deflections.is_empty() and boss.received_damage_sources.is_empty(), "the window ends; the boss is immune")
	_check(authority.add(boss, 50.0, "cast:boss@2", player)["error_code"] == &"immune", "Madness is refused under immunity")
	_check(authority.disorient(boss, "revelation:1", player)["error_code"] == &"immune", "a plain Disorientation is refused under immunity")
	var strong := authority.disorient(boss, "revelation:1b", player, {"bypass_immunity": true, "duration": 6.0, "damage_taken": 1.4, "minion_chance": 0.6, "immunity": 20.0})
	_check(strong["ok"] and MadnessAuthority.state_of(boss) == MadnessRules.STATE_DISORIENTED and is_equal_approx(boss.marks.remaining(MadnessRules.MARK_IMMUNE), 26.0), "the Revelation path bypasses immunity once and sets the longer immunity")
	_check(authority.disorient(boss, "revelation:1b", player, {"bypass_immunity": true})["error_code"] == &"duplicate_event", "once per Revelation event")
	_check(authority.disorient(minion, "revelation:2", player)["error_code"] == &"invalid_target", "only bosses take the Disorientation")
	_advance(26.1)
	_check(MadnessAuthority.state_of(boss) == MadnessRules.STATE_NONE and authority.add(boss, 40.0, "cast:boss@3", player)["ok"], "after the immunity the boss gathers Madness again")

# --- Ecstasy ---------------------------------------------------------------------------

func _check_ecstasy() -> void:
	_setup()
	var source := _mob(&"forest_wolf", Vector2(900, 100))
	var mobs: Array[EnemyActor] = []
	for index: int in 3: mobs.append(_mob(&"forest_boar", Vector2(300 + index * 50, 300)))
	var base_matk := player.stat_breakdown.value(&"magic_attack")
	var base_cost := player.skill_cost(ClassKitRegistry.skill_ids(&"sp_ac")[2])
	_check(player.health.max_hp > 60.0, "the fixture player survives the probe hits")
	var plain := _taken(source, 20.0)
	_check(not plain.has("kit_damage_multiplier"), "no onus without Ecstasy")
	authority.add(mobs[0], 100.0, "cast:ex@0", player)
	authority.add(mobs[0], 100.0, "cast:ex@0", player)
	_check(authority.ecstasy.charges == 1, "one charge per entry; a retried event gives none")
	authority.add(mobs[1], 100.0, "cast:ex@1", player)
	_check(authority.ecstasy.charges == 2 and not _taken(source, 20.0).has("kit_damage_multiplier"), "two charges: still no onus")
	_check(absf(player.stat_breakdown.value(&"magic_attack") - base_matk * 1.08) <= 1.0, "+4%% MATK per charge in the breakdown (%s -> %s)" % [base_matk, player.stat_breakdown.value(&"magic_attack")])
	_check(is_equal_approx(player.skill_cost(ClassKitRegistry.skill_ids(&"sp_ac")[2]), base_cost * 0.92), "-4% SP cost per charge")
	authority.add(mobs[2], 100.0, "cast:ex@2", player)
	_check(is_equal_approx(float(_taken(source, 20.0).get("kit_damage_multiplier", 1.0)), 1.08), "from 3 charges the owner takes x1.08 (onus)")
	for extra: int in 4: authority._gain_ecstasy(player, mobs[0])
	_check(authority.ecstasy.charges == 5 and authority.ecstasy.gained_total == 5, "the charges stop at 5")
	_check(player.is_alive(), "the probe hits never kill the owner")
	_check(is_equal_approx(float(_taken(source, 20.0).get("kit_damage_multiplier", 1.0)), 1.24) and is_equal_approx(player.skill_cost(ClassKitRegistry.skill_ids(&"sp_ac")[2]), base_cost * 0.80), "5 charges: x1.24 damage taken and -20% cost")
	var sources := authority.temporary_stat_sources()
	_check(sources.size() == 1 and sources[0]["source_id"] == &"paladin_ecstasy" and is_equal_approx(float(sources[0]["increased"][&"magic_attack"]), 0.20), "the stat source carries the kit prefix and +20% MATK")
	var request := _enemy_request(source, 10.0)
	request.is_secondary = true
	_check(authority.before_hit(player, {"request": request}).is_empty(), "secondary hits are not scaled by the onus")
	# Build change: no recharge, no reset.
	player.health.current_hp = player.health.max_hp * 0.5
	kit.on_build_changed(player)
	_check(authority.ecstasy.charges == 5 and is_equal_approx(player.health.current_hp, player.health.max_hp * 0.5), "a build change keeps the charges and heals nothing")
	# Decay: 6 s without gain, then one charge every 3 s.
	_advance(5.9)
	_check(authority.ecstasy.charges == 5, "no decay before 6 s")
	_advance(3.2)
	_check(authority.ecstasy.charges == 4, "one charge lost after the next 3 s")
	_advance(3.0)
	_check(authority.ecstasy.charges == 3 and absf(player.stat_breakdown.value(&"magic_attack") - base_matk * 1.12) <= 1.0, "the breakdown follows the decay")
	# Off: no gain and identity helpers; the charges remain.
	authority.set_ecstasy_enabled(player, false)
	_check(authority.skill_cost(10.0) == 10.0 and authority.before_hit(player, {"request": _enemy_request(source, 1.0)}).is_empty() and authority.temporary_stat_sources().is_empty() and authority.ecstasy.charges == 3, "disabled Ecstasy keeps its charges and applies nothing")
	authority.set_ecstasy_enabled(player, true)
	kit.on_death(player)
	_check(authority.ecstasy.charges == 0 and authority.temporary_stat_sources().is_empty(), "the owner's death empties the Ecstasy")

# --- Idol ------------------------------------------------------------------------------

func _check_idol() -> void:
	_setup()
	var boss := _boss(Vector2(560, 300))
	var near := _mob(&"forest_wolf", Vector2(460, 300))
	var elite := _mob(&"forest_boar", Vector2(540, 380), &"elite")
	var far := _mob(&"forest_wolf", Vector2(900, 100))
	var first := authority.place_idol(player, Vector2(500, 300))
	_check(first["ok"] and is_equal_approx((first["decoy"] as CombatActor).health.max_hp, player.health.max_hp * 0.30) and is_equal_approx(float(first["decoy"].get(&"remaining")), 8.0), "the Idol has 30% of the owner's max HP and 8 s")
	var idol: CombatActor = first["decoy"]
	_check(idol.get(&"drawer_id") == MadnessRules.IDOL_DRAWER and idol.get(&"source_id_tag") == MadnessRules.IDOL_TAG and idol not in controller.enemies, "drawn in code by the system drawer, never a player target")
	_check(near.combat_target() == idol and elite.combat_target() == idol and near.target_override_reason() == MadnessRules.IDOL_REASON, "commons and elites in reach target the Idol")
	_check(boss.combat_target() == player and far.combat_target() == player, "the boss never; out of reach neither")
	var second := authority.place_idol(player, Vector2(480, 300))
	_check(second["ok"] and not idol.call(&"is_active") and authority.idols(player).size() == 1 and authority.idol(player) == second["decoy"], "one Idol per owner: the new one replaces the old")
	idol = second["decoy"]
	_advance(0.05)
	_check(near.combat_target() == idol, "the enemies follow the new Idol")
	near.global_position = idol.global_position + Vector2(-40, 0)
	near.attack_cooldown = 0.0
	attacks.clear()
	near._process(0.05)
	_check(attacks.size() == 1 and attacks[0][1] == idol and (attacks[0][0] as DamageRequest).source_id == near.get_instance_id(), "a hit on the Idol is the enemy's own")
	near.global_position = Vector2(460, 300)
	_advance(1.0)
	_check(is_equal_approx(MadnessAuthority.madness_of(near), 8.0) and is_equal_approx(MadnessAuthority.madness_of(boss), 8.0) and is_equal_approx(MadnessAuthority.madness_of(elite), 8.0) and MadnessAuthority.madness_of(far) == 0.0, "every enemy in reach, boss included, gains 8 Madness per tick")
	_check(boss.combat_target() == player, "the boss gazes but does not change its target")
	# Delirium has priority over the Idol.
	authority.add(elite, 100.0, "cast:idol@1", player)
	_check(elite.target_override_reason() == MadnessRules.DELIRIUM_REASON and elite.combat_target() == near, "a delirious enemy attacks enemies, not the Idol")
	_advance(1.0)
	_check(elite.target_override_reason() == MadnessRules.DELIRIUM_REASON, "the Idol never takes a delirious enemy")
	_check(authority.compact_blocker(player) == "madness_idol" and kit.snapshot_compact_blocker(player) == "madness_idol", "an active Idol keeps the exact format")
	var described := authority.describe(player)
	_check(is_equal_approx(float(described["idol"].get("hp", 0.0)), idol.health.current_hp) and float(described["idol"].get("remaining", 0.0)) > 0.0, "describe() reads the Idol HP and deadline")
	for step: int in 9: idol._process(1.0)
	_check(not idol.call(&"is_active") and authority.idol(player) == null and authority.compact_blocker(player) == "", "the Idol expires on the gameplay clock")
	near._advance_target_override(0.05)
	_check(near.combat_target() == player, "with the Idol gone the enemy targets the player again")
	authority.place_idol(player, Vector2(500, 300))
	kit.on_death(player)
	_check(authority.idol(player) == null, "the owner's death removes the Idol")

# --- Contagion -------------------------------------------------------------------------

func _check_contagion() -> void:
	_setup()
	var marked := _mob(&"forest_wolf", Vector2(400, 300))
	var beside := _mob(&"forest_boar", Vector2(500, 300))
	var second_hop := _mob(&"forest_wolf", Vector2(620, 300))
	var far := _mob(&"forest_boar", Vector2(900, 300))
	_check(authority.mark_contagion(player, marked)["ok"] and authority.mark_contagion(player, beside)["ok"], "two enemies are marked for contagion")
	_check(authority.mark_contagion(player, marked, {"radius": 999.0})["error_code"] == &"invalid_options", "contagion options are validated")
	authority.add(marked, 40.0, "cast:contagion@1", player)
	_check(is_equal_approx(MadnessAuthority.madness_of(beside), 20.0), "half of a direct gain is copied to the neighbour in reach")
	_check(MadnessAuthority.madness_of(second_hop) == 0.0 and MadnessAuthority.madness_of(far) == 0.0, "the copy is never copied again (one hop), even through a marked neighbour")
	authority.add(marked, 40.0, "cast:contagion@1", player)
	_check(is_equal_approx(MadnessAuthority.madness_of(beside), 20.0), "a retried event copies nothing")
	authority.add(marked, 60.0, "cast:contagion@2", player)
	_check(MadnessAuthority.state_of(marked) == MadnessRules.STATE_DELIRIUM, "the marked enemy enters Delirium")
	_check(is_equal_approx(MadnessAuthority.madness_of(beside), 75.0), "the neighbour gets the copy (30) and one pulse (25): %s" % MadnessAuthority.madness_of(beside))
	_check(MadnessAuthority.madness_of(second_hop) == 0.0, "the pulse does not spread either")
	authority.add(beside, 30.0, "cast:contagion@3", player)
	_check(MadnessAuthority.state_of(beside) == MadnessRules.STATE_DELIRIUM and is_equal_approx(MadnessAuthority.madness_of(second_hop), 12.5 + 25.0), "a direct gain on the second marked enemy spreads from it, once (half of the 25 received + pulse 25): %s" % MadnessAuthority.madness_of(second_hop))
	_check(MadnessAuthority.madness_of(far) == 0.0, "nothing reaches the far enemy")

# --- describe() and the tick ----------------------------------------------------------

func _check_describe_and_tick_dedupe() -> void:
	_setup()
	var boss := _boss(Vector2(700, 300))
	var wolf := _mob(&"forest_wolf", Vector2(400, 300))
	var boar := _mob(&"forest_boar", Vector2(460, 300))
	authority.add(wolf, 100.0, "cast:describe@1", player)
	authority.add(boar, 30.0, "cast:describe@2", player)
	authority.add(boss, 100.0, "cast:describe@3", player)
	var revisions := [wolf.marks.revision, boar.marks.revision, boss.marks.revision, authority.ecstasy.charges, authority._claim_order.size()]
	var first := authority.describe(player)
	var second := authority.describe(player)
	_check(first == second and revisions == [wolf.marks.revision, boar.marks.revision, boss.marks.revision, authority.ecstasy.charges, authority._claim_order.size()], "describe() is pure")
	_check(first["ecstasy"] == 2 and first["ecstasy_cap"] == 5 and first["delirium_count"] == 1 and first["delirium_cap"] == 3 and first["enemies"].size() == 3, "describe() lists Ecstasy, Delirium count and the maddened enemies")
	var lines := {}
	for line: Dictionary in first["enemies"]: lines[line["id"]] = line
	_check(lines[wolf.get_instance_id()]["state"] == MadnessRules.STATE_DELIRIUM and lines[boar.get_instance_id()]["madness"] == 30.0 and lines[boss.get_instance_id()]["state"] == MadnessRules.STATE_DISORIENTED and bool(lines[boss.get_instance_id()]["boss"]), "one line per enemy with Madness and state")
	_check(MadnessAuthority.describe_enemy(boar)["threshold"] == MadnessRules.THRESHOLD, "describe_enemy() for a single enemy")
	# Two modules forwarding on_tick in the same instant: one tick counts.
	_advance(3.9)
	_advance(0.2)
	var before := MadnessAuthority.madness_of(boar)
	player.kit_time += 1.0
	authority.tick(player, 1.0)
	authority.tick(player, 1.0)
	_check(absf(before - MadnessAuthority.madness_of(boar) - 20.0) <= 0.01, "a second forward in the same kit_time is ignored")

# --- Snapshot (A4) -----------------------------------------------------------------------

func _check_snapshot_formats() -> void:
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty(), "every fragment merges, including madness: " + str(registry.fragment_errors))
	for path: String in ["res://scripts/systems/madness/madness_authority.gd", "res://scripts/systems/madness/madness_ecstasy.gd", "res://scripts/systems/madness/fixture/madness_fixture_kit.gd"]:
		_check(registry.schemas.has(path), "schema present for " + path)
	_check("res://scripts/systems/madness/snapshot_manifest.json" in SnapshotRegistry.fragment_paths(), "the system fragment is discovered by folder")
	_setup()
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var standalone := _make_player(nav)
	standalone.global_position = Vector2(400, 350)
	owned.append(standalone)
	var held: MadnessAuthority = standalone.kit.get("madness")
	held.ecstasy.charges = 4
	held.ecstasy.idle_time = 2.5
	held.ecstasy_published = 0.16
	held._remember("madness@before_save:t4_wolf")
	var placed := held.place_idol(standalone, Vector2(450, 350), {"duration": 10.0}, standalone)
	_check(placed["ok"], "Idol placed under the standalone owner: " + str(placed))
	var idol: CombatActor = placed.get("decoy")
	if idol != null: idol.set(&"remaining", 6.5)
	held.idol_tick_remaining = 0.4
	held.idol_ticks = 3
	standalone.kit_time = 9.0
	var barrier := SnapshotTickBarrier.new()
	paused = true
	_check(barrier.acquire(standalone)["ok"], "barrier acquired")
	var captured := SnapshotRegistry.new().capture(standalone, barrier)
	_check(captured.get("ok", false), "exact capture with Ecstasy and an Idol: " + str(captured.get("detail", captured.get("error_code", ""))))
	if captured.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(captured["snapshot"])))
		_check(restored.get("ok", false), "exact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied: MadnessAuthority = copy.kit.get("madness")
			_check(copied != null and copied.ecstasy.charges == 4 and copied.ecstasy.enabled and is_equal_approx(copied.ecstasy.idle_time, 2.5) and copied.owner_id == copy.get_instance_id(), "exact format preserves the Ecstasy and rebinds the owner")
			_check(copied != null and copied.has_claimed("madness@before_save:t4_wolf") and is_equal_approx(copied.idol_tick_remaining, 0.4) and copied.idol_ticks == 3, "exact format preserves the event ring and the Idol clock")
			var copied_idol := copied.idol(copy) if copied != null else null
			_check(copied_idol != null and is_equal_approx(float(copied_idol.get(&"remaining")), 6.5) and int(copied_idol.get(&"owner_id")) == copy.get_instance_id() and is_equal_approx(copied_idol.health.max_hp, standalone.health.max_hp * 0.30), "exact format preserves the Idol with its owner")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	var projection := {"fields": {}, "excluded": {}}
	var compact := SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(not compact.get("ok", false) and held.compact_blocker(standalone) == "madness_idol", "an active Idol makes the compact cut ineligible: " + str(compact.get("error_code", "")) + " " + str(compact.get("detail", "")))
	if idol != null:
		standalone.remove_child(idol)
		idol.free()
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("ok", false), "without an Idol the compact cut is accepted: " + str(compact.get("detail", compact.get("error_code", ""))))
	if compact.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(compact["snapshot"])))
		_check(restored.get("ok", false), "compact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied: MadnessAuthority = copy.kit.get("madness")
			_check(copied != null and copied.ecstasy.charges == 4 and copied.compact_blocker(copy) == "", "compact format preserves the Ecstasy on the player")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	barrier.release()
	paused = false

# --- Expedition world (second path) ------------------------------------------------------

func _check_world_path() -> void:
	_setup()
	var input := WorldFixture.make()
	var built := ExpeditionAssembler.build(input)
	var world := WorldGeometry.new()
	_check(built["ok"] and world.configure(built["data"]["manifest"], "sample")["ok"], "F1 fixture geometry configured")
	if not built["ok"]: return
	var profile := input.traversal.to_data()
	_check(player.bind_world_geometry(world, WorldFixture.point("root", Vector3(20, 0, 20)), profile, str(player.get_instance_id()))["ok"], "player bound to the world")
	player.set_process(false)
	var a := _mob(&"forest_wolf", Vector2.ZERO)
	var b := _mob(&"forest_boar", Vector2.ZERO)
	var c := _mob(&"forest_wolf", Vector2.ZERO)
	var boss := _boss(Vector2.ZERO)
	for row: Array in [[a, Vector3(20, 0, 150)], [b, Vector3(80, 0, 60)], [c, Vector3(80, 0, 190)], [boss, Vector3(40, 0, 140)]]:
		var hostile: EnemyActor = row[0]
		_check(hostile.bind_world_geometry(world, WorldFixture.point("root", row[1]), profile, str(hostile.get_instance_id()))["ok"], "world mob bound")
		hostile.set_process(false)
	var entered := authority.add(a, 100.0, "cast:world@1", player)
	_check(entered["entered"] == MadnessRules.STATE_DELIRIUM and a.target_override_reason() == MadnessRules.DELIRIUM_REASON, "a world mob enters Delirium")
	var expected := b if a.world_distance_to(b) < a.world_distance_to(c) else c
	_check(a.combat_target() == expected and a.combat_target() != boss, "it targets the nearest non-boss enemy by world distance (the closer boss is skipped)")
	var target := a.combat_target()
	var start := a.world_distance_to(target)
	for step: int in 10: a._process(0.2)
	_check(a.world_distance_to(target) < start - 20.0, "in the world it chases its Delirium target (%s -> %s)" % [start, a.world_distance_to(target)])
	for step: int in 40:
		if a.world_can_reach(target, 55.0): break
		a._process(0.2)
	a.attack_cooldown = 0.0
	attacks.clear()
	a._process(0.05)
	_check(attacks.size() == 1 and attacks[0][1] == target and (attacks[0][0] as DamageRequest).source_id == player.get_instance_id(), "in reach it attacks the other world mob with the player's authorship")
	_check(c.set_combat_hold(player.get_instance_id(), 1.0, &"test")["ok"], "a world mob accepts the hold")
	var held_at := c.world_point().position
	c.attack_cooldown = 0.0
	attacks.clear()
	for step: int in 4: c._process(0.2)
	_check(attacks.is_empty() and c.world_point().position.distance_to(held_at) < 0.5, "a held world mob neither moves nor attacks")
	c.clear_combat_hold()
	var disoriented := authority.add(boss, 100.0, "cast:world@2", player)
	_check(disoriented["entered"] == MadnessRules.STATE_DISORIENTED and boss.combat_target() == player and boss.commit_deflections.has(MadnessRules.DISORIENT_SOURCE), "the world boss is disoriented without a redirect")
	# World Idol.
	var placed := authority.place_idol(player, WorldFixture.point("root", Vector3(60, 0, 80)))
	_check(placed["ok"] and (placed["decoy"] as CombatActor).world_motion != null, "the Idol is placed in the world: " + str(placed.get("error_code", "")))
	if placed["ok"]:
		var idol: CombatActor = placed["decoy"]
		_check(b.combat_target() == idol and boss.combat_target() == player, "a world mob in reach targets the Idol; the boss does not")
		var before := MadnessAuthority.madness_of(b)
		_advance(1.0, [b, c])
		_check(is_equal_approx(MadnessAuthority.madness_of(b), before + 8.0), "the world Idol gives Madness per tick")
		_check(authority.compact_blocker(player) == "madness_idol", "the world Idol keeps the exact format")
		idol.call(&"remove")
