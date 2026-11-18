extends SceneTree
## E10a T6 — Sacerdote (`priest`) kit invariants (docs/epics/e10a/t6_contract.md): catalog data,
## the two review builds, the Santuário at the chosen point, Graça sources (excess heal, Prece,
## Escudo Votivo, Selo de Luz) without duplication, entry pulse, Égide, Juízo (spend, circle,
## column), Exorcista (shield, buff, Exposto, dormant undead bonus), Selo de Luz (root, boss
## slow), Hora Santa, build change, death, pause and both snapshot formats.
## The Acólito is the T1 fixture base (scripts/classes/fixture/fixture_base.gd): the production
## base is still an empty skeleton (T5). Fixture profiles only; nothing is written to disk.
const FixtureBase = preload("res://scripts/classes/fixture/fixture_base.gd")
const KIT_PATH := "res://scripts/classes/priest/priest_kit.gd"
const BUILDS_PATH := "res://scripts/classes/priest/review_builds.json"

class Controller extends RunController:
	func _ready() -> void: pass

## Calls the effect drawers inside a real _draw() pass.
class DrawProbe extends Node2D:
	var kit: ClassKit
	var effects: Array[StringName] = []
	var drawn: Dictionary = {}
	func _draw() -> void:
		for effect_id: StringName in effects: drawn[effect_id] = kit.draw_vfx(effect_id, self, {"dir": Vector2.RIGHT}, Vector2(60, 60), 0.4)

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
	_install_base()
	_check_catalog()
	_check_review_builds()
	await _check_drawers()
	_check_sanctuary()
	_check_grace()
	_check_base_interactions()
	_check_aegis()
	_check_judgment()
	_check_exorcist()
	_check_light_seal()
	_check_holy_hour()
	_check_build_change_death_and_pause()
	_check_snapshot_formats()
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	print("E10a T6 priest kit: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixture --------------------------------------------------------------------

func _install_base() -> void:
	ClassKitRegistry.clear_fixtures()
	FixtureBase.order_log.clear()
	ClassBaseRegistry.install_fixture(&"acolyte", FixtureBase.new())

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	paused = false

func _all_ranks(evolution_rank: int = 5, passive_rank: int = 3) -> Dictionary:
	var ranks := {&"acolyte_prayer": 5, &"acolyte_votive_shield": 5, &"acolyte_punishing_light": 5, &"acolyte_shadow_seal": 3}
	for skill: StringName in ClassKitRegistry.skill_ids(&"priest"):
		ranks[skill] = passive_rank if skill in [&"priest_grace", &"priest_exorcist"] else evolution_rank
	return ranks

func _make_player(navigation: ArenaNavigation, ranks: Dictionary) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"acolyte"
	snapshot.evolution_id = &"priest"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"acolyte", &"priest")
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	snapshot.active_slots = [&"priest_sanctuary", &"priest_judgment", &"priest_aegis", &"priest_light_seal", &"priest_holy_hour"]
	var actor := PlayerActor.new()
	actor.configure(navigation, RunState.from_build("priest-" + str(checks), snapshot))
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
	player.max_sp = 1000.0

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

## A fresh direct light hit of the player on an enemy (no crit), through the controller.
func _light_hit(enemy: CombatActor, amount: float = 100.0, skill: StringName = &"priest_judgment") -> Dictionary:
	var request := player.kit_make_request(enemy, skill, 0.0, amount, DamageRequest.AccuracyMode.GEOMETRY, false)
	return enemy.apply_damage(request, controller.rng)

func _ready_cast(skill: StringName) -> void:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp

func _cast(skill: StringName, enemy: CombatActor = null, point: Variant = null) -> bool:
	_ready_cast(skill)
	var at: Vector2 = point if point is Vector2 else (enemy.global_position if enemy != null else player.global_position)
	return player.use_kit_skill(skill, at, enemy)

func _tick(delta: float) -> void:
	player._process(delta)

## Natural regeneration may move HP by a fraction of a point while the clock ticks.
func _near(a: float, b: float) -> bool:
	return absf(a - b) < 1.5

func _grace() -> int:
	return authority.grace.charges

func _fill_grace(charges: int) -> void:
	authority.grace.charges = charges

# --- Catalog ----------------------------------------------------------------------

