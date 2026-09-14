extends SceneTree

class UncertainStore:
	extends ProfileStore
	var hide_next_success := true

	func commit(source: ProfileState) -> Dictionary:
		var result := super.commit(source)
		if hide_next_success and result["ok"]:
			hide_next_success = false
			return {"ok": false, "error_code": &"save_failed"}
		return result

class DivergentStore:
	extends ProfileStore
	var diverge_next_commit := true

	func commit(source: ProfileState) -> Dictionary:
		if not diverge_next_commit:
			return super.commit(source)
		diverge_next_commit = false
		var different := source.copy_state()
		different.characters[-1].display_name = "Outro resultado"
		var result := super.commit(different)
		return {"ok": false, "error_code": &"save_failed"} if result["ok"] else result

class DefiniteFailStore:
	extends ProfileStore

	func _should_fail(stage: StringName) -> bool:
		return stage == &"write_pending"

class StaleRefreshFailStore:
	extends ProfileStore
	var fail_refresh := false

	func commit(source: ProfileState) -> Dictionary:
		var result := super.commit(source)
		if result.get("error_code", &"") == &"stale_revision":
			fail_refresh = true
		return result

	func load_profile() -> Dictionary:
		if fail_refresh:
			fail_refresh = false
			return {"ok": false, "error_code": &"unsupported_schema", "read_only": true}
		return super.load_profile()

