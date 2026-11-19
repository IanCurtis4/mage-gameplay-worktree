extends SceneTree
## E10a T5 — Acólito base module (`acolyte`) invariants (docs/epics/e10a/t5_contract.md): catalog
## data and pt-BR texts, learning rows and prerequisites, the two initial skills, Luz Punitiva
## (projectile, light), Prece (four pulses), Escudo Votivo (shield, expiry), Selo Sombrio (DoT,
## accuracy, Madness, one mark), Sussurro (cone, push, boss stays), Visão Eldritch (range and the
## doubled Madness), Delírio on the base, Devoção (light/shadow alternation by element, also for the
## evolution's commits), Fé Protetora (heal bonus, no recursion), the Madness authority wiring,
## build change, death, pause, both snapshot formats, the evolution destinations and the world path.
## T15 (A15.3): the barrier_received hook of the seam (CombatActor.grant_barrier) and the Fé
## Protetora on every barrier, the Votive counted once.
## Fixture profiles only; nothing is written to disk.
const WorldFixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const BASE_PATH := "res://scripts/classes/bases/acolyte/acolyte_base.gd"
const SKILLS: Array[StringName] = [&"acolyte_punishing_light", &"acolyte_prayer", &"acolyte_votive_shield", &"acolyte_shadow_seal", &"acolyte_disturbing_whisper", &"acolyte_eldritch_vision", &"acolyte_devotion", &"acolyte_protective_faith"]

class Controller extends RunController:
	func _ready() -> void: pass

## T15: an evolution module that records the barrier hook and answers a programmed value.
class BarrierProbeKit extends ClassKit:
	var seen: Array[Dictionary] = []
	var answer: Variant = null
	var add := 0.0
	func kit_id() -> StringName: return &"t15_barrier_probe"
	func barrier_received(_player: PlayerActor, capacity: float, context: Dictionary) -> float:
		seen.append({"capacity": capacity, "context": context.duplicate()})
		if answer != null: return float(answer)
		return capacity + add

## Calls the effect drawers inside a real _draw() pass.
class DrawProbe extends Node2D:
	var base: ClassKit
	var effects: Array[StringName] = []
	var drawn: Dictionary = {}
	func _draw() -> void:
		for effect_id: StringName in effects: drawn[effect_id] = base.draw_vfx(effect_id, self, {"dir": Vector2.RIGHT}, Vector2(60, 60), 0.4)

var checks := 0
var failures := 0
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var base: ClassKit
var madness: MadnessAuthority
var navigation: ArenaNavigation
var mob_serial := 0
var projectiles: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	_check_catalog()
	_check_learning()
	await _check_drawers()
	_check_basic_attack_and_vision()
	_check_light()
	_check_prayer_and_faith()
	_check_votive_shield()
	_check_barrier_hook()
	_check_shadow_seal()
	_check_whisper()
	_check_madness_wiring()
	_check_devotion()
	_check_build_change_death_and_pause()
	_check_evolution_destinations()
	_check_snapshot_formats()
	_check_world_path()
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	print("E10a T5 acolyte base: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixture --------------------------------------------------------------------------

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	projectiles.clear()
	paused = false

func _all_ranks(rank: int = 5, passive_rank: int = 3) -> Dictionary:
	var ranks := {}
	for skill: StringName in SKILLS: ranks[skill] = passive_rank if skill in [&"acolyte_devotion", &"acolyte_protective_faith"] else rank
	return ranks

func _make_player(nav: ArenaNavigation, ranks: Dictionary, evolution: StringName = &"") -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL if evolution != &"" else ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL
	snapshot.base_class_id = &"acolyte"
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"acolyte", evolution)
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	snapshot.active_slots = [&"acolyte_punishing_light", &"acolyte_prayer", &"acolyte_votive_shield", &"acolyte_shadow_seal", &"acolyte_disturbing_whisper"]
	var actor := PlayerActor.new()
	actor.configure(nav, RunState.from_build("acolyte-" + str(checks), snapshot))
	return actor

func _setup(ranks: Dictionary = {}, evolution: StringName = &"") -> void:
	_cleanup()
	navigation = ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	player = _make_player(navigation, ranks if not ranks.is_empty() else _all_ranks(), evolution)
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(400, 350)
	player.character_animation.state.face(Vector2.RIGHT)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 31
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	player.mage_projectile_requested.connect(func(skill_id: StringName, request: DamageRequest, victim: CombatActor, _facing: Vector2, _count: int) -> void: projectiles.append({"skill_id": skill_id, "request": request, "victim": victim}))
	base = player.origin_kit
	madness = base.get("madness") if base != null else null
	player.max_sp = 1000.0
	player.current_sp = 1000.0

## A real catalog mob of the forest phase.
func _mob(mob_id: StringName, at: Vector2, category: StringName = &"normal") -> EnemyActor:
	mob_serial += 1
	var hostile := EnemyActor.new()
	hostile.global_position = at
	var spawn := MobOccurrence.new()
	spawn.occurrence_id = "t5_%s_%03d" % [mob_id, mob_serial]
	spawn.mob_base_id = mob_id
	spawn.category_id = category
	spawn.origin_id = &"trial_stage_1"
	var configured := hostile.configure_occurrence(spawn, BuildContentLoader.pilot().mob_catalog(), navigation, player)
	_check(configured.get("ok", false), "real mob %s configured: %s" % [mob_id, configured])
	controller.add_child(hostile)
	hostile.set_process(false)
	hostile.attack_requested.connect(controller._on_enemy_attack_requested)
	hostile.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(hostile)
	return hostile

func _boss(at: Vector2) -> EnemyActor:
	return _mob(&"forest_ancient_warden", at, &"boss")

func _hits_on(enemy: CombatActor) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	enemy.health.damage_applied.connect(func(result: Dictionary) -> void: hits.append(result))
	return hits

