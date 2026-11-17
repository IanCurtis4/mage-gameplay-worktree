extends SceneTree
## E12 H2 (contract docs/epics/e12_contract.md §5) — HUD state of the Duelista (`sp_la`).
## - Integrated combat against the real boss of the K3 review (both review builds of
##   scripts/classes/sp_la/review_builds.json, rotation of sp_la_boss_combat_test): on
##   every tick the DTO validates by KitHudState, PlayerActor.kit_hud_state returns it,
##   A6 holds for the Aparo (ready == false iff can_cast refuses the real cast
##   descriptor, same code), the Sentence pips equal the flank_victim mark of the living
##   victim, the Duelo, automatic-parry and Guarda Paciente entries follow the kit, and
##   hud_state leaves the whole kit graph unchanged (FlankAuthority included).
## - Pause in the middle of the fight, death and return.
## - Exact snapshot (SnapshotRegistry) identical before and after 100 reads.
## Fixture profiles only; nothing is written to disk.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const BUILDS_PATH := "res://scripts/classes/sp_la/review_builds.json"
const STEP := 0.05
const DURATION := 60.0
const DEATH_AT := 40.0
## The death step also runs once the boss is this low, so the fight never ends first.
const DEATH_HP_FRACTION := 0.35
const PAUSE_AT := 8.0
const BOSS_HP := 20000.0
const ATTRIBUTES: Dictionary[StringName, int] = {&"dex": 50, &"agi": 36, &"str": 25, &"vit": 5}
const PARRY := &"duelist_parry"
const DUEL := &"duelist_duel"
const EXPECTED_SKILLS: Array[StringName] = [&"duelist_parry"]

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
	_check(KitHudState.reported_warnings().is_empty(), "no invalid HUD DTO was reported: %s" % str(KitHudState.reported_warnings()))
	paused = false
	print("E12 H2 sp_la HUD: %d checks, %d failures" % [checks, failures])
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
	snapshot.evolution_id = &"sp_la"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"sp_la")
	snapshot.skill_ranks = {}
	for skill: Variant in build["base_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["base_ranks"][skill])
	for skill: Variant in build["evolution_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["evolution_ranks"][skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	var actives: Array[Variant] = []
	for skill: Variant in build["shortcuts"]:
		if actives.size() < 5 and StringName(skill) in ClassKitRegistry.skill_ids(&"sp_la"): actives.append(StringName(skill))
	snapshot.active_slots = actives
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("sp-la-hud-" + label, snapshot))
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(500, 450)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 43
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	var kit := player.kit
	_check(kit != null and kit.get_script().resource_path == "res://scripts/classes/sp_la/sp_la_kit.gd", "%s: the production Duelista kit is attached" % label)
	if kit == null:
		controller.free()
		return
	var flank: FlankAuthority = kit.get("flank")
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
	var tally := {"casts": {}, "swings": 0}
	controller.enemy_attack_committed.connect(func(event: Dictionary) -> void:
		if int(event.get("attacker_id", 0)) == boss.get_instance_id() and event.get("kind") == &"melee": tally["swings"] = int(tally["swings"]) + 1)
	var watch := _new_watch()
	var time := 0.0
	var paused_once := false
	var died := false
	var planned_swing := -1
	player.target = boss
	while time < DURATION and boss.is_alive():
		if not died and (time >= DEATH_AT or boss.health.current_hp < BOSS_HP * DEATH_HP_FRACTION):
			died = true
			_check_death_and_return(label, player, kit, flank, boss, controller, watch)
		if not player.is_alive(): break
		var facing := player.global_position.direction_to(boss.global_position)
		if not facing.is_zero_approx(): player.character_animation.state.face(facing)
		planned_swing = _rotation(player, boss, kit, flank, tally, planned_swing)
		boss._process(STEP)
		player._process(STEP)
		_observe(player, kit, flank, boss, watch)
		if not paused_once and time >= PAUSE_AT:
			paused_once = true
			_check_pause(label, player, kit, flank, boss, watch)
		time += STEP
	print("%s: %.1fs, %d ticks, reasons %s, casts %s, victim ticks %d, max sentence %d, duel ticks %d, patient ticks %d, auto parry ticks %d" % [label, time, int(watch["ticks"]), watch["reasons"], tally["casts"], int(watch["victim_ticks"]), int(watch["max_sentence"]), int(watch["duel_ticks"]), int(watch["patient_ticks"]), int(watch["auto_ticks"])])
	_report(label, watch)
	_check(died, "%s: the fight reached the death and return step" % label)
	_check(watch["reasons"].has(&"duelist_duel_active"), "%s: the Duelo made the Aparo not ready in combat (A6 observed refusing)" % label)
	_check(int(watch["ready_ticks"]) > 0, "%s: the Aparo is also ready in combat" % label)
	_check(int(watch["victim_ticks"]) > 0 and int(watch["max_sentence"]) >= 3, "%s: the Sentence pips sit on the victim in combat (max %d)" % [label, int(watch["max_sentence"])])
	_check(int(watch["duel_ticks"]) > 0, "%s: the Duelo deadline appears in combat" % label)
	controller.free()

## Fixed priority rotation of sp_la_boss_combat_test (K3 review).
func _rotation(player: PlayerActor, boss: EnemyActor, kit: ClassKit, flank: FlankAuthority, tally: Dictionary, planned_swing: int) -> int:
	if player.has_active_cast() or not player.is_alive(): return planned_swing
	var distance := player.global_position.distance_to(boss.global_position)
	var swing := int(tally["swings"])
	var window := float(kit.call(&"parry_window", player))
	if distance <= 70.0 and not flank.parry_open() and not bool(kit.call(&"duel_active")) and boss.attack_cooldown <= window * 0.6 and planned_swing != swing:
		planned_swing = swing
		if swing % 3 != 2 and _use(player, PARRY, null, tally): return planned_swing
	var order: Array[StringName] = []
	if flank.sentence(player) >= 4 and flank.victim(player) == boss: order.append(&"duelist_fatal_riposte")
	order.append(DUEL)
	if not boss.marks.has_mark(&"duelist_feint"): order.append(&"duelist_feint")
	if player.health.current_hp < player.health.max_hp * 0.4: order.append(&"duelist_guarded_retreat")
	var reserve := player.skill_cost(&"duelist_fatal_riposte")
	for skill: StringName in order:
		var target := boss if ClassKitRegistry.skill_definition(skill).targeting == SkillDefinition.Targeting.SINGLE_TARGET else null
		if skill != &"duelist_fatal_riposte" and player.current_sp < player.skill_cost(skill) + reserve: continue
		if _use(player, skill, target, tally): return planned_swing
	if distance > 110.0 and player.skill_rank(&"dash") > 0 and player.dash_cooldown <= 0.0 and player.current_sp >= player.skill_cost(&"dash") + 30.0:
		if player.use_dash(player.global_position.direction_to(boss.global_position)): return planned_swing
	if distance <= 120.0 and player.skill_rank(&"slash") > 0 and player.slash_cooldown <= 0.0 and player.current_sp >= player.skill_cost(&"slash") + 40.0:
		var foes: Array[CombatActor] = [boss]
		player.use_slash(player.global_position.direction_to(boss.global_position), foes)
	return planned_swing

func _use(player: PlayerActor, skill: StringName, target: CombatActor, tally: Dictionary) -> bool:
	if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): return false
	if target != null and not player.can_target_skill(skill, target): return false
	if not player.use_kit_skill(skill, target.global_position if target != null else player.global_position, target): return false
	tally["casts"][skill] = int(tally["casts"].get(skill, 0)) + 1
	return true

