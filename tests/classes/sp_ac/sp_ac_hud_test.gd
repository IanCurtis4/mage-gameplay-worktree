extends SceneTree
## E12 H2 (contract docs/epics/e12_contract.md §5) — HUD state of the Paladino (`sp_ac`).
## - Integrated combat against the real boss of the K1 review (both review builds of
##   scripts/classes/sp_ac/review_builds.json, rotation of sp_ac_boss_combat_test): on
##   every tick the DTO validates by KitHudState, PlayerActor.kit_hud_state returns it,
##   A6 holds (ready == false iff can_cast refuses the real cast descriptor, same code),
##   Grace equals grace.charges, zones and the Seal follow the authority, only living
##   targets are marked, and hud_state leaves the whole kit graph unchanged.
## - Pause in the middle of the fight, death and return.
## - Exact snapshot (SnapshotRegistry) identical before and after 100 reads.
## - World zones: the Oath cone in the expedition world carries the owner's ground point
##   and ground facing (needs the F1 fixture: tools/verify.ps1 -F1Fixture).
## Fixture profiles only; nothing is written to disk.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const F1Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const BUILDS_PATH := "res://scripts/classes/sp_ac/review_builds.json"
const STEP := 0.05
const DURATION := 30.0
const DEATH_AT := 22.0
const PAUSE_AT := 8.0
const BOSS_HP := 6000.0
const ATTRIBUTES: Dictionary[StringName, int] = {&"vit": 50, &"str": 36, &"int": 15, &"dex": 10, &"agi": 5}
const OATH := &"paladin_oath"
const HOUR := &"paladin_oath_hour"
const EXPECTED_SKILLS: Array[StringName] = [&"paladin_oath"]

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	KitHudState.reset_reports()
	var file := FileAccess.open(BUILDS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_check(parsed is Dictionary and parsed.get("builds", []).size() == 2, "two review builds to fight with")
	if parsed is Dictionary:
		for build: Variant in parsed["builds"]: _fight(build)
	_check_exact_snapshot()
	_check_world_zone()
	_check(KitHudState.reported_warnings().is_empty(), "no invalid HUD DTO was reported: %s" % str(KitHudState.reported_warnings()))
	paused = false
	print("E12 H2 sp_ac HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Integrated combat --------------------------------------------------------------------------

func _fight(build: Dictionary) -> void:
	var label := String(build["id"])
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1400, 900), [], 20.0)
	var controller := Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	controller.navigation = navigation
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_level = ProgressionRules.MAX_BASE_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.attribute_allocations = ATTRIBUTES.duplicate()
	snapshot.evolution_id = &"sp_ac"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"sp_ac")
	snapshot.skill_ranks = {}
	for skill: Variant in build["base_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["base_ranks"][skill])
	for skill: Variant in build["evolution_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["evolution_ranks"][skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	var actives: Array[Variant] = []
	for skill: Variant in build["shortcuts"]:
		if actives.size() < 5 and StringName(skill) in ClassKitRegistry.skill_ids(&"sp_ac"): actives.append(StringName(skill))
	snapshot.active_slots = actives
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("sp-ac-hud-" + label, snapshot))
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(500, 450)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 41
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	var kit := player.kit
	_check(kit != null and kit.get_script().resource_path == "res://scripts/classes/sp_ac/sp_ac_kit.gd", "%s: the production Paladino kit is attached" % label)
	if kit == null:
		controller.free()
		return
	var authority: SanctuaryAuthority = kit.get("sanctuary")
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "h2_boss_" + label
	occurrence.mob_base_id = &"forest_ancient_warden"
	occurrence.category_id = &"boss"
	occurrence.origin_id = &"trial_stage_4"
	var boss := EnemyActor.new()
	var configured := boss.configure_occurrence(occurrence, player.run_state.effect_catalog().mob_catalog(), navigation, player)
	_check(configured.get("ok", false), "%s: boss occurrence configures" % label)
	if not configured.get("ok", false):
		boss.free()
		controller.free()
		return
	boss.global_position = player.global_position + Vector2(70, 0)
	boss.attack_requested.connect(controller._on_enemy_attack_requested)
	boss.mob_skill_requested.connect(controller._on_mob_skill_requested)
	boss.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	boss.status_damage_requested.connect(controller._on_attack_requested)
	controller.add_child(boss)
	controller.enemies.append(boss)
	boss.set_process(false)
	boss.health.max_hp = BOSS_HP
	boss.health.current_hp = BOSS_HP
	var watch := _new_watch()
	var time := 0.0
	var paused_once := false
	var died := false
	player.target = boss
	while time < DURATION and boss.is_alive():
		if not died and time >= DEATH_AT:
			died = true
			_check_death_and_return(label, player, kit, authority, boss, controller, watch)
		if not player.is_alive(): break
		var facing := player.global_position.direction_to(boss.global_position)
		if not facing.is_zero_approx(): player.character_animation.state.face(facing)
		_rotation(player, boss, authority, kit)
		boss._process(STEP)
		player._process(STEP)
		_observe(player, kit, authority, boss, watch)
		if not paused_once and time >= PAUSE_AT:
			paused_once = true
			_check_pause(label, player, kit, authority, boss, watch)
		time += STEP
	print("%s: %.1fs, %d ticks, reasons %s, max grace %d, zones %s, seal ticks %d, unlimited ticks %d" % [label, time, int(watch["ticks"]), watch["reasons"], int(watch["max_grace"]), watch["shapes"], int(watch["seal_ticks"]), int(watch["unlimited_ticks"])])
	_report(label, watch)
	_check(died, "%s: the fight reached the death and return step" % label)
	_check(watch["reasons"].has(&"paladin_hour_active"), "%s: the Hora made the Juramento not ready in combat (A6 observed refusing)" % label)
	_check(int(watch["ready_ticks"]) > 0, "%s: the Juramento is also ready in combat" % label)
	_check(watch["shapes"].has(&"cone") and watch["shapes"].has(&"circle"), "%s: the zone shows the cone and the circle of the Hora: %s" % [label, watch["shapes"]])
	_check(int(watch["seal_ticks"]) > 0 and int(watch["unlimited_ticks"]) > 0, "%s: the Seal badge and the unlimited Grace appear in combat" % label)
	controller.free()

## Fixed priority rotation of sp_ac_boss_combat_test (K1 review).
func _rotation(player: PlayerActor, boss: CombatActor, authority: SanctuaryAuthority, kit: ClassKit) -> void:
	if player.has_active_cast(): return
	var hour: bool = kit.call(&"hour_active")
	var order: Array[StringName] = []
	if authority.zone(&"oath") == null: order.append(OATH)
	if not authority.is_sealed(boss): order.append(&"paladin_condemned_seal")
	if authority.zone(&"oath") != null: order.append(HOUR)
	if player.health.current_hp < player.health.max_hp * 0.6: order.append(&"paladin_oath_aegis")
	if authority.grace.charges >= 3 or hour: order.append(&"paladin_consecrated_impact")
	for skill: StringName in order:
		if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): continue
		var target := boss if ClassKitRegistry.skill_definition(skill).targeting == SkillDefinition.Targeting.SINGLE_TARGET else null
		if player.use_kit_skill(skill, boss.global_position if target != null else player.global_position, target): return
	for base: StringName in [&"perseverance", &"provoke"]:
		if player.skill_rank(base) <= 0 or player.skill_cooldown(base) > 0.0 or player.current_sp < player.skill_cost(base) + 30.0: continue
		if base == &"provoke": player.note_base_commit(base, boss.global_position, boss)
		var used := player.use_perseverance() if base == &"perseverance" else (authority.is_sealed(boss) and player.use_provoke(boss))
		player.clear_base_commit_note()
		if used: return