func _enemy_request(source: CombatActor, amount: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.context = player.run_state.effect_ledger.new_root(source.get_instance_id(), false, "", false, {})
	return request

func _ready_cast(skill: StringName) -> void:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp

func _cast(skill: StringName, enemy: CombatActor = null) -> bool:
	_ready_cast(skill)
	var definition := ClassKitRegistry.skill_definition(skill)
	var single := definition != null and definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET
	return player.use_kit_skill(skill, enemy.global_position if enemy != null else player.global_position, enemy if single else null)

## Gameplay clock: enemy statuses and override clocks, then the player's tick (as PlayerActor._process).
func _advance(delta: float) -> void:
	for candidate: Variant in controller.enemies:
		var hostile := candidate as EnemyActor
		if is_instance_valid(hostile) and hostile.is_alive():
			hostile.advance_statuses(delta)
			hostile._advance_target_override(delta)
	player._process(delta)

## Natural regeneration may move HP by a fraction of a point while the clock ticks.
func _near(a: float, b: float, tolerance: float = 1.5) -> bool:
	return absf(a - b) < tolerance

func _matk() -> float:
	return player.stat_breakdown.value(&"magic_attack")

# --- Catalog ----------------------------------------------------------------------------

func _check_catalog() -> void:
	var module := ClassBaseRegistry.module(&"acolyte")
	_check(module != null and module.get_script().resource_path == BASE_PATH and module is ClassBase, "the production module is the acolyte base")
	_check(ClassBaseRegistry.validate(&"acolyte").get("ok", false), "registry validation passes: " + str(ClassBaseRegistry.validate(&"acolyte")))
	_check(module.ready_for_play() and ClassBaseRegistry.ready_for_play(&"acolyte") and module.base_id() == &"acolyte" and module.kit_id() == &"acolyte" and module.display_name() == "Acólito", "the base is ready for play and named in pt-BR")
	_check(module.initial_attributes() == {&"str": 3, &"agi": 4, &"vit": 7, &"int": 8, &"dex": 5, &"luk": 3} and IdentityIds.initial_attributes(&"acolyte") == module.initial_attributes(), "attributes: INT 8, VIT 7, DEX 5, AGI 4, STR 3, LUK 3 (D2)")
	var total := 0
	for value: int in module.initial_attributes().values(): total += value
	_check(total == 30, "the six attributes sum 30")
	var attack := module.basic_attack()
	_check(attack["delivery"] == &"magic" and is_equal_approx(float(attack["range"]), 220.0) and is_equal_approx(float(attack["power"]), 1.0), "basic attack: magic, range 220, power 1.0")
	_check(module.starting_skill_ids() == [&"acolyte_punishing_light", &"acolyte_prayer"] and module.starting_passive_id() == &"acolyte_protective_faith", "starting skills Luz Punitiva and Prece; starting passive Fé Protetora")
	var definition := ClassCatalog.class_definition(&"acolyte")
	_check(definition != null and definition.display_name == "Acólito" and definition.basic_range == 220.0 and definition.basic_delivery == &"mage" and definition.skill_ids == [&"acolyte_punishing_light", &"acolyte_prayer"] and definition.passive_id == &"acolyte_protective_faith", "ClassCatalog composes the class from the module")
	var definitions := module.skill_definitions()
	var ids: Array[StringName] = []
	for item: SkillDefinition in definitions: ids.append(item.id)
	_check(ids == SKILLS and ids == ClassBaseRegistry.skill_ids(&"acolyte"), "the eight skills in the order of section 1")
	var elements := {&"acolyte_punishing_light": &"light", &"acolyte_prayer": &"light", &"acolyte_votive_shield": &"light", &"acolyte_shadow_seal": &"shadow", &"acolyte_disturbing_whisper": &"shadow", &"acolyte_eldritch_vision": &"", &"acolyte_devotion": &"", &"acolyte_protective_faith": &"light"}
	for index: int in definitions.size():
		var item := definitions[index]
		var active: bool = ClassBaseRegistry.SKILL_CATEGORIES[&"acolyte"][index] == &"active"
		_check(item.handler_id == SkillDefinition.Handler.KIT and item.is_rank_catalog_valid() and item.ranks.size() == (5 if active else 3) and item.element == elements[item.id] and String(item.id).begins_with("acolyte_"), "%s: kit handler, ranks 1-%d, element '%s', prefix" % [item.id, 5 if active else 3, elements[item.id]])
		_check(ClassCatalog.skill_definition(item.id) != null and ClassKitRegistry.skill_owner(item.id) == &"acolyte", "%s is published by the catalog (ready base)" % item.id)
	_check(definitions[0].element == &"light" and definitions[3].element == &"shadow" and definitions[4].element == &"shadow", "Luz Punitiva is light; Selo Sombrio and Sussurro are shadow (C3 4.1)")
	_check(definitions[0].targeting == SkillDefinition.Targeting.SINGLE_TARGET and definitions[0].can_crit and definitions[1].targeting == SkillDefinition.Targeting.SELF and definitions[4].targeting == SkillDefinition.Targeting.SINGLE_TARGET, "targeting of Luz, Prece and Sussurro")
	for definition_without_mobility: SkillDefinition in definitions: _check(definition_without_mobility.action_kind != SkillDefinition.ActionKind.MOBILITY, "%s is not a mobility skill (the base has none)" % definition_without_mobility.id)
	var texts := module.skill_texts()
	for skill: StringName in ids:
		var text: Dictionary = texts.get(skill, {})
		var ranks: Array = text.get("ranks", [])
		_check(not String(text.get("flavor", "")).is_empty() and not String(text.get("effect", "")).is_empty() and not String(text.get("mechanics", "")).is_empty() and ranks.size() == (3 if skill in [&"acolyte_devotion", &"acolyte_protective_faith"] else 5), "%s has pt-BR flavor, effect, mechanics and per-rank tooltip" % skill)
		for line: Variant in ranks: _check(String(line).begins_with("R"), "%s rank tooltip line: %s" % [skill, line])
		_check(SkillPresentation.mechanics_of(skill) == String(text["mechanics"]) and not ClassCatalog.skill_definition(skill).display_name.is_empty(), "%s reaches SkillPresentation" % skill)
		var recipe := FeedbackRecipeCatalog.recipe(skill)
		_check(not recipe.generic, "%s has its own feedback recipe" % skill)
	_check(FeedbackRecipeCatalog.recipe(&"acolyte_punishing_light").element == &"light" and FeedbackRecipeCatalog.recipe(&"acolyte_shadow_seal").element == &"shadow" and FeedbackRecipeCatalog.recipe(&"acolyte_disturbing_whisper").element == &"shadow", "light and shadow recipes (D5)")
	var basic := FeedbackRecipeCatalog.recipe(&"basic_attack", &"acolyte")
	_check(not basic.generic and basic.family == &"projectile" and basic.element == &"light", "the basic attack of the base is a light projectile")
	var effects := module.vfx_effects()
	_check(effects.keys() == [&"acolyte_light_bolt", &"acolyte_prayer_glow", &"acolyte_votive_ward", &"acolyte_seal_mark", &"acolyte_whisper_wave", &"acolyte_vision_eye"], "six reserved flipbook IDs with the acolyte_ prefix")
	_check(ClassKitRegistry.vfx_effect(&"acolyte_shadow_seal", &"effect_start")["effect_id"] == &"acolyte_seal_mark" and ClassKitRegistry.vfx_effect(&"acolyte_punishing_light", &"impact")["effect_id"] == &"acolyte_light_bolt", "effects reach the presentation catalog by skill and kind")
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid() and catalog.base_class_is_available(&"acolyte"), "the production catalog is valid and offers the Acólito at creation (A11)")
	_check(IdentityIds.base_class_ids() == [&"swordsman", &"mage", &"archer"] and IdentityIds.registered_base_ids() == [&"acolyte"], "the E00 list is stable; the registered base is listed apart")
	_check(ClassKitRegistry.actor_kind(&"", &"acolyte") == ClassKitRegistry.base_actor_kind(&"acolyte"), "the body follows the base folder rule (reserve body while there is no art)")

