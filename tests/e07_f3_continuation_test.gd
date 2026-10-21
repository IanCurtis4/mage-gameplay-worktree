extends SceneTree
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
const SpatialFixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Sequence = preload("res://scripts/world/elementalist_sequence.gd")
var checks := 0
var failures := 0
var measurements: Array[Dictionary] = []
var selected_skill: StringName = &""
var cut_during_preparation := false
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var identities: Array[Array] = [[&"swordsman",&""],[&"mage",&""],[&"archer",&""],[&"swordsman",&"defender"],[&"swordsman",&"berserker"],[&"mage",&"elementalist"],[&"mage",&"spiritualist"],[&"archer",&"sentinel"],[&"archer",&"hunter"],[&"mage",&"mg_ar"]]
	for delta: float in [1.0/30.0,1.0/60.0,0.25]:
		for identity: Array in identities: await _case(identity[0],identity[1],delta)
	var output := FileAccess.open("res://.godot/verification/e07_f3_measurements.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(measurements,"  ",true)); output.close()
	print("E07 F3 continuation: %d checks, %d failures; scenarios=%d" % [checks,failures,measurements.size()])
	quit(1 if failures else 0)
func _case(base: StringName,evolution: StringName,delta: float) -> void:
	var build := BuildSnapshot.new()
	build.character_id = "f3_fixture"
	build.base_class_id = base; build.evolution_id = evolution
	build.base_level = 30; build.job_level = 20 if evolution.is_empty() else 40
	build.attribute_allocations = {&"vit":20,&"dex":20,&"int":20}
	build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(base,evolution)
	for skill: StringName in build.library_skill_ids: build.skill_ranks[skill] = 1
	Dependencies.complete_snapshot(build)
	RunController.pending_run_state = RunState.from_build("f3_fixture",build)
	var source := RunController.new()
	root.add_child(source)
	_disable(source)
	source.rng.seed = 20261020
	source.player.health._hp_deficit = 30.5
	source.player._sp_deficit = 15.5
	source.player.attack_cooldown = 0.3
	var input := SpatialFixture.make()
	for part: ExpeditionPartDefinition in input.parts:
		for surface: ExpeditionSurfaceDefinition in part.surfaces:
			for index: int in surface.vertices.size(): surface.vertices[index] *= Vector3(10,1,10)
		for connector: ExpeditionConnectorDefinition in part.connectors: connector.position *= Vector3(10,1,10); connector.width *= 10
		for socket: ExpeditionSocketDefinition in part.sockets: socket.position *= Vector3(10,1,10)
		for index: int in part.solid_volumes.size():
			var volume: AABB = part.solid_volumes[index]; part.solid_volumes[index] = AABB(volume.position*Vector3(10,1,10),volume.size*Vector3(10,1,10))
	var world := WorldGeometry.new()
	check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"real geometry fixture builds")
	check(source.player.bind_world_geometry(world,SpatialFixture.point("root",Vector3(200,0,500)),input.traversal.to_data(),str(source.player.get_instance_id()))["ok"],"player has supported world position")
	for index: int in source.enemies.size():
		var enemy: CombatActor = source.enemies[index]
		enemy.health.max_hp = 100000; enemy.health.current_hp = 100000
		check(enemy.bind_world_geometry(world,SpatialFixture.point("root",Vector3(250+index*40,0,500)),input.traversal.to_data(),str(enemy.get_instance_id()))["ok"],"enemies have supported distinct positions")
	if source.geometer_casting != null: check(source.geometer_casting.bind_world_construction(16)["ok"],"Geometer construction has world support")
	_prepare(source,evolution)
	_disable(source)
	await process_frame # Complete deferred deletions before the coherent cut.
	check(source.player.run_state.effects_valid(),"real identity builds: "+String(evolution if not evolution.is_empty() else base))
	var barrier := SnapshotTickBarrier.new()
	paused = true
	check(barrier.acquire(source)["ok"],"scene freezes at completed tick")
	var registry := SnapshotRegistry.new()
	var captured := registry.capture(source,barrier)
	check(captured["ok"],"complete scene captures "+String(base)+"/"+String(evolution)+": "+str(captured.get("detail",captured.get("error_code",""))))
	barrier.release(); paused = false
	if not captured["ok"]: source.free(); await process_frame; return
	var expected: Array[Dictionary] = []
	var tick_count := ceili(2.5/delta)
	for index: int in tick_count:
		_step(source,delta)
		expected.append(_outcome(source))
	var delivered_damage := 100000.0 - source.enemies[0].health.current_hp
	var next_random := source.rng.randf()
	source.free()
	await process_frame
	var restorer := SnapshotRegistry.new()
	var restored := restorer.restore(captured["snapshot"])
	check(restored["ok"],"complete scene reconstructs: "+str(restored.get("detail",restored.get("error_code",""))))
	if restored["ok"]:
		var copy: RunController = restored["root"]
		check(restorer.install(restored,root)["ok"],"passive graph installs without spawning/resetting")
		check(restorer.activate(restored)["ok"],"validated graph activates explicitly")
		_disable(copy)
		check(copy.run_state.character_id == "f3_fixture","same character/build, no new run constructor")
		for index: int in tick_count:
			_step(copy,delta)
			check(_outcome(copy) == expected[index],"next real damage/state/RNG equal at tick%d delta%f %s/%s" % [index,delta,base,evolution])
		check(copy.rng.randf() == next_random,"next RNG output after all real effects identical")
		measurements.append({"base":base,"evolution":evolution,"skill":selected_skill,"delta":delta,"damage":delivered_damage,"bytes":captured["bytes"],"capture_usec":captured["capture_usec"],"restore_usec":restored["restore_usec"],"kinds":captured["snapshot"]["coverage"].keys()})
		copy.free()
	await process_frame

