extends SceneTree
const Ports = preload("res://scripts/core/expedition/generation/connector_partition.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Generation = preload("res://scripts/map_authoring/generation/generation_document.gd")
const Adapter = preload("res://scripts/map_authoring/generation/assembler_adapter.gd")
const PROFILE := {"radius":20.0,"height":32.0,"connector_kinds":["walk"]}
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_PORT_CHECK "+id+" "+str(ok))
func run() -> void:
	var a := part("a",false,12.5); var b := part("b",true,100)
	var original := Canonical.digest([a,b])
	check("refined_group_valid",Ports.validate_groups(a).ok)
	check("single_group_valid",Ports.validate_groups(b).ok)
	var pa := Ports.resolve_port(a,"a/opening"); var pb := Ports.resolve_port(b,"b/opening")
	check("logical_opening_resolves_eight_fragments",pa.ok and pa.fragments.size() == 8)
	check("physical_member_cannot_be_attached_separately",not Ports.resolve_port(a,a.connector_groups[0].fragments[0].connector_id).ok)
	var single := part("s",false,100)
	var old_id: String = single.connector_groups[0].fragments[0].connector_id
	single.connectors.filter(func(p: Dictionary) -> bool: return p.connector_id == old_id)[0].connector_id = "s/opening"
	single.connector_groups[0].fragments[0].connector_id = "s/opening"
	check("single_endpoint_alias_resolves_group",Ports.resolve_port(single,"s/opening").get("grouped",false))
	var simple := Ports.partition_link(Ports.resolve_port(single,"s/opening"),pb,"simple",PROFILE)
	check("simple_link_preserves_physical_id",simple.ok and simple.connections.size() == 1 and simple.connections[0].a_connector == "s/opening")
	var split := Ports.partition_link(pa,pb,"link",PROFILE)
	check("one_to_eight_partition",split.ok and split.connections.size() == 8)
	if not split.ok: print(split); finish(); return
	var cuts: Array = [-40.0,-37.5,-25.0,-12.5,0.0,12.5,25.0,37.5,40.0]
	var intervals := true; var width := 0.0; var coincident := true
	for k: int in split.provenance.size():
		var span: Dictionary = split.provenance[k]
		intervals = intervals and span.t0 == cuts[k] and span.t1 == cuts[k+1]
		width += float(span.t1)-float(span.t0)
		var left := get_port(split.endpoints,span.a_connector); var right := get_port(split.endpoints,span.b_connector)
		coincident = coincident and left.position == right.position and left.width == right.width
	check("independent_interval_oracle",intervals)
	check("whole_eighty_units_preserved",width == 80.0)
	check("physical_pairs_share_exact_position",coincident)
	check("operator_preserves_inputs",Canonical.digest([a,b]) == original)
	check("all_consumed_endpoints_have_remapping",split.remap.size() == 9 and split.remap[b.connector_groups[0].fragments[0].connector_id].size() == 8)
	var mixed := part("m",true,20)
	var nm := Ports.partition_link(pa,Ports.resolve_port(mixed,"m/opening"),"nm",PROFILE)
	check("different_subdivisions_common_partition",nm.ok and nm.connections.size() == 12)
	var reordered := a.duplicate(true); reordered.surfaces.reverse(); reordered.connectors.reverse(); reordered.connector_groups[0].fragments.reverse()
	var repeated := Ports.partition_link(Ports.resolve_port(reordered,"a/opening"),pb,"link",PROFILE)
	check("array_order_is_not_identity",repeated.ok and Canonical.digest(repeated) == Canonical.digest(split))
	var slope_a := part("up",false,12.5,0.25); var slope_b := part("down",true,20,0.25)
	check("sloping_piecewise_edge_matches",Ports.partition_link(Ports.resolve_port(slope_a,"up/opening"),Ports.resolve_port(slope_b,"down/opening"),"slope",PROFILE).ok)
	var kink_a := kinked(part("ka",false,12.5)); var kink_b := kinked(part("kb",true,25))
	check("matching_gradient_changes_preserve_piecewise_height",Ports.partition_link(Ports.resolve_port(kink_a,"ka/opening"),Ports.resolve_port(kink_b,"kb/opening"),"kink",PROFILE).ok)
	var false_center := part("other",true,20,-0.25,25)
	check("matching_center_does_not_hide_wrong_end_heights",not Ports.partition_link(Ports.resolve_port(slope_a,"up/opening"),Ports.resolve_port(false_center,"other/opening"),"wrong",PROFILE).ok)
	var bad := a.duplicate(true); bad.connector_groups[0].fragments.remove_at(3)
	check("middle_gap_rejected",not Ports.validate_groups(bad).ok)
	bad = a.duplicate(true); bad.connector_groups[0].fragments[3].t0 += 0.000001
	check("positive_gap_below_geometric_epsilon_is_not_erased",not Ports.validate_groups(bad).ok)
	bad = a.duplicate(true); bad.connector_groups[0].fragments[3].t0 -= 1
	check("positive_overlap_rejected",not Ports.validate_groups(bad).ok)
	bad = a.duplicate(true); bad.connector_groups[0].fragments[0].connector_id = "missing"
	check("missing_fragment_rejected",not Ports.validate_groups(bad).ok)
	bad = a.duplicate(true); get_port(bad.connectors,bad.connector_groups[0].fragments[0].connector_id).surface_id = bad.surfaces[-1].surface_id
	check("wrong_surface_rejected",not Ports.validate_groups(bad).ok)
	bad = a.duplicate(true); alter_group(bad,"outward",Vector3.LEFT)
	check("inverted_normal_rejected",not Ports.validate_groups(bad).ok)
	bad = a.duplicate(true); bad.connector_groups[0].connector_id = bad.connector_groups[0].fragments[0].connector_id
	check("compound_group_alias_rejected",not Ports.validate_groups(bad).ok)
	bad = a.duplicate(true); var duplicate: Dictionary = bad.connector_groups[0].duplicate(true); duplicate.connector_id = "duplicate"; bad.connector_groups.append(duplicate)
	check("member_cannot_belong_to_two_groups",not Ports.validate_groups(bad).ok)
	bad = a.duplicate(true); bad.surfaces[0].vertices = ["bad",Vector3.ZERO,Vector3.ONE]
	check("malformed_cell_rejected_without_script_error",not Ports.validate_groups(bad).ok)
	bad = a.duplicate(true); bad.connector_groups[0].width = NAN
	check("non_finite_group_rejected",not Ports.validate_groups(bad).ok)
	var large := PROFILE.duplicate(true); large.radius = 41.0
	check("body_wider_than_logical_opening_rejected",not Ports.partition_link(pa,pb,"large",large).ok)
	bad = a.duplicate(true); get_port(bad.connectors,bad.connector_groups[0].fragments[3].connector_id).headroom = 20.0
	check("physical_fragment_headroom_is_required",not Ports.partition_link(Ports.resolve_port(bad,"a/opening"),pb,"low",PROFILE).ok)
	bad = b.duplicate(true); alter_group(bad,"tags",["different"])
	check("incompatible_tags_rejected",not Ports.partition_link(pa,Ports.resolve_port(bad,"b/opening"),"tags",PROFILE).ok)
	check("shared_tag_suffices_for_grouped_opening",split.ok and a.connector_groups[0].tags != b.connector_groups[0].tags)
	bad = b.duplicate(true); bad.connector_groups[0].headroom = 90.0
	for fragment: Dictionary in bad.connector_groups[0].fragments: get_port(bad.connectors,fragment.connector_id).headroom = 90.0
	check("authored_dimensions_must_match",not Ports.partition_link(pa,Ports.resolve_port(bad,"b/opening"),"dimensions",PROFILE).ok)
	var outward := a.duplicate(true); alter_group(outward,"direction","out")
	var inward := b.duplicate(true); alter_group(inward,"direction","in")
	var one_way := Ports.partition_link(Ports.resolve_port(outward,"a/opening"),Ports.resolve_port(inward,"b/opening"),"one_way",PROFILE)
	check("one_way_flags_preserved",one_way.ok and one_way.connections.all(func(link: Dictionary) -> bool: return link.forward and not link.backward))
	alter_group(inward,"direction","out")
	check("incompatible_directions_rejected",not Ports.partition_link(Ports.resolve_port(outward,"a/opening"),Ports.resolve_port(inward,"b/opening"),"direction",PROFILE).ok)
	var legacy_a := part("legacy_a",false,100); var legacy_b := part("legacy_b",true,100)
	var legacy_a_id: String = legacy_a.connector_groups[0].fragments[0].connector_id; var legacy_b_id: String = legacy_b.connector_groups[0].fragments[0].connector_id
	legacy_a.erase("connector_groups"); legacy_b.erase("connector_groups")
	get_port(legacy_b.connectors,legacy_b_id).width = 60.0
	get_port(legacy_b.connectors,legacy_b_id).tags = get_port(legacy_a.connectors,legacy_a_id).tags.duplicate()
	var legacy := Ports.partition_link(Ports.resolve_port(legacy_a,legacy_a_id),Ports.resolve_port(legacy_b,legacy_b_id),"legacy",PROFILE,true)
	check("legacy_assembler_keeps_unequal_width_rule",legacy.ok and legacy.endpoints[1].width == 60.0)
	get_port(legacy_b.connectors,legacy_b_id).tags.append("extra")
	check("legacy_assembler_keeps_exact_tag_rule",not Ports.partition_link(Ports.resolve_port(legacy_a,legacy_a_id),Ports.resolve_port(legacy_b,legacy_b_id),"legacy",PROFILE,true).ok)
	check("ungrouped_endpoint_remains_resolvable",Ports.resolve_port(legacy_a,legacy_a_id).ok and not Ports.resolve_port(legacy_a,legacy_a_id).grouped)
	bad = a.duplicate(true); bad.connector_groups[0].script = "res://bad.gd"
	check("group_is_closed_passive_data",not Ports.validate_groups(bad).ok)
	world_cases(a,mixed,nm,outward,b)
	terrain_cases()
	composition_cases()
	assembler_cases()
	finish()

func assembler_cases() -> void:
	var input := assembler_input()
	var before := Canonical.digest(input.to_data())
	var built := ExpeditionAssembler.build(input)
	check("assembler_accepts_compound_ports",built.ok)
	if not built.ok: print(built); return
	var stage: Dictionary = built.data.manifest.to_data().stages[0]
	var attached: Dictionary = stage.part_instances.filter(func(item: Dictionary) -> bool: return item.instance_id == "right")[0].attachment
	check("assembler_keeps_all_twelve_external_links",attached.fragments.size() == 12 and stage.connections.filter(func(link: Dictionary) -> bool: return link.connection_id.begins_with("authored/right/cut_")).size() == 12)
	check("assembler_logical_anchor_translation",stage.part_instances[1].translation == Vector3(100,0,0))
	var references := {}; var unique := true
	for port: Dictionary in stage.connectors:
		if references.has(port.connector_id): unique = false
		references[port.connector_id] = 0
	for link: Dictionary in stage.connections:
		for id: String in [link.a_connector,link.b_connector]: references[id] = references.get(id,0)+1
	check("assembler_no_ghost_or_duplicate_endpoint",unique and references.values().all(func(count: int) -> bool: return count == 1))
	var width := 0.0
	for fragment: Dictionary in attached.fragments: width += fragment.t1-fragment.t0
	check("assembler_preserves_eighty_units",width == 80.0)
	check("assembler_definitions_are_immutable",Canonical.digest(input.to_data()) == before)
	var world := WorldGeometry.new(); world.configure(built.data.manifest,"authored")
	var from := qualified_at(world,"left",Vector2(25,35)); var to := qualified_at(world,"right",Vector2(175,35))
	check("actor_crosses_assembled_refined_map",walk(world,from,to,PROFILE))
	input.parts.reverse()
	for part_resource: ExpeditionPartDefinition in input.parts:
		part_resource.surfaces.reverse(); part_resource.connectors.reverse(); part_resource.internal_connections.reverse()
		for group: Dictionary in part_resource.connector_groups: group.fragments.reverse()
	var repeated := ExpeditionAssembler.build(input)
	check("assembler_reordered_input_same_manifest",repeated.ok and repeated.data.hash == built.data.hash)
	var snapshot := input.to_data(); var definitions: Array = snapshot.parts
	var tasks: Array = input.stages[0].parts
	var root_definition := ExpeditionAssembler.lookup(definitions,"part_id","left")
	var child_definition := ExpeditionAssembler.lookup(definitions,"part_id","right")
	var root := ExpeditionAssembler.place({"stage_id":"authored","biome":"authored","node":tasks[0]},root_definition,0,[],PROFILE)
	var placements: Array[Dictionary] = [root.instance]
	var child_task := {"stage_id":"authored","biome":"authored","node":tasks[1]}
	var child := ExpeditionAssembler.place(child_task,child_definition,0,placements,PROFILE)
	placements.append(child.instance)
	var retry := child_task.duplicate(true); retry.node.instance_id = "third"
	var placed_hash := Canonical.digest(placements)
	check("assembler_reserves_whole_logical_port",not ExpeditionAssembler.place(retry,child_definition,0,placements,PROFILE).ok)
	check("failed_attachment_does_not_mutate_placements",Canonical.digest(placements) == placed_hash)
	retry = child_task.duplicate(true); retry.node.instance_id = "third"; retry.node.parent = "right"; retry.node.parent_connector = child_definition.connector_groups[0].connector_id
	check("child_attachment_port_cannot_be_reused_as_parent",not ExpeditionAssembler.place(retry,child_definition,0,placements,PROFILE).ok)
	retry = child_task.duplicate(true); retry.node.connector = child_definition.connector_groups[0].fragments[0].connector_id
	var root_only: Array[Dictionary] = [root.instance]
	check("assembler_rejects_physical_member_attachment",not ExpeditionAssembler.place(retry,child_definition,0,root_only,PROFILE).ok)
	var bad := child_definition.duplicate(true); bad.connector_groups[0].fragments[1].t0 += 0.01
	check("assembler_revalidates_group_coverage",not ExpeditionAssembler.place(child_task,bad,0,root_only,PROFILE).ok)
	bad = child_definition.duplicate(true); alter_group(bad,"direction","out")
	var outward := root_definition.duplicate(true); alter_group(outward,"direction","out")
	var outward_root := ExpeditionAssembler.place({"stage_id":"authored","biome":"authored","node":tasks[0]},outward,0,[],PROFILE)
	var outward_placements: Array[Dictionary] = [outward_root.instance]
	check("assembler_rejects_incompatible_group_directions",not ExpeditionAssembler.place(child_task,bad,0,outward_placements,PROFILE).ok)
	alter_group(bad,"direction","in")
	var directional := ExpeditionAssembler.place(child_task,bad,0,outward_placements,PROFILE)
	check("assembler_preserves_one_way_flags",directional.ok and directional.instance.external_connections.all(func(link: Dictionary) -> bool: return link.forward and not link.backward))
	var old_revision := input.generator_revision; input.generator_revision = "f0_convex_cells_v1"
	check("old_generator_revision_is_explicitly_unavailable",ExpeditionAssembler.build(input).error_code == &"content_revision_unavailable")
	input.generator_revision = old_revision
	var legacy := ExpeditionPartDefinition.new(); legacy.part_id = "legacy"; legacy.revision = 1; legacy.biome_tags = PackedStringArray(["authored"]); legacy.allowed_rotations.assign([0])
	var expected := {"part_id":"legacy","revision":1,"biome_tags":["authored"],"allowed_rotations":[0],"surfaces":[],"connectors":[],"sockets":[],"solid_volumes":[],"blockers":[]}
	check("legacy_part_canonical_bytes_unchanged",Canonical.encode(legacy.to_data()) == Canonical.encode(expected))
	var source := map_source(); var source_hash := Map.hash_source(source)
	var adapted := Adapter.build(Generation.from_map(source))
	check("production_adapter_transports_compound_ports",adapted.ok and adapted.metrics.revision == ExpeditionAssembler.REVISION and adapted.package.realized_links[0].fragments.size() == 12)
	check("production_adapter_preserves_authorship",Map.hash_source(source) == source_hash)

static func assembler_input() -> ExpeditionGenerationInput:
	var input := ExpeditionGenerationInput.new()
	input.request_id = "port_test"; input.phase_id = "port_test"; input.entry_stage_id = "authored"; input.seed_text = "0"; input.generator_revision = ExpeditionAssembler.REVISION; input.recipe_revision = 1; input.catalog_revision = "port_test"
	input.generation_policy_id = "generation"; input.population_policy_id = "population"
	for pair: Array in [["generation","generation",{"max_attempts":1,"max_expansions":10}],["population","population",{}]]:
		var policy := ExpeditionPolicyDefinition.new(); policy.policy_id = pair[0]; policy.domain = pair[1]; policy.revision = 1; policy.parameters = pair[2]; input.policies.append(policy)
	var profile := ExpeditionTraversalProfile.new(); profile.profile_id = "body"; profile.revision = 1; profile.radius = 20; profile.height = 32; profile.connector_kinds = PackedStringArray(["walk"]); input.traversal = profile
	var nodes: Array = []
	for spec: Array in [["left",9,"east"],["right",6,"west"]]:
		var package: Dictionary = Terrain.compile(authored_source(spec[1],spec[2])).package
		var data: Dictionary = package.part
		var part_resource := ExpeditionPartDefinition.new(); part_resource.part_id = spec[0]; part_resource.revision = data.revision; part_resource.biome_tags = PackedStringArray(["authored"]); part_resource.allowed_rotations.assign([0])
		for cell: Dictionary in data.surfaces:
			var surface := ExpeditionSurfaceDefinition.new(); surface.surface_id = cell.surface_id; surface.vertices = PackedVector3Array(cell.vertices); surface.headroom = cell.headroom; part_resource.surfaces.append(surface)
		for port: Dictionary in data.connectors:
			var endpoint := ExpeditionConnectorDefinition.new()
			for field: String in ["connector_id","surface_id","position","outward","width","headroom","kind","direction"]: endpoint.set(field,port[field])
			endpoint.tags = PackedStringArray(port.tags); part_resource.connectors.append(endpoint)
		part_resource.connector_groups.assign(data.connector_groups); part_resource.solid_prisms.assign(data.get("solid_prisms",[]))
		part_resource.internal_connections.assign(package.adjacency)
		for cell: Dictionary in data.surfaces:
			var point := Kernel.support_y(cell,Vector3(25,0,35))
			if not Kernel.contains(cell,point): continue
			var socket := ExpeditionSocketDefinition.new(); socket.socket_id = "entry"; socket.surface_id = cell.surface_id; socket.position = point; socket.kind = "entrance"; part_resource.sockets.append(socket); break
		input.parts.append(part_resource)
		nodes.append({"instance_id":spec[0],"candidates":[spec[0]],"parent":"" if spec[0] == "left" else "left","parent_connector":"" if spec[0] == "left" else "port_"+"east".sha256_text().substr(0,20),"connector":"" if spec[0] == "left" else "port_"+"west".sha256_text().substr(0,20)})
	input.stages.assign([{"stage_id":"authored","biome":"authored","entrance":"left/entry","parts":nodes}]); return input

static func qualified_at(world: WorldGeometry, id: String, horizontal: Vector2) -> ExpeditionWorldPoint:
	for cell: Dictionary in world._stage.surfaces:
		if not cell.surface_id.begins_with("authored/"+id+"/surface/"): continue
		var point := Kernel.support_y(cell,Vector3(horizontal.x,0,horizontal.y))
		if Kernel.contains(cell,point): return ExpeditionWorldPoint.create("authored",cell.surface_id,point)
	return null

func composition_cases() -> void:
	var source := map_source(); var original := Map.hash_source(source)
	var built := MapCompiler.compile(source)
	check("refined_map_compiles",built.ok)
	print("F9_PORT_METRICS "+JSON.stringify(built.get("metrics",built.get("geometry_diagnostic",{}))))
	if not built.ok: print(built); return
	check("map_realizes_all_twelve_intervals_and_two_logical_ports",built.package.realized_links.size() == 1 and built.package.realized_links[0].fragments.size() == 12 and built.package.logical_ports.size() == 2)
	var references: Dictionary = {}; var stage: Dictionary = built.package.manifest.stages[0]
	for link: Dictionary in stage.connections:
		references[link.a_connector] = references.get(link.a_connector,0)+1; references[link.b_connector] = references.get(link.b_connector,0)+1
	check("runtime_has_no_ghost_or_duplicate_endpoints",stage.connectors.all(func(port: Dictionary) -> bool: return references.get(port.connector_id,0) == 1))
	var world := WorldGeometry.new(); world.configure(MapCompiler.manifest(built.package),"map_preview")
	var from := instance_at(world,"left",Vector2(25,35)); var to := instance_at(world,"right",Vector2(175,35))
	check("compiled_map_supports_real_body_off_center",world.ground_line_to(from,to,PROFILE,world.geometry_revision).ok)
	check("real_actor_crosses_compiled_refined_map",walk(world,from,to,PROFILE))
	check("composition_does_not_rewrite_authoring",Map.hash_source(source) == original and built.input_hash == original)
	check("refined_map_package_revalidates",MapCompiler.validate_package(built.package))
	var bad: Dictionary = built.package.duplicate(true); bad.logical_ports[0].width += 1.0; rehash(bad)
	check("map_receiver_rejects_forged_logical_width",not MapCompiler.validate_package(bad))
	bad = built.package.duplicate(true); bad.profile = []; rehash(bad)
	check("map_receiver_rejects_malformed_profile_without_error",not MapCompiler.validate_package(bad))
	bad = built.package.duplicate(true); bad.realized_links[0].fragments[0].a_connector = "absent"; rehash(bad)
	check("map_receiver_rejects_forged_fragment_reference",not MapCompiler.validate_package(bad))
	bad = built.package.duplicate(true); bad.manifest.stages[0].connections.pop_back(); rehash(bad)
	check("map_receiver_rejects_missing_realized_connection",not MapCompiler.validate_package(bad))
	bad = built.package.duplicate(true); bad.manifest.stages[0].surfaces[0].vertices[0].x += 1.0; rehash(bad)
	check("map_receiver_rejects_forged_runtime_surface",not MapCompiler.validate_package(bad))
	var recipe := source.duplicate(true); recipe.mode = "recipe"; recipe.instances[1].position_xyz = [900,0,0]
	var aligned := MapCompiler.compile(recipe)
	check("recipe_aligns_logical_anchors_not_first_fragments",aligned.ok and aligned.package.manifest.stages == built.package.manifest.stages)
	var orphan := source.duplicate(true); orphan.links.clear()
	check("unlinked_compound_opening_rejected",MapCompiler.compile(orphan).code == "opening_unlinked")
	var sloping := map_source()
	for piece: Dictionary in sloping.pieces:
		var layer: Dictionary = piece.source.layers[0]
		for k: int in layer.heights.size(): layer.heights[k] += float(k/int(layer.columns))*float(layer.sample_spacing)*0.25
		piece.source.connectors[0].position_xyz[1] = 12.5
		var old_hash: String = piece.piece_hash; piece.piece_hash = Schema.semantic_hash(piece.source)
		for instance: Dictionary in sloping.instances:
			if instance.piece_hash == old_hash: instance.piece_hash = piece.piece_hash
	var inclined := MapCompiler.compile(sloping)
	check("sloped_refined_seam_uses_horizontal_width",inclined.ok and MapCompiler.validate_package(inclined.package) and inclined.package.realized_links[0].fragments.size() == 12)

static func map_source() -> Dictionary:
	var data := Map.empty("refined_map")
	for spec: Array in [["left",9,"east",0],["right",6,"west",100]]:
		var source := authored_source(spec[1],spec[2]); var hash_value := Schema.semantic_hash(source)
		data.pieces.append({"piece_hash":hash_value,"source":source}); data.instances.append({"instance_id":spec[0],"piece_hash":hash_value,"position_xyz":[spec[3],0,0],"rotation_quarters":0})
	data.links = [{"link_id":"bridge","a_instance":"left","a_connector":"east","b_instance":"right","b_connector":"west"}]
	return data

func terrain_cases() -> void:
	var source := authored_source(9,"east"); var original := Schema.semantic_hash(source)
	var built := Terrain.compile(source)
	check("refined_authored_terrain_compiles",built.ok)
	if not built.ok: print(built); return
	var metadata: Array = built.package.authored_ports
	check("source_logical_id_survives_refinement",metadata.size() == 1 and metadata[0].connector_id == "east" and metadata[0].surface_id == "floor" and metadata[0].fragments.size() == 8)
	var resolved := Ports.resolve_port(built.package.part,metadata[0].port_id)
	check("terrain_group_covers_whole_opening",resolved.ok and resolved.fragments.size() == 8 and resolved.port.width == 80.0)
	check("compiling_fragments_does_not_rewrite_source",Schema.semantic_hash(source) == original and built.input_hash == original)
	check("terrain_package_revalidates",Terrain.validate_package(built.package))
	var bad: Dictionary = built.package.duplicate(true); bad.authored_ports[0].fragments[0].span_id = "absent"; rehash(bad)
	check("terrain_receiver_rejects_forged_span",not Terrain.validate_package(bad))
	bad = built.package.duplicate(true); bad.profile = []; rehash(bad)
	check("terrain_receiver_rejects_malformed_profile_without_error",not Terrain.validate_package(bad))
	bad = built.package.duplicate(true); bad.authored_ports[0].width += 1.0; rehash(bad)
	check("terrain_receiver_rejects_forged_authored_width",not Terrain.validate_package(bad))
	bad = built.package.duplicate(true)
	for boundary: Dictionary in bad.boundaries:
		if not boundary.openings.is_empty(): boundary.openings.clear(); boundary.kind = "support_edge"; break
	rehash(bad)
	check("terrain_receiver_rejects_missing_opening_reference",not Terrain.validate_package(bad))
	bad = built.package.duplicate(true); bad.adjacency[0].a_connector = "absent"; rehash(bad)
	check("terrain_receiver_rejects_forged_internal_reference",not Terrain.validate_package(bad))
	source.connectors.clear(); var no_port := Terrain.compile(source)
	check("empty_groups_omitted_from_compiled_part",no_port.ok and not no_port.package.part.has("connector_groups"))

static func rehash(package: Dictionary) -> void:
	package.erase("package_hash"); package.package_hash = Canonical.digest(package)

static func authored_source(axis: int, side: String) -> Dictionary:
	var data := Piece.empty("refined_"+side); var heights: Array = []
	for z: int in axis:
		for x: int in axis: heights.append(float(x*(axis-1-x)*z*(axis-1-z))*0.001)
	data.layers = [{"layer_id":"floor","name":"Relevo","origin_xz":[0,0],"sample_spacing":100.0/float(axis-1),"columns":axis,"rows":axis,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]}]
	data.connectors = [{"connector_id":side,"surface_id":"floor","position_xyz":[100 if side == "east" else 0,0,50],"kind":"walk","normal_xyz":[1 if side == "east" else -1,0,0],"width":80,"headroom":100,"tags":["map_editor"],"direction":"both"}]
	return data

