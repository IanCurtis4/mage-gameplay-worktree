extends SceneTree
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Ops = preload("res://scripts/map_authoring/objects/object_operations.gd")
const Metadata = preload("res://scripts/map_authoring/objects/object_schema.gd")
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const Candidate = preload("res://tests/map_editor_candidate_test.gd")
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
var checks: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_OBJECT_CHECK "+id+" "+str(ok))

func run() -> void:
	var source := fixture(); var hash_before := Schema.semantic_hash(source)
	var catalog := Catalog.load_catalog()
	check("catalog_loads",catalog.ok)
	if not catalog.ok: print(catalog); finish(); return
	var definition := Catalog.definition("oak_tree",catalog)
	check("catalog_origin_and_rights",definition.ok and definition.definition.origin.license == "project_generated_output" and definition.definition.origin.tool == "image_gen built-in")
	definition.definition.name = "Alterado em cópia"
	check("catalog_immutable",Catalog.definition("oak_tree",catalog).definition.name == "Carvalho")
	check("definition_missing",Catalog.definition("absent",catalog).code == "object_definition_missing")
	var placed := Ops.propose(source,"place",{"placement_id":"shrub","definition_id":"woodland_shrub","surface_id":"floor","position_xz":[203,201],"snap":10})
	check("place_and_snap",placed.ok and Vector3(placed.data.placements[0].position_xyz[0],placed.data.placements[0].position_xyz[1],placed.data.placements[0].position_xyz[2]) == Vector3(200,0,200))
	check("source_not_mutated",Schema.semantic_hash(source) == hash_before and source.placements.is_empty())
	if not placed.ok: print(placed); finish(); return
	check("invalid_selection_type_rejected",Ops.propose(placed.data,"move",{"ids":"shrub","position_xz":[220,220]}).code == "object_selection_invalid")
	check("duplicate_identity_rejected",not Ops.propose(placed.data,"place",{"placement_id":"shrub","definition_id":"woodland_shrub","surface_id":"floor","position_xz":[220,220]}).ok)
	var rock := Ops.propose(placed.data,"place",{"placement_id":"rock","definition_id":"moss_boulder","surface_id":"floor","position_xz":[400,400]})
	check("place_solid",rock.ok)
	if not rock.ok: print(rock); finish(); return
	var tree := Ops.propose(rock.data,"place",{"placement_id":"tree","definition_id":"oak_tree","surface_id":"floor","position_xz":[600,600]})
	check("place_tree",tree.ok)
	if not tree.ok: print(tree); finish(); return
	source = tree.data
	var compiled := Terrain.compile(source)
	check("compile_objects",compiled.ok and compiled.package.objects.size() == 3)
	if not compiled.ok: print(compiled); finish(); return
	check("only_two_body_envelopes",compiled.package.part.solid_volumes.size() == 2)
	check("catalog_and_sprite_dependencies",expected_asset_set(compiled.package.dependencies))
	check("package_integrity",Terrain.validate_package(compiled.package))
	var legacy_keys: Dictionary = compiled.package.duplicate(true)
	var old_hash: String = legacy_keys.package_hash; legacy_keys.erase("package_hash"); legacy_keys[&"package_hash"] = old_hash
	check("legacy_textual_package_key_accepted",Terrain.validate_package(legacy_keys))
	var bad_record: Dictionary = compiled.package.duplicate(true)
	bad_record.objects[0].definition.sprite_path = "res://scripts/main.gd"; bad_record.erase("package_hash")
	bad_record.package_hash = Terrain.Canonical.digest(bad_record)
	check("executable_sprite_path_rejected",not Terrain.validate_package(bad_record))
	var bad_dependency: Dictionary = compiled.package.duplicate(true)
	bad_dependency.dependencies[-1].path = 42; bad_dependency.erase("package_hash"); bad_dependency.package_hash = Terrain.Canonical.digest(bad_dependency)
	check("dependency_type_rejected_without_script_error",not Terrain.validate_package(bad_dependency))
	var decoded := Schema.read(JSON.stringify(source,"",true,true).to_utf8_buffer())
	check("source_roundtrip",decoded.ok and decoded.output_hash == Schema.semantic_hash(source))
	check("roundtrip_compiled_identity",Terrain.compile(decoded.data).output_hash == compiled.output_hash)
	var reordered := source.duplicate(true); reordered.placements.reverse(); reordered.dependencies.reverse()
	check("order_independent",Terrain.compile(reordered).output_hash == compiled.output_hash)
	var world := WorldGeometry.new(); world.configure(Terrain.preview_manifest(compiled.package),"terrain_preview")
	var surface: String = compiled.package.part.surfaces[0].surface_id
	var start := ExpeditionWorldPoint.create("terrain_preview",surface,Vector3(200,0,400))
	var goal := ExpeditionWorldPoint.create("terrain_preview",surface,Vector3(600,0,400))
	var profile: Dictionary = compiled.package.profile
	check("rock_has_body_collision",not world.position_query(ExpeditionWorldPoint.create("terrain_preview",surface,Vector3(400,0,400)),profile,world.geometry_revision).ok)
	check("shrub_is_decoration",world.position_query(ExpeditionWorldPoint.create("terrain_preview",surface,Vector3(200,0,200)),profile,world.geometry_revision).ok)
	check("rock_blocks_attack",not world.query_attack({"geometry_rule_id":"direct_volume","range":500},start,goal,world.geometry_revision).data.hit)
	var route := world.path(start,goal,profile,world.geometry_revision)
	check("route_detours_around_rock",route.ok and route.data.cost > 400)
	var moved := Ops.propose(source,"move",{"ids":["rock"],"position_xz":[450,400]})
	check("move_preserves_identity",moved.ok and moved.data.placements[1].placement_id == source.placements[1].placement_id)
	var rotated := Ops.propose(source,"rotate",{"ids":["rock"],"degrees":90})
	check("rotation_preserved",rotated.ok and Ops._find(rotated.data.placements,"placement_id","rock").rotation_y == 90)
	check("unsupported_rotation_rejected",not Ops.propose(source,"rotate",{"ids":["rock"],"degrees":45}).ok)
	check("outside_floor_rejected",not Ops.propose(source,"move",{"ids":["rock"],"position_xz":[900,400]}).ok)
	check("overlapping_solids_rejected",not Ops.propose(source,"move",{"ids":["rock"],"position_xz":[600,600]}).ok)
	var grouped := Ops.propose(source,"group",{"ids":["rock","tree"],"group_id":"landmarks","name":"Marcos"})
	check("group_metadata",grouped.ok and Metadata.state(grouped.data,"rock").group_id == "landmarks")
	var copied_group := Ops.propose(grouped.data,"duplicate",{"ids":["rock","tree"],"delta_xz":[-200,0]})
	check("duplicate_remaps_group",copied_group.ok and copied_group.data.objects.groups.size() == 2 and copied_group.data.objects.states.size() == 4 and copied_group.data.objects.groups[0].group_id != copied_group.data.objects.groups[1].group_id)
	var locked_group := Ops.propose(grouped.data,"group_state",{"group_id":"landmarks","locked":true})
	check("group_lock_blocks_all_members",locked_group.ok and not Ops.propose(locked_group.data,"rotate",{"ids":["rock","tree"],"degrees":90}).ok)
	check("explicit_group_unlock",locked_group.ok and Ops.propose(locked_group.data,"group_state",{"group_id":"landmarks","locked":false}).ok)
	var locked := Ops.propose(grouped.data,"lock",{"ids":["rock"],"value":true})
	check("lock_blocks_move_and_remove",locked.ok and not Ops.propose(locked.data,"move",{"ids":["rock"],"position_xz":[450,400]}).ok and not Ops.propose(locked.data,"remove",{"ids":["rock"]}).ok)
	var layer_locked := source.duplicate(true); layer_locked.layers[0].locked = true
	check("layer_lock_blocks_duplicate",not Ops.propose(layer_locked,"duplicate",{"ids":["shrub"],"delta_xz":[40,0]}).ok)
	var duplicate := Ops.propose(source,"duplicate",{"ids":["shrub"],"delta_xz":[40,0]})
	check("duplicate_new_identity",duplicate.ok and duplicate.data.placements.size() == 4 and duplicate.data.placements[-1].placement_id != "shrub")
	var hidden := Ops.propose(source,"hide",{"ids":["rock"],"value":true})
	check("editor_hiding_keeps_published_collision",hidden.ok and Terrain.compile(hidden.data).package.part.solid_volumes.size() == 2)
	var session := Session.new(); session.replace(source); var original := session.document().semantic_hash()
	check("session_apply",session.apply(grouped.data).ok)
	check("metadata_undo_redo",session.undo() and session.document().semantic_hash() == original and session.redo() and session.document().to_data().objects.groups.size() == 1)
	var layered: Dictionary = grouped.data.duplicate(true)
	layered.regions = [{"region_id":"floor","layer_id":"floor","polygon_xz":[[10,10],[20,10],[20,20],[10,20]],"purpose":"encounter"}]
	layered.layers[0].protected_regions = ["floor"]
	layered.context = Context.empty(); layered.context.areas = [{"region_id":"floor","allowed_species":[],"allow_rare":false,"reserved":[{"encounter_id":"guardian","species_id":"test_gel","category":"boss","origin_id":"trial_stage_1","quest_id":"find_guardian"}]}]
	var copied_layer := Session.new(); copied_layer.replace(layered)
	check("duplicate_layer_with_objects",copied_layer.duplicate_layer("floor").ok and copied_layer.document().to_data().placements.size() == 6 and copied_layer.document().to_data().objects.groups.size() == 2)
	var layer_data: Dictionary = copied_layer.document().to_data()
	check("duplicate_layer_separate_id_namespaces",layer_data.layers[1].layer_id != layer_data.regions[1].region_id and layer_data.regions[1].layer_id == layer_data.layers[1].layer_id and layer_data.layers[1].protected_regions[0] == layer_data.regions[1].region_id)
	check("duplicate_layer_remaps_reservation",layer_data.context.areas.size() == 2 and layer_data.context.areas[1].region_id == layer_data.regions[1].region_id and layer_data.context.areas[1].reserved[0].encounter_id != "guardian" and layer_data.context.areas[1].reserved[0].quest_id == "find_guardian")
	check("same_numeric_position_is_noop",Ops.propose(source,"move",{"ids":["shrub"],"position_xz":[200,200]}).no_op)
	var bridge_piece: Dictionary = Candidate.representative_map().pieces[0].source
	var below := Ops.propose(bridge_piece,"place",{"placement_id":"bridge_shrub","definition_id":"woodland_shrub","surface_id":"lower","position_xz":[200,600]})
	var above := Ops.propose(below.data,"move",{"ids":["bridge_shrub"],"surface_id":"bridge","position_xz":[200,600]}) if below.ok else {"ok":false}
	check("move_uses_chosen_bridge_floor",above.ok and above.data.placements[0].surface_id == "bridge" and above.data.placements[0].position_xyz[1] == 40)
	if below.ok:
		var locked_bridge: Dictionary = below.data.duplicate(true)
		for layer: Dictionary in locked_bridge.layers:
			if layer.layer_id == "plateau": layer.locked = true
		check("move_to_locked_floor_rejected",Ops.propose(locked_bridge,"move",{"ids":["bridge_shrub"],"surface_id":"bridge","position_xz":[200,600]}).code == "object_locked")
	var damaged := source.duplicate(true); damaged.dependencies[0].sha256 = "0".repeat(64)
	check("changed_dependency_rejected",Terrain.compile(damaged).code == "object_dependency_changed")
	var floating := source.duplicate(true); floating.placements[0].position_xyz[1] += 1
	check("floating_object_rejected",Terrain.compile(floating).code == "object_not_settled")
	var region := fixture(); region.regions = [{"region_id":"path","layer_id":"floor","polygon_xz":[[350,350],[450,350],[450,450],[350,450]],"purpose":"path"}]; region.layers[0].protected_regions = ["path"]
	check("protected_region_rejected",Ops.propose(region,"place",{"definition_id":"moss_boulder","surface_id":"floor","position_xz":[400,400]}).code == "object_protected")
	var params := {"definition_id":"woodland_shrub","surface_id":"floor","center_xz":[400,400],"radius":250,"count":8,"spacing":12,"seed_text":"-9223372036854775808","exclusions":[[[350,350],[450,350],[450,450],[350,450]]]}
	var scattered := Ops.propose(fixture(),"scatter",params)
	check("scatter_count",scattered.ok and scattered.data.placements.size() == 8)
	check("scatter_repeatable",scattered.ok and Ops.propose(fixture(),"scatter",params).output_hash == scattered.output_hash)
	if scattered.ok:
		var clear := true
		for placement: Dictionary in scattered.data.placements:
			var p := Vector2(placement.position_xyz[0],placement.position_xyz[2])
			if Rect2(350,350,100,100).has_point(p): clear = false
		check("scatter_exclusion",clear)
	var impossible := params.duplicate(true); impossible.radius = 1; impossible.count = 2; impossible.exclusions = []
	var rejected := Ops.propose(fixture(),"scatter",impossible)
	check("scatter_quota_failure_no_partial",not rejected.ok and rejected.code == "object_scatter_deficit" and not rejected.has("data") and rejected.deficit > 0)
	var bundle := Exchange.export_bundle("piece",source,Exchange.policy(["name"]),"Objetos F9")
	check("bundle_preserves_objects",bundle.ok and Exchange.validate_bundle(bundle.bundle).ok and bundle.bundle.ticket.base.placements == source.placements)
	finish()

