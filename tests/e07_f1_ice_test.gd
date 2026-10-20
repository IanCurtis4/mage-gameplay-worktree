extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
const ID := &"ice_wall"
class Controller extends RunController:
	func _ready() -> void: pass
var checks := 0
var failures := 0
var owned: Array[Node] = []
var c: Controller
var world: WorldGeometry
var profile: Dictionary
var input: ExpeditionGenerationInput
var lower: CombatActor
var upper: CombatActor
var center := Vector3.ZERO
var normal := Vector3.RIGHT
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	for rank: int in [1,5]:
		for facing: Vector3 in [Vector3.RIGHT,Vector3(1,0,1).normalized()]: _nominal(rank,facing)
	for reason: String in ["height","nan","direction","sp","stun","pause","stale","edge","ceiling","sloped","occupied","socket"]: _invalid(reason)
	for mode: String in ["pause","build","epoch","free"]: _lifetime(mode)
	for mode: String in ["occupied","revision","build","stun"]: _during_preparation(mode)
	_capsule_snapshot()
	_height_gap()
	_inflight()
	_teleport()
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 Ice Wall: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _nominal(rank: int,facing: Vector3) -> void:
	_setup(rank,facing)
	var before := c.player.current_sp; var revision := world.geometry_revision
	var destination := lower.world_point()
	check(c.player.move_world_to(destination,revision)["ok"],"route exists before dynamic wall")
	var preview := c.player.preview_world_skill(ID,null,normal,null,c.enemies,revision,0,12)
	check(preview["ok"] and world.geometry_revision == revision and c.player.current_sp == before and _wall() == null and _clear(),"preview is pure and reserves no obstacle")
	if not preview["ok"]: return
	preview["data"]["field"]["height"] = 999
	var cast := c.cast_world_skill(ID,null,normal,null,revision,0,12)
	check(cast["ok"] and c.player.has_active_cast() and c.player.current_sp == before and world.geometry_revision == revision,"preparation is free and leaves paths intact")
	c.player._advance_world_cast(10)
	var wall := _wall()
	check(c.player.world_cast_status()["ok"] and wall != null and world.geometry_revision == revision+1,"actual canonical handler registers exactly one obstacle")
	if wall == null: return
	check(is_equal_approx(c.player.current_sp,before-c.player.skill_cost(ID)) and is_equal_approx(c.player.skill_cooldown(ID),StatCalculator.effective_cooldown(9,c.player.stat_breakdown)),"canonical rank pays SP and cooldown exactly once")
	check(wall.remaining == ClassCatalog.skill_definition(ID).rank_definition(rank).power and wall.world == world,"nominal duration and logical authority captured")
	check(not c.player.advance_world(5)["ok"] and c.player.world_point().position == Vector3(80,0,500),"old path revision cannot move even a partial step")
	var hit := world.sweep(c.player.world_point().position,destination.position,profile,world.geometry_revision)
	check(hit["ok"] and hit["data"]["hit"] and String(hit["data"]["volume_id"]).begins_with("temporary/ice_wall/"),"continuous body sweep hits stable temporary identity")
	check(not _clear(),"same registered solid occludes direct attacks")
	var route := world.path(c.player.world_point(),destination,profile,world.geometry_revision)
	check(route["ok"] and route["data"]["cost"] > c.player.world_point().position.distance_to(destination.position),"supported path detours around exact capsule")
	check(world.path(Fixture.point("bridge",center-normal*60+Vector3.UP*40),Fixture.point("bridge",center+normal*60+Vector3.UP*40),profile,world.geometry_revision)["ok"],"wall downstairs never blocks upper route")
	check(not world.sweep(center-normal*60+Vector3.UP*40,center+normal*60+Vector3.UP*40,profile,world.geometry_revision)["data"]["hit"],"upper projected crossing stays physically clear")
	var unchanged := lower.world_point().position
	check(not lower.world_motion.displace(Fixture.point("root",center-normal*40),200,world.geometry_revision)["ok"] and lower.world_point().position == unchanged,"forced linear displacement cannot acquire a detour through wall")
	_arrow(false)
	_arrow(true)
	_owned_shot()
	var old_hp := lower.health.current_hp
	check(c.player.move_world_to(destination,world.geometry_revision)["ok"] and c.player.advance_world(10000)["ok"] and c.player.world_point().to_data() == destination.to_data(),"real actor executes each safe detour segment")
	check(lower.health.current_hp == old_hp,"solid wall introduces no damage")
	var revision_before := world.geometry_revision
	wall.expire()
	check(world.geometry_revision == revision_before+1 and _clear(),"expiry removes registered collision and restores direct LoS")
	wall.expire()
	check(world.geometry_revision == revision_before+1,"duplicate expiry never removes or revises again")
