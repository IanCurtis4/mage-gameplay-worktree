extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
const IDS: Array[StringName] = [&"fire_wall",&"lightning_wall",&"phantom_barrier"]
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
var inside: CombatActor
var center := Vector3.ZERO
var normal := Vector3.RIGHT
var contact := Vector3.ZERO
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	for id: StringName in IDS:
		for rank: int in [1,5]: _nominal(id,rank)
		for reason: String in ["height","nan","direction","sp","stun","pause","stale","edge","ceiling"]: _invalid(id,reason)
		for mode: String in ["pause","epoch","removed","build"]: _late(id,mode)
		_oblique(id)
		_zero_delta(id)
	_fire_multi()
	_cadence()
	_motion()
	_barrier_arrows(1)
	_barrier_arrows(12)
	_capsule()
	_destructive()
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 ground fields: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _nominal(id: StringName,rank: int) -> void:
	_setup(id,rank)
	var before := c.player.current_sp; var cooldown := c.player.skill_cooldown(id)
	var preview := c.player.preview_world_skill(id,null,normal,null,c.enemies,world.geometry_revision,0,12)
	check(preview["ok"] and c.player.current_sp == before and not c.player.has_active_cast() and c.player.skill_cooldown(id) == cooldown,"field preview is pure: "+String(id))
	if not preview["ok"]: return
	check(preview["data"]["field"]["anchor"]["position"].is_equal_approx(center) and preview["data"]["field"]["height"] == 12,"preflight captures nominal range on exact logical support and explicit height")
	preview["data"]["field"]["height"] = 999
	check(_cast(id,12),"canonical field preparation/commit succeeds: "+String(id))
	var effect: Variant = _field()
	check(effect != null and effect.world_field != null and effect.world_field.height == 12 and is_equal_approx(c.player.current_sp,before-c.player.skill_cost(id)) and is_equal_approx(c.player.skill_cooldown(id),StatCalculator.effective_cooldown(ClassCatalog.skill_definition(id).rank_definition(rank).cooldown,c.player.stat_breakdown)),"one committed real field pays once and ignores mutated preview")
	if effect == null: return
	var initial := lower.health.current_hp
	effect._process(0.05)
	if id == &"fire_wall": check(inside.burn_streams.size() == 1,"stationary occupant receives one canonical burn source")
	else: check(inside.health.current_hp == 100000 and inside.slow_fraction == 0,"initial occupancy is not a fresh crossing")
	_move(lower,contact+normal*40)
	_move(upper,contact+normal*40+Vector3.UP*40)
	effect._process(0.05)
	_check_contact(id,lower,true)
	_check_contact(id,upper,false)
	check(lower.global_position == upper.global_position,"logical crossing is independent of identical sprites")
	if id == &"lightning_wall":
		var hp := lower.health.current_hp; effect._process(0.1)
		check(lower.health.current_hp == hp and hp < initial,"standing outside does not become a periodic lightning tick")
	if id == &"fire_wall":
		var request: DamageRequest = effect.burn_request
		check(is_equal_approx(request.magic_damage,c.player.stat_breakdown.value(&"magic_attack")*ClassCatalog.skill_definition(id).rank_definition(rank).power),"Fire Wall keeps canonical rank power")
		lower._process(1.1)
		check(lower.health.current_hp < initial and lower.burn_streams.size() == 1,"applied burn ticks through actual shared damage callback, not four independent pillars")
func _invalid(id: StringName,reason: String) -> void:
	_setup(id,1)
	var height := 12.0; var facing := normal; var revision := world.geometry_revision
	match reason:
		"height": height = 0
		"nan": height = NAN
		"ceiling": height = 40
		"direction": facing = Vector3.UP
		"sp": c.player.current_sp = 0
		"stun": c.player.apply_stun(2)
		"pause": paused = true
		"stale": revision -= 1
		"edge": facing = Vector3.LEFT

	var before := c.player.current_sp
	var result := c.cast_world_skill(id,null,facing,null,revision,0,height)
	if result["ok"] and c.player.has_active_cast(): c.player._advance_world_cast(10); result = c.player.world_cast_status()
	check(not result["ok"] and c.player.current_sp == before and c.player.skill_cooldown(id) == 0 and _field() == null,"invalid/missing authored field data is free: "+reason+" "+String(id))
	paused = false
