extends SceneTree
## E10a T5 (C3.2, 4.1) — integrated combat of the Acólito base at every job level from 1 to 19
## against the Mestre das Feras of the E06 script (`test_beast_master`, rare, the species of the
## playtest route; the companion signal is not connected, so no adds), without augments. One
## fight per job level J: the build spends the J − 1 base skill points on a fixed legal order,
## the attributes follow a legal allocation of base level J, the enemy level follows the stage
## of the route that matches J (1: levels 2, 4, 6, 9, 12, 15). The master runs its own AI and
## attacks through RunController._on_enemy_attack_requested; the player casts through
## PlayerActor.use_kit_skill and attacks with the basic attack while the gameplay clocks tick.
## Fixture profile only; nothing is written to disk.
const STEP := 0.05
const DURATION := 60.0
## Stand-in HP of the master by job level: 600 + 220 per level (820 at job 1, 4780 at job 19).
const FIGHT_HP_BASE := 600.0
const FIGHT_HP_PER_JOB := 220.0
## Spending order of the base points (every prefix is legal): the Acólito that serves first
## (Luz, Prece, Escudo) and then contemplates (Selo, Sussurro, Visão, Devoção).
const ORDER: Array[StringName] = [
	&"acolyte_punishing_light", &"acolyte_prayer", &"acolyte_punishing_light", &"acolyte_shadow_seal", &"acolyte_votive_shield",
	&"acolyte_punishing_light", &"acolyte_disturbing_whisper", &"acolyte_prayer", &"acolyte_punishing_light", &"acolyte_shadow_seal",
	&"acolyte_protective_faith", &"acolyte_devotion", &"acolyte_eldritch_vision", &"acolyte_punishing_light", &"acolyte_prayer",
	&"acolyte_votive_shield", &"acolyte_disturbing_whisper", &"acolyte_shadow_seal", &"acolyte_protective_faith"]
const STAGES: Array[StringName] = [&"trial_stage_1", &"trial_stage_1", &"trial_stage_1", &"trial_stage_2", &"trial_stage_2", &"trial_stage_2", &"trial_stage_3", &"trial_stage_3", &"trial_stage_3", &"trial_stage_4", &"trial_stage_4", &"trial_stage_4", &"trial_stage_5", &"trial_stage_5", &"trial_stage_5", &"trial_stage_5", &"trial_stage_6", &"trial_stage_6", &"trial_stage_6"]

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var summary: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	_check(ORDER.size() == 19 and STAGES.size() == 19, "the order spends the 19 base points and every job level has a stage")
	for job_level: int in range(1, 20): _fight(job_level)
	print("E10a T5 acolyte boss combat: %d checks, %d failures" % [checks, failures])
	for line: String in summary: print(line)
	quit(1 if failures > 0 else 0)

## Base-level-J experience and a legal attribute allocation that favours INT and VIT.
func _attributes_for(base_level: int) -> Dictionary[StringName, int]:
	var xp := 0
	while ProgressionRules.base_level_for_xp(xp) < base_level and xp < ProgressionRules.MAX_BASE_XP: xp += 10
	var initial := IdentityIds.initial_attributes(&"acolyte")
	var allocations: Dictionary[StringName, int] = {}
	var points := ProgressionRules.attribute_points_granted(xp)
	var cycle: Array[StringName] = [&"int", &"vit", &"int", &"int", &"dex", &"vit"]
	var progressed := true
	while progressed:
		progressed = false
		for attribute: StringName in cycle:
			var cost := ProgressionRules.attribute_increment_cost(int(initial[attribute]) + int(allocations.get(attribute, 0)), 1)
			if cost > 0 and cost <= points:
				points -= cost
				allocations[attribute] = int(allocations.get(attribute, 0)) + 1
				progressed = true
	return allocations

func _ranks_for(job_level: int) -> Dictionary[StringName, int]:
	var ranks: Dictionary[StringName, int] = {}
	for index: int in job_level - 1:
		var skill := ORDER[index]
		ranks[skill] = int(ranks.get(skill, 0)) + 1
	return ranks