func _arrow(upstairs: bool,passes: bool = false) -> void:
	var target := upper if upstairs else c.player
	var destination := target.world_point()
	var from := Fixture.point("bridge" if upstairs else "root",center+normal*60+Vector3.UP*(40 if upstairs else 0))
	var hp := target.health.current_hp
	var request := DamageRequest.new(); request.magic_damage = 40; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; request.can_crit = false
	var arrow := ArrowProjectile.new(); arrow.configure(request,target,Vector2.ZERO,c.navigation); c.add_child(arrow)
	check(arrow.bind_world_flight(world,from,Vector3(0,3,0),-normal,{"radius":3.0,"height":6.0},world.geometry_revision)["ok"],"hostile arrow starts with explicit logical cylinder")
	arrow.hit.connect(c._on_attack_requested); arrow._process(2)
	check(arrow.is_queued_for_deletion() and ((target.health.current_hp < hp) if upstairs or passes else target.health.current_hp == hp),"real arrow passes upstairs and stops downstairs, independent of pixels")
func _owned_shot() -> void:
	var hp := lower.health.current_hp
	var request := DamageRequest.new(); request.skill_id = &"fireball"; request.magic_damage = 40; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; request.can_crit = false
	var bolt := MageProjectile.new()
	bolt.configure_directional(request,Vector2.ZERO,Vector2(normal.x,normal.z),[lower],c.navigation,430,600)
	c.add_child(bolt); bolt.hit.connect(c._on_mage_projectile_hit)
	check(bolt.bind_world_flight(world,c.player.world_point(),Vector3.ZERO,normal,{"radius":6.0,"height":12.0},world.geometry_revision)["ok"],"owned Mage projectile binds canonical shared flight")
	bolt._process(2)
	check(bolt.is_queued_for_deletion() and lower.health.current_hp == hp,"actual owned spell also stops on the same registered Ice volume")
func _height_gap() -> void:
	_setup(1)
	var result := c.cast_world_skill(ID,null,normal,null,world.geometry_revision,0,1)
	check(result["ok"],"short wall uses authored height, not actor or visual height")
	c.player._advance_world_cast(10)
	check(_wall() != null and not _clear(),"short solid still blocks ground-level line")
	_arrow(false,true)
func _inflight() -> void:
	_setup(1)
	var hp := c.player.health.current_hp
	var request := DamageRequest.new(); request.magic_damage = 40; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; request.can_crit = false
	var arrow := ArrowProjectile.new(); arrow.configure(request,c.player,Vector2.ZERO,c.navigation); c.add_child(arrow); arrow.hit.connect(c._on_attack_requested)
	check(arrow.bind_world_flight(world,lower.world_point(),Vector3(0,3,0),-normal,{"radius":3.0,"height":6.0},world.geometry_revision)["ok"],"incoming arrow emitted before obstacle exists")
	arrow._process(0.01)
	check(not arrow.is_queued_for_deletion() and _cast(),"wall can appear after real projectile launch")
	arrow._process(2)
	check(arrow.is_queued_for_deletion() and c.player.health.current_hp == hp,"in-flight delivery consults current revision and hits newly inserted Ice")
func _teleport() -> void:
	_setup(1,Vector3.RIGHT,false,true)
	check(_cast(),"Ice remains compatible with legal teleport state")
	var sp := c.player.current_sp; var origin := c.player.world_point()
	check(not c.player.use_world_teleport(Fixture.point("root",center),world.geometry_revision) and c.player.current_sp == sp and c.player.world_point().to_data() == origin.to_data(),"teleport destination inside solid is rejected without cost")
	var destination := Fixture.point("root",center+normal*20)
	check(c.player.use_world_teleport(destination,world.geometry_revision) and c.player.world_point().to_data() == destination.to_data() and c.player.current_sp == sp-c.player.skill_cost(&"teleport"),"actual canonical teleport preserves planar obstacle bypass and exact legal destination")