func world_cases(a: Dictionary, b: Dictionary, split: Dictionary, one_way_a: Dictionary, one_way_b: Dictionary) -> void:
	var world := WorldGeometry.new(); var manifest := realized(a,b,split)
	check("partition_realizes_canonical_world",world.configure(manifest,"port_fixture").ok)
	var from := at(world,Vector3(25,0,35)); var to := at(world,Vector3(175,0,35))
	check("body_spans_multiple_smaller_fragments",world.position_query(at(world,Vector3(100,0,50)),PROFILE,world.geometry_revision).ok)
	check("off_center_route_crosses_full_union",world.ground_line_to(from,to,PROFILE,world.geometry_revision).ok)
	check("real_actor_crosses_fragmented_opening",walk(world,from,to,PROFILE))
	var large := PROFILE.duplicate(true); large.radius = 41.0
	check("oversized_body_cannot_cross_closed_opening_ends",not world.path(at(world,Vector3(50,0,50)),at(world,Vector3(150,0,50)),large,world.geometry_revision).ok)
	var small := PROFILE.duplicate(true); small.radius = 8.0
	world.insert_obstacle("middle",AABB(Vector3(98,-1,46),Vector3(4,60,8)),world.geometry_revision)
	check("central_obstacle_keeps_lateral_passage",walk(world,at(world,Vector3(25,0,25)),at(world,Vector3(175,0,25)),small))
	world.insert_obstacle("closed",AABB(Vector3(98,-1,9),Vector3(4,60,82)),world.geometry_revision)
	check("closed_fragmented_opening_has_no_route",not world.path(from,to,PROFILE,world.geometry_revision).ok)
	var directional := one_way_b.duplicate(true); alter_group(directional,"direction","in")
	var links := Ports.partition_link(Ports.resolve_port(one_way_a,"a/opening"),Ports.resolve_port(directional,"b/opening"),"directional",PROFILE)
	world.configure(realized(one_way_a,directional,links),"port_fixture")
	check("one_way_world_rejects_reverse_crossing",not world.path(at(world,Vector3(175,0,35)),at(world,Vector3(25,0,35)),PROFILE,world.geometry_revision).ok)

