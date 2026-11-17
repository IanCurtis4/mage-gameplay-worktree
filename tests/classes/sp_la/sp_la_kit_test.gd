extends SceneTree
## E09 K3 — Duelista (`sp_la`) kit invariants (docs/epics/e09/k3_contract.md):
## catalog data and readiness, the two review builds, the parry rules on the hit
## pipeline, the Leitura do Oponente sources (no Sentence duplication in retry),
## the Fatal Riposte execution (thresholds, boss, single kill callback), Finta,
## Guarda Paciente (reset by the basic attack, the base skills through the T1.2
## hook and the Riposte), Recuo em Guarda, Duelo, base interactions (Investida,
## Corte), build change without heal/reset, death, pause and both snapshot formats.
## The parry against real enemy AI attacks is in sp_la_parry_ai_test.gd.
## Fixture profiles only (no save on disk).
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const KIT_PATH := "res://scripts/classes/sp_la/sp_la_kit.gd"
const BUILDS_PATH := "res://scripts/classes/sp_la/review_builds.json"
const SKILLS: Array[StringName] = [&"duelist_parry", &"duelist_read_opponent", &"duelist_fatal_riposte", &"duelist_feint", &"duelist_patient_guard", &"duelist_guarded_retreat", &"duelist_duel"]
const PASSIVES: Array[StringName] = [&"duelist_read_opponent", &"duelist_patient_guard"]

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
	_check_parry_pipeline()
	_check_reading_sources()
	_check_riposte()
	_check_feint()
	_check_patient_guard()
	_check_retreat()
	_check_duel()
	_check_base_interactions()
	_check_build_change_death_and_pause()
	_check_snapshot_formats()
	_check_source_guards()
	_cleanup()
	print("E09 K3 sp_la kit: %d checks, %d failures" % [checks, failures])
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
	var ranks := {&"slash": 5, &"dash": 5, &"perseverance": 3}
	for skill: StringName in SKILLS:
		ranks[skill] = passive_rank if skill in PASSIVES else evolution_rank
	return ranks

func _make_player(navigation: ArenaNavigation, ranks: Dictionary) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"sp_la"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"sp_la")
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [&"duelist_parry", &"duelist_fatal_riposte", &"duelist_feint", &"duelist_guarded_retreat", &"duelist_duel"]
	var actor := PlayerActor.new()
	actor.configure(navigation, RunState.from_build("sp-la-" + str(checks), snapshot))
	return actor

func _setup(ranks: Dictionary = {}) -> void:
	_cleanup()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
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
	controller.rng.seed = 31
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

func _claw(source: CombatActor, amount: float = 30.0, skill: StringName = &"enemy_claw") -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = skill
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.context = player.run_state.effect_ledger.new_root(source.get_instance_id(), false, "", false, {})
	return request

func _cast(skill: StringName, enemy: CombatActor = null) -> bool:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp
	return player.use_kit_skill(skill, enemy.global_position if enemy != null else player.global_position, enemy)

func _tick(delta: float) -> void:
	player._process(delta)

