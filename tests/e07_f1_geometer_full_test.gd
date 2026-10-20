extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
const A := Vector3(60,0,340)
const B := Vector3(240,0,340)
const C := Vector3(60,0,520)
class Controller extends RunController:
	func _ready() -> void: pass
var checks := 0
var failures := 0
var owned: Array[Node] = []
var c: Controller
var casting: GeometerCasting
var state: WorldGeometerConstruction
var world: WorldGeometry
var profile: Dictionary
var lower: CombatActor
var neighbor: CombatActor
var upper: CombatActor
var hits: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	for first: StringName in GeometerGeometry.ELEMENTS:
		for second: StringName in GeometerGeometry.ELEMENTS:
			if first != second: _wall(first,second)
			for third: StringName in GeometerGeometry.ELEMENTS: _triangle(first,second,third)
	for skill: StringName in [&"geometer_translation",&"geometer_rewrite"]: _edit(skill)
	for triangle: bool in [false,true]: _collapse(triangle)
	for mode: String in ["fire","conduit","redirect","triangle"]: _owned_projectile(mode)
	_hostile_arrow(false)
	_hostile_arrow(true)
	_region_contract()
	for mode: String in ["pause","obstacle","epoch","expiry"]: _lifecycle(mode)
	_rank_gate()
	_cleanup()
	await process_frame
	print("E07 F1 Geometer full: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _setup(rank: int = 5, height: float = 16) -> void:
	_cleanup()
	var input := Fixture.make(); profile = input.traversal.to_data()
	for part: ExpeditionPartDefinition in input.parts:
		for surface: ExpeditionSurfaceDefinition in part.surfaces:
			for index: int in surface.vertices.size(): surface.vertices[index] = _scale(surface.vertices[index])
		for connector: ExpeditionConnectorDefinition in part.connectors: connector.position = _scale(connector.position); connector.width *= 3
		for socket: ExpeditionSocketDefinition in part.sockets: socket.position = _scale(socket.position)
		for index: int in part.solid_volumes.size():
			var volume: AABB = part.solid_volumes[index]; part.solid_volumes[index] = AABB(_scale(volume.position),_scale(volume.size))
	world = WorldGeometry.new(); check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"unchanged F0 assembles explicit two-floor recipe fixture")
	c = Controller.new(); root.add_child(c); owned.append(c); c.set_process(false); c.rng.seed = 711
	c.navigation.configure(Rect2(0,0,4000,4000),[],0)
	var build := BuildSnapshot.new(); build.character_id = "f1_geometer_full"; build.base_class_id = &"mage"; build.evolution_id = &"mg_ar"; build.base_level = 30; build.job_level = 40
	build.skill_ranks = {&"geometer_trace":1,&"geometer_triangulation":rank,&"geometer_translation":1,&"geometer_rewrite":1,&"geometer_collapse":1,&"geometer_incidence":1,&"fireball":1}
	Dependencies.complete_snapshot(build); build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(&"mage",&"mg_ar")
	c.run_state = RunState.from_build("f1_fixture",build); c.player = PlayerActor.new(); c.add_child(c.player); c.player.configure(c.navigation,c.run_state); c.player.set_process(false)
	check(c.player.bind_world_geometry(world,Fixture.point("root",Vector3(20,0,320)),profile,str(c.player.get_instance_id()))["ok"],"Geometer has explicit lower support and body")
	c.player.global_position = Vector2(-9000,9000)
	lower = _actor(Fixture.point("root",Vector3(110,0,380))); neighbor = _actor(Fixture.point("root",Vector3(150,0,380))); upper = _actor(Fixture.point("bridge",Vector3(110,40,380)))
	c.enemies.assign([lower,neighbor,upper])
	casting = GeometerCasting.new(); c.add_child(casting); casting.configure(c.player); casting.targets = c.enemies; c.geometer_casting = casting
	casting.hit.connect(func(request: DamageRequest,actor: CombatActor) -> void:
		hits.append({"id":actor.get_instance_id(),"request":request.copy()})
		c._on_attack_requested(request,actor))
	check(casting.bind_world_construction(height)["ok"],"figure height is explicit, not inferred from sprites")
	state = casting.construction as WorldGeometerConstruction
func _actor(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor); actor.set_process(false)
	actor.setup("Portador",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"target binds own authored support")
	actor.global_position = Vector2(9000,-9000)
	return actor
