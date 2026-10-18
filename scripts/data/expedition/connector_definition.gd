class_name ExpeditionConnectorDefinition
extends Resource
@export var connector_id: String = ""
@export var surface_id: String = ""
@export var position: Vector3 = Vector3.ZERO
@export var outward: Vector3 = Vector3.ZERO
@export var width: float = 0.0
@export var headroom: float = 0.0
@export var kind: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export_enum("both", "in", "out") var direction: String = "both"

func to_data() -> Dictionary:
	var ordered := Array(tags)
	ordered.sort()
	return {"connector_id": connector_id, "surface_id": surface_id, "position": position,
		"outward": outward, "width": width, "headroom": headroom, "kind": kind,
		"tags": ordered, "direction": direction}
