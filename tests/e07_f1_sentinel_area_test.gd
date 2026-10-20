extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const NET := &"sentinel_net_shot"
const EXPLOSIVE := &"sentinel_explosive_shot"
class Controller extends RunController:
	func _ready() -> void: pass
var checks := 0
var failures := 0
var owned: Array[Node] = []
var world: WorldGeometry
var profile: Dictionary
var caster: PlayerActor
var controller: RunController
var lower: CombatActor
var upper: CombatActor
var bursts: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	for rank: int in [1,5]:
		_net(rank)
		_explosive(rank)
	for mode: String in ["endpoint","zero","wall","upper","ramp","pause","removed","epoch","build","destructive"]: _net_late(mode)
	for mode: String in ["sp","stun","pause","revision","support","distance","moved","geometry","cancel"]: _net_invalid(mode)
	for mode: String in ["sp","focus","dead","slab","origin","pause","stun","epoch"]: _reservation_invalid(mode)
	for mode: String in ["wall","removed","epoch","pause","build","destructive"]: _explosive_late(mode)
	_reservation()
	_contacts()
	_frequency()
	_capacity()
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 Sentinel areas: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _net(rank: int) -> void:
	_setup({NET:rank,&"sentinel_opening_read":3})
	caster.sentinel_state.focus = 0
	caster.attack_cooldown = 0.7; caster._attack_recovery = 0.2
	var before := caster.current_sp
	var expected := SentinelMath.raw_power(NET,rank,caster.stat_breakdown)
	var intent := Fixture.point("root",Vector3(90,0,150))
	var preview := caster.preview_world_skill(NET,intent,Vector3.LEFT,null,controller.enemies,world.geometry_revision)
	check(preview["ok"] and not caster.has_active_cast() and caster.current_sp == before,"Net preview is pure and permits zero Focus")
	if not preview["ok"]: return
	check(preview["data"]["projectiles"].size() == 1 and is_equal_approx(preview["data"]["projectiles"][0]["range"],70),"point intent captures exact endpoint distance despite unrelated visual facing")
	check(not caster.preview_world_skill(NET,intent,Vector3.RIGHT,null,controller.enemies,world.geometry_revision,rank)["ok"],"Sentinel highest-only rank policy remains intact")
	check(controller.cast_world_skill(NET,intent,Vector3.RIGHT,null,world.geometry_revision)["ok"] and caster.has_active_cast(),"Net begins nominal DES-scaled preparation")
	check(caster.current_sp == before and caster.skill_cooldown(NET) == 0,"Net preparation has no payment")
	caster._advance_world_cast(1)
	var shot := _shot()
	check(shot != null and shot.world_flight != null and shot.world_flight.collider == {"radius":4.0,"height":8.0},"real controller creates one cylindrical area projectile")
	if shot == null: return
	check(is_equal_approx(before-caster.current_sp,float(SentinelTuning.values(NET,rank)["sp_cost"])) and caster.skill_cooldown(NET) > 0,"Net commit pays canonical rank once")
	check(is_equal_approx(caster.attack_cooldown,0.7) and is_equal_approx(caster._attack_recovery,0.2),"Net does not become a reset or consume auto recovery")
	check(is_equal_approx(shot.request.magic_damage,expected) and shot.request.physical_damage == 0,"Net uses canonical INT request")
	var events: Array[Dictionary] = []
	lower.health.damage_applied.connect(func(result: Dictionary) -> void: events.append(result.duplicate(true)))
	shot._process(1)
	check(bursts.size() == 1 and bursts[0]["anchor"]["surface_id"] == lower.world_point().surface_id and bursts[0]["center"] == lower.world_point().position,"first body opens Net on that body's captured support")
	check(events.size() == 1 and lower.health.current_hp < 100000 and lower.is_rooted(),"one canonical primary impact then magic root")
	check(upper.health.current_hp == 100000 and not upper.is_rooted() and controller.enemies[2].health.current_hp < 100000,"connected ground hits neighbors without crossing overhead slab")
	check(caster.sentinel_state.focus == SentinelTuning.DIRECT_FOCUS_RETURN+(4 if not events.is_empty() and events[0].get("critical",false) else 0),"new Net root does not qualify its own opening; critical OR remains nominal")
	var hp := lower.health.current_hp
	shot._process(1)
	check(lower.health.current_hp == hp and bursts.size() == 1,"claimed Net never repeats after callback")