# --- Per-tick invariants ---------------------------------------------------------------------------

func _new_watch() -> Dictionary:
	return {"ticks": 0, "invalid": 0, "invalid_first": "", "mismatch": 0, "impure": 0, "impure_first": "", "a6": 0, "a6_first": "", "authority": 0, "authority_first": "", "reasons": {}, "ready_ticks": 0, "max_grace": 0, "shapes": {}, "seal_ticks": 0, "unlimited_ticks": 0, "aegis_ticks": 0, "dead_marks": 0}

## One HUD read with every invariant of §5; failures are counted, the first one kept.
func _observe(player: PlayerActor, kit: ClassKit, authority: SanctuaryAuthority, boss: CombatActor, watch: Dictionary) -> void:
	watch["ticks"] = int(watch["ticks"]) + 1
	var before: Variant = _graph(kit)
	var state := kit.hud_state(player)
	var after: Variant = _graph(kit)
	if before != after:
		watch["impure"] = int(watch["impure"]) + 1
		if String(watch["impure_first"]).is_empty(): watch["impure_first"] = "tick %d" % int(watch["ticks"])
	var result := KitHudState.validate(state, kit)
	if not result["ok"]:
		watch["invalid"] = int(watch["invalid"]) + 1
		if String(watch["invalid_first"]).is_empty(): watch["invalid_first"] = str(result)
		return
	if player.kit_hud_state() != state: watch["mismatch"] = int(watch["mismatch"]) + 1
	_check_a6(player, kit, boss, state, watch)
	var problem := _authority_problem(player, kit, authority, state, watch)
	if not problem.is_empty():
		watch["authority"] = int(watch["authority"]) + 1
		if String(watch["authority_first"]).is_empty(): watch["authority_first"] = "tick %d: %s" % [int(watch["ticks"]), problem]
	for mark: Dictionary in state.get("target_marks", []):
		var actor := instance_from_id(int(mark["target_id"])) as CombatActor
		if not is_instance_valid(actor) or not actor.is_alive(): watch["dead_marks"] = int(watch["dead_marks"]) + 1

