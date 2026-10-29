@tool
extends RefCounted
## Ordered route edits use the same document and body/leash compiler as the GUI.
const Document = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Common = preload("res://scripts/map_authoring/population/population_operations.gd")
const FIELDS := {
	"name":{"name":"string"},
	"route/upsert":Document.ROUTE,
	"route/remove":{"patrol_id":"id","confirm_remove":"bool"},
	"waypoint/upsert":{"patrol_id":"id","point_id":"id","surface_id":"string","position_xyz":"v3","wait_seconds":"number"},
	"waypoint/remove":{"patrol_id":"id","point_id":"id","confirm_remove":"bool"},
	"waypoint/move":{"patrol_id":"id","point_id":"id","direction":"number"}}

static func fail(code: String, entity: String = "") -> Dictionary:
	var error := Common.fail(code,entity)
	error.diagnostics[0].field = "patrol"
	return error

static func propose(source: Dictionary, operation: String, parameters: Dictionary) -> Dictionary:
	if not FIELDS.has(operation): return fail("action_missing")
	var errors: Array = []
	Schema._shape(parameters,FIELDS[operation],"parameters",errors)
	if not errors.is_empty(): return fail("arguments_invalid")
	var checked := Document.validate(source)
	if not checked.ok: return checked
	var data: Dictionary = checked.data
	var entity: String = parameters.get("patrol_id",data.document_id)
	if operation == "name": data.name = parameters.name
	else:
		var route := Common.find(data.patrols,"patrol_id",parameters.patrol_id)
		if operation == "route/upsert":
			if route.is_empty(): data.patrols.append(parameters.duplicate(true))
			else:
				for key: String in parameters: route[key] = parameters[key].duplicate(true) if parameters[key] is Array else parameters[key]
		elif route.is_empty(): return fail("entity_missing",entity)
		elif operation == "route/remove":
			if not parameters.confirm_remove: return fail("confirmation_required",entity)
			data.patrols = data.patrols.filter(func(item: Dictionary) -> bool: return item.patrol_id != entity)
		else:
			entity = parameters.point_id
			var point := Common.find(route.waypoints,"point_id",entity)
			match operation:
				"waypoint/upsert":
					var value: Dictionary = parameters.duplicate(true); value.erase("patrol_id")
					if point.is_empty(): route.waypoints.append(value)
					else:
						for key: String in value: point[key] = value[key].duplicate(true) if value[key] is Array else value[key]
				"waypoint/remove":
					if point.is_empty(): return fail("entity_missing",entity)
					if not parameters.confirm_remove: return fail("confirmation_required",entity)
					route.waypoints = route.waypoints.filter(func(item: Dictionary) -> bool: return item.point_id != entity)
				"waypoint/move":
					if point.is_empty(): return fail("entity_missing",entity)
					if parameters.direction not in [-1,1]: return fail("arguments_invalid",entity)
					var index: int = route.waypoints.find(point); var other: int = index+int(parameters.direction)
					if other >= 0 and other < route.waypoints.size():
						var adjacent: Dictionary = route.waypoints[other]
						route.waypoints[other] = point; route.waypoints[index] = adjacent
	checked = Document.validate(data)
	if not checked.ok: return checked
	checked.entity_id = entity; checked.input_hash = Document.hash_source(source)
	checked.added_ids = []; checked.removed_ids = []
	for route: Dictionary in data.patrols:
		if Common.find(source.patrols,"patrol_id",route.patrol_id).is_empty(): checked.added_ids.append(route.patrol_id)
	for route: Dictionary in source.patrols:
		if Common.find(data.patrols,"patrol_id",route.patrol_id).is_empty(): checked.removed_ids.append(route.patrol_id)
	return checked
