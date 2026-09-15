class_name ProfileFacade
extends RefCounted
## Transactional profile operations. Runtime combat receives only copied run state.

const MAX_REQUEST_ID_LENGTH := 64

var _store: ProfileStore
var _catalog: ProfileCatalog
var _reward_resolver: ProfileRewardResolver
var _profile: ProfileState = null
var _operation_in_progress := false
var _read_only := false
var _read_only_error_code: StringName = &""

func _init(store: ProfileStore = null, reward_resolver: ProfileRewardResolver = null) -> void:
	_store = store if store != null else ProfileStore.new()
	_catalog = _store.catalog_copy()
	_reward_resolver = reward_resolver.copy_resolver() if reward_resolver != null else ProfileRewardResolver.new()

func open_profile() -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress"}
	_operation_in_progress = true
	var result := _open_profile_transaction()
	_operation_in_progress = false
	return _public_result(result)

func current_profile() -> ProfileState:
	return _profile.copy_state() if _profile != null else null

func create_character(request_id: String, expected_revision: int, display_name: String, base_class_id: StringName) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _profile.reward_session != null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	if _profile.characters.size() >= ProfileState.MAX_CHARACTERS:
		return _finish_operation(request_id, {"ok": false, "error_code": &"character_limit"})
	if not _catalog.base_class_is_available(base_class_id):
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_origin"})

	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var character_id := IdentityIds.character_id(candidate.profile_id, candidate.next_character_counter)
	var character := CharacterState.new(character_id, display_name, base_class_id)
	var initial_slots := _catalog.initial_skill_slots(base_class_id)
	var starter_equipment := _catalog.starter_equipment(base_class_id)
	character.equipped = starter_equipment.duplicate(true)
	for preset: Dictionary in character.presets:
		preset["active_slots"] = initial_slots["active_slots"].duplicate(true)
		preset["passive_slots"] = initial_slots["passive_slots"].duplicate(true)
		preset["equipped"] = starter_equipment.duplicate(true)
	for item_id: StringName in _catalog.starter_item_ids(base_class_id):
		if item_id not in candidate.equipment_collection:
			candidate.equipment_collection.append(item_id)
			candidate.lifetime_stats[&"equipment_unlocked"] += 1
	candidate.characters.append(character)
	candidate.selected_character_id = character_id
	candidate.next_character_counter += 1

	var committed := _resolve_commit(before, candidate, _store.commit(candidate))
	if committed["ok"]:
		committed["character_id"] = character_id
	return _finish_operation(request_id, committed)

func select_character(request_id: String, expected_revision: int, character_id: String) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _profile.reward_session != null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	if _profile.character_by_id(character_id) == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_character_id"})
	if _profile.selected_character_id == character_id:
		return _finish_operation(request_id, {
			"ok": true,
			"already_applied": true,
			"new_revision": _profile.revision,
			"profile": _profile,
			"selected_character_id": character_id,
		})

	var before := _profile.copy_state()
	var candidate := before.copy_state()
	candidate.selected_character_id = character_id
	var committed := _resolve_commit(before, candidate, _store.commit(candidate))
	if committed["ok"]:
		committed["selected_character_id"] = character_id
	return _finish_operation(request_id, committed)

func select_preset(request_id: String, expected_revision: int, character_id: String, preset_index: int) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _profile.reward_session != null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	var character := _profile.character_by_id(character_id)
	if character == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_character_id"})
	if preset_index < 0 or preset_index >= CharacterState.PRESET_COUNT:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_presets"})
	if character.selected_preset == preset_index:
		return _finish_operation(request_id, {
			"ok": true,
			"already_applied": true,
			"new_revision": _profile.revision,
			"profile": _profile,
			"character_id": character_id,
			"selected_preset": preset_index,
		})
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var candidate_character := candidate.character_by_id(character_id)
	candidate_character.selected_preset = preset_index
	candidate_character.equipped = candidate_character.presets[preset_index]["equipped"].duplicate(true)
	var committed := _resolve_commit(before, candidate, _store.commit(candidate))
	if committed["ok"]:
		committed["character_id"] = character_id
		committed["selected_preset"] = preset_index
	return _finish_operation(request_id, committed)

