extends SceneTree
const Sequence = preload("res://scripts/world/elementalist_sequence.gd")
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
class Controller extends RunController:
	func _ready() -> void: pass
var checks := 0
var failures := 0
var catalog: BuildEffectCatalog
var owned: Array[Node] = []
var c: Controller
var world: WorldGeometry
var profile: Dictionary
var lower: CombatActor
var upper: CombatActor
var results: Array[Dictionary] = []
var evidence: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var loaded := BuildContentLoader.load_catalog(true,true); check(loaded["ok"],"complete production effect catalog loads unchanged")
	if not loaded["ok"]: quit(1); return
	catalog = loaded["catalog"]
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for id: StringName in catalog.ids(origin):
			var definition := catalog.get_definition(origin,id)
			for effect: EffectDefinition in definition.effects:
				if effect.kind == EffectDefinition.Kind.STAT: continue
				_case(origin,id,definition,effect)
	check(evidence.size() == 27,"all27 non-stat production recipes have explicit spatial evidence")
	var output := FileAccess.open("res://.godot/f1_composition_evidence.json",FileAccess.WRITE); output.store_string(JSON.stringify(evidence,"  ",true)); output.close()
	_cleanup()
	await process_frame
	print("E07 F1 compositions: %d checks, %d failures; recipes=%d" % [checks,failures,evidence.size()])
	quit(1 if failures else 0)
func _case(origin: StringName,id: StringName,definition: Resource,effect: EffectDefinition) -> void:
	var base: StringName = definition.allowed_origins[0] if not definition.allowed_origins.is_empty() else &"mage"
	var evolution: StringName = definition.allowed_evolutions[0] if not definition.allowed_evolutions.is_empty() else &""
	if not effect.allowed_origins.is_empty(): base = effect.allowed_origins[0]
	if not effect.allowed_evolutions.is_empty(): evolution = effect.allowed_evolutions[0]
	var skill: StringName = effect.target_skill_ids[0] if not effect.target_skill_ids.is_empty() else &"basic_attack"
	if effect.kind == EffectDefinition.Kind.ACTIVE_GRANT: skill = effect.granted_skill_id
	_setup(base,evolution,origin,id,definition,skill,effect.kind == EffectDefinition.Kind.ACTIVE_GRANT)
	var composed := c.run_state.composed_build()
	check(composed["ok"] and c.run_state.effects_valid(),"real source composes without catalog mutation: "+String(id))
	if not composed["ok"]: return
	var proof := {"origin":origin,"definition_id":id,"effect_id":effect.id,"family":effect.family_id,"kind":EffectDefinition.Kind.keys()[effect.kind],"base":base,"evolution":evolution,"skill":skill}
	if effect.kind == EffectDefinition.Kind.PROC:
		_proc_case(effect,skill)
		proof["consumer"] = "canonical spatial hit -> HealthState -> RunController -> claimed same-target secondary"
	elif effect.kind == EffectDefinition.Kind.KIT_RULE:
		check(bool(composed["kit_policies"].get(effect.axis,false)),"authored nominal kit policy is active: "+String(effect.axis))
		if id in [&"geometer_ground_anchor",&"geometer_collapse_first_element"]: _geometer_policy(id)
		proof["consumer"] = "actual Geometer figure" if base == &"mage" and evolution == &"mg_ar" else "composed nominal policy; real consumers reexecuted by F1 hunter_traps/hunter_cover/echo/chain/ember"
	elif skill == &"teleport":
		var sp := c.player.current_sp
		check(c.player.use_world_teleport(Fixture.point("root",Vector3(80,0,550)),world.geometry_revision) and c.player.world_point().position == Vector3(80,0,550) and c.player.current_sp < sp,"equipment grant uses actual supported teleport without learning mage library")
		proof["consumer"] = "PlayerActor.use_world_teleport"
	else:
		if effect.kind == EffectDefinition.Kind.ACTIVE_GRANT: check(not c.run_state.build_snapshot.skill_ranks.has(skill) and c.run_state.has_item_active(skill),"item active remains separate from permanent learned ranks")
		if effect.axis == &"range":
			var nominal := ClassCatalog.skill_definition(skill).rank_definition(c.player.skill_rank(skill)).range
			var composed_range := c.player.skill_range(skill)
			check(composed_range > nominal,"real card increases canonical range")
			_move(c.player,Fixture.point("root",Vector3(80,0,80)))
			_move(lower,Fixture.point("root",Vector3(80,0,80+(nominal+composed_range)*0.5)))
		var count := c.run_state.projectile_count(skill)
		var cast := c.cast_world_skill(skill,null,Vector3.RIGHT,lower,world.geometry_revision)
		check(cast["ok"],"actual composed spell enters spatial preparation: "+String(id))
		if c.player.has_active_cast(): c.player._advance_world_cast(10)
		var shots: Array[PlayerProjectile] = []
		for child: Node in c.get_children():
			if child is PlayerProjectile and not child.is_queued_for_deletion(): shots.append(child); child.set_process(false)
		check(shots.size() == count,"physical projectile count equals one composed canonical capture")
		var hp := lower.health.current_hp; var upper_hp := upper.health.current_hp
		for shot: PlayerProjectile in shots: shot.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; shot.request.can_crit = false; shot._process(2)
		check(lower.health.current_hp < hp and upper.health.current_hp == upper_hp,"composed real spell reaches selected body and never projected other floor")
		proof["consumer"] = "RunController canonical world spell/projectiles"; proof["projectiles"] = count
	# Emitted snapshots survive removal; a new preview observes the new composition/revision.
	var old_hp := c.player.health.max_hp-c.player.health.current_hp; var old_sp := c.player.sp_deficit(); var old_cd := c.player.skill_cooldown(skill)
	if origin == &"augment": c.run_state.augment_stacks.erase(id)
	elif origin == &"equipment":
		for slot: StringName in c.run_state.build_snapshot.equipped:
			if c.run_state.build_snapshot.equipped[slot] == &"recipe_item": c.run_state.build_snapshot.equipped[slot] = null
	else: c.run_state.card_sockets.clear(); c.run_state.card_instances.clear()
	c.run_state.runtime_revision += 1; c.player.apply_run_modifiers(c.run_state)
	check(is_equal_approx(c.player.health.max_hp-c.player.health.current_hp,old_hp) and is_equal_approx(c.player.sp_deficit(),old_sp) and c.player.skill_cooldown(skill) == old_cd,"source removal never heals/refunds/resets cooldown")
	evidence.append(proof)