# --- Per-tick invariants ---------------------------------------------------------------------------

func _new_watch() -> Dictionary:
	return {"ticks": 0, "invalid": 0, "invalid_first": "", "mismatch": 0, "impure": 0, "impure_first": "", "a6": 0, "a6_first": "", "authority": 0, "authority_first": "", "reasons": {}, "ready_ticks": 0, "victim_ticks": 0, "max_sentence": 0, "duel_ticks": 0, "patient_ticks": 0, "auto_ticks": 0, "dead_marks": 0}

func _observe(player: PlayerActor, kit: ClassKit, flank: FlankAuthority, boss: CombatActor, watch: Dictionary) -> void:
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
	var problem := _authority_problem(player, kit, flank, boss, state, watch)
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

## Sentence pips against the flank_victim mark, deadlines against the kit.
func _authority_problem(player: PlayerActor, kit: ClassKit, flank: FlankAuthority, boss: CombatActor, state: Dictionary, watch: Dictionary) -> String:
	var resources := _by_id(state.get("resources", []))
	var marks: Array = state.get("target_marks", [])
	if is_instance_valid(boss) and boss.is_alive() and flank.is_victim(player, boss):
		watch["victim_ticks"] = int(watch["victim_ticks"]) + 1
		var sentence := int(FlankRules.victim_mark(boss).get("sentence", -1))
		watch["max_sentence"] = maxi(int(watch["max_sentence"]), sentence)
		if marks.size() != 1: return "victim marks %s" % str(marks)
		var mark: Dictionary = marks[0]
		if int(mark["target_id"]) != boss.get_instance_id() or mark["key"] != FlankRules.VICTIM_MARK or mark["kind"] != &"pips" or int(mark["value"]) != sentence or int(mark["max"]) != FlankRules.SENTENCE_CAP: return "Sentence %s vs mark %d" % [str(mark), sentence]
		if sentence != flank.sentence(player, boss): return "Sentence vs authority"
	elif not marks.is_empty(): return "mark without a living victim"
	var duel: bool = kit.call(&"duel_active")
	if resources.has(&"duelist_duel") != duel: return "Duelo deadline"
	if duel:
		watch["duel_ticks"] = int(watch["duel_ticks"]) + 1
		if float(resources[&"duelist_duel"]["remaining"]) != float(kit.get("duel_remaining")): return "Duelo remaining"
	var automatic := float(kit.get("auto_parry_remaining"))
	if resources.has(&"duelist_auto_parry") != (automatic > 0.0): return "automatic parry"
	if automatic > 0.0: watch["auto_ticks"] = int(watch["auto_ticks"]) + 1
	var patient: bool = kit.call(&"patient", player)
	if resources.has(&"duelist_patient_guard") != patient: return "Guarda Paciente"
	if patient: watch["patient_ticks"] = int(watch["patient_ticks"]) + 1
	if state.has("zones"): return "the Duelista draws no zone"
	return ""

