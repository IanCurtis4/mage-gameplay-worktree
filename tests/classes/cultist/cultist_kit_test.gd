extends SceneTree
## E10a T7 — Cultista (`cultist`) kit invariants (docs/epics/e10a/t7_contract.md): catalog
## data and readiness, the Profeta and Vidente builds, the authority read from the origin
## (never a second copy), Olhar do Abismo channel (cone, ticks, Madness once per tick event,
## interruption), Êxtase forwarded once (MATK, cost, onus from 3, 0..5, compensation by
## Escudo Votivo and Prece), Ídolo (one per owner, boss never retargeted), Delírio
## Compartilhado (one hop), Delirium cap 3, Pupila Aberta (owner filter), Geometria
## (commons lose their way, boss slowed), Revelação (strong Disorientation once per cast even
## under immunity, longer immunity, delirious hurt each other), base Madness summing (Selo,
## Sussurro), death, pause and both snapshot formats. The Acólito base is the T7 stand-in
## (scripts/classes/cultist/fixture/) until T5 is composed; enemies are real forest mobs.
const FixtureBase = preload("res://scripts/classes/cultist/fixture/cultist_fixture_base.gd")
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const KIT_PATH := "res://scripts/classes/cultist/cultist_kit.gd"
const BUILDS_PATH := "res://scripts/classes/cultist/review_builds.json"
const GAZE := &"cultist_abyss_gaze"
const ECSTASY := &"cultist_ecstasy"
const IDOL := &"cultist_impossible_idol"
const SHARED := &"cultist_shared_delirium"
const PUPIL := &"cultist_open_pupil"
const GEOMETRY := &"cultist_impossible_geometry"
const REVELATION := &"cultist_revelation"

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var kit: ClassKit
var authority: MadnessAuthority
var navigation: ArenaNavigation
var attacks: Array[Array] = []
var mob_serial := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	_install()
	_check_catalog()
	_check_review_builds()
	_check_authority_from_origin()
	_check_gaze()
	_check_ecstasy()
	_check_idol()
	_check_shared_delirium()
	_check_delirium_cap()
	_check_pupil()
	_check_geometry()
	_check_revelation()
	_check_base_madness()
	_check_delirium_kill()
	_check_death_and_pause()
	_check_snapshot_formats()
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	KitDecoy.unregister_drawer(MadnessRules.IDOL_DRAWER)
	print("E10a T7 cultist kit: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixture ---------------------------------------------------------------------------

func _install() -> void:
	ClassKitRegistry.clear_fixtures()
	_check(ClassBaseRegistry.install_fixture(&"acolyte", FixtureBase.new()), "the T7 stand-in base is installed over acolyte")

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	attacks.clear()
	paused = false

func _all_ranks(active: int = 5, passive: int = 3) -> Dictionary:
	var ranks := {&"acolyte_punishing_light": 1, &"acolyte_prayer": 1, &"acolyte_votive_shield": 1, &"acolyte_shadow_seal": 1, &"acolyte_disturbing_whisper": 1, &"acolyte_protective_faith": 1}
	for skill: StringName in ClassKitRegistry.skill_ids(&"cultist"): ranks[skill] = passive if skill in [ECSTASY, PUPIL] else active
	return ranks

func _make_player(nav: ArenaNavigation, ranks: Dictionary) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"acolyte"
	snapshot.evolution_id = &"cultist"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"acolyte", &"cultist")
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [GAZE, IDOL, SHARED, GEOMETRY, REVELATION]
	var actor := PlayerActor.new()
	actor.configure(nav, RunState.from_build("cultist-" + str(checks), snapshot))
	return actor

func _setup(ranks: Dictionary = {}, position: Vector2 = Vector2(300, 350)) -> void:
	_cleanup()
	navigation = ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1400, 900), [], 20.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	player = _make_player(navigation, ranks if not ranks.is_empty() else _all_ranks())
	controller.add_child(player)
	player.set_process(false)
	player.global_position = position
	player.character_animation.state.face(Vector2.RIGHT)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 31
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	kit = player.kit
	authority = MadnessAuthority.of(player) as MadnessAuthority

