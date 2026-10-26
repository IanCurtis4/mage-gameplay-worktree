extends SceneTree
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Motion = preload("res://scripts/core/expedition/spatial/world_actor_motion.gd")
var checks: Array[Dictionary] = []
var metrics: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_MESH_CHECK "+id+" "+str(ok))
func run() -> void:
	var built := Terrain.compile(source(3))
	check("curved_grid_compiles",built.ok)
	if not built.ok: print(built); finish(); return
	check("curved_grid_has_eight_exact_triangles",built.package.part.surfaces.size() == 8)
	var manifest := Terrain.preview_manifest(built.package)
	var world := WorldGeometry.new(); world.configure(manifest,"terrain_preview")
	var profile := {"radius":10.0,"height":12.0,"connector_kinds":["walk"]}
	var center := Vector3(100,2,100)
	var supports := 0; var valid := 0
	for cell: Dictionary in built.package.part.surfaces:
		if Kernel.contains(cell,center):
			supports += 1
			if world.position_query(ExpeditionWorldPoint.create("terrain_preview",cell.surface_id,center),profile,world.geometry_revision).ok: valid += 1
	check("six_triangles_meet_at_same_vertex",supports == 6)
	check("body_supported_over_all_six_triangles",valid == 6)
	var wide := profile.duplicate(true); wide.radius = 60.0
	check("body_wider_than_individual_internal_edge",world.position_query(at(world,Vector2(100,100)),wide,world.geometry_revision).ok)
	var from := at(world,Vector2(20,30)); var to := at(world,Vector2(180,170))
	var line := world.ground_line_to(from,to,profile,world.geometry_revision)
	check("ground_line_crosses_mesh_vertex",line.ok)
	if not line.ok: print("F9_MESH_LINE_DIAGNOSTIC "+str(line)+" "+str(world._ground_line_samples(from,to.position-from.position,Vector2(to.position.x-from.position.x,to.position.z-from.position.z).length(),1,profile,world.geometry_revision,true)))
	check("real_actor_crosses_mesh_vertex",walk(world,from,to,profile,center))
	var selected_seam := 0; var selected_actor := 0
	for cell: Dictionary in built.package.part.surfaces:
		if not Kernel.contains(cell,center): continue
		var seam := ExpeditionWorldPoint.create("terrain_preview",cell.surface_id,center)
		var direct := world.ground_line_to(from,seam,profile,world.geometry_revision)
		if direct.ok and direct.data.points[-1] == seam.to_data(): selected_seam += 1
		if walk(world,from,seam,profile,center): selected_actor += 1
	check("direct_line_preserves_every_selected_seam_support",selected_seam == 6)
	check("actor_arrives_on_every_selected_seam_support",selected_actor == 6)
	var t := 0.314159265
	var quantized := Vector3(7600.0+400.0*t,160.0*t,400.0*t)
	var upper := {"vertices":[Vector3(7600,0,0),Vector3(8000,160,400),Vector3(7600,0,400)],"headroom":100.0}
	var lower := {"vertices":[Vector3(7600,0,0),Vector3(8000,160,0),Vector3(8000,160,400)],"headroom":100.0}
	check("quantized_diagonal_anchor_supported_on_both_planes",Kernel.contains(upper,quantized) and Kernel.contains(lower,quantized))
	check("quantized_edge_does_not_expand_body_clearance",not Kernel.contains(upper,quantized,20) and not Kernel.contains(lower,quantized,20))
	check("quantized_edge_rejects_real_outside_anchor",not Kernel.contains(upper,quantized+Vector3(0.01,0.004,0)) and not Kernel.contains(lower,quantized-Vector3(0.01,0.004,0)))
	check("quantized_plane_rejects_real_height_error",not Kernel.contains(upper,quantized+Vector3.UP*0.01) and not Kernel.contains(lower,quantized+Vector3.UP*0.01))
	check("exterior_edge_still_closed",not world.position_query(at(world,Vector2(5,30)),profile,world.geometry_revision).ok)
	var disconnected := Terrain.preview_manifest(built.package); disconnected._data.stages[0].connections.clear()
	world.configure(disconnected,"terrain_preview")
	check("unconnected_neighbors_do_not_support_disk",not world.position_query(at(world,Vector2(100,100)),profile,world.geometry_revision).ok)
	var discontinuous := Terrain.preview_manifest(built.package); var lifted: Array[String] = []
	for cell: Dictionary in discontinuous._data.stages[0].surfaces:
		var centroid := Vector3.ZERO
		for p: Vector3 in cell.vertices: centroid += p
		if centroid.x/float(cell.vertices.size()) > 100:
			lifted.append(cell.surface_id)
			for k: int in cell.vertices.size(): cell.vertices[k] += Vector3.UP*100
	for port: Dictionary in discontinuous._data.stages[0].connectors:
		if port.surface_id in lifted: port.position += Vector3.UP*100
	world.configure(discontinuous,"terrain_preview")
	check("discontinuous_floor_cannot_fill_support_patch",not world.position_query(at(world,Vector2(100,100)),profile,world.geometry_revision).ok)
	world.configure(manifest,"terrain_preview")
	check("reconfigure_rebuilds_derived_index",world.position_query(at(world,Vector2(100,100)),profile,world.geometry_revision).ok)
	var low := Terrain.preview_manifest(built.package)
	low._data.stages[0].surfaces[0].headroom = 6.0
	world.configure(low,"terrain_preview")
	check("neighbor_headroom_is_required",not world.position_query(at(world,Vector2(100,100)),profile,world.geometry_revision).ok)
	var hole := Terrain.preview_manifest(built.package); var removed: Array[String] = []
	for cell: Dictionary in hole._data.stages[0].surfaces:
		var c := Vector3.ZERO
		for p: Vector3 in cell.vertices: c += p
		c /= float(cell.vertices.size())
		if c.x > 100 and c.z > 100: removed.append(cell.surface_id)
	hole._data.stages[0].surfaces = hole._data.stages[0].surfaces.filter(func(c: Dictionary) -> bool: return c.surface_id not in removed)
	hole._data.stages[0].solid_prisms = hole._data.stages[0].solid_prisms.filter(func(p: Dictionary) -> bool: return p.support_surface_id not in removed)
	var ports: Array[String] = []
	for port: Dictionary in hole._data.stages[0].connectors:
		if port.surface_id in removed: ports.append(port.connector_id)
	hole._data.stages[0].connectors = hole._data.stages[0].connectors.filter(func(p: Dictionary) -> bool: return p.connector_id not in ports)
	hole._data.stages[0].connections = hole._data.stages[0].connections.filter(func(c: Dictionary) -> bool: return c.a_connector not in ports and c.b_connector not in ports)
	world.configure(hole,"terrain_preview")
	check("hole_corner_rejects_partial_support",not world.position_query(at(world,Vector2(95,95)),profile,world.geometry_revision).ok)
	check("closed_corner_radial_clearance",world.position_query(at(world,Vector2(90,90)),profile,world.geometry_revision).ok)
	from = at(world,Vector2(85,105)); to = at(world,Vector2(105,85))
	check("segment_cannot_cut_reentrant_corner",not world.ground_line_to(from,to,profile,world.geometry_revision).ok)
	world.configure(manifest,"terrain_preview")
	world.insert_obstacle("center",AABB(Vector3(90,0,90),Vector3(20,50,20)),world.geometry_revision)
	check("solid_obstacle_still_blocks_center",not world.position_query(at(world,Vector2(100,100)),profile,world.geometry_revision).ok)
	world.configure(manifest,"terrain_preview")
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,200,200),[],10.0)
	var hero := PlayerActor.new(); hero.configure(nav,RunState.new(&"mage"))
	check("player_binds_over_shared_vertex",hero.bind_world_geometry(world,at(world,Vector2(100,100)),profile,"mesh_player").ok)
	check("derived_index_is_populated",not world._support_index.is_empty())
	var barrier := SnapshotTickBarrier.new(); barrier.acquire(hero)
	var registry := SnapshotRegistry.new(); var captured := registry.capture(hero,barrier)
	var omitted: bool = captured.ok
	if captured.ok:
		for object: Dictionary in captured.snapshot.objects.values():
			if object.kind == "res://scripts/core/expedition/spatial/world_geometry.gd" and object.fields.has("_support_index"): omitted = false
	check("snapshot_captures_without_derived_index",captured.ok and omitted)
	var restored := SnapshotRegistry.new().restore(captured.snapshot) if captured.ok else {"ok":false}
	check("snapshot_restores_mesh_actor",restored.ok)
	var restored_support := false
	if restored.ok:
		var copy: PlayerActor = restored.root
		restored_support = copy.world_motion.geometry.position_query(copy.world_point(),profile,copy.world_motion.geometry.geometry_revision).ok
		copy.free()
	check("restored_mesh_support_rebuilds_index",restored_support)
	barrier.release(); hero.free()
	var tick := Time.get_ticks_usec(); var representative := Terrain.compile(source(9))
	metrics["compile_9x9_ms"] = (Time.get_ticks_usec()-tick)/1000.0
	check("representative_curved_grid_compiles",representative.ok)
	if representative.ok:
		world.configure(Terrain.preview_manifest(representative.package),"terrain_preview")
		tick = Time.get_ticks_usec(); var point := at(world,Vector2(400,400))
		var supported := world.position_query(point,profile,world.geometry_revision)
		metrics["cold_support_ms"] = (Time.get_ticks_usec()-tick)/1000.0
		tick = Time.get_ticks_usec()
		for i: int in 100: supported = world.position_query(point,profile,world.geometry_revision)
		metrics["warm_support_100_ms"] = (Time.get_ticks_usec()-tick)/1000.0
		check("representative_internal_vertex_supported",supported.ok)
	var one_way := Terrain.preview_manifest(Terrain.compile(source(2)).package)
	var link: Dictionary = one_way._data.stages[0].connections[0]
	link.forward = true; link.backward = false
	world.configure(one_way,"terrain_preview")
	var endpoints: Dictionary = {}
	for port: Dictionary in world._stage.connectors: endpoints[port.connector_id] = port
	var a := ExpeditionWorldPoint.create("terrain_preview",endpoints[link.a_connector].surface_id,Vector3(50,1,50))
	var b := ExpeditionWorldPoint.create("terrain_preview",endpoints[link.b_connector].surface_id,a.position)
	check("coincident_contact_honors_forward_direction",world.ground_line_to(a,b,profile,world.geometry_revision).ok)
	check("coincident_contact_rejects_reverse_direction",not world.ground_line_to(b,a,profile,world.geometry_revision).ok)
	var hill := source(3); hill.layers[0].sample_spacing = 200; hill.layers[0].heights = [0,0,0,0,16,0,0,0,0]
	world.configure(Terrain.preview_manifest(Terrain.compile(hill).package),"terrain_preview")
	var origin := at(world,Vector2(133.333333,66.666666))
	var outward := true; var inward := true; var witnessed := true
	for horizontal: Vector2 in [Vector2(264,56),Vector2(344,136),Vector2(56,264),Vector2(88,312)]:
		var destination := at(world,horizontal)
		outward = outward and world.ground_line_to(origin,destination,profile,world.geometry_revision).ok
		inward = inward and world.ground_line_to(destination,origin,profile,world.geometry_revision).ok
		var path := world.path(origin,destination,profile,world.geometry_revision)
		var changes := 0
		if path.ok:
			for k: int in range(1,path.data.points.size()):
				if path.data.points[k-1].surface_id != path.data.points[k].surface_id: changes += 1
		witnessed = witnessed and path.ok and changes > 0 and path.data.connection_ids.size() == changes
	check("hill_exit_does_not_reenter_quantized_incoming_edge",outward)
	check("hill_entry_does_not_reenter_quantized_incoming_edge",inward)
	check("quantized_routes_keep_all_connection_witnesses",witnessed)
	finish()
