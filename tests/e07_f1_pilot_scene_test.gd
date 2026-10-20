extends SceneTree
## Real main.tscn/controller/HUD assembly in isolated native fixture. No projection/input/visual acceptance.
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
const Sequence = preload("res://scripts/world/elementalist_sequence.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	for row: Array in [[&"swordsman",&"",&"slash"],[&"mage",&"",&"fireball"],[&"archer",&"",&"double_shot"],[&"swordsman",&"defender",&"defender_counterstroke"],[&"swordsman",&"berserker",&"berserker_rupture"],[&"mage",&"elementalist",&"elementalist_flame_burst"],[&"mage",&"spiritualist",&"spiritualist_dissipation"],[&"archer",&"sentinel",&"sentinel_headshot"],[&"archer",&"hunter",&"hunter_thorn_trap"],[&"mage",&"mg_ar",&"geometer_trace"]]:
		await _identity(row[0],row[1],row[2])
	print("E07 F1 native pilot scene: %d checks, %d failures; identities=10; presentation=logical_assembly_only; D05_visual_separate" % [checks,failures])
	quit(1 if failures else 0)
func _identity(base: StringName,evolution: StringName,skill: StringName) -> void:
	var build := BuildSnapshot.new(); build.character_id = "f1_native_pilot"; build.base_class_id = base; build.evolution_id = evolution; build.base_level = 30; build.job_level = 40; build.skill_ranks = {skill:1}; build.attribute_allocations = {&"dex":30,&"int":20}
	if evolution == &"mg_ar": build.skill_ranks[&"geometer_triangulation"] = 5
	Dependencies.complete_snapshot(build); build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(base,evolution)
	RunController.pending_run_state = RunState.from_build("f1_fixture",build); RunController.pending_run_facade = null; RunController.pending_training_mode = true
	var c := load("res://scenes/main.tscn").instantiate() as RunController
	c.control_preferences.path = "res://.godot/f1_pilot_controls.cfg"
	root.add_child(c); c.set_process(false); c.player.set_process(false); c.rng.seed = 711
	check(c.player.is_alive() and c.run_state.uses_persistent_build() and c.training_boss != null and not c.run_finished,"real main scene/controller/HUD initializes legal identity: "+String(base)+"/"+String(evolution))
	var input := Fixture.make(); var world := WorldGeometry.new(); var profile := input.traversal.to_data()
	check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"real F0 manifest supplies native scene geometry")
	check(c.player.bind_world_geometry(world,Fixture.point("root",Vector3(20,0,150)),profile,str(c.player.get_instance_id()))["ok"],"actual scene player binds lower support")
	c.player.set_process(false)
	var lower := c.training_boss
	check(lower.bind_world_geometry(world,Fixture.point("root",Vector3(60,0,150)),profile,str(lower.get_instance_id()))["ok"],"actual training EnemyActor binds independent logical body")
	lower.set_process(false); lower.health.max_hp = 100000; lower.health.current_hp = 100000
	var upper := CombatActor.new(); c.add_child(upper); upper.setup("Piso superior",Color.WHITE,StatCalculator.calculate({&"vit":10})); upper.health.max_hp = 100000; upper.health.current_hp = 100000
	check(upper.bind_world_geometry(world,Fixture.point("bridge",Vector3(60,40,150)),profile,str(upper.get_instance_id()))["ok"],"overlapping projected upper target has distinct explicit support")
	upper.set_process(false); c.enemies.append(upper)
	c.player.global_position = Vector2(-5000,5000); lower.global_position = Vector2(5000,-5000); upper.global_position = lower.global_position
	var original := c.player.world_point().to_data(); var sp := c.player.current_sp
	if evolution == &"mg_ar":
		check(c.geometer_casting != null and c.geometer_casting.bind_world_construction(12)["ok"],"native scene Geometer receives explicit field height and support")
		c.geometer_casting.targets = c.enemies
		for index: int in 3:
			var id := &"geometer_triangulation" if index == 2 else &"geometer_trace"
			var points: Array[Vector3] = [Vector3(20,0,120),Vector3(80,0,120),Vector3(20,0,180)]
			c.player.mage_cooldowns[id] = 0; c.geometer_casting.select(&"fire")
			var cast := c.geometer_casting.begin_world_trace(id,Fixture.point("root",points[index]),null,world.geometry_revision)
			check(cast["ok"],"native scene grammar uses world entry")
			if c.player.has_active_cast(): c.player._advance_world_cast(10)
			for child: Node in c.geometer_casting.get_children():
				if child is GeometerTraceProjectile and not child.is_queued_for_deletion(): child.set_process(false); child._process(1)
		check(c.geometer_casting.construction.has_active_figure(),"native scene forms actual supported triangle")
	else:
		c.player.sentinel_state.focus = SentinelTuning.FOCUS_CAP
		var preview := c.player.preview_world_skill(skill,lower.world_point(),Vector3.RIGHT,lower,c.enemies,world.geometry_revision)
		check(preview["ok"] and c.player.current_sp == sp,"native preview uses same logical source and pays nothing")
		var cast := c.cast_world_skill(skill,lower.world_point(),Vector3.RIGHT,lower,world.geometry_revision)
		check(cast["ok"],"native controller routes representative active through spatial transaction")
		if c.player.has_active_cast(): c.player._advance_world_cast(10)
		check(c.player.world_cast_status()["ok"] and c.player.current_sp < sp,"native handler commits canonical cost once")
		for child: Node in c.get_children():
			if child is PlayerProjectile and not child.is_queued_for_deletion(): child.set_process(false); child.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; child.request.can_crit = false; child._process(2)
			elif child.get_script() == Sequence and not child.is_queued_for_deletion(): child.set_process(false); child._process(2)
			elif child is HunterTrap and not child.is_queued_for_deletion(): child.set_process(false); child._process(2)
	check(upper.health.current_hp == 100000 and c.player.world_point().to_data() == original,"native consumer never reaches projected upper body or moves caster from a pixel coordinate")
	check(not c.run_finished,"logical sample does not invoke campaign completion/loot/save flow")
	c.queue_free(); await process_frame