## A real catalog mob of the forest phase.
func _mob(mob_id: StringName, at: Vector2, category: StringName = &"normal", hp: float = 100000.0) -> EnemyActor:
	mob_serial += 1
	var hostile := EnemyActor.new()
	hostile.global_position = at
	var spawn := MobOccurrence.new()
	spawn.occurrence_id = "t7_%s_%03d" % [mob_id, mob_serial]
	spawn.mob_base_id = mob_id
	spawn.category_id = category
	spawn.origin_id = &"trial_stage_1"
	var configured := hostile.configure_occurrence(spawn, BuildContentLoader.pilot().mob_catalog(), navigation, player)
	_check(configured.get("ok", false), "real mob %s configured: %s" % [mob_id, configured])
	controller.add_child(hostile)
	hostile.set_process(false)
	hostile.health.max_hp = hp
	hostile.health.current_hp = hp
	hostile.attack_requested.connect(func(request: DamageRequest, target: CombatActor, ranged: bool) -> void: attacks.append([request, target, ranged, hostile]))
	hostile.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(hostile)
	return hostile

func _boss(at: Vector2) -> EnemyActor:
	return _mob(&"forest_ancient_warden", at, &"boss")

## Gameplay clock: enemy statuses and overrides, then both modules' on_tick (outside pause).
func _advance(delta: float) -> void:
	for candidate: Variant in controller.enemies.duplicate():
		var hostile := candidate as EnemyActor
		if is_instance_valid(hostile) and hostile.is_alive():
			hostile.advance_statuses(delta)
			hostile._advance_target_override(delta)
	player.advance_statuses(delta)
	player.kit_time += delta
	for module: ClassKit in player.kit_modules(): module.on_tick(player, delta)

func _advance_for(seconds: float, step: float = 0.05) -> void:
	var left := seconds
	while left > 0.0001:
		_advance(minf(step, left))
		left -= step

func _cast(skill: StringName, enemy: CombatActor = null, point: Variant = null) -> bool:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp
	player.kit_time += 0.001
	var at: Vector2 = point if point is Vector2 else (enemy.global_position if enemy != null else player.global_position)
	return player.use_kit_skill(skill, at, enemy)

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

func _taken(source: CombatActor, amount: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return player.apply_damage(_enemy_request(source, amount), rng)

# --- Catalog ---------------------------------------------------------------------------

func _check_catalog() -> void:
	var module := ClassKitRegistry.module(&"cultist")
	_check(module != null and module.get_script().resource_path == KIT_PATH, "the production module is the cultist kit")
	_check(ClassKitRegistry.validate(&"cultist").get("ok", false), "registry validation passes: " + str(ClassKitRegistry.validate(&"cultist")))
	_check(module.ready_for_play() and ClassKitRegistry.ready_for_play(&"cultist"), "the kit is ready for play")
	var source := FileAccess.get_file_as_string(KIT_PATH)
	_check(not source.contains("class_name") and not source.contains("EnemyActor") and not source.contains("\nvar madness"),"A7: no own class_name, no EnemyActor, no second authority field")
	var definitions := module.skill_definitions()
	var ids: Array[StringName] = []
	for definition: SkillDefinition in definitions: ids.append(definition.id)
	_check(ids == ClassKitRegistry.skill_ids(&"cultist") and ids == [GAZE, ECSTASY, IDOL, SHARED, PUPIL, GEOMETRY, REVELATION], "seven skills in the job order of §1")
	for index: int in definitions.size():
		var definition := definitions[index]
		var active: bool = ClassKitRegistry.SLOT_CATEGORIES[index] == &"active"
		_check(definition.handler_id == SkillDefinition.Handler.KIT and definition.is_rank_catalog_valid() and definition.ranks.size() == (5 if active else 3) and definition.element == &"shadow", "%s: kit handler, ranks 1-%d, shadow (D5)" % [definition.id, 5 if active else 3])
	var learning := module.learning_entries()
	_check(learning.size() == 7 and int(learning[0]["free_rank"]) == 1 and int(learning[0]["job_level"]) == 20 and int(learning[6]["job_level"]) == 37 and not learning[0].has("prerequisites"), "learning rows: free entry at job 20 (no prerequisites) through job 37")
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid(), "ProfileCatalog stays valid with the Cultista ready")
	var offered: Array[StringName] = []
	for evolution: EvolutionDefinition in catalog.evolution_definitions_for_origin(&"acolyte"): offered.append(evolution.id)
	_check(&"cultist" in offered, "the Acólito is offered the Cultista when the base is ready: %s" % [offered])
	var texts := module.skill_texts()
	for skill: StringName in ids:
		var text: Dictionary = texts.get(skill, {})
		var ranks: Array = text.get("ranks", [])
		_check(not String(text.get("effect", "")).is_empty() and not String(text.get("flavor", "")).is_empty() and ranks.size() == (3 if skill in [ECSTASY, PUPIL] else 5), "%s has pt-BR name, effect and per-rank tooltip" % skill)
		for line: Variant in ranks: _check(String(line).begins_with("R") and String(line).length() > 8, "%s rank tooltip line: %s" % [skill, line])
		_check(not ClassCatalog.skill_definition(skill).display_name.is_empty() and SkillPresentation.mechanics_of(skill) == String(text["mechanics"]), "%s reaches SkillPresentation" % skill)
		_check(not FeedbackRecipeCatalog.recipe(skill).is_empty() and ClassKitRegistry.feedback_recipe(skill)[1] == &"shadow", "%s has a shadow feedback recipe" % skill)
	var effects := module.vfx_effects()
	_check(effects.size() == 9, "nine reserved flipbook IDs")
	var canvas := Node2D.new()
	root.add_child(canvas)
	owned.append(canvas)
	for effect_id: StringName in effects:
		_check(String(effect_id).begins_with("cultist_") and StringName(effects[effect_id]["skill_id"]) in ids, "effect %s carries the prefix and a kit skill" % effect_id)
	_check(effects.has(MadnessRules.IDOL_FLIPBOOK_ID), "the Idol flipbook ID reserved by T4 is listed")
	_check(not module.draw_vfx(&"cultist_unknown", canvas, {}, Vector2.ZERO, 0.5), "unknown effect is not drawn")
	_check(ClassKitRegistry.vfx_effect(GAZE, &"impact")["effect_id"] == &"cultist_abyss_gaze_hit", "effects reach the presentation catalog")
	_check(module.passive_modifier_source(ECSTASY, 3).is_empty() and module.passive_modifier_source(PUPIL, 3).is_empty(), "the passives have no permanent stat source (state-driven)")

