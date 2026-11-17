extends SceneTree
## E12 H2 (contract docs/epics/e12_contract.md §5) — HUD state of the Lâmina Arcana (`mg_la`).
## - Integrated combat against the real boss of the K4 review (both review builds of
##   scripts/classes/mg_la/review_builds.json, rotation of mg_la_boss_combat_test): on
##   every tick the DTO validates by KitHudState, PlayerActor.kit_hud_state returns it,
##   A6 holds for the Refração (ready == false iff can_cast refuses the real cast
##   descriptor, same code; charges and the kit's own recharge in the skill entry:
##   limitation 1 of K4), the Sentence pips equal the flank_victim mark of the living
##   victim, the concealment deadline and the Espectro badges follow the authority and
##   the kit, and hud_state leaves the whole kit graph unchanged.
## - Pause in the middle of the fight, death and return.
## - Exact snapshot (SnapshotRegistry) identical before and after 100 reads.
## Fixture profiles only; nothing is written to disk.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const BUILDS_PATH := "res://scripts/classes/mg_la/review_builds.json"
const STEP := 0.05
const DURATION := 80.0
const DEATH_AT := 50.0
## The death step also runs once the boss is this low, so the fight never ends first.
const DEATH_HP_FRACTION := 0.35
const PAUSE_AT := 8.0
const BOSS_HP := 20000.0
const ATTRIBUTES: Dictionary[StringName, int] = {&"int": 50, &"dex": 36, &"agi": 20, &"vit": 8}
const MARK := &"arcane_blade_refracted_mark"
const REFRACTION := &"arcane_blade_refraction"
const LEAP := &"arcane_blade_prismatic_leap"
const SENTENCE := &"arcane_blade_prismatic_sentence"
const SPECTER := &"arcane_blade_prism_specter"
const SPECTER_MARK := &"arcane_blade_specter"
const EXPECTED_SKILLS: Array[StringName] = [&"arcane_blade_refraction"]

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
	print("E12 H2 mg_la HUD: %d checks, %d failures" % [checks, failures])
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
	snapshot.evolution_id = &"mg_la"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"mg_la")
	snapshot.skill_ranks = {}
	for skill: Variant in build["base_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["base_ranks"][skill])
	for skill: Variant in build["evolution_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["evolution_ranks"][skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	var actives: Array[Variant] = []
	for skill: Variant in build["shortcuts"]:
		if actives.size() < 5 and StringName(skill) in ClassKitRegistry.skill_ids(&"mg_la"): actives.append(StringName(skill))
	snapshot.active_slots = actives
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("mg-la-hud-" + label, snapshot))
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(400, 450)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 53
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	player.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, target: CombatActor, _facing: Vector2, _count: int) -> void: controller._on_attack_requested(request, target))
	var kit := player.kit
	_check(kit != null and kit.get_script().resource_path == "res://scripts/classes/mg_la/mg_la_kit.gd", "%s: the production Lâmina Arcana kit is attached" % label)
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
	boss.global_position = Vector2(700, 450)
	var configured := boss.configure_occurrence(occurrence, player.run_state.effect_catalog().mob_catalog(), navigation, player)
	_check(configured.get("ok", false), "%s: boss occurrence configures" % label)
	if not configured.get("ok", false):
		boss.free()
		controller.free()
		return
	boss.attack_requested.connect(controller._on_enemy_attack_requested)
	boss.mob_skill_requested.connect(controller._on_mob_skill_requested)
	boss.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	boss.status_damage_requested.connect(controller._on_attack_requested)
	controller.add_child(boss)
	controller.enemies.append(boss)
	boss.set_process(false)
	boss.health.max_hp = BOSS_HP
	boss.health.current_hp = BOSS_HP
	var tally := {"casts": {}}
	var watch := _new_watch()
	var time := 0.0
	var paused_once := false
	var died := false
	while time < DURATION and boss.is_alive():
		if not died and (time >= DEATH_AT or boss.health.current_hp < BOSS_HP * DEATH_HP_FRACTION):
			died = true
			_check_death_and_return(label, player, kit, flank, boss, watch)
		if not player.is_alive(): break
		_rotation(player, boss, kit, flank, tally)
		boss._process(STEP)
		player._process(STEP)
		_observe(player, kit, flank, boss, watch)
		if not paused_once and time >= PAUSE_AT:
			paused_once = true
			_check_pause(label, player, kit, flank, boss, watch)
		time += STEP
	print("%s: %.1fs, %d ticks, reasons %s, casts %s, victim ticks %d, max sentence %d, concealed ticks %d, recharge ticks %d, specter ticks %d" % [label, time, int(watch["ticks"]), watch["reasons"], tally["casts"], int(watch["victim_ticks"]), int(watch["max_sentence"]), int(watch["concealed_ticks"]), int(watch["recharge_ticks"]), int(watch["specter_ticks"])])
	_report(label, watch)
	_check(died, "%s: the fight reached the death and return step" % label)
	_check(watch["reasons"].has(&"arcane_blade_refraction_recharging"), "%s: without a charge the Refração is not ready, with the kit's code (A6, limitation 1 of K4)" % label)
	_check(watch["reasons"].has(&"arcane_blade_already_concealed"), "%s: concealed, the Refração is not ready with the kit's code (A6)" % label)
	_check(int(watch["ready_ticks"]) > 0, "%s: the Refração is also ready in combat" % label)
	_check(int(watch["recharge_ticks"]) > 0 and int(watch["concealed_ticks"]) > 0, "%s: the own recharge and the concealment deadline appear in combat" % label)
	_check(int(watch["victim_ticks"]) > 0 and int(watch["max_sentence"]) >= 3, "%s: the Sentence pips sit on the victim in combat (max %d)" % [label, int(watch["max_sentence"])])
	controller.free()