func _net_late(mode: String) -> void:
	_setup({NET:5})
	var intent := Fixture.point("root",Vector3(90,0,150))
	if mode in ["endpoint","zero","ramp"]: controller.enemies.clear()
	if mode == "zero": intent = caster.world_point()
	if mode == "ramp":
		check(caster.move_world_to(Fixture.point("root",Vector3(90,0,50)),world.geometry_revision)["ok"],"caster has authored approach to ramp")
		caster.advance_world(1000); intent = Fixture.point("slope",Vector3(150,20,50))
	if mode == "upper":
		check(caster.move_world_to(Fixture.point("bridge",Vector3(20,40,150)),world.geometry_revision)["ok"],"caster approaches bridge by authored connections")
		caster.advance_world(1000); intent = Fixture.point("bridge",Vector3(90,40,150))
	check(controller.cast_world_skill(NET,intent,Vector3.RIGHT,null,world.geometry_revision)["ok"],"late Net intention accepted: "+mode)
	caster._advance_world_cast(1)
	var shot := _shot()
	if shot == null: check(false,"late Net exists: "+mode); return
	var before := caster.current_sp
	if mode == "wall": check(world.insert_obstacle("late_net",AABB(Vector3(40,0,140),Vector3(3,20,20)),world.geometry_revision)["ok"],"late Net terrain is inserted without invalidating paid request")
	if mode == "pause": paused = true; shot._process(1); check(shot.travelled == 0 and bursts.is_empty(),"pause freezes paid Net"); paused = false
	if mode == "removed": controller.enemies.erase(lower); lower.free()
	if mode == "epoch": world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
	if mode == "build": caster.run_state.build_snapshot.skill_ranks.erase(NET); caster.apply_run_modifiers(caster.run_state)
	if mode == "destructive":
		var later := controller.enemies[2]
		lower.health.damage_applied.connect(func(_r: Dictionary) -> void: later.free(); shot._process(1))
	shot._process(1)
	check(caster.current_sp == before,"paid Net does not refund or pay again: "+mode)
	if mode == "epoch": check(bursts.is_empty() and shot.world_failure == &"world_reconfigured","world epoch cancels future Net without migration")
	elif mode == "wall": check(bursts.size() == 1 and bursts[0]["center"].x < 40 and lower.health.current_hp == 100000,"terrain opens exact supported contact; LoS prevents damage through wall")
	elif mode == "zero": check(shot.world_flight == null and bursts.size() == 1 and bursts[0]["center"] == caster.world_point().position,"zero-distance Net opens at exact self support without fake range")
	elif mode == "upper": check(bursts.size() == 1 and bursts[0]["center"] == upper.world_point().position and lower.health.current_hp == 100000,"upper Net opens on first upper body and never leaks below slab")
	elif mode in ["endpoint","ramp"]: check(bursts.size() == 1 and Vector3(bursts[0]["center"]).is_equal_approx(intent.position),"Net reaches exact supported endpoint: "+mode)
	elif mode == "destructive": check(bursts.size() == 1 and lower.is_rooted(),"destructive victim and reentrant process do not repeat area or crash")
	else: check(bursts.size() == 1,"captured Net survives later target/build changes: "+mode)