func _late(id: StringName,mode: String) -> void:
	_setup(id,5)
	check(_cast(id,12),"late field emitted: "+mode)
	var effect: Variant = _field()
	if effect == null: check(false,"late field exists"); return
	var before := c.player.current_sp; var remaining: float = effect.remaining
	_move(lower,contact+normal*40)
	match mode:
		"pause": paused = true; effect._process(0.5); check(effect.remaining == remaining,"pause freezes field lifetime and queued contacts"); paused = false
		"epoch": world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")
		"removed": c.enemies.erase(lower); lower.free()
		"build": c.player.run_state.build_snapshot.skill_ranks.erase(id); c.player.apply_run_modifiers(c.player.run_state)
	effect._process(0.1)
	check(c.player.current_sp == before,"emitted field never repays or refunds: "+mode)
	if mode == "epoch": check(effect.is_queued_for_deletion() and upper.health.current_hp == 100000,"world epoch cancels field without migrating its center")
	elif mode == "removed": check(upper.health.current_hp == 100000,"freed queued victim is filtered before typed conversion")
	else: _check_contact(id,lower,true)
func _oblique(id: StringName) -> void:
	_setup(id,1,Vector3(1,0,1).normalized())
	check(_cast(id,12),"oblique field has real oriented footprint")
	var effect: Variant = _field()
	if effect == null: return
	_move(lower,contact+normal*40)
	effect._process(0.1)
	_check_contact(id,lower,true)
	check(not effect.world_field.contains(upper),"rotated volume cannot count upper projected overlap")
func _zero_delta(id: StringName) -> void:
	_setup(id,1)
	check(_cast(id,12),"zero-time field emitted")
	var effect: Variant = _field()
	if effect == null: return
	var remaining: float = effect.remaining
	_move(lower,contact+normal*40)
	effect._process(NAN); effect._process(-1)
	check(effect.remaining == remaining,"invalid delta cannot change lifetime or drain queued movement")
	_check_contact(id,lower,false)
	effect._process(0)
	check(effect.remaining == remaining,"zero delta samples contact without advancing canonical lifetime")
	_check_contact(id,lower,true)
func _fire_multi() -> void:
	_setup(&"fire_wall",5)
	c.enemies.erase(inside); inside.free()
	_move(lower,center+Vector3(0,0,-110))
	check(_cast(&"fire_wall",12),"four-pillar field emitted")
	var effect: Variant = _field()
	if effect == null: return
	_move(lower,center+Vector3(0,0,110))
	effect._process(0.1)
	check(lower.burn_streams.size() == 1,"one swept passage across all four pillars creates one canonical burn stream")
	var anchor: WorldGroundField = effect.world_field
	check(anchor.half_length == FireWall.PILLAR_SPACING*float(FireWall.PILLAR_COUNT-1)*0.5 and anchor.half_width == FireWall.PILLAR_RADIUS,"layout is captured from existing nominal constants")
func _cadence() -> void:
	_setup(&"lightning_wall",5); check(_cast(&"lightning_wall",12),"cadence field emitted")
	var effect: Variant = _field()
	if effect == null: return
	_move(lower,contact+normal*40); effect._process(0.1)
	var hp := lower.health.current_hp
	_move(lower,center-normal*40); effect._process(0.1)
	check(lower.health.current_hp == hp,"entry cooldown prevents rapid return from double hitting")
	effect._process(1)
	check(lower.health.current_hp == hp,"ICD expiry alone never damages a stationary body")
	_move(lower,contact+normal*40); effect._process(0.1)
	check(lower.health.current_hp < hp,"a new crossing after nominal ICD hits again")
