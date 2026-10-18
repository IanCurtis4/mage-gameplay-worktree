extends RefCounted
## Artificial policies/geometry only. No game catalog, save or approved production tuning.

static func cell(id: String, west_height: float = 0.0, east_height: float = 0.0) -> ExpeditionSurfaceDefinition:
	var result := ExpeditionSurfaceDefinition.new()
	result.surface_id = id
	result.vertices = PackedVector3Array([Vector3(0,west_height,0),Vector3(10,east_height,0),Vector3(10,east_height,10),Vector3(0,west_height,10)])
	result.headroom = 4.0
	return result

static func connector(id: String, point: Vector3, normal: Vector3) -> ExpeditionConnectorDefinition:
	var result := ExpeditionConnectorDefinition.new()
	result.connector_id = id
	result.surface_id = "floor"
	result.position = point
	result.outward = normal
	result.width = 4.0
	result.headroom = 4.0
	result.kind = "walk"
	result.tags = PackedStringArray(["fixture"])
	result.direction = "both"
	return result

static func socket(id: String, kind: String, point: Vector3, tags: Array[String] = []) -> ExpeditionSocketDefinition:
	var result := ExpeditionSocketDefinition.new()
	result.socket_id = id
	result.surface_id = "floor"
	result.position = point
	result.kind = kind
	result.tags = PackedStringArray(tags)
	return result

static func part(id: String, west_height: float = 0.0, east_height: float = 0.0) -> ExpeditionPartDefinition:
	var result := ExpeditionPartDefinition.new()
	result.part_id = id
	result.revision = 1
	result.biome_tags = PackedStringArray(["fixture_biome"])
	result.allowed_rotations.assign([0,1,2,3])
	result.surfaces.append(cell("floor",west_height,east_height))
	result.connectors.assign([connector("west",Vector3(0,west_height,5),Vector3.LEFT),connector("east",Vector3(10,east_height,5),Vector3.RIGHT)])
	return result

static func policy(id: String, domain: String, parameters: Dictionary) -> ExpeditionPolicyDefinition:
	var result := ExpeditionPolicyDefinition.new()
	result.policy_id = id
	result.domain = domain
	result.revision = 1
	result.parameters = parameters.duplicate(true)
	return result

static func node(id: String, candidates: Array[String], parent: String = "", parent_connector: String = "", endpoint: String = "") -> Dictionary:
	return {"instance_id": id,"candidates": candidates.duplicate(),"parent": parent,"parent_connector": parent_connector,"connector": endpoint}

static func make(seed_text: String = "42") -> ExpeditionGenerationInput:
	var input := ExpeditionGenerationInput.new()
	input.request_id = "fixture_request"
	input.phase_id = "fixture_branch_phase"
	input.entry_stage_id = "entry"
	input.seed_text = seed_text
	input.generator_revision = ExpeditionAssembler.REVISION
	input.recipe_revision = 1
	input.catalog_revision = "fixture_catalog_v1"
	input.generation_policy_id = "fixture_generation"
	input.population_policy_id = "fixture_population"
	input.policies.assign([policy("fixture_generation","generation",{"max_attempts":32,"max_expansions":4096}),policy("fixture_population","population",{"fixture_only":true}),policy("fixture_reward","reward",{"fixture_only":true}),policy("fixture_respawn","respawn",{"fixture_only":true})])
	var traversal := ExpeditionTraversalProfile.new()
	traversal.profile_id = "fixture_actor"
	traversal.revision = 1
	traversal.radius = 0.5
	traversal.height = 2.0
	traversal.connector_kinds = PackedStringArray(["walk"])
	input.traversal = traversal
	for id: String in ["fixture_gel","fixture_keeper"]:
		var species := ExpeditionSpeciesDefinition.new()
		species.species_id = id
		species.revision = 1
		species.biome_tags = PackedStringArray(["fixture_biome"])
		species.occurrence_categories = PackedStringArray(["normal"] if id == "fixture_gel" else ["boss"])
		species.required_site_tags = PackedStringArray(["field"] if id == "fixture_gel" else ["shrine"])
		input.species.append(species)
	var hub := part("hub")
	hub.allowed_rotations.assign([0])
	hub.connectors.append(connector("north",Vector3(5,0,10),Vector3.BACK))
	hub.sockets.assign([socket("entry","entrance",Vector3(2,0,2)),socket("out_a","portal",Vector3(7,0,2)),socket("out_b","portal",Vector3(7,0,7))])
	var wing_a := part("wing_a")
	wing_a.sockets.assign([socket("home","population",Vector3(4,0,5),["field"]),socket("goal","objective",Vector3(6,0,7),["quest"])])
	var wing_b := part("wing_b")
	wing_b.sockets.assign([socket("home","population",Vector3(6,0,5),["field"]),socket("goal","objective",Vector3(4,0,7),["quest"])])
	var ramp := part("ramp",0.0,4.0)
	var high := part("high",4.0,4.0)
	high.sockets.assign([socket("boss","thematic_encounter",Vector3(5,4,5),["shrine"]),socket("finish","exit",Vector3(8,4,8),["final"])])
	input.parts.assign([hub,wing_a,wing_b,ramp,high])
	for stage_id: String in ["entry","left","right"]:
		input.stages.append({"stage_id":stage_id,"biome":"fixture_biome","entrance":"root/entry","parts":[node("root",["hub"]),node("field",["wing_a","wing_b"],"root","east","west"),node("slope",["ramp"],"root","north","west"),node("shrine",["high"],"slope","east","west")]})
		input.population.append({"slot_id":stage_id+"_field","species_id":"fixture_gel","occurrence_category":"normal","origin_id":"fixture_origin","stage_id":stage_id,"instance_id":"field","socket_id":"home","required_tags":["field"],"respawn_policy_id":"fixture_respawn","reward_policy_id":"fixture_reward","blocks_clear":true})
		input.population.append({"slot_id":stage_id+"_boss","species_id":"fixture_keeper","occurrence_category":"boss","origin_id":"fixture_origin","stage_id":stage_id,"instance_id":"shrine","socket_id":"boss","required_tags":["shrine"],"respawn_policy_id":"fixture_respawn","reward_policy_id":"fixture_reward","blocks_clear":true})
	input.objectives.append({"objective_id":"quest_left","revision":1,"stage_id":"left","instance_id":"field","socket_id":"goal","required_tags":["quest"],"outcome":"objective","required":true})
	for destination: String in ["left","right"]:
		input.portals.append({"portal_id":"entry_to_"+destination,"from_stage":"entry","from_socket":"root/out_a" if destination == "left" else "root/out_b","to_stage":destination,"to_socket":"root/entry","kind":"travel"})
		input.portals.append({"portal_id":destination+"_to_entry","from_stage":destination,"from_socket":"root/out_a","to_stage":"entry","to_socket":"root/entry","kind":"travel"})
	return input

static func sources_current() -> bool:
	# A filtered test run must not silently execute an old staged copy.
	var root_path := FileAccess.get_file_as_string("res://source_root.txt")
	var hashes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://source_hashes.json"))
	if root_path.is_empty() or not hashes is Dictionary: return false
	for file: String in hashes:
		if FileAccess.get_sha256(root_path.path_join(file)) != hashes[file]: return false
	return true
