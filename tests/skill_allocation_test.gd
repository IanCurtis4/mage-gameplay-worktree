extends SceneTree

class TrackingStore:
	extends ProfileStore
	var load_count := 0
	var commit_count := 0
	var failure_stage: StringName = &""
	var hide_reads := 0
	var uncertain_rename_commit := false

	func load_profile() -> Dictionary:
		load_count += 1
		if hide_reads > 0:
			hide_reads -= 1
			return {"ok": false, "error_code": &"result_uncertain", "read_only": true}
		return super.load_profile()

	func commit(source: ProfileState) -> Dictionary:
		commit_count += 1
		var result := super.commit(source)
		if uncertain_rename_commit and result.get("ok", false):
			uncertain_rename_commit = false
			hide_reads = 1
			return {"ok": false, "error_code": &"save_failed"}
		return result

	func _should_fail(stage: StringName) -> bool:
		return stage == failure_stage and not failure_stage.is_empty()

const DEPENDENCY_SKILLS := {
	&"feedback_followup": {
		"allowed_base_classes": [&"mage"],
		"category": ProfileCatalog.ACTIVE,
		"wallet": ProfileCatalog.BASE_WALLET,
		"free_rank": 0,
		"max_purchased_rank": 1,
		"rank_requirements": {
			1: {"job_level": 1, "skill_ranks": {&"fire_spear": 1}},
		},
	},
}

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174000"
var checks := 0
var failures := 0
var fixture_root := ""
var fixture_serial := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	fixture_root = ProjectSettings.globalize_path("res://.godot/verification/e06_skill_allocation")
	_cleanup_directory(fixture_root)
	DirAccess.make_dir_recursive_absolute(fixture_root)
	await _preview_is_read_only_and_ordered()
	await _profile_transaction_and_wallets()
	await _draft_rejects_invalid_changes()
	await _draft_failure_and_uncertainty()
	await _active_run_is_read_only()
	_cleanup_directory(fixture_root)
	print("E06 skill allocation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _preview_is_read_only_and_ordered() -> void:
	var unopened_fixture := _new_unopened_fixture("preview_unopened", ProfileCatalog.pilot({}, DEPENDENCY_SKILLS))
	var unopened_facade: ProfileFacade = unopened_fixture["facade"]
	var unopened_store: TrackingStore = unopened_fixture["store"]
	var unopened := unopened_facade.skill_allocation_preview("unopened", 0, [])
	_check(not unopened["ok"] and unopened["error_code"] == &"profile_unavailable" and unopened_store.load_count == 0 and unopened_store.commit_count == 0, "preview on an unopened facade does not load, create or repair a profile")
	_cleanup_fixture(unopened_fixture)
	var fixture := _new_fixture("preview", ProfileCatalog.pilot({}, DEPENDENCY_SKILLS))
	var facade: ProfileFacade = fixture["facade"]
	var store: TrackingStore = fixture["store"]
	var character_id: String = fixture["character_id"]
	assert(_grant_max_levels(facade, character_id, "preview-max")["ok"])
	var profile: ProfileState = facade.current_profile()
	var before_revision := profile.revision
	var before_record := ProfileCodec.encode(profile, fixture["catalog"])
	var loads_before := store.load_count
	var commits_before := store.commit_count
	var missing_profile := facade.skill_allocation_preview("missing", before_revision, [])
	var legal := facade.skill_allocation_preview(character_id, before_revision, [&"fire_wall", &"fire_wall", &"fire_spear", &"feedback_followup"])
	var bad_order := facade.skill_allocation_preview(character_id, before_revision, [&"feedback_followup", &"fire_wall", &"fire_wall", &"fire_spear"])
	var after_record := ProfileCodec.encode(facade.current_profile(), fixture["catalog"])
	_check(not missing_profile["ok"] and missing_profile["error_code"] == &"invalid_character_id", "preview rejects an unknown character without mutating the opened profile")
	_check(legal["ok"] and legal["can_apply"] and legal["pending_counts"][&"fire_wall"] == 2 and legal["pending_counts"][&"fire_spear"] == 1 and legal["pending_counts"][&"feedback_followup"] == 1, "preview simulates an ordered skill prerequisite through the canonical progression rules")
	_check(not bad_order["ok"] and bad_order["error_code"] == &"requirements_unmet" and bad_order["failed_index"] == 0, "preview rejects a dependent rank when submitted before its prerequisite")
	_check(store.load_count == loads_before and store.commit_count == commits_before and facade.current_profile().revision == before_revision and before_record["text"] == after_record["text"], "repeated previews perform no store IO and leave the profile byte-equivalent")
	_check(legal["original_ranks"].get(&"fire_spear", 0) == 0 and legal["summary"]["effective_skill_ranks"].get(&"fire_spear", 0) == 1, "preview exposes copied original and simulated ranks separately")
	_cleanup_fixture(fixture)
	await process_frame

func _profile_transaction_and_wallets() -> void:
	var fixture := _new_fixture("wallets", ProfileCatalog.pilot())
	var facade: ProfileFacade = fixture["facade"]
	var mage_id: String = fixture["character_id"]
	var mage := _grant_max_levels(facade, mage_id, "mage-max")
	_check(mage["ok"], "isolated mage fixture receives XP through the playtest progression API")
	var evolved_id := _create_character(facade, &"mage", "Elementalista")
	_check(_grant_max_levels(facade, evolved_id, "elemental-prep")["ok"], "evolution fixture receives real progression XP before evolution")
	var evolution := facade.change_evolution("elementalist-evolution", _revision(facade), evolved_id, &"elementalist")
	_check(evolution["ok"], "production mage fixture evolves through its catalog definition")
	_check(_grant_max_levels(facade, evolved_id, "elementalist-max")["ok"], "evolved fixture receives XP through the same progression API")
	var before := facade.progression_summary(evolved_id)
	var before_revision := _revision(facade)
	var ordered: Array[StringName] = [&"fire_wall", &"fire_wall", &"fire_spear", &"elementalist_flame_burst"]
	var preview := facade.skill_allocation_preview(evolved_id, before_revision, ordered)
	var committed := facade.apply_skill_allocations("two-wallet-batch", before_revision, evolved_id, ordered)
	var after := facade.progression_summary(evolved_id)
	var profile: ProfileState = facade.current_profile()
	var evolved: CharacterState = profile.character_by_id(evolved_id)
	_check(preview["ok"] and preview["pending_counts"][&"fire_wall"] == 2 and preview["pending_counts"][&"fire_spear"] == 1 and preview["pending_counts"][&"elementalist_flame_burst"] == 1, "production preview accepts base and evolved skill ranks in one ordered batch")
	_check(committed["ok"] and committed["new_revision"] == before_revision + 1 and _revision(facade) == before_revision + 1, "a full multi-skill batch persists in exactly one profile revision")
	_check(evolved.purchased_skill_ranks.get(&"fire_wall", 0) == 2 and evolved.purchased_skill_ranks.get(&"fire_spear", 0) == 1 and evolved.purchased_skill_ranks.get(&"elementalist_flame_burst", 0) == 1, "committed batch applies both canonical ranks to the evolved character")
	_check(after["base_skill_points_available"] == before["base_skill_points_available"] - 3 and after["evolution_skill_points_available"] == before["evolution_skill_points_available"] - 1, "base and evolution ranks spend only their matching production wallets")

	var floor_id := _create_character(facade, &"mage", "Sem pontos")
	var floor_revision := _revision(facade)
	var floor_profile := facade.current_profile()
	var floor_profile_record := ProfileCodec.encode(floor_profile, fixture["catalog"])
	var empty := facade.apply_skill_allocations("empty-batch", floor_revision, floor_id, [])
	var no_wallet := facade.apply_skill_allocations("grant-floor", floor_revision, floor_id, [&"fire_wall", &"fire_wall", &"fire_spear"])
	var invalid_id := facade.apply_skill_allocations("bad-skill-id", floor_revision, floor_id, [&"not_a_published_skill"])
	var invalid_type := facade.skill_allocation_preview(floor_id, floor_revision, [4])
	var partial_id := _create_character(facade, &"mage", "Lote inválido")
	_check(_grant_max_levels(facade, partial_id, "partial-max")["ok"], "partial-batch fixture receives canonical XP points")
	var partial_revision := _revision(facade)
	var partial_before := ProfileCodec.encode(facade.current_profile(), fixture["catalog"])
	var partial := facade.apply_skill_allocations("partial-invalid", partial_revision, partial_id, [&"fire_wall", &"fire_wall", &"fire_spear", "not_a_published_skill"])
	var unchanged := ProfileCodec.encode(facade.current_profile(), fixture["catalog"])
	_check(not empty["ok"] and empty["error_code"] == &"invalid_skill_allocations" and not no_wallet["ok"] and no_wallet["error_code"] == &"insufficient_points", "empty batches and ranks below the XP grant floor are rejected")
	_check(not invalid_id["ok"] and invalid_id["error_code"] == &"invalid_skill_id" and not invalid_type["ok"] and invalid_type["error_code"] == &"invalid_skill_id", "unknown skill IDs and invalid sequence element types are rejected")
	_check(not partial["ok"] and partial["error_code"] == &"invalid_skill_id" and partial_before["text"] == unchanged["text"], "an invalid later rank rejects the whole batch without persisting its valid prefix")
	_check(_revision(facade) == partial_revision and facade.current_profile().character_by_id(floor_id).purchased_skill_ranks.is_empty() and facade.current_profile().character_by_id(partial_id).purchased_skill_ranks.is_empty(), "all rejected requests leave durable ranks and profile revision unchanged")

	var stale_revision := _revision(facade) - 1
	var stale := facade.apply_skill_allocations("stale-batch", stale_revision, floor_id, [&"fire_wall", &"fire_wall", &"fire_spear"])
	var foreign := facade.apply_skill_allocations("foreign-character", _revision(facade), "missing-character", [&"fire_wall", &"fire_wall", &"fire_spear"])
	_check(not stale["ok"] and stale["error_code"] == &"stale_revision" and stale["current_revision"] == _revision(facade), "batch apply rejects a stale profile revision and returns the current revision")
	_check(not foreign["ok"] and foreign["error_code"] == &"invalid_character_id", "batch apply rejects an unknown character without changing either profile")

	var capped_id := _create_character(facade, &"mage", "Limite")
	_check(_grant_max_levels(facade, capped_id, "cap-max")["ok"], "rank-cap fixture obtains real skill points")
	var five_ranks: Array[StringName] = [&"fire_wall", &"fire_wall", &"fire_spear", &"fire_spear", &"fire_spear", &"fire_spear", &"fire_spear"]
	var cap_preview := facade.skill_allocation_preview(capped_id, _revision(facade), five_ranks)
	var sixth := facade.skill_allocation_preview(capped_id, _revision(facade), five_ranks + [&"fire_spear"])
	_check(cap_preview["ok"] and cap_preview["summary"]["effective_skill_ranks"][&"fire_spear"] == 5 and not sixth["ok"] and sixth["error_code"] == &"rank_cap_reached", "production rank cap accepts the last legal purchase and rejects the next rank")
	_cleanup_fixture(fixture)
	await process_frame

func _draft_rejects_invalid_changes() -> void:
	var fixture := _new_fixture("draft", ProfileCatalog.pilot({}, DEPENDENCY_SKILLS))
	var facade: ProfileFacade = fixture["facade"]
	var character_id: String = fixture["character_id"]
	_check(_grant_max_levels(facade, character_id, "draft-max")["ok"], "draft fixture gets progression points through the facade")
	var original_revision := _revision(facade)
	var draft := SkillAllocationDraft.new()
	draft.configure(facade, character_id, true)
	var first := _stage_spear(draft)
	var dependent := draft.add(&"feedback_followup")
	var invalid_remove := draft.remove(&"fire_spear")
	var sequence_preserved := draft.sequence == [&"fire_wall", &"fire_wall", &"fire_spear", &"feedback_followup"]
	_check(first["ok"] and dependent["ok"] and draft.preview["can_apply"], "draft accepts a prerequisite before its dependent skill")
	_check(not invalid_remove["ok"] and invalid_remove["error_code"] == &"requirements_unmet" and sequence_preserved, "removing a required skill is rejected while preserving the previously valid draft")
	var old_ranks: Dictionary = facade.progression_summary(character_id)["effective_skill_ranks"]
	draft.reset()
	_check(draft.sequence.is_empty() and draft.preview["pending_count"] == 0 and facade.progression_summary(character_id)["effective_skill_ranks"] == old_ranks and _revision(facade) == original_revision, "reset discards only pending ranks and keeps saved ranks/revision intact")

	_stage_spear(draft)
	var second_id := _create_character(facade, &"mage", "Outro")
	_check(_grant_max_levels(facade, second_id, "other-max")["ok"], "second character receives independent progression for selection tests")
	draft.configure(facade, second_id, true)
	_check(draft.sequence.is_empty() and draft.character_id == second_id and draft.revision == _revision(facade), "switching to another character invalidates the old pending sequence")
	_stage_spear(draft)
	var stale_expected := draft.revision
	_create_character(facade, &"mage", "Mudança externa")
	_check(_revision(facade) > stale_expected, "a separate profile transaction advances revision while a draft is pending")
	draft.configure(facade, second_id, true)
	_check(draft.sequence.is_empty() and draft.revision > stale_expected, "reconfiguring against a newer profile revision discards stale pending ranks")
	draft.configure(facade, second_id, false)
	var frozen := _stage_spear(draft)
	_check(not frozen["ok"] and frozen["error_code"] == &"run_active" and draft.sequence.is_empty(), "non-editable draft rejects new purchases")
	_cleanup_fixture(fixture)
	await process_frame

func _draft_failure_and_uncertainty() -> void:
	var fixture := _new_fixture("save_failure", ProfileCatalog.pilot())
	var facade: ProfileFacade = fixture["facade"]
	var store: TrackingStore = fixture["store"]
	var character_id: String = fixture["character_id"]
	_check(_grant_max_levels(facade, character_id, "failure-max")["ok"], "save failure fixture receives real progression points")
	var start_revision := _revision(facade)
	store.failure_stage = &"write_pending"
	var failed := facade.apply_skill_allocations("write-fails", start_revision, character_id, [&"fire_wall", &"fire_wall", &"fire_spear"])
	var after_failure := facade.current_profile().character_by_id(character_id)
	_check(not failed["ok"] and failed["error_code"] == &"save_failed" and after_failure.purchased_skill_ranks.is_empty() and _revision(facade) == start_revision, "definite pending-write failure publishes no rank or revision")
	store.failure_stage = &""
	var retried := facade.apply_skill_allocations("write-retry", start_revision, character_id, [&"fire_wall", &"fire_wall", &"fire_spear"])
	_check(retried["ok"] and facade.current_profile().character_by_id(character_id).purchased_skill_ranks == {&"fire_wall": 2, &"fire_spear": 1}, "a definite failed batch can retry at the unchanged revision")
	_cleanup_fixture(fixture)
	await process_frame

	var uncertain_fixture := _new_fixture("uncertain", ProfileCatalog.pilot())
	var uncertain_facade: ProfileFacade = uncertain_fixture["facade"]
	var uncertain_store: TrackingStore = uncertain_fixture["store"]
	var uncertain_id: String = uncertain_fixture["character_id"]
	_check(_grant_max_levels(uncertain_facade, uncertain_id, "uncertain-max")["ok"], "uncertain-commit fixture receives real progression points")
	var draft := SkillAllocationDraft.new()
	draft.configure(uncertain_facade, uncertain_id, true)
	_check(_stage_spear(draft)["ok"], "uncertain transaction starts from a valid pending draft")
	var pending_request := draft.sequence.duplicate()
	uncertain_store.uncertain_rename_commit = true
	var uncertain := draft.apply()
	_check(not uncertain["ok"] and uncertain["error_code"] == &"result_uncertain" and draft.is_uncertain(), "successful rename with an uncertain read remains explicitly unresolved")
	var pending_request_id := draft._request
	_check(not pending_request_id.is_empty() and draft.sequence == pending_request and not draft.add(&"fireball")["ok"] and draft.sequence == pending_request and draft._request == pending_request_id, "uncertain draft retains its request identity and freezes edits")
	var reconciled := draft.apply()
	_check(reconciled["ok"] and not draft.is_uncertain() and draft.sequence.is_empty(), "draft reconciliation confirms the matching renamed profile and clears its pending sequence")
	_check(uncertain_facade.current_profile().character_by_id(uncertain_id).purchased_skill_ranks == {&"fire_wall": 2, &"fire_spear": 1}, "reconciliation exposes exactly the committed prerequisite and Spear ranks without replay")
	_cleanup_fixture(uncertain_fixture)
	await process_frame

func _active_run_is_read_only() -> void:
	var fixture := _new_fixture("run_active", ProfileCatalog.pilot())
	var facade: ProfileFacade = fixture["facade"]
	var character_id: String = fixture["character_id"]
	_check(_grant_max_levels(facade, character_id, "run-max")["ok"], "run fixture receives real XP before starting a run")
	var started := facade.start_run("skill-run-start", _revision(facade))
	var revision := _revision(facade)
	var preview := facade.skill_allocation_preview(character_id, revision, [&"fire_wall", &"fire_wall", &"fire_spear"])
	var apply := facade.apply_skill_allocations("during-run-allocation", revision, character_id, [&"fire_wall", &"fire_wall", &"fire_spear"])
	_check(started["ok"] and preview["ok"] and preview["run_active"] and not preview["can_apply"], "an active run can inspect the canonical preview without granting edit access")
	_check(not apply["ok"] and apply["error_code"] == &"run_active" and _revision(facade) == revision and facade.current_profile().reward_session != null, "skill allocation during an active run remains read-only and preserves the reward session")
	_cleanup_fixture(fixture)
	await process_frame

func _stage_spear(draft: SkillAllocationDraft) -> Dictionary:
	for skill: StringName in [&"fire_wall", &"fire_wall", &"fire_spear"]:
		var result := draft.add(skill)
		if not result["ok"]:
			return result
	return {"ok": true}

func _new_fixture(label: String, catalog: ProfileCatalog) -> Dictionary:
	fixture_serial += 1
	var directory := fixture_root.path_join("%s_%d" % [label, fixture_serial])
	var store := TrackingStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var opened := facade.open_profile()
	assert(opened["ok"])
	var character_id := _create_character(facade, &"mage", "Mago")
	return {"directory": directory, "catalog": catalog, "store": store, "facade": facade, "character_id": character_id}

func _new_unopened_fixture(label: String, catalog: ProfileCatalog) -> Dictionary:
	fixture_serial += 1
	var directory := fixture_root.path_join("%s_%d" % [label, fixture_serial])
	var store := TrackingStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	return {"directory": directory, "catalog": catalog, "store": store, "facade": facade}

func _create_character(facade: ProfileFacade, origin: StringName, name: String) -> String:
	var result := facade.create_character("create-%d" % Time.get_ticks_usec(), _revision(facade), name, origin)
	assert(result["ok"])
	return String(result["character_id"])

func _grant_max_levels(facade: ProfileFacade, character_id: String, label: String) -> Dictionary:
	return facade.grant_playtest_progression(label, _revision(facade), character_id, &"max_levels")

func _revision(facade: ProfileFacade) -> int:
	return facade.current_profile().revision

func _cleanup_fixture(fixture: Dictionary) -> void:
	_cleanup_directory(String(fixture["directory"]))

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
