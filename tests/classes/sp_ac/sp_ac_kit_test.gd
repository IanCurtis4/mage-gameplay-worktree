extends SceneTree
## E09 K1 — Paladino (`sp_ac`) kit invariants (docs/epics/e09/k1_contract.md):
## catalog data and readiness, the two review builds, Oath cone and Grace sources,
## no Grace duplication in retry, Consecrated Impact spending, Égide, Fé Inabalável,
## Selo, Hora do Juramento, base interactions (Parede de Escudos, Perseverança,
## Provocar), build change without heal/reset, death, pause and both snapshot formats.
## Fixture profiles only (no save on disk).
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const KIT_PATH := "res://scripts/classes/sp_ac/sp_ac_kit.gd"
const BUILDS_PATH := "res://scripts/classes/sp_ac/review_builds.json"

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var kit: ClassKit
var authority: SanctuaryAuthority

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
	_check_oath_and_frontal_grace()
	_check_excess_heal_and_guard_grace()
	_check_impact_spend()
	_check_aegis()
	_check_faith()
	_check_seal_and_base_interactions()
	_check_hour()
	_check_build_change_death_and_pause()
	_check_snapshot_formats()
	_cleanup()
	print("E09 K1 sp_ac kit: %d checks, %d failures" % [checks, failures])
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
	var ranks := {&"shield_wall": 5, &"perseverance": 3, &"provoke": 3, &"slash": 3}
	for skill: StringName in ClassKitRegistry.skill_ids(&"sp_ac"):
		ranks[skill] = passive_rank if skill in [&"paladin_guard_grace", &"paladin_unshaken_faith"] else evolution_rank
	return ranks

func _make_player(navigation: ArenaNavigation, ranks: Dictionary) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"sp_ac"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"sp_ac")
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [&"paladin_oath", &"paladin_consecrated_impact", &"paladin_oath_aegis", &"paladin_condemned_seal", &"paladin_oath_hour"]
	var actor := PlayerActor.new()
	actor.configure(navigation, RunState.from_build("sp-ac-" + str(checks), snapshot))
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
	controller.rng.seed = 23
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	kit = player.kit
	authority = kit.get("sanctuary") if kit != null else null

func _enemy(at: Vector2, hp: float = 100000.0) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	controller.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position = at
	enemy.health.max_hp = hp
	enemy.health.current_hp = hp
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(enemy)
	return enemy

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
	return player.use_kit_skill(skill, enemy.global_position if enemy != null else player.global_position, enemy)

func _tick(delta: float) -> void:
	player._process(delta)

func _grace() -> int:
	return authority.grace.charges

# --- Catalog ----------------------------------------------------------------------

