extends SceneTree
## Deterministic ray ownership at connected support seams; movement stays canonical.
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const SupportPatch = preload("res://scripts/core/expedition/spatial/world_support_patch.gd")
var checks: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(id: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"id":id,"ok":ok,"detail":detail})
	print("F9_PICK_CHECK "+id+" "+str(ok))

func run() -> void:
	var input := Fixture.make()
	var assembled := ExpeditionAssembler.build(input)
	check("canonical_f1_fixture_assembles",assembled.get("ok",false))
	if not assembled.get("ok",false): finish(); return
	var template: Dictionary = assembled.data.manifest.to_data()
	var planar_cells := [rectangle("surface_a",0,100,0,0,100),rectangle("surface_b",100,200,0,0,100)]
	var planar_ports := seam_ports("surface_a","surface_b",Vector3(100,0,50),80.0)
	var planar_links := [link("a_b")]
	var planar_world := make_world(template,planar_cells,planar_ports,planar_links)
	check("planar_connected_edge_resolves_to_lexical_owner",resolved_owner(planar_world,["surface_b","surface_a"],Vector3(100,0,50),"surface_a"))
	check("projected_camera_ray_on_planar_edge_resolves_with_existing_tolerance",projected_edge_resolves(planar_world,["surface_b","surface_a"],Vector3(100,0,50),"surface_a"))
	var slope_cells := [rectangle("surface_a",0,100,0,0,100),rectangle("surface_b",100,200,0,40,100)]
	var slope_world := make_world(template,slope_cells,seam_ports("surface_a","surface_b",Vector3(100,0,50),80.0),[link("a_b")])
	var slope_hit := ray(slope_world,["surface_a","surface_b"],Vector3(100,0,50))
	var expected_slope_normal := Kernel.plane_normal(slope_cells[1].vertices)
	if expected_slope_normal.y < 0.0: expected_slope_normal = -expected_slope_normal
	check("inclined_connected_edge_returns_real_non_coplanar_support",slope_hit.get("ok",false) and slope_hit.data.point.surface_id == "surface_a" and slope_hit.data.point.position == Vector3(100,0,50) and slope_hit.data.normal.distance_to(Vector3.UP) < 0.001 and slope_cells[0].vertices[0] != slope_cells[1].vertices[0])
	check("inclined_edge_keeps_neighbor_plane_normal_available",expected_slope_normal.is_finite() and not expected_slope_normal.is_equal_approx(Vector3.UP))
	check("projected_camera_ray_on_inclined_edge_resolves_with_existing_tolerance",projected_edge_resolves(slope_world,["surface_a","surface_b"],Vector3(100,0,50),"surface_a"))
	check("body_twenty_by_thirty_two_walks_across_resolved_inclined_seam",walk_across_seam(slope_world))
	var reversed_world := make_world(template,reversed(slope_cells),reversed(seam_ports("surface_a","surface_b",Vector3(100,0,50),80.0)),[link("a_b")])
	var reversed_visible: Array[String] = ["surface_b","surface_a"]
	var reversed_hit := ray(reversed_world,reversed_visible,Vector3(100,0,50))
	check("surface_visible_and_link_iteration_order_do_not_change_owner",reversed_hit.get("ok",false) and reversed_hit.data.point.surface_id == "surface_a" and reversed_hit.data.point.position == slope_hit.get("data",{}).get("point",{}).get("position",Vector3.INF))
	var vertex_cells := vertex_supports()
	var vertex_ports := vertex_ports_for_three()
	var vertex_links := [link("a_b"),link("a_c",true,true,"a_c_a","a_c_b")]
	var vertex_world := make_world(template,vertex_cells,vertex_ports,vertex_links)
	check("multi_face_vertex_connected_through_local_openings_resolves",resolved_owner(vertex_world,["surface_c","surface_b","surface_a"],Vector3.ZERO,"surface_a"))
	var reversed_vertex := make_world(template,reversed(vertex_cells),reversed(vertex_ports),reversed(vertex_links))
	check("multi_face_owner_is_stable_when_all_iteration_orders_reverse",resolved_owner(reversed_vertex,["surface_a","surface_b","surface_c"],Vector3.ZERO,"surface_a"))
	var disconnected_world := make_world(template,planar_cells,[],[])
	check("unlinked_touching_equal_height_faces_remain_ambiguous",ambiguous(disconnected_world,["surface_a","surface_b"],Vector3(100,0,50)))
	var coplanar_overlap := [rectangle("overlap_a",0,100,0,0,100),rectangle("overlap_b",0,100,0,0,100)]
	var overlap_world := make_world(template,coplanar_overlap,[],[])
	check("coplanar_interior_overlap_remains_ambiguous",ambiguous(overlap_world,["overlap_a","overlap_b"],Vector3(50,0,50)))
	var rogue_cells := [rectangle("surface_a",0,100,0,0,100),rectangle("surface_b",100,200,0,40,100),rectangle("surface_rogue",50,150,0,0,100)]
	var rogue_world := make_world(template,rogue_cells,seam_ports("surface_a","surface_b",Vector3(100,0,50),80.0),[link("a_b")])
	check("unlinked_third_coplanar_candidate_keeps_tie_ambiguous",ambiguous(rogue_world,["surface_a","surface_b","surface_rogue"],Vector3(100,0,50)))
	var remote_ports := seam_ports("surface_a","surface_b",Vector3(100,0,20),20.0)
	var remote_world := make_world(template,planar_cells,remote_ports,[link("a_b")])
	check("linked_but_remote_opening_does_not_resolve_tie",ambiguous(remote_world,["surface_a","surface_b"],Vector3(100,0,80)))
	var disabled_world := make_world(template,planar_cells,planar_ports,[link("a_b",false,false)])
	check("disabled_connection_does_not_resolve_tie",ambiguous(disabled_world,["surface_a","surface_b"],Vector3(100,0,50)))
	var oneway_world := make_world(template,planar_cells,planar_ports,[link("a_b",true,false)])
	check("one_way_connection_does_not_resolve_tie",ambiguous(oneway_world,["surface_a","surface_b"],Vector3(100,0,50)))
	var mismatched_ports := seam_ports("surface_a","surface_b",Vector3(100,0,50),80.0)
	mismatched_ports[1].kind = "stairs"
	var mismatched_world := make_world(template,planar_cells,mismatched_ports,[link("a_b")])
	check("incompatible_connector_kinds_do_not_resolve_tie",ambiguous(mismatched_world,["surface_a","surface_b"],Vector3(100,0,50)))
	var nonwalk_ports := seam_ports("surface_a","surface_b",Vector3(100,0,50),80.0,"portal","portal")
	var nonwalk_world := make_world(template,planar_cells,nonwalk_ports,[link("a_b")])
	check("nonwalk_opening_does_not_resolve_tie",ambiguous(nonwalk_world,["surface_a","surface_b"],Vector3(100,0,50)))
	var split_height_cells := [rectangle("surface_a",0,100,0,0,100),rectangle("surface_b",0,100,10,10,100)]
	var split_height_world := make_world(template,split_height_cells,[],[])
	check("near_t_values_with_distinct_hit_positions_remain_ambiguous",ambiguous_from(split_height_world,["surface_a","surface_b"],Vector3(50,100000000,50),Vector3.DOWN))
	var interior := ray(planar_world,["surface_a"],Vector3(50,0,50))
	check("single_visible_interior_surface_still_resolves",interior.get("ok",false) and interior.data.point.surface_id == "surface_a" and interior.data.point.position == Vector3(50,0,50))
	var layered_world := make_world(template,[rectangle("lower",0,100,0,0,100),rectangle("upper",0,100,10,10,100)],[],[])
	var upper_hit := ray(layered_world,["lower","upper"],Vector3(50,0,50))
	check("nearest_visible_support_remains_the_first_hit",upper_hit.get("ok",false) and upper_hit.data.point.surface_id == "upper" and upper_hit.data.point.position.y == 10.0)
	var fixture_world := WorldGeometry.new()
	var fixture_configured := fixture_world.configure(assembled.data.manifest,"sample")
	var stale := fixture_world.resolve_surface(Vector3(50,100,150),Vector3.DOWN,["sample/root/surface/floor"],fixture_world.geometry_revision+1)
	check("stale_revision_is_rejected",fixture_configured.get("ok",false) and not stale.get("ok",false) and stale.get("error_code") == &"stale_geometry")
	var invalid_ray := fixture_world.resolve_surface(Vector3(50,100,150),Vector3.ZERO,["sample/root/surface/floor"],fixture_world.geometry_revision)
	check("zero_direction_ray_is_rejected",not invalid_ray.get("ok",false) and invalid_ray.get("error_code") == &"invalid_ray")
	var hidden := fixture_world.resolve_surface(Vector3(50,100,150),Vector3.DOWN,["sample/root/surface/floor"],fixture_world.geometry_revision)
	check("hidden_upper_slab_still_occludes_lower_visible_floor",not hidden.get("ok",false) and hidden.get("error_code") == &"occluded_surface")
	finish()

