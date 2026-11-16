extends SceneTree
## E09 K2 — Taumaturgo (`mg_ac`) kit invariants (docs/epics/e09/k2_contract.md):
## catalog data and readiness, the two review builds, Círculo Votivo element from the
## first spell inside, alternation Grace (Prisma) without duplication in retry, the
## weakness outside the circle, element rules (fire, ice DEF, lightning SP), Refração,
## Mudança de Altar, Coro tricolor, Juízo in three pulses, Aurora (wide tricolor circle,
## unlimited Grace, half SP through skill_cost, pure), base interactions (Bola de Fogo,
## Lança de Gelo, Relâmpago, Barreira Fantasma), build change without heal/reset, death,
## pause and both snapshot formats. Fixture profiles only (no save on disk).
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const KIT_PATH := "res://scripts/classes/mg_ac/mg_ac_kit.gd"
const BUILDS_PATH := "res://scripts/classes/mg_ac/review_builds.json"
const CIRCLE := &"thaumaturge_votive_circle"
const PRISM := &"thaumaturge_votive_prism"
const REFRACTION := &"thaumaturge_healing_refraction"
const ALTAR := &"thaumaturge_altar_shift"
const CHOIR := &"thaumaturge_elemental_choir"
const JUDGMENT := &"thaumaturge_prismatic_judgment"
const DAWN := &"thaumaturge_convergent_dawn"

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
	_check_circle_and_alternation()
	_check_element_rules()
	_check_refraction()
	_check_altar()
	_check_choir()
	_check_judgment()
	_check_dawn()
	_check_build_change_death_and_pause()
	_check_snapshot_formats()
	_cleanup()
	print("E09 K2 mg_ac kit: %d checks, %d failures" % [checks, failures])
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
	var ranks := {&"fireball": 3, &"ice_spear": 3, &"lightning": 3, &"phantom_barrier": 2, &"teleport": 1}
	for skill: StringName in ClassKitRegistry.skill_ids(&"mg_ac"):
		ranks[skill] = passive_rank if skill in [PRISM, CHOIR] else evolution_rank
	return ranks

func _make_player(navigation: ArenaNavigation, ranks: Dictionary) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ac"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"mg_ac")
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [CIRCLE, REFRACTION, ALTAR, JUDGMENT, DAWN]
	var actor := PlayerActor.new()
	actor.configure(navigation, RunState.from_build("mg-ac-" + str(checks), snapshot))
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
	controller.rng.seed = 29
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

func _ready_cast(skill: StringName) -> void:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp

func _cast(skill: StringName, enemy: CombatActor = null) -> bool:
	_ready_cast(skill)
	return player.use_kit_skill(skill, enemy.global_position if enemy != null else player.global_position, enemy)

## A base spell as RunController._execute_skill commits it (entry note + handler).
func _spell(skill: StringName, enemy: CombatActor = null) -> bool:
	_ready_cast(skill)
	player.kit_time += 0.01
	var point := enemy.global_position if enemy != null else player.global_position + Vector2.RIGHT * 100.0
	player.note_base_commit(skill, point, enemy)
	var used := false
	match skill:
		&"fireball": used = player.use_fireball(Vector2.RIGHT)
		&"ice_spear", &"fire_spear": used = player.use_spear(skill, enemy)
		&"lightning": used = player.use_lightning(enemy)
		&"phantom_barrier": used = player.use_phantom_barrier(Vector2.RIGHT)
		&"teleport": used = player.use_teleport(point)
	player.clear_base_commit_note()
	return used

func _tick(delta: float) -> void:
	player._process(delta)

func _grace() -> int:
	return authority.grace.charges

func _zone() -> SanctuaryZone:
	return authority.zone(&"votive")

# --- Catalog ----------------------------------------------------------------------

