extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
var checks := 0
var failures := 0
var owned: Array[Node] = []
var world: WorldGeometry
var profile: Dictionary
var caster: PlayerActor
var lower: CombatActor
var upper: CombatActor
var controller: RunController
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	_setup(&"mage",&"elementalist",{&"elementalist_ember_path":1})
	var start := Fixture.point("root",Vector3(20,0,50))
	var result := world.ground_line_samples(start,Vector3.RIGHT,80,3,profile,world.geometry_revision)
	check(result["ok"] and result["data"]["points"].size() == 3,"ground line crosses exact authored connectors")
	var points: Array = result["data"]["points"]
	if points.size() == 3:
		check(points[0]["position"].is_equal_approx(Vector3(100,0,50)),"first80 units reach ramp seam")
		var ramp_length := sqrt(100.0*100.0+40.0*40.0)
		check(points[1]["position"].is_equal_approx(Vector3(100+80.0/ramp_length*100,80.0/ramp_length*40,50)),"next80 count true sloped distance, not projected pixels")
		check(points[2]["surface_id"] == Fixture.point("landing",Vector3(250,40,50)).surface_id and points[2]["position"].is_equal_approx(Vector3(200+160-ramp_length,40,50)),"third center preserves upper support and total240 distance")
	var seam := world.ground_line_samples(Fixture.point("root",Vector3(100,0,50)),Vector3.RIGHT,80,1,profile,world.geometry_revision)
	check(seam["ok"] and seam["data"]["points"].size() == 1 and seam["data"]["points"][0]["surface_id"] == Fixture.point("slope",Vector3(150,20,50)).surface_id,"legal source on connector seam transitions without artificial unsupported prefix")
	check(world.ground_line_samples(start,Vector3.UP,80,3,profile,world.geometry_revision)["error_code"] == &"invalid_ground_line","vertical-only ground direction is explicit failure")
	check(world.ground_line_samples(start,Vector3.RIGHT,0,3,profile,world.geometry_revision)["error_code"] == &"invalid_ground_line","zero spacing rejected")
	check(world.ground_line_samples(start,Vector3.RIGHT,80,0,profile,world.geometry_revision)["error_code"] == &"invalid_ground_line","empty plan rejected")
	check(world.ground_line_samples(start,Vector3.RIGHT,80,3,profile,world.geometry_revision-1)["error_code"] == &"stale_geometry","stale line query rejected")
	var wide := profile.duplicate(true); wide["radius"] = 25.0
	check(world.ground_line_samples(Fixture.point("root",Vector3(50,0,50)),Vector3.RIGHT,80,3,wide,world.geometry_revision)["data"]["points"].is_empty(),"ray cannot cross narrower authored opening")
	check(world.ground_line_samples(Fixture.point("root",Vector3(20,0,150)),Vector3.RIGHT,80,3,profile,world.geometry_revision)["data"]["points"].is_empty(),"shared projection cannot jump from lower floor to unrelated landing")
	for condition: String in ["normal","blocked","epoch","source_removed","pause_callback"]:
		_setup(&"mage",&"elementalist",{&"elementalist_ember_path":1})
		check(caster.move_world_to(start,world.geometry_revision)["ok"],"caster reaches actual launch support")
		caster.advance_world(1000.0)
		var overlap := target(Fixture.point("slope",Vector3(140,16,50)))
		var late := target(Fixture.point("slope",Vector3(185,34,50)))
		var tail := target(Fixture.point("landing",Vector3(250,40,50)))
		controller.enemies.append(overlap); controller.enemies.append(late); controller.enemies.append(tail)
		caster.elementalist_ember_path_requested.connect(controller._on_elementalist_ember_path_requested)
		var before := caster.current_sp
		var status := caster.world_cast_status()
		var preview := caster.preview_world_skill(&"elementalist_ember_path",null,Vector3.RIGHT,null,controller.enemies,world.geometry_revision)
		check(preview["ok"] and preview["data"]["ground_points"].size() == 3 and caster.current_sp == before and not caster.has_active_cast() and status == caster.world_cast_status(),"preview returns pure copied plan of three supported centers")
		preview["data"]["ground_points"][0]["position"] = Vector3(999,999,999)
		check(controller.cast_world_skill(&"elementalist_ember_path",null,Vector3.RIGHT,null,world.geometry_revision)["ok"] and caster.current_sp == before,"Ember preparation costs nothing")
		caster._advance_world_cast(100.0)
		var sequence: Node
		for child: Node in controller.get_children():
			if child.get_script() == preload("res://scripts/world/elementalist_sequence.gd"): sequence = child
		check(sequence != null and sequence._world_areas.size() == 3 and sequence._world_areas[0].anchor().position == Vector3(100,0,50),"canonical consumer uses immutable plan, not mutated preview or Vector2 placeholders")
		check(caster.current_sp < before and overlap.health.current_hp < 100000 and tail.health.current_hp == 100000,"first pulse occurs at commit with single canonical payment")
		var overlap_hp := overlap.health.current_hp
		var paid_sp := caster.current_sp
		paused = true; sequence._process(1.0)
		check(sequence._next_pulse == 1 and late.health.current_hp == 100000,"caster tree pause freezes detached sequence simulation")
		paused = false
		if condition == "blocked": check(world.insert_obstacle("late_center",AABB(Vector3(170,25,44),Vector3(10,22,12)),world.geometry_revision)["ok"],"new solid can invalidate emitted later center")
		if condition == "epoch": world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
		if condition == "source_removed": caster.free()
		if condition == "normal":
			check(caster.move_world_to(Fixture.point("root",Vector3(30,0,50)),world.geometry_revision)["ok"],"caster can move after emitted ground plan")
			caster.advance_world(10.0)
		if condition == "pause_callback": late.health.damage_applied.connect(func(_r: Dictionary) -> void: set_pause(true))
		sequence._process(1.0 if condition == "pause_callback" else 0.15)
		if condition in ["epoch","source_removed"]:
			check(sequence.is_queued_for_deletion() and late.health.current_hp == 100000 and tail.health.current_hp == 100000,"invalid world or removed caster cancels remaining emitted pulses")
			continue
		check(sequence._next_pulse == 2 and overlap.health.current_hp == overlap_hp and tail.health.current_hp == 100000,"second pulse at0.15 never repeats overlapping target")
		check((late.health.current_hp == 100000) if condition == "blocked" else (late.health.current_hp < 100000),"current solid geometry governs second pulse membership")
		if condition == "pause_callback":
			check(paused and tail.health.current_hp == 100000,"pause during second pulse stops remaining due callbacks")
			paused = false
		sequence._process(0.15)
		check(sequence._next_pulse == 3 and tail.health.current_hp < 100000 and upper.health.current_hp == 100000 and caster.current_sp == paid_sp,"third0.30 pulse uses captured upper center without repeat cost or lower-upper projection hits")
	_setup(&"mage",&"elementalist",{&"elementalist_ember_path":1})
	var sp := caster.current_sp
	check(not controller.cast_world_skill(&"elementalist_ember_path",null,Vector3.RIGHT,null,world.geometry_revision)["ok"] and caster.current_sp == sp and not caster.has_active_cast(),"no legal first center rejects entire action before payment")
	check(caster.preview_world_skill(&"elementalist_ember_path",null,Vector3.FORWARD,null,controller.enemies,world.geometry_revision)["data"]["ground_points"].size() == 1,"unsupported edge retains only legal prefix")
	check(world.insert_obstacle("before_first",AABB(Vector3(10,0,90),Vector3(20,20,10)),world.geometry_revision)["ok"],"solid before first center leaves detour available")
	check(not controller.cast_world_skill(&"elementalist_ember_path",null,Vector3.FORWARD,null,world.geometry_revision)["ok"] and caster.current_sp == sp,"directional ground line never detours around blocker to repair a cast")
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 ember: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _setup(identity: StringName,evolution: StringName,ranks: Dictionary) -> void:
	var input := Fixture.make(); var built := ExpeditionAssembler.build(input)
	world = WorldGeometry.new(); check(world.configure(built["data"]["manifest"],"sample")["ok"],"real F0 geometry configured")
	profile = input.traversal.to_data()
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,1000,800),[],0)
	var build := BuildSnapshot.new(); build.character_id = "f1_area_casts"; build.base_class_id = identity; build.evolution_id = evolution; build.base_level = 30; build.job_level = 20 if evolution == &"" else 40; build.skill_ranks.assign(ranks)
	var pending := true
	while pending:
		pending = false
		for skill: StringName in build.skill_ranks.keys():
			var prerequisites: Dictionary = build._skill_catalog.skill_metadata(skill)["rank_requirements"][1]["skill_ranks"]
			for id: StringName in prerequisites:
				if int(build.skill_ranks.get(id,0)) < int(prerequisites[id]): build.skill_ranks[id] = prerequisites[id]; pending = true
	caster = PlayerActor.new(); caster.configure(nav,RunState.from_build("f1_fixture",build)); root.add_child(caster); owned.append(caster); caster.set_process(false)
	check(caster.bind_world_geometry(world,Fixture.point("root",Vector3(20,0,150)),profile,str(caster.get_instance_id()))["ok"],"real caster bound")
	lower = target(Fixture.point("root",Vector3(60,0,150))); upper = target(Fixture.point("bridge",Vector3(60,40,150)))
	controller = RunController.new(); owned.append(controller); controller.player = caster; controller.run_state = caster.run_state; controller.navigation = nav; controller.enemies.assign([lower,upper]); controller.rng.seed = 711
	caster.soul_impact_requested.connect(controller._on_soul_impact_requested)
	caster.haunt_requested.connect(controller._on_haunt_requested)
	caster.piercing_shout_requested.connect(controller._on_piercing_shout_requested)
	caster.terrifying_shout_requested.connect(controller._on_terrifying_shout_requested)
	caster.spiritualist_dissipation_requested.connect(controller._on_spiritualist_dissipation_requested)
func target(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor)
	actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"real target bound"); actor.set_process(false)
	return actor
