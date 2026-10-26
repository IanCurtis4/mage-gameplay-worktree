extends SceneTree
const Catalog = preload("res://scripts/map_authoring/composition/border_profile_catalog.gd")
const Geometry = preload("res://scripts/map_authoring/composition/border_geometry.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Prism = preload("res://scripts/core/expedition/spatial/world_solid_prism.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_compiler.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Operations = preload("res://scripts/map_authoring/composition/border_operations.gd")
const Spans = preload("res://scripts/map_authoring/composition/border_spans.gd")
const Session = preload("res://scripts/map_authoring/composition/map_session.gd")
const PortFixture = preload("res://tests/map_editor_port_fragments_test.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_BORDER_CHECK "+id+" "+str(ok))
static func span(id: String, profile: String, length: float = 400.0) -> Dictionary:
	return {"span_id":id,"profile_id":profile,"a":Vector3.ZERO,"b":Vector3(length,0,0),"outward":Vector3(0,0,-1)}
static func area(faces: Array) -> float:
	var total := 0.0
	for face: Dictionary in faces:
		var v: Array = face.vertices
		for k: int in range(1,v.size()-1): total += (Vector3(v[k])-Vector3(v[0])).cross(Vector3(v[k+1])-Vector3(v[0])).length()*0.5
	return total
func run() -> void:
	var catalog := Catalog.load_catalog()
	check("four_families_and_transition_catalog",catalog.ok and catalog.definitions.size() == 5)
	if not catalog.ok: print(catalog); finish(); return
	check("unknown_profile_is_explicit",Catalog.resolve("missing",catalog).code == "profile_missing")
	check("legacy_profile_is_not_redefined",not catalog.definitions.has("ruin_envelope_v1"))
	for id: String in Catalog.IDS:
		var resolved := Catalog.resolve(id,catalog); var saved: String = resolved.definition.name
		resolved.definition.name = "Alteração em cópia"
		check(id+"_definition_immutable",Catalog.resolve(id,catalog).definition.name == saved)
		var dependencies := Catalog.dependencies(catalog.definitions[id]); var seen := {}; var valid: bool = dependencies.ok
		if valid:
			for dependency: Dictionary in dependencies.dependencies:
				if seen.has(dependency.path) or dependency.sha256 != FileAccess.get_sha256(dependency.path): valid = false
				seen[dependency.path] = true
		check(id+"_closed_asset_dependencies",valid and seen.has(Catalog.PATH) and seen.has(Catalog.BORDER_SHADER))
	var forest := span("forest","forest_rootbank_v1",100); var input_hash := Canonical.digest(forest)
	var built := Geometry.build([forest],catalog.definitions)
	check("forest_span_builds",built.ok)
	if not built.ok: print(built); finish(); return
	check("obstacle_cap_never_emits_support",not built.has("surfaces") and built.solid_prisms.size() == 1 and built.solid_prisms[0].support_surface_id == "")
	check("forest_mass_exact_bounds",Prism.prepare(built.solid_prisms[0]).bounds == AABB(Vector3(0,-4,-80),Vector3(100,28,80)))
	var hit := Prism.sweep(Vector3(50,100,-40),Vector3(50,-20,-40),Prism.prepare(built.solid_prisms[0]),0,0)
	check("forest_cap_height12_oracle",not hit.is_empty() and absf(float(hit.fraction)-88.0/120.0) < 0.000001)
	check("forest_real_side_area5760",absf(area(built.faces.filter(func(face: Dictionary) -> bool: return face.outward != Vector3.ZERO))-5760.0) < 0.01)
	check("short_forest_span_uses_small_safe_fallback",built.props.size() == 1 and built.props[0].definition_id == "woodland_shrub" and built.props[0].position == Vector3(50,12,-40))
	check("decorations_use_catalog_record_contract",Objects.validate_records(built.props))
	check("input_span_remains_immutable",Canonical.digest(forest) == input_hash)
	var bare := Geometry.build([forest],catalog.definitions,false)
	check("disabling_dressing_keeps_visible_mass",bare.ok and bare.props.is_empty() and bare.volumes.is_empty() and bare.solid_prisms == built.solid_prisms and bare.faces == built.faces)
	var desert := span("desert","desert_ridge_v1")
	var dune := Geometry.build([desert],catalog.definitions)
	check("desert_has_four_grounded_props",dune.ok and dune.props.size() == 4 and dune.volumes.size() == 4 and dune.props.all(func(prop: Dictionary) -> bool: return prop.position.y == 10.0))
	check("desert_mass_matches_width_and_height",dune.ok and Prism.prepare(dune.solid_prisms[0]).bounds == AABB(Vector3(0,-4,-112),Vector3(400,24,112)))
	var ruin := Geometry.build([span("ruin","ruin_rubble_v1")],catalog.definitions)
	check("rich_ruin_uses_pillar_and_rock",ruin.ok and ruin.props.size() == 2 and ruin.props[0].definition_id == "broken_pillar" and ruin.props[1].definition_id == "moss_boulder")
	var moved := desert.duplicate(true); moved.a = Vector3(200,0,400); moved.b = Vector3(200,0,800); moved.outward = Vector3.RIGHT; moved["rotation_quarters"] = 1
	var rotated := Geometry.build([moved],catalog.definitions); var matched: bool = rotated.ok and rotated.solid_prisms.size() == dune.solid_prisms.size() and rotated.props.size() == dune.props.size()
	if matched:
		for k: int in dune.solid_prisms.size():
			if Canonical.encode(Prism.transformed(dune.solid_prisms[k],1,Vector3(200,0,400))) != Canonical.encode(rotated.solid_prisms[k]): matched = false
		for k: int in dune.props.size():
			if rotated.props[k].position != Kernel.rotate(dune.props[k].position,1)+Vector3(200,0,400) or rotated.props[k].body_volume != Kernel.transform_volume(dune.props[k].body_volume,1,Vector3(200,0,400)) or rotated.props[k].rotation_y != 90.0: matched = false
	check("mass_and_prop_transform_once",matched)
	var separate := desert.duplicate(true); separate.a += Vector3(0,0,-200); separate.b += Vector3(0,0,-200)
	var combined := Geometry.build([forest,separate],catalog.definitions,false)
	var reversed := Geometry.build([separate,forest],catalog.definitions,false)
	check("span_order_does_not_change_geometry",combined.ok and reversed.ok and Canonical.encode(combined) == Canonical.encode(reversed))
	var water := Geometry.build([span("stream","meadow_stream_v1")],catalog.definitions)
	check("stream_has_two_banks_and_visual_water",water.ok and water.solid_prisms.size() == 2 and water.water.size() == 1 and water.volumes.is_empty())
	check("water_has_no_support_or_collider",water.ok and not water.water[0].has("support_surface_id") and not water.water[0].has("volume") and water.props.is_empty())
	check("water_level_and_channel_width_oracle",water.ok and water.water[0].vertices == [Vector3(0,-12,-8),Vector3(400,-12,-8),Vector3(400,-12,-24),Vector3(0,-12,-24)])
	var source := Piece.empty("banks_world"); source.layers = [{"layer_id":"floor","name":"Piso","origin_xz":[0,0],"sample_spacing":400,"columns":2,"rows":2,"heights":[0,0,0,0],"material_masks":{},"locked":false,"protected_regions":[]}]
	var terrain := Terrain.compile(source); var manifest := Terrain.preview_manifest(terrain.package)
	manifest._data.stages[0].solid_prisms.append_array(water.solid_prisms)
	var far_cell := {"surface_id":"far_floor","vertices":[Vector3(0,0,-100),Vector3(400,0,-100),Vector3(400,0,-40),Vector3(0,0,-40)],"headroom":100.0}
	manifest._data.stages[0].surfaces.append(far_cell); manifest._data.stages[0].solid_prisms.append({"volume_id":"far_mass","support_surface_id":"far_floor","top":far_cell.vertices,"bottom_y":-4.0})
	var world := WorldGeometry.new()
	check("canonical_world_accepts_bank_geometry",world.configure(manifest,"terrain_preview").ok)
	check("bank_has_real_mass_below_margin",world.sweep(Vector3(200,-8,10),Vector3(200,-8,-40),{"radius":0.0,"height":0.0},world.geometry_revision).data.hit)
	check("ray_above_water_and_banks_clear",not world.sweep(Vector3(200,5,10),Vector3(200,5,-40),{"radius":0.0,"height":0.0},world.geometry_revision).data.hit)
	check("water_film_does_not_block_rays",not world.sweep(Vector3(200,-12,-10),Vector3(200,-12,-22),{"radius":0.0,"height":0.0},world.geometry_revision).data.hit)
	var support: String = terrain.package.part.surfaces[0].surface_id
	var from := ExpeditionWorldPoint.create("terrain_preview",support,Vector3(200,0,50)); var to := ExpeditionWorldPoint.create("terrain_preview","far_floor",Vector3(200,0,-70))
	var profile := {"radius":20.0,"height":32.0,"connector_kinds":["walk"]}
	check("water_destination_is_unsupported",not world.position_query(ExpeditionWorldPoint.create("terrain_preview",support,Vector3(200,-12,-16)),profile,world.geometry_revision).ok)
	check("body_cannot_cross_without_bridge",not world.path(from,to,profile,world.geometry_revision).ok)
	var attack := world.query_attack({"geometry_rule_id":"direct_volume","range":160.0,"source_offset":Vector3.UP*8,"target_offset":Vector3.UP*8},from,to,world.geometry_revision)
	check("canonical_attack_can_cross_channel",attack.ok and attack.data.hit and attack.data.los_ok)
	check("cancel_returns_no_partial_package",Geometry.build([forest],catalog.definitions,true,func() -> bool: return true).code == "cancelled")
	check("duplicate_span_id_rejected",not Geometry.build([forest,forest],catalog.definitions).ok)
	var invalid := forest.duplicate(true); invalid.outward = Vector3.RIGHT
	check("nonperpendicular_normal_rejected",not Geometry.build([invalid],catalog.definitions).ok)
	invalid = forest.duplicate(true); invalid.b = invalid.a
	check("zero_span_rejected",Geometry.build([invalid],catalog.definitions).code == "geometry_precision_limit")
	var excess: Array = []
	for k: int in 1025:
		var value := forest.duplicate(true); value.span_id = "over_%d"%k; excess.append(value)
	check("mass_budget_is_whole_failure",Geometry.build(excess,catalog.definitions,false).code == "border_limit")
	map_checks(source,catalog)
	port_checks()
	finish()

func port_checks() -> void:
	var source := PortFixture.map_source(); source.barrier_profile = "forest_rootbank_v1"
	var compiled := MapCompiler.compile(source)
	check("rich_border_refined_opening_compiles",compiled.ok)
	if not compiled.ok: print("BORDER_PORT_DIAGNOSTIC "+str(compiled)); return
	check("rich_border_receiver_reconstructs_twelve_intervals",compiled.package.realized_links[0].fragments.size() == 12 and MapCompiler.validate_package(compiled.package))
	var world := WorldGeometry.new(); world.configure(MapCompiler.manifest(compiled.package),"map_preview")
	var from := PortFixture.instance_at(world,"left",Vector2(25,35)); var to := PortFixture.instance_at(world,"right",Vector2(175,35))
	check("rich_border_preserves_full_offcenter_body_passage",world.ground_line_to(from,to,PortFixture.PROFILE,world.geometry_revision).ok)
	check("actor_crosses_rich_border_nm12_opening",PortFixture.walk(world,from,to,PortFixture.PROFILE))
	var reordered := source.duplicate(true); reordered.instances.reverse(); reordered.pieces.reverse()
	var repeated := MapCompiler.compile(reordered)
	check("rich_border_map_order_is_not_identity",repeated.ok and repeated.output_hash == compiled.output_hash)
	var recipe := source.duplicate(true); recipe.mode = "recipe"; recipe.instances[1].position_xyz = [700,0,900]
	var arranged := MapCompiler.compile(recipe)
	check("rich_border_recipe_realizes_same_geometry",arranged.ok and arranged.package.border_geometry == compiled.package.border_geometry)

static func map_source(piece: Dictionary, profile: String) -> Dictionary:
	var data := Map.empty("border_map"); var hash_value := Schema.semantic_hash(piece)
	data.pieces = [{"piece_hash":hash_value,"source":piece.duplicate(true)}]
	data.instances = [{"instance_id":"land","piece_hash":hash_value,"position_xyz":[0,0,0],"rotation_quarters":0}]
	data.barrier_profile = profile
	return data

static func rehash(value: Dictionary) -> Dictionary:
	value.erase("package_hash"); value["package_hash"] = Canonical.digest(value); return value

func map_checks(piece: Dictionary, catalog: Dictionary) -> void:
	var legacy := MapCompiler.compile(map_source(piece,Operations.LEGACY))
	check("legacy_geometry_and_nine_dependencies_unchanged",legacy.ok and legacy.package.barriers.size() == 4 and legacy.package.dependencies.size() == 9 and legacy.package.border_geometry.solid_prisms.is_empty() and MapCompiler.validate_package(legacy.package))
	var packages := {}
	for id: String in Catalog.IDS:
		var source := map_source(piece,id); var before := Map.hash_source(source); var built := MapCompiler.compile(source)
		check(id+"_map_compiles",built.ok)
		if not built.ok: print("BORDER_MAP_DIAGNOSTIC "+str(built)); continue
		packages[id] = built.package
		check(id+"_v5_receiver_reconstructs_mass",built.package.format_version == 5 and MapCompiler.validate_package(built.package))
		check(id+"_keeps_only_authored_support",built.package.manifest.stages[0].surfaces.size() == 1 and built.package.border_geometry.solid_prisms.all(func(mass: Dictionary) -> bool: return mass.support_surface_id == ""))
		check(id+"_source_immutable",Map.hash_source(source) == before)
	if not packages.has("forest_rootbank_v1"): return
	var forest: Dictionary = packages.forest_rootbank_v1; var masses: Array = forest.border_geometry.solid_prisms
	check("square_has_four_welded_caps",masses.size() == 4 and forest.border_geometry.faces.size() == 12)
	var corner := false
	for mass: Dictionary in masses:
		if not Prism.sweep(Vector3(-60,30,-60),Vector3(-60,-3,-60),Prism.prepare(mass),0,0).is_empty(): corner = true
	check("convex_corner_has_real_mass_at_minus60",corner)
	var manifest := MapCompiler.manifest(forest); var world := WorldGeometry.new(); world.configure(manifest,"map_preview")
	check("world_ray_hits_exact_miter_seam",world.sweep(Vector3(-60,30,-60),Vector3(-60,-3,-60),{"radius":0.0,"height":0.0},world.geometry_revision).data.hit)
	var left := Prism.prepare({"volume_id":"left","support_surface_id":"","top":[Vector3(0,20,0),Vector3(50,20,0),Vector3(50,20,100),Vector3(0,20,100)],"bottom_y":-4.0})
	var right := Prism.prepare({"volume_id":"right","support_surface_id":"","top":[Vector3(50,20,0),Vector3(100,20,0),Vector3(100,20,100),Vector3(50,20,100)],"bottom_y":-4.0})
	check("axis_aligned_ray_seam_is_closed",not Prism.sweep(Vector3(50,30,50),Vector3(50,0,50),left,0,0).is_empty() and not Prism.sweep(Vector3(50,30,50),Vector3(50,0,50),right,0,0).is_empty())
	check("ray_tangent_to_cap_stays_clear",Prism.sweep(Vector3(10,20,10),Vector3(40,20,90),left,0,0).is_empty())
	check("real_gap_outside_side_stays_clear",Prism.sweep(Vector3(50.01,30,50),Vector3(50.01,0,50),left,0,0).is_empty())
	var changed := forest.duplicate(true); changed.border_geometry.solid_prisms[0].bottom_y -= 1
	check("receiver_rejects_border_base_with_new_hash",not MapCompiler.validate_package(rehash(changed)))
	changed = forest.duplicate(true); changed.manifest.stages[0].solid_prisms[-1].bottom_y -= 1
	check("receiver_rejects_effective_border_mass_with_new_hash",not MapCompiler.validate_package(rehash(changed)))
	changed = forest.duplicate(true); changed.border_geometry.faces[0].material_weights[0] = [1.0,0.0,0.0,0.0]
	check("receiver_rejects_border_paint_with_new_hash",not MapCompiler.validate_package(rehash(changed)))
	changed = forest.duplicate(true); changed.border_geometry.props[0].position.y += 1
	check("receiver_rejects_floating_prop_with_new_hash",not MapCompiler.validate_package(rehash(changed)))
	if packages.has("meadow_stream_v1"):
		changed = packages.meadow_stream_v1.duplicate(true); changed.border_geometry.water[0].vertices[0].y += 1
		check("receiver_rejects_water_height_with_new_hash",not MapCompiler.validate_package(rehash(changed)))
	var settings := Operations.empty(); var source := map_source(piece,Operations.LEGACY)
	var applied := Operations.apply(source,{"operation":"set_instance_profile","instance_id":"land","profile_id":"desert_ridge_v1"})
	check("profile_operation_is_reviewable_and_source_preserved",applied.ok and applied.diff.before == null and not source.has("borders") and Map.validate(applied.data).ok)
	var session := Session.new(); session.replace(source); session.apply(applied.data); session.undo()
	check("profile_undo_restores_exact_legacy_source",session.data == source)
	session.redo()
	check("profile_redo_restores_chosen_style",session.data == applied.data)
	var bare := Operations.apply(applied.data,{"operation":"set_decorations","enabled":false}); var built := MapCompiler.compile(bare.data)
	check("map_decoration_toggle_keeps_mass",built.ok and built.package.border_geometry.props.is_empty() and built.package.border_geometry.solid_prisms == packages.desert_ridge_v1.border_geometry.solid_prisms)
	settings.instances = [{"instance_id":"absent","profile_id":"forest_rootbank_v1"}]
	check("unknown_instance_reference_rejected",not Operations.validate(settings,source.instances).ok)
	settings = Operations.empty(); settings["script"] = "res://untrusted.gd"
	check("border_source_schema_is_closed",not Operations.validate(settings,source.instances).ok)
	var a := {"span_id":"a","instance_id":"a","closure":"profile","a":Vector3(0,0,0),"b":Vector3(400,0,0),"outward":Vector3.FORWARD,"openings":[]}
	var b := a.duplicate(true); b.span_id = "b"; b.instance_id = "b"; b.a = Vector3(300,0,0); b.b = Vector3(100,0,0); b.outward = Vector3.BACK
	var instances := [{"instance_id":"a","rotation_quarters":0},{"instance_id":"b","rotation_quarters":2}]
	settings = Operations.empty()
	var arranged := Spans.build([a,b],{},settings,"forest_rootbank_v1",instances)
	check("collinear_overlap_split_at_original_endpoints",arranged.ok and arranged.spans.size() == 3 and arranged.spans.filter(func(value: Dictionary) -> bool: return value.owners.size() == 2).size() == 1)
	check("owner_and_geometry_independent_of_boundary_order",Canonical.encode(arranged) == Canonical.encode(Spans.build([b,a],{},settings,"forest_rootbank_v1",instances)))
	settings.instances = [{"instance_id":"b","profile_id":"desert_ridge_v1"}]
	check("different_profiles_require_explicit_transition",Spans.build([a,b],{},settings,"forest_rootbank_v1",instances).get("code") == "transition_required")
	settings.transitions = [{"a_instance":"b","b_instance":"a","profile_id":"transition_terrace_v1"}]
	arranged = Spans.build([a,b],{},settings,"forest_rootbank_v1",instances)
	check("explicit_transition_has_one_realized_owner",arranged.ok and arranged.spans.filter(func(value: Dictionary) -> bool: return value.profile_id == "transition_terrace_v1").size() == 1)
	a.openings = ["door"]
	arranged = Spans.build([a],{"door":{"position":Vector3(200,0,0),"width":80.0}},Operations.empty(),"forest_rootbank_v1",instances)
	check("opening80_subtracted_before_extrusion",arranged.ok and arranged.spans.size() == 2 and arranged.spans.any(func(value: Dictionary) -> bool: return value.b == Vector3(160,0,0)) and arranged.spans.any(func(value: Dictionary) -> bool: return value.a == Vector3(240,0,0)))
	var stream := Geometry.build([span("stream","meadow_stream_v1")],catalog.definitions)
	var cell := {"surface_id":"cover","headroom":100.0,"vertices":[Vector3(100,0,-28),Vector3(300,0,-28),Vector3(300,0,-4),Vector3(100,0,-4)]}
	var stage := {"surfaces":[cell],"solid_prisms":[{"volume_id":"cover_mass","support_surface_id":"cover","top":cell.vertices,"bottom_y":-4.0}]}
	check("ordinary_floor_cannot_cover_channel",not MapCompiler._channel_space_clear(stream,[span("stream","meadow_stream_v1")],catalog.definitions,stage))
	stage.solid_prisms[0].erase("bottom_y"); stage.solid_prisms[0]["thickness_y"] = 6.0
	check("explicit_bridge_with_base_above_water_is_allowed",MapCompiler._channel_space_clear(stream,[span("stream","meadow_stream_v1")],catalog.definitions,stage))
	stage.solid_prisms[0].thickness_y = 14.0
	check("bridge_base_intersecting_water_rejected",not MapCompiler._channel_space_clear(stream,[span("stream","meadow_stream_v1")],catalog.definitions,stage))
	var spine_a := span("spine_a","forest_rootbank_v1",200); spine_a.a = Vector3(0,0,-200); spine_a.b = Vector3.ZERO; spine_a.outward = Vector3.RIGHT
	var spine_b := spine_a.duplicate(true); spine_b.span_id = "spine_b"; spine_b.a = Vector3.ZERO; spine_b.b = Vector3(0,0,200)
	var branch := span("branch","forest_rootbank_v1",200)
	var junction := Geometry.build([spine_a,spine_b,branch],catalog.definitions,false)
	check("t_junction_realizes_without_overlapping_caps",junction.ok)
	if junction.ok:
		var footprint := 0.0; var disjoint := true
		for i: int in junction.solid_prisms.size():
			var vertices: Array = junction.solid_prisms[i].top; var flat: Array = []
			for p: Vector3 in vertices: flat.append(Vector3(p.x,0,p.z))
			for k: int in range(1,flat.size()-1): footprint += (Vector3(flat[k])-Vector3(flat[0])).cross(Vector3(flat[k+1])-Vector3(flat[0])).length()*0.5
			for j: int in range(i+1,junction.solid_prisms.size()):
				var other_flat: Array = []
				for p: Vector3 in junction.solid_prisms[j].top: other_flat.append(Vector3(p.x,0,p.z))
				if Kernel.cells_overlap({"vertices":flat},{"vertices":other_flat}): disjoint = false
		check("t_junction_cap_area41600_oracle",absf(footprint-41600.0) < 0.01)
		check("t_junction_one_cap_per_projected_interior",disjoint)
		check("t_junction_order_does_not_change_union",Canonical.encode(junction) == Canonical.encode(Geometry.build([branch,spine_b,spine_a],catalog.definitions,false)))
		var highest := -INF
		for mass: Dictionary in junction.solid_prisms:
			if Kernel.contains({"vertices":mass.top,"headroom":1.0},Kernel.support_y({"vertices":mass.top,"headroom":1.0},Vector3(20,0,-40))): highest = maxf(highest,Kernel.support_y({"vertices":mass.top,"headroom":1.0},Vector3(20,0,-40)).y)
		check("t_junction_keeps_higher_real_cap18",absf(highest-18.0) < 0.0001)
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("F9_BORDER_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
