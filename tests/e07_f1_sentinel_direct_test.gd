extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const IDS: Array[StringName] = [&"sentinel_headshot",&"sentinel_piercing_shot",&"sentinel_concussion_shot"]
var checks := 0
var failures := 0
var owned: Array[Node] = []
var world: WorldGeometry
var profile: Dictionary
var caster: PlayerActor
var controller: RunController
var lower: CombatActor
var upper: CombatActor
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	for id: StringName in IDS:
		for rank: int in [1,5]: _direct(id,rank)
		for reason: String in ["focus","sp","stun","pause","slab","origin","stale"]: _invalid(id,reason)
		for condition: String in ["pause","wall","removed","epoch","build"]: _flight(id,condition)
	_state()
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 Sentinel direct: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _direct(id: StringName,rank: int) -> void:
	_setup({id:rank})
	var preview := caster.preview_world_skill(id,null,Vector3.RIGHT,lower if id != &"sentinel_piercing_shot" else null,controller.enemies,world.geometry_revision)
	check(preview["ok"] and preview["data"]["projectiles"].size() == 1,"reset preview has one captured projectile")
	if not preview["ok"]: return
	check(preview["data"]["projectiles"][0]["collider"] == {"radius":4.0,"height":8.0} and not caster.has_active_cast(),"preflight uses real precision body and is pure")
	preview["data"]["projectiles"].clear()
	var before := caster.current_sp; var focus := caster.sentinel_state.focus
	var expected := SentinelMath.raw_power(id,rank,caster.stat_breakdown)
	var payload := SentinelTuning.values(id,rank)
	var called: Array[Dictionary] = []
	caster.resources_changed.connect(func() -> void:
		if caster._world_executing_cast != null: called.append(controller.cast_world_skill(id,null,Vector3.RIGHT,lower,world.geometry_revision))
	)
	check(not caster.preview_world_skill(id,null,Vector3.RIGHT,lower if id != &"sentinel_piercing_shot" else null,controller.enemies,world.geometry_revision,1)["ok"] and caster.current_sp == before,"highest-only Sentinel policy still rejects explicit rank override without cost")
	var accepted := controller.cast_world_skill(id,null,Vector3.RIGHT,lower if id != &"sentinel_piercing_shot" else null,world.geometry_revision)
	check(accepted["ok"] and not caster.has_active_cast(),"highest learned rank reset launches immediately through canonical handler")
	var projectiles := shots()
	check(projectiles.size() == 1 and projectiles[0] is SentinelProjectile and projectiles[0].world_flight != null,"actual controller creates one bound Sentinel silhouette")
	if projectiles.size() != 1: return
	var projectile := projectiles[0]
	check(is_equal_approx(before-caster.current_sp,float(payload["sp_cost"])) and is_equal_approx(focus-caster.sentinel_state.focus,float(payload["focus_cost"])),"nominal rank pays SP and Focus once")
	check(caster.attack_cooldown > 0 and caster._attack_recovery > 0 and caster.skill_cooldown(id) > 0 and not called.is_empty() and called[0]["error_code"] == &"cast_busy","reset starts normal recovery and rejects callback reentry")
	check(is_equal_approx(projectile.request.magic_damage if id == &"sentinel_piercing_shot" else projectile.request.physical_damage,expected),"single canonical SentinelMath request preserves learned rank")
	var hp := upper.health.current_hp
	projectile._process(1.0)
	check(lower.health.current_hp < 100000 and upper.health.current_hp == hp,"real flight damages lower body without leaking through overhead slab")
	var lower_hp := lower.health.current_hp
	projectile._process(1.0)
	check(lower.health.current_hp == lower_hp,"queued/exhausted flight cannot repeat its impact")
	if id == &"sentinel_piercing_shot":
		check(controller.enemies[2].health.current_hp < 100000 and projectile._hit_actor_ids.size() == 2,"piercing visits each real lower body once")
	else: check(projectile.homing and projectile._hit_actor_ids.size() == 1,"targeted reset remains single-target homing")
	if id == &"sentinel_concussion_shot": check(lower.is_stunned() and lower.attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_DEALT,&"sentinel_concussion_shot") > 0,"positive canonical impact applies captured stun/debuff")
