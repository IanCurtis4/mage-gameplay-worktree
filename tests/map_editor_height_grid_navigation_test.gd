extends SceneTree
## F10 H3 (contracts/f10_height_grid.md): navigation over height-grid stretches.
## Three stretches in a row joined by seam connectors from their shared open
## spans, a steep wall with a gap in the middle one, and a planar surface after
## the last. Routes bend around steep ground, cross seams and the planar
## opening; certification sees the same reachability; worker views agree.
const Grid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const PROFILE := {"radius":10.0,"height":40.0,"connector_kinds":["walk"]}
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_GRID_NAV_CHECK "+id+" "+str(ok))
## Gentle relief across x only; the middle stretch has a steep wall at x = 1536.
func height(gx: int, gz: int, gap: bool) -> float:
	var base := 10.0*sin(float(gx)*0.35)
	if gx == 24 and not (gap and gz >= 6 and gz <= 10): base += 200.0
	return snappedf(base,0.25)
func stretch(id: String, column: int, gap: bool) -> Dictionary:
	var heights: Array = []
	for z: int in 17:
		for x: int in 17: heights.append(height(column+x,z,gap))
	var grid := {"origin_xz":[float(column)*64.0,0.0],"sample_spacing":64.0,"columns":17,"rows":17,"heights":heights}
	return {"surface_id":id,"headroom":200.0,"vertices":Grid.corners(Grid.view(grid)),"height_grid":grid}
func seam(connectors: Array, connections: Array, a: Dictionary, b: Dictionary, side: int) -> void:
	var spans := Grid.shared_spans(Grid.view(a.height_grid),side,Grid.view(b.height_grid))
	for k: int in spans.size():
		var p: Vector3 = spans[k].a; var q: Vector3 = spans[k].b
		var middle := (p+q)*0.5; middle.y = Grid.support_y_clamped(Grid.view(a.height_grid),middle.x,middle.z)
		var key := "%s_%s_%d"%[a.surface_id,b.surface_id,k]
		connectors.append({"connector_id":key+"_a","surface_id":a.surface_id,"position":middle,"outward":Grid.side_outward(side),"kind":"walk","tags":[],"width":p.distance_to(q),"headroom":200.0,"direction":"both"})
		connectors.append({"connector_id":key+"_b","surface_id":b.surface_id,"position":middle,"outward":-Grid.side_outward(side),"kind":"walk","tags":[],"width":p.distance_to(q),"headroom":200.0,"direction":"both"})
		connections.append({"connection_id":key,"a_connector":key+"_a","b_connector":key+"_b","forward":true,"backward":true})
func build(gap: bool) -> Dictionary:
	var a := stretch("A",0,gap); var b := stretch("B",16,gap); var c := stretch("C",32,gap)
	var edge_y := height(48,0,gap)
	var d := {"surface_id":"D","headroom":200.0,"vertices":[Vector3(3072,edge_y,0),Vector3(3400,edge_y,0),Vector3(3400,edge_y,1024),Vector3(3072,edge_y,1024)]}
	var connectors: Array = []; var connections: Array = []
	seam(connectors,connections,a,b,1); seam(connectors,connections,b,c,1)
	connectors.append({"connector_id":"C_D_a","surface_id":"C","position":Vector3(3072,edge_y,512),"outward":Vector3(1,0,0),"kind":"walk","tags":[],"width":1024.0,"headroom":200.0,"direction":"both"})
	connectors.append({"connector_id":"C_D_b","surface_id":"D","position":Vector3(3072,edge_y,512),"outward":Vector3(-1,0,0),"kind":"walk","tags":[],"width":1024.0,"headroom":200.0,"direction":"both"})
	connections.append({"connection_id":"C_D","a_connector":"C_D_a","b_connector":"C_D_b","forward":true,"backward":true})
	var stage := {"stage_id":"grid_nav","biome":"ruin","entrance":"","part_instances":[],"surfaces":[a,b,c,d],"connectors":connectors,"connections":connections,"sockets":[],"volumes":[],"solid_prisms":[]}
	var manifest := ExpeditionManifest.new()
	manifest._data = {"manifest_revision":1,"geometry_revision":1,"input":{"parts":[]},"stages":[stage],"traversal":PROFILE.duplicate(true),"population":{"slots":[]},"objectives":[],"portals":[],"witnesses":{}}
	var world := WorldGeometry.new()
	var configured: Dictionary = world.configure(manifest,"grid_nav")
	return {"world":world,"ok":configured.ok,"stage":stage,"cells":{"A":a,"B":b,"C":c,"D":d}}
func at(built: Dictionary, id: String, x: float, z: float) -> ExpeditionWorldPoint:
	var cell: Dictionary = built.cells[id]
	return ExpeditionWorldPoint.create("grid_nav",id,Kernel.support_y(cell,Vector3(x,0,z)))
