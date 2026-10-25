@tool
extends EditorExportPlugin
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
func _get_name() -> String: return "RagRPGAuthoredMapDependencies"
func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	# Runtime package integrity uses original dependency bytes, while Godot also
	# exports the imported GPU resources. Preserve both representations.
	var dependencies := Materials.dependencies()
	if dependencies.is_empty(): push_error("Dependências originais dos materiais do mapa ausentes."); return
	for dependency: Dictionary in dependencies:
		add_file(dependency.path,FileAccess.get_file_as_bytes(dependency.path),false)