func _prepare(c: RunController,evolution: StringName) -> void:
	if selected_skill == &"enemy_arrow_fixture":
		var enemy: EnemyActor = c.enemies[0]
		enemy.player_target_acquired = true
		enemy._try_attack(true)
		return
	var skill: StringName = &"slash" if c.run_state.class_id == &"swordsman" else &"fireball" if c.run_state.class_id == &"mage" else &"arrow_rain"
	match evolution:
		&"defender": skill = &"defender_line_lock"
		&"berserker": skill = &"berserker_blood_rift"
		&"elementalist": skill = &"elementalist_ember_path"
		&"spiritualist": skill = &"spiritualist_soul_drain"
		&"sentinel": skill = &"sentinel_headshot"; c.player.sentinel_state.focus = SentinelFocusState.CAP
		&"hunter": skill = &"hunter_freezing_trap"
		&"mg_ar":
			var trace := c.geometer_casting.begin_world_trace(&"geometer_trace",SpatialFixture.point("root",Vector3(300,0,500)),null,c.player.world_motion.geometry.geometry_revision)
			check(trace["ok"],"real Geometer trace prepares")
			if c.player.has_active_cast() and not cut_during_preparation: c.player._advance_world_cast(10)
			return
	if not selected_skill.is_empty(): skill = selected_skill
	var point := SpatialFixture.point("root",Vector3(250,0,500))
	var cast := c.player.prepare_world_sentinel_explosive(c.player.world_motion.geometry.geometry_revision) if skill == &"sentinel_explosive_shot" else c.cast_world_skill(skill,point,Vector3.RIGHT,c.enemies[0],c.player.world_motion.geometry.geometry_revision,0,16.0)
	check(cast["ok"],"real world skill emits before snapshot: "+String(skill)+" "+str(cast.get("error_code","")))
	if c.player.has_active_cast() and not cut_during_preparation: c.player._advance_world_cast(10)
	if skill == &"spiritualist_echo_curse":
		var trigger := c.cast_world_skill(&"fire_spear",null,Vector3.RIGHT,c.enemies[0],c.player.world_motion.geometry.geometry_revision)
		check(trigger["ok"],"real follow-up prepares an Echo carrier")
		if c.player.has_active_cast(): c.player._advance_world_cast(10)
		_step_effects(c,1)
	if skill == &"sentinel_explosive_shot":
		c.player.attack_cooldown = 0
		c.player.target = c.enemies[0]
		c.player._try_basic_attack()
	_disable(c)