func _check_catalog() -> void:
	var module := ClassKitRegistry.module(&"sp_ac")
	_check(module != null and module.get_script().resource_path == KIT_PATH, "the production module is the sp_ac kit")
	_check(ClassKitRegistry.validate(&"sp_ac").get("ok", false), "registry validation passes: " + str(ClassKitRegistry.validate(&"sp_ac")))
	_check(module.ready_for_play() and ClassKitRegistry.ready_for_play(&"sp_ac"), "the kit is ready for play (A7)")
	var definitions := module.skill_definitions()
	var ids: Array[StringName] = []
	for definition: SkillDefinition in definitions: ids.append(definition.id)
	_check(ids == ClassKitRegistry.skill_ids(&"sp_ac"), "seven skills in the job order of C1")
	for index: int in definitions.size():
		var definition := definitions[index]
		var active: bool = ClassKitRegistry.SLOT_CATEGORIES[index] == &"active"
		_check(definition.handler_id == SkillDefinition.Handler.KIT and definition.is_rank_catalog_valid() and definition.ranks.size() == (5 if active else 3) and definition.element == &"light", "%s: kit handler, ranks 1-%d, light" % [definition.id, 5 if active else 3])
	var learning := module.learning_entries()
	_check(learning.size() == 7 and int(learning[0]["free_rank"]) == 1 and int(learning[0]["job_level"]) == 20 and int(learning[6]["job_level"]) == 37, "learning rows: free entry at job 20 through job 37")
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid(), "ProfileCatalog stays valid with the Paladino ready")
	var offered: Array[StringName] = []
	for evolution: EvolutionDefinition in catalog.evolution_definitions_for_origin(&"swordsman"): offered.append(evolution.id)
	_check(&"sp_ac" in offered and catalog.evolution_definition(&"sp_ac").affinity_class_id == &"acolyte", "ProfileCatalog offers the Paladino to the Espadachim with acolyte affinity")
	var texts := module.skill_texts()
	for skill: StringName in ids:
		var text: Dictionary = texts.get(skill, {})
		var ranks: Array = text.get("ranks", [])
		_check(not String(text.get("effect", "")).is_empty() and not String(text.get("mechanics", "")).is_empty() and ranks.size() == (3 if skill in [&"paladin_guard_grace", &"paladin_unshaken_faith"] else 5), "%s has pt-BR name, effect and per-rank tooltip" % skill)
		for line: Variant in ranks: _check(not String(line).is_empty() and String(line).begins_with("R"), "%s rank tooltip line: %s" % [skill, line])
		_check(not ClassCatalog.skill_definition(skill).display_name.is_empty() and SkillPresentation.mechanics_of(skill) == String(text["mechanics"]), "%s reaches SkillPresentation" % skill)
	var effects := module.vfx_effects()
	_check(effects.size() == 8, "eight reserved flipbook IDs")
	for effect_id: StringName in effects:
		_check(String(effect_id).begins_with("paladin_"), "effect %s carries the prefix" % effect_id)
	var canvas := Node2D.new()
	root.add_child(canvas)
	owned.append(canvas)
	_check(not module.draw_vfx(&"paladin_unknown", canvas, {}, Vector2.ZERO, 0.5), "unknown effect is not drawn")
	_check(not FeedbackRecipeCatalog.recipe(&"paladin_oath").is_empty() and ClassKitRegistry.vfx_effect(&"paladin_consecrated_impact", &"impact")["effect_id"] == &"paladin_impact_column", "recipes and effects reach the presentation catalogs")
	_check(module.passive_modifier_source(&"paladin_guard_grace", 3).get("increased", {}).get(&"physical_defense", 0.0) == 0.10 and module.passive_modifier_source(&"paladin_unshaken_faith", 1).is_empty(), "Graça de Guarda is a passive DEF source; Fé has no permanent source")

# --- Review builds (A11) -------------------------------------------------------------

func _check_review_builds() -> void:
	var file := FileAccess.open(BUILDS_PATH, FileAccess.READ)
	_check(file != null, "review_builds.json exists")
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary and parsed.get("schema") == "ragrpg_review_builds_v1" and parsed.get("identity_id") == "sp_ac", "review builds schema and identity")
	if not parsed is Dictionary: return
	var builds: Array = parsed.get("builds", [])
	_check(builds.size() == 2, "exactly two named builds")
	var catalog := ProfileCatalog.pilot()
	for build: Variant in builds:
		var data: Dictionary = build
		var purchased: Dictionary[StringName, int] = {}
		var base_points := 0
		var evolution_points := 0
		var final_ranks := {}
		for skill: Variant in data["base_ranks"]:
			purchased[StringName(skill)] = int(data["base_ranks"][skill])
			base_points += int(data["base_ranks"][skill])
			final_ranks[StringName(skill)] = int(data["base_ranks"][skill])
		for skill: Variant in data["evolution_ranks"]:
			var free := int(catalog.skill_metadata(StringName(skill)).get("free_rank", 0))
			purchased[StringName(skill)] = int(data["evolution_ranks"][skill]) - free
			evolution_points += int(data["evolution_ranks"][skill]) - free
			final_ranks[StringName(skill)] = int(data["evolution_ranks"][skill])
		_check(not String(data.get("id", "")).is_empty() and not String(data.get("name", "")).is_empty(), "build %s has id and pt-BR name" % data.get("id"))
		_check(base_points == 19 and catalog.skill_points_spent(purchased, ProfileCatalog.BASE_WALLET) == 19, "build %s spends the 19 base points" % data["id"])
		_check(evolution_points == 20 and catalog.skill_points_spent(purchased, ProfileCatalog.EVOLUTION_WALLET) == 20, "build %s spends the 20 evolution points" % data["id"])
		var legal := catalog.validate_purchased_ranks(&"swordsman", &"sp_ac", ProgressionRules.MAX_JOB_LEVEL, purchased)
		_check(legal.get("ok", false), "build %s is legal: %s" % [data["id"], legal])
		var shortcuts: Array = data.get("shortcuts", [])
		var known := true
		for skill: Variant in shortcuts: known = known and final_ranks.has(StringName(skill))
		_check(shortcuts.size() <= 24 and known and ClassKitRegistry.skill_ids(&"sp_ac").size() == data["evolution_ranks"].size(), "build %s shortcuts are learned skills (<= 24)" % data["id"])