func available_build_options(character_id: String) -> Dictionary:
	var character := _profile.character_by_id(character_id) if _profile != null else null
	if character == null:
		return {"ok": false, "error_code": &"invalid_character_id"}
	var effective_ranks := _catalog.effective_skill_ranks(character.base_class_id, character.evolution_id, character.purchased_skill_ranks)
	var active_skills: Array[StringName] = []
	var passive_skills: Array[StringName] = []
	for skill_id: StringName in effective_ranks:
		var metadata := _catalog.skill_metadata(skill_id)
		if metadata["category"] == ProfileCatalog.ACTIVE:
			active_skills.append(skill_id)
		else:
			passive_skills.append(skill_id)
	var equipment_by_slot: Dictionary[StringName, Array] = {}
	for slot: StringName in IdentityIds.equipment_slots():
		equipment_by_slot[slot] = []
	for item_id: StringName in _profile.equipment_collection:
		for slot: StringName in IdentityIds.equipment_slots():
			if _catalog.equipment_is_allowed(item_id, slot, character.base_class_id):
				equipment_by_slot[slot].append(item_id)
	return {
		"ok": true,
		"character_id": character_id,
		"active_skills": active_skills,
		"passive_skills": passive_skills,
		"equipment_by_slot": equipment_by_slot,
	}

func update_preset(
	request_id: String,
	expected_revision: int,
	character_id: String,
	preset_index: int,
	active_slots: Array[Variant],
	passive_slots: Array[Variant],
	equipped: Dictionary[StringName, Variant]
) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _profile.reward_session != null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	var character := _profile.character_by_id(character_id)
	if character == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_character_id"})
	if preset_index < 0 or preset_index >= CharacterState.PRESET_COUNT:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_presets"})
	if active_slots.size() != CharacterState.ACTIVE_SLOT_COUNT or passive_slots.size() != CharacterState.PASSIVE_SLOT_COUNT:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_presets"})
	if equipped.size() != IdentityIds.equipment_slots().size():
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_equipment"})
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var candidate_character := candidate.character_by_id(character_id)
	var candidate_preset: Dictionary = candidate_character.presets[preset_index]
	candidate_preset["active_slots"] = active_slots.duplicate(true)
	candidate_preset["passive_slots"] = passive_slots.duplicate(true)
	candidate_preset["equipped"] = equipped.duplicate(true)
	candidate_character.selected_preset = preset_index
	candidate_character.equipped = equipped.duplicate(true)
	var committed := _resolve_commit(before, candidate, _store.commit(candidate))
	if committed["ok"]:
		committed["character_id"] = character_id
		committed["selected_preset"] = preset_index
	return _finish_operation(request_id, committed)

func start_run(request_id: String, expected_revision: int) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _store.has_pending_transaction():
		return _finish_operation(request_id, _block_with({"ok": false, "error_code": &"recovery_required", "read_only": true}))
	if not _reward_resolver.is_compatible_with(_catalog):
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_catalog"})
	if _profile.reward_session != null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	var character := _profile.character_by_id(_profile.selected_character_id)
	if character == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_character_id"})
	if not _catalog.build_is_ready(character):
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_loadout"})

	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var run_id := IdentityIds.run_id(candidate.profile_id, candidate.next_run_counter)
	candidate.next_run_counter += 1
	candidate.reward_session = {
		"run_id": run_id,
		"character_id": character.character_id,
		"last_committed_seq": 0,
	}
	candidate.lifetime_stats[&"runs_started"] += 1
	var committed := _resolve_commit(before, candidate, _store.commit(candidate))
	if committed["ok"]:
		var committed_character := _profile.character_by_id(character.character_id)
		var snapshot := _build_snapshot(committed_character)
		committed["run_id"] = run_id
		committed["run_state"] = RunState.from_build(run_id, snapshot)
	return _finish_operation(request_id, committed)