func _shoot(element: StringName, point: Vector3, third: bool = false) -> bool:
	var id := &"geometer_triangulation" if third else &"geometer_trace"
	c.player.mage_cooldowns[id] = 0
	check(casting.select(element),"intrinsic element selection remains canonical")
	var result := casting.begin_world_trace(id,Fixture.point("root",point),null,world.geometry_revision)
	check(result["ok"],"real explicit figure shot starts preparation: "+String(id))
	if not result["ok"]: return false
	c.player._advance_world_cast(10)
	check(c.player.world_cast_status()["ok"],"canonical release pays once and publishes real trace")
	for child: Node in casting.get_children():
		if child is GeometerTraceProjectile and not child.is_queued_for_deletion():
			child.set_process(false); child._process(0.5)
	return state.grammar.pending_count() == 0
func _wall(first: StringName,second: StringName) -> void:
	_setup()
	_move(lower,Fixture.point("root",Vector3(120,0,300)))
	_move(neighbor,Fixture.point("root",Vector3(150,0,350)))
	check(_shoot(first,A) and _shoot(second,B) and state.shape == GeometerConstructionState.Shape.WALL and state.has_active_figure(),"ordered mixed wall forms spatially: %s/%s" % [first,second])
	if not state.has_active_figure(): return
	hits.clear(); var hp := lower.health.current_hp; var upper_hp := upper.health.current_hp
	_move(lower,Fixture.point("root",Vector3(120,0,380)))
	var damages := first == &"fire" or second == &"fire"
	check((lower.health.current_hp < hp) == damages,"wall preserves nominal crossing damage recipe")
	check((lower.slow_fraction > 0) == (first == &"ice"),"wall preserves ordered ice slow recipe")
	check(upper.health.current_hp == upper_hp and not hits.any(func(item: Dictionary) -> bool: return item["id"] == upper.get_instance_id()),"projected upper-floor body never receives lower wall pulse")
	var count := hits.size(); _move(lower,Fixture.point("root",Vector3(120,0,300)))
	check(hits.size() == count,"shared two-second victim claim prevents immediate recross duplication")
	casting.advance(2.1); hp = lower.health.current_hp; _move(lower,Fixture.point("root",Vector3(120,0,380)))
	check((lower.health.current_hp < hp) == damages,"victim window reopens on original finite clock")
func _triangle(first: StringName,second: StringName,third: StringName) -> void:
	_setup()
	check(_shoot(first,A) and _shoot(second,B) and _shoot(third,C,true),"ordered recipe commits three real spatial shots: %s/%s/%s" % [first,second,third])
	check(state.shape == GeometerConstructionState.Shape.TRIANGLE and state.has_active_figure(),"all27 recipes retain canonical triangle classification")
	if not state.has_active_figure(): return
	var closure := hits.filter(func(item: Dictionary) -> bool: return String((item["request"] as DamageRequest).skill_id).begins_with("geometer_resolution_"))
	check(closure.size() == 2 and not hits.any(func(item: Dictionary) -> bool: return item["id"] == upper.get_instance_id()),"C resolves exactly once per lower occupant, never projected upper floor")
	check((lower.root_remaining() > 0) == (third == &"ice"),"C ice retains canonical hard control")
	for item: Dictionary in closure:
		var request := item["request"] as DamageRequest
		check(request.is_secondary and request.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and not request.can_crit,"C retains secondary geometry request and root snapshot")
	hits.clear(); casting.advance(0.99)
	check(hits.is_empty(),"maintenance never fires before one-second phase")
	casting.advance(0.02)
	var burns := first == &"fire" or second == &"fire"
	check(hits.size() == (2 if burns else 0),"A/B share one maintenance request per victim, no damage for lightning-only foundation")
	var slow := 0.20 if second == &"ice" else (0.10 if first == &"ice" else 0.0)
	check(is_equal_approx(lower.slow_fraction,slow),"A/B movement slow takes canonical maximum")
	var before := hits.size(); casting.advance(3)
	check(hits.size() == before+(2 if burns else 0),"large delta discards missed ticks rather than catch-up damage")
func _edit(skill: StringName) -> void:
	_setup()
	check(_shoot(&"fire",A) and _shoot(&"ice",B) and _shoot(&"fire",C,true),"edit fixture forms actual triangle")
	if not state.has_active_figure(): return
	casting.advance(0.4); var identity := state.construction_id; var remaining := state.figure_remaining
	var sp := c.player.current_sp; hits.clear(); casting.select(&"ice")
	if skill == &"geometer_rewrite":
		var rejected := casting.begin_world_trace(skill,Fixture.point("root",Vector3(90,0,490)),null,world.geometry_revision)
		check(not rejected["ok"] and c.player.current_sp == sp and state.construction_id == identity and state.figure_remaining == remaining,"collinear rewrite is free and leaves construction untouched")
	var accepted := casting.begin_world_trace(skill,Fixture.point("root",Vector3(90,0,470)),null,world.geometry_revision)
	check(accepted["ok"],"explicit spatial edit accepted")
	if c.player.has_active_cast(): c.player._advance_world_cast(10)
	check(c.player.world_cast_status()["ok"] and state.construction_id == identity and state.figure_remaining == remaining and hits.is_empty(),"edit preserves identity/clock and never replays C")
	check(is_equal_approx(c.player.current_sp,sp-c.player.skill_cost(skill)) and state.world_points()[-1].position == Vector3(90,0,470),"edit pays nominal resource and commits explicit new support")
	check(state.elements()[-1] == (&"ice" if skill == &"geometer_rewrite" else &"fire"),"translation preserves moved element; rewrite uses captured selection")