func _check_catalog() -> void:
	var module := ClassKitRegistry.module(&"mg_ac")
	_check(module != null and module.get_script().resource_path == KIT_PATH, "the production module is the mg_ac kit")
	_check(ClassKitRegistry.validate(&"mg_ac").get("ok", false), "registry validation passes: " + str(ClassKitRegistry.validate(&"mg_ac")))
	_check(module.ready_for_play() and ClassKitRegistry.ready_for_play(&"mg_ac"), "the kit is ready for play (A7)")
	var definitions := module.skill_definitions()
	var ids: Array[StringName] = []
	for definition: SkillDefinition in definitions: ids.append(definition.id)
	_check(ids == ClassKitRegistry.skill_ids(&"mg_ac"), "seven skills in the job order of C1")
	for index: int in definitions.size():
		var definition := definitions[index]
		var active: bool = ClassKitRegistry.SLOT_CATEGORIES[index] == &"active"
		_check(definition.handler_id == SkillDefinition.Handler.KIT and definition.is_rank_catalog_valid() and definition.ranks.size() == (5 if active else 3) and definition.element == &"light", "%s: kit handler, ranks 1-%d, light (A2)" % [definition.id, 5 if active else 3])
	var learning := module.learning_entries()
	_check(learning.size() == 7 and int(learning[0]["free_rank"]) == 1 and int(learning[0]["job_level"]) == 20 and int(learning[6]["job_level"]) == 37, "learning rows: free entry at job 20 through job 37")
	_check(not learning[0].has("prerequisites") or (learning[0]["prerequisites"] as Dictionary).is_empty(), "the job 20 entry has no prerequisites (A13)")
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid(), "ProfileCatalog stays valid with the Taumaturgo ready")
	var offered: Array[StringName] = []
	for evolution: EvolutionDefinition in catalog.evolution_definitions_for_origin(&"mage"): offered.append(evolution.id)
	_check(&"mg_ac" in offered and catalog.evolution_definition(&"mg_ac").affinity_class_id == &"acolyte", "ProfileCatalog offers the Taumaturgo to the Mago with acolyte affinity")
	var texts := module.skill_texts()
	for skill: StringName in ids:
		var text: Dictionary = texts.get(skill, {})
		var ranks: Array = text.get("ranks", [])
		_check(not String(text.get("effect", "")).is_empty() and not String(text.get("mechanics", "")).is_empty() and ranks.size() == (3 if skill in [PRISM, CHOIR] else 5), "%s has pt-BR name, effect and per-rank tooltip" % skill)
		for line: Variant in ranks: _check(not String(line).is_empty() and String(line).begins_with("R"), "%s rank tooltip line: %s" % [skill, line])
		_check(not ClassCatalog.skill_definition(skill).display_name.is_empty() and SkillPresentation.mechanics_of(skill) == String(text["mechanics"]), "%s reaches SkillPresentation" % skill)
	var effects := module.vfx_effects()
	_check(effects.size() == 9, "nine reserved flipbook IDs")
	var canvas := Node2D.new()
	root.add_child(canvas)
	owned.append(canvas)
	for effect_id: StringName in effects:
		_check(String(effect_id).begins_with("thaumaturge_"), "effect %s carries the prefix" % effect_id)
	_check(not module.draw_vfx(&"thaumaturge_unknown", canvas, {}, Vector2.ZERO, 0.5), "unknown effect is not drawn")
	_check(not FeedbackRecipeCatalog.recipe(CIRCLE).is_empty() and ClassKitRegistry.vfx_effect(JUDGMENT, &"impact")["effect_id"] == &"thaumaturge_judgment_column", "recipes and effects reach the presentation catalogs")
	_check(is_equal_approx(module.passive_modifier_source(PRISM, 3).get("increased", {}).get(&"magic_attack", 0.0), 0.09) and module.passive_modifier_source(CHOIR, 1).is_empty(), "Prisma Votivo is a passive magic ATK source; Coro has no permanent source")

# --- Review builds (A11) -------------------------------------------------------------

func _check_review_builds() -> void:
	var file := FileAccess.open(BUILDS_PATH, FileAccess.READ)
	_check(file != null, "review_builds.json exists")
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary and parsed.get("schema") == "ragrpg_review_builds_v1" and parsed.get("identity_id") == "mg_ac", "review builds schema and identity")
	if not parsed is Dictionary: return
	var builds: Array = parsed.get("builds", [])
	_check(builds.size() == 2, "exactly two named builds")
	var catalog := ProfileCatalog.pilot()
	for build: Variant in builds:
		var data: Dictionary = build
		var purchased: Dictionary[StringName, int] = {}
		var base_points := 0
		var evolution_points := 0
		var evolution_rank_sum := 0
		var final_ranks := {}
		for skill: Variant in data["base_ranks"]:
			purchased[StringName(skill)] = int(data["base_ranks"][skill])
			base_points += int(data["base_ranks"][skill])
			final_ranks[StringName(skill)] = int(data["base_ranks"][skill])
		for skill: Variant in data["evolution_ranks"]:
			var free := int(catalog.skill_metadata(StringName(skill)).get("free_rank", 0))
			purchased[StringName(skill)] = int(data["evolution_ranks"][skill]) - free
			evolution_points += int(data["evolution_ranks"][skill]) - free
			evolution_rank_sum += int(data["evolution_ranks"][skill])
			final_ranks[StringName(skill)] = int(data["evolution_ranks"][skill])
		_check(not String(data.get("id", "")).is_empty() and not String(data.get("name", "")).is_empty(), "build %s has id and pt-BR name" % data.get("id"))
		_check(base_points == 19 and catalog.skill_points_spent(purchased, ProfileCatalog.BASE_WALLET) == 19, "build %s spends the 19 base points" % data["id"])
		_check(evolution_points == 20 and evolution_rank_sum == 21 and catalog.skill_points_spent(purchased, ProfileCatalog.EVOLUTION_WALLET) == 20, "build %s spends the 20 evolution points (ranks sum 21 with the free entry)" % data["id"])
		var legal := catalog.validate_purchased_ranks(&"mage", &"mg_ac", ProgressionRules.MAX_JOB_LEVEL, purchased)
		_check(legal.get("ok", false), "build %s is legal: %s" % [data["id"], legal])
		var shortcuts: Array = data.get("shortcuts", [])
		var known := true
		for skill: Variant in shortcuts: known = known and final_ranks.has(StringName(skill))
		_check(shortcuts.size() <= 24 and known and ClassKitRegistry.skill_ids(&"mg_ac").size() == data["evolution_ranks"].size(), "build %s shortcuts are learned skills (<= 24)" % data["id"])

