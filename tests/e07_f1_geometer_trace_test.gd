extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Spatial = preload("res://tools/content/spatial_bundle.gd")
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
const ID := &"geometer_trace"
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
var target: CombatActor
var bystander: CombatActor
var input: ExpeditionGenerationInput
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	for rank: int in [1,5]:
		_nominal(rank)
		_carrier(rank)
	_fifo()
	_fifo_timeout()
	_suspension()
	_pending_death()
	for reason: String in ["sp","stun","pause","build","revision","move","clear","owner","death","epoch"]: _cancel(reason)
	for reason: String in ["point","floor","range","slab","wall","element","recipe","third","legacy","incompatible","slots"]: _invalid(reason)
	for reason: String in ["wall","death","caster","epoch","pause","clear","range","timeout","free"]: _flight(reason)
	_upper_support()
	_fixed_anchor()
	_true_range()
	_support_edges()
	_expiry()
	_reentrant()
	_cleanup()
	await process_frame
	print("E07 F1 Geometer trace: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _setup(rank: int = 1) -> void:
	_cleanup()
	input = Fixture.make(); profile = input.traversal.to_data()
	world = WorldGeometry.new()
	check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"unmodified F0 assembly supplies trace fixture")
	c = Controller.new(); root.add_child(c); owned.append(c); c.set_process(false)
	c.navigation.configure(Rect2(0,0,1400,1000),[],0); c.rng.seed = 711
	var build := BuildSnapshot.new(); build.character_id = "f1_geometer"; build.base_class_id = &"mage"; build.evolution_id = &"mg_ar"; build.base_level = 30; build.job_level = 40; build.skill_ranks = {ID:rank,&"geometer_triangulation":5}
	Dependencies.complete_snapshot(build)
	build.library_skill_ids = [ID,&"geometer_triangulation"]
	build.active_slots = [ID,&"geometer_triangulation",null,null,null]
	c.run_state = RunState.from_build("f1_fixture",build)
	c.player = PlayerActor.new(); c.add_child(c.player); c.player.configure(c.navigation,c.run_state); c.player.set_process(false)
	check(c.player.bind_world_geometry(world,Fixture.point("root",Vector3(20,0,50)),profile,str(c.player.get_instance_id()))["ok"],"actual Geometer binds explicit support")
	c.player.global_position = Vector2(-9999,8888) # Deliberately unrelated display coordinates.
	target = _actor(Fixture.point("root",Vector3(70,0,80)))
	bystander = _actor(Fixture.point("root",Vector3(45,0,65)))
	c.enemies.assign([target,bystander])
	casting = GeometerCasting.new(); c.add_child(casting); casting.configure(c.player); casting.targets = c.enemies
	c.geometer_casting = casting
	casting.hit.connect(c._on_attack_requested)
	check(casting.bind_world_construction()["ok"],"real consumer installs spatial grammar adapter")
	state = casting.construction as WorldGeometerConstruction
func _actor(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor)
	actor.setup("Portador",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000; actor.set_process(false)
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"actor has explicit point and finite body")
	actor.global_position = Vector2(10000,-10000)
	return actor
func _shoot(point: ExpeditionWorldPoint, victim: CombatActor = null) -> GeometerTraceProjectile:
	# Closed choreography only; production still pays nominal cooldown on every accepted launch.
	c.player.mage_cooldowns[ID] = 0.0
	var result := casting.begin_world_trace(ID,point,victim,world.geometry_revision)
	check(result["ok"],"explicit world intent enters actual preparation")
	if not result["ok"]: return null
	c.player._advance_world_cast(10)
	check(c.player.world_cast_status()["ok"],"actual canonical release commits")
	for child: Node in casting.get_children():
		if child is GeometerTraceProjectile and not child.is_queued_for_deletion() and child.ticket == int(state.grammar.pending_snapshot()[-1]["ticket"]):
			child.set_process(false); return child as GeometerTraceProjectile
	check(false,"release must publish finite world flight"); return null
