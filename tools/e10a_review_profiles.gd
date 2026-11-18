extends SceneTree
## E10a T10 (C7): one isolated review profile per build of the Acólito family (priest, cultist),
## at job 40 (A18 of E09: the 20 evolution points only exist there). The reader/validator is the
## E09 one (same schema ragrpg_review_builds_v1, same ProfileCatalog rules); this tool adds the
## family list, the "E10a " profile names and the pending state of the base.
##
## Run: godot --headless --script res://tools/e10a_review_profiles.gd -- <absolute output folder>
## The personal save is never touched: the output folder must be absolute and outside the user
## data directory. A base or kit with no review_builds.json, or not ready_for_play, is "pending".

const E09Profiles = preload("res://tools/e09_review_profiles.gd")
const BASE_ID := &"acolyte"
const DISPLAY_PREFIX := "E10a "
const MAX_DISPLAY_NAME := E09Profiles.MAX_DISPLAY_NAME
const PENDING := E09Profiles.PENDING
const READY := E09Profiles.READY
const INVALID := E09Profiles.INVALID

static func review_display_name(build_name: String) -> String:
	var trimmed := build_name.strip_edges()
	if trimmed.is_empty():
		return DISPLAY_PREFIX.strip_edges()
	var prefixed := DISPLAY_PREFIX + trimmed
	if prefixed.length() <= MAX_DISPLAY_NAME:
		return prefixed
	if trimmed.length() <= MAX_DISPLAY_NAME:
		return trimmed
	return trimmed.left(MAX_DISPLAY_NAME - E09Profiles.ELLIPSIS.length()).strip_edges() + E09Profiles.ELLIPSIS

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

## The family: the base (never has builds, so always pending) and its pure kits, in order.
static func family_ids() -> Array[StringName]:
	var ids: Array[StringName] = [BASE_ID]
	for id: StringName in ClassKitRegistry.pure_ids():
		if ClassKitRegistry.origin(id) == BASE_ID:
			ids.append(id)
	return ids

## Same result shape as E09Profiles.read_builds. The base has no evolution definition, so it is
## answered here: pending when it has no file or is not ready; a base file is not a schema case.
static func read_builds(identity_id: StringName, root: String = E09Profiles.DEFAULT_ROOT, catalog: ProfileCatalog = null) -> Dictionary:
	if identity_id == BASE_ID:
		var result := {"identity_id": identity_id, "status": PENDING, "reason": "", "error_code": &"", "detail": "", "builds": []}
		result["reason"] = "base sem review_builds.json" if not FileAccess.file_exists(root.path_join(String(identity_id)).path_join("review_builds.json")) else "base não tem evolução; builds só nas puras"
		return result
	return E09Profiles.read_builds(identity_id, _tolerant_root(identity_id, root), catalog)

## T7's cultist review_builds.json marks "not learned" skills with rank 0, which the E09 schema
## (rank >= 1) refuses. Zero ranks are dropped into a sanitized copy under .godot/verification;
## the file itself is T7's and stays untouched. Files with no zero rank are read in place.
static func _tolerant_root(identity_id: StringName, root: String) -> String:
	var path := root.path_join(String(identity_id)).path_join("review_builds.json")
	if not FileAccess.file_exists(path):
		return root
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not document is Dictionary or not (document as Dictionary).get("builds") is Array:
		return root
	var changed := false
	for build: Variant in document["builds"]:
		if not build is Dictionary:
			continue
		for key: String in ["base_ranks", "evolution_ranks"]:
			var ranks: Variant = (build as Dictionary).get(key)
			if not ranks is Dictionary:
				continue
			for skill: Variant in (ranks as Dictionary).keys():
				if ranks[skill] is float or ranks[skill] is int:
					if int(ranks[skill]) == 0:
						(ranks as Dictionary).erase(skill)
						changed = true
	if not changed:
		return root
	var sanitized := ProjectSettings.globalize_path("res://.godot/verification/e10a_review_sanitized")
	var target := sanitized.path_join(String(identity_id))
	DirAccess.make_dir_recursive_absolute(target)
	var file := FileAccess.open(target.path_join("review_builds.json"), FileAccess.WRITE)
	if file == null:
		return root
	file.store_string(JSON.stringify(document))
	file.close()
	return sanitized

static func write_all(output_root: String, root: String = E09Profiles.DEFAULT_ROOT, catalog: ProfileCatalog = null) -> Dictionary:
	var report := {"ok": true, "profiles": [], "pending": [], "invalid": []}
	var normalized := output_root.replace("\\", "/").simplify_path().trim_suffix("/")
	var user_root := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if not normalized.is_absolute_path() or normalized == user_root or normalized.begins_with(user_root + "/"):
		report["ok"] = false
		report["error_code"] = &"unsafe_output_folder"
		return report
	var active_catalog := catalog if catalog != null else ProfileCatalog.pilot()
	for identity_id: StringName in family_ids():
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
	var character := CharacterState.new(character_id, review_display_name(String(build["name"])), ClassKitRegistry.origin(identity_id))
	character.evolution_id = identity_id
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = E09Profiles.review_job_xp()
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
