extends SceneTree
## E09 K4 — Lâmina Arcana (`mg_la`) kit invariants (docs/epics/e09/k4_contract.md):
## catalog data and readiness, the two review builds, the Marca Refratada (victim,
## bonus, no reveal), the crystal blade basic attack (melee, fire → ice → lightning,
## triad +2 and reaction, retry guard, Lança de Gelo as ice), Refração (own
## concealment with the kit charge), Salto Prismático (concealed only, victim only,
## back point validated before payment, back + opening, flat route after the
## teleport), Fratura de Luz (single kill callback), Sentença Prismática (thresholds,
## boss, no duplication in retry), Espectro de Prisma (three different victims, back
## points, chain of executions, compact blocker), the base Teleporte exit through the
## T1.2 hook, build change without heal/reset, death, pause and both snapshot formats.
## World geometry of the Salto: mg_la_world_leap_test.gd. Boss: mg_la_boss_combat_test.gd.
## Fixture profiles only (no save on disk).
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const KIT_PATH := "res://scripts/classes/mg_la/mg_la_kit.gd"
const BUILDS_PATH := "res://scripts/classes/mg_la/review_builds.json"
const MARK := &"arcane_blade_refracted_mark"
const EDGE := &"arcane_blade_enchanted_edge"
const REFRACTION := &"arcane_blade_refraction"
const LEAP := &"arcane_blade_prismatic_leap"
const FRACTURE := &"arcane_blade_light_fracture"
const SENTENCE := &"arcane_blade_prismatic_sentence"
const SPECTER := &"arcane_blade_prism_specter"
const SKILLS: Array[StringName] = [MARK, EDGE, REFRACTION, LEAP, FRACTURE, SENTENCE, SPECTER]
const PASSIVES: Array[StringName] = [EDGE, FRACTURE]
const FIELDS := ["flank", "blade_index", "triad_serial", "triad_landed", "triad_keys", "reaction_pending", "reaction_serial", "refraction_charges", "refraction_recharge", "specter_serial", "specter_pending", "last_ground", "has_last_ground", "fracture_total"]

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var kit: ClassKit
var flank: FlankAuthority

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
	_check_review_builds()
	_check_mark()
	_check_crystal_blade()
	_check_triad()
	_check_refraction()
	_check_leap()
	_check_leap_flat_route()
	_check_sentence_and_fracture()
	_check_specter()
	_check_base_teleport_exit()
	_check_build_change_death_and_pause()
	_check_snapshot_formats()
	_check_source_guards()
	_cleanup()
	print("E09 K4 mg_la kit: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixture --------------------------------------------------------------------

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	paused = false

func _all_ranks(evolution_rank: int = 5, passive_rank: int = 3) -> Dictionary:
	var ranks := {&"teleport": 5, &"ice_spear": 5, &"fireball": 3}
	for skill: StringName in SKILLS:
		ranks[skill] = passive_rank if skill in PASSIVES else evolution_rank
	return ranks

func _make_player(navigation: ArenaNavigation, ranks: Dictionary) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_la"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"mg_la")
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [MARK, REFRACTION, LEAP, SENTENCE, SPECTER]
	var actor := PlayerActor.new()
	actor.configure(navigation, RunState.from_build("mg-la-" + str(checks), snapshot))
	return actor

func _setup(ranks: Dictionary = {}, obstacles: Array[Rect2] = []) -> void:
	_cleanup()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 700), obstacles, 20.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	player = _make_player(navigation, ranks if not ranks.is_empty() else _all_ranks())
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(400, 350)
	player.character_animation.state.face(Vector2.RIGHT)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 47
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	kit = player.kit
	flank = kit.get("flank") if kit != null else null

func _enemy(at: Vector2, hp: float = 100000.0, facing: Vector2 = Vector2.LEFT) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	controller.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position = at
	if enemy.character_animation == null: enemy.set_animation_kind(&"warrior")
	enemy.character_animation.state.face(facing)
	enemy.health.max_hp = hp
	enemy.health.current_hp = hp
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(enemy)
	return enemy

func _hostile(at: Vector2) -> EnemyActor:
	var hostile := EnemyActor.new()
	hostile.configure(&"chaser", controller.navigation, player)
	controller.add_child(hostile)
	hostile.set_process(false)
	hostile.global_position = at
	hostile.health.max_hp = 100000.0
	hostile.health.current_hp = 100000.0
	hostile.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(hostile)
	return hostile

func _hits_on(enemy: CombatActor) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	enemy.health.damage_applied.connect(func(result: Dictionary) -> void: hits.append(result))
	return hits

func _claw(source: CombatActor, amount: float = 30.0) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.context = player.run_state.effect_ledger.new_root(source.get_instance_id(), false, "", false, {})
	return request

func _cast(skill: StringName, enemy: CombatActor = null) -> bool:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp
	return player.use_kit_skill(skill, enemy.global_position if enemy != null else player.global_position, enemy)

func _refusal(skill: StringName, enemy: CombatActor = null) -> StringName:
	var cast := player._kit_cast_legacy(skill, enemy.global_position if enemy != null else player.global_position, enemy)
	return StringName(kit.can_cast(player, cast).get("error_code", &""))

func _tick(delta: float, steps: int = 1) -> void:
	for step: int in steps: player._process(delta)

