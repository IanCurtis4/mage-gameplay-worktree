class_name ExpeditionInputValidator
extends RefCounted

static func identity(value: Variant) -> bool:
	if not value is String or value.is_empty(): return false
	for character: String in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_": return false
	return true

static func strings(value: Variant, allow_empty: bool = false) -> bool:
	if not value is Array or (value.is_empty() and not allow_empty): return false
	var seen := {}
	for item: Variant in value:
		if not identity(item) or seen.has(item): return false
		seen[item] = true
	return true

static func shape(value: Dictionary, fields: Array[String]) -> bool:
	if value.size() != fields.size(): return false
	for field: String in fields:
		if not value.has(field): return false
	return true

static func failure(code: StringName, detail: String) -> Dictionary:
	return {"ok": false, "error_code": code, "detail": detail}

static func validate(input: ExpeditionGenerationInput) -> Dictionary:
	if input == null: return failure(&"invalid_payload", "null input")
	if not identity(input.request_id) or not identity(input.phase_id) or not identity(input.catalog_revision): return failure(&"invalid_identity", "input identity")
	if input.generator_revision != ExpeditionAssembler.REVISION: return failure(&"content_revision_unavailable", "generator_revision")
	if input.recipe_revision <= 0 or input.seed_text != str(input.seed_text.to_int()): return failure(&"invalid_recipe", "revision or signed int64 seed_text")
	if not ExpeditionCanonical.valid([input.stages,input.portals,input.objectives,input.population]): return failure(&"invalid_payload", "recipe value types/depth")
	var species_ids := {}
	for species: ExpeditionSpeciesDefinition in input.species:
		if species == null or not identity(species.species_id) or species.revision <= 0 or not strings(Array(species.biome_tags)) or not strings(Array(species.occurrence_categories)) or not strings(Array(species.required_site_tags),true): return failure(&"invalid_recipe", "species schema")
		if species_ids.has(species.species_id): return failure(&"duplicate_id", "species")
		species_ids[species.species_id] = true
	var profile := input.traversal
	if profile == null: return failure(&"policy_unresolved", "traversal")
	if not ExpeditionCanonical.valid(profile.to_data()) or not identity(profile.profile_id) or profile.revision <= 0 or profile.radius <= 0.0 or profile.height <= 0.0 or not strings(Array(profile.connector_kinds)): return failure(&"invalid_payload", "traversal")
	var policy_ids := {}
	for policy: ExpeditionPolicyDefinition in input.policies:
		if policy == null or not identity(policy.policy_id) or not identity(policy.domain) or policy.revision <= 0 or not ExpeditionCanonical.valid(policy.parameters): return failure(&"invalid_payload", "policy")
		if policy_ids.has(policy.policy_id): return failure(&"duplicate_id", policy.policy_id)
		policy_ids[policy.policy_id] = policy
	for pair: Array in [[input.generation_policy_id,"generation"],[input.population_policy_id,"population"]]:
		if not policy_ids.has(pair[0]) or policy_ids[pair[0]].domain != pair[1]: return failure(&"policy_unresolved", str(pair[0]))
	var budget: Dictionary = policy_ids[input.generation_policy_id].parameters
	if not shape(budget,["max_attempts","max_expansions"]) or not budget["max_attempts"] is int or not budget["max_expansions"] is int or budget["max_attempts"] <= 0 or budget["max_expansions"] <= 0: return failure(&"invalid_recipe", "finite search budget")
	var part_ids := {}
	for part: ExpeditionPartDefinition in input.parts:
		if part == null or not identity(part.part_id) or part.revision <= 0: return failure(&"invalid_identity", "part")
		if part_ids.has(part.part_id): return failure(&"duplicate_id", part.part_id)
		part_ids[part.part_id] = true
		if not strings(Array(part.biome_tags)) or part.allowed_rotations.is_empty(): return failure(&"invalid_recipe", part.part_id)
		var rotations := {}
		for rotation: int in part.allowed_rotations:
			if rotation < 0 or rotation > 3 or rotations.has(rotation): return failure(&"invalid_recipe", "rotation")
			rotations[rotation] = true
		var data := part.to_data()
		if data.is_empty() or not ExpeditionCanonical.valid(data) or part.surfaces.is_empty(): return failure(&"invalid_recipe", "nonfinite or empty part")
		var cells := {}
		for cell: Dictionary in data["surfaces"]:
			if not identity(cell["surface_id"]) or cells.has(cell["surface_id"]): return failure(&"duplicate_id", "surface")
			if not ExpeditionFixtureGeometry.valid_cell(cell): return failure(&"invalid_recipe", "convex planar surface")
			cells[cell["surface_id"]] = cell
		for index: int in range(data["surfaces"].size()):
			for previous: int in range(index):
				if ExpeditionFixtureGeometry.cells_overlap(data["surfaces"][index],data["surfaces"][previous]): return failure(&"invalid_recipe", "overlapping support cells")
		var connectors := {}
		for connector: Dictionary in data["connectors"]:
			if not identity(connector["connector_id"]) or connectors.has(connector["connector_id"]): return failure(&"duplicate_id", "connector")
			connectors[connector["connector_id"]] = true
			if not cells.has(connector["surface_id"]) or not identity(connector["kind"]) or not strings(connector["tags"]) or connector["width"] <= 0.0 or connector["headroom"] <= 0.0 or not connector["direction"] in ["both","in","out"]: return failure(&"invalid_recipe", "connector schema")
			if not ExpeditionFixtureGeometry.connector_valid(connector,cells[connector["surface_id"]]): return failure(&"incompatible_connector", part.part_id+"/"+connector["connector_id"])
		var sockets := {}
		for socket: Dictionary in data["sockets"]:
			if not identity(socket["socket_id"]) or sockets.has(socket["socket_id"]): return failure(&"duplicate_id", "socket")
			sockets[socket["socket_id"]] = true
			if not cells.has(socket["surface_id"]) or not strings(socket["tags"],true) or not socket["kind"] in ["entrance","exit","objective","thematic_encounter","population","portal"]: return failure(&"invalid_recipe", "socket schema")
			if not ExpeditionFixtureGeometry.contains(cells[socket["surface_id"]],socket["position"]): return failure(&"invalid_recipe", "socket off support")
		for volumes: Array in [data["solid_volumes"],data["blockers"]]:
			for volume: AABB in volumes:
				if volume.size.x <= 0 or volume.size.y <= 0 or volume.size.z <= 0: return failure(&"invalid_recipe", "volume extent")
	var stage_ids := {}
	var nodes_by_stage := {}
	if input.stages.is_empty(): return failure(&"invalid_recipe", "no stages")
	for stage: Dictionary in input.stages:
		if not shape(stage,["stage_id","biome","entrance","parts"]) or not identity(stage["stage_id"]) or not identity(stage["biome"]) or not stage["entrance"] is String or not stage["parts"] is Array or stage["parts"].is_empty(): return failure(&"invalid_recipe", "stage schema")
		if stage_ids.has(stage["stage_id"]): return failure(&"duplicate_id", "stage")
		stage_ids[stage["stage_id"]] = true
		var nodes := {}
		var roots := 0
		for raw: Variant in stage["parts"]:
			if not raw is Dictionary: return failure(&"invalid_recipe", "node type")
			var node: Dictionary = raw
			if not shape(node,["instance_id","candidates","parent","parent_connector","connector"]) or not identity(node["instance_id"]) or not strings(node["candidates"]): return failure(&"invalid_recipe", "node schema")
			for field: String in ["parent","parent_connector","connector"]:
				if not node[field] is String: return failure(&"invalid_recipe", "node reference type")
			if nodes.has(node["instance_id"]): return failure(&"duplicate_id", "instance")
			nodes[node["instance_id"]] = node
			for candidate: String in node["candidates"]:
				if not part_ids.has(candidate): return failure(&"content_revision_unavailable", candidate)
			if node["parent"].is_empty():
				roots += 1
				if node["parent_connector"] != "" or node["connector"] != "": return failure(&"invalid_recipe", "root connector")
			elif not identity(node["parent"]) or not identity(node["parent_connector"]) or not identity(node["connector"]): return failure(&"invalid_recipe", "attachment identity")
		if roots != 1: return failure(&"invalid_recipe", "one root per stage")
		for node: Dictionary in nodes.values():
			var visited := {}
			var current: Dictionary = node
			while not current["parent"].is_empty():
				if visited.has(current["instance_id"]) or not nodes.has(current["parent"]): return failure(&"invalid_recipe", "cyclic or missing parent")
				visited[current["instance_id"]] = true
				current = nodes[current["parent"]]
		nodes_by_stage[stage["stage_id"]] = nodes
	if not stage_ids.has(input.entry_stage_id): return failure(&"invalid_recipe", "entry_stage_id")
	var portal_ids := {}
	for portal: Dictionary in input.portals:
		if not shape(portal,["portal_id","from_stage","from_socket","to_stage","to_socket","kind"]) or not identity(portal["portal_id"]) or portal["kind"] != "travel": return failure(&"invalid_recipe", "portal schema")
		if portal_ids.has(portal["portal_id"]): return failure(&"duplicate_id", "portal")
		portal_ids[portal["portal_id"]] = true
		if not stage_ids.has(portal["from_stage"]) or not stage_ids.has(portal["to_stage"]) or portal["from_stage"] == portal["to_stage"] or not portal["from_socket"] is String or not portal["to_socket"] is String: return failure(&"invalid_recipe", "portal references")
	var obligation_ids := {}
	for objective: Dictionary in input.objectives:
		if not shape(objective,["objective_id","revision","stage_id","instance_id","socket_id","required_tags","outcome","required"]) or not identity(objective["objective_id"]) or not objective["revision"] is int or objective["revision"] <= 0 or not objective["required"] is bool or not objective["outcome"] in ["objective","phase_completion","early_exit"]: return failure(&"invalid_recipe", "objective schema")
		var checked := obligation(objective,"objective_id",stage_ids,nodes_by_stage,obligation_ids)
		if not checked["ok"]: return checked
	for slot: Dictionary in input.population:
		if not shape(slot,["slot_id","species_id","occurrence_category","origin_id","stage_id","instance_id","socket_id","required_tags","respawn_policy_id","reward_policy_id","blocks_clear"]): return failure(&"invalid_recipe", "population schema")
		for field: String in ["slot_id","species_id","occurrence_category","origin_id","respawn_policy_id","reward_policy_id"]:
			if not identity(slot[field]): return failure(&"invalid_identity", field)
		if not species_ids.has(slot["species_id"]): return failure(&"incompatible_species", slot["species_id"])
		if not slot["blocks_clear"] is bool: return failure(&"invalid_recipe", "blocks_clear")
		var checked := obligation(slot,"slot_id",stage_ids,nodes_by_stage,obligation_ids)
		if not checked["ok"]: return checked
		for pair: Array in [[slot["respawn_policy_id"],"respawn"],[slot["reward_policy_id"],"reward"]]:
			if not policy_ids.has(pair[0]) or policy_ids[pair[0]].domain != pair[1]: return failure(&"policy_unresolved", str(pair[0]))
	return {"ok": true, "error_code": &"", "detail": ""}

static func obligation(value: Dictionary, key: String, stages: Dictionary, nodes: Dictionary, seen: Dictionary) -> Dictionary:
	if seen.has(value[key]): return failure(&"duplicate_id", str(value[key]))
	seen[value[key]] = true
	if not identity(value["stage_id"]) or not stages.has(value["stage_id"]) or not identity(value["instance_id"]) or not nodes[value["stage_id"]].has(value["instance_id"]) or not identity(value["socket_id"]) or not strings(value["required_tags"],true): return failure(&"invalid_recipe", "obligation references")
	return {"ok": true}
