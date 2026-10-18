class_name ExpeditionSocketDefinition
extends Resource
@export var socket_id: String = ""
@export var surface_id: String = ""
@export var position: Vector3 = Vector3.ZERO
@export_enum("entrance", "exit", "objective", "thematic_encounter", "population", "portal") var kind: String = ""
@export var tags: PackedStringArray = PackedStringArray()

func to_data() -> Dictionary:
	var ordered := Array(tags)
	ordered.sort()
	return {"socket_id": socket_id, "surface_id": surface_id, "position": position, "kind": kind, "tags": ordered}
