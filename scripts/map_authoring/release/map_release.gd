@tool
extends RefCounted
## Checkpoint48 (F9-11, P5): the consumption point for the next epics.
## A released map is an immutable patrol package (.rpp: "RPP1", the sha256 of the
## payload, then var_to_bytes of the package; read with bytes_to_var, which never
## instantiates objects) listed in data/map_authoring/release_packages.json with
## its pinned package_hash and source_hash. Consumers ask for a package_id and use
## load_package(), manifest() or prepare(); they never read map sources, editor
## sessions, caches or the player profile. Publishing a new revision of a map is
## a new .rpp and a new registry entry hash, never an edit of the bytes.
## Checkpoint49 (F9-11, P6b): publish() is the editor's "Publicar no jogo": the
## source, a new <id>.<hash12>.rpp (an older revision stays on disk) and the
## registry entry, after the person confirmed plan_publication(). Every function
## takes the folder of the registry (data/map_authoring by default; tests use a
## scratch folder).
const Store = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const Compiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const Document = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
const REGISTRY := "res://data/map_authoring/release_packages.json"
const FOLDER := "res://data/map_authoring/"
const VERSION := 1
const MAX_PACKAGES := 64
const MAX_REGISTRY_BYTES := 64 * 1024
const KEYS := ["package_id","name","kind","path","source_path","compiler_revision","source_hash","package_hash"]

static func fail(code: String, id: String = "") -> Dictionary:
	var messages := {"release_registry_invalid":"A lista de mapas publicados está inválida ou incompleta.","release_entry_invalid":"Escolha um identificador (minúsculas, dígitos, _ ou -) e um nome visível para o mapa.","release_registry_changed":"A lista de mapas publicados mudou depois da revisão; revise de novo.","release_registry_full":"A lista de mapas publicados está cheia.","release_stale_source":"As patrulhas mudaram depois da compilação; valide de novo antes de publicar.","release_io":"Não foi possível gravar a publicação; nada foi alterado na lista.","immutable_conflict":"Já existe outro pacote com este nome; nada foi sobrescrito.","release_unknown":"Não há mapa publicado com este identificador.","release_package_invalid":"O pacote publicado está ausente, incompleto ou foi alterado.","release_package_mismatch":"O pacote publicado não é o que a lista de mapas fixa; publique de novo.","release_source_missing":"A fonte deste mapa não está neste projeto."}
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"severity":"error","entity_id":id,"field":"release","message":messages.get(code,"Mapa publicado recusado: "+code)}]}

static func _local(path: Variant, suffix: String, folder: String = FOLDER) -> bool:
	return path is String and path.begins_with(folder) and path.ends_with(suffix) and not path.contains("..") and not path.trim_prefix(folder).contains("/") and path.length() <= 256

static func valid_id(value: Variant) -> bool:
	return Schema._type(value,"id") and not value.contains(".") and not value.contains(":") and value == value.to_lower() and value.length() <= 64

