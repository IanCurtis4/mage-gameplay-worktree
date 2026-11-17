extends SceneTree
## E09 K4 (C4.2) — short integrated combat of the Lâmina Arcana against a real boss
## (`forest_ancient_warden`, category boss), without adds (the companion signal is not
## connected) and without augments, once per review build of
## scripts/classes/mg_la/review_builds.json. The boss runs its own AI and strikes through
## RunController._on_enemy_attack_requested. The Lâmina plays the loop of the sheet like a
## player would: Marca → Refração → Salto às costas → crystal blade alternating the three
## elements → Sentença Prismática; when hurt, the base Teleporte is the exit, then a new
## Refração and Salto. Casts go through PlayerActor.use_kit_skill and the base skills,
## ticking real gameplay clocks. Fixture profile only.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const BUILDS_PATH := "res://scripts/classes/mg_la/review_builds.json"
const STEP := 0.05
const DURATION := 120.0
const BOSS_HP := 20000.0
const MARK := &"arcane_blade_refracted_mark"
const REFRACTION := &"arcane_blade_refraction"
const LEAP := &"arcane_blade_prismatic_leap"
const SENTENCE := &"arcane_blade_prismatic_sentence"
const SPECTER := &"arcane_blade_prism_specter"
## Legal level-30 allocation for the sheet's INT > DES > AGI (fixture, not a save).
const ATTRIBUTES: Dictionary[StringName, int] = {&"int": 50, &"dex": 36, &"agi": 20, &"vit": 8}

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
	print("E09 K4 mg_la boss combat: %d checks, %d failures" % [checks, failures])
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
	_check(ProgressionRules.attribute_points_available(ProgressionRules.MAX_BASE_XP, snapshot.attribute_allocations, &"mage") >= 0, "%s: legal level-30 attributes INT > DES > AGI" % label)
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
	player.configure(navigation, RunState.from_build("mg-la-boss-" + label, snapshot))
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(400, 450)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 53
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	# Base spells (Lança de Gelo) resolve as an instant hit here (no projectile layer).
	player.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, target: CombatActor, _facing: Vector2, _count: int) -> void: controller._on_attack_requested(request, target))
	var kit := player.kit
	_check(kit != null and kit.get_script().resource_path == "res://scripts/classes/mg_la/mg_la_kit.gd", "%s: the production Lâmina Arcana kit is attached" % label)
	if kit == null:
		controller.free()
		return
	var flank: FlankAuthority = kit.get("flank")
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "k4_boss_" + label
	occurrence.mob_base_id = &"forest_ancient_warden"
	occurrence.category_id = &"boss"
	occurrence.origin_id = &"trial_stage_4"
	var boss := EnemyActor.new()
	boss.global_position = Vector2(700, 450) # the spawn home (leash centre) is the boss post
	var configured := boss.configure_occurrence(occurrence, player.run_state.effect_catalog().mob_catalog(), navigation, player)
	_check(configured.get("ok", false), "%s: boss occurrence configures: %s" % [label, configured])
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
	_check(boss.hard_controls.boss and FlankRules.category_of(boss) == &"boss" and controller.enemies.size() == 1, "%s: a single boss, no adds" % label)
	var tally := {"casts": {}, "swings": 0, "landed": 0, "sentence_charges": [], "leap_back": 0, "leaps": 0, "elements": {}, "exits": 0}
	var sentence_results: Array[Dictionary] = []
	boss.health.damage_applied.connect(func(result: Dictionary) -> void:
		var skill := StringName(result.get("skill_id", &""))
		if skill == SENTENCE: sentence_results.append(result)
		if skill == LEAP:
			tally["leaps"] = int(tally["leaps"]) + 1
			if FlankRules.result_flags(result).get("side") == &"back": tally["leap_back"] = int(tally["leap_back"]) + 1
		var element := String(result.get("effect_snapshot", {}).get("arcane_blade_element", ""))
		if not element.is_empty(): tally["elements"][element] = int(tally["elements"].get(element, 0)) + 1)
	controller.enemy_attack_committed.connect(func(event: Dictionary) -> void:
		if int(event.get("attacker_id", 0)) == boss.get_instance_id(): tally["swings"] = int(tally["swings"]) + 1)
	var time := 0.0
	var min_hp := player.health.max_hp
	while time < DURATION and player.is_alive() and boss.is_alive():
		var hp_before := player.health.current_hp
		_rotation(player, boss, kit, flank, tally)
		boss._process(STEP)
		player._process(STEP)
		if player.health.current_hp < hp_before: tally["landed"] = int(tally["landed"]) + 1
		min_hp = minf(min_hp, player.health.current_hp)
		time += STEP
	var casts: Dictionary = tally["casts"]
	print("%s: %.1fs boss %.0f/%.0f player %.0f/%.0f (min %.0f) casts %s swings %d landed %d sentence charges %s leaps %d (back %d) elements %s reactions %d sentence gained %d" % [label, time, boss.health.current_hp, BOSS_HP, player.health.current_hp, player.health.max_hp, min_hp, casts, int(tally["swings"]), int(tally["landed"]), tally["sentence_charges"], int(tally["leaps"]), int(tally["leap_back"]), tally["elements"], int(kit.get("reaction_serial")), flank.gained_total])
	_check(player.is_alive(), "%s: the Lâmina Arcana survives the boss" % label)
	_check(not boss.is_alive(), "%s: the Lâmina alone defeats the boss (%.0f left after %.1f s)" % [label, boss.health.current_hp, time])
	_check(int(tally["swings"]) > 0 and int(tally["landed"]) > 0, "%s: the boss really strikes the Lâmina (%d swings, %d landed)" % [label, int(tally["swings"]), int(tally["landed"])])
	_check(int(casts.get(REFRACTION, 0)) >= 2 and int(casts.get(LEAP, 0)) >= 2 and int(casts.get(SENTENCE, 0)) >= 3, "%s: Refração, Salto and Sentença are used in the loop: %s" % [label, casts])
	_check(int(tally["leaps"]) >= 2 and int(tally["leap_back"]) == int(tally["leaps"]), "%s: every Salto strike lands from behind the boss (%d/%d)" % [label, int(tally["leap_back"]), int(tally["leaps"])])
	var elements: Dictionary = tally["elements"]
	_check(int(elements.get("fire", 0)) > 0 and int(elements.get("ice", 0)) > 0 and int(elements.get("lightning", 0)) > 0, "%s: the crystal blade cuts the boss with the three elements: %s" % [label, elements])
	_check(int(kit.get("reaction_serial")) >= 1, "%s: the three elements trigger the prismatic reaction" % label)
	var charged := false
	for charges: Variant in tally["sentence_charges"]: charged = charged or int(charges) >= 4
	_check(charged, "%s: the Sentença spends a built Sentence (%s)" % [label, tally["sentence_charges"]])
	var lethal := false
	for result: Dictionary in sentence_results: lethal = lethal or bool(FlankRules.result_flags(result).get("lethal", false))
	_check(not sentence_results.is_empty() and not lethal and flank.lethal_total == 0, "%s: the Sentença on the boss is only high damage, never certain death (A4)" % label)
	_check(int(casts.get(&"teleport", 0)) >= 1 and int(tally.get("exit_sight", 0)) == int(casts.get(&"teleport", 0)), "%s: the base Teleporte is the exit: every one breaks the boss sight (%d/%d)" % [label, int(tally.get("exit_sight", 0)), int(casts.get(&"teleport", 0))])
	if int(build["evolution_ranks"].get(SPECTER, 0)) >= 1:
		_check(int(casts.get(SPECTER, 0)) >= 1, "%s: the Espectro de Prisma is used" % label)
	_check(controller.enemies.size() <= 1, "%s: no add joined the fight" % label)
	controller.free()

