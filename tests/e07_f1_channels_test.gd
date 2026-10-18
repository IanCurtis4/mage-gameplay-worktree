extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Sequence = preload("res://scripts/world/elementalist_sequence.gd")
var checks := 0
var failures := 0
var owned: Array[Node] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var input := Fixture.make()
	var built := ExpeditionAssembler.build(input)
	if not built["ok"]: push_error(str(built)); quit(1); return
	var world := WorldGeometry.new(); world.configure(built["data"]["manifest"],"sample")
	var profile := input.traversal.to_data()
	var origin := Fixture.point("root",Vector3(20,0,150))
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,1000,800),[],0)
	var build := BuildSnapshot.new(); build.character_id = "f1_channels"; build.base_class_id = &"mage"; build.evolution_id = &"spiritualist"; build.skill_ranks.assign({&"spiritualist_soul_drain":1,&"spiritualist_procession":1})
	var caster := PlayerActor.new(); caster.configure(nav,RunState.from_build("f1_fixture",build)); root.add_child(caster); owned.append(caster)
	check(caster.bind_world_geometry(world,origin,profile,"caster")["ok"],"real channel caster support"); caster.set_process(false)
	var lower := target(world,Fixture.point("root",Vector3(60,0,150)),profile)
	var upper := target(world,Fixture.point("bridge",Vector3(60,40,150)),profile)
	var ledger := EffectProcLedger.new("f1_channels")
	var request := DamageRequest.new(); request.source_id = caster.get_instance_id(); request.target_id = lower.get_instance_id(); request.magic_damage = 10.0; request.skill_id = &"spiritualist_soul_drain"; request.emission_id = 7; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.context = ledger.new_root(caster.get_instance_id())
	var drain := SpiritualistDrainState.new()
	check(not drain.start_world(caster,upper,request,100.0,world.geometry_revision)["ok"] and not drain.active,"slab prevents channel start")
	check(drain.start_world(caster,lower,request,100.0,world.geometry_revision)["ok"],"real drain binds world guard")
	for index: int in range(4):
		var due := drain.advance(0.5)
		check(due.size() == 1 and due[0].magic_damage == 10.0 and due[0].source_id == request.source_id and due[0].context.ancestor_root_id == request.context.root_event_id and due[0].context.intrinsic and due[0].context.root_event_id != request.context.root_event_id,"finite drain tick preserves power/source and canonical intrinsic ancestry")
		check(drain.resolve_tick() == (index == 3),"drain completes only fourth canonical tick")
	check(not drain.active and drain.advance(20.0).is_empty(),"completed drain cannot synthesize later ticks")
	drain.start_world(caster,lower,request,100.0,world.geometry_revision)
	paused = true
	check(drain.advance(1.0).is_empty() and drain.elapsed == 0.0,"pause freezes bound channel clock")
	paused = false
	caster.move_world_to(Fixture.point("root",Vector3(30,0,150)),world.geometry_revision); caster.advance_world(10.0)
	check(drain.advance(0.5).is_empty() and not drain.active and drain.world_failure == &"caster_moved","logical movement interrupts channel independently of unchanged sprite position")
	caster.move_world_to(origin,world.geometry_revision); caster.advance_world(10.0)
	drain.start_world(caster,lower,request,100.0,world.geometry_revision)
	check(world.insert_obstacle("channel_wall",AABB(Vector3(40,0,140),Vector3(4,20,20)),world.geometry_revision)["ok"],"wall changes during channel")
	check(drain.advance(0.5).is_empty() and not drain.active and drain.world_failure == &"out_of_range_or_occluded","due channel tick revalidates new solid geometry")
	world.remove_obstacle("channel_wall",world.geometry_revision)
	var procession := SpiritualistProcessionState.new()
	check(procession.start_world(caster,lower,request,50.0,world.geometry_revision)["ok"],"real procession world guard")
	var events := procession.advance(1.0)
	var impacts := 0
	var departures := 0
	for event: Dictionary in events:
		if event["kind"] == &"impact": impacts += 1; check(event["request"].context.ancestor_root_id == request.context.root_event_id and event["request"].context.intrinsic,"procession preserves canonical intrinsic ancestry")
		else: departures += 1
	check(impacts == 3 and departures == 3 and procession.all_impacts_issued(),"procession keeps finite 3/3 schedule")
	procession.start_world(caster,lower,request,50.0,world.geometry_revision)
	lower.move_world_to(Fixture.point("root",Vector3(95,0,150)),world.geometry_revision); lower.advance_world(100.0)
	check(procession.advance(1.0).is_empty() and not procession.active,"moving target outside 3D range cancels pending apparitions")
	lower.move_world_to(Fixture.point("root",Vector3(60,0,150)),world.geometry_revision); lower.advance_world(100.0)
	var controller := RunController.new(); controller.player = caster; controller.navigation = nav; controller.enemies.assign([lower,upper])
	check(controller.spiritualist_veil_state.start_world(world,origin,profile,1.0,world.geometry_revision)["ok"],"real veil captures surface")
	controller.spiritualist_veil_fraction = 0.2
	controller._advance_spiritualist_veil(0.0)
	check(lower.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) > 0.0 and upper.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0,"real controller applies veil only on connected ground")
	controller._advance_spiritualist_veil(1.0)
	check(lower.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0 and not controller.spiritualist_veil_state.active,"veil expiry removes own debuff")
	var elemental_build := BuildSnapshot.new(); elemental_build.character_id = "f1_elemental_channels"; elemental_build.base_class_id = &"mage"; elemental_build.evolution_id = &"elementalist"; elemental_build.skill_ranks.assign({&"elementalist_ember_path":1})
	var elementalist := PlayerActor.new(); elementalist.configure(nav,RunState.from_build("f1_fixture",elemental_build)); root.add_child(elementalist); owned.append(elementalist)
	check(elementalist.bind_world_geometry(world,origin,profile,"elementalist")["ok"],"real elemental identity owns staged consumer"); elementalist.set_process(false)
	controller.player = elementalist
	var elemental_request := request.copy(); elemental_request.source_id = elementalist.get_instance_id(); elemental_request.skill_id = &"elementalist_ember_path"; elemental_request.context = ledger.new_root(elementalist.get_instance_id())
	var sequence := Sequence.new(); root.add_child(sequence); owned.append(sequence); sequence.set_process(false)
	sequence.world_pulse_requested.connect(controller._on_world_elementalist_area_requested)
	var anchors: Array[ExpeditionWorldPoint] = [origin,origin,origin]
	var requests: Array[DamageRequest] = [elemental_request,elemental_request,elemental_request]
	var elements: Array[StringName] = [&"fire",&"ice",&"lightning"]
	var lower_hp := lower.health.current_hp
	var upper_hp := upper.health.current_hp
	check(sequence.configure_world(elementalist,anchors,requests,elements,80.0,0.2,true,world.geometry_revision)["ok"],"staged elemental consumer captures all supported anchors before first pulse")
	sequence._process(0.5)
	check(lower.health.current_hp < lower_hp and upper.health.current_hp == upper_hp,"canonical elemental callback respects ground while sharing once-per-target budget")
	check(sequence.is_queued_for_deletion() and sequence._hit_ids.size() == 1,"finite elemental sequence claims target only once across stages")
	controller.free()
	var reconfigured := SpiritualistDrainState.new(); reconfigured.start_world(caster,lower,request,100.0,world.geometry_revision)
	world.configure(built["data"]["manifest"],"sample")
	check(reconfigured.advance(1.0).is_empty() and reconfigured.world_failure == &"world_reconfigured","old channel cannot migrate across world replacement")
	for item: Variant in owned:
		if is_instance_valid(item) and not item.is_queued_for_deletion(): item.queue_free()
	await process_frame
	print("E07 F1 channels: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func target(world: WorldGeometry,point: ExpeditionWorldPoint,profile: Dictionary) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor)
	actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10}))
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"real channel target support"); actor.set_process(false)
	return actor
