extends SceneTree
## E09 K4 — the Salto Prismático validated by the world geometry (F1 technical fixture,
## tests/fixtures/e07/f1): the real world cast pipeline (request_world_skill →
## KitWorldSkillCast → can_cast → payment → resolve) teleports the Lâmina behind the
## victim through FlankAuthority.teleport_behind (trace_ground + WorldActorMotion.teleport).
## Covers the range, the blocked back point (edge without ground), the slab above (victim
## under the bridge, and victim on the bridge over the Lâmina), the route after the
## teleport and the base Teleporte exit measured from the last tick (world departure).
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const WorldFixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const MARK := &"arcane_blade_refracted_mark"
const EDGE := &"arcane_blade_enchanted_edge"
const REFRACTION := &"arcane_blade_refraction"
const LEAP := &"arcane_blade_prismatic_leap"
const FRACTURE := &"arcane_blade_light_fracture"
const SENTENCE := &"arcane_blade_prismatic_sentence"
const SPECTER := &"arcane_blade_prism_specter"

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var kit: ClassKit
var flank: FlankAuthority
var world: WorldGeometry
var profile: Dictionary

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	var input := WorldFixture.make()
	var built := ExpeditionAssembler.build(input)
	world = WorldGeometry.new()
	_check(built["ok"] and world.configure(built["data"]["manifest"], "sample")["ok"], "F1 fixture geometry configured")
	if built["ok"]:
		profile = input.traversal.to_data()
		_check_leap_under_slab()
		_check_leap_onto_slab()
		_check_edge_and_range()
		_check_exit_from_last_tick()
	_cleanup()
	print("E09 K4 mg_la world leap: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()

func _setup(at: ExpeditionWorldPoint, leap_rank: int = 5) -> void:
	_cleanup()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_la"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"mg_la")
	snapshot.skill_ranks = {&"teleport": 5, &"ice_spear": 5, MARK: 5, EDGE: 3, REFRACTION: 5, LEAP: leap_rank, FRACTURE: 3, SENTENCE: 5, SPECTER: 5}
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [MARK, REFRACTION, LEAP, SENTENCE, SPECTER]
	player = PlayerActor.new()
	player.configure(navigation, RunState.from_build("mg-la-world-" + str(checks), snapshot))
	controller.add_child(player)
	player.set_process(false)
	controller.player = player
	controller.run_state = player.run_state
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	player.world_attack_requested.connect(func(request: DamageRequest, target: CombatActor, _delivery: StringName) -> void: controller._on_attack_requested(request, target))
	_check(player.bind_world_geometry(world, at, profile, str(player.get_instance_id()))["ok"], "kit player bound to the world")
	player.set_process(false)
	kit = player.kit
	flank = kit.get("flank")

func _actor(point: ExpeditionWorldPoint, facing: Vector3) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}))
	controller.add_child(actor)
	actor.set_process(false)
	actor.health.max_hp = 100000.0
	actor.health.current_hp = 100000.0
	actor.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	_check(actor.bind_world_geometry(world, point, profile, str(actor.get_instance_id()))["ok"], "world actor bound at %s" % point.position)
	actor.set_process(false)
	actor.override_gameplay_ground_facing(facing, 60.0, &"test")
	controller.enemies.append(actor)
	return actor

func _hostile(point: ExpeditionWorldPoint) -> EnemyActor:
	var hostile := EnemyActor.new()
	hostile.configure(&"chaser", controller.navigation, player)
	controller.add_child(hostile)
	hostile.set_process(false)
	_check(hostile.bind_world_geometry(world, point, profile, str(hostile.get_instance_id()))["ok"], "world enemy bound")
	hostile.set_process(false)
	controller.enemies.append(hostile)
	return hostile

func _hits_on(enemy: CombatActor) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	enemy.health.damage_applied.connect(func(result: Dictionary) -> void: hits.append(result))
	return hits

func _actors() -> Array[CombatActor]:
	var actors: Array[CombatActor] = []
	for enemy: CombatActor in controller.enemies: actors.append(enemy)
	return actors

## Real world cast pipeline for one kit skill.
func _world_cast(skill: StringName, target: CombatActor = null) -> Dictionary:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp
	var anchor := target.world_point() if target != null else null
	return player.request_world_skill(skill, anchor, Vector3.RIGHT, target, _actors(), world.geometry_revision)