static func part(id: String, right: bool, step: float, slope: float = 0, intercept: float = 0) -> Dictionary:
	var cells: Array = []; var endpoints: Array = []; var joins: Array = []; var fragments: Array = []
	var x0 := 100.0 if right else 0.0; var x1 := x0+100.0
	var normal := Vector3.LEFT if right else Vector3.RIGHT
	for k: int in ceili(100.0/step):
		var lo := float(k)*step; var hi := minf(100,float(k+1)*step)
		var surface := id+"/cell_"+str(lo)
		cells.append({"surface_id":surface,"vertices":[Vector3(x0,slope*lo+intercept,lo),Vector3(x1,slope*lo+intercept,lo),Vector3(x1,slope*hi+intercept,hi),Vector3(x0,slope*hi+intercept,hi)],"headroom":100.0})
		var left := maxf(10,lo); var end := minf(90,hi)
		if end > left:
			var connector := id+"/external_"+str(left)+"_"+str(end)
			endpoints.append({"connector_id":connector,"surface_id":surface,"position":Vector3(100,slope*(left+end)*0.5+intercept,(left+end)*0.5),"outward":normal,"width":end-left,"headroom":100.0,"kind":"walk","tags":["shared",id],"direction":"both"})
			fragments.append({"connector_id":connector,"t0":50.0-end if right else left-50.0,"t1":50.0-left if right else end-50.0})
		if k > 0:
			var pair: Array[String] = []
			for side: int in 2:
				var connector := id+"/join_"+str(lo)+"_"+str(side); pair.append(connector)
				endpoints.append({"connector_id":connector,"surface_id":cells[k-1 if side == 0 else k].surface_id,"position":Vector3((x0+x1)*0.5,slope*lo+intercept,lo),"outward":Vector3(0,0,1 if side == 0 else -1),"width":100.0,"headroom":100.0,"kind":"walk","tags":["internal"],"direction":"both"})
			joins.append({"connection_id":id+"/join_"+str(lo),"a_connector":pair[0],"b_connector":pair[1],"forward":true,"backward":true})
	return {"surfaces":cells,"connectors":endpoints,"internal_connections":joins,"connector_groups":[{"connector_id":id+"/opening","position":Vector3(100,slope*50.0+intercept,50),"outward":normal,"width":80.0,"headroom":100.0,"kind":"walk","tags":["shared",id],"direction":"both","fragments":fragments}]}