## A basic attack through the kit composition and the RunController (claims, callbacks).
func _basic(target: CombatActor, amount: float = 20.0) -> DamageRequest:
	var origin := player.kit_make_request(target, &"basic_attack", amount, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var request := kit.compose_basic_attack(player, target, origin)
	controller._on_attack_requested(request, target)
	return request

## Parry `source` through the real hit pipeline (Aparo cast, frontal claw).
func _parry(source: CombatActor) -> Dictionary:
	_cast(&"duelist_parry")
	return player.apply_damage(_claw(source), controller.rng)

## Ends the forced turn and faces the enemy back to the Duelista (the sprite keeps the
## turned direction after the override until the enemy turns again, T6 §3).
func _unturn(enemy: CombatActor) -> void:
	enemy.clear_gameplay_facing_override()
	enemy.character_animation.state.face(Vector2.LEFT)

var _fills := 0

## Full Sentence on `target` through combo events with fresh keys (dedup is per key).
func _fill(target: CombatActor) -> void:
	flank.mark_victim(player, target)
	for index: int in 3:
		_fills += 1
		flank.gain(player, target, FlankRules.SOURCE_COMBO, "fill_%d" % _fills)

# --- Catalog ----------------------------------------------------------------------

func _check_catalog() -> void:
	var module := ClassKitRegistry.module(&"sp_la")
	_check(module != null and module.get_script().resource_path == KIT_PATH, "the production module is the sp_la kit")
	_check(ClassKitRegistry.validate(&"sp_la").get("ok", false), "registry validation passes: " + str(ClassKitRegistry.validate(&"sp_la")))
	_check(module.ready_for_play() and ClassKitRegistry.ready_for_play(&"sp_la"), "the kit is ready for play (A7)")
	_check(module.display_name() == "Duelista", "pt-BR identity name")
	var definitions := module.skill_definitions()
	var ids: Array[StringName] = []
	for definition: SkillDefinition in definitions: ids.append(definition.id)
	_check(ids == ClassKitRegistry.skill_ids(&"sp_la") and ids == SKILLS, "seven skills in the job order of C1")
	for index: int in definitions.size():
		var definition := definitions[index]
		var active: bool = ClassKitRegistry.SLOT_CATEGORIES[index] == &"active"
		_check(definition.handler_id == SkillDefinition.Handler.KIT and definition.is_rank_catalog_valid() and definition.ranks.size() == (5 if active else 3) and definition.element == &"physical", "%s: kit handler, ranks 1-%d, physical" % [definition.id, 5 if active else 3])
	var learning := module.learning_entries()
	_check(learning.size() == 7 and int(learning[0]["free_rank"]) == 1 and int(learning[0]["job_level"]) == 20 and int(learning[6]["job_level"]) == 37, "learning rows: free entry at job 20 through job 37")
	_check(learning[0]["skill_id"] == &"duelist_parry" and not learning[0].has("prerequisites"), "the entry skill has no prerequisites (A13)")
	var jobs: Array[int] = []
	for row: Dictionary in learning: jobs.append(int(row["job_level"]))
	_check(jobs == [20, 23, 25, 28, 31, 34, 37], "job levels of section 1")
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid(), "ProfileCatalog stays valid with the Duelista ready")
	var offered: Array[StringName] = []
	for evolution: EvolutionDefinition in catalog.evolution_definitions_for_origin(&"swordsman"): offered.append(evolution.id)
	_check(&"sp_la" in offered and catalog.evolution_definition(&"sp_la").affinity_class_id == &"rogue" and catalog.evolution_definition(&"sp_la").display_name == "Duelista", "ProfileCatalog offers the Duelista to the Espadachim with rogue affinity")
	var texts := module.skill_texts()
	for skill: StringName in ids:
		var text: Dictionary = texts.get(skill, {})
		var ranks: Array = text.get("ranks", [])
		_check(not String(text.get("effect", "")).is_empty() and not String(text.get("mechanics", "")).is_empty() and ranks.size() == (3 if skill in PASSIVES else 5), "%s has pt-BR effect and per-rank tooltip" % skill)
		for line: Variant in ranks: _check(not String(line).is_empty() and String(line).begins_with("R"), "%s rank tooltip line: %s" % [skill, line])
		_check(not ClassCatalog.skill_definition(skill).display_name.is_empty() and SkillPresentation.mechanics_of(skill) == String(text["mechanics"]) and not SkillCopy.text_for(skill).is_empty(), "%s reaches SkillPresentation/SkillCopy" % skill)
	var names: Array[String] = []
	for definition: SkillDefinition in definitions: names.append(definition.display_name)
	_check(names == ["Aparo", "Leitura do Oponente", "Riposte Fatal", "Finta", "Guarda Paciente", "Recuo em Guarda", "Duelo"], "pt-BR names of the sheet")
	var effects := module.vfx_effects()
	_check(effects.size() == 7, "seven reserved flipbook IDs")
	for effect_id: StringName in effects:
		_check(String(effect_id).begins_with("duelist_") and StringName(effects[effect_id]["skill_id"]) in SKILLS, "effect %s carries the prefix and a kit skill" % effect_id)
	var canvas := Node2D.new()
	root.add_child(canvas)
	owned.append(canvas)
	_check(not module.draw_vfx(&"duelist_unknown", canvas, {}, Vector2.ZERO, 0.5), "unknown effect is not drawn")
	_check(ClassKitRegistry.vfx_effect(&"duelist_parry", &"effect_start")["effect_id"] == &"duelist_parry_flash" and ClassKitRegistry.vfx_effect(&"duelist_fatal_riposte", &"impact")["effect_id"] == &"duelist_riposte_strike" and ClassKitRegistry.vfx_effect(&"duelist_duel", &"impact")["effect_id"] == &"duelist_duel_thrust", "effects reach the presentation catalog by skill and kind")
	for skill: StringName in ids: _check(not FeedbackRecipeCatalog.recipe(skill).is_empty(), "%s has a feedback recipe" % skill)
	_check(module.passive_modifier_source(&"duelist_read_opponent", 3).is_empty() and module.passive_modifier_source(&"duelist_patient_guard", 3).is_empty(), "the passives are kit rules, not permanent stat sources")

# --- Review builds (A11) -------------------------------------------------------------