func _invalid(id: StringName,reason: String) -> void:
	_setup({id:1})
	var revision := world.geometry_revision
	var facing := Vector3.RIGHT
	var victim := lower if id != &"sentinel_piercing_shot" else null
	match reason:
		"focus": caster.sentinel_state.focus = 0
		"sp": caster.current_sp = 0
		"stun": caster.apply_stun(1)
		"pause": paused = true
		"slab":
			victim = upper if id != &"sentinel_piercing_shot" else null
			facing = Vector3.UP if id == &"sentinel_piercing_shot" else Vector3.RIGHT
		"origin": check(world.insert_obstacle("off_center",AABB(Vector3(23,0,153),Vector3(1,10,1)),revision)["ok"],"off-center cylinder blocker leaves actor legal")
		"stale": revision -= 1
	var before := caster.current_sp; var focus := caster.sentinel_state.focus
	var result := controller.cast_world_skill(id,null,facing,victim,revision)
	if reason == "slab" and id == &"sentinel_piercing_shot":
		check(result["ok"],"directional shot may launch upward into a later slab collision")
		var projectiles := shots()
		if projectiles.size() == 1: projectiles[0]._process(1.0)
		check(lower.health.current_hp == 100000 and upper.health.current_hp == 100000,"upward piercing stops on slab instead of using projected aim")
	elif reason == "focus" and id == &"sentinel_concussion_shot":
		check(result["ok"] and caster.sentinel_state.focus == 0 and is_equal_approx(before-caster.current_sp,caster.skill_cost(id)),"Concussion has zero nominal Focus cost, not an invented gate")
	else:
		check(not result["ok"] and caster.current_sp == before and caster.sentinel_state.focus == focus and caster.skill_cooldown(id) == 0 and shots().is_empty(),"invalid "+reason+" reset is free and emits nothing")
	paused = false
func _flight(id: StringName,condition: String) -> void:
	_setup({id:5})
	check(controller.cast_world_skill(id,null,Vector3.RIGHT,lower if id != &"sentinel_piercing_shot" else null,world.geometry_revision)["ok"],"late flight case launches")
	var projectiles := shots()
	if projectiles.size() != 1: check(false,"late flight exists"); return
	var projectile := projectiles[0]; var before := caster.current_sp; var original_power := projectile.request.physical_damage+projectile.request.magic_damage
	projectile.reparent(root); owned.append(projectile) # Real tree pause applies to the actual projectile.
	match condition:
		"pause":
			paused = true; projectile._process(1)
			check(projectile.world_flight.travelled == 0 and lower.health.current_hp == 100000,"pause freezes in-flight reset")
			paused = false
		"wall": check(world.insert_obstacle("late",AABB(Vector3(35,0,140),Vector3(3,20,20)),world.geometry_revision)["ok"],"late wall permits alternate routes")
		"removed":
			controller.enemies.erase(lower); lower.free()
		"epoch": world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
		"build":
			caster.run_state.build_snapshot.skill_ranks.erase(id); caster.apply_run_modifiers(caster.run_state)
	projectile._process(1)
	check(caster.current_sp == before and is_equal_approx(projectile.request.physical_damage+projectile.request.magic_damage,original_power),"paid flight never recharges or changes captured power")
	if condition in ["wall","epoch"]: check(lower.health.current_hp == 100000,"new solid or world epoch cancels future reset impact")
	elif condition == "removed": check(projectile.is_queued_for_deletion(),"removed homing target or exhausted piercing ends safely")
	else: check(lower.health.current_hp < 100000,"pause resume/build removal preserves already emitted request")
