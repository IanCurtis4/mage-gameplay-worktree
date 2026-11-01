@tool
extends RefCounted
## Checkpoint46 (F9-05, P3d): receipts and replay of regional variations.
## - A proposal carries one receipt at its ROOT (receipt_schema.gd): the closed
##   request, request_hash, base_hash (whole base root), dependencies_hash
##   (catalogs, asset manifest, compiler and algorithm revisions) and
##   result_content_hash, the hash of the result WITHOUT the receipts extension,
##   so a receipt never names a hash that contains itself. The integral
##   source_hash is computed after the receipt is in and is never stored in it.
## - Bases live in a passive, write-once ledger keyed by base_hash
##   (.godot/map_authoring/ledger, at most LEDGER_FILES / LEDGER_BYTES, oldest
##   copies out first; it only ever holds copies, never the user's files) and
##   travel in a replay bundle when needed. Old sources without receipts keep
##   their hash; nothing is normalized when they open.
## - replay() runs the same prepare() on the stored base: the same base, request,
##   dependencies and algorithm give the same result_content_hash. The seed alone
##   never rebuilds later human edits; a missing or different base is a diagnostic.
const Shape = preload("res://scripts/map_authoring/synthesis/receipt_schema.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const KEY := Shape.KEY
const LEDGER := "res://.godot/map_authoring/ledger"
const LEDGER_FILES := 64
const LEDGER_BYTES := 128 * 1024 * 1024
const BUNDLE_KEYS := ["replay_version","kind","receipt","base","bundle_hash"]

static func fail(code: String, message: String = "", entity: String = "") -> Dictionary:
	var messages := {"replay_receipt_missing":"Este documento não tem esse recibo de variação.","replay_base_missing":"A base desta variação não está no livro de revisões deste projeto; importe o pacote de replay que a contém.","replay_base_diverged":"A base guardada não é a base do recibo.","replay_bundle_invalid":"O pacote de replay está incompleto ou foi alterado.","replay_kind":"O pacote de replay é de outro tipo de documento.","io_failure":"Não foi possível gravar o arquivo.","io_conflict":"O arquivo de destino já existe; escolha outro nome."}
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"severity":"error","entity_id":entity,"field":"receipts","message":message if not message.is_empty() else messages.get(code,"Recibo recusado: "+code)}]}

static func root_hash(kind: String, root: Dictionary) -> String:
	match kind:
		"piece": return Schema.semantic_hash(root)
		"map": return MapDocument.hash_source(root)
		"population": return PopulationDocument.hash_source(root)
		"patrol": return PatrolDocument.hash_source(root)
	return ""

static func strip(root: Dictionary) -> Dictionary:
	var copy := root.duplicate(true); copy.erase(KEY); return copy

## Hash of the root without its receipts: what a receipt certifies. A piece's
## revision counter is session bookkeeping (each apply bumps it), not content.
static func content_hash(kind: String, root: Dictionary) -> String:
	var projected := strip(root)
	if kind == "piece": projected.erase("revision")
	return root_hash(kind,projected)

static func dependencies_hash() -> String:
	var files := {}
	for path: String in ["res://data/map_authoring/prop_catalog.json","res://data/map_authoring/asset_manifest.json","res://data/map_authoring/border_profiles.json"]:
		files[path.get_file()] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	var revisions := {}
	for entry: Array in [["terrain","res://scripts/map_authoring/compiler/terrain_compiler.gd"],["map","res://scripts/map_authoring/composition/map_compiler.gd"],["population","res://scripts/map_authoring/population/population_compiler.gd"],["patrol","res://scripts/map_authoring/patrol/patrol_compiler.gd"],["synthesis","res://scripts/map_authoring/synthesis/regional_synthesis.gd"]]:
		revisions[entry[0]] = str(load(entry[1]).get_script_constant_map().get("REVISION",""))
	return Schema.semantic_hash({"files":files,"revisions":revisions})

static func make(kind: String, request: Dictionary, result: Dictionary, summary: Dictionary, algorithm: String) -> Dictionary:
	var counts := {}
	for key: String in Shape.SUMMARY: counts[key] = int(summary.get(key,0))
	return {"receipt_version":1,"algorithm_revision":algorithm,"kind":kind,"request":request.duplicate(true),"request_hash":Schema.semantic_hash(request),"base_hash":request.base_hash,"dependencies_hash":dependencies_hash(),"result_content_hash":content_hash(kind,result),"summary":counts}

## Appends the receipt; only the last Shape.MAX receipts are kept (oldest out).
static func attach(root: Dictionary, receipt: Dictionary) -> void:
	var list: Array = root.get(KEY,[]).duplicate(true)
	list.append(receipt)
	while list.size() > Shape.MAX: list.pop_front()
	root[KEY] = list

static func list(root: Dictionary) -> Array:
	var result: Array = []
	var receipts: Array = root.get(KEY,[])
	for index: int in receipts.size():
		var receipt: Dictionary = receipts[index]
		var selection: Dictionary = receipt.request.get("selection",{})
		result.append({"index":index,"kind":receipt.kind,"seed_text":receipt.request.get("seed_text",""),"target":receipt.request.get("target",{}),"selection":selection.get("region_id","polígono"),"summary":receipt.summary,"base_hash":receipt.base_hash,"result_content_hash":receipt.result_content_hash,"base_stored":FileAccess.file_exists(_path(receipt.base_hash))})
	return result

static func _path(base_hash: String) -> String: return LEDGER.path_join(base_hash+".json")

