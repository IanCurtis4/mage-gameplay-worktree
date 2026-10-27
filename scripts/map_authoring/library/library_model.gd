@tool
extends RefCounted
const Preferences = preload("res://scripts/map_authoring/library/editor_preferences.gd")
const Props = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Borders = preload("res://scripts/map_authoring/composition/border_profile_catalog.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const CATEGORIES := {"trees":"Árvores","rocks":"Rochas","vegetation":"Vegetação","structures":"Estruturas","materials":"Materiais","biomes":"Bordas de bioma","pieces":"Peças salvas","maps":"Mapas salvos"}
const MATERIAL_NAMES := {"grass":"Grama","earth":"Terra","sand":"Areia","stone":"Pedra"}

static func builtin_presets() -> Array:
	var base := {"mode":"raise","shape":"circle","material":"earth","radius":120.0,"strength":12.0,"hardness":0.0,"target":0.0,"end_height":40.0}
	var soft := base.duplicate(true); soft.mode = "smooth"; soft.strength = 0.5; soft.radius = 80.0
	var path := base.duplicate(true); path.mode = "material"; path.strength = 0.65; path.radius = 28.0; path.hardness = 0.35
	return [{"id":"builtin_soft_hill","name":"Colina suave","options":base},{"id":"builtin_smooth_ground","name":"Suavizar relevo","options":soft},{"id":"builtin_earth_path","name":"Caminho de terra","options":path}]

static func presets(data: Dictionary) -> Array:
	if not Preferences.validate(data): return []
	return builtin_presets()+data.presets.duplicate(true)

static func preset(id: String, data: Dictionary) -> Dictionary:
	for entry: Dictionary in presets(data):
		if entry.id == id: return {"ok":true,"preset":entry.duplicate(true)}
	return {"ok":false,"code":"preset_missing"}

static func folded(text: String) -> String:
	var result := text.to_lower()
	for group: String in ["áàâãä","éèêë","íìîï","óòôõö","úùûü","ç"]:
		var replacement: String = {"á":"a","é":"e","í":"i","ó":"o","ú":"u","ç":"c"}[group[0]]
		for c: String in group: result = result.replace(c,replacement)
	return result

static func entries(data: Dictionary) -> Dictionary:
	if not Preferences.validate(data): return {"ok":false,"code":"preferences_invalid"}
	var props := Props.load_catalog()
	if not props.ok: return props
	var border := Borders.load_catalog()
	if not border.ok: return border
	if Materials.dependencies().is_empty(): return {"ok":false,"code":"material_missing"}
	var result: Array = []
	var ids: Array = props.definitions.keys(); ids.sort()
	for id: String in ids:
		var definition: Dictionary = props.definitions[id]
		result.append({"id":"prop:"+id,"kind":"prop","definition_id":id,"name":definition.name,"category":definition.category,"tags":definition.biome_ids.duplicate(),"revision":definition.revision,"thumbnail":definition.sprite_path,"source_hash":definition.sprite_sha256})
	for k: int in Materials.IDS.size():
		var id: String = Materials.IDS[k]
		result.append({"id":"material:"+id,"kind":"material","definition_id":id,"name":MATERIAL_NAMES[id],"category":"materials","tags":[id],"revision":1,"thumbnail":Materials.PATHS[k],"source_hash":FileAccess.get_sha256(Materials.PATHS[k])})
	ids = border.definitions.keys(); ids.sort()
	for id: String in ids:
		var definition: Dictionary = border.definitions[id]; var largest := 0
		for k: int in 4:
			if definition.material_weights[k] > definition.material_weights[largest]: largest = k
		result.append({"id":"border:"+id,"kind":"border","definition_id":id,"name":definition.name,"category":"biomes","tags":[str(definition.get("biome_id","transition"))],"revision":definition.revision,"thumbnail":Borders.WATER_PATH if definition.geometry == "unsupported_channel" else Materials.PATHS[largest],"source_hash":Schema.bytes_hash(JSON.stringify(definition,"",true,true).to_utf8_buffer())})
	result.append_array(source_entries(data))
	return {"ok":true,"entries":result}

static func source_entries(data: Dictionary) -> Array:
	var result: Array = []
	for source: Dictionary in data.sources:
		var item := source.duplicate(true); item["source_kind"] = item.kind; item.kind = "source"; item["category"] = "pieces" if source.kind == "piece" else "maps"; item["tags"] = [source.document_id]; item["thumbnail"] = ""
		result.append(item)
	return result

static func query(items: Array, text: String, category: String, favorites_only: bool, favorites: Array) -> Array:
	var result: Array = []; var tokens := folded(text.left(256).strip_edges()).split(" ",false)
	for item: Dictionary in items:
		if not category.is_empty() and item.category != category: continue
		if favorites_only and item.id not in favorites: continue
		var haystack := folded(str(item.name)+" "+str(item.id)+" "+CATEGORIES.get(item.category,item.category)+" "+" ".join(item.tags))
		var matches := true
		for token: String in tokens:
			if token not in haystack: matches = false; break
		if matches: result.append(item.duplicate(true))
	return result

static func describe_source(path: String, kind: String = "") -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path).replace("\\","/").simplify_path()
	if not absolute.is_absolute_path() or not absolute.to_lower().ends_with(".json") or kind not in ["","piece","map"]: return {"ok":false,"code":"library_source_invalid"}
	var raw := IO._bytes(absolute)
	if not raw.ok: return raw
	var parsed: Dictionary
	if kind == "map": parsed = MapDocument.read(raw.bytes)
	else:
		parsed = Schema.read(raw.bytes)
		if kind.is_empty() and not parsed.ok: parsed = MapDocument.read(raw.bytes); kind = "map"
		else: kind = "piece"
	if not parsed.ok: return parsed
	var data: Dictionary = parsed.data; var caption := str(data.name).strip_edges()
	if caption.is_empty(): caption = "Peça sem título" if kind == "piece" else "Mapa sem título"
	var entry := {"id":Preferences.source_id(absolute),"kind":kind,"path":absolute,"name":caption,"document_id":data.document_id,"revision":data.revision,"source_hash":parsed.output_hash,"byte_hash":Schema.bytes_hash(raw.bytes)}
	return {"ok":true,"entry":entry,"data":data.duplicate(true),"valid":parsed.get("valid",true),"diagnostics":parsed.get("diagnostics",[])}