func _check_review_builds() -> void:
	var file := FileAccess.open(BUILDS_PATH, FileAccess.READ)
	_check(file != null, "review_builds.json exists")
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary and parsed.get("schema") == "ragrpg_review_builds_v1" and parsed.get("identity_id") == "cultist", "review builds schema and identity")
	if not parsed is Dictionary: return
	var builds: Array = parsed.get("builds", [])
	_check(builds.size() == 2 and builds[0]["name"] == "Profeta" and builds[1]["name"] == "Vidente", "the two D6 builds: Profeta and Vidente")
	var catalog := ProfileCatalog.pilot()
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
			purchased[StringName(skill)] = maxi(0, int(data["evolution_ranks"][skill]) - free)
			evolution_points += maxi(0, int(data["evolution_ranks"][skill]) - free)
			rank_sum += int(data["evolution_ranks"][skill])
			if int(data["evolution_ranks"][skill]) > 0: final_ranks[StringName(skill)] = int(data["evolution_ranks"][skill])
		_check(base_points == 19 and catalog.skill_points_spent(purchased, ProfileCatalog.BASE_WALLET) == 19, "build %s spends the 19 base points" % data["id"])
		_check(evolution_points == 20 and rank_sum == 21 and catalog.skill_points_spent(purchased, ProfileCatalog.EVOLUTION_WALLET) == 20, "build %s spends the 20 evolution points" % data["id"])
		var legal := catalog.validate_purchased_ranks(&"acolyte", &"cultist", ProgressionRules.MAX_JOB_LEVEL, purchased)
		_check(legal.get("ok", false), "build %s is legal: %s" % [data["id"], legal])
		var known := true
		for skill: Variant in data["shortcuts"]: known = known and final_ranks.has(StringName(skill))
		_check(data["shortcuts"].size() <= 24 and known, "build %s shortcuts are learned skills" % data["id"])
	var prophet: Dictionary = builds[0]
	var seer: Dictionary = builds[1]
	_check(int(prophet["evolution_ranks"][ECSTASY]) > 0 and int(prophet["evolution_ranks"][PUPIL]) > 0 and int(prophet["base_ranks"].get("acolyte_disturbing_whisper", 0)) > 0 and int(prophet["evolution_ranks"][IDOL]) > 0 and int(prophet["evolution_ranks"][SHARED]) > 0, "Profeta: Olhar, Ídolo, Delírio Compartilhado, Sussurro, Revelação; Êxtase and Pupila")
	_check(int(seer["evolution_ranks"][PUPIL]) > 0 and int(seer["base_ranks"].get("acolyte_devotion", 0)) > 0 and int(seer["evolution_ranks"][GEOMETRY]) > 0 and int(seer["base_ranks"].get("acolyte_shadow_seal", 0)) > 0 and int(seer["base_ranks"].get("acolyte_votive_shield", 0)) > 0, "Vidente: Olhar, Geometria, Selo, Escudo, Revelação; Pupila and Devoção")

