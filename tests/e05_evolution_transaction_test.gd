extends SceneTree

class ToggleFailStore:
	extends ProfileStore
	var failure_stage: StringName = &""

	func _should_fail(stage: StringName) -> bool:
		return not failure_stage.is_empty() and stage == failure_stage

class UncertainStore:
	extends ProfileStore
	var hide_next_success := false

	func commit(source: ProfileState) -> Dictionary:
		var result := super.commit(source)
		if hide_next_success and result["ok"]:
			hide_next_success = false
			return {"ok": false, "error_code": &"save_failed"}
		return result

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174050"

var failures := 0
var checks := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e05_evolution_transaction")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	_check_first_choice_and_reload()
	_check_switch_refund_and_presets()
	_check_rejections_are_atomic()
	_check_save_failure_retry_and_uncertainty()
	_check_unavailable_identity_blocks_run()
	_cleanup_directory(root_directory)
	print("E05-S1B transação de evolução: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_first_choice_and_reload() -> void:
	var directory := root_directory.path_join("first_choice")
	_prepare_directory(directory)
	var catalog := _catalog()
	var seeded := _seed_character(directory, catalog, &"", ProgressionRules.EVOLUTION_MIN_BASE_XP, ProgressionRules.EVOLUTION_MIN_JOB_XP, false)
	var character_id: String = seeded["character_id"]
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := facade.open_profile()
	var before: CharacterState = opened["profile"].character_by_id(character_id)
	var evolved := facade.change_evolution("first-choice", opened["profile"].revision, character_id, &"defender")
	var character: CharacterState = evolved["profile"].character_by_id(character_id)
	_check(evolved["ok"] and evolved["new_revision"] == opened["profile"].revision + 1 and evolved["evolution_id"] == &"defender", "exact base-10/job-20 threshold commits the selected destination once")
	_check(character.base_class_id == &"swordsman" and character.base_xp_total == before.base_xp_total and character.job_xp_total == before.job_xp_total and character.attribute_allocations == before.attribute_allocations, "first choice preserves origin, XP and attribute investments")
	_check(character.purchased_skill_ranks == before.purchased_skill_ranks and character.granted_skill_ranks == before.granted_skill_ranks and character.equipped == before.equipped, "first choice preserves base purchases, legacy grants and equipment")
	_check(evolved["evolution_refund"] == 0 and evolved["cleared_slots_by_preset"] == _empty_clear_report(), "first choice reports no refund and no cleared legal base slots")
	_check(evolved["progression"]["effective_skill_ranks"].get(&"defender_entry", 0) == 1 and not character.granted_skill_ranks.has(&"defender_entry"), "entry rank is derived exactly once without persisting a grant or spending the wallet")

	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var reload_open := reloaded.open_profile()
	var reloaded_character: CharacterState = reload_open["profile"].character_by_id(character_id)
	_check(reload_open["ok"] and reloaded_character.evolution_id == &"defender" and reloaded.progression_summary(character_id)["effective_skill_ranks"][&"defender_entry"] == 1, "destination and its single free entry rank survive a full store/facade reload")
	var repeated := reloaded.change_evolution("same-choice", reload_open["profile"].revision, character_id, &"defender")
	_check(repeated["ok"] and repeated["already_applied"] and repeated["new_revision"] == reload_open["profile"].revision and repeated["evolution_refund"] == 0, "already-current request is an idempotent no-op without a revision")
	var started := reloaded.start_run("ready-run", reload_open["profile"].revision)
	_check(started["ok"] and started["run_state"].build_snapshot.evolution_id == &"defender" and started["run_state"].build_snapshot.skill_ranks[&"defender_entry"] == 1, "a fixture whose content is explicitly ready may start a run with the committed identity and rank")

func _check_switch_refund_and_presets() -> void:
	var directory := root_directory.path_join("switch")
	_prepare_directory(directory)
	var catalog := _catalog()
	var seeded := _seed_character(directory, catalog, &"defender", ProgressionRules.MAX_BASE_XP, ProgressionRules.MAX_JOB_XP, true)
	var character_id: String = seeded["character_id"]
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := facade.open_profile()
	var before: CharacterState = opened["profile"].character_by_id(character_id)
	var before_disk := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	var locked := facade.change_evolution("normal-switch-blocked", opened["profile"].revision, character_id, &"berserker")
	_check(not locked["ok"] and locked["error_code"] == &"evolution_locked" and facade.current_profile().revision == opened["profile"].revision and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == before_disk, "ordinary evolution transaction rejects a second identity without writing or changing revision")
	var switched := facade.change_playtest_evolution("switch-branch", opened["profile"].revision, character_id, &"berserker")
	var after: CharacterState = switched["profile"].character_by_id(character_id)
	_check(switched["ok"] and switched["evolution_refund"] == 4 and after.evolution_id == &"berserker", "branch switch refunds the exact four purchased evolution ranks and commits the new identity")
	_check(after.purchased_skill_ranks == {&"slash": 2} and after.granted_skill_ranks == {&"slash": 1, &"dash": 1, &"swordsman_resistance": 1}, "switch removes only evolution-wallet ranks while preserving base purchases and legacy base grants")
	_check(after.base_xp_total == before.base_xp_total and after.job_xp_total == before.job_xp_total and after.attribute_allocations == before.attribute_allocations and after.equipped == before.equipped, "switch preserves XP, investments and selected equipment")
	_check(after.presets[0]["active_slots"] == [&"slash", null, null, null, null] and after.presets[0]["passive_slots"] == [null, &"swordsman_resistance"], "first preset clears only skills made illegal by the old branch")
	_check(after.presets[1]["active_slots"] == [null, &"dash", null, null, null] and after.presets[1]["passive_slots"] == [null, null], "second preset keeps slot order, empty slots and legal base skills")
	_check(after.presets[0]["equipped"] == before.presets[0]["equipped"] and after.presets[1]["equipped"] == before.presets[1]["equipped"], "normalization never erases either preset or its equipment")
	_check(switched["cleared_slots_by_preset"] == [
		{"preset_index": 0, "active_slot_indices": [1, 2], "passive_slot_indices": [0]},
		{"preset_index": 1, "active_slot_indices": [0], "passive_slot_indices": [0]},
	], "success reports the exact active and passive indices cleared in both presets")
	_check(switched["progression"]["effective_skill_ranks"].get(&"berserker_entry", 0) == 1 and not switched["progression"]["effective_skill_ranks"].has(&"defender_entry"), "new free entry replaces the old derived branch without accumulating ranks")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var reload_open := reloaded.open_profile()
	var durable: CharacterState = reload_open["profile"].character_by_id(character_id)
	_check(reload_open["ok"] and durable.evolution_id == &"berserker" and durable.presets == after.presets and durable.purchased_skill_ranks == after.purchased_skill_ranks, "identity, refund result and normalized presets remain durable after reload")

func _check_rejections_are_atomic() -> void:
	var catalog := _catalog()
	var directory := root_directory.path_join("rejections")
	_prepare_directory(directory)
	var seeded := _seed_character(directory, catalog, &"", ProgressionRules.EVOLUTION_MIN_BASE_XP - 1, ProgressionRules.EVOLUTION_MIN_JOB_XP, false)
	var character_id: String = seeded["character_id"]
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := facade.open_profile()
	var initial_revision: int = opened["profile"].revision
	var initial_character: CharacterState = opened["profile"].character_by_id(character_id)
	var below := facade.change_evolution("below-threshold", initial_revision, character_id, &"defender")
	var wrong_origin := facade.change_evolution("wrong-origin", initial_revision, character_id, &"elementalist")
	var unknown := facade.change_evolution("unknown", initial_revision, character_id, &"missing_evolution")
	var incomplete := facade.change_evolution("incomplete", initial_revision, character_id, &"sp_mg")
	var stale := facade.change_evolution("stale", initial_revision - 1, character_id, &"defender")
	_check(not below["ok"] and below["error_code"] == &"requirements_unmet", "below 10/20 is rejected before any candidate state is published")
	_check(not wrong_origin["ok"] and wrong_origin["error_code"] == &"invalid_origin" and not unknown["ok"] and unknown["error_code"] == &"invalid_origin", "destination from another origin and unknown ID keep invalid-origin semantics")
	_check(not incomplete["ok"] and incomplete["error_code"] == &"content_unavailable", "known destination without a complete kit is rejected as unavailable content")
	_check(not stale["ok"] and stale["error_code"] == &"stale_revision", "stale revision is rejected before evaluating or mutating the destination")
	var current: CharacterState = facade.current_profile().character_by_id(character_id)
	_check(facade.current_profile().revision == initial_revision and current.evolution_id.is_empty() and current.purchased_skill_ranks == initial_character.purchased_skill_ranks and current.presets == initial_character.presets, "all rejected requests leave revision, identity, ranks and presets unchanged")
	var job_directory := root_directory.path_join("below_job_threshold")
	_prepare_directory(job_directory)
	var job_seed := _seed_character(job_directory, catalog, &"", ProgressionRules.EVOLUTION_MIN_BASE_XP, ProgressionRules.EVOLUTION_MIN_JOB_XP - 1, false)
	var job_facade := ProfileFacade.new(ProfileStore.new(job_directory, catalog))
	var job_open := job_facade.open_profile()
	var below_job := job_facade.change_evolution("below-job", job_open["profile"].revision, job_seed["character_id"], &"defender")
	_check(not below_job["ok"] and below_job["error_code"] == &"requirements_unmet" and job_facade.current_profile().revision == job_open["profile"].revision, "base 10 with job below 20 is independently rejected without a write")

	var run_directory := root_directory.path_join("run_boundary")
	_prepare_directory(run_directory)
	var run_seed := _seed_character(run_directory, catalog, &"", ProgressionRules.EVOLUTION_MIN_BASE_XP, ProgressionRules.EVOLUTION_MIN_JOB_XP, false)
	var run_facade := ProfileFacade.new(ProfileStore.new(run_directory, catalog))
	var run_open := run_facade.open_profile()
	var started := run_facade.start_run("base-run", run_open["profile"].revision)
	var during := run_facade.change_evolution("during-run", started["new_revision"], run_seed["character_id"], &"defender")
	var admin_during := run_facade.change_playtest_evolution("admin-during-run", started["new_revision"], run_seed["character_id"], &"defender")
	_check(started["ok"] and not during["ok"] and during["error_code"] == &"run_active" and not admin_during["ok"] and admin_during["error_code"] == &"run_active" and run_facade.current_profile().character_by_id(run_seed["character_id"]).evolution_id.is_empty(), "active run blocks ordinary and admin evolution without changing the snapshot/profile identity")

func _check_save_failure_retry_and_uncertainty() -> void:
	var catalog := _catalog()
	for stage: StringName in [&"write_pending", &"validate_pending", &"backup", &"replace"]:
		var directory := root_directory.path_join("definite_" + String(stage))
		_prepare_directory(directory)
		var seeded := _seed_character(directory, catalog, &"", ProgressionRules.EVOLUTION_MIN_BASE_XP, ProgressionRules.EVOLUTION_MIN_JOB_XP, false)
		var store := ToggleFailStore.new(directory, catalog)
		var facade := ProfileFacade.new(store)
		var opened := facade.open_profile()
		store.failure_stage = stage
		var failed := facade.change_evolution("failed-" + String(stage), opened["profile"].revision, seeded["character_id"], &"defender")
		var durable := ProfileStore.new(directory, catalog).load_profile()
		_check(not failed["ok"] and failed["error_code"] == &"save_failed" and facade.current_profile().character_by_id(seeded["character_id"]).evolution_id.is_empty(), "%s store failure publishes no partial identity, ranks or presets" % stage)
		_check(durable["ok"] and durable["profile"].revision == opened["profile"].revision and durable["profile"].character_by_id(seeded["character_id"]).evolution_id.is_empty(), "%s store failure leaves the previous durable state intact and cleans its pending candidate" % stage)
		if stage == &"write_pending":
			store.failure_stage = &""
			var retried := facade.change_evolution("retry-choice", opened["profile"].revision, seeded["character_id"], &"defender")
			var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog)).open_profile()
			_check(retried["ok"] and reloaded["profile"].character_by_id(seeded["character_id"]).evolution_id == &"defender", "same expected revision can retry a definite failure and persists exactly once")

	var uncertain_directory := root_directory.path_join("uncertain")
	_prepare_directory(uncertain_directory)
	var uncertain_seed := _seed_character(uncertain_directory, catalog, &"", ProgressionRules.EVOLUTION_MIN_BASE_XP, ProgressionRules.EVOLUTION_MIN_JOB_XP, false)
	var uncertain_store := UncertainStore.new(uncertain_directory, catalog)
	var uncertain := ProfileFacade.new(uncertain_store)
	var uncertain_open := uncertain.open_profile()
	uncertain_store.hide_next_success = true
	var recovered := uncertain.change_evolution("uncertain-choice", uncertain_open["profile"].revision, uncertain_seed["character_id"], &"defender")
	var replay := uncertain.change_evolution("uncertain-choice", uncertain_open["profile"].revision, uncertain_seed["character_id"], &"defender")
	_check(recovered["ok"] and recovered["recovered_after_uncertain_result"] and recovered["evolution_refund"] == 0, "uncertain result is resolved by durable reread with the original mutation report")
	_check(not replay["ok"] and replay["error_code"] == &"stale_revision" and uncertain.current_profile().character_by_id(uncertain_seed["character_id"]).evolution_id == &"defender", "literal retry after uncertain success cannot apply the choice or refund twice")

