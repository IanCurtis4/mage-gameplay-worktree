extends SceneTree
## E09 T1.1 — second-generation seam hooks for C2 owner rules:
## - "damage_multiplier" of ClassKit.before_hit_mitigation (copy, never the original);
## - ClassKit.temporary_stat_sources + PlayerActor.refresh_kit_stats (no heal, no reset).
## Uses the fixture kit (subclassed here) installed over sp_ac; no profile or save.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")

const ZONE_SOURCE: StringName = &"paladin_fixture_zone"

var checks := 0
var failures := 0

class HooksKit extends "res://scripts/classes/fixture/fixture_kit.gd":
	var next_multiplier: Variant = null
	var defense_bonus := 0.0
	var seen_request: DamageRequest = null
	var seen_result: Dictionary = {}

	func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
		var answer := super(player, hit)
		if next_multiplier != null: answer["damage_multiplier"] = next_multiplier
		return answer

	func after_hit_mitigation(player: PlayerActor, hit: Dictionary, result: Dictionary) -> void:
		super(player, hit, result)
		seen_request = hit.get("request") as DamageRequest
		seen_result = result.duplicate()

	func temporary_stat_sources(_player: PlayerActor) -> Array[Dictionary]:
		if defense_bonus <= 0.0: return []
		return [{"source_id": &"paladin_fixture_zone", "label": "Zona de teste", "increased": {&"physical_defense": defense_bonus, &"magic_defense": defense_bonus}}]

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	_check(ClassKitRegistry.install_fixture(&"sp_ac", HooksKit.new(&"sp_ac")), "hooks fixture installs over sp_ac")
	_check(ClassKit.new().temporary_stat_sources(null).is_empty(), "default kit has no temporary stat sources")
	var player := _kit_player(&"sp_ac")
	var kit := player.kit
	_check(kit != null and kit.get_script() == HooksKit, "player carries the hooks fixture kit")
	var source := _enemy(player.global_position + Vector2(60, 0), player.stat_breakdown)
	_check_damage_multiplier(player, kit, source)
	_check_stat_sources(player, kit)
	source.free()
	player.free()
	ClassKitRegistry.clear_fixtures()
	print("E09 kit seam hooks v2: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixtures ----------------------------------------------------------------------

func _kit_player(evolution: StringName) -> PlayerActor:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", evolution)
	snapshot.skill_ranks = {}
	for skill: StringName in ClassKitRegistry.skill_ids(evolution): snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [ClassKitRegistry.skill_ids(evolution)[0], ClassKitRegistry.skill_ids(evolution)[2], ClassKitRegistry.skill_ids(evolution)[3], null, null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("kit-seam-v2-" + String(evolution), snapshot))
	player.global_position = Vector2(400, 350)
	return player

func _enemy(at: Vector2, stats: StatBreakdown) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, stats, 18.0)
	enemy.global_position = at
	return enemy