func grant_reward(request_id: String, expected_revision: int, run_id: String, sequence: int, reward_id: StringName) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_context(request_id)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _store.has_pending_transaction():
		return _finish_operation(request_id, _block_with({"ok": false, "error_code": &"recovery_required", "read_only": true}))
	if _profile.reward_session == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_inactive"})
	var session: Dictionary = _profile.reward_session
	if run_id != session["run_id"] or sequence < 1:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_reward_sequence"})
	var cursor: int = session["last_committed_seq"]
	if sequence <= cursor:
		return _finish_operation(request_id, {
			"ok": true,
			"already_applied": true,
			"new_revision": _profile.revision,
			"profile": _profile,
			"run_id": run_id,
			"sequence": sequence,
		})
	var revision_result := _check_expected_revision(expected_revision)
	if not revision_result["ok"]:
		return _finish_operation(request_id, revision_result)
	if sequence != cursor + 1:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_reward_sequence"})
	var resolved := _reward_resolver.resolve(reward_id)
	if not resolved["ok"]:
		return _finish_operation(request_id, resolved)
	var reward: Dictionary = resolved["reward"]
	for item_id: StringName in reward["equipment_ids"]:
		if not _catalog.knows_equipment(item_id):
			return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_catalog"})

	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var candidate_session: Dictionary = candidate.reward_session
	var character := candidate.character_by_id(candidate_session["character_id"])
	if character == null:
		return _finish_operation(request_id, _block_with({"ok": false, "error_code": &"invalid_reward_session", "read_only": true}))
	character.base_xp_total = ProgressionRules.add_base_xp(character.base_xp_total, reward["base_xp"])
	character.job_xp_total = ProgressionRules.add_job_xp(character.job_xp_total, reward["job_xp"], not character.evolution_id.is_empty())
	for item_id: StringName in reward["equipment_ids"]:
		if item_id not in candidate.equipment_collection:
			candidate.equipment_collection.append(item_id)
			candidate.lifetime_stats[&"equipment_unlocked"] += 1
	for stat_id: StringName in reward["stat_increments"]:
		candidate.lifetime_stats[stat_id] = candidate.lifetime_stats.get(stat_id, 0) + reward["stat_increments"][stat_id]
	candidate_session["last_committed_seq"] = sequence
	candidate.reward_session = candidate_session
	var committed := _resolve_commit(before, candidate, _store.commit(candidate))
	if committed["ok"]:
		committed["run_id"] = run_id
		committed["sequence"] = sequence
		committed["reward_id"] = reward_id
		committed["applied_reward"] = reward.duplicate(true)
	return _finish_operation(request_id, committed)

func end_run(request_id: String, expected_revision: int, run_id: String, outcome: StringName) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _store.has_pending_transaction():
		return _finish_operation(request_id, _block_with({"ok": false, "error_code": &"recovery_required", "read_only": true}))
	if _profile.reward_session == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_inactive"})
	var session: Dictionary = _profile.reward_session
	if run_id != session["run_id"]:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_reward_sequence"})
	if outcome not in [&"completed", &"death", &"abandoned"]:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_run_outcome"})

	var before := _profile.copy_state()
	var candidate := before.copy_state()
	candidate.reward_session = null
	if outcome == &"completed":
		candidate.lifetime_stats[&"runs_completed"] += 1
	elif outcome == &"death":
		candidate.lifetime_stats[&"deaths"] += 1
	var committed := _resolve_commit(before, candidate, _store.commit(candidate))
	if committed["ok"]:
		committed["run_id"] = run_id
		committed["outcome"] = outcome
	return _finish_operation(request_id, committed)

func _begin_operation(request_id: String, expected_revision: int) -> Dictionary:
	var ready := _begin_context(request_id)
	if not ready["ok"]:
		return ready
	return _check_expected_revision(expected_revision)

func _begin_context(request_id: String) -> Dictionary:
	_operation_in_progress = true
	if not _valid_request_id(request_id):
		return {"ok": false, "error_code": &"invalid_request_id"}
	if _read_only:
		return {"ok": false, "error_code": _read_only_error_code, "read_only": true}
	if _profile == null:
		var opened := _open_profile_transaction()
		if not opened["ok"]:
			return opened
	return {"ok": true}

func _check_expected_revision(expected_revision: int) -> Dictionary:
	if expected_revision != _profile.revision:
		return {"ok": false, "error_code": &"stale_revision", "current_revision": _profile.revision}
	return {"ok": true}

func _open_profile_transaction() -> Dictionary:
	var loaded := _store.load_profile()
	if not loaded["ok"]:
		return _block_with(loaded)
	_profile = loaded["profile"].copy_state()
	_clear_read_only()
	if _profile.reward_session == null:
		return loaded
	if _store.has_pending_transaction():
		return _block_with({"ok": false, "error_code": &"recovery_required", "read_only": true})
	var before := _profile.copy_state()
	var abandoned_session: Dictionary = before.reward_session
	var candidate := before.copy_state()
	candidate.reward_session = null
	var closed := _resolve_commit(before, candidate, _store.commit(candidate))
	if not closed["ok"]:
		return _block_with(closed)
	closed["abandoned_run_closed"] = true
	closed["abandoned_run_id"] = abandoned_session["run_id"]
	for metadata_key: String in ["warning", "recovered", "migrated"]:
		if loaded.has(metadata_key):
			closed[metadata_key] = loaded[metadata_key]
	return closed

