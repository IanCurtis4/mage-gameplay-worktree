@tool
extends RefCounted
## Passive project catalog. Every returned value is a copy, never mutable catalog state.
const Reader = preload("res://scripts/map_authoring/io/strict_json.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const PATH := "res://data/map_authoring/prop_catalog.json"
const FIELDS := ["definition_id","revision","name","category","biome_ids","sprite_path","sprite_sha256","pivot_uv","world_height","footprint_radius","body_box_xyz","max_slope_degrees","allowed_rotations","rotation_mode","capabilities","origin"]

static func failure(code: String, id: String = "") -> Dictionary:
	var messages := {"object_catalog_missing":"O catálogo de objetos está ausente.","object_catalog_invalid":"O catálogo de objetos não é válido.","object_definition_missing":"A definição do objeto está ausente.","object_dependency_changed":"A definição ou o asset do objeto mudou.","object_asset_missing":"A imagem do objeto está ausente.","object_capability_unsupported":"Esta combinação de bloqueios não é representada pelo runtime."}
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"severity":"error","entity_id":id,"field":"placements","message":messages.get(code,"Revise o objeto indicado."),"suggestion":"Confira o catálogo e as dependências antes de compilar."}]}

static func load_catalog() -> Dictionary:
	if not FileAccess.file_exists(PATH): return failure("object_catalog_missing")
	var raw := Reader.new().decode(FileAccess.get_file_as_bytes(PATH))
	if not raw.ok or not raw.value is Dictionary: return failure("object_catalog_invalid")
	var data: Dictionary = raw.value
	if data.size() != 4 or not data.has_all(["schema_version","catalog_id","revision","definitions"]) or not _positive(data.schema_version) or data.schema_version != 1 or not data.catalog_id is String or data.catalog_id != "ragrpg_editor_props" or not _positive(data.revision) or data.revision != floor(float(data.revision)) or data.revision > 2147483647 or not data.definitions is Array or data.definitions.size() > 128: return failure("object_catalog_invalid")
	var definitions := {}; var dependencies: Array = []
	for value: Variant in data.definitions:
		if not value is Dictionary or value.size() != FIELDS.size() or not value.has_all(FIELDS): return failure("object_catalog_invalid")
		var item: Dictionary = value
		if not item.definition_id is String or item.definition_id.is_empty() or definitions.has(item.definition_id) or item.revision != 1 or not item.name is String or not item.category is String: return failure("object_catalog_invalid")
		if not item.sprite_path is String or not item.sprite_path.begins_with("res://assets/art/map_authoring/props/") or ".." in item.sprite_path or "\\" in item.sprite_path or not item.sprite_path.ends_with(".png"): return failure("object_catalog_invalid",item.definition_id)
		if not FileAccess.file_exists(item.sprite_path): return failure("object_asset_missing",item.definition_id)
		if FileAccess.get_sha256(item.sprite_path) != item.sprite_sha256: return failure("object_dependency_changed",item.definition_id)
		if not _numbers(item.pivot_uv,2) or not _numbers(item.body_box_xyz,6) or not _positive(item.world_height) or not _positive(item.footprint_radius) or not _positive(item.max_slope_degrees) or item.max_slope_degrees > 45: return failure("object_catalog_invalid",item.definition_id)
		for v: float in item.pivot_uv:
			if v < 0 or v > 1: return failure("object_catalog_invalid",item.definition_id)
		if not item.allowed_rotations is Array or item.allowed_rotations.is_empty() or item.allowed_rotations.size() > 4 or item.rotation_mode != "symmetric" or not item.biome_ids is Array: return failure("object_catalog_invalid",item.definition_id)
		for rotation: Variant in item.allowed_rotations:
			if not (rotation is int or rotation is float) or float(rotation) not in [0.0,90.0,180.0,270.0]: return failure("object_catalog_invalid",item.definition_id)
		if not item.capabilities is Dictionary or item.capabilities.size() != 4 or not item.capabilities.has_all(["decoration","body","attack_los","camera_occlusion"]): return failure("object_catalog_invalid",item.definition_id)
		for key: String in item.capabilities:
			if not item.capabilities[key] is bool: return failure("object_catalog_invalid",item.definition_id)
		if item.capabilities.body != item.capabilities.attack_los: return failure("object_capability_unsupported",item.definition_id)
		if item.capabilities.decoration == item.capabilities.body: return failure("object_catalog_invalid",item.definition_id)
		if item.capabilities.body and minf(item.body_box_xyz[3],minf(item.body_box_xyz[4],item.body_box_xyz[5])) <= 0: return failure("object_catalog_invalid",item.definition_id)
		if not item.origin is Dictionary or not item.origin.has_all(["kind","tool","license","record"]) or item.origin.license != "project_generated_output": return failure("object_catalog_invalid",item.definition_id)
		definitions[item.definition_id] = item.duplicate(true)
		dependencies.append({"definition_id":item.definition_id+"_sprite","revision":1,"path":item.sprite_path,"sha256":item.sprite_sha256})
	dependencies.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.definition_id < b.definition_id)
	return {"ok":true,"code":"","definitions":definitions,"dependencies":dependencies,"catalog_hash":Canonical.digest(data),"revision":int(data.revision)}

static func definition(id: String, catalog: Dictionary = {}) -> Dictionary:
	var current := catalog if not catalog.is_empty() else load_catalog()
	if not current.ok: return current
	if not current.definitions.has(id): return failure("object_definition_missing",id)
	return {"ok":true,"code":"","definition":current.definitions[id].duplicate(true)}

static func dependency(definition: Dictionary) -> Dictionary:
	return {"definition_id":definition.definition_id,"revision":int(definition.revision),"sha256":Canonical.digest(definition),"kind":"prop"}

static func _positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0

static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count: return false
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true