## A basic attack through the kit composition and the RunController (claims, callbacks).
func _basic(target: CombatActor) -> DamageRequest:
	var origin := player.kit_make_request(target, &"basic_attack", 0.0, 20.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var request := kit.compose_basic_attack(player, target, origin)
	controller._on_attack_requested(request, target)
	return request

var _fills := 0

## Full Sentence on `target` through combo events with fresh keys (dedup is per key).
func _fill(target: CombatActor) -> void:
	flank.mark_victim(player, target)
	for index: int in 3:
		_fills += 1
		flank.gain(player, target, FlankRules.SOURCE_COMBO, "fill_%d" % _fills)

func _sight_broken(hostile: EnemyActor) -> bool:
	var threat := hostile.get(&"threat") as ThreatService
	return threat != null and threat.sight_broken(String(hostile.call(&"threat_id_for", player)))

func _element(result_or_request: Variant) -> StringName:
	var snapshot: Dictionary = result_or_request.effect_snapshot if result_or_request is DamageRequest else result_or_request.get("effect_snapshot", {})
	return StringName(snapshot.get("arcane_blade_element", &""))

# --- Catalog ----------------------------------------------------------------------

func _check_catalog() -> void:
	var module := ClassKitRegistry.module(&"mg_la")
	_check(module != null and module.get_script().resource_path == KIT_PATH, "the production module is the mg_la kit")
	_check(ClassKitRegistry.validate(&"mg_la").get("ok", false), "registry validation passes: " + str(ClassKitRegistry.validate(&"mg_la")))
	_check(module.ready_for_play() and ClassKitRegistry.ready_for_play(&"mg_la"), "the kit is ready for play (A7)")
	_check(module.display_name() == "Lâmina Arcana", "pt-BR identity name")
	var definitions := module.skill_definitions()
	var ids: Array[StringName] = []
	for definition: SkillDefinition in definitions: ids.append(definition.id)
	_check(ids == ClassKitRegistry.skill_ids(&"mg_la") and ids == SKILLS, "seven skills in the job order of C1")
	var elements: Array[StringName] = []
	for index: int in definitions.size():
		var definition := definitions[index]
		var active: bool = ClassKitRegistry.SLOT_CATEGORIES[index] == &"active"
		elements.append(definition.element)
		_check(definition.handler_id == SkillDefinition.Handler.KIT and definition.is_rank_catalog_valid() and definition.ranks.size() == (5 if active else 3), "%s: kit handler, ranks 1-%d" % [definition.id, 5 if active else 3])
	_check(elements == [&"arcane", &"arcane", &"light", &"arcane", &"light", &"light", &"light"], "rule elements: arcane and light (A2): %s" % [elements])
	for skill: StringName in ids:
		var recipe := FeedbackRecipeCatalog.recipe(skill)
		_check(not recipe.is_empty() and recipe.get("element", &"") == &"arcane", "%s: light recipes use arcane (ELEMENTS has no light)" % skill)
	var learning := module.learning_entries()
	_check(learning.size() == 7 and int(learning[0]["free_rank"]) == 1 and int(learning[0]["job_level"]) == 20 and int(learning[6]["job_level"]) == 37, "learning rows: free entry at job 20 through job 37")
	_check(learning[0]["skill_id"] == MARK and not learning[0].has("prerequisites"), "the entry skill has no prerequisites (A13)")
	var jobs: Array[int] = []
	for row: Dictionary in learning: jobs.append(int(row["job_level"]))
	_check(jobs == [20, 23, 25, 28, 31, 34, 37], "job levels of section 1")
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid(), "ProfileCatalog stays valid with the Lâmina Arcana ready")
	var offered: Array[StringName] = []
	for evolution: EvolutionDefinition in catalog.evolution_definitions_for_origin(&"mage"): offered.append(evolution.id)
	_check(&"mg_la" in offered and catalog.evolution_definition(&"mg_la").affinity_class_id == &"rogue" and catalog.evolution_definition(&"mg_la").display_name == "Lâmina Arcana", "ProfileCatalog offers the Lâmina Arcana to the Mago with rogue affinity")
	var texts := module.skill_texts()
	for skill: StringName in ids:
		var text: Dictionary = texts.get(skill, {})
		var ranks: Array = text.get("ranks", [])
		_check(not String(text.get("effect", "")).is_empty() and not String(text.get("mechanics", "")).is_empty() and ranks.size() == (3 if skill in PASSIVES else 5), "%s has pt-BR effect and per-rank tooltip" % skill)
		for line: Variant in ranks: _check(not String(line).is_empty() and String(line).begins_with("R"), "%s rank tooltip line: %s" % [skill, line])
		_check(not ClassCatalog.skill_definition(skill).display_name.is_empty() and SkillPresentation.mechanics_of(skill) == String(text["mechanics"]) and not SkillCopy.text_for(skill).is_empty(), "%s reaches SkillPresentation/SkillCopy" % skill)
	var names: Array[String] = []
	for definition: SkillDefinition in definitions: names.append(definition.display_name)
	_check(names == ["Marca Refratada", "Lâmina Encantada", "Refração", "Salto Prismático", "Fratura de Luz", "Sentença Prismática", "Espectro de Prisma"], "pt-BR names of the sheet")
	var effects := module.vfx_effects()
	_check(effects.size() == 11, "eleven reserved flipbook IDs")
	var canvas := Node2D.new()
	root.add_child(canvas)
	owned.append(canvas)
	for effect_id: StringName in effects:
		_check(String(effect_id).begins_with("arcane_blade_") and StringName(effects[effect_id]["skill_id"]) in SKILLS, "effect %s carries the prefix and a kit skill" % effect_id)
	_check(not module.draw_vfx(&"arcane_blade_unknown", canvas, {}, Vector2.ZERO, 0.5), "unknown effect is not drawn")
	_check(ClassKitRegistry.vfx_effect(LEAP, &"impact")["effect_id"] == &"arcane_blade_leap_strike" and ClassKitRegistry.vfx_effect(EDGE, &"effect_start")["effect_id"] == &"arcane_blade_crystal_swing" and ClassKitRegistry.vfx_effect(SPECTER, &"impact")["effect_id"] == &"arcane_blade_specter_strike", "effects reach the presentation catalog by skill and kind")
	_check(FeedbackRecipeCatalog.recipe(&"basic_attack", &"mg_la").get("family", &"") == &"melee", "the crystal blade basic attack has the melee recipe")
	_check(module.passive_modifier_source(EDGE, 3).is_empty() and module.passive_modifier_source(FRACTURE, 3).is_empty(), "the passives are kit rules, not permanent stat sources")

# --- Review builds (A11) -------------------------------------------------------------

