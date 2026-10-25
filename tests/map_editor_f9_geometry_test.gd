extends SceneTree
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Candidate = preload("res://tests/map_editor_candidate_test.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
var checks: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"id":id,"ok":ok,"detail":detail})
	print("F9_CHECK "+id+" "+str(ok))

func run() -> void:
	var map := Map.sample()
	for piece: Dictionary in map.pieces:
		piece.source.connectors[0].width = 80
	rehash(map)
	var built := Compiler.compile(map)
	check("wide_opening_compiles",built.ok,built.get("code"))
	if built.ok:
		var world := WorldGeometry.new()
		world.configure(Compiler.manifest(built.package),"map_preview")
		for z: float in [25.0,75.0]:
			var start := at(built.package,"left",Vector3(20,0,z))
			var goal := at(built.package,"right",Vector3(180,0,z))
			var path := world.path(start,goal,built.package.profile,world.geometry_revision)
			check("free_off_center_%d"%z,path.ok and straight(path,z),path.get("data"))
			check("continuous_actor_%d"%z,walk(world,start,goal,built.package.profile,z))
		var start := at(built.package,"left",Vector3(20,0,25))
		var goal := at(built.package,"right",Vector3(180,0,25))
		var inserted := world.insert_obstacle("middle",AABB(Vector3(95,-1,44),Vector3(10,40,12)),world.geometry_revision)
		check("center_obstacle_installed",inserted.ok)
		var beside := world.path(start,goal,built.package.profile,world.geometry_revision)
		check("center_blocked_side_open",beside.ok and straight(beside,25),beside.get("error_code"))
		var diagonal_goal := at(built.package,"right",Vector3(180,0,75))
		check("blocked_diagonal_uses_free_portal_interval",walk(world,start,diagonal_goal,built.package.profile))
		world.remove_obstacle("middle",world.geometry_revision)
		var oversized: Dictionary = built.package.profile.duplicate(true); oversized.radius = 41.0
		check("body_wider_than_opening_rejected",not world.path(at(built.package,"left",Vector3(50,0,50)),at(built.package,"right",Vector3(150,0,50)),oversized,world.geometry_revision).ok)
		var blocked_manifest := Compiler.manifest(built.package)
		blocked_manifest._data.stages[0].connections[0].forward = false
		blocked_manifest._data.stages[0].connections[0].backward = false
		world.configure(blocked_manifest,"map_preview")
		check("disabled_direction_still_rejected",not world.path(start,goal,built.package.profile,world.geometry_revision).ok)
		blocked_manifest._data.stages[0].connections[0].forward = true
		world.configure(blocked_manifest,"map_preview")
		check("one_way_forward",world.path(start,goal,built.package.profile,world.geometry_revision).ok)
		check("one_way_backward_rejected",not world.path(goal,start,built.package.profile,world.geometry_revision).ok)
		# A candidate wall must participate in every new route edge as well.
		world.configure(Compiler.manifest(built.package),"map_preview")
		var wall := world.insert_obstacle("closed",AABB(Vector3(95,-1,9),Vector3(10,40,82)),world.geometry_revision)
		check("closed_opening_has_no_route",not wall.ok or not world.path(start,goal,built.package.profile,world.geometry_revision).ok)
	for height: float in [40.0,160.0,200.0]:
		var ramp := Candidate.representative_map()
		for piece: Dictionary in ramp.pieces:
			for layer: Dictionary in piece.source.layers:
				for i: int in layer.heights.size(): layer.heights[i] *= height/40.0
			for surface: Dictionary in piece.source.special_surfaces:
				for xyz: Array in surface.vertices_xyz: xyz[1] *= height/40.0
			for connector: Dictionary in piece.source.connectors: connector.position_xyz[1] *= height/40.0
		rehash(ramp)
		var terrain := Terrain.compile(ramp.pieces[0].source)
		check("ramp400_height%d_terrain"%height,terrain.ok,terrain.get("code"))
		var result := Compiler.compile(ramp)
		check("ramp400_height%d_map"%height,result.ok,result.get("geometry_diagnostic",result.get("code")))
		if not result.ok: continue
		var world := WorldGeometry.new(); world.configure(Compiler.manifest(result.package),"map_preview")
		var start := at(result.package,"land",Vector3(64,0,200))
		var goal := at(result.package,"sanctuary",Vector3(1400,height,200))
		check("ramp400_height%d_walk"%height,walk(world,start,goal,result.package.profile))
		check("bridge_height%d_walk_on_slab"%height,walk(world,start,at(result.package,"land",Vector3(400,height,600)),result.package.profile))
		# Independent oracle: the authored ramp rises linearly over x=400..800.
		var middle := at(result.package,"land",Vector3(600,height*0.5,200))
		check("ramp400_height%d_half_height"%height,not middle.surface_id.is_empty() and world.position_query(middle,result.package.profile,world.geometry_revision).ok)
	for origin: float in [0.0,1200.0,7600.0]:
		for height: float in [160.0,200.0]:
			var cell := {"vertices":[Vector3(origin,0,0),Vector3(origin+400,height,0),Vector3(origin+400,height,400),Vector3(origin,0,400)],"headroom":100.0}
			check("planarity_%d_%d"%[origin,height],Kernel.valid_cell(cell))
			var supported := true; var rejects_height := true
			for i: int in 41:
				var x := origin+float(i)*10.0
				var p := Kernel.support_y(cell,Vector3(x,0,125))
				supported = supported and Kernel.contains(cell,p) and absf(p.y-(x-origin)*height/400.0) < 0.001
				rejects_height = rejects_height and not Kernel.contains(cell,p+Vector3(0,0.01,0))
			check("support_height_oracle_%d_%d"%[origin,height],supported)
			check("off_plane_rejected_%d_%d"%[origin,height],rejects_height)
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_GEOMETRY_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	quit(0 if ok else 1)