static func register_source(path: String, kind: String = "") -> Dictionary:
	var described := describe_source(path,kind)
	if not described.ok: return described
	var saved := Preferences.transact({"operation":"source_register","entry":described.entry})
	if not saved.ok: return saved
	return described

static func duplicate_source(data: Dictionary, kind: String, new_id: String) -> Dictionary:
	if kind not in ["piece","map"] or not Schema._type(new_id,"id") or new_id == data.get("document_id"): return {"ok":false,"code":"library_source_invalid"}
	var copy := data.duplicate(true); copy.document_id = new_id; copy.revision = 1; copy.name = "Cópia de "+str(data.get("name",""))
	var checked := Schema.read(JSON.stringify(copy,"",true,true).to_utf8_buffer()) if kind == "piece" else MapDocument.validate(copy)
	return {"ok":true,"data":copy} if checked.ok else checked

static func _collect_scripts(directory: String, paths: Array[String]) -> void:
	var folder := DirAccess.open(directory)
	if folder == null: return
	for file: String in folder.get_files():
		if file.ends_with(".gd") or file.ends_with(".gdshader"): paths.append(directory.path_join(file))
	for child: String in folder.get_directories(): _collect_scripts(directory.path_join(child),paths)

static func thumbnail_environment() -> Dictionary:
	var paths: Array[String] = [Props.PATH,Borders.PATH]
	for directory: String in ["res://scripts/map_authoring","res://scripts/world","res://scripts/core/expedition"]: _collect_scripts(directory,paths)
	var props := Props.load_catalog()
	if not props.ok: return props
	var borders := Borders.load_catalog()
	if not borders.ok: return borders
	var dependencies := Materials.dependencies()
	if dependencies.is_empty(): return {"ok":false,"code":"material_missing"}
	dependencies.append_array(props.dependencies)
	for definition: Dictionary in borders.definitions.values():
		var found := Borders.dependencies(definition)
		if not found.ok: return found
		dependencies.append_array(found.dependencies)
	for dependency: Dictionary in dependencies:
		if dependency.path not in paths: paths.append(dependency.path)
		if dependency.path.ends_with(".png") and FileAccess.file_exists(dependency.path+".import") and dependency.path+".import" not in paths: paths.append(dependency.path+".import")
	paths.sort(); var hashes: Array = []
	for path: String in paths:
		if not FileAccess.file_exists(path): return {"ok":false,"code":"library_dependency_missing"}
		var hash := FileAccess.get_sha256(path)
		if hash.is_empty(): return {"ok":false,"code":"library_dependency_missing"}
		hashes.append([path,hash])
	return {"ok":true,"hash":Schema.bytes_hash(JSON.stringify([Engine.get_version_info(),hashes],"",true,true).to_utf8_buffer())}

