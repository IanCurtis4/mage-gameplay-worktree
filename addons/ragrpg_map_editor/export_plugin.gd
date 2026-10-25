@tool
extends EditorExportPlugin
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Objects = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
func _get_name() -> String: return "RagRPGAuthoredMapDependencies"
func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	# Runtime package integrity uses original dependency bytes, while Godot also
	# exports the imported GPU resources. Preserve both representations.
	var dependencies := Materials.dependencies()
	if dependencies.is_empty(): push_error("Dependências originais dos materiais do mapa ausentes."); return
	for dependency: Dictionary in dependencies:
		add_file(dependency.path,FileAccess.get_file_as_bytes(dependency.path),false)
	var catalog := Objects.load_catalog()
	if not catalog.ok: push_error("Catálogo de objetos ausente ou inválido no export."); return
	add_file(Objects.PATH,FileAccess.get_file_as_bytes(Objects.PATH),false)
	for dependency: Dictionary in catalog.dependencies:
		add_file(dependency.path,FileAccess.get_file_as_bytes(dependency.path),false)
		if FileAccess.file_exists(dependency.path+".import"): add_file(dependency.path+".import",FileAccess.get_file_as_bytes(dependency.path+".import"),false)
	var provenance := "res://assets/art/map_authoring/props/provenance.json"
	if FileAccess.file_exists(provenance): add_file(provenance,FileAccess.get_file_as_bytes(provenance),false)