## Write-once copy of a base root, verified on every read.
static func store(kind: String, root: Dictionary) -> bool:
	var key := root_hash(kind,root)
	if key.is_empty(): return false
	var path := _path(key)
	if FileAccess.file_exists(path): return true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LEDGER))
	var temporary := path+".tmp"+str(OS.get_process_id())
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"kind":kind,"root":root},"\t",true,true)); file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary)); return FileAccess.file_exists(path)
	_prune()
	return true

static func fetch(kind: String, base_hash: String) -> Dictionary:
	var path := _path(base_hash)
	if not FileAccess.file_exists(path): return fail("replay_base_missing","",base_hash)
	var decoded := StrictJSON.new().decode(FileAccess.get_file_as_bytes(path))
	if not decoded.ok or not decoded.value is Dictionary or decoded.value.get("kind") != kind or not decoded.value.get("root") is Dictionary: return fail("replay_base_diverged","",base_hash)
	var root: Dictionary = decoded.value.root
	if kind == "piece":
		var read := Schema.read(JSON.stringify(root,"",true,true).to_utf8_buffer())
		if not read.ok: return fail("replay_base_diverged","",base_hash)
		root = read.data
	if root_hash(kind,root) != base_hash: return fail("replay_base_diverged","",base_hash)
	return {"ok":true,"root":root}

static func _prune() -> void:
	var folder := ProjectSettings.globalize_path(LEDGER)
	var entries: Array = []
	for name: String in DirAccess.get_files_at(folder):
		if not name.ends_with(".json"): continue
		var full := folder.path_join(name)
		var reader := FileAccess.open(full,FileAccess.READ)
		var size := reader.get_length() if reader != null else 0
		if reader != null: reader.close()
		entries.append([FileAccess.get_modified_time(full),full,size])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var kept := 0; var bytes := 0
	for entry: Array in entries:
		kept += 1; bytes += int(entry[2])
		if kept > LEDGER_FILES or bytes > LEDGER_BYTES: DirAccess.remove_absolute(entry[1])

## Re-runs receipt <index> of the open root on its stored base (or on the base of
## an imported bundle). Never writes the open document.
static func replay(kind: String, root: Dictionary, index: int, cancellation: Callable = Callable(), base: Dictionary = {}) -> Dictionary:
	var receipts: Array = root.get(KEY,[])
	if index < 0 or index >= receipts.size(): return fail("replay_receipt_missing")
	var receipt: Dictionary = receipts[index]
	if not Shape.valid_receipt(receipt) or receipt.kind != kind: return fail("replay_bundle_invalid")
	var source := base
	if source.is_empty():
		var fetched := fetch(kind,receipt.base_hash)
		if not fetched.ok: return fetched
		source = fetched.root
	if root_hash(kind,source) != receipt.base_hash: return fail("replay_base_diverged","",receipt.base_hash)
	var proposal: Dictionary
	if kind == "piece": proposal = load("res://scripts/map_authoring/synthesis/regional_synthesis.gd").prepare(source,receipt.request,cancellation)
	else: proposal = load("res://scripts/map_authoring/synthesis/root_synthesis.gd").prepare(kind,source,receipt.request,cancellation)
	if not proposal.ok: return proposal
	var produced := content_hash(kind,proposal.source)
	var dependencies := dependencies_hash()
	return {"ok":true,"code":"","index":index,"reproduced":produced == receipt.result_content_hash,"result_content_hash":produced,"expected_content_hash":receipt.result_content_hash,"dependencies_changed":dependencies != receipt.dependencies_hash,"current_is_result":content_hash(kind,root) == receipt.result_content_hash,"diagnostics":[]}

## Passive transport of a receipt with its base. Importing never runs it.
static func bundle(kind: String, root: Dictionary, index: int) -> Dictionary:
	var receipts: Array = root.get(KEY,[])
	if index < 0 or index >= receipts.size(): return fail("replay_receipt_missing")
	var receipt: Dictionary = receipts[index]
	var fetched := fetch(kind,receipt.base_hash)
	if not fetched.ok: return fetched
	var data := {"replay_version":1,"kind":kind,"receipt":receipt.duplicate(true),"base":fetched.root}
	data["bundle_hash"] = Schema.semantic_hash(data)
	return {"ok":true,"code":"","bundle":data}

static func read_bundle(raw: Variant, kind: String) -> Dictionary:
	if not raw is Dictionary or raw.size() != BUNDLE_KEYS.size() or not raw.has_all(BUNDLE_KEYS): return fail("replay_bundle_invalid")
	if not (raw.replay_version is int or raw.replay_version is float) or float(raw.replay_version) != 1.0: return fail("replay_bundle_invalid")
	if raw.kind != kind: return fail("replay_kind")
	var copy: Dictionary = raw.duplicate(true); copy.erase("bundle_hash")
	if raw.bundle_hash != Schema.semantic_hash(copy) or not Shape.valid_receipt(raw.receipt) or raw.receipt.kind != kind or not raw.base is Dictionary: return fail("replay_bundle_invalid")
	var base: Dictionary = raw.base
	if kind == "piece":
		var read := Schema.read(JSON.stringify(base,"",true,true).to_utf8_buffer())
		if not read.ok or not read.valid: return fail("replay_bundle_invalid")
		base = read.data
	if root_hash(kind,base) != raw.receipt.base_hash: return fail("replay_base_diverged")
	return {"ok":true,"code":"","receipt":raw.receipt,"base":base}

## Writes a new file only (an existing path is io_conflict).
static func save_new(path: String, value: Dictionary) -> Dictionary:
	if FileAccess.file_exists(path): return fail("io_conflict")
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return fail("io_failure")
	file.store_string(JSON.stringify(value,"\t",true,true)); file.close()
	return {"ok":true,"code":""}
