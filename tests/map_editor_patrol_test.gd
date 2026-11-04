extends SceneTree
const Document = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const Compiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const Store = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const Session = preload("res://scripts/map_authoring/patrol/patrol_session.gd")
const Preview = preload("res://scripts/map_authoring/patrol/patrol_preview.gd")
const PopulationFixture = preload("res://tests/map_editor_population_test.gd")
const Patrol = preload("res://scripts/core/expedition/patrol/enemy_patrol.gd")
var checks: Array = []
var package_hash := ""
func _initialize() -> void: _run.call_deferred()
func check(id: String, value: bool) -> void:
	checks.append({"id":id,"ok":value}); print("M5_CHECK "+id+" "+str(value))
static func fixture() -> Dictionary:
	var population := PopulationFixture.fixture()
	population.brushes = [population.brushes[0]]; population.brushes[0].quantity = 1; population.exclusions = []; population.interactions = []
	var surface: String = population.brushes[0].surface_id
	population.slots = [{"slot_id":"guard","brush_id":"field","surface_id":surface,"position_xyz":[240,0,200],"species_id":"test_gel","category":"normal","origin_id":"trial_stage_1","fixed":true,"site_id":""}]
	population.plan_hash = Compiler.Population.Document.recipe_hash(population)
	var source := Document.empty(); source.population = [population]
	source.patrols = [{"patrol_id":"guard_route","revision":1,"mode":"loop","slot_ids":["guard"],"waypoints":[{"point_id":"west","surface_id":surface,"position_xyz":[240,0,200],"wait_seconds":2.0},{"point_id":"north","surface_id":surface,"position_xyz":[300,0,260],"wait_seconds":0.0},{"point_id":"south","surface_id":surface,"position_xyz":[300,0,140],"wait_seconds":0.5}]}]
	return source
static func far_player(player: PlayerActor) -> void:
	var world := player.world_motion.geometry
	var surface: String = world._stage.surfaces[-1].surface_id
	player.world_motion._point = ExpeditionWorldPoint.create("map_preview",surface,Vector3(736,0,340))
	world.set_occupant(player.world_motion._occupant_id,player.world_point(),player.world_motion.profile(),world.geometry_revision)
	player.global_position = Vector2(736,340)
static func idle_fixture(package: Dictionary) -> Dictionary:
	var made := Preview.make_actors(package)
	if made.ok:
		far_player(made.player)
		for actor: EnemyActor in made.actors: actor.engagement_mode = &"idle"; actor.threat.disengage(); actor.player_target_acquired = false
	return made
static func cut(player: PlayerActor) -> Dictionary:
	var barrier := SnapshotTickBarrier.new(); barrier.acquire(player)
	var captured := SnapshotRegistry.new().capture(player,barrier); barrier.release(); return captured
