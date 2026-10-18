class_name ExpeditionWorldPoint
extends RefCounted

var stage_id: String = ""
var surface_id: String = ""
var position: Vector3 = Vector3.ZERO

static func create(stage: String, surface: String, point: Vector3) -> ExpeditionWorldPoint:
	var result := ExpeditionWorldPoint.new()
	result.stage_id = stage
	result.surface_id = surface
	result.position = point
	return result

func to_data() -> Dictionary:
	return {"stage_id": stage_id, "surface_id": surface_id, "position": position}