## Fixed priority rotation of mg_la_boss_combat_test (K4 review), without its tallies.
func _rotation(player: PlayerActor, boss: EnemyActor, kit: ClassKit, flank: FlankAuthority, tally: Dictionary) -> void:
	if player.has_active_cast() or not player.is_alive(): return
	var distance := player.global_position.distance_to(boss.global_position)
	if flank.victim(player) != boss:
		if _use(player, MARK, boss, tally): return
	if player.kit_concealed():
		player.target = null
		_use(player, LEAP, boss, tally)
		return
	if flank.sentence(player) >= 4 and distance <= 80.0 + player.collision_radius + boss.collision_radius:
		if _use(player, SENTENCE, boss, tally):
			tally["exit_next"] = true
			return
	if _use(player, SPECTER, null, tally): return
	var facing_her: bool = FlankRules.side_between(boss, player)["side"] == FlankRules.FRONT
	var exit: bool = (bool(tally.get("exit_next", false)) and facing_her) or player.health.current_hp < player.health.max_hp * 0.45
	if exit and distance < 160.0 and player.skill_cooldown(&"teleport") <= 0.0 and player.current_sp >= player.skill_cost(&"teleport"):
		var away := boss.global_position.direction_to(player.global_position)
		if away.is_zero_approx(): away = Vector2.LEFT
		var point := (player.global_position + away * 280.0).clamp(Vector2(40, 40), Vector2(1360, 860))
		if player.use_teleport(point):
			tally["exit_next"] = false
			return
	if player.skill_cooldown(LEAP) <= 0.0 and player.current_sp >= player.skill_cost(REFRACTION) + player.skill_cost(LEAP):
		if _use(player, REFRACTION, null, tally): return
	if distance > 200.0 and player.skill_cooldown(&"ice_spear") <= 0.0 and player.current_sp >= player.skill_cost(&"ice_spear") + 40.0:
		player.use_spear(&"ice_spear", boss)
	if player.target != boss: player.pursue(boss)

func _use(player: PlayerActor, skill: StringName, target: CombatActor, tally: Dictionary) -> bool:
	if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): return false
	if target != null and not player.can_target_skill(skill, target): return false
	if not player.use_kit_skill(skill, target.global_position if target != null else player.global_position, target): return false
	tally["casts"][skill] = int(tally["casts"].get(skill, 0)) + 1
	return true

# --- Per-tick invariants ---------------------------------------------------------------------------

func _new_watch() -> Dictionary:
	return {"ticks": 0, "invalid": 0, "invalid_first": "", "mismatch": 0, "impure": 0, "impure_first": "", "a6": 0, "a6_first": "", "authority": 0, "authority_first": "", "reasons": {}, "ready_ticks": 0, "victim_ticks": 0, "max_sentence": 0, "concealed_ticks": 0, "recharge_ticks": 0, "specter_ticks": 0, "dead_marks": 0}

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

