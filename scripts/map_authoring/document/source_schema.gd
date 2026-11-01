@tool
extends RefCounted
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_schema.gd")
const IDS := {"dependencies": "definition_id", "layers": "layer_id", "special_surfaces": "surface_id", "placements": "placement_id", "regions": "region_id", "connectors": "connector_id", "sockets": "socket_id"}
const ROOT := {"schema_version": "int", "document_id": "id", "revision": "int", "units": "string", "name": "string", "dependencies": "array", "layers": "array", "special_surfaces": "array", "placements": "array", "regions": "array", "connectors": "array", "sockets": "array", "composition": "reference"}
const REFERENCE := {"document_id": "id", "revision": "int", "sha256": "hash"}
const FIELDS := {
	"dependencies": {"definition_id": "id", "revision": "int", "sha256": "hash", "kind": "id"},
	"layers": {"layer_id": "id", "name": "string", "origin_xz": "v2", "sample_spacing": "number", "columns": "int", "rows": "int", "heights": "numbers", "material_masks": "masks", "locked": "bool", "protected_regions": "strings"},
	"special_surfaces": {"surface_id": "id", "layer_id": "id", "vertices_xyz": "points3", "headroom": "number"},
	"placements": {"placement_id": "id", "definition_id": "id", "revision": "int", "position_xyz": "v3", "rotation_y": "number", "surface_id": "id"},
	"regions": {"region_id": "id", "layer_id": "id", "polygon_xz": "points2", "purpose": "id"},
	"connectors": {"connector_id": "id", "surface_id": "id", "position_xyz": "v3", "kind": "id", "normal_xyz": "v3", "width": "number", "headroom": "number", "tags": "strings", "direction": "id"},
	"sockets": {"socket_id": "id", "surface_id": "id", "position_xyz": "v3", "kind": "id"}}

static func result(ok: bool, code: String = "", diagnostics: Array = []) -> Dictionary:
	return {"ok": ok, "code": code, "diagnostics": diagnostics, "input_hash": "", "output_hash": ""}

static func read(bytes: PackedByteArray) -> Dictionary:
	var decoded: Dictionary = StrictJSON.new().decode(bytes)
	var output := result(false, decoded.code)
	output.byte_hash = bytes_hash(bytes)
	if not decoded.ok: return output
	if not decoded.value is Dictionary:
		output.code = "source_invalid_type"
		return output
	var data: Dictionary = decoded.value
	var errors: Array = []
	var root_fields := ROOT.duplicate(); if data.has("context"): root_fields.context = "object"
	if data.has("objects"): root_fields.objects = "object"
	# Checkpoint46 (P3d): optional receipts of regional variations (root only).
	if data.has("synthesis_receipts"): root_fields.synthesis_receipts = "array"
	_shape(data, root_fields, "$", errors)
	if errors.is_empty() and data.schema_version != 1:
		output.code = "source_version_unsupported"
		return output
	if errors.is_empty():
		for collection: String in IDS:
			if data[collection].size() > 4096:
				_issue(errors, "source_limit_exceeded", collection)
				break
			for entry: Variant in data[collection]: _shape(entry, FIELDS[collection], collection, errors)
	if not errors.is_empty():
		output.code = errors[0].code
		output.diagnostics = errors
		return output
	output = result(true, "", validate(data))
	output.valid = output.diagnostics.is_empty()
	output.byte_hash = bytes_hash(bytes)
	output.data = data.duplicate(true)
	output.output_hash = semantic_hash(data)
	output.input_hash = output.output_hash
	return output

static func _shape(value: Variant, fields: Dictionary, path: String, errors: Array) -> void:
	if not value is Dictionary:
		_issue(errors, "source_invalid_type", path)
		return
	for key: Variant in value:
		if not fields.has(key): _issue(errors, "source_unknown_field", path + "." + str(key))
	for key: String in fields:
		if not value.has(key) or not _type(value.get(key), fields[key]): _issue(errors, "source_invalid_type", path + "." + key)

static func _type(value: Variant, kind: String) -> bool:
	match kind:
		"string": return value is String and value.length() <= StrictJSON.MAX_STRING
		"id":
			if not value is String or value.is_empty() or value.length() > 128: return false
			for c: String in value:
				if not c in "abcdefghijklmnopqrstuvwxyz0123456789_-.:": return false
			return true
		"hash": return value is String and value.length() == 64 and value.is_valid_hex_number(false)
		"number": return (value is int or value is float) and is_finite(float(value))
		"int": return _type(value, "number") and float(value) == floor(float(value)) and value >= 1 and value <= 2147483647
		"bool": return value is bool
		"array": return value is Array
		"object": return value is Dictionary
		"v2", "v3", "numbers":
			if not value is Array: return false
			if kind == "v2" and value.size() != 2: return false
			if kind == "v3" and value.size() != 3: return false
			for number: Variant in value:
				if not _type(number, "number"): return false
			return true
		"strings", "points2", "points3":
			if not value is Array: return false
			for item: Variant in value:
				if not _type(item, "id" if kind == "strings" else ("v2" if kind == "points2" else "v3")): return false
			return true
		"masks":
			if not value is Dictionary: return false
			for key: Variant in value:
				if not _type(key, "id") or not _type(value[key], "numbers"): return false
			return true
		"reference":
			if value == null: return true
			var errors: Array = []
			_shape(value, REFERENCE, "composition", errors)
			return errors.is_empty()
	return false

