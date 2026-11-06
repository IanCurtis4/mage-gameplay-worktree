@tool
extends EditorExportPlugin
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Objects = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
var _original_textures: Dictionary = {}
func _get_name() -> String: return "RagRPGAuthoredMapDependencies"
func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	_original_textures.clear()
	# Runtime package integrity uses original dependency bytes, while Godot also
	# exports the imported GPU resources. Preserve both representations.
	var dependencies := Materials.dependencies()
	if dependencies.is_empty(): push_error("Dependências originais dos materiais do mapa ausentes."); return
	for dependency: Dictionary in dependencies:
		if String(dependency.path).ends_with(".png"): _original_textures[dependency.path] = true
		add_file(dependency.path,FileAccess.get_file_as_bytes(dependency.path),false)
	var catalog := Objects.load_catalog()
	if not catalog.ok: push_error("Catálogo de objetos ausente ou inválido no export."); return
	add_file(Objects.PATH,FileAccess.get_file_as_bytes(Objects.PATH),false)
	for dependency: Dictionary in catalog.dependencies:
		_original_textures[dependency.path] = true
		add_file(dependency.path,FileAccess.get_file_as_bytes(dependency.path),false)
		if FileAccess.file_exists(dependency.path+".import"): add_file(dependency.path+".import",FileAccess.get_file_as_bytes(dependency.path+".import"),false)
	var provenance := "res://assets/art/map_authoring/props/provenance.json"
	if FileAccess.file_exists(provenance): add_file(provenance,FileAccess.get_file_as_bytes(provenance),false)

func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if not _original_textures.has(path): return
	# The normal texture exporter can overwrite our earlier original .import
	# with a stripped remap. Keep the certified bytes and ship the same imported
	# texture explicitly; this affects packaging only, never map publication.
	var settings := ConfigFile.new()
	if settings.load(path+".import") != OK:
		push_error("Importação original do mapa ausente: "+path); return
	var destinations := PackedStringArray(settings.get_value("deps","dest_files",PackedStringArray()))
	if destinations.is_empty():
		push_error("Textura importada do mapa ausente: "+path); return
	for destination: String in destinations:
		if not destination.begins_with("res://.godot/imported/") or not FileAccess.file_exists(destination):
			push_error("Dependência importada do mapa ausente: "+destination); return
	skip()
	add_file(path,FileAccess.get_file_as_bytes(path),false)
	add_file(path+".import",FileAccess.get_file_as_bytes(path+".import"),false)
	for destination: String in destinations:
		add_file(destination,FileAccess.get_file_as_bytes(destination),false)
