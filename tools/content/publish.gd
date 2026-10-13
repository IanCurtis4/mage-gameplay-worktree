extends SceneTree
const Publication = preload("res://tools/content/publication_bundle.gd")
const Pilot = preload("res://tools/content/pilot_bundle.gd")
const Directions = preload("res://tools/content/directions_bundle.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var result := Publication.compile()
	if not result["ok"]: _fail(result); return
	var verify_only := "--check" in OS.get_cmdline_user_args()
	var files: Array[String] = []
	for entry: Dictionary in result["entries"]:
		var definition: Resource = entry["definition"]
		if (entry["origin"] == &"equipment" and definition.id in Publication.ID_MAPPING) or (entry["origin"] == &"mob" and definition.id in Publication.PRESERVED_MOBS): continue
		var path := "res://resources/build_effects/%s/%s.tres" % [entry["origin"], definition.id]
		if not verify_only and (DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK or ResourceSaver.save(definition, path) != OK): _fail({"error_code": "publication_save_failed", "path": path}); return
		files.append(path)
	var loaded := BuildContentLoader.load_catalog()
	if not loaded["ok"]: _fail(loaded); return
	var native_entries: Array[Dictionary] = []
	for origin: StringName in ContentAuthoring.ORIGINS:
		for definition: Resource in BuildContentLoader.definitions(origin):
			native_entries.append({"origin": origin, "definition": definition, "purpose": "Publicado conforme mapeamento autorizado."})
	var native := ContentAuthoring.prepare(native_entries)
	if not native["ok"] or native["mechanical_digest"] != result["mechanical_digest"]: _fail({"error_code": "native_publication_mismatch"}); return
	var builds: Array[Dictionary] = []
	for identity: String in Pilot.ROUTES:
		for branch: int in 2:
			var comparison := Publication.comparison(identity, branch, loaded["catalog"], result["source_catalog"])
			if not comparison["ok"]: _fail(comparison); return
			builds.append({"identity": identity, "branch": "A" if branch == 0 else "B", "build": Directions.describe(comparison), "composition_valid": true})
	var manifest := {"schema_version": 1, "scope": "e06_published_catalog", "source_mechanical_digest": result["source_mechanical_digest"], "mechanical_digest": result["mechanical_digest"], "id_mapping": result["id_mapping"], "published_resource_paths": files, "preserved_equipment_ids": Publication.ID_MAPPING.keys(), "preserved_mob_ids": Publication.PRESERVED_MOBS, "entry_count": result["entries"].size(), "published_resource_count": files.size(), "comparisons": builds, "progression_formula": null, "production_loot_rates": null, "human_playtest_accepted": false}
	if verify_only:
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/publication_manifest.json"))
		if not previous is Dictionary or previous != JSON.parse_string(JSON.stringify(manifest, "", true)): _fail({"error_code": "stale_publication_manifest"}); return
		print("E06_PUBLICATION_CHECK_OK entries=", result["entries"].size(), " builds=", builds.size(), " digest=", native["mechanical_digest"])
		quit(0); return
	var file := FileAccess.open("res://content/authoring/publication_manifest.json", FileAccess.WRITE)
	if file == null: _fail({"error_code": "publication_manifest_failed"}); return
	file.store_string(JSON.stringify(manifest, "\t", true) + "\n")
	file.close()
	print("E06_PUBLICATION_OK entries=", result["entries"].size(), " published=", files.size(), " builds=", builds.size(), " digest=", result["mechanical_digest"])
	quit(0)
func _fail(result: Dictionary) -> void:
	push_error(JSON.stringify(result))
	quit(1)