func _collapse(triangle: bool) -> void:
	_setup()
	check(_shoot(&"fire",A) and _shoot(&"ice",B),"collapse forms wall")
	if triangle: check(_shoot(&"fire",C,true),"collapse forms triangle")
	var sp := c.player.current_sp; hits.clear()
	var result := casting.begin_world_trace(&"geometer_collapse",null,null,world.geometry_revision)
	check(result["ok"],"collapse explicit command accepted without a guessed ground click")
	if c.player.has_active_cast(): c.player._advance_world_cast(10)
	check(c.player.world_cast_status()["ok"] and state.vertices.is_empty() and state.grammar.pending_count() == 0 and is_equal_approx(c.player.current_sp,sp-c.player.skill_cost(&"geometer_collapse")),"collapse consumes construction and pays canonical resource exactly once")
	check(hits.size() == (2 if triangle else 0),"captured collapse footprint uses original support after clear")
	var count := hits.size(); result = casting.begin_world_trace(&"geometer_collapse",null,null,world.geometry_revision)
	check(not result["ok"] and hits.size() == count,"consumed construction cannot collapse again")
func _owned_projectile(mode: String) -> void:
	_setup()
	var first := &"lightning" if mode == "conduit" or mode == "triangle" else &"fire"
	var second := &"lightning" if mode == "redirect" or mode == "triangle" else &"fire"
	if mode == "fire": first = &"ice"
	if mode == "conduit": second = &"fire"
	check(_shoot(first,A) and _shoot(second,B),"projectile fixture forms actual wall/preparation")
	if mode == "triangle": check(_shoot(&"lightning",C,true),"projectile fixture closes lightning triangle")
	_move(c.player,Fixture.point("root",Vector3(120,0,300)))
	_move(lower,Fixture.point("root",Vector3(240 if mode == "conduit" or mode == "redirect" else 120,0,420)))
	_move(neighbor,Fixture.point("root",Vector3(250 if mode == "conduit" or mode == "redirect" else 150,0,420)))
	var origin := c.player.world_point(); var direction := Vector3.BACK
	if mode == "triangle":
		origin = Fixture.point("root",Vector3(90,0,380)); direction = Vector3.RIGHT
		_move(lower,Fixture.point("root",Vector3(110,0,380))); _move(neighbor,Fixture.point("root",Vector3(150,0,380)))
	_move(c.player,origin)
	c.player.mage_projectile_requested.connect(c._on_mage_projectile_requested)
	var cast := c.cast_world_skill(&"fireball",null,direction,null,world.geometry_revision)
	check(cast["ok"],"real canonical Fireball cast admits the spatial interceptor")
	if c.player.has_active_cast(): c.player._advance_world_cast(10)
	var shot: MageProjectile
	for child: Node in c.get_children():
		if child is MageProjectile and child.world_flight != null and not child.is_queued_for_deletion(): shot = child; shot.set_process(false)
	check(shot != null and shot.geometer_field == casting.wall_field,"real handler publishes bound Mage projectile and field reference")
	if shot == null: return
	var hp := lower.health.current_hp; hits.clear(); shot._process(1)
	check(lower.health.current_hp < hp and shot.is_queued_for_deletion(),"actual field-transformed projectile reaches finite primary impact: "+mode)
	check(not hits.any(func(item: Dictionary) -> bool: return item["id"] == upper.get_instance_id()),"projectile payload never spills to projected upper floor")
	if mode == "conduit" or mode == "redirect": check(casting.interaction_ledger.projectile_claimed(shot.get_instance_id(),GeometerInteractionLedger.Component.TRANSPORT),"transport claimed once per projectile")
	if mode == "fire" or mode == "conduit": check(casting.interaction_ledger.projectile_claimed(shot.get_instance_id(),GeometerInteractionLedger.Component.FIRE_EXIT),"fire exit payload claimed once per projectile")
	if mode == "triangle":
		check(casting.interaction_ledger.projectile_claimed(shot.get_instance_id(),GeometerInteractionLedger.Component.LIGHTNING_FOUNDATION) and casting.interaction_ledger.projectile_claimed(shot.get_instance_id(),GeometerInteractionLedger.Component.LIGHTNING_RULE),"inside-born projectile captures both lightning components before body impact")
		check(hits.size() == 2,"triangle projectile contributes one foundation hit and one bounded neighbor arc")
