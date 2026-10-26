extends SceneTree
const Compiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Partition = preload("res://scripts/map_authoring/compiler/terrain_partition.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const DecimalFloat = preload("res://scripts/map_authoring/io/decimal_float.gd")
var checks: Array[Dictionary] = []
var source_path := ""
var package_hash := ""
var first_compile_ms := 0.0
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok})
	if not ok: print("M2_SCALE_FAILURE "+id)
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	print("M2_SCALE_PHASE begin")
	var next_bytes := PackedByteArray(); next_bytes.resize(8); next_bytes.encode_s64(0,0x3ff0000000000001)
	check("decimal_tie_rounds_to_even",DecimalFloat.parse("1.00000000000000011102230246251565404236316680908203125") == 1.0)
	check("decimal_above_tie_rounds_up",DecimalFloat.parse("1.00000000000000011102230246251565404236316680908203126") == next_bytes.decode_double(0))
	next_bytes.encode_s64(0,1)
	check("decimal_subnormal_retained",DecimalFloat.parse("5e-324") == next_bytes.decode_double(0))
	check("decimal_underflow_and_overflow",DecimalFloat.parse("1e-400") == 0.0 and not is_finite(DecimalFloat.parse("1e400")))
	var source := TerrainPanel.large_sample_source(Document.empty("large_piece_fixture"))
	var before := Schema.semantic_hash(source)
	var first_compile_started := Time.get_ticks_usec()
	var built := Compiler.compile(source)
	first_compile_ms = (Time.get_ticks_usec()-first_compile_started)/1000.0
	check("fractional_masks_binary_roundtrip",Schema.read(JSON.stringify(source,"",true,true).to_utf8_buffer()).output_hash == before)
	print("M2_SCALE_PHASE large_built")
	check("large_contiguous_piece_compiles",built.ok)
	if not built.ok: finish(); return
	var package: Dictionary = built.package; package_hash = built.output_hash
	check("one_piece_is_not_grid_count",package.piece_count == 1 and package.grid_quads == 4096 and package.part.surfaces.size() == 3)
	check("full_extent_preserved",package.render_layers[0].columns == 65 and package.render_layers[0].rows == 65 and Partition.point(package.render_layers[0],64,64) == Vector3(8192,128,8192))
	check("dense_paint_retained",package.render_layers[0].material_masks == source.layers[0].material_masks)
	check("dependencies_hashed",package.dependencies.size() == 9 and package.dependencies == Materials.dependencies())
	var forged := package.duplicate(true); forged.dependencies[0].sha256 = "0".repeat(64); forged.erase("package_hash"); forged.package_hash = ExpeditionCanonical.digest(forged)
	check("forged_asset_dependency_rejected",not Compiler.validate_package(forged))
	var arrays := Materials.arrays(source.layers[0])
	var compiled_arrays := Materials.arrays(package.render_layers[0])
	check("visual_source_package_equivalence",arrays == compiled_arrays)
	check("dense_visual_count",arrays[Mesh.ARRAY_VERTEX].size() == 4225 and arrays[Mesh.ARRAY_INDEX].size() == 4096*6)
	check("world_uv_scale_independent_of_partition",arrays[Mesh.ARRAY_TEX_UV][0] == Vector2.ZERO and arrays[Mesh.ARRAY_TEX_UV][-1] == Vector2(64,64))
	var normal_ok := true
	for color: Color in arrays[Mesh.ARRAY_COLOR]:
		for weight: float in [color.r,color.g,color.b,color.a]:
			if weight < 0 or weight > 1.0: normal_ok = false
		if absf(color.r+color.g+color.b+color.a-1.0) > 0.000001: normal_ok = false
	for k: int in 4225:
		var normal := Vector3(arrays[Mesh.ARRAY_CUSTOM1][k*4],arrays[Mesh.ARRAY_CUSTOM1][k*4+1],arrays[Mesh.ARRAY_CUSTOM1][k*4+2])
		if absf(normal.length()-1.0) > 0.000001: normal_ok = false
	check("continuous_blend_and_normal_range",normal_ok)
	var steep_layer: Dictionary = source.layers[0].duplicate(true)
	for z: int in 65:
		for x: int in 65: steep_layer.heights[z*65+x] = float(x)*128.0
	var paint_before: Dictionary = steep_layer.material_masks.duplicate(true)
	var steep_arrays := Materials.arrays(steep_layer)
	var center := (32*65+32)*4
	check("steep_material_receives_real_slope_normal",absf(steep_arrays[Mesh.ARRAY_CUSTOM1][center]+sqrt(0.5)) < 0.000001 and absf(steep_arrays[Mesh.ARRAY_CUSTOM1][center+1]-sqrt(0.5)) < 0.000001 and arrays[Mesh.ARRAY_CUSTOM1][center+1] > 0.99)
	check("steep_material_preserves_author_paint",steep_layer.material_masks == paint_before)
	var all_supported := true
	for z: int in 65:
		for x: int in 65:
			var position := Partition.point(source.layers[0],x,z)
			var found := false
			for cell: Dictionary in package.part.surfaces:
				if ExpeditionFixtureGeometry.contains(cell,position): found = true; break
			if not found: all_supported = false
	check("all4225_source_samples_on_exact_support",all_supported)
	print("M2_SCALE_PHASE all_samples")
	var geometry := WorldGeometry.new(); geometry.configure(Compiler.preview_manifest(package),"terrain_preview")
	var start := at(package,Vector3(64,0,3500)); var finish_point := at(package,Vector3(7000,128,3500))
	check("large_piece_route",geometry.path(start,finish_point,package.profile,geometry.geometry_revision).ok)
	var motion := WorldActorMotion.new(); var crossed := false; var arrived := false; var movement_ok: bool = motion.configure(geometry,start,package.profile,"scale_actor").ok
	if movement_ok: movement_ok = motion.plan(finish_point,geometry.geometry_revision).ok
	if movement_ok:
		for i: int in 100:
			var step := motion.advance(128)
			if not step.ok: movement_ok = false; break
			if motion.point().position.y > 0 and motion.point().position.y < 128: crossed = true
			if step.data.arrived: arrived = true; break
	check("large_real_continuous_traversal",movement_ok and crossed and arrived and motion.point().to_data() == finish_point.to_data())
	print("M2_SCALE_PHASE traversal")
	var options := {"mode":"raise","radius":200.0,"strength":8.0,"hardness":0.5}
	var edited := Brush.stroke(source,"field",[Vector2(2560,2560)],options)
	var preview := Brush.stroke(source,"field",[Vector2(2560,2560)],options,true)
	check("large_local_brush_exact_oracle",edited.ok and edited.data.layers[0].heights[20*65+20] == 8.0 and edited.data.layers[0].heights[0] == 0)
	check("preview_commit_same_data",edited.ok and preview.ok and edited.data == preview.data)
	var edited_package := Compiler.compile(edited.data)
	check("edited_large_piece_still_compiles",edited_package.ok and edited_package.package.piece_count == 1 and edited_package.package.part.surfaces.size() > 3)
	check("source_immutable",Schema.semantic_hash(source) == before)
	var session := Session.new(); session.replace(source); session.apply(edited.data)
	check("large_atomic_undo",session.undo() and session.document().semantic_hash() == before)
	check("large_atomic_redo",session.redo() and session.document().to_data().layers[0].heights == edited.data.layers[0].heights)
	source_path = ProjectSettings.globalize_path("res://.godot/large_piece_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json")
	check("large_source_saved",Store.save_source(source_path,source,"").ok)
	check("large_roundtrip_hash",Compiler.compile(Store.load_source(source_path).data).output_hash == built.output_hash)
	print("M2_SCALE_PHASE roundtrip")
	var flat := TerrainPanel.large_sample_source(Document.empty("flat129"),129)
	flat.layers[0].heights.fill(0.0); flat.connectors.clear()
	var flat_built := Compiler.compile(flat)
	check("flat129_is_one_generated_support",flat_built.ok and flat_built.package.grid_quads == 16384 and flat_built.package.part.surfaces.size() == 1)
	var complex := TerrainPanel.large_sample_source(Document.empty("complex"),33)
	complex.connectors.clear()
	for z: int in 33:
		for x: int in 33: complex.layers[0].heights[z*33+x] = float((x+z)%2)*8.0
	check("logical_budget_fails_without_partial_package",Compiler.compile(complex).code == "terrain_limit_exceeded" and not Compiler.compile(complex).has("package"))
	var extensive := TerrainPanel.large_sample_source(Document.empty("extensive"),257)
	extensive.layers.append(extensive.layers[0].duplicate(true)); extensive.layers[1].layer_id = "second"
	check("sample_budget_distinct_from_piece_size",Compiler.compile(extensive).code == "terrain_sample_limit")
	print("M2_SCALE_PHASE budgets")
	var metrics: Array = []
	for axis: int in [33,65,129]:
		var data := TerrainPanel.large_sample_source(Document.empty("measure_large_%d"%axis),axis)
		var bakes: Array = []; var previews: Array = []; var brushes: Array = []; var render_build: Array = []; var package_bytes := 0; var supports := 0
		for repeat: int in 5:
			var started := Time.get_ticks_usec(); var measured := Compiler.compile(data); bakes.append((Time.get_ticks_usec()-started)/1000.0)
			check("large_measurement_%d_%d"%[axis,repeat],measured.ok)
			if measured.ok: supports = measured.package.part.surfaces.size(); package_bytes = var_to_bytes(measured.package).size()
			started = Time.get_ticks_usec(); Brush.stroke(data,"field",[Vector2(2560,2560)],options,true); previews.append((Time.get_ticks_usec()-started)/1000.0)
			started = Time.get_ticks_usec(); Brush.stroke(data,"field",[Vector2(2560,2560)],options); brushes.append((Time.get_ticks_usec()-started)/1000.0)
			started = Time.get_ticks_usec(); Materials.arrays(data.layers[0]); render_build.append((Time.get_ticks_usec()-started)/1000.0)
		metrics.append({"piece_count":1,"axis":axis,"area_world2":8192*8192,"samples":axis*axis,"visual_triangles":2*(axis-1)*(axis-1),"supports":supports,"bake_ms":bakes,"brush_preview_ms":previews,"brush_commit_ms":brushes,"render_build_ms":render_build,"package_bytes":package_bytes,"source_bytes":JSON.stringify(data).to_utf8_buffer().size()})
		print("M2_SCALE_PHASE measured_"+str(axis))
	var file := FileAccess.open("res://.godot/terrain_scale_measurements.json",FileAccess.WRITE); file.store_string(JSON.stringify(metrics)); file.close()
	finish()

func at(package: Dictionary, position: Vector3) -> ExpeditionWorldPoint:
	for cell: Dictionary in package.part.surfaces:
		if ExpeditionFixtureGeometry.contains(cell,position): return ExpeditionWorldPoint.create("terrain_preview",cell.surface_id,position)
	return null

func finish() -> void:
	var ok := not checks.is_empty()
	for entry: Dictionary in checks:
		if not entry.ok: ok = false
	print("M2_SCALE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"source_path":source_path,"package_hash":package_hash,"first_compile_ms":first_compile_ms}))
	quit(0 if ok else 1)