## Refração charge and recharge against the kit, concealment against the authority,
## Sentence pips against the flank_victim mark, Espectro badges against the marks.
func _authority_problem(player: PlayerActor, kit: ClassKit, flank: FlankAuthority, boss: CombatActor, state: Dictionary, watch: Dictionary) -> String:
	var resources := _by_id(state.get("resources", []))
	var charges := int(kit.get("refraction_charges"))
	var recharge := float(kit.get("refraction_recharge"))
	var charge: Dictionary = resources.get(&"arcane_blade_refraction", {})
	var skill: Dictionary = state["skills"][REFRACTION]
	if charge.is_empty() or charge["kind"] != &"charges" or int(charge["value"]) != charges or int(charge["max"]) != 1: return "Refração charge %s vs %d" % [str(charge), charges]
	if int(skill["charges"]) != charges or int(skill["max_charges"]) != 1: return "skill charges"
	var recharging := charges < 1 and recharge > 0.0
	if charge.has("remaining") != recharging or skill.has("recharge_remaining") != recharging: return "recharge presence"
	if recharging:
		watch["recharge_ticks"] = int(watch["recharge_ticks"]) + 1
		if float(charge["remaining"]) != recharge or float(skill["recharge_remaining"]) != recharge or float(skill["recharge_total"]) != float(charge["total"]): return "recharge values"
	if resources.has(&"flank_concealment") != flank.concealment_active(): return "concealment deadline"
	if flank.concealment_active():
		watch["concealed_ticks"] = int(watch["concealed_ticks"]) + 1
		if float(resources[&"flank_concealment"]["remaining"]) != flank.concealment_remaining: return "concealment remaining"
	var marks: Array = state.get("target_marks", [])
	var victim_marks: Array = []
	var specter_marks: Array = []
	for mark: Dictionary in marks:
		if mark["key"] == FlankRules.VICTIM_MARK: victim_marks.append(mark)
		elif mark["key"] == SPECTER_MARK: specter_marks.append(mark)
		else: return "unknown mark %s" % str(mark)
	if is_instance_valid(boss) and boss.is_alive() and flank.is_victim(player, boss):
		watch["victim_ticks"] = int(watch["victim_ticks"]) + 1
		var sentence := int(FlankRules.victim_mark(boss).get("sentence", -1))
		watch["max_sentence"] = maxi(int(watch["max_sentence"]), sentence)
		if victim_marks.size() != 1 or int(victim_marks[0]["target_id"]) != boss.get_instance_id() or int(victim_marks[0]["value"]) != sentence or sentence != flank.sentence(player, boss): return "Sentence %s vs %d" % [str(victim_marks), sentence]
	elif not victim_marks.is_empty(): return "victim mark without a living victim"
	var reflected := int(kit.get("specter_pending")) > 0 and is_instance_valid(boss) and boss.is_alive() and boss.marks.owner_of(SPECTER_MARK) == player.get_instance_id() and int((boss.marks.value(SPECTER_MARK) as Dictionary).get("serial", -1)) == int(kit.get("specter_serial"))
	if reflected != (specter_marks.size() == 1): return "Espectro badge %s" % str(specter_marks)
	if reflected:
		watch["specter_ticks"] = int(watch["specter_ticks"]) + 1
		if specter_marks[0]["kind"] != &"badge" or int(specter_marks[0]["target_id"]) != boss.get_instance_id(): return "Espectro badge shape"
	if state.has("zones"): return "the Lâmina draws no zone"
	return ""

func _report(label: String, watch: Dictionary) -> void:
	var ticks := int(watch["ticks"])
	_check(ticks > 100, "%s: the integrated combat ran (%d HUD reads)" % [label, ticks])
	_check(int(watch["invalid"]) == 0, "%s: the DTO validates by KitHudState on every tick (%d invalid; first %s)" % [label, int(watch["invalid"]), watch["invalid_first"]])
	_check(int(watch["mismatch"]) == 0, "%s: PlayerActor.kit_hud_state returns the kit DTO on every tick" % label)
	_check(int(watch["impure"]) == 0, "%s: hud_state never changes the kit graph (%d impure reads; first %s)" % [label, int(watch["impure"]), watch["impure_first"]])
	_check(int(watch["a6"]) == 0, "%s: A6 on every tick: ready is false iff can_cast refuses, same code (%d breaks; first %s)" % [label, int(watch["a6"]), watch["a6_first"]])
	_check(int(watch["authority"]) == 0, "%s: charge, recharge, concealment, Sentence and Espectro follow the authority (%d breaks; first %s)" % [label, int(watch["authority"]), watch["authority_first"]])
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