func rectangle(id: String, x0: float, x1: float, y0: float, y1: float, z1: float) -> Dictionary:
	return {"surface_id":id,"vertices":[Vector3(x0,y0,0),Vector3(x1,y1,0),Vector3(x1,y1,z1),Vector3(x0,y0,z1)],"headroom":100.0}

func endpoint(id: String, surface_id: String, position: Vector3, outward: Vector3, width: float, kind: String = "walk") -> Dictionary:
	return {"connector_id":id,"surface_id":surface_id,"position":position,"outward":outward,"width":width,"headroom":100.0,"kind":kind,"tags":["walk"],"direction":"both"}

func seam_ports(a_surface: String, b_surface: String, point: Vector3, width: float, a_kind: String = "walk", b_kind: String = "walk") -> Array:
	return [endpoint("a_b_a",a_surface,point,Vector3.RIGHT,width,a_kind),endpoint("a_b_b",b_surface,point,Vector3.LEFT,width,b_kind)]

func link(prefix: String, forward: bool = true, backward: bool = true, a_connector: String = "a_b_a", b_connector: String = "a_b_b") -> Dictionary:
	return {"connection_id":"connection_"+prefix,"a_connector":a_connector,"b_connector":b_connector,"forward":forward,"backward":backward}

func vertex_ports_for_three() -> Array:
	return [endpoint("a_b_a","surface_a",Vector3(50,0,0),Vector3.FORWARD,100.0),endpoint("a_b_b","surface_b",Vector3(50,0,0),Vector3.BACK,100.0),endpoint("a_c_a","surface_a",Vector3(0,0,50),Vector3.LEFT,100.0),endpoint("a_c_b","surface_c",Vector3(0,0,50),Vector3.RIGHT,100.0)]

