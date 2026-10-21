extends RefCounted
const Base = preload("res://tests/fixtures/e07/f0/fixture_input.gd")

static func input(seed_text: String = "20261021") -> ExpeditionGenerationInput:
	var result := Base.make(seed_text)
	result.phase_id = "f5_fixture_phase"
	var final: Dictionary = result.stages[0].duplicate(true)
	final["stage_id"] = "final"
	result.stages.append(final)
	var additional: Array[Dictionary] = []
	for slot: Dictionary in result.population:
		if slot["stage_id"] == "entry":
			var copy := slot.duplicate(true)
			copy["stage_id"] = "final"
			copy["slot_id"] = copy["slot_id"].replace("entry", "final")
			additional.append(copy)
	result.population.append_array(additional)
	for slot: Dictionary in result.population:
		slot["species_id"] = "test_gel" if slot["occurrence_category"] == "normal" else "test_beast_master"
		slot["origin_id"] = "trial_stage_%d" % (["entry", "left", "right", "final"].find(slot["stage_id"]) + 1)
	for species: ExpeditionSpeciesDefinition in result.species:
		species.species_id = "test_gel" if species.species_id == "fixture_gel" else "test_beast_master"
	result.portals.append({"portal_id": "right_to_final", "from_stage": "right", "from_socket": "root/out_b", "to_stage": "final", "to_socket": "root/entry", "kind": "travel"})
	result.portals.append({"portal_id": "final_to_right", "from_stage": "final", "from_socket": "root/out_a", "to_stage": "right", "to_socket": "root/entry", "kind": "travel"})
	result.objectives[0]["outcome"] = "early_exit"
	result.objectives[0]["required"] = false
	result.objectives.append({"objective_id": "final_exit", "revision": 1, "stage_id": "final", "instance_id": "shrine", "socket_id": "finish", "required_tags": ["final"], "outcome": "phase_completion", "required": true})
	# Explicit artificial geometry scale, not a production density/layout contract.
	for part: ExpeditionPartDefinition in result.parts:
		for surface: ExpeditionSurfaceDefinition in part.surfaces:
			for index: int in surface.vertices.size():
				var vertex := surface.vertices[index] * 64.0
				vertex.y *= 1.25 # exact 1:2 ramp ratio avoids a float32 coplanarity artifact
				surface.vertices[index] = vertex
			surface.headroom *= 64.0
		for connector: ExpeditionConnectorDefinition in part.connectors:
			connector.position *= 64.0
			connector.position.y *= 1.25
			connector.width *= 64.0
			connector.headroom *= 64.0
		for socket: ExpeditionSocketDefinition in part.sockets:
			socket.position *= 64.0
			socket.position.y *= 1.25
	result.traversal.radius = 20.0
	result.traversal.height = 32.0
	return result

static func rules(manifest: ExpeditionManifest) -> Dictionary:
	var result := {}
	for slot: Dictionary in manifest.population_plan().slots():
		# Artificial XP oracles, explicitly by origin, not production balancing.
		var origin_index := int(String(slot["origin_id"]).get_slice("_", 2))
		result[slot["slot_id"]] = {"trash": slot["occurrence_category"] == "normal", "base_xp": 10 * origin_index, "job_xp": 8 * origin_index}
	return result