func _check_learning() -> void:
	var module := ClassBaseRegistry.module(&"acolyte")
	var rows := module.learning_entries()
	_check(rows.size() == 8, "one learning row per skill")
	var expected := {
		&"acolyte_punishing_light": {}, &"acolyte_prayer": {},
		&"acolyte_votive_shield": {&"acolyte_prayer": 1}, &"acolyte_shadow_seal": {&"acolyte_punishing_light": 1},
		&"acolyte_disturbing_whisper": {&"acolyte_shadow_seal": 1}, &"acolyte_eldritch_vision": {&"acolyte_disturbing_whisper": 1},
		&"acolyte_devotion": {&"acolyte_punishing_light": 1, &"acolyte_shadow_seal": 1}, &"acolyte_protective_faith": {&"acolyte_votive_shield": 1}}
	for row: Dictionary in rows:
		var skill: StringName = row["skill_id"]
		var passive := skill in [&"acolyte_devotion", &"acolyte_protective_faith"]
		_check(row["category"] == (&"passive" if passive else &"active") and int(row["max_purchased_rank"]) == (3 if passive else 5) and int(row.get("free_rank", 0)) == 0 and int(row["job_level"]) == 1, "%s: category, cap and no free rank" % skill)
		_check(row["prerequisites"] == expected[skill], "%s closes its prerequisites in the module" % skill)
		_check(SkillDependencyRules.requirements_for(skill) == expected[skill], "%s: SkillDependencyRules reads the module" % skill)
	var catalog := ProfileCatalog.pilot()
	var ok_light := catalog.validate_purchased_ranks(&"acolyte", &"", 5, {&"acolyte_punishing_light": 2, &"acolyte_shadow_seal": 1})
	_check(ok_light.get("ok", false), "Selo Sombrio is legal with Luz Punitiva: " + str(ok_light))
	_check(not catalog.validate_purchased_ranks(&"acolyte", &"", 5, {&"acolyte_shadow_seal": 1}).get("ok", false), "Selo Sombrio without Luz Punitiva is refused")
	_check(not catalog.validate_purchased_ranks(&"acolyte", &"", 6, {&"acolyte_punishing_light": 1, &"acolyte_devotion": 1}).get("ok", false), "Devoção needs Selo Sombrio as well")
	_check(not catalog.validate_purchased_ranks(&"acolyte", &"", 6, {&"acolyte_prayer": 1, &"acolyte_protective_faith": 1}).get("ok", false), "Fé Protetora needs Escudo Votivo")
	var full := catalog.validate_purchased_ranks(&"acolyte", &"", ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL, {&"acolyte_punishing_light": 5, &"acolyte_prayer": 1, &"acolyte_shadow_seal": 1, &"acolyte_disturbing_whisper": 1, &"acolyte_eldritch_vision": 5, &"acolyte_votive_shield": 1, &"acolyte_protective_faith": 3, &"acolyte_devotion": 1})
	_check(catalog.skill_points_spent({&"acolyte_punishing_light": 5, &"acolyte_prayer": 1, &"acolyte_shadow_seal": 1, &"acolyte_disturbing_whisper": 1, &"acolyte_eldritch_vision": 5, &"acolyte_votive_shield": 1, &"acolyte_protective_faith": 3, &"acolyte_devotion": 1}, ProfileCatalog.BASE_WALLET) == 18 and full.get("ok", false), "a chain through Visão Eldritch and Fé Protetora is legal on the base wallet (18 points): " + str(full))
	# The Sacerdote builds of T6 spend their 19 base points on this module.
	var file := FileAccess.open("res://scripts/classes/priest/review_builds.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_check(parsed is Dictionary, "the Sacerdote review builds are readable")
	if parsed is Dictionary:
		for build: Variant in parsed["builds"]:
			var purchased: Dictionary[StringName, int] = {}
			for skill: Variant in build["base_ranks"]: purchased[StringName(skill)] = int(build["base_ranks"][skill])
			var legal := catalog.validate_purchased_ranks(&"acolyte", &"", ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL, purchased)
			_check(catalog.skill_points_spent(purchased, ProfileCatalog.BASE_WALLET) == 19 and legal.get("ok", false), "%s: its 19 base points are legal on the real base: %s" % [build["id"], legal])

# --- Drawers --------------------------------------------------------------------------------

func _check_drawers() -> void:
	var probe := DrawProbe.new()
	probe.base = ClassBaseRegistry.module(&"acolyte")
	for effect_id: StringName in probe.base.vfx_effects(): probe.effects.append(effect_id)
	probe.effects.append(&"acolyte_unknown")
	root.add_child(probe)
	owned.append(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	var drawn_all := true
	for effect_id: StringName in probe.base.vfx_effects(): drawn_all = drawn_all and bool(probe.drawn.get(effect_id, false))
	_check(drawn_all and not bool(probe.drawn.get(&"acolyte_unknown", true)), "the six code drawers run in a real _draw() pass; an unknown ID is refused")

# --- Basic attack and Visão Eldritch ------------------------------------------------------------

func _check_basic_attack_and_vision() -> void:
	_setup()
	var profile := base.basic_attack_profile(player)
	_check(is_equal_approx(float(profile["range"]), 220.0) and profile["delivery"] == &"mage", "the base profile: range 220, mage delivery")
	_check(is_equal_approx(player._basic_range(), 220.0), "the player reads the base profile (origin, no evolution)")
	_check(_cast(&"acolyte_eldritch_vision"), "Visão Eldritch commits")
	_check(is_equal_approx(float(base.basic_attack_profile(player)["range"]), 220.0 + 120.0) and is_equal_approx(player._basic_range(), 340.0), "R5: the basic range grows by 120 while it lasts")
	_check(bool(base.get("vision_charged")) and is_equal_approx(float(base.get("vision_remaining")), 10.0), "R5: 10 s, charged")
	_advance(10.1)
	_check(not bool(base.get("vision_charged")) and is_equal_approx(player._basic_range(), 220.0), "the reinforcement and its charge end with the duration")
	for row: Array in [[1, 6.0, 40.0, 14.0, 18.0], [3, 8.0, 80.0, 15.0, 16.0], [5, 10.0, 120.0, 16.0, 14.0]]:
		_setup(_all_ranks(row[0], 1))
		_cast(&"acolyte_eldritch_vision")
		_check(is_equal_approx(float(base.get("vision_remaining")), row[1]) and is_equal_approx(float(base.get("vision_range_bonus")), row[2]) and is_equal_approx(player.skill_cost(&"acolyte_eldritch_vision"), row[3]) and is_equal_approx(player.skill_cooldown(&"acolyte_eldritch_vision"), row[4]), "Visão Eldritch R%d numbers: %ss, +%d, %s SP, %ss" % [row[0], row[1], row[2], row[3], row[4]])

# --- Luz Punitiva -------------------------------------------------------------------------

func _check_light() -> void:
	_setup()
	var enemy := _mob(&"forest_wolf", Vector2(550, 350))
	_check(_cast(&"acolyte_punishing_light", enemy), "Luz Punitiva commits on a target in range")
	_check(projectiles.size() == 1 and projectiles[0]["skill_id"] == &"acolyte_punishing_light" and projectiles[0]["victim"] == enemy, "it launches one mage projectile at the target")
	var request: DamageRequest = projectiles[0]["request"]
	_check(is_equal_approx(request.magic_damage, _matk() * 2.2) and is_zero_approx(request.physical_damage) and request.can_crit, "R5: magic damage MATQ × 2.20, no physical part, can crit")
	_check(CombatActor.request_element(request) == &"light", "the hit carries the light label (no resistance axis)")
	_check(is_equal_approx(player.skill_cost(&"acolyte_punishing_light"), 14.0) and is_equal_approx(player.skill_cooldown(&"acolyte_punishing_light"), 3.0), "R5: 14 SP and a 3 s cooldown")
	_setup(_all_ranks(1, 1))
	enemy = _mob(&"forest_wolf", Vector2(550, 350))
	_cast(&"acolyte_punishing_light", enemy)
	request = projectiles[0]["request"]
	_check(is_equal_approx(request.magic_damage, _matk() * 1.4) and is_equal_approx(player.skill_cost(&"acolyte_punishing_light"), 10.0), "R1: MATQ × 1.40 and 10 SP")
	var far := _mob(&"forest_wolf", Vector2(900, 350))
	_ready_cast(&"acolyte_punishing_light")
	_check(not player.use_kit_skill(&"acolyte_punishing_light", far.global_position, far), "a target beyond 300 is refused")

# --- Prece and Fé Protetora ----------------------------------------------------------------------

func _check_prayer_and_faith() -> void:
	_setup(_all_ranks(1, 1))
	var no_faith := _all_ranks(1, 1)
	no_faith[&"acolyte_protective_faith"] = 0
	_setup(no_faith)
	player.health.current_hp = player.health.max_hp * 0.3
	var hp := player.health.current_hp
	_check(_cast(&"acolyte_prayer"), "Prece commits")
	_check(is_equal_approx(player.skill_cost(&"acolyte_prayer"), 14.0) and is_equal_approx(player.skill_cooldown(&"acolyte_prayer"), 10.0), "R1: 14 SP and a 10 s cooldown")
	_check(_near(player.health.current_hp, hp), "no immediate heal: the pulses come every second")
	_advance(1.05)
	_check(_near(player.health.current_hp - hp, player.health.max_hp * 0.04, 2.0), "R1 pulse: 4% of the max HP")
	_advance(1.0)
	_advance(1.0)
	_advance(1.0)
	_check(_near(player.health.current_hp - hp, player.health.max_hp * 0.16, 4.0) and not bool(base.call(&"prayer_active")), "R1: four pulses, 16% in total, then it ends")
	_advance(2.0)
	_check(_near(player.health.current_hp - hp, player.health.max_hp * 0.16, 6.0), "no pulse after the fourth")
	# R5 with Fé Protetora R3: +20% of every heal.
	_setup()
	player.health.current_hp = player.health.max_hp * 0.2
	hp = player.health.current_hp
	_cast(&"acolyte_prayer")
	for step: int in 4: _advance(1.0)
	_check(_near(player.health.current_hp - hp, player.health.max_hp * 0.32 * 1.2, 5.0), "R5 with Fé Protetora R3: 32%% of the max HP plus 20%% of each heal (%.1f)" % (player.health.current_hp - hp))
	# Fé Protetora on a plain heal, and no recursion with the bonus source.
	_setup(_all_ranks(5, 1))
	player.health.current_hp = player.health.max_hp * 0.4
	hp = player.health.current_hp
	player.heal_player(20.0, &"test_heal")
	_check(_near(player.health.current_hp - hp, 22.0, 0.5), "Fé Protetora R1: a 20-point heal gives 22 (+10% as its own heal)")
	_setup()
	player.health.current_hp = player.health.max_hp * 0.4
	hp = player.health.current_hp
	player.heal_player(20.0, &"test_heal")
	_check(_near(player.health.current_hp - hp, 24.0, 0.5), "Fé Protetora R3: 20 becomes 24")
	player.health.current_hp = player.health.max_hp * 0.4
	hp = player.health.current_hp
	player.heal_player(50.0, &"acolyte_faith")
	_check(_near(player.health.current_hp - hp, 50.0, 0.5), "the bonus source itself is never multiplied again")
	player.health.current_hp = player.health.max_hp * 0.4
	hp = player.health.current_hp
	player.heal_player(50.0, SanctuaryRules.HEAL_BONUS_SOURCE)
	_check(_near(player.health.current_hp - hp, 50.0, 0.5), "the Santuário's bonus source is not multiplied either")
	# Two modules: inside the Santuário the heal bonuses of both modules end (no endless recursion).
	_setup(_priest_ranks(), &"priest")
	_cast(&"priest_sanctuary")
	_advance(0.05)
	player.health.current_hp = player.health.max_hp * 0.3
	hp = player.health.current_hp
	var applied := player.heal_player(20.0, &"test_heal")
	var gained := player.health.current_hp - hp
	_check(is_finite(applied) and gained >= 20.0 * 1.2 and gained <= 20.0 * 1.2 * 1.5, "Fé Protetora R3 plus the Santuário's heal bonus end with a bounded total (%.1f)" % gained)

# --- Escudo Votivo -----------------------------------------------------------------------

func _check_votive_shield() -> void:
	_setup(_all_ranks(5, 1))
	_check(_cast(&"acolyte_votive_shield"), "Escudo Votivo commits")
	var expected := StatCalculator.personal_shield_capacity(78.0, player.stat_breakdown) * 1.10
	_check(_near(player.health.shield_hp, expected, 0.01) and is_equal_approx(float(base.get("votive_remaining")), 5.0), "R5 with Fé Protetora R1: capacity 78 + VIT/INT, +10%%, for 5 s (%.2f)" % player.health.shield_hp)
	var no_faith := _all_ranks(5, 1)
	no_faith[&"acolyte_protective_faith"] = 0
	_setup(no_faith)
	_cast(&"acolyte_votive_shield")
	_check(is_equal_approx(player.health.shield_hp, StatCalculator.personal_shield_capacity(78.0, player.stat_breakdown)), "without the passive the barrier is the plain capacity")
	_advance(4.0)
	_check(player.health.shield_hp > 0.0, "the barrier lasts the whole window")
	_advance(1.2)
	_check(is_zero_approx(player.health.shield_hp) and is_zero_approx(float(base.get("votive_remaining"))), "the leftover barrier ends with the window")
	_cast(&"acolyte_votive_shield")
	player.health.grant_shield(player.health.shield_hp + 500.0)
	_advance(5.5)
	_check(player.health.shield_hp > 400.0, "a stronger barrier from another source is not cleared by the Votive window")
	_setup(_all_ranks(1, 1))
	_cast(&"acolyte_votive_shield")
	_check(is_equal_approx(player.skill_cost(&"acolyte_votive_shield"), 14.0) and is_equal_approx(player.skill_cooldown(&"acolyte_votive_shield"), 9.0), "R1: 14 SP and a 9 s cooldown")
	var enemy := _mob(&"forest_wolf", Vector2(450, 350))
	var shield := player.health.shield_hp
	player.apply_damage(_enemy_request(enemy, 10.0), controller.rng)
	_check(player.health.shield_hp < shield, "the barrier absorbs damage")
	_check(base.snapshot_compact_blocker(player) == "acolyte_votive_shield", "an active barrier forces the exact snapshot format")

# --- Barreira recebida (T15, A15.3) -----------------------------------------------------

func _check_barrier_hook() -> void:
	_setup(_all_ranks(5, 3))
	for rank: int in [0, 1, 2, 3]:
		var ranks := _all_ranks(5, 3)
		ranks[&"acolyte_protective_faith"] = rank
		_setup(ranks)
		var factors: Array[float] = [1.0, 1.10, 1.15, 1.20]
		var expected: float = 100.0 * factors[rank]
		_check(is_equal_approx(base.barrier_received(player, 100.0, {"source": &"t15", "raw_capacity": 100.0}), expected), "Fé Protetora R%d: barrier_received gives %.0f of 100" % [rank, expected])
		var granted := player.grant_barrier(100.0, &"t15_other_source")
		_check(is_equal_approx(granted, expected) and is_equal_approx(player.health.shield_hp, expected), "Fé Protetora R%d: a barrier of any source is reinforced once (%.2f)" % [rank, player.health.shield_hp])
	# The Votive asks for the plain capacity: one reinforcement, never two.
	_setup(_all_ranks(5, 3))
	_check(_cast(&"acolyte_votive_shield"), "Escudo Votivo commits with Fé R3")
	var plain := StatCalculator.personal_shield_capacity(78.0, player.stat_breakdown)
	_check(_near(player.health.shield_hp, plain * 1.20, 0.01) and _near(float(base.get("votive_capacity")), player.health.shield_hp, 0.001), "Votive R5 with Fé R3: plain capacity × 1.20 once, and the module keeps the granted value (%.2f of %.2f)" % [player.health.shield_hp, plain])
	_advance(5.2)
	_check(is_zero_approx(player.health.shield_hp), "the reinforced Votive still ends with its window (the module recognises its own barrier)")
	# Invalid grants and other actors.
	_setup(_all_ranks(5, 3))
	for bad: float in [0.0, -10.0, NAN, INF]:
		_check(is_zero_approx(player.grant_barrier(bad, &"t15")) and is_zero_approx(player.health.shield_hp), "an invalid capacity (%s) grants nothing" % str(bad))
	var wolf := _mob(&"forest_wolf", Vector2(600, 350))
	_check(is_equal_approx(wolf.grant_barrier(50.0, &"t15"), 50.0) and is_equal_approx(wolf.health.shield_hp, 50.0), "an actor without seam modules gets the barrier as it is")
	# Order origin -> evolution, context, and the answers that keep or refuse.
	var probe := BarrierProbeKit.new()
	probe.add = 7.0
	player.attach_kit(probe)
	var modules := player.kit_modules()
	_check(modules.size() == 2 and modules[0] == base and modules[1] == probe, "probe attached as the evolution module")
	var composed := player.grant_barrier(100.0, &"priest_aegis")
	_check(probe.seen.size() == 1 and is_equal_approx(float(probe.seen[0]["capacity"]), 120.0) and is_equal_approx(composed, 127.0) and is_equal_approx(player.health.shield_hp, 127.0), "chained origin then evolution: Fé 100 → 120, then the evolution +7 → 127 (%.2f)" % composed)
	_check(probe.seen.size() == 1 and probe.seen[0]["context"].get("source") == &"priest_aegis" and is_equal_approx(float(probe.seen[0]["context"].get("raw_capacity", 0.0)), 100.0), "context carries the source and the raw capacity")
	player.health.clear_shield()
	for kept: float in [NAN, INF, -3.0]:
		probe.answer = kept
		_check(is_equal_approx(player.grant_barrier(100.0, &"t15"), 120.0), "a non-finite or negative answer (%s) keeps the previous value" % str(kept))
		player.health.clear_shield()
	probe.answer = 0.0
	_check(is_zero_approx(player.grant_barrier(100.0, &"t15")) and is_zero_approx(player.health.shield_hp), "an answer of 0 refuses the grant")
	probe.answer = null
	player.health.grant_shield(500.0)
	_check(is_equal_approx(player.grant_barrier(100.0, &"t15"), 127.0) and is_equal_approx(player.health.shield_hp, 500.0), "a smaller grant keeps the larger barrier and reports its own capacity")
	var calls := probe.seen.size()
	player.health.current_hp = 0.0
	_check(not player.is_alive() and is_zero_approx(player.grant_barrier(100.0, &"t15")) and probe.seen.size() == calls, "a dead player gains no barrier and the hook is not called")
	player.attach_kit(null)

# --- Selo Sombrio -------------------------------------------------------------------------

func _check_shadow_seal() -> void:
	_setup()
	var enemy := _mob(&"forest_wolf", Vector2(550, 350))
	var hits := _hits_on(enemy)
	var before_madness := MadnessAuthority.madness_of(enemy)
	_check(_cast(&"acolyte_shadow_seal", enemy), "Selo Sombrio commits")
	_check(enemy.marks.has_mark(&"acolyte_shadow_seal") and enemy.marks.owner_of(&"acolyte_shadow_seal") == player.get_instance_id() and is_equal_approx(enemy.marks.remaining(&"acolyte_shadow_seal"), 6.0), "the enemy carries the mark of the owner for 6 s")
	_check(enemy.accuracy_sources.has(&"acolyte_shadow_seal") and is_equal_approx(float(enemy.accuracy_sources[&"acolyte_shadow_seal"]["reduction"]), 0.36), "R5: the enemy loses 36% of its accuracy (C1.7)")
	_check(is_equal_approx(enemy.outgoing_hit_rating(100.0), 64.0), "the reduction reaches the enemy's hit rating")
	_check(is_equal_approx(MadnessAuthority.madness_of(enemy) - before_madness, 26.0), "R5: 26 Madness at the commit (T4 authority)")
	_check(is_equal_approx(player.skill_cost(&"acolyte_shadow_seal"), 20.0) and is_equal_approx(player.skill_cooldown(&"acolyte_shadow_seal"), 8.0), "R5: 20 SP and an 8 s cooldown")
	_check(hits.is_empty(), "no damage at the commit: the DoT starts one second later")
	var life := enemy.health.current_hp
	for step: int in 6: _advance(1.0)
	var ticks: Array[Dictionary] = []
	for hit: Dictionary in hits:
		if StringName(hit.get("skill_id", &"")) == &"acolyte_shadow_seal": ticks.append(hit)
	_check(ticks.size() == 6, "six DoT pulses over the 6 s (got %d)" % ticks.size())
	var secondary := true
	for tick: Dictionary in ticks: secondary = secondary and bool(tick.get("secondary", false))
	_check(secondary and enemy.health.current_hp < life, "the pulses are secondary hits and wound the enemy")
	_check(not enemy.marks.has_mark(&"acolyte_shadow_seal") and not bool(base.call(&"seal_active")) and not enemy.accuracy_sources.has(&"acolyte_shadow_seal"), "the mark and the debuff end with the window")
	var request: Variant = base.get("seal_prototype")
	_check(request == null, "the pulse prototype is released")
	# One seal at a time; the old mark goes away.
	_setup()
	var first := _mob(&"forest_wolf", Vector2(550, 350))
	var second := _mob(&"forest_boar", Vector2(520, 380))
	_cast(&"acolyte_shadow_seal", first)
	_cast(&"acolyte_shadow_seal", second)
	_check(not first.marks.has_mark(&"acolyte_shadow_seal") and not first.accuracy_sources.has(&"acolyte_shadow_seal") and second.marks.has_mark(&"acolyte_shadow_seal") and int(base.get("marked_target_id")) == second.get_instance_id(), "marking another enemy replaces the seal")
	_check(base.snapshot_compact_blocker(player) == "acolyte_shadow_seal", "an active seal forces the exact snapshot format")
	second.health.current_hp = 0.0
	second._on_health_died(second.get_instance_id())
	controller.enemies.erase(second)
	_advance(1.1)
	_check(not bool(base.call(&"seal_active")) and int(base.get("marked_target_id")) == 0, "the seal ends when its target dies")
	# Boss: the accuracy debuff applies; Madness builds towards the Desorientação.
	_setup()
	var boss := _boss(Vector2(560, 350))
	_cast(&"acolyte_shadow_seal", boss)
	_check(boss.accuracy_sources.has(&"acolyte_shadow_seal") and MadnessAuthority.madness_of(boss) > 0.0, "the boss is marked, loses accuracy and gains Madness")
	# R1 numbers.
	_setup(_all_ranks(1, 1))
	enemy = _mob(&"forest_wolf", Vector2(550, 350))
	_cast(&"acolyte_shadow_seal", enemy)
	_check(is_equal_approx(float(enemy.accuracy_sources[&"acolyte_shadow_seal"]["reduction"]), 0.20) and is_equal_approx(MadnessAuthority.madness_of(enemy), 18.0) and is_equal_approx(player.skill_cost(&"acolyte_shadow_seal"), 16.0), "R1: −20% accuracy, 18 Madness, 16 SP")

# --- Sussurro Perturbador -------------------------------------------------------------------------

func _check_whisper() -> void:
	_setup()
	var front := _mob(&"forest_wolf", Vector2(530, 350))
	var side := _mob(&"forest_boar", Vector2(500, 420))
	var behind := _mob(&"forest_wolf", Vector2(300, 350))
	var far := _mob(&"forest_wolf", Vector2(560, 300))
	far.global_position = Vector2(700, 350)
	var boss := _boss(Vector2(520, 330))
	var front_start := front.global_position
	var boss_start := boss.global_position
	_check(_cast(&"acolyte_disturbing_whisper", front), "Sussurro commits on a target in range")
	_check(is_equal_approx(MadnessAuthority.madness_of(front), 40.0) and is_equal_approx(MadnessAuthority.madness_of(boss), 40.0), "R5: 40 Madness to each enemy in the cone, the boss included")
	_check(is_zero_approx(MadnessAuthority.madness_of(behind)) and is_zero_approx(MadnessAuthority.madness_of(far)), "an enemy behind or beyond 190 is outside the cone")
	_check(MadnessAuthority.madness_of(side) < 40.0 + 0.01, "the cone is a 50-degree half angle (the side enemy is judged by angle)")
	_check(front.global_position.x > front_start.x + 80.0, "a common enemy is pushed away by 85 (got %.1f)" % (front.global_position.x - front_start.x))
	_check(boss.global_position.is_equal_approx(boss_start), "the boss is not pushed (it stays where it is)")
	_check(front.health.current_hp == front.health.max_hp and boss.health.current_hp == boss.health.max_hp, "the Sussurro deals no damage")
	_check(is_equal_approx(player.skill_cost(&"acolyte_disturbing_whisper"), 20.0) and is_equal_approx(player.skill_cooldown(&"acolyte_disturbing_whisper"), 10.0), "R5: 20 SP and a 10 s cooldown")
	# The same cast never pays Madness twice (event identity of the cast).
	var again := madness.add(front, 10.0, MadnessHelpers.cast_event({"skill_id": &"acolyte_disturbing_whisper"}, player.kit_time), player)
	_check(not again["ok"] and again["error_code"] == &"duplicate_event", "the cast event is deduplicated per enemy")
	# R1 numbers.
	_setup(_all_ranks(1, 1))
	front = _mob(&"forest_wolf", Vector2(500, 350))
	front_start = front.global_position
	_cast(&"acolyte_disturbing_whisper", front)
	_check(is_equal_approx(MadnessAuthority.madness_of(front), 24.0) and is_equal_approx(front.global_position.x - front_start.x, 45.0) and is_equal_approx(player.skill_cost(&"acolyte_disturbing_whisper"), 16.0), "R1: 24 Madness, push 45, 16 SP")
	var out_of_range := _mob(&"forest_wolf", Vector2(600, 350))
	_ready_cast(&"acolyte_disturbing_whisper")
	_check(not player.use_kit_skill(&"acolyte_disturbing_whisper", out_of_range.global_position, out_of_range), "R1 reaches only 150: a target at 200 is refused")

# --- Madness authority wiring, Visão Eldritch doubling and Delirium on the base -------------------

func _check_madness_wiring() -> void:
	_setup()
	_check(madness != null and MadnessAuthority.of(player) == madness and madness.stat_source_id == &"acolyte_ecstasy" and madness.owner_id == player.get_instance_id(), "the base keeps the authority in the field `madness` and configured it on attach")
	_check(not madness.ecstasy.enabled and base.temporary_stat_sources(player).is_empty(), "the Êxtase is off on the base: no stat source")
	_check(is_equal_approx(base.skill_cost(player, &"acolyte_prayer", 20.0), 20.0), "the base does not forward the Êxtase cost")
	_check(base.before_hit_mitigation(player, {"request": _enemy_request(player, 5.0)}).is_empty(), "the base does not forward the Êxtase damage taken")
	# Doubled Madness: the next Selo or Sussurro only, once.
	var wolf := _mob(&"forest_wolf", Vector2(530, 350))
	var other := _mob(&"forest_boar", Vector2(400, 440)) # outside the cone: only the Selo reaches it
	_cast(&"acolyte_eldritch_vision")
	_cast(&"acolyte_disturbing_whisper", wolf)
	_check(is_equal_approx(MadnessAuthority.madness_of(wolf), 80.0) and not bool(base.get("vision_charged")), "Visão Eldritch: the next Sussurro gives double (80) and spends the charge")
	_cast(&"acolyte_shadow_seal", other)
	_check(is_equal_approx(MadnessAuthority.madness_of(other), 26.0), "the following Selo gives the plain 26")
	# The Delirium happens on the base, only slowly: it needs the doubled Whisper plus the Seal at R5.
	_check(MadnessAuthority.state_of(wolf) == MadnessRules.STATE_NONE, "80 Madness is not yet Delirium")
	_cast(&"acolyte_shadow_seal", wolf)
	_check(MadnessAuthority.state_of(wolf) == MadnessRules.STATE_DELIRIUM and wolf.target_override_reason() == MadnessRules.DELIRIUM_REASON and wolf.combat_target() == other, "Visão + Sussurro + Selo at R5 reach 100: Delirium, aiming at the nearest other enemy")
	# Slowly: at R1, even doubled, the threshold is out of reach in the hold window.
	_setup(_all_ranks(1, 1))
	wolf = _mob(&"forest_wolf", Vector2(500, 350))
	_cast(&"acolyte_eldritch_vision")
	_cast(&"acolyte_disturbing_whisper", wolf)
	_cast(&"acolyte_shadow_seal", wolf)
	_check(is_equal_approx(MadnessAuthority.madness_of(wolf), 48.0 + 18.0) and MadnessAuthority.state_of(wolf) == MadnessRules.STATE_NONE, "R1: 48 + 18 = 66, no Delirium (the base is slow)")
	_advance(4.2)
	_advance(2.0)
	_check(MadnessAuthority.madness_of(wolf) < 66.0 - 30.0, "the Madness waits 4 s and then decays 20 per second (T4)")
	# Boss: the Desorientação, without a push.
	_setup()
	var boss := _boss(Vector2(520, 350))
	var boss_start := boss.global_position
	_cast(&"acolyte_eldritch_vision")
	_cast(&"acolyte_disturbing_whisper", boss)
	_cast(&"acolyte_shadow_seal", boss)
	_check(MadnessAuthority.state_of(boss) == MadnessRules.STATE_DISORIENTED and boss.global_position.is_equal_approx(boss_start) and not boss.has_target_override() and boss.combat_target() == player, "the boss reaches the Desorientação and is neither pushed nor redirected")
	_check(MadnessAuthority.state_of(boss) != MadnessRules.STATE_DELIRIUM, "the boss never enters Delirium")
	# Pause freezes the Madness clocks of the authority.
	_setup()
	wolf = _mob(&"forest_wolf", Vector2(500, 350))
	_cast(&"acolyte_disturbing_whisper", wolf)
	var value := MadnessAuthority.madness_of(wolf)
	paused = true
	_advance(10.0)
	paused = false
	_check(is_equal_approx(MadnessAuthority.madness_of(wolf), value), "pause freezes the Madness")

# --- Devoção ----------------------------------------------------------------------------------------

func _check_devotion() -> void:
	_setup()
	var enemy := _mob(&"forest_wolf", Vector2(530, 350))
	var plain := _matk()
	_cast(&"acolyte_punishing_light", enemy) # light
	_check(is_equal_approx(_matk(), plain) and not bool(base.call(&"devotion_ready")), "light alone: nothing changes")
	_cast(&"acolyte_shadow_seal", enemy) # shadow after light: the pair
	_check(bool(base.get("devotion_fresh")) and is_equal_approx(_matk(), plain), "the pairing commit itself is not boosted")
	_advance(0.05)
	_check(bool(base.call(&"devotion_ready")) and is_equal_approx(_matk(), plain * 1.20) and not base.temporary_stat_sources(player).is_empty(), "R3: the next skill sees MATQ +20%% (%.1f of %.1f)" % [_matk(), plain])
	projectiles.clear()
	_cast(&"acolyte_punishing_light", enemy) # the boosted skill (light after shadow: pairs again)
	var request: DamageRequest = projectiles[0]["request"]
	_check(is_equal_approx(request.magic_damage, _matk() * 2.2) and _matk() > plain * 1.19, "the boosted skill resolves with the raised MATQ")
	_advance(0.05)
	_check(bool(base.call(&"devotion_ready")), "alternating again (shadow then light) keeps the reinforcement for the next skill")
	_cast(&"acolyte_prayer", enemy) # light after light: no pair; consumes the reinforcement
	_advance(0.05)
	_check(not bool(base.call(&"devotion_ready")) and is_equal_approx(_matk(), plain), "the reinforcement lasts one skill")
	# No pair across the window, none with a neutral element, none with the same element.
	_setup()
	enemy = _mob(&"forest_wolf", Vector2(530, 350))
	_cast(&"acolyte_punishing_light", enemy)
	_advance(9.0)
	_cast(&"acolyte_shadow_seal", enemy)
	_advance(0.1)
	_check(not bool(base.call(&"devotion_ready")), "light then shadow after more than 8 s is not a pair")
	_setup()
	enemy = _mob(&"forest_wolf", Vector2(530, 350))
	_cast(&"acolyte_punishing_light", enemy)
	_cast(&"acolyte_eldritch_vision")
	_cast(&"acolyte_shadow_seal", enemy)
	_advance(0.1)
	_check(bool(base.call(&"devotion_ready")), "a neutral skill in between neither breaks nor makes the pair (light, Visão, shadow)")
	_setup()
	enemy = _mob(&"forest_wolf", Vector2(530, 350))
	_cast(&"acolyte_shadow_seal", enemy)
	_cast(&"acolyte_disturbing_whisper", enemy)
	_advance(0.1)
	_check(not bool(base.call(&"devotion_ready")), "shadow then shadow is not a pair")
	# Expiry of the waiting reinforcement.
	_setup()
	enemy = _mob(&"forest_wolf", Vector2(530, 350))
	var raw := _matk()
	_cast(&"acolyte_shadow_seal", enemy)
	_cast(&"acolyte_punishing_light", enemy)
	_advance(0.05)
	_check(bool(base.call(&"devotion_ready")), "shadow then light also pairs")
	_advance(8.1)
	_check(not bool(base.call(&"devotion_ready")) and is_equal_approx(_matk(), raw), "an unused reinforcement ends after 8 s")
	# Without the passive nothing happens.
	var no_devotion := _all_ranks()
	no_devotion[&"acolyte_devotion"] = 0
	_setup(no_devotion)
	enemy = _mob(&"forest_wolf", Vector2(530, 350))
	_cast(&"acolyte_punishing_light", enemy)
	_cast(&"acolyte_shadow_seal", enemy)
	_advance(0.1)
	_check(not bool(base.call(&"devotion_ready")), "without Devoção learned there is no reinforcement")
	# The evolution's commits join by element: the Sacerdote's skills are all light (T1 on_base_skill_committed).
	_setup(_priest_ranks(), &"priest")
	enemy = _mob(&"forest_wolf", Vector2(530, 350))
	var priest_raw := _matk()
	_cast(&"acolyte_shadow_seal", enemy)
	_check(player.kit != null and player.kit != base and player.origin_kit == base, "two modules: the base is the origin, the Sacerdote the evolution")
	_cast(&"priest_sanctuary")
	_advance(0.05)
	_check(bool(base.call(&"devotion_ready")) and _matk() > priest_raw * 1.19, "shadow (base) then the Sacerdote's light skill pairs by element, no fixed list")

func _priest_ranks() -> Dictionary:
	var ranks := _all_ranks()
	for skill: StringName in ClassKitRegistry.skill_ids(&"priest"): ranks[skill] = 3 if skill in [&"priest_grace", &"priest_exorcist"] else 5
	return ranks

# --- Build change, death and pause -------------------------------------------------------------

func _check_build_change_death_and_pause() -> void:
	_setup()
	var enemy := _mob(&"forest_wolf", Vector2(530, 350))
	_cast(&"acolyte_prayer")
	_cast(&"acolyte_shadow_seal", enemy)
	_cast(&"acolyte_eldritch_vision")
	player.apply_run_modifiers(player.run_state)
	player.health.current_hp = player.health.max_hp * 0.4
	player.current_sp = player.max_sp * 0.3
	var hp := player.health.current_hp
	var sp := player.current_sp
	var remaining := float(base.get("seal_remaining"))
	player.mage_cooldowns[&"acolyte_prayer"] = 3.0
	player.apply_run_modifiers(player.run_state)
	_check(_near(player.health.current_hp, hp) and is_equal_approx(player.current_sp, sp) and is_equal_approx(player.skill_cooldown(&"acolyte_prayer"), 3.0) and is_equal_approx(float(base.get("seal_remaining")), remaining) and bool(base.get("vision_charged")), "build change: no heal, no SP refill, no cooldown reset, Seal and Vision kept")
	paused = true
	_advance(1.0)
	paused = false
	_check(is_equal_approx(float(base.get("seal_remaining")), remaining) and int(base.get("prayer_pulses")) == 4 and is_equal_approx(float(base.get("vision_remaining")), 10.0), "pause freezes the Seal, the Prece and the Visão")
	_cast(&"acolyte_votive_shield")
	player.health.current_hp = 1.0
	player.apply_damage(_enemy_request(enemy, 100000.0), controller.rng)
	_check(not player.is_alive() and int(base.get("prayer_pulses")) == 0 and not bool(base.call(&"seal_active")) and not enemy.marks.has_mark(&"acolyte_shadow_seal") and not enemy.accuracy_sources.has(&"acolyte_shadow_seal") and not bool(base.get("vision_charged")) and is_zero_approx(float(base.get("votive_remaining"))) and not bool(base.call(&"devotion_ready")), "death ends the Prece, Seal (mark and debuff), Visão, Votive window and Devoção")
	# Build change with a waiting Devoção follows the new rank.
	_setup()
	enemy = _mob(&"forest_wolf", Vector2(530, 350))
	var raw := _matk()
	_cast(&"acolyte_punishing_light", enemy)
	_cast(&"acolyte_shadow_seal", enemy)
	_advance(0.05)
	_check(is_equal_approx(_matk(), raw * 1.20), "R3 reinforcement waiting")
	player.run_state.skill_levels[&"acolyte_devotion"] = 1
	player.apply_run_modifiers(player.run_state)
	_check(is_equal_approx(float(base.get("devotion_bonus")), 0.10) and is_equal_approx(_matk(), raw * 1.10), "the waiting reinforcement follows a lower rank without resetting")

# --- Evolution destinations (A10 item 4, A11) ----------------------------------------------------------

func _check_evolution_destinations() -> void:
	ClassKitRegistry.clear_fixtures()
	var catalog := ProfileCatalog.pilot()
	var listed: Array = catalog.evolution_definitions_for_origin(&"acolyte").map(func(d: EvolutionDefinition) -> StringName: return d.id)
	var expected: Array[StringName] = []
	for id: StringName in ClassKitRegistry.pure_ids():
		if ClassKitRegistry.ready_for_play(id): expected.append(id)
	_check(not expected.is_empty() and expected[0] == &"priest", "the Sacerdote (T6) is a ready pure kit")
	_check(listed == expected, "with the base ready, the ready pure kits (and only they) are the Acólito's destinations, in registry order: %s" % [listed])
	for id: StringName in listed:
		var definition := catalog.evolution_definition(id)
		_check(definition != null and definition.content_ready, "%s is offered as ready" % id)
		_check(ClassKitRegistry.origin(id) == &"acolyte" and IdentityIds.evolution_origin(id) == &"acolyte" and catalog.evolution_definition(id).branch_kind == ClassKitRegistry.branch(id), "%s: origin acolyte and branch %s from the registry" % [id, ClassKitRegistry.branch(id)])
	var priest := catalog.evolution_definition(&"priest")
	_check(priest != null and priest.branch_kind == &"2-1" and priest.entry_skill_id == &"priest_sanctuary", "the Sacerdote: branch 2-1, entry Santuário")
	# An empty ClassBase (the shape of the old skeleton) is never ready.
	var skeleton := ClassBase.new()
	_check(skeleton.ready_for_play() == false and skeleton.base_id() == &"", "an empty ClassBase is never ready")
	_check(not IdentityIds.initial_attributes(&"acolyte").is_empty(), "attributes are available only because the real module is ready and valid")

# --- Snapshot formats ----------------------------------------------------------------------------------

func _check_snapshot_formats() -> void:
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty() and registry.schemas.has(BASE_PATH), "the acolyte fragment merges: " + str(registry.fragment_errors))
	var fields: Array = registry.schemas[BASE_PATH].get("fields", []) if registry.schemas.has(BASE_PATH) and registry.schemas[BASE_PATH] is Dictionary else []
	for field: String in ["madness", "prayer_pulses", "votive_remaining", "marked_target_id", "seal_prototype", "vision_charged", "devotion_ready_remaining", "devotion_rearm"]:
		_check(field in fields, "the fragment lists %s" % field)
	var module_variables: Array[String] = []
	for property: Dictionary in (ClassBaseRegistry.module(&"acolyte").get_script() as Script).get_script_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0: module_variables.append(String(property["name"]))
	var unlisted: Array[String] = []
	for variable: String in module_variables:
		if variable not in fields and variable != "evolution_id": unlisted.append(variable)
	_check(unlisted.is_empty(), "every script variable of the module (the inherited evolution_id apart) is in the fragment: %s" % [unlisted])
	_setup()
	var standalone := _make_player(navigation, _all_ranks())
	standalone.global_position = Vector2(400, 350)
	owned.append(standalone)
	var standalone_base := standalone.origin_kit
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = Vector2(480, 350)
	enemy.health.max_hp = 1000.0
	enemy.health.current_hp = 1000.0
	standalone.add_child(enemy)
	standalone.max_sp = 1000.0
	standalone.current_sp = 1000.0
	var cast := {"skill_id": &"acolyte_shadow_seal", "rank": 5, "element": &"shadow", "world": false, "anchor": null, "point": Vector2(480, 350), "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": enemy, "actors": [enemy]}
	standalone_base.resolve_cast(standalone, cast)
	standalone_base.set("prayer_pulses", 3)
	standalone_base.set("prayer_tick", 0.4)
	standalone_base.set("prayer_fraction", 0.08)
	standalone_base.set("vision_remaining", 5.0)
	standalone_base.set("vision_range_bonus", 120.0)
	standalone_base.set("vision_charged", true)
	standalone_base.set("devotion_element", &"shadow")
	standalone_base.set("devotion_pair_remaining", 4.0)
	standalone.kit_time = 9.0
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(standalone)["ok"], "barrier acquired")
	var captured := SnapshotRegistry.new().capture(standalone, barrier)
	_check(captured.get("ok", false), "exact capture with a seal, a Prece and a Visão: " + str(captured.get("detail", captured.get("error_code", ""))))
	if captured.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(captured["snapshot"])))
		_check(restored.get("ok", false), "exact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied := copy.origin_kit
			var copied_enemy: CombatActor = null
			for child: Node in copy.get_children():
				if child is CombatActor: copied_enemy = child
			_check(copied != null and copied.get_script().resource_path == BASE_PATH and int(copied.get("prayer_pulses")) == 3 and is_equal_approx(float(copied.get("prayer_tick")), 0.4) and is_equal_approx(float(copied.get("prayer_fraction")), 0.08), "exact format keeps the Prece pulses")
			_check(copied != null and bool(copied.get("vision_charged")) and is_equal_approx(float(copied.get("vision_remaining")), 5.0) and is_equal_approx(float(copied.get("vision_range_bonus")), 120.0) and copied.get("devotion_element") == &"shadow", "exact format keeps the Visão and the Devoção pairing")
			_check(copied != null and copied_enemy != null and int(copied.get("marked_target_id")) == copied_enemy.get_instance_id() and is_equal_approx(float(copied.get("seal_remaining")), 6.0) and copied.get("seal_prototype") != null and copied_enemy.marks.has_mark(&"acolyte_shadow_seal"), "exact format keeps the seal with the restored enemy")
			_check(copied != null and MadnessAuthority.of(copy) == copied.get("madness") and (copied.get("madness") as MadnessAuthority).owner_id == copy.get_instance_id(), "the Madness authority is restored and found by of()")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	var projection := {"fields": {}, "excluded": {}}
	var compact := SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and compact.get("detail") == "acolyte_shadow_seal", "the seal makes the compact cut ineligible")
	standalone_base.call(&"_end_seal")
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("ok", false), "without a seal or a barrier the compact cut is accepted: " + str(compact.get("detail", compact.get("error_code", ""))))
	if compact.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(compact["snapshot"])))
		_check(restored.get("ok", false), "compact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied := copy.origin_kit
			_check(copied != null and int(copied.get("prayer_pulses")) == 3 and bool(copied.get("vision_charged")) and copied.get("devotion_element") == &"shadow", "the compact format keeps the player state of the base")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	barrier.release()

# --- World path ---------------------------------------------------------------------------------------

func _check_world_path() -> void:
	_setup()
	var input := WorldFixture.make()
	var built := ExpeditionAssembler.build(input)
	var world := WorldGeometry.new()
	_check(built["ok"] and world.configure(built["data"]["manifest"], "sample")["ok"], "F1 fixture geometry configured")
	if not built["ok"]: return
	var profile := input.traversal.to_data()
	_check(player.bind_world_geometry(world, WorldFixture.point("root", Vector3(20, 0, 20)), profile, str(player.get_instance_id()))["ok"], "player bound to the world")
	player.set_process(false)
	var common := _mob(&"forest_wolf", Vector2.ZERO)
	var behind := _mob(&"forest_boar", Vector2.ZERO)
	var boss := _boss(Vector2.ZERO)
	for row: Array in [[common, Vector3(20, 0, 150)], [behind, Vector3(80, 0, 60)], [boss, Vector3(40, 0, 140)]]:
		var hostile: EnemyActor = row[0]
		_check(hostile.bind_world_geometry(world, WorldFixture.point("root", row[1]), profile, str(hostile.get_instance_id()))["ok"], "world mob bound")
		hostile.set_process(false)
	var common_start := common.world_point().position
	var boss_start := boss.world_point().position
	var cast := {"skill_id": &"acolyte_disturbing_whisper", "rank": 5, "element": &"shadow", "world": true, "anchor": player.world_point(), "point": Vector2(20, 20), "facing": Vector3(0, 0, 1), "facing_2d": Vector2(0, 1), "target": common, "actors": [common, behind, boss]}
	_check(base.resolve_cast(player, cast), "the Sussurro resolves in the world")
	_check(is_equal_approx(MadnessAuthority.madness_of(common), 40.0) and is_equal_approx(MadnessAuthority.madness_of(boss), 40.0) and is_zero_approx(MadnessAuthority.madness_of(behind)), "world cone: the two ahead gain Madness; the one behind does not")
	_check(common.world_point().position.distance_to(common_start) > 40.0, "the common enemy is pushed in the world (%.1f)" % common.world_point().position.distance_to(common_start))
	_check(boss.world_point().position.distance_to(boss_start) < 0.5, "the world boss is not pushed")
	cast["skill_id"] = &"acolyte_shadow_seal"
	cast["actors"] = [common]
	cast["element"] = &"shadow"
	_check(base.resolve_cast(player, cast) and common.marks.has_mark(&"acolyte_shadow_seal"), "the Selo marks in the world")
	_check(base.snapshot_compact_blocker(player) == "acolyte_shadow_seal", "the world seal blocks the compact cut")