func _nominal(rank: int) -> void:
	_setup(rank)
	var point := Fixture.point("root",Vector3(70,0,30)); var sp := c.player.current_sp; var revision := world.geometry_revision
	var preview := casting.preview_world_trace(ID,point,null,revision)
	check(preview["ok"] and state.vertices.is_empty() and state.grammar.pending_count() == 0 and c.player.current_sp == sp and world.geometry_revision == revision,"preview never reserves or pays")
	if preview["ok"]: preview["data"]["point"]["position"] = Vector3(9000,9000,9000)
	var began := casting.begin_world_trace(ID,point,null,revision)
	check(began["ok"] and c.player.has_active_cast() and c.player.current_sp == sp and state.grammar.pending_count() == 0,"preparation is free")
	casting.select(&"ice")
	point.position = Vector3(999,999,999)
	c.player._advance_world_cast(10)
	check(c.player.world_cast_status()["ok"],"caller mutation cannot alter captured intent")
	var flight := _latest(); check(flight != null and flight.world_flight != null,"actual trace node binds shared continuous flight")
	if flight == null: return
	check(is_equal_approx(c.player.current_sp,sp-c.player.skill_cost(ID)) and c.player.skill_cooldown(ID) > 0.0,"rank pays canonical SP and cooldown once")
	var hp := bystander.health.current_hp
	flight._process(0.5)
	check(flight.is_queued_for_deletion() and state.vertices.size() == 1 and state.grammar.pending_count() == 0,"ground arrival confirms one finite vertex")
	if state.vertices.is_empty(): return
	check(state.world_points()[0].to_data() == Fixture.point("root",Vector3(70,0,30)).to_data() and state.vertices[0].actor_id == 0 and state.vertices[0].element == &"fire","anchor retains exact surface, height and selected element before preparation")
	check(bystander.health.current_hp == hp,"ground trace ignores unselected bodies")
	var exposed := state.world_points(); exposed[0].position = Vector3.INF
	check(state.world_points()[0].position.is_finite(),"world point snapshots cannot mutate construction")
	var ticket := flight.ticket
	casting._on_delivered(ticket,true,Vector2(70,30),target,flight)
	check(state.vertices.size() == 1 and target.health.current_hp == 100000,"legacy callback cannot claim a bound world ticket")
	casting._on_world_delivered(ticket,true,Fixture.point("root",Vector3(80,0,30)),target,flight)
	check(state.vertices.size() == 1 and target.health.current_hp == 100000,"duplicate or late delivery cannot damage or append")
	casting.select(&"fire")
	var second := _shoot(Fixture.point("root",Vector3(70,0,80)))
	if second != null: second._process(0.5)
	check(state.shape == GeometerConstructionState.Shape.PREPARATION and state.vertices.size() == 2 and not state.has_active_figure(),"same-element second anchor preserves canonical preparation shape without field effects")
func _carrier(rank: int) -> void:
	_setup(rank)
	var hp := target.health.current_hp; var untouched := bystander.health.current_hp
	var flight := _shoot(null,target)
	if flight == null: return
	var power := flight.request.magic_damage
	check(power > 0.0 and flight.request.skill_id == ID and flight.request.source_id == c.player.get_instance_id(),"trace keeps canonical rank power and source request")
	flight._process(0.5)
	check(target.health.current_hp < hp and bystander.health.current_hp == untouched and state.vertices.size() == 1,"selected actor receives real damage; body in front is ignored")
	if state.vertices.is_empty(): return
	check(state.vertices[0].actor_id == target.get_instance_id(),"successful selected impact captures carrier identity")
	check(target.world_motion.displace(Fixture.point("root",Vector3(80,0,80)),20,world.geometry_revision)["ok"],"carrier walks through actual spatial motion")
	casting.advance(0.25)
	check(state.world_points()[0].to_data() == target.world_point().to_data() and is_equal_approx(state.vertices[0].remaining,7.75),"anchor follows actual carrier and canonical clock")
	var last := state.world_points()[0].to_data()
	target.health.current_hp = 0
	casting.advance(0.1)
	check(state.vertices[0].actor_id == 0 and state.world_points()[0].to_data() == last,"dead carrier detaches at last valid explicit support")
	var current := state.vertices[0].remaining
	paused = true; casting.advance(5); flight._process(5); paused = false
	check(state.vertices[0].remaining == current,"pause freezes anchor and flight clocks")
