extends SceneTree
const Topology = preload("res://scripts/map_authoring/compiler/terrain_topology.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_compiler.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Ops = preload("res://scripts/map_authoring/objects/object_operations.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_CLIFF_CHECK "+id+" "+str(ok))
static func face(id: String, x0: float, x1: float, y0: float = 40.0, y1: float = 40.0) -> Dictionary:
	var vertices: Array = [Vector3(x0,y0,0),Vector3(x1,y1,0),Vector3(x1,y1,100),Vector3(x0,y0,100)]
	return {"face_id":id,"source_id":id,"vertices":vertices,"headroom":100.0,"walkable":Topology.is_walkable(vertices),"special":false,"bottom_y":-4.0}
static func side_area(sides: Array) -> float:
	var area := 0.0
	for side: Dictionary in sides:
		var v: Array = side.vertices
		area += (Vector3(v[1])-Vector3(v[0])).cross(Vector3(v[2])-Vector3(v[0])).length()*0.5
		area += (Vector3(v[2])-Vector3(v[0])).cross(Vector3(v[3])-Vector3(v[0])).length()*0.5
	return area
static func layer(id: String, x: float, spacing: float, heights: Array) -> Dictionary:
	return {"layer_id":id,"name":id,"origin_xz":[x,0],"sample_spacing":spacing,"columns":2,"rows":2,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]}
static func source() -> Dictionary:
	var data := Piece.empty("mixed_relief")
	data.layers = [layer("floor",0,100,[0,0,0,0]),layer("cliff",100,100,[0,400,0,400])]
	return data
static func rehash(package: Dictionary) -> Dictionary:
	package.erase("package_hash"); package["package_hash"] = Canonical.digest(package); return package
