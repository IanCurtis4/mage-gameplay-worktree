extends SceneTree
## Model invariants for the rounded-hill stroke and the organic terrain example.
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
const Example = preload("res://scripts/map_authoring/terrain/organic_example.gd")
const Compiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Preferences = preload("res://scripts/map_authoring/library/editor_preferences.gd")
const Library = preload("res://scripts/map_authoring/library/library_model.gd")

var checks: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ROUNDED_CHECK "+id+" "+str(ok))

func run() -> void:
	var source := Document.empty("rounded_hill_model")
	var source_before := source.duplicate(true)
	var source_hash := Schema.semantic_hash(source)
	var created := Example.create(source)
	check("organic_example_created_without_mutating_empty_source",created.ok and Schema.semantic_hash(source) == source_hash and source == source_before)
	if not created.ok: finish(); return
	var data: Dictionary = created.data
	check("organic_example_valid_source",Schema.validate(data).is_empty())
	check("prescribed_grid_and_domain",data.layers.size() == 1 and data.layers[0].columns == 33 and data.layers[0].rows == 33 and data.layers[0].sample_spacing == 50 and data.layers[0].origin_xz == [0,0] and data.layers[0].origin_xz[0]+(data.layers[0].columns-1)*data.layers[0].sample_spacing == 1600 and data.layers[0].origin_xz[1]+(data.layers[0].rows-1)*data.layers[0].sample_spacing == 1600)
	var layer: Dictionary = data.layers[0]
	var heights: Array = layer.heights
	var center := 16*33+16
	check("two_frozen_110_hill_strokes_reach_220_cap",is_equal_approx(float(heights[center]),220.0) and heights.max() <= 220.0 and heights.min() >= 0.0)
	check("rounded_profile_is_radial_and_symmetric",is_equal_approx(float(heights[16*33+12]),float(heights[16*33+20])) and is_equal_approx(float(heights[12*33+16]),float(heights[20*33+16])) and is_equal_approx(float(heights[16*33+12]),float(heights[12*33+16])) and heights[center] > heights[16*33+20] and heights[16*33+20] > heights[16*33+24])
	check("rounded_profile_has_soft_outer_edge",heights[16*33+24] > 0.0 and heights[16*33+25] == 0.0 and heights[16*33+24] < 1.0)
	check("curved_material_path_is_painted_without_global_fill",layer.material_masks.has("earth") and layer.material_masks.earth.size() == 33*33 and layer.material_masks.earth[10*33+10] > 0.5 and layer.material_masks.earth[32*33+32] == 0.0)
	check("profile_and_resource_caps_remain_unchanged",Compiler.MAX_SUPPORTS == 1024 and Compiler.MAX_GRID_QUADS == 65536 and Compiler.PROFILE.radius == 2.0 and Compiler.PROFILE.height == 12.0 and Compiler.PROFILE.connector_kinds == ["walk"])
	check("grid_and_stroke_strength_remain_under_existing_caps",(layer.columns-1)*(layer.rows-1) <= Compiler.MAX_GRID_QUADS and 110.0 <= 128.0)

	var flat := flat_source("rounded_stroke")
	var flat_center := 2*5+2
	var options := {"mode":"rounded_hill","shape":"circle","radius":420.0,"strength":110.0,"hardness":0.0}
	var one := Brush.stroke(flat,"field",[Vector2(100,100)],options)
	var repeated := Brush.stroke(flat,"field",[Vector2(100,100),Vector2(100,100),Vector2(100,100)],options)
	check("repeated_pointer_events_do_not_accumulate",one.ok and repeated.ok and one.output_hash == repeated.output_hash and one.data.layers[0].heights[flat_center] == 110.0 and flat.layers[0].heights[flat_center] == 0.0)
	var straight := Brush.stroke(flat,"field",[Vector2(30,100),Vector2(170,100)],options)
	var densified := Brush.stroke(flat,"field",[Vector2(30,100),Vector2(70,100),Vector2(120,100),Vector2(170,100)],options)
	check("collinear_events_preserve_frozen_stroke_result",straight.ok and densified.ok and straight.output_hash == densified.output_hash and flat.layers[0].heights[flat_center] == 0.0)
	var locked := flat.duplicate(true); locked.layers[0].locked = true
	check("locked_layer_refuses_rounded_hill",Brush.stroke(locked,"field",[Vector2(100,100)],options).get("code") == "layer_locked")
	var protected := flat.duplicate(true)
	protected.regions = [{"region_id":"protected_center","layer_id":"field","polygon_xz":[[75,75],[125,75],[125,125],[75,125]],"purpose":"protected"}]
	protected.layers[0].protected_regions = ["protected_center"]
	var protected_result := Brush.stroke(protected,"field",[Vector2(100,100)],options)
	check("protected_region_is_preserved",protected_result.ok and protected_result.data.layers[0].heights[2*5+2] == 0.0)
	var connected := flat.duplicate(true)
	connected.connectors = [{"connector_id":"door","surface_id":"field","position_xyz":[100,0,0],"normal_xyz":[0,0,-1],"width":50,"headroom":100,"tags":["walk"],"kind":"walk","direction":"both"}]
	var connector_result := Brush.stroke(connected,"field",[Vector2(100,0)],options)
	check("connector_clearance_is_preserved",connector_result.ok and Schema.validate(connector_result.data).is_empty() and connector_result.data.connectors == connected.connectors and connector_result.data.layers[0].heights[2] == 0.0 and connector_result.data.layers[0].heights[2*5+2] == 110.0)
	var invalid := options.duplicate(true); invalid.radius = -1.0
	check("invalid_shape_parameters_are_rejected",not Brush.stroke(flat,"field",[Vector2(100,100)],invalid).ok)
	check("preference_limits_reject_strength_above_existing_cap",not Preferences.valid_options({"mode":"rounded_hill","shape":"circle","material":"earth","radius":420.0,"strength":129.0,"hardness":0.0,"target":0.0,"end_height":0.0}))
	var occupied := flat.duplicate(true)
	check("occupied_example_source_is_refused_without_mutation",Example.create(occupied).get("code") == "source_occupied" and Schema.semantic_hash(occupied) == Schema.semantic_hash(flat))
	var presets := Library.builtin_presets()
	check("rounded_builtin_preset_is_appended_after_legacy_presets",presets.size() == 4 and presets[0].id == "builtin_soft_hill" and presets[1].id == "builtin_smooth_ground" and presets[2].id == "builtin_earth_path" and presets[3].id == "builtin_rounded_hill" and presets[3].options.mode == "rounded_hill")
	check("rounded_builtin_preset_options_obey_existing_caps",presets.size() == 4 and presets.all(func(p: Dictionary) -> bool: return Preferences.valid_options(p.options)) and presets[3].options.radius == 120.0 and presets[3].options.strength == 12.0)
	finish()

func flat_source(document_id: String) -> Dictionary:
	var data := Document.empty(document_id)
	var heights: Array = []; heights.resize(25); heights.fill(0.0)
	data.layers = [{"layer_id":"field","name":"Campo","origin_xz":[0,0],"sample_spacing":50,"columns":5,"rows":5,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]}]
	return data

func finish() -> void:
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_ROUNDED_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	quit(0 if ok else 1)