func _fight(job_level: int) -> void:
	var label := "job %d" % job_level
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1400, 900), [], 20.0)
	var controller := Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	controller.navigation = navigation
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = job_level
	snapshot.base_level = job_level
	snapshot.base_class_id = &"acolyte"
	snapshot.attribute_allocations = _attributes_for(job_level)
	var catalog := ProfileCatalog.pilot()
	var xp := 0
	while ProgressionRules.base_level_for_xp(xp) < job_level and xp < ProgressionRules.MAX_BASE_XP: xp += 10
	_check(ProgressionRules.attribute_points_available(xp, snapshot.attribute_allocations, &"acolyte") >= 0, "%s: legal attributes for base level %d" % [label, job_level])
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"acolyte", &"")
	var ranks := _ranks_for(job_level)
	var legal := catalog.validate_purchased_ranks(&"acolyte", &"", job_level, ranks)
	_check(legal.get("ok", false) and catalog.skill_points_spent(ranks, ProfileCatalog.BASE_WALLET) == job_level - 1, "%s: %d base points, legal: %s" % [label, job_level - 1, legal])
	snapshot.skill_ranks = {}
	for skill: StringName in ranks: snapshot.skill_ranks[skill] = ranks[skill]
	var slots: Array[Variant] = []
	for skill: StringName in ClassBaseRegistry.skill_ids(&"acolyte"):
		if ranks.has(skill) and slots.size() < 5 and ClassKitRegistry.skill_definition(skill).category == SkillDefinition.Category.ACTIVE: slots.append(skill)
	snapshot.active_slots = slots
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("acolyte-boss-%d" % job_level, snapshot))
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(500, 450)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 47
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	# Stand-in for the flight of Main._on_mage_projectile_requested: a projectile with a target lands at once.
	player.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, victim: CombatActor, _direction: Vector2, _count: int) -> void:
		if is_instance_valid(victim): controller._on_attack_requested(request, victim))
	var origin := player.origin_kit
	_check(player.kit == null and origin != null and origin.get_script().resource_path == "res://scripts/classes/bases/acolyte/acolyte_base.gd", "%s: only the production Acólito base is attached" % label)
	_check(player.class_id == &"acolyte" and is_equal_approx(player._basic_range(), 220.0), "%s: the Acólito class with a 220 basic range" % label)
	if origin == null:
		controller.free()
		return
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "t5_master_%d" % job_level
	occurrence.mob_base_id = &"test_beast_master"
	occurrence.category_id = &"rare"
	occurrence.origin_id = STAGES[job_level - 1]
	var master := EnemyActor.new()
	var configured := master.configure_occurrence(occurrence, player.run_state.effect_catalog().mob_catalog(), navigation, player)
	_check(configured.get("ok", false), "%s: the Mestre das Feras configures at %s: %s" % [label, STAGES[job_level - 1], configured])
	if not configured.get("ok", false):
		master.free()
		controller.free()
		return
	master.global_position = player.global_position + Vector2(170, 0)
	master.attack_requested.connect(controller._on_enemy_attack_requested)
	master.mob_skill_requested.connect(controller._on_mob_skill_requested)
	master.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	master.status_damage_requested.connect(controller._on_attack_requested)
	controller.add_child(master)
	controller.enemies.append(master)
	master.set_process(false)
	# The catalog species is a weak test mob (192-348 HP): the stand-in HP keeps the fight long enough to run the loop, as the Sacerdote test does with its 6000.
	var master_hp := FIGHT_HP_BASE + FIGHT_HP_PER_JOB * float(job_level)
	master.health.max_hp = master_hp
	master.health.current_hp = master_hp
	_check(controller.enemies.size() == 1 and not master.hard_controls.boss, "%s: a single Mestre das Feras (rare), no adds" % label)
	var tally := {"casts": {}, "madness": 0.0, "slowdown": 0}
	var hits_taken := 0
	var time := 0.0
	player.target = master
	while time < DURATION and player.is_alive() and master.is_alive():
		var facing := player.global_position.direction_to(master.global_position)
		if not facing.is_zero_approx(): player.character_animation.state.face(facing)
		var hp_before := player.health.current_hp
		_rotation(player, master, origin, tally)
		master._process(STEP)
		player._process(STEP)
		if player.health.current_hp < hp_before: hits_taken += 1
		tally["madness"] = maxf(float(tally["madness"]), MadnessAuthority.madness_of(master))
		time += STEP
	var casts: Dictionary = tally["casts"]
	var damage := 1.0 - master.health.current_hp / master_hp
	var line := "%s (%s, %d pts): %.1fs master %.0f%% of %.0f taken, player %.0f/%.0f %s, casts %s, hits taken %d, max Madness %.0f" % [label, STAGES[job_level - 1], job_level - 1, time, damage * 100.0, master_hp, player.health.current_hp, player.health.max_hp, "alive" if player.is_alive() else "dead", casts, hits_taken, float(tally["madness"])]
	summary.append(line)
	_check(damage > 0.0, "%s: the Acólito hurts the Mestre das Feras (%.1f%%)" % [label, damage * 100.0])
	_check(player.is_alive() or not master.is_alive() or damage > 0.0, "%s: the fight resolves without error" % label)
	_check(hits_taken > 0, "%s: the master really attacks the Acólito" % label)
	if job_level >= 2:
		_check(int(casts.get(&"acolyte_punishing_light", 0)) >= 1, "%s: Luz Punitiva is cast" % label)
	if job_level >= 3:
		_check(int(casts.get(&"acolyte_prayer", 0)) >= 1 or player.health.current_hp >= player.health.max_hp * 0.7, "%s: the Prece answers damage" % label)
	if job_level >= 8:
		_check(int(casts.get(&"acolyte_disturbing_whisper", 0)) >= 1 and int(casts.get(&"acolyte_shadow_seal", 0)) >= 1, "%s: Selo Sombrio and Sussurro are cast (%s)" % [label, casts])
		_check(float(tally["madness"]) > 0.0, "%s: the master gathers Madness from the base (%.0f)" % [label, float(tally["madness"])])
	if job_level >= 14:
		_check(int(casts.get(&"acolyte_eldritch_vision", 0)) >= 1, "%s: Visão Eldritch is cast" % label)
	# At every job level the Acólito beats the master of its stage alone, hurt but alive.
	_check(player.is_alive() and not master.is_alive(), "%s: the Acólito beats the Mestre das Feras of its stage alone" % label)
	_check(controller.enemies.size() == 1, "%s: no add joined the fight" % label)
	controller.free()

