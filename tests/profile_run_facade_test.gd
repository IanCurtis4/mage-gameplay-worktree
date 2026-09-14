extends SceneTree

class ToggleFailStore:
	extends ProfileStore
	var fail_writes := false

	func _should_fail(stage: StringName) -> bool:
		return fail_writes and stage == &"write_pending"

class ToggleUncertainStore:
	extends ProfileStore
	var hide_next_success := false

	func commit(source: ProfileState) -> Dictionary:
		var result := super.commit(source)
		if hide_next_success and result["ok"]:
			hide_next_success = false
			return {"ok": false, "error_code": &"save_failed"}
		return result

var failures := 0
var checks := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e01_profile_run_facade")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	_check_run_reward_and_end_flow()
	_check_start_preconditions()
	_check_reward_resolver_boundary()
	_check_write_failures_and_uncertainty()
	_check_abandoned_session_reopen()
	_cleanup_directory(root_directory)
	print("Sessão e recompensas E01.3-B: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_run_reward_and_end_flow() -> void:
	var directory := root_directory.path_join("full_flow")
	_prepare_directory(directory)
	var catalog := _catalog()
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog), _rewards())
	var first := facade.create_character("create-ana", 0, "Ana", &"swordsman")
	var second := facade.create_character("create-bia", 1, "Bia", &"mage")
	var selected := facade.select_character("select-ana", 2, first["character_id"])
	_check(first["ok"] and second["ok"] and selected["ok"] and selected["new_revision"] == 3, "two alts are durably ready before the run")

	var started := facade.start_run("start-1", 3)
	var run_id: String = started["run_id"]
	var run_state: RunState = started["run_state"]
	_check(started["ok"] and started["new_revision"] == 4 and run_id == IdentityIds.run_id(started["profile"].profile_id, 1), "start_run reserves and commits the first monotonic run ID")
	_check(started["profile"].next_run_counter == 2 and started["profile"].reward_session["last_committed_seq"] == 0 and started["profile"].lifetime_stats[&"runs_started"] == 1, "run counter, reward cursor and runs_started share the start commit")
	_check(run_state.character_id == first["character_id"] and run_state.build_snapshot.base_level == 1 and run_state.build_snapshot.job_level == 1, "runtime receives the selected character and derived levels")
	_check(run_state.skill_levels[&"slash"] == 1 and run_state.skill_levels[&"dash"] == 1 and run_state.build_snapshot.equipped[&"weapon"] == &"training_sword", "snapshot contains effective free ranks and selected preset equipment")
	run_state.build_snapshot.attribute_allocations[&"str"] = 50
	run_state.skill_levels[&"slash"] = 5
	run_state.augment_stacks[&"vitality"] = 3
	var persistent_after_runtime_mutation := facade.current_profile().character_by_id(first["character_id"])
	_check(persistent_after_runtime_mutation.attribute_allocations[&"str"] == 0 and persistent_after_runtime_mutation.purchased_skill_ranks.is_empty(), "runtime snapshot, ranks and augments cannot mutate persistent character state")
	var duplicate_start := facade.start_run("start-1", 3)
	var active_start := facade.start_run("start-2", 4)
	_check(not duplicate_start["ok"] and duplicate_start["error_code"] == &"stale_revision" and not active_start["ok"] and active_start["error_code"] == &"run_active", "stale retry and second active run are rejected without reserving another ID")

	var wrong_run := facade.grant_reward("reward-wrong-run", 4, IdentityIds.run_id(started["profile"].profile_id, 99), 1, &"encounter_one")
	var gap := facade.grant_reward("reward-gap", 4, run_id, 2, &"encounter_two")
	var unknown := facade.grant_reward("reward-unknown", 4, run_id, 1, &"ui_supplied_values")
	_check(not wrong_run["ok"] and wrong_run["error_code"] == &"invalid_reward_sequence" and not gap["ok"] and gap["error_code"] == &"invalid_reward_sequence", "wrong run and sequence gap cannot mutate rewards")
	_check(not unknown["ok"] and unknown["error_code"] == &"invalid_reward" and facade.current_profile().revision == 4, "UI can select only a locally resolved reward ID")

	var reward_one := facade.grant_reward("reward-1", 4, run_id, 1, &"encounter_one")
	var rewarded_character: CharacterState = reward_one["profile"].character_by_id(first["character_id"])
	_check(reward_one["ok"] and reward_one["new_revision"] == 5 and rewarded_character.base_xp_total == 100 and rewarded_character.job_xp_total == 80, "next reward applies base/job XP in one commit")
	_check(reward_one["profile"].reward_session["last_committed_seq"] == 1 and reward_one["profile"].lifetime_stats[&"kills"] == 2, "reward stats and cursor advance atomically")
	_check(&"reward_blade" in reward_one["profile"].equipment_collection and reward_one["profile"].lifetime_stats[&"equipment_unlocked"] == 3, "new reward equipment joins the shared collection and increments its stat once")
	_check(reward_one["profile"].character_by_id(second["character_id"]).base_xp_total == 0, "reward origin is fixed to the session character, not the other alt")
	var stale_reward_retry := facade.grant_reward("reward-1", 4, run_id, 1, &"encounter_one")
	var replay := facade.grant_reward("reward-1-confirm", 5, run_id, 1, &"encounter_one")
	_check(not stale_reward_retry["ok"] and stale_reward_retry["error_code"] == &"stale_revision" and replay["ok"] and replay["already_applied"] and replay["new_revision"] == 5, "original revision cannot duplicate reward and committed seq replays as an explicit no-op")

	var reward_two := facade.grant_reward("reward-2", 5, run_id, 2, &"encounter_two")
	var twice_rewarded: CharacterState = reward_two["profile"].character_by_id(first["character_id"])
	_check(reward_two["ok"] and reward_two["new_revision"] == 6 and twice_rewarded.base_xp_total == 250 and twice_rewarded.job_xp_total == 180, "strict next sequence applies the second resolved XP payload")
	_check(reward_two["profile"].lifetime_stats[&"kills"] == 3 and reward_two["profile"].lifetime_stats[&"equipment_unlocked"] == 3, "duplicate equipment never duplicates collection or unlock stats")

	var wrong_end := facade.end_run("end-wrong", 6, IdentityIds.run_id(reward_two["profile"].profile_id, 99), &"completed")
	var invalid_end := facade.end_run("end-invalid", 6, run_id, &"victoryish")
	_check(not wrong_end["ok"] and wrong_end["error_code"] == &"invalid_reward_sequence" and not invalid_end["ok"] and invalid_end["error_code"] == &"invalid_run_outcome", "end_run validates session identity and enumerated outcome")
	var ended := facade.end_run("end-completed", 6, run_id, &"completed")
	_check(ended["ok"] and ended["new_revision"] == 7 and ended["profile"].reward_session == null and ended["profile"].lifetime_stats[&"runs_completed"] == 1, "completed run closes the session and records completion once")
	var closed_reward := facade.grant_reward("reward-after-end", 7, run_id, 3, &"encounter_two")
	var closed_end := facade.end_run("end-again", 7, run_id, &"completed")
	_check(not closed_reward["ok"] and closed_reward["error_code"] == &"run_inactive" and not closed_end["ok"] and closed_end["error_code"] == &"run_inactive", "closed session rejects reward and end replays")
	_check(facade.current_profile().lifetime_stats[&"runs_completed"] == 1, "end replay cannot duplicate completion stats")

	var second_run := facade.start_run("start-2", 7)
	var death := facade.end_run("end-death", 8, second_run["run_id"], &"death")
	_check(second_run["ok"] and second_run["run_id"] == IdentityIds.run_id(death["profile"].profile_id, 2) and death["profile"].next_run_counter == 3, "later run consumes a new ID and never reuses the closed session")
	_check(run_state.build_snapshot.base_level == 1 and second_run["run_state"].build_snapshot.base_level == 3 and second_run["run_state"].build_snapshot.job_level == 3, "confirmed XP affects only the next run snapshot and derives levels centrally")
	_check(death["ok"] and death["profile"].lifetime_stats[&"deaths"] == 1 and death["profile"].lifetime_stats[&"runs_completed"] == 1, "death closes the run without inventing a completion")