func _hostile_arrow(high: bool) -> void:
	_setup()
	check(_shoot(&"fire",A) and _shoot(&"ice",B),"hostile interception uses real ordered ice-exit wall")
	_move(c.player,Fixture.point("root",Vector3(120,0,380)))
	var request := DamageRequest.new(); request.source_id = lower.get_instance_id(); request.magic_damage = 40; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; request.can_crit = false
	var shot := ArrowProjectile.new(); shot.configure(request,c.player,Vector2.ZERO,c.navigation); shot.geometer_field = casting.wall_field; c.add_child(shot); shot.set_process(false); shot.hit.connect(c._on_attack_requested)
	check(shot.bind_world_flight(world,Fixture.point("root",Vector3(120,0,300)),Vector3.UP*(25 if high else 3),Vector3.BACK,{"radius":3.0,"height":6.0},world.geometry_revision)["ok"],"hostile Arrow uses explicit world body/height")
	var hp := c.player.health.current_hp; var sp := c.player.current_sp; shot._process(0.3)
	check(c.player.health.current_hp == hp,"ice exit intercepts low Arrow; high Arrow stays above target body")
	check((c.player.current_sp > sp) == not high,"incidence refund claims only a real in-height interception")
func _region_contract() -> void:
	_setup()
	var tri := PackedVector2Array([Vector2(360,60),Vector2(540,60),Vector2(360,240)])
	var query := world.ground_region(Fixture.point("slope",Vector3(360,8,60)),tri,profile,world.geometry_revision)
	check(query["ok"],"region follows authored ramp plane rather than flattening y")
	if query["ok"]:
		var point := Fixture.point("slope",Vector3(390,12,100))
		check(WorldSupportRegion.ground_contains(query["data"],point),"region membership retains ramp support and exact height")
		point.position.y = 0; check(not WorldSupportRegion.ground_contains(query["data"],point),"same x/z at wrong height is never membership")
	var polygon := PackedVector2Array([Vector2(A.x,A.z),Vector2(B.x,B.z),Vector2(C.x,C.z)])
	check(world.ground_region(Fixture.point("root",A),polygon,profile,world.geometry_revision)["ok"],"lower triangle ignores overhead slab when height fits")
	check(world.insert_obstacle("inside",AABB(Vector3(90,0,410),Vector3(5,20,5)),world.geometry_revision)["ok"],"small internal obstacle installs away from vertices and actors")
	check(not world.ground_region(Fixture.point("root",A),polygon,profile,world.geometry_revision)["ok"],"interior blocker invalidates region even if all three edges stay clear")
func _lifecycle(mode: String) -> void:
	_setup()
	check(_shoot(&"fire",A) and _shoot(&"ice",B) and _shoot(&"fire",C,true),"lifecycle fixture forms spatial triangle")
	if not state.has_active_figure(): return
	hits.clear(); var remaining := state.figure_remaining
	match mode:
		"pause": paused = true; casting.advance(2); paused = false; check(state.figure_remaining == remaining and hits.is_empty(),"pause freezes both construction and maintenance")
		"obstacle":
			check(world.insert_obstacle("inside",AABB(Vector3(90,0,410),Vector3(5,20,5)),world.geometry_revision)["ok"],"dynamic interior blocker installs")
			casting.advance(1); check(state.suspended and hits.is_empty(),"new interior geometry suspends without damage")
			world.remove_obstacle("inside",world.geometry_revision); casting.advance(0.1); check(not state.suspended and hits.is_empty(),"resume never replays C or catches up skipped maintenance")
		"epoch":
			world.configuration_revision += 1; casting.advance(1); check(state.vertices.is_empty() and hits.is_empty(),"epoch invalidates old figure and maintenance")
		"expiry": casting.advance(7); check(state.vertices.is_empty() and hits.is_empty(),"expired figure clears before scheduled late tick")
func _rank_gate() -> void:
	_setup(1)
	check(_shoot(&"fire",A) and _shoot(&"ice",B),"rank gate has two mixed anchors")
	var sp := c.player.current_sp
	var result := casting.begin_world_trace(&"geometer_triangulation",Fixture.point("root",C),null,world.geometry_revision)
	check(not result["ok"] and c.player.current_sp == sp,"rank1 rejects mixed recipe before payment; canonical required rank preserved")
func _move(actor: CombatActor,point: ExpeditionWorldPoint) -> void:
	check(actor.move_world_to(point,world.geometry_revision)["ok"] and actor.advance_world(2000)["ok"],"actor follows actual supported route")
func _scale(point: Vector3) -> Vector3: return Vector3(point.x*3,point.y,point.z*3)
func _cleanup() -> void:
	paused = false
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	owned.clear(); hits.clear()