func _check_review_builds() -> void:
	var file := FileAccess.open(BUILDS_PATH, FileAccess.READ)
	_check(file != null, "review_builds.json exists")
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary and parsed.get("schema") == "ragrpg_review_builds_v1" and parsed.get("identity_id") == "mg_la", "review builds schema and identity")
	if not parsed is Dictionary: return
	var builds: Array = parsed.get("builds", [])
	_check(builds.size() == 2, "exactly two named builds")
	var catalog := ProfileCatalog.pilot()
	var seen_ids: Array[String] = []
	for build: Variant in builds:
		var data: Dictionary = build
		var purchased: Dictionary[StringName, int] = {}
		var base_points := 0
		var evolution_points := 0
		var rank_sum := 0
		var final_ranks := {}
		for skill: Variant in data["base_ranks"]:
			purchased[StringName(skill)] = int(data["base_ranks"][skill])
			base_points += int(data["base_ranks"][skill])
			final_ranks[StringName(skill)] = int(data["base_ranks"][skill])
		for skill: Variant in data["evolution_ranks"]:
			var free := int(catalog.skill_metadata(StringName(skill)).get("free_rank", 0))
			purchased[StringName(skill)] = int(data["evolution_ranks"][skill]) - free
			evolution_points += int(data["evolution_ranks"][skill]) - free
			rank_sum += int(data["evolution_ranks"][skill])
			final_ranks[StringName(skill)] = int(data["evolution_ranks"][skill])
		seen_ids.append(String(data.get("id", "")))
		_check(String(data.get("id", "")).begins_with("arcane_blade_") and not String(data.get("name", "")).is_empty(), "build %s has id and pt-BR name" % data.get("id"))
		_check(base_points == 19 and catalog.skill_points_spent(purchased, ProfileCatalog.BASE_WALLET) == 19, "build %s spends the 19 base points" % data["id"])
		_check(evolution_points == 20 and rank_sum == 21 and catalog.skill_points_spent(purchased, ProfileCatalog.EVOLUTION_WALLET) == 20, "build %s spends the 20 evolution points (ranks sum 21 with the free R1)" % data["id"])
		var legal := catalog.validate_purchased_ranks(&"mage", &"mg_la", ProgressionRules.MAX_JOB_LEVEL, purchased)
		_check(legal.get("ok", false), "build %s is legal: %s" % [data["id"], legal])
		var shortcuts: Array = data.get("shortcuts", [])
		var known := true
		for skill: Variant in shortcuts: known = known and final_ranks.has(StringName(skill))
		_check(shortcuts.size() <= 24 and known and SKILLS.size() == data["evolution_ranks"].size(), "build %s shortcuts are learned skills (<= 24)" % data["id"])
		_check(final_ranks.has(&"teleport") and final_ranks.has(&"ice_spear"), "build %s keeps the Teleporte and the Lança de Gelo of the sheet" % data["id"])
	_check(seen_ids.size() == 2 and seen_ids[0] != seen_ids[1], "two distinct builds")

# --- Marca Refratada ---------------------------------------------------------------------

func _check_mark() -> void:
	_setup()
	var first := _enemy(Vector2(700, 350))
	var second := _enemy(Vector2(720, 420))
	_check(_cast(MARK, first) and flank.victim(player) == first and FlankRules.see_through(first), "Marca: the target is the victim, visible through obstacles")
	_check(is_equal_approx(player.skill_range(MARK), 500.0) and is_equal_approx(player.base_skill_cost(MARK), 6.0), "Marca R5: range 500, 6 SP")
	_check(_cast(MARK, second) and flank.victim(player) == second and not first.marks.has_mark(FlankRules.VICTIM_MARK), "marking another enemy removes the previous mark")
	# Marking does not reveal the concealment (defensive skill).
	_cast(REFRACTION)
	_check(player.kit_concealed(), "Refração conceals")
	_check(_cast(MARK, first) and player.kit_concealed() and flank.victim(player) == first, "the Marca keeps the Lâmina concealed")
	flank.end_concealment()
	# Kit requests on the victim get the Marca bonus; elsewhere they do not.
	var on_victim := _basic(first)
	var elsewhere := _basic(second)
	_check(is_equal_approx(float(on_victim.effect_snapshot.get("arcane_blade_mark_bonus", 0.0)), 1.13) and not elsewhere.effect_snapshot.has("arcane_blade_mark_bonus"), "Marca R5: +13% on the victim only")
	_check(not FlankRules.flags_of(on_victim.effect_snapshot).is_empty() and not FlankRules.flags_of(elsewhere.effect_snapshot).is_empty(), "every basic attack is marked by the authority")
	_check(not _cast(MARK, _enemy(Vector2(1100, 350))), "Marca out of range is refused")

# --- Crystal blade basic attack -------------------------------------------------------------

func _check_crystal_blade() -> void:
	# Without the passive the Mage bolt stays (a marked projectile).
	_setup(_all_ranks(5, 0))
	var bolts: Array[DamageRequest] = []
	player.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _facing: Vector2, _count: int) -> void: bolts.append(request))
	var far := _enemy(Vector2(600, 350))
	_check(kit.basic_attack_profile(player).is_empty() and is_equal_approx(player._basic_range(), 250.0) and player._basic_delivery() == &"mage", "Lâmina Encantada R0: the origin Mage basic attack")
	player.target = far
	_tick(0.05, 20)
	_check(not bolts.is_empty() and FlankRules.flags_of(bolts[0].effect_snapshot).has("side") and _element(bolts[0]).is_empty(), "the Mage bolt is still marked by the authority, without element")
	# With the passive: melee crystal blade alternating fire → ice → lightning.
	_setup()
	var requests: Array[DamageRequest] = []
	var bolt_count := [0]
	player.attack_requested.connect(func(request: DamageRequest, _target: CombatActor) -> void: requests.append(request))
	player.mage_projectile_requested.connect(func(_skill: StringName, _request: DamageRequest, _target: CombatActor, _facing: Vector2, _count: int) -> void: bolt_count[0] += 1)
	_check(kit.basic_attack_profile(player) == {"range": 50.0, "delivery": &"direct"} and player._basic_delivery() == &"direct" and is_equal_approx(player._basic_range(), 50.0), "Lâmina Encantada: melee profile, reach 50, direct delivery")
	var distant := _enemy(Vector2(600, 350))
	_check(not player.can_basic_attack(distant), "the crystal blade does not reach 200 px away")
	var target := _enemy(Vector2(440, 350))
	_check(player.can_basic_attack(target), "the crystal blade reaches the adjacent enemy")
	var hits := _hits_on(target)
	player.target = target
	var matk := player.stat_breakdown.value(&"magic_attack")
	var seen: Array[StringName] = []
	var time := 0.0
	while requests.size() < 4 and time < 20.0:
		_tick(0.05)
		time += 0.05
	for request: DamageRequest in requests: seen.append(_element(request))
	_check(requests.size() >= 4 and bolt_count[0] == 0, "the basic attacks are direct melee requests, no bolt (%d)" % requests.size())
	_check(seen.slice(0, 4) == [&"fire", &"ice", &"lightning", &"fire"], "the blade alternates fire → ice → lightning → fire: %s" % [seen])
	var magic_only := true
	for request: DamageRequest in requests:
		magic_only = magic_only and is_zero_approx(request.physical_damage) and is_equal_approx(request.magic_damage, matk * 1.20) and request.skill_id == &"basic_attack" and not FlankRules.flags_of(request.effect_snapshot).is_empty()
	_check(magic_only, "Lâmina R3: 120% of the magic ATK, magic only, marked basic_attack requests")
	_check(not hits.is_empty() and _element(hits[0]) == &"fire", "the blade element travels to the confirmed result")
	_check(kit.call(&"next_element") == _element_after(requests.size()), "the sequence state follows the strikes")