# --- Círculo Votivo, first spell, alternation -------------------------------------------

func _check_circle_and_alternation() -> void:
	_setup()
	var target := _enemy(Vector2(480, 350))
	_check(_cast(CIRCLE), "Círculo Votivo commits")
	var zone := _zone()
	_check(zone != null and zone.shape == &"circle" and zone.anchor_mode == &"world" and is_equal_approx(zone.radius, 140.0) and is_equal_approx(zone.duration, 12.0) and zone.element == &"none", "R5 circle: world anchor, radius 140, 12 s, no element yet")
	if zone == null: return
	_check(is_equal_approx(zone.rules["burn_ratio"], 0.18) and zone.rules["burn_stat"] == &"magic_attack" and is_equal_approx(zone.rules["owner_damage_taken"], 1.0) and is_equal_approx(zone.rules["heal_multiplier"], 1.0) and is_equal_approx(zone.rules["ice_defense"], 0.18) and is_equal_approx(zone.rules["lightning_sp_regen"], 0.80), "R5 rules: burn 18% of magic ATK, ice +18% DEF, lightning +0.80, no damage or heal rule")
	_check(is_equal_approx(player.skill_cost(CIRCLE), 22.0), "R5 circle costs 22 SP")
	# Barreira Fantasma (no element) neither defines the altar nor counts.
	_check(_spell(&"phantom_barrier") and zone.element == &"none" and StringName(kit.get("last_element")).is_empty(), "Barreira Fantasma inside: no element, nothing changes")
	# First elemental spell inside defines the element.
	var before := _grace()
	_check(_spell(&"fireball") and zone.element == &"fire" and kit.get("circle_element") == &"fire", "the first spell inside (Bola de Fogo) sets the circle to fire")
	_check(_grace() == before, "the first element is not an alternation (no Grace)")
	# Same element again: no alternation.
	_spell(&"fireball")
	_check(_grace() == before, "the same element twice yields no Grace")
	# Different element: alternation, +2 Grace with Prisma R3; the altar stays fire.
	_check(_spell(&"ice_spear", target) and _grace() == before + 2 and zone.element != &"ice" and kit.get("circle_element") == &"fire", "Lança de Gelo after fire: +2 Grace (Prisma R3); the altar stays fire")
	# Retry of the same commit (same kit_time) does not pay again.
	var context := {"element": &"lightning", "point": player.global_position, "target": target, "world": false, "rank": 3}
	var grace_before_retry := _grace()
	kit.on_base_skill_committed(player, &"lightning", context)
	kit.on_base_skill_committed(player, &"lightning", context)
	_check(_grace() == grace_before_retry + 2 or (_grace() == 5 and grace_before_retry >= 3), "a repeated commit of the same spell yields Grace once")
	var after_retry := _grace()
	kit.on_base_skill_committed(player, &"lightning", context)
	_check(_grace() == after_retry, "the third call of the same commit adds nothing")
	# Weakness: leaving the circle loses the sequence and the Grace source.
	authority.grace.charges = 0
	player.global_position = Vector2(900, 650)
	_check(_spell(&"fireball") and _grace() == 0 and StringName(kit.get("last_element")).is_empty() and (kit.get("choir_sequence") as Array).is_empty(), "a spell cast outside the circle yields no Grace and resets the sequence")
	player.global_position = Vector2(400, 350)
	_spell(&"fireball")
	_check(_grace() == 0, "back inside, the first spell after the reset is not an alternation")
	_spell(&"lightning", target)
	_check(_grace() == 2, "then alternating inside pays again")
	# Without the Prisma the alternation yields no Grace.
	var no_prism := _all_ranks()
	no_prism[PRISM] = 0
	_setup(no_prism)
	var other := _enemy(Vector2(480, 350))
	_cast(CIRCLE)
	_spell(&"fireball")
	_spell(&"ice_spear", other)
	_check(_grace() == 0 and _zone().element == &"fire", "without Prisma Votivo the alternation yields no Grace")
	# R1 numbers.
	_setup(_all_ranks(1, 1))
	_check(_cast(CIRCLE), "R1 circle commits")
	var small := _zone()
	_check(small != null and is_equal_approx(small.radius, 120.0) and is_equal_approx(small.duration, 8.0) and is_equal_approx(small.rules["burn_ratio"], 0.10) and is_equal_approx(player.skill_cost(CIRCLE), 18.0), "R1 circle: radius 120, 8 s, burn 10%, 18 SP")
	var target_r1 := _enemy(Vector2(480, 350))
	_spell(&"fireball")
	_spell(&"ice_spear", target_r1)
	_check(_grace() == 1, "Prisma R1: 1 Grace per alternation")