func _run() -> void:
	var source := fixture(); var before := source.duplicate(true)
	check("strict_source",Document.validate(source).ok)
	var built := Compiler.compile(source); check("compile_canonical_body_route",built.ok)
	if not built.ok: print(built); finish(); return
	package_hash = built.output_hash
	check("immutable_source",source == before)
	check("repeat_hash",Compiler.compile(source).output_hash == built.output_hash)
	check("json_roundtrip",Document.read(JSON.stringify(source,"",true,true).to_utf8_buffer()).output_hash == Document.hash_source(source))
	var bad := source.duplicate(true); bad.schema_version = 2; check("future_source_rejected",not Document.validate(bad).ok)
	bad = source.duplicate(true); bad.patrols[0].slot_ids = ["missing"]; check("missing_slot",Document.validate(bad).code == "patrol_slot_missing")
	bad = source.duplicate(true); bad.patrols.append(bad.patrols[0].duplicate(true)); bad.patrols[1].patrol_id = "other"; check("duplicate_assignment",Document.validate(bad).code == "patrol_slot_duplicate")
	bad = source.duplicate(true); bad.patrols[0].waypoints[1].position_xyz[0] = NAN; check("nan_rejected",not Document.validate(bad).ok)
	bad = source.duplicate(true); bad.patrols[0].waypoints[1].surface_id = "missing"; check("missing_support",not Compiler.compile(bad).ok)
	bad = source.duplicate(true); bad.patrols[0].waypoints[1].position_xyz = [2000,0,200]; check("outside_leash",not Compiler.compile(bad).ok)
	bad = source.duplicate(true); bad.patrols[0].waypoints = [bad.patrols[0].waypoints[0]]; check("unfinished_route_draft_allowed",Document.validate(bad).ok); check("unfinished_route_cannot_publish",not Compiler.compile(bad).ok)
	check("cancelled_no_package",Compiler.compile(source,func() -> bool: return true).code == "cancelled")
	var session := Session.new(); session.replace(source); var edited := source.duplicate(true); edited.patrols[0].mode = "ping_pong"; session.apply(edited)
	check("undo_whole_route",session.undo() and session.data == source); check("redo_whole_route",session.redo() and session.data == edited)
	var prior := session.data.duplicate(true); check("reject_without_mutation",not session.apply({}).ok and session.data == prior)
	var directory := ProjectSettings.globalize_path("res://.godot/m5_samples"); DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("patrols.json"); var saved := Store.save_source(path,source,Compiler.Population.Schema.bytes_hash(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else "")
	check("source_saved",saved.ok); check("source_reopened",Store.load_source(path).data == source)
	check("external_conflict",Store.save_source(path,source,"wrong").code == "io_conflict")
	var diagnostic_copy: Dictionary = built.package.duplicate(true); diagnostic_copy.erase("package_hash")
	print("M5_PACKAGE_DIAGNOSTIC ",built.package.size()," canonical=",ExpeditionCanonical.valid(built.package)," hash=",ExpeditionCanonical.digest(diagnostic_copy) == built.package.package_hash," population=",Compiler.Population.validate_package(built.package.population_package)," definition=",Patrol.valid_definition(built.package.manifest.population.slots[0].patrol))
	var publication := Store.publish(directory,built.package,Document.hash_source(source)); check("publish_local",publication.ok)
	if not publication.ok: print(publication); finish(); return
	check("immutable_repeat",Store.publish(directory,built.package,Document.hash_source(source)).ok)
	check("package_reload",Store.load_package(publication.path).ok)
	check("warm_package_proof_accepts_exact_copy",Compiler.validate_package(built.package.duplicate(true)))
	check("stale_refused",not Store.publish(directory,built.package,"stale").ok)
	var tampered: Dictionary = built.package.duplicate(true); tampered.manifest.population.slots[0].home.position.x += 10
	check("hash_integrity",not Compiler.validate_package(tampered))
	tampered = built.package.duplicate(true); tampered.manifest.population.slots[0].patrol.waypoints[1].point.position = Vector3(2000,0,200)
	var unsigned := tampered.duplicate(true); unsigned.erase("package_hash"); tampered.package_hash = ExpeditionCanonical.digest(unsigned)
	check("forged_hash_does_not_bypass_geometry",not Compiler.validate_package(tampered))
	check("rejected_mutation_does_not_poison_original_proof",Compiler.validate_package(built.package))
	var made := idle_fixture(built.package); check("real_actors_bind",made.ok)
	if not made.ok: print(made); finish(); return
	var player: PlayerActor = made.player; var actor: EnemyActor = made.actors[0]
	actor._process(0.25); check("wait_begins_at_first_point",actor.patrol.waiting and is_equal_approx(actor.patrol.wait_remaining,1.75))
	var initial_home := actor._world_home.to_data(); var initial_wait: float = actor.patrol.wait_remaining
	actor._process(0.0); check("zero_delta_frozen",actor.patrol.wait_remaining == initial_wait)
	actor.hard_controls.apply(&"root",1.0,0.0); actor._process(0.1)
	check("root_freezes_wait",actor.patrol.wait_remaining == initial_wait); actor.hard_controls.clear()
	actor.hard_controls.apply(&"stun",1.0,0.0); actor._process(0.1)
	check("stun_freezes_wait",actor.patrol.wait_remaining == initial_wait); actor.hard_controls.clear()
	var paused_made := idle_fixture(built.package); var paused_enemy: EnemyActor = paused_made.actors[0]
	paused_enemy._process(0.25); var paused_wait: float = paused_enemy.patrol.wait_remaining
	root.add_child(paused_made.player); paused = true; paused_enemy._process(0.5)
	check("tree_pause_freezes_wait",paused_enemy.patrol.wait_remaining == paused_wait); paused = false; paused_made.player.free()
	actor.health.current_hp = 0; actor._process(0.25); check("dead_does_not_advance",actor.patrol.wait_remaining == initial_wait); actor.health.current_hp = actor.health.max_hp
	actor._process(2.0); check("loop_next_cursor",actor.patrol.cursor == 1 and not actor.patrol.waiting)
	var walked := [0.0]
	var observe := func(a: ExpeditionWorldPoint,b: ExpeditionWorldPoint) -> void: walked[0] += a.position.distance_to(b.position)
	actor.world_ground_walked.connect(observe)
	for i: int in 180: actor._process(0.05)
	actor.world_ground_walked.disconnect(observe)
	check("real_movement_from_home",walked[0] > 100.0)
	check("fixed_home_preserved",actor._world_home.to_data() == initial_home)
	check("patrol_reaches_later_points",actor.patrol.cursor != 1 or actor.patrol.waiting)
	# Aggro interrupts a wait; moving the player outside fixed leash forces canonical return.
	actor.world_motion._point = ExpeditionPopulationPlanner.point(initial_home); actor.world_motion.cancel()
	actor.patrol = Patrol.create(actor.patrol.definition); actor._process(0.5)
	var wait_before: float = actor.patrol.wait_remaining
	player.world_motion._point = ExpeditionWorldPoint.create("map_preview",actor.world_point().surface_id,actor.world_point().position+Vector3(60,0,0))
	actor._process(0.1)
	check("aggro_interrupts_wait",actor.engagement_mode == &"engaged" and actor.patrol.interrupted and actor.patrol.wait_remaining == wait_before)
	player.world_motion._point.position = Vector3(2000,0,200)
	actor._process(0.1); check("leash_starts_return",actor.engagement_mode in [&"returning",&"idle"])
	far_player(player)
	for i: int in 120: actor._process(0.05)
	check("returns_and_resumes",not actor.patrol.interrupted and actor.engagement_mode == &"idle")
	# Full dynamic blocker is injected as an adverse fixture, not a production obstacle API.
	actor.world_motion._point = ExpeditionPopulationPlanner.point(initial_home); actor.world_motion.cancel(); actor.patrol = Patrol.create(actor.patrol.definition); actor.patrol.cursor = 1
	var world := actor.world_motion.geometry
	world._temporary["fault"] = AABB(Vector3(280,-5,230),Vector3(40,80,60)); world.geometry_revision += 1
	var blocked_at := actor.world_point().to_data(); actor._process(0.1)
	check("blocked_diagnosed_without_teleport",actor.patrol.state == "blocked" and actor.world_point().to_data() == blocked_at)
	var blocked_state := actor.patrol.duplicate(true)
	check("temporary_blocker_does_not_refuse_birth_binding",actor.bind_patrol(actor.patrol.definition).ok)
	actor.patrol = blocked_state
	var retry: float = actor.patrol.retry_remaining; actor._process(0.1)
	check("retry_budget",actor.patrol.retry_remaining < retry and actor.patrol.retry_remaining > 0)
	var captured := cut(player); check("blocked_snapshot_valid",captured.ok)
	if not captured.ok: print(captured)
	world._temporary.erase("fault"); world.geometry_revision += 1
	for i: int in 30: actor._process(0.05)
	check("obstacle_removed_route_recalculated",actor.world_point().to_data() != blocked_at and actor.patrol.error == "")
	var restored := SnapshotRegistry.new().restore(captured.snapshot) if captured.ok else {"ok":false}
	check("blocked_graph_restores",restored.ok)
	if restored.ok:
		var copy: PlayerActor = restored.root; var enemy: EnemyActor = copy.get_child(0)
		check("blocked_state_exact",enemy.patrol.state == "blocked" and enemy.patrol.cursor == 1 and enemy.patrol_valid())
		copy.free()
	var broken := actor.patrol.duplicate(true); broken.cursor = 999; actor.patrol = broken
	check("invalid_cursor_blocks_snapshot",not cut(player).ok)
	actor.world_motion.release(); check("released_actor_binding_refused",not actor.bind_patrol(actor.patrol.definition).ok)
	player.free()
	# Ping-pong endpoint direction has a separate expected sequence.
	var def := Compiler.definition(source.patrols[0]); def.mode = "ping_pong"
	for p: Dictionary in def.waypoints: p.wait_seconds = 0.0
	var pp := idle_fixture(built.package); var enemy: EnemyActor = pp.actors[0]; enemy.bind_patrol(def)
	var sequence: Array = [0]
	for i: int in 600:
		var last: int = enemy.patrol.cursor; enemy._process(0.05)
		if last != enemy.patrol.cursor: sequence.append(enemy.patrol.cursor)
		if sequence.size() == 6: break
	check("ping_pong_expected_sequence",sequence == [0,1,2,1,0,1]); pp.player.free()
	ramp_cases()
	finish()
func ramp_cases() -> void:
	var input := preload("res://tests/fixtures/e07/f1/fixture_input.gd").make()
	input.traversal.radius = 20; input.traversal.height = 32
	var scale := Vector3(4,1,4)
	for part: ExpeditionPartDefinition in input.parts:
		for surface: ExpeditionSurfaceDefinition in part.surfaces:
			for i: int in surface.vertices.size(): surface.vertices[i] *= scale
		for connector: ExpeditionConnectorDefinition in part.connectors: connector.position *= scale; connector.width *= 4
		for socket: ExpeditionSocketDefinition in part.sockets: socket.position *= scale
		for i: int in part.solid_volumes.size(): part.solid_volumes[i] = AABB(part.solid_volumes[i].position*scale,part.solid_volumes[i].size*scale)
	var built := ExpeditionAssembler.build(input); check("canonical_ramp_bridge_fixture",built.ok)
	if not built.ok: print(built); return
	var manifest: ExpeditionManifest = built.data.manifest; var world := WorldGeometry.new(); world.configure(manifest,"sample")
	var profile := input.traversal.to_data(); var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,2000,2000),[],18)
	var player := PlayerActor.new(); player.configure(nav,RunState.new(&"mage")); player.global_position = Vector2(80,720)
	player.bind_world_geometry(world,ExpeditionWorldPoint.create("sample","sample/root/surface/floor",Vector3(80,0,720)),profile,"ramp_player")
	var actor := EnemyActor.new(); actor.global_position = Vector2(200,200)
	var spawn := MobOccurrence.new(); spawn.occurrence_id = "ramp_guard"; spawn.mob_base_id = &"test_gel"; spawn.category_id = &"normal"; spawn.origin_id = &"trial_stage_1"
	var catalog := Compiler.Catalog.load_current(); actor.configure_occurrence(spawn,catalog.catalog,nav,player)
	var home := ExpeditionWorldPoint.create("sample","sample/root/surface/floor",Vector3(200,0,200))
	actor.bind_world_geometry(world,home,profile,"ramp_guard"); player.add_child(actor)
	var def := {"patrol_id":"ramp_route","revision":1,"mode":"ping_pong","slot_ids":["ramp_guard"],"waypoints":[{"point_id":"low","point":home.to_data(),"wait_seconds":0.0},{"point_id":"high","point":ExpeditionWorldPoint.create("sample","sample/landing/surface/floor",Vector3(1000,40,200)).to_data(),"wait_seconds":1.0}]}
	check("ramp_route_valid_for_real_body",actor.bind_patrol(def).ok)
	var large := profile.duplicate(true); large.radius = 100
	check("body_too_large_refused",not Patrol.validate_route(def,world,home,large,850).ok)
	var seen_ramp := false
	for i: int in 400:
		actor._process(0.05)
		if actor.world_point().surface_id == "sample/slope/surface/floor" and actor.world_point().position.y > 10 and actor.world_point().position.y < 30: seen_ramp = true; break
	check("actual_actor_reaches_mid_ramp",seen_ramp)
	var cursor: int = actor.patrol.cursor
	var on_ramp := actor.world_point(); player.world_motion._point = ExpeditionWorldPoint.create("sample",on_ramp.surface_id,on_ramp.position+Vector3(0,0,60)); actor._process(0.05)
	check("aggro_on_ramp_preserves_cursor",actor.engagement_mode == &"engaged" and actor.patrol.interrupted and actor.patrol.cursor == cursor)
	actor._begin_return(); world._temporary["return_fault"] = AABB(Vector3(380,-5,0),Vector3(40,100,400)); world.geometry_revision += 1
	var before := actor.world_point().to_data(); actor._process(0.1)
	check("blocked_return_has_diagnostic_no_teleport",actor.engagement_mode == &"returning" and actor.patrol.state == "blocked" and actor.world_point().to_data() == before)
	check("blocked_return_captures",cut(player).ok)
	world._temporary.erase("return_fault"); world.geometry_revision += 1
	player.world_motion._point = ExpeditionWorldPoint.create("sample","sample/root/surface/floor",Vector3(80,0,720))
	var returned := false
	for i: int in 400:
		actor._process(0.05)
		if actor.engagement_mode == &"idle" and not actor.patrol.interrupted: returned = true; break
	check("return_from_ramp_resumes_legal_waypoint",returned and actor._world_home.to_data() == home.to_data() and actor.patrol.cursor == cursor)
	player.free()
func finish() -> void:
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("M5_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"package_hash":package_hash})); quit(0 if ok else 1)