func _report(label: String, watch: Dictionary) -> void:
	var ticks := int(watch["ticks"])
	_check(ticks > 100, "%s: the integrated combat ran (%d HUD reads)" % [label, ticks])
	_check(int(watch["invalid"]) == 0, "%s: the DTO validates by KitHudState on every tick (%d invalid; first %s)" % [label, int(watch["invalid"]), watch["invalid_first"]])
	_check(int(watch["mismatch"]) == 0, "%s: PlayerActor.kit_hud_state returns the kit DTO on every tick" % label)
	_check(int(watch["impure"]) == 0, "%s: hud_state never changes the kit graph (%d impure reads; first %s)" % [label, int(watch["impure"]), watch["impure_first"]])
	_check(int(watch["a6"]) == 0, "%s: A6 on every tick: ready is false iff can_cast refuses, same code (%d breaks; first %s)" % [label, int(watch["a6"]), watch["a6_first"]])
	_check(int(watch["authority"]) == 0, "%s: Sentence and deadlines follow the authority (%d breaks; first %s)" % [label, int(watch["authority"]), watch["authority_first"]])
	_check(int(watch["dead_marks"]) == 0, "%s: only living actors are marked (A7)" % label)

# --- Pause, death and return ------------------------------------------------------------------------

func _check_pause(label: String, player: PlayerActor, kit: ClassKit, flank: FlankAuthority, boss: CombatActor, watch: Dictionary) -> void:
	paused = true
	var before := player.kit_hud_state()
	var graph: Variant = _graph(kit)
	for _step: int in 20:
		player._process(STEP)
		_observe(player, kit, flank, boss, watch)
	var after := player.kit_hud_state()
	_check(not before.is_empty() and before == after and _graph(kit) == graph, "%s: with the tree paused the DTO is readable and frozen" % label)
	paused = false