func _invalid(reason: String) -> void:
	_setup(1,Vector3.RIGHT,reason == "socket")
	var height := 12.0; var facing := normal; var revision := world.geometry_revision
	match reason:
		"height": height = 0
		"nan": height = NAN
		"direction": facing = Vector3.UP
		"sp": c.player.current_sp = 0
		"stun": c.player.apply_stun(2)
		"pause": paused = true
		"stale": revision -= 1
		"edge": facing = Vector3.LEFT
		"ceiling": height = 40
		"sloped":
			check(c.player.move_world_to(Fixture.point("slope",Vector3(600,20,300)),world.geometry_revision)["ok"] and c.player.advance_world(10000)["ok"],"ramp approach is legal before unsupported lateral placement")
			facing = Vector3.FORWARD
		"occupied": _move(lower,Fixture.point("root",center))
	var before := c.player.current_sp; var geometry_before := world.geometry_revision
	var result := c.cast_world_skill(ID,null,facing,null,revision,0,height)
	check(not result["ok"] and c.player.current_sp == before and c.player.skill_cooldown(ID) == 0 and world.geometry_revision == geometry_before and _wall() == null,"invalid ice placement is atomic/free: "+reason)
	if reason == "occupied": check(result["error_code"] == &"occupied","registered downstairs body blocks placement; upstairs body alone does not")
	if reason == "socket": check(result["error_code"] == &"would_disconnect","currently reachable authored socket cannot become inaccessible")
	if reason == "sloped": check(result["error_code"] == &"non_planar_field_support","uneven lateral field remains explicit unsupported case")
	paused = false
func _lifetime(mode: String) -> void:
	_setup(5)
	check(_cast(),"persistent world Ice Wall emitted: "+mode)
	var wall := _wall()
	if wall == null: return
	var remaining := wall.remaining; var revision := world.geometry_revision; var sp := c.player.current_sp
	match mode:
		"pause":
			paused = true; wall._process(1); check(wall.remaining == remaining and world.geometry_revision == revision,"pause freezes lifespan and occupancy"); paused = false
			wall._process(0); wall._process(-1); wall._process(NAN)
			check(wall.remaining == remaining and world.geometry_revision == revision,"zero/invalid delta never advances lifetime or expires")
			wall._process(remaining)
			check(wall.is_queued_for_deletion() and world.geometry_revision == revision+1 and _clear(),"ranked finite clock expires and unregisters")
		"build":
			c.player.run_state.build_snapshot.skill_ranks.erase(ID); c.player.apply_run_modifiers(c.player.run_state)
			wall._process(0.1)
			check(wall.remaining == remaining-0.1 and not _clear(),"build removal does not alter already emitted solid or nominal clock")
		"epoch":
			var hit := world.sweep(c.player.world_point().position,lower.world_point().position,profile,revision)
			var id := String(hit["data"]["volume_id"]).trim_prefix("temporary/")
			world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")
			var insert := world.insert_obstacle(id,AABB(Vector3(10,0,700),Vector3(5,5,5)),world.geometry_revision)
			var current := world.geometry_revision
			wall._process(0)
			check(insert["ok"] and wall.is_queued_for_deletion() and world.geometry_revision == current,"epoch cleanup cannot remove a reused identity from the replacement world")
		"free":
			wall.free()
			check(world.geometry_revision == revision+1 and _clear(),"direct tree removal unregisters the solid")
	check(c.player.current_sp == sp,"late clock/build/epoch/cleanup never repays or refunds")
func _during_preparation(mode: String) -> void:
	_setup(1)
	var before := c.player.current_sp
	var preparing := c.cast_world_skill(ID,null,normal,null,world.geometry_revision,0,12)
	check(preparing["ok"] and c.player.has_active_cast(),"ice starts real preparation: "+mode)
	match mode:
		"occupied": _move(lower,Fixture.point("root",center))
		"revision": check(world.insert_obstacle("other",AABB(Vector3(10,0,700),Vector3(5,5,5)),world.geometry_revision)["ok"],"independent obstacle changes revision during preparation")
		"build": c.player.run_state.build_snapshot.skill_ranks.erase(ID); c.player.apply_run_modifiers(c.player.run_state)
		"stun": c.player.apply_stun(1)
	c.player._advance_world_cast(10)
	check(not c.player.has_active_cast() and not c.player.world_cast_status()["ok"] and c.player.current_sp == before and c.player.skill_cooldown(ID) == 0 and _wall() == null,"preparation revalidates geometry/body/build/control before paying: "+mode)
