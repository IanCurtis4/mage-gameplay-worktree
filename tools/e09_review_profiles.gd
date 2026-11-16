extends SceneTree
## E09 T9 (A11): reads scripts/classes/<id>/review_builds.json (schema
## ragrpg_review_builds_v1), validates every build with the ProfileCatalog rules and writes
## one isolated profile per build, at the maximum job level, into a folder given on the command line.
## Why 40 and not 37: the seventh skill unlocks at job 37, but the 20 evolution points that the
## builds spend (C4.2) are only granted at job 40 (job level - 20).
##
## Run: godot --headless --script res://tools/e09_review_profiles.gd -- <absolute output folder>
## The personal save is never touched: the output folder must be absolute and outside the
## user data directory. The reader and validator are static so tests reuse them.
##
## A kit with no file, or not ready_for_play, is "pending" (not an error). A ready kit with
## a malformed or illegal file is "invalid" with an error code and a detail.

const SCHEMA := "ragrpg_review_builds_v1"
const DEFAULT_ROOT := "res://scripts/classes"
const REVIEW_JOB_LEVEL := ProgressionRules.MAX_JOB_LEVEL
const PENDING := &"pending"
const READY := &"ready"
const INVALID := &"invalid"
const MIN_BUILDS := 2

static var _job_xp_cache := -1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Uso: -- <pasta de saída absoluta>")
		quit(1)
		return
	var report := write_all(String(args[0]))
	print(JSON.stringify(report, "\t"))
	quit(0 if bool(report.get("ok", false)) else 1)

# --- Reader ------------------------------------------------------------------------

## Result: {"identity_id", "status", "reason", "error_code", "detail", "builds"}.
## Every build: {"id", "name", "base_ranks", "evolution_ranks", "purchased", "shortcuts",
## "base_points", "evolution_points"}. `catalog` defaults to ProfileCatalog.pilot().
static func read_builds(identity_id: StringName, root: String = DEFAULT_ROOT, catalog: ProfileCatalog = null) -> Dictionary:
	var result := {"identity_id": identity_id, "status": PENDING, "reason": "", "error_code": &"", "detail": "", "builds": []}
	if not ClassKitRegistry.is_kit(identity_id):
		return _invalid(result, &"unknown_identity", String(identity_id))
	var path := root.path_join(String(identity_id)).path_join("review_builds.json")
	if not FileAccess.file_exists(path):
		result["reason"] = "sem review_builds.json"
		return result
	if not ClassKitRegistry.ready_for_play(identity_id):
		result["reason"] = "kit sem ready_for_play"
		return result
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not parsed is Dictionary:
		return _invalid(result, &"malformed_json", path)
	var document: Dictionary = parsed
	if document.get("schema") != SCHEMA:
		return _invalid(result, &"unknown_schema", str(document.get("schema")))
	if StringName(str(document.get("identity_id", ""))) != identity_id:
		return _invalid(result, &"identity_mismatch", str(document.get("identity_id")))
	var raw_builds: Variant = document.get("builds")
	if not raw_builds is Array or (raw_builds as Array).size() < MIN_BUILDS:
		return _invalid(result, &"too_few_builds", "mínimo %d" % MIN_BUILDS)
	var active_catalog := catalog if catalog != null else ProfileCatalog.pilot()
	if not active_catalog.is_valid() or active_catalog.evolution_definition(identity_id) == null:
		return _invalid(result, &"kit_not_in_catalog", String(identity_id))
	var seen: Dictionary = {}
	for raw: Variant in raw_builds:
		var checked := _check_build(identity_id, raw, active_catalog)
		if not checked["ok"]:
			return _invalid(result, checked["error_code"], checked["detail"])
		var build: Dictionary = checked["build"]
		if seen.has(build["id"]):
			return _invalid(result, &"duplicate_build_id", String(build["id"]))
		seen[build["id"]] = true
		result["builds"].append(build)
	result["status"] = READY
	return result