static func expected_asset_set(dependencies: Array) -> bool:
	# Independent inventory: four material images/imports, one shader, one prop
	# catalog and the three placed sprite images/imports. Reject duplicates/extras.
	var expected: Array[String] = ["res://scripts/map_authoring/terrain/terrain_material.gdshader","res://data/map_authoring/prop_catalog.json"]
	for name: String in ["grass_tile","earth_tile","sand_tile","cliff_tile"]:
		var path := "res://assets/art/map_authoring/"+name+".png"
		expected.append(path); expected.append(path+".import")
	for name: String in ["oak_tree","moss_boulder","woodland_shrub"]:
		var path := "res://assets/art/map_authoring/props/"+name+".png"
		expected.append(path); expected.append(path+".import")
	if dependencies.size() != 16 or expected.size() != 16: return false
	var actual := {}
	for item: Dictionary in dependencies:
		if item.path not in expected or actual.has(item.path) or FileAccess.get_sha256(item.path) != item.sha256: return false
		actual[item.path] = true
	return actual.size() == expected.size()

static func fixture() -> Dictionary:
	var source := Piece.empty("objects_fixture")
	source.layers = [{"layer_id":"floor","name":"Chão","origin_xz":[0,0],"sample_spacing":800,"columns":2,"rows":2,"heights":[0,0,0,0],"material_masks":{},"locked":false,"protected_regions":[]}]
	return source

func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_OBJECTS_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
