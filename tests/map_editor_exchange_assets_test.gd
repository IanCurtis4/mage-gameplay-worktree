extends SceneTree
## Checkpoint47 (F9-01/03/09, P4): exchange bundles v2 with a passive asset
## manifest. Real compiler revisions, every dependency declared with hash, kind,
## rights basis and provenance record, nothing outside the controlled asset area,
## no bytes carried, tampering refused, a receiving project without the same
## assets told which files before anything compiles, and v1 bundles refused.
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const Rooms = preload("res://tests/map_editor_root_synthesis_test.gd")
const TerrainCompiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const PatrolCompiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ASSETS_CHECK "+id+" "+str(ok))
static func rehash(bundle: Dictionary) -> Dictionary:
	for file: Dictionary in bundle.files: file.sha256 = Exchange.digest(file.data)
	bundle.ticket_hash = Exchange.digest(bundle.ticket)
	bundle.erase("bundle_hash"); bundle.bundle_hash = Exchange.digest(bundle); return bundle
static func file(bundle: Dictionary, path: String) -> Dictionary:
	for entry: Dictionary in bundle.files:
		if entry.path == path: return entry
	return {}
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var piece: Dictionary = Rooms.piece_source()
	var catalog := Exchange.PropCatalog.load_catalog()
	piece.placements = [{"placement_id":"stone_a","definition_id":"moss_boulder","revision":int(catalog.definitions.moss_boulder.revision),"position_xyz":[640,0,640],"rotation_y":0.0,"surface_id":"ground"}]
	piece.dependencies = [Exchange.PropCatalog.dependency(catalog.definitions.moss_boulder)]
	check("revisions_are_the_real_compilers",Exchange.REVISIONS.piece == TerrainCompiler.REVISION and Exchange.REVISIONS.map == MapCompiler.REVISION and Exchange.REVISIONS.patrol == PatrolCompiler.REVISION and Exchange.REVISIONS.piece != "map_terrain_v2")
	var exported := Exchange.export_bundle("piece",piece,Exchange.policy(["layers","placements"]),"Relevo e objetos")
	check("piece_exports_v2",exported.ok and exported.bundle.exchange_version == 2 and exported.bundle.revision == "map_exchange_v2")
	if not exported.ok: print(exported); finish(); return
	var request: Dictionary = exported.bundle
	var assets: Dictionary = file(request,"assets.json").get("data",{})
	var paths: Array = []
	var hashes_ok := true
	for entry: Dictionary in assets.get("entries",[]):
		paths.append(entry.path)
		if entry.sha256 != Exchange.AssetManifest.sha256(entry.path) or String(entry.rights_basis).is_empty(): hashes_ok = false
	var sprite: String = catalog.definitions.moss_boulder.sprite_path
	check("manifest_names_every_asset_with_rights",request.files.size() == 3 and Exchange.AssetManifest.valid(assets) and hashes_ok and Exchange.PropCatalog.PATH in paths and sprite in paths and (sprite+".import") in paths and paths.any(func(p: String) -> bool: return p.ends_with(".gdshader")) and paths.any(func(p: String) -> bool: return p.ends_with("_tile.png")))
	check("no_asset_bytes_travel",not JSON.stringify(request).contains("iVBORw0KGgo") and JSON.stringify(assets).length() < 16384)
	# Proposals keep working.
	var candidate := piece.duplicate(true); candidate.layers[0].heights[100] = 12.0
	var proposed := Exchange.propose(request,candidate)
	var prepared := Exchange.prepare(request,proposed.get("bundle",{}),piece)
	check("v2_proposal_roundtrip",proposed.ok and prepared.ok and prepared.source.layers[0].heights[100] == 12.0)
	# Tampering and unsafe declarations.
	var tampered := rehash(_alter(request,func(data: Dictionary) -> void: data.entries[0].sha256 = "0".repeat(64)))
	check("tampered_manifest_is_refused",Exchange.validate_bundle(tampered).code == "exchange_assets_incomplete")
	var outside := rehash(_alter(request,func(data: Dictionary) -> void: data.entries.append({"path":"res://scripts/main.gd","sha256":"1".repeat(64),"kind":"catalog","rights_basis":"project_source","record":""})))
	var foreign := rehash(_alter(request,func(data: Dictionary) -> void: data.entries.append({"path":"res://assets/art/other/skin.png","sha256":"1".repeat(64),"kind":"texture","rights_basis":"project_source","record":""})))
	check("unsafe_assets_are_refused",Exchange.validate_bundle(outside).code == "unsafe_asset" and Exchange.validate_bundle(foreign).code == "unsafe_asset")
	var stripped: Dictionary = request.duplicate(true); stripped.files = stripped.files.slice(0,2)
	check("v1_shape_is_refused",Exchange.validate_bundle(rehash(stripped)).code == "exchange_files")
	var old: Dictionary = request.duplicate(true); old.exchange_version = 1; old.revision = "map_exchange_v1"
	check("v1_version_is_refused",Exchange.validate_bundle(rehash(old)).code == "exchange_version")
	# A receiving project with other assets: named files, before compiling.
	var texture: String = ""
	for path: String in paths:
		if path.ends_with("_tile.png"): texture = path
	var other := _consistent(proposed.get("bundle",{}),texture,"2".repeat(64))
	var mismatch := Exchange.prepare(request,other,piece)
	check("different_asset_is_named",mismatch.code == "exchange_asset_mismatch" and mismatch.paths == [texture])
	var ghost := "res://assets/art/map_authoring/props/ghost_tree.png"
	var absent := _consistent(proposed.get("bundle",{}),ghost,"3".repeat(64))
	var missing := Exchange.prepare(request,absent,piece)
	check("missing_asset_is_named",missing.code == "exchange_asset_missing" and missing.paths == [ghost])
	# Encounters and patrols declare the assets of their map.
	var built := Rooms.fixture()
	var patrol := Exchange.export_bundle("patrol",built.patrols,Exchange.policy(["name"]),"Patrulhas")
	var patrol_assets: Array = file(patrol.get("bundle",{}),"assets.json").get("data",{}).get("entries",[])
	check("patrol_bundle_declares_map_assets",patrol.ok and patrol_assets.size() > 0 and patrol.bundle.ticket.compiler_revision == PatrolCompiler.REVISION)
	finish()
func _alter(bundle: Dictionary, change: Callable) -> Dictionary:
	var copy := bundle.duplicate(true)
	for entry: Dictionary in copy.files:
		if entry.path == "assets.json": change.call(entry.data)
	return copy
# Report and manifest agree with each other but not with this project.
func _consistent(bundle: Dictionary, path: String, sha: String) -> Dictionary:
	var copy := bundle.duplicate(true)
	for entry: Dictionary in copy.files:
		if entry.path == "report.json":
			var found := false
			for dependency: Dictionary in entry.data.dependencies:
				if dependency.get("path","") == path: dependency.sha256 = sha; found = true
			if not found: entry.data.dependencies.append({"definition_id":path.get_file().replace(".","_"),"revision":1,"sha256":sha,"path":path})
		if entry.path == "assets.json":
			var present := false
			for asset: Dictionary in entry.data.entries:
				if asset.path == path: asset.sha256 = sha; present = true
			if not present: entry.data.entries.append({"path":path,"sha256":sha,"kind":"texture","rights_basis":"project_source","record":""})
	return rehash(copy)
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_ASSETS_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