static func _hash(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)

static func thumbnail_key(source_hash: String, environment_hash: String) -> String:
	return ("library_thumbnail_v1/"+source_hash+"/"+environment_hash).sha256_text() if _hash(source_hash) and _hash(environment_hash) else ""

static func thumbnail_path(key: String) -> String:
	return ProjectSettings.globalize_path("res://.godot/map_authoring/library/"+key+".png") if _hash(key) else ""

static func cached_thumbnail(source_hash: String, environment_hash: String) -> Dictionary:
	var key := thumbnail_key(source_hash,environment_hash); var path := thumbnail_path(key)
	if path.is_empty(): return {"ok":false,"code":"library_thumbnail_invalid"}
	var raw := IO._bytes(path+".json")
	if not raw.ok: return {"ok":false,"code":"library_thumbnail_missing"}
	var decoded := preload("res://scripts/map_authoring/io/strict_json.gd").new().decode(raw.bytes)
	if not decoded.ok or not Preferences._keys(decoded.value,["version","key","source_hash","environment_hash","png_sha256","package_hash"]): return {"ok":false,"code":"library_thumbnail_invalid"}
	var stamp: Dictionary = decoded.value
	if stamp.version != 1 or stamp.key != key or stamp.source_hash != source_hash or stamp.environment_hash != environment_hash or not _hash(stamp.package_hash) or not _hash(stamp.png_sha256) or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != stamp.png_sha256: return {"ok":false,"code":"library_thumbnail_invalid"}
	var image := Image.load_from_file(path)
	if image == null or image.get_width() != 256 or image.get_height() != 192: return {"ok":false,"code":"library_thumbnail_invalid"}
	return {"ok":true,"image":image,"key":key,"package_hash":stamp.package_hash}

static func save_thumbnail(source_hash: String, environment_hash: String, package_hash: String, image: Image) -> Dictionary:
	var key := thumbnail_key(source_hash,environment_hash); var path := thumbnail_path(key)
	if path.is_empty() or not _hash(package_hash) or image == null or image.is_empty(): return {"ok":false,"code":"library_thumbnail_invalid"}
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return {"ok":false,"code":"io_failure"}
	var resized := image.duplicate() as Image; resized.resize(256,192,Image.INTERPOLATE_LANCZOS)
	if resized.save_png(path+".pending") != OK: return {"ok":false,"code":"io_failure"}
	var stamp := {"version":1,"key":key,"source_hash":source_hash,"environment_hash":environment_hash,"png_sha256":FileAccess.get_sha256(path+".pending"),"package_hash":package_hash}
	if not IO._write(path+".json.pending",JSON.stringify(stamp,"",true,true).to_utf8_buffer()): return {"ok":false,"code":"io_failure"}
	if DirAccess.rename_absolute(path+".pending",path) != OK or DirAccess.rename_absolute(path+".json.pending",path+".json") != OK: return {"ok":false,"code":"io_failure"}
	return {"ok":true,"image":resized,"key":key}
