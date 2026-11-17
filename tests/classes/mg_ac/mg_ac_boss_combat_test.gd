extends SceneTree
## E09 K2 (C4.2) — short integrated combat of the Taumaturgo against a real boss
## (`forest_ancient_warden`, category boss), without adds (the companion signal is
## not connected) and without augments, once per review build of
## scripts/classes/mg_ac/review_builds.json. The boss runs its own AI and attacks
## through RunController._on_enemy_attack_requested; the player casts the kit through
## PlayerActor.use_kit_skill and the origin spells through RunController._execute_skill
## (entry note, real projectiles of RunController._on_mage_projectile_requested, ticked
## here), with real gameplay clocks. Fixture profile only; nothing is written to disk.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const BUILDS_PATH := "res://scripts/classes/mg_ac/review_builds.json"
const KIT_PATH := "res://scripts/classes/mg_ac/mg_ac_kit.gd"
const STEP := 0.05
const DURATION := 30.0
## Higher than the K1 fixture: the origin Mage alone (basic attack, Bola de Fogo)
## burns 6000 HP in ~5 s, before the kit loop turns. The loop needs a longer fight.
const BOSS_HP := 24000.0
## Legal level-30 allocation for the sheet's INT > VIT > DES (fixture, not a save).
const ATTRIBUTES: Dictionary[StringName, int] = {&"int": 50, &"vit": 36, &"dex": 20, &"agi": 5, &"str": 5}
const SPELL_ELEMENTS := {&"fireball": &"fire", &"ice_spear": &"ice", &"lightning": &"lightning"}

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
	print("E09 K2 mg_ac boss combat: %d checks, %d failures" % [checks, failures])
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
	snapshot.base_class_id = &"mage"
	snapshot.attribute_allocations = ATTRIBUTES.duplicate()
	_check(ProgressionRules.attribute_points_available(ProgressionRules.MAX_BASE_XP, snapshot.attribute_allocations, &"mage") >= 0, "%s: legal level-30 attributes INT > VIT > DES" % label)
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
	player.configure(navigation, RunState.from_build("mg-ac-boss-" + label, snapshot))
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
	_check(kit != null and kit.get_script().resource_path == KIT_PATH, "%s: the production Taumaturgo kit is attached" % label)
	if kit == null:
		controller.free()
		return
	var authority: SanctuaryAuthority = kit.get("sanctuary")
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "k2_boss_" + label
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
	_check(boss.hard_controls.boss and controller.enemies.size() == 1, "%s: a single boss, no adds" % label)
	var tally := {"casts": {}, "alternations": 0, "max_grace": 0, "dawn_half": 0, "elements_seen": {}, "tricolor": false}
	var hits_taken: Array[Dictionary] = []
	var damage_by_skill := {}
	boss.health.damage_applied.connect(func(result: Dictionary) -> void:
		var skill := StringName(result.get("skill_id", &""))
		damage_by_skill[skill] = float(damage_by_skill.get(skill, 0.0)) + float(result.get("actual_damage", 0.0)))
	var gained_before := authority.grace.gained_total
	var time := 0.0
	player.target = boss
	while time < DURATION and player.is_alive() and boss.is_alive():
		var facing := player.global_position.direction_to(boss.global_position)
		if not facing.is_zero_approx(): player.character_animation.state.face(facing)
		var hp_before := player.health.current_hp
		_rotation(controller, player, boss, authority, kit, tally)
		boss._process(STEP)
		player._process(STEP)
		for node: Node in get_nodes_in_group("player_projectiles"):
			if is_instance_valid(node) and node.has_method(&"_process"): node.call(&"_process", STEP)
		if player.health.current_hp < hp_before: hits_taken.append({"t": time})
		tally["max_grace"] = maxi(int(tally["max_grace"]), authority.grace.charges)
		var zone := authority.zone(&"votive")
		if zone != null:
			tally["elements_seen"][zone.element] = true
			if zone.element == &"tricolor": tally["tricolor"] = true
		time += STEP
	var casts: Dictionary = tally["casts"]
	var gained := authority.grace.gained_total - gained_before
	print("%s: %.1fs boss %.0f/%.0f player %.0f/%.0f casts %s grace +%d (max %d) spent %d hits taken %d elements %s half-cost casts %d" % [label, time, boss.health.current_hp, BOSS_HP, player.health.current_hp, player.health.max_hp, casts, gained, int(tally["max_grace"]), authority.grace.spent_total, hits_taken.size(), tally["elements_seen"].keys(), int(tally["dawn_half"])])
	print("%s: damage by skill %s" % [label, damage_by_skill])
	_check(player.is_alive(), "%s: the Taumaturgo survives the boss" % label)
	_check(boss.health.current_hp < BOSS_HP * 0.5, "%s: the boss loses at least half of its HP (%.0f left)" % [label, boss.health.current_hp])
	_check(not hits_taken.is_empty(), "%s: the boss really attacks the Taumaturgo" % label)
	_check(int(casts.get(&"thaumaturge_votive_circle", 0)) >= 1 and int(casts.get(&"thaumaturge_prismatic_judgment", 0)) >= 2, "%s: Círculo and Juízo are used in the loop: %s" % [label, casts])
	_check(int(casts.get(&"fireball", 0)) >= 1 and int(casts.get(&"ice_spear", 0)) >= 1 and int(casts.get(&"lightning", 0)) >= 1, "%s: the base spells feed the circle: %s" % [label, casts])
	_check(gained > 0 and authority.grace.spent_total > 0, "%s: Grace is gained by alternating and spent (+%d / -%d)" % [label, gained, authority.grace.spent_total])
	var alternation_keys := 0
	for key: String in authority.grace._claim_order:
		if key.contains("@alt:"): alternation_keys += 1
	_check(alternation_keys > 0, "%s: alternation events inside the circle fill Grace (%d events)" % [label, alternation_keys])
	_check(tally["tricolor"], "%s: the circle turns tricolor (Coro or Aurora)" % label)
	if int(build["evolution_ranks"].get("thaumaturge_convergent_dawn", 0)) >= 1:
		_check(int(casts.get(&"thaumaturge_convergent_dawn", 0)) >= 1 and int(tally["dawn_half"]) >= 1, "%s: the Aurora is used and spells are cast at half SP" % label)
	_check(controller.enemies.size() == 1, "%s: no add joined the fight" % label)
	controller.free()