# --- Oath cone and frontal Grace ------------------------------------------------------

func _check_oath_and_frontal_grace() -> void:
	_setup()
	var front := _enemy(Vector2(520, 350))
	var behind := _enemy(Vector2(300, 350))
	var front_hits := _hits_on(front)
	_check(_cast(&"paladin_oath"), "Juramento commits")
	var cone := authority.zone(&"oath")
	_check(cone != null and cone.shape == &"cone" and cone.anchor_mode == &"owner" and is_equal_approx(cone.radius, 170.0) and is_equal_approx(cone.duration, 8.0) and is_equal_approx(cone.half_angle, deg_to_rad(55.0)), "R5 cone: radius 170, 8 s, 55°")
	if cone == null: return
	_check(is_equal_approx(cone.rules["owner_damage_taken"], 0.74) and is_equal_approx(cone.rules["burn_ratio"], 0.20) and cone.rules["burn_stat"] == &"melee_attack" and is_equal_approx(cone.prototype.magic_damage, player.stat_breakdown.value(&"melee_attack") * 0.20), "R5 rules: ×0.74 frontal, burn 20% of melee ATK as light magic")
	_check(cone.contains(player, front) and not cone.contains(player, behind), "cone in front of the shield only")
	# Frontal hit: reduced by the cone and +1 Grace.
	var before := _grace()
	var result := player.apply_damage(_enemy_request(front, 40.0), controller.rng)
	_check(is_equal_approx(float(result.get("kit_damage_multiplier", 1.0)), 0.74) and _grace() == before + 1, "frontal hit inside the cone: ×0.74 and +1 Grace")
	# Retry of the same result never pays again (event identity of the ledger).
	kit.after_hit_mitigation(player, {"frontal": true, "facing_dot": 1.0, "request": _enemy_request(front, 1.0), "paladin_stance": false}, result)
	kit.after_hit_mitigation(player, {"frontal": true, "facing_dot": 1.0, "request": _enemy_request(front, 1.0), "paladin_stance": false}, result)
	_check(_grace() == before + 1, "a retried hit result does not add Grace twice")
	# Back hit: not reduced, no Grace (the Paladino's weakness).
	var back := player.apply_damage(_enemy_request(behind, 40.0), controller.rng)
	_check(not back.has("kit_damage_multiplier") and _grace() == before + 1, "hit from behind: no reduction, no Grace")
	_check(not player.use_kit_skill(&"paladin_oath", player.global_position), "a second Oath waits for the cooldown")
	# The burn pulse hits the enemy in the cone as light, through DamageRequest.
	for step: int in 4: _tick(0.25)
	_check(front_hits.size() == 1 and bool(front_hits[0]["secondary"]) and front_hits[0]["skill_id"] == &"paladin_oath" and float(front_hits[0]["actual_damage"]) > 0.0, "the cone burns the enemy in front once per second")
	# R1 numbers.
	_setup(_all_ranks(1, 1))
	_check(_cast(&"paladin_oath"), "R1 Juramento commits")
	var small := authority.zone(&"oath")
	_check(small != null and is_equal_approx(small.radius, 150.0) and is_equal_approx(small.duration, 6.0) and is_equal_approx(small.rules["owner_damage_taken"], 0.82) and is_equal_approx(small.rules["burn_ratio"], 0.12) and is_equal_approx(player.skill_cost(&"paladin_oath"), 20.0), "R1 cone: radius 150, 6 s, ×0.82, burn 12%, 20 SP")

