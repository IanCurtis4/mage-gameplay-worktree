class_name PlaytestProfileAdmin
extends RefCounted
## Narrow playtest authority. The UI supplies intent, never persistent state.

static func grant(facade: ProfileFacade, request_id: String, expected_revision: int, character_id: String, action: StringName, definition_id: StringName = &"", options: Dictionary = {}, controller: RunController = null) -> Dictionary:
	if facade == null:
		return _failure(&"profile_unavailable", request_id)
	var reconciling := not facade._admin_pending.is_empty()
	if reconciling and (facade._admin_pending["request_id"] != request_id or facade._admin_pending["character_id"] != character_id or facade._admin_pending["action"] != action or facade._admin_pending["definition_id"] != definition_id):
		return _failure(&"result_uncertain", request_id)
	if controller != null:
		if controller.persistent_facade != facade or controller.run_state == null or controller.player == null or controller.player.run_state != controller.run_state or controller.run_finished:
			return _failure(&"invalid_session", request_id)
		if controller.run_state.character_id != character_id or controller.run_state.run_id.is_empty():
			return _failure(&"invalid_session", request_id)
		if not controller.player.is_alive():
			return _failure(&"actor_dead", request_id)
		if not controller.get_tree().paused or controller.get("admin_panel") == null or not controller.get("admin_panel").visible:
			return _failure(&"admin_closed", request_id)
		if (controller.inventory_frozen and not reconciling) or controller.build_service == null or controller.build_service.has_pending_transaction():
			return _failure(&"save_in_progress", request_id)
		if controller.reward_service != null and controller.reward_service.has_pending_transaction():
			return _failure(&"save_in_progress", request_id)
		if controller.run_state.has_open_offer():
			return _failure(&"offer_open", request_id)
		if not reconciling:
			var boundary := facade.run_mutation_status(controller.run_state.run_id, character_id)
			if not boundary["ok"]:
				return _failure(boundary["error_code"], request_id)
	elif facade.current_profile() != null and facade.current_profile().reward_session != null:
		return _failure(&"invalid_session", request_id)
	var normalized: Dictionary = {}
	for key: Variant in options:
		if typeof(key) != TYPE_STRING:
			return _failure(&"invalid_options", request_id)
		if key == "quality_id" and typeof(options[key]) in [TYPE_STRING, TYPE_STRING_NAME]:
			normalized[key] = String(options[key])
		else:
			normalized[key] = options[key]
	var result := facade.grant_playtest_admin(request_id, expected_revision, character_id, action, definition_id, normalized)
	if controller != null and not result["ok"] and result.get("read_only", false):
		controller.set_inventory_freeze(true)
	return result

static func _failure(error_code: StringName, request_id: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "request_id": request_id}