func _hit(player: PlayerActor, source: CombatActor, amount: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	return request

## One hit on a full-HP player with a fixed seed; returns the result.
func _strike(player: PlayerActor, kit: ClassKit, request: DamageRequest, multiplier: Variant) -> Dictionary:
	player.health.current_hp = player.health.max_hp
	player.health.shield_hp = 0.0
	kit.set("next_multiplier", multiplier)
	kit.set("seen_request", null)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var result := player.apply_damage(request, rng)
	kit.set("next_multiplier", null)
	return result

# --- Damage multiplier -------------------------------------------------------------

func _check_damage_multiplier(player: PlayerActor, kit: ClassKit, source: CombatActor) -> void:
	player.character_animation.state.face(Vector2.RIGHT)
	var baseline_request := _hit(player, source, 60.0)
	var baseline := _strike(player, kit, baseline_request, null)
	var base_damage := float(baseline.get("actual_damage", 0.0))
	_check(bool(baseline.get("landed", false)) and base_damage > 0.0 and not baseline.has("kit_damage_multiplier"), "baseline hit lands without a kit multiplier")
	_check(kit.get("seen_request") == baseline_request, "without multiplier the original request reaches after_hit_mitigation")

	var request := _hit(player, source, 60.0)
	var halved := _strike(player, kit, request, 0.5)
	var halved_damage := float(halved.get("actual_damage", 0.0))
	_check(bool(halved.get("landed", false)) and halved_damage > 0.0 and halved_damage < base_damage, "multiplier 0.5 reduces the damage taken")
	_check(is_equal_approx(float(halved.get("kit_damage_multiplier", 0.0)), 0.5), "result records kit_damage_multiplier")
	_check(is_equal_approx(request.damage_dealt_multiplier, 1.0) and is_equal_approx(request.physical_damage, 60.0), "original request is never mutated")
	_check(kit.get("seen_request") == request, "after_hit_mitigation receives the original request")
	_check(is_equal_approx(float((kit.get("seen_result") as Dictionary).get("kit_damage_multiplier", 0.0)), 0.5), "after_hit_mitigation sees the recorded multiplier")
	var again := _strike(player, kit, request, 0.5)
	_check(is_equal_approx(float(again.get("actual_damage", -1.0)), halved_damage) and is_equal_approx(request.damage_dealt_multiplier, 1.0), "reusing the same request gives the same damage (no accumulation)")

	var doubled := _strike(player, kit, _hit(player, source, 60.0), 2.0)
	_check(float(doubled.get("actual_damage", 0.0)) > base_damage and is_equal_approx(float(doubled.get("kit_damage_multiplier", 0.0)), 2.0), "multiplier above one increases the damage taken")
	var zero := _strike(player, kit, _hit(player, source, 60.0), 0.0)
	_check(is_zero_approx(float(zero.get("kit_damage_multiplier", -1.0))) and float(zero.get("actual_damage", 0.0)) <= halved_damage, "multiplier zero is accepted and recorded")
	var identity := _strike(player, kit, _hit(player, source, 60.0), 1.0)
	_check(is_equal_approx(float(identity.get("actual_damage", 0.0)), base_damage) and not identity.has("kit_damage_multiplier"), "multiplier 1.0 keeps the current path and records nothing")

	for invalid: Variant in [NAN, INF, -INF, -0.5, "0.5", null, true]:
		var raw := _hit(player, source, 60.0)
		var ignored := _strike(player, kit, raw, invalid)
		_check(is_equal_approx(float(ignored.get("actual_damage", 0.0)), base_damage) and not ignored.has("kit_damage_multiplier") and is_equal_approx(raw.damage_dealt_multiplier, 1.0), "invalid multiplier is ignored: %s" % str(invalid))

	kit.set("cancel_next_hit", true)
	var cancel_request := _hit(player, source, 60.0)
	var cancelled := _strike(player, kit, cancel_request, 0.5)
	_check(bool(cancelled.get("cancelled", false)) and not bool(cancelled.get("landed", true)) and player.health.current_hp == player.health.max_hp, "cancel wins over the multiplier")
	_check(not cancelled.has("kit_damage_multiplier") and kit.get("seen_request") == null and is_equal_approx(cancel_request.damage_dealt_multiplier, 1.0), "a cancelled hit records no multiplier and skips later steps")

	var secondary := _hit(player, source, 60.0)
	secondary.is_secondary = true
	var tick := _strike(player, kit, secondary, 0.5)
	_check(not tick.has("kit_damage_multiplier") and is_equal_approx(secondary.damage_dealt_multiplier, 1.0), "secondary ticks skip the kit multiplier")

# --- Temporary stat sources --------------------------------------------------------

func _has_source(player: PlayerActor, id: StringName) -> bool:
	for entry: Dictionary in player.stat_breakdown.sources():
		if StringName(entry.get("source_id", &"")) == id: return true
	return false

func _check_stat_sources(player: PlayerActor, kit: ClassKit) -> void:
	var base_physical := player.stat_breakdown.value(&"physical_defense")
	var base_magic := player.stat_breakdown.value(&"magic_defense")
	var base_values := player.stat_breakdown.values()
	_check(not _has_source(player, ZONE_SOURCE), "no kit source before entering the zone")
	# Deficits and cooldown that a refresh must keep.
	player.current_sp = player.max_sp
	_check(player.use_kit_skill(&"paladin_oath", player.global_position), "kit cast puts a skill on cooldown")
	var cooldown := player.skill_cooldown(&"paladin_oath")
	player.health.current_hp = player.health.max_hp - 40.0
	var hp_deficit := player.health.max_hp - player.health.current_hp
	var sp_deficit := player.sp_deficit()
	_check(cooldown > 0.0 and sp_deficit > 0.0 and hp_deficit > 0.0, "player has HP, SP and cooldown deficits before refresh")
	var unchanged := player.stat_breakdown
	player.refresh_kit_stats()
	_check(player.stat_breakdown.values() == base_values and player.stat_breakdown != unchanged, "refresh without kit sources recomposes the same values")

	kit.set("defense_bonus", 0.25)
	_check(not _has_source(player, ZONE_SOURCE), "a kit source waits for refresh_kit_stats")
	player.refresh_kit_stats()
	_check(_has_source(player, ZONE_SOURCE), "kit DEF source appears in the breakdown")
	_check(player.temporary_stat_sources().any(func(entry: Dictionary) -> bool: return entry.get("source_id") == ZONE_SOURCE), "kit source joins PlayerActor.temporary_stat_sources")
	_check(player.stat_breakdown.value(&"physical_defense") > base_physical and player.stat_breakdown.value(&"magic_defense") > base_magic, "kit source raises physical and magic defense")
	var inside := player.stat_breakdown.values()
	_check(is_equal_approx(player.health.max_hp - player.health.current_hp, hp_deficit) and is_equal_approx(player.sp_deficit(), sp_deficit) and is_equal_approx(player.skill_cooldown(&"paladin_oath"), cooldown), "refresh does not heal, refill SP or reset cooldowns")
	player.refresh_kit_stats()
	player.refresh_kit_stats()
	_check(player.stat_breakdown.values() == inside and is_equal_approx(player.health.max_hp - player.health.current_hp, hp_deficit) and is_equal_approx(player.sp_deficit(), sp_deficit), "refresh is idempotent")

	kit.set("defense_bonus", 0.0)
	player.refresh_kit_stats()
	_check(not _has_source(player, ZONE_SOURCE), "kit source disappears after leaving the zone")
	_check(player.stat_breakdown.values() == base_values, "leaving the zone restores the base values")
	_check(is_equal_approx(player.health.max_hp - player.health.current_hp, hp_deficit) and is_equal_approx(player.sp_deficit(), sp_deficit) and is_equal_approx(player.skill_cooldown(&"paladin_oath"), cooldown), "leaving the zone keeps every deficit and cooldown")

	# The anchor/fury path rebuilds with the kit source too (one composition).
	kit.set("defense_bonus", 0.25)
	player.apply_run_modifiers(player.run_state)
	_check(_has_source(player, ZONE_SOURCE), "the shared rebuild path keeps the kit source")
	kit.set("defense_bonus", 0.0)
	player.refresh_kit_stats()
