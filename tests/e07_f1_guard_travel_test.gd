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
	_geometry()
	_guard()
	_fields()
	for identity: StringName in [&"defender",&"berserker"]:
		for condition: String in ["normal","pause","control","revision","epoch","cancel","removed_target","cleanup","under_bridge"]: _travel(identity,condition)
	_retreat()
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 guard and travel: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _geometry() -> void:
	_setup(&"swordsman",&"defender",{&"defender_counterstroke":1})
	var reverse := world.trace_ground(Fixture.point("landing",Vector3(250,40,50)),Vector3.LEFT,240,profile,world.geometry_revision)
	check(reverse["ok"] and is_equal_approx(reverse["data"]["cost"],240) and reverse["data"]["destination"]["surface_id"] == lower.world_point().surface_id and absf(reverse["data"]["destination"]["position"].y) < 0.001,"reverse ground trace descends actual ramp and preserves240 world units")
	var edge := world.trace_ground(caster.world_point(),Vector3.RIGHT,150,profile,world.geometry_revision)
	check(edge["ok"] and edge["data"]["truncated"] and absf(edge["data"]["cost"]-78) < 0.002,"unsupported edge clips whole actor footprint without changing floor")
	var diagonal := world.trace_ground(Fixture.point("root",Vector3(98,0,34)),Vector3(1,0,-1),10,profile,world.geometry_revision)
	check(diagonal["ok"] and diagonal["data"]["cost"] <= sqrt(8.0)+0.002,"continuous opening support cannot skip an unsupported sliver between legal endpoints")
	check(world.insert_obstacle("clip",AABB(Vector3(70,0,140),Vector3(4,25,20)),world.geometry_revision)["ok"],"clip obstacle keeps alternate authored paths")
	var clip := world.trace_ground(caster.world_point(),Vector3.RIGHT,100,profile,world.geometry_revision)
	check(clip["ok"] and absf(clip["data"]["destination"]["position"].x-68) < 0.002,"directional clipping reaches first solid with body radius")
	check(world.trace_ground(caster.world_point(),Vector3.RIGHT,10,profile,world.geometry_revision-1)["error_code"] == &"stale_geometry","trace rejects stale revision")
	check(world.trace_ground(caster.world_point(),Vector3.UP,10,profile,world.geometry_revision)["error_code"] == &"invalid_ground_line","trace rejects vertical-only direction")
func _guard() -> void:
	_setup(&"swordsman",&"defender",{&"defender_counterstroke":1,&"defender_guard_return":1})
	var above := enemy(Fixture.point("bridge",Vector3(20,40,150)))
	controller.enemies.append(above)
	var plain := caster.apply_damage(incoming(above),controller.rng)
	check(controller.cast_world_skill(&"defender_counterstroke",null,Vector3.UP,null,world.geometry_revision)["ok"],"actual Counterstroke captures vertical world direction")
	finish()
	var before_recovery := caster.current_sp
	var frontal := incoming(above)
	var guarded := caster.apply_damage(frontal,controller.rng)
	check(guarded["damage"] < plain["damage"] and caster._world_counter_guard_facing == Vector3.UP and caster.has_defender_token(),"accepted event source above is frontal to captured 3D guard, without duplicating attack selection")
	check(caster.current_sp > before_recovery and guarded["context"] != null,"canonical finite incoming ledger allows one real Resguardo recovery")
	var recovered := caster.current_sp
	var duplicate := frontal.copy(); duplicate.context = (guarded["context"] as CombatEventContext).copy_context()
	check(caster.apply_damage(duplicate,controller.rng).is_empty() and caster.current_sp == recovered,"same applied event cannot duplicate mitigation reward or recovery")
	var flank := caster.apply_damage(incoming(lower),controller.rng)
	check(is_equal_approx(flank["damage"],plain["damage"]),"horizontal source is outside vertical guard even when legacy facing points toward it")
	var secondary := incoming(above); secondary.is_secondary = true; secondary.skill_id = &"burn_tick"; secondary.context.family_id = &"burn_tick"
	check(is_equal_approx(caster.apply_damage(secondary,controller.rng)["damage"],plain["damage"]),"secondary event cannot gain front mitigation")
	world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
	check(not caster._faces_source_actor(Vector2.RIGHT,above,Vector3.UP),"stale body/world cannot produce frontal guard event")