func run() -> void:
	var a := face("a",0,100); var b := face("b",100,200)
	var before := Canonical.digest([a,b]); var built := Topology.build([a,b])
	check("flat_pair_valid",built.ok)
	check("flat_pair_has_one_join",built.ok and built.adjacency.size() == 1 and built.connectors.size() == 2)
	check("equal_bases_have_only_six_sides",built.ok and built.exposed_sides.size() == 6)
	check("flat_pair_side_area_26400",built.ok and absf(side_area(built.exposed_sides)-26400) < 0.001)
	check("all_flat_external_boundaries_use_profile",built.ok and built.boundaries.size() == 6 and built.boundaries.all(func(edge: Dictionary) -> bool: return edge.closure == "profile"))
	check("topology_does_not_mutate_faces",before == Canonical.digest([a,b]))
	check("face_order_is_not_identity",Canonical.encode(built) == Canonical.encode(Topology.build([b,a])))
	b.erase("bottom_y"); b["thickness_y"] = 4.0; b.special = true
	built = Topology.build([a,b])
	check("ground_bridge_has_seven_sides",built.ok and built.exposed_sides.size() == 7)
	check("ground_bridge_area_18400",built.ok and absf(side_area(built.exposed_sides)-18400) < 0.001)
	var internal: Array = built.exposed_sides.filter(func(side: Dictionary) -> bool: return side.vertices.all(func(p: Vector3) -> bool: return p.x == 100))
	check("bridge_reveals_ground_lower_strip",internal.size() == 1 and internal[0].face_id == "a" and absf(side_area(internal)-4000) < 0.001)
	check("bridge_lower_strip_exact_bounds",internal.size() == 1 and internal[0].vertices.all(func(p: Vector3) -> bool: return p.y == -4 or p.y == 36))
	a = face("a",0,100,0,0); b = face("b",100,110,0,40); built = Topology.build([a,b])
	check("steep_face_is_nonwalking",not b.walkable and Topology.valid_face(b))
	check("mixed_pair_has_no_virtual_join",built.ok and built.connectors.is_empty() and built.adjacency.is_empty())
	check("mixed_external_skin_area_6080",built.ok and absf(side_area(built.exposed_sides)-6080) < 0.001)
	var contact: Array = built.boundaries.filter(func(edge: Dictionary) -> bool: return edge.adjacent_face_id == "b")
	check("walking_cliff_contact_closed_by_terrain",contact.size() == 1 and contact[0].closure == "terrain" and contact[0].surface_id == "a")
	check("cliff_external_boundary_has_no_support",built.boundaries.any(func(edge: Dictionary) -> bool: return edge.face_id == "b" and edge.surface_id == "" and edge.closure == "terrain"))
	# Independently chosen bases cross at z20: triangle70 plus triangle1120.
	a = face("a",0,100,5,5); b = face("b",100,200,5,5)
	for candidate: Dictionary in [a,b]:
		candidate.vertices[2].y = 40; candidate.vertices[3].y = 40
	a.erase("bottom_y"); a["thickness_y"] = 8.0; b.bottom_y = 4.0
	built = Topology.build([a,b])
	internal = built.exposed_sides.filter(func(side: Dictionary) -> bool: return side.vertices.all(func(p: Vector3) -> bool: return p.x == 100))
	check("crossed_bases_split_into_two_skins",built.ok and internal.size() == 2)
	check("crossed_bases_area_1190",absf(side_area(internal)-1190) < 0.005)
	check("crossed_bases_switch_owner",internal.size() == 2 and internal[0].face_id != internal[1].face_id)
	check("crossing_point_z20_retained",internal.size() == 2 and internal.all(func(side: Dictionary) -> bool: return side.vertices.any(func(p: Vector3) -> bool: return absf(p.z-20.0) < 0.00001 and absf(p.y-4.0) < 0.00001)))
	var invalid := a.duplicate(true); invalid.walkable = false
	check("false_walkable_flag_rejected",not Topology.build([invalid]).ok)
	invalid = a.duplicate(true); invalid["script"] = "res://evil.gd"
	check("closed_face_schema",not Topology.build([invalid]).ok)
	check("duplicate_face_id_rejected",not Topology.build([a,a]).ok)
	check("cancellation_returns_no_partial_geometry",Topology.build([a,b],func() -> bool: return true).get("code") == "cancelled")
	var over: Array = []
	over.resize(1025); over.fill(a)
	check("face_budget_precedes_support_filter",Topology.build(over).get("code") == "terrain_face_limit")
	var data := source(); var initial := Schema.semantic_hash(data); var compiled := Terrain.compile(data)
	check("compiler_accepts_mixed_piece",compiled.ok)
	if not compiled.ok: print(compiled); finish(); return
	var package: Dictionary = compiled.package
	check("terrain_v5_receives_own_package",package.format_version == 5 and Terrain.validate_package(package))
	check("all_faces_keep_mass_and_visuals",package.visuals.size() == 2 and package.part.solid_prisms.size() == 2 and package.part.surfaces.size() == 1)
	check("cliff_mass_has_empty_support_binding",package.part.solid_prisms.any(func(mass: Dictionary) -> bool: return mass.support_surface_id == ""))
	check("source_unchanged_by_compile",Schema.semantic_hash(data) == initial)
	var placed := Ops.propose(data,"place",{"placement_id":"safe_shrub","definition_id":"woodland_shrub","surface_id":"floor","position_xz":[50,50]})
	check("object_support_uses_identity_after_cliff_visual",placed.ok and Terrain.compile(placed.data).ok)
	var on_cliff := Ops.propose(data,"place",{"placement_id":"unsafe_shrub","definition_id":"woodland_shrub","surface_id":"cliff","position_xz":[150,50]})
	check("object_cannot_settle_on_nonwalking_cliff",not on_cliff.ok and on_cliff.code == "object_support_missing")
	var side: Dictionary = package.exposed_sides[0]
	var arrays := Materials.face_arrays(side.vertices,[],side.outward,1,Vector3(300,20,50))
	var world_point := Vector3(arrays[Mesh.ARRAY_CUSTOM0][0],arrays[Mesh.ARRAY_CUSTOM0][1],arrays[Mesh.ARRAY_CUSTOM0][2])
	check("side_renderer_transforms_world_position_once",world_point == Vector3(-side.vertices[0].z+300,side.vertices[0].y+20,side.vertices[0].x+50))
	var normal := Vector3(arrays[Mesh.ARRAY_CUSTOM1][0],arrays[Mesh.ARRAY_CUSTOM1][1],arrays[Mesh.ARRAY_CUSTOM1][2])
	check("side_renderer_rotates_physical_normal",normal == Vector3(-side.outward.z,side.outward.y,side.outward.x))
	check("side_renderer_is_stone_with_height_data",arrays[Mesh.ARRAY_COLOR][0] == Color(0,0,0,1) and arrays[Mesh.ARRAY_CUSTOM0].size() == side.vertices.size()*4)
	var world := WorldGeometry.new(); var configured := world.configure(Terrain.preview_manifest(package),"terrain_preview")
	check("canonical_world_accepts_mixed_mass",configured.ok)
	check("ray_hits_real_cliff_cap",world.sweep(Vector3(150,300,50),Vector3(150,100,50),{"radius":0.0,"height":0.0},world.geometry_revision).data.hit)
	check("ray_above_cliff_is_clear",not world.sweep(Vector3(110,500,50),Vector3(190,500,50),{"radius":0.0,"height":0.0},world.geometry_revision).data.hit)
	check("body_cannot_enter_cliff_mass",world.sweep(Vector3(95,0,50),Vector3(120,0,50),Terrain.PROFILE,world.geometry_revision).data.hit)
	var visible: Array[String] = [package.part.surfaces[0].surface_id]
	check("cliff_never_resolves_as_walking_support",not world.resolve_surface(Vector3(150,600,50),Vector3.DOWN,visible,world.geometry_revision).ok)
	var malformed := package.duplicate(true); malformed.visuals[0].walkable = not malformed.visuals[0].walkable
	check("rehash_does_not_legitimize_walkable_flag",not Terrain.validate_package(rehash(malformed)))
	malformed = package.duplicate(true); malformed.part.solid_prisms[0].bottom_y -= 10
	check("rehash_does_not_legitimize_wrong_mass",not Terrain.validate_package(rehash(malformed)))
	malformed = package.duplicate(true); malformed.exposed_sides[0].vertices[0].y += 1
	check("rehash_does_not_legitimize_wrong_skin",not Terrain.validate_package(rehash(malformed)))
	malformed = package.duplicate(true); malformed.boundaries[0].closure = "profile" if malformed.boundaries[0].closure == "terrain" else "terrain"
	check("rehash_does_not_legitimize_wrong_closure",not Terrain.validate_package(rehash(malformed)))
	malformed = package.duplicate(true); malformed.render_layers[0].heights[0] += 10
	check("terrain_rehash_cannot_forge_render_cap",not Terrain.validate_package(rehash(malformed)))
	malformed = package.duplicate(true); malformed.render_layers[0].material_masks["sand"] = [1.0,1.0,1.0,1.0]
	check("terrain_rehash_cannot_forge_render_paint",not Terrain.validate_package(rehash(malformed)))
	var cliff_only := data.duplicate(true); cliff_only.layers.remove_at(0)
	check("all_steep_piece_has_explicit_diagnostic",Terrain.compile(cliff_only).code == "slope_too_steep")
	var isolated := data.duplicate(true); isolated.layers.append(layer("plateau",200,100,[400,400,400,400]))
	check("isolated_flat_plateau_is_not_hidden",Terrain.compile(isolated).code == "route_unreachable")
	var illegal := data.duplicate(true)
	illegal.connectors = [{"connector_id":"cut_cliff","surface_id":"floor","position_xyz":[100,0,50],"normal_xyz":[1,0,0],"kind":"walk","width":80,"headroom":100,"tags":["ruin"],"direction":"both"}]
	check("authored_port_cannot_cut_real_cliff",Terrain.compile(illegal).code == "connector_invalid")
	var reordered := data.duplicate(true); reordered.layers.reverse()
	check("source_layer_order_preserves_package",Terrain.compile(reordered).output_hash == compiled.output_hash)
	var map := Map.empty("cliff_rotation"); map.pieces = [{"piece_hash":initial,"source":data}]; map.instances = [{"instance_id":"mixed","piece_hash":initial,"rotation_quarters":1,"position_xyz":[300,0,0]}]
	var composed := MapCompiler.compile(map)
	check("rotated_mixed_map_compiles",composed.ok)
	if not composed.ok: print(composed); finish(); return
	check("map_v4_receives_own_package",composed.package.format_version == 4 and MapCompiler.validate_package(composed.package))
	check("rotated_cliff_mass_stays_unbound",composed.package.manifest.stages[0].solid_prisms.any(func(mass: Dictionary) -> bool: return mass.support_surface_id == ""))
	check("cliff_receives_no_biome_wall",composed.package.barriers.size() == 3)
	check("map_keeps_exposed_geometry",composed.package.render_instances[0].exposed_sides == package.exposed_sides)
	malformed = composed.package.duplicate(true); malformed.render_instances[0].exposed_sides[0].vertices[0].y += 1
	check("map_rehash_cannot_forge_side",not MapCompiler.validate_package(rehash(malformed)))
	malformed = composed.package.duplicate(true); malformed.manifest.stages[0].solid_prisms[0].bottom_y -= 1
	check("map_rehash_cannot_forge_transformed_mass",not MapCompiler.validate_package(rehash(malformed)))
	malformed = composed.package.duplicate(true); malformed.render_instances[0].layers[0].heights[0] += 10
	check("map_rehash_cannot_forge_render_cap",not MapCompiler.validate_package(rehash(malformed)))
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_CLIFF_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
