extends SceneTree
## Preserves the failing Gauss17/512 shape. Publication and public-witness
## validation/movement are measured separately; no cap or body reduction.
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
var checks: Array[Dictionary] = []
var metrics: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ORGANIC_CHECK "+id+" "+str(ok))
static func gaussian(axis: int = 17) -> Dictionary:
	var source := Piece.empty("organic_gaussian"); var heights: Array = []
	for z: int in axis:
		for x: int in axis:
			var px := float(x)*1200.0/(axis-1)-600.0; var pz := float(z)*1200.0/(axis-1)-600.0
			heights.append(220.0*exp(-(px*px+pz*pz)/(2.0*180.0*180.0)))
	source.layers = [{"layer_id":"hill","name":"Relevo contínuo","origin_xz":[0,0],"sample_spacing":1200.0/(axis-1),"columns":axis,"rows":axis,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]}]
	return source
static func map_source(source: Dictionary) -> Dictionary:
	var data := MapDocument.empty("organic_map"); var hash_value := Schema.semantic_hash(source)
	data.pieces = [{"piece_hash":hash_value,"source":source}]; data.instances = [{"instance_id":"hill","piece_hash":hash_value,"position_xyz":[0,0,0],"rotation_quarters":0}]
	return data
static func point(data: Dictionary) -> ExpeditionWorldPoint:
	return ExpeditionWorldPoint.create(data.stage_id,data.surface_id,data.position)
static func walk(world: WorldGeometry, route: Dictionary, profile: Dictionary) -> bool:
	var points: Array = route.points
	if points.is_empty(): return false
	var motion := WorldActorMotion.new()
	if not motion.configure(world,point(points[0]),profile,"organic_probe_actor").ok: return false
	motion._route = points.duplicate(true); motion._cursor = 1; motion._route_revision = world.geometry_revision
	var advanced := motion.advance(100000.0)
	var last: Dictionary = points[-1]
	var arrived: bool = advanced.ok and not motion.has_route() and motion.point().to_data() == last
	motion.release(); return arrived
func run() -> void:
	var source := gaussian(); var source_hash := Schema.semantic_hash(source)
	var read := Schema.read(JSON.stringify(source,"",true,true).to_utf8_buffer())
	check("same_gauss17_source_keeps_exact_shape",read.ok and read.valid and source.layers[0].columns == 17 and source.layers[0].heights[144] == 220.0)
	var started := Time.get_ticks_usec(); var terrain := Terrain.compile(source); metrics["terrain_ms"] = (Time.get_ticks_usec()-started)/1000.0
	check("rounded_geometry_keeps_512_actual_supports",terrain.ok and terrain.package.part.surfaces.size() == 512)
	check("original_storage_budget_is_preserved",WorldConnectivityBatch.LIMITS.max_storage_bytes == 268435456)
	started = Time.get_ticks_usec(); var compiled := Maps.compile(map_source(source)); metrics["map_ms"] = (Time.get_ticks_usec()-started)/1000.0
	check("gauss17_map_publishes_in_original_budget",compiled.ok)
	if not compiled.ok: print(compiled); finish(); return
	check("compilation_preserves_source",Schema.semantic_hash(source) == source_hash)
	var package_hash := ExpeditionCanonical.digest(compiled.package)
	var candidate := Candidate.create("map",compiled.package,compiled.package.source_hash)
	started = Time.get_ticks_usec(); var prepared := Candidate.prepare(candidate.candidate); metrics["real_body_ms"] = (Time.get_ticks_usec()-started)/1000.0
	check("same_curvature_accepts_actual_player_body",prepared.ok)
	if not prepared.ok: print(prepared); finish(); return
	var profile: Dictionary = prepared.manifest._data.input.traversal
	check("configured_player_profile_remains_20_32",profile.radius == 20.0 and profile.height == 32.0)
	check("inspection_package_is_not_rewritten",compiled.package.profile.radius == 2.0 and ExpeditionCanonical.digest(compiled.package) == package_hash)
	check("organic_area_is_one_authored_piece",compiled.package.piece_count == 1)
	var world := WorldGeometry.new(); var configured := world.configure(prepared.manifest,"map_preview")
	check("canonical_runtime_world_configures",configured.ok)
	var entry := point(prepared.entry); var destinations: Array[ExpeditionWorldPoint] = []
	for cell: Dictionary in world._stage.surfaces: destinations.append(Maps._walkable_point(world,cell,profile))
	started = Time.get_ticks_usec(); var batch := world.connectivity_batch(entry,destinations,profile,world.geometry_revision); metrics["publication_ms"] = (Time.get_ticks_usec()-started)/1000.0
	check("all_512_terminals_have_both_directions",batch.ok and batch.data.complete and batch.data.all_reachable and batch.data.targets.size() == 512)
	if not batch.ok: print(batch); finish(); return
	metrics["publication"] = batch.data.metrics.duplicate(true)
	var all_public := true; var all_endpoints := true; var all_moved := true; var verified := 0
	started = Time.get_ticks_usec()
	for index: int in destinations.size():
		for outward: bool in [true,false]:
			var witness := world.connectivity_witness(batch,index,outward,world.geometry_revision)
			all_public = all_public and witness.ok
			if not witness.ok: print("F9_ORGANIC_WITNESS_FAILURE "+str(index)+" "+str(outward)+" "+str(witness)); continue
			var first: Dictionary = witness.data.points[0]; var last: Dictionary = witness.data.points[-1]
			all_endpoints = all_endpoints and first == (entry.to_data() if outward else destinations[index].to_data()) and last == (destinations[index].to_data() if outward else entry.to_data())
			all_moved = all_moved and walk(world,witness.data,profile); verified += 1
		if index%32 == 31: print("F9_ORGANIC_WITNESS_PROGRESS "+str(index+1)); await process_frame
	metrics["public_validation_and_movement_ms"] = (Time.get_ticks_usec()-started)/1000.0; metrics["witnesses"] = verified
	check("all_1024_public_witnesses_revalidate_geometry",all_public and verified == 1024)
	check("all_witness_endpoints_keep_surface_and_position",all_endpoints)
	check("actual_motion_walks_every_witness_with_real_profile",all_moved)
	check("proofs_preserve_source_package_and_world_revision",Schema.semantic_hash(source) == source_hash and ExpeditionCanonical.digest(compiled.package) == package_hash and world.geometry_revision == 1 and world._occupancy.is_empty())
	finish()
func finish() -> void:
	var ok := checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("F9_ORGANIC_METRICS "+JSON.stringify(metrics,"",true,true))
	print("F9_ORGANIC_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
