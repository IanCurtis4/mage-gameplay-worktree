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
	for condition: String in ["plain","block","move","reconfigured","freed","absorbed","death"]:
		_setup(&"mage",&"elementalist",{&"elementalist_lightning_arc":1})
		var next := target(Fixture.point("root",Vector3(90,0,150)))
		var third := target(Fixture.point("root",Vector3(10,0,150)))
		controller.enemies.append(next); controller.enemies.append(third)
		caster.elementalist_lightning_arc_requested.connect(controller._on_elementalist_lightning_arc_requested)
		var events: Array[Dictionary] = []
		for actor: CombatActor in controller.enemies:
			actor.health.damage_applied.connect(controller._on_enemy_damage_resolved)
			actor.health.damage_applied.connect(func(r: Dictionary) -> void:
				if r.get("skill_id") == &"elementalist_lightning_arc": events.append(r)
			)
		var before := caster.current_sp
		check(not controller.cast_world_skill(&"elementalist_lightning_arc",null,Vector3.RIGHT,upper,world.geometry_revision)["ok"] and caster.current_sp == before,"initial Arc through slab fails before cost")
		if condition == "block":
			lower.health.damage_applied.connect(func(_r: Dictionary) -> void: check(world.insert_obstacle("arc_block",AABB(Vector3(70,0,145),Vector3(4,20,10)),world.geometry_revision)["ok"],"callback inserts narrow direct-volume blocker"))
		if condition == "move":
			lower.health.damage_applied.connect(func(_r: Dictionary) -> void:
				check(next.move_world_to(upper.world_point(),world.geometry_revision)["ok"],"next target plans real path to upper floor")
				next.advance_world(1000.0)
			)
		if condition == "reconfigured": lower.health.damage_applied.connect(func(_r: Dictionary) -> void: world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample"))
		if condition == "freed": lower.health.damage_applied.connect(func(_r: Dictionary) -> void: controller.enemies.erase(next); next.free())
		if condition == "absorbed": lower.health.shield_hp = 100000.0
		if condition == "death": lower.health.current_hp = 0.01
		check(controller.cast_world_skill(&"elementalist_lightning_arc",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"] and caster.current_sp == before,"actual Arc enters preparation without payment")
		caster._advance_world_cast(100.0)
		check(caster.world_cast_status()["ok"] and caster.current_sp < before and caster.skill_cooldown(&"elementalist_lightning_arc") > 0.0,"Arc canonical commit pays once")
		check(upper.health.current_hp == 100000.0 and not upper.is_electrified(),"chain never crosses solid slab to coincident upper sprite")
		if condition in ["reconfigured","absorbed"]:
			check(events.size() == 1 and next.health.current_hp == 100000.0 and third.health.current_hp == 100000.0,"world replacement or zero real root damage stops chain")
		elif condition in ["block","move","freed"]:
			check(events.size() == 2 and events[1]["target_id"] == third.get_instance_id() and (not is_instance_valid(next) if condition == "freed" else next.health.current_hp == 100000.0),"each jump chooses current nearest legal 3D target and rechecks occlusion")
		else:
			check(events.size() == 3 and events[1]["target_id"] == next.get_instance_id() and events[2]["target_id"] == third.get_instance_id(),"up to two distinct secondary jumps follow actual previous point even after lethal/free callback")
		var seen: Dictionary[int,bool] = {}
		for i: int in events.size():
			var result: Dictionary = events[i]
			check(not seen.has(result["target_id"]),"chain never repeats target")
			seen[result["target_id"]] = true
			check(bool(result["secondary"]) == (i > 0) and (i == 0 or not bool(result["can_trigger_effects"])),"only primary Arc can trigger generic procs")
			var context: CombatEventContext = result["context"]
			check(context.is_active() and context.ancestor_root_id == (events[0]["context"] as CombatEventContext).ancestor_root_id,"jump retains canonical causal root")
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 chains: %d checks, %d failures" % [checks,failures])
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
