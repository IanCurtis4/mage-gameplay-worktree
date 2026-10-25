@tool
extends RefCounted
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_schema.gd")
signal changed
var _document: Document
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var generation := 0
var saved_hash := ""

func document() -> Document: return _document

func replace(data: Dictionary) -> Dictionary:
	var read := Schema.read(JSON.stringify(data, "", true, true).to_utf8_buffer())
	if not read.ok: return read
	_document = Document.new(read.data)
	_undo.clear()
	_redo.clear()
	generation += 1
	changed.emit()
	return read

func apply(data: Dictionary) -> Dictionary:
	if _document == null: return Schema.result(false, "source_missing")
	if data.get("document_id") != _document.to_data().document_id: return Schema.result(false, "base_diverged")
	var next := data.duplicate(true)
	next.revision = int(_document.to_data().revision) + 1
	var read := Schema.read(JSON.stringify(next, "", true, true).to_utf8_buffer())
	if not read.ok: return read
	if not read.diagnostics.is_empty(): return Schema.result(false, read.diagnostics[0].code, read.diagnostics)
	read.input_hash = _document.semantic_hash()
	_undo.append(_document.to_data())
	_redo.clear()
	_document = Document.new(read.data)
	generation += 1
	changed.emit()
	return read

func undo() -> bool:
	if _undo.is_empty(): return false
	_redo.append(_document.to_data())
	_document = Document.new(_undo.pop_back())
	generation += 1
	changed.emit()
	return true

func redo() -> bool:
	if _redo.is_empty(): return false
	_undo.append(_document.to_data())
	_document = Document.new(_redo.pop_back())
	generation += 1
	changed.emit()
	return true

func dirty() -> bool: return _document != null and _document.semantic_hash() != saved_hash
func can_undo() -> bool: return not _undo.is_empty()
func can_redo() -> bool: return not _redo.is_empty()

func duplicate_layer(layer_id: String) -> Dictionary:
	var data := _document.to_data()
	var selected: Dictionary = {}
	for layer: Dictionary in data.layers:
		if layer.layer_id == layer_id: selected = layer
	if selected.is_empty(): return Schema.result(false, "source_reference_missing")
	var new_layer_id := _new_id("layer")
	var surface_remap := {layer_id:new_layer_id}
	var region_remap := {}; var placement_remap := {}
	var added_regions: Array = []
	for region: Dictionary in data.regions:
		if region.layer_id != layer_id: continue
		var copy := region.duplicate(true)
		region_remap[region.region_id] = _new_id("region")
		copy.region_id = region_remap[region.region_id]
		copy.layer_id = new_layer_id
		added_regions.append(copy)
	data.regions.append_array(added_regions)
	var added_surfaces: Array = []
	for surface: Dictionary in data.special_surfaces:
		if surface.layer_id != layer_id: continue
		var copy := surface.duplicate(true)
		surface_remap[surface.surface_id] = _new_id("surface")
		copy.surface_id = surface_remap[surface.surface_id]
		copy.layer_id = new_layer_id
		added_surfaces.append(copy)
	data.special_surfaces.append_array(added_surfaces)
	var layer_copy := selected.duplicate(true)
	layer_copy.layer_id = new_layer_id
	layer_copy.name += " (cópia)"
	for i: int in layer_copy.protected_regions.size(): layer_copy.protected_regions[i] = region_remap[layer_copy.protected_regions[i]]
	data.layers.append(layer_copy)
	for collection: String in ["placements", "connectors", "sockets"]:
		var additions: Array = []
		for entry: Dictionary in data[collection]:
			if not surface_remap.has(entry.surface_id): continue
			var copy := entry.duplicate(true)
			var id_key: String = Schema.IDS[collection]
			copy[id_key] = _new_id(collection)
			if collection == "placements": placement_remap[entry.placement_id] = copy[id_key]
			copy.surface_id = surface_remap[entry.surface_id]
			additions.append(copy)
		data[collection].append_array(additions)
	Objects.duplicate_metadata(data,placement_remap,func(_group: String) -> String: return _new_id("object_group"))
	if data.has("context"):
		for area: Dictionary in data.context.areas.duplicate(true):
			if not region_remap.has(area.region_id): continue
			var copy := area.duplicate(true); copy.region_id = region_remap[area.region_id]
			for encounter: Dictionary in copy.reserved: encounter.encounter_id = _new_id("encounter")
			data.context.areas.append(copy)
	return apply(data)

func _new_id(prefix: String) -> String:
	return prefix + "_" + Crypto.new().generate_random_bytes(12).hex_encode()