## Element expected after `count` strikes starting at fire.
func _element_after(count: int) -> StringName:
	return [&"fire", &"ice", &"lightning"][count % 3]

# --- Triad, reaction and retry -----------------------------------------------------------------

func _check_triad() -> void:
	_setup()
	var victim := _enemy(Vector2(440, 350))
	var hits := _hits_on(victim)
	flank.mark_victim(player, victim)
	_basic(victim)
	_basic(victim)
	_check(flank.sentence(player) == 2 and not bool(kit.get("reaction_pending")), "two blade strikes from the front: +1 each, no reaction yet")
	# Retry of the same confirmed result counts neither the Sentence nor the element.
	kit.on_damage_dealt(player, hits[1])
	_check(flank.sentence(player) == 2 and (kit.get("triad_landed") as Array).size() == 2, "a retried result adds no Sentence and no element")
	_basic(victim)
	_check(flank.sentence(player) == 5 and bool(kit.get("reaction_pending")) and (kit.get("triad_landed") as Array).is_empty(), "the third element: +1 and the triad +2 (5), reaction pending")
	var before := hits.size()
	_tick(0.05)
	_check(hits.size() == before + 1 and hits[-1]["skill_id"] == EDGE and bool(hits[-1]["effect_snapshot"].get("arcane_blade_reaction", false)) and float(hits[-1]["damage"]) > 0.0, "the prismatic reaction strikes the victim on the next tick")
	_check(not bool(kit.get("reaction_pending")) and int(kit.get("reaction_serial")) == 1, "a single reaction per triad")
	kit.on_damage_dealt(player, hits[-1])
	_check(flank.has_claimed("combo@triad:1") and flank.gained_total == 5, "the reaction itself never feeds the Sentence; the triad is one combo event")
	# The sequence restarts on a new victim.
	var other := _enemy(Vector2(440, 380))
	_basic(victim) # fire
	flank.mark_victim(player, other)
	_basic(other) # ice
	_basic(other) # lightning
	_check(not bool(kit.get("reaction_pending")) and (kit.get("triad_landed") as Array) == [&"ice", &"lightning"], "the sequence restarts when the victim changes")
	# Lança de Gelo holds the victim from afar: its hit counts as the ice of the sequence.
	_setup()
	var held := _enemy(Vector2(700, 350))
	flank.mark_victim(player, held)
	kit.set("blade_index", 0)
	var fire := player.kit_make_request(held, &"basic_attack", 0.0, 10.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	fire.effect_snapshot["arcane_blade_element"] = &"fire"
	controller._on_attack_requested(fire, held)
	var spear := player.kit_make_request(held, &"ice_spear", 0.0, 10.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	controller._on_attack_requested(spear, held)
	_check((kit.get("triad_landed") as Array) == [&"fire", &"ice"] and flank.sentence(player) == 2, "a Lança de Gelo hit on the victim counts as the ice (+1 direct)")
	var bolt := player.kit_make_request(held, &"lightning", 0.0, 10.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	controller._on_attack_requested(bolt, held)
	_check((kit.get("triad_landed") as Array) == [&"fire", &"ice"] and flank.sentence(player) == 3, "the base Relâmpago is a direct hit (+1) but not the blade lightning")

# --- Refração ---------------------------------------------------------------------------------

func _check_refraction() -> void:
	_setup(_all_ranks(1, 1))
	_check(int(kit.get("refraction_charges")) == 1, "one Refração charge at start")
	_check(_cast(REFRACTION) and player.kit_concealed() and is_equal_approx(flank.concealment_remaining, 3.0), "Refração R1: own concealment for 3 s")
	_check(is_equal_approx(player.skill_cooldown(REFRACTION), 1.0) and is_equal_approx(player.base_skill_cost(REFRACTION), 14.0), "Refração R1: 14 SP, canonical cooldown 1 s")
	_check(int(kit.get("refraction_charges")) == 0 and is_equal_approx(float(kit.get("refraction_recharge")), 14.0), "the charge is spent; it returns in 14 s")
	_check(_refusal(REFRACTION) == &"arcane_blade_already_concealed", "Refração refused while concealed")
	flank.end_concealment()
	_check(_refusal(REFRACTION) == &"arcane_blade_refraction_recharging" and not _cast(REFRACTION), "Refração refused without a charge")
	_tick(0.5, 27)
	_check(int(kit.get("refraction_charges")) == 0, "13.5 s later the charge is still recharging")
	_tick(0.5)
	_check(int(kit.get("refraction_charges")) == 1 and is_zero_approx(float(kit.get("refraction_recharge"))), "after 14 s the charge is back")
	# Attacking reveals; the first strike out of the concealment gives +2.
	var victim := _enemy(Vector2(440, 350))
	flank.mark_victim(player, victim)
	_cast(REFRACTION)
	var enemy := _hostile(Vector2(700, 350))
	_check(not player.can_be_acquired_by(enemy.global_position), "concealed: nobody acquires the Lâmina")
	var request := _basic(victim)
	_check(not player.kit_concealed() and bool(FlankRules.flags_of(request.effect_snapshot).get("from_concealment", false)) and flank.sentence(player) == 2, "attacking reveals; the opening strike gives +2")
	_check(_refusal(REFRACTION) == &"arcane_blade_refraction_recharging", "the next Refração waits for the charge")

# --- Salto Prismático ---------------------------------------------------------------------------

func _check_leap() -> void:
	_setup()
	var victim := _enemy(Vector2(650, 350))
	var bystander := _enemy(Vector2(650, 450))
	var hits := _hits_on(victim)
	flank.mark_victim(player, victim)
	_check(_refusal(LEAP, victim) == &"arcane_blade_not_concealed" and not _cast(LEAP, victim), "Salto refused when not concealed")
	_cast(REFRACTION)
	_check(_refusal(LEAP, bystander) == &"arcane_blade_not_victim", "Salto refused on an enemy that is not the victim")
	player.mage_cooldowns[LEAP] = 0.0
	player.current_sp = player.max_sp
	var sp := player.current_sp
	_check(player.use_kit_skill(LEAP, victim.global_position, victim), "Salto commits on the victim while concealed")
	var reach := victim.collision_radius + player.collision_radius + FlankRules.BACK_GAP
	_check(player.global_position.is_equal_approx(Vector2(650 + reach, 350)), "the Lâmina lands behind the victim (opposite its facing): %s" % player.global_position)
	_check(FlankRules.side_between(victim, player)["side"] == &"back" and is_equal_approx(sp - player.current_sp, 20.0), "Salto R5: 20 SP; behind the victim")
	_check(hits.size() == 1 and hits[0]["skill_id"] == LEAP, "the Salto strikes once")
	var flags := FlankRules.result_flags(hits[0])
	_check(flags.get("side") == &"back" and bool(flags.get("from_concealment", false)) and flank.sentence(player) == 2, "the strike counts from behind and from the concealment: +2 (sources do not add up)")
	_check(not player.kit_concealed() and player.target == victim, "the Salto reveals and engages the victim")
	_check(is_equal_approx(float(hits[0]["effect_snapshot"].get("arcane_blade_mark_bonus", 0.0)), 1.13), "the Salto strike carries the Marca bonus")
	# Back point validated before the payment: a blocked back costs nothing.
	var walls: Array[Rect2] = [Rect2(690, 300, 60, 100)]
	_setup(_all_ranks(), walls)
	var cornered := _enemy(Vector2(650, 350))
	flank.mark_victim(player, cornered)
	_cast(REFRACTION)
	player.mage_cooldowns[LEAP] = 0.0
	player.current_sp = player.max_sp
	sp = player.current_sp
	var start := player.global_position
	_check(_refusal(LEAP, cornered) == &"back_point_blocked" and not player.use_kit_skill(LEAP, cornered.global_position, cornered), "a blocked back point refuses the Salto (0°, +30°, -30°)")
	_check(is_equal_approx(player.current_sp, sp) and is_zero_approx(player.skill_cooldown(LEAP)) and player.global_position == start and player.kit_concealed(), "a refused Salto costs no SP, no cooldown and keeps the concealment")
	# Range of the cast.
	_setup()
	var far := _enemy(Vector2(900, 350))
	flank.mark_victim(player, far)
	_cast(REFRACTION)
	_check(not player.can_target_skill(LEAP, far) and not _cast(LEAP, far), "a victim beyond 380 is out of the Salto range")
	player.global_position = Vector2(540, 350)
	_check(_cast(LEAP, far) and FlankRules.side_between(far, player)["side"] == &"back", "inside 380 the Salto reaches the victim")

## Limitation 3 of T6 on the flat map: a pending private route must not continue after
## the teleport. The Salto engages the victim through the public pursue command.
func _check_leap_flat_route() -> void:
	_setup()
	var victim := _enemy(Vector2(650, 350))
	var hits := _hits_on(victim)
	flank.mark_victim(player, victim)
	_cast(REFRACTION)
	player.move_to(Vector2(100, 350))
	_tick(0.05, 2)
	_check(player.global_position.x < 400.0, "the Lâmina was walking away to the left")
	_cast(LEAP, victim)
	var landed := player.global_position
	_tick(0.05, 30)
	var stayed := player.global_position.distance_to(victim.global_position) <= player.basic_attack_distance(victim) + 1.0
	_check(stayed and player.global_position.distance_to(landed) < 20.0, "after the teleport the old flat route does not continue (%s → %s)" % [landed, player.global_position])
	_check(hits.size() >= 2 and _element(hits[-1]) in [&"fire", &"ice", &"lightning"], "the Lâmina keeps cutting the victim with the crystal blade (%d hits)" % hits.size())

# --- Sentença Prismática and Fratura de Luz ------------------------------------------------------

func _check_sentence_and_fracture() -> void:
	_setup()
	var victim := _enemy(Vector2(440, 350))
	var hits := _hits_on(victim)
	_fill(victim)
	_check(flank.sentence(player) == 5, "full Sentence prepared")
	_check(_cast(SENTENCE, victim) and hits.size() == 1, "Sentença Prismática commits on the victim")
	var flags := FlankRules.result_flags(hits[0])
	_check(bool(flags.get("execution", false)) and int(flags.get("charges", 0)) == 5 and not bool(flags.get("lethal", true)) and flank.sentence(player) == 0, "execution spends the 5 charges (not lethal at full HP)")
	_check(float(hits[0]["damage"]) > 0.0 and is_equal_approx(float(hits[0]["effect_snapshot"].get("arcane_blade_mark_bonus", 0.0)), 1.13), "magic execution damage with the Marca bonus")
	# No duplication in retry: a second commit at the same kit_time is refused and spends nothing.
	_fill(victim)
	var retry := flank.execute(player, victim, SENTENCE, 0.0, 100.0, {"emit": false})
	_check(retry["error_code"] == &"already_executed" and flank.sentence(player) == 5 and hits.size() == 1, "a retried Sentence in the same commit is refused and keeps the Sentence")
	kit.on_damage_dealt(player, hits[0])
	_check(flank.sentence(player) == 5, "the execution result never feeds the Sentence, also in retry")
	_check(not player.use_kit_skill(SENTENCE, victim.global_position, victim), "the Sentença waits for its 7 s cooldown")
	# Thresholds per category and the boss (A4).
	for category: StringName in [&"normal", &"rare", &"elite", &"rare_elite"]:
		_setup()
		var target := _hostile(Vector2(440, 350))
		target.occurrence.category_id = category
		var threshold := FlankRules.execution_threshold(category)
		target.health.current_hp = target.health.max_hp * (threshold + 0.03)
		_fill(target)
		_cast(SENTENCE, target)
		_check(target.is_alive(), "%s above %d%%: no certain death" % [category, roundi(threshold * 100.0)])
		target.health.current_hp = target.health.max_hp * threshold
		player.kit_time += 1.0
		_fill(target)
		var target_hits := _hits_on(target)
		_cast(SENTENCE, target)
		_check(not target.is_alive() and target_hits.size() == 1 and bool(FlankRules.result_flags(target_hits[0]).get("lethal", false)), "%s at %d%% with 5 charges: certain death through DamageRequest" % [category, roundi(threshold * 100.0)])
	_setup()
	var boss := _hostile(Vector2(440, 350))
	boss.occurrence.category_id = &"boss"
	boss.hard_controls.boss = true
	boss.health.current_hp = boss.health.max_hp * 0.01
	_fill(boss)
	var boss_hits := _hits_on(boss)
	_cast(SENTENCE, boss)
	_check(boss.is_alive() and boss_hits.size() == 1 and not bool(FlankRules.result_flags(boss_hits[0]).get("lethal", true)) and flank.lethal_total == 0, "boss at 1% with 5 charges: no certain death, only damage")
	# Fratura de Luz: an execution kill returns the Refração charge and SP, once.
	_setup()
	_cast(REFRACTION)
	flank.end_concealment()
	_check(int(kit.get("refraction_charges")) == 0, "the Refração charge is spent")
	var doomed := _enemy(Vector2(440, 350), 1000.0)
	doomed.health.current_hp = 250.0
	_fill(doomed)
	var doomed_hits := _hits_on(doomed)
	player.mage_cooldowns[SENTENCE] = 0.0
	player.current_sp = player.max_sp * 0.5
	var sp := player.current_sp
	_check(player.use_kit_skill(SENTENCE, doomed.global_position, doomed) and not doomed.is_alive(), "the Sentença kills the doomed victim")
	_check(int(kit.get("refraction_charges")) == 1 and is_zero_approx(float(kit.get("refraction_recharge"))) and int(kit.get("fracture_total")) == 1, "Fratura: the kill returns the Refração charge (a charge, not an instant concealment)")
	_check(not flank.concealment_armed and is_equal_approx(player.current_sp, sp - 22.0 + player.max_sp * 0.16), "Fratura R3: +16% of max SP; no concealment is forced")
	kit.on_kill_confirmed(player, doomed_hits[0])
	kit.on_kill_confirmed(player, doomed_hits[0])
	_check(int(kit.get("fracture_total")) == 1 and flank.execution_kills == 1, "a retried kill callback returns nothing again")
	# A common kill returns nothing.
	_setup()
	_cast(REFRACTION)
	flank.end_concealment()
	var common := _enemy(Vector2(440, 350), 5.0)
	var heavy := player.kit_make_request(common, &"basic_attack", 0.0, 500.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	controller._on_attack_requested(kit.compose_basic_attack(player, common, heavy), common)
	_check(not common.is_alive() and int(kit.get("refraction_charges")) == 0 and int(kit.get("fracture_total")) == 0, "a basic-attack kill returns no charge")
	# Without the Fratura passive, nothing either.
	var no_fracture := _all_ranks()
	no_fracture[FRACTURE] = 0
	_setup(no_fracture)
	_cast(REFRACTION)
	flank.end_concealment()
	var plain := _enemy(Vector2(440, 350), 1000.0)
	plain.health.current_hp = 250.0
	_fill(plain)
	_cast(SENTENCE, plain)
	_check(not plain.is_alive() and int(kit.get("refraction_charges")) == 0, "without the Fratura the execution kill returns no charge")

# --- Espectro de Prisma -----------------------------------------------------------------------------

func _check_specter() -> void:
	_setup()
	var near := _enemy(Vector2(470, 350), 100000.0, Vector2.LEFT)
	var middle := _enemy(Vector2(400, 470), 100000.0, Vector2.UP)
	var victim := _enemy(Vector2(620, 350), 1000.0, Vector2.LEFT)
	var fourth := _enemy(Vector2(400, 230), 100000.0, Vector2.DOWN)
	var outside := _enemy(Vector2(1000, 350), 100000.0, Vector2.LEFT)
	victim.health.current_hp = 250.0
	_fill(victim)
	var logs := {}
	for enemy: CombatActor in [near, middle, victim, fourth, outside]: logs[enemy] = _hits_on(enemy)
	_check(_cast(SPECTER), "Espectro de Prisma commits")
	_check(not victim.is_alive() and logs[victim].size() == 1, "the first reflection strikes the victim at once")
	var flags := FlankRules.result_flags(logs[victim][0])
	_check(bool(flags.get("execution", false)) and bool(flags.get("lethal", false)) and int(flags.get("charges", 0)) == 5 and flags.get("side") == &"back", "the victim's reflection is an execution from behind (certain death under the threshold)")
	_check(int(kit.get("fracture_total")) == 1 and int(kit.get("refraction_charges")) == 1, "the reflection execution kill triggers the Fratura")
	_check(int(kit.get("specter_pending")) == 2 and near.marks.owner_of(&"arcane_blade_specter") == player.get_instance_id() and middle.marks.has_mark(&"arcane_blade_specter"), "two more reflections wait on the two nearest enemies")
	_check(not fourth.marks.has_mark(&"arcane_blade_specter") and not outside.marks.has_mark(&"arcane_blade_specter"), "three reflections only, never outside the radius")
	_check(player.kit_compact_blocker() == "arcane_blade_prism_specter_reflections", "pending reflections make the compact cut ineligible")
	paused = true
	_tick(1.0)
	_check(int(kit.get("specter_pending")) == 2 and logs[near].is_empty(), "pause freezes the reflections")
	paused = false
	_tick(0.05)
	_check(logs[near].is_empty(), "the second reflection waits 0.2 s")
	_tick(0.05, 3)
	_check(logs[near].size() == 1 and logs[middle].is_empty(), "the second reflection strikes the nearest enemy at 0.2 s")
	_tick(0.05, 4)
	_check(logs[middle].size() == 1 and int(kit.get("specter_pending")) == 0 and player.kit_compact_blocker().is_empty(), "the third reflection strikes at 0.4 s; the compact cut is eligible again")
	for enemy: CombatActor in [near, middle]:
		var reflection := FlankRules.result_flags(logs[enemy][0])
		_check(bool(reflection.get("execution", false)) and reflection.get("side") == &"back" and int(reflection.get("charges", -1)) == 0 and not bool(reflection.get("lethal", true)), "a reflection on another enemy: execution from its own back point, no charges")
	var elements: Array[String] = [String(logs[victim][0]["effect_snapshot"].get("arcane_blade_reflection", "")), String(logs[near][0]["effect_snapshot"].get("arcane_blade_reflection", "")), String(logs[middle][0]["effect_snapshot"].get("arcane_blade_reflection", ""))]
	_check(elements == ["fire", "ice", "lightning"], "one reflection per element: %s" % [elements])
	_check(logs[fourth].is_empty() and logs[outside].is_empty(), "no fourth reflection")
	# Nothing in the radius: refused before the payment.
	_setup()
	_enemy(Vector2(1000, 350))
	_check(_refusal(SPECTER) == &"arcane_blade_no_reflection_target" and not _cast(SPECTER), "Espectro refused without an enemy in the radius")
	# A reflection whose target died is dropped.
	_setup()
	var a := _enemy(Vector2(470, 350))
	var b := _enemy(Vector2(470, 300), 10.0)
	_cast(SPECTER)
	var b_hits := _hits_on(b)
	var kill := player.kit_make_request(b, &"basic_attack", 0.0, 500.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	controller._on_attack_requested(kit.compose_basic_attack(player, b, kill), b)
	_tick(0.05, 10)
	_check(not b.is_alive() and b_hits.size() == 1 and int(kit.get("specter_pending")) == 0, "a pending reflection on a dead enemy is dropped")
	_check(a.is_alive(), "the other reflection struck normally")

# --- Base Teleporte: the exit -----------------------------------------------------------------------

func _check_base_teleport_exit() -> void:
	_setup()
	var near := _hostile(Vector2(460, 350))
	var far := _hostile(Vector2(400, 650))
	_check(not _sight_broken(near) and not _sight_broken(far), "both enemies see the Lâmina")
	player.mage_cooldowns[&"teleport"] = 0.0
	player.current_sp = player.max_sp
	_check(player.use_teleport(Vector2(700, 200)), "the base Teleporte commits")
	_check(_sight_broken(near) and not _sight_broken(far), "the Teleporte is the exit: the enemy near the departure loses sight, the far one does not")
	# A refused Teleporte calls no hook.
	_setup()
	var other := _hostile(Vector2(460, 350))
	player.mage_cooldowns[&"teleport"] = 0.0
	player.current_sp = 0.0
	_check(not player.use_teleport(Vector2(700, 200)) and not _sight_broken(other), "a refused Teleporte breaks no sight")
	# Other base skills are not the exit.
	player.current_sp = player.max_sp
	player.mage_cooldowns[&"ice_spear"] = 0.0
	player.use_spear(&"ice_spear", other)
	_check(not _sight_broken(other), "the Lança de Gelo commit is not the exit")

# --- Build change, death and pause -----------------------------------------------------------------

func _check_build_change_death_and_pause() -> void:
	_setup()
	var victim := _enemy(Vector2(440, 350))
	var other := _enemy(Vector2(470, 300))
	flank.mark_victim(player, victim)
	_cast(SPECTER) # the victim's reflection strikes at once (0 charges); another one waits
	_basic(victim)
	_cast(REFRACTION)
	player.health.current_hp = player.health.max_hp * 0.4
	player.current_sp = player.max_sp * 0.3
	player.mage_cooldowns[SENTENCE] = 3.0
	var hp := player.health.current_hp
	var sp := player.current_sp
	var hidden := flank.concealment_remaining
	var recharge := float(kit.get("refraction_recharge"))
	var landed := (kit.get("triad_landed") as Array).duplicate()
	var index := int(kit.get("blade_index"))
	player.apply_run_modifiers(player.run_state)
	_check(is_equal_approx(player.health.current_hp, hp) and is_equal_approx(player.current_sp, sp) and is_equal_approx(player.skill_cooldown(SENTENCE), 3.0), "build change: no heal, no SP refill, no cooldown reset")
	_check(player.kit == kit and flank.victim(player) == victim and flank.sentence(player) == 1 and int(kit.get("refraction_charges")) == 0 and is_equal_approx(float(kit.get("refraction_recharge")), recharge) and (kit.get("triad_landed") as Array) == landed and int(kit.get("blade_index")) == index, "build change: no reset of victim, Sentence, charge, sequence")
	paused = true
	_tick(1.0)
	_check(is_equal_approx(float(kit.get("refraction_recharge")), recharge) and is_equal_approx(flank.concealment_remaining, hidden), "pause freezes every kit clock")
	paused = false
	var pending := int(kit.get("specter_pending"))
	player.health.current_hp = 1.0
	player.apply_damage(_claw(victim, 100000.0), controller.rng)
	_check(not player.is_alive(), "the Lâmina dies")
	_check(not flank.concealment_active() and flank.victim(player) == null and not victim.marks.has_mark(FlankRules.VICTIM_MARK), "death: concealment and victim end")
	_check(int(kit.get("specter_pending")) == 0 and not other.marks.has_mark(&"arcane_blade_specter") and pending == 1 and (kit.get("triad_landed") as Array).is_empty() and not bool(kit.get("reaction_pending")), "death: reflections, sequence and reaction end")
	_check(int(kit.get("refraction_charges")) == 0, "death keeps the Refração charge state")

# --- Snapshot formats ---------------------------------------------------------------------------------

func _check_snapshot_formats() -> void:
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty() and registry.schemas.has(KIT_PATH), "the mg_la fragment merges: " + str(registry.fragment_errors))
	if registry.schemas.has(KIT_PATH):
		var fields: Array = registry.schemas[KIT_PATH].get("fields", [])
		_check(fields == FIELDS and int(registry.schemas[KIT_PATH].get("revision", 0)) == 2, "the kit lists its fields (revision 2)")
	_setup()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var standalone := _make_player(navigation, _all_ranks())
	standalone.global_position = Vector2(400, 350)
	standalone.character_animation.state.face(Vector2.RIGHT)
	owned.append(standalone)
	var standalone_kit := standalone.kit
	var standalone_flank: FlankAuthority = standalone_kit.get("flank")
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = Vector2(440, 350)
	enemy.health.max_hp = 1000.0
	enemy.health.current_hp = 1000.0
	standalone.add_child(enemy)
	standalone_flank.mark_victim(standalone, enemy)
	standalone_flank.gain(standalone, enemy, FlankRules.SOURCE_COMBO, "snap_a")
	standalone_flank.gain(standalone, enemy, FlankRules.SOURCE_DIRECT, "snap_b")
	standalone_flank.enter_concealment(standalone, 4.0)
	standalone_kit.set("blade_index", 2)
	standalone_kit.set("triad_serial", standalone_flank.victim_serial)
	var landed: Array[StringName] = [&"fire", &"ice"]
	standalone_kit.set("triad_landed", landed)
	standalone_kit.set("reaction_serial", 4)
	standalone_kit.set("refraction_charges", 0)
	standalone_kit.set("refraction_recharge", 6.5)
	standalone_kit.set("fracture_total", 3)
	standalone.kit_time = 11.0
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(standalone)["ok"], "barrier acquired")
	var captured := SnapshotRegistry.new().capture(standalone, barrier)
	_check(captured.get("ok", false), "exact capture with victim, concealment and sequence: " + str(captured.get("detail", captured.get("error_code", ""))))
	if captured.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(captured["snapshot"])))
		_check(restored.get("ok", false), "exact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied_kit := copy.kit
			var copied: FlankAuthority = copied_kit.get("flank") if copied_kit != null else null
			var copied_enemy: CombatActor = null
			for child: Node in copy.get_children():
				if child is CombatActor: copied_enemy = child
			_check(copied != null and copied_enemy != null and copied.victim(copy) == copied_enemy and copied.sentence(copy) == 3, "exact format keeps the victim and its Sentence with the restored enemy")
			_check(copied != null and copied.concealment_armed and is_equal_approx(copied.concealment_remaining, 4.0), "exact format keeps the own concealment")
			_check(copied_kit != null and int(copied_kit.get("blade_index")) == 2 and (copied_kit.get("triad_landed") as Array) == [&"fire", &"ice"] and int(copied_kit.get("triad_serial")) == copied.victim_serial and int(copied_kit.get("reaction_serial")) == 4, "exact format keeps the blade sequence bound to the victim")
			_check(copied_kit != null and int(copied_kit.get("refraction_charges")) == 0 and is_equal_approx(float(copied_kit.get("refraction_recharge")), 6.5) and int(copied_kit.get("fracture_total")) == 3 and is_equal_approx(copy.kit_time, 11.0), "exact format keeps the Refração charge, its recharge and the clock")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	_check(standalone.kit_compact_blocker().is_empty(), "without reflections the Lâmina does not block the compact cut")
	var projection := {"fields": {}, "excluded": {enemy.get_instance_id(): true}}
	var compact := SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("ok", false), "the compact cut stays eligible with a living victim: " + str(compact.get("detail", compact.get("error_code", ""))))
	if compact.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(compact["snapshot"])))
		_check(restored.get("ok", false), "compact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied_kit := copy.kit
			var copied: FlankAuthority = copied_kit.get("flank")
			_check(int(copied_kit.get("refraction_charges")) == 0 and is_equal_approx(float(copied_kit.get("refraction_recharge")), 6.5) and int(copied_kit.get("blade_index")) == 2 and copied.concealment_armed, "compact format keeps the player state (charge, recharge, sequence index, concealment)")
			_check(copied.victim(copy) == null and copied.sentence(copy) == 0, "compact format: the enemy returns without marks, so no victim (A5)")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	# Pending reflections: the compact cut is refused, the exact one keeps them with the enemy.
	enemy.marks.set_mark(&"arcane_blade_specter", standalone.get_instance_id(), {"serial": 1, "order": 1, "due": 11.2, "element": "ice"}, 3.0)
	standalone_kit.set("specter_serial", 1)
	standalone_kit.set("specter_pending", 1)
	var refused := SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(not refused.get("ok", false) and refused.get("error_code") == &"kit_compact_ineligible", "pending reflections refuse the compact cut: %s" % refused.get("error_code"))
	var exact := SnapshotRegistry.new().capture(standalone, barrier)
	_check(exact.get("ok", false), "exact capture with a pending reflection")
	if exact.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(exact["snapshot"])))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied_enemy: CombatActor = null
			for child: Node in copy.get_children():
				if child is CombatActor: copied_enemy = child
			_check(copied_enemy != null and copied_enemy.marks.owner_of(&"arcane_blade_specter") == copy.get_instance_id() and int(copy.kit.get("specter_pending")) == 1, "exact format keeps the pending reflection with the enemy, owner rebound")
			SnapshotRegistry.new().activate(restored)
			copy.free()
		else:
			_check(false, "exact restore with a reflection: " + str(restored.get("error_code", "")))
	barrier.release()

# --- Source guards ------------------------------------------------------------------------------------

func _check_source_guards() -> void:
	var source := FileAccess.get_file_as_string(KIT_PATH)
	_check(not source.is_empty() and not source.contains("current_hp =") and not source.contains("current_hp -="), "the kit never writes HP directly")
	_check(not source.contains("KIT_RULE"), "no item KIT_RULE (A10)")
	_check(not source.contains("mage_cooldowns") and not source.contains("concealment_reveal_remaining") and not source.contains("_path"), "the kit writes no private player state (cooldowns, reveal window, route)")
	var requests := source.count("kit_make_request(")
	var marked := source.count("_mark(player, blade") + source.count("_mark(player, request")
	_check(requests == 3 and marked >= 3 and source.count("flank.execute(") == 2, "every kit request goes through flank.mark_request (blade, Salto, reaction via _mark; Sentença and reflections via execute)")
