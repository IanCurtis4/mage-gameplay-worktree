extends SceneTree
## E10a T7 (C3.2, §4.3) — short integrated combat of the Cultista against the Guardião
## Antigo of the forest phase (`forest_ancient_warden`, category boss, summons a companion):
## 1. once per review build (scripts/classes/cultist/review_builds.json) without adds (the
##    companion signal is not connected) and without augments;
## 2. with the companion: the warden's own AI asks for it and RunController spawns it
##    (`_on_companion_requested`), and during the Disorientation some of the boss's hits fall
##    on that minion (commit deflection of the T4), the boss never changing target.
## The boss runs its own AI and attacks through RunController._on_enemy_attack_requested;
## the player casts through PlayerActor.use_kit_skill, with real gameplay clocks. The Acólito
## base is the production module when it is ready (T5 composed), else the T7 stand-in.
## Fixture profiles only; nothing is written to disk.
const FixtureBase = preload("res://scripts/classes/cultist/fixture/cultist_fixture_base.gd")
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const BUILDS_PATH := "res://scripts/classes/cultist/review_builds.json"
const KIT_PATH := "res://scripts/classes/cultist/cultist_kit.gd"
const STEP := 0.05
const DURATION := 30.0
## High enough for the 30 s loop (two windows and their immunity) before the boss falls.
const BOSS_HP := 24000.0
## Legal level-30 allocation for the sheet's INT > VIT > DES (fixture, not a save).
const ATTRIBUTES: Dictionary[StringName, int] = {&"int": 50, &"vit": 36, &"dex": 20, &"agi": 5, &"str": 5}

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var base_label := ""

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	if ClassBaseRegistry.ready_for_play(&"acolyte") and ClassBaseRegistry.module(&"acolyte") != null and ClassBaseRegistry.module(&"acolyte").get(&"madness") != null:
		base_label = "production base"
	else:
		_check(ClassBaseRegistry.install_fixture(&"acolyte", FixtureBase.new()), "T7 stand-in base installed (the T5 base is not in this branch)")
		base_label = "T7 stand-in base"
	print("Acólito base: " + base_label)
	var file := FileAccess.open(BUILDS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_check(parsed is Dictionary and parsed.get("builds", []).size() == 2, "two review builds to fight with")
	if parsed is Dictionary:
		for build: Variant in parsed["builds"]: _fight(build, false)
		_fight(parsed["builds"][0], true)
	ClassKitRegistry.clear_fixtures()
	KitDecoy.unregister_drawer(MadnessRules.IDOL_DRAWER)
	print("E10a T7 cultist boss combat: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _fight(build: Dictionary, with_companion: bool) -> void:
	var label := String(build["id"]) + (" +companion" if with_companion else "")
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
	_check(ProgressionRules.attribute_points_available(ProgressionRules.MAX_BASE_XP, snapshot.attribute_allocations, &"acolyte") >= 0, "%s: legal level-30 attributes INT > VIT > DES" % label)
	snapshot.evolution_id = &"cultist"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"acolyte", &"cultist")
	snapshot.skill_ranks = {}
	for group: String in ["base_ranks", "evolution_ranks"]:
		for skill: Variant in build[group]:
			if int(build[group][skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(build[group][skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	var actives: Array[Variant] = []
	for skill: Variant in build["shortcuts"]:
		if actives.size() < 5 and StringName(skill) in ClassKitRegistry.skill_ids(&"cultist"): actives.append(StringName(skill))
	snapshot.active_slots = actives
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("cultist-boss-" + label, snapshot))
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(500, 450)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 47
	controller.enemies = []
	controller.encounter_active = true
	player.attack_requested.connect(controller._on_attack_requested)
	player.mage_projectile_requested.connect(controller._on_mage_projectile_requested)
	var kit := player.kit
	_check(kit != null and kit.get_script().resource_path == KIT_PATH, "%s: the production Cultista kit is attached" % label)
	var authority := MadnessAuthority.of(player) as MadnessAuthority
	_check(authority != null, "%s: the origin holds the Madness authority" % label)
	if kit == null or authority == null:
		controller.free()
		return
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "t7_boss_" + label.replace(" ", "_").replace("+", "")
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
	if with_companion: boss.companion_requested.connect(controller._on_companion_requested)
	controller.add_child(boss)
	controller.enemies.append(boss)
	boss.set_process(false)
	boss.health.max_hp = BOSS_HP
	boss.health.current_hp = BOSS_HP
	_check(boss.hard_controls.boss and controller.enemies.size() == 1, "%s: the fight starts with the boss alone" % label)
	var tally := {"casts": {}, "disoriented": 0, "immune_seen": false, "retargeted": false, "max_ecstasy": 0, "deflected": 0, "minion_ids": {}}
	var hits_taken := 0
	var damage_by_skill := {}
	boss.health.damage_applied.connect(func(result: Dictionary) -> void:
		var skill := StringName(result.get("skill_id", &""))
		damage_by_skill[skill] = float(damage_by_skill.get(skill, 0.0)) + float(result.get("actual_damage", 0.0)))
	var time := 0.0
	var was_disoriented := false
	player.target = boss
	while time < DURATION and player.is_alive() and boss.is_alive():
		var facing := player.global_position.direction_to(boss.global_position)
		if not facing.is_zero_approx(): player.character_animation.state.face(facing)
		var hp_before := player.health.current_hp
		_rotation(player, boss, authority, kit, tally)
		for actor: CombatActor in controller.enemies.duplicate():
			if is_instance_valid(actor) and actor.is_alive():
				if actor != boss and not tally["minion_ids"].has(actor.get_instance_id()): _watch_minion(actor as EnemyActor, boss, tally)
				actor._process(STEP)
		player._process(STEP)
		for node: Node in get_nodes_in_group("player_projectiles"):
			if is_instance_valid(node) and node.has_method(&"_process"): node.call(&"_process", STEP)
		if player.health.current_hp < hp_before: hits_taken += 1
		var state := MadnessAuthority.state_of(boss)
		if state == MadnessRules.STATE_DISORIENTED and not was_disoriented: tally["disoriented"] = int(tally["disoriented"]) + 1
		was_disoriented = state == MadnessRules.STATE_DISORIENTED
		if state == MadnessRules.STATE_IMMUNE: tally["immune_seen"] = true
		if boss.has_target_override() or boss.combat_target() != player: tally["retargeted"] = true
		tally["max_ecstasy"] = maxi(int(tally["max_ecstasy"]), authority.ecstasy.charges)
		time += STEP
	var casts: Dictionary = tally["casts"]
	print("%s [%s]: %.1fs boss %.0f/%.0f player %.0f/%.0f casts %s windows %d max ecstasy %d hits taken %d enemies %d deflected %d" % [label, base_label, time, boss.health.current_hp, BOSS_HP, player.health.current_hp, player.health.max_hp, casts, int(tally["disoriented"]), int(tally["max_ecstasy"]), hits_taken, controller.enemies.size(), int(tally["deflected"])])
	print("%s: damage by skill %s" % [label, damage_by_skill])
	_check(player.is_alive(), "%s: the Cultista survives the boss" % label)
	_check(boss.health.current_hp < BOSS_HP * 0.5, "%s: the boss loses at least half of its HP (%.0f left)" % [label, boss.health.current_hp])
	_check(hits_taken > 0, "%s: the boss really attacks the Cultista" % label)
	_check(int(casts.get(&"cultist_abyss_gaze", 0)) >= 2 and int(casts.get(&"cultist_revelation", 0)) >= 1, "%s: Olhar and Revelação are used in the loop: %s" % [label, casts])
	_check(float(damage_by_skill.get(&"cultist_abyss_gaze", 0.0)) > 0.0, "%s: the gaze deals continuous damage" % label)
	_check(int(tally["disoriented"]) >= 2, "%s: the boss lives in Disorientation windows (%d)" % [label, int(tally["disoriented"])])
	_check(tally["immune_seen"], "%s: each window is followed by immunity" % label)
	_check(not tally["retargeted"], "%s: the boss never changes target" % label)
	_check(not boss.marks.has_mark(MadnessRules.MARK_DELIRIUM), "%s: the boss never enters Delirium" % label)
	if int(build["evolution_ranks"].get("cultist_ecstasy", 0)) > 0: _check(int(tally["max_ecstasy"]) >= 2, "%s: windows feed the Êxtase (max %d)" % [label, int(tally["max_ecstasy"])])
	if with_companion:
		_check(not tally["minion_ids"].is_empty(), "%s: the warden summons its companion through RunController" % label)
		_check(int(tally["deflected"]) >= 1, "%s: during the Disorientation the boss's hits fall on the minion beside it (%d)" % [label, int(tally["deflected"])])
	else:
		_check(controller.enemies.size() == 1, "%s: no add joined the fight" % label)
	controller.free()

## Counts the boss hits relayed onto a minion (deflection at the commit, authored by the player).
func _watch_minion(minion: EnemyActor, boss: EnemyActor, tally: Dictionary) -> void:
	tally["minion_ids"][minion.get_instance_id()] = true
	minion.set_process(false)
	minion.health.max_hp = 100000.0
	minion.health.current_hp = 100000.0
	minion.health.damage_applied.connect(func(result: Dictionary) -> void:
		var relay: Dictionary = result.get("effect_snapshot", {}).get(EnemyActor.RELAY_KEY, {})
		if EnemyActor.is_relay_result(result) and int(relay.get("actor_id", 0)) == boss.get_instance_id(): tally["deflected"] = int(tally["deflected"]) + 1)

## Fixed priority: never break a channel; Revelação, Ídolo, Geometria and Delírio
## Compartilhado when ready; the base Selo and Sussurro for Madness; Escudo Votivo and
## Prece when hurt (they pay the Êxtase onus); then the gaze.
func _rotation(player: PlayerActor, boss: CombatActor, _authority: MadnessAuthority, kit: ClassKit, tally: Dictionary) -> void:
	if player.has_active_cast() or bool(kit.call(&"channeling")): return
	var order: Array[StringName] = []
	if player.health.current_hp < player.health.max_hp * 0.7: order.append(&"acolyte_votive_shield")
	if player.health.current_hp < player.health.max_hp * 0.5: order.append(&"acolyte_prayer")
	# The Revelação forces a window out of turn: kept for when the boss is immune.
	if MadnessAuthority.state_of(boss) == MadnessRules.STATE_IMMUNE: order.append(&"cultist_revelation")
	order.append_array([&"cultist_impossible_idol", &"cultist_impossible_geometry", &"cultist_shared_delirium", &"acolyte_shadow_seal"])
	if player.global_position.distance_to(boss.global_position) <= 150.0: order.append(&"acolyte_disturbing_whisper")
	order.append(&"cultist_abyss_gaze")
	for skill: StringName in order:
		if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): continue
		var definition := ClassCatalog.skill_definition(skill)
		var target := boss if definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET else null
		var point := boss.global_position if definition.targeting in [SkillDefinition.Targeting.POINT, SkillDefinition.Targeting.SINGLE_TARGET] else player.global_position
		if skill == &"cultist_impossible_idol": point = player.global_position.lerp(boss.global_position, 0.5)
		if player.use_kit_skill(skill, point, target):
			tally["casts"][skill] = int(tally["casts"].get(skill, 0)) + 1
			return