# --- Excess heal and Graça de Guarda -----------------------------------------------------

func _check_excess_heal_and_guard_grace() -> void:
	_setup()
	_check(is_equal_approx(authority.grace.excess_fraction, 0.05), "Graça de Guarda R3: 1 charge per 5% of max HP of excess")
	player.health.current_hp = player.health.max_hp
	var before := _grace()
	player.heal_player(player.health.max_hp * 0.11, &"test_heal")
	_check(_grace() == before + 2, "an 11% excess heal yields 2 charges at 5%")
	player.health.current_hp = player.health.max_hp * 0.5
	player.heal_player(player.health.max_hp * 0.2, &"test_heal")
	_check(_grace() == before + 2, "a heal without excess yields no Grace")
	# Shield Wall stance: a frontal hit outside any zone yields Grace with the passive.
	var front := _enemy(Vector2(470, 350))
	player.current_sp = player.max_sp
	_check(player.use_shield_wall(Vector2.RIGHT) and player.has_shield_stance(), "Parede de Escudos raised")
	authority.grace.charges = 0
	player.apply_damage(_enemy_request(front, 30.0), controller.rng)
	_check(_grace() == 1, "frontal hit on the raised Parede de Escudos yields Grace (Graça de Guarda)")
	var no_passive := _all_ranks()
	no_passive[&"paladin_guard_grace"] = 0
	_setup(no_passive)
	_check(is_equal_approx(authority.grace.excess_fraction, SanctuaryRules.GRACE_EXCESS_FRACTION), "without the passive, the excess fraction is the T5 default (8%)")
	var other := _enemy(Vector2(470, 350))
	player.current_sp = player.max_sp
	player.use_shield_wall(Vector2.RIGHT)
	player.apply_damage(_enemy_request(other, 30.0), controller.rng)
	_check(_grace() == 0, "without Graça de Guarda the stance alone yields no hit Grace")

# --- Consecrated Impact ---------------------------------------------------------------

func _check_impact_spend() -> void:
	_setup()
	var target := _enemy(Vector2(480, 350))
	var near := _enemy(Vector2(480, 380))
	var far := _enemy(Vector2(480, 520))
	var hits := _hits_on(target)
	var near_hits := _hits_on(near)
	var far_hits := _hits_on(far)
	_check(_cast(&"paladin_consecrated_impact", target), "Impacto with 0 Grace still strikes (base damage)")
	var base_damage := float(hits[0]["damage"]) if not hits.is_empty() else 0.0
	_check(hits.size() == 1 and hits[0]["skill_id"] == &"paladin_consecrated_impact" and float(hits[0]["actual_damage"]) > 0.0 and int(kit.get("impact_charges")) == 0, "Impacto hits the target as light damage")
	_check(near_hits.size() == 1 and far_hits.is_empty(), "the column (radius 55) also hits a neighbour but not a far enemy")
	authority.grace.charges = 5
	hits.clear()
	player.kit_time += 1.0
	_check(_cast(&"paladin_consecrated_impact", target) and _grace() == 0 and int(kit.get("impact_charges")) == 5, "Impacto spends 5 charges at commit")
	_check(hits.size() == 1 and float(hits[0]["damage"]) >= base_damage * 2.0, "5 charges multiply the column damage (x3 before the flat defense)")
	authority.grace.begin_unlimited(5.0)
	authority.grace.charges = 7
	player.kit_time += 1.0
	_check(_cast(&"paladin_consecrated_impact", target) and _grace() == 2 and int(kit.get("impact_charges")) == 5, "at most 5 charges per Impacto; the rest carry over")
	# Atomic with the commit: a refused cast (cooldown) spends nothing.
	authority.grace.charges = 3
	player.mage_cooldowns[&"paladin_consecrated_impact"] = 2.0
	_check(not player.use_kit_skill(&"paladin_consecrated_impact", target.global_position, target) and _grace() == 3, "a refused Impacto never spends Grace")
	var sp_before := player.current_sp
	_ready_cast(&"paladin_consecrated_impact")
	sp_before = player.current_sp
	player.use_kit_skill(&"paladin_consecrated_impact", target.global_position, target)
	_check(is_equal_approx(sp_before - player.current_sp, 26.0), "R5 Impacto costs 26 SP outside the Hora")

