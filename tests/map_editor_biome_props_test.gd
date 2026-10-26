extends SceneTree
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Ops = preload("res://scripts/map_authoring/objects/object_operations.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Reader = preload("res://scripts/map_authoring/io/strict_json.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const IDS := ["desert_cactus","broken_pillar","sandstone_boulder"]
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_BIOME_PROPS_CHECK "+id+" "+str(ok))
static func source(material: String = "sand") -> Dictionary:
	var result := Piece.empty("biome_props")
	result.layers = [{"layer_id":"floor","name":"Piso","origin_xz":[0,0],"sample_spacing":800,"columns":2,"rows":2,"heights":[0,0,0,0],"material_masks":{"grass":[0,0,0,0]},"locked":false,"protected_regions":[]}]
	result.layers[0].material_masks[material] = [1.0,1.0,1.0,1.0]
	return result
func run() -> void:
	var catalog := Catalog.load_catalog()
	check("six_catalog_definitions",catalog.ok and catalog.definitions.size() == 6)
	if not catalog.ok: print(catalog); finish(); return
	# Decode the independent original bytes without Godot JSON's integer loss.
	# Canonical deliberately distinguishes i226 from f226; keep that invariant.
	var snapshot := Reader.new().decode(FileAccess.get_file_as_bytes("res://tests/fixtures/map_authoring/f9_original_props.json"))
	var golden: Variant = snapshot.get("value")
	var unchanged: bool = snapshot.ok and golden is Dictionary and golden.definitions.size() == 3
	if unchanged:
		for original: Dictionary in golden.definitions:
			if not catalog.definitions.has(original.definition_id) or Canonical.encode(catalog.definitions[original.definition_id]) != Canonical.encode(original): unchanged = false
	check("existing_definitions_immutable",unchanged)
	var data := source(); var initial := Schema.semantic_hash(data)
	for k: int in IDS.size():
		var definition: Dictionary = catalog.definitions[IDS[k]]
		check(IDS[k]+"_provenance_and_actual_hash",definition.origin.license == "project_generated_output" and definition.origin.tool == "image_gen built-in" and FileAccess.get_sha256(definition.sprite_path) == definition.sprite_sha256)
		var texture := load(definition.sprite_path) as Texture2D
		var image := texture.get_image()
		var corners := [Vector2i.ZERO,Vector2i(image.get_width()-1,0),Vector2i(0,image.get_height()-1),image.get_size()-Vector2i.ONE]
		check(IDS[k]+"_transparent_corners",corners.all(func(pixel: Vector2i) -> bool: return image.get_pixelv(pixel).a == 0.0))
		check(IDS[k]+"_ground_pivot_inside_asset",image.get_pixel(int(definition.pivot_uv[0]*image.get_width()),int(definition.pivot_uv[1]*image.get_height())).a > 0.9)
		var placed := Ops.propose(data,"place",{"placement_id":IDS[k],"definition_id":IDS[k],"surface_id":"floor","position_xz":[180+k*220,400]})
		check(IDS[k]+"_places_on_real_support",placed.ok)
		if not placed.ok: print(placed); finish(); return
		data = placed.data
	check("placement_does_not_mutate_empty_source",Schema.semantic_hash(source()) == initial)
	var compiled := Terrain.compile(data)
	check("three_new_props_compile",compiled.ok and compiled.package.objects.size() == 3 and compiled.package.part.solid_volumes.size() == 3)
	if not compiled.ok: print(compiled); finish(); return
	check("new_props_package_receives",Terrain.validate_package(compiled.package))
	var paths := {}
	for dependency: Dictionary in compiled.package.dependencies: paths[dependency.path] = dependency.sha256
	var all_assets := paths.size() == 16
	for id: String in IDS:
		var path: String = catalog.definitions[id].sprite_path
		all_assets = all_assets and paths.has(path) and paths.has(path+".import") and paths[path] == FileAccess.get_sha256(path)
	check("complete_selected_asset_transport",all_assets)
	check("catalog_dependency_tracks_revision",catalog.revision == 2 and compiled.package.dependencies.any(func(item: Dictionary) -> bool: return item.path == Catalog.PATH and item.revision == 2))
	var decoded := Schema.read(JSON.stringify(data,"",true,true).to_utf8_buffer())
	check("source_roundtrip_keeps_new_definitions",decoded.ok and Terrain.compile(decoded.data).output_hash == compiled.output_hash)
	var world := WorldGeometry.new(); var manifest := Terrain.preview_manifest(compiled.package)
	check("world_accepts_three_real_envelopes",world.configure(manifest,"terrain_preview").ok)
	var support: String = compiled.package.part.surfaces[0].surface_id
	var profile := {"radius":20.0,"height":32.0,"connector_kinds":["walk"]}
	for k: int in IDS.size():
		var x := 180.0+k*220.0
		var from := ExpeditionWorldPoint.create("terrain_preview",support,Vector3(x-90,0,400))
		var to := ExpeditionWorldPoint.create("terrain_preview",support,Vector3(x+90,0,400))
		check(IDS[k]+"_blocks_body_at_declared_mass",world.sweep(from.position,to.position,profile,world.geometry_revision).data.hit)
		check(IDS[k]+"_blocks_ray_through_declared_mass",not world.query_attack({"geometry_rule_id":"direct_volume","range":250.0,"source_offset":Vector3.UP*8,"target_offset":Vector3.UP*8},from,to,world.geometry_revision).data.hit)
	var route_start := ExpeditionWorldPoint.create("terrain_preview",support,Vector3(60,0,400)); var route_end := ExpeditionWorldPoint.create("terrain_preview",support,Vector3(740,0,400))
	var motion := WorldActorMotion.new(); var walking: bool = motion.configure(world,route_start,profile,"biome_props_actor").ok
	if walking: walking = motion.plan(route_end,world.geometry_revision).ok
	var steps := 2000
	while walking and motion.has_route() and steps > 0:
		steps -= 1; walking = motion.advance(2.0).ok
	check("real_actor_detours_three_props",walking and steps > 0 and motion.point().position.distance_to(route_end.position) < 0.001)
	motion.release()
	var map := Map.empty("biome_props_rotated"); var key := Schema.semantic_hash(data)
	map.pieces = [{"piece_hash":key,"source":data}]; map.instances = [{"instance_id":"garden","piece_hash":key,"rotation_quarters":1,"position_xyz":[800,0,0]}]
	var composed := MapCompiler.compile(map)
	check("new_props_survive_rotated_composition",composed.ok and MapCompiler.validate_package(composed.package) and composed.package.render_instances[0].objects.size() == 3)
	var unchanged_defs := true
	for id: String in IDS:
		var copy: Dictionary = Catalog.definition(id,catalog).definition; copy.name = "Alteração local"
		if Catalog.definition(id,catalog).definition.name == "Alteração local": unchanged_defs = false
	check("new_definitions_are_copies",unchanged_defs)
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("F9_BIOME_PROPS_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