func _step(c: RunController,delta: float) -> void:
	c._advance_runtime(delta)
	c.player._process(delta)
	for enemy: CombatActor in c.enemies.duplicate(): enemy._process(delta)
	_step_effects(c,delta)
func _step_effects(node: Node,delta: float) -> void:
	for child: Node in node.get_children():
		if child.is_queued_for_deletion(): continue
		if child is PlayerProjectile or child is ArrowProjectile or child is PlayerTrap or child is ArrowRain or child is SoulImpactSequence or child is FoliageShelter or child is HunterTarField or child is FireWall or child is LightningWall or child is IceWall or child is PhantomBarrier or child.get_script() == Sequence:
			child._process(delta)
		_step_effects(child,delta)
func _outcome(c: RunController) -> Dictionary:
	var enemies: Array = []
	for enemy: CombatActor in c.enemies:
		var state := {"hp":enemy.health.current_hp,"burn":enemy.burn_remaining,"slow":enemy.slow_remaining,"root":enemy.root_remaining(),"position":enemy.world_point().position}
		if enemy is EnemyActor:
			state.merge({"sp":enemy._mob_sp,"cooldowns":enemy._mob_cooldowns.duplicate(),"cast":enemy._mob_cast.get("remaining",0.0),"engagement":enemy.engagement_mode,"summon_used":enemy.summon_used,"summoned":enemy.is_summoned,"owner":c.enemies.find(instance_from_id(enemy.summoner_id)) if enemy.summoner_id != 0 else -1})
		enemies.append(state)
	var geometer: Dictionary = {}
	if c.geometer_casting != null:
		geometer = {"shape":c.geometer_casting.construction.shape,"pending":c.geometer_casting.construction.grammar.pending_count(),"points":c.geometer_casting.construction.positions(),"remaining":c.geometer_casting.construction.figure_remaining,"claims":c.geometer_casting.interaction_ledger._projectile_components.size()}
	var class_states: Array = []
	for enemy: CombatActor in c.enemies:
		class_states.append({"wounds":c.player.berserker_wound_stacks(enemy.get_instance_id()),"opening":c.player.hunter_state._openings.get(enemy.get_instance_id(),{}).get("remaining",0.0),"marks":c.spiritualist_echo_state.marks.get(enemy.get_instance_id(),{}).get("remaining",0.0)})
	var tickets: Array = []
	if c.reward_service != null:
		for id: String in c.reward_service._queue:
			var ticket := c.reward_service.ticket(id)
			tickets.append({"id":id,"payload":ticket["payload"],"sequence":ticket["sequence"],"delivered":ticket["delivered"]})
	return {"hp":c.player.health.current_hp,"sp":c.player.current_sp,"cooldowns":c.player.mage_cooldowns.duplicate(),"position":c.player.world_point().position,"cast":c.player.active_cast_remaining,"rng":c.rng.state,"enemies":enemies,"drain_ticks":c.spiritualist_drain_state.ticks_issued,"drain_active":c.spiritualist_drain_state.active,"focus":c.player.sentinel_state.focus,"reserved_focus":c.player.sentinel_state.reserved_focus,"shield":c.player.shield_remaining,"echoes":c.spiritualist_echo_state.pending.size(),"geometer":geometer,"kits":class_states,"tickets":tickets,"choices":c.run_state.offer_token()}
func _disable(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child: Node in node.get_children(): _disable(child)
