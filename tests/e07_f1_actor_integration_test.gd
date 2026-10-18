extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var input := Fixture.make()
	var built := ExpeditionAssembler.build(input)
	if not built["ok"]: push_error(str(built)); quit(1); return
	var geometry := WorldGeometry.new()
	geometry.configure(built["data"]["manifest"],"sample")
	var profile := input.traversal.to_data()
	var lower := Fixture.point("root",Vector3(50,0,150))
	var upper := Fixture.point("bridge",Vector3(50,40,150))
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0,0,1000,800),[],0)
	var mage := player(nav,&"mage",{&"teleport":1})
	check(mage.bind_world_geometry(geometry,lower,profile,"mage")["ok"],"real player binds world support")
	var sp := mage.current_sp
	check(not mage.use_world_teleport(upper,geometry.geometry_revision) and mage.current_sp == sp and mage.skill_cooldown(&"teleport") == 0.0 and mage.world_point().to_data() == lower.to_data(),"invalid slab cast commits no resources/cooldown/motion")
	check(not mage.use_teleport(Vector2(80,150)) and mage.current_sp == sp,"legacy cast explicitly rejected when bound, no 2D fallback")
	var destination := Fixture.point("root",Vector3(80,0,150))
	var preview_revision := geometry.geometry_revision
	check(geometry.insert_obstacle("wall",AABB(Vector3(60,0,130),Vector3(5,20,40)),preview_revision)["ok"],"planar wall inserted")
	check(not mage.use_world_teleport(destination,preview_revision) and mage.current_sp == sp,"stale preview rejected at real player commit")
	check(mage.use_world_teleport(destination,geometry.geometry_revision),"real player teleport crosses planar wall")
	check(mage.current_sp == sp-mage.skill_cost(&"teleport") and mage.skill_cooldown(&"teleport") > 0.0 and mage.world_point().to_data() == destination.to_data(),"canonical resource/cooldown authority, exact world destination")
	geometry.remove_obstacle("wall",geometry.geometry_revision)
	var swordsman := player(nav,&"swordsman",{&"dash":1})
	var start := Fixture.point("root",Vector3(50,0,50))
	check(swordsman.bind_world_geometry(geometry,start,profile,"swordsman")["ok"],"swordsman binds real world")
	var ramp_end := Fixture.point("landing",Vector3(220,40,50))
	check(swordsman.use_world_dash(ramp_end,geometry.geometry_revision),"dash plans a connected ramp route")
	var arrived := false
	var crossed_ramp := false
	for index: int in range(300):
		var movement := swordsman.advance_world(1.0)
		check(movement["ok"],"continuous movement step %d: %s point=%s" % [index,movement,swordsman.world_point().to_data()])
		if not movement["ok"]: break
		var current := swordsman.world_point()
		if current.surface_id.contains("slope") and current.position.y > 0.0 and current.position.y < 40.0: crossed_ramp = true
		if movement["data"]["arrived"]: arrived = true; break
	check(arrived and crossed_ramp and swordsman.world_point().to_data() == ramp_end.to_data(),"actual player traverses continuous ramp without repairing by teleport")
	var enemy := EnemyActor.new()
	root.add_child(enemy)
	check(enemy.bind_world_geometry(geometry,lower,profile,"enemy")["ok"],"real enemy uses same logical motion authority")
	check(enemy.move_world_to(upper,geometry.geometry_revision)["ok"],"enemy plans path around to bridge")
	var travelled := enemy.advance_world(1000.0)
	check(travelled["ok"] and travelled["data"]["arrived"] and enemy.world_point().to_data() == upper.to_data(),"real enemy crosses ramp and bridge connections")
	check(enemy.move_world_to(lower,geometry.geometry_revision)["ok"],"return route retains surface")
	geometry.insert_obstacle("revision",AABB(Vector3(270,40,100),Vector3(5,10,5)),geometry.geometry_revision)
	var before := enemy.world_point().to_data()
	check(not enemy.advance_world(10.0)["ok"] and enemy.world_point().to_data() == before,"revision change stops actor before stale route movement")
	for node: Node in [mage,swordsman,enemy]: node.queue_free()
	await process_frame
	print("E07 F1 actor integration: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func player(nav: ArenaNavigation, identity: StringName, ranks: Dictionary) -> PlayerActor:
	var build := BuildSnapshot.new()
	build.character_id = "f1_"+identity
	build.base_class_id = identity
	build.skill_ranks.assign(ranks)
	var result := PlayerActor.new()
	result.configure(nav,RunState.from_build("f1_fixture",build))
	root.add_child(result)
	result.set_process(false)
	return result
