@tool
extends RefCounted
const Document = preload("res://scripts/map_authoring/generation/generation_document.gd")
const Solver = preload("res://scripts/map_authoring/generation/generation_solver.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")

## Measurement adapter only. Production assembler and its policies remain unchanged.
## Rich parts share canonical geometry; external recipe cycles still exceed the tree API.
static func build(source: Dictionary) -> Dictionary:
	var checked := Document.validate(source)
	if not checked.ok: return checked
	if not source.map.get("context",{}).get("overrides",[]).is_empty(): return Document.fail("context_override_invalid")
	var domains := Document.domains(source)
	for id: String in domains:
		var instance := Compiler._find(source.map.instances,"instance_id",id)
		domains[id] = domains[id].filter(func(option: Dictionary) -> bool: return Compiler.Context.eligible(source.map,instance,Compiler._find(source.map.pieces,"piece_hash",option.piece_hash).source,true).ok)
		if domains[id].is_empty(): return Document.fail("contradiction",id)
	var ids: Array = domains.keys(); ids.sort()
	var root: String = ids[0]
	if source.map.links.size() != ids.size()-1: return Document.fail("assembler_unsupported","","tree")
	var parents := {root:{"parent":"","parent_connector":"","connector":""}}
	while parents.size() < ids.size():
		var previous := parents.size()
		var links: Array = source.map.links.duplicate(true); links.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.link_id < b.link_id)
		for link: Dictionary in links:
			if parents.has(link.a_instance) == parents.has(link.b_instance): continue
			var forward: bool = parents.has(link.a_instance)
			parents[link.b_instance if forward else link.a_instance] = {"parent":link.a_instance if forward else link.b_instance,"parent_connector":Compiler._port_id("",link.a_connector if forward else link.b_connector).trim_prefix("/"),"connector":Compiler._port_id("",link.b_connector if forward else link.a_connector).trim_prefix("/")}
		if parents.size() == previous: return Document.fail("assembler_unsupported","","tree")
	var input := ExpeditionGenerationInput.new()
	input.request_id = "editor_generation_comparison"; input.phase_id = "editor_generation_comparison"; input.entry_stage_id = "authored"
	input.seed_text = source.seed_text; input.generator_revision = ExpeditionAssembler.REVISION; input.recipe_revision = 1; input.catalog_revision = "editor_generation_v1"
	input.generation_policy_id = "editor_generation"; input.population_policy_id = "editor_population"
	for pair: Array in [["editor_generation","generation",{"max_attempts":1,"max_expansions":int(source.budget.operations)}],["editor_population","population",{}]]:
		var policy := ExpeditionPolicyDefinition.new(); policy.policy_id = pair[0]; policy.domain = pair[1]; policy.revision = 1; policy.parameters = pair[2]; input.policies.append(policy)
	var traversal := ExpeditionTraversalProfile.new(); traversal.profile_id = "editor_body"; traversal.revision = 1; traversal.radius = Terrain.PROFILE.radius; traversal.height = Terrain.PROFILE.height; traversal.connector_kinds = PackedStringArray(["walk"]); input.traversal = traversal
	var compiled := {}; var worlds := {}; var lookup := {}; var nodes: Array = []
	for id: String in ids:
		var candidates: Array = []
		for option: Dictionary in domains[id]:
			if not compiled.has(option.piece_hash):
				var piece := Compiler._find(source.map.pieces,"piece_hash",option.piece_hash)
				var built := Terrain.compile(piece.source)
				if not built.ok: return built
				compiled[option.piece_hash] = built.package
				var world := WorldGeometry.new(); world.configure(Terrain.preview_manifest(built.package),"terrain_preview"); worlds[option.piece_hash] = world
			var data: Dictionary = compiled[option.piece_hash].part
			var part := ExpeditionPartDefinition.new(); part.part_id = "p_"+(id+Document.option_key(option)).sha256_text().substr(0,24); part.revision = data.revision; part.biome_tags = PackedStringArray(["authored"]); part.allowed_rotations.assign([int(option.rotation_quarters)])
			for cell: Dictionary in data.surfaces:
				var surface := ExpeditionSurfaceDefinition.new(); surface.surface_id = cell.surface_id; surface.vertices = PackedVector3Array(cell.vertices); surface.headroom = cell.headroom; part.surfaces.append(surface)
			for port: Dictionary in data.connectors:
				var connector := ExpeditionConnectorDefinition.new()
				for key: String in ["connector_id","surface_id","position","outward","width","headroom","kind","direction"]: connector.set(key,port[key])
				connector.tags = PackedStringArray(port.tags); part.connectors.append(connector)
			# Synthetic entrance makes the comparison a generation-only request; no grants.
			var entry := Compiler._walkable_point(worlds[option.piece_hash],data.surfaces[0],Terrain.PROFILE,"terrain_preview")
			if entry == null: return Document.fail("assembler_constraint",id,"entrance")
			var socket := ExpeditionSocketDefinition.new(); socket.socket_id = "entry"; socket.surface_id = entry.surface_id; socket.kind = "entrance"; socket.position = entry.position; part.sockets.append(socket)
			part.solid_volumes.assign(data.solid_volumes); part.blockers.assign(data.blockers)
			part.solid_prisms.assign(data.get("solid_prisms",[])); part.internal_connections.assign(compiled[option.piece_hash].adjacency)
			part.connector_groups.assign(data.get("connector_groups",[]))
			input.parts.append(part); candidates.append(part.part_id); lookup[part.part_id] = option
		var node: Dictionary = parents[id].duplicate(true); node["instance_id"] = id; node["candidates"] = candidates; nodes.append(node)
	input.stages.assign([{"stage_id":"authored","biome":"authored","entrance":root+"/entry","parts":nodes}])
	var tick := Time.get_ticks_usec()
	var assembled := ExpeditionAssembler.build(input)
	var metrics := {"revision":ExpeditionAssembler.REVISION,"elapsed_ms":(Time.get_ticks_usec()-tick)/1000.0,"diagnostic":assembled.data.get("diagnostic",{}),"input_hash":ExpeditionCanonical.digest(input.to_data())}
	if not assembled.ok:
		var failed := Document.fail("assembler_constraint","",str(assembled.error_code)); failed.metrics = metrics; return failed
	var proposal: Dictionary = source.map.duplicate(true)
	var offset := Compiler._vector(Compiler._find(source.map.instances,"instance_id",root).position_xyz)
	var realized: Array = assembled.data.manifest.to_data().stages[0].part_instances
	for placement: Dictionary in realized:
		var instance := Compiler._find(proposal.instances,"instance_id",placement.instance_id)
		var position: Vector3 = placement.translation+offset
		if position.distance_to(Compiler._vector(instance.position_xyz)) > Compiler.EPS:
			var failed := Document.fail("assembler_constraint",placement.instance_id,"position"); failed.metrics = metrics; return failed
		instance.piece_hash = lookup[placement.part_id].piece_hash; instance.rotation_quarters = placement.rotation_quarters
	var chosen := {}
	for instance: Dictionary in proposal.instances: chosen[instance.instance_id] = [{"piece_hash":instance.piece_hash,"rotation_quarters":instance.rotation_quarters,"weight":1}]
	if not Solver.constraints_possible(source,chosen):
		var failed := Document.fail("assembler_constraint","","quota_or_diversity"); failed.metrics = metrics; return failed
	var built := Compiler.compile(proposal)
	if not built.ok: built.metrics = metrics; return built
	return {"ok":true,"code":"","proposal":proposal,"package":built.package,"output_hash":built.output_hash,"base_hash":Map.hash_source(source.map),"input_hash":checked.output_hash,"diff":Solver.diff(source.map,proposal),"metrics":metrics}