func _check_unavailable_identity_blocks_run() -> void:
	var directory := root_directory.path_join("unavailable_run")
	_prepare_directory(directory)
	var catalog := ProfileCatalog.pilot()
	var seeded := _seed_character(directory, catalog, &"defender", ProgressionRules.EVOLUTION_MIN_BASE_XP, ProgressionRules.EVOLUTION_MIN_JOB_XP, false)
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := facade.open_profile()
	var revision: int = opened["profile"].revision
	var repeated := facade.change_evolution("current-unavailable", revision, seeded["character_id"], &"defender")
	var blocked := facade.start_run("blocked-run", revision)
	_check(repeated["ok"] and repeated["already_applied"] and repeated["new_revision"] == revision, "retrying an already-persisted identity remains a non-writing idempotent acknowledgement")
	_check(blocked["ok"] and blocked["run_state"].build_snapshot.evolution_id == &"defender", "completed production Defender starts a persistent run")
	_check(catalog.build_is_ready(opened["profile"].character_by_id(seeded["character_id"])), "full build readiness includes the completed evolution content declaration")
	var reload_open := ProfileFacade.new(ProfileStore.new(directory, catalog)).open_profile()
	_check(reload_open["ok"] and reload_open["profile"].character_by_id(seeded["character_id"]).evolution_id == &"defender", "run start preserves persisted identity and the profile remains loadable")