# --- Authority -------------------------------------------------------------------------

func _check_authority_from_origin() -> void:
	_setup()
	_check(kit != null and kit.get_script().resource_path == KIT_PATH and player.origin_kit != null, "the Cultista kit and the origin base are attached")
	_check(authority != null and authority == player.origin_kit.get("madness") and kit.get("madness") == null, "one authority, held by the origin; the Cultista keeps none")
	_check(authority != null and authority.ecstasy.enabled and is_equal_approx(authority.ecstasy.matk_per_charge, 0.05) and authority.stat_source_id == &"cultist_ecstasy", "the Êxtase passive (R3) turns the charges on at 5% per charge")

# --- Olhar do Abismo -------------------------------------------------------------------

func _check_gaze() -> void:
	_setup()
	var front := _mob(&"forest_wolf", Vector2(450, 350))
	var side := _mob(&"forest_boar", Vector2(440, 270)) # ~30° off the facing: inside 40°
	var behind := _mob(&"forest_wolf", Vector2(200, 350))
	var far := _mob(&"forest_boar", Vector2(560, 350)) # 260 away: outside the 200 cone
	var front_hits := _hits_on(front)
	var behind_hits := _hits_on(behind)
	var targets: Array = kit.call(&"gaze_targets", player)
	_check(front in targets and side in targets and behind not in targets and far not in targets, "the cone covers the front (200, 40°), not behind nor beyond reach")
	var sp_before := player.max_sp
	_check(_cast(GAZE), "Olhar do Abismo commits")
	_check(player.current_sp < sp_before and bool(kit.call(&"channeling")) and kit.call(&"snapshot_compact_blocker", player) == "cultist_channel", "it pays SP, channels and forces the exact snapshot")
	_check(front_hits.size() == 1 and behind_hits.is_empty() and is_equal_approx(MadnessAuthority.madness_of(front), 12.0), "first tick at commit: one hit and 12 Madness (R5)")
	_advance_for(2.1)
	_check(front_hits.size() == 5 and not bool(kit.call(&"channeling")), "five ticks over the 2 s channel, then it ends")
	_check(MadnessAuthority.madness_of(front) >= 59.0 and MadnessAuthority.madness_of(side) >= 59.0 and MadnessAuthority.madness_of(behind) == 0.0, "60 Madness per channel on each target in the cone")
	var total := 0.0
	for result: Dictionary in front_hits: total += float(result.get("actual_damage", 0.0))
	_check(total > 0.0 and String(front_hits[0].get("skill_id", "")) == String(GAZE), "continuous magic damage of the gaze lands")
	_check(not authority.add(front, 12.0, "gaze:%d:2" % int(kit.get("gaze_serial")), player)["ok"], "a tick event never gives Madness twice (retry)")
	# Movement interrupts the channel.
	_cast(GAZE)
	player.global_position += Vector2(40, 0)
	_advance(0.05)
	_check(not bool(kit.call(&"channeling")), "moving more than 24 interrupts the channel")
	player.global_position -= Vector2(40, 0)
	# Another skill interrupts it.
	_cast(GAZE)
	_check(bool(kit.call(&"channeling")), "channel restarted")
	_cast(&"acolyte_prayer")
	_check(not bool(kit.call(&"channeling")), "a base skill commit interrupts the channel")

# --- Êxtase ----------------------------------------------------------------------------