func _check_review_builds() -> void:
	var file := FileAccess.open(BUILDS_PATH, FileAccess.READ)
	_check(file != null, "review_builds.json exists")
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary and parsed.get("schema") == "ragrpg_review_builds_v1" and parsed.get("identity_id") == "sp_la", "review builds schema and identity")
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
		_check(String(data.get("id", "")).begins_with("duelist_") and not String(data.get("name", "")).is_empty(), "build %s has id and pt-BR name" % data.get("id"))
		_check(base_points == 19 and catalog.skill_points_spent(purchased, ProfileCatalog.BASE_WALLET) == 19, "build %s spends the 19 base points" % data["id"])
		_check(evolution_points == 20 and rank_sum == 21 and catalog.skill_points_spent(purchased, ProfileCatalog.EVOLUTION_WALLET) == 20, "build %s spends the 20 evolution points (ranks sum 21 with the free R1)" % data["id"])
		var legal := catalog.validate_purchased_ranks(&"swordsman", &"sp_la", ProgressionRules.MAX_JOB_LEVEL, purchased)
		_check(legal.get("ok", false), "build %s is legal: %s" % [data["id"], legal])
		var shortcuts: Array = data.get("shortcuts", [])
		var known := true
		for skill: Variant in shortcuts: known = known and final_ranks.has(StringName(skill))
		_check(shortcuts.size() <= 24 and known and SKILLS.size() == data["evolution_ranks"].size(), "build %s shortcuts are learned skills (<= 24)" % data["id"])
		_check(final_ranks.has(&"dash") and final_ranks.has(&"slash"), "build %s keeps the Investida and the Corte of the sheet" % data["id"])
	_check(seen_ids.size() == 2 and seen_ids[0] != seen_ids[1], "two distinct builds")

# --- Parry rules on the hit pipeline ----------------------------------------------------

func _check_parry_pipeline() -> void:
	_setup()
	var front := _enemy(Vector2(440, 350))
	var behind := _enemy(Vector2(360, 350), 100000.0, Vector2.RIGHT)
	var flank_enemy := _enemy(Vector2(400, 395), 100000.0, Vector2.UP)
	var hp := player.health.current_hp
	# No window: the frontal claw lands.
	var result := player.apply_damage(_claw(front), controller.rng)
	_check(bool(result.get("landed", false)) and player.health.current_hp < hp, "without a window the frontal claw lands")
	hp = player.health.current_hp
	result = _parry(front)
	_check(bool(result.get("cancelled", false)) and result.get("cancel_reason") == &"flank_parry" and is_equal_approx(player.health.current_hp, hp), "Aparo cancels the whole frontal melee hit (reason flank_parry)")
	_check(int(kit.get("parry_serial")) == 1 and flank.victim(player) == front and flank.sentence(player) == 2, "parry: last parried is the victim, +2 Sentence")
	# The SP of the Aparo comes back on a parry through its window, not on a miss.
	player.current_sp = player.max_sp * 0.5
	var sp := player.current_sp
	player.mage_cooldowns[&"duelist_parry"] = 0.0
	player.use_kit_skill(&"duelist_parry", player.global_position)
	_check(is_equal_approx(player.current_sp, sp - 3.0) and is_equal_approx(float(kit.get("parry_refund")), 3.0), "Aparo R5 costs 3 SP, held for refund")
	front.clear_gameplay_facing_override()
	front.character_animation.state.face(Vector2.LEFT)
	player.apply_damage(_claw(front), controller.rng)
	_check(is_equal_approx(player.current_sp, sp) and is_zero_approx(float(kit.get("parry_refund"))), "a parry through the Aparo window refunds its SP")
	player.mage_cooldowns[&"duelist_parry"] = 0.0
	player.use_kit_skill(&"duelist_parry", player.global_position)
	for step: int in 9: _tick(0.05)
	_check(player.current_sp < sp - 1.5 and is_zero_approx(float(kit.get("parry_refund"))), "a window that closes without a parry refunds nothing")
	# Projectile, area, back, flank: never parried, the charge stays.
	_cast(&"duelist_parry")
	var arrow := _claw(front, 30.0, &"enemy_arrow")
	result = player.apply_damage(arrow, controller.rng)
	_check(not result.get("cancelled", false) and flank.parry_open(), "a frontal projectile is not parried")
	player.incoming_attack_event = {"kind": &"area", "attacker_id": front.get_instance_id()}
	result = player.apply_damage(_claw(front), controller.rng)
	player.incoming_attack_event = {}
	_check(not result.get("cancelled", false) and flank.parry_open(), "a frontal area hit is not parried")
	result = player.apply_damage(_claw(behind), controller.rng)
	_check(not result.get("cancelled", false) and flank.parry_open(), "a melee hit from behind is not parried")
	result = player.apply_damage(_claw(flank_enemy), controller.rng)
	_check(not result.get("cancelled", false) and flank.parry_open() and int(kit.get("parry_serial")) == 2, "a melee hit from the flank is not parried")
	# Window rank and expiry on the gameplay clock.
	_setup(_all_ranks(1, 1))
	kit.set("patience", 0.0)
	_check(_cast(&"duelist_parry") and is_equal_approx(flank.parry_remaining, 0.30), "Aparo R1 window 0.30 s")
	_check(is_equal_approx(player.skill_cooldown(&"duelist_parry"), 1.2) and is_equal_approx(player.base_skill_cost(&"duelist_parry"), 4.0), "Aparo R1: 4 SP, 1.2 s cooldown")
	for step: int in 7: _tick(0.05)
	_check(not flank.parry_open(), "the window closes after 0.30 s")
	var late := _enemy(Vector2(440, 350))
	result = player.apply_damage(_claw(late), controller.rng)
	_check(not result.get("cancelled", false), "after the window the claw lands")

# --- Leitura do Oponente -----------------------------------------------------------------