func _check_start_preconditions() -> void:
	var catalog := _catalog()
	var empty_directory := root_directory.path_join("empty_profile")
	_prepare_directory(empty_directory)
	var empty := ProfileFacade.new(ProfileStore.new(empty_directory, catalog), _rewards())
	var empty_start := empty.start_run("start-empty", 0)
	_check(not empty_start["ok"] and empty_start["error_code"] == &"invalid_character_id", "run cannot start without a selected character")

	var loadout_directory := root_directory.path_join("invalid_loadout")
	_prepare_directory(loadout_directory)
	var loadout_facade := ProfileFacade.new(ProfileStore.new(loadout_directory, catalog), _rewards())
	var created := loadout_facade.create_character("create-loadout", 0, "Lia", &"swordsman")
	var invalid_profile: ProfileState = created["profile"]
	var invalid_character := invalid_profile.character_by_id(created["character_id"])
	for index: int in CharacterState.ACTIVE_SLOT_COUNT:
		invalid_character.presets[invalid_character.selected_preset]["active_slots"][index] = null
	var invalid_commit := ProfileStore.new(loadout_directory, catalog).commit(invalid_profile)
	var invalid_facade := ProfileFacade.new(ProfileStore.new(loadout_directory, catalog), _rewards())
	var invalid_open := invalid_facade.open_profile()
	var invalid_start := invalid_facade.start_run("start-invalid-loadout", invalid_open["profile"].revision)
	_check(invalid_commit["ok"] and not invalid_start["ok"] and invalid_start["error_code"] == &"invalid_loadout", "structurally valid empty active slots do not prove run readiness")

	var pending_directory := root_directory.path_join("pending_start")
	_prepare_directory(pending_directory)
	var pending_facade := ProfileFacade.new(ProfileStore.new(pending_directory, catalog), _rewards())
	var pending_created := pending_facade.create_character("create-pending", 0, "Mia", &"swordsman")
	_write_text(pending_directory.path_join(ProfileStore.PENDING_FILE), "{}")
	var pending_start := pending_facade.start_run("start-pending", pending_created["new_revision"])
	_check(not pending_start["ok"] and pending_start["error_code"] == &"recovery_required" and pending_start["read_only"], "pending transaction blocks run reservation")
	_check(pending_facade.current_profile().next_run_counter == 1 and pending_facade.current_profile().reward_session == null, "blocked pending start publishes no run state or counter")

