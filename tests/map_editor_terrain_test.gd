extends SceneTree
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
const Compiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
const Prism = preload("res://scripts/core/expedition/spatial/world_solid_prism.gd")
var checks: Array[Dictionary] = []
var source_file := ""
var package_hash := ""
func check(id: String, ok: bool) -> void: checks.append({"id":id,"ok":ok})

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var source := TerrainPanel.sample_source(Document.empty("terrain_fixture"))
	var original := Schema.semantic_hash(source)
	var built := Compiler.compile(source)
	check("compile_sample",built.ok)
	if not built.ok: finish(); return
	var package: Dictionary = built.package
	package_hash = built.output_hash
	check("exact_coplanar_compaction_count",package.part.surfaces.size() == 4)
	var slabs: Array = package.part.solid_prisms.filter(func(mass: Dictionary) -> bool: return mass.has("thickness_y"))
	check("solid_slab_exact",package.part.solid_volumes.is_empty() and slabs.size() == 1 and slabs[0].thickness_y == 4.0 and Prism.prepare(slabs[0]).bounds == AABB(Vector3(0,36,100),Vector3(200,4,100)))
	check("source_not_mutated",Schema.semantic_hash(source) == original)
	check("repeat_identical_package",Compiler.compile(source).output_hash == built.output_hash)
	var reordered := source.duplicate(true); reordered.layers.reverse()
	check("collection_order_independent",Compiler.compile(reordered).output_hash == built.output_hash)
	check("package_valid",Compiler.validate_package(package))
	var corrupt := package.duplicate(true); corrupt.part.surfaces[0].vertices[0] += Vector3.UP
	check("tampered_package_rejected",not Compiler.validate_package(corrupt) and Compiler.preview_manifest(corrupt) == null)
	for i: int in package.visuals.size(): check("same_visual_logic_vertices_%d"%i,package.visuals[i].vertices == package.part.surfaces[i].vertices)
	var geometry := WorldGeometry.new()
	check("canonical_configure",geometry.configure(Compiler.preview_manifest(package),"terrain_preview").ok)
	var profile: Dictionary = package.profile
	var start := point(package,"lower",Vector3(20,0,50))
	var under := point(package,"lower",Vector3(50,0,150))
	var ramp := point(package,"ramp",Vector3(150,20,50))
	var top := point(package,"bridge",Vector3(50,40,150))
	check("ramp_intermediate_support",geometry.position_query(ramp,profile,geometry.geometry_revision).ok)
	check("ramp_rejects_flattening",not geometry.position_query(ExpeditionWorldPoint.create("terrain_preview",ramp.surface_id,Vector3(150,0,50)),profile,geometry.geometry_revision).ok)
	check("lower_support_under_bridge",geometry.position_query(under,profile,geometry.geometry_revision).ok)
	var route := geometry.path(start,top,profile,geometry.geometry_revision)
	check("connected_route_to_bridge",route.ok)
	var motion := WorldActorMotion.new()
	check("canonical_motion_bind",motion.configure(geometry,start,profile,"fixture_actor").ok)
	check("canonical_motion_plan",motion.plan(top,geometry.geometry_revision).ok)
	var crossed := false; var arrived := false; var movement_ok := true
	for i: int in 400:
		var step := motion.advance(3.0)
		if not step.ok: movement_ok = false; break
		if motion.point().surface_id == ramp.surface_id and motion.point().position.y > 0 and motion.point().position.y < 40: crossed = true
		if step.data.arrived: arrived = true; break
	check("continuous_motion_no_teleport",movement_ok and crossed and arrived and motion.point().to_data() == top.to_data())
	check("underpass_route",geometry.path(under,start,profile,geometry.geometry_revision).ok)
	var large := profile.duplicate(true); large.height = 38.0
	check("slab_rejects_tall_body",not geometry.position_query(under,large,geometry.geometry_revision).ok)
	var attack := geometry.query_attack({"geometry_rule_id":&"direct_volume","range":100.0},under,top,geometry.geometry_revision)
	check("bridge_blocks_attack",attack.ok and not attack.data.hit and not attack.data.los_ok)
	var ray := geometry.resolve_surface(Vector3(50,100,150),Vector3.DOWN,[top.surface_id,under.surface_id],geometry.geometry_revision)
	check("ray_picks_upper_deck",ray.ok and ray.data.point.surface_id == top.surface_id)
	check("slab_occludes_hidden_lower",not geometry.resolve_surface(Vector3(50,100,150),Vector3.DOWN,[under.surface_id],geometry.geometry_revision).ok)
	var flat := Document.empty("brush_fixture")
	flat.layers = [TerrainPanel._layer("floor","Chão",0,0,10,5,5,[])]; flat.layers[0].heights.resize(25); flat.layers[0].heights.fill(0.0)
	var options := {"mode":"raise","radius":15.0,"strength":4.0,"hardness":1.0}
	var stroke := Brush.stroke(flat,"floor",[Vector2(10,20),Vector2(30,20)],options)
	check("brush_raise_oracle",stroke.ok and stroke.data.layers[0].heights[12] == 4 and flat.layers[0].heights[12] == 0)
	check("brush_input_density_independent",Brush.stroke(flat,"floor",[Vector2(10,20),Vector2(10,20),Vector2(20,20),Vector2(30,20)],options).output_hash == stroke.output_hash)
	options.mode = "lower"
	check("brush_lower_oracle",Brush.stroke(flat,"floor",[Vector2(20,20)],options).data.layers[0].heights[12] == -4)
	options.mode = "flatten"; options.target = 8.0; options.strength = 1.0
	check("flatten_oracle",Brush.stroke(flat,"floor",[Vector2(20,20)],options).data.layers[0].heights[12] == 8)
	options.mode = "ramp"; options.target = 0.0; options.end_height = 10.0; options.radius = 5.0
	var sloped := Brush.stroke(flat,"floor",[Vector2(0,20),Vector2(40,20)],options)
	check("ramp_control_oracle",sloped.ok and sloped.data.layers[0].heights[12] == 5.0 and sloped.data.layers[0].heights[14] == 10.0)
	check("ramp_rejects_zero_length",not Brush.stroke(flat,"floor",[Vector2.ZERO,Vector2.ZERO],options).ok)
	options.mode = "smooth"; options.radius = 1.0
	var spike := flat.duplicate(true); spike.layers[0].heights[12] = 9.0
	check("smooth_frozen_neighbors_oracle",Brush.stroke(spike,"floor",[Vector2(20,20)],options).data.layers[0].heights[12] == 1.0)
	options.mode = "material"; options.material = "earth"
	var painted := Brush.stroke(flat,"floor",[Vector2(20,20)],options)
	check("paint_two_materials",painted.ok and painted.data.layers[0].material_masks.earth[12] == 1.0 and painted.data.layers[0].material_masks.grass[12] == 0.0)
	options.mode = "raise"; options.strength = 4.0; options.radius = 15.0
	var locked := flat.duplicate(true); locked.layers[0].locked = true
	check("layer_lock",Brush.stroke(locked,"floor",[Vector2(20,20)],options).code == "layer_locked")
	var protected := flat.duplicate(true)
	protected.regions = [{"region_id":"keep","layer_id":"floor","polygon_xz":[[15,15],[25,15],[25,25],[15,25]],"purpose":"protected"}]
	protected.layers[0].protected_regions = ["keep"]
	check("region_protected",Brush.stroke(protected,"floor",[Vector2(20,20)],options).data.layers[0].heights[12] == 0.0)
	protected = flat.duplicate(true)
	protected.connectors = [{"connector_id":"door","surface_id":"floor","position_xyz":[20,0,0],"normal_xyz":[0,0,-1],"width":10,"headroom":100,"tags":["walk"],"kind":"walk","direction":"both"}]
	check("connector_protected",Brush.stroke(protected,"floor",[Vector2(20,0)],options).data.layers[0].heights[2] == 0.0)
	var session := Session.new(); session.replace(flat)
	check("stroke_atomic_apply",session.apply(stroke.data).ok)
	check("stroke_atomic_undo",session.undo() and session.document().semantic_hash() == Schema.semantic_hash(flat))
	check("stroke_atomic_redo",session.redo() and session.document().to_data().layers[0].heights == stroke.data.layers[0].heights)
	var source_path := ProjectSettings.globalize_path("res://.godot/terrain_source_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json")
	source_file = source_path
	check("save_source",Store.save_source(source_path,source,"").ok)
	check("reopen_preserves_compilation",Compiler.compile(Store.load_source(source_path).data).output_hash == built.output_hash)
	var invalid := source.duplicate(true); invalid.layers[0].heights[0] = NAN
	check("nonfinite_rejected",not Compiler.compile(invalid).ok)
	invalid = source.duplicate(true); invalid.layers.append(invalid.layers[0].duplicate(true)); invalid.layers[-1].layer_id = "overlap"
	check("overlap_rejected",Compiler.compile(invalid).code == "geometry_overlap")
	invalid = source.duplicate(true); invalid.special_surfaces[0].vertices_xyz[2][1] = 50
	check("nonplanar_special_rejected",Compiler.compile(invalid).code == "geometry_invalid")
	invalid = source.duplicate(true); invalid.special_surfaces[0].vertices_xyz = [[0,40,100],[200,40,100],[50,40,130],[200,40,200],[0,40,200]]
	check("concave_special_rejected",Compiler.compile(invalid).code == "geometry_invalid")
	invalid = source.duplicate(true)
	for vertex: Array in invalid.special_surfaces[0].vertices_xyz: vertex[1] = 10
	check("insufficient_clearance_rejected",Compiler.compile(invalid).code == "insufficient_headroom")
	invalid = flat.duplicate(true); invalid.layers[0].heights[1] = 100
	# F9 explicitly accepts mixed relief. Keep steep faces as unbound masses;
	# do not raise the walking limit or quietly discard the peak.
	var mixed_peak := Compiler.compile(invalid)
	var walking_only := mixed_peak.ok
	if mixed_peak.ok:
		for cell: Dictionary in mixed_peak.package.part.surfaces:
			var v: Array = cell.vertices
			if absf((Vector3(v[1])-Vector3(v[0])).cross(Vector3(v[2])-Vector3(v[0])).normalized().y) < sqrt(0.5)-0.00001: walking_only = false
	var steep_only := flat.duplicate(true)
	steep_only.layers[0].columns = 2; steep_only.layers[0].rows = 2; steep_only.layers[0].heights = [0,100,0,100]
	check("mixed_relief_retains_mass_and_45_degree_support_limit",walking_only and mixed_peak.package.part.solid_prisms.size() == mixed_peak.package.visuals.size() and mixed_peak.package.part.solid_prisms.any(func(mass: Dictionary) -> bool: return mass.support_surface_id == "") and Compiler.compile(steep_only).code == "slope_too_steep")
	var port_source := flat.duplicate(true)
	port_source.connectors = [{"connector_id":"west","surface_id":"floor","position_xyz":[0,0,5],"normal_xyz":[-1,0,0],"width":6,"headroom":100,"tags":["walk"],"kind":"walk","direction":"both"}]
	var port_package := Compiler.compile(port_source)
	check("authored_opening_compiles",port_package.ok)
	if port_package.ok:
		var openings := 0
		for boundary: Dictionary in port_package.package.boundaries:
			if boundary.kind == "opening": openings += 1
		check("one_stable_boundary_opening",openings == 1)
	port_source.connectors[0].position_xyz[0] = 5
	check("interior_port_rejected",Compiler.compile(port_source).code == "connector_invalid")
	port_source.connectors[0].position_xyz[0] = 0; port_source.connectors[0].width = 100
	check("port_wider_than_edge_rejected",Compiler.compile(port_source).code == "connector_invalid")
	invalid = source.duplicate(true); invalid.layers[1].origin_xz[1] = -110
	check("unconnected_ramp_rejected",Compiler.compile(invalid).code == "route_unreachable")
	var warped := flat.duplicate(true); warped.layers[0].heights[12] = 1.0
	var triangulated := Compiler.compile(warped)
	check("warped_grid_compiles_to_triangles",triangulated.ok and triangulated.package.part.surfaces.size() == 12)
	check("invalid_brush_radius_rejected",not Brush.stroke(flat,"floor",[Vector2.ZERO],{"radius":-1}).ok)
	check("nonfinite_brush_point_rejected",not Brush.stroke(flat,"floor",[Vector2(NAN,0)],options).ok)
	options.shape = "square"; options.radius = 10.0; options.hardness = 1.0
	check("square_stamp_corner_oracle",Brush.stroke(flat,"floor",[Vector2(20,20)],options).data.layers[0].heights[6] == 4.0)
	var before := Schema.semantic_hash(source)
	check("compile_cancelled",Compiler.compile(source,func(_p: float) -> bool: return true).code == "cancelled" and Schema.semantic_hash(source) == before)
	var job := Compiler.new(); job.start(source)
	while not job.ready(): await process_frame
	check("late_result_rejected",job.take("different_source").code == "stale_source")
	job = Compiler.new(); job.start(source); job.cancel()
	while not job.ready(): await process_frame
	check("thread_cancelled_no_package",job.take(original).code == "cancelled")
	var measures: Array = []
	for axis: int in [3,5,9,17]:
		var data := Document.empty("measure_%d"%axis); var heights: Array = []; heights.resize(axis*axis); heights.fill(0.0)
		data.layers = [TerrainPanel._layer("floor","Medição",0,0,32,axis,axis,heights)]
		var samples: Array = []
		var brush_samples: Array = []
		var measured_package: Dictionary = {}
		for repeat: int in 10:
			var started := Time.get_ticks_usec(); var measured := Compiler.compile(data); samples.append((Time.get_ticks_usec()-started)/1000.0)
			check("measurement_success_%d_%d"%[axis,repeat],measured.ok)
			measured_package = measured.package if measured.ok else {}
			started = Time.get_ticks_usec(); Brush.stroke(data,"floor",[Vector2(32,32),Vector2(64,64)],{"radius":32.0,"strength":2.0}); brush_samples.append((Time.get_ticks_usec()-started)/1000.0)
		measures.append({"axis":axis,"area":pow((axis-1)*32,2),"cells":(axis-1)*(axis-1),"visual_triangles":(axis-1)*(axis-1)*2,"bake_ms":samples,"brush_ms":brush_samples,"source_bytes":JSON.stringify(data).to_utf8_buffer().size(),"package_bytes":var_to_bytes(measured_package).size()})
	var too_large := flat.duplicate(true); too_large.layers[0].columns = 18; too_large.layers[0].rows = 18; too_large.layers[0].heights.resize(324); too_large.layers[0].heights.fill(0.0)
	check("flat_grid_above_old_limit_compiles",Compiler.compile(too_large).ok and Compiler.compile(too_large).package.part.surfaces.size() == 1)
	check("brush_above_old_grid_limit",Brush.stroke(too_large,"floor",[Vector2.ZERO],options).ok)
	var long_trace: Array = []; long_trace.resize(4097); long_trace.fill(Vector2.ZERO)
	check("long_stroke_rejected_whole",Brush.stroke(flat,"floor",long_trace,options).code == "brush_limit_exceeded" and flat.layers[0].heights[12] == 0.0)
	var metrics := FileAccess.open("res://.godot/terrain_measurements.json",FileAccess.WRITE); metrics.store_string(JSON.stringify(measures)); metrics.close()
	print("M2_HASH "+built.output_hash)
	finish()

func point(package: Dictionary, source_id: String, position: Vector3) -> ExpeditionWorldPoint:
	for i: int in package.visuals.size():
		if package.visuals[i].source_id == source_id and ExpeditionFixtureGeometry.contains(package.part.surfaces[i],position): return ExpeditionWorldPoint.create("terrain_preview",package.part.surfaces[i].surface_id,position)
	return null

func finish() -> void:
	var ok := not checks.is_empty()
	for item: Dictionary in checks:
		if not item.ok: ok = false
	print("M2_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"source_path":source_file,"package_hash":package_hash}))
	quit(0 if ok else 1)