func reversed(values: Array) -> Array:
	var result := values.duplicate(true)
	result.reverse()
	return result

func vertex_supports() -> Array:
	return [
		{"surface_id":"surface_a","vertices":[Vector3.ZERO,Vector3(100,0,0),Vector3(0,0,100)],"headroom":100.0},
		{"surface_id":"surface_b","vertices":[Vector3.ZERO,Vector3(100,0,0),Vector3(100,40,-100)],"headroom":100.0},
		{"surface_id":"surface_c","vertices":[Vector3.ZERO,Vector3(0,0,100),Vector3(-100,30,100)],"headroom":100.0}
	]

func make_world(template: Dictionary, surfaces: Array, connectors: Array, connections: Array) -> WorldGeometry:
	var data: Dictionary = template.duplicate(true)
	var stage: Dictionary = data.stages[0]
	stage.surfaces = surfaces.duplicate(true)
	stage.connectors = connectors.duplicate(true)
	stage.connections = connections.duplicate(true)
	stage.part_instances = []
	stage.volumes = []
	stage.solid_prisms = []
	var manifest := ExpeditionManifest.new()
	manifest._data = data
	var world := WorldGeometry.new()
	var configured: Dictionary = world.configure(manifest,"sample")
	if not configured.get("ok",false): print("F9_PICK_CONFIGURE "+JSON.stringify(configured))
	return world

func ray(world: WorldGeometry, visible: Array[String], point: Vector3) -> Dictionary:
	return world.resolve_surface(Vector3(point.x,500.0,point.z),Vector3.DOWN,visible,world.geometry_revision)

func resolved_owner(world: WorldGeometry, visible: Array[String], point: Vector3, owner: String) -> bool:
	var result := ray(world,visible,point)
	return result.get("ok",false) and result.data.point.surface_id == owner and result.data.point.position.distance_to(point) <= 0.0001

func projected_edge_resolves(world: WorldGeometry, visible: Array[String], expected: Vector3, owner: String) -> bool:
	var camera_ray: Dictionary = ExpeditionGeometryView.ray(ExpeditionGeometryView.project(expected))
	var origin: Vector3 = camera_ray.origin
	var direction: Vector3 = camera_ray.direction
	var result: Dictionary = world.resolve_surface(origin,direction,visible,world.geometry_revision)
	return result.get("ok",false) and result.data.point.surface_id == owner and result.data.point.position.distance_to(expected) <= WorldGeometry.point_tolerance(origin,expected)

func ambiguous(world: WorldGeometry, visible: Array[String], point: Vector3) -> bool:
	return ambiguous_from(world,visible,Vector3(point.x,500.0,point.z),Vector3.DOWN)

func ambiguous_from(world: WorldGeometry, visible: Array[String], origin: Vector3, direction: Vector3) -> bool:
	var result := world.resolve_surface(origin,direction,visible,world.geometry_revision)
	return not result.get("ok",false) and result.get("error_code") == &"ambiguous_surface"

func walk_across_seam(world: WorldGeometry) -> bool:
	var profile: Dictionary = Fixture.make().traversal.to_data()
	profile.radius = 20.0
	profile.height = 32.0
	var actor := WorldActorMotion.new()
	var start := ExpeditionWorldPoint.create("sample","surface_a",Vector3(75,0,50))
	var goal := ExpeditionWorldPoint.create("sample","surface_b",Vector3(125,10,50))
	if not actor.configure(world,start,profile,"f9_pick_actor").get("ok",false): return false
	var plan: Dictionary = actor.plan(goal,world.geometry_revision)
	if not plan.get("ok",false): actor.release(); return false
	var passed_clearance := true
	var arrived := false
	for _step: int in 600:
		var moved: Dictionary = actor.advance(1.0)
		if not moved.get("ok",false): passed_clearance = false; break
		var current: ExpeditionWorldPoint = actor.point()
		passed_clearance = passed_clearance and world.position_query(current,profile,world.geometry_revision).get("ok",false)
		if moved.data.arrived: arrived = true; break
	var final_point: ExpeditionWorldPoint = actor.point()
	var outcome: bool = passed_clearance and arrived and final_point.surface_id == goal.surface_id and final_point.position.distance_to(goal.position) < 0.001
	actor.release()
	return outcome

func finish() -> void:
	var complete: bool = checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_PICK_RESULT "+JSON.stringify({"ok":complete,"count":checks.size(),"checks":checks}))
	quit(0 if complete else 1)

