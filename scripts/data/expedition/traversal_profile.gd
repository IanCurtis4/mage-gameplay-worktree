class_name ExpeditionTraversalProfile
extends Resource
@export var profile_id: String = ""
@export var revision: int = 0
@export var radius: float = 0.0
@export var height: float = 0.0
@export var connector_kinds: PackedStringArray = PackedStringArray()

func to_data() -> Dictionary:
	var kinds := Array(connector_kinds)
	kinds.sort()
	return {"profile_id": profile_id, "revision": revision, "radius": radius, "height": height, "connector_kinds": kinds}
