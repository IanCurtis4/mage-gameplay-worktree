extends SceneTree
## E12 H2 (contract docs/epics/e12_contract.md §5) — HUD state of the Taumaturgo (`mg_ac`).
## - Integrated combat against the real boss of the K2 review (both review builds of
##   scripts/classes/mg_ac/review_builds.json, rotation of mg_ac_boss_combat_test): on
##   every tick the DTO validates by KitHudState, PlayerActor.kit_hud_state returns it,
##   A6 holds for the Círculo and the Mudança de Altar (ready == false iff can_cast
##   refuses the real cast descriptor, same code), Grace equals grace.charges, the votive
##   zone and its deadline carry the zone's current element (limitation 1 of K2), and
##   hud_state leaves the whole kit graph unchanged.
## - Pause in the middle of the fight, death and return.
## - Exact snapshot (SnapshotRegistry) identical before and after 100 reads.
## - World zones: the votive circle in the expedition world sits on its ground anchor
##   (needs the F1 fixture: tools/verify.ps1 -F1Fixture).
## Fixture profiles only; nothing is written to disk.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const F1Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const BUILDS_PATH := "res://scripts/classes/mg_ac/review_builds.json"
const STEP := 0.05
const DURATION := 30.0
const DEATH_AT := 24.0
const PAUSE_AT := 8.0
const BOSS_HP := 24000.0
const ATTRIBUTES: Dictionary[StringName, int] = {&"int": 50, &"vit": 36, &"dex": 20, &"agi": 5, &"str": 5}
const SPELL_ELEMENTS := {&"fireball": &"fire", &"ice_spear": &"ice", &"lightning": &"lightning"}
const CIRCLE := &"thaumaturge_votive_circle"
const ALTAR := &"thaumaturge_altar_shift"
const DAWN := &"thaumaturge_convergent_dawn"
const EXPECTED_SKILLS: Array[StringName] = [&"thaumaturge_votive_circle", &"thaumaturge_altar_shift"]

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
	print("E12 H2 mg_ac HUD: %d checks, %d failures" % [checks, failures])
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
	snapshot.base_class_id = &"mage"
	snapshot.attribute_allocations = ATTRIBUTES.duplicate()
	snapshot.evolution_id = &"mg_ac"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"mg_ac")
	snapshot.skill_ranks = {}
	for skill: Variant in build["base_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["base_ranks"][skill])
	for skill: Variant in build["evolution_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["evolution_ranks"][skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	var actives: Array[Variant] = []
	for skill: Variant in build["shortcuts"]:
		if actives.size() < 5 and StringName(skill) in ClassKitRegistry.skill_ids(&"mg_ac"): actives.append(StringName(skill))
	snapshot.active_slots = actives
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("mg-ac-hud-" + label, snapshot))
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(500, 450)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 43
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	player.mage_projectile_requested.connect(controller._on_mage_projectile_requested)
	var kit := player.kit
	_check(kit != null and kit.get_script().resource_path == "res://scripts/classes/mg_ac/mg_ac_kit.gd", "%s: the production Taumaturgo kit is attached" % label)
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
	boss.global_position = player.global_position + Vector2(110, 0)
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
		_rotation(controller, player, boss, authority, kit)
		boss._process(STEP)
		player._process(STEP)
		for node: Node in get_nodes_in_group("player_projectiles"):
			if is_instance_valid(node) and node.has_method(&"_process"): node.call(&"_process", STEP)
		_observe(player, kit, authority, boss, watch)
		if not paused_once and time >= PAUSE_AT:
			paused_once = true
			_check_pause(label, player, kit, authority, boss, watch)
		time += STEP
	print("%s: %.1fs, %d ticks, reasons %s, max grace %d, zone elements %s, unlimited ticks %d" % [label, time, int(watch["ticks"]), watch["reasons"], int(watch["max_grace"]), watch["elements"].keys(), int(watch["unlimited_ticks"])])
	_report(label, watch)
	_check(died, "%s: the fight reached the death and return step" % label)
	_check(watch["reasons"].has(&"thaumaturge_no_circle"), "%s: without the circle the Mudança de Altar is not ready (A6 observed refusing)" % label)
	_check(watch["reasons"].has(&"thaumaturge_dawn_active"), "%s: the Aurora made the Círculo not ready in combat (A6 observed refusing)" % label)
	_check(int(watch["ready_ticks"]) > 0, "%s: the kit skills are also ready in combat" % label)
	_check(watch["elements"].size() >= 2 and watch["elements"].has(&"tricolor"), "%s: the zone carries the changing element, tricolor included: %s" % [label, watch["elements"].keys()])
	_check(int(watch["unlimited_ticks"]) > 0, "%s: the unlimited Grace of the Aurora appears in combat" % label)
	controller.free()

## Fixed priority rotation of mg_ac_boss_combat_test (K2 review).
func _rotation(controller: RunController, player: PlayerActor, boss: CombatActor, authority: SanctuaryAuthority, kit: ClassKit) -> void:
	if player.has_active_cast(): return
	var zone := authority.zone(&"votive")
	var dawn: bool = kit.call(&"dawn_active")
	var order: Array[StringName] = []
	if (zone == null or not zone.owner_inside) and not dawn: order.append(CIRCLE)
	# After a first spend (the boss test waits for one Juízo cast).
	if zone != null and authority.grace.spent_total > 0: order.append(DAWN)
	if authority.grace.charges >= 3 or (dawn and authority.grace.charges >= 1): order.append(&"thaumaturge_prismatic_judgment")
	if player.health.current_hp < player.health.max_hp * 0.6 and authority.grace.charges >= 1: order.append(&"thaumaturge_healing_refraction")
	if zone != null and authority.grace.charges < 3: order.append(ALTAR)
	for skill: StringName in order:
		if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): continue
		var target := boss if ClassKitRegistry.skill_definition(skill).targeting == SkillDefinition.Targeting.SINGLE_TARGET else null
		if player.use_kit_skill(skill, boss.global_position if target != null else player.global_position, target): return
	var last := StringName(kit.get("last_element"))
	var spells: Array[StringName] = [&"fireball", &"ice_spear", &"lightning"]
	for spell: StringName in spells:
		if SPELL_ELEMENTS[spell] == last: continue
		if player.skill_rank(spell) <= 0 or player.skill_cooldown(spell) > 0.0 or player.current_sp < player.skill_cost(spell) + 10.0: continue
		if spell != &"fireball" and not player.can_target_skill(spell, boss): continue
		var sp_before := player.current_sp
		controller._execute_skill(spell, boss.global_position, boss)
		if player.current_sp < sp_before: return