func _check_write_failures_and_uncertainty() -> void:
	var catalog := _catalog()
	var fail_directory := root_directory.path_join("write_failures")
	_prepare_directory(fail_directory)
	var fail_store := ToggleFailStore.new(fail_directory, catalog)
	var facade := ProfileFacade.new(fail_store, _rewards())
	var created := facade.create_character("failure-create", 0, "Nina", &"swordsman")
	fail_store.fail_writes = true
	var failed_start := facade.start_run("failure-start", created["new_revision"])
	_check(not failed_start["ok"] and failed_start["error_code"] == &"save_failed" and facade.current_profile().next_run_counter == 1 and facade.current_profile().reward_session == null, "failed start commit publishes neither run ID nor session")
	fail_store.fail_writes = false
	var started := facade.start_run("retry-start", created["new_revision"])
	fail_store.fail_writes = true
	var failed_reward := facade.grant_reward("failure-reward", started["new_revision"], started["run_id"], 1, &"encounter_one")
	_check(not failed_reward["ok"] and failed_reward["error_code"] == &"save_failed" and facade.current_profile().character_by_id(created["character_id"]).base_xp_total == 0 and facade.current_profile().reward_session["last_committed_seq"] == 0, "failed reward commit publishes neither XP nor cursor")
	fail_store.fail_writes = false
	var retried_reward := facade.grant_reward("retry-reward", started["new_revision"], started["run_id"], 1, &"encounter_one")
	_check(retried_reward["ok"] and retried_reward["profile"].character_by_id(created["character_id"]).base_xp_total == 100, "same uncommitted sequence can succeed after a definite failure")

	var uncertain_directory := root_directory.path_join("uncertain_reward")
	_prepare_directory(uncertain_directory)
	var uncertain_store := ToggleUncertainStore.new(uncertain_directory, catalog)
	var uncertain := ProfileFacade.new(uncertain_store, _rewards())
	var uncertain_created := uncertain.create_character("uncertain-create", 0, "Olga", &"swordsman")
	var uncertain_started := uncertain.start_run("uncertain-start", uncertain_created["new_revision"])
	uncertain_store.hide_next_success = true
	var uncertain_reward := uncertain.grant_reward("uncertain-reward", uncertain_started["new_revision"], uncertain_started["run_id"], 1, &"encounter_one")
	_check(uncertain_reward["ok"] and uncertain_reward["recovered_after_uncertain_result"] and uncertain_reward["profile"].reward_session["last_committed_seq"] == 1, "uncertain reward result is confirmed only by exact durable reread")
	var uncertain_replay := uncertain.grant_reward("uncertain-replay", uncertain_reward["new_revision"], uncertain_started["run_id"], 1, &"encounter_one")
	_check(uncertain_replay["ok"] and uncertain_replay["already_applied"] and uncertain.current_profile().character_by_id(uncertain_created["character_id"]).base_xp_total == 100, "confirmed uncertain reward cannot be applied twice")
	uncertain_store.hide_next_success = true
	var uncertain_end := uncertain.end_run("uncertain-end", uncertain_reward["new_revision"], uncertain_started["run_id"], &"completed")
	_check(uncertain_end["ok"] and uncertain_end["recovered_after_uncertain_result"] and uncertain_end["profile"].reward_session == null and uncertain_end["profile"].lifetime_stats[&"runs_completed"] == 1, "uncertain end result closes and counts the run exactly once after reread")