func _check_reading_sources() -> void:
	_setup()
	var victim := _enemy(Vector2(440, 350))
	_parry(victim)
	_check(flank.sentence(player) == 2, "aparo +2")
	# The parry turned the victim: the basic attack is from behind (+2) and gets the bonus.
	var request := _basic(victim)
	_check(FlankRules.flags_of(request.effect_snapshot).get("side") == &"back" and is_equal_approx(float(request.effect_snapshot.get("duelist_reading", 0.0)), 1.20), "basic attack from behind on the victim: Leitura R3 × 1.20")
	_check(flank.sentence(player) == 4, "golpe pelas costas +2")
	# Retry of the same confirmed result: no new Sentence.
	var hits := _hits_on(victim)
	_unturn(victim)
	request = _basic(victim)
	_check(FlankRules.flags_of(request.effect_snapshot).get("side") == &"front" and not request.effect_snapshot.has("duelist_reading"), "basic attack from the front: no Leitura bonus")
	_check(flank.sentence(player) == 5 and hits.size() == 1, "outro golpe +1, capped at 5")
	flank._set_sentence(victim, 3)
	kit.on_damage_dealt(player, hits[0])
	kit.on_damage_dealt(player, hits[0])
	_check(flank.sentence(player) == 3, "a retried result never adds Sentence again")
	# A fresh frontal hit: +1; a DoT result: nothing; a hit on a non-victim: nothing.
	_basic(victim)
	_check(flank.sentence(player) == 4, "a new frontal hit adds +1")
	var other := _enemy(Vector2(440, 380))
	_basic(other)
	_check(flank.sentence(player, other) == 0 and flank.sentence(player) == 4, "only the last parried accumulates")
	var dot := {"landed": true, "damage": 10, "secondary": true, "target_id": victim.get_instance_id(), "application_sequence": 999}
	kit.on_damage_dealt(player, dot)
	_check(flank.sentence(player) == 4, "a secondary (DoT) result adds nothing")
	# Parrying another enemy moves the victim: the old one loses its Sentence.
	_parry(other)
	_check(flank.victim(player) == other and flank.sentence(player) == 2 and flank.sentence(player, victim) == 0 and not victim.marks.has_mark(FlankRules.VICTIM_MARK), "the last parried becomes the victim; the previous one loses the mark")
	# Without the Leitura: the parry still marks, but nothing accumulates.
	var ranks := _all_ranks()
	ranks[&"duelist_read_opponent"] = 0
	ranks[&"duelist_fatal_riposte"] = 0
	_setup(ranks)
	victim = _enemy(Vector2(440, 350))
	_parry(victim)
	request = _basic(victim)
	_check(flank.victim(player) == victim and flank.sentence(player) == 0 and not request.effect_snapshot.has("duelist_reading"), "without the Leitura the parry marks the victim but no source counts")

# --- Riposte Fatal ---------------------------------------------------------------------------

func _check_riposte() -> void:
	_setup()
	var victim := _enemy(Vector2(440, 350))
	var hits := _hits_on(victim)
	_fill(victim)
	_check(flank.sentence(player) == 5, "full Sentence prepared")
	_check(_cast(&"duelist_fatal_riposte", victim) and hits.size() == 1, "Riposte commits on the victim")
	var flags := FlankRules.result_flags(hits[0])
	var atk := player.stat_breakdown.value(&"melee_attack")
	_check(bool(flags.get("execution", false)) and int(flags.get("charges", 0)) == 5 and not bool(flags.get("lethal", true)) and flank.sentence(player) == 0, "execution spends the 5 charges (not lethal at full HP)")
	_check(is_equal_approx(float(hits[0]["effect_snapshot"].get("duelist_reading", 1.0)), 1.0), "the Riposte from the front gets no Leitura bonus")
	_check(int(kit.get("parry_serial")) == 0 and is_zero_approx(float(kit.get("auto_parry_remaining"))), "a Riposte without a kill arms nothing")
	_check(not player.use_kit_skill(&"duelist_fatal_riposte", victim.global_position, victim), "the Riposte waits for its 6 s cooldown")
	_check(is_equal_approx(float(hits[0]["damage"]), 0.0) == false and atk > 0.0, "the Riposte deals damage from the melee ATK")
	# Lethal under the normal threshold (30%), refused above it.
	for category: StringName in [&"normal", &"rare", &"elite", &"rare_elite"]:
		_setup()
		var target := _hostile(Vector2(440, 350))
		target.occurrence.category_id = category
		var threshold := FlankRules.execution_threshold(category)
		target.health.current_hp = target.health.max_hp * (threshold + 0.03)
		_fill(target)
		_cast(&"duelist_fatal_riposte", target)
		_check(target.is_alive(), "%s above %d%%: no certain death" % [category, roundi(threshold * 100.0)])
		target.health.current_hp = target.health.max_hp * threshold
		player.kit_time += 1.0 # a new commit (the execution is spent once per commit key)
		_fill(target)
		var target_hits := _hits_on(target)
		_cast(&"duelist_fatal_riposte", target)
		_check(not target.is_alive() and target_hits.size() == 1 and bool(FlankRules.result_flags(target_hits[0]).get("lethal", false)), "%s at %d%% with 5 charges: certain death through DamageRequest" % [category, roundi(threshold * 100.0)])
		_check(is_equal_approx(float(kit.get("auto_parry_remaining")), 8.0), "%s: the Riposte kill arms the automatic parry" % category)
	# Boss: never certain death, only the scaled damage (A4).
	_setup()
	var boss := _hostile(Vector2(440, 350))
	boss.occurrence.category_id = &"boss"
	boss.hard_controls.boss = true
	boss.health.current_hp = boss.health.max_hp * 0.01
	_fill(boss)
	var boss_hits := _hits_on(boss)
	_cast(&"duelist_fatal_riposte", boss)
	_check(boss.is_alive() and boss_hits.size() == 1 and not bool(FlankRules.result_flags(boss_hits[0]).get("lethal", true)) and int(flank.lethal_total) == 0, "boss at 1% with 5 charges: no certain death, only damage")
	# Single kill callback, also in retry.
	_setup()
	var doomed := _enemy(Vector2(440, 350), 1000.0)
	doomed.health.current_hp = 200.0
	_fill(doomed)
	var doomed_hits := _hits_on(doomed)
	_cast(&"duelist_fatal_riposte", doomed)
	_check(not doomed.is_alive() and int(flank.execution_kills) == 1, "the Riposte kills the doomed victim")
	kit.set("auto_parry_remaining", 0.0)
	kit.on_kill_confirmed(player, doomed_hits[0])
	kit.on_kill_confirmed(player, doomed_hits[0])
	_check(is_zero_approx(float(kit.get("auto_parry_remaining"))) and int(flank.execution_kills) == 1, "a retried kill callback does not arm the automatic parry again")
	# A common kill (not the Riposte) arms nothing.
	_setup()
	var common := _enemy(Vector2(440, 350), 10.0)
	_basic(common, 500.0)
	_check(not common.is_alive() and is_zero_approx(float(kit.get("auto_parry_remaining"))), "a basic-attack kill does not arm the automatic parry")

