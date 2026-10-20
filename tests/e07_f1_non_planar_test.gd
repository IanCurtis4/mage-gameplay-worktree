extends "res://tests/e07_f1_fields_test.gd"
## New supported-plane/piecewise capability supersedes the historical F1 sloped-rejection cases.
## Legacy E04/E05 oracles are unchanged; previous F1 sources remain in Git/evidence.
const ALL_FIELDS: Array[StringName] = [&"fire_wall",&"lightning_wall",&"phantom_barrier",&"ice_wall"]
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	for id: StringName in ALL_FIELDS:
		for rank: int in [1,5]:
			_sloped_field(id,rank,false)
			_sloped_field(id,rank,true)
	_interval_geometry()
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 non-planar fields: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _field() -> Variant:
	for child: Node in c.get_children():
		if child is IceWall: return child
	return super._field()
func _sloped_field(id: StringName,rank: int,piecewise: bool) -> void:
	_setup(id,rank)
	if id == &"ice_wall": c.player.ice_wall_requested.connect(c._on_ice_wall_requested)
	normal = Vector3.FORWARD
	var x := 440.0 if piecewise else 600.0
	var origin := _support(x,160+c.player.skill_range(id))
	check(origin != null and c.player.move_world_to(origin,world.geometry_revision)["ok"] and c.player.advance_world(10000)["ok"],"caster reaches explicit ramp origin before lateral placement")
	var lateral := -27.0 if id == &"fire_wall" else 0.0
	var before := _support(x+lateral,200); var after := _support(x+lateral,120)
	check(before != null and after != null,"both crossing endpoints have authored support")
	_move_on(lower,before)
	var sp := c.player.current_sp; var revision := world.geometry_revision
	var preview := c.player.preview_world_skill(id,null,normal,null,c.enemies,revision,0,12)
	check(preview["ok"] and c.player.current_sp == sp and world.geometry_revision == revision and _field() == null,"non-planar preview uses support without flattening, mutation or payment")
	if not preview["ok"]: return
	check(_cast(id,12),"canonical handler accepts explicitly supported non-planar footprint: "+String(id))
	var effect: Variant = _field()
	check(effect != null,"real field/solid node is published")
	if effect == null: return
	effect.set_process(false)
	check(is_equal_approx(c.player.current_sp,sp-c.player.skill_cost(id)),"rank cost is paid once regardless of number of support pieces")
	if id == &"ice_wall":
		var solid: WorldSolidSegment = world._segments[effect._world_id]
		var ends := solid.ends()
		check(absf(ends[0].y-ends[1].y) > 1 and solid.support_region()["patches"].size() >= (2 if piecewise else 1),"solid snapshot retains distinct support heights and pieces")
		var hit := world.sweep(before.position,after.position,profile,world.geometry_revision)
		check(hit["ok"] and hit["data"]["hit"] and String(hit["data"]["volume_id"]).begins_with("temporary/ice_wall/"),"actual actor sweep hits supported capsule")
		check(not lower.world_motion.displace(after,200,world.geometry_revision)["ok"] and lower.world_point().to_data() == before.to_data(),"linear push cannot cross solid on ramp or seam")
		var exposed := solid.support_region(); exposed["patches"][0]["origin"] = Vector3.INF
		check(world.sweep(before.position,after.position,profile,world.geometry_revision)["data"]["hit"],"caller cannot mutate stored piecewise collision")
		check(not world.sweep(before.position+Vector3.UP*30,after.position+Vector3.UP*30,profile,world.geometry_revision)["data"]["hit"],"solid follows its local base; body above authored top passes")
		var current := world.geometry_revision; effect.expire()
		check(world.geometry_revision == current+1 and lower.world_motion.displace(after,200,world.geometry_revision)["ok"],"expiry removes all support pieces atomically once")
	else:
		var field: WorldGroundField = effect.world_field
		check(field._non_planar and field.anchor().position.y > 0,"field captures original non-zero anchor height")
		if id == &"fire_wall":
			check(field._centers[0].position.y != field._centers[-1].position.y,"four pillar bases retain their distinct authored heights")
		else:
			check(field.volume._support_region["patches"].size() >= (2 if piecewise else 1),"volume captures connected support patches rather than one flat AABB")
			check(field.volume.fraction(before.position+Vector3.UP*30,after.position+Vector3.UP*30,{"radius":2.0,"height":4.0}) < 0,"air sweep above top does not spend field capacity")
		_move_on(lower,after)
		effect._process(0.1)
		if id == &"fire_wall": check(lower.is_burning(),"actual four-pillar field applies one canonical burn source on sloped support")
		elif id == &"lightning_wall": check(lower.is_electrified() and lower.health.current_hp < 100000,"actual Lightning uses swept sloped capsule crossing")
		else: check(lower.slow_fraction > 0 and lower.weaken_fraction > 0,"actual Phantom applies crossing debuffs on supported volume")
		check(upper.health.current_hp == 100000 and not upper.is_burning() and not upper.is_electrified() and upper.slow_fraction == 0,"unrelated elevated support never inherits field contact")
		var remaining: float = effect.remaining
		paused = true; effect._process(1); paused = false
		check(effect.remaining == remaining,"pause freezes non-planar lifetime")
		world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample"); effect._process(0.01)
		check(effect.is_queued_for_deletion(),"epoch closes old non-planar field and observers")
func _support(x: float,z: float) -> ExpeditionWorldPoint:
	var id := "root" if x < 400 else "slope"
	var query := world.support_at(Fixture.point(id,Vector3.ZERO).surface_id,Vector2(x,z),world.geometry_revision)
	if not query["ok"]: return null
	var point: Dictionary = query["data"]["point"]
	return ExpeditionWorldPoint.create(point["stage_id"],point["surface_id"],point["position"])
func _move_on(actor: CombatActor,point: ExpeditionWorldPoint) -> void:
	check(actor.move_world_to(point,world.geometry_revision)["ok"] and actor.advance_world(10000)["ok"],"crossing follows real supported route with per-segment provenance")
func _interval_geometry() -> void:
	var patch := {"surface_id":"slope","origin":Vector3.ZERO,"normal":Vector3(-0.5,1,0),"polygon":PackedVector2Array([Vector2(0,-20),Vector2(100,-20),Vector2(100,20),Vector2(0,20)])}
	var region := {"patches":[patch]}
	var body := {"radius":1.0,"height":2.0}
	check(WorldSupportRegion.capsule_fraction(region,Vector2(0,0),Vector2(100,0),10,Vector3(-10,30,0),Vector3(110,30,0),body,5) >= 0,"height interval can begin after horizontal entry on rising support")
	check(WorldSupportRegion.capsule_fraction(region,Vector2(0,0),Vector2(100,0),10,Vector3(-10,80,0),Vector3(110,80,0),body,5) < 0,"whole sweep above rising support stays clear")
	check(WorldSupportRegion.capsule_fraction(region,Vector2(0,0),Vector2(100,0),10,Vector3(105,52.5,9),Vector3(105,52.5,9),{"radius":0.0,"height":1.0},5) < 0,"rounded cap does not become rectangle corner on inclined support")
