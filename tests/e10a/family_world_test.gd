extends SceneTree
## E10a T15 (A15, item 3) — the skills of the Acólito base and of the Sacerdote through the world
## skill command of the expedition (RunController.cast_world_skill → PlayerActor.request_world_skill
## → capture, validation, payment and kit resolution), never through a hand-built resolve_cast.
## The world is the F1 fixture geometry; the modules are the production ones (no fixture base),
## attached by PlayerActor.configure; mobs are real forest mobs bound to the same world. Each
## active is checked for payment (SP and cooldown) and for its world effect: the Luz Punitiva's
## world projectile lands, Prece heals, Escudo Votivo and Égide give their barrier (with the Fé
## Protetora, A15.3), Selo marks, Sussurro pushes the common enemy and spares the boss, Visão
## extends the basic attack, Santuário opens at the world point, Juízo spends Grace, Selo de Luz
## seals the common, Hora Santa opens. A19/A20/A21: every world selection of the family reaches
## only the floor of its anchor (the F1 bridge stands 40 above the lower floor): Juízo, Olhar,
## Sussurro, Geometria, Revelação, Ídolo and the contagion of the Delírio Compartilhado, each
## with one enemy stacked on the bridge above a lower-floor enemy.
## Fixture profiles only; nothing is written to disk.
const WorldFixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const BASE_PATH := "res://scripts/classes/bases/acolyte/acolyte_base.gd"
const PRIEST_PATH := "res://scripts/classes/priest/priest_kit.gd"
const ACOLYTE_ACTIVES: Array[StringName] = [&"acolyte_punishing_light", &"acolyte_prayer", &"acolyte_votive_shield", &"acolyte_shadow_seal", &"acolyte_disturbing_whisper", &"acolyte_eldritch_vision"]

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var navigation: ArenaNavigation
var world: WorldGeometry
var profile: Dictionary
var mob_serial := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	if not WorldFixture.sources_current():
		push_error("FAIL: stale F1 fixture (run e07_f1_import_test first)")
		quit(1)
		return
	_check(ClassBaseRegistry.ready_for_play(&"acolyte") and ClassBaseRegistry.module(&"acolyte").get_script().resource_path == BASE_PATH, "the production Acólito base is the registered module (no fixture)")
	_check_acolyte_world()
	_check_priest_world()
	_check_judgment_floor()
	_check_cultist_floors()
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	KitDecoy.unregister_drawer(MadnessRules.IDOL_DRAWER)
	print("E10a T15 family world: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixture --------------------------------------------------------------------------

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	paused = false

func _setup(evolution: StringName, ranks: Dictionary, start: Vector3 = Vector3(20, 0, 20)) -> bool:
	_cleanup()
	var input := WorldFixture.make()
	var built := ExpeditionAssembler.build(input)
	world = WorldGeometry.new()
	var configured: bool = built["ok"] and world.configure(built["data"]["manifest"], "sample")["ok"]
	_check(configured, "F1 fixture geometry configured")
	if not configured: return false
	profile = input.traversal.to_data()
	navigation = ArenaNavigation.new()
	navigation.configure(Rect2(-2000, -2000, 4000, 4000), [], 0.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL if evolution != &"" else ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL
	snapshot.base_class_id = &"acolyte"
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"acolyte", evolution)
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	player = PlayerActor.new()
	player.configure(navigation, RunState.from_build("t15-world-%s-%d" % [evolution, checks], snapshot))
	controller.add_child(player)
	player.set_process(false)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 37
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	player.status_damage_requested.connect(controller._on_attack_requested)
	player.world_attack_requested.connect(controller._on_world_attack_requested)
	player.mage_projectile_requested.connect(controller._on_mage_projectile_requested)
	var bound := player.bind_world_geometry(world, WorldFixture.point("root", start), profile, str(player.get_instance_id()))
	_check(bound["ok"], "the player is bound to the world: %s" % [bound])
	player.set_process(false)
	player.max_sp = 1000.0
	player.current_sp = 1000.0
	return bound["ok"]

## A real catalog mob of the forest phase bound to the same world and wired to the RunController.
func _mob(mob_id: StringName, at: Vector3, category: StringName = &"normal", part: String = "root") -> EnemyActor:
	mob_serial += 1
	var hostile := EnemyActor.new()
	var spawn := MobOccurrence.new()
	spawn.occurrence_id = "t15w_%s_%03d" % [mob_id, mob_serial]
	spawn.mob_base_id = mob_id
	spawn.category_id = category
	spawn.origin_id = &"trial_stage_1"
	var configured := hostile.configure_occurrence(spawn, BuildContentLoader.pilot().mob_catalog(), navigation, player)
	_check(configured.get("ok", false), "real mob %s configured: %s" % [mob_id, configured])
	controller.add_child(hostile)
	hostile.set_process(false)
	hostile.health.max_hp = 100000.0
	hostile.health.current_hp = 100000.0
	hostile.attack_requested.connect(controller._on_enemy_attack_requested)
	hostile.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(hostile)
	var bound := hostile.bind_world_geometry(world, WorldFixture.point(part, at), profile, str(hostile.get_instance_id()))
	_check(bound["ok"], "%s bound to the world: %s" % [mob_id, bound])
	hostile.set_process(false)
	hostile.global_position = Vector2(at.x, at.z)
	return hostile

## The world skill command, as RunController._world_skill_pointer issues it after picking.
func _world_cast(skill: StringName, victim: CombatActor = null, anchor: ExpeditionWorldPoint = null, aim: Vector3 = Vector3.ZERO) -> Dictionary:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp
	player.kit_time += 0.001
	var at := anchor if anchor != null else (victim.world_point() if victim != null else player.world_point())
	var facing := aim if not aim.is_zero_approx() else at.position - player.world_point().position
	if facing.is_zero_approx(): facing = Vector3.RIGHT
	var sp := player.current_sp
	var result := controller.cast_world_skill(skill, at, facing, victim, world.geometry_revision)
	if result.get("ok", false) and player.has_active_cast(): player._advance_world_cast(10.0)
	_check(result.get("ok", false), "%s: the world skill command accepts it (%s)" % [skill, result.get("error_code", "")])
	if result.get("ok", false):
		_check(player.current_sp < sp and player.skill_cooldown(skill) > 0.0, "%s: paid through the world command (SP %.1f → %.1f, cooldown %.1f)" % [skill, sp, player.current_sp, player.skill_cooldown(skill)])
	return result

## Lets the world projectiles of the RunController fly to their target.
func _fly_projectiles() -> int:
	var flown := 0
	for step: int in 40:
		var live := 0
		for child: Node in controller.get_children():
			if child is PlayerProjectile and not child.is_queued_for_deletion():
				live += 1
				child.set_process(false)
				(child as PlayerProjectile)._process(0.05)
		if live == 0: break
		flown += 1
	return flown

func _advance(delta: float) -> void:
	for candidate: Variant in controller.enemies.duplicate():
		var hostile := candidate as EnemyActor
		if is_instance_valid(hostile) and hostile.is_alive():
			hostile.advance_statuses(delta)
			hostile._advance_target_override(delta)
	player._process(delta)

func _advance_for(seconds: float, step: float = 0.05) -> void:
	var left := seconds
	while left > 0.0001:
		_advance(minf(step, left))
		left -= step

# --- Acólito -------------------------------------------------------------------------

func _check_acolyte_world() -> void:
	var ranks := {}
	for skill: StringName in ClassBaseRegistry.skill_ids(&"acolyte"): ranks[skill] = 3 if skill in [&"acolyte_devotion", &"acolyte_protective_faith"] else 5
	if not _setup(&"", ranks): return
	var base := player.origin_kit
	_check(base != null and base.get_script().resource_path == BASE_PATH and player.kit == null, "only the production Acólito base is attached")
	var wolf := _mob(&"forest_wolf", Vector3(20, 0, 150))
	var behind := _mob(&"forest_boar", Vector3(80, 0, 60))
	var boss := _mob(&"forest_ancient_warden", Vector3(40, 0, 140), &"boss")
	for skill: StringName in ACOLYTE_ACTIVES:
		_check(player.kit_owns_skill(skill) and player.preview_world_skill(skill, wolf.world_point() if ClassKitRegistry.skill_definition(skill).targeting == SkillDefinition.Targeting.SINGLE_TARGET else player.world_point(), Vector3(0, 0, 1), wolf if ClassKitRegistry.skill_definition(skill).targeting == SkillDefinition.Targeting.SINGLE_TARGET else null, controller.enemies, world.geometry_revision).get("ok", false), "%s: the world preview accepts it" % skill)
	# Luz Punitiva: a world projectile of the RunController reaches the wolf.
	var hp := wolf.health.current_hp
	_world_cast(&"acolyte_punishing_light", wolf)
	var flown := _fly_projectiles()
	_check(flown > 0 and wolf.health.current_hp < hp, "Luz Punitiva: the world projectile flies and lands (%.0f → %.0f)" % [hp, wolf.health.current_hp])
	# Selo Sombrio: mark, accuracy and Madness in the world.
	_world_cast(&"acolyte_shadow_seal", wolf)
	_check(wolf.marks.has_mark(&"acolyte_shadow_seal") and is_equal_approx(MadnessAuthority.madness_of(wolf), 26.0) and wolf.accuracy_sources.has(&"acolyte_shadow_seal"), "Selo Sombrio marks the world wolf (Madness %.0f)" % MadnessAuthority.madness_of(wolf))
	# Sussurro: cone toward the wolf; the boss in the cone gains Madness and stays; the one behind does not.
	var wolf_start := wolf.world_point().position
	var boss_start := boss.world_point().position
	_world_cast(&"acolyte_disturbing_whisper", wolf)
	_check(is_equal_approx(MadnessAuthority.madness_of(wolf), 66.0) and is_equal_approx(MadnessAuthority.madness_of(boss), 40.0) and is_zero_approx(MadnessAuthority.madness_of(behind)), "Sussurro: the two ahead gain Madness (wolf %.0f, boss %.0f), the one behind none" % [MadnessAuthority.madness_of(wolf), MadnessAuthority.madness_of(boss)])
	_check(wolf.world_point().position.distance_to(wolf_start) > 40.0 and boss.world_point().position.distance_to(boss_start) < 0.5, "Sussurro pushes the common wolf in the world (%.1f) and never the boss" % wolf.world_point().position.distance_to(wolf_start))
	# Visão Eldritch: the basic attack reaches farther; the charge doubles the next Selo or Sussurro.
	var basic := player._basic_range()
	_world_cast(&"acolyte_eldritch_vision")
	_check(bool(base.call(&"vision_active")) and bool(base.get(&"vision_charged")), "Visão Eldritch opens through the world command and charges")
	_check(player._basic_range() > basic, "the basic attack reaches farther under the Visão (%.0f → %.0f)" % [basic, player._basic_range()])
	# Prece and Escudo Votivo: self casts at the player's world point.
	player.health.current_hp = player.health.max_hp * 0.5
	var before := player.health.current_hp
	_world_cast(&"acolyte_prayer")
	_check(bool(base.call(&"prayer_active")), "Prece starts its pulses through the world command")
	_advance_for(1.1)
	_check(player.health.current_hp > before, "Prece heals in the world (%.1f → %.1f)" % [before, player.health.current_hp])
	player.health.clear_shield()
	_world_cast(&"acolyte_votive_shield")
	var plain := StatCalculator.personal_shield_capacity(78.0, player.stat_breakdown)
	_check(absf(player.health.shield_hp - plain * 1.20) < 0.01 and float(base.get(&"votive_remaining")) > 0.0, "Escudo Votivo in the world: barrier with the Fé R3 once (%.2f of %.2f)" % [player.health.shield_hp, plain])

# --- Sacerdote -----------------------------------------------------------------------

func _priest_ranks() -> Dictionary:
	var ranks := {&"acolyte_punishing_light": 2, &"acolyte_prayer": 5, &"acolyte_votive_shield": 5, &"acolyte_shadow_seal": 1, &"acolyte_devotion": 3, &"acolyte_protective_faith": 3}
	for skill: StringName in ClassKitRegistry.skill_ids(&"priest"): ranks[skill] = 3 if skill in [&"priest_grace", &"priest_exorcist"] else 5
	return ranks

func _check_priest_world() -> void:
	if not _setup(&"priest", _priest_ranks()): return
	var kit := player.kit
	_check(kit != null and kit.get_script().resource_path == PRIEST_PATH and player.origin_kit.get_script().resource_path == BASE_PATH, "the production Sacerdote over the production base")
	if kit == null: return
	var sanctuary: Variant = kit.get(&"sanctuary")
	var wolf := _mob(&"forest_wolf", Vector3(20, 0, 150))
	var boss := _mob(&"forest_ancient_warden", Vector3(60, 0, 180), &"boss")
	# Santuário at a world point in front of the Sacerdote.
	var spot := WorldFixture.point("root", Vector3(20, 0, 120))
	_world_cast(&"priest_sanctuary", null, spot)
	_check(sanctuary.has_active_zone(), "Santuário opens at the world point")
	# Égide: the barrier through grant_barrier, with the Fé Protetora once.
	player.health.clear_shield()
	_world_cast(&"priest_aegis")
	var aegis_plain := StatCalculator.personal_shield_capacity(ClassKitRegistry.skill_definition(&"priest_aegis").rank_definition(player.skill_rank(&"priest_aegis")).power, player.stat_breakdown)
	_check(sanctuary.aegis_active() and absf(player.health.shield_hp - aegis_plain * 1.20) < 0.01, "Égide in the world: barrier with the Fé R3 once (%.2f of %.2f)" % [player.health.shield_hp, aegis_plain])
	# Base skills under the Sacerdote through the world command give Grace.
	var grace := int(kit.call(&"grace_charges"))
	_world_cast(&"acolyte_prayer")
	_world_cast(&"acolyte_votive_shield")
	_check(int(kit.call(&"grace_charges")) >= grace + 2, "Prece and Escudo Votivo in the world give Grace (%d → %d)" % [grace, int(kit.call(&"grace_charges"))])
	# Selo de Luz: the common is held, the boss only slowed.
	_world_cast(&"priest_light_seal", wolf)
	_check(sanctuary.is_sealed(wolf), "Selo de Luz seals the world wolf")
	# Juízo spends Grace and strikes the world wolf.
	var charges := int(kit.call(&"grace_charges"))
	var hp := wolf.health.current_hp
	_world_cast(&"priest_judgment", wolf)
	_advance_for(0.2)
	_fly_projectiles()
	_check(int(kit.call(&"grace_charges")) < charges and wolf.health.current_hp < hp, "Juízo spends Grace (%d → %d) and strikes in the world (%.0f → %.0f)" % [charges, int(kit.call(&"grace_charges")), hp, wolf.health.current_hp])
	# Hora Santa.
	_world_cast(&"priest_holy_hour")
	_check(bool(kit.call(&"hour_active")), "Hora Santa opens through the world command")
	_check(boss.is_alive(), "the boss stays in the fight")

## A19: two enemies stacked at the same x/z, one per floor (root y=0, bridge y=40).
## No Santuário and no Hora Santa here: inside a zone the Juízo strikes every enemy of the zone instead.
func _check_judgment_floor() -> void:
	if not _setup(&"priest", _priest_ranks()): return
	var kit := player.kit
	var lower := _mob(&"forest_wolf", Vector3(60, 0, 150))
	var upper := _mob(&"forest_boar", Vector3(60, 40, 150), &"normal", "bridge")
	var actors: Array = [lower, upper]
	var at_lower := SanctuaryHelpers.judgment_targets(player, actors, lower.world_point())
	_check(lower in at_lower and upper not in at_lower, "the column at the lower floor hits only the lower enemy (%d targets)" % at_lower.size())
	var at_upper := SanctuaryHelpers.judgment_targets(player, actors, upper.world_point())
	_check(upper in at_upper and lower not in at_upper, "the column at the bridge hits only the bridge enemy (%d targets)" % at_upper.size())
	var beside := SanctuaryHelpers.judgment_targets(player, actors, WorldFixture.point("root", Vector3(60, 0, 300)))
	_check(beside.is_empty(), "a column far in x/z hits nobody")
	# Through the world command: the Juízo on the lower wolf never touches the bridge.
	var sanctuary: Variant = kit.get(&"sanctuary")
	sanctuary.gain({"key": "t15_floor_grace"}, 3)
	var lower_hp := lower.health.current_hp
	var upper_hp := upper.health.current_hp
	_world_cast(&"priest_judgment", lower)
	_advance_for(0.2)
	_check(lower.health.current_hp < lower_hp and is_equal_approx(upper.health.current_hp, upper_hp), "Juízo in the world: the lower wolf is struck (%.0f → %.0f), the bridge boar never (%.0f → %.0f)" % [lower_hp, lower.health.current_hp, upper_hp, upper.health.current_hp])

# --- Floors of the Cultista's and the Sussurro's selections (A20, A21) ------------------

func _cultist_ranks() -> Dictionary:
	var ranks := {&"acolyte_punishing_light": 1, &"acolyte_prayer": 1, &"acolyte_votive_shield": 1, &"acolyte_shadow_seal": 5, &"acolyte_disturbing_whisper": 5, &"acolyte_protective_faith": 1}
	for skill: StringName in ClassKitRegistry.skill_ids(&"cultist"): ranks[skill] = 3 if skill in [&"cultist_ecstasy", &"cultist_open_pupil"] else 5
	return ranks

## The Cultista at root (20, 0, 40) facing +z; `lower` and `beside` on the lower floor (x 0..100),
## `upper` on the bridge exactly above `lower` (same x/z, 40 higher). On foot, the bridge is ~460
## away through the ramp and the landing, beyond every radius of the family (Revelação 360), so a
## selection that reaches it is a projection across floors. Returns [lower, upper, beside].
func _stack() -> Array[EnemyActor]:
	var stacked: Array[EnemyActor] = []
	if not _setup(&"cultist", _cultist_ranks(), Vector3(20, 0, 40)): return stacked
	stacked.append(_mob(&"forest_wolf", Vector3(20, 0, 150)))
	stacked.append(_mob(&"forest_boar", Vector3(20, 40, 150), &"normal", "bridge"))
	stacked.append(_mob(&"forest_wolf", Vector3(50, 0, 150)))
	player.override_gameplay_ground_facing(Vector3(0, 0, 1), 30.0)
	return stacked

func _check_cultist_floors() -> void:
	var stacked := _stack()
	if stacked.size() != 3: return
	var kit := player.kit
	var authority := MadnessAuthority.of(player) as MadnessAuthority
	var lower := stacked[0]
	var upper := stacked[1]
	var beside := stacked[2]
	_check(kit != null and authority != null and absf(upper.world_point().position.y - lower.world_point().position.y - 40.0) < 0.01, "the stack: one enemy on the bridge 40 above the lower one, same x/z")
	# Olhar do Abismo: pure selection, then the world command.
	var gaze: Array = kit.call(&"gaze_targets", player, controller.enemies)
	_check(lower in gaze and beside in gaze and upper not in gaze, "Olhar: the cone takes the lower floor only (%d targets)" % gaze.size())
	_world_cast(&"cultist_abyss_gaze", null, null, Vector3(0, 0, 1))
	_check(MadnessAuthority.madness_of(lower) > 0.0 and is_zero_approx(MadnessAuthority.madness_of(upper)), "Olhar in the world: Madness below (%.0f), none on the bridge" % MadnessAuthority.madness_of(lower))
	# Revelação: pure selection, then the world command.
	stacked = _stack()
	if stacked.size() != 3: return
	kit = player.kit
	lower = stacked[0]
	upper = stacked[1]
	beside = stacked[2]
	var sight: Array = kit.call(&"_in_sight", player, controller.enemies)
	_check(lower in sight and beside in sight and upper not in sight, "Revelação: the sight takes the lower floor only (%d targets)" % sight.size())
	_world_cast(&"cultist_revelation", null, null, Vector3(0, 0, 1))
	_check(MadnessAuthority.madness_of(lower) > 0.0 and is_zero_approx(MadnessAuthority.madness_of(upper)), "Revelação in the world: Madness below (%.0f), none on the bridge" % MadnessAuthority.madness_of(lower))
	# Geometria Impossível at the lower enemy's point.
	stacked = _stack()
	if stacked.size() != 3: return
	lower = stacked[0]
	upper = stacked[1]
	beside = stacked[2]
	_world_cast(&"cultist_impossible_geometry", null, lower.world_point())
	_check(lower.is_disoriented() and beside.is_disoriented() and not upper.is_disoriented() and not upper.marks.has_mark(&"cultist_geometry"), "Geometria in the world: the figure below disorients the lower floor, never the bridge")
	_check(ClassKit.anchor_on_floor(player, lower.world_point().position, controller.enemies) != null and ClassKit.anchor_on_floor(player, lower.world_point().position, controller.enemies).surface_id == lower.world_point().surface_id, "the figure's anchor is rebuilt on the lower floor from its centre")
	_check(ClassKit.anchor_on_floor(player, upper.world_point().position, controller.enemies).surface_id == upper.world_point().surface_id, "a centre on the bridge is rebuilt on the bridge")
	# Ídolo at a lower-floor point beside the stack.
	stacked = _stack()
	if stacked.size() != 3: return
	authority = MadnessAuthority.of(player) as MadnessAuthority
	lower = stacked[0]
	upper = stacked[1]
	beside = stacked[2]
	_world_cast(&"cultist_impossible_idol", null, WorldFixture.point("root", Vector3(35, 0, 120)))
	var decoy := authority.idol(player) if authority != null else null
	_check(decoy != null, "Ídolo placed through the world command")
	if decoy != null:
		_check(lower.combat_target() == decoy and beside.combat_target() == decoy and upper.combat_target() != decoy and is_zero_approx(MadnessAuthority.madness_of(upper)), "Ídolo in the world: the lower floor turns to it, the bridge never (upper target %s)" % [upper.combat_target()])
	# Contagion (Delírio Compartilhado) from the lower enemy.
	stacked = _stack()
	if stacked.size() != 3: return
	authority = MadnessAuthority.of(player) as MadnessAuthority
	lower = stacked[0]
	upper = stacked[1]
	beside = stacked[2]
	var near := MadnessHelpers.neighbours(lower, controller.enemies, MadnessRules.CONTAGION_RADIUS)
	_check(beside in near and upper not in near, "contagion: the neighbours of the lower enemy are on its floor only (%d)" % near.size())
	_check(authority.mark_contagion(player, lower)["ok"] and authority.add(lower, 50.0, "t15_floor_contagion", player)["ok"], "contagion marked and fed")
	_check(MadnessAuthority.madness_of(beside) > 0.0 and is_zero_approx(MadnessAuthority.madness_of(upper)), "contagion copies to the lower neighbour (%.0f), never to the bridge" % MadnessAuthority.madness_of(beside))
	# Sussurro Perturbador (base, under the Cultista) toward the lower enemy.
	stacked = _stack()
	if stacked.size() != 3: return
	lower = stacked[0]
	upper = stacked[1]
	var upper_start := upper.world_point().position
	_world_cast(&"acolyte_disturbing_whisper", lower)
	_check(MadnessAuthority.madness_of(lower) > 0.0 and is_zero_approx(MadnessAuthority.madness_of(upper)) and upper.world_point().position.distance_to(upper_start) < 0.5, "Sussurro in the world: Madness and push below, the bridge untouched")