func _conceal_and_mark(victim: CombatActor) -> void:
	_check(_world_cast(MARK, victim).get("ok", false) and flank.victim(player) == victim, "world Marca on the victim")
	_check(_world_cast(REFRACTION).get("ok", false) and player.kit_concealed(), "world Refração conceals")

func _sight_broken(hostile: EnemyActor) -> bool:
	var threat := hostile.get(&"threat") as ThreatService
	return threat != null and threat.sight_broken(String(hostile.call(&"threat_id_for", player)))

# --- Under the slab: the back point stays on the ground below the bridge -------------------

func _check_leap_under_slab() -> void:
	_setup(WorldFixture.point("root", Vector3(20, 0, 40)))
	var victim := _actor(WorldFixture.point("root", Vector3(60, 0, 150)), Vector3(1, 0, 0))
	var hits := _hits_on(victim)
	_check(_world_cast(LEAP, victim).get("error_code") == &"arcane_blade_not_concealed", "world Salto refused when not concealed")
	_check(_world_cast(REFRACTION).get("ok", false) and player.kit_concealed(), "world Refração conceals")
	_check(_world_cast(LEAP, victim).get("error_code") == &"arcane_blade_not_victim", "world Salto refused before the Marca")
	_check(_world_cast(MARK, victim).get("ok", false) and player.kit_concealed(), "world Marca while concealed")
	var expected := flank.back_point(player, victim)
	var result := _world_cast(LEAP, victim)
	_check(result.get("ok", false), "world Salto commits: %s" % str(result))
	var at := player.world_point()
	_check(expected["ok"] and at.position.distance_to(expected["ground"]) < 0.01 and at.surface_id == "sample/root/surface/floor" and absf(at.position.y) < 0.01, "under the bridge slab the Lâmina lands on the ground behind the victim, not on the slab: %s %s" % [at.surface_id, at.position])
	_check(FlankRules.side_between(victim, player)["side"] == &"back", "the landing is behind the victim (ground plane)")
	_check(hits.size() == 1 and hits[0]["skill_id"] == LEAP and FlankRules.result_flags(hits[0]).get("side") == &"back" and bool(FlankRules.result_flags(hits[0]).get("from_concealment", false)), "the world strike counts from behind and from the concealment")
	_check(flank.sentence(player) == 2 and not player.kit_concealed(), "+2 Sentence; the Salto revealed the Lâmina")
	_check(not player.world_motion.has_route() and player.target == victim, "after the teleport no route is left; the Lâmina engages the victim")
	_check(player.can_basic_attack(victim), "the crystal blade reaches the victim from the landing point")

# --- Onto the slab: the victim stands on the bridge above the Lâmina -------------------------

func _check_leap_onto_slab() -> void:
	# Right under the victim: the slab is 40 above, but the ground route up is longer
	# than the Salto range, so the world targeting refuses it and nothing is paid.
	_setup(WorldFixture.point("root", Vector3(60, 0, 140)))
	var above := _actor(WorldFixture.point("bridge", Vector3(60, 40, 150)), Vector3(1, 0, 0))
	_check(_world_cast(REFRACTION).get("ok", false), "world Refração conceals")
	flank.mark_victim(player, above)
	var sp := player.current_sp
	player.mage_cooldowns[LEAP] = 0.0
	var start := player.world_point().position
	var refused := player.request_world_skill(LEAP, above.world_point(), Vector3.RIGHT, above, _actors(), world.geometry_revision)
	_check(not player.world_can_reach(above, player.skill_range(LEAP)) and not refused.get("ok", false) and refused.get("error_code") == &"invalid_target", "a victim on the slab right above is out of the ground reach: refused (%s)" % refused.get("error_code"))
	_check(is_equal_approx(player.current_sp, sp) and player.world_point().position.distance_to(start) < 0.01 and player.kit_concealed(), "the refused Salto under the slab costs nothing and keeps the concealment")
	# From the landing, the same victim on the slab is in reach: the Lâmina lands on the slab.
	_setup(WorldFixture.point("landing", Vector3(220, 40, 150)))
	var victim := _actor(WorldFixture.point("bridge", Vector3(60, 40, 150)), Vector3(1, 0, 0))
	_conceal_and_mark(victim)
	var expected := flank.back_point(player, victim)
	_check(expected["ok"] and String(expected["world_point"].surface_id).contains("bridge") and is_equal_approx(expected["ground"].y, 40.0), "the back point of a victim on the slab is traced on the slab")
	var result := _world_cast(LEAP, victim)
	_check(result.get("ok", false), "the world Salto onto the slab commits: %s" % str(result))
	_check(player.world_point().position.distance_to(expected["ground"]) < 0.01 and String(player.world_point().surface_id).contains("bridge") and is_equal_approx(player.world_point().position.y, 40.0), "the Lâmina lands on the slab behind the victim, not on the floor below: %s" % player.world_point().position)
	_check(FlankRules.side_between(victim, player)["side"] == &"back", "behind the victim on the slab")