static func _invalid(result: Dictionary, code: StringName, detail: String) -> Dictionary:
	result["status"] = INVALID
	result["error_code"] = code
	result["detail"] = detail
	result["builds"] = []
	return result

static func _check_build(identity_id: StringName, raw: Variant, catalog: ProfileCatalog) -> Dictionary:
	if not raw is Dictionary:
		return _fail(&"build_not_object", "")
	var entry: Dictionary = raw
	var build_id := StringName(str(entry.get("id", "")))
	if build_id.is_empty() or str(entry.get("name", "")).strip_edges().is_empty():
		return _fail(&"build_unnamed", str(build_id))
	var origin := ClassKitRegistry.origin(identity_id)
	var purchased: Dictionary[StringName, int] = {}
	var final_ranks: Dictionary[StringName, int] = {}
	for key: String in ["base_ranks", "evolution_ranks"]:
		var ranks: Variant = entry.get(key)
		if not ranks is Dictionary:
			return _fail(&"ranks_missing", "%s/%s" % [build_id, key])
		for raw_skill: Variant in ranks:
			var skill_id := StringName(str(raw_skill))
			var value: Variant = ranks[raw_skill]
			if not (value is int or (value is float and value == floorf(value))) or int(value) < 1:
				return _fail(&"rank_not_positive_integer", "%s/%s" % [build_id, skill_id])
			var metadata := catalog.skill_metadata(skill_id)
			if metadata.is_empty() or not catalog.skill_is_allowed(skill_id, origin, identity_id):
				return _fail(&"skill_not_allowed", "%s/%s" % [build_id, skill_id])
			var wallet := ProfileCatalog.BASE_WALLET if key == "base_ranks" else ProfileCatalog.EVOLUTION_WALLET
			if metadata["wallet"] != wallet or final_ranks.has(skill_id):
				return _fail(&"skill_in_wrong_map", "%s/%s" % [build_id, skill_id])
			# The maps carry the FINAL rank; the free rank of the entry costs no point.
			var bought := int(value) - int(metadata["free_rank"])
			if bought < 0:
				return _fail(&"rank_below_free_rank", "%s/%s" % [build_id, skill_id])
			final_ranks[skill_id] = int(value)
			if bought > 0:
				purchased[skill_id] = bought
	var legal := catalog.validate_purchased_ranks(origin, identity_id, REVIEW_JOB_LEVEL, purchased)
	if not legal["ok"]:
		return _fail(legal.get("error_code", &"illegal_ranks"), str(build_id))
	var base_points := catalog.skill_points_spent(purchased, ProfileCatalog.BASE_WALLET)
	var evolution_points := catalog.skill_points_spent(purchased, ProfileCatalog.EVOLUTION_WALLET)
	if base_points > ProgressionRules.base_skill_points_granted(ProgressionRules.MAX_JOB_XP, true):
		return _fail(&"base_budget_exceeded", "%s: %d" % [build_id, base_points])
	if evolution_points > _evolution_points_at_review_level():
		return _fail(&"evolution_budget_exceeded", "%s: %d" % [build_id, evolution_points])
	var effective := catalog.effective_skill_ranks(origin, identity_id, purchased)
	var shortcuts: Array[StringName] = []
	var raw_shortcuts: Variant = entry.get("shortcuts", [])
	if not raw_shortcuts is Array or (raw_shortcuts as Array).size() > ActionBarLayout.SLOT_COUNT:
		return _fail(&"shortcuts_invalid", str(build_id))
	for raw_shortcut: Variant in raw_shortcuts:
		var shortcut := StringName(str(raw_shortcut))
		var metadata := catalog.skill_metadata(shortcut)
		if shortcut in shortcuts or metadata.is_empty() or metadata["category"] != ProfileCatalog.ACTIVE or int(effective.get(shortcut, 0)) <= 0:
			return _fail(&"shortcut_not_learned_active", "%s/%s" % [build_id, shortcut])
		shortcuts.append(shortcut)
	return {"ok": true, "build": {
		"id": build_id, "name": String(entry["name"]), "base_ranks": (entry["base_ranks"] as Dictionary).duplicate(true),
		"evolution_ranks": (entry["evolution_ranks"] as Dictionary).duplicate(true), "purchased": purchased,
		"shortcuts": shortcuts, "base_points": base_points, "evolution_points": evolution_points,
	}}