func _catalog() -> ProfileCatalog:
	return ProfileCatalog.pilot({
		&"practice_sword": {"slot": &"weapon", "allowed_base_classes": [&"swordsman"]},
		&"practice_armor": {"slot": &"armor", "allowed_base_classes": [&"swordsman"]},
	}, {
		&"defender_entry": _skill(ProfileCatalog.ACTIVE, 1, 4, &"defender", {1: {"job_level": 20, "skill_ranks": {}}}),
		&"defender_guard": _skill(ProfileCatalog.ACTIVE, 0, 5, &"defender"),
		&"defender_anchor": _skill(ProfileCatalog.PASSIVE, 0, 3, &"defender"),
		&"berserker_entry": _skill(ProfileCatalog.ACTIVE, 1, 4, &"berserker", {1: {"job_level": 20, "skill_ranks": {}}}),
		&"berserker_rage": _skill(ProfileCatalog.ACTIVE, 0, 5, &"berserker"),
	}, {
		&"defender": {
			"entry_skill_id": &"defender_entry",
			"exclusive_skill_ids": [&"defender_entry", &"defender_guard", &"defender_anchor"],
			"content_ready": true,
		},
		&"berserker": {
			"entry_skill_id": &"berserker_entry",
			"exclusive_skill_ids": [&"berserker_entry", &"berserker_rage"],
			"content_ready": true,
		},
	})