# --- Edge without ground and range --------------------------------------------------------------

func _check_edge_and_range() -> void:
	_setup(WorldFixture.point("root", Vector3(50, 0, 40)))
	var edge := _actor(WorldFixture.point("root", Vector3(3, 0, 150)), Vector3(1, 0, 0))
	_conceal_and_mark(edge)
	var sp := player.current_sp
	player.mage_cooldowns[LEAP] = 0.0
	var start := player.world_point().position
	var refused := player.request_world_skill(LEAP, edge.world_point(), Vector3.RIGHT, edge, _actors(), world.geometry_revision)
	_check(not refused.get("ok", false) and refused.get("error_code") == &"back_point_blocked", "no ground behind the victim: the world Salto is refused (%s)" % refused.get("error_code"))
	_check(is_equal_approx(player.current_sp, sp) and is_zero_approx(player.skill_cooldown(LEAP)) and player.world_point().position.distance_to(start) < 0.01 and player.kit_concealed(), "a refused world Salto costs nothing and keeps the concealment")
	# Range: a rank-1 Salto (300) cannot reach a victim at the far end of the landing.
	_setup(WorldFixture.point("root", Vector3(5, 0, 5)), 1)
	var far := _actor(WorldFixture.point("landing", Vector3(290, 40, 190)), Vector3(0, 0, 1))
	_conceal_and_mark(far)
	var reach := player.skill_range(LEAP)
	_check(is_equal_approx(reach, 300.0) and not player.world_can_reach(far, reach), "the far victim is beyond the rank-1 Salto range on the ground")
	start = player.world_point().position
	var out := _world_cast(LEAP, far)
	_check(not out.get("ok", false) and player.world_point().position.distance_to(start) < 0.01, "the out-of-range world Salto is refused and leaves the Lâmina in place (%s)" % out.get("error_code"))
	var near := _actor(WorldFixture.point("root", Vector3(60, 0, 40)), Vector3(1, 0, 0))
	_check(_world_cast(MARK, near).get("ok", false) and _world_cast(LEAP, near).get("ok", false) and FlankRules.side_between(near, player)["side"] == &"back", "inside the range the same Salto lands behind the victim")

# --- Base Teleporte exit in the world (departure = last tick) -----------------------------------

func _check_exit_from_last_tick() -> void:
	_setup(WorldFixture.point("root", Vector3(30, 0, 40)))
	var near := _hostile(WorldFixture.point("root", Vector3(50, 0, 40)))
	var arrival_side := _hostile(WorldFixture.point("landing", Vector3(270, 40, 60)))
	player._process(0.05)
	var departure: Vector3 = kit.get("last_ground")
	_check(bool(kit.get("has_last_ground")) and departure.distance_to(Vector3(30, 0, 40)) < 1.0, "the kit tick records the ground position")
	player.mage_cooldowns[&"teleport"] = 0.0
	player.current_sp = player.max_sp
	_check(not _sight_broken(near) and not _sight_broken(arrival_side), "both enemies see the Lâmina before the exit")
	_check(player.use_world_teleport(WorldFixture.point("landing", Vector3(250, 40, 50)), world.geometry_revision), "the world Teleporte commits (up the ramp to the landing)")
	_check(_sight_broken(near) and not player.can_be_acquired_by_world(near), "the world Teleporte is the exit: the enemy near the departure loses sight and cannot acquire the Lâmina")
	_check(not _sight_broken(arrival_side), "the enemy near the arrival keeps sight: the exit is measured from the departure (last tick), not the arrival")