func _proc_case(effect: EffectDefinition,skill: StringName) -> void:
	var hp := lower.health.current_hp; var upper_hp := upper.health.current_hp
	if skill == &"basic_attack":
		c.player.target = lower
		c.player._try_basic_attack()
	else:
		c.player.sentinel_state.focus = SentinelTuning.FOCUS_CAP
		var cast := c.cast_world_skill(skill,lower.world_point(),Vector3.RIGHT,lower,world.geometry_revision)
		check(cast["ok"],"targeted proc source enters actual canonical spatial skill")
		if c.player.has_active_cast(): c.player._advance_world_cast(10)
	_drain()
	var procs := results.filter(func(result: Dictionary) -> bool: return result.get("skill_id",&"") == effect.family_id)
	check(lower.health.current_hp < hp and upper.health.current_hp == upper_hp,"causal parent contact respects supported body/floor")
	check(procs.size() == 1 and procs[0]["target_id"] == lower.get_instance_id() and not bool(procs[0].get("can_trigger_effects",true)),"real catalog PROC is one claimed same-target secondary, never another spatial selection")
	if not procs.is_empty():
		var before := lower.health.current_hp
		c.player.resolve_build_effect_procs(procs[0])
		check(lower.health.current_hp == before,"secondary cannot cascade or replay its family")
