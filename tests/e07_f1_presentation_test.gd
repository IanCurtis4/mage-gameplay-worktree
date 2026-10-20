extends SceneTree
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var sample: Node2D = load("res://tests/fixtures/e07/f1/presentation_sample.tscn").instantiate()
	root.add_child(sample); sample.set_process(false)
	var c: RunController = sample.controller; var view: ExpeditionGeometryView = sample.view; var world: WorldGeometry = sample.world
	c.player.set_process(false); sample.lower.set_process(false)
	check(c.persistent_facade == null and c.control_preferences.path.begins_with("res://.godot/"),"native sample has isolated settings and no personal profile facade")
	var epoch := world.geometry_revision
	var snapshot := world.presentation_snapshot(epoch); check(snapshot["ok"] and snapshot["geometry_revision"] == epoch,"presentation consumes a revisioned copied stage")
	snapshot["data"]["surfaces"].clear(); check(world.presentation_snapshot(epoch)["data"]["surfaces"].size() == 4,"renderer cannot mutate logical surfaces")
	for row: Array in [["root",Vector3(60,0,150)],["slope",Vector3(450,60,150)],["landing",Vector3(750,120,450)],["bridge",Vector3(180,120,440)]]:
		var expected := Fixture.point(row[0],row[1]); var pixel := view.project(expected.position); var picked := view.pick(pixel,epoch)
		check(picked["ok"] and picked["data"]["point"]["surface_id"] == expected.surface_id and Vector3(picked["data"]["point"]["position"]).distance_to(expected.position) < 0.02,"camera ray roundtrips actual support "+String(row[0]))
	var bridge := Fixture.point("bridge",Vector3(180,120,440))
	var picked := view.pick(view.project(bridge.position),epoch); check(picked["ok"] and picked["data"]["point"]["surface_id"] == bridge.surface_id,"visible upper deck wins overlap, never current player floor")
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	event.position = c.get_canvas_transform()*view.to_global(view.project(Vector3(110,0,150)))
	c._unhandled_input(event)
	check(view.marker != null and view.marker.surface_id == Fixture.point("root",Vector3.ZERO).surface_id,"native left-click event reaches the same support resolver and marker")
	check(not view.point_visible(sample.lower.world_point().position+Vector3.UP*18) and view.point_visible(sample.upper.world_point().position+Vector3.UP*18),"presentation hides under-deck flights without hiding legal above-deck flights")
	var original := c.player.world_point().to_data(); var hp := c.player.health.current_hp; var sp := c.player.current_sp
	check(c.spatial_pointer_move(Vector2(50000,50000))["ok"] == false and c.player.world_point().to_data() == original and c.player.current_sp == sp,"off-map click rejected without moving/paying")
	var blocked := c.spatial_pointer_skill(&"fire_spear",view.project(sample.upper.world_point().position)+Vector2(0,-24),true)
	check(not blocked["ok"] and c.player.current_sp == sp,"preview rejects upper enemy behind solid deck")
	check(not c.spatial_pointer_skill(&"fire_spear",view.project(sample.upper.world_point().position)+Vector2(0,-24),false)["ok"] and c.player.current_sp == sp,"same logical commit rejects occluded attack with no payment")
	var destination := Fixture.point("bridge",Vector3(120,120,520))
	var move := c.spatial_pointer_move(view.project(destination.position))
	check(move["ok"] and move["data"]["cost"] > c.player.world_point().position.distance_to(destination.position),"click routes along ramp rather than projected shortcut")
	check(view.marker != null and view.marker.surface_id == destination.surface_id and view.marker_valid,"destination marker keeps exact selected support")
	check(c.player.advance_world(10000)["ok"],"route reaches bridge on actual connected surfaces")
	view.sync(); check(c.player.global_position.distance_to(view.to_global(view.project(c.player.world_point().position))) < 0.01 and c.player.health.current_hp == hp,"unchanged sprite follows logical point without deriving gameplay from pixels")
	var upper_pixel := view.project(sample.upper.world_point().position)+Vector2(0,-24)
	var preview := c.spatial_pointer_skill(&"fire_spear",upper_pixel,true)
	check(preview["ok"] and c.player.current_sp == sp,"same-floor preview is legal and pure")
	var cast := c.spatial_pointer_skill(&"fire_spear",upper_pixel,false)
	check(cast["ok"],"same-floor native pointer commits actual skill")
	if c.player.has_active_cast(): c.player._advance_world_cast(10)
	check(c.player.current_sp < sp,"same-floor cast pays canonical cost exactly at commit")
	var old_revision := world.geometry_revision
	var hidden: Array[String] = [bridge.surface_id]; view.hide_surfaces(hidden)
	check(not view.pick(view.project(bridge.position),world.geometry_revision)["ok"] and world.geometry_revision == old_revision,"hidden ceiling cannot receive clicks and retains slab collision/revision")
	var under := Fixture.point("root",Vector3(180,0,440))
	check(not world.query_attack({"geometry_rule_id":&"direct_volume","range":1000},under,bridge,world.geometry_revision)["data"]["hit"],"cutaway never disables collision")
	view.hide_surfaces([])
	var seam := view.pick(view.project(Vector3(300,0,150)),world.geometry_revision)
	check(not seam["ok"] and seam["error_code"] == &"ambiguous_surface","coincident surface seam is refused rather than choosing floor by order: "+str(seam))
	check(not view.pick(Vector2.ZERO,epoch-1)["ok"],"stale pick does not produce a fresh marker")
	# Public convex-region input must reject concavity and a forged cross-stage point.
	var polygon := PackedVector2Array([Vector2(50,100),Vector2(100,100),Vector2(70,120),Vector2(100,150),Vector2(50,150)])
	var region := world.ground_region(Fixture.point("root",Vector3(70,0,120)),polygon,sample.profile,world.geometry_revision)
	check(not region["ok"] and region["error_code"] == &"invalid_region" and region["geometry_revision"] == world.geometry_revision,"region envelope rejects concave input with current revision")
	check(not WorldSupportRegion.ground_contains({"anchor":{"stage_id":"sample"},"patches":[]},ExpeditionWorldPoint.create("other",bridge.surface_id,bridge.position)),"region never accepts a foreign stage")
	# Pointer ground fields use horizontal heading even when the selected support rises.
	c.run_state.skill_levels[&"phantom_barrier"] = 1
	c.run_state.build_snapshot.skill_ranks[&"phantom_barrier"] = 1
	Dependencies.complete_snapshot(c.run_state.build_snapshot); c.run_state.runtime_revision += 1; c.player.apply_run_modifiers(c.run_state)
	var ramp_origin := Fixture.point("slope",Vector3(340,16,150))
	check(c.player.move_world_to(ramp_origin,world.geometry_revision)["ok"] and c.player.advance_world(10000)["ok"],"pointer field source walks onto actual ramp support")
	view.sync()
	var ramp_aim := Fixture.point("slope",Vector3(380,32,150)); var aim_pixel := view.project(ramp_aim.position)
	var field_sp := c.player.current_sp
	var field_destination: Dictionary = {}
	for id: StringName in [&"fire_wall",&"lightning_wall",&"phantom_barrier",&"ice_wall"]:
		var placement := c.spatial_pointer_skill(id,aim_pixel,true)
		check(placement["ok"] and c.player.current_sp == field_sp,"ramp pointer previews horizontal supported field without paying: "+String(id))
		if placement["ok"]:
			var expected: Dictionary = placement["data"]["field"]["anchor"]
			check(view.marker != null and view.marker.to_data() == expected and Vector3(expected["position"]).distance_to(ramp_aim.position) > 50,"field marker uses actual fixed-range placement support, not the direction click")
			if id == &"fire_wall": field_destination = expected
	var placed := c.spatial_pointer_skill(&"fire_wall",aim_pixel,false)
	check(placed["ok"] and view.marker != null and view.marker.to_data() == field_destination,"pointer commit preserves actual previewed field destination")
	if c.player.has_active_cast(): c.player._advance_world_cast(10)
	var actual: FireWall
	for child: Node in c.get_children():
		if child is FireWall and child.world_field != null: actual = child
	check(c.player.world_cast_status()["ok"] and is_equal_approx(c.player.current_sp,field_sp-c.player.skill_cost(&"fire_wall")) and actual != null and actual.world_field.anchor().to_data() == field_destination,"ramp click emits real canonical field and pays exactly once on the previewed support")
	sample.queue_free(); await process_frame
	print("E07 F1 presentation: %d checks, %d failures; native scene, projection, click, preview, marker, occlusion" % [checks,failures])
	quit(1 if failures else 0)