## Fixed priority rotation, like a player: keep the boss marked; concealed → Salto às
## costas; Sentença with 4+ charges; Espectro on cooldown; hurt → base Teleporte away (the
## exit), then Refração and Salto back; Refração when the Salto is ready; Lança de Gelo
## from afar. The crystal blade basic attack runs on its own when not concealed.
func _rotation(player: PlayerActor, boss: EnemyActor, kit: ClassKit, flank: FlankAuthority, tally: Dictionary) -> void:
	if player.has_active_cast(): return
	var distance := player.global_position.distance_to(boss.global_position)
	if flank.victim(player) != boss:
		if _use(player, MARK, boss, tally): return
	if player.kit_concealed():
		player.target = null # never cancel the Refração with a basic attack
		_use(player, LEAP, boss, tally)
		return
	if flank.sentence(player) >= 4 and distance <= 80.0 + player.collision_radius + boss.collision_radius:
		tally["pending_charges"] = flank.sentence(player)
		if _use(player, SENTENCE, boss, tally):
			tally["sentence_charges"].append(int(tally["pending_charges"]))
			tally["exit_next"] = true
			return
	if _use(player, SPECTER, null, tally): return
	# The exit: once the Sentence is spent and the boss faces her (or when hurt), the
	# Lâmina leaves with the base Teleporte; the boss loses sight of her.
	var facing_her: bool = FlankRules.side_between(boss, player)["side"] == FlankRules.FRONT
	var exit: bool = (bool(tally.get("exit_next", false)) and facing_her) or player.health.current_hp < player.health.max_hp * 0.45
	if exit and distance < 160.0 and player.skill_cooldown(&"teleport") <= 0.0 and player.current_sp >= player.skill_cost(&"teleport"):
		var away := boss.global_position.direction_to(player.global_position)
		if away.is_zero_approx(): away = Vector2.LEFT
		var point := player.global_position + away * 280.0
		point = point.clamp(Vector2(40, 40), Vector2(1360, 860))
		if player.use_teleport(point):
			tally["exit_next"] = false
			tally["casts"][&"teleport"] = int(tally["casts"].get(&"teleport", 0)) + 1
			var threat := boss.get(&"threat") as ThreatService
			if threat != null and threat.sight_broken(String(boss.call(&"threat_id_for", player))): tally["exit_sight"] = int(tally.get("exit_sight", 0)) + 1
			return
	if player.skill_cooldown(LEAP) <= 0.0 and player.current_sp >= player.skill_cost(REFRACTION) + player.skill_cost(LEAP):
		if _use(player, REFRACTION, null, tally): return
	if distance > 200.0 and player.skill_cooldown(&"ice_spear") <= 0.0 and player.current_sp >= player.skill_cost(&"ice_spear") + 40.0:
		if player.use_spear(&"ice_spear", boss):
			tally["casts"][&"ice_spear"] = int(tally["casts"].get(&"ice_spear", 0)) + 1
	if player.target != boss: player.pursue(boss)

func _use(player: PlayerActor, skill: StringName, target: CombatActor, tally: Dictionary) -> bool:
	if player.skill_rank(skill) <= 0 or player.skill_cooldown(skill) > 0.0 or player.current_sp < player.skill_cost(skill): return false
	if target != null and not player.can_target_skill(skill, target): return false
	if not player.use_kit_skill(skill, target.global_position if target != null else player.global_position, target): return false
	tally["casts"][skill] = int(tally["casts"].get(skill, 0)) + 1
	return true