static func rehash(map: Dictionary) -> void:
	for piece: Dictionary in map.pieces:
		var old: String = piece.piece_hash; piece.piece_hash = Schema.semantic_hash(piece.source)
		for instance: Dictionary in map.instances:
			if instance.piece_hash == old: instance.piece_hash = piece.piece_hash

static func at(package: Dictionary, instance: String, position: Vector3) -> ExpeditionWorldPoint:
	for cell: Dictionary in package.manifest.stages[0].surfaces:
		if cell.surface_id.begins_with(instance+"/") and Kernel.contains(cell,position): return ExpeditionWorldPoint.create("map_preview",cell.surface_id,position)
	return ExpeditionWorldPoint.create("map_preview","",position)

static func straight(path: Dictionary, z: float) -> bool:
	if not path.ok: return false
	for point: Dictionary in path.data.points:
		if absf(point.position.z-z) > 0.001: return false
	return absf(float(path.data.cost)-160.0) < 0.001

static func walk(world: WorldGeometry, start: ExpeditionWorldPoint, goal: ExpeditionWorldPoint, profile: Dictionary, z: float = NAN) -> bool:
	var actor := WorldActorMotion.new()
	if not actor.configure(world,start,profile,"f9_actor").ok: return false
	if not actor.plan(goal,world.geometry_revision).ok: actor.release(); return false
	var arrived := false; var valid := true
	for i: int in 1200:
		var previous := actor.point().position
		var result := actor.advance(3.0)
		if not result.ok: valid = false; break
		var current := actor.point().position
		if previous.distance_to(current) > 3.002 or (not is_nan(z) and absf(current.z-z) > 0.001): valid = false; break
		if result.data.arrived: arrived = true; break
	valid = valid and arrived and actor.point().surface_id == goal.surface_id and actor.point().position.distance_to(goal.position) < 0.001
	actor.release()
	return valid
