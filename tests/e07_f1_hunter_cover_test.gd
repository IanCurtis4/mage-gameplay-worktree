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
var primary: CombatActor
var neighbor: CombatActor
var shadow: CombatActor
var catalog: BuildEffectCatalog
var fan_baseline := 0.0
class SpatialController extends RunController:
	func _ready() -> void: pass
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var entries: Array[Dictionary] = Transform.entries()
	var prepared := ContentAuthoring.prepare(entries)
	check(prepared["ok"],"actual recipe bundle is prepared in memory")
	if not prepared["ok"]: quit(1); return
	catalog = ContentAuthoring.compile_bundle(entries,prepared["text_template"],false)["catalog"]
	for condition: String in ["normal","blocked","root","pause","late_wall"]: _recoil(condition)
	for condition: String in ["original","enabled","blocked","outside","boundary","tie","remove","late"]: _fan(condition)
	_cover(); _epoch(); _base_cover()
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 Hunter cover: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _recoil(condition: String) -> void:
	_setup()
	move(caster,Fixture.point("landing",Vector3(240,40,50)))
	move(primary,Fixture.point("landing",Vector3(270,40,50)))
	if condition == "blocked": move(caster,Fixture.point("root",Vector3(20,0,150)))
	if condition == "root": caster.apply_root(5,&"magic")
	if condition == "pause": paused = true
	var before := caster.current_sp; var source := caster.world_point(); var hp := primary.health.current_hp
	caster.attack_cooldown = 0.7; caster._attack_recovery = 0.2
	var preview := caster.preview_world_skill(&"hunter_covering_shot",null,Vector3.RIGHT,null,controller.enemies,world.geometry_revision)
	if condition in ["blocked","root","pause"]:
		check(not preview["ok"] and not controller.cast_world_skill(&"hunter_covering_shot",null,Vector3.RIGHT,null,world.geometry_revision)["ok"] and caster.current_sp == before and caster.world_point().to_data() == source.to_data() and shots().is_empty(),"invalid full recoil/control/pause rejects shot and movement before cost")
		paused = false; return
	check(preview["ok"] and is_equal_approx(preview["data"]["travel_plan"]["cost"],80) and caster.current_sp == before,"preview shares whole supported recoil80 without mutating source")
	check(controller.cast_world_skill(&"hunter_covering_shot",null,Vector3.RIGHT,null,world.geometry_revision)["ok"],"actual Covering Shot commits canonical request and recoil")
	finish()
	var flights := shots()
	check(flights.size() == 1 and flights[0].world_flight != null and flights[0].world_flight.position.is_equal_approx(source.position+Vector3.UP*2),"actual flight retains original source before recoil")
	check(caster.world_point().surface_id == Fixture.point("slope",Vector3(160,24,50)).surface_id and caster.world_point().position.y < source.position.y and is_equal_approx(before-caster.current_sp,caster.skill_cost(&"hunter_covering_shot")),"recoil descends ramp by actual3D80 with one canonical cost")
	check(is_equal_approx(caster.attack_cooldown,0.7) and is_equal_approx(caster._attack_recovery,0.2),"Covering Shot never resets auto/recovery clocks")
	if flights.size() != 1: return
	if condition == "late_wall": check(world.insert_obstacle("late_shot",AABB(Vector3(253,40,40),Vector3(3,20,20)),world.geometry_revision)["ok"],"late solid leaves alternate supported path")
	flights[0]._process(1)
	check((primary.health.current_hp < hp) == (condition != "late_wall"),"paid original-origin flight hits target or is stopped by current solid")