func _fields() -> void:
	_setup(&"swordsman",&"defender",{&"defender_anchor":1,&"defender_reprisal_wave":1})
	var defense := caster.stat_breakdown.value(&"physical_defense")
	var sp := caster.current_sp
	check(not controller.cast_world_skill(&"defender_anchor",upper.world_point(),Vector3.RIGHT,null,world.geometry_revision)["ok"] and caster.current_sp == sp,"anchor cannot be placed through slab/outside connected range before cost")
	check(controller.cast_world_skill(&"defender_anchor",lower.world_point(),Vector3.RIGHT,null,world.geometry_revision)["ok"],"anchor enters canonical world cast")
	finish(); controller._sync_defender_anchor()
	check(caster.has_defender_anchor() and caster.stat_breakdown.value(&"physical_defense") > defense and lower.slow_fraction > 0 and upper.slow_fraction == 0,"anchor defenses/slow share connected support rather than sprites")
	check(caster.move_world_to(upper.world_point(),world.geometry_revision)["ok"],"caster plans actual route out of lower anchor")
	caster.advance_world(1000); controller._sync_defender_anchor()
	check(not caster._defender_inside_anchor and is_equal_approx(caster.stat_breakdown.value(&"physical_defense"),defense),"upper floor is outside lower anchor despite same drawing")
	var hp := lower.health.current_hp; var high_hp := upper.health.current_hp
	check(controller.cast_world_skill(&"defender_reprisal_wave",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"wave at active remote anchor uses canonical handler")
	finish()
	check(lower.health.current_hp < hp and upper.health.current_hp == high_hp,"active anchor is the only wave origin even after source climbs")
	caster.clear_defender_state(); controller._sync_defender_anchor()
	check(lower.slow_remaining == 0 and caster.defender_anchor_area == null,"anchor cleanup removes exactly its slow source")
	_setup(&"swordsman",&"berserker",{&"berserker_blood_rift":1,&"berserker_deep_bleeding":1})
	hp = upper.health.current_hp
	check(controller.cast_world_skill(&"berserker_blood_rift",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"Rift has spatial directional preparation")
	finish()
	check(lower.health.current_hp < 100000 and not lower.bleed_streams.is_empty() and upper.health.current_hp == hp and upper.bleed_streams.is_empty(),"Rift direct damage/extended bleed inherit only accepted ground strip hit")
	var before := lower.health.current_hp
	lower.move_world_to(upper.world_point(),world.geometry_revision); lower.advance_world(1000)
	lower._process(1.1)
	check(lower.health.current_hp < before,"already applied bleed inherits hit and follows target without fresh cast LoS")
	_setup(&"swordsman",&"berserker",{&"berserker_blood_rift":1})
	move(Fixture.point("root",Vector3(80,0,50)))
	var uphill := target(Fixture.point("slope",Vector3(180,32,50))); controller.enemies.append(uphill)
	check(controller.cast_world_skill(&"berserker_blood_rift",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"Rift directional footprint can propagate onto connected ramp")
	finish()
	check(uphill.health.current_hp < 100000 and not uphill.bleed_streams.is_empty(),"ground strip uses logical footprint and support distance rather than treating ramp elevation as line width")
func _travel(identity: StringName, condition: String) -> void:
	var id := &"defender_wall_advance" if identity == &"defender" else &"berserker_wound_leap"
	_setup(&"swordsman",identity,{id:5})
	move(Fixture.point("root",Vector3(20,0,150) if condition == "under_bridge" else Vector3(80,0,50)))
	var victim := enemy(Fixture.point("root",Vector3(60,0,150)) if condition == "under_bridge" else Fixture.point("slope",Vector3(140,16,50)))
	controller.enemies.append(victim)
	if condition == "under_bridge": controller.enemies.assign([victim,upper])
	var captured: Array[DamageRequest] = []
	caster.attack_requested.connect(func(r: DamageRequest,_a: CombatActor) -> void:
		if r.skill_id == id: captured.append(r.copy())
	)
	caster.world_defender_hit_requested.connect(func(r: DamageRequest,_a: CombatActor,_root: float,_push: Vector3) -> void: captured.append(r.copy()))
	var sp := caster.current_sp
	var preview := caster.preview_world_skill(id,null,Vector3.RIGHT,null,controller.enemies,world.geometry_revision,1)
	check(preview["ok"] and preview["data"]["travel_plan"]["cost"] > 0 and caster.current_sp == sp and not caster.has_active_cast(),"travel preview is pure and uses selected rank plan")
	check(controller.cast_world_skill(id,null,Vector3.RIGHT,null,world.geometry_revision)["ok"] and caster._world_dash_remaining > 0,"actual travel starts simulation path with captured request")
	finish()
	var paid := caster.current_sp
	check(paid < sp and captured.is_empty(),"travel pays once but produces no teleport/chord hit at emission")
	var start := caster.world_point().position
	var old_victim := victim.world_point().position
	if condition == "pause":
		paused = true; caster._process(1.0)
		check(caster.world_point().position == start and captured.is_empty(),"tree pause freezes travel and collision")
		paused = false
	if condition == "control": caster.apply_root(5.0,&"magic")
	if condition == "revision": check(world.insert_obstacle("revision",AABB(Vector3(110,0,60),Vector3(4,20,6)),world.geometry_revision)["ok"],"new geometry invalidates committed travel route")
	if condition == "epoch": world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
	if condition == "cancel": check(caster.use_world_dash(Fixture.point("root",Vector3(85,0,50)),world.geometry_revision),"base dash replaces travel without inheriting its hit payload")
	if condition == "removed_target": controller.enemies.erase(victim); victim.free()
	if condition == "cleanup":
		if identity == &"defender": caster.clear_defender_state()
		else: caster.clear_berserker_state()
	caster._process(1.0)
	if condition in ["control","revision","epoch","cancel","cleanup"]:
		check(captured.is_empty() and caster._world_travel_request == null and not caster.defender_advance_guard_active,"control/revision/epoch/replacement cancels future travel hit and guard")
	elif condition == "removed_target": check(captured.is_empty(),"removed target weak reference cannot produce ghost hit")
	else:
		check(captured.size() == 1 and victim.health.current_hp < 100000 and upper.health.current_hp == 100000,"actual ramp segments emit at most one canonical hit, never through upper sprite")
		if not captured.is_empty(): check(captured[0].context.is_active() and captured[0].context.root_event_id != "" and not captured[0].is_secondary,"travel hit preserves original finite emission ancestry")
		if identity == &"defender": check(victim.world_point().position.distance_to(old_victim) > 0 and (victim.world_point().position.y == 0 if condition == "under_bridge" else victim.world_point().position.y > old_victim.y),"normal target push follows ramp support after actual damage")
	if condition == "cleanup": check(caster.world_point().position == start,"explicit cleanup cancels underlying route as well as travel payload")
	check(caster._world_dash_remaining == 0 and not caster.defender_advance_guard_active,"guard only lasts active travel")
	check(caster.current_sp <= paid if condition == "cancel" else caster.current_sp >= paid-0.001,"no second travel cost while advancing or cancelling")
func _retreat() -> void:
	_setup(&"swordsman",&"defender",{&"defender_retreat_guard":5})
	move(Fixture.point("landing",Vector3(240,40,50)))
	var front := Vector3(1,1,0).normalized()
	check(controller.cast_world_skill(&"defender_retreat_guard",null,front,null,world.geometry_revision)["ok"],"Retreat commits short backwards supported move")
	check(caster.world_point().surface_id == Fixture.point("slope",Vector3(150,20,50)).surface_id and caster.world_point().position.y < 40 and caster._world_retreat_guard_facing.is_equal_approx(front),"Retreat descends ramp while preserving captured front, not reversed movement vector")
	var mob := enemy(Fixture.point("root",Vector3(90,0,150)))
	var before := mob.world_point().position
	var pushed := mob.apply_world_defender_push_direction(Vector3.RIGHT,35,world.geometry_revision)
	check(pushed["ok"] and mob.world_point().position.x <= 98.001 and mob.world_point().position.x > before.x,"push clips before unsupported edge without detour or floor repair")
	mob.hard_controls.boss = true; before = mob.world_point().position
	check(not mob.apply_world_defender_push_direction(Vector3.LEFT,35,world.geometry_revision)["ok"] and mob.world_point().position == before,"boss immunity suppresses displacement while damage remains independent")
func incoming(source: CombatActor) -> DamageRequest:
	var request := DamageRequest.new(); request.source_id = source.get_instance_id(); request.target_id = caster.get_instance_id(); request.physical_damage = 20.0; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; request.can_crit = false
	if source is EnemyActor:
		var families := BuildEffectCatalog.INTRINSIC_FAMILIES.duplicate(); families.append_array(BuildEffectCatalog.INTRINSIC_COMPONENTS)
		request.skill_id = &"enemy_claw"
		request.context = (source as EnemyActor).effect_ledger.new_root(source.get_instance_id(),false,"",false,{"families":families,"targets":[source.get_instance_id(),caster.get_instance_id()],"carriers":[]})
	return request
func finish() -> void:
	if caster.has_active_cast(): caster._advance_world_cast(100)
func move(point: ExpeditionWorldPoint) -> void:
	check(caster.move_world_to(point,world.geometry_revision)["ok"],"real caster route accepted")
	caster.advance_world(1000)
func enemy(point: ExpeditionWorldPoint) -> EnemyActor:
	var actor := EnemyActor.new(); actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.player = caster; actor.navigation = controller.navigation; root.add_child(actor); owned.append(actor); actor.health.max_hp = 100000; actor.health.current_hp = 100000
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"real normal enemy bound"); actor.set_process(false)
	actor.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	return actor
func _setup(identity: StringName,evolution: StringName,ranks: Dictionary) -> void:
	var input := Fixture.make(); var built := ExpeditionAssembler.build(input)
	world = WorldGeometry.new(); check(world.configure(built["data"]["manifest"],"sample")["ok"],"real F0 geometry configured")
	profile = input.traversal.to_data()
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,1000,800),[],0)
	var build := BuildSnapshot.new(); build.character_id = "f1_area_casts"; build.base_class_id = identity; build.evolution_id = evolution; build.base_level = 30; build.job_level = 20 if evolution == &"" else 40; build.skill_ranks.assign(ranks); build.skill_ranks[&"dash"] = 1; build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(identity,evolution)
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
	for actor: CombatActor in [lower,upper]: actor.status_damage_requested.connect(controller._on_attack_requested)
	caster.attack_requested.connect(controller._on_attack_requested)
	caster.world_defender_hit_requested.connect(controller._on_world_defender_hit_requested)
	caster.berserker_rift_hit_requested.connect(controller._on_berserker_rift_hit_requested)
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