static func valid_name(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 120

static func registry_path(folder: String = FOLDER) -> String: return folder.path_join("release_packages.json")

static func valid_entry(entry: Variant, folder: String = FOLDER) -> bool:
	if not entry is Dictionary or entry.size() != KEYS.size() or not entry.has_all(KEYS): return false
	if not valid_id(entry.package_id) or not valid_name(entry.name): return false
	if entry.kind != "patrol" or entry.compiler_revision != Compiler.REVISION: return false
	if not _local(entry.path,".rpp",folder) or not _local(entry.source_path,".patrol.json",folder): return false
	return Schema._type(entry.source_hash,"hash") and Schema._type(entry.package_hash,"hash") and entry.source_hash == entry.source_hash.to_lower() and entry.package_hash == entry.package_hash.to_lower()

## The registry as data: {"registry_version":1,"packages":[entry...]}.
static func valid_registry(value: Variant, folder: String = FOLDER) -> bool:
	if not value is Dictionary or value.size() != 2 or not value.has_all(["registry_version","packages"]): return false
	if not (value.registry_version is int or value.registry_version is float) or float(value.registry_version) != float(VERSION): return false
	if not value.packages is Array or value.packages.size() > MAX_PACKAGES: return false
	var ids := {}; var paths := {}
	for entry: Variant in value.packages:
		if not valid_entry(entry,folder) or ids.has(entry.package_id) or paths.has(entry.path): return false
		ids[entry.package_id] = true; paths[entry.path] = true
	return true

static func registry(folder: String = FOLDER) -> Dictionary:
	var path := registry_path(folder)
	if not FileAccess.file_exists(path): return fail("release_registry_invalid")
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() > MAX_REGISTRY_BYTES: return fail("release_registry_invalid")
	var decoded := StrictJSON.new().decode(bytes)
	if not decoded.ok or not valid_registry(decoded.value,folder): return fail("release_registry_invalid")
	return {"ok":true,"code":"","registry":decoded.value,"registry_hash":FileAccess.get_sha256(path)}

static func _listing(listing: Dictionary, folder: String = FOLDER) -> Dictionary:
	if listing.is_empty(): return registry(folder)
	return {"ok":true,"code":"","registry":listing} if valid_registry(listing,folder) else fail("release_registry_invalid")

## [{package_id, name}] in registry order, for menus and campaign tables.
static func packages(listing: Dictionary = {}) -> Array:
	var read := _listing(listing)
	var result: Array = []
	if not read.ok: return result
	for entry: Dictionary in read.registry.packages: result.append({"package_id":entry.package_id,"name":entry.name})
	return result

static func entry(package_id: String, listing: Dictionary = {}, folder: String = FOLDER) -> Dictionary:
	var read := _listing(listing,folder)
	if not read.ok: return read
	for item: Dictionary in read.registry.packages:
		if item.package_id == package_id: return {"ok":true,"code":"","entry":item.duplicate(true)}
	return fail("release_unknown",package_id)

## The validated immutable package, only if its hashes are the pinned ones.
static func load_package(package_id: String, listing: Dictionary = {}, folder: String = FOLDER) -> Dictionary:
	var found := entry(package_id,listing,folder)
	if not found.ok: return found
	var pinned: Dictionary = found.entry
	var loaded := Store.load_package(pinned.path)
	if not loaded.ok: return fail("release_package_invalid",package_id)
	var package: Dictionary = loaded.package
	if package.package_hash != pinned.package_hash or package.source_hash != pinned.source_hash or package.compiler_revision != pinned.compiler_revision: return fail("release_package_mismatch",package_id)
	return {"ok":true,"code":"","entry":pinned,"package":package}

## The ExpeditionManifest of the package (stages, surfaces, sockets, objectives,
## portals, population slots with patrols). A copy: callers may not edit the package.
static func manifest(package_id: String, listing: Dictionary = {}) -> Dictionary:
	var loaded := load_package(package_id,listing)
	if not loaded.ok: return loaded
	return {"ok":true,"code":"","entry":loaded.entry,"package":loaded.package,"manifest":Compiler.manifest(loaded.package)}

## Runtime only (never inside the editor): the same preparation as the gameplay
## test — entrance and every surface, objective and portal reachable by the real
## body, encounter homes and patrol routes certified by the game authorities.
## Returns manifest, rules, map_package, entry point and candidate_hash.
static func prepare(package_id: String, listing: Dictionary = {}) -> Dictionary:
	var loaded := load_package(package_id,listing)
	if not loaded.ok: return loaded
	var made := Candidate.create("patrol",loaded.package,loaded.package.source_hash)
	if not made.ok: return made
	var prepared := Candidate.prepare(made.candidate)
	if not prepared.ok: return prepared
	prepared["package"] = loaded.package; prepared["release"] = loaded.entry
	return prepared

## Authoring checks only: whether the committed source still produces the pinned
## source_hash (a changed source needs a new publication).
static func freshness(package_id: String, listing: Dictionary = {}) -> Dictionary:
	var found := entry(package_id,listing)
	if not found.ok: return found
	if not FileAccess.file_exists(found.entry.source_path): return fail("release_source_missing",package_id)
	var source := Store.load_source(found.entry.source_path)
	if not source.ok: return source
	var current := Document.hash_source(source.data)
	return {"ok":true,"code":"","current":current == found.entry.source_hash,"source_hash":current,"pinned_source_hash":found.entry.source_hash}

static func package_file(package_id: String, package_hash: String) -> String: return package_id+"."+package_hash.substr(0,12)+".rpp"
static func source_file(package_id: String) -> String: return package_id+".patrol.json"

## The registry as it is now (an absent registry in a scratch folder is empty).
static func _current(folder: String) -> Dictionary:
	if not FileAccess.file_exists(registry_path(folder)):
		return {"ok":true,"code":"","registry":{"registry_version":VERSION,"packages":[]},"registry_hash":""} if folder != FOLDER else fail("release_registry_invalid")
	return registry(folder)

## What publishing would change, for the confirmation. Never writes.
static func plan_publication(package_id: String, name: String, package: Dictionary, folder: String = FOLDER) -> Dictionary:
	if not valid_id(package_id) or not valid_name(name): return fail("release_entry_invalid",package_id)
	var read := _current(folder)
	if not read.ok: return read
	var previous: Dictionary = {}
	for item: Dictionary in read.registry.packages:
		if item.package_id == package_id: previous = item.duplicate(true)
	if previous.is_empty() and read.registry.packages.size() >= MAX_PACKAGES: return fail("release_registry_full",package_id)
	var source_path := folder.path_join(source_file(package_id))
	return {"ok":true,"code":"","package_id":package_id,"name":name.strip_edges(),"new":previous.is_empty(),"previous":previous,"package_hash":package.get("package_hash",""),"source_hash":package.get("source_hash",""),"path":folder.path_join(package_file(package_id,String(package.get("package_hash","")))),"source_path":source_path,"source_exists":FileAccess.file_exists(source_path),"unchanged":previous.get("package_hash","") == package.get("package_hash","x") and previous.get("name","") == name.strip_edges(),"registry_hash":read.registry_hash}

static func _write(path: String, bytes: PackedByteArray) -> bool:
	var temporary := path+".tmp"+str(OS.get_process_id())
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes); file.flush(); var error := file.get_error(); file.close()
	if error != OK or FileAccess.get_file_as_bytes(temporary) != bytes: DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary)); return false
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path)) != OK: return false
	return FileAccess.get_file_as_bytes(path) == bytes

