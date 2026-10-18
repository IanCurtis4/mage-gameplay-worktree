class_name ExpeditionPolicyDefinition
extends Resource
## F0 resolves explicit versioned declarations; it does not execute future lifecycle policies.
@export var policy_id: String = ""
@export var revision: int = 0
@export var domain: String = ""
@export var parameters: Dictionary = {}

func to_data() -> Dictionary:
	return {"policy_id": policy_id, "revision": revision, "domain": domain, "parameters": parameters.duplicate(true)}