func _net_invalid(mode: String) -> void:
	_setup({NET:5})
	var before := caster.current_sp
	var intent := Fixture.point("root",Vector3(90,0,150))
	var revision := world.geometry_revision
	match mode:
		"sp": caster.current_sp = 0; before = 0
		"stun": caster.apply_stun(2)
		"pause": paused = true
		"revision": revision -= 1
		"support": intent = Fixture.point("root",Vector3(90,5,150))
		"distance": intent = Fixture.point("bridge",Vector3(5,40,150))
	var result := controller.cast_world_skill(NET,intent,Vector3.RIGHT,null,revision)
	if mode in ["moved","geometry","cancel"]:
		check(result["ok"] and caster.has_active_cast(),"invalidated Net first prepares")
		if mode == "moved":
			check(caster.move_world_to(Fixture.point("root",Vector3(25,0,150)),world.geometry_revision)["ok"],"movement invalidation has legal destination"); caster.advance_world(1)
		elif mode == "geometry": world.insert_obstacle("net_stale",AABB(Vector3(40,0,140),Vector3(3,20,20)),world.geometry_revision)
		else: caster.cancel_active_cast()
		caster._advance_world_cast(1)
	else: check(not result["ok"],"invalid Net rejected: "+mode)
	check(caster.current_sp == before and caster.skill_cooldown(NET) == 0 and _shot() == null,"invalid/cancelled Net is free: "+mode)
	paused = false
func _explosive(rank: int) -> void:
	_setup({EXPLOSIVE:rank,&"sentinel_opening_read":3})
	caster.sentinel_state.focus = 25
	caster.current_sp = caster.skill_cost(EXPLOSIVE)
	var before := caster.current_sp
	check(not caster.preview_world_skill(EXPLOSIVE,null,Vector3.RIGHT,lower,controller.enemies,world.geometry_revision)["ok"],"explosive cannot bypass its reservation through cast preview")
	check(caster.prepare_world_sentinel_explosive(world.geometry_revision)["ok"] and caster.sentinel_state.explosive_prepared,"explicit world API reserves explosive")
	check(caster.current_sp == before and caster.sentinel_free_sp() == 0 and caster.sentinel_state.free_focus() == 0 and caster.skill_cooldown(EXPLOSIVE) == 0,"exact resources are reserved but not paid")
	var expected := SentinelMath.raw_power(EXPLOSIVE,rank,caster.stat_breakdown)
	var events: Array[Dictionary] = []
	lower.health.damage_applied.connect(func(r: Dictionary) -> void: events.append(r.duplicate(true)))
	caster.target = lower; caster._attack_engaged = true; caster.attack_cooldown = 0; caster._sentinel_last_launch_frame = -1
	caster._try_basic_attack()
	var shot := _shot()
	check(shot != null and shot.homing and not caster.sentinel_state.explosive_prepared,"next real auto consumes reservation into homing area projectile")
	if shot == null: return
	check(caster.current_sp == 0 and caster.sentinel_state.focus == 0 and caster.skill_cooldown(EXPLOSIVE) > 0,"launch spends exact reserved resources once")
	check(is_equal_approx(shot.request.magic_damage,expected) and shot.request.physical_damage == 0,"explosive replaces physical auto with captured canonical INT power")
	check(caster.attack_cooldown > 0 and caster._attack_recovery > 0,"explosive launches on normal auto recovery")
	caster._try_basic_attack(); check(_shots().size() == 1,"same-frame ordinary auto is suppressed")
	shot._process(1)
	check(events.size() == 1 and lower.health.current_hp < 100000 and controller.enemies[2].health.current_hp < 100000,"explosive hits each area body once, never adds a direct primary")
	check(upper.health.current_hp == 100000 and not lower.is_rooted(),"explosion direct volume is slab-occluded and does not gain Net root")
	check(bursts.size() == 1 and bursts[0]["center"].y == 6 and caster.sentinel_state.focus == SentinelTuning.DIRECT_FOCUS_RETURN,"actual aerial center used; one intrinsic Focus return across AoE")