func _check_reward_resolver_boundary() -> void:
	var invalid := ProfileRewardResolver.new({
		&"invalid_reward": {"base_xp": 10, "stat_increments": {&"runs_started": 1}},
	})
	_check(not invalid.is_valid() and not invalid.copy_resolver().is_valid(), "invalid local reward definitions remain invalid across facade copies")
	var directory := root_directory.path_join("invalid_resolver")
	_prepare_directory(directory)
	var facade := ProfileFacade.new(ProfileStore.new(directory, _catalog()), invalid)
	var created := facade.create_character("resolver-create", 0, "Rita", &"swordsman")
	var rejected_start := facade.start_run("resolver-start", created["new_revision"])
	_check(not rejected_start["ok"] and rejected_start["error_code"] == &"invalid_catalog" and facade.current_profile().reward_session == null and facade.current_profile().next_run_counter == 1, "invalid resolver cannot start a session or reserve a run ID")

	var unknown_directory := root_directory.path_join("unknown_reward_equipment")
	_prepare_directory(unknown_directory)
	var unknown_resolver := ProfileRewardResolver.new({
		&"unknown_item": {"equipment_ids": [&"not_in_profile_catalog"]},
	})
	var unknown_facade := ProfileFacade.new(ProfileStore.new(unknown_directory, _catalog()), unknown_resolver)
	var unknown_created := unknown_facade.create_character("unknown-create", 0, "Sara", &"swordsman")
	var unknown_start := unknown_facade.start_run("unknown-start", unknown_created["new_revision"])
	_check(not unknown_start["ok"] and unknown_start["error_code"] == &"invalid_catalog" and unknown_facade.current_profile().reward_session == null, "reward equipment absent from the profile catalog blocks the run before reserving its session")

	var cap_directory := root_directory.path_join("xp_caps")
	_prepare_directory(cap_directory)
	var cap_facade := ProfileFacade.new(ProfileStore.new(cap_directory, _catalog()), _rewards())
	var cap_created := cap_facade.create_character("cap-create", 0, "Tainá", &"swordsman")
	var cap_started := cap_facade.start_run("cap-start", cap_created["new_revision"])
	var capped := cap_facade.grant_reward("cap-reward", cap_started["new_revision"], cap_started["run_id"], 1, &"cap_reward")
	var capped_character: CharacterState = capped["profile"].character_by_id(cap_created["character_id"])
	_check(capped["ok"] and capped_character.base_xp_total == ProgressionRules.MAX_BASE_XP and capped_character.job_xp_total == ProgressionRules.UNEVOLVED_MAX_JOB_XP, "reward addition saturates accepted XP caps instead of creating an invalid profile")