## A6: for every skill in `skills`, ready is false iff the kit's can_cast refuses the real
## cast descriptor of the flat pipeline (PlayerActor._kit_cast_legacy), with the same code.
func _check_a6(player: PlayerActor, kit: ClassKit, boss: CombatActor, state: Dictionary, watch: Dictionary) -> void:
	var skills: Dictionary = state.get("skills", {})
	var keys: Array = skills.keys()
	keys.sort()
	var expected: Array = EXPECTED_SKILLS.duplicate()
	expected.sort()
	if keys != expected:
		watch["a6"] = int(watch["a6"]) + 1
		if String(watch["a6_first"]).is_empty(): watch["a6_first"] = "skills %s" % str(keys)
		return
	for skill: StringName in skills:
		var entry: Dictionary = skills[skill]
		var answer := kit.can_cast(player, player._kit_cast_legacy(skill, boss.global_position, boss))
		var refused := not bool(answer.get("ok", false))
		var code := StringName(answer.get("error_code", &"")) if refused else &""
		if bool(entry["ready"]) == refused or StringName(entry.get("reason", &"")) != code:
			watch["a6"] = int(watch["a6"]) + 1
			if String(watch["a6_first"]).is_empty(): watch["a6_first"] = "%s: hud %s vs can_cast %s" % [skill, str(entry), str(answer)]
		if refused: watch["reasons"][code] = int(watch["reasons"].get(code, 0)) + 1
		else: watch["ready_ticks"] = int(watch["ready_ticks"]) + 1

