extends SceneTree
## E09 K1 (C4.2) — short integrated combat of the Paladino against a real boss
## (`forest_ancient_warden`, category boss), without adds (the companion signal is
## not connected) and without augments, once per review build of
## scripts/classes/sp_ac/review_builds.json. The boss runs its own AI and attacks
## through RunController._on_enemy_attack_requested; the player casts through
## PlayerActor.use_kit_skill and the base skills, ticking real gameplay clocks.
## Fixture profile only; nothing is written to disk.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const BUILDS_PATH := "res://scripts/classes/sp_ac/review_builds.json"
const STEP := 0.05
const DURATION := 30.0
const BOSS_HP := 6000.0
## Legal level-30 allocation for the sheet's VIT > FOR > INT (fixture, not a save).
const ATTRIBUTES: Dictionary[StringName, int] = {&"vit": 50, &"str": 36, &"int": 15, &"dex": 10, &"agi": 5}

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
	print("E09 K1 sp_ac boss combat: %d checks, %d failures" % [checks, failures])
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
	_check(ProgressionRules.attribute_points_available(ProgressionRules.MAX_BASE_XP, snapshot.attribute_allocations, &"swordsman") >= 0, "%s: legal level-30 attributes VIT > FOR > INT" % label)
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
	player.configure(navigation, RunState.from_build("sp-ac-boss-" + label, snapshot))
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
	occurrence.occurrence_id = "k1_boss_" + label
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
	_check(boss.hard_controls.boss and controller.enemies.size() == 1, "%s: a single boss, no adds" % label)
	var tally := {"casts": {}, "grace_gained": 0, "frontal_hits": 0, "boss_hits": 0, "light_on_sealed": 0, "max_grace": 0, "hour_impacts": 0}
	var hits_taken: Array[Dictionary] = []
	boss.health.damage_applied.connect(func(result: Dictionary) -> void:
		if bool(result.get("landed", false)): tally["boss_hits"] = int(tally["boss_hits"]) + 1)
	var gained_before := authority.grace.gained_total
	var time := 0.0
	player.target = boss
	while time < DURATION and player.is_alive() and boss.is_alive():
		var facing := player.global_position.direction_to(boss.global_position)
		if not facing.is_zero_approx(): player.character_animation.state.face(facing)
		var hp_before := player.health.current_hp
		_rotation(player, boss, authority, kit, tally)
		boss._process(STEP)
		player._process(STEP)
		if player.health.current_hp < hp_before: hits_taken.append({"t": time})
		tally["max_grace"] = maxi(int(tally["max_grace"]), authority.grace.charges)
		time += STEP
	var casts: Dictionary = tally["casts"]
	var gained := authority.grace.gained_total - gained_before
	print("%s: %.1fs boss %.0f/%.0f player %.0f/%.0f casts %s grace +%d (max %d) spent %d hits taken %d" % [label, time, boss.health.current_hp, BOSS_HP, player.health.current_hp, player.health.max_hp, casts, gained, int(tally["max_grace"]), authority.grace.spent_total, hits_taken.size()])
	_check(player.is_alive(), "%s: the Paladino survives the boss" % label)
	_check(boss.health.current_hp < BOSS_HP * 0.5, "%s: the boss loses at least half of its HP (%.0f left)" % [label, boss.health.current_hp])
	_check(not hits_taken.is_empty(), "%s: the boss really attacks the Paladino" % label)
	_check(int(casts.get(&"paladin_oath", 0)) >= 2 and int(casts.get(&"paladin_consecrated_impact", 0)) >= 3 and int(casts.get(&"paladin_condemned_seal", 0)) >= 1, "%s: Juramento, Impacto and Selo are used in the loop: %s" % [label, casts])
	_check(gained > 0 and authority.grace.spent_total > 0, "%s: Grace is gained from the boss and spent by the Impacto (+%d / -%d)" % [label, gained, authority.grace.spent_total])
	var boss_marker := ":%d:" % boss.get_instance_id()
	var from_boss_hits := 0
	for key: String in authority.grace._claim_order:
		if key.contains(boss_marker) and key.ends_with(":%d" % player.get_instance_id()): from_boss_hits += 1
	_check(from_boss_hits > 0, "%s: the boss's frontal hits fill Grace (%d events)" % [label, from_boss_hits])
	if int(build["evolution_ranks"].get("paladin_oath_hour", 0)) >= 1:
		_check(int(casts.get(&"paladin_oath_hour", 0)) >= 1, "%s: the Hora do Juramento is used" % label)
	_check(controller.enemies.size() == 1, "%s: no add joined the fight" % label)
	controller.free()

## Fixed priority rotation: Oath in front of the boss, Seal, Hour, Égide when hurt,
## Impacto with 3+ Grace (any amount in the Hora), Shield Wall and Perseverance
## (Grace from the base), Provoke on the sealed boss; the basic attack runs on its own.
func _rotation(player: PlayerActor, boss: CombatActor, authority: SanctuaryAuthority, kit: ClassKit, tally: Dictionary) -> void:
	if player.has_active_cast(): return
	var hour: bool = kit.call(&"hour_active")
	var order: Array[StringName] = []
	if authority.zone(&"oath") == null: order.append(&"paladin_oath")
	if not authority.is_sealed(boss): order.append(&"paladin_condemned_seal")
	if authority.zone(&"oath") != null: order.append(&"paladin_oath_hour")
	if player.health.current_hp < player.health.max_hp * 0.6: order.append(&"paladin_oath_aegis")
	if authority.grace.charges >= 3 or hour: order.append(&"paladin_consecrated_impact")
	for skill: StringName in order:
		if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): continue
		var target := boss if ClassKitRegistry.skill_definition(skill).targeting == SkillDefinition.Targeting.SINGLE_TARGET else null
		if player.use_kit_skill(skill, boss.global_position if target != null else player.global_position, target):
			tally["casts"][skill] = int(tally["casts"].get(skill, 0)) + 1
			if skill == &"paladin_consecrated_impact" and hour: tally["hour_impacts"] = int(tally["hour_impacts"]) + 1
			return
	for base: StringName in [&"perseverance", &"provoke"]:
		if player.skill_rank(base) <= 0 or player.skill_cooldown(base) > 0.0 or player.current_sp < player.skill_cost(base) + 30.0: continue
		# Provoke enters like RunController._execute_skill: the selected target is noted.
		if base == &"provoke": player.note_base_commit(base, boss.global_position, boss)
		var used := player.use_perseverance() if base == &"perseverance" else (authority.is_sealed(boss) and player.use_provoke(boss))
		player.clear_base_commit_note()
		if used:
			tally["casts"][base] = int(tally["casts"].get(base, 0)) + 1
			return