# --- Égide -------------------------------------------------------------------------

func _check_aegis() -> void:
	_setup()
	var enemy := _enemy(Vector2(460, 350))
	var hits := _hits_on(enemy)
	_check(_cast(&"paladin_oath_aegis"), "Égide commits")
	var expected := StatCalculator.personal_shield_capacity(110.0, player.stat_breakdown)
	_check(is_equal_approx(player.health.shield_hp, expected) and authority.aegis_active(), "R5 Égide shield = Perseverança formula with base 110")
	player.health.max_hp = 100000.0
	player.health.current_hp = 100000.0
	var big := _enemy_request(enemy, expected * 50.0)
	player.apply_damage(big, controller.rng)
	_check(authority.aegis_pulses == 1 and hits.size() == 1 and hits[0]["skill_id"] == &"paladin_oath_aegis" and float(hits[0]["actual_damage"]) > 0.0, "breaking the Égide releases one light pulse")
	for step: int in 30: _tick(0.25)
	_check(authority.aegis_pulses == 1 and hits.size() == 1, "no second pulse at expiry after a break")

# --- Fé Inabalável ---------------------------------------------------------------------

func _check_faith() -> void:
	_setup()
	var cc_before := player.stat_breakdown.value(&"magic_cc_resistance")
	var hp_before := player.health.current_hp
	_check(_cast(&"paladin_oath"), "Juramento for Fé")
	_check(is_equal_approx(float(kit.get("faith_applied")), 0.20) and is_equal_approx(player.stat_breakdown.value(&"magic_cc_resistance"), minf(cc_before + 0.20, 0.5)) and player.health.current_hp == hp_before, "Fé R3 inside the Oath: +0.20 CC resistance, no heal from the recomposition")
	var zone := authority.zone(&"oath")
	_check(zone != null and is_equal_approx(zone.rules["heal_multiplier"], 1.30), "Fé R3 sets the zone heal multiplier to 1.30")
	var stun := player.apply_stun(2.0)
	_check(stun < 2.0 and stun > 0.0, "controls last less inside the Oath (stun %.2f s)" % stun)
	player.health.current_hp = 1.0
	player.heal_player(50.0, &"test_heal")
	_check(is_equal_approx(player.health.current_hp - 1.0, 65.0), "heal inside the Oath yields ×1.30: %.2f" % (player.health.current_hp - 1.0))
	authority.end_zone(&"oath", player)
	_tick(0.05)
	_check(is_equal_approx(float(kit.get("faith_applied")), 0.0) and is_equal_approx(player.stat_breakdown.value(&"magic_cc_resistance"), cc_before), "leaving the Oath removes Fé")
	var no_faith := _all_ranks()
	no_faith[&"paladin_unshaken_faith"] = 0
	_setup(no_faith)
	_cast(&"paladin_oath")
	_check(is_equal_approx(authority.zone(&"oath").rules["heal_multiplier"], 1.0) and is_equal_approx(float(kit.get("faith_applied")), 0.0), "without Fé the Oath does not boost heals")

# --- Selo and base interactions --------------------------------------------------------