## Fixed priority rotation: Circle under the Taumaturgo, Aurora, Juízo with 3+ Grace
## (any amount in the Aurora), Refração when hurt, Mudança de Altar, then the origin
## spells, choosing an element different from the last one cast inside.
func _rotation(controller: RunController, player: PlayerActor, boss: CombatActor, authority: SanctuaryAuthority, kit: ClassKit, tally: Dictionary) -> void:
	if player.has_active_cast(): return
	var zone := authority.zone(&"votive")
	var dawn: bool = kit.call(&"dawn_active")
	var order: Array[StringName] = []
	if (zone == null or not zone.owner_inside) and not dawn: order.append(&"thaumaturge_votive_circle")
	if zone != null and int(tally["casts"].get(&"thaumaturge_prismatic_judgment", 0)) >= 1: order.append(&"thaumaturge_convergent_dawn")
	if authority.grace.charges >= 3 or (dawn and authority.grace.charges >= 1): order.append(&"thaumaturge_prismatic_judgment")
	if player.health.current_hp < player.health.max_hp * 0.6 and authority.grace.charges >= 1: order.append(&"thaumaturge_healing_refraction")
	if zone != null and authority.grace.charges < 3: order.append(&"thaumaturge_altar_shift")
	for skill: StringName in order:
		if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): continue
		var target := boss if ClassKitRegistry.skill_definition(skill).targeting == SkillDefinition.Targeting.SINGLE_TARGET else null
		if player.use_kit_skill(skill, boss.global_position if target != null else player.global_position, target):
			tally["casts"][skill] = int(tally["casts"].get(skill, 0)) + 1
			return
	var last := StringName(kit.get("last_element"))
	var spells: Array[StringName] = [&"fireball", &"ice_spear", &"lightning"]
	for spell: StringName in spells:
		if SPELL_ELEMENTS[spell] == last: continue
		if player.skill_rank(spell) <= 0 or player.skill_cooldown(spell) > 0.0 or player.current_sp < player.skill_cost(spell) + 10.0: continue
		if spell != &"fireball" and not player.can_target_skill(spell, boss): continue
		var halved := player.skill_cost(spell) < player.base_skill_cost(spell)
		var sp_before := player.current_sp
		controller._execute_skill(spell, boss.global_position, boss)
		if player.current_sp < sp_before:
			tally["casts"][spell] = int(tally["casts"].get(spell, 0)) + 1
			if halved: tally["dawn_half"] = int(tally["dawn_half"]) + 1
			return
