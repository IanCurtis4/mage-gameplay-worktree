extends SceneTree
const Pilot = preload("res://tools/content/pilot_bundle.gd")
const Transform = preload("res://tools/content/transform_bundle.gd")
const Directions = preload("res://tools/content/directions_bundle.gd")
const BRIEFS := "res://content/authoring/transform_briefs.json"
const TEXTS := "res://content/authoring/transform_texts.json"
const BUILDS := "res://content/authoring/directions_builds.json"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var entries: Array[Dictionary] = Transform.entries()
	var prepared := ContentAuthoring.prepare(entries)
	if not prepared["ok"]: _fail(prepared); return
	var editorial: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXTS))
	if not editorial is Dictionary: _fail({"error_code": "invalid_editorial_document"}); return
	var compiled := ContentAuthoring.compile_bundle(entries, editorial)
	if not compiled["ok"]: _fail(compiled); return
	var catalog: BuildEffectCatalog = compiled["catalog"]
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/directions_execution.json"))
	if not proof is Dictionary or proof.get("mechanical_digest") != compiled["mechanical_digest"] or proof.get("observations", []).size() != 20: _fail({"error_code": "missing_direction_proof"}); return
	var observed: Dictionary = {}
	for row: Dictionary in proof["observations"]:
		var key := "%s:%s" % [row["identity"], row["branch"]]
		if observed.has(key) or not row.get("decision_validated", false): _fail({"error_code": "invalid_direction_proof"}); return
		observed[key] = row

	var builds: Array[Dictionary] = []
	for identity: String in Pilot.ROUTES:
		for branch: int in 2:
			var comparison: Dictionary = Directions.comparison(identity, branch, catalog)
			if not comparison["ok"]: _fail(comparison); return
			var snapshot: BuildSnapshot = comparison["snapshot"]
			var key := "%s:%s" % [identity, "A" if branch == 0 else "B"]
			var expected: Dictionary = JSON.parse_string(JSON.stringify(Directions.describe(comparison), "", true))
			if not observed.has(key) or observed[key]["build"] != expected: _fail({"error_code": "direction_build_mismatch", "build": key}); return

			var composed: Dictionary = comparison["composed"]
			var capture: Dictionary = {}
			for skill: StringName in snapshot.skill_ranks:
				var result := SkillEffectResolver.capture(skill, int(snapshot.skill_ranks[skill]), composed)
				if not result["ok"]: _fail(result); return
				capture[skill] = result["values"]
			var layout: Dictionary = {}
			for slot: StringName in IdentityIds.equipment_slots(): layout[slot] = snapshot.equipment_instances[snapshot.equipped[slot]].definition_id if snapshot.equipped[slot] != null else null
			builds.append({"decision_proof": observed[key].duplicate(true), "identity": identity, "branch": "A" if branch == 0 else "B", "base_class_id": snapshot.base_class_id, "evolution_id": snapshot.evolution_id, "base_level": snapshot.base_level, "job_level": snapshot.job_level, "purchased_ranks": comparison["purchased_ranks"], "support_purchases": comparison["support_purchases"], "effective_ranks": snapshot.skill_ranks, "action_slots": snapshot.action_slots, "equipment": layout, "run_effects": comparison["run_effects"], "stats": composed["breakdown"].values(), "skill_capture": capture, "procs": composed["procs"], "kit_policies": composed["kit_policies"], "inactive": composed["inactive"], "composition_valid": true, "tactical_validated": false})
	var report := {"scope": "directions_pilot_offline", "production_published": false, "mechanical_digest": compiled["mechanical_digest"], "editorial_sha256": FileAccess.get_file_as_string(TEXTS).sha256_text(), "comparisons": builds, "direction_decisions_validated": true, "direction_proof_sha256": FileAccess.get_file_as_string("res://content/authoring/directions_execution.json").sha256_text(), "tactical_validation_pending": true, "progression_formula": null, "production_loot_rates": null}
	if not _write(BUILDS, report): quit(1); return
	var output := "res://.godot/content_authoring/directions_%d" % Time.get_ticks_usec()
	if DirAccess.make_dir_recursive_absolute(output) != OK: _fail({"error_code": "output_directory_failed"}); return
	var files: Array[String] = []
	for entry: Dictionary in compiled["entries"]:
		var file := output.path_join("%s_%s.tres" % [entry["origin"], entry["definition"].id])
		if ResourceSaver.save(entry["definition"], file) != OK: _fail({"error_code": "resource_save_failed"}); return
		files.append(file)
	if not _write(output.path_join("manifest.json"), {"scope": report["scope"], "production_published": false, "mechanical_digest": compiled["mechanical_digest"], "editorial_sha256": report["editorial_sha256"], "resource_paths": files, "comparison_count": builds.size(), "tactical_validated": false}): quit(1); return
	print("Directions pilot validated: %d recipes, %d composed comparisons; tactical validation pending. %s" % [files.size(), builds.size(), output])
	quit(0)
func _write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: push_error("Cannot write %s" % path); return false
	file.store_string(JSON.stringify(data, "\t", true) + "\n")
	file.close()
	return true
func _fail(result: Dictionary) -> void:
	push_error(str(result))
	quit(1)