func _setup(base: StringName,evolution: StringName,origin: StringName,id: StringName,definition: Resource,skill: StringName,grant: bool) -> void:
	_cleanup()
	var input := Fixture.make(); profile = input.traversal.to_data()
	for part: ExpeditionPartDefinition in input.parts:
		for surface: ExpeditionSurfaceDefinition in part.surfaces:
			for index: int in surface.vertices.size(): surface.vertices[index] = _scale(surface.vertices[index])
		for connector: ExpeditionConnectorDefinition in part.connectors: connector.position = _scale(connector.position); connector.width *= 4
		for socket: ExpeditionSocketDefinition in part.sockets: socket.position = _scale(socket.position)
		for index: int in part.solid_volumes.size():
			var volume: AABB = part.solid_volumes[index]; part.solid_volumes[index] = AABB(_scale(volume.position),_scale(volume.size))
	world = WorldGeometry.new(); check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"F0 supplies composition support")
	c = Controller.new(); root.add_child(c); owned.append(c); c.set_process(false); c.rng.seed = 711; c.navigation.configure(Rect2(0,0,4000,4000),[],0)
	var build := BuildSnapshot.new(); build.character_id = "f1_composition"; build.base_class_id = base; build.evolution_id = evolution; build.base_level = 30; build.job_level = 40; build.attribute_allocations = {&"dex":30,&"int":20}
	if skill != &"basic_attack" and not grant: build.skill_ranks[skill] = 1
	if base == &"mage": build.skill_ranks[&"fire_spear"] = 1; build.skill_ranks[&"ice_spear"] = 1
	if evolution == &"mg_ar": build.skill_ranks[&"geometer_trace"] = 1; build.skill_ranks[&"geometer_triangulation"] = 5; build.skill_ranks[&"geometer_collapse"] = 1
	if evolution == &"hunter":
		for active: StringName in [&"hunter_mark",&"hunter_covering_shot",&"hunter_freezing_trap",&"hunter_tar_trap",&"hunter_thorn_trap"]: build.skill_ranks[active] = 1
	if evolution == &"spiritualist": build.skill_ranks[&"spiritualist_echo_curse"] = 1; build.skill_ranks[&"spiritualist_soul_drain"] = 1
	Dependencies.complete_snapshot(build); build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(base,evolution)
	if origin == &"equipment": _equip(build,definition as EquipmentDefinition,&"recipe_item")
	elif origin == &"card":
		var host := catalog.get_definition(&"equipment",&"arena_ember_staff") as EquipmentDefinition
		_equip(build,host,&"card_host")
		var acquired := build.card_inventory.grant(id,catalog,"f1_card")
		check(acquired["ok"],"real card instance acquired in isolated value fixture")
		var definitions := {host.id:host.metadata()}
		var socketed := build.card_inventory.preview({"kind":&"socket","equipment_instance_id":&"card_host","socket_index":0,"card_instance_id":acquired["card_instance_id"]},build.equipped,build.equipment_instances,definitions)
		check(socketed["ok"],"real card candidate validates host and socket")
		if socketed["ok"]: build.card_inventory = socketed["inventory"]
	c.run_state = RunState.from_build("f1_fixture",build)
	if origin == &"augment": c.run_state.augment_stacks[id] = 1
	check(c.run_state.set_effect_catalog(catalog)["ok"],"real complete catalog composes into isolated run")
	c.player = PlayerActor.new(); c.add_child(c.player); c.player.configure(c.navigation,c.run_state); c.player.set_process(false)
	check(c.player.bind_world_geometry(world,Fixture.point("root",Vector3(80,0,500)),profile,str(c.player.get_instance_id()))["ok"],"composition caster has explicit support")
	c.player.global_position = Vector2(-9999,9999)
	lower = _actor(Fixture.point("root",Vector3(130,0,500))); upper = _actor(Fixture.point("bridge",Vector3(130,40,500))); c.enemies.assign([lower,upper])
	lower.health.damage_applied.connect(c._on_enemy_damage_resolved)
	lower.health.damage_applied.connect(func(result: Dictionary) -> void: results.append(result.duplicate(true)))
	upper.health.damage_applied.connect(c._on_enemy_damage_resolved)
	c.player.status_damage_requested.connect(c._on_attack_requested)
	c.player.attack_requested.connect(func(request: DamageRequest,actor: CombatActor) -> void: request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; request.can_crit = false; c._on_attack_requested(request,actor))
	c.player.world_attack_requested.connect(c._on_world_attack_requested)
	c.player.mage_projectile_requested.connect(c._on_mage_projectile_requested)
	c.player.precision_projectile_requested.connect(c._on_precision_projectile_requested)
	c.player.sentinel_projectile_requested.connect(c._on_sentinel_projectile_requested)
	c.player.defender_hit_requested.connect(c._on_defender_hit_requested)
	c.player.elementalist_flame_burst_requested.connect(c._on_elementalist_flame_burst_requested)
	c.player.elementalist_area_requested.connect(c._on_elementalist_area_requested)