static func get_port(items: Array, id: String) -> Dictionary:
	for item: Dictionary in items:
		if item.connector_id == id: return item
	return {}
static func kinked(value: Dictionary) -> Dictionary:
	for cell: Dictionary in value.surfaces:
		for k: int in cell.vertices.size(): cell.vertices[k].y = minf(cell.vertices[k].z,100.0-cell.vertices[k].z)*0.25
	for port: Dictionary in value.connectors: port.position.y = minf(port.position.z,100.0-port.position.z)*0.25
	value.connector_groups[0].position.y = 12.5
	return value
static func alter_group(value: Dictionary, field: String, target: Variant) -> void:
	value.connector_groups[0][field] = target
	for fragment: Dictionary in value.connector_groups[0].fragments: get_port(value.connectors,fragment.connector_id)[field] = target
static func realized(a: Dictionary, b: Dictionary, split: Dictionary) -> ExpeditionManifest:
	var stage := {"stage_id":"port_fixture","part_instances":[],"surfaces":a.surfaces.duplicate(true)+b.surfaces.duplicate(true),"connectors":[],"connections":a.internal_connections.duplicate(true)+b.internal_connections.duplicate(true),"volumes":[],"sockets":[]}
	for port: Dictionary in a.connectors+b.connectors:
		if port.connector_id not in split.consumed: stage.connectors.append(port.duplicate(true))
	stage.connectors.append_array(split.endpoints.duplicate(true)); stage.connections.append_array(split.connections.duplicate(true))
	var manifest := ExpeditionManifest.new(); manifest._data = {"input":{"parts":[]},"stages":[stage]}; return manifest