func _capsule_snapshot() -> void:
	_setup(1)
	var segment := WorldSolidSegment.new()
	check(segment.configure(Fixture.point("root",center),normal,IceWall.HALF_LENGTH,IceWall.HALF_WIDTH,12,profile),"explicit immutable capsule data configured")
	var revision := world.geometry_revision
	check(world.can_insert_segment("probe",segment,revision)["ok"] and world.geometry_revision == revision and _clear(),"pure safety probe leaves actual navigation/LoS unchanged")
	check(world.insert_segment("probe",segment,revision)["ok"],"safe capsule inserted")
	var current := world.geometry_revision
	check(not world.sweep(center+Vector3(9,0,114),center+Vector3(9,0,114),profile,current)["data"]["hit"],"rounded corner stays clear instead of using inflated rectangle")
	check(world.sweep(center+Vector3(0,0,116.9),center+Vector3(0,0,116.9),profile,current)["data"]["hit"],"actual round cap includes body radius")
	segment.configure(Fixture.point("root",Vector3(80,0,700)),Vector3.FORWARD,30,5,8,profile)
	check(not _clear(),"mutating caller-owned segment cannot move registered snapshot without a revision")
	check(not world.insert_segment("probe",segment,current)["ok"] and world.geometry_revision == current,"stable identity is exclusive")
	check(world.remove_obstacle("probe",current)["ok"] and _clear(),"capsule removes through same obstacle API")
	_setup(1,Vector3(1,0,1).normalized())
	check(_cast(),"oblique capsule emitted")
	var point := center+normal*70
	check(not world.sweep(point,point,profile,world.geometry_revision)["data"]["hit"],"empty area inside global bounds remains clear for oblique wall")
func _clear() -> bool:
	var query := world.query_attack({"geometry_rule_id":&"direct_volume","range":2000},c.player.world_point(),lower.world_point(),world.geometry_revision)
	return query["ok"] and query["data"]["hit"]
func _cast() -> bool:
	var result := c.cast_world_skill(ID,null,normal,null,world.geometry_revision,0,12)
	if not result["ok"]: return false
	if c.player.has_active_cast(): c.player._advance_world_cast(10)
	return c.player.world_cast_status()["ok"]
func _wall() -> IceWall:
	for child: Node in c.get_children():
		if child is IceWall: return child
	return null
func _move(actor: CombatActor,point: ExpeditionWorldPoint) -> void:
	check(actor.move_world_to(point,world.geometry_revision)["ok"] and actor.advance_world(10000)["ok"],"fixture actor moves on actual supported route")
func _setup(rank: int,facing: Vector3 = Vector3.RIGHT,blocked_socket: bool = false,learn_teleport: bool = false) -> void:
	input = Fixture.make()
	for part: ExpeditionPartDefinition in input.parts:
		for surface: ExpeditionSurfaceDefinition in part.surfaces:
			for i: int in surface.vertices.size(): surface.vertices[i] = _scale(surface.vertices[i])
		for connector: ExpeditionConnectorDefinition in part.connectors: connector.position = _scale(connector.position); connector.width *= 4
		for socket: ExpeditionSocketDefinition in part.sockets: socket.position = _scale(socket.position)
		for i: int in part.solid_volumes.size():
			var box: AABB = part.solid_volumes[i]; part.solid_volumes[i] = AABB(_scale(box.position),_scale(box.size))
	if blocked_socket: input.parts[0].sockets.append(Fixture.F0.socket("protected","objective",Vector3(280,0,500)))
	world = WorldGeometry.new(); check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"unchanged F0 assembly supplies technical Ice fixture")
	profile = input.traversal.to_data(); normal = facing
	c = Controller.new(); root.add_child(c); owned.append(c); c.set_process(false); c.navigation.configure(Rect2(0,0,4000,4000),[],0); c.rng.seed = 711
	var build := BuildSnapshot.new(); build.character_id = "f1_ice"; build.base_class_id = &"mage"; build.base_level = ProgressionRules.MAX_BASE_LEVEL; build.job_level = 40; build.skill_ranks = {ID:rank}; build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(&"mage",&"")
	if learn_teleport: build.skill_ranks[&"teleport"] = 1
	Dependencies.complete_snapshot(build)
	c.run_state = RunState.from_build("f1_fixture",build); c.player = PlayerActor.new(); c.add_child(c.player); c.player.configure(c.navigation,c.run_state)
	check(c.player.bind_world_geometry(world,Fixture.point("root",Vector3(80,0,500)),profile,str(c.player.get_instance_id()))["ok"],"Mage binds explicit point and body")
	c.player.set_process(false); c.player.health.max_hp = 100000; c.player.health.current_hp = 100000
	center = c.player.world_point().position+normal*c.player.skill_range(ID)
	lower = _target(Fixture.point("root",center+normal*60)); upper = _target(Fixture.point("bridge",center-normal*60+Vector3.UP*40))
	c.enemies.assign([lower,upper])
	c.player.ice_wall_requested.connect(c._on_ice_wall_requested)
func _target(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor); actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"target binds own support"); actor.set_process(false)
	return actor
func _scale(point: Vector3) -> Vector3: return Vector3(point.x*4,point.y,point.z*4)