func _check_death_and_return(label: String, player: PlayerActor, kit: ClassKit, flank: FlankAuthority, boss: CombatActor, _controller: Controller, watch: Dictionary) -> void:
	var request := DamageRequest.new()
	request.source_id = boss.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = 1000000.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.context = player.run_state.effect_ledger.new_root(boss.get_instance_id(), false, "", false, {})
	# Straight on the HealthState: an open parry window would cancel a melee hit, and the
	# test needs a certain death (the kit still sees it through on_death).
	player.health.clear_shield()
	player.health.apply(request, 0.0, 1.0)
	_check(not player.is_alive(), "%s: the Duelista dies" % label)
	var dead := player.kit_hud_state()
	_check(KitHudState.validate(dead, kit)["ok"] and not dead.is_empty(), "%s: dead, the DTO still validates" % label)
	_check((dead.get("target_marks", []) as Array).is_empty() and not FlankRules.victim_mark(boss).has("sentence") and (dead.get("resources", []) as Array).is_empty(), "%s: dead, no victim, no Sentence, no deadline" % label)
	_check(bool(dead["skills"][PARRY]["ready"]), "%s: dead, the Duelo is over: the Aparo is not refused by the kit" % label)
	_observe(player, kit, flank, boss, watch)
	player.health.reset(player.stat_breakdown)
	player._process(STEP)
	_check(player.is_alive(), "%s: the Duelista returns" % label)
	var back := player.kit_hud_state()
	_check(KitHudState.validate(back, kit)["ok"] and (back.get("target_marks", []) as Array).is_empty(), "%s: after the return the DTO follows the authority (no victim until a new parry)" % label)
	_observe(player, kit, flank, boss, watch)

# --- Exact snapshot ---------------------------------------------------------------------------------

## The exact snapshot of a Duelista with a victim at 3 Sentence, the Duelo and the
## automatic parry is byte-identical before and after 100 HUD reads.
func _check_exact_snapshot() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := _standalone(navigation)
	var kit := player.kit
	var flank: FlankAuthority = kit.get("flank")
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = Vector2(440, 350)
	enemy.health.max_hp = 1000.0
	enemy.health.current_hp = 1000.0
	player.add_child(enemy)
	flank.mark_victim(player, enemy)
	flank.gain(player, enemy, FlankRules.SOURCE_COMBO, "snap_a")
	flank.gain(player, enemy, FlankRules.SOURCE_DIRECT, "snap_b")
	flank.open_parry_mode(player, 4.0)
	kit.set("duel_remaining", 4.0)
	kit.set("auto_parry_remaining", 5.0)
	kit.set("patience", 59.0)
	player.kit_time = 11.0
	var state := player.kit_hud_state()
	var resources := _by_id(state.get("resources", []))
	_check(KitHudState.validate(state, kit)["ok"] and resources.has(&"duelist_duel") and resources.has(&"duelist_auto_parry") and resources.has(&"duelist_patient_guard") and (state["target_marks"] as Array).size() == 1 and int(state["target_marks"][0]["value"]) == 3 and not bool(state["skills"][PARRY]["ready"]) and state["skills"][PARRY]["reason"] == &"duelist_duel_active", "rich state: Duelo, automatic parry, Guarda Paciente, Sentence 3 and the refused Aparo in the DTO")
	player.current_sp = player.max_sp
	player.mage_cooldowns[PARRY] = 0.0
	_check(player.skill_cooldown(PARRY) <= 0.0 and player.current_sp >= player.skill_cost(PARRY) and player.use_kit_skill(PARRY, player.global_position) == false, "with SP and no cooldown, the real cast path refuses the Aparo the DTO calls not ready")
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(player)["ok"], "barrier acquired")
	var first := SnapshotRegistry.new().capture(player, barrier)
	for _index: int in 100: kit.hud_state(player)
	var second := SnapshotRegistry.new().capture(player, barrier)
	_check(first.get("ok", false) and second.get("ok", false), "exact captures succeed: %s" % str(first.get("detail", first.get("error_code", ""))))
	if first.get("ok", false) and second.get("ok", false):
		_check(var_to_bytes(first["snapshot"]) == var_to_bytes(second["snapshot"]), "the exact snapshot (FlankAuthority and the victim mark included) is identical after 100 HUD reads")
	barrier.release()
	player.free()

# --- Helpers ------------------------------------------------------------------------------------------

func _standalone(navigation: ArenaNavigation) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"sp_la"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"sp_la")
	snapshot.skill_ranks = {}
	for skill: StringName in ClassKitRegistry.skill_ids(&"sp_la"): snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [PARRY, &"duelist_fatal_riposte", &"duelist_feint", &"duelist_guarded_retreat", DUEL]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("sp-la-hud-standalone", snapshot))
	player.global_position = Vector2(400, 350)
	return player

func _by_id(resources: Array) -> Dictionary:
	var found := {}
	for resource: Dictionary in resources: found[resource["id"]] = resource
	return found

## Every script variable of the kit graph, recursively; nodes by instance ID. Stricter
## than the snapshot fragments: it includes the omitted caches (_victim_hint).
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