func _fan(condition: String) -> void:
	_setup(condition != "original")
	var point := Fixture.point("bridge",Vector3(100,40,150))
	move(primary,point)
	move(neighbor,Fixture.point("bridge",Vector3(20 if condition == "boundary" else (19.99 if condition == "outside" else 60),40,150)))
	if condition == "tie":
		move(neighbor,Fixture.point("bridge",Vector3(100,40,110)))
		controller.enemies.append(target(Fixture.point("bridge",Vector3(100,40,190))))
	move(shadow,Fixture.point("root",Vector3(60,0,150)))
	check(controller.cast_world_skill(&"hunter_thorn_trap",primary.world_point(),Vector3.LEFT,null,world.geometry_revision)["ok"],"real Thorn placement seeds opening for fan")
	finish()
	var traps := controller.trap_registry.active_traps()
	if traps.is_empty(): check(false,"fan has registered opening trap"); return
	traps[0].set_process(false); traps[0]._process(traps[0].arming_duration+0.001)
	check(not caster.hunter_state.opening(primary.get_instance_id()).is_empty() and caster.hunter_state.opening(shadow.get_instance_id()).is_empty(),"real upper trap opening does not transfer through slab")
	var neighbor_hp := neighbor.health.current_hp; var shadow_hp := shadow.health.current_hp
	var secondary: Array[DamageRequest] = []
	caster.status_damage_requested.connect(func(request: DamageRequest,_victim: CombatActor) -> void:
		if request.skill_id == &"hunter_exploit": secondary.append(request.copy())
		if condition == "late" and is_instance_valid(neighbor) and request.skill_id == &"hunter_exploit" and request.target_id == primary.get_instance_id(): controller.enemies.erase(neighbor); neighbor.free()
	)
	if condition == "blocked": check(world.insert_obstacle("fan_wall",AABB(Vector3(75,40,140),Vector3(3,20,20)),world.geometry_revision)["ok"],"wall blocks fan but not incoming primary shot")
	check(controller.cast_world_skill(&"hunter_covering_shot",null,Vector3.LEFT,null,world.geometry_revision)["ok"],"real upper Covering Shot launches from pre-recoil point")
	finish()
	if condition == "remove": caster.run_state.augment_stacks.clear(); caster.apply_run_modifiers(caster.run_state)
	var flights := shots()
	if flights.size() != 1: check(false,"fan has one real flight"); return
	flights[0]._process(1)
	var split := condition in ["enabled","boundary","tie","remove","late"]
	check(secondary.size() == (1 if not split or condition == "late" else 2),"fan has finite admitted descendant count after real primary impact")
	check(caster.hunter_state.opening(primary.get_instance_id()).is_empty() and caster.hunter_state.step_remaining > 0 and shadow.health.current_hp == shadow_hp,"one opening/step claim never damages lower projected neighbor")
	if condition == "original":
		if secondary.size() == 1: fan_baseline = secondary[0].physical_damage
		check(fan_baseline > 0 and neighbor.health.current_hp == neighbor_hp,"untransformed bow retains full primary exploit")
	elif split:
		if not secondary.is_empty(): check(is_equal_approx(secondary[0].physical_damage,fan_baseline*0.5),"fan captures half of canonical original secondary, not a second formula")
		if condition == "late": check(not is_instance_valid(neighbor),"late removed fan target is skipped after claim without retry")
		elif secondary.size() == 2:
			check(is_equal_approx(secondary[0].physical_damage,secondary[1].physical_damage) and secondary[1].target_id == neighbor.get_instance_id() and secondary[1].context.secondary and not secondary[1].can_crit,"nearest3D/stable-ID eligible neighbor gets one equal secondary with inherited ancestry")
			check(neighbor.health.current_hp < neighbor_hp and not caster.hunter_state.opening(neighbor.get_instance_id()).is_empty(),"fan damage does not consume or reopen second victim opening")
	else: check(secondary.size() == 1 and is_equal_approx(secondary[0].physical_damage,fan_baseline) and neighbor.health.current_hp == neighbor_hp,"occluded/outside80 candidate keeps full original exploit on primary")
