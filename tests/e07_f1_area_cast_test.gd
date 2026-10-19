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
	_setup(&"mage",&"",{&"soul_impact":1,&"haunt":1})
	var before := caster.current_sp
	check(not controller.cast_world_skill(&"soul_impact",null,Vector3.RIGHT,upper,world.geometry_revision)["ok"] and caster.current_sp == before,"locked spell rejects target through solid slab before payment")
	check(controller.cast_world_skill(&"soul_impact",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"] and caster.current_sp == before,"locked spell preparation spends nothing")
	finish()
	var sequence := soul()
	check(sequence != null and sequence.world_action != null,"actual SoulImpact cast binds spatial guard")
	var pulses: Array[DamageRequest] = []
	sequence.impact.connect(func(r: DamageRequest,_t: CombatActor) -> void: pulses.append(r.copy()))
	paused = true; sequence._process(1.0)
	check(sequence.emitted == 0 and pulses.is_empty(),"pause freezes actual locked schedule")
	paused = false; sequence._process(1.0)
	check(sequence.emitted == 3 and pulses.size() == 3,"locked sequence preserves exactly three canonical pulses")
	var total := 0.0
	for pulse: DamageRequest in pulses:
		total += pulse.magic_damage
		check(pulse.source_id == caster.get_instance_id() and pulse.target_id == lower.get_instance_id() and pulse.context.intrinsic and pulse.context.ancestor_root_id == sequence.impact_request.context.root_event_id,"pulse preserves target/source and canonical intrinsic ancestry")
	check(is_equal_approx(total,sequence.impact_request.magic_damage*3.0),"canonical total damage budget is unchanged")
	var upper_hp := upper.health.current_hp
	check(controller.cast_world_skill(&"haunt",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"actual Haunt uses 3D cast entry")
	finish()
	check(lower.is_feared() and lower.weaken_remaining > 0.0 and not upper.is_feared() and upper.health.current_hp == upper_hp,"Haunt damage and controls inherit accepted 3D cone/occlusion")
	_setup(&"mage",&"",{&"soul_impact":1})
	controller.cast_world_skill(&"soul_impact",null,Vector3.RIGHT,lower,world.geometry_revision); finish(); sequence = soul()
	sequence.impact.connect(func(_r: DamageRequest,_t: CombatActor) -> void:
		if sequence.emitted == 1: check(world.insert_obstacle("between_pulses",AABB(Vector3(38,0,140),Vector3(3,20,20)),world.geometry_revision)["ok"],"callback inserts solid between due pulses")
	)
	before = caster.current_sp
	sequence._process(1.0)
	check(sequence.emitted == 3 and sequence.world_failure == &"", "locked packet keeps all emitted pulses when a new wall separates caster and target")
	check(caster.current_sp == before,"locked paid sequence cannot charge again")
	_setup(&"mage",&"",{&"soul_impact":1})
	controller.cast_world_skill(&"soul_impact",null,Vector3.RIGHT,lower,world.geometry_revision); finish(); sequence = soul()
	sequence.impact.connect(func(_r: DamageRequest,_t: CombatActor) -> void: world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample"))
	sequence._process(1.0)
	check(sequence.emitted == 1 and sequence.world_failure == &"world_reconfigured","world replacement during pulse cannot migrate remaining schedule")
	_setup(&"mage",&"",{&"soul_impact":1})
	controller.cast_world_skill(&"soul_impact",null,Vector3.RIGHT,lower,world.geometry_revision); finish(); sequence = soul()
	sequence.impact.connect(func(_r: DamageRequest,victim: CombatActor) -> void: victim.free())
	sequence._process(1.0)
	check(sequence.emitted == 1 and sequence.is_queued_for_deletion(),"freed target callback ends sequence without ghost impacts")
	_setup(&"mage",&"",{&"soul_impact":1})
	controller.cast_world_skill(&"soul_impact",null,Vector3.RIGHT,lower,world.geometry_revision); finish(); sequence = soul()
	sequence._process(0.0)
	check(lower.move_world_to(Fixture.point("bridge",Vector3(60,40,150)),world.geometry_revision)["ok"],"locked target gets actual ramp route to upper floor")
	lower.advance_world(1000.0)
	check(lower.world_point().surface_id == upper.world_point().surface_id,"locked target changed supported floor through real connectors")
	sequence._process(1.0)
	check(sequence.emitted == 3 and sequence.world_action.point().surface_id == upper.world_point().surface_id and sequence.world_failure == &"", "already emitted packet follows same target across legal heights without rechecking original cast LoS")
	_setup(&"mage",&"",{&"soul_impact":1})
	controller.cast_world_skill(&"soul_impact",null,Vector3.RIGHT,lower,world.geometry_revision); finish(); sequence = soul()
	caster.free()
	sequence._process(1.0)
	check(sequence.emitted == 3 and sequence.impact_request.context.is_active(),"emitted packet retains captured causal lifetime after caster removal")
	_setup(&"swordsman",&"",{&"piercing_shout":1,&"terrifying_shout":1})
	upper_hp = upper.health.current_hp
	check(controller.cast_world_skill(&"piercing_shout",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"ground shout cast enters canonical handler")
	finish()
	check(lower.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) > 0.0 and upper.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) == 0.0 and upper.health.current_hp == upper_hp,"ground shout damage/debuff stays on connected support within range")
	check(controller.cast_world_skill(&"terrifying_shout",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"fear shout cast enters canonical handler")
	finish()
	check(lower.is_feared() and not upper.is_feared() and lower.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_RECEIVED) > 0.0,"fear and vulnerability follow same supported area")
	_setup(&"mage",&"spiritualist",{&"spiritualist_dissipation":1})
	upper_hp = upper.health.current_hp
	var anchor := lower.world_point()
	check(controller.cast_world_skill(&"spiritualist_dissipation",anchor,Vector3.RIGHT,null,world.geometry_revision)["ok"],"Dissipation captures explicit ground anchor")
	finish()
	check(lower.health.current_hp < 100000.0 and lower.weaken_remaining > 0.0 and upper.health.current_hp == upper_hp and upper.weaken_remaining == 0.0,"Dissipation canonical damage/weaken never uses projected center")
	var legacy := SoulImpactSequence.new(); owned.append(legacy)
	var request := DamageRequest.new(); request.magic_damage = 3.0
	legacy.configure(request,lower)
	check(legacy.world_failure == &"spatial_binding_required" and legacy.impact_request == null,"legacy locked sequence refuses bound target without spatial guard")
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 area casts: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func finish() -> void:
	if caster.has_active_cast(): caster._advance_world_cast(100.0)
func soul() -> SoulImpactSequence:
	for child: Node in controller.get_children():
		if child is SoulImpactSequence: return child
	return null
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