func _motion() -> void:
	_setup(&"lightning_wall",1)
	var records: Array[Dictionary] = []
	lower.world_motion.traversed.connect(func(segments: Array[Dictionary]) -> void: records.append_array(segments.duplicate(true)))
	check(lower.move_world_to(Fixture.point("bridge",Vector3(lower.world_point().position.x,40,lower.world_point().position.z)),world.geometry_revision)["ok"],"logical route to overlapping bridge exists")
	var moved := lower.advance_world(10000)
	check(moved["ok"] and records == moved["data"]["segments"] and records.size() > 3,"motion signal emits each actual supported route segment, never an endpoint chord")
	var good := true
	for segment: Dictionary in records:
		var a: Dictionary = segment["from"]; var b: Dictionary = segment["to"]
		good = good and a["surface_id"] == b["surface_id"] and Vector3(a["position"]).distance_to(b["position"]) > 0
	check(good,"each continuous walking segment keeps its own support provenance")
func _barrier_arrows(height: float) -> void:
	_setup(&"phantom_barrier",1)
	check(_cast(&"phantom_barrier",height),"barrier has explicit authored interception height")
	var effect: Variant = _field()
	if effect == null: return
	var capacity: int = effect.remaining_capacity; var hp := c.player.health.current_hp
	var limit := capacity+1 if height > 1 else 1
	for i: int in limit:
		var request := DamageRequest.new(); request.magic_damage = 40; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; request.can_crit = false
		var arrow := ArrowProjectile.new(); arrow.configure(request,c.player,Vector2.ZERO,c.navigation); c.add_child(arrow)
		var source := Fixture.point("root",center+normal*70)
		check(arrow.bind_world_flight(world,source,Vector3(0,3,0),-normal,{"radius":3.0,"height":6.0},world.geometry_revision)["ok"],"hostile arrow uses actual bound cylinder")
		arrow.hit.connect(c._on_attack_requested); arrow._process(1)
		if height > 1 and i < capacity: check(c.player.health.current_hp == hp and effect.remaining_capacity == capacity-i-1,"real barrier consumes exactly one capacity per absorbed arrow")
	check(c.player.health.current_hp < hp,"height gap or exhausted barrier allows the actual arrow through")
	if height == 1: check(effect.remaining_capacity == capacity,"arrow above authored top does not spend capacity")
	else: check(effect.remaining_capacity == 0 and effect.is_queued_for_deletion(),"finite barrier exhausts and closes")
func _capsule() -> void:
	_setup(&"lightning_wall",1); check(_cast(&"lightning_wall",12),"capsule field emitted")
	var effect: Variant = _field()
	if effect == null: return
	_move(lower,center+Vector3(13,0,133))
	check(not effect.world_field.contains(lower),"capsule rounded cap does not become a square-expanded rectangle")
	_move(lower,center+Vector3(0,0,133.9))
	check(effect.world_field.contains(lower),"capsule tip includes nominal width plus body radius")
func _destructive() -> void:
	_setup(&"lightning_wall",1); check(_cast(&"lightning_wall",12),"destructive-callback field emitted")
	var effect: Variant = _field()
	if effect == null: return
	lower.health.damage_applied.connect(func(_result: Dictionary) -> void: upper.free(); lower.queue_free(); effect._process(1))
	_move(lower,contact+normal*40); effect._process(0.1)
	check(lower.is_queued_for_deletion() and not is_instance_valid(upper) and is_equal_approx(effect.remaining,4.9) and not lower.is_electrified(),"removed next victim and reentrant process do not cause another hit, clock step or invalid access")