# --- Per-tick invariants ---------------------------------------------------------------------------

func _new_watch() -> Dictionary:
	return {"ticks": 0, "invalid": 0, "invalid_first": "", "mismatch": 0, "impure": 0, "impure_first": "", "a6": 0, "a6_first": "", "authority": 0, "authority_first": "", "reasons": {}, "ready_ticks": 0, "max_grace": 0, "elements": {}, "unlimited_ticks": 0, "dead_marks": 0}

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

func _authority_problem(_player: PlayerActor, kit: ClassKit, authority: SanctuaryAuthority, state: Dictionary, watch: Dictionary) -> String:
	var resources := _by_id(state.get("resources", []))
	if not resources.has(&"sanctuary_grace"): return "no Grace resource"
	var grace: Dictionary = resources[&"sanctuary_grace"]
	if int(grace["value"]) != authority.grace.charges or int(grace["max"]) != authority.grace.cap: return "Grace %s vs %d/%d" % [str(grace), authority.grace.charges, authority.grace.cap]
	if bool(grace.get("unlimited", false)) != authority.grace.is_unlimited(): return "unlimited flag"
	if authority.grace.is_unlimited():
		watch["unlimited_ticks"] = int(watch["unlimited_ticks"]) + 1
		if float(grace["remaining"]) != authority.grace.unlimited_remaining: return "unlimited deadline"
	watch["max_grace"] = maxi(int(watch["max_grace"]), int(grace["value"]))
	var circle := authority.zone(&"votive")
	var zones: Array = state.get("zones", [])
	if (circle == null) != zones.is_empty() or zones.size() > 1: return "zones %d vs circle %s" % [zones.size(), circle != null]
	if circle != null:
		var zone: Dictionary = zones[0]
		watch["elements"][zone["element"]] = true
		if zone["shape"] != circle.shape or float(zone["radius"]) != circle.radius or float(zone["remaining"]) != circle.remaining or zone["space"] != &"flat": return "zone %s" % str(zone)
		if zone["element"] != circle.element or circle.element != StringName(kit.call(&"display_element")): return "zone element %s vs %s / %s" % [zone["element"], circle.element, kit.call(&"display_element")]
		if zone["center"] != Vector3(circle.center.x, circle.center.y, 0.0) or zone.has("half_angle"): return "circle anchor"
		if not resources.has(CIRCLE) or float(resources[CIRCLE]["remaining"]) != circle.remaining or resources[CIRCLE]["element"] != circle.element: return "Circle deadline %s" % str(resources.get(CIRCLE))
	elif resources.has(CIRCLE): return "Circle deadline without a zone"
	if resources.has(&"thaumaturge_elemental_choir") != bool(kit.call(&"choir_active")): return "Coro deadline"
	if resources.has(&"thaumaturge_elemental_choir") and float(resources[&"thaumaturge_elemental_choir"]["remaining"]) != float(kit.get("choir_remaining")): return "Coro remaining"
	if resources.has(DAWN) != bool(kit.call(&"dawn_active")): return "Aurora deadline"
	if resources.has(DAWN) and float(resources[DAWN]["remaining"]) != float(kit.get("dawn_remaining")): return "Aurora remaining"
	if not (state.get("target_marks", []) as Array).is_empty(): return "the Taumaturgo marks nobody"
	return ""