func _check_abandoned_session_reopen() -> void:
	var directory := root_directory.path_join("abandoned")
	_prepare_directory(directory)
	var catalog := _catalog()
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog), _rewards())
	var created := facade.create_character("abandoned-create", 0, "Pia", &"swordsman")
	var started := facade.start_run("abandoned-start", created["new_revision"])
	var rewarded := facade.grant_reward("abandoned-reward", started["new_revision"], started["run_id"], 1, &"encounter_one")
	var restarted := ProfileFacade.new(ProfileStore.new(directory, catalog), _rewards())
	var reopened := restarted.open_profile()
	var character: CharacterState = reopened["profile"].character_by_id(created["character_id"])
	_check(reopened["ok"] and reopened["abandoned_run_closed"] and reopened["abandoned_run_id"] == started["run_id"] and reopened["profile"].reward_session == null, "reopen durably closes an abandoned session instead of resuming combat")
	_check(character.base_xp_total == 100 and character.job_xp_total == 80 and reopened["profile"].lifetime_stats[&"runs_completed"] == 0 and reopened["profile"].lifetime_stats[&"deaths"] == 0, "abandoned close preserves confirmed rewards without inventing end rewards or outcomes")
	var replay := restarted.grant_reward("abandoned-replay", reopened["new_revision"], started["run_id"], 2, &"encounter_two")
	_check(not replay["ok"] and replay["error_code"] == &"run_inactive", "closed abandoned session rejects later reward replay")

	var fail_directory := root_directory.path_join("abandoned_close_failure")
	_prepare_directory(fail_directory)
	var bootstrap := ProfileFacade.new(ProfileStore.new(fail_directory, catalog), _rewards())
	var fail_created := bootstrap.create_character("close-fail-create", 0, "Quézia", &"swordsman")
	var fail_started := bootstrap.start_run("close-fail-start", fail_created["new_revision"])
	var fail_store := ToggleFailStore.new(fail_directory, catalog)
	fail_store.fail_writes = true
	var blocked_facade := ProfileFacade.new(fail_store, _rewards())
	var failed_open := blocked_facade.open_profile()
	_check(not failed_open["ok"] and failed_open["error_code"] == &"save_failed" and failed_open["read_only"], "failed abandoned-session close leaves the facade read-only")
	var blocked_start := blocked_facade.start_run("blocked-new-run", fail_started["new_revision"])
	_check(not blocked_start["ok"] and blocked_start["error_code"] == &"save_failed" and blocked_start["read_only"], "new run remains blocked after abandoned close failure")
	fail_store.fail_writes = false
	var recovered := blocked_facade.open_profile()
	_check(recovered["ok"] and recovered["abandoned_run_closed"] and recovered["profile"].reward_session == null, "successful explicit reopen retries and durably closes the abandoned session")

func _catalog() -> ProfileCatalog:
	return ProfileCatalog.pilot({
		&"training_sword": {"slot": &"weapon", "allowed_base_classes": [&"swordsman"], "starter": true},
		&"apprentice_staff": {"slot": &"weapon", "allowed_base_classes": [&"mage"], "starter": true},
		&"reward_blade": {"slot": &"weapon", "allowed_base_classes": [&"swordsman"]},
	})

func _rewards() -> ProfileRewardResolver:
	return ProfileRewardResolver.new({
		&"encounter_one": {
			"base_xp": 100,
			"job_xp": 80,
			"equipment_ids": [&"reward_blade"],
			"stat_increments": {&"kills": 2},
		},
		&"encounter_two": {
			"base_xp": 150,
			"job_xp": 100,
			"equipment_ids": [&"reward_blade"],
			"stat_increments": {&"kills": 1},
		},
		&"cap_reward": {
			"base_xp": ProfileRewardResolver.MAX_EXACT_INTEGER,
			"job_xp": ProfileRewardResolver.MAX_EXACT_INTEGER,
		},
	})

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