static func at(world: WorldGeometry, position: Vector3) -> ExpeditionWorldPoint:
	for cell: Dictionary in world._stage.surfaces:
		if Kernel.contains(cell,position): return ExpeditionWorldPoint.create(world._stage.stage_id,cell.surface_id,position)
	return null
static func instance_at(world: WorldGeometry, prefix: String, horizontal: Vector2) -> ExpeditionWorldPoint:
	for cell: Dictionary in world._stage.surfaces:
		if not cell.surface_id.begins_with(prefix+"/"): continue
		var position := Kernel.support_y(cell,Vector3(horizontal.x,0,horizontal.y))
		if Kernel.contains(cell,position): return ExpeditionWorldPoint.create(world._stage.stage_id,cell.surface_id,position)
	return null
static func walk(world: WorldGeometry, from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary) -> bool:
	var actor := WorldActorMotion.new()
	if not actor.configure(world,from,profile,"fragment_actor").ok: return false
	if not actor.plan(to,world.geometry_revision).ok: actor.release(); return false
	var budget := 1000
	while actor.has_route() and budget > 0:
		budget -= 1
		if not actor.advance(3.0).ok: actor.release(); return false
	var ok := budget > 0 and actor.point().surface_id == to.surface_id and actor.point().position.distance_to(to.position) < 0.001
	actor.release(); return ok
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_PORT_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