func _report(label: String, watch: Dictionary) -> void:
	var ticks := int(watch["ticks"])
	_check(ticks > 100, "%s: the integrated combat ran (%d HUD reads)" % [label, ticks])
	_check(int(watch["invalid"]) == 0, "%s: the DTO validates by KitHudState on every tick (%d invalid; first %s)" % [label, int(watch["invalid"]), watch["invalid_first"]])
	_check(int(watch["mismatch"]) == 0, "%s: PlayerActor.kit_hud_state returns the kit DTO on every tick" % label)
	_check(int(watch["impure"]) == 0, "%s: hud_state never changes the kit graph (%d impure reads; first %s)" % [label, int(watch["impure"]), watch["impure_first"]])
	_check(int(watch["a6"]) == 0, "%s: A6 on every tick: ready is false iff can_cast refuses, same code (%d breaks; first %s)" % [label, int(watch["a6"]), watch["a6_first"]])
	_check(int(watch["authority"]) == 0, "%s: Grace, zone, element and deadlines follow the authority (%d breaks; first %s)" % [label, int(watch["authority"]), watch["authority_first"]])
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
	_check(not player.is_alive(), "%s: the Taumaturgo dies" % label)
	var dead := player.kit_hud_state()
	_check(KitHudState.validate(dead, kit)["ok"] and not dead.is_empty(), "%s: dead, the DTO still validates" % label)
	var grace: Dictionary = _by_id(dead.get("resources", [])).get(&"sanctuary_grace", {})
	_check(int(grace.get("value", -1)) == authority.grace.charges and authority.grace.charges == 0 and not bool(grace.get("unlimited", false)), "%s: dead, Grace is the authority's (0, no ∞)" % label)
	_check((dead.get("zones", []) as Array).is_empty() and (dead["resources"] as Array).size() == 1, "%s: dead, no zone and no deadline" % label)
	var skills: Dictionary = dead["skills"]
	_check(not bool(skills[ALTAR]["ready"]) and skills[ALTAR]["reason"] == &"thaumaturge_no_circle" and bool(skills[CIRCLE]["ready"]), "%s: dead, the Altar has no circle and the Círculo is free again" % label)
	_observe(player, kit, authority, boss, watch)
	player.health.reset(player.stat_breakdown)
	player._process(STEP)
	_check(player.is_alive(), "%s: the Taumaturgo returns" % label)
	var back := player.kit_hud_state()
	_check(KitHudState.validate(back, kit)["ok"] and int(_by_id(back["resources"])[&"sanctuary_grace"]["value"]) == authority.grace.charges, "%s: after the return the DTO follows the authority" % label)
	_observe(player, kit, authority, boss, watch)

