class_name ExpeditionGenerationInput
extends RefCounted

var request_id: String = ""
var phase_id: String = ""
var entry_stage_id: String = ""
var seed_text: String = ""
var generator_revision: String = ""
var recipe_revision: int = 0
var catalog_revision: String = ""
var parts: Array[ExpeditionPartDefinition] = []
var policies: Array[ExpeditionPolicyDefinition] = []
var species: Array[ExpeditionSpeciesDefinition] = []
var traversal: ExpeditionTraversalProfile
## Exact schemas are validated before search; arrays are sets ordered by their declared IDs.
var stages: Array[Dictionary] = []
var portals: Array[Dictionary] = []
var objectives: Array[Dictionary] = []
var population: Array[Dictionary] = []
var generation_policy_id: String = ""
var population_policy_id: String = ""

func to_data() -> Dictionary:
	var definitions: Array[Dictionary] = []
	var species_data: Array[Dictionary] = []
	for entry: ExpeditionSpeciesDefinition in species:
		if entry == null: return {}
		species_data.append(entry.to_data())
	species_data.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["species_id"] < b["species_id"])
	var declarations: Array[Dictionary] = []
	for part: ExpeditionPartDefinition in parts:
		if part == null: return {}
		definitions.append(part.to_data())
	for policy: ExpeditionPolicyDefinition in policies:
		if policy == null: return {}
		declarations.append(policy.to_data())
	definitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("part_id", "") < b.get("part_id", ""))
	declarations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["policy_id"] < b["policy_id"])
	var stage_data := stages.duplicate(true)
	for stage: Dictionary in stage_data:
		if stage.get("parts") is Array:
			stage["parts"].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("instance_id", "") < b.get("instance_id", ""))
			for node: Dictionary in stage["parts"]:
				if node.get("candidates") is Array: node["candidates"].sort()
	stage_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("stage_id", "") < b.get("stage_id", ""))
	var collections: Array[Array] = [portals.duplicate(true), objectives.duplicate(true), population.duplicate(true)]
	var keys := ["portal_id", "objective_id", "slot_id"]
	for index: int in range(collections.size()):
		for item: Dictionary in collections[index]:
			if item.has("required_tags"): item["required_tags"].sort()
		collections[index].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get(keys[index], "") < b.get(keys[index], ""))
	return {"phase_id": phase_id, "entry_stage_id": entry_stage_id, "seed_text": seed_text, "generator_revision": generator_revision,
		"recipe_revision": recipe_revision, "catalog_revision": catalog_revision, "species": species_data, "catalog_hash": ExpeditionCanonical.digest(species_data), "parts": definitions,
		"part_hashes": definitions.map(func(p: Dictionary) -> Dictionary: return {"part_id": p.get("part_id", ""), "hash": ExpeditionCanonical.digest(p)}),
		"policies": declarations, "traversal": traversal.to_data() if traversal != null else {},
		"recipe_hash": ExpeditionCanonical.digest({"revision": recipe_revision,"stages": stage_data,"portals": collections[0],"objectives": collections[1],"population": collections[2]}),
		"stages": stage_data, "portals": collections[0], "objectives": collections[1], "population": collections[2],
		"generation_policy_id": generation_policy_id, "population_policy_id": population_policy_id}