# --- Element rules ---------------------------------------------------------------------

func _check_element_rules() -> void:
	_setup()
	var inside := _enemy(Vector2(460, 350))
	var outside := _enemy(Vector2(800, 350))
	var inside_hits := _hits_on(inside)
	var outside_hits := _hits_on(outside)
	_cast(CIRCLE)
	var zone := _zone()
	for step: int in 4: _tick(0.25)
	_check(inside_hits.size() == 1 and outside_hits.is_empty() and inside_hits[0]["skill_id"] == CIRCLE and bool(inside_hits[0]["secondary"]), "the circle burns once per second only inside")
	var plain := float(inside_hits[0]["damage"]) if not inside_hits.is_empty() else 0.0
	_spell(&"fireball")
	for step: int in 4: _tick(0.25)
	_check(inside_hits.size() == 2 and float(inside_hits[1]["damage"]) > plain * 1.3, "fire: the burn is multiplied (×1.5)")
	# Ice: DEF on the owner as a real breakdown source and slow on enemies.
	var defense := player.stat_breakdown.value(&"magic_defense")
	var hp := player.health.current_hp
	authority.set_zone_element(&"votive", &"ice", player)
	_check(player.stat_breakdown.value(&"magic_defense") > defense and is_equal_approx(authority.ice_defense_applied, 0.18) and player.health.current_hp == hp, "ice: +18% DEF in the breakdown, no heal from the recomposition")
	for step: int in 4: _tick(0.25)
	_check(inside.movement_speed_multiplier() < 1.0, "ice: enemies inside are slowed")
	player.global_position = Vector2(900, 650)
	_tick(0.25)
	_check(is_zero_approx(authority.ice_defense_applied) and not zone.owner_inside, "leaving the circle removes the ice DEF")
	player.global_position = Vector2(400, 350)
	_tick(0.25)
	# Lightning: SP recovers faster inside.
	authority.set_zone_element(&"votive", &"lightning", player)
	player.current_sp = 0.0
	for step: int in 4: _tick(0.25)
	var fast := player.current_sp
	authority.end_zone(&"votive", player)
	player.current_sp = 0.0
	for step: int in 4: _tick(0.25)
	_check(fast > player.current_sp + 0.01, "lightning: SP recovers faster inside (%.2f vs %.2f)" % [fast, player.current_sp])

# --- Refração Curativa -----------------------------------------------------------------

