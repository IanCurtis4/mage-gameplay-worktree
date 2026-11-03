extends SceneTree
## F10 H2 (contracts/f10_height_grid.md): a height-grid stretch as a support
## surface of the real WorldGeometry. Support, bodies, segments, the stretch's
## ground mass for sight, ground lines, picking and skill regions. Routes and
## seams between surfaces are H3.
const Grid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const PROFILE := {"radius":10.0,"height":40.0,"connector_kinds":["walk"]}
const GroundShadow = preload("res://scripts/world/ground_shadow.gd")
const Patch = preload("res://scripts/core/expedition/spatial/world_support_patch.gd")
var checks: Array[Dictionary] = []
var world: WorldGeometry
var view: Dictionary
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_GRID_WORLD_CHECK "+id+" "+str(ok))
## A ridge across x (peak 60 at sample 8, walkable slopes) and one steep bump.
func height(x: int, z: int) -> float:
	var ridge := 0.0
	if x > 4 and x <= 8: ridge = float(x-4)*15.0
	elif x > 8 and x < 12: ridge = float(12-x)*15.0
	return ridge+(120.0 if x == 2 and z == 12 else 0.0)
func grid_cell() -> Dictionary:
	var heights: Array = []
	for z: int in 17:
		for x: int in 17: heights.append(height(x,z))
	var grid := {"origin_xz":[0.0,0.0],"sample_spacing":64.0,"columns":17,"rows":17,"heights":heights}
	return {"surface_id":"field","headroom":200.0,"vertices":Grid.corners(Grid.view(grid)),"height_grid":grid}
func flat_cell() -> Dictionary:
	return {"surface_id":"flat","headroom":200.0,"vertices":[Vector3(1100,0,0),Vector3(1300,0,0),Vector3(1300,0,200),Vector3(1100,0,200)]}
func manifest(surfaces: Array) -> ExpeditionManifest:
	var stage := {"stage_id":"grid_stage","biome":"ruin","entrance":"","part_instances":[],"surfaces":surfaces,"connectors":[],"connections":[],"sockets":[],"volumes":[],"solid_prisms":[]}
	var result := ExpeditionManifest.new()
	result._data = {"manifest_revision":1,"geometry_revision":1,"input":{"parts":[]},"stages":[stage],"traversal":PROFILE.duplicate(true),"population":{"slots":[]},"objectives":[],"portals":[],"witnesses":{}}
	return result
func at(x: float, z: float) -> ExpeditionWorldPoint:
	return ExpeditionWorldPoint.create("grid_stage","field",Vector3(x,Grid.support_y(view,x,z),z))