## Grace, zones, deadlines and the Seal of the DTO against the SanctuaryAuthority and the kit.
func _authority_problem(player: PlayerActor, kit: ClassKit, authority: SanctuaryAuthority, state: Dictionary, watch: Dictionary) -> String:
	var resources := _by_id(state.get("resources", []))
	if not resources.has(&"sanctuary_grace"): return "no Grace resource"
	var grace: Dictionary = resources[&"sanctuary_grace"]
	if int(grace["value"]) != authority.grace.charges or int(grace["max"]) != authority.grace.cap: return "Grace %s vs %d/%d" % [str(grace), authority.grace.charges, authority.grace.cap]
	if bool(grace.get("unlimited", false)) != authority.grace.is_unlimited(): return "unlimited flag"
	if authority.grace.is_unlimited():
		watch["unlimited_ticks"] = int(watch["unlimited_ticks"]) + 1
		if float(grace["remaining"]) != authority.grace.unlimited_remaining: return "unlimited deadline"
	watch["max_grace"] = maxi(int(watch["max_grace"]), int(grace["value"]))
	var oath := authority.zone(&"oath")
	var zones: Array = state.get("zones", [])
	if (oath == null) != zones.is_empty() or zones.size() > 1: return "zones %d vs oath %s" % [zones.size(), oath != null]
	if oath != null:
		var zone: Dictionary = zones[0]
		watch["shapes"][zone["shape"]] = true
		if zone["shape"] != oath.shape or float(zone["radius"]) != oath.radius or float(zone["remaining"]) != oath.remaining or zone["space"] != &"flat": return "zone %s" % str(zone)
		if zone["center"] != Vector3(player.global_position.x, player.global_position.y, 0.0): return "cone not on the owner"
		if oath.shape == &"cone" and (float(zone["half_angle"]) != oath.half_angle or not (zone["facing"] as Vector3).is_equal_approx(Vector3(player.gameplay_facing().x, player.gameplay_facing().y, 0.0).normalized())): return "cone facing"
		if not resources.has(&"paladin_oath") or float(resources[&"paladin_oath"]["remaining"]) != oath.remaining: return "Oath deadline"
	elif resources.has(&"paladin_oath"): return "Oath deadline without a zone"
	if resources.has(&"paladin_aegis") != authority.aegis_active(): return "Égide deadline"
	if authority.aegis_active():
		watch["aegis_ticks"] = int(watch["aegis_ticks"]) + 1
		if float(resources[&"paladin_aegis"]["remaining"]) != authority.aegis_remaining: return "Égide remaining"
	if resources.has(&"paladin_hour") != bool(kit.call(&"hour_active")): return "Hora deadline"
	if resources.has(&"paladin_hour") and float(resources[&"paladin_hour"]["remaining"]) != float(kit.get("hour_remaining")): return "Hora remaining"
	var marks: Array = state.get("target_marks", [])
	var sealed := authority.sealed_target()
	if sealed != null and sealed.is_alive():
		watch["seal_ticks"] = int(watch["seal_ticks"]) + 1
		if marks.size() != 1 or int(marks[0]["target_id"]) != sealed.get_instance_id() or marks[0]["key"] != &"paladin_seal" or marks[0]["kind"] != &"badge": return "Seal mark %s" % str(marks)
	elif not marks.is_empty(): return "mark without a living sealed enemy"
	return ""

func _report(label: String, watch: Dictionary) -> void:
	var ticks := int(watch["ticks"])
	_check(ticks > 100, "%s: the integrated combat ran (%d HUD reads)" % [label, ticks])
	_check(int(watch["invalid"]) == 0, "%s: the DTO validates by KitHudState on every tick (%d invalid; first %s)" % [label, int(watch["invalid"]), watch["invalid_first"]])
	_check(int(watch["mismatch"]) == 0, "%s: PlayerActor.kit_hud_state returns the kit DTO on every tick" % label)
	_check(int(watch["impure"]) == 0, "%s: hud_state never changes the kit graph (%d impure reads; first %s)" % [label, int(watch["impure"]), watch["impure_first"]])
	_check(int(watch["a6"]) == 0, "%s: A6 on every tick: ready is false iff can_cast refuses, same code (%d breaks; first %s)" % [label, int(watch["a6"]), watch["a6_first"]])
	_check(int(watch["authority"]) == 0, "%s: Grace, zones, deadlines and Seal follow the authority (%d breaks; first %s)" % [label, int(watch["authority"]), watch["authority_first"]])
	_check(int(watch["dead_marks"]) == 0, "%s: only living actors are marked (A7)" % label)

# --- Pause, death and return ------------------------------------------------------------------------

func _check_pause(label: String, player: PlayerActor, kit: ClassKit, authority: SanctuaryAuthority, boss: CombatActor, watch: Dictionary) -> void:
	paused = true
	var before := player.kit_hud_state()
	var graph: Variant = _graph(kit)
	for _step: int in 20:
		player._process(STEP)
		_observe(player, kit, authority, boss, watch)
	var after := player.kit_hud_state()
	_check(not before.is_empty() and before == after and _graph(kit) == graph, "%s: with the tree paused the DTO is readable and frozen" % label)
	paused = false

