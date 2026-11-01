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
	var messages := {"release_registry_invalid":"A lista de mapas publicados está inválida ou incompleta.","release_unknown":"Não há mapa publicado com este identificador.","release_package_invalid":"O pacote publicado está ausente, incompleto ou foi alterado.","release_package_mismatch":"O pacote publicado não é o que a lista de mapas fixa; publique de novo.","release_source_missing":"A fonte deste mapa não está neste projeto."}
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"severity":"error","entity_id":id,"field":"release","message":messages.get(code,"Mapa publicado recusado: "+code)}]}

static func _local(path: Variant, suffix: String) -> bool:
	return path is String and path.begins_with(FOLDER) and path.ends_with(suffix) and not path.contains("..") and not path.trim_prefix(FOLDER).contains("/") and path.length() <= 256

static func valid_entry(entry: Variant) -> bool:
	if not entry is Dictionary or entry.size() != KEYS.size() or not entry.has_all(KEYS): return false
	if not Schema._type(entry.package_id,"id") or entry.package_id.contains(".") or entry.package_id.contains(":"): return false
	if not entry.name is String or entry.name.strip_edges().is_empty() or entry.name.length() > 120: return false
	if entry.kind != "patrol" or entry.compiler_revision != Compiler.REVISION: return false
	if not _local(entry.path,".rpp") or not _local(entry.source_path,".patrol.json"): return false
	return Schema._type(entry.source_hash,"hash") and Schema._type(entry.package_hash,"hash") and entry.source_hash == entry.source_hash.to_lower() and entry.package_hash == entry.package_hash.to_lower()

## The registry as data: {"registry_version":1,"packages":[entry...]}.
static func valid_registry(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2 or not value.has_all(["registry_version","packages"]): return false
	if not (value.registry_version is int or value.registry_version is float) or float(value.registry_version) != float(VERSION): return false
	if not value.packages is Array or value.packages.size() > MAX_PACKAGES: return false
	var ids := {}; var paths := {}
	for entry: Variant in value.packages:
		if not valid_entry(entry) or ids.has(entry.package_id) or paths.has(entry.path): return false
		ids[entry.package_id] = true; paths[entry.path] = true
	return true

static func registry() -> Dictionary:
	if not FileAccess.file_exists(REGISTRY): return fail("release_registry_invalid")
	var bytes := FileAccess.get_file_as_bytes(REGISTRY)
	if bytes.size() > MAX_REGISTRY_BYTES: return fail("release_registry_invalid")
	var decoded := StrictJSON.new().decode(bytes)
	if not decoded.ok or not valid_registry(decoded.value): return fail("release_registry_invalid")
	return {"ok":true,"code":"","registry":decoded.value}

static func _listing(listing: Dictionary) -> Dictionary:
	if listing.is_empty(): return registry()
	return {"ok":true,"code":"","registry":listing} if valid_registry(listing) else fail("release_registry_invalid")

## [{package_id, name}] in registry order, for menus and campaign tables.
static func packages(listing: Dictionary = {}) -> Array:
	var read := _listing(listing)
	var result: Array = []
	if not read.ok: return result
	for entry: Dictionary in read.registry.packages: result.append({"package_id":entry.package_id,"name":entry.name})
	return result

static func entry(package_id: String, listing: Dictionary = {}) -> Dictionary:
	var read := _listing(listing)
	if not read.ok: return read
	for item: Dictionary in read.registry.packages:
		if item.package_id == package_id: return {"ok":true,"code":"","entry":item.duplicate(true)}
	return fail("release_unknown",package_id)

## The validated immutable package, only if its hashes are the pinned ones.
static func load_package(package_id: String, listing: Dictionary = {}) -> Dictionary:
	var found := entry(package_id,listing)
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