func _check_ecstasy() -> void:
	var ranks := _all_ranks()
	ranks[ECSTASY] = 0
	_setup(ranks)
	_check(authority != null and not authority.ecstasy.enabled, "without the passive the Êxtase stays off")
	var a := _mob(&"forest_wolf", Vector2(450, 350))
	authority.add(a, 100.0, "cast:e0", player)
	_check(authority.ecstasy.charges == 0, "no charge without the passive")
	_setup()
	var cost := player.base_skill_cost(GAZE)
	var mobs: Array[EnemyActor] = []
	for index: int in 3: mobs.append(_mob(&"forest_wolf", Vector2(450 + 30 * index, 500)))
	for index: int in 3: authority.add(mobs[index], 100.0, "cast:e%d" % index, player)
	_check(authority.ecstasy.charges == 3 and authority.ecstasy.has_onus(), "three Delirium entries give three charges and start the onus")
	_check(is_equal_approx(player.skill_cost(GAZE), cost * (1.0 - 0.15)), "SP cost -5%% per charge, applied once (%.3f vs %.3f)" % [player.skill_cost(GAZE), cost])
	var sources := player.temporary_stat_sources().filter(func(source: Dictionary) -> bool: return source.get("source_id") == &"cultist_ecstasy")
	_check(sources.size() == 1 and is_equal_approx(float(sources[0]["increased"][&"magic_attack"]), 0.15), "one MATK source of +15% (published once)")
	a = _mob(&"forest_boar", Vector2(450, 350))
	var hit := _taken(a, 100.0)
	_check(is_equal_approx(float(hit.get("kit_damage_multiplier", 1.0)), 1.08), "the onus multiplies damage taken by 1.08 at 3 charges, once")
	# Compensation by the base: Escudo Votivo absorbs, Prece heals.
	player.health.current_hp = player.health.max_hp
	_cast(&"acolyte_votive_shield")
	var shield := player.health.shield_hp
	var shielded := _taken(a, 50.0)
	_check(shield > 0.0 and float(shielded.get("absorbed_damage", 0.0)) > 0.0 and player.health.current_hp > player.health.max_hp - float(hit.get("actual_damage", 0.0)), "Escudo Votivo absorbs the multiplied hit")
	player.health.current_hp = player.health.max_hp * 0.5
	var hp := player.health.current_hp
	_cast(&"acolyte_prayer")
	_check(player.health.current_hp > hp, "Prece restores the HP the onus took")
	# Free the three Delirium slots (cap 3) so new entries can arrive.
	for mob: EnemyActor in mobs: authority._end_delirium(mob)
	for index: int in 4:
		var extra := _mob(&"forest_boar", Vector2(450 + 30 * index, 600))
		authority.add(extra, 100.0, "cast:ex%d" % index, player)
	_check(authority.ecstasy.charges == 5 and is_equal_approx(authority.ecstasy.damage_taken_multiplier(), 1.24), "charges cap at 5 (onus 1.24)")
	authority.ecstasy.charges = 2
	authority.sync_stats(player)
	_check(not authority.ecstasy.has_onus() and _taken(a, 10.0).get("kit_damage_multiplier", 1.0) == 1.0, "no onus below 3 charges")
	kit.on_build_changed(player)
	_check(authority.ecstasy.charges == 2, "build change neither recharges nor empties")

# --- Ídolo -----------------------------------------------------------------------------

func _check_idol() -> void:
	_setup()
	var wolf := _mob(&"forest_wolf", Vector2(520, 350))
	var boss := _boss(Vector2(480, 420))
	_check(_cast(IDOL, null, Vector2(480, 350)), "Ídolo Impossível commits at a point")
	var idol := authority.idol(player)
	_check(idol != null and is_equal_approx(idol.health.max_hp, player.health.max_hp * 0.45) and is_equal_approx(float(idol.get(&"remaining")), 10.0), "R5 Idol: 45% HP, 10 s")
	_check(wolf.combat_target() == idol and boss.combat_target() == player and not boss.has_target_override(), "commons attack the Idol; the boss never changes target")
	_advance_for(1.05)
	_check(MadnessAuthority.madness_of(wolf) >= 9.9 and MadnessAuthority.madness_of(boss) >= 9.9, "everyone gazing gains the tick Madness (10 at R5), boss included")
	_check(_cast(IDOL, null, Vector2(500, 300)) and authority.idols(player).size() == 1, "one Idol per owner: a new one replaces the old")

# --- Delírio Compartilhado ---------------------------------------------------------------

