extends SceneTree
## E09 T5 (C2) — Santuário and Graça family authority. Invariants of C2 and the
## numbers of docs/epics/e09/t5_contract.md. A fixture kit outside the production
## registry (scripts/systems/sanctuary/fixture/) is installed over sp_ac and
## forwards the T1 seam hooks to a SanctuaryAuthority. Fixture profiles only.
const SanctuaryFixtureKit = preload("res://scripts/systems/sanctuary/fixture/sanctuary_fixture_kit.gd")
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
var authority: SanctuaryAuthority

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	_check_rules_as_data()
	_check_zone_geometry_flat()
	_check_pulse_duration_and_pause()
	_check_no_rule_twice_per_tick()
	_check_owner_damage_rule()
	_check_heal_excess_and_multiplier()
	_check_grace_dedupe_cap_and_unlimited()
	_check_spend_and_judgment()
	_check_build_change_and_death()
	_check_aegis()
	_check_seal_and_light()
	_check_snapshot_formats()
	_check_world_geometry()
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	print("E09 T5 sanctuary: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixture --------------------------------------------------------------------

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	paused = false

func _make_player(navigation: ArenaNavigation) -> PlayerActor:
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
	actor.configure(navigation, RunState.from_build("sanctuary-" + str(checks), snapshot))
	return actor

func _setup(position: Vector2 = Vector2(400, 350)) -> void:
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	ClassKitRegistry.install_fixture(&"sp_ac", SanctuaryFixtureKit.new(&"sp_ac"))
	var navigation := ArenaNavigation.new()
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
	player.character_animation.state.face(Vector2.RIGHT)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 17
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	kit = player.kit
	authority = kit.get("sanctuary")

func _enemy(at: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	controller.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position = at
	enemy.health.max_hp = 100000.0
	enemy.health.current_hp = 100000.0
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(enemy)
	return enemy

func _hostile(at: Vector2) -> CombatActor:
	var hostile := EnemyActor.new()
	hostile.configure(&"chaser", controller.navigation, player)
	controller.add_child(hostile)
	hostile.set_process(false)
	hostile.global_position = at
	hostile.health.max_hp = 100000.0
	hostile.health.current_hp = 100000.0
	hostile.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(hostile)
	return hostile

func _slot(index: int) -> StringName:
	return ClassKitRegistry.skill_ids(&"sp_ac")[index]

func _cast_zone(config: Dictionary) -> SanctuaryZone:
	kit.set("zone_config", config)
	player.mage_cooldowns[_slot(0)] = 0.0
	player.current_sp = player.max_sp
	_check(player.use_kit_skill(_slot(0), player.global_position), "zone cast commits: " + str(config))
	return authority.zone(StringName(config["role"]))

func _enemy_request(source: CombatActor, amount: float, with_context: bool = true) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	if with_context: request.context = player.run_state.effect_ledger.new_root(source.get_instance_id(), false, "", false, {})
	return request

func _hits_on(enemy: CombatActor) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	enemy.health.damage_applied.connect(func(result: Dictionary) -> void: hits.append(result))
	return hits

func _tick(delta: float) -> void:
	player._process(delta)

# --- Rules as data ----------------------------------------------------------------

func _check_rules_as_data() -> void:
	var defaults := SanctuaryRules.validate_rules({})
	_check(defaults["ok"] and is_equal_approx(defaults["rules"]["owner_damage_taken"], 0.80) and is_equal_approx(defaults["rules"]["heal_multiplier"], 1.25) and defaults["rules"]["burn_stat"] == &"magic_attack", "rules default to the contract numbers")
	_check(SanctuaryRules.validate_rules({"owner_damage_taken": 0.6, "burn_stat": &"melee_attack"})["ok"], "rules accept overrides in range")
	_check(SanctuaryRules.validate_rules({"teleport": 1.0})["error_code"] == &"invalid_rules", "unknown rule key is refused")
	_check(SanctuaryRules.validate_rules({"owner_damage_taken": 0.1})["error_code"] == &"invalid_rules" and SanctuaryRules.validate_rules({"heal_multiplier": INF})["error_code"] == &"invalid_rules", "out-of-range and non-finite values are refused")
	_check(SanctuaryRules.validate_rules({"burn_stat": &"luck"})["error_code"] == &"invalid_rules", "burn stat is a closed list")
	_check(SanctuaryRules.ELEMENTS == [&"none", &"fire", &"ice", &"lightning", &"tricolor"] and SanctuaryRules.has_fire(&"tricolor") and SanctuaryRules.has_ice(&"tricolor") and SanctuaryRules.has_lightning(&"tricolor") and not SanctuaryRules.has_fire(&"ice"), "element modes; tricolor carries the three")

# --- Zone geometry (flat arena) ------------------------------------------------------

func _check_zone_geometry_flat() -> void:
	_setup()
	var front := _enemy(Vector2(520, 350))
	var behind := _enemy(Vector2(300, 350))
	var far := _enemy(Vector2(700, 350))
	var cone := _cast_zone({"role": &"oath", "shape": &"cone"})
	_check(cone != null and cone.shape == &"cone" and cone.anchor_mode == &"owner" and is_equal_approx(cone.radius, 160.0) and is_equal_approx(cone.half_angle, deg_to_rad(55.0)), "cone zone is anchored on the owner with the contract numbers")
	if cone == null: return
	_check(cone.contains(player, front) and not cone.contains(player, behind) and not cone.contains(player, far), "cone membership: front inside, behind and far outside")
	player.character_animation.state.face(Vector2.LEFT)
	_check(cone.contains(player, behind) and not cone.contains(player, front), "cone follows the owner's gameplay facing")
	player.character_animation.state.face(Vector2.RIGHT)
	_check(cone.contains(player, player) and cone.owner_inside, "owner is inside a zone anchored on itself")
	var remaining := cone.remaining
	cone.pulse_remaining = 0.4
	_check(authority.set_zone_shape(&"oath", &"circle")["ok"] and cone.shape == &"circle" and cone.contains(player, behind) and cone.remaining == remaining and cone.pulse_remaining == 0.4, "the cone becomes a full circle without restarting its clocks")
	_check(authority.set_zone_shape(&"oath", &"wide_circle")["ok"] and is_equal_approx(cone.radius, 160.0 * 1.6), "wide circle scales the base radius by 1.6")
	_check(authority.open_zone(player, {"role": &"bad", "skill_id": _slot(0), "shape": &"cone", "anchor": &"world"})["error_code"] == &"invalid_anchor", "a cone is always anchored on the owner")
	_check(authority.open_zone(player, {"role": &"bad", "skill_id": _slot(0), "radius": 500.0})["error_code"] == &"invalid_radius" and authority.open_zone(player, {"role": &"bad", "skill_id": _slot(0), "element": &"shadow"})["error_code"] == &"invalid_element", "zone parameters are range checked")
	# World-anchored circle on the flat arena: leaving it keeps the zone, only the bonus goes.
	var circle := _cast_zone({"role": &"votive", "shape": &"circle", "anchor": &"world"})
	_check(circle != null and circle.center == player.global_position and is_equal_approx(circle.radius, 130.0) and circle.owner_inside, "world-anchored circle at the cast point")
	var replaced := _cast_zone({"role": &"votive", "shape": &"circle", "anchor": &"world", "duration": 5.0})
	_check(replaced != circle and authority.zones.size() == 2 and is_equal_approx(replaced.duration, 5.0), "one zone per owner and role: a new one replaces the old")
	player.global_position = Vector2(400 + 300, 350)
	_tick(0.3)
	_check(replaced.is_active() and not replaced.owner_inside, "leaving the zone does not end it; presence follows the owner")
	_check(is_equal_approx(authority.heal_multiplier(), cone.rules["heal_multiplier"]), "outside the world circle only the owner-anchored zone still counts")

# --- Pulse, duration and pause ------------------------------------------------------

func _check_pulse_duration_and_pause() -> void:
	_setup()
	var enemy := _enemy(Vector2(500, 350))
	var hits := _hits_on(enemy)
	var zone := _cast_zone({"role": &"oath", "shape": &"cone", "duration": 4.0})
	if zone == null: return
	_check(zone.prototype != null and zone.prototype.is_secondary and zone.prototype.magic_damage > 0.0 and zone.prototype.physical_damage == 0.0 and is_equal_approx(zone.prototype.magic_damage, player.stat_breakdown.value(&"magic_attack") * 0.20), "burn prototype is a secondary magic DamageRequest from the owner's stats")
	paused = true
	_tick(1.0)
	_tick(1.0)
	_check(zone.remaining == 4.0 and zone.pulses == 0 and hits.is_empty(), "pause freezes zone duration and pulses")
	paused = false
	_tick(0.5)
	_check(zone.pulses == 0 and is_equal_approx(zone.remaining, 3.5), "first pulse is 1 s after creation")
	_tick(0.5)
	_check(zone.pulses == 1 and hits.size() == 1 and bool(hits[0]["secondary"]) and hits[0]["skill_id"] == _slot(0) and float(hits[0]["actual_damage"]) > 0.0, "a pulse burns the enemy inside through a DamageRequest")
	_check(hits.size() == 1 and String(hits[0]["root_event_id"]) != "" and int(hits[0]["event_id"]) > 0, "the burn tick is a ledger-claimed application")
	for step: int in 6: _tick(0.5)
	_check(zone.pulses == 4 and hits.size() == 4 and authority.zone(&"oath") == null and authority.zones.is_empty(), "4 s zone pulses 4 times and ends by time")
	_tick(1.0)
	_check(hits.size() == 4, "an ended zone never pulses again")

# --- No rule twice in one tick ------------------------------------------------------

func _check_no_rule_twice_per_tick() -> void:
	_setup()
	var enemy := _enemy(Vector2(480, 350))
	var hits := _hits_on(enemy)
	var a := _cast_zone({"role": &"oath", "shape": &"cone", "element": &"ice"})
	var b := _cast_zone({"role": &"votive", "shape": &"circle", "anchor": &"world", "element": &"ice"})
	if a == null or b == null: return
	a.pulse_remaining = 0.2
	b.pulse_remaining = 0.2
	_tick(0.25)
	_check(a.pulses == 1 and b.pulses == 1 and hits.size() == 1, "two overlapping zones pulsing in the same tick burn the enemy once")
	_check(enemy.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) > 0.0, "ice slows the enemy inside")
	var before := hits.size()
	authority.pulse_now(player, &"oath")
	_check(hits.size() == before, "an immediate pulse in the same tick does not burn the same enemy again")
	_tick(0.01)
	authority.pulse_now(player, &"oath", &"fire")
	_check(hits.size() == before + 1, "after a new tick the immediate pulse burns once more")
	var fire_amount: float = a.prototype.magic_damage * a.rules["fire_burn_multiplier"]
	_check(is_equal_approx(float(hits[-1]["magic_component"]), fire_amount * 100.0 / (100.0 + enemy.health.magic_defense)), "a pulse of the fire element burns 1.5x (old-element pulse of the altar shift)")
	# Lightning: SP once per tick with the strongest value.
	b.set_element(&"lightning")
	a.set_element(&"tricolor")
	player.current_sp = player.max_sp * 0.2
	var sp := player.current_sp
	_tick(0.1)
	var expected := player.stat_breakdown.value(&"sp_regen") * 0.1 * (1.0 + 0.5)
	_check(is_equal_approx(player.current_sp - sp, expected), "lightning adds sp_regen x 0.5 once per tick, not once per zone")

# --- Owner damage taken ----------------------------------------------------------

func _damage_with(source: CombatActor, amount: float) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	player.health.current_hp = player.health.max_hp
	player.health.clear_shield()
	return float(player.apply_damage(_enemy_request(source, amount), rng).get("damage", 0.0))

func _check_owner_damage_rule() -> void:
	_setup()
	var front := _enemy(Vector2(460, 350))
	var behind := _enemy(Vector2(340, 350))
	var base_front := _damage_with(front, 200.0)
	var base_behind := _damage_with(behind, 200.0)
	_check(base_front > 0.0 and is_equal_approx(base_front, base_behind), "without a zone both sides take the same damage")
	_cast_zone({"role": &"oath", "shape": &"cone"})
	var cone_front := _damage_with(front, 200.0)
	var cone_behind := _damage_with(behind, 200.0)
	_check(absf(cone_front - base_front * 0.80) <= 1.0, "cone: frontal hit takes x0.80 (%s vs %s)" % [cone_front, base_front])
	_check(is_equal_approx(cone_behind, base_behind), "cone: a hit from behind is not reduced")
	# T1.1 hook: the multiplier is applied on a copy; the original request never changes.
	var original := _enemy_request(front, 200.0)
	var hook_rng := RandomNumberGenerator.new()
	player.health.current_hp = player.health.max_hp
	var hooked := player.apply_damage(original, hook_rng)
	_check(original.damage_dealt_multiplier == 1.0 and is_equal_approx(float(hooked.get("kit_damage_multiplier", 1.0)), 0.80), "the zone returns damage_multiplier; the player scales a copy (T1.1)")
	_check(authority.before_hit(player, {"request": _enemy_request(behind, 10.0), "facing_dot": -1.0}).is_empty(), "no multiplier when the zone does not cover the hit")
	# T1.1 hook: ice is real DEF in the breakdown (temporary stat source), refreshed without heal.
	var defense := player.stat_breakdown.value(&"physical_defense")
	var magic_defense := player.stat_breakdown.value(&"magic_defense")
	player.health.current_hp = player.health.max_hp * 0.7
	var deficit := player.health.hp_deficit()
	var sp_deficit := player.sp_deficit()
	_check(authority.temporary_stat_sources().is_empty(), "no stat source without ice")
	authority.set_zone_element(&"oath", &"ice", player)
	var sources := player.temporary_stat_sources()
	var ice_source: Dictionary = {}
	for source: Dictionary in sources:
		if source.get("source_id") == &"paladin_sanctuary_ice": ice_source = source
	_check(not ice_source.is_empty() and is_equal_approx(float(ice_source["increased"][&"physical_defense"]), 0.15) and is_equal_approx(float(ice_source["increased"][&"magic_defense"]), 0.15), "ice publishes +15% DEF as a kit-prefixed temporary stat source")
	_check(player.stat_breakdown.value(&"physical_defense") > defense and player.stat_breakdown.value(&"magic_defense") > magic_defense and is_equal_approx(player.health.physical_defense, player.stat_breakdown.value(&"physical_defense")), "the ice DEF is in the breakdown and in the health defenses")
	_check(player.health.hp_deficit() == deficit and player.sp_deficit() == sp_deficit, "the stat refresh neither heals nor recharges")
	var ice_behind := _damage_with(behind, 200.0)
	_check(ice_behind < base_behind and ice_behind == float(maxi(1, floori(200.0 * 100.0 / (100.0 + player.health.physical_defense) + 0.5))), "ice DEF reduces the damage through CombatMath")
	_check(absf(_damage_with(front, 200.0) - ice_behind * 0.80) <= 1.0, "the frontal multiplier stacks with the ice DEF")
	authority.end_zone(&"oath", player)
	_check(authority.temporary_stat_sources().is_empty() and is_equal_approx(player.stat_breakdown.value(&"physical_defense"), defense), "ending the ice zone removes the DEF")
	var world_ice := _cast_zone({"role": &"votive", "shape": &"circle", "anchor": &"world", "element": &"ice"})
	_check(world_ice != null and player.stat_breakdown.value(&"physical_defense") > defense, "an ice circle under the owner gives DEF")
	var home := player.global_position
	player.global_position = home + Vector2(400, 0)
	_tick(0.3)
	_check(not world_ice.owner_inside and authority.temporary_stat_sources().is_empty() and is_equal_approx(player.stat_breakdown.value(&"physical_defense"), defense), "leaving the ice circle removes the DEF at the next presence check")
	player.global_position = home
	authority.end_zone(&"votive", player)
	_cast_zone({"role": &"votive", "shape": &"circle", "anchor": &"world", "rules": {"owner_damage_taken": 0.6}})
	_cast_zone({"role": &"oath", "shape": &"cone"})
	_check(absf(_damage_with(front, 200.0) - base_front * 0.60) <= 1.0, "two zones: the smallest multiplier applies once")
	_check(absf(_damage_with(behind, 200.0) - base_behind * 0.60) <= 1.0, "a circle covers hits from every side")
	var secondary := _enemy_request(front, 50.0, false)
	secondary.is_secondary = true
	var plain_tick := secondary.copy()
	var rng := RandomNumberGenerator.new()
	player.apply_damage(secondary, rng)
	_check(secondary.damage_dealt_multiplier == plain_tick.damage_dealt_multiplier, "secondary ticks skip the pipeline and the rule")

# --- Heal excess and multiplier ----------------------------------------------------

func _check_heal_excess_and_multiplier() -> void:
	_setup()
	var grace := authority.grace
	var max_hp := player.health.max_hp
	player.health.current_hp = max_hp - max_hp * 0.5
	player.heal_player(max_hp * 0.2, &"fixture")
	_check(grace.charges == 0 and grace.excess_pool == 0.0, "heal without excess never generates Grace")
	player.health.current_hp = max_hp
	player.heal_player(max_hp * 0.10, &"fixture")
	_check(grace.charges == 1 and absf(grace.excess_pool - max_hp * 0.02) < 0.01, "excess measured after the heal: 10% max HP -> 1 charge (8% each), 2% kept")
	player.heal_player(max_hp * 0.07, &"fixture")
	_check(grace.charges == 2 and absf(grace.excess_pool - max_hp * 0.01) < 0.01, "the pool carries the remainder to the next charge")
	player.health.current_hp = max_hp - 10.0
	player.heal_player(max_hp * 0.33, &"fixture")
	_check(grace.charges == 5, "a large excess gains several charges at once, capped at 5")
	# Heal multiplier inside the zone, through a separate reported bonus heal.
	_setup()
	grace = authority.grace
	max_hp = player.health.max_hp
	_cast_zone({"role": &"oath", "shape": &"cone"})
	player.health.current_hp = max_hp * 0.5
	var before_hp := player.health.current_hp
	var applied := player.heal_player(max_hp * 0.1, &"fixture")
	_check(is_equal_approx(applied, max_hp * 0.1) and absf(player.health.current_hp - before_hp - max_hp * 0.125) < 0.01, "inside the zone the heal yields x1.25")
	_check(kit.get("calls").count("heal:sanctuary_heal_bonus") == 1 and kit.get("calls").count("heal:fixture") == 1 and grace.charges == 0, "the bonus is one reported heal, never multiplied again, without excess")
	player.health.current_hp = max_hp
	player.heal_player(max_hp * 0.08, &"fixture")
	_check(grace.charges == 1 and absf(grace.excess_pool - max_hp * 0.02) < 0.01, "at full HP the amplified heal is all excess: 8% x 1.25 = 10%")
	authority.end_zone(&"oath")
	player.health.current_hp = max_hp * 0.5
	authority.on_heal(player, max_hp * 0.1, max_hp * 0.1, &"fixture") # applied == requested
	_check(grace.charges == 1, "applied equal to requested has no excess")

# --- Grace: dedupe, cap, unlimited, decay -----------------------------------------------

func _check_grace_dedupe_cap_and_unlimited() -> void:
	_setup()
	var grace := authority.grace
	var source := _enemy(Vector2(460, 350))
	_cast_zone({"role": &"oath", "shape": &"cone"})
	var rng := RandomNumberGenerator.new()
	var result := player.apply_damage(_enemy_request(source, 30.0), rng)
	_check(grace.charges == 1 and kit.get("calls").has("after:front"), "kit source: a frontal mitigated hit gains Grace")
	_check(authority.gain(SanctuaryHelpers.result_event(result), 1) == 0 and grace.charges == 1, "the same hit event never gains twice")
	_check(SanctuaryGrace.event_key(SanctuaryHelpers.result_event(result), &"x").begins_with("x@%s#" % result["root_event_id"]), "the event key is the ledger identity of the application")
	var behind := _enemy(Vector2(340, 350))
	player.apply_damage(_enemy_request(behind, 30.0), rng)
	_check(grace.charges == 1, "a hit from behind is not a frontal mitigated hit")
	_check(authority.gain({}, 1) == 0 and authority.gain({"key": "k"}, 0) == 0 and authority.gain({"key": "k"}, 6) == 0, "keyless events and amounts outside 1..5 gain nothing")
	_check(authority.gain({"key": "a"}, 2) == 2 and authority.gain({"key": "b"}, 5) == 2 and grace.charges == 5, "gain is clamped to the cap of 5")
	_check(authority.gain({"key": "c"}, 1) == 0 and grace.has_claimed({"key": "c"}, authority.grace_family), "a gain on a full reserve still consumes its event")
	_check(grace.begin_unlimited(2.0) and authority.gain({"key": "d"}, 4) == 4 and grace.charges == 9, "unlimited mode has no cap")
	paused = true
	_tick(5.0)
	_check(grace.is_unlimited() and grace.charges == 9, "pause freezes the unlimited mode")
	paused = false
	_tick(1.0)
	_tick(1.0)
	_check(not grace.is_unlimited() and grace.charges == 5, "at the end of the unlimited mode Grace returns to the cap")
	for index: int in 200: grace.gain({"key": "ring%d" % index}, 1)
	_check(grace._claimed.size() == SanctuaryRules.GRACE_EVENT_MEMORY and grace._claim_order.size() == SanctuaryRules.GRACE_EVENT_MEMORY, "event memory is bounded")
	# Decay: only without a zone, 8 s after the last gain or spend, then -1 every 2 s.
	authority.end_zone(&"oath")
	grace.idle_time = 0.0
	grace.excess_pool = 3.0
	for step: int in 7: _tick(1.0)
	_check(grace.charges == 5 and grace.excess_pool == 3.0, "no decay before 8 s idle")
	_tick(1.0)
	_check(grace.charges == 5 and grace.excess_pool == 0.0, "decay starts at 8 s and empties the excess pool")
	_tick(2.0)
	_check(grace.charges == 4, "decay removes one charge every 2 s")
	paused = true
	_tick(10.0)
	_check(grace.charges == 4, "pause freezes the decay")
	paused = false
	_cast_zone({"role": &"oath", "shape": &"cone"})
	for step: int in 4: _tick(1.0)
	_check(grace.charges == 4, "an active zone holds the decay")

# --- Spend and Juízo ---------------------------------------------------------------

func _check_spend_and_judgment() -> void:
	_setup()
	var grace := authority.grace
	var enemy := _enemy(Vector2(480, 350))
	var hits := _hits_on(enemy)
	var cast := {"skill_id": _slot(2)}
	grace.charges = 3
	_check(grace.can_spend(3) and not grace.can_spend(4) and grace.charges == 3, "can_spend is pure")
	player.kit_time = 2.0
	_check(authority.spend_for_cast(player, cast, 1) == 3 and grace.charges == 0, "spend takes every charge by default")
	grace.charges = 2
	_check(authority.spend_for_cast(player, cast, 1) == 3 and grace.charges == 2, "the same commit never spends twice")
	player.kit_time = 3.0
	_check(authority.spend_for_cast(player, cast, 3) == 0 and grace.charges == 2 and authority.spend_for_cast(player, {"skill_id": _slot(2)}, 1, 1) == 1 and grace.charges == 1, "minimum and partial spend")
	# Real cast: Grace spent in on_cast_confirmed, Juízo scaled by the spent charges.
	var rng_amount := SanctuaryHelpers.judgment_amount(100.0, 5)
	_check(is_equal_approx(rng_amount, 300.0) and is_equal_approx(SanctuaryHelpers.judgment_amount(100.0, 0), 100.0) and SanctuaryHelpers.judgment_amount(-1.0, 3) == 0.0, "Juízo amount = base x (1 + 0.40 x charges)")
	grace.charges = 0
	player.kit_time = 4.0
	player.current_sp = player.max_sp
	player.mage_cooldowns[_slot(2)] = 0.0
	_check(player.use_kit_skill(_slot(2), enemy.global_position, enemy) and kit.get("last_spent") == 0 and hits.size() == 1, "Juízo with no charge strikes at base")
	var base_damage := float(hits[-1]["magic_component"])
	grace.charges = 5
	player.kit_time = 5.0
	player.current_sp = player.max_sp
	player.mage_cooldowns[_slot(2)] = 0.0
	_check(player.use_kit_skill(_slot(2), enemy.global_position, enemy) and kit.get("last_spent") == 5 and grace.charges == 0 and hits.size() == 2, "the cast commit spends the 5 charges atomically")
	_check(absf(float(hits[-1]["magic_component"]) - base_damage * 3.0) < 0.01 and float(hits[-1]["physical_component"]) == 0.0, "5 charges triple the magic Juízo; defense by CombatMath")
	var near := _enemy(Vector2(600, 350))
	var far := _enemy(Vector2(700, 350))
	var column := SanctuaryHelpers.judgment_targets(player, controller.enemies, Vector2(600, 350))
	_check(column == [near], "the column hits the enemies at the point (radius 45)")
	var cone := _cast_zone({"role": &"oath", "shape": &"cone"})
	var inside := SanctuaryHelpers.judgment_targets(player, controller.enemies, Vector2.ZERO, 45.0, cone)
	_check(enemy in inside and near not in inside and far not in inside, "with a zone, the Juízo hits every enemy inside it")

# --- Build change and death ------------------------------------------------------

func _check_build_change_and_death() -> void:
	_setup()
	var grace := authority.grace
	_cast_zone({"role": &"oath", "shape": &"cone"})
	grace.charges = 3
	grace.excess_pool = 4.0
	var hp := player.health.current_hp
	player.apply_run_modifiers(player.run_state)
	_check(kit.get("calls")[-1] == "build" and grace.charges == 3 and grace.excess_pool == 4.0 and player.health.current_hp == hp and authority.zone(&"oath") != null, "a build change neither recharges nor resets Grace, nor heals")
	grace.begin_unlimited(5.0)
	grace.charges = 8
	player.apply_run_modifiers(player.run_state)
	_check(grace.charges == 8, "build change keeps unlimited charges")
	var enemy := _enemy(Vector2(480, 350))
	authority.seal(player, enemy, &"paladin_seal", 5.0)
	authority.on_death(player)
	_check(authority.zones.is_empty() and grace.charges == 0 and not grace.is_unlimited() and not enemy.marks.has_mark(&"paladin_seal") and authority.compact_blocker() == "", "death ends zones, the unlimited mode and the seal, and empties Grace")

# --- Égide -------------------------------------------------------------------------

func _check_aegis() -> void:
	_setup()
	var hostile := _hostile(Vector2(460, 350))
	var hits := _hits_on(hostile)
	var start := hostile.global_position
	player.current_sp = player.max_sp
	_check(player.use_kit_skill(_slot(3), player.global_position, null, false) and authority.aegis_active() and is_equal_approx(player.health.shield_hp, player.health.max_hp * 0.25), "Égide grants the shield through HealthState.grant_shield")
	_check(authority.compact_blocker() == "sanctuary_aegis", "an active Égide makes the compact cut ineligible")
	var rng := RandomNumberGenerator.new()
	player.apply_damage(_enemy_request(hostile, player.health.max_hp * 0.6), rng)
	_check(player.is_alive() and player.health.shield_hp == 0.0, "the hit takes the halo and part of the HP")
	_check(kit.get("calls").has("shield_broken") and authority.aegis_pulses == 1 and not authority.aegis_active(), "breaking the halo releases one pulse")
	_check(hits.size() == 1 and bool(hits[0]["secondary"]) and float(hits[0]["actual_damage"]) > 0.0, "the pulse deals light damage through the captured request")
	_check(hostile.global_position.distance_to(player.global_position) > start.distance_to(player.global_position), "the pulse pushes the enemy away")
	_tick(10.0)
	_check(authority.aegis_pulses == 1 and hits.size() == 1, "a broken halo never pulses again at expiry")
	# Expiry path.
	player.health.current_hp = player.health.max_hp
	player.health.clear_shield()
	_check(authority.grant_aegis(player, 50.0, 2.0), "grant again")
	_tick(1.0)
	_check(authority.aegis_active() and player.health.shield_hp == 50.0, "halo holds before expiry")
	_tick(1.0)
	_check(not authority.aegis_active() and player.health.shield_hp == 0.0 and authority.aegis_pulses == 2, "expiry clears the halo and releases one pulse")
	player.health.grant_shield(30.0)
	player.apply_damage(_enemy_request(hostile, player.health.max_hp * 0.3), rng)
	_check(player.is_alive(), "player survives the later break")
	_check(authority.aegis_pulses == 2, "a later shield break without the halo does not pulse")
	player.health.current_hp = player.health.max_hp
	authority.grant_aegis(player, 20.0, 1.0)
	player.health.grant_shield(80.0)
	_tick(1.0)
	_check(player.health.shield_hp == 80.0 and authority.aegis_pulses == 3, "expiry leaves a larger shield of another source")
	_check(not authority.grant_aegis(player, 0.0) and not authority.grant_aegis(player, 10.0, 0.0), "invalid halo is refused")

# --- Selo and light ------------------------------------------------------------------

func _check_seal_and_light() -> void:
	_setup()
	var plain := _enemy(Vector2(480, 350))
	var hostile := _hostile(Vector2(520, 300))
	var sealed := authority.seal(player, plain, &"paladin_seal", 4.0)
	_check(sealed["ok"] and not sealed["forced"] and plain.marks.owner_of(&"paladin_seal") == player.get_instance_id() and authority.is_sealed(plain), "Selo marks the target in ActorMarks with the owner")
	var forced := authority.seal(player, hostile, &"paladin_seal", 4.0)
	_check(forced["ok"] and forced["forced"] and hostile.get("threat").forced_id == "player" and not plain.marks.has_mark(&"paladin_seal") and authority.is_sealed(hostile) and not authority.is_sealed(plain), "Selo forces the target and keeps one seal per owner")
	_check(authority.add_to_seal(2) and hostile.marks.value(&"paladin_seal") == 3, "add_to_seal (Provocar) adds to the seal value")
	_check(authority.compact_blocker() == "sanctuary_seal", "an active seal makes the compact cut ineligible")
	# Light damage on the sealed target is a kit Grace source, once per result, even on retry.
	var grace := authority.grace
	var hits := _hits_on(hostile)
	player.current_sp = player.max_sp
	player.mage_cooldowns[_slot(2)] = 0.0
	player.kit_time = 1.0
	_check(player.use_kit_skill(_slot(2), hostile.global_position, hostile) and hits.size() == 1 and grace.charges == 1 and kit.get("light_gains") == 1, "light damage on the sealed target gains Grace")
	controller._on_enemy_damage_resolved(hits[0])
	_check(grace.charges == 1 and kit.get("light_gains") == 1, "a retried result never gains twice")
	_check(SanctuaryHelpers.is_light_skill(_slot(2)) and not SanctuaryHelpers.is_light_skill(&"slash") and SanctuaryHelpers.is_light_result(hits[0]), "light is the skill element (A2)")
	# A2: light is plain magic damage, no resistance axis.
	var light := player.kit_make_request(plain, _slot(2), 0.0, 200.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var arcane := player.kit_make_request(plain, _slot(0), 0.0, 200.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var rng := RandomNumberGenerator.new()
	var a := plain.apply_damage(light, rng)
	var b := plain.apply_damage(arcane, rng)
	_check(a["damage"] == b["damage"] and a["magic_component"] == b["magic_component"], "light damage equals any magic damage of the same amount (no resistance)")
	hostile.advance_statuses(5.0)
	_tick(0.1)
	_check(not authority.is_sealed(hostile) and authority.sealed_target() == null and authority.marked_target_id == 0 and authority.compact_blocker() == "", "the seal ends with its mark on the gameplay clock")

# --- Snapshot: exact and compact ---------------------------------------------------------

func _find_kit_enemy(copy: PlayerActor) -> CombatActor:
	for child: Node in copy.get_children():
		if child is CombatActor: return child
	return null

func _check_snapshot_formats() -> void:
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty(), "every fragment merges, including sanctuary: " + str(registry.fragment_errors))
	for path: String in ["res://scripts/systems/sanctuary/sanctuary_authority.gd", "res://scripts/systems/sanctuary/sanctuary_zone.gd", "res://scripts/systems/sanctuary/sanctuary_grace.gd", "res://scripts/systems/sanctuary/fixture/sanctuary_fixture_kit.gd"]:
		_check(registry.schemas.has(path), "schema present for " + path)
	_check("res://scripts/systems/sanctuary/snapshot_manifest.json" in SnapshotRegistry.fragment_paths(), "the system fragment is discovered by folder")
	# Exact snapshot with a zone, Grace and a seal on a child enemy.
	_setup()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var standalone := _make_player(navigation)
	standalone.global_position = Vector2(400, 350)
	owned.append(standalone)
	authority = standalone.kit.get("sanctuary")
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = Vector2(480, 350)
	enemy.health.max_hp = 1000.0
	enemy.health.current_hp = 1000.0
	standalone.add_child(enemy)
	authority.open_zone(standalone, {"role": &"votive", "skill_id": _slot(0), "shape": &"circle", "anchor": &"world", "point": Vector2(420, 350), "element": &"fire", "duration": 9.0})
	var zone := authority.zone(&"votive")
	zone.remaining = 6.5
	zone.pulse_remaining = 0.3
	zone.pulses = 2
	authority.grace.charges = 4
	authority.grace.excess_pool = 7.5
	authority.gain({"key": "before_save"}, 1)
	authority.seal(standalone, enemy, &"paladin_seal", 3.0, 2)
	standalone.kit_time = 12.0
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(standalone)["ok"], "barrier acquired")
	var captured := SnapshotRegistry.new().capture(standalone, barrier)
	_check(captured.get("ok", false), "exact capture with an active zone: " + str(captured.get("detail", captured.get("error_code", ""))))
	if captured.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(captured["snapshot"])))
		_check(restored.get("ok", false), "exact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied: SanctuaryAuthority = copy.kit.get("sanctuary")
			var copied_zone := copied.zone(&"votive") if copied != null else null
			var copied_enemy := _find_kit_enemy(copy)
			_check(copied != null and copied_zone != null and copied_zone.remaining == 6.5 and copied_zone.pulse_remaining == 0.3 and copied_zone.pulses == 2 and copied_zone.element == &"fire" and copied_zone.center == Vector2(420, 350) and copied_zone.rules == zone.rules, "exact format preserves the zone")
			_check(copied_zone != null and copied_zone.prototype != null and is_equal_approx(copied_zone.prototype.magic_damage, zone.prototype.magic_damage) and copied_zone.owner_id == copy.get_instance_id(), "exact format preserves the burn prototype and rebinds the owner")
			_check(copied != null and copied.grace.charges == 5 and copied.grace.excess_pool == 7.5 and copied.grace.has_claimed({"key": "before_save"}, copied.grace_family) and copied.gain({"key": "before_save"}, 1) == 0, "exact format preserves Grace and its event memory")
			_check(copied != null and copied_enemy != null and copied.marked_target_id == copied_enemy.get_instance_id() and copied.owner_id == copy.get_instance_id() and copied.is_sealed(copied_enemy) and copied_enemy.marks.value(&"paladin_seal") == 2, "exact format keeps the seal mark with the restored enemy")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	var projection := {"fields": {}, "excluded": {}}
	var compact := SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and compact.get("detail") == "sanctuary_zone:votive", "an active zone makes the compact cut ineligible (A5)")
	authority.end_zone(&"votive")
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and compact.get("detail") == "sanctuary_seal", "an active seal also keeps the exact format")
	enemy.marks.clear()
	authority.grace.begin_unlimited(4.0)
	authority.grace.charges = 7
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("ok", false), "without zone, halo or seal the compact cut is accepted: " + str(compact.get("detail", compact.get("error_code", ""))))
	if compact.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(compact["snapshot"])))
		_check(restored.get("ok", false), "compact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied: SanctuaryAuthority = copy.kit.get("sanctuary")
			_check(copied != null and copied.grace.charges == 7 and copied.grace.is_unlimited() and copied.zones.is_empty() and copied.compact_blocker() == "", "compact format preserves Grace and the unlimited mode on the player")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	barrier.release()

# --- World geometry -------------------------------------------------------------------

func _world_target(world: WorldGeometry, profile: Dictionary, point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}))
	controller.add_child(actor)
	actor.set_process(false)
	actor.health.max_hp = 100000.0
	actor.health.current_hp = 100000.0
	_check(actor.bind_world_geometry(world, point, profile, str(actor.get_instance_id()))["ok"], "world target bound")
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
	var lower := _world_target(world, profile, WorldFixture.point("root", Vector3(60, 0, 150)))
	var upper := _world_target(world, profile, WorldFixture.point("bridge", Vector3(60, 40, 150)))
	var far := _world_target(world, profile, WorldFixture.point("root", Vector3(95, 0, 20)))
	var opened := authority.open_zone(player, {"role": &"votive", "skill_id": _slot(0), "shape": &"circle", "anchor": &"world", "point": WorldFixture.point("root", Vector3(60, 0, 150)), "radius": 100.0})
	_check(opened["ok"] and opened["zone"].area != null, "world zone captures a WorldEffectArea: " + str(opened.get("error_code", "")))
	if not opened["ok"]: return
	var zone: SanctuaryZone = opened["zone"]
	_check(zone.contains(player, lower) and not zone.contains(player, far), "world circle uses the ground-connected distance")
	_check(not zone.contains(player, upper), "height counts: a target on the slab above the centre is outside")
	_check(zone.owner_inside, "the owner standing on the circle is inside")
	var hits := _hits_on(lower)
	var upper_hits := _hits_on(upper)
	zone.pulse_remaining = 0.1
	_tick(0.2)
	_check(hits.size() == 1 and upper_hits.is_empty(), "the world pulse burns only who is inside")
	var column := SanctuaryHelpers.judgment_targets(player, controller.enemies, WorldFixture.point("root", Vector3(60, 0, 150)))
	_check(lower in column and upper not in column and far not in column, "the Juízo column reaches only its floor (A22)")
	var cone := authority.open_zone(player, {"role": &"oath", "skill_id": _slot(0), "shape": &"cone"})
	_check(cone["ok"], "world cone opens on the owner")
	if cone["ok"]:
		player.override_gameplay_ground_facing(Vector3(1, 0, 0), 5.0)
		_check(cone["zone"].contains(player, lower) and not cone["zone"].contains(player, far), "world cone: target in front within radius")
		player.override_gameplay_ground_facing(Vector3(-1, 0, 0), 5.0)
		_check(not cone["zone"].contains(player, lower), "world cone follows the gameplay ground facing")
