class_name ExpeditionManifest
extends RefCounted
var _data: Dictionary = {}

func to_data() -> Dictionary:
	return _data.duplicate(true)

func canonical_hash() -> String:
	return ExpeditionCanonical.digest(_data)

func surface(surface_id: String) -> Dictionary:
	for stage: Dictionary in _data["stages"]:
		for cell: Dictionary in stage["surfaces"]:
			if cell["surface_id"] == surface_id: return cell.duplicate(true)
	return {}

func connector(connector_id: String) -> Dictionary:
	for stage: Dictionary in _data["stages"]:
		for endpoint: Dictionary in stage["connectors"]:
			if endpoint["connector_id"] == connector_id: return endpoint.duplicate(true)
	return {}

func population_plan() -> ExpeditionPopulationPlan:
	var result := ExpeditionPopulationPlan.new()
	result._slots.assign(_data["population"]["slots"].duplicate(true))
	return result

func witness(obligation_id: String) -> Dictionary:
	return _data["witnesses"].get(obligation_id, {}).duplicate(true)