# --- Finta -------------------------------------------------------------------------------------

func _check_feint() -> void:
	_setup()
	var target := _enemy(Vector2(440, 350))
	var other := _enemy(Vector2(440, 380))
	var start := player.global_position
	_check(_cast(&"duelist_feint", target) and target.marks.owner_of(&"duelist_feint") == player.get_instance_id(), "Finta marks the target")
	_check(is_equal_approx(start.distance_to(player.global_position), 48.0), "Finta side step of 48 px")
	var result := player.apply_damage(_claw(other), controller.rng)
	_check(not result.get("cancelled", false) and target.marks.has_mark(&"duelist_feint"), "another enemy's strike is not parried by the Finta")
	result = player.apply_damage(_claw(target, 30.0, &"enemy_arrow"), controller.rng)
	_check(not result.get("cancelled", false) and target.marks.has_mark(&"duelist_feint"), "the feinted enemy's arrow is not parried")
	result = player.apply_damage(_claw(target), controller.rng)
	_check(result.get("cancel_reason") == &"duelist_feint" and not target.marks.has_mark(&"duelist_feint") and flank.victim(player) == target and flank.sentence(player) == 2, "the next melee strike of the feinted enemy is parried (+2, victim)")
	# The mark expires on the gameplay clock.
	_setup(_all_ranks(1, 1))
	target = _enemy(Vector2(440, 350))
	_cast(&"duelist_feint", target)
	_check(is_equal_approx(target.marks.remaining(&"duelist_feint"), 2.5), "Finta R1 lasts 2.5 s")
	target.advance_statuses(2.6)
	_check(not target.marks.has_mark(&"duelist_feint"), "the Finta expires")
	# Out of range: refused.
	var far := _enemy(Vector2(700, 350))
	_check(not _cast(&"duelist_feint", far), "Finta out of range (220) is refused")
	# Blocked on the left: the step goes to the right; blocked on both sides: no step.
	_cleanup()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(380, 280, 40, 30)], 20.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	player = _make_player(navigation, _all_ranks())
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(400, 350)
	player.character_animation.state.face(Vector2.RIGHT)
	controller.player = player
	controller.run_state = player.run_state
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	kit = player.kit
	flank = kit.get("flank")
	target = _enemy(Vector2(440, 350))
	_check(_cast(&"duelist_feint", target) and player.global_position.distance_to(Vector2(400, 398)) < 0.01, "blocked on one side, the Finta steps to the other")

# --- Guarda Paciente ---------------------------------------------------------------------------

