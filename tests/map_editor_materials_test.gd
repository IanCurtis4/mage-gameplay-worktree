extends SceneTree
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_view.gd")
const ProjectionView = preload("res://scripts/world/expedition_geometry_view.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_MATERIAL_CHECK "+id+" "+str(ok))
static func source() -> Dictionary:
	var data := Piece.empty("four_materials"); var heights: Array = []; heights.resize(25); heights.fill(0.0)
	var masks := {}
	for id: String in Materials.IDS:
		var weights: Array = []; weights.resize(25); weights.fill(0.25); masks[id] = weights
	data.layers = [{"layer_id":"floor","name":"Materiais","origin_xz":[0,0],"sample_spacing":16.0,"columns":5,"rows":5,"heights":heights,"material_masks":masks,"locked":false,"protected_regions":[]}]
	return data
func run() -> void:
	var original := source(); var original_hash := Schema.semantic_hash(original)
	check("four_named_materials",Materials.IDS == ["grass","earth","sand","stone"])
	var dependencies := Materials.dependencies()
	check("four_tiles_and_imports_are_hashed",dependencies.size() == 9 and dependencies.all(func(item: Dictionary) -> bool: return item.sha256 == FileAccess.get_sha256(item.path)))
	check("renderer_dependency_has_new_revision",dependencies.any(func(item: Dictionary) -> bool: return item.path == Materials.SHADER_PATH and item.revision == 2))
	var built := Terrain.compile(original)
	check("four_mask_source_compiles",built.ok)
	if not built.ok: print(built); finish(); return
	check("four_masks_survive_compilation",built.package.render_layers[0].material_masks == original.layers[0].material_masks)
	check("package_dependencies_revalidate",Terrain.validate_package(built.package) and built.package.dependencies == dependencies)
	check("compilation_preserves_source",Schema.semantic_hash(original) == original_hash)
	var options := {"mode":"material","material":"sand","radius":12.0,"strength":1.0,"hardness":1.0}
	var full := Brush.stroke(original,"floor",[Vector2(32,32)],options)
	check("sand_paint_independent_weights",full.ok and full.data.layers[0].material_masks.sand[12] == 1.0 and full.data.layers[0].material_masks.grass[12] == 0.0 and full.data.layers[0].material_masks.earth[12] == 0.0 and full.data.layers[0].material_masks.stone[12] == 0.0)
	check("paint_keeps_heights",full.data.layers[0].heights == original.layers[0].heights)
	check("paint_outside_stamp_unchanged",Materials.weights(full.data.layers[0],0) == [0.25,0.25,0.25,0.25])
	options.material = "stone"; options.strength = 0.5
	var partial := Brush.stroke(original,"floor",[Vector2(32,32)],options)
	check("stone_half_strength_oracle",partial.ok and Materials.weights(partial.data.layers[0],12) == [0.125,0.125,0.125,0.625])
	var sums := true
	for k: int in 25:
		var weights := Materials.weights(partial.data.layers[0],k)
		sums = sums and absf(weights[0]+weights[1]+weights[2]+weights[3]-1.0) < 1e-12
	check("every_painted_weight_vector_is_normalized",sums)
	var dense := Brush.stroke(original,"floor",[Vector2(20,32),Vector2(28,32),Vector2(36,32),Vector2(44,32)],options)
	var sparse := Brush.stroke(original,"floor",[Vector2(20,32),Vector2(44,32)],options)
	check("four_material_stroke_is_pointer_density_independent",dense.ok and sparse.ok and dense.data == sparse.data)
	check("preview_and_commit_use_same_paint",Brush.stroke(original,"floor",[Vector2(32,32)],options,true).data == partial.data)
	var locked := original.duplicate(true); locked.layers[0].locked = true
	check("locked_layer_rejects_paint",Brush.stroke(locked,"floor",[Vector2(32,32)],options).code == "layer_locked")
	var protected := original.duplicate(true); protected.regions = [{"region_id":"pin","layer_id":"floor","polygon_xz":[[20,20],[44,20],[44,44],[20,44]],"purpose":"protected"}]; protected.layers[0].protected_regions = ["pin"]
	check("protected_region_keeps_all_masks",Brush.stroke(protected,"floor",[Vector2(32,32)],options).data.layers[0].material_masks == original.layers[0].material_masks)
	protected = original.duplicate(true); protected.connectors = [{"connector_id":"gate","surface_id":"floor","position_xyz":[0,0,32],"normal_xyz":[-1,0,0],"width":8.0,"headroom":100.0,"kind":"walk","tags":["walk"],"direction":"both"}]
	check("connector_exclusion_keeps_all_masks",Brush.stroke(protected,"floor",[Vector2(0,32)],options).data.layers[0].material_masks == original.layers[0].material_masks)
	var implicit := original.duplicate(true); implicit.layers[0].material_masks = {}
	options.material = "sand"; options.strength = 1.0
	var from_default := Brush.stroke(implicit,"floor",[Vector2(32,32)],options)
	check("implicit_grass_can_be_painted_sand",from_default.ok and Materials.weights(from_default.data.layers[0],12) == [0.0,0.0,1.0,0.0])
	check("implicit_unpainted_region_stays_grass",Materials.weights(from_default.data.layers[0],0) == [1.0,0.0,0.0,0.0])
	options.material = "lava"
	check("unknown_brush_material_rejected",Brush.stroke(original,"floor",[Vector2(32,32)],options).code == "material_unsupported")
	var unknown := original.duplicate(true); unknown.layers[0].material_masks.lava = unknown.layers[0].material_masks.sand.duplicate()
	check("unknown_compiler_material_rejected",Terrain.compile(unknown).code == "material_unsupported")
	var session := Session.new(); session.replace(original); session.apply(full.data)
	var painted_hash := session.document().semantic_hash()
	check("four_material_edit_undo",session.undo() and session.document().semantic_hash() == original_hash)
	check("four_material_edit_redo",session.redo() and session.document().semantic_hash() == painted_hash)
	check("paint_roundtrip_is_exact",Schema.read(JSON.stringify(full.data,"",true,true).to_utf8_buffer()).output_hash == Schema.semantic_hash(full.data))
	var legacy: Dictionary = original.layers[0].duplicate(true); legacy.material_masks.erase("sand"); legacy.material_masks.erase("stone")
	check("legacy_two_mask_ratio_is_preserved",Materials.weights(legacy,0) == [0.5,0.5,0.0,0.0])
	var arrays := Materials.arrays(original.layers[0])
	check("all_four_weights_reach_mesh",arrays[Mesh.ARRAY_COLOR][12] == Color(0.25,0.25,0.25,0.25))
	check("custom_world_channels_cover_every_vertex",arrays[Mesh.ARRAY_CUSTOM0].size() == 100 and arrays[Mesh.ARRAY_CUSTOM1].size() == 100)
	check("world_xyz_is_not_projected_uv",arrays[Mesh.ARRAY_CUSTOM0][12*4] == 32.0 and arrays[Mesh.ARRAY_CUSTOM0][12*4+1] == 0.0 and arrays[Mesh.ARRAY_CUSTOM0][12*4+2] == 32.0)
	var sloping: Dictionary = original.layers[0].duplicate(true)
	for z: int in 5:
		for x: int in 5: sloping.heights[z*5+x] = float(x)*16.0
	var transformed := Materials.arrays(sloping,{},1,Vector3(100,3,50))
	var point := Vector3(transformed[Mesh.ARRAY_CUSTOM0][44],transformed[Mesh.ARRAY_CUSTOM0][45],transformed[Mesh.ARRAY_CUSTOM0][46])
	check("world_data_transforms_once",point == Vector3(68,19,66) and transformed[Mesh.ARRAY_VERTEX][11] == ProjectionView.project(point))
	var normal := Vector3(transformed[Mesh.ARRAY_CUSTOM1][44],transformed[Mesh.ARRAY_CUSTOM1][45],transformed[Mesh.ARRAY_CUSTOM1][46])
	check("material_normal_rotates_with_geometry",normal.distance_to(Vector3(0,sqrt(0.5),-sqrt(0.5))) < 0.000001)
	check("world_uv_tracks_transformed_position",transformed[Mesh.ARRAY_TEX_UV][11] == Vector2(point.x,point.z)/128.0)
	var mesh := Materials.mesh(original.layers[0])
	check("mesh_declares_custom_float_formats",mesh.get_surface_count() == 1 and (mesh.surface_get_format(0) & Materials.MESH_FLAGS) == Materials.MESH_FLAGS)
	check("source_survives_paint_and_render",Schema.semantic_hash(original) == original_hash)
	var domain := Objects.depth_domain([-8192.0,0.0,8192.0])
	check("negative_display_depth_stays_above_background",Objects.depth_order(-8192,domain) > 0 and Objects.depth_order(8192,domain) < 4090)
	check("display_depth_preserves_order_and_object_offset",Objects.depth_order(-100,domain) < Objects.depth_order(100,domain) and Objects.depth_order(0,domain,1) == Objects.depth_order(0,domain)+1)
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_MATERIAL_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
