class_name ExpeditionSurfaceDefinition
extends Resource
## A convex planar support cell, fan-triangulated in vertex order. Units are world units.
@export var surface_id: String = ""
@export var vertices: PackedVector3Array = PackedVector3Array()
@export var headroom: float = 0.0

func to_data() -> Dictionary:
	return {"surface_id": surface_id, "vertices": Array(vertices), "headroom": headroom}