func _fifo() -> void:
	_setup()
	var first := _shoot(Fixture.point("root",Vector3(70,0,30)))
	var second := _shoot(null,target)
	if first == null or second == null: return
	second._process(0.5)
	check(state.vertices.is_empty() and state.grammar.pending_count() == 2,"later impact waits for earlier flight")
	check(target.world_motion.displace(Fixture.point("root",Vector3(80,0,80)),20,world.geometry_revision)["ok"],"confirmed waiting impact carrier can move")
	casting.advance(0.4)
	first._process(0.5)
	check(state.vertices.size() == 2 and state.grammar.pending_count() == 0,"FIFO commits both in launch order")
	if state.vertices.size() != 2: return
	check(state.world_points()[0].position == Vector3(70,0,30) and state.world_points()[1].to_data() == target.world_point().to_data(),"FIFO carries each explicit support rather than callback order")
	check(is_equal_approx(state.vertices[1].remaining,7.6) and is_equal_approx(state.vertices[0].remaining,8.0),"waiting confirmed impact ages without refreshing lifetime")
func _fifo_timeout() -> void:
	_setup()
	var first := _shoot(Fixture.point("root",Vector3(70,0,30))); var second := _shoot(null,target)
	if first == null or second == null: return
	second._process(0.5)
	casting.advance(3.1)
	check(first.is_queued_for_deletion() and state.grammar.pending_count() == 0 and state.vertices.size() == 1,"canonical timeout drains failed FIFO head and retires its flight")
	if state.vertices.size() != 1: return
	check(state.world_points()[0].to_data() == target.world_point().to_data() and is_equal_approx(state.vertices[0].remaining,4.9),"waiting confirmed impact preserves support and elapsed lifetime across earlier timeout")
	var hp := target.health.current_hp
	casting._on_world_delivered(first.ticket,true,target.world_point(),target,first)
	check(target.health.current_hp == hp and state.vertices.size() == 1,"timed-out head cannot replay damage or replace confirmed anchor")
func _suspension() -> void:
	_setup()
	var first := _shoot(Fixture.point("root",Vector3(70,0,30))); if first != null: first._process(0.5)
	var second := _shoot(null,target); if second != null: second._process(0.5)
	check(state.vertices.size() == 2 and not state.suspended,"two supported preparation anchors are initially valid")
	if state.vertices.size() != 2: return
	var identity := state.construction_id; var remaining := state.vertices[0].remaining
	check(world.insert_obstacle("edge-wall",AABB(Vector3(60,0,52),Vector3(20,25,4)),world.geometry_revision)["ok"],"edge obstacle installs without disconnecting protected authored sockets")
	casting.advance(0.1)
	check(state.suspended and state.construction_id == identity and is_equal_approx(state.vertices[0].remaining,remaining-0.1),"changed geometry suspends exact edge without identity/clock reset")
	check(world.remove_obstacle("edge-wall",world.geometry_revision)["ok"],"same obstacle authority removes edge occlusion")
	casting.advance(0.1)
	check(not state.suspended and state.construction_id == identity and is_equal_approx(state.vertices[0].remaining,remaining-0.2),"edge resumes without formation replay, relocation or lifetime refresh")
func _pending_death() -> void:
	_setup()
	var first := _shoot(Fixture.point("root",Vector3(70,0,30))); var second := _shoot(null,target)
	if first == null or second == null: return
	second._process(0.5); casting.advance(0.2)
	var last := target.world_point().to_data(); target.free()
	casting.advance(0.2); first._process(0.5)
	check(state.vertices.size() == 2 and state.vertices[1].actor_id == 0 and state.world_points()[1].to_data() == last,"freed waiting carrier retains last real ground through FIFO")
