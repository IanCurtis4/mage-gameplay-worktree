@tool
extends RefCounted
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
var _data: Dictionary

func _init(data: Dictionary = {}) -> void:
	_data = data.duplicate(true)

func to_data() -> Dictionary: return _data.duplicate(true)
func semantic_hash() -> String: return Schema.semantic_hash(_data)
func diagnostics() -> Array: return Schema.validate(_data)

static func empty(document_id: String, display_name: String = "Peça sem título") -> Dictionary:
	return {"schema_version": 1, "document_id": document_id, "revision": 1,
		"units": "e07_world", "name": display_name, "dependencies": [], "layers": [],
		"special_surfaces": [], "placements": [], "regions": [], "connectors": [],
		"sockets": [], "composition": null}