func run() -> void:
	var cell := grid_cell(); view = Grid.view(cell.height_grid)
	# 1. A stretch is a valid kernel cell; a wrong outline is not (configure only
	# validates cells of stages with masses, as for planar cells).
	world = WorldGeometry.new()
	var configured: Dictionary = world.configure(manifest([cell,flat_cell()]),"grid_stage")
	var broken := cell.duplicate(true); broken.vertices[2] = Vector3(broken.vertices[2]) + Vector3(0,1,0)
	check("stretch_is_a_valid_cell",Kernel.valid_cell(cell) and not Kernel.valid_cell(broken) and configured.ok)
	var revision := world.geometry_revision
	# 2. Exact support through the world and the kernel, on the ridge slope.
	var support: Dictionary = world.support_at("field",Vector2(400.0,300.0),revision)
	var expected := Grid.support_y(view,400.0,300.0)
	check("support_is_the_stretch",support.ok and is_equal_approx(float(support.data.point.position.y),expected) and expected > 20.0 and is_equal_approx(Kernel.support_y(cell,Vector3(400,0,300)).y,expected) and Kernel.contains(cell,Vector3(400,expected,300)) and not Kernel.contains(cell,Vector3(400,expected+1.0,300)))
	# 3. Bodies: on the slope, beside and on the steep bump.
	var bump_center := Vector2(128.0,768.0)
	check("body_on_walkable_ground",world.position_query(at(400.0,300.0),PROFILE,revision).ok and world.set_occupant("hero",at(400.0,300.0),PROFILE,revision).ok)
	check("body_refused_on_and_near_steep_ground",not world.position_query(at(bump_center.x,bump_center.y),PROFILE,revision).ok and not world.position_query(at(200.0,768.0),PROFILE,revision).ok and world.position_query(at(215.0,640.0),PROFILE,revision).ok)
	# 4. Walking segments: across the ridge yes, through the bump no.
	check("segment_over_the_ridge_is_walkable",world.segment_walkable("field",at(100.0,300.0).position,at(900.0,300.0).position,PROFILE,revision))
	check("segment_through_the_bump_is_not",not world.segment_walkable("field",at(40.0,600.0).position,at(240.0,900.0).position,PROFILE,revision))
	# 5. The stretch is solid below its support: sight over the ridge is blocked.
	var chest := Vector3.UP*20.0
	var blocked: Dictionary = world.sweep(at(120.0,300.0).position+chest,at(900.0,300.0).position+chest,{"radius":0.0,"height":0.0},revision)
	var open: Dictionary = world.sweep(at(120.0,300.0).position+chest,at(300.0,500.0).position+chest,{"radius":0.0,"height":0.0},revision)
	var along_slope: Dictionary = world.sweep(at(330.0,300.0).position,at(500.0,300.0).position,{"radius":0.0,"height":0.0},revision)
	check("ridge_blocks_sight",blocked.ok and blocked.data.hit and str(blocked.data.volume_id) == "terrain/grid/field" and float(blocked.data.fraction) > 0.2 and float(blocked.data.fraction) < 0.6)
	check("open_ground_and_planar_slope_do_not",open.ok and not open.data.hit and along_slope.ok and not along_slope.data.hit)
	var attack: Dictionary = world.query_attack({"geometry_rule_id":&"direct_volume","range":2000.0,"source_offset":chest,"target_offset":chest},at(120.0,300.0),at(900.0,300.0),revision)
	var near: Dictionary = world.query_attack({"geometry_rule_id":&"direct_volume","range":2000.0,"source_offset":chest,"target_offset":chest},at(120.0,300.0),at(200.0,500.0),revision)
	check("attack_sight_follows_the_ground",attack.ok and not attack.data.los_ok and near.ok and near.data.los_ok)
	# 6. Ground lines walk the bent support and stop at steep ground.
	var line: Dictionary = world.ground_line_samples(at(100.0,300.0),Vector3(1,0,0),50.0,12,PROFILE,revision)
	var on_support: bool = line.ok and not line.data.truncated and line.data.points.size() == 12
	var spaced: bool = on_support
	if on_support:
		var previous: Vector3 = at(100.0,300.0).position
		for item: Dictionary in line.data.points:
			var p: Vector3 = item.position
			if absf(p.y-Grid.support_y(view,p.x,p.z)) > 0.001: on_support = false
			if previous.distance_to(p) > 50.0+0.01 or previous.distance_to(p) < 45.0: spaced = false
			previous = p
	check("ground_line_follows_the_support",on_support and spaced)
	var trace: Dictionary = world.trace_ground(at(30.0,768.0),Vector3(1,0,0),600.0,PROFILE,revision)
	check("trace_stops_before_steep_ground",trace.ok and trace.data.truncated and float(trace.data.destination.position.x) < 64.0-10.0+0.01 and float(trace.data.destination.position.x) > 40.0)
	# 7. Picking: a camera ray lands on the exact support; the bump is no pick.
	var target := at(600.0,400.0).position
	var direction := Vector3(-0.5,-1.0,-0.4)
	var picked: Dictionary = world.resolve_surface(target-direction*500.0,direction,["field","flat"],revision)
	var bump := Vector3(bump_center.x,Grid.support_y(view,bump_center.x,bump_center.y),bump_center.y)
	var steep_pick: Dictionary = world.resolve_surface(bump-direction*500.0,direction,["field"],revision)
	check("pick_lands_on_the_support",picked.ok and picked.data.point.surface_id == "field" and Vector3(picked.data.point.position).distance_to(target) < 0.05 and not steep_pick.ok)
	# 8. Skill regions: walkable footprint split into triangle patches; the bump refused.
	var region: Dictionary = world.ground_region(at(500.0,300.0),PackedVector2Array([Vector2(450,250),Vector2(560,250),Vector2(560,350),Vector2(450,350)]),PROFILE,revision)
	var bumpy: Dictionary = world.ground_region(at(215.0,640.0),PackedVector2Array([Vector2(100,700),Vector2(220,700),Vector2(220,820),Vector2(100,820)]),PROFILE,revision)
	check("region_on_the_stretch",region.ok and region.data.patches.size() > 2 and not bumpy.ok)
	# 9. Overlap uses the stretch's height range.
	var above := flat_cell(); above.vertices = [Vector3(300,300,100),Vector3(500,300,100),Vector3(500,300,300),Vector3(300,300,300)]
	var crossing := flat_cell(); crossing.vertices = [Vector3(300,30,100),Vector3(500,30,100),Vector3(500,30,300),Vector3(300,30,300)]
	check("overlap_uses_the_height_range",Kernel.cells_overlap(cell,crossing) and not Kernel.cells_overlap(cell,above) and not Kernel.cells_overlap(cell,flat_cell()))
	# 10. A contact shadow on a stretch lies on the support triangles.
	var shadow_index: Dictionary = Patch.index({"surfaces":[cell],"connectors":[],"connections":[]})
	var anchor := at(500.0,300.0).position
	var shadow: Dictionary = GroundShadow.mesh_data(anchor,Vector2(70.0,50.0),shadow_index,"field",func(point: Vector3) -> Vector2: return Vector2(point.x,point.z))
	var on_ground: bool = shadow.ok and GroundShadow.receiver(anchor,shadow_index,"a_layer") == "field" and shadow.world_vertices.size() > 3
	if shadow.ok:
		for vertex: Vector3 in shadow.world_vertices:
			if absf(vertex.y-Grid.support_y(view,vertex.x,vertex.z)) > 0.01: on_ground = false
	check("shadow_lies_on_the_support",on_ground)
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_GRID_WORLD_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