func _check_refraction() -> void:
	_setup()
	var inside := _enemy(Vector2(460, 350))
	var far := _enemy(Vector2(800, 350))
	var hits := _hits_on(inside)
	var far_hits := _hits_on(far)
	_cast(CIRCLE)
	_spell(&"fireball")
	authority.grace.charges = 4
	player.health.current_hp = player.health.max_hp * 0.5
	var hp := player.health.current_hp
	_check(_cast(REFRACTION) and _grace() == 0 and int(kit.get("refraction_charges")) == 4, "Refração spends the Grace at commit (4)")
	var matk := player.stat_breakdown.value(&"magic_attack")
	var expected_heal := minf(matk * 1.0 * (1.0 + 0.4 * 4), player.health.max_hp - hp)
	_check(is_equal_approx(player.health.current_hp - hp, expected_heal), "heal = magic ATK × 100% × (1 + 0.4 × 4), capped at the missing HP")
	_check(hits.size() == 1 and hits[0]["skill_id"] == REFRACTION and far_hits.is_empty() and float(hits[0]["actual_damage"]) > 0.0, "the wave hits the enemies inside the circle only")
	# Capped heal: at full HP the own heal never overflows into Grace.
	player.health.current_hp = player.health.max_hp
	authority.grace.charges = 5
	player.kit_time += 1.0
	_cast(REFRACTION)
	_check(_grace() == 0 and player.health.current_hp == player.health.max_hp, "at full HP the Refração heals nothing and gives no excess Grace")
	# Lightning wave restores SP; a refused cast spends nothing. The wave reads the
	# kit's altar (display element), so the altar is moved, not only the zone.
	kit.set("circle_element", &"lightning")
	kit.call(&"_apply_zone_element", player)
	_check(_zone().element == &"lightning", "altar moved to lightning")
	authority.grace.charges = 2
	player.mage_cooldowns[REFRACTION] = 3.0
	_check(not player.use_kit_skill(REFRACTION, player.global_position) and _grace() == 2, "a refused Refração (cooldown) never spends Grace")
	_ready_cast(REFRACTION)
	player.current_sp = player.max_sp * 0.5
	var sp := player.current_sp
	player.kit_time += 1.0
	player.use_kit_skill(REFRACTION, player.global_position)
	_check(player.current_sp > sp - 24.0 + player.max_sp * 0.04, "lightning wave restores 5% of max SP")
	# Without circle: the wave falls around the Taumaturgo (radius 90).
	authority.end_zone(&"votive", player)
	hits.clear()
	player.kit_time += 1.0
	_cast(REFRACTION)
	_check(hits.size() == 1 and far_hits.is_empty(), "without circle the wave hits around the Taumaturgo")

# --- Mudança de Altar -------------------------------------------------------------------

func _check_altar() -> void:
	_setup()
	var inside := _enemy(Vector2(460, 350))
	var hits := _hits_on(inside)
	_check(not _cast(ALTAR), "Mudança de Altar is refused without a circle")
	_cast(CIRCLE)
	_spell(&"fireball")
	authority.grace.charges = 0
	hits.clear()
	_check(_cast(ALTAR) and kit.get("circle_element") == &"ice" and _zone().element == &"ice", "fire -> ice at once")
	var burn := 0
	var shock := 0
	for hit: Dictionary in hits:
		if hit["skill_id"] == CIRCLE: burn += 1
		if hit["skill_id"] == ALTAR: shock += 1
	_check(burn == 1 and shock == 1, "the old element pulses: one burn (pulse_now) and one shock")
	_check(_grace() == 2 and kit.get("last_element") == &"ice", "the shift counts as casting ice inside: alternation +2 Grace")
	player.kit_time += 1.0
	_cast(ALTAR)
	_check(kit.get("circle_element") == &"lightning", "ice -> lightning")
	player.kit_time += 1.0
	_cast(ALTAR)
	_check(kit.get("circle_element") == &"fire", "lightning -> fire")
	_check(is_equal_approx(player.skill_cost(ALTAR), 20.0), "R5 altar costs 20 SP")

# --- Coro dos Elementos -------------------------------------------------------------------

func _check_choir() -> void:
	_setup()
	var target := _enemy(Vector2(480, 350))
	_cast(CIRCLE)
	_spell(&"fireball")
	_spell(&"ice_spear", target)
	_check(not kit.call(&"choir_active") and _zone().element == &"fire", "two elements: no Coro yet")
	_spell(&"lightning", target)
	_check(kit.call(&"choir_active") and _zone().element == &"tricolor" and is_equal_approx(float(kit.get("choir_remaining")), 5.0) and (kit.get("choir_sequence") as Array).is_empty(), "fire, ice, lightning: the circle turns tricolor for 5 s (R3)")
	_check(authority.ice_defense_applied > 0.0, "tricolor applies the ice DEF too")
	paused = true
	_tick(1.0)
	_check(is_equal_approx(float(kit.get("choir_remaining")), 5.0), "pause freezes the Coro")
	paused = false
	for step: int in 21: _tick(0.25)
	_check(not kit.call(&"choir_active") and _zone().element == &"fire", "after the Coro the altar element returns")
	# Without the passive no Coro.
	var no_choir := _all_ranks()
	no_choir[CHOIR] = 0
	_setup(no_choir)
	var other := _enemy(Vector2(480, 350))
	_cast(CIRCLE)
	_spell(&"fireball")
	_spell(&"ice_spear", other)
	_spell(&"lightning", other)
	_check(not kit.call(&"choir_active") and _zone().element == &"fire", "without Coro dos Elementos the circle stays fire")

