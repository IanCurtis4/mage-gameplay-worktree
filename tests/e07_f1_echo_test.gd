extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Spatial = preload("res://tools/content/transform_bundle.gd")
var checks := 0
var failures := 0
var owned: Array[Node] = []
var world: WorldGeometry
var profile: Dictionary
var caster: PlayerActor
var lower: CombatActor
var upper: CombatActor
var neighbor: CombatActor
var controller: RunController
var catalog: BuildEffectCatalog
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var entries := Spatial.entries()
	var prepared := ContentAuthoring.prepare(entries)
	check(prepared["ok"],"real spatial recipe bundle prepares")
	catalog = ContentAuthoring.compile_bundle(entries,prepared["text_template"],false)["catalog"]
	for condition: String in ["follow","fixed","remove","pause","reconfigured","freed","obstacle","propagate","carrier_dies","world_callback","source_removed","lethal_curse"]:
		_setup(condition in ["fixed","remove"])
		var state := controller.spiritualist_echo_state
		var sp := caster.current_sp
		check(not controller.cast_world_skill(&"spiritualist_echo_curse",null,Vector3.RIGHT,upper,world.geometry_revision)["ok"] and caster.current_sp == sp,"curse through slab fails before payment")
		if condition == "lethal_curse": lower.health.current_hp = 0.01
		check(controller.cast_world_skill(&"spiritualist_echo_curse",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"] and caster.current_sp == sp,"curse preparation is free")
		finish()
		check(caster.current_sp < sp and caster.skill_cooldown(&"spiritualist_echo_curse") > 0.0,"curse pays canonical cost/cooldown once")
		check(state.has_mark(neighbor.get_instance_id()) and not state.has_mark(upper.get_instance_id()),"collective curse follows connected support, not coincident sprites")
		if condition == "lethal_curse":
			check(not lower.is_alive() and not state.has_mark(lower.get_instance_id()) and state.has_mark(neighbor.get_instance_id()),"lethal initial cast still marks surviving neighbors from captured support")
			continue
		check(state.has_mark(lower.get_instance_id()) and state.pending.is_empty(),"new curse marks without detonating itself")
		check(controller.cast_world_skill(&"soul_impact",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"],"actual inherited SoulImpact starts direct trigger")
		finish()
		var sequence: SoulImpactSequence
		for child: Node in controller.get_children():
			if child is SoulImpactSequence: sequence = child
		check(sequence != null,"real paid trigger produces sequence")
		sequence._process(0.0)
		check(state.pending.size() == 1 and state.waves.size() == 1,"one positive primary impact schedules one finite carrier")
		if state.pending.size() != 1: continue
		var echo: Dictionary = state.pending[0]
		var origin: WorldEffectArea = echo.get("world_origin")
		check(origin != null and origin.anchor().surface_id == lower.world_point().surface_id and origin.anchor().position == Vector3(60,0,150),"pending wave copies logical ground origin at scheduling")
		check(bool(echo["fixed_origin"]) == (condition in ["fixed","remove"]),"wave policy captured from actual composed primary action")
		check((echo["context"] as CombatEventContext).is_active(),"pending wave retains causal ledger")
		var hp := lower.health.current_hp
		var near_hp := neighbor.health.current_hp
		var high_hp := upper.health.current_hp
		if condition == "remove":
			caster.run_state.augment_stacks.erase(&"spiritualist_echo_fixed_origin")
			caster.run_state.runtime_revision += 1
			caster.apply_run_modifiers(caster.run_state)
			check(not bool(caster.run_state.composed_build()["kit_policies"].get(&"echo_origin_fixed",false)),"current build loses fixed-origin policy")
		if condition in ["follow","fixed","remove"]:
			check(lower.move_world_to(upper.world_point(),world.geometry_revision)["ok"],"carrier plans actual connector route to upper floor")
			lower.advance_world(1000.0)
			check(lower.world_point().surface_id == upper.world_point().surface_id,"carrier reaches supported upper floor without sprite movement")
		if condition == "pause":
			paused = true
			controller._apply_spiritualist_echo(echo)
			check(state.pending.size() == 1 and state.pending[0]["remaining"] == SpiritualistEchoState.ECHO_DELAY and lower.health.current_hp == hp and neighbor.health.current_hp == near_hp,"controller pause freezes echo countdown")
			paused = false
		if condition == "reconfigured": world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
		if condition == "freed": controller.enemies.erase(lower); lower.free()
		if condition == "obstacle": check(world.insert_obstacle("echo_block",AABB(Vector3(70,0,90),Vector3(4,30,110)),world.geometry_revision)["ok"],"solid detour inserted after scheduling")
		var results: Array[Dictionary] = []
		for target: CombatActor in controller.enemies:
			target.health.damage_applied.connect(func(r: Dictionary) -> void:
				if bool(r.get("secondary",false)): results.append(r)
			)
		if condition == "carrier_dies": lower.health.current_hp = 0.01
		if condition == "source_removed":
			lower.health.damage_applied.connect(func(_r: Dictionary) -> void: caster.free())
		if condition == "world_callback":
			lower.health.damage_applied.connect(func(_r: Dictionary) -> void: world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample"))
		resolve()
		if condition in ["reconfigured","freed"]:
			check(neighbor.health.current_hp == near_hp and upper.health.current_hp == high_hp and state.pending.is_empty(),"invalid epoch or removed carrier cannot migrate or ghost a wave")
		elif condition in ["fixed","remove"]:
			check(lower.health.current_hp == hp and upper.health.current_hp == high_hp and neighbor.health.current_hp < near_hp,"fixed origin remains lower, carrier can escape to upper floor")
			check(state.pending.size() == 1 and (state.pending[0]["world_origin"] as WorldEffectArea).anchor().position == neighbor.world_point().position and bool(state.pending[0]["fixed_origin"]),"propagation captures new carrier support and original policy after removal")
		elif condition == "follow":
			check(lower.health.current_hp < hp and upper.health.current_hp < high_hp and neighbor.health.current_hp == near_hp,"following origin climbs with carrier and only hits connected upper neighborhood")
		elif condition == "obstacle":
			check(lower.health.current_hp < hp and neighbor.health.current_hp == near_hp and upper.health.current_hp == high_hp,"wave resamples ground detour within radius at resolution")
		elif condition in ["world_callback","source_removed"]:
			check(lower.health.current_hp < hp and neighbor.health.current_hp == near_hp,"replacement during first damage prevents remaining candidates from entering new world")
		else:
			check(lower.health.current_hp < hp and neighbor.health.current_hp < near_hp and upper.health.current_hp == high_hp,"supported echo resolves canonical damage on same-floor victims only")
			check(state.pending.size() == 1,"only preexisting eligible neighbor transmits, carrier cannot reenter")
			var after_first := neighbor.health.current_hp
			controller._apply_spiritualist_echo(echo)
			check(neighbor.health.current_hp == after_first,"reentering same carrier cannot claim a pair twice")
			resolve()
			check(state.pending.is_empty() and state.waves.is_empty() and state.wave_by_emission.is_empty(),"finite wave completes without secondary cascade")
			check(state.has_mark(neighbor.get_instance_id()) and state.marks[neighbor.get_instance_id()].get("world_origin") != null,"survivor rearmed for next action retains spatial identity")
		# Generated echo requests use the canonical finite-pair exception, never fresh roots.
		if condition not in ["reconfigured","freed"]: check(not results.is_empty(),"real echo damage emits captured secondary result")
		for result: Dictionary in results:
			var context: CombatEventContext = result.get("context")
			check(context != null and context.secondary and context.proc_child and context.family_id == &"spiritualist_echo" and not bool(result.get("can_trigger_effects",false)),"echo preserves finite-pair ancestry without generic procs")
	_setup(false)
	caster.run_state.augment_stacks[&"spiritualist_drain_inscription"] = 1
	caster.run_state.runtime_revision += 1
	caster.apply_run_modifiers(caster.run_state)
	check(bool(caster.run_state.composed_build()["kit_policies"].get(&"drain_inscription",false)),"real completion-inscription policy composed")
	caster.spiritualist_drain_requested.connect(controller._on_spiritualist_drain_requested)
	check(controller.cast_world_skill(&"spiritualist_soul_drain",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"],"inscription uses real spatial channel")
	finish()
	check(controller.spiritualist_drain_state.active and controller.spiritualist_drain_state.world_action != null,"channel begins with spatial guard")
	controller._advance_spiritualist_drain(2.1)
	check(not controller.spiritualist_drain_state.active and controller.spiritualist_echo_state.has_mark(lower.get_instance_id()) and controller.spiritualist_echo_state.marks[lower.get_instance_id()].get("world_origin") != null,"four valid ticks create a spatial mark from captured inscription policy")
	check(not controller.spiritualist_echo_state.has_mark(upper.get_instance_id()) and controller.spiritualist_echo_state.pending.is_empty(),"inherited completion mark neither crosses floors nor detonates itself")
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 echoes: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func finish() -> void:
	if caster.has_active_cast(): caster._advance_world_cast(100.0)
func resolve() -> void:
	for echo: Dictionary in controller.spiritualist_echo_state.advance(0.36): controller._apply_spiritualist_echo(echo)
	controller.spiritualist_echo_state.finish_resolution()
func _setup(fixed: bool) -> void:
	var input := Fixture.make()
	world = WorldGeometry.new(); check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"real F0 geometry configured")
	profile = input.traversal.to_data()
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,1000,800),[],0)
	var build := BuildSnapshot.new(); build.character_id = "f1_echo"; build.base_class_id = &"mage"; build.evolution_id = &"spiritualist"; build.base_level = 30; build.job_level = 40; build.skill_ranks = {&"spiritualist_echo_curse":1,&"soul_impact":1,&"spiritualist_soul_drain":1}
	var pending := true
	while pending:
		pending = false
		for skill: StringName in build.skill_ranks.keys():
			var prerequisites: Dictionary = build._skill_catalog.skill_metadata(skill)["rank_requirements"][1]["skill_ranks"]
			for id: StringName in prerequisites:
				if int(build.skill_ranks.get(id,0)) < int(prerequisites[id]): build.skill_ranks[id] = prerequisites[id]; pending = true
	var state := RunState.from_build("f1_fixture",build)
	if fixed: state.augment_stacks[&"spiritualist_echo_fixed_origin"] = 1
	check(state.set_effect_catalog(catalog)["ok"],"real authored spatial policy catalog injected")
	caster = PlayerActor.new(); caster.configure(nav,state); root.add_child(caster); owned.append(caster); caster.set_process(false)
	check(caster.bind_world_geometry(world,Fixture.point("root",Vector3(20,0,150)),profile,str(caster.get_instance_id()))["ok"],"real caster bound")
	controller = RunController.new(); owned.append(controller); controller.player = caster; controller.run_state = state; controller.navigation = nav; controller.rng.seed = 711
	controller.spiritualist_echo_state.source_id = caster.get_instance_id()
	lower = target(Fixture.point("root",Vector3(60,0,150))); upper = target(Fixture.point("bridge",Vector3(60,40,150))); neighbor = target(Fixture.point("root",Vector3(90,0,150)))
	controller.enemies.assign([lower,upper,neighbor])
	caster.spiritualist_echo_curse_requested.connect(controller._on_spiritualist_echo_curse_requested)
	caster.soul_impact_requested.connect(controller._on_soul_impact_requested)
func target(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor)
	actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"real target bound"); actor.set_process(false)
	actor.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	return actor