func _cover() -> void:
	_setup()
	var before := caster.current_sp
	check(controller.cast_world_skill(&"hunter_total_cover",caster.world_point(),Vector3.LEFT,null,world.geometry_revision)["ok"],"actual Total Cover has supported placement entry")
	finish()
	var field := shelter()
	check(field != null and field.world_area != null and caster.is_concealed() and is_equal_approx(before-caster.current_sp,caster.skill_cost(&"hunter_total_cover")),"paid Total Cover registers real geometry and begins canonical budget")
	if field == null: return
	field.set_process(false)
	var inside := target(Fixture.point("bridge",Vector3(180,40,150)))
	var below := target(Fixture.point("root",Vector3(80,0,150)))
	check(caster.can_be_acquired_by_world(inside) and not caster.can_be_acquired_by_world(below),"observer inside same support detects, lower projected observer does not")
	caster._process(0.5); field._process(0.5)
	check(is_equal_approx(caster.hunter_cover.budget_remaining,2.5),"budget pays only actual hidden time")
	move(caster,Fixture.point("bridge",Vector3(80,40,150)))
	check(caster.is_concealed() and is_equal_approx(caster.hunter_cover.grace_remaining,1),"actual supported exit starts at most1s grace")
	caster._process(1.25); field._process(1.25)
	check(not caster.is_concealed() and is_equal_approx(caster.hunter_cover.budget_remaining,1.5),"large frame integrates grace exactly once")
	move(caster,Fixture.point("landing",Vector3(210,40,150)))
	check(caster.is_concealed() and is_equal_approx(caster.hunter_cover.budget_remaining,1.5),"reentry does not renew shared budget")
	check(controller.cast_world_skill(&"slowing_arrow",null,Vector3.LEFT,null,world.geometry_revision)["ok"],"valid offensive bow reveals inside cover")
	finish()
	check(not caster.is_concealed() and caster.hunter_cover.reveal_remaining > 0,"reveal is canonical after spatial offensive commit")
	before = caster.current_sp
	check(not controller.cast_world_skill(&"foliage_shelter",caster.world_point(),Vector3.LEFT,null,world.geometry_revision)["ok"] and caster.current_sp == before,"Abrigo shares paid Total Cover cooldown")
	field.expire(&"cleanup")
	check(caster.hunter_cover.zone_id == 0 and caster.hunter_cover.grace_remaining == 0 and caster.hunter_cover.reveal_remaining > 0,"cleanup removes grace but never refunds budget/reveal")
	caster._process(20)
	check(controller.cast_world_skill(&"foliage_shelter",caster.world_point(),Vector3.LEFT,null,world.geometry_revision)["ok"],"new paid Abrigo after actual common cooldown is legal")
	finish()
	field = shelter()
	check(field != null and is_equal_approx(field.radius,110) and caster.is_concealed() and is_equal_approx(caster.hunter_cover.budget_remaining,3),"new paid cover cycle renews one budget without replacing purchased radius")
	move(caster,Fixture.point("bridge",Vector3(80,40,150)))
	check(not caster.is_concealed() and caster.hunter_cover.grace_remaining == 0,"Abrigo retains zero extra exit grace")
func _epoch() -> void:
	_setup()
	controller.cast_world_skill(&"hunter_total_cover",caster.world_point(),Vector3.LEFT,null,world.geometry_revision); finish()
	var field := shelter()
	check(field != null and caster.is_concealed(),"epoch fixture starts genuinely hidden")
	if field == null: return
	world.configure(ExpeditionAssembler.build(Fixture.make())["data"]["manifest"],"sample")
	check(not caster.is_concealed(),"stale world actor cannot retain concealment")
	var rebound := caster.bind_world_geometry(world,Fixture.point("landing",Vector3(210,40,150)),profile,str(caster.get_instance_id()))
	check(not rebound["ok"] and rebound["error_code"] == &"already_bound","existing actor binding cannot silently migrate to a new configuration")
	field._process(0.01)
	check(not caster.is_concealed() and caster.hunter_cover.zone_id == 0 and caster.hunter_cover.grace_remaining == 0,"old field cleanup removes grace without inventing a rebind lifecycle")
	check(not field.is_active(),"old field expires without migrating to new configuration")
func _base_cover() -> void:
	_setup(false,false)
	check(controller.cast_world_skill(&"foliage_shelter",caster.world_point(),Vector3.LEFT,null,world.geometry_revision)["ok"],"base Archer Abrigo also gains actual placement binding")
	finish()
	var field := shelter()
	check(field != null and caster.is_concealed() and caster.hunter_cover.budget_remaining == 0,"base Archer retains concealment independent of Hunter budget")
	if field != null: field._process(field.duration); check(not caster.is_concealed(),"base spatial cover expiration unregisters membership")
