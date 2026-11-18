extends SceneTree
## E10a T6 (C3.2) — short integrated combat of the Sacerdote against a real boss
## (`forest_ancient_warden`, category boss), without adds (the companion signal is not connected)
## and without augments, once per review build of scripts/classes/priest/review_builds.json.
## The boss runs its own AI and attacks through RunController._on_enemy_attack_requested; the
## player casts through PlayerActor.use_kit_skill, ticking real gameplay clocks. The Acólito is
## the T1 fixture base (the production base is still a skeleton until T5), so the builds'
## acolyte_* ranks run on the fixture's Prece (heals 10), Escudo Votivo and Luz Punitiva.
## Fixture profile only; nothing is written to disk.
const FixtureBase = preload("res://scripts/classes/fixture/fixture_base.gd")
const BUILDS_PATH := "res://scripts/classes/priest/review_builds.json"
const STEP := 0.05
const DURATION := 40.0
const BOSS_HP := 6000.0
## Legal level-30 allocation (fixture, not a save): the Sacerdote scales with INT and VIT.
const ATTRIBUTES: Dictionary[StringName, int] = {&"int": 40, &"vit": 30, &"dex": 10, &"agi": 5}

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
	ClassBaseRegistry.install_fixture(&"acolyte", FixtureBase.new())
	var file := FileAccess.open(BUILDS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_check(parsed is Dictionary and parsed.get("builds", []).size() == 2, "two review builds to fight with")
	if parsed is Dictionary:
		for build: Variant in parsed["builds"]: _fight(build)
	ClassKitRegistry.clear_fixtures()
	print("E10a T6 priest boss combat: %d checks, %d failures" % [checks, failures])
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
	snapshot.base_class_id = &"acolyte"
	snapshot.attribute_allocations = ATTRIBUTES.duplicate()
	_check(ProgressionRules.attribute_points_available(ProgressionRules.MAX_BASE_XP, snapshot.attribute_allocations, &"acolyte") >= 0, "%s: legal level-30 attributes INT > VIT" % label)
	snapshot.evolution_id = &"priest"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"acolyte", &"priest")
	snapshot.skill_ranks = {}
	for skill: Variant in build["base_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["base_ranks"][skill])
	for skill: Variant in build["evolution_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["evolution_ranks"][skill])
	# Five active slots: the kit's own shortcuts first, then the base ones the build lists.
	var actives: Array[Variant] = []
	for skill: Variant in build["shortcuts"]:
		if actives.size() < 5 and StringName(skill) in ClassKitRegistry.skill_ids(&"priest"): actives.append(StringName(skill))
	snapshot.active_slots = actives
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("priest-boss-" + label, snapshot))
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(500, 450)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 43
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	var kit := player.kit
	_check(kit != null and kit.get_script().resource_path == "res://scripts/classes/priest/priest_kit.gd", "%s: the production Sacerdote kit is attached" % label)
	_check(player.origin_kit != null and player.origin_kit.get_script() == FixtureBase, "%s: the fixture Acólito is the origin module" % label)
	if kit == null:
		controller.free()
		return
	var authority: SanctuaryAuthority = kit.get("sanctuary")
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "t6_boss_" + label
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
	var tally := {"casts": {}, "max_grace": 0, "max_slow": 0.0, "rooted": false, "exposed": false, "mitigated": 0, "hour_judgments": 0}
	var hits_taken: Array[Dictionary] = []
	boss.health.damage_applied.connect(func(result: Dictionary) -> void:
		if bool(result.get("landed", false)) and StringName(result.get("skill_id", &"")) == &"priest_judgment": tally["judgments_landed"] = int(tally.get("judgments_landed", 0)) + 1)
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
		tally["max_slow"] = maxf(float(tally["max_slow"]), boss.slow_fraction)
		tally["rooted"] = bool(tally["rooted"]) or boss.is_rooted()
		tally["exposed"] = bool(tally["exposed"]) or boss.received_damage_sources.has(&"priest_exposed")
		time += STEP
	var casts: Dictionary = tally["casts"]
	var gained := authority.grace.gained_total - gained_before
	print("%s: %.1fs boss %.0f/%.0f player %.0f/%.0f casts %s grace +%d (max %d) spent %d hits taken %d slow %.2f exposed %s" % [label, time, boss.health.current_hp, BOSS_HP, player.health.current_hp, player.health.max_hp, casts, gained, int(tally["max_grace"]), authority.grace.spent_total, hits_taken.size(), float(tally["max_slow"]), tally["exposed"]])
	_check(player.is_alive(), "%s: the Sacerdote survives the boss" % label)
	_check(boss.health.current_hp < BOSS_HP * 0.5, "%s: the boss loses at least half of its HP (%.0f left)" % [label, boss.health.current_hp])
	_check(not hits_taken.is_empty(), "%s: the boss really attacks the Sacerdote" % label)
	_check(int(casts.get(&"priest_sanctuary", 0)) >= 2, "%s: the Santuário is renewed through the fight: %s" % [label, casts])
	_check(gained > 0 and authority.grace.spent_total > 0 and int(tally["max_grace"]) >= 3, "%s: Grace is gained and spent (+%d / -%d, max %d)" % [label, gained, authority.grace.spent_total, int(tally["max_grace"])])
	_check(int(casts.get(&"priest_judgment", 0)) >= 2 and int(tally.get("judgments_landed", 0)) >= 2, "%s: the Juízo lands on the boss (%d casts)" % [label, int(casts.get(&"priest_judgment", 0))])
	_check(int(casts.get(&"acolyte_prayer", 0)) >= 1, "%s: the Prece of the base feeds the loop" % label)
	if int(build["evolution_ranks"].get("priest_holy_hour", 0)) >= 1:
		_check(int(casts.get(&"priest_holy_hour", 0)) >= 1, "%s: the Hora Santa is used" % label)
	if int(build["evolution_ranks"].get("priest_light_seal", 0)) >= 1:
		_check(int(casts.get(&"priest_light_seal", 0)) >= 1 and float(tally["max_slow"]) > 0.25 and not bool(tally["rooted"]), "%s: the Selo de Luz slows the boss and never roots it" % label)
	if int(build["evolution_ranks"].get("priest_exorcist", 0)) >= 1:
		_check(bool(tally["exposed"]), "%s: with nothing to remove, the Exorcista leaves the boss Exposto" % label)
	if int(build["evolution_ranks"].get("priest_aegis", 0)) >= 1:
		_check(int(casts.get(&"priest_aegis", 0)) >= 1 or player.health.current_hp >= player.health.max_hp * 0.6, "%s: the Égide is used when the Sacerdote is hurt" % label)
	_check(controller.enemies.size() == 1, "%s: no add joined the fight" % label)
	controller.free()

## Fixed priority rotation: Santuário between the Sacerdote and the boss, Selo de Luz, Hora
## Santa inside the circle, Égide when hurt, Juízo with 3+ Grace (any in the Hora), Prece and
## Escudo Votivo (Grace from the base), Luz Punitiva otherwise; the basic attack runs on its own.
func _rotation(player: PlayerActor, boss: CombatActor, authority: SanctuaryAuthority, _kit: ClassKit, tally: Dictionary) -> void:
	if player.has_active_cast(): return
	var hour: bool = _kit.call(&"hour_active")
	var order: Array[StringName] = []
	if authority.zone(&"sanctuary") == null: order.append(&"priest_sanctuary")
	if not authority.is_sealed(boss): order.append(&"priest_light_seal")
	if authority.zone(&"sanctuary") != null and authority.grace.charges >= 2: order.append(&"priest_holy_hour")
	if player.health.current_hp < player.health.max_hp * 0.6: order.append(&"priest_aegis")
	if authority.grace.charges >= 3 or hour: order.append(&"priest_judgment")
	order.append_array([&"acolyte_prayer", &"acolyte_votive_shield", &"acolyte_punishing_light"])
	for skill: StringName in order:
		if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): continue
		var definition := ClassKitRegistry.skill_definition(skill)
		var single: bool = definition != null and definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET
		var point := player.global_position.lerp(boss.global_position, 0.5) if skill == &"priest_sanctuary" else (boss.global_position if single else player.global_position)
		if player.use_kit_skill(skill, point, boss if single else null):
			tally["casts"][skill] = int(tally["casts"].get(skill, 0)) + 1
			if skill == &"priest_judgment" and hour: tally["hour_judgments"] = int(tally["hour_judgments"]) + 1
			return
