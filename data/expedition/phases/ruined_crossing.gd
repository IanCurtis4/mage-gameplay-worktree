extends RefCounted
## Authored small D07 recipe. All geometry is realized by ExpeditionAssembler.
const PHASE_ID := "ruined_crossing"
const TITLE := "Travessia das Ruínas"
const STAGES := ["entry", "left", "right", "final"]

static func surface(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> ExpeditionSurfaceDefinition:
	var value := ExpeditionSurfaceDefinition.new()
	value.surface_id = "floor"
	value.vertices = PackedVector3Array([Vector3(x0,y0,z0), Vector3(x1,y1,z0), Vector3(x1,y1,z1), Vector3(x0,y0,z1)])
	value.headroom = 128.0
	return value

static func socket(id: String, kind: String, position: Vector3, tags: Array[String] = []) -> ExpeditionSocketDefinition:
	var value := ExpeditionSocketDefinition.new()
	value.socket_id = id; value.kind = kind; value.position = position
	value.surface_id = "floor"; value.tags = PackedStringArray(tags)
	return value

static func endpoint(id: String, position: Vector3, outward: Vector3) -> ExpeditionConnectorDefinition:
	var value := ExpeditionConnectorDefinition.new()
	value.connector_id = id; value.position = position; value.outward = outward
	value.surface_id = "floor"; value.width = 120.0; value.headroom = 128.0
	value.kind = "walk"; value.tags = PackedStringArray(["ruins"]); value.direction = "both"
	return value

static func part(id: String, cell: ExpeditionSurfaceDefinition) -> ExpeditionPartDefinition:
	var value := ExpeditionPartDefinition.new()
	value.part_id = id; value.revision = 1
	value.biome_tags = PackedStringArray(["ruins"]); value.allowed_rotations.assign([0])
	value.surfaces.assign([cell])
	return value

static func policy(id: String, domain: String, parameters: Dictionary) -> ExpeditionPolicyDefinition:
	var value := ExpeditionPolicyDefinition.new()
	value.policy_id = id; value.revision = 1; value.domain = domain; value.parameters = parameters.duplicate(true)
	return value

static func input(seed_text: String) -> ExpeditionGenerationInput:
	var value := ExpeditionGenerationInput.new()
	value.request_id = "ruined_crossing_generation"; value.phase_id = PHASE_ID
	value.entry_stage_id = "entry"; value.seed_text = seed_text
	value.generator_revision = ExpeditionAssembler.REVISION; value.recipe_revision = 1
	value.catalog_revision = "ruined_crossing_v1"
	value.generation_policy_id = "ruins_generation"; value.population_policy_id = "ruins_population"
	value.policies.assign([policy("ruins_generation", "generation", {"max_attempts": 8, "max_expansions": 2048}), policy("ruins_population", "population", {"revision": 1}), policy("ruins_rewards", "reward", {"policy_id": "e07_initial"}), policy("ruins_respawn", "respawn", {"policy_id": "e07_initial"})])
	value.traversal = ExpeditionTraversalProfile.new()
	value.traversal.profile_id = "ruins_player"; value.traversal.revision = 1
	value.traversal.radius = 20.0; value.traversal.height = 32.0
	value.traversal.connector_kinds = PackedStringArray(["walk"])
	var court := part("ruins_court", surface(0,300,0,600,0,0))
	court.connectors.assign([endpoint("east", Vector3(300,0,150), Vector3.RIGHT)])
	court.sockets.assign([socket("entry", "entrance", Vector3(60,0,150)), socket("side", "portal", Vector3(150,0,90)), socket("main", "portal", Vector3(150,0,510)), socket("field", "population", Vector3(150,0,360), ["field"])])
	var ramp := part("ruins_ramp", surface(300,600,0,300,0,120))
	ramp.connectors.assign([endpoint("west", Vector3(300,0,150), Vector3.LEFT), endpoint("east", Vector3(600,120,150), Vector3.RIGHT)])
	var landing := part("ruins_landing", surface(600,900,0,600,120,120))
	landing.connectors.assign([endpoint("west", Vector3(600,120,150), Vector3.LEFT), endpoint("bridge", Vector3(600,120,450), Vector3.LEFT)])
	value.parts.assign([court,ramp,landing])
	for variant: int in 2:
		var bridge := part("ruins_bridge_%d" % variant, surface(0,600,300,600 + variant * 60,120,120))
		bridge.connectors.assign([endpoint("east", Vector3(600,120,450), Vector3.RIGHT)])
		bridge.sockets.assign([socket("keeper", "thematic_encounter", Vector3(330,120,450), ["shrine"]), socket("finish", "exit", Vector3(450,120,510), ["final"]), socket("rest", "objective", Vector3(120,120,450), ["rest"])])
		bridge.solid_volumes.assign([AABB(Vector3(0,108,300), Vector3(600,12,300 + variant * 60))])
		value.parts.append(bridge)
	for species_id: String in ["pilot_trail_species", "pilot_precision_species", "pilot_frost_species", "pilot_bulwark_species"]:
		var species := ExpeditionSpeciesDefinition.new()
		species.species_id = species_id; species.revision = 1
		species.biome_tags = PackedStringArray(["ruins"])
		species.occurrence_categories = PackedStringArray(["normal", "rare", "rare_elite"])
		value.species.append(species)
	for stage_id: String in STAGES:
		value.stages.append({"stage_id": stage_id, "biome": "ruins", "entrance": "root/entry", "parts": [{"instance_id": "root", "candidates": ["ruins_court"], "parent": "", "parent_connector": "", "connector": ""}, {"instance_id": "ramp", "candidates": ["ruins_ramp"], "parent": "root", "parent_connector": "east", "connector": "west"}, {"instance_id": "landing", "candidates": ["ruins_landing"], "parent": "ramp", "parent_connector": "east", "connector": "west"}, {"instance_id": "bridge", "candidates": ["ruins_bridge_0", "ruins_bridge_1"], "parent": "landing", "parent_connector": "bridge", "connector": "east"}]})
		var index := STAGES.find(stage_id)
		var category := "rare_elite" if stage_id == "final" else "normal"
		var species: String = ["pilot_trail_species", "pilot_precision_species", "pilot_frost_species", "pilot_bulwark_species"][index]
		value.population.append(slot(stage_id + "_guard", stage_id, "root", "field", species, category, index))
	value.population.append(slot("entry_keeper", "entry", "bridge", "keeper", "pilot_bulwark_species", "rare", 0))
	for edge: Array in [["entry", "left", "side"], ["left", "entry", "side"], ["entry", "right", "main"], ["right", "entry", "side"], ["right", "final", "main"], ["final", "right", "side"]]:
		value.portals.append({"portal_id": edge[0] + "_to_" + edge[1], "from_stage": edge[0], "from_socket": "root/" + edge[2], "to_stage": edge[1], "to_socket": "root/entry", "kind": "travel"})
	value.objectives.assign([{"objective_id": "final_exit", "revision": 1, "stage_id": "final", "instance_id": "bridge", "socket_id": "finish", "required_tags": ["final"], "outcome": "phase_completion", "required": true}, {"objective_id": "side_rest", "revision": 1, "stage_id": "left", "instance_id": "bridge", "socket_id": "rest", "required_tags": ["rest"], "outcome": "early_exit", "required": false}])
	return value

static func slot(id: String, stage: String, instance: String, socket_id: String, species: String, category: String, index: int) -> Dictionary:
	return {"slot_id": id, "species_id": species, "occurrence_category": category, "origin_id": "trial_stage_%d" % (index + 1), "stage_id": stage, "instance_id": instance, "socket_id": socket_id, "required_tags": ["shrine"] if socket_id == "keeper" else ["field"], "respawn_policy_id": "ruins_respawn", "reward_policy_id": "ruins_rewards", "blocks_clear": true}

static func rules(manifest: ExpeditionManifest) -> Dictionary:
	var result := {}
	for record: Dictionary in manifest.population_plan().slots():
		var index: int = STAGES.find(record["stage_id"]) + 1
		result[record["slot_id"]] = {"trash": record["occurrence_category"] == "normal", "base_xp": index * 10, "job_xp": index * 8}
	return result