func _state() -> void:
	_setup({&"sentinel_precision_stance":3,&"sentinel_headshot":1})
	var baseline := caster.stat_breakdown.value(&"precision_attack")
	caster._process(1)
	check(caster._sentinel_stance_active and caster.stat_breakdown.value(&"precision_attack") > baseline,"logical stationary actor gains canonical stance")
	check(caster.move_world_to(Fixture.point("root",Vector3(25,0,150)),world.geometry_revision)["ok"],"external logical displacement has real route")
	caster.advance_world(5)
	var emitted: Array[DamageRequest] = []
	caster.world_attack_requested.connect(func(r: DamageRequest,_target: CombatActor,_kind: StringName) -> void: emitted.append(r.copy()))
	caster.target = lower; caster._attack_engaged = true; caster.attack_cooldown = 0; caster._sentinel_last_launch_frame = -1
	caster._process(0.01)
	check(not caster._sentinel_stance_active and caster.sentinel_state.stable_time == 0,"movement with unchanged sprite resets stance and stability")
	check(emitted.size() == 1 and is_equal_approx(emitted[0].physical_damage,baseline*caster.class_definition.basic_power),"stance is removed before same-frame auto after logical displacement")
	caster.sentinel_state.observe(lower.get_instance_id(),1)
	controller.enemies.erase(lower); lower.free(); caster.target = null
	caster._process(0.01)
	check(caster.sentinel_state.observed_target_id == 0,"removed observation is cleared in bound update too")
func shots() -> Array[PlayerProjectile]:
	var result: Array[PlayerProjectile] = []
	for child: Node in controller.get_children():
		if child is PlayerProjectile: result.append(child)
	return result
func _setup(ranks: Dictionary) -> void:
	var input := Fixture.make(); var built := ExpeditionAssembler.build(input)
	world = WorldGeometry.new(); check(world.configure(built["data"]["manifest"],"sample")["ok"],"real F0 manifest configured")
	profile = input.traversal.to_data()
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,1000,800),[],0)
	var build := BuildSnapshot.new(); build.character_id = "f1_sentinel_direct"; build.base_class_id = &"archer"; build.evolution_id = &"sentinel"; build.base_level = ProgressionRules.MAX_BASE_LEVEL; build.job_level = 40; build.skill_ranks.assign(ranks); build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(&"archer",&"sentinel"); build.attribute_allocations = {&"dex":20,&"int":20,&"luk":10}
	var pending := true
	while pending:
		pending = false
		for skill: StringName in build.skill_ranks.keys():
			var requirements: Dictionary = build._skill_catalog.skill_metadata(skill)["rank_requirements"][1]["skill_ranks"]
			for id: StringName in requirements:
				if int(build.skill_ranks.get(id,0)) < int(requirements[id]): build.skill_ranks[id] = requirements[id]; pending = true
	caster = PlayerActor.new(); caster.configure(nav,RunState.from_build("f1_fixture",build)); root.add_child(caster); owned.append(caster); caster.set_process(false)
	caster.sentinel_state.gain(100); caster.sentinel_combat_active = true
	check(caster.bind_world_geometry(world,Fixture.point("root",Vector3(20,0,150)),profile,str(caster.get_instance_id()))["ok"],"Sentinel bound")
	lower = target(Fixture.point("root",Vector3(60,0,150))); upper = target(Fixture.point("bridge",Vector3(60,40,150)))
	controller = RunController.new(); owned.append(controller); controller.player = caster; controller.run_state = caster.run_state; controller.navigation = nav; controller.enemies.assign([lower,upper]); controller.rng.seed = 711
	controller.enemies.append(target(Fixture.point("root",Vector3(85,0,150))))
	for actor: CombatActor in controller.enemies: actor.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	caster.sentinel_projectile_requested.connect(controller._on_sentinel_projectile_requested)
func target(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor)
	actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"target bound"); actor.set_process(false)
	return actor