func _cancel(reason: String) -> void:
	_setup()
	var sp := c.player.current_sp
	check(casting.begin_world_trace(ID,null,target,world.geometry_revision)["ok"],"cancel scenario starts free preparation")
	match reason:
		"sp": c.player.current_sp = 0; sp = 0
		"stun": c.player.apply_stun(1)
		"pause": paused = true
		"build": c.run_state.build_snapshot.skill_ranks.erase(ID); c.player.apply_run_modifiers(c.run_state)
		"revision": world.geometry_revision += 1
		"move": c.player.world_motion.displace(Fixture.point("root",Vector3(25,0,50)),10,world.geometry_revision)
		"clear": casting.clear_construction()
		"owner": casting.queue_free()
		"death": target.health.current_hp = 0
		"epoch": world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")
	c.player._advance_world_cast(10)
	if reason == "pause": paused = false
	check(not c.player.world_cast_status()["ok"] and c.player.current_sp == sp and c.player.skill_cooldown(ID) <= 0.0 and state.grammar.pending_count() == 0,"commit revalidates %s before resource/root/reservation" % reason)
func _invalid(reason: String) -> void:
	_setup()
	var point := Fixture.point("root",Vector3(70,0,30)); var victim: CombatActor
	match reason:
		"point": point.position.y = NAN
		"floor": point.surface_id = "missing"
		"range": point = Fixture.point("landing",Vector3(290,40,50)); c.player.push_cast_rank(ID,1); point.position.x = 999
		"slab": point = Fixture.point("bridge",Vector3(50,40,150))
		"wall": check(world.insert_obstacle("trace-wall",AABB(Vector3(35,0,20),Vector3(3,25,70)),world.geometry_revision)["ok"],"authored wall really installs before admission")
		"element": state.grammar.selected_element = &"invalid"
		"recipe":
			var flight := _shoot(Fixture.point("root",Vector3(70,0,30))); if flight != null: flight._process(0.5)
			c.player.mage_cooldowns[ID] = 0; casting.select(&"ice"); point = Fixture.point("root",Vector3(70,0,80))
		"third": pass
		"legacy": pass
		"incompatible": target.world_motion = null; victim = target
		"slots": pass
	var sp := c.player.current_sp; var count := state.grammar.pending_count(); var slots: Array[Node] = []
	if reason == "slots":
		for index: int in 128:
			var slot := Node.new(); root.add_child(slot); slot.add_to_group("player_projectiles"); slots.append(slot)
	var result := casting.begin_world_trace(&"geometer_triangulation" if reason == "third" else ID,point,victim,world.geometry_revision)
	if reason == "legacy":
		var command := GeometerCastCommand.new(); command.skill_id = ID; command.point = Vector2(70,30)
		result = c.player.geometer_shot_check(command,state,c.enemies)
	check(not result["ok"] and c.player.current_sp == sp and state.grammar.pending_count() == count,"invalid %s is free and never falls back to screen coordinates" % reason)
	for slot: Node in slots: slot.free()
func _flight(reason: String) -> void:
	_setup()
	var flight := _shoot(null,target)
	if flight == null: return
	var hp := target.health.current_hp; var initial := flight.world_flight.position
	match reason:
		"wall": check(world.insert_obstacle("late-wall",AABB(Vector3(35,0,20),Vector3(3,25,70)),world.geometry_revision)["ok"],"new solid really installs during flight")
		"death": target.health.current_hp = 0; hp = 0
		"caster": c.player.health.current_hp = 0
		"epoch": world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")
		"pause": paused = true
		"clear": casting.clear_construction()
		"range": flight.world_flight.max_distance = 1 # Closed flight exhaustion, no rank/catalog edits.
		"timeout": flight.remaining = 0.001
		"free": target.free()
	flight._process(0.5)
	if reason == "pause":
		check(flight.world_flight.position == initial and flight.remaining == 3 and not flight.is_queued_for_deletion(),"pause preserves actual world flight and timeout")
		paused = false; flight._process(-1); flight._process(NAN); flight._process(0)
		check(flight.world_flight.position == initial and flight.remaining == 3,"invalid/zero deltas never move or age trace")
	else:
		check(flight.is_queued_for_deletion() and (not is_instance_valid(target) or target.health.current_hp == hp) and state.vertices.is_empty(),"in-flight %s cannot leave damaging late vertex" % reason)