# --- Juízo Prismático --------------------------------------------------------------------

func _check_judgment() -> void:
	_setup()
	var target := _enemy(Vector2(520, 350))
	var near := _enemy(Vector2(520, 380))
	var far := _enemy(Vector2(520, 560))
	var hits := _hits_on(target)
	var near_hits := _hits_on(near)
	var far_hits := _hits_on(far)
	authority.grace.charges = 5
	_check(_cast(JUDGMENT, target) and _grace() == 0 and int(kit.get("judgment_charges")) == 5, "Juízo spends 5 charges at commit")
	_check(hits.size() == 1 and near_hits.size() == 1 and far_hits.is_empty(), "fire pulse at the commit on the column (radius 45)")
	_check(int(kit.get("judgment_pulses_left")) == 2 and kit.snapshot_compact_blocker(player) == "thaumaturge_judgment", "two pulses pending; the compact cut is ineligible")
	var first := float(hits[0]["damage"]) if not hits.is_empty() else 0.0
	paused = true
	_tick(1.0)
	_check(hits.size() == 1, "pause freezes the pending pulses")
	paused = false
	_tick(0.2)
	_check(hits.size() == 1, "nothing before 0.3 s")
	_tick(0.15)
	_check(hits.size() == 2 and near_hits.size() == 2 and target.movement_speed_multiplier() < 1.0, "ice pulse at 0.3 s (slow)")
	player.current_sp = player.max_sp * 0.5
	var sp := player.current_sp
	_tick(0.3)
	_check(hits.size() == 3 and int(kit.get("judgment_pulses_left")) == 0 and player.current_sp > sp, "lightning pulse at 0.6 s restores SP")
	_check(first > float(hits[1]["damage"]) * 1.15 if hits.size() >= 2 else false, "the fire pulse is the strongest (×1.25)")
	_tick(1.0)
	_check(hits.size() == 3, "exactly three pulses")
	# Zero Grace: base damage; a refused cast spends nothing.
	player.kit_time += 1.0
	hits.clear()
	_check(_cast(JUDGMENT, target) and hits.size() == 1 and int(kit.get("judgment_charges")) == 0, "Juízo with 0 Grace strikes with the base")
	var base := float(hits[0]["damage"])
	_check(first > base * 2.0, "5 charges multiply the pulse (×3 before the defense)")
	authority.grace.charges = 3
	player.mage_cooldowns[JUDGMENT] = 2.0
	_check(not player.use_kit_skill(JUDGMENT, target.global_position, target) and _grace() == 3, "a refused Juízo never spends Grace")
	# The target dies: the remaining pulses do not fall.
	_tick(1.0)
	var fragile := _enemy(Vector2(480, 300), 1.0)
	var fragile_hits := _hits_on(fragile)
	player.kit_time += 1.0
	_cast(JUDGMENT, fragile)
	for step: int in 8: _tick(0.1)
	_check(not fragile.is_alive() and fragile_hits.size() == 1 and int(kit.get("judgment_pulses_left")) == 0, "a dead target receives no further pulses")

# --- Aurora Convergente ------------------------------------------------------------------