func _check_seal_and_base_interactions() -> void:
	_setup()
	var target := _enemy(Vector2(480, 350))
	_check(_cast(&"paladin_condemned_seal", target), "Selo commits")
	_check(authority.is_sealed(target) and int(target.marks.value(&"paladin_seal", 0)) == 1 and is_equal_approx(target.marks.remaining(&"paladin_seal"), 7.0), "R5 Selo: mark with value 1 for 7 s")
	var before := _grace()
	player.kit_time += 1.0
	_cast(&"paladin_consecrated_impact", target)
	_check(_grace() == before + 1, "light damage on the sealed target yields Grace = seal value (1)")
	# Provocar adds to the seal (cooldown watch on the next tick).
	_tick(0.01)
	player.current_sp = player.max_sp
	_check(player.use_provoke(target), "Provocar commits")
	_tick(0.01)
	_check(int(target.marks.value(&"paladin_seal", 0)) == 2, "Provocar with an active seal adds 1 to the seal")
	player.mage_cooldowns[&"provoke"] = 0.0
	_tick(0.01)
	player.current_sp = player.max_sp
	player.use_provoke(target)
	_tick(0.01)
	player.mage_cooldowns[&"provoke"] = 0.0
	_tick(0.01)
	player.current_sp = player.max_sp
	player.use_provoke(target)
	_tick(0.01)
	_check(int(target.marks.value(&"paladin_seal", 0)) == 3, "the seal value stops at 3")
	before = _grace()
	player.kit_time += 1.0
	player.mage_cooldowns[&"paladin_consecrated_impact"] = 0.0
	_cast(&"paladin_consecrated_impact", target)
	_check(_grace() == before + 3 - int(kit.get("impact_charges")), "light damage on a seal of value 3 yields 3 Grace")
	# Parede de Escudos and Perseverança fill Grace once per use.
	authority.grace.charges = 0
	player.current_sp = player.max_sp
	player.use_shield_wall(Vector2.RIGHT)
	_tick(0.01)
	_tick(0.01)
	_check(_grace() == 1, "Parede de Escudos yields +1 Grace once")
	player.current_sp = player.max_sp
	player.use_perseverance()
	_tick(0.01)
	_tick(0.01)
	_check(_grace() == 2, "Perseverança yields +1 Grace once")
	player.use_shield_wall(Vector2.RIGHT) # lowering the stance spends nothing
	_tick(0.01)
	_check(_grace() == 2, "lowering the Parede (no payment) yields nothing")

# --- Hora do Juramento ------------------------------------------------------------------