func _check_patient_guard() -> void:
	_setup()
	var enemy := _enemy(Vector2(440, 350))
	kit.set("patience", 0.0)
	for step: int in 39: _tick(0.05)
	_check(not kit.call(&"patient", player) and is_equal_approx(float(kit.call(&"parry_window", player)), 0.38), "under 2 s: base window")
	_tick(0.05)
	_check(kit.call(&"patient", player) and is_equal_approx(float(kit.call(&"parry_window", player)), 0.56), "2 s without attacking (R3): window 0.56 s")
	# Defensive kit casts and parries do not reset the patience.
	_parry(enemy)
	_cast(&"duelist_feint", enemy)
	_cast(&"duelist_guarded_retreat")
	_check(kit.call(&"patient", player), "Aparo, aparo, Finta and Recuo are not attacking")
	# Basic attack resets.
	_basic(enemy)
	_check(is_zero_approx(float(kit.get("patience"))), "the basic attack resets the patience")
	# Base skills reset through the T1.2 commit hook: Corte and Investida.
	kit.set("patience", 5.0)
	var foes: Array[CombatActor] = [enemy]
	player.slash_cooldown = 0.0
	player.current_sp = player.max_sp
	_check(player.use_slash(Vector2.RIGHT, foes) and is_zero_approx(float(kit.get("patience"))), "Corte (base) resets the patience")
	kit.set("patience", 5.0)
	player.dash_cooldown = 0.0
	_check(player.use_dash(Vector2.RIGHT) and is_zero_approx(float(kit.get("patience"))), "Investida (base) resets the patience")
	# A refused base cast does not reach the hook.
	kit.set("patience", 5.0)
	player.dash_cooldown = 3.0
	_check(not player.use_dash(Vector2.RIGHT) and is_equal_approx(float(kit.get("patience")), 5.0), "a refused Investida does not reset the patience")
	# The Riposte commit resets.
	kit.set("patience", 5.0)
	player.global_position = enemy.global_position + Vector2(-40, 0)
	_cast(&"duelist_fatal_riposte", enemy)
	_check(is_zero_approx(float(kit.get("patience"))), "the Riposte resets the patience")
	# R1 delay 3 s and bonus +0.10; without the passive nothing changes.
	_setup(_all_ranks(1, 1))
	kit.set("patience", 2.9)
	_check(not kit.call(&"patient", player), "R1 needs 3 s")
	kit.set("patience", 3.0)
	_check(is_equal_approx(float(kit.call(&"parry_window", player)), 0.40), "R1: 0.30 + 0.10")
	var ranks := _all_ranks()
	ranks[&"duelist_patient_guard"] = 0
	_setup(ranks)
	kit.set("patience", 30.0)
	_check(not kit.call(&"patient", player) and is_equal_approx(float(kit.call(&"parry_window", player)), 0.38), "without the passive the window is the Aparo's")

# --- Recuo em Guarda -----------------------------------------------------------------------------

func _check_retreat() -> void:
	_setup()
	var near := _hostile(Vector2(460, 350))
	var far := _hostile(Vector2(620, 350))
	kit.set("patience", 0.0)
	_check(_cast(&"duelist_guarded_retreat") and player.global_position.distance_to(Vector2(320, 350)) < 0.01, "Recuo steps 80 px back, keeping the facing")
	_check(is_equal_approx(player.gameplay_facing().x, 1.0), "the guard (facing) is kept")
	var near_id := near.threat_id_for(player)
	_check(near.threat.sight_broken(near_id) and is_equal_approx(near.threat.sight_break_remaining(near_id), 2.0), "an enemy within 180 of the start loses sight (R5 2.0 s)")
	_check(not far.threat.sight_broken(far.threat_id_for(player)), "an enemy beyond 180 keeps sight")
	_check(flank.parry_open() and is_equal_approx(flank.parry_remaining, 0.38), "the Recuo opens the parry window")
	# Boss: sight break × 0.6.
	_setup()
	var boss := _hostile(Vector2(460, 350))
	boss.occurrence.category_id = &"boss"
	boss.hard_controls.boss = true
	_cast(&"duelist_guarded_retreat")
	_check(is_equal_approx(boss.threat.sight_break_remaining(boss.threat_id_for(player)), 1.2), "boss: sight break × 0.6")
	# Map edge: the step shortens to a walkable fraction.
	_setup()
	player.global_position = Vector2(70, 350)
	_cast(&"duelist_guarded_retreat")
	_check(controller.navigation.is_walkable(player.global_position), "the Recuo never leaves the walkable arena")
	_check(player.global_position.x < 70.0 and player.global_position.x > 20.0, "near the edge the Recuo uses a shorter step (%s)" % player.global_position)
	# Limitation 1 of T6 (flat arena): a near enemy still acquires by position.
	_setup()
	near = _hostile(Vector2(460, 350))
	_cast(&"duelist_guarded_retreat")
	_check(near.threat.sight_broken(near.threat_id_for(player)) and player.can_be_acquired_by(near.global_position), "flat arena: the sight break acts on the threat only (T6 limitation 1)")

# --- Duelo ------------------------------------------------------------------------------------