static func source(axis: int) -> Dictionary:
	var data := Piece.empty("mesh_fixture"); var heights: Array = []
	for z: int in axis:
		for x: int in axis: heights.append(float(x*z)*2.0)
	data.layers = [{"layer_id":"curved","name":"Relevo","origin_xz":[0,0],"sample_spacing":100,"columns":axis,"rows":axis,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]}]
	return data
static func at(world: WorldGeometry, horizontal: Vector2) -> ExpeditionWorldPoint:
	for cell: Dictionary in world._stage.surfaces:
		var point := Kernel.support_y(cell,Vector3(horizontal.x,0,horizontal.y))
		if Kernel.contains(cell,point): return ExpeditionWorldPoint.create("terrain_preview",cell.surface_id,point)
	return null
static func walk(world: WorldGeometry, from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, vertex: Vector3) -> bool:
	var motion := Motion.new()
	if not motion.configure(world,from,profile,"mesh_actor").ok: return false
	var planned := motion.plan(to,world.geometry_revision)
	if not planned.ok: motion.release(); return false
	var crosses := false
	for point: Dictionary in planned.data.points:
		if Vector3(point.position).distance_to(vertex) < 0.0001: crosses = true
	if not crosses: print("F9_MESH_ACTOR_MISSED_VERTEX "+str(planned)); motion.release(); return false
	var budget := 1000
	while motion.has_route() and budget > 0:
		budget -= 1
		var advanced := motion.advance(1.0)
		if not advanced.ok:
			print("F9_MESH_ACTOR_BLOCKED "+str({"result":advanced,"point":motion.point().to_data(),"cursor":motion._cursor,"route":planned.data.points}))
			motion.release(); return false
	var ok := budget > 0 and motion.point().position.distance_to(to.position) < 0.001
	motion.release(); return ok
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_MESH_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"metrics":metrics})); quit(0 if ok else 1)