func _check_hour() -> void:
	_setup()
	var front := _enemy(Vector2(480, 350))
	var behind := _enemy(Vector2(320, 350))
	var behind_hits := _hits_on(behind)
	_check(_cast(&"paladin_oath"), "Juramento before the Hora")
	var zone := authority.zone(&"oath")
	var remaining := zone.remaining
	_check(_cast(&"paladin_oath_hour"), "Hora commits")
	_check(kit.call(&"hour_active") and zone == authority.zone(&"oath") and zone.shape == &"circle" and zone.remaining == remaining and not bool(kit.get("hour_opened_zone")), "with a long enough Oath, the cone becomes a circle without restarting clocks")
	_check(authority.grace.is_unlimited(), "Grace has no cap during the Hora")
	_check(not _cast(&"paladin_oath"), "Juramento is refused during the Hora")
	# Hits from behind are reduced and pay Grace in the circle.
	authority.grace.charges = 5
	var back := player.apply_damage(_enemy_request(behind, 40.0), controller.rng)
	_check(is_equal_approx(float(back.get("kit_damage_multiplier", 1.0)), 0.74) and _grace() == 6, "in the circle a hit from behind is reduced and Grace passes 5")
	# Impacto: no net SP and the column covers the whole circle.
	_ready_cast(&"paladin_consecrated_impact")
	var sp_before := player.current_sp
	player.kit_time += 1.0
	_check(player.use_kit_skill(&"paladin_consecrated_impact", front.global_position, front) and is_equal_approx(player.current_sp, sp_before), "Impacto costs no SP during the Hora")
	_check(behind_hits.size() == 1 and behind_hits[0]["skill_id"] == &"paladin_consecrated_impact", "the column falls on the whole circle (enemy behind hit)")
	paused = true
	var hour_before := float(kit.get("hour_remaining"))
	_tick(1.0)
	_check(float(kit.get("hour_remaining")) == hour_before, "pause freezes the Hora")
	paused = false
	for step: int in 40: _tick(0.25)
	_check(not kit.call(&"hour_active") and authority.zone(&"oath") == null and _grace() <= 5 and not authority.grace.is_unlimited(), "the Hora ends: Grace back to the cap")
	# Without an Oath: the Hora opens its own circle and ends it.
	_setup()
	_check(_cast(&"paladin_oath_hour"), "Hora without Juramento")
	var opened := authority.zone(&"oath")
	_check(opened != null and opened.shape == &"circle" and is_equal_approx(opened.radius, 170.0) and is_equal_approx(opened.duration, 8.0) and bool(kit.get("hour_opened_zone")), "the Hora opens an owner circle (170) for its duration")
	for step: int in 34: _tick(0.25)
	_check(not kit.call(&"hour_active") and authority.zone(&"oath") == null, "the Hora's own circle ends with it")
	# A short Oath left when the Hora starts: the Hora replaces it with its circle.
	_setup()
	_cast(&"paladin_oath")
	for step: int in 20: _tick(0.25)
	_cast(&"paladin_oath_hour")
	_check(bool(kit.get("hour_opened_zone")) and authority.zone(&"oath").shape == &"circle" and is_equal_approx(authority.zone(&"oath").remaining, 8.0), "a short Oath is replaced by the Hora circle")
	# An Oath that outlives the Hora returns to a cone.
	_setup(_all_ranks(5, 3))
	_cast(&"paladin_oath")
	var long_zone := authority.zone(&"oath")
	long_zone.remaining = 14.0
	_cast(&"paladin_oath_hour")
	for step: int in 33: _tick(0.25)
	_check(not kit.call(&"hour_active") and authority.zone(&"oath") != null and authority.zone(&"oath").shape == &"cone", "after the Hora a surviving Oath is a cone again")

# --- Build change, death, pause ------------------------------------------------------------

func _check_build_change_death_and_pause() -> void:
	_setup()
	_cast(&"paladin_oath")
	authority.grace.charges = 4
	player.health.current_hp = player.health.max_hp * 0.4
	player.current_sp = player.max_sp * 0.3
	var hp := player.health.current_hp
	var sp := player.current_sp
	var impact_cd := 3.0
	player.mage_cooldowns[&"paladin_consecrated_impact"] = impact_cd
	var zone := authority.zone(&"oath")
	var remaining := zone.remaining
	player.apply_run_modifiers(player.run_state)
	_check(_grace() == 4 and is_equal_approx(player.health.current_hp, hp) and is_equal_approx(player.current_sp, sp) and is_equal_approx(player.skill_cooldown(&"paladin_consecrated_impact"), impact_cd) and authority.zone(&"oath") == zone and zone.remaining == remaining, "build change: no heal, no SP refill, no Grace reset, no cooldown reset, zone kept")
	paused = true
	_tick(1.0)
	_check(zone.remaining == remaining and _grace() == 4, "pause freezes the zone and Grace")
	paused = false
	var enemy := _enemy(Vector2(480, 350))
	_cast(&"paladin_condemned_seal", enemy)
	_cast(&"paladin_oath_hour")
	player.health.current_hp = 1.0
	player.apply_damage(_enemy_request(enemy, 100000.0), controller.rng)
	_check(not player.is_alive() and _grace() == 0 and not kit.call(&"hour_active") and authority.zone(&"oath") == null and not authority.is_sealed(enemy) and is_equal_approx(float(kit.get("faith_applied")), 0.0), "death: Grace zero, Hora, zone, seal and Fé end")

# --- Snapshot formats -----------------------------------------------------------------------