func _check_contact(id: StringName,actor: CombatActor,expected: bool) -> void:
	if id == &"fire_wall": check((not actor.burn_streams.is_empty()) == expected,"ground burn membership: "+String(id))
	elif id == &"lightning_wall": check((actor.health.current_hp < 100000 and actor.is_electrified()) == expected,"ground lightning crossing: "+String(id))
	else: check((actor.slow_fraction > 0 and actor.weaken_fraction > 0) == expected,"ground barrier crossing: "+String(id))
func _cast(id: StringName,height: float) -> bool:
	var result := c.cast_world_skill(id,null,normal,null,world.geometry_revision,0,height)
	if not result["ok"]: return false
	if c.player.has_active_cast(): c.player._advance_world_cast(10)
	return c.player.world_cast_status()["ok"]
func _field() -> Variant:
	for child: Node in c.get_children():
		if child is FireWall or child is LightningWall or child is PhantomBarrier: return child
	return null
func _move(actor: CombatActor,position: Vector3) -> void:
	var point := ExpeditionWorldPoint.create("sample",actor.world_point().surface_id,position)
	var route := actor.move_world_to(point,world.geometry_revision)
	check(route["ok"] and actor.advance_world(10000)["ok"],"fixture follows actual supported movement")
func _setup(id: StringName,rank: int,facing: Vector3 = Vector3.RIGHT) -> void:
	input = Fixture.make()
	for part: ExpeditionPartDefinition in input.parts:
		for surface: ExpeditionSurfaceDefinition in part.surfaces:
			for i: int in surface.vertices.size(): surface.vertices[i] = _scale(surface.vertices[i])
		for connector: ExpeditionConnectorDefinition in part.connectors: connector.position = _scale(connector.position); connector.width *= 4
		for socket: ExpeditionSocketDefinition in part.sockets: socket.position = _scale(socket.position)
		for i: int in part.solid_volumes.size():
			var box: AABB = part.solid_volumes[i]; part.solid_volumes[i] = AABB(_scale(box.position),_scale(box.size))
	world = WorldGeometry.new(); check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"real F0 field fixture configured")
	profile = input.traversal.to_data(); normal = facing
	c = Controller.new(); root.add_child(c); owned.append(c); c.set_process(false); c.navigation.configure(Rect2(0,0,4000,4000),[],0); c.rng.seed = 711
	var build := BuildSnapshot.new(); build.character_id = "f1_fields"; build.base_class_id = &"mage"; build.base_level = ProgressionRules.MAX_BASE_LEVEL; build.job_level = 40; build.attribute_allocations = {&"int":20,&"dex":20}; build.skill_ranks = {id:rank}; build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(&"mage",&""); Dependencies.complete_snapshot(build)
	c.run_state = RunState.from_build("f1_fixture",build); c.player = PlayerActor.new(); c.add_child(c.player); c.player.configure(c.navigation,c.run_state)
	check(c.player.bind_world_geometry(world,Fixture.point("root",Vector3(80,0,500)),profile,str(c.player.get_instance_id()))["ok"],"Mage bound")
	c.player.set_process(false); c.player.health.max_hp = 100000; c.player.health.current_hp = 100000
	center = c.player.world_point().position+normal*c.player.skill_range(id)
	contact = center+Vector3(-normal.z,0,normal.x)*(-27) if id == &"fire_wall" else center
	lower = _target(Fixture.point("root",contact-normal*40)); upper = _target(Fixture.point("bridge",contact-normal*40+Vector3.UP*40)); inside = _target(Fixture.point("root",contact))
	c.enemies.assign([lower,upper,inside])
	c.player.fire_wall_requested.connect(c._on_fire_wall_requested); c.player.lightning_wall_requested.connect(c._on_lightning_wall_requested); c.player.phantom_barrier_requested.connect(c._on_phantom_barrier_requested)
func _target(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor); actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"field target bound"); actor.set_process(false); actor.status_damage_requested.connect(c._on_attack_requested)
	return actor
func _scale(point: Vector3) -> Vector3: return Vector3(point.x*4,point.y,point.z*4)
