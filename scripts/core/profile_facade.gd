class_name ProfileFacade
extends RefCounted
## Transactional menu-facing profile operations. Runtime/run operations begin in E01.3-B.

const MAX_REQUEST_ID_LENGTH := 64

var _store: ProfileStore
var _catalog: ProfileCatalog
var _profile: ProfileState = null
var _operation_in_progress := false
var _read_only := false
var _read_only_error_code: StringName = &""

func _init(store: ProfileStore = null) -> void:
	_store = store if store != null else ProfileStore.new()
	_catalog = _store.catalog_copy()

func open_profile() -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress"}
	var loaded := _store.load_profile()
	if not loaded["ok"]:
		return _block_with(loaded)
	_profile = loaded["profile"].copy_state()
	_clear_read_only()
	return _public_result(loaded)

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

func _begin_operation(request_id: String, expected_revision: int) -> Dictionary:
	_operation_in_progress = true
	if not _valid_request_id(request_id):
		return {"ok": false, "error_code": &"invalid_request_id"}
	if _read_only:
		return {"ok": false, "error_code": _read_only_error_code, "read_only": true}
	if _profile == null:
		var loaded := _store.load_profile()
		if not loaded["ok"]:
			return loaded
		_profile = loaded["profile"].copy_state()
	if expected_revision != _profile.revision:
		return {"ok": false, "error_code": &"stale_revision", "current_revision": _profile.revision}
	return {"ok": true}

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
			_profile = durable.copy_state()
			return commit_result
		if loaded.get("created_empty", false) and before.revision == 0:
			return commit_result
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