func _check_snapshot_formats() -> void:
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty() and registry.schemas.has(KIT_PATH), "the sp_ac fragment merges: " + str(registry.fragment_errors))
	_check("sanctuary" in registry.schemas[KIT_PATH].get("fields", []) if registry.schemas.has(KIT_PATH) and registry.schemas[KIT_PATH] is Dictionary else true, "the kit lists the sanctuary field")
	_setup()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var standalone := _make_player(navigation, _all_ranks())
	standalone.global_position = Vector2(400, 350)
	owned.append(standalone)
	var standalone_kit := standalone.kit
	var standalone_authority: SanctuaryAuthority = standalone_kit.get("sanctuary")
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = Vector2(480, 350)
	enemy.health.max_hp = 1000.0
	enemy.health.current_hp = 1000.0
	standalone.add_child(enemy)
	var cast := {"skill_id": &"paladin_oath", "rank": 5, "element": &"light", "world": false, "anchor": null, "point": standalone.global_position, "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": [enemy]}
	standalone_kit.resolve_cast(standalone, cast)
	cast["skill_id"] = &"paladin_oath_hour"
	standalone_kit.resolve_cast(standalone, cast)
	standalone_authority.grace.charges = 7
	standalone_authority.seal(standalone, enemy, &"paladin_seal", 4.0, 2)
	standalone_kit.set("base_cooldowns", {&"shield_wall": 3.5, &"perseverance": 0.0, &"provoke": 1.25})
	standalone.kit_time = 9.0
	var hour := float(standalone_kit.get("hour_remaining"))
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(standalone)["ok"], "barrier acquired")
	var captured := SnapshotRegistry.new().capture(standalone, barrier)
	_check(captured.get("ok", false), "exact capture with zone, Hora and seal: " + str(captured.get("detail", captured.get("error_code", ""))))
	if captured.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(captured["snapshot"])))
		_check(restored.get("ok", false), "exact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied_kit := copy.kit
			var copied: SanctuaryAuthority = copied_kit.get("sanctuary") if copied_kit != null else null
			var copied_enemy: CombatActor = null
			for child: Node in copy.get_children():
				if child is CombatActor: copied_enemy = child
			_check(copied != null and copied.zone(&"oath") != null and copied.zone(&"oath").shape == &"circle" and copied.grace.charges == 7 and copied.grace.is_unlimited(), "exact format keeps the circle and the unlimited Grace")
			_check(copied_kit != null and is_equal_approx(float(copied_kit.get("hour_remaining")), hour) and not bool(copied_kit.get("hour_opened_zone")) and is_equal_approx(float(copied_kit.get("faith_applied")), float(standalone_kit.get("faith_applied"))) and is_equal_approx(float(copied_kit.get("base_cooldowns")[&"provoke"]), 1.25), "exact format keeps the Hora clock, Fé and the base watch")
			_check(copied != null and copied_enemy != null and copied.is_sealed(copied_enemy) and int(copied_enemy.marks.value(&"paladin_seal", 0)) == 2, "exact format keeps the seal with the restored enemy")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	var projection := {"fields": {}, "excluded": {}}
	var compact := SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and compact.get("detail") == "paladin_hour", "the Hora makes the compact cut ineligible")
	standalone_kit.set("hour_remaining", 0.0)
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and String(compact.get("detail", "")).begins_with("sanctuary_zone"), "an active zone keeps the exact format")
	standalone_authority.end_zone(&"oath")
	enemy.marks.clear()
	standalone_kit.set("faith_applied", 0.0)
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("ok", false), "without zone, seal or Hora the compact cut is accepted: " + str(compact.get("detail", compact.get("error_code", ""))))
	if compact.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(compact["snapshot"])))
		_check(restored.get("ok", false), "compact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied: SanctuaryAuthority = copy.kit.get("sanctuary")
			_check(copied != null and copied.grace.charges == 7 and copied.grace.is_unlimited() and copied.zones.is_empty() and is_equal_approx(float(copy.kit.get("base_cooldowns")[&"shield_wall"]), 3.5), "compact format keeps Grace, the unlimited mode and the base watch on the player")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	barrier.release()