func _upper_support() -> void:
	_setup()
	check(c.player.move_world_to(Fixture.point("bridge",Vector3(70,40,150)),world.geometry_revision)["ok"] and c.player.advance_world(1000)["ok"],"caster reaches upper floor through actual ramp/bridge route")
	var flight := _shoot(Fixture.point("bridge",Vector3(20,40,150)))
	if flight != null: flight._process(0.5)
	check(state.vertices.size() == 1 and state.world_points()[0].surface_id == Fixture.point("bridge",Vector3.ZERO).surface_id and state.world_points()[0].position.y == 40,"upper-floor ground trace commits authored support with unrelated screen positions")
	casting.clear_construction()
	var upper := _actor(Fixture.point("bridge",Vector3(40,40,150))); c.enemies.append(upper); casting.targets = c.enemies
	flight = _shoot(null,upper)
	if flight == null: return
	flight._process(0.5)
	check(state.vertices.size() == 1 and state.vertices[0].actor_id == upper.get_instance_id(),"upper selected body can carry explicit anchor")
	check(upper.move_world_to(Fixture.point("root",Vector3(50,0,150)),world.geometry_revision)["ok"] and upper.advance_world(1000)["ok"],"carrier changes floor by real supported travel")
	casting.advance(0.1)
	check(state.world_points()[0].surface_id == Fixture.point("root",Vector3.ZERO).surface_id and state.world_points()[0].position.y == 0,"anchor follows carrier to exact lower support without nearest-floor selection")
	upper.free(); casting.advance(0.1)
	check(state.vertices[0].actor_id == 0 and state.world_points()[0].position == Vector3(50,0,150),"freed carrier retains last valid lower support after floor transition")
func _fixed_anchor() -> void:
	_setup()
	var entries: Array[Dictionary] = Spatial.entries(); var prepared := ContentAuthoring.prepare(entries)
	check(prepared["ok"],"authored spatial augment bundle prepares unchanged")
	if not prepared["ok"]: return
	var compiled := ContentAuthoring.compile_bundle(entries,prepared["text_template"],false)
	check(compiled["ok"],"authored spatial augment catalog compiles")
	if not compiled["ok"]: return
	c.run_state.augment_stacks[&"geometer_ground_anchor"] = 1
	check(c.run_state.set_effect_catalog(compiled["catalog"])["ok"],"real composed policy admits Geometer ground anchor")
	c.player.apply_run_modifiers(c.run_state)
	var flight := _shoot(null,target)
	if flight == null: return
	check(bool(flight.request.effect_snapshot["kit_policies"].get(&"geometer_ground_anchor",false)),"real request captures ground policy")
	c.run_state.augment_stacks.erase(&"geometer_ground_anchor"); c.run_state.runtime_revision += 1; c.player.apply_run_modifiers(c.run_state)
	check(target.world_motion.displace(Fixture.point("root",Vector3(80,0,80)),20,world.geometry_revision)["ok"],"fixed-mode projectile still homes on actual moving target")
	flight._process(0.5)
	check(state.vertices.size() == 1 and state.vertices[0].actor_id == 0 and state.world_points()[0].position == Vector3(80,0,80),"removing policy after launch preserves fixed anchor at real impact ground")
	check(target.world_motion.displace(Fixture.point("root",Vector3(80,0,90)),20,world.geometry_revision)["ok"],"carrier can leave fixed impact")
	casting.advance(0.2)
	check(state.world_points()[0].position == Vector3(80,0,80),"captured fixed ground never follows later carrier motion")