func _check_duel() -> void:
	_setup()
	var front := _enemy(Vector2(440, 350))
	var behind := _enemy(Vector2(360, 350), 100000.0, Vector2.RIGHT)
	var hits := _hits_on(front)
	_check(_cast(&"duelist_duel") and flank.parry_charges == FlankRules.UNLIMITED_CHARGES and is_equal_approx(flank.parry_remaining, 6.0), "Duelo opens the unlimited parry mode for 6 s")
	var hp := player.health.current_hp
	for strike: int in 3:
		front.clear_gameplay_facing_override()
		player.apply_damage(_claw(front), controller.rng)
	_check(is_equal_approx(player.health.current_hp, hp) and int(kit.get("parry_serial")) == 3 and hits.size() == 3, "three frontal strikes: three parries and three thrusts")
	var atk := player.stat_breakdown.value(&"melee_attack")
	_check(hits[0]["skill_id"] == &"duelist_duel" and FlankRules.result_flags(hits[0]).get("side") == &"back" and is_equal_approx(float(hits[0]["effect_snapshot"].get("duelist_reading", 0.0)), 1.20), "each thrust is a kit request from behind with the Leitura bonus")
	_check(flank.sentence(player) == 5 and atk > 0.0, "parry +2 and thrust +2 per exchange, capped at 5")
	var result := player.apply_damage(_claw(behind), controller.rng)
	_check(not result.get("cancelled", false) and player.health.current_hp < hp, "the Duelo does not parry from behind")
	_check(not _cast(&"duelist_parry"), "Aparo refused in the Duelo (duelist_duel_active)")
	_cast(&"duelist_guarded_retreat")
	_check(flank.parry_charges == FlankRules.UNLIMITED_CHARGES, "a Recuo in the Duelo keeps the unlimited mode")
	for step: int in 130: _tick(0.05)
	_check(not kit.call(&"duel_active") and not flank.parry_open(), "the Duelo ends")
	_check(_cast(&"duelist_parry"), "after the Duelo the Aparo is available again")

# --- Base interactions ---------------------------------------------------------------------------

func _check_base_interactions() -> void:
	_setup()
	var victim := _enemy(Vector2(450, 350))
	var other := _enemy(Vector2(450, 380))
	_parry(victim)
	_check(FlankRules.side_between(victim, player)["side"] == &"back", "the parried victim shows its back")
	var foes: Array[CombatActor] = [victim, other]
	var hits := _hits_on(victim)
	var other_hits := _hits_on(other)
	player.slash_cooldown = 0.0
	player.current_sp = player.max_sp
	_check(player.use_slash(Vector2.RIGHT, foes) and hits.size() == 1 and other_hits.size() == 1, "Corte hits both enemies in the cone")
	_check(FlankRules.result_flags(hits[0]).is_empty() and flank.sentence(player) == 4, "Corte (base, unmarked) on the turned victim: +2 from behind, read on the result")
	_check(flank.sentence(player, other) == 0, "the Corte on another enemy adds nothing")
	kit.on_damage_dealt(player, hits[0])
	_check(flank.sentence(player) == 4, "a retried Corte result adds nothing")
	_unturn(victim)
	player.slash_cooldown = 0.0
	player.current_sp = player.max_sp
	var slashed := player.use_slash(Vector2.RIGHT, foes)
	_check(slashed and hits.size() == 2 and FlankRules.side_between(victim, player)["side"] == &"front", "second Corte from the front lands (%s, %d hits, %s)" % [slashed, hits.size(), hits[-1].get("landed")])
	_check(flank.sentence(player) == 5, "Corte from the front on the victim: +1 (%d)" % flank.sentence(player))
	# Investida enters the Riposte range.
	_setup()
	var landing := player.dash_destination(Vector2.RIGHT)
	var target := _enemy(landing + Vector2(60, 0))
	_check(landing.x > player.global_position.x + 60.0, "the Investida covers ground (%s)" % landing)
	_check(not player.can_target_skill(&"duelist_fatal_riposte", target), "before the Investida the Riposte is out of range")
	player.dash_cooldown = 0.0
	player.current_sp = player.max_sp
	_check(player.use_dash(Vector2.RIGHT), "Investida commits")
	for step: int in 8: _tick(0.05)
	_check(player.can_target_skill(&"duelist_fatal_riposte", target), "after the Investida the Riposte reaches the target (%s)" % player.global_position)

# --- Build change, death, pause ------------------------------------------------------------