func _check_death_and_return(label: String, player: PlayerActor, kit: ClassKit, authority: SanctuaryAuthority, boss: CombatActor, controller: Controller, watch: Dictionary) -> void:
	var request := DamageRequest.new()
	request.source_id = boss.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = 1000000.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.context = player.run_state.effect_ledger.new_root(boss.get_instance_id(), false, "", false, {})
	player.health.clear_shield()
	player.apply_damage(request, controller.rng)
	_check(not player.is_alive(), "%s: the Paladino dies" % label)
	var dead := player.kit_hud_state()
	_check(KitHudState.validate(dead, kit)["ok"] and not dead.is_empty(), "%s: dead, the DTO still validates" % label)
	var grace: Dictionary = _by_id(dead.get("resources", [])).get(&"sanctuary_grace", {})
	_check(int(grace.get("value", -1)) == authority.grace.charges and authority.grace.charges == 0 and not bool(grace.get("unlimited", false)), "%s: dead, Grace is the authority's (0, no ∞)" % label)
	_check((dead.get("zones", []) as Array).is_empty() and (dead.get("target_marks", []) as Array).is_empty() and (dead["resources"] as Array).size() == 1, "%s: dead, no zone, no Seal, no deadline" % label)
	_observe(player, kit, authority, boss, watch)
	player.health.reset(player.stat_breakdown)
	player._process(STEP)
	_check(player.is_alive(), "%s: the Paladino returns" % label)
	var back := player.kit_hud_state()
	_check(KitHudState.validate(back, kit)["ok"] and int(_by_id(back["resources"])[&"sanctuary_grace"]["value"]) == authority.grace.charges, "%s: after the return the DTO follows the authority" % label)
	_observe(player, kit, authority, boss, watch)

# --- Exact snapshot ---------------------------------------------------------------------------------

## The exact snapshot of a Paladino with the Oath circle, the Hora, unlimited Grace, the
## Égide and a Seal is byte-identical before and after 100 HUD reads.
func _check_exact_snapshot() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := _standalone(navigation)
	var kit := player.kit
	var authority: SanctuaryAuthority = kit.get("sanctuary")
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = Vector2(480, 350)
	enemy.health.max_hp = 1000.0
	enemy.health.current_hp = 1000.0
	player.add_child(enemy)
	var cast := {"skill_id": OATH, "rank": 5, "element": &"light", "world": false, "anchor": null, "point": player.global_position, "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": [enemy]}
	kit.resolve_cast(player, cast)
	cast["skill_id"] = HOUR
	kit.resolve_cast(player, cast)
	authority.grace.charges = 7
	authority.grant_aegis(player, 50.0)
	authority.seal(player, enemy, &"paladin_seal", 4.0, 2)
	player.kit_time = 9.0
	var state := player.kit_hud_state()
	_check(KitHudState.validate(state, kit)["ok"] and _by_id(state["resources"]).has(&"paladin_aegis") and _by_id(state["resources"]).has(&"paladin_hour") and (state["target_marks"] as Array).size() == 1 and bool(_by_id(state["resources"])[&"sanctuary_grace"].get("unlimited", false)) and int(_by_id(state["resources"])[&"sanctuary_grace"]["value"]) == 7, "rich state: unlimited Grace 7, Oath circle, Égide, Hora and Seal in the DTO")
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(player)["ok"], "barrier acquired")
	var first := SnapshotRegistry.new().capture(player, barrier)
	for _index: int in 100: kit.hud_state(player)
	var second := SnapshotRegistry.new().capture(player, barrier)
	_check(first.get("ok", false) and second.get("ok", false), "exact captures succeed: %s" % str(first.get("detail", first.get("error_code", ""))))
	if first.get("ok", false) and second.get("ok", false):
		_check(var_to_bytes(first["snapshot"]) == var_to_bytes(second["snapshot"]), "the exact snapshot (SanctuaryAuthority, zone, Grace included) is identical after 100 HUD reads")
	barrier.release()
	player.free()

# --- World zone -------------------------------------------------------------------------------------