## Publishes after confirmation: source, package (new file, never overwritten),
## then the registry entry, only if the registry is still the reviewed one.
static func publish(package_id: String, name: String, package: Dictionary, source: Dictionary, registry_hash: String, folder: String = FOLDER) -> Dictionary:
	var plan := plan_publication(package_id,name,package,folder)
	if not plan.ok: return plan
	if plan.registry_hash != registry_hash: return fail("release_registry_changed",package_id)
	if not Document.validate(source).ok or Document.hash_source(source) != package.get("source_hash",""): return fail("release_stale_source",package_id)
	if not Compiler.validate_package(package): return fail("release_package_invalid",package_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var payload := var_to_bytes(package)
	var bytes := ("RPP1"+Schema.bytes_hash(payload)).to_utf8_buffer()+payload
	if bytes.size() > Compiler.MAX_PACKAGE_BYTES: return fail("release_package_invalid",package_id)
	if FileAccess.file_exists(plan.path):
		if FileAccess.get_file_as_bytes(plan.path) != bytes: return fail("immutable_conflict",package_id)
	elif not _write(plan.path,bytes): return fail("release_io",package_id)
	# The source is rewritten only when it is not already the published one.
	var existing: Dictionary = Store.load_source(plan.source_path) if plan.source_exists else {"ok":false}
	if not existing.ok or Document.hash_source(existing.data) != package.source_hash:
		if not _write(plan.source_path,JSON.stringify(source,"\t",true,true).to_utf8_buffer()): return fail("release_io",package_id)
	var pinned := {"package_id":package_id,"name":plan.name,"kind":"patrol","path":plan.path,"source_path":plan.source_path,"compiler_revision":package.compiler_revision,"source_hash":package.source_hash,"package_hash":package.package_hash}
	var listing: Dictionary = _current(folder).registry.duplicate(true)
	var replaced := false
	for index: int in listing.packages.size():
		if listing.packages[index].package_id == package_id: listing.packages[index] = pinned; replaced = true
	if not replaced: listing.packages.append(pinned)
	listing.registry_version = VERSION
	if not valid_registry(listing,folder): return fail("release_registry_invalid",package_id)
	if FileAccess.file_exists(registry_path(folder)) and FileAccess.get_sha256(registry_path(folder)) != registry_hash: return fail("release_registry_changed",package_id)
	if not _write(registry_path(folder),(JSON.stringify(listing,"\t",false)+"\n").to_utf8_buffer()): return fail("release_io",package_id)
	var check := entry(package_id,{},folder)
	if not check.ok or check.entry != pinned: return fail("release_io",package_id)
	return {"ok":true,"code":"","entry":pinned,"previous":plan.previous,"new":plan.new,"path":plan.path,"source_path":plan.source_path}