func _true_range() -> void:
	_setup()
	# Larger technical supports, authored before unchanged assembly. No production/map content change.
	for part: ExpeditionPartDefinition in input.parts:
		for surface: ExpeditionSurfaceDefinition in part.surfaces:
			for index: int in surface.vertices.size(): surface.vertices[index] = _scale(surface.vertices[index])
		for connector: ExpeditionConnectorDefinition in part.connectors: connector.position = _scale(connector.position); connector.width *= 4
		for socket: ExpeditionSocketDefinition in part.sockets: socket.position = _scale(socket.position)
		for index: int in part.solid_volumes.size():
			var volume := part.solid_volumes[index]; part.solid_volumes[index] = AABB(_scale(volume.position),_scale(volume.size))
	check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"large technical fixture assembles from untouched F0")
	check(c.player.world_motion.configure(world,Fixture.point("root",Vector3(80,0,200)),profile,str(c.player.get_instance_id()))["ok"],"range scenario explicitly rebinds caster after epoch")
	check(target.world_motion.configure(world,Fixture.point("root",Vector3(280,0,320)),profile,str(target.get_instance_id()))["ok"] and bystander.world_motion.configure(world,Fixture.point("root",Vector3(180,0,260)),profile,str(bystander.get_instance_id()))["ok"],"range scenario explicitly rebinds target bodies")
	state.configure(world,profile)
	var sp := c.player.current_sp
	var far := casting.preview_world_trace(ID,Fixture.point("root",Vector3(390,0,790)),null,world.geometry_revision)
	check(not far["ok"] and far["error_code"] == &"out_of_range_or_occluded" and c.player.current_sp == sp,"valid supported point outside canonical600 range is free")
	var flight := _shoot(Fixture.point("root",Vector3(80,0,790)))
	if flight != null: flight._process(0.7)
	check(state.vertices.size() == 1 and state.world_points()[0].position == Vector3(80,0,790),"actual590-unit trace arrives without truncation or screen-space range")
func _scale(point: Vector3) -> Vector3: return Vector3(point.x*4,point.y,point.z*4)
func _support_edges() -> void:
	_setup()
	var a := Fixture.point("root",Vector3(80,0,50)); var b := Fixture.point("landing",Vector3(220,40,50))
	var edge := world.ground_line_to(a,b,profile,world.geometry_revision)
	check(edge["ok"] and edge["data"]["cost"] > a.position.distance_to(b.position),"straight supported edge measures actual ramp travel rather than chord")
	if edge["ok"]:
		edge["data"]["points"][0]["position"] = Vector3.INF
		check(world.ground_line_to(a,b,profile,world.geometry_revision)["ok"],"edge route is copied")
	check(not world.ground_line_to(Fixture.point("root",Vector3(50,0,150)),Fixture.point("bridge",Vector3(50,40,150)),profile,world.geometry_revision)["ok"],"same x/z on another floor cannot be repaired or inferred")
	check(not world.ground_line_to(a,b,{},world.geometry_revision)["ok"] and not world.ground_line_to(a,b,profile,world.geometry_revision-1)["ok"],"edge validates profile and revision")
func _expiry() -> void:
	_setup()
	var first := _shoot(Fixture.point("root",Vector3(70,0,30))); if first != null: first._process(0.5)
	var flight := _shoot(null,target)
	if flight == null: return
	state.vertices[0].remaining = 0.1
	casting.advance(0.2)
	var hp := target.health.current_hp
	casting._on_world_delivered(flight.ticket,true,target.world_point(),target,flight)
	check(state.vertices.is_empty() and state.grammar.pending_count() == 0 and flight.is_queued_for_deletion() and target.health.current_hp == hp,"vertex expiry cancels pending flights and rejects late callbacks")
func _reentrant() -> void:
	_setup()
	var flight := _shoot(null,target)
	if flight == null: return
	var callbacks := [0]
	casting.hit.connect(func(_request: DamageRequest,_victim: CombatActor) -> void:
		callbacks[0] += 1
		check(state.grammar.pending_count() == 0 and state.vertices.size() == 1,"ticket and anchor commit before damage callbacks")
		casting.clear_construction()
		casting._on_world_delivered(flight.ticket,true,target.world_point(),target,flight))
	flight._process(0.5)
	check(callbacks[0] == 1 and state.vertices.is_empty() and state.grammar.pending_count() == 0,"reentrant clear/duplicate never reconstructs or damages twice")
func _latest() -> GeometerTraceProjectile:
	for child: Node in casting.get_children():
		if child is GeometerTraceProjectile and not child.is_queued_for_deletion(): child.set_process(false); return child as GeometerTraceProjectile
	return null
func _cleanup() -> void:
	paused = false
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	owned.clear()