var failures := 0
var checks := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e01_profile_facade")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	_check_create_select_and_restart()
	_check_uncertain_results()
	_check_definite_failure_does_not_publish()
	_check_read_only_propagation()
	_check_run_active_boundary()
	_cleanup_directory(root_directory)
	print("Fachada de perfil E01.3-A: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_create_select_and_restart() -> void:
	var directory := root_directory.path_join("create_select")
	_prepare_directory(directory)
	var catalog := _catalog_with_starters()
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := facade.open_profile()
	_check(opened["ok"] and opened["created_empty"] and opened["profile"].revision == 0, "facade opens a new empty profile without committing it")
	var profile_id: String = opened["profile"].profile_id
	opened["profile"].next_character_counter = 99
	_check(facade.current_profile().next_character_counter == 1, "open and current profile results cannot mutate facade-owned state")

	var first := facade.create_character("create-ana", 0, "Ana", &"swordsman")
	var first_id := IdentityIds.character_id(profile_id, 1)
	_check(first["ok"] and first["new_revision"] == 1 and first["character_id"] == first_id and first["request_id"] == "create-ana", "first creation commits once and correlates its request")
	var first_character: CharacterState = first["profile"].character_by_id(first_id)
	_check(first_character != null and first_character.base_xp_total == 0 and first_character.job_xp_total == 0 and first_character.evolution_id.is_empty(), "new character starts with zero progression and no evolution")
	_check(first_character.purchased_skill_ranks.is_empty() and first_character.presets[0]["active_slots"].slice(0, 2) == [&"slash", &"dash"] and first_character.presets[0]["passive_slots"][0] == &"swordsman_resistance", "free base ranks come from catalog slots and are never stored as purchases")
	_check(first_character.equipped[&"weapon"] == &"training_sword" and first["profile"].equipment_collection == [&"training_sword"], "creation unlocks and equips the catalog starter atomically")
	_check(first["profile"].selected_character_id == first_id and first["profile"].next_character_counter == 2, "creation selects the alt and reserves its monotonic ID")

	var restarted := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var reopened := restarted.open_profile()
	_check(reopened["ok"] and reopened["profile"].character_by_id(first_id) != null and reopened["profile"].selected_character_id == first_id, "committed character and selection survive facade restart")
	var second := restarted.create_character("create-bia", 1, "Bia", &"mage")
	var second_id := IdentityIds.character_id(profile_id, 2)
	_check(second["ok"] and second["new_revision"] == 2 and second["character_id"] == second_id, "second alt consumes the next ID after restart")
	var second_character: CharacterState = second["profile"].character_by_id(second_id)
	_check(second_character.presets[0]["active_slots"].slice(0, 2) == [&"fireball", &"fire_wall"] and second_character.presets[0]["passive_slots"][0] == &"mage_mana_regeneration", "each origin receives only its catalog-declared free loadout")
	_check(second_character.equipped[&"weapon"] == &"apprentice_staff" and second["profile"].equipment_collection == [&"training_sword", &"apprentice_staff"], "starters are shared in the collection without replacing another alt loadout")
	_check(second["profile"].character_by_id(first_id).equipped[&"weapon"] == &"training_sword" and second["profile"].lifetime_stats[&"equipment_unlocked"] == 2, "creating another alt does not leak its build and counts only new starter unlocks")

	var selected := restarted.select_character("select-ana", 2, first_id)
	_check(selected["ok"] and selected["new_revision"] == 3 and selected["selected_character_id"] == first_id, "selection is a durable revisioned transaction")
	var repeated := restarted.select_character("select-ana", 2, first_id)
	_check(not repeated["ok"] and repeated["error_code"] == &"stale_revision" and repeated["current_revision"] == 3, "repeating the original request and revision cannot publish twice")
	var missing := restarted.select_character("select-missing", 3, profile_id + "_99")
	_check(not missing["ok"] and missing["error_code"] == &"invalid_character_id" and restarted.current_profile().revision == 3, "unknown selection fails without a revision")
	var unavailable := restarted.create_character("create-archer", 3, "Cris", &"archer")
	_check(not unavailable["ok"] and unavailable["error_code"] == &"invalid_origin" and restarted.current_profile().next_character_counter == 3, "an unavailable base cannot consume a character ID")
	var invalid_name := restarted.create_character("create-invalid", 3, "", &"swordsman")
	_check(not invalid_name["ok"] and invalid_name["error_code"] == &"invalid_display_name" and restarted.current_profile().next_character_counter == 3, "invalid character data is rejected before publication and preserves the counter")
	var third := restarted.create_character("create-cora", 3, "Cora", &"swordsman")
	_check(third["ok"] and third["character_id"] == IdentityIds.character_id(profile_id, 3), "the next successful creation uses the unconsumed monotonic ID")

	var revision: int = third["new_revision"]
	for counter: int in range(4, ProfileState.MAX_CHARACTERS + 1):
		var filled := restarted.create_character("create-%d" % counter, revision, "Alt %d" % counter, &"mage")
		_check(filled["ok"] and filled["character_id"] == IdentityIds.character_id(profile_id, counter), "alt %d fills a distinct slot" % counter)
		revision = filled["new_revision"]
	var before_limit := restarted.current_profile()
	var over_limit := restarted.create_character("create-nine", revision, "Nona", &"swordsman")
	_check(not over_limit["ok"] and over_limit["error_code"] == &"character_limit" and restarted.current_profile().revision == before_limit.revision and restarted.current_profile().next_character_counter == 9, "ninth alt is rejected without consuming revision or ID")
	var selected_id: String = restarted.current_profile().selected_character_id
	var no_op := restarted.select_character("select-current", revision, selected_id)
	_check(no_op["ok"] and no_op["already_applied"] and no_op["new_revision"] == revision, "selecting the current alt is an explicit no-op without a write")
	var invalid_request := restarted.select_character("", revision, selected_id)
	_check(not invalid_request["ok"] and invalid_request["error_code"] == &"invalid_request_id", "menu operations require a bounded request ID")
	var ambiguous_starters := ProfileCatalog.pilot({
		&"first_sword": {"slot": &"weapon", "allowed_base_classes": [&"swordsman"], "starter": true},
		&"second_sword": {"slot": &"weapon", "allowed_base_classes": [&"swordsman"], "starter": true},
	})
	_check(not ambiguous_starters.is_valid(), "catalog rejects more than one starter for the same origin and slot")

func _check_uncertain_results() -> void:
	var catalog := _catalog_with_starters()
	var uncertain_directory := root_directory.path_join("uncertain_success")
	_prepare_directory(uncertain_directory)
	var uncertain := ProfileFacade.new(UncertainStore.new(uncertain_directory, catalog))
	var opened := uncertain.open_profile()
	var profile_id: String = opened["profile"].profile_id
	var recovered := uncertain.create_character("uncertain-create", 0, "Dora", &"swordsman")
	_check(recovered["ok"] and recovered["recovered_after_uncertain_result"] and recovered["new_revision"] == 1, "facade confirms an uncertain return only after rereading the exact committed candidate")
	var retry := uncertain.create_character("uncertain-create", 0, "Dora", &"swordsman")
	_check(not retry["ok"] and retry["error_code"] == &"stale_revision" and uncertain.current_profile().characters.size() == 1, "retry after recovered uncertainty cannot duplicate character creation")
	var durable := ProfileStore.new(uncertain_directory, catalog).load_profile()
	_check(durable["ok"] and durable["profile"].character_by_id(IdentityIds.character_id(profile_id, 1)) != null, "uncertain recovery publishes only the durable character")

	var divergent_directory := root_directory.path_join("uncertain_divergent")
	_prepare_directory(divergent_directory)
	var divergent := ProfileFacade.new(DivergentStore.new(divergent_directory, catalog))
	var divergent_open := divergent.open_profile()
	var divergent_result := divergent.create_character("divergent-create", 0, "Eva", &"swordsman")
	_check(not divergent_result["ok"] and divergent_result["error_code"] == &"result_uncertain" and divergent_result["read_only"], "a different durable result is never claimed as the requested mutation")
	_check(divergent.current_profile().profile_id == divergent_open["profile"].profile_id and divergent.current_profile().characters.is_empty(), "divergent uncertainty does not publish either candidate in facade memory")
	var blocked := divergent.create_character("blocked-after-divergence", 0, "Eva", &"swordsman")
	_check(not blocked["ok"] and blocked["error_code"] == &"result_uncertain" and blocked["read_only"], "divergent result keeps the facade read-only until an explicit reload")
	var reconciled := divergent.open_profile()
	_check(reconciled["ok"] and reconciled["profile"].characters[0].display_name == "Outro resultado", "explicit reload exposes the durable divergent state before further commands")

func _check_definite_failure_does_not_publish() -> void:
	var directory := root_directory.path_join("definite_failure")
	_prepare_directory(directory)
	var facade := ProfileFacade.new(DefiniteFailStore.new(directory, _catalog_with_starters()))
	var opened := facade.open_profile()
	var failed := facade.create_character("failed-create", 0, "Fabi", &"swordsman")
	var current := facade.current_profile()
	_check(not failed["ok"] and failed["error_code"] == &"save_failed", "definite write failure is reported without claiming success")
	_check(current.profile_id == opened["profile"].profile_id and current.revision == 0 and current.characters.is_empty() and current.next_character_counter == 1, "failed commit leaves the published profile and monotonic counter untouched")
	_check(not FileAccess.file_exists(directory.path_join(ProfileStore.PRIMARY_FILE)) and not FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "failure before pending write leaves no durable transaction artifact")

func _check_read_only_propagation() -> void:
	var catalog := _catalog_with_starters()
	var reopen_directory := root_directory.path_join("read_only_reopen")
	_prepare_directory(reopen_directory)
	var facade := ProfileFacade.new(ProfileStore.new(reopen_directory, catalog))
	var created := facade.create_character("create-before-future", 0, "Iara", &"swordsman")
	var original_text := _read_text(reopen_directory.path_join(ProfileStore.PRIMARY_FILE))
	_write_text(reopen_directory.path_join(ProfileStore.PRIMARY_FILE), JSON.stringify({"schema_version": 99}))
	var failed_open := facade.open_profile()
	_check(not failed_open["ok"] and failed_open["error_code"] == &"unsupported_schema" and failed_open["read_only"], "failed reopen publishes the incompatible reason and enters read-only mode")
	var blocked_no_op := facade.select_character("blocked-no-op", created["new_revision"], created["character_id"])
	_check(not blocked_no_op["ok"] and blocked_no_op["error_code"] == &"unsupported_schema" and blocked_no_op["read_only"], "read-only state blocks even a selection that would otherwise be a no-op")
	_check(facade.current_profile().character_by_id(created["character_id"]) != null, "failed reopen may retain the former snapshot for display without certifying commands")
	_write_text(reopen_directory.path_join(ProfileStore.PRIMARY_FILE), original_text)
	var reopened := facade.open_profile()
	var released_no_op := facade.select_character("released-no-op", reopened["profile"].revision, created["character_id"])
	_check(reopened["ok"] and released_no_op["ok"] and released_no_op["already_applied"], "successful explicit reopen clears read-only mode and permits commands again")

	var stale_directory := root_directory.path_join("read_only_stale_refresh")
	_prepare_directory(stale_directory)
	var stale_store := StaleRefreshFailStore.new(stale_directory, catalog)
	var stale_facade := ProfileFacade.new(stale_store)
	var stale_created := stale_facade.create_character("stale-first", 0, "Joana", &"swordsman")
	var external_store := ProfileStore.new(stale_directory, catalog)
	var external := external_store.load_profile()
	var external_profile: ProfileState = external["profile"]
	external_profile.settings["external_revision"] = true
	var external_commit := external_store.commit(external_profile)
	_check(external_commit["ok"], "stale refresh fixture advances disk through a separate test writer")
	var refresh_failed := stale_facade.create_character("stale-second", stale_created["new_revision"], "Katia", &"mage")
	_check(not refresh_failed["ok"] and refresh_failed["error_code"] == &"unsupported_schema" and refresh_failed["read_only"], "failed refresh after stale propagates its reason and blocks the facade")
	var stale_blocked := stale_facade.select_character("stale-blocked", stale_created["new_revision"], stale_created["character_id"])
	_check(not stale_blocked["ok"] and stale_blocked["error_code"] == &"unsupported_schema" and stale_blocked["read_only"], "stale refresh failure cannot fall through to an old in-memory no-op")
	var stale_reopened := stale_facade.open_profile()
	_check(stale_reopened["ok"] and stale_reopened["profile"].revision == external_commit["new_revision"], "explicit successful reload reconciles and releases a stale-blocked facade")

func _check_run_active_boundary() -> void:
	var directory := root_directory.path_join("run_active")
	_prepare_directory(directory)
	var catalog := _catalog_with_starters()
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var created := facade.create_character("bootstrap", 0, "Gabi", &"swordsman")
	var activated := facade.start_run("bootstrap-run", created["new_revision"])
	_check(activated["ok"], "run-active fixture is durably valid")
	var create_blocked := facade.create_character("blocked-create", activated["new_revision"], "Hugo", &"mage")
	var select_blocked := facade.select_character("blocked-select", activated["new_revision"], created["character_id"])
	_check(not create_blocked["ok"] and create_blocked["error_code"] == &"run_active" and not select_blocked["ok"] and select_blocked["error_code"] == &"run_active", "create and select remain menu-only while a durable run session is active")

func _catalog_with_starters() -> ProfileCatalog:
	return ProfileCatalog.pilot({
		&"training_sword": {"slot": &"weapon", "allowed_base_classes": [&"swordsman"], "starter": true},
		&"apprentice_staff": {"slot": &"weapon", "allowed_base_classes": [&"mage"], "starter": true},
	})

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write test fixture: %s" % path)
		return
	file.store_string(text)
	file.close()

func _prepare_directory(path: String) -> void:
	_cleanup_directory(path)
	DirAccess.make_dir_recursive_absolute(path)

func _cleanup_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	for child: String in directory.get_directories():
		_cleanup_directory(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