static func _fail(code: StringName, detail: String) -> Dictionary:
	return {"ok": false, "error_code": code, "detail": detail}

static func _evolution_points_at_review_level() -> int:
	return ProgressionRules.evolution_skill_points_granted(review_job_xp(), true)

## Smallest job XP that reaches the review job level (evolved).
static func review_job_xp() -> int:
	if _job_xp_cache < 0:
		for xp: int in range(ProgressionRules.EVOLUTION_MIN_JOB_XP, ProgressionRules.MAX_JOB_XP + 1):
			if ProgressionRules.job_level_for_xp(xp, true) >= REVIEW_JOB_LEVEL:
				_job_xp_cache = xp
				break
	return _job_xp_cache

# --- Writer --------------------------------------------------------------------------

## One isolated profile (own folder, one character) per build of every ready kit.
## Returns {"ok", "profiles": [{identity_id, build_id, directory}], "pending": [...], "invalid": [...]}.
static func write_all(output_root: String, root: String = DEFAULT_ROOT, catalog: ProfileCatalog = null) -> Dictionary:
	var report := {"ok": true, "profiles": [], "pending": [], "invalid": []}
	var normalized := output_root.replace("\\", "/").simplify_path().trim_suffix("/")
	var user_root := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if not normalized.is_absolute_path() or normalized == user_root or normalized.begins_with(user_root + "/"):
		report["ok"] = false
		report["error_code"] = &"unsafe_output_folder"
		return report
	var active_catalog := catalog if catalog != null else ProfileCatalog.pilot()
	for identity_id: StringName in ClassKitRegistry.ids():
		var read := read_builds(identity_id, root, active_catalog)
		match read["status"]:
			PENDING:
				report["pending"].append({"identity_id": identity_id, "reason": read["reason"]})
			INVALID:
				report["invalid"].append({"identity_id": identity_id, "error_code": read["error_code"], "detail": read["detail"]})
				report["ok"] = false
			_:
				for build: Dictionary in read["builds"]:
					var directory := normalized.path_join("%s__%s" % [identity_id, build["id"]])
					var written := _write_profile(directory, identity_id, build, active_catalog)
					if not written["ok"]:
						report["ok"] = false
						report["invalid"].append({"identity_id": identity_id, "error_code": written["error_code"], "detail": String(build["id"])})
						continue
					report["profiles"].append({"identity_id": identity_id, "build_id": build["id"], "directory": directory})
	return report

static func _write_profile(directory: String, identity_id: StringName, build: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(directory)
	var store := ProfileStore.new(directory, catalog)
	if store.has_pending_transaction() or FileAccess.file_exists(directory.path_join("profile.json")):
		return {"ok": false, "error_code": &"output_not_empty"}
	var profile := ProfileState.new(IdentityIds.new_profile_id())
	var character_id := IdentityIds.character_id(profile.profile_id, profile.next_character_counter)
	var character := CharacterState.new(character_id, "E09 %s" % build["name"], ClassKitRegistry.origin(identity_id))
	character.evolution_id = identity_id
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = review_job_xp()
	character.purchased_skill_ranks.assign(build["purchased"])
	var slots := ActionBarLayout.empty()
	for index: int in (build["shortcuts"] as Array).size():
		slots[index] = build["shortcuts"][index]
	character.action_slots = slots
	profile.characters.append(character)
	profile.next_character_counter += 1
	profile.selected_character_id = character_id
	var committed := store.commit(profile)
	if not committed.get("ok", false):
		return {"ok": false, "error_code": committed.get("error_code", &"commit_failed")}
	var loaded := ProfileStore.new(directory, catalog).load_profile()
	return {"ok": bool(loaded.get("ok", false)), "error_code": loaded.get("error_code", &"")}
