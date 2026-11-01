extends SceneTree
## Checkpoint41 (F9-09/F9-11): the committed asset manifest matches the checkout,
## covers every dependency a compiled package can name, and is what an exported
## build uses in place of the raw files.
const Assets = preload("res://scripts/map_authoring/assets/asset_manifest.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Borders = preload("res://scripts/map_authoring/composition/border_profile_catalog.gd")
const Props = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const PatrolStore = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ASSET_CHECK "+id+" "+str(ok))
func run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Assets.PATH)) if FileAccess.file_exists(Assets.PATH) else null
	check("committed_manifest_is_valid",Assets.valid(parsed))
	var committed := Assets.entries_by_path()
	var expected := Assets.build()
	var rebuilt := {}
	for entry: Dictionary in expected.entries: rebuilt[entry.path] = entry
	check("committed_manifest_matches_checkout",not committed.is_empty() and committed == rebuilt)
	# Every dependency the compilers and catalogs can record is listed with its hash.
	var dependencies: Array = Materials.dependencies()
	var border_ok := true
	for id: String in Borders.IDS:
		var resolved: Dictionary = Borders.resolve(id)
		if not resolved.ok: border_ok = false; continue
		var listed: Dictionary = Borders.dependencies(resolved.definition)
		if not listed.ok: border_ok = false; continue
		dependencies.append_array(listed.dependencies)
	var props := Props.load_catalog()
	if props.ok:
		dependencies.append({"path":Props.PATH,"sha256":FileAccess.get_sha256(Props.PATH)})
		for id: String in props.definitions:
			var definition: Dictionary = props.definitions[id]
			for path: String in [definition.sprite_path,definition.sprite_path+".import"]: dependencies.append({"path":path,"sha256":FileAccess.get_sha256(path)})
	var covered: bool = not dependencies.is_empty() and border_ok and props.ok
	for dependency: Dictionary in dependencies:
		if not committed.has(dependency.path) or committed[dependency.path].sha256 != dependency.sha256: covered = false; print("F9_ASSET_MISSING "+str(dependency.path))
	check("every_package_dependency_is_listed",covered)
	var grass: String = Materials.GRASS_PATH
	check("source_runs_hash_the_real_bytes",Assets.sha256_for(grass,false) == FileAccess.get_sha256(grass) and not Assets.exported())
	check("exported_lookup_uses_the_manifest",Assets.sha256_for(grass,true) == String(committed.get(grass,{}).get("sha256","x")) and Assets.sha256_for("res://assets/art/map_authoring/absent.png",true).is_empty())
	var tampered := committed.duplicate(true)
	if tampered.has(grass): tampered[grass].sha256 = "0".repeat(64)
	check("tampered_manifest_no_longer_matches_packages",Assets.sha256_for(grass,true,tampered) != FileAccess.get_sha256(grass))
	check("representative_release_package_validates",PatrolStore.load_package("res://data/map_authoring/representative.rpp").ok)
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_ASSET_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