func _check_shared_delirium() -> void:
	_setup()
	var marked := _mob(&"forest_wolf", Vector2(450, 350))
	var near := _mob(&"forest_boar", Vector2(450, 430))
	var second := _mob(&"forest_wolf", Vector2(450, 520)) # near the neighbour, 170 from the marked
	var hits := _hits_on(marked)
	_check(_cast(SHARED, marked), "Delírio Compartilhado commits on a target")
	_check(marked.marks.has_mark(MadnessRules.MARK_CONTAGION) and hits.size() == 1, "the target is struck and marked")
	_check(is_equal_approx(MadnessAuthority.madness_of(marked), 35.0) and is_equal_approx(MadnessAuthority.madness_of(near), 21.0) and MadnessAuthority.madness_of(second) == 0.0, "35 Madness on the target, 60% copied to the neighbour, never a second hop")
	authority.add(marked, 65.0, "cast:shared_fill", player)
	_check(MadnessAuthority.state_of(marked) == MadnessRules.STATE_DELIRIUM and MadnessAuthority.madness_of(near) >= 21.0 + 39.0 + 40.0 - 0.01 or MadnessAuthority.state_of(near) == MadnessRules.STATE_DELIRIUM, "Delirium of the marked: share plus one pulse (40) on the neighbour")
	_check(MadnessAuthority.madness_of(second) == 0.0, "the pulse does not hop on (D4)")

# --- Delirium cap ---------------------------------------------------------------------

func _check_delirium_cap() -> void:
	_setup()
	var mobs: Array[EnemyActor] = []
	for index: int in 5: mobs.append(_mob(&"forest_wolf", Vector2(420 + 40 * index, 360)))
	_check(_cast(REVELATION), "Revelação commits")
	_advance_for(3.5)
	var delirious := 0
	var pending := 0
	for mob: EnemyActor in mobs:
		if MadnessAuthority.state_of(mob) == MadnessRules.STATE_DELIRIUM: delirious += 1
		elif MadnessAuthority.state_of(mob) == MadnessRules.STATE_PENDING: pending += 1
	_check(delirious == 3 and pending == 2 and authority.delirium_count(player) == 3, "at most 3 delirious per owner; the rest wait at the threshold (%d / %d)" % [delirious, pending])
	for mob: EnemyActor in mobs:
		if MadnessAuthority.state_of(mob) == MadnessRules.STATE_DELIRIUM: _check(mob.combat_target() != player and not MadnessHelpers.is_boss(mob.combat_target()), "a delirious enemy never targets the player nor a boss")

# --- Pupila Aberta ---------------------------------------------------------------------

func _check_pupil() -> void:
	_setup()
	var wolf := _mob(&"forest_wolf", Vector2(450, 350))
	var other := _mob(&"forest_boar", Vector2(480, 350))
	authority.add(wolf, 100.0, "cast:pupil", player)
	_advance(0.05)
	var source: Dictionary = wolf.received_damage_sources.get(&"cultist_open_pupil", {})
	_check(is_equal_approx(float(source.get("multiplier", 0.0)), 1.20) and int(source.get("owner_id", 0)) == player.get_instance_id(), "Pupila R3: ×1.20 on the delirious enemy, filtered by owner")
	_check(is_equal_approx(wolf.received_damage_multiplier(player.get_instance_id()), 1.20) and is_equal_approx(wolf.received_damage_multiplier(other.get_instance_id()), 1.0), "only the Cultista's damage is raised")
	_check(not other.received_damage_sources.has(&"cultist_open_pupil"), "not on a sane enemy")
	authority._end_delirium(wolf)
	_advance(0.05)
	_check(not wolf.received_damage_sources.has(&"cultist_open_pupil"), "the bonus leaves with the Delirium")

# --- Geometria Impossível -------------------------------------------------------------

func _check_geometry() -> void:
	_setup()
	var wolf := _mob(&"forest_wolf", Vector2(500, 350))
	var boss := _boss(Vector2(540, 360))
	var outside := _mob(&"forest_boar", Vector2(800, 350))
	_check(_cast(GEOMETRY, null, Vector2(520, 350)), "Geometria Impossível commits at a point")
	_check(wolf.is_disoriented() and is_equal_approx(MadnessAuthority.madness_of(wolf), 10.0), "a common inside loses its way and gains 10 Madness")
	_check(not boss.is_disoriented() and boss.slow_remaining > 0.0 and is_equal_approx(boss.slow_fraction, 0.40) and boss.combat_target() == player and not boss.has_target_override(), "the boss is only slowed, never disoriented nor retargeted")
	_check(not outside.is_disoriented() and MadnessAuthority.madness_of(outside) == 0.0, "nothing outside the figure")
	_check(kit.call(&"snapshot_compact_blocker", player) == "cultist_geometry", "the figure forces the exact snapshot")
	var madness_before := MadnessAuthority.madness_of(wolf)
	_advance_for(1.0)
	_check(MadnessAuthority.madness_of(wolf) <= madness_before + 0.001, "once per enemy per figure")
	_advance_for(3.2)
	_check(not bool(kit.call(&"geometry_active")), "the figure ends after 4 s")