func _check_build_change_death_and_pause() -> void:
	_setup()
	var victim := _enemy(Vector2(440, 350))
	_parry(victim)
	_cast(&"duelist_duel")
	kit.set("auto_parry_remaining", 5.0)
	kit.set("patience", 1.5)
	player.health.current_hp = player.health.max_hp * 0.4
	player.current_sp = player.max_sp * 0.3
	player.mage_cooldowns[&"duelist_fatal_riposte"] = 3.0
	var hp := player.health.current_hp
	var sp := player.current_sp
	var duel := float(kit.get("duel_remaining"))
	var window := flank.parry_remaining
	player.apply_run_modifiers(player.run_state)
	_check(is_equal_approx(player.health.current_hp, hp) and is_equal_approx(player.current_sp, sp) and is_equal_approx(player.skill_cooldown(&"duelist_fatal_riposte"), 3.0), "build change: no heal, no SP refill, no cooldown reset")
	_check(player.kit == kit and flank.sentence(player) == 2 and flank.victim(player) == victim and is_equal_approx(float(kit.get("duel_remaining")), duel) and is_equal_approx(flank.parry_remaining, window) and is_equal_approx(float(kit.get("auto_parry_remaining")), 5.0) and is_equal_approx(float(kit.get("patience")), 1.5), "build change: no reset of Sentence, victim, Duelo, window, automatic parry or patience")
	paused = true
	_tick(1.0)
	_check(is_equal_approx(float(kit.get("duel_remaining")), duel) and is_equal_approx(flank.parry_remaining, window) and is_equal_approx(float(kit.get("patience")), 1.5) and is_equal_approx(float(kit.get("auto_parry_remaining")), 5.0), "pause freezes every kit clock")
	paused = false
	var feinted := _enemy(Vector2(440, 380))
	_cast(&"duelist_feint", feinted)
	player.health.current_hp = 1.0
	var behind := _enemy(Vector2(360, 350), 100000.0, Vector2.RIGHT)
	player.apply_damage(_claw(behind, 100000.0), controller.rng)
	_check(not player.is_alive(), "the Duelista dies from behind")
	_check(not kit.call(&"duel_active") and not flank.parry_open() and is_zero_approx(float(kit.get("auto_parry_remaining"))) and is_zero_approx(float(kit.get("patience"))), "death: Duelo, window, automatic parry and patience end")
	_check(not victim.marks.has_mark(FlankRules.VICTIM_MARK) and not feinted.marks.has_mark(&"duelist_feint"), "death: the victim mark and the Fintas are removed")

# --- Snapshot formats -----------------------------------------------------------------------

func _check_snapshot_formats() -> void:
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty() and registry.schemas.has(KIT_PATH), "the sp_la fragment merges: " + str(registry.fragment_errors))
	if registry.schemas.has(KIT_PATH):
		var fields: Array = registry.schemas[KIT_PATH].get("fields", [])
		_check(fields == ["flank", "patience", "duel_remaining", "auto_parry_remaining", "parry_serial", "parry_refund"] and int(registry.schemas[KIT_PATH].get("revision", 0)) == 2, "the kit lists its six fields (revision 2)")
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
	standalone_flank.open_parry_mode(standalone, 4.0)
	enemy.marks.set_mark(&"duelist_feint", standalone.get_instance_id(), 1, 2.0)
	standalone_kit.set("duel_remaining", 4.0)
	standalone_kit.set("auto_parry_remaining", 6.5)
	standalone_kit.set("patience", 2.25)
	standalone_kit.set("parry_serial", 7)
	standalone.kit_time = 11.0
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(standalone)["ok"], "barrier acquired")
	var captured := SnapshotRegistry.new().capture(standalone, barrier)
	_check(captured.get("ok", false), "exact capture with victim, Duelo and Finta: " + str(captured.get("detail", captured.get("error_code", ""))))
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
			_check(copied != null and copied.parry_charges == FlankRules.UNLIMITED_CHARGES and is_equal_approx(copied.parry_remaining, 4.0), "exact format keeps the parry mode")
			_check(copied_kit != null and is_equal_approx(float(copied_kit.get("duel_remaining")), 4.0) and is_equal_approx(float(copied_kit.get("auto_parry_remaining")), 6.5) and is_equal_approx(float(copied_kit.get("patience")), 2.25) and int(copied_kit.get("parry_serial")) == 7 and is_equal_approx(copy.kit_time, 11.0), "exact format keeps the Duelo, the automatic parry, the patience and the serial")
			_check(copied_enemy != null and copied_enemy.marks.owner_of(&"duelist_feint") == copy.get_instance_id(), "exact format keeps the Finta with the enemy, owner rebound")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	_check(standalone.kit_compact_blocker().is_empty(), "the Duelista never blocks the compact cut")
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
			_check(is_equal_approx(float(copied_kit.get("duel_remaining")), 4.0) and is_equal_approx(float(copied_kit.get("auto_parry_remaining")), 6.5) and is_equal_approx(float(copied_kit.get("patience")), 2.25) and int(copied_kit.get("parry_serial")) == 7 and is_equal_approx(copied.parry_remaining, 4.0), "compact format keeps the player state (Duelo, window, automatic parry, patience)")
			_check(copied.victim(copy) == null and copied.sentence(copy) == 0, "compact format: the enemy returns without marks, so no victim (A5)")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	barrier.release()

# --- Source guards ------------------------------------------------------------------------------

func _check_source_guards() -> void:
	var source := FileAccess.get_file_as_string(KIT_PATH)
	_check(not source.is_empty() and not source.contains("current_hp =") and not source.contains("current_hp -="), "the kit never writes HP directly")
	_check(not source.contains("KIT_RULE"), "no item KIT_RULE (A10)")
	var requests := source.count("kit_make_request(")
	var marks := source.count("_mark(player, request") + source.count("_apply_reading(player, executed")
	_check(requests == 1 and marks >= 1, "every kit request goes through flank.mark_request (thrust via _mark, Riposte via execute)")