# --- Exact snapshot ---------------------------------------------------------------------------------

## The exact snapshot of a Taumaturgo with the Aurora wide circle, the Coro, an altar
## element and unlimited Grace is byte-identical before and after 100 HUD reads.
func _check_exact_snapshot() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := _standalone(navigation)
	var kit := player.kit
	var authority: SanctuaryAuthority = kit.get("sanctuary")
	var cast := {"skill_id": CIRCLE, "rank": 1, "element": &"light", "world": false, "anchor": null, "point": player.global_position, "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": []}
	_check(kit.resolve_cast(player, cast), "the circle opens")
	kit.set("circle_element", &"ice")
	kit.call(&"_apply_zone_element", player)
	var before_dawn := player.kit_hud_state()
	_check(KitHudState.validate(before_dawn, kit)["ok"] and _by_id(before_dawn["resources"])[CIRCLE]["element"] == &"ice" and before_dawn["zones"][0]["element"] == &"ice", "the circle deadline and zone carry the altar element (ice)")
	cast["skill_id"] = DAWN
	_check(kit.resolve_cast(player, cast), "the Aurora widens the circle")
	kit.set("choir_remaining", 2.0)
	authority.grace.charges = 6
	player.kit_time = 7.0
	var state := player.kit_hud_state()
	var resources := _by_id(state["resources"])
	_check(KitHudState.validate(state, kit)["ok"] and resources.has(DAWN) and resources.has(&"thaumaturge_elemental_choir") and resources[CIRCLE]["element"] == &"tricolor" and state["zones"][0]["shape"] == &"wide_circle" and bool(resources[&"sanctuary_grace"].get("unlimited", false)), "rich state: Aurora, Coro, tricolor wide circle and unlimited Grace in the DTO")
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
	_check(player.bind_world_geometry(geometry, F1Fixture.point("root", Vector3(50, 0, 150)), input.traversal.to_data(), "thaumaturge")["ok"], "the Taumaturgo binds the world")
	player.set_process(false)
	var kit := player.kit
	var anchor := F1Fixture.point("root", Vector3(80, 0, 150))
	var cast := {"skill_id": CIRCLE, "rank": 1, "element": &"light", "world": true, "anchor": anchor, "point": Vector2(anchor.position.x, anchor.position.z), "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": []}
	_check(kit.resolve_cast(player, cast), "the circle opens in the world")
	var authority: SanctuaryAuthority = kit.get("sanctuary")
	var zone := authority.zone(&"votive")
	var state := player.kit_hud_state()
	_check(KitHudState.validate(state, kit)["ok"] and (state.get("zones", []) as Array).size() == 1, "world DTO validates with one zone")
	if zone != null and (state.get("zones", []) as Array).size() == 1:
		var entry: Dictionary = state["zones"][0]
		_check(entry["space"] == &"world" and entry["shape"] == &"circle" and (entry["center"] as Vector3).is_equal_approx(zone.area.anchor().position) and not entry.has("facing"), "the world circle sits on its ground anchor: %s" % str(entry))
	root.remove_child(player)
	player.free()

# --- Helpers ------------------------------------------------------------------------------------------

func _standalone(navigation: ArenaNavigation) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ac"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"mg_ac")
	snapshot.skill_ranks = {&"fireball": 1}
	for skill: StringName in ClassKitRegistry.skill_ids(&"mg_ac"): snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [CIRCLE, &"thaumaturge_healing_refraction", ALTAR, &"thaumaturge_prismatic_judgment", DAWN]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("mg-ac-hud-standalone", snapshot))
	player.global_position = Vector2(400, 350)
	return player

func _by_id(resources: Array) -> Dictionary:
	var found := {}
	for resource: Dictionary in resources: found[resource["id"]] = resource
	return found

## Every script variable of the kit graph, recursively; nodes by instance ID. Stricter
## than the snapshot fragments: it includes the omitted caches.
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