func _check_dawn() -> void:
	_setup()
	var target := _enemy(Vector2(480, 350))
	var wide := _enemy(Vector2(600, 350))
	var wide_hits := _hits_on(wide)
	_cast(CIRCLE)
	_spell(&"fireball")
	var zone := _zone()
	var remaining := zone.remaining
	_check(_cast(DAWN), "Aurora commits")
	_check(kit.call(&"dawn_active") and zone == _zone() and zone.shape == &"wide_circle" and is_equal_approx(zone.radius, 140.0 * 1.6) and zone.element == &"tricolor" and is_equal_approx(zone.remaining, remaining) and not bool(kit.get("dawn_opened_zone")), "a long circle becomes wide (×1.6) and tricolor without restarting clocks")
	_check(authority.grace.is_unlimited(), "Grace has no cap during the Aurora")
	_check(not _cast(CIRCLE), "the circle is refused during the Aurora")
	# skill_cost: half for spells inside, pure; full for the teleport and outside.
	var grace_seen := _grace()
	var dawn_seen := float(kit.get("dawn_remaining"))
	var halved := true
	for read: int in 10:
		halved = halved and is_equal_approx(player.skill_cost(JUDGMENT), 15.0) and is_equal_approx(player.skill_cost(&"fireball"), player.base_skill_cost(&"fireball") * 0.5)
	_check(halved and _grace() == grace_seen and float(kit.get("dawn_remaining")) == dawn_seen and is_equal_approx(player.base_skill_cost(JUDGMENT), 30.0), "skill_cost halves kit and base spells, a pure read (base cost unchanged)")
	_check(is_equal_approx(player.skill_cost(&"phantom_barrier"), player.base_skill_cost(&"phantom_barrier") * 0.5) and is_equal_approx(player.skill_cost(&"teleport"), player.base_skill_cost(&"teleport")) and is_equal_approx(player.skill_cost(DAWN), player.base_skill_cost(DAWN)), "Barreira Fantasma halves; teleport and the Aurora itself do not")
	# The halved price is the one paid (no refund).
	player.mage_cooldowns[&"fireball"] = 0.0
	player.current_sp = player.max_sp
	var sp := player.current_sp
	player.kit_time += 0.01
	player.use_fireball(Vector2.RIGHT)
	_check(is_equal_approx(sp - player.current_sp, player.base_skill_cost(&"fireball") * 0.5), "Bola de Fogo pays half the SP at commit")
	# Grace beyond 5 during the Aurora; spells alternate freely.
	authority.grace.charges = 5
	_spell(&"ice_spear", target)
	_check(_grace() == 7, "alternation passes the cap during the Aurora")
	# Wide circle reaches farther: the burn hits the enemy at 200.
	for step: int in 4: _tick(0.25)
	_check(not wide_hits.is_empty(), "the wide circle burns an enemy at distance 200")
	# Outside the circle the discount does not apply.
	player.global_position = Vector2(950, 680)
	_tick(0.25)
	_check(is_equal_approx(player.skill_cost(&"fireball"), player.base_skill_cost(&"fireball")), "outside the circle spells cost full SP")
	player.global_position = Vector2(400, 350)
	_tick(0.25)
	paused = true
	var before := float(kit.get("dawn_remaining"))
	_tick(1.0)
	_check(float(kit.get("dawn_remaining")) == before, "pause freezes the Aurora")
	paused = false
	for step: int in 30: _tick(0.25)
	_check(not kit.call(&"dawn_active") and _zone() != null and _zone().shape == &"circle" and is_equal_approx(_zone().radius, 140.0) and _zone().element == &"fire" and _grace() <= 5 and not authority.grace.is_unlimited(), "after the Aurora the circle shrinks back, returns to the altar element and Grace to the cap")
	_check(is_equal_approx(player.skill_cost(&"fireball"), player.base_skill_cost(&"fireball")), "after the Aurora spells cost full SP")
	# Without a circle: the Aurora opens its own wide circle and ends it.
	_setup()
	_check(_cast(DAWN), "Aurora without circle")
	var opened := _zone()
	_check(opened != null and opened.shape == &"wide_circle" and is_equal_approx(opened.duration, 8.0) and opened.element == &"tricolor" and bool(kit.get("dawn_opened_zone")), "the Aurora opens a wide tricolor circle for its duration")
	for step: int in 34: _tick(0.25)
	_check(not kit.call(&"dawn_active") and _zone() == null, "the Aurora's own circle ends with it")

# --- Build change, death, pause ------------------------------------------------------------

func _check_build_change_death_and_pause() -> void:
	_setup()
	var enemy := _enemy(Vector2(480, 350))
	_cast(CIRCLE)
	_spell(&"fireball")
	_spell(&"ice_spear", enemy)
	authority.grace.charges = 4
	player.health.current_hp = player.health.max_hp * 0.4
	player.current_sp = player.max_sp * 0.3
	var hp := player.health.current_hp
	var sp := player.current_sp
	var judgment_cd := 3.0
	player.mage_cooldowns[JUDGMENT] = judgment_cd
	var zone := _zone()
	var remaining := zone.remaining
	var sequence := (kit.get("choir_sequence") as Array).duplicate()
	player.apply_run_modifiers(player.run_state)
	_check(_grace() == 4 and is_equal_approx(player.health.current_hp, hp) and is_equal_approx(player.current_sp, sp) and is_equal_approx(player.skill_cooldown(JUDGMENT), judgment_cd) and _zone() == zone and zone.remaining == remaining and kit.get("circle_element") == &"fire" and kit.get("choir_sequence") == sequence, "build change: no heal, no SP refill, no Grace/element/sequence reset, no cooldown reset")
	paused = true
	_tick(1.0)
	_check(zone.remaining == remaining and _grace() == 4, "pause freezes the zone and Grace")
	paused = false
	_cast(DAWN)
	player.kit_time += 1.0
	_cast(JUDGMENT, enemy)
	var request := DamageRequest.new()
	request.source_id = enemy.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = 1000000.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.context = player.run_state.effect_ledger.new_root(enemy.get_instance_id(), false, "", false, {})
	player.health.current_hp = 1.0
	player.apply_damage(request, controller.rng)
	_check(not player.is_alive() and _grace() == 0 and not kit.call(&"dawn_active") and _zone() == null and kit.get("circle_element") == &"none" and int(kit.get("judgment_pulses_left")) == 0 and (kit.get("choir_sequence") as Array).is_empty(), "death: Grace zero; Aurora, circle, altar, sequence and pending pulses end")