func _skill(category: StringName, free_rank: int, max_purchased_rank: int, evolution_id: StringName, requirements: Dictionary = {}) -> Dictionary:
	return {
		"allowed_base_classes": [&"swordsman"],
		"category": category,
		"wallet": ProfileCatalog.EVOLUTION_WALLET,
		"free_rank": free_rank,
		"max_purchased_rank": max_purchased_rank,
		"required_evolution_id": evolution_id,
		"rank_requirements": requirements,
	}

func _seed_character(directory: String, catalog: ProfileCatalog, evolution_id: StringName, base_xp: int, job_xp: int, branch_build: bool) -> Dictionary:
	var profile := ProfileState.new(PROFILE_ID)
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Teste E05-S1B", &"swordsman")
	character.evolution_id = evolution_id
	character.base_xp_total = base_xp
	character.job_xp_total = job_xp
	character.attribute_allocations[&"str"] = 1
	character.purchased_skill_ranks[&"slash"] = 2
	character.granted_skill_ranks = {&"slash": 1, &"dash": 1, &"swordsman_resistance": 1}
	character.equipped[&"weapon"] = &"practice_sword" if catalog.knows_equipment(&"practice_sword") else null
	for preset: Dictionary in character.presets:
		preset["equipped"] = character.equipped.duplicate(true)
	character.presets[0]["active_slots"][0] = &"slash"
	character.presets[0]["passive_slots"][1] = &"swordsman_resistance"
	character.presets[1]["active_slots"][1] = &"dash"
	if branch_build:
		character.purchased_skill_ranks[&"defender_entry"] = 1
		character.purchased_skill_ranks[&"defender_guard"] = 2
		character.purchased_skill_ranks[&"defender_anchor"] = 1
		character.presets[0]["active_slots"][1] = &"defender_entry"
		character.presets[0]["active_slots"][2] = &"defender_guard"
		character.presets[0]["passive_slots"][0] = &"defender_anchor"
		character.presets[1]["active_slots"][0] = &"defender_guard"
		character.presets[1]["passive_slots"][0] = &"defender_anchor"
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	if catalog.knows_equipment(&"practice_sword"):
		profile.equipment_collection.append(&"practice_sword")
	var committed := ProfileStore.new(directory, catalog).commit(profile)
	_check(committed["ok"], "isolated evolution transaction fixture is durably seeded: %s" % [committed])
	return {"character_id": character_id, "profile": committed.get("profile")}

func _empty_clear_report() -> Array[Dictionary]:
	return [
		{"preset_index": 0, "active_slot_indices": [], "passive_slot_indices": []},
		{"preset_index": 1, "active_slot_indices": [], "passive_slot_indices": []},
	]

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