func _check_world_zone() -> void:
	if not F1Fixture.sources_current():
		_check(false, "F1 world fixture is current (run with -F1Fixture)")
		return
	var input := F1Fixture.make()
	var built := ExpeditionAssembler.build(input)
	_check(built["ok"], "world fixture builds")
	if not built["ok"]: return
	var geometry := WorldGeometry.new()
	geometry.configure(built["data"]["manifest"], "sample")
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := _standalone(navigation)
	root.add_child(player)
	_check(player.bind_world_geometry(geometry, F1Fixture.point("root", Vector3(50, 0, 150)), input.traversal.to_data(), "paladin")["ok"], "the Paladino binds the world")
	player.set_process(false)
	var kit := player.kit
	var cast := {"skill_id": OATH, "rank": 1, "element": &"light", "world": true, "anchor": player.world_point(), "point": Vector2.ZERO, "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": []}
	_check(kit.resolve_cast(player, cast), "the Oath opens in the world")
	var state := player.kit_hud_state()
	_check(KitHudState.validate(state, kit)["ok"], "world DTO validates")
	var zones: Array = state.get("zones", [])
	_check(zones.size() == 1, "one world zone")
	if zones.size() == 1:
		var zone: Dictionary = zones[0]
		var facing := player.gameplay_ground_facing()
		facing.y = 0.0
		_check(zone["space"] == &"world" and zone["shape"] == &"cone" and (zone["center"] as Vector3).is_equal_approx(player.world_point().position), "the world cone sits on the owner's ground point: %s" % str(zone))
		_check((zone["facing"] as Vector3).is_equal_approx(facing.normalized()) and is_zero_approx((zone["facing"] as Vector3).y), "the world cone faces the owner's ground facing")
	cast["skill_id"] = HOUR
	_check(kit.resolve_cast(player, cast), "the Hora turns the world cone into a circle")
	state = player.kit_hud_state()
	_check(KitHudState.validate(state, kit)["ok"] and (state["zones"] as Array).size() == 1 and state["zones"][0]["shape"] == &"circle" and not state["zones"][0].has("half_angle"), "world circle of the Hora validates without a half-angle")
	root.remove_child(player)
	player.free()

# --- Helpers ------------------------------------------------------------------------------------------

func _standalone(navigation: ArenaNavigation) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"sp_ac"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"sp_ac")
	snapshot.skill_ranks = {&"provoke": 1}
	for skill: StringName in ClassKitRegistry.skill_ids(&"sp_ac"): snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [OATH, &"paladin_consecrated_impact", &"paladin_oath_aegis", &"paladin_condemned_seal", HOUR]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("sp-ac-hud-standalone", snapshot))
	player.global_position = Vector2(400, 350)
	return player

func _by_id(resources: Array) -> Dictionary:
	var found := {}
	for resource: Dictionary in resources: found[resource["id"]] = resource
	return found

## Every script variable of the kit graph (kit, authorities, zones, Grace, prototypes),
## recursively; nodes by instance ID. Stricter than the snapshot fragments: it includes
## the omitted caches.
func _graph(value: Variant, seen: Dictionary = {}, depth: int = 0) -> Variant:
	if depth > 16: return "<deep>"
	match typeof(value):
		TYPE_OBJECT:
			if value == null: return null
			if not is_instance_valid(value): return "<freed>"
			var object: Object = value
			if object is Node: return "node:%d" % object.get_instance_id()
			if object is Resource and not (object as Resource).resource_path.is_empty(): return "res:" + (object as Resource).resource_path
			var id := object.get_instance_id()
			if seen.has(id): return "ref:%d" % id
			seen[id] = true
			var script: Script = object.get_script()
			var out := {"@class": object.get_class(), "@script": script.resource_path if script != null else ""}
			for property: Dictionary in object.get_property_list():
				if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE: out[property["name"]] = _graph(object.get(property["name"]), seen, depth + 1)
			return out
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value: items.append(_graph(item, seen, depth + 1))
			return items
		TYPE_DICTIONARY:
			var entries := {}
			for key: Variant in value: entries[_graph(key, seen, depth + 1) if typeof(key) == TYPE_OBJECT else key] = _graph(value[key], seen, depth + 1)
			return entries
	return value