# --- Snapshot formats -----------------------------------------------------------------------

func _check_snapshot_formats() -> void:
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty() and registry.schemas.has(KIT_PATH), "the mg_ac fragment merges: " + str(registry.fragment_errors))
	_check("sanctuary" in registry.schemas[KIT_PATH].get("fields", []) if registry.schemas.has(KIT_PATH) and registry.schemas[KIT_PATH] is Dictionary else false, "the kit lists the sanctuary field")
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
	enemy.health.max_hp = 100000.0
	enemy.health.current_hp = 100000.0
	standalone.add_child(enemy)
	var cast := {"skill_id": CIRCLE, "rank": 5, "element": &"light", "world": false, "anchor": null, "point": standalone.global_position, "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": [enemy]}
	standalone_kit.resolve_cast(standalone, cast)
	standalone.kit_time = 3.0
	standalone_kit.on_base_skill_committed(standalone, &"fireball", {"element": &"fire", "point": standalone.global_position, "target": null, "world": false, "rank": 3})
	standalone.kit_time = 4.0
	standalone_kit.on_base_skill_committed(standalone, &"ice_spear", {"element": &"ice", "point": standalone.global_position, "target": enemy, "world": false, "rank": 3})
	cast["skill_id"] = DAWN
	standalone_kit.resolve_cast(standalone, cast)
	standalone_authority.grace.charges = 7
	cast["skill_id"] = JUDGMENT
	cast["target"] = enemy
	standalone_kit.resolve_cast(standalone, cast)
	standalone.kit_time = 9.0
	var dawn := float(standalone_kit.get("dawn_remaining"))
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(standalone)["ok"], "barrier acquired")
	var captured := SnapshotRegistry.new().capture(standalone, barrier)
	_check(captured.get("ok", false), "exact capture with circle, Aurora and pending Juízo: " + str(captured.get("detail", captured.get("error_code", ""))))
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
			_check(copied != null and copied.zone(&"votive") != null and copied.zone(&"votive").shape == &"wide_circle" and copied.zone(&"votive").element == &"tricolor" and copied.grace.charges == 7 and copied.grace.is_unlimited(), "exact format keeps the wide tricolor circle and the unlimited Grace")
			_check(copied_kit != null and is_equal_approx(float(copied_kit.get("dawn_remaining")), dawn) and copied_kit.get("circle_element") == &"fire" and copied_kit.get("last_element") == &"ice" and str(copied_kit.get("choir_sequence")) == str([&"fire", &"ice"]), "exact format keeps the Aurora clock, the altar and the Coro sequence")
			_check(copied_kit != null and copied_enemy != null and int(copied_kit.get("judgment_pulses_left")) == 2 and int(copied_kit.get("victim_id")) == copied_enemy.get_instance_id() and copied_kit.get("judgment_prototype") != null, "exact format keeps the pending Juízo pulses relinked to the restored enemy")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	var projection := {"fields": {}, "excluded": {}}
	var compact := SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and compact.get("detail") == "thaumaturge_dawn", "the Aurora makes the compact cut ineligible")
	standalone_kit.set("dawn_remaining", 0.0)
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and compact.get("detail") == "thaumaturge_judgment", "pending Juízo pulses make the compact cut ineligible")
	standalone_kit.call(&"_clear_judgment")
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and String(compact.get("detail", "")).begins_with("sanctuary_zone"), "an active zone keeps the exact format (A5)")
	standalone_authority.end_zone(&"votive", standalone)
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("ok", false), "without zone, Aurora or Juízo the compact cut is accepted: " + str(compact.get("detail", compact.get("error_code", ""))))
	if compact.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(compact["snapshot"])))
		_check(restored.get("ok", false), "compact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied: SanctuaryAuthority = copy.kit.get("sanctuary")
			_check(copied != null and copied.grace.charges == 7 and copied.grace.is_unlimited() and copied.zones.is_empty() and copy.kit.get("circle_element") == &"fire", "compact format keeps Grace, the unlimited mode and the kit state on the player")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	barrier.release()