## Fixed priority rotation: Prece when hurt, Escudo Votivo when pressed, Visão Eldritch before
## the Selo/Sussurro pair, the Sussurro in the cone, the Selo, Luz Punitiva otherwise; the basic
## attack runs on its own.
func _rotation(player: PlayerActor, master: CombatActor, origin: ClassKit, tally: Dictionary) -> void:
	if player.has_active_cast(): return
	var hp := player.health.current_hp / player.health.max_hp
	var order: Array[StringName] = []
	if hp < 0.7: order.append(&"acolyte_prayer")
	if hp < 0.9: order.append(&"acolyte_votive_shield")
	if player.skill_rank(&"acolyte_eldritch_vision") > 0 and player.skill_cooldown(&"acolyte_disturbing_whisper") <= 0.0 and player.skill_cooldown(&"acolyte_shadow_seal") <= 0.0 and not bool(origin.get("vision_charged")): order.append(&"acolyte_eldritch_vision")
	order.append(&"acolyte_disturbing_whisper")
	if not bool(origin.call(&"seal_active")): order.append(&"acolyte_shadow_seal")
	order.append(&"acolyte_punishing_light")
	for skill: StringName in order:
		if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): continue
		var definition := ClassKitRegistry.skill_definition(skill)
		var single: bool = definition != null and definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET
		if player.use_kit_skill(skill, master.global_position if single else player.global_position, master if single else null):
			tally["casts"][skill] = int(tally["casts"].get(skill, 0)) + 1
			return