func _build_snapshot(character: CharacterState) -> BuildSnapshot:
	var effective_ranks := _catalog.effective_skill_ranks(character.base_class_id, character.evolution_id, character.purchased_skill_ranks)
	return BuildSnapshot.from_character(
		character,
		ProgressionRules.base_level_for_xp(character.base_xp_total),
		ProgressionRules.job_level_for_xp(character.job_xp_total, not character.evolution_id.is_empty()),
		effective_ranks
	)

func _resolve_commit(before: ProfileState, candidate: ProfileState, commit_result: Dictionary) -> Dictionary:
	if commit_result["ok"]:
		_profile = commit_result["profile"].copy_state()
		_clear_read_only()
		return commit_result
	if commit_result.get("error_code", &"") == &"stale_revision":
		var refreshed := _refresh_after_stale()
		if not refreshed["ok"]:
			return refreshed
		var stale_result := commit_result.duplicate(true)
		stale_result["current_revision"] = _profile.revision if _profile != null else -1
		return stale_result
	if commit_result.get("error_code", &"") != &"save_failed":
		if commit_result.get("read_only", false):
			return _block_with(commit_result)
		return commit_result

	var loaded := _store.load_profile()
	if loaded["ok"]:
		var durable: ProfileState = loaded["profile"]
		if _matches_committed_candidate(durable, candidate):
			_profile = durable.copy_state()
			_clear_read_only()
			return {
				"ok": true,
				"profile": durable,
				"new_revision": durable.revision,
				"recovered_after_uncertain_result": true,
			}
		if _same_profile(durable, before):
			var cleanup := _store.discard_failed_pending(before, candidate)
			if cleanup["ok"]:
				_profile = durable.copy_state()
				return commit_result
			return _block_with(cleanup)
		if loaded.get("created_empty", false) and before.revision == 0:
			return commit_result
	var cleanup := _store.discard_failed_pending(before, candidate)
	if cleanup["ok"] and cleanup.get("discarded_pending", false):
		_profile = before.copy_state()
		return commit_result
	if not cleanup["ok"]:
		return _block_with(cleanup)
	if not loaded["ok"]:
		return _block_with(loaded)
	return _block_with({"ok": false, "error_code": &"result_uncertain", "read_only": true})

func _refresh_after_stale() -> Dictionary:
	var loaded := _store.load_profile()
	if loaded["ok"]:
		_profile = loaded["profile"].copy_state()
		_clear_read_only()
		return {"ok": true}
	return _block_with(loaded)

func _block_with(result: Dictionary) -> Dictionary:
	_read_only = true
	_read_only_error_code = result.get("error_code", &"result_uncertain")
	var blocked := result.duplicate(true)
	blocked["ok"] = false
	blocked["error_code"] = _read_only_error_code
	blocked["read_only"] = true
	return blocked

func _clear_read_only() -> void:
	_read_only = false
	_read_only_error_code = &""

func _matches_committed_candidate(durable: ProfileState, candidate: ProfileState) -> bool:
	var expected := candidate.copy_state()
	expected.revision += 1
	return _same_profile(durable, expected)

func _same_profile(left: ProfileState, right: ProfileState) -> bool:
	var left_encoded := ProfileCodec.encode(left, _catalog)
	var right_encoded := ProfileCodec.encode(right, _catalog)
	return left_encoded["ok"] and right_encoded["ok"] and left_encoded["text"] == right_encoded["text"]

func _finish_operation(request_id: String, result: Dictionary) -> Dictionary:
	_operation_in_progress = false
	var public_result := _public_result(result)
	public_result["request_id"] = request_id
	return public_result

func _public_result(result: Dictionary) -> Dictionary:
	var public_result: Dictionary = {}
	for key: Variant in result:
		public_result[key] = result[key]
	if public_result.get("profile") is ProfileState:
		public_result["profile"] = public_result["profile"].copy_state()
	return public_result

func _valid_request_id(request_id: String) -> bool:
	if request_id.is_empty() or request_id.length() > MAX_REQUEST_ID_LENGTH:
		return false
	for index: int in request_id.length():
		var codepoint := request_id.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return false
	return true