func _reservation() -> void:
	_setup({EXPLOSIVE:5,&"sentinel_concussion_shot":1})
	var before := caster.current_sp
	caster.attack_cooldown = 0.5; caster._attack_recovery = 0.1
	check(not caster.prepare_sentinel_explosive(),"legacy pixel entry cannot reserve on bound actor")
	var legacy_reentry: Array[bool] = []
	caster.resources_changed.connect(func() -> void:
		if caster._world_requesting: legacy_reentry.append(caster.prepare_sentinel_explosive())
	)
	check(caster.prepare_world_sentinel_explosive(world.geometry_revision)["ok"],"world reservation starts")
	check(not legacy_reentry.is_empty() and not legacy_reentry[0] and caster.sentinel_state.explosive_prepared,"resource observer cannot reopen legacy entry and cancel/recurse into explicit reservation")
	check(caster.current_sp == before and caster.sentinel_state.focus == 100 and is_equal_approx(caster.attack_cooldown,0.5) and is_equal_approx(caster._attack_recovery,0.1) and _shot() == null,"reservation does not reset recovery, emit or pay")
	check(caster.prepare_world_sentinel_explosive(world.geometry_revision)["ok"] and not caster.sentinel_state.explosive_prepared and caster.current_sp == before,"second explicit toggle releases reservation free")
	check(caster.prepare_world_sentinel_explosive(world.geometry_revision)["ok"],"reservation rearmed")
	check(controller.cast_world_skill(&"sentinel_concussion_shot",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"] and caster.sentinel_state.explosive_prepared,"reset does not consume prepared explosive")
	caster.target = lower; caster.attack_cooldown = 0; caster._try_basic_attack()
	check(_shot() == null and caster.sentinel_state.explosive_prepared,"reset frame cannot fire prepared auto for free")
	check(caster.cancel_sentinel_preparation() and caster.sentinel_state.reserved_sp == 0 and caster.sentinel_state.reserved_focus == 0,"explicit cancellation clears both reserves")
	check(not caster.prepare_world_sentinel_explosive(world.geometry_revision-1)["ok"] and not caster.sentinel_state.explosive_prepared,"stale explicit reservation is rejected")
func _reservation_invalid(mode: String) -> void:
	_setup({EXPLOSIVE:5})
	check(caster.prepare_world_sentinel_explosive(world.geometry_revision)["ok"],"invalid launch first reserves: "+mode)
	match mode:
		"sp": caster.current_sp = 0
		"focus": caster.sentinel_state.focus = 0
		"dead": lower.health.current_hp = 0
		"slab": caster.target = upper
		"origin": check(world.insert_obstacle("origin",AABB(Vector3(23,0,153),Vector3(1,10,1)),world.geometry_revision)["ok"],"offset blocker leaves actor support legal")
		"pause": paused = true
		"stun": caster.apply_stun(1)
		"epoch": world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
	var before := caster.current_sp; var focus := caster.sentinel_state.focus
	var victim := upper if mode == "slab" else lower
	check(not caster._launch_sentinel_explosive(victim),"invalid prepared launch is rejected: "+mode)
	check(caster.current_sp == before and caster.sentinel_state.focus == focus and caster.skill_cooldown(EXPLOSIVE) == 0 and caster.sentinel_state.explosive_prepared and _shot() == null,"failed launch preserves unpaid reservation and recovery: "+mode)
	paused = false
func _explosive_late(mode: String) -> void:
	_setup({EXPLOSIVE:5})
	check(caster.prepare_world_sentinel_explosive(world.geometry_revision)["ok"] and caster._launch_sentinel_explosive(lower),"late explosive launched: "+mode)
	var shot := _shot()
	if shot == null: check(false,"late explosive exists"); return
	var before := caster.current_sp; var power := shot.request.magic_damage
	if mode == "wall": check(world.insert_obstacle("late_explosive",AABB(Vector3(40,0,140),Vector3(3,20,20)),world.geometry_revision)["ok"],"late explosion wall inserted")
	if mode == "removed": controller.enemies.erase(lower); lower.free()
	if mode == "epoch": world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
	if mode == "pause": paused = true; shot._process(1); check(shot.travelled == 0 and bursts.is_empty(),"pause freezes prepared shot after launch"); paused = false
	if mode == "build": caster.run_state.build_snapshot.skill_ranks.erase(EXPLOSIVE); caster.apply_run_modifiers(caster.run_state)
	if mode == "destructive":
		var later := controller.enemies[2]
		lower.health.damage_applied.connect(func(_r: Dictionary) -> void: later.free(); shot._process(1))
	shot._process(1)
	check(caster.current_sp == before and is_equal_approx(shot.request.magic_damage,power) and not caster.sentinel_state.explosive_prepared,"paid explosive snapshot is immutable: "+mode)
	if mode in ["removed","epoch"]: check(bursts.is_empty(),"lost target/epoch ends explosive without refund or accidental AoE")
	elif mode == "wall": check(bursts.size() == 1 and lower.health.current_hp == 100000,"late terrain explosion cannot hit through wall")
	else: check(bursts.size() == 1 and lower.health.current_hp < 100000,"emitted explosive completes safely: "+mode)
func _contacts() -> void:
	_setup({NET:1})
	var start := Fixture.point("root",Vector3(90,0,50))
	var exact := world.ground_line_point_at(start,Vector2(150,50),profile,world.geometry_revision)
	check(exact["ok"] and Vector3(exact["data"]["point"]["position"]).is_equal_approx(Vector3(150,20,50)),"exact terrain support walks original authored ramp instead of treating horizontal distance as 3D")
	check(not world.ground_line_point_at(Fixture.point("root",Vector3(90,0,150)),Vector2(150,150),profile,world.geometry_revision)["ok"],"unsupported original ground line never snaps to overhead bridge")
	var zero := world.ground_line_point_at(start,Vector2(90,50),profile,world.geometry_revision)
	check(zero["ok"] and zero["data"]["point"] == start.to_data(),"zero support query remains exact")
	var area := WorldEffectArea.new()
	check(area.configure(world,caster.world_point(),profile,&"direct_volume",world.geometry_revision)["ok"],"actual explosion origin volume configured")
	check(controller._world_sentinel_burst_contains(area,lower.world_point().position+Vector3.UP*6,lower,0,EXPLOSIVE),"aerial burst center and target body center agree at exact zero radius")
	check(not controller._world_sentinel_burst_contains(area,lower.world_point().position+Vector3.UP*6,upper,80,EXPLOSIVE),"explicit center cannot leak through solid supporting slab")
func _frequency() -> void:
	for skill: StringName in [NET,EXPLOSIVE]:
		var outcomes: Array[float] = []
		for step: float in [1.0/30,1.0/60,1.0/144,1.0]:
			_setup({skill:5})
			if skill == NET:
				check(controller.cast_world_skill(NET,Fixture.point("root",Vector3(90,0,150)),Vector3.RIGHT,null,world.geometry_revision)["ok"],"frequency Net prepares")
				caster._advance_world_cast(1)
			else: check(caster.prepare_world_sentinel_explosive(world.geometry_revision)["ok"] and caster._launch_sentinel_explosive(lower),"frequency explosive launches")
			var shot := _shot()
			if shot == null: check(false,"frequency area projectile exists"); continue
			for _frame: int in range(200):
				if shot.is_queued_for_deletion(): break
				shot._process(step)
			outcomes.append(100000-lower.health.current_hp)
			check(bursts.size() == 1 and outcomes[-1] > 0,"continuous area delivery completes exactly once at each frame step")
		for damage: float in outcomes: check(is_equal_approx(damage,outcomes[0]),"frame frequency and large delta preserve deterministic damage")
func _capacity() -> void:
	_setup({NET:5,EXPLOSIVE:5})
	var filled: Array[Node] = []
	for _i: int in range(128):
		var slot := Node.new(); root.add_child(slot); slot.add_to_group("enemy_projectiles"); filled.append(slot)
	var before := caster.current_sp
	check(not caster.prepare_world_sentinel_explosive(world.geometry_revision)["ok"] and not caster.sentinel_state.explosive_prepared,"world projectile cap blocks reservation without resource changes")
	check(not controller.cast_world_skill(NET,Fixture.point("root",Vector3(90,0,150)),Vector3.RIGHT,null,world.geometry_revision)["ok"] and caster.current_sp == before and caster.skill_cooldown(NET) == 0,"capacity rejects Net before preparation/payment")
	for slot: Node in filled: slot.free()
	check(caster.prepare_world_sentinel_explosive(world.geometry_revision)["ok"],"freed slots permit ordinary reservation")
	var reentry: Array[Dictionary] = []
	caster.resources_changed.connect(func() -> void:
		if caster._world_requesting: reentry.append(caster.prepare_world_sentinel_explosive(world.geometry_revision))
	)
	check(caster._launch_sentinel_explosive(lower),"reentrant callback launch completes")
	check(not reentry.is_empty() and reentry[0]["error_code"] == &"cast_busy" and not caster.sentinel_state.explosive_prepared,"resource callback cannot create a second reservation during paid launch")

func _shots() -> Array[SentinelAreaProjectile]:
	var result: Array[SentinelAreaProjectile] = []
	for item: Node in controller.get_children():
		if item is SentinelAreaProjectile: result.append(item)
	return result
func _shot() -> SentinelAreaProjectile:
	var all := _shots()
	return all[-1] if not all.is_empty() else null
func _setup(ranks: Dictionary) -> void:
	var input := Fixture.make()
	world = WorldGeometry.new(); check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"real F0 input configured")
	profile = input.traversal.to_data()
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,1000,800),[],0)
	var build := BuildSnapshot.new(); build.character_id = "f1_sentinel_area"; build.base_class_id = &"archer"; build.evolution_id = &"sentinel"; build.base_level = ProgressionRules.MAX_BASE_LEVEL; build.job_level = 40; build.skill_ranks.assign(ranks); build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(&"archer",&"sentinel"); build.attribute_allocations = {&"dex":20,&"int":20,&"luk":10}
	var pending := true
	while pending:
		pending = false
		for skill: StringName in build.skill_ranks.keys():
			var requirements: Dictionary = build._skill_catalog.skill_metadata(skill)["rank_requirements"][1]["skill_ranks"]
			for id: StringName in requirements:
				if int(build.skill_ranks.get(id,0)) < int(requirements[id]): build.skill_ranks[id] = requirements[id]; pending = true
	controller = Controller.new(); root.add_child(controller); owned.append(controller); controller.set_process(false)
	caster = PlayerActor.new(); controller.add_child(caster); caster.configure(nav,RunState.from_build("f1_fixture",build)); caster.set_process(false)
	caster.sentinel_state.gain(100); caster.sentinel_combat_active = true
	check(caster.bind_world_geometry(world,Fixture.point("root",Vector3(20,0,150)),profile,str(caster.get_instance_id()))["ok"],"Sentinel bound")
	controller.player = caster; controller.run_state = caster.run_state; controller.navigation = nav; controller.rng.seed = 711
	lower = target(Fixture.point("root",Vector3(60,0,150))); upper = target(Fixture.point("bridge",Vector3(60,40,150)))
	controller.enemies.assign([lower,upper,target(Fixture.point("root",Vector3(85,0,150)))])
	for actor: CombatActor in controller.enemies: actor.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	caster.sentinel_projectile_requested.connect(controller._on_sentinel_projectile_requested)
	bursts = []
	caster.sentinel_projectile_requested.connect(func(_r: DamageRequest,_t: CombatActor,_d: Vector2,_p: Dictionary) -> void:
		var shot := _shot()
		if shot != null: shot.world_burst.connect(func(area: WorldEffectArea,center: Vector3,_req: DamageRequest,_payload: Dictionary) -> void: bursts.append({"anchor":area.anchor().to_data(),"center":center}))
	)
func target(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor)
	actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"target bound"); actor.set_process(false)
	return actor