func shots() -> Array[PlayerProjectile]:
	var result: Array[PlayerProjectile] = []
	for node: Node in controller.get_children():
		if node is PlayerProjectile: node.set_process(false); result.append(node)
	return result
func shelter() -> FoliageShelter:
	for node: Node in controller.get_children():
		if node is FoliageShelter and node.is_active(): return node
	return null
func finish() -> void:
	if caster.has_active_cast(): caster._advance_world_cast(100)
func move(actor: CombatActor,point: ExpeditionWorldPoint) -> void:
	check(actor.move_world_to(point,world.geometry_revision)["ok"],"actor uses legal real route")
	actor.advance_world(1000)
func _setup(fan: bool = false,hunter: bool = true) -> void:
	var input := Fixture.make(); profile = input.traversal.to_data(); world = WorldGeometry.new(); check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"F0 manifest configured")
	controller = SpatialController.new(); root.add_child(controller); owned.append(controller); controller.set_process(false); controller.set_process_input(false); controller.set_process_unhandled_input(false)
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,1000,800),[],0); controller.navigation = nav
	var build := BuildSnapshot.new(); build.character_id = "f1_hunter_cover"; build.base_class_id = &"archer"; build.evolution_id = &"hunter" if hunter else &""; build.base_level = 30; build.job_level = 40 if hunter else 20; build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(&"archer",build.evolution_id); build.attribute_allocations = {&"int":20,&"dex":10}
	build.skill_ranks = {&"foliage_shelter":1,&"slowing_arrow":2}
	if hunter: build.skill_ranks.merge({&"hunter_covering_shot":1,&"hunter_total_cover":1,&"hunter_thorn_trap":1,&"hunter_shooting_discipline":1,&"hunter_easy_prey":1})
	var pending := true
	while pending:
		pending = false
		for skill: StringName in build.skill_ranks.keys():
			var requirements: Dictionary = build._skill_catalog.skill_metadata(skill)["rank_requirements"][1]["skill_ranks"]
			for id: StringName in requirements:
				if int(build.skill_ranks.get(id,0)) < int(requirements[id]): build.skill_ranks[id] = requirements[id]; pending = true
	var state := RunState.from_build("f1_fixture",build)
	if fan: state.augment_stacks[&"hunter_covering_fan"] = 1
	check(state.set_effect_catalog(catalog)["ok"],"real catalog injects captured fan policy")
	caster = PlayerActor.new(); caster.configure(nav,state); controller.player = caster; controller.run_state = state; controller.add_child(caster); caster.set_process(false)
	check(caster.bind_world_geometry(world,Fixture.point("landing",Vector3(210,40,150)),profile,str(caster.get_instance_id()))["ok"],"real caster bound")
	primary = target(Fixture.point("bridge",Vector3(100,40,150))); neighbor = target(Fixture.point("bridge",Vector3(60,40,150))); shadow = target(Fixture.point("root",Vector3(60,0,150))); controller.enemies.assign([primary,neighbor,shadow]); controller.rng.seed = 711
	controller.trap_registry = PlayerTrapRegistry.new(); controller.add_child(controller.trap_registry)
	caster.hunter_trap_requested.connect(controller._on_hunter_trap_requested); caster.hunter_covering_shot_requested.connect(controller._on_hunter_covering_shot_requested); caster.foliage_shelter_requested.connect(controller._on_foliage_shelter_requested); caster.hunter_total_cover_requested.connect(controller._on_hunter_total_cover_requested); caster.slowing_arrow_requested.connect(controller._on_slowing_arrow_requested); caster.status_damage_requested.connect(controller._on_attack_requested)
func target(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); controller.add_child(actor); actor.setup("f1",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000; actor.health.physical_defense = 0; actor.health.magic_defense = 0; actor.health.flee_rating = 0
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"real target bound")
	actor.set_process(false); actor.health.damage_applied.connect(controller._on_enemy_damage_resolved); actor.status_damage_requested.connect(controller._on_attack_requested)
	return actor