# --- Revelação -------------------------------------------------------------------------

func _check_revelation() -> void:
	_setup()
	var boss := _boss(Vector2(420, 350))
	var minion := _mob(&"forest_wolf", Vector2(420, 420))
	var a := _mob(&"forest_boar", Vector2(500, 300))
	var b := _mob(&"forest_wolf", Vector2(540, 300))
	# The boss is already immune from an earlier window.
	authority.add(boss, 100.0, "cast:early", player)
	_advance_for(4.2)
	_check(MadnessAuthority.state_of(boss) == MadnessRules.STATE_IMMUNE, "the boss is immune after its first window")
	_check(_cast(REVELATION), "Revelação commits")
	_check(MadnessAuthority.state_of(boss) == MadnessRules.STATE_DISORIENTED and is_equal_approx(boss.marks.remaining(MadnessRules.MARK_IMMUNE), 6.0 + 20.0), "strong Disorientation even under immunity (6 s), then the longer immunity (20 s)")
	_check(is_equal_approx(float(boss.commit_deflections.get(MadnessRules.DISORIENT_SOURCE, {}).get("chance", 0.0)), 0.6) and is_equal_approx(boss.received_damage_multiplier(player.get_instance_id()), 1.4 * 1.2), "60% of its hits on minions; ×1.4 damage taken (and the Pupila)")
	_check(boss.combat_target() == player and not boss.has_target_override(), "the boss never changes target")
	var serial := int(kit.get("revelation_serial"))
	_check(authority.disorient(boss, "revelation:%d" % serial, player, {"bypass_immunity": true})["error_code"] == &"duplicate_event", "once per Revelação")
	# Minion hits: some of the boss's hits fall on the minion beside it.
	boss.player_target_acquired = true
	var on_minion := 0
	for attempt: int in 40:
		boss.attack_cooldown = 0.0
		attacks.clear()
		boss._try_attack(false)
		if attacks.size() == 1 and attacks[0][1] == minion: on_minion += 1
	_check(on_minion >= 12 and on_minion <= 36, "about 60%% of the boss hits land on the minion (%d of 40)" % on_minion)
	_advance_for(3.0)
	_check(MadnessAuthority.state_of(a) == MadnessRules.STATE_DELIRIUM and MadnessAuthority.state_of(b) == MadnessRules.STATE_DELIRIUM, "fast Madness: the commons reach Delirium inside the Revelação")
	var source: Dictionary = a.received_damage_sources.get(&"cultist_revelation", {})
	_check(is_equal_approx(float(source.get("multiplier", 0.0)), 1.60) and int(source.get("owner_id", 0)) == player.get_instance_id(), "delirious enemies take ×1.60 of the owner's damage, including each other's relayed hits")
	_check(kit.call(&"snapshot_compact_blocker", player) == "cultist_revelation", "the eye forces the exact snapshot")
	_advance_for(4.5)
	_check(not bool(kit.call(&"revelation_active")) and not a.received_damage_sources.has(&"cultist_revelation"), "the eye closes after 7 s and the bonus leaves")

# --- Base interactions -------------------------------------------------------------------

func _check_base_madness() -> void:
	_setup()
	var wolf := _mob(&"forest_wolf", Vector2(420, 350))
	_check(_cast(&"acolyte_shadow_seal", wolf) and is_equal_approx(MadnessAuthority.madness_of(wolf), 25.0), "Selo Sombrio adds Madness through the same authority")
	_check(_cast(&"acolyte_disturbing_whisper") and is_equal_approx(MadnessAuthority.madness_of(wolf), 50.0), "Sussurro sums on it")
	_check(_cast(GAZE), "then the gaze")
	_advance_for(2.1)
	_check(MadnessAuthority.state_of(wolf) == MadnessRules.STATE_DELIRIUM or MadnessAuthority.madness_of(wolf) >= 99.0, "base and kit Madness sum to the threshold")

# --- Delirium kill -----------------------------------------------------------------------