func _check_catalog() -> void:
	var module := ClassKitRegistry.module(&"priest")
	_check(module != null and module.get_script().resource_path == KIT_PATH, "the production module is the priest kit")
	_check(ClassKitRegistry.validate(&"priest").get("ok", false), "registry validation passes: " + str(ClassKitRegistry.validate(&"priest")))
	_check(module.ready_for_play() and ClassKitRegistry.ready_for_play(&"priest") and module.kit_id() == &"priest" and module.display_name() == "Sacerdote", "the kit is ready for play and named in pt-BR")
	_check(ClassKitRegistry.origin(&"priest") == &"acolyte" and ClassKitRegistry.branch(&"priest") == &"2-1" and ClassKitRegistry.is_pure(&"priest"), "pure kit of the Acólito, branch 2-1")
	var definitions := module.skill_definitions()
	var ids: Array[StringName] = []
	for definition: SkillDefinition in definitions: ids.append(definition.id)
	_check(ids == ClassKitRegistry.skill_ids(&"priest") and ids.size() == 7, "seven skills in the job order of C1")
	for index: int in definitions.size():
		var definition := definitions[index]
		var active: bool = ClassKitRegistry.SLOT_CATEGORIES[index] == &"active"
		_check(definition.handler_id == SkillDefinition.Handler.KIT and definition.is_rank_catalog_valid() and definition.ranks.size() == (5 if active else 3) and definition.element == &"light" and String(definition.id).begins_with("priest_"), "%s: kit handler, ranks 1-%d, light, prefix" % [definition.id, 5 if active else 3])
	_check(definitions[0].targeting == SkillDefinition.Targeting.POINT and is_equal_approx(definitions[0].range, 260.0), "the Santuário is a point skill with placement range 260")
	var learning := module.learning_entries()
	_check(learning.size() == 7 and int(learning[0]["free_rank"]) == 1 and int(learning[0]["job_level"]) == 20 and int(learning[6]["job_level"]) == 37 and (learning[0]["prerequisites"] as Dictionary).is_empty(), "learning rows: free entry at job 20 without prerequisite through job 37")
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid() and catalog.base_class_is_available(&"acolyte"), "ProfileCatalog stays valid with the fixture base ready")
	var destination := catalog.evolution_definition(&"priest")
	_check(destination != null and destination.content_ready and destination.branch_kind == &"2-1" and destination.entry_skill_id == &"priest_sanctuary", "the Sacerdote is offered to the ready Acólito (branch 2-1, entry Santuário)")
	var texts := module.skill_texts()
	for skill: StringName in ids:
		var text: Dictionary = texts.get(skill, {})
		var ranks: Array = text.get("ranks", [])
		_check(not String(text.get("effect", "")).is_empty() and not String(text.get("mechanics", "")).is_empty() and ranks.size() == (3 if skill in [&"priest_grace", &"priest_exorcist"] else 5), "%s has pt-BR effect, mechanics and per-rank tooltip" % skill)
		for line: Variant in ranks: _check(not String(line).is_empty() and String(line).begins_with("R"), "%s rank tooltip line: %s" % [skill, line])
		_check(not ClassCatalog.skill_definition(skill).display_name.is_empty() and SkillPresentation.mechanics_of(skill) == String(text["mechanics"]), "%s reaches SkillPresentation" % skill)
		var recipe := FeedbackRecipeCatalog.recipe(skill)
		_check(not recipe.generic and recipe.element == &"light", "%s has a light feedback recipe" % skill)
	var effects := module.vfx_effects()
	_check(effects.size() == 8, "eight reserved flipbook IDs")
	for effect_id: StringName in effects: _check(String(effect_id).begins_with("priest_"), "effect %s carries the prefix" % effect_id)
	_check(ClassKitRegistry.vfx_effect(&"priest_judgment", &"impact")["effect_id"] == &"priest_judgment_column" and ClassKitRegistry.vfx_effect(&"priest_sanctuary", &"effect_start")["effect_id"] == &"priest_sanctuary_circle", "effects reach the presentation catalog by skill and kind")
	_check(is_equal_approx(module.skill_definitions()[3].ranks[4].secondary_power, SanctuaryRules.JUDGMENT_PER_CHARGE), "the Juízo scales 0.40 per charge (the Sanctuary system value)")

# --- Review builds (A11, D6) ------------------------------------------------------------

func _check_review_builds() -> void:
	var file := FileAccess.open(BUILDS_PATH, FileAccess.READ)
	_check(file != null, "review_builds.json exists")
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary and parsed.get("schema") == "ragrpg_review_builds_v1" and parsed.get("identity_id") == "priest", "review builds schema and identity")
	if not parsed is Dictionary: return
	var builds: Array = parsed.get("builds", [])
	_check(builds.size() == 2 and [builds[0].get("id"), builds[1].get("id")] == ["priest_bastion", "priest_inquisition"] and [builds[0].get("name"), builds[1].get("name")] == ["Bastião da Fé", "Inquisição"], "exactly the two named builds of D6: Bastião da Fé and Inquisição")
	var catalog := ProfileCatalog.pilot()
	for build: Variant in builds:
		var data: Dictionary = build
		var purchased: Dictionary[StringName, int] = {}
		var base_points := 0
		var evolution_points := 0
		var final_ranks := {}
		for skill: Variant in data["base_ranks"]:
			_check(String(skill).begins_with("acolyte_") and ClassBaseRegistry.skill_ids(&"acolyte").has(StringName(skill)), "build %s base skill %s is an acolyte_* ID of the contract" % [data["id"], skill])
			purchased[StringName(skill)] = int(data["base_ranks"][skill])
			base_points += int(data["base_ranks"][skill])
			final_ranks[StringName(skill)] = int(data["base_ranks"][skill])
		for skill: Variant in data["evolution_ranks"]:
			var free := int(catalog.skill_metadata(StringName(skill)).get("free_rank", 0))
			purchased[StringName(skill)] = int(data["evolution_ranks"][skill]) - free
			evolution_points += int(data["evolution_ranks"][skill]) - free
			final_ranks[StringName(skill)] = int(data["evolution_ranks"][skill])
		_check(base_points == 19 and catalog.skill_points_spent(purchased, ProfileCatalog.BASE_WALLET) == 19, "build %s spends the 19 base points" % data["id"])
		_check(evolution_points == 20 and catalog.skill_points_spent(purchased, ProfileCatalog.EVOLUTION_WALLET) == 20, "build %s spends the 20 evolution points" % data["id"])
		var legal := catalog.validate_purchased_ranks(&"acolyte", &"priest", ProgressionRules.MAX_JOB_LEVEL, purchased)
		_check(legal.get("ok", false), "build %s is legal: %s" % [data["id"], legal])
		var shortcuts: Array = data.get("shortcuts", [])
		var known := true
		for skill: Variant in shortcuts: known = known and final_ranks.has(StringName(skill))
		_check(shortcuts.size() <= 24 and known, "build %s shortcuts are learned skills (<= 24)" % data["id"])

# --- Effect drawers -------------------------------------------------------------------------