## Every leg is walkable on its own support; seam steps keep the same position.
func route_valid(world: WorldGeometry, points: Array) -> bool:
	for k: int in range(1,points.size()):
		var p: Dictionary = points[k-1]; var q: Dictionary = points[k]
		if p.surface_id == q.surface_id:
			if Vector3(p.position) != Vector3(q.position) and not world.segment_walkable(p.surface_id,p.position,q.position,PROFILE,world.geometry_revision): return false
		elif Vector3(p.position).distance_to(q.position) > 0.001: return false
	return true
func run() -> void:
	var open := build(true)
	var world: WorldGeometry = open.world
	var connectors_valid := true
	for port: Dictionary in open.stage.connectors:
		if not Kernel.connector_valid(port,open.cells[port.surface_id]): connectors_valid = false
	check("seams_from_shared_spans",open.ok and connectors_valid and open.stage.connections.size() == 3)
	var revision := world.geometry_revision
	# 1. Across three stretches through the gap of the wall.
	var from := at(open,"A",200.0,150.0); var to := at(open,"C",2900.0,150.0)
	var started := Time.get_ticks_usec()
	var route: Dictionary = world.path(from,to,PROFILE,revision)
	var cold_ms := (Time.get_ticks_usec()-started)/1000.0
	started = Time.get_ticks_usec()
	var again: Dictionary = world.path(from,to,PROFILE,revision)
	var warm_ms := (Time.get_ticks_usec()-started)/1000.0
	var through_gap := false; var surfaces := {}
	if route.ok:
		for point: Dictionary in route.data.points:
			surfaces[point.surface_id] = true
			if point.surface_id == "B" and float(point.position.z) > 384.0 and float(point.position.z) < 640.0 and absf(float(point.position.x)-1536.0) < 200.0: through_gap = true
	check("route_crosses_the_stretches_through_the_gap",route.ok and through_gap and surfaces.has("A") and surfaces.has("B") and surfaces.has("C") and route_valid(world,route.data.points) and float(route.data.cost) > from.position.distance_to(to.position))
	check("route_is_deterministic",again.ok and route.ok and again.data.points == route.data.points)
	# 2. Into the planar surface after the last stretch.
	var planar: Dictionary = world.path(from,at(open,"D",3300.0,500.0),PROFILE,revision)
	check("route_reaches_the_planar_surface",planar.ok and planar.data.points[-1].surface_id == "D" and route_valid(world,planar.data.points))
	# 3. The worker view (background navigation) gives the same route.
	var view := world._navigation_current_view()
	var from_view: Dictionary = view._path(from,to,PROFILE,revision,null)
	check("worker_view_agrees",from_view.ok and route.ok and from_view.data.points == route.data.points)
	# 4. Without the gap the wall splits the field.
	var closed := build(false)
	var closed_world: WorldGeometry = closed.world
	var cut: Dictionary = closed_world.path(at(closed,"A",200.0,150.0),at(closed,"C",2900.0,150.0),PROFILE,closed_world.geometry_revision)
	var near: Dictionary = closed_world.path(at(closed,"A",200.0,150.0),at(closed,"B",1300.0,800.0),PROFILE,closed_world.geometry_revision)
	check("wall_without_gap_splits_the_field",closed.ok and not cut.ok and near.ok)
	# 5. Certification: the same reachability, with valid witnesses.
	var targets: Array[ExpeditionWorldPoint] = [at(open,"B",1300.0,800.0),at(open,"B",1800.0,800.0),at(open,"C",2500.0,500.0),at(open,"D",3300.0,500.0)]
	started = Time.get_ticks_usec()
	var certified: Dictionary = world.connectivity_batch(from,targets,PROFILE,revision)
	var batch_ms := (Time.get_ticks_usec()-started)/1000.0
	var all_reached: bool = certified.ok and certified.data.complete and certified.data.all_reachable
	var witness_ok: bool = all_reached
	if all_reached:
		for index: int in targets.size():
			for outward: bool in [true,false]:
				var witness: Dictionary = world.connectivity_witness(certified,index,outward,revision)
				if not witness.ok or not route_valid(world,witness.data.points): witness_ok = false
	check("certification_reaches_every_target",all_reached and witness_ok)
	var closed_targets: Array[ExpeditionWorldPoint] = [at(closed,"B",1300.0,800.0),at(closed,"B",1800.0,800.0),at(closed,"D",3300.0,500.0)]
	var refused: Dictionary = closed_world.connectivity_batch(at(closed,"A",200.0,150.0),closed_targets,PROFILE,closed_world.geometry_revision)
	var reach: Array = []
	if refused.ok:
		for target: Dictionary in refused.data.targets: reach.append(target.outward_reachable and target.inward_reachable)
	check("certification_sees_the_cut",refused.ok and refused.data.complete and not refused.data.all_reachable and reach == [true,false,false])
	print("F10_GRID_NAV_TIMING "+JSON.stringify({"cold_ms":snappedf(cold_ms,0.1),"warm_ms":snappedf(warm_ms,0.1),"batch_ms":snappedf(batch_ms,0.1),"points":route.data.points.size() if route.ok else 0}))
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_GRID_NAV_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
