extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Transform = preload("res://tools/content/transform_bundle.gd")
var checks := 0
var failures := 0
var owned: Array[Node] = []
var world: WorldGeometry
var profile: Dictionary
var controller: RunController
var caster: PlayerActor
var lower: CombatActor
var upper: CombatActor
var neighbor: CombatActor
var catalog: BuildEffectCatalog
class SpatialController extends RunController:
	func _ready() -> void: pass # Explicit logic fixture, no menu/profile initialization.
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var entries: Array[Dictionary] = Transform.entries()
	var prepared := ContentAuthoring.prepare(entries)
	check(prepared["ok"],"actual transform bundle prepared in memory")
	if not prepared["ok"]: quit(1); return
	catalog = ContentAuthoring.compile_bundle(entries,prepared["text_template"],false)["catalog"]
	for id: StringName in HunterMath.TRAP_IDS:
		_nominal(id)
		for condition: String in ["pause","wall","removed","epoch"]: _late(id,condition)
	for id: StringName in HunterMath.NEW_TRAP_IDS:
		for condition: String in ["missing","moved","swap","remove","expire","dead_after","ttl"]: _selective(id,condition)
	for condition: String in ["normal","blocked","upper","epoch","late_entry","owner_world"]: _tar(condition)
	_destructive(&"explosive_trap"); _destructive(&"hunter_thorn_trap")
	_fifo()
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 Hunter traps: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _nominal(id: StringName) -> void:
	_setup()
	var before := caster.current_sp
	check(not caster.preview_world_skill(id,upper.world_point(),Vector3.RIGHT,null,controller.enemies,world.geometry_revision)["ok"] and caster.current_sp == before,"upper support cannot be selected through slab/outside ground range")
	var preview := caster.preview_world_skill(id,lower.world_point(),Vector3.RIGHT,null,controller.enemies,world.geometry_revision)
	check(preview["ok"] and not caster.has_active_cast() and caster.current_sp == before,"trap preview is pure and uses typed placement")
	if not preview["ok"]: return
	preview["data"]["anchor"]["position"] = upper.world_point().position
	var trap := place(id)
	if trap == null: return
	check(is_equal_approx(before-caster.current_sp,caster.skill_cost(id)) and trap.world_area != null and trap.world_area.anchor().surface_id == lower.world_point().surface_id,"one cost and captured support survive caller DTO mutation")
	var high_hp := upper.health.current_hp
	trap._process(trap.arming_duration+0.001)
	check(trap.state == PlayerTrap.State.TRIGGERED and controller.trap_registry.active_count() == 0,"real registered trap arms and claims one primary activation")
	check(not caster.hunter_state.opening(lower.get_instance_id()).is_empty() and caster.hunter_state.opening(upper.get_instance_id()).is_empty() and upper.health.current_hp == high_hp,"opening and damage never transfer to overhead sprite")
	if id in [&"snare_trap",&"hunter_freezing_trap"]: check(lower.is_rooted(),"trap applies canonical hard control after supported trigger")
	if id == &"hunter_thorn_trap":
		check(not lower.bleed_streams.is_empty() and lower.health.current_hp < 100000,"Thorn applies captured physical damage and inherited bleed")
		var hp := lower.health.current_hp
		move(lower,upper.world_point()); lower._process(1.1)
		check(lower.health.current_hp < hp,"already accepted Thorn bleed follows body after climbing without new LoS")
	if id == &"explosive_trap": check(lower.health.current_hp < 100000 and neighbor.health.current_hp < 100000,"real Hunter explosion uses its canonical area request")
	if id == &"hunter_tar_trap": check(controller.hunter_tar_field != null and lower.slow_fraction > 0 and upper.slow_fraction == 0 and lower.health.current_hp == 100000,"Tar opens once and applies only own connected slow without damage")
	# A real bow consumes the accepted opening through the existing causal ledger.
	if id != &"hunter_thorn_trap":
		check(controller.cast_world_skill(&"slowing_arrow",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"real bow can consume supported trap opening")
		finish()
		var projectiles: Array[PlayerProjectile] = []
		for node: Node in controller.get_children():
			if node is PlayerProjectile: node.set_process(false); projectiles.append(node)
		for flight: PlayerProjectile in projectiles: flight._process(1)
		check(caster.hunter_state.opening(lower.get_instance_id()).is_empty() and caster.hunter_state.step_remaining > 0,"positive own bow consumes opening exactly once and grants canonical step")
func _late(id: StringName,condition: String) -> void:
	_setup()
	var trap := place(id)
	if trap == null: return
	var before := caster.current_sp
	if condition == "pause":
		paused = true; trap._process(5)
		check(trap.state == PlayerTrap.State.ARMING,"real tree pause freezes trap arming")
		paused = false
	if condition == "wall": check(world.insert_obstacle("late",AABB(Vector3(40,0,140),Vector3(3,20,20)),world.geometry_revision)["ok"],"late wall keeps alternate ground paths")
	if condition == "removed": controller.enemies.erase(lower); lower.free()
	if condition == "epoch": world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
	trap._process(trap.arming_duration+0.001)
	check(caster.current_sp == before,"trigger/cancellation never charges another placement cost")
	if condition in ["wall","epoch"]:
		# Wall is between caster and trap only, not between this trap and its prey.
		if condition == "wall": check(trap.state == PlayerTrap.State.TRIGGERED,"paid trap keeps its anchor after caster is occluded")
		else: check(trap.state == PlayerTrap.State.ARMED and caster.hunter_state.opening(lower.get_instance_id()).is_empty(),"old epoch cannot create a new opening")
	else: check(trap.state == PlayerTrap.State.TRIGGERED,"paused resume/removed prey safely selects one living eligible body")
func _selective(id: StringName,condition: String) -> void:
	_setup(true)
	var sp := caster.current_sp
	if condition == "missing":
		check(not caster.preview_world_skill(id,lower.world_point(),Vector3.RIGHT,null,controller.enemies,world.geometry_revision)["ok"] and not controller.cast_world_skill(id,lower.world_point(),Vector3.RIGHT,null,world.geometry_revision)["ok"] and caster.current_sp == sp and controller.trap_registry.active_count() == 0,"marked mechanism rejects missing mark before preparation/cost")
		return
	check(controller.cast_world_skill(&"hunter_mark",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"],"actual Mark seeds selective captured ID")
	finish()
	var trap := place(id)
	if trap == null: return
	var lower_id := lower.get_instance_id()
	check((trap as HunterTrap).marked_trigger_target_id == lower_id,"mechanism captures real marked body identity at placement")
	if condition in ["moved","ttl"]: move(lower,upper.world_point())
	if condition == "swap":
		caster.mage_cooldowns[&"hunter_mark"] = 0
		check(controller.cast_world_skill(&"hunter_mark",null,Vector3.RIGHT,neighbor,world.geometry_revision)["ok"],"later Mark can change without redirecting emitted mechanism")
		finish()
	if condition == "remove": caster.run_state.augment_stacks.clear(); caster.apply_run_modifiers(caster.run_state)
	if condition == "expire": caster.hunter_state.advance(caster.hunter_state.mark_remaining+0.001)
	if condition == "dead_after": lower.health.current_hp = 0
	trap._process(trap.arming_duration+0.001)
	if condition in ["moved","ttl","dead_after"]:
		check(trap.state == PlayerTrap.State.ARMED and caster.hunter_state.opening(neighbor.get_instance_id()).is_empty(),"unmarked nearby prey cannot replace captured moved/dead body")
		if condition == "moved": move(lower,Fixture.point("root",Vector3(60,0,150))); trap._process(0.01); check(trap.state == PlayerTrap.State.TRIGGERED,"captured body can return by actual route and trigger")
		if condition == "ttl": trap._process(trap.lifetime_remaining+0.01); check(trap.state == PlayerTrap.State.EXPIRED,"finite selective lifetime expires without fallback target")
	else: check(trap.state == PlayerTrap.State.TRIGGERED and not caster.hunter_state.opening(lower_id).is_empty(),"paid selective mechanism survives mark/recipe removal or expiration")
func _tar(condition: String) -> void:
	_setup()
	if condition == "owner_world":
		var other := WorldGeometry.new()
		check(other.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")["ok"],"distinct geometry has byte-equivalent stage/surface IDs")
		var incompatible := HunterTarField.new(); controller.add_child(incompatible)
		check(incompatible.bind_world_area(other,lower.world_point(),profile,other.geometry_revision)["ok"],"consumer can inspect a field from another valid world")
		incompatible.configure_tar(caster,Vector2.ZERO,HunterTuning.values(&"hunter_tar_trap",1),[lower]); incompatible.set_process(false)
		check(incompatible.consume_for_world_explosion(lower.world_point(),105) == 0 and incompatible.active,"matching coordinates/IDs cannot consume bonus across owner-world identity")
		incompatible._process(0.01)
		check(not incompatible.active and lower.slow_fraction == 0,"incompatible field expires without applying control")
		return
	var trap := place(&"hunter_tar_trap",Fixture.point("root",Vector3(30,0,150)))
	if trap == null: return
	trap._process(trap.arming_duration+0.001)
	var field := controller.hunter_tar_field
	check(field != null and field.world_area != null and lower.slow_fraction > 0,"actual Tar activation creates spatial field")
	if field == null: return
	field.set_process(false)
	lower.apply_slow(0.1,10,&"other_source")
	if condition == "upper":
		check(field.consume_for_world_explosion(upper.world_point(),ExplosiveTrap.BLAST_RADIUS) == 0 and field.active,"overhead explosion cannot consume lower Tar by projected circle")
		return
	if condition == "epoch":
		world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
		field._process(0.1)
		check(not field.active and lower.attribute_debuffs.remaining(AttributeDebuffState.MOVE_SPEED,field.source_id) == 0 and lower.attribute_debuffs.remaining(AttributeDebuffState.MOVE_SPEED,&"other_source") > 0,"epoch cleanup removes only old field slow before any later pulse")
		return
	if condition == "late_entry":
		caster.hunter_state.advance(4.1); field._process(4.1)
		var late := target(Fixture.point("root",Vector3(80,0,50)))
		controller.enemies.append(late); field.track_target(late)
		move(late,Fixture.point("root",Vector3(80,0,150))); field.refresh_occupants()
		check(late.slow_fraction > 0 and caster.hunter_state.opening(late.get_instance_id()).is_empty() and caster.hunter_state.opening(lower.get_instance_id()).is_empty(),"late field occupant gets slow without new or renewed opening")
		return
	var blast := place(&"explosive_trap",Fixture.point("root",Vector3(80,0,150))) as ExplosiveTrap
	if blast == null: return
	if condition == "blocked": check(world.insert_obstacle("reaction_los",AABB(Vector3(55,0,140),Vector3(3,20,20)),world.geometry_revision)["ok"],"reaction LoS blocker leaves detour")
	var raw := blast.damage_request.physical_damage
	var impacts: Array[float] = []
	var sources_at_hit: Array[float] = []
	blast.hit.connect(func(request: DamageRequest,_victim: CombatActor) -> void:
		impacts.append(request.physical_damage)
		sources_at_hit.append(lower.attribute_debuffs.remaining(AttributeDebuffState.MOVE_SPEED,field.source_id))
	)
	blast._process(blast.arming_duration+0.001)
	check(not impacts.is_empty() and blast.damage_request.physical_damage == raw,"whole blast uses copy and never mutates original captured request")
	if condition == "blocked": check(field.active and is_equal_approx(impacts[0],raw),"connected detour does not bypass nominal center LoS for Tar reaction")
	else:
		check(not field.active and is_equal_approx(impacts[0],raw*1.25) and sources_at_hit[0] == 0,"one full-duration reaction consumes field and own slow before every damage callback")
		check(lower.attribute_debuffs.remaining(AttributeDebuffState.MOVE_SPEED,&"other_source") > 0 and field.consume_for_world_explosion(blast.world_area.anchor(),105) == 0,"reaction preserves other source and cannot be claimed again")
func _destructive(id: StringName) -> void:
	_setup()
	var next_id := neighbor.get_instance_id()
	lower.health.damage_applied.connect(func(_result: Dictionary) -> void:
		if is_instance_valid(neighbor): controller.enemies.erase(neighbor); neighbor.free()
	)
	var trap := place(id)
	if trap == null: return
	trap._process(trap.arming_duration+0.001)
	check(not is_instance_valid(neighbor) and caster.hunter_state.opening(next_id).is_empty(),"destructive callback cannot cast freed next victim or create ghost opening")
func _fifo() -> void:
	_setup()
	var first := place(&"hunter_freezing_trap")
	place(&"snare_trap"); place(&"explosive_trap"); place(&"hunter_tar_trap")
	check(first != null and first.removal_reason == PlayerTrap.REASON_REPLACED and controller.trap_registry.active_count() == 3 and caster.hunter_state.opening(lower.get_instance_id()).is_empty(),"shared FIFO replacement emits no activation or opening")
func place(id: StringName,point: ExpeditionWorldPoint = null) -> PlayerTrap:
	if point == null: point = lower.world_point()
	caster.mage_cooldowns[id] = 0
	var result := controller.cast_world_skill(id,point,Vector3.RIGHT,null,world.geometry_revision)
	check(result["ok"],"real typed placement starts: "+String(id)+" "+str(result))
	if not result["ok"]: return null
	finish()
	check(caster.world_cast_status()["ok"],"real typed placement commits: "+String(id)+" "+str(caster.world_cast_status()))
	var traps := controller.trap_registry.active_traps()
	if traps.is_empty(): check(false,"registered trap exists"); return null
	var trap := traps[-1]; trap.set_process(false)
	return trap
func finish() -> void:
	if caster.has_active_cast(): caster._advance_world_cast(100)
func move(actor: CombatActor,point: ExpeditionWorldPoint) -> void:
	check(actor.move_world_to(point,world.geometry_revision)["ok"],"actual actor route is legal")
	actor.advance_world(1000)
func _setup(selective: bool = false) -> void:
	var input := Fixture.make(); world = WorldGeometry.new(); check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"F0 manifest configured")
	profile = input.traversal.to_data()
	controller = SpatialController.new(); root.add_child(controller); owned.append(controller); controller.set_process(false); controller.set_process_input(false); controller.set_process_unhandled_input(false)
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,1000,800),[],0); controller.navigation = nav
	var build := BuildSnapshot.new(); build.character_id = "f1_hunter_traps"; build.base_class_id = &"archer"; build.evolution_id = &"hunter"; build.base_level = 30; build.job_level = 40; build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(&"archer",&"hunter"); build.attribute_allocations = {&"int":20,&"dex":10}
	build.skill_ranks = {&"hunter_freezing_trap":1,&"hunter_tar_trap":5,&"hunter_thorn_trap":1,&"snare_trap":1,&"explosive_trap":1,&"slowing_arrow":2,&"hunter_mark":1}
	var pending := true
	while pending:
		pending = false
		for skill: StringName in build.skill_ranks.keys():
			var requirements: Dictionary = build._skill_catalog.skill_metadata(skill)["rank_requirements"][1]["skill_ranks"]
			for id: StringName in requirements:
				if int(build.skill_ranks.get(id,0)) < int(requirements[id]): build.skill_ranks[id] = requirements[id]; pending = true
	var state := RunState.from_build("f1_fixture",build)
	if selective: state.augment_stacks[&"hunter_marked_mechanism"] = 1
	check(state.set_effect_catalog(catalog)["ok"],"actual policy catalog injected in fixture")
	caster = PlayerActor.new(); caster.configure(nav,state); controller.player = caster; controller.run_state = state; controller.add_child(caster); caster.set_process(false)
	check(caster.bind_world_geometry(world,Fixture.point("root",Vector3(20,0,150)),profile,str(caster.get_instance_id()))["ok"],"Hunter bound to explicit support")
	lower = target(Fixture.point("root",Vector3(60,0,150))); upper = target(Fixture.point("bridge",Vector3(60,40,150))); neighbor = target(Fixture.point("root",Vector3(85,0,150)))
	controller.enemies.assign([lower,upper,neighbor]); controller.rng.seed = 711
	controller.trap_registry = PlayerTrapRegistry.new(); controller.add_child(controller.trap_registry)
	caster.hunter_trap_requested.connect(controller._on_hunter_trap_requested); caster.snare_trap_requested.connect(controller._on_snare_trap_requested); caster.explosive_trap_requested.connect(controller._on_explosive_trap_requested); caster.slowing_arrow_requested.connect(controller._on_slowing_arrow_requested)
	caster.status_damage_requested.connect(controller._on_attack_requested)
func target(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); controller.add_child(actor); actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000; actor.health.physical_defense = 0; actor.health.magic_defense = 0; actor.health.flee_rating = 0
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"real target bound")
	actor.set_process(false); actor.health.damage_applied.connect(controller._on_enemy_damage_resolved); actor.status_damage_requested.connect(controller._on_attack_requested)
	return actor