func _check_drawers() -> void:
	var probe := DrawProbe.new()
	probe.kit = ClassKitRegistry.module(&"priest")
	for effect_id: StringName in probe.kit.vfx_effects(): probe.effects.append(effect_id)
	probe.effects.append(&"priest_unknown")
	root.add_child(probe)
	owned.append(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	var drawn_all := true
	for effect_id: StringName in probe.kit.vfx_effects(): drawn_all = drawn_all and bool(probe.drawn.get(effect_id, false))
	_check(probe.drawn.size() == 9 and drawn_all and probe.drawn.get(&"priest_unknown") == false, "every reserved effect draws inside _draw(); an unknown ID is refused")

# --- Santuário ------------------------------------------------------------------------------

func _check_sanctuary() -> void:
	_setup()
	var near := _enemy(Vector2(450, 350))
	var far := _enemy(Vector2(700, 350))
	var near_hits := _hits_on(near)
	var far_hits := _hits_on(far)
	_check(_cast(&"priest_sanctuary", null, Vector2(450, 350)), "Santuário commits at the chosen point")
	var zone := authority.zone(&"sanctuary")
	_check(zone != null and zone.shape == &"circle" and zone.anchor_mode == &"world" and zone.center.is_equal_approx(Vector2(450, 350)) and is_equal_approx(zone.radius, 150.0) and is_equal_approx(zone.duration, 11.0), "R5 circle: radius 150, 11 s, anchored at the chosen point (not on the Sacerdote)")
	if zone == null: return
	_check(is_equal_approx(zone.rules["owner_damage_taken"], 0.76) and is_equal_approx(zone.rules["heal_multiplier"], 1.40) and is_equal_approx(zone.rules["burn_ratio"], 0.22) and zone.rules["burn_stat"] == &"magic_attack" and is_equal_approx(zone.prototype.magic_damage, player.stat_breakdown.value(&"magic_attack") * 0.22), "R5 rules: ×0.76 damage, ×1.40 heal, burn 22% of magic attack")
	_check(zone.owner_inside and zone.contains(player, near) and not zone.contains(player, far), "enemies inside the circle only")
	_check(is_equal_approx(player.skill_cost(&"priest_sanctuary"), 26.0) and is_equal_approx(player.skill_cooldown(&"priest_sanctuary"), 14.0), "R5 costs 26 SP with a 14 s cooldown")
	_check(not player.use_kit_skill(&"priest_sanctuary", Vector2(450, 350)), "a second Santuário waits for the cooldown")
	for step: int in 4: _tick(0.25)
	_check(near_hits.size() == 1 and bool(near_hits[0]["secondary"]) and near_hits[0]["skill_id"] == &"priest_sanctuary" and float(near_hits[0]["actual_damage"]) > 0.0 and far_hits.is_empty(), "the circle burns the enemy inside once per second, as light, and spares the one outside")
	# Inside: less damage and a bigger heal.
	var attacker := _enemy(Vector2(500, 380))
	var result := player.apply_damage(_enemy_request(attacker, 40.0), controller.rng)
	_check(is_equal_approx(float(result.get("kit_damage_multiplier", 1.0)), 0.76), "a hit inside the Santuário takes ×0.76 (omnidirectional, no stance needed)")
	var behind := player.apply_damage(_enemy_request(_enemy(Vector2(300, 350)), 40.0), controller.rng)
	_check(is_equal_approx(float(behind.get("kit_damage_multiplier", 1.0)), 0.76), "the rule has no direction: the Sacerdote guards an area")
	player.health.current_hp = player.health.max_hp * 0.4
	var before_hp := player.health.current_hp
	var applied := player.heal_player(10.0, &"test_heal")
	_check(is_equal_approx(player.health.current_hp - before_hp, 14.0) and applied > 0.0, "a 10 HP heal inside rents 14 HP (×1.40, reported as a bonus heal)")
	# Leaving does not undo the circle, but the bonuses go.
	player.global_position = Vector2(850, 350)
	_tick(0.3)
	_tick(0.3)
	_check(authority.zone(&"sanctuary") == zone and not zone.owner_inside, "leaving keeps the circle and drops the presence")
	var outside := player.apply_damage(_enemy_request(attacker, 40.0), controller.rng)
	player.health.current_hp = player.health.max_hp * 0.4
	before_hp = player.health.current_hp
	player.heal_player(10.0, &"test_heal")
	_check(not outside.has("kit_damage_multiplier") and is_equal_approx(player.health.current_hp - before_hp, 10.0), "outside the circle: no reduction and no heal bonus")
	# One circle per owner; a recast replaces it.
	player.global_position = Vector2(400, 350)
	_cast(&"priest_sanctuary", null, Vector2(300, 300))
	var second := authority.zone(&"sanctuary")
	_check(second != null and second != zone and authority.zones.size() == 1 and second.center.is_equal_approx(Vector2(300, 300)), "a recast replaces the single circle of the owner")
	# R1 numbers.
	_setup(_all_ranks(1, 1))
	_check(_cast(&"priest_sanctuary", null, Vector2(400, 350)), "R1 Santuário commits")
	var small := authority.zone(&"sanctuary")
	_check(small != null and is_equal_approx(small.radius, 130.0) and is_equal_approx(small.duration, 9.0) and is_equal_approx(small.rules["owner_damage_taken"], 0.84) and is_equal_approx(small.rules["heal_multiplier"], 1.20) and is_equal_approx(small.rules["burn_ratio"], 0.14) and is_equal_approx(player.skill_cost(&"priest_sanctuary"), 22.0), "R1 circle: 130, 9 s, ×0.84, ×1.20, burn 14%, 22 SP")

# --- Graça ------------------------------------------------------------------------------------

func _check_grace() -> void:
	_setup()
	_check(is_equal_approx(authority.grace.excess_fraction, 0.05), "Graça R3: 1 charge per 5% of max HP of excess")
	player.health.current_hp = player.health.max_hp
	var before := _grace()
	player.heal_player(player.health.max_hp * 0.11, &"test_heal")
	_check(_grace() == before + 2, "an 11% excess heal yields 2 charges at 5%")
	player.health.current_hp = player.health.max_hp * 0.5
	player.heal_player(player.health.max_hp * 0.2, &"test_heal")
	_check(_grace() == before + 2, "a heal without excess yields no Grace")
	var no_passive := _all_ranks()
	no_passive[&"priest_grace"] = 0
	_setup(no_passive)
	_check(is_equal_approx(authority.grace.excess_fraction, 0.12), "without the passive the excess converts slowly (12%)")
	_setup(_all_ranks(5, 1))
	_check(is_equal_approx(authority.grace.excess_fraction, 0.08), "Graça R1: 8%")
	# Entry pulse (R3): outside -> inside with full Grace, once per cooldown.
	_setup()
	_cast(&"priest_sanctuary", null, Vector2(640, 350))
	_fill_grace(5)
	player.health.current_hp = player.health.max_hp * 0.5
	var hp := player.health.current_hp
	_tick(0.3)
	_tick(0.3)
	_check(not authority.zone(&"sanctuary").owner_inside and _near(player.health.current_hp, hp), "outside the circle there is no entry pulse")
	player.global_position = Vector2(640, 350)
	_tick(0.3)
	_tick(0.3)
	var healed := player.health.current_hp - hp
	_check(authority.zone(&"sanctuary").owner_inside and healed >= player.health.max_hp * 0.12 - 0.01 and is_equal_approx(float(kit.get("pulse_cooldown")), 6.0 - 0.3), "entering with full Grace heals 12% of max HP (R3), boosted by the circle, and starts the 6 s cooldown")
	player.global_position = Vector2(400, 350)
	_tick(0.3)
	_tick(0.3)
	player.global_position = Vector2(640, 350)
	hp = player.health.current_hp
	_tick(0.3)
	_tick(0.3)
	_check(_near(player.health.current_hp, hp), "re-entering during the cooldown gives no second pulse")
	# Not full: no pulse. Rank 0: no pulse.
	_setup()
	_cast(&"priest_sanctuary", null, Vector2(640, 350))
	_fill_grace(4)
	player.health.current_hp = player.health.max_hp * 0.5
	hp = player.health.current_hp
	player.global_position = Vector2(640, 350)
	_tick(0.3)
	_tick(0.3)
	_check(_near(player.health.current_hp, hp), "no pulse without a full Grace reserve")
	_setup(no_passive)
	_cast(&"priest_sanctuary", null, Vector2(640, 350))
	_fill_grace(5)
	player.health.current_hp = player.health.max_hp * 0.5
	hp = player.health.current_hp
	player.global_position = Vector2(640, 350)
	_tick(0.3)
	_tick(0.3)
	_check(_near(player.health.current_hp, hp), "no pulse without the passive")
	# Opening the circle with the owner inside is an entry too.
	_setup()
	_fill_grace(5)
	player.health.current_hp = player.health.max_hp * 0.5
	hp = player.health.current_hp
	_cast(&"priest_sanctuary", null, Vector2(400, 350))
	_tick(0.3)
	_check(player.health.current_hp > hp, "opening the Santuário around the Sacerdote with full Grace pulses")

# --- Base interactions (Prece, Escudo Votivo, Luz Punitiva) --------------------------------------

func _check_base_interactions() -> void:
	_setup()
	player.health.current_hp = player.health.max_hp * 0.4
	var before := _grace()
	_check(_cast(&"acolyte_prayer"), "Prece (fixture base) commits")
	_check(_grace() == before + 1, "each paid Prece commit yields +1 Grace")
	_check(_cast(&"acolyte_votive_shield"), "Escudo Votivo (fixture base) commits")
	_check(_grace() == before + 2, "each paid Escudo Votivo commit yields +1 Grace")
	var enemy := _enemy(Vector2(500, 350))
	_check(_cast(&"acolyte_punishing_light", enemy), "Luz Punitiva (fixture base) commits")
	_check(_grace() == before + 2, "Luz Punitiva yields no Grace by itself")
	_check(not player.use_kit_skill(&"acolyte_prayer", player.global_position), "a refused cast (cooldown) gives no Grace")
	_check(_grace() == before + 2, "refused casts do not pay")
	# The same commit never pays twice.
	var kit_time := player.kit_time
	kit.on_base_skill_committed(player, &"acolyte_prayer", {})
	kit.on_base_skill_committed(player, &"acolyte_prayer", {})
	_check(_grace() == before + 2 and kit_time == player.kit_time, "the event key is skill@kit_time: a repeated call in the instant of the paid commit does not pay again")
	_tick(0.1)
	kit.on_base_skill_committed(player, &"acolyte_prayer", {})
	kit.on_base_skill_committed(player, &"acolyte_prayer", {})
	_check(_grace() == before + 3, "a new instant is a new event, and it pays once")

# --- Égide ----------------------------------------------------------------------------------------

func _check_aegis() -> void:
	_setup()
	var enemy := _enemy(Vector2(460, 350))
	var hits := _hits_on(enemy)
	_check(_cast(&"priest_aegis"), "Égide commits")
	var expected := StatCalculator.personal_shield_capacity(105.0, player.stat_breakdown)
	_check(is_equal_approx(player.health.shield_hp, expected) and authority.aegis_active(), "R5 Égide shield = Perseverança formula with base 105")
	player.health.max_hp = 100000.0
	player.health.current_hp = 100000.0
	player.apply_damage(_enemy_request(enemy, expected * 50.0), controller.rng)
	_check(authority.aegis_pulses == 1 and hits.size() == 1 and hits[0]["skill_id"] == &"priest_aegis" and float(hits[0]["actual_damage"]) > 0.0, "breaking the Égide releases one light pulse")
	for step: int in 30: _tick(0.25)
	_check(authority.aegis_pulses == 1 and hits.size() == 1, "no second pulse at expiry after a break")
	_setup()
	var other := _enemy(Vector2(460, 350))
	var other_hits := _hits_on(other)
	_cast(&"priest_aegis")
	for step: int in 28: _tick(0.25)
	_check(authority.aegis_pulses == 1 and other_hits.size() == 1 and player.health.shield_hp == 0.0, "an unbroken Égide expires into a single pulse and clears the halo")

# --- Juízo -------------------------------------------------------------------------------------------

func _check_judgment() -> void:
	# Spend and scaling (outside any circle: a column of radius 55). Without the Exorcista, so
	# the first light hit does not leave the target Exposto before the second.
	var no_exorcist := _all_ranks()
	no_exorcist[&"priest_exorcist"] = 0
	_setup(no_exorcist)
	var target := _enemy(Vector2(520, 350))
	var hits := _hits_on(target)
	_fill_grace(0)
	_check(_cast(&"priest_judgment", target), "Juízo commits without Grace")
	var base_damage := float(hits[0]["damage"]) if not hits.is_empty() else 0.0
	_check(base_damage > 0.0 and _grace() == 0 and int(kit.get("judgment_charges")) == 0, "with 0 charges the Juízo deals the base damage")
	_fill_grace(5)
	_check(_cast(&"priest_judgment", target), "Juízo commits with 5 charges")
	var full_damage := float(hits[1]["damage"]) if hits.size() > 1 else 0.0
	_check(_grace() == 0 and int(kit.get("judgment_charges")) == 5 and absf(full_damage / maxf(1.0, base_damage) - 3.0) < 0.25, "5 charges are spent and the damage is about ×3.0 (%.0f vs %.0f)" % [full_damage, base_damage])
	_check(authority.grace.spent_total == 5, "the Grace ledger counts the 5 charges once")
	# More than 5 (the Hora's unlimited mode) is capped outside the Hora.
	authority.begin_unlimited(5.0)
	_fill_grace(8)
	_tick(0.1) # the same instant would repeat the previous commit's spend (key skill@kit_time)
	_cast(&"priest_judgment", target)
	_check(int(kit.get("judgment_charges")) == 5 and _grace() == 3, "outside the Hora a Juízo spends at most 5 charges")
	# Column of radius 55 outside the circle.
	_setup()
	var a := _enemy(Vector2(520, 350))
	var b := _enemy(Vector2(550, 350))
	var c := _enemy(Vector2(700, 350))
	var hits_a := _hits_on(a)
	var hits_b := _hits_on(b)
	var hits_c := _hits_on(c)
	_cast(&"priest_judgment", a)
	_check(hits_a.size() == 1 and hits_b.size() == 1 and hits_c.is_empty(), "outside the circle the column (radius 55) strikes only who stands under it")
	# Inside the circle: every enemy in it.
	_setup()
	_cast(&"priest_sanctuary", null, Vector2(450, 350))
	var in_one := _enemy(Vector2(430, 350))
	var in_two := _enemy(Vector2(520, 400))
	var in_three := _enemy(Vector2(380, 300))
	var out := _enemy(Vector2(800, 350))
	var h1 := _hits_on(in_one)
	var h2 := _hits_on(in_two)
	var h3 := _hits_on(in_three)
	var h_out := _hits_on(out)
	_fill_grace(3)
	_check(_cast(&"priest_judgment", in_one), "Juízo inside the Santuário commits")
	var direct := [h1, h2, h3].map(func(list: Array) -> int: return list.size())
	_check(direct == [1, 1, 1] and h_out.is_empty(), "inside the Santuário the Juízo strikes every enemy in the circle, and nobody outside")
	# No SP outside the Hora, base cost 28 at R5.
	_check(is_equal_approx(player.skill_cost(&"priest_judgment"), 28.0), "outside the Hora the Juízo costs its rank SP")
	# Cancelled preparation never spends: spend only on commit.
	_fill_grace(4)
	_check(authority.grace.can_spend(1), "can_spend is a pure read")
	_check(_grace() == 4, "reading does not spend")

# --- Exorcista ----------------------------------------------------------------------------------------

func _check_exorcist() -> void:
	_setup()
	var enemy := _enemy(Vector2(520, 350))
	var player_id := player.get_instance_id()
	# Shield first.
	enemy.health.grant_shield(500.0)
	_light_hit(enemy)
	_check(enemy.health.shield_hp == 0.0 and not enemy.received_damage_sources.has(&"priest_exposed"), "a direct light hit on a shielded enemy removes the shield and does not expose yet")
	enemy.health.grant_shield(900.0)
	var outcome := (kit as Object).call(&"exorcise", player, enemy, 3) as StringName
	_check(outcome == &"shield" and enemy.health.shield_hp == 0.0, "the Exorcista removes the enemy shield")
	# Buffs: the strongest defensive source goes first.
	enemy.add_received_damage_source(&"fixture_ward", 0.7, 20.0)
	enemy.add_received_damage_source(&"fixture_mild", 0.9, 20.0)
	_light_hit(enemy)
	_check(not enemy.received_damage_sources.has(&"fixture_ward") and enemy.received_damage_sources.has(&"fixture_mild") and not enemy.received_damage_sources.has(&"priest_exposed"), "a direct light hit removes the strongest buff (×0.7), not Exposto")
	_light_hit(enemy)
	_check(not enemy.received_damage_sources.has(&"fixture_mild") and not enemy.received_damage_sources.has(&"priest_exposed"), "the next light hit removes the remaining buff")
	# Nothing to remove: Exposto, only for this owner's light.
	_light_hit(enemy)
	var exposed: Dictionary = enemy.received_damage_sources.get(&"priest_exposed", {})
	_check(not exposed.is_empty() and is_equal_approx(float(exposed["multiplier"]), 1.20) and int(exposed["owner_id"]) == player_id and exposed["element"] == &"light" and is_equal_approx(float(exposed["remaining"]), 6.0), "with nothing to remove the target is Exposto: ×1.20 of this owner's light for 6 s (R3)")
	_check(is_equal_approx(enemy.received_damage_multiplier(player_id, &"light"), 1.20) and is_equal_approx(enemy.received_damage_multiplier(player_id + 1, &"light"), 1.0) and is_equal_approx(enemy.received_damage_multiplier(player_id, &"shadow"), 1.0) and is_equal_approx(enemy.received_damage_multiplier(player_id, &"fire"), 1.0), "Exposto filters the owner and the light element")
	var exposed_hit := _light_hit(enemy, 100.0)
	var plain := _enemy(Vector2(560, 350))
	var plain_hit := player.kit_make_request(plain, &"priest_judgment", 0.0, 100.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var plain_result := plain.apply_damage(plain_hit, controller.rng)
	_check(absf(float(exposed_hit["damage"]) / maxf(1.0, float(plain_result["damage"])) - 1.2) < 0.06, "an Exposto enemy takes about ×1.2 of the owner's light (%.0f vs %.0f)" % [float(exposed_hit["damage"]), float(plain_result["damage"])])
	enemy.advance_statuses(3.0)
	_check(enemy.received_damage_sources.has(&"priest_exposed") and float(enemy.received_damage_sources[&"priest_exposed"]["remaining"]) < 6.0, "Exposto runs on the gameplay clock")
	enemy.advance_statuses(10.0)
	_check(not enemy.received_damage_sources.has(&"priest_exposed"), "Exposto expires")
	# Secondary light (the circle's burn) never exorcises.
	_setup()
	_cast(&"priest_sanctuary", null, Vector2(450, 350))
	var burned := _enemy(Vector2(450, 350))
	for step: int in 8: _tick(0.25)
	_check(float(burned.health.max_hp - burned.health.current_hp) > 0.0 and not burned.received_damage_sources.has(&"priest_exposed"), "burn pulses are light but secondary: no Exposto")
	# Base light (Luz Punitiva) exorcises; non-light does not.
	var target := _enemy(Vector2(500, 350))
	_cast(&"acolyte_punishing_light", target)
	_check(target.received_damage_sources.has(&"priest_exposed"), "the base Luz Punitiva also exposes (direct light)")
	var shadow_target := _enemy(Vector2(520, 380))
	var shadow := player.kit_make_request(shadow_target, &"acolyte_shadow_seal", 0.0, 50.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	shadow_target.apply_damage(shadow, controller.rng)
	_check(not shadow_target.received_damage_sources.has(&"priest_exposed"), "shadow damage does not exorcise")
	# Without the passive nothing happens.
	var without := _all_ranks()
	without[&"priest_exorcist"] = 0
	_setup(without)
	var plain_enemy := _enemy(Vector2(500, 350))
	plain_enemy.health.grant_shield(300.0)
	_light_hit(plain_enemy)
	_light_hit(plain_enemy, 1000.0)
	_check(not plain_enemy.received_damage_sources.has(&"priest_exposed"), "without the passive no Exposto is applied")
	# D3: the undead bonus is recorded and without effect.
	_check((kit.get_script() as GDScript).get_script_constant_map()["UNDEAD_BONUS"] == [0.15, 0.20, 0.25] and is_zero_approx((kit as Object).call(&"undead_bonus_for", plain_enemy)), "the undead bonus is recorded as data and its value is 0 while the category does not exist")
	var before := _light_hit(_enemy(Vector2(600, 400)), 100.0)
	var tagged := _enemy(Vector2(620, 400))
	tagged.set_meta(&"undead", true)
	var after := _light_hit(tagged, 100.0)
	_check(float(before["damage"]) == float(after["damage"]), "a creature tagged undead takes the same light damage (dormant bonus)")

# --- Selo de Luz ------------------------------------------------------------------------------------------

func _check_light_seal() -> void:
	_setup()
	var enemy := _enemy(Vector2(520, 350))
	_check(_cast(&"priest_light_seal", enemy), "Selo de Luz commits")
	_check(authority.is_sealed(enemy) and authority.sealed_target() == enemy and enemy.marks.owner_of(&"priest_light_seal") == player.get_instance_id(), "the target carries the mark with the Sacerdote as owner")
	_check(enemy.is_rooted() and enemy.root_remaining() > 0.0, "a common enemy is rooted")
	_check(is_equal_approx(player.skill_cost(&"priest_light_seal"), 22.0) and is_equal_approx(player.skill_cooldown(&"priest_light_seal"), 12.0), "R5 costs 22 SP with a 12 s cooldown")
	# Graça from light damage on the marked, once per event, and not from other elements.
	_fill_grace(0)
	var result := _light_hit(enemy)
	_check(_grace() == 1, "light damage on the marked yields 1 Grace")
	kit.on_damage_dealt(player, result)
	kit.on_damage_dealt(player, result)
	_check(_grace() == 1, "a retried damage result does not pay twice")
	_light_hit(enemy)
	_check(_grace() == 2, "a new light event pays again")
	var shadow := player.kit_make_request(enemy, &"acolyte_shadow_seal", 0.0, 50.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	enemy.apply_damage(shadow, controller.rng)
	_check(_grace() == 2, "shadow damage on the marked yields no Grace")
	var unmarked := _enemy(Vector2(560, 380))
	_light_hit(unmarked)
	_check(_grace() == 2, "light damage on an unmarked enemy yields no Grace")
	# One seal per owner.
	_cast(&"priest_light_seal", unmarked)
	_check(authority.is_sealed(unmarked) and not authority.is_sealed(enemy) and not enemy.marks.has_mark(&"priest_light_seal"), "sealing another enemy moves the single mark")
	# The sealed enemy burned by the circle feeds the Graça (the Inquisição loop).
	_setup()
	_cast(&"priest_sanctuary", null, Vector2(450, 350))
	var burned := _enemy(Vector2(450, 350))
	_cast(&"priest_light_seal", burned)
	_fill_grace(0)
	for step: int in 8: _tick(0.25)
	_check(_grace() >= 1, "the Santuário burn on the sealed enemy yields Grace each pulse (%d)" % _grace())
	# Boss: slow, never root.
	_setup()
	var boss := _enemy(Vector2(520, 350))
	boss.configure_hard_control_profile(true)
	_check(_cast(&"priest_light_seal", boss), "Selo de Luz commits on a boss")
	_check(authority.is_sealed(boss) and not boss.is_rooted() and boss.root_remaining() == 0.0, "a boss is marked but never rooted")
	_check(absf(boss.slow_fraction - 0.38) < 0.001 and absf(boss.slow_remaining - 6.0) < 0.05, "the boss is slowed by 38% for the mark duration (R5)")
	# R1 numbers.
	_setup(_all_ranks(1, 1))
	var small := _enemy(Vector2(520, 350))
	_cast(&"priest_light_seal", small)
	_check(small.is_rooted() and small.root_remaining() <= 1.6 + 0.001 and is_equal_approx(player.skill_cost(&"priest_light_seal"), 18.0), "R1: 18 SP, root up to 1.6 s")

# --- Hora Santa -------------------------------------------------------------------------------------------------

func _check_holy_hour() -> void:
	# On a lasting Santuário.
	_setup()
	_cast(&"priest_sanctuary", null, Vector2(400, 350))
	var zone := authority.zone(&"sanctuary")
	var remaining := zone.remaining
	_check(_cast(&"priest_holy_hour"), "Hora Santa commits")
	_check(zone == authority.zone(&"sanctuary") and zone.shape == &"wide_circle" and is_equal_approx(zone.radius, 240.0) and is_equal_approx(zone.rules["heal_multiplier"], 2.0) and zone.remaining == remaining and not bool(kit.get("hour_opened_zone")), "the Santuário grows to ×1.6 and heals ×2.0 without restarting its clocks")
	_check(is_equal_approx(float(kit.get("hour_remaining")), 9.0) and authority.grace.is_unlimited(), "R5 lasts 9 s and the Grace has no limit")
	_check(not player.use_kit_skill(&"priest_sanctuary", Vector2(400, 350)) and kit.can_cast(player, {"skill_id": &"priest_sanctuary"})["error_code"] == &"priest_hour_active", "a new Santuário is refused during the Hora")
	# Heal doubles.
	player.health.current_hp = player.health.max_hp * 0.4
	var before_hp := player.health.current_hp
	player.heal_player(10.0, &"test_heal")
	_check(is_equal_approx(player.health.current_hp - before_hp, 20.0), "a 10 HP heal rents 20 HP in the Hora (×2.0)")
	# Grace past the cap; Juízo free and wider.
	_fill_grace(8)
	_check(_grace() == 8, "the Grace passes the cap in the Hora")
	_check(is_equal_approx(player.skill_cost(&"priest_judgment"), 0.0), "the Juízo costs 0 SP in the Hora while inside the Santuário")
	var enemy := _enemy(Vector2(400, 350 + 200))
	var hits := _hits_on(enemy)
	_check(zone.contains(player, enemy), "an enemy 200 away is inside the wide circle (240)")
	player.current_sp = 0.0
	player.mage_cooldowns[&"priest_judgment"] = 0.0
	_check(player.use_kit_skill(&"priest_judgment", enemy.global_position, enemy) and player.current_sp == 0.0 and hits.size() == 1, "the Juízo casts with 0 SP in the Hora and hits the wide circle")
	_check(int(kit.get("judgment_charges")) == 8 and _grace() == 0, "in the Hora a Juízo spends up to 10 charges (8 here)")
	_check(kit.snapshot_compact_blocker(player) == "priest_holy_hour", "the Hora makes the compact cut ineligible")
	for step: int in 38: _tick(0.25)
	_check(not kit.call(&"hour_active") and authority.zone(&"sanctuary") == zone and zone.shape == &"circle" and is_equal_approx(zone.radius, 150.0) and is_equal_approx(zone.rules["heal_multiplier"], 1.40) and not authority.grace.is_unlimited(), "after the Hora the circle, the heal and the Grace limit return")
	_check(is_equal_approx(player.skill_cost(&"priest_judgment"), 28.0), "the Juízo costs SP again outside the Hora")
	# Without a Santuário: the Hora opens its own wide circle and ends it.
	_setup()
	_check(_cast(&"priest_holy_hour"), "Hora without Santuário")
	var opened := authority.zone(&"sanctuary")
	_check(opened != null and opened.shape == &"wide_circle" and is_equal_approx(opened.radius, 240.0) and is_equal_approx(opened.duration, 9.0) and bool(kit.get("hour_opened_zone")) and opened.center.is_equal_approx(player.global_position), "the Hora opens a wide circle (rank 5 of the Santuário) at the Sacerdote for its duration")
	for step: int in 38: _tick(0.25)
	_check(not kit.call(&"hour_active") and authority.zone(&"sanctuary") == null, "the Hora's own circle ends with it")
	# A short Santuário is replaced at the same point.
	_setup()
	_cast(&"priest_sanctuary", null, Vector2(300, 300))
	for step: int in 40: _tick(0.25)
	_check(authority.zone(&"sanctuary") != null and authority.zone(&"sanctuary").remaining < 9.0, "the Santuário is shorter than the Hora")
	_cast(&"priest_holy_hour")
	var replaced := authority.zone(&"sanctuary")
	_check(bool(kit.get("hour_opened_zone")) and replaced.shape == &"wide_circle" and replaced.center.is_equal_approx(Vector2(300, 300)) and is_equal_approx(replaced.remaining, 9.0), "a short Santuário is replaced by the Hora circle at the same point")

# --- Build change, death, pause ------------------------------------------------------------------------------------

func _check_build_change_death_and_pause() -> void:
	_setup()
	_cast(&"priest_sanctuary", null, Vector2(400, 350))
	player.apply_run_modifiers(player.run_state) # back to the real max SP (the fixture raised it)
	_fill_grace(4)
	player.health.current_hp = player.health.max_hp * 0.4
	player.current_sp = player.max_sp * 0.3
	var hp := player.health.current_hp
	var sp := player.current_sp
	player.mage_cooldowns[&"priest_judgment"] = 3.0
	var zone := authority.zone(&"sanctuary")
	var remaining := zone.remaining
	player.apply_run_modifiers(player.run_state)
	_check(_grace() == 4 and _near(player.health.current_hp, hp) and is_equal_approx(player.current_sp, sp) and is_equal_approx(player.skill_cooldown(&"priest_judgment"), 3.0) and authority.zone(&"sanctuary") == zone and zone.remaining == remaining, "build change: no heal, no SP refill, no Grace reset, no cooldown reset, circle kept")
	paused = true
	_tick(1.0)
	_check(zone.remaining == remaining and _grace() == 4 and is_equal_approx(float(kit.get("pulse_cooldown")), 0.0), "pause freezes the circle and the Grace")
	paused = false
	var enemy := _enemy(Vector2(480, 350))
	_cast(&"priest_light_seal", enemy)
	_cast(&"priest_holy_hour")
	kit.set("pulse_cooldown", 5.0)
	player.health.current_hp = 1.0
	player.apply_damage(_enemy_request(enemy, 100000.0), controller.rng)
	_check(not player.is_alive() and _grace() == 0 and not kit.call(&"hour_active") and authority.zone(&"sanctuary") == null and not authority.is_sealed(enemy) and is_zero_approx(float(kit.get("pulse_cooldown"))) and not bool(kit.get("was_inside")), "death: Grace zero, Hora, circle, seal and pulse cooldown end")

# --- Snapshot formats -----------------------------------------------------------------------------------------------------

func _check_snapshot_formats() -> void:
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty() and registry.schemas.has(KIT_PATH), "the priest fragment merges: " + str(registry.fragment_errors))
	var fields: Array = registry.schemas[KIT_PATH].get("fields", []) if registry.schemas.has(KIT_PATH) and registry.schemas[KIT_PATH] is Dictionary else []
	_check("sanctuary" in fields and "hour_remaining" in fields and "was_inside" in fields and "pulse_cooldown" in fields, "the kit lists its run-state fields")
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
	var cast := {"skill_id": &"priest_sanctuary", "rank": 5, "element": &"light", "world": false, "anchor": null, "point": Vector2(450, 350), "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": [enemy]}
	standalone_kit.resolve_cast(standalone, cast)
	cast["skill_id"] = &"priest_holy_hour"
	standalone_kit.resolve_cast(standalone, cast)
	standalone_authority.grace.charges = 7
	standalone_authority.seal(standalone, enemy, &"priest_light_seal", 4.0, 1)
	standalone_kit.set("pulse_cooldown", 3.5)
	standalone_kit.set("was_inside", true)
	standalone.kit_time = 9.0
	var hour := float(standalone_kit.get("hour_remaining"))
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(standalone)["ok"], "barrier acquired")
	var captured := SnapshotRegistry.new().capture(standalone, barrier)
	_check(captured.get("ok", false), "exact capture with circle, Hora and seal: " + str(captured.get("detail", captured.get("error_code", ""))))
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
			_check(copied != null and copied.zone(&"sanctuary") != null and copied.zone(&"sanctuary").shape == &"wide_circle" and is_equal_approx(float(copied.zone(&"sanctuary").rules["heal_multiplier"]), 2.0) and copied.grace.charges == 7 and copied.grace.is_unlimited(), "exact format keeps the wide circle, its doubled heal and the unlimited Grace")
			_check(copied_kit != null and is_equal_approx(float(copied_kit.get("hour_remaining")), hour) and is_equal_approx(float(copied_kit.get("pulse_cooldown")), 3.5) and bool(copied_kit.get("was_inside")) and is_equal_approx(float(copied_kit.get("hour_saved_heal")), float(standalone_kit.get("hour_saved_heal"))), "exact format keeps the Hora clock, the pulse cooldown and the presence")
			_check(copied != null and copied_enemy != null and copied.is_sealed(copied_enemy), "exact format keeps the seal with the restored enemy")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	var projection := {"fields": {}, "excluded": {}}
	var compact := SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and compact.get("detail") == "priest_holy_hour", "the Hora makes the compact cut ineligible")
	standalone_kit.set("hour_remaining", 0.0)
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and String(compact.get("detail", "")).begins_with("sanctuary_zone"), "an active circle keeps the exact format")
	standalone_authority.end_zone(&"sanctuary")
	enemy.marks.clear()
	compact = SnapshotRegistry.new().capture(standalone, barrier, false, projection)
	_check(compact.get("ok", false), "without circle, seal or Hora the compact cut is accepted: " + str(compact.get("detail", compact.get("error_code", ""))))
	if compact.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(compact["snapshot"])))
		_check(restored.get("ok", false), "compact restore: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied: SanctuaryAuthority = copy.kit.get("sanctuary")
			_check(copied != null and copied.grace.charges == 7 and copied.grace.is_unlimited() and copied.zones.is_empty(), "compact format keeps Grace and the unlimited mode on the player")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	barrier.release()