static func _issue(errors: Array, code: String, field: String, entity_id: String = "") -> void:
	errors.append({"code": code, "severity": "error", "entity_id": entity_id, "field": field,
		"message": "Revise o campo %s (%s)." % [field, code], "suggestion": "Corrija a fonte antes de compilar."})

static func validate(data: Dictionary) -> Array:
	var errors: Array = []
	if data.has("objects"):
		var checked_objects := Objects.validate(data.objects,data.placements,load("res://scripts/map_authoring/document/source_schema.gd"))
		if not checked_objects.ok:
			if checked_objects.diagnostics.is_empty(): _issue(errors,checked_objects.code,"objects")
			else: errors.append_array(checked_objects.diagnostics)
	if data.has("context"):
		var checked := Context.validate(data.context,data.regions,load("res://scripts/map_authoring/document/source_schema.gd"))
		if not checked.ok: errors.append_array(checked.diagnostics)
	if data.has("synthesis_receipts") and not load("res://scripts/map_authoring/synthesis/receipt_schema.gd").valid(data.synthesis_receipts): _issue(errors, "receipts_invalid", "synthesis_receipts")
	if data.units != "e07_world": _issue(errors, "source_units_unsupported", "units")
	var ids: Dictionary = {}
	for collection: String in IDS:
		ids[collection] = {}
		for entry: Dictionary in data[collection]:
			var id: String = entry[IDS[collection]]
			if ids[collection].has(id): _issue(errors, "source_duplicate_id", collection, id)
			ids[collection][id] = entry
	for layer: Dictionary in data.layers:
		var count: int = int(layer.columns) * int(layer.rows)
		if layer.columns < 2 or layer.rows < 2 or layer.columns > 257 or layer.rows > 257 or layer.sample_spacing <= 0: _issue(errors, "source_grid_invalid", "dimensions", layer.layer_id)
		if layer.heights.size() != count: _issue(errors, "source_sample_count", "heights", layer.layer_id)
		for material: String in layer.material_masks:
			if layer.material_masks[material].size() != count: _issue(errors, "source_sample_count", "material_masks", layer.layer_id)
			for weight: float in layer.material_masks[material]:
				if weight < 0 or weight > 1: _issue(errors, "source_mask_invalid", "material_masks", layer.layer_id)
		for region_id: String in layer.protected_regions:
			if not ids.regions.has(region_id) or ids.regions[region_id].layer_id != layer.layer_id: _issue(errors, "source_reference_missing", "protected_regions", layer.layer_id)
	var surfaces: Dictionary = ids.layers.duplicate()
	for surface: Dictionary in data.special_surfaces:
		if surfaces.has(surface.surface_id): _issue(errors, "source_duplicate_id", "surface_id", surface.surface_id)
		surfaces[surface.surface_id] = surface
		if not ids.layers.has(surface.layer_id): _issue(errors, "source_reference_missing", "layer_id", surface.surface_id)
		if surface.vertices_xyz.size() < 3 or surface.headroom <= 0: _issue(errors, "source_geometry_invalid", "special_surfaces", surface.surface_id)
	for region: Dictionary in data.regions:
		if not ids.layers.has(region.layer_id): _issue(errors, "source_reference_missing", "layer_id", region.region_id)
		if region.polygon_xz.size() < 3: _issue(errors, "source_geometry_invalid", "polygon_xz", region.region_id)
	for collection: String in ["placements", "connectors", "sockets"]:
		for entry: Dictionary in data[collection]:
			if not surfaces.has(entry.surface_id): _issue(errors, "source_reference_missing", "surface_id", entry[IDS[collection]])
			if collection == "placements":
				if not ids.dependencies.has(entry.definition_id) or ids.dependencies[entry.definition_id].revision != entry.revision: _issue(errors, "dependency_missing", "definition_id", entry.placement_id)
			if collection == "connectors" and (entry.width <= 0 or entry.headroom <= 0 or entry.direction not in ["both", "in", "out"] or Vector3(entry.normal_xyz[0], entry.normal_xyz[1], entry.normal_xyz[2]).length_squared() == 0): _issue(errors, "source_connector_invalid", "connectors", entry.connector_id)
	return errors

static func bytes_hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func semantic_hash(data: Dictionary) -> String:
	var normalized := data.duplicate(true)
	if normalized.has("objects"):
		normalized.objects.groups.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.group_id < b.group_id)
		normalized.objects.states.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.placement_id < b.placement_id)
	for collection: String in IDS:
		if normalized.has(collection):
			var id_key: String = IDS[collection]
			normalized[collection].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a[id_key]) < str(b[id_key]))
	return bytes_hash(_canonical(normalized).to_utf8_buffer())

static func _canonical(value: Variant) -> String:
	if value == null: return "n"
	if value is bool: return "t" if value else "f"
	if value is int or value is float:
		var bytes := PackedByteArray()
		bytes.resize(8)
		bytes.encode_double(0, 0.0 if value == 0 else float(value))
		return "d" + bytes.hex_encode()
	if value is String or value is StringName: return "s" + JSON.stringify(String(value))
	var parts := PackedStringArray()
	if value is Array:
		for item: Variant in value: parts.append(_canonical(item))
		return "a%d[%s]" % [value.size(), ",".join(parts)]
	# Dictionary dot assignment can introduce StringName keys. Sort textual keys
	# before encoding, so GUI additions and JSON reads have identical identity.
	var keys: Array[String] = []
	for key: Variant in value.keys(): keys.append(String(key))
	keys.sort()
	for key: String in keys: parts.append(_canonical(key) + ":" + _canonical(value[key]))
	return "o%d{%s}" % [keys.size(), ",".join(parts)]
