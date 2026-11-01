extends SceneTree
## Checkpoint48 (F9-11, P5): the consumption point of released maps. The Bosque
## package is committed, pinned in the registry, current with its source, loads
## only with its pinned hashes, gives the ExpeditionManifest the next epics read,
## and prepares through the game authorities outside the editor. Tampered bytes,
## wrong pins and unsafe registry entries are refused; publication is by hash
## and never overwrites.
const Release = preload("res://scripts/map_authoring/release/map_release.gd")
const Store = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const BOSQUE := "sanctuary_woods"
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_RELEASE_API_CHECK "+id+" "+str(ok))
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var read := Release.registry()
	var listing: Dictionary = read.get("registry",{})
	check("registry_lists_the_bosque",read.ok and Release.packages() == [{"package_id":BOSQUE,"name":"Bosque do Santuário"}])
	var pinned: Dictionary = listing.packages[0] if read.ok else {}
	var bad: Array = []
	for change: Callable in [
		func(e: Dictionary) -> void: e["note"] = "x",
		func(e: Dictionary) -> void: e.path = "res://scripts/main.rpp",
		func(e: Dictionary) -> void: e.path = "res://data/map_authoring/../main.rpp",
		func(e: Dictionary) -> void: e.path = "res://data/map_authoring/sub/a.rpp",
		func(e: Dictionary) -> void: e.compiler_revision = "map_patrol_v0",
		func(e: Dictionary) -> void: e.kind = "map",
		func(e: Dictionary) -> void: e.package_hash = e.package_hash.to_upper(),
		func(e: Dictionary) -> void: e.package_id = "Bosque"]:
		var copy: Dictionary = listing.duplicate(true); change.call(copy.packages[0]); bad.append(Release.valid_registry(copy))
	var twice: Dictionary = listing.duplicate(true); twice.packages.append(twice.packages[0].duplicate(true))
	bad.append(Release.valid_registry(twice))
	var newer: Dictionary = listing.duplicate(true); newer.registry_version = 2
	bad.append(Release.valid_registry(newer))
	check("registry_refuses_unsafe_entries",read.ok and Release.valid_registry(listing) and not bad.has(true))
	var fresh := Release.freshness(BOSQUE)
	check("committed_package_is_current",fresh.get("current",false) and fresh.source_hash == pinned.get("source_hash",""))
	# The contract: the manifest of the pinned package.
	var opened := Release.manifest(BOSQUE)
	var package: Dictionary = opened.get("package",{})
	var manifest: ExpeditionManifest = opened.get("manifest")
	var bytes := FileAccess.get_file_as_bytes(pinned.get("path","res://absent.rpp"))
	check("package_loads_with_its_pins",opened.ok and package.package_hash == pinned.package_hash and package.source_hash == pinned.source_hash and bytes.size() <= 4*1024*1024 and bytes.slice(0,4).get_string_from_utf8() == "RPP1")
	var data: Dictionary = manifest._data if manifest != null else {}
	var patrolled: int = data.get("population",{}).get("slots",[]).filter(func(slot: Dictionary) -> bool: return slot.has("patrol")).size() if not data.is_empty() else 0
	var objective_ids: Array = data.get("objectives",[]).map(func(item: Dictionary) -> String: return item.objective_id)
	check("manifest_is_the_consumption_contract",data.get("stages",[]).size() == 1 and data.stages[0].stage_id == "map_preview" and data.stages[0].entrance == "authored_entry" and data.population.slots.size() == 7 and patrolled == 1 and "shrine_completion" in objective_ids)
	if manifest != null: manifest._data.stages[0].entrance = "changed"
	check("manifest_is_a_copy",package.get("manifest",{}).get("stages",[{}])[0].get("entrance","") == "authored_entry")
	# Wrong pins and tampered bytes.
	var unknown := Release.load_package("absent_map")
	var wrong: Dictionary = listing.duplicate(true); wrong.packages[0].path = "res://data/map_authoring/representative.rpp"
	var mismatch := Release.load_package(BOSQUE,wrong)
	check("unknown_and_mismatched_pins_are_refused",unknown.code == "release_unknown" and mismatch.code == "release_package_mismatch" and Store.load_package("res://data/map_authoring/representative.rpp").ok)
	var folder := "res://.godot/f9_release_api"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var flipped := bytes.duplicate(); flipped[flipped.size()-9] = flipped[flipped.size()-9] ^ 0x5a
	var header := bytes.duplicate(); header[10] = 0x30 if header[10] != 0x30 else 0x31
	var results: Array = []
	for entry: Array in [["flipped.rpp",flipped],["header.rpp",header],["short.rpp",bytes.slice(0,64)]]:
		var file := FileAccess.open(folder.path_join(entry[0]),FileAccess.WRITE); file.store_buffer(entry[1]); file.close()
		results.append(Store.load_package(folder.path_join(entry[0])).code)
	check("tampered_bytes_are_refused",results == ["package_invalid","package_invalid","package_invalid"])
	# Publication is by hash and never overwrites another value.
	var small := Store.load_package("res://data/map_authoring/representative.rpp")
	var target := folder.path_join("published")
	if small.ok:
		var squatter := FileAccess.open(target.path_join(small.package.package_hash+".rpp"),FileAccess.WRITE) if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target)) == OK else null
		if squatter != null: squatter.store_string("not a package"); squatter.close()
	var conflict := Store.publish(target,small.package,small.package.source_hash) if small.ok else {"code":""}
	if small.ok: DirAccess.remove_absolute(ProjectSettings.globalize_path(target.path_join(small.package.package_hash+".rpp")))
	var published := Store.publish(target,small.package,small.package.source_hash) if small.ok else {"ok":false}
	var stale := Store.publish(target,small.package,"0".repeat(64)) if small.ok else {"code":""}
	check("publication_is_by_hash_and_immutable",conflict.code == "immutable_conflict" and published.ok and published.path.get_file() == small.package.package_hash+".rpp" and FileAccess.get_file_as_bytes(published.path) == FileAccess.get_file_as_bytes("res://data/map_authoring/representative.rpp") and stale.code == "stale_source")
	# The export ships packages and the registry.
	var runner := FileAccess.get_file_as_string("res://tools/map_editor_candidate/run.ps1")
	check("release_export_ships_packages_and_registry",runner.contains("data/map_authoring/*.rpp") and runner.contains("data/map_authoring/*.json") and runner.contains("--m8-package=sanctuary_woods"))
	# Runtime preparation through the game authorities (outside the editor).
	var prepared := Release.prepare(BOSQUE)
	var entry_point: Dictionary = prepared.get("entry",{})
	check("prepare_uses_the_game_authorities",not Engine.is_editor_hint() and prepared.ok and not prepared.ephemeral_entry and prepared.manifest is ExpeditionManifest and prepared.candidate_hash.length() == 64 and entry_point.get("surface_id","").begins_with("clearing/") and prepared.release.package_id == BOSQUE)
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_RELEASE_API_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