func _check_delirium_kill() -> void:
	_setup()
	var a := _mob(&"forest_wolf", Vector2(400, 300))
	var b := _mob(&"forest_boar", Vector2(440, 300), &"normal", 1.0)
	authority.add(a, 100.0, "cast:kill", player)
	a.attack_cooldown = 0.0
	attacks.clear()
	a._process(0.05)
	_check(attacks.size() == 1 and attacks[0][1] == b, "the delirious enemy commits on the other enemy")
	if attacks.size() != 1: return
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lethal: DamageRequest = attacks[0][0]
	lethal.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var kill := b.apply_damage(lethal, rng)
	_check(bool(kill.get("killed", false)) and EnemyActor.is_relay_result(kill) and controller._credited_kills.has(b.get_instance_id()), "the Delirium kill is the Cultista's")
	var credited := controller._credited_kills.size()
	controller._on_enemy_damage_resolved(kill)
	_check(b.apply_damage(lethal, rng).is_empty() and controller._credited_kills.size() == credited, "credited once, retry included")

# --- Death and pause -----------------------------------------------------------------------

func _check_death_and_pause() -> void:
	_setup()
	_mob(&"forest_wolf", Vector2(450, 350))
	_cast(GAZE)
	_cast(GEOMETRY, null, Vector2(450, 350))
	_cast(REVELATION)
	_check(bool(kit.call(&"geometry_active")) and bool(kit.call(&"revelation_active")), "figure and eye active")
	var remaining := float(kit.get("revelation_remaining"))
	paused = true
	# Pause: PlayerActor._process does not run on_tick; nothing advances.
	_check(is_equal_approx(float(kit.get("revelation_remaining")), remaining), "pause freezes the kit clocks")
	paused = false
	kit.on_death(player)
	_check(not bool(kit.call(&"channeling")) and not bool(kit.call(&"geometry_active")) and not bool(kit.call(&"revelation_active")) and kit.call(&"snapshot_compact_blocker", player) == "", "death ends channel, figure and eye")

# --- Snapshot ------------------------------------------------------------------------------

func _check_snapshot_formats() -> void:
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty(), "every fragment merges, cultist included: " + str(registry.fragment_errors))
	for path: String in [KIT_PATH, "res://scripts/classes/cultist/fixture/cultist_fixture_base.gd"]: _check(registry.schemas.has(path), "schema present for " + path)
	_setup()
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var standalone := _make_player(nav, _all_ranks())
	standalone.global_position = Vector2(400, 350)
	owned.append(standalone)
	var own_kit := standalone.kit
	var held := MadnessAuthority.of(standalone) as MadnessAuthority
	held.ecstasy.charges = 4
	own_kit.set("revelation_serial", 7)
	own_kit.set("gaze_serial", 3)
	own_kit.set("revelation_remaining", 2.5)
	own_kit.set("revelation_rank", 4)
	var barrier := SnapshotTickBarrier.new()
	paused = true
	_check(barrier.acquire(standalone)["ok"], "barrier acquired")
	var projection := {"fields": {}, "excluded": {}}
	var compact := SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(not compact.get("ok", false), "an active Revelação makes the compact cut ineligible")
	var captured := SnapshotRegistry.new().capture(standalone, barrier)
	_check(captured.get("ok", false), "exact capture of the Cultista: " + str(captured.get("detail", captured.get("error_code", ""))))
	if captured.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(captured["snapshot"])))
		_check(restored.get("ok", false), "exact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied := MadnessAuthority.of(copy) as MadnessAuthority
			_check(int(copy.kit.get("revelation_serial")) == 7 and int(copy.kit.get("gaze_serial")) == 3 and is_equal_approx(float(copy.kit.get("revelation_remaining")), 2.5) and int(copy.kit.get("revelation_rank")) == 4, "exact format preserves the kit serials and the eye clock")
			_check(copied != null and copied.ecstasy.charges == 4 and copy.kit.get("madness") == null, "the Êxtase comes back in the origin's single authority")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	own_kit.set("revelation_remaining", 0.0)
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("ok", false), "without channel, figure or eye the compact cut is accepted: " + str(compact.get("detail", compact.get("error_code", ""))))
	if compact.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(compact["snapshot"])))
		_check(restored.get("ok", false), "compact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			_check(int(copy.kit.get("revelation_serial")) == 7 and (MadnessAuthority.of(copy) as MadnessAuthority).ecstasy.charges == 4, "compact format preserves the serials and the Êxtase")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	barrier.release()
	paused = false