func _equip(build: BuildSnapshot,definition: EquipmentDefinition,instance: StringName) -> void:
	var created := EquipmentInstance.from_metadata(instance,definition.id,definition.metadata()); check(created["ok"],"real equipment metadata creates explicit item instance")
	if not created["ok"]: return
	build.equipment_instances[instance] = created["instance"]
	build.equipped[&"accessory_1" if definition.slot == &"accessory" else definition.slot] = instance
func _actor(point: ExpeditionWorldPoint) -> CombatActor:
	var actor := CombatActor.new(); root.add_child(actor); owned.append(actor); actor.set_process(false); actor.setup("Portador",Color.WHITE,StatCalculator.calculate({&"vit":10})); actor.health.max_hp = 100000; actor.health.current_hp = 100000
	check(actor.bind_world_geometry(world,point,profile,str(actor.get_instance_id()))["ok"],"composition target has explicit independent floor")
	actor.global_position = Vector2(9999,-9999)
	return actor
func _drain() -> void:
	for child: Node in c.get_children():
		if child is PlayerProjectile and not child.is_queued_for_deletion(): child.set_process(false); child.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; child.request.can_crit = false; child._process(2)
		elif child.get_script() == Sequence and not child.is_queued_for_deletion(): child.set_process(false); child._process(2)
func _geometer_policy(id: StringName) -> void:
	var casting := GeometerCasting.new(); c.add_child(casting); casting.configure(c.player); casting.targets = c.enemies; c.geometer_casting = casting
	casting.hit.connect(c._on_attack_requested); check(casting.bind_world_construction(12)["ok"],"nominal policy uses bound Geometer consumer")
	var state := casting.construction as WorldGeometerConstruction
	var points: Array[Vector3] = [Vector3(100,0,450),Vector3(300,0,450),Vector3(130,0,550)]
	for index: int in 3:
		var skill := &"geometer_triangulation" if index == 2 else &"geometer_trace"
		c.player.mage_cooldowns[skill] = 0
		casting.select(&"ice" if index == 0 and id == &"geometer_collapse_first_element" else &"fire")
		var target: CombatActor = lower if index == 2 and id == &"geometer_ground_anchor" else null
		var result := casting.begin_world_trace(skill,Fixture.point("root",points[index]) if target == null else null,target,world.geometry_revision)
		check(result["ok"],"policy prepares real triangle shot")
		if c.player.has_active_cast(): c.player._advance_world_cast(10)
		for child: Node in casting.get_children():
			if child is GeometerTraceProjectile and not child.is_queued_for_deletion(): child.set_process(false); child._process(1)
	check(state.has_active_figure(),"policy preserves canonical recipe and figure formation")
	if not state.has_active_figure(): return
	if id == &"geometer_ground_anchor":
		var fixed := state.world_points()[2].to_data()
		check(state.vertices[2].actor_id == 0,"triangulation ground policy captures fixed impact support")
		_move(lower,Fixture.point("root",Vector3(170,0,520))); casting.advance(0.1)
		check(state.world_points()[2].to_data() == fixed,"third vertex never follows carrier after fixed capture")
	else:
		check(lower.root_remaining() == 0,"fire C formation applies no ice control before collapse")
		var result := casting.begin_world_trace(&"geometer_collapse",null,null,world.geometry_revision)
		check(result["ok"] and state.vertices.is_empty() and lower.root_remaining() > 0,"first-element policy selects actual ice containment at collapse rather than fire C")
func _move(actor: CombatActor,point: ExpeditionWorldPoint) -> void:
	check(actor.move_world_to(point,world.geometry_revision)["ok"] and actor.advance_world(10000)["ok"],"composition fixture moves through actual supported route")
func _scale(point: Vector3) -> Vector3: return Vector3(point.x*4,point.y,point.z*4)
func _cleanup() -> void:
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	owned.clear(); results.clear()