func _check_death_and_return(label: String, player: PlayerActor, kit: ClassKit, flank: FlankAuthority, boss: CombatActor, watch: Dictionary) -> void:
	var request := DamageRequest.new()
	request.source_id = boss.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = 1000000.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.context = player.run_state.effect_ledger.new_root(boss.get_instance_id(), false, "", false, {})
	var charges := int(kit.get("refraction_charges"))
	var recharge := float(kit.get("refraction_recharge"))
	player.health.clear_shield()
	player.health.apply(request, 0.0, 1.0)
	_check(not player.is_alive(), "%s: the Lâmina dies" % label)
	var dead := player.kit_hud_state()
	_check(KitHudState.validate(dead, kit)["ok"] and not dead.is_empty(), "%s: dead, the DTO still validates" % label)
	var resources := _by_id(dead.get("resources", []))
	_check((dead.get("target_marks", []) as Array).is_empty() and not resources.has(&"flank_concealment") and not flank.concealment_active(), "%s: dead, no victim, no reflection, no concealment" % label)
	_check(int(resources[&"arcane_blade_refraction"]["value"]) == charges and int(kit.get("refraction_charges")) == charges and float(kit.get("refraction_recharge")) == recharge, "%s: dead, the Refração charge state is kept and shown as is" % label)
	_observe(player, kit, flank, boss, watch)
	player.health.reset(player.stat_breakdown)
	player._process(STEP)
	_check(player.is_alive(), "%s: the Lâmina returns" % label)
	var back := player.kit_hud_state()
	_check(KitHudState.validate(back, kit)["ok"] and (back.get("target_marks", []) as Array).is_empty(), "%s: after the return the DTO follows the authority (no victim until a new Marca)" % label)
	_observe(player, kit, flank, boss, watch)

# --- Exact snapshot ---------------------------------------------------------------------------------

## The exact snapshot of a Lâmina with a victim at 3 Sentence, the concealment, an empty
## Refração recharging and a pending reflection is byte-identical before and after 100 reads.
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
	flank.enter_concealment(player, 4.0)
	kit.set("refraction_charges", 0)
	kit.set("refraction_recharge", 6.5)
	kit.set("specter_serial", 2)
	kit.set("specter_pending", 1)
	enemy.marks.set_mark(SPECTER_MARK, player.get_instance_id(), {"serial": 2, "order": 0, "due": 12.0, "element": "ice"}, 3.0)
	player.kit_time = 11.0
	var state := player.kit_hud_state()
	var resources := _by_id(state.get("resources", []))
	var skill: Dictionary = state.get("skills", {}).get(REFRACTION, {})
	_check(KitHudState.validate(state, kit)["ok"] and resources.has(&"flank_concealment") and float(resources[&"arcane_blade_refraction"].get("remaining", -1.0)) == 6.5 and (state["target_marks"] as Array).size() == 2, "rich state: concealment, Refração recharge 6.5 s, Sentence and one reflection badge in the DTO")
	_check(not bool(skill.get("ready", true)) and skill.get("reason") == &"arcane_blade_already_concealed" and int(skill.get("charges", -1)) == 0 and float(skill.get("recharge_remaining", -1.0)) == 6.5, "concealed with no charge: the kit's first refusal is the concealment, the entry carries the recharge")
	flank.end_concealment()
	state = player.kit_hud_state()
	skill = state["skills"][REFRACTION]
	_check(not bool(skill["ready"]) and skill["reason"] == &"arcane_blade_refraction_recharging", "visible again, the empty Refração is not ready with arcane_blade_refraction_recharging")
	player.current_sp = player.max_sp
	player.mage_cooldowns[REFRACTION] = 0.0
	_check(player.skill_cooldown(REFRACTION) <= 0.0 and player.current_sp >= player.skill_cost(REFRACTION) and player.use_kit_skill(REFRACTION, player.global_position) == false, "with SP and no canonical cooldown, the real cast path refuses the Refração the DTO calls not ready")
	flank.enter_concealment(player, 4.0)
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(player)["ok"], "barrier acquired")
	var first := SnapshotRegistry.new().capture(player, barrier)
	for _index: int in 100: kit.hud_state(player)
	var second := SnapshotRegistry.new().capture(player, barrier)
	_check(first.get("ok", false) and second.get("ok", false), "exact captures succeed: %s" % str(first.get("detail", first.get("error_code", ""))))
	if first.get("ok", false) and second.get("ok", false):
		_check(var_to_bytes(first["snapshot"]) == var_to_bytes(second["snapshot"]), "the exact snapshot (FlankAuthority, the victim and reflection marks included) is identical after 100 HUD reads")
	barrier.release()
	player.free()

# --- Helpers ------------------------------------------------------------------------------------------

func _standalone(navigation: ArenaNavigation) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_la"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"mg_la")
	snapshot.skill_ranks = {}
	for skill: StringName in ClassKitRegistry.skill_ids(&"mg_la"): snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [MARK, REFRACTION, LEAP, SENTENCE, SPECTER]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("mg-la-hud-standalone", snapshot))
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
