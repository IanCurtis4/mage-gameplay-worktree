extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Effects = preload("res://tests/e06_effects_fixture.gd")
var checks := 0
var failures := 0
var owned: Array[Node] = []
var world: WorldGeometry
var profile: Dictionary
var nav: ArenaNavigation
var controller: RunController
var caster: PlayerActor
var lower: CombatActor
var upper: CombatActor
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	_setup(&"mage",&"",{&"fireball":3,&"fire_spear":1,&"ice_spear":1,&"lightning":1,&"electric_discharge":1})
	var before := caster.current_sp
	var prior_status := caster.world_cast_status()
	var preview := caster.preview_world_skill(&"fire_spear",null,Vector3.RIGHT,lower,controller.enemies,world.geometry_revision,1)
	check(preview["ok"] and preview["data"].get("projectiles",[]).size() == 1,"preview captures actual projectile plan: "+str(preview))
	if not preview["ok"]: quit(1); return
	check(preview["data"]["projectiles"][0]["collider"] == {"radius":6.0,"height":12.0},"preflight uses real MageProjectile cylinder")
	preview["data"]["projectiles"][0]["direction"] = Vector3.UP
	check(caster.current_sp == before and not caster.has_active_cast() and caster.world_cast_status() == prior_status,"preview leaves resources, cast and diagnostic state untouched")
	check(not caster.preview_world_skill(&"geometer_triangle",null,Vector3.RIGHT,null,controller.enemies,world.geometry_revision)["ok"] and caster.world_cast_status() == prior_status,"failed preview is pure too")
	check(not controller.cast_world_skill(&"fire_spear",null,Vector3.RIGHT,upper,world.geometry_revision)["ok"] and caster.current_sp == before,"slab rejects targeted cast before payment")
	check(not controller.cast_world_skill(&"fireball",null,Vector3.RIGHT,null,world.geometry_revision,4)["ok"] and caster.current_sp == before,"unlearned requested rank is rejected without cost")
	caster.apply_stun(1.0)
	check(not controller.cast_world_skill(&"fireball",null,Vector3.RIGHT,null,world.geometry_revision)["ok"] and not caster.has_active_cast() and caster.current_sp == before,"controls reject cast without preparation or payment")
	caster.clear_statuses()
	paused = true
	check(not controller.cast_world_skill(&"fireball",null,Vector3.RIGHT,null,world.geometry_revision)["ok"] and caster.current_sp == before,"pause rejects cast without payment")
	paused = false
	var ephemeral := target(Fixture.point("root",Vector3(75,0,150)))
	controller.enemies.append(ephemeral)
	check(controller.cast_world_skill(&"fire_spear",null,Vector3.RIGHT,ephemeral,world.geometry_revision)["ok"] and caster.has_active_cast(),"targeted preparation captures weak target")
	controller.enemies.erase(ephemeral); ephemeral.free()
	finish()
	check(caster.world_cast_status()["error_code"] == &"invalid_target" and caster.current_sp == before,"freed target cancels preparation before cost or callback")
	var begun := controller.cast_world_skill(&"fireball",null,Vector3.RIGHT,null,world.geometry_revision,1)
	check(begun["ok"] and caster.has_active_cast() and caster.current_sp == before,"real fireball preparation spends nothing")
	check(world.insert_obstacle("stale",AABB(Vector3(80,0,130),Vector3(3,15,8)),world.geometry_revision)["ok"],"revision changes during preparation")
	caster._advance_world_cast(10.0)
	check(not caster.has_active_cast() and caster.world_cast_status()["error_code"] == &"stale_geometry" and caster.current_sp == before and controller.get_child_count() == 1,"stale cast emits no projectile or cost")
	world.remove_obstacle("stale",world.geometry_revision)
	controller.cast_world_skill(&"fireball",null,Vector3.RIGHT,null,world.geometry_revision,1)
	caster.move_world_to(Fixture.point("root",Vector3(25,0,150)),world.geometry_revision); caster.advance_world(5.0)
	caster._advance_world_cast(10.0)
	check(caster.world_cast_status()["error_code"] == &"caster_moved" and caster.current_sp == before,"logical movement interrupts preparation despite unchanged sprite")
	caster.move_world_to(Fixture.point("root",Vector3(20,0,150)),world.geometry_revision); caster.advance_world(5.0)
	check(world.insert_obstacle("cylinder",AABB(Vector3(24,0,154),Vector3(1,12,1)),world.geometry_revision)["ok"],"thin off-center blocker installed")
	check(caster.world_can_reach(lower,caster.skill_range(&"fire_spear")),"central target ray remains clear")
	check(not controller.cast_world_skill(&"fire_spear",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"] and caster.current_sp == before,"actual cylinder origin blocks whole cast before cost")
	world.remove_obstacle("cylinder",world.geometry_revision)
	var emitted: Array[DamageRequest] = []
	caster.mage_projectile_requested.connect(func(_skill: StringName,r: DamageRequest,_target: CombatActor,_facing: Vector2,_count: int) -> void: emitted.append(r.copy()))
	var reentry: Array[Dictionary] = []
	caster.resources_changed.connect(func() -> void:
		if caster._world_executing_cast != null: reentry.append(controller.cast_world_skill(&"ice_spear",null,Vector3.RIGHT,lower,world.geometry_revision))
	)
	var expected_power := caster.stat_breakdown.value(&"magic_attack") * ClassCatalog.skill_definition(&"fireball").rank_definition(1).power
	var expected_cost := ClassCatalog.skill_definition(&"fireball").rank_definition(1).sp_cost
	check(controller.cast_world_skill(&"fireball",null,Vector3.RIGHT,null,world.geometry_revision,1)["ok"],"rank-one intent begins from learned rank three")
	var outer_rank := caster.push_cast_rank(&"fireball",3)
	caster._advance_world_cast(10.0)
	check(caster.skill_rank(&"fireball") == 3,"preparation restores enclosing rank context")
	caster.restore_cast_rank(outer_rank)
	check(caster.world_cast_status()["ok"] and emitted.size() == 1 and is_equal_approx(emitted[0].magic_damage,expected_power),"canonical request retains selected rank and power")
	check(is_equal_approx(before-caster.current_sp,expected_cost) and caster.skill_cooldown(&"fireball") > 0.0,"one canonical cost and cooldown at commit")
	check(reentry.size() == 1 and reentry[0]["error_code"] == &"cast_busy","payment callbacks cannot reenter cast")
	var projectile := controller.get_child(1) as MageProjectile
	check(projectile != null and projectile.world_flight != null and projectile.world_flight.direction == Vector3.RIGHT,"real controller emits bound flight from immutable intent")
	var hp := lower.health.current_hp
	projectile._process(0.15)
	check(lower.health.current_hp < hp,"real bound projectile reaches canonical damage callback")
	_setup(&"swordsman",&"",{&"slash":1,&"brutal_strike":1})
	var low_hp := lower.health.current_hp
	var upper_hp := upper.health.current_hp
	check(controller.cast_world_skill(&"slash",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"real slash uses typed cast entry")
	finish()
	check(lower.health.current_hp < low_hp and upper.health.current_hp == upper_hp,"cone uses logical direction and slab despite identical sprite positions")
	before = caster.current_sp
	check(not controller.cast_world_skill(&"brutal_strike",null,Vector3.RIGHT,upper,world.geometry_revision)["ok"] and caster.current_sp == before,"targeted melee rejects upper floor before payment")
	_setup(&"swordsman",&"defender",{&"defender_line_lock":1})
	caster.defender_hit_requested.connect(controller._on_defender_hit_requested)
	low_hp = lower.health.current_hp; upper_hp = upper.health.current_hp
	check(controller.cast_world_skill(&"defender_line_lock",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"Defender line enters canonical handler")
	finish()
	check(lower.health.current_hp < low_hp and lower.is_rooted() and upper.health.current_hp == upper_hp,"real Defender line applies root only behind accepted 3D hit")
	_setup(&"swordsman",&"berserker",{&"berserker_pursuit_cut":1,&"berserker_execution":1})
	low_hp = lower.health.current_hp; upper_hp = upper.health.current_hp
	check(controller.cast_world_skill(&"berserker_pursuit_cut",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"],"Berserker targeted melee enters canonical handler")
	finish()
	check(lower.health.current_hp < low_hp and upper.health.current_hp == upper_hp,"real Berserker hit retains target surface")
	caster.health.current_hp = 1.0; before = caster.current_sp
	check(not controller.cast_world_skill(&"berserker_execution",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"] and caster.health.current_hp == 1.0 and caster.current_sp == before,"Execution validates canonical nonlethal HP cost before preparation")
	_setup(&"archer",&"",{&"arrow_rain":1,&"snare_trap":1,&"explosive_trap":1,&"double_shot":1})
	var anchor := Fixture.point("root",Vector3(60,0,150))
	check(controller.cast_world_skill(&"arrow_rain",anchor,Vector3.RIGHT,null,world.geometry_revision)["ok"],"rain placement accepts connected floor")
	anchor.position = Vector3(60,40,150); anchor.surface_id = upper.world_point().surface_id
	finish()
	var rain: ArrowRain
	for child: Node in controller.get_children():
		if child is ArrowRain: rain = child
	check(rain != null and rain.world_area != null and rain.world_area.anchor().surface_id == lower.world_point().surface_id,"placement copies WorldPoint before caller mutation")
	low_hp = lower.health.current_hp; upper_hp = upper.health.current_hp
	rain._process(1.0)
	check(lower.health.current_hp < low_hp and upper.health.current_hp == upper_hp,"real cast rain cannot leak across slab")
	check(controller.cast_world_skill(&"snare_trap",lower.world_point(),Vector3.RIGHT,null,world.geometry_revision)["ok"],"base trap begins")
	finish()
	var trap := controller.trap_registry.active_traps()[0]
	check(trap.world_area != null and trap.contains_target(lower,80.0) and not trap.contains_target(upper,80.0),"registered trap retains supported anchor")
	check(controller.cast_world_skill(&"double_shot",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"multi-projectile canonical entry")
	finish()
	var flights: Array[PlayerProjectile] = []
	for child: Node in controller.get_children():
		if child is PlayerProjectile: flights.append(child)
	check(flights.size() == 2 and flights[0].world_flight != null and flights[1].world_flight != null and is_equal_approx(flights[0].world_flight.position.distance_to(flights[1].world_flight.position),14.0),"all volley origins share one preflight and preserve spacing")
	_setup(&"mage",&"elementalist",{&"elementalist_glacial_ring":1,&"elementalist_tri_nova":1,&"elementalist_flame_burst":1})
	low_hp = lower.health.current_hp; upper_hp = upper.health.current_hp
	check(controller.cast_world_skill(&"elementalist_glacial_ring",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"elementalist self area begins")
	finish()
	check(lower.health.current_hp < low_hp and upper.health.current_hp == upper_hp,"self area uses captured ground source")
	low_hp = lower.health.current_hp
	check(controller.cast_world_skill(&"elementalist_tri_nova",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"tri nova begins")
	finish()
	var sequence: Node
	for child: Node in controller.get_children():
		if child.get_script() == preload("res://scripts/world/elementalist_sequence.gd"): sequence = child
	check(sequence != null and sequence._world_areas.size() == 3,"real staged cast binds every anchor")
	sequence._process(1.0)
	check(lower.health.current_hp < low_hp and upper.health.current_hp == upper_hp and sequence._next_pulse == 3,"three canonical pulses retain ground membership")
	_setup(&"mage",&"spiritualist",{&"spiritualist_spectral_veil":1,&"spiritualist_soul_drain":1,&"spiritualist_procession":1})
	check(controller.cast_world_skill(&"spiritualist_spectral_veil",lower.world_point(),Vector3.RIGHT,null,world.geometry_revision)["ok"],"veil begins through typed entry")
	finish()
	check(controller.spiritualist_veil_state.world_area != null and controller.spiritualist_veil_state.contains_actor(lower) and not controller.spiritualist_veil_state.contains_actor(upper),"cast binds real ground veil")
	check(controller.cast_world_skill(&"spiritualist_soul_drain",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"],"drain begins through typed entry")
	finish()
	check(controller.spiritualist_drain_state.active and controller.spiritualist_drain_state.world_action != null,"drain commit retains spatial channel guard")
	_setup(&"archer",&"sentinel",{&"sentinel_observe":1})
	check(controller.cast_world_skill(&"sentinel_observe",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"],"Sentinel observes logical target")
	finish()
	check(caster.sentinel_state.observed_target_id == lower.get_instance_id(),"Sentinel canonical observation retains target identity")
	_setup(&"archer",&"hunter",{&"snare_trap":1})
	before = caster.current_sp
	check(controller.cast_world_skill(&"snare_trap",lower.world_point(),Vector3.RIGHT,null,world.geometry_revision)["error_code"] == &"spatial_hunter_composition_required" and caster.current_sp == before,"pending Hunter composition fails explicitly without flat fallback")
	_setup(&"swordsman",&"",{})
	var grant := EffectDefinition.new(); grant.id = &"fixture_active"; grant.family_id = &"fixture_active"; grant.kind = EffectDefinition.Kind.ACTIVE_GRANT; grant.handler_id = EffectDefinition.Handler.ACTIVE_SKILL; grant.granted_skill_id = &"fire_spear"; grant.granted_rank = 3; grant.allowed_origins = [&"swordsman",&"mage",&"archer"]; grant.unit = &"points"
	var effects: Array[EffectDefinition] = [grant,Effects.count_effect(),Effects.proc_effect(),Effects.range_effect()]
	var armor := Effects.definition(&"equipment",&"fixture",effects) as EquipmentDefinition
	armor.slot = &"accessory"; armor.item_kind = &"jewelry"; armor.hand_usage = &"none"; armor.socket_capacity = 0
	var catalog := Effects.registry()
	var registered := catalog.register_definition(&"equipment",armor)
	check(registered["ok"],"real effect composer accepts item active/count/proc/range recipe: "+str(registered))
	caster.run_state.build_snapshot.equipped[&"accessory_1"] = &"fixture"
	caster.run_state.build_snapshot.equipment_instances[&"fixture"] = EquipmentInstance.from_metadata(&"fixture",&"fixture",armor.metadata())["instance"]
	var composed := caster.run_state.set_effect_catalog(catalog)
	check(composed["ok"],"item fixture catalog composes with legal source: "+str(composed))
	caster.apply_run_modifiers(caster.run_state)
	check(caster.run_state.has_item_active(&"fire_spear") and int(caster.run_state.skill_levels.get(&"fire_spear",0)) == 0,"granted active never becomes learned skill")
	preview = caster.preview_world_skill(&"fire_spear",null,Vector3.RIGHT,lower,controller.enemies,world.geometry_revision,2)
	check(preview["ok"] and preview["data"]["projectiles"].size() == 2,"cross-class item preview uses composed count")
	before = caster.current_sp
	check(controller.cast_world_skill(&"fire_spear",null,Vector3.RIGHT,lower,world.geometry_revision,2)["ok"] and caster.has_active_cast(),"cross-class item preparation captures selected granted rank")
	caster.run_state.build_snapshot.equipped[&"accessory_1"] = null
	caster.apply_run_modifiers(caster.run_state)
	finish()
	check(not caster.world_cast_status()["ok"] and caster.current_sp == before and caster.skill_cooldown(&"fire_spear") == 0.0,"removing final item source during preparation cancels without payment")
	caster.run_state.build_snapshot.equipped[&"accessory_1"] = &"fixture"; caster.apply_run_modifiers(caster.run_state)
	check(controller.cast_world_skill(&"fire_spear",null,Vector3.RIGHT,lower,world.geometry_revision,2)["ok"],"restored item source permits new captured intent")
	finish()
	flights.clear()
	for child: Node in controller.get_children():
		if child is PlayerProjectile: flights.append(child)
	check(flights.size() == 2 and flights[0].world_flight != null and flights[1].world_flight != null and flights[0].request.effect_snapshot["cast_rank"] == 2 and flights[0].request.effect_snapshot["procs"].size() == 1,"real cross-class volley preserves selected rank, composed count and proc snapshot")
	low_hp = lower.health.current_hp
	for flight: PlayerProjectile in flights: flight._process(0.2)
	check(lower.health.current_hp < low_hp and flights.size() == 2 and flights[0]._hit_actor_ids.size() == 1 and flights[1]._hit_actor_ids.size() == 1,"both real homing flights advance through typed candidates and hit canonical target")
	check(int(caster.run_state.skill_levels.get(&"fire_spear",0)) == 0 and caster.skill_cooldown(&"fire_spear") > 0.0,"item emission keeps learned state separate and shared cooldown")
	_setup(&"mage",&"",{&"fire_spear":1})
	caster.run_state.augment_stacks[&"fixture"] = 1
	var aug_effects: Array[EffectDefinition] = [Effects.count_effect()]
	check(caster.run_state.set_effect_catalog(Effects.catalog_for(&"augment",aug_effects))["ok"],"augment count composes through real registry")
	caster.apply_run_modifiers(caster.run_state)
	check(controller.cast_world_skill(&"fire_spear",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"],"augmented world cast begins")
	before = caster.current_sp
	caster.run_state.augment_stacks.clear(); caster.apply_run_modifiers(caster.run_state)
	finish()
	check(caster.world_cast_status()["error_code"] == &"stale_build" and caster.current_sp == before and caster.skill_cooldown(&"fire_spear") == 0.0,"changed composition invalidates whole preparation before cost or mismatched volley")
	caster.mage_projectile_requested.disconnect(controller._on_mage_projectile_requested)
	caster.mage_projectile_requested.connect(func(_id: StringName,_r: DamageRequest,_v: CombatActor,_d: Vector2,_n: int) -> void:
		world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
	)
	caster.mage_projectile_requested.connect(controller._on_mage_projectile_requested)
	check(controller.cast_world_skill(&"fire_spear",null,Vector3.RIGHT,lower,world.geometry_revision)["ok"],"valid replacement-world callback case begins")
	finish()
	check(caster.world_cast_status()["ok"] and not caster.world_motion.is_current_world() and controller.get_child_count() == 1,"callback replacing world after commit cannot migrate projectile into new configuration")
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 casts: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func finish() -> void:
	if caster.has_active_cast(): caster._advance_world_cast(100.0)
func _setup(identity: StringName,evolution: StringName,ranks: Dictionary) -> void:
	var input := Fixture.make()
	var built := ExpeditionAssembler.build(input)
	world = WorldGeometry.new(); check(world.configure(built["data"]["manifest"],"sample")["ok"],"real F0 manifest configured")
	profile = input.traversal.to_data()
	nav = ArenaNavigation.new(); nav.configure(Rect2(0,0,1000,800),[],0)
	var build := BuildSnapshot.new(); build.character_id = "f1_casts"; build.base_class_id = identity; build.evolution_id = evolution; build.base_level = ProgressionRules.MAX_BASE_LEVEL; build.job_level = 20 if evolution == &"" else 40; build.skill_ranks.assign(ranks)
	var pending := true
	while pending:
		pending = false
		for skill: StringName in build.skill_ranks.keys():
			var requirements: Dictionary = build._skill_catalog.skill_metadata(skill)["rank_requirements"][1]["skill_ranks"]
			for prerequisite: StringName in requirements:
				if int(build.skill_ranks.get(prerequisite,0)) < int(requirements[prerequisite]): build.skill_ranks[prerequisite] = requirements[prerequisite]; pending = true
	caster = PlayerActor.new(); caster.configure(nav,RunState.from_build("f1_fixture",build)); root.add_child(caster); owned.append(caster); caster.set_process(false)
	check(caster.bind_world_geometry(world,Fixture.point("root",Vector3(20,0,150)),profile,str(caster.get_instance_id()))["ok"],"real caster bound")
	lower = target(Fixture.point("root",Vector3(60,0,150)))
	upper = target(Fixture.point("bridge",Vector3(60,40,150)))
	controller = RunController.new(); owned.append(controller); controller.player = caster; controller.navigation = nav; controller.enemies.assign([lower,upper]); controller.rng.seed = 711
	controller.trap_registry = PlayerTrapRegistry.new(); controller.add_child(controller.trap_registry)
	caster.attack_requested.connect(controller._on_attack_requested)
	caster.mage_projectile_requested.connect(controller._on_mage_projectile_requested)
	caster.precision_projectile_requested.connect(controller._on_precision_projectile_requested)
	caster.arrow_rain_requested.connect(controller._on_arrow_rain_requested)
	caster.snare_trap_requested.connect(controller._on_snare_trap_requested)
	caster.explosive_trap_requested.connect(controller._on_explosive_trap_requested)
	caster.elementalist_area_requested.connect(controller._on_elementalist_area_requested)
	caster.elementalist_tri_nova_requested.connect(controller._on_elementalist_tri_nova_requested)
	caster.spiritualist_veil_requested.connect(controller._on_spiritualist_veil_requested)
	caster.spiritualist_drain_requested.connect(controller._on_spiritualist_drain_requested)
func target(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor)
	actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"real target bound"); actor.set_process(false)
	return actor
