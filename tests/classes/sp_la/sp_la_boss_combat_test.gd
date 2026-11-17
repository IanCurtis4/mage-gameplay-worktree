extends SceneTree
## E09 K3 (C4.2) — short integrated combat of the Duelista against a real boss
## (`forest_ancient_warden`, category boss), without adds (the companion signal is
## not connected) and without augments, once per review build of
## scripts/classes/sp_la/review_builds.json. The boss runs its own AI and strikes
## through RunController._on_enemy_attack_requested; the Duelista reads the boss
## rhythm (its real attack cooldown) to time the Aparo, like a player would, and
## misses one swing out of three on purpose. Casts go through PlayerActor.use_kit_skill
## and the base skills, ticking real gameplay clocks. Fixture profile only.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const BUILDS_PATH := "res://scripts/classes/sp_la/review_builds.json"
const STEP := 0.05
const DURATION := 90.0
const BOSS_HP := 20000.0
## Legal level-30 allocation for the sheet's DES > AGI > FOR (fixture, not a save).
const ATTRIBUTES: Dictionary[StringName, int] = {&"dex": 50, &"agi": 36, &"str": 25, &"vit": 5}

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
	var file := FileAccess.open(BUILDS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_check(parsed is Dictionary and parsed.get("builds", []).size() == 2, "two review builds to fight with")
	if parsed is Dictionary:
		for build: Variant in parsed["builds"]: _fight(build)
	print("E09 K3 sp_la boss combat: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

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
	_check(ProgressionRules.attribute_points_available(ProgressionRules.MAX_BASE_XP, snapshot.attribute_allocations, &"swordsman") >= 0, "%s: legal level-30 attributes DES > AGI > FOR" % label)
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
	player.configure(navigation, RunState.from_build("sp-la-boss-" + label, snapshot))
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
	occurrence.occurrence_id = "k3_boss_" + label
	occurrence.mob_base_id = &"forest_ancient_warden"
	occurrence.category_id = &"boss"
	occurrence.origin_id = &"trial_stage_4"
	var boss := EnemyActor.new()
	var configured := boss.configure_occurrence(occurrence, player.run_state.effect_catalog().mob_catalog(), navigation, player)
	_check(configured.get("ok", false), "%s: boss occurrence configures: %s" % [label, configured])
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
	_check(boss.hard_controls.boss and FlankRules.category_of(boss) == &"boss" and controller.enemies.size() == 1, "%s: a single boss, no adds" % label)
	var tally := {"casts": {}, "swings": 0, "parried": 0, "landed": 0, "riposte_charges": [], "max_turn": 0.0, "skipped": 0}
	var riposte_results: Array[Dictionary] = []
	boss.health.damage_applied.connect(func(result: Dictionary) -> void:
		if result.get("skill_id") == &"duelist_fatal_riposte": riposte_results.append(result))
	controller.enemy_attack_committed.connect(func(event: Dictionary) -> void:
		if int(event.get("attacker_id", 0)) == boss.get_instance_id() and event.get("kind") == &"melee": tally["swings"] = int(tally["swings"]) + 1)
	var serial_before := int(kit.get("parry_serial"))
	var time := 0.0
	player.target = boss
	var planned_swing := -1
	while time < DURATION and player.is_alive() and boss.is_alive():
		var facing := player.global_position.direction_to(boss.global_position)
		if not facing.is_zero_approx(): player.character_animation.state.face(facing)
		var hp_before := player.health.current_hp
		var serial := int(kit.get("parry_serial"))
		planned_swing = _rotation(player, boss, kit, flank, tally, planned_swing)
		boss._process(STEP)
		player._process(STEP)
		if player.health.current_hp < hp_before: tally["landed"] = int(tally["landed"]) + 1
		if int(kit.get("parry_serial")) > serial: tally["max_turn"] = maxf(float(tally["max_turn"]), boss.gameplay_facing_override_remaining())
		time += STEP
	var casts: Dictionary = tally["casts"]
	var parried := int(kit.get("parry_serial")) - serial_before
	print("%s: %.1fs boss %.0f/%.0f player %.0f/%.0f casts %s swings %d parried %d landed %d riposte charges %s sentence gained %d" % [label, time, boss.health.current_hp, BOSS_HP, player.health.current_hp, player.health.max_hp, casts, int(tally["swings"]), parried, int(tally["landed"]), tally["riposte_charges"], flank.gained_total])
	_check(player.is_alive(), "%s: the Duelista survives the boss" % label)
	_check(not boss.is_alive(), "%s: the Duelista alone defeats the boss (%.0f left after %.1f s)" % [label, boss.health.current_hp, time])
	_check(int(tally["swings"]) > 0 and int(tally["landed"]) > 0, "%s: the boss really strikes the Duelista (%d swings, %d landed)" % [label, int(tally["swings"]), int(tally["landed"])])
	_check(parried >= 5, "%s: the boss's real melee swings are parried (%d)" % [label, parried])
	_check(float(tally["max_turn"]) > 0.0 and float(tally["max_turn"]) <= FlankRules.TURN_DURATION * FlankRules.BOSS_DURATION_FACTOR + 1.0e-4, "%s: the parried boss is turned for at most 0.9 s (boss × 0.6)" % label)
	_check(int(casts.get(&"duelist_parry", 0)) >= 5 and int(casts.get(&"duelist_fatal_riposte", 0)) >= 4, "%s: Aparo and Riposte are used in the loop: %s" % [label, casts])
	var charged := false
	for charges: Variant in tally["riposte_charges"]: charged = charged or int(charges) >= 4
	_check(charged, "%s: the Riposte spends a built Sentence (%s)" % [label, tally["riposte_charges"]])
	var lethal := false
	for result: Dictionary in riposte_results: lethal = lethal or bool(FlankRules.result_flags(result).get("lethal", false))
	_check(not riposte_results.is_empty() and not lethal and flank.lethal_total == 0, "%s: the Riposte on the boss is only high damage, never certain death (A4)" % label)
	var parry_keys := 0
	for key: String in flank._claim_order:
		if key.begins_with("combo@parry:"): parry_keys += 1
	_check(parry_keys > 0, "%s: the parries fill the Sentence (%d events)" % [label, parry_keys])
	if int(build["evolution_ranks"].get("duelist_duel", 0)) >= 1:
		_check(int(casts.get(&"duelist_duel", 0)) >= 1, "%s: the Duelo is used" % label)
	_check(controller.enemies.size() <= 1, "%s: no add joined the fight" % label)
	controller.free()

## Fixed priority rotation. The Aparo is cast when the boss's real attack cooldown says
## the swing falls inside the window (every third swing is left unparried on purpose);
## Riposte with 4+ Sentence; Finta and Duelo on cooldown; Investida to re-enter; Corte
## on cooldown; Recuo when hurt. The basic attack runs on its own.
func _rotation(player: PlayerActor, boss: EnemyActor, kit: ClassKit, flank: FlankAuthority, tally: Dictionary, planned_swing: int) -> int:
	if player.has_active_cast(): return planned_swing
	var distance := player.global_position.distance_to(boss.global_position)
	var swing := int(tally["swings"])
	var window := float(kit.call(&"parry_window", player))
	# Aparo: the next swing lands within the window (boss cooldown below 60% of it).
	if distance <= 70.0 and not flank.parry_open() and not bool(kit.call(&"duel_active")) and boss.attack_cooldown <= window * 0.6 and planned_swing != swing:
		planned_swing = swing
		if swing % 3 == 2:
			tally["skipped"] = int(tally["skipped"]) + 1
		elif _use(player, &"duelist_parry", null, tally):
			return planned_swing
	var order: Array[StringName] = []
	if flank.sentence(player) >= 4 and flank.victim(player) == boss: order.append(&"duelist_fatal_riposte")
	order.append(&"duelist_duel")
	if not boss.marks.has_mark(&"duelist_feint"): order.append(&"duelist_feint")
	if player.health.current_hp < player.health.max_hp * 0.4: order.append(&"duelist_guarded_retreat")
	var reserve := player.skill_cost(&"duelist_fatal_riposte")
	for skill: StringName in order:
		var target := boss if ClassKitRegistry.skill_definition(skill).targeting == SkillDefinition.Targeting.SINGLE_TARGET else null
		# Keep SP for the Riposte: the other actives only spend above that reserve.
		if skill != &"duelist_fatal_riposte" and player.current_sp < player.skill_cost(skill) + reserve: continue
		if skill == &"duelist_fatal_riposte": tally["pending_charges"] = flank.sentence(player)
		if _use(player, skill, target, tally):
			if skill == &"duelist_fatal_riposte": tally["riposte_charges"].append(int(tally["pending_charges"]))
			return planned_swing
	if distance > 110.0 and player.skill_rank(&"dash") > 0 and player.dash_cooldown <= 0.0 and player.current_sp >= player.skill_cost(&"dash") + 30.0:
		if player.use_dash(player.global_position.direction_to(boss.global_position)):
			tally["casts"][&"dash"] = int(tally["casts"].get(&"dash", 0)) + 1
			return planned_swing
	if distance <= 120.0 and player.skill_rank(&"slash") > 0 and player.slash_cooldown <= 0.0 and player.current_sp >= player.skill_cost(&"slash") + 40.0:
		var foes: Array[CombatActor] = [boss]
		if player.use_slash(player.global_position.direction_to(boss.global_position), foes):
			tally["casts"][&"slash"] = int(tally["casts"].get(&"slash", 0)) + 1
	return planned_swing

func _use(player: PlayerActor, skill: StringName, target: CombatActor, tally: Dictionary) -> bool:
	if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): return false
	if target != null and not player.can_target_skill(skill, target): return false
	if not player.use_kit_skill(skill, target.global_position if target != null else player.global_position, target): return false
	tally["casts"][skill] = int(tally["casts"].get(skill, 0)) + 1
	return true
