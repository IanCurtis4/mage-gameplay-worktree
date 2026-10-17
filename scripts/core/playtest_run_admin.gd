class_name PlaytestRunAdmin
extends RefCounted
## Session-bound playtest commands. UI supplies intent, never mutable run state.

const ACTOR_CAP := 20
const SPAWN_OFFSETS: Array[Vector2] = [
	Vector2(180, 0), Vector2(-180, 0), Vector2(0, 180), Vector2(0, -180),
	Vector2(220, 140), Vector2(-220, 140), Vector2(220, -140), Vector2(-220, -140),
]

var _owner: WeakRef
var _run: RunState
var _requests: Dictionary = {}

func _init(controller: RunController) -> void:
	_owner = weakref(controller)
	_run = controller.run_state

func execute(request_id: String, action: StringName, definition_id: StringName = &"", options: Dictionary = {}) -> Dictionary:
	if request_id.is_empty():
		return _failure(request_id, &"invalid_request_id")
	var intent := {"action": action, "definition_id": definition_id, "options": options.duplicate(true)}
	if _requests.has(request_id):
		var previous: Dictionary = _requests[request_id]
		if previous["intent"] != intent:
			return _failure(request_id, &"request_id_conflict")
		return previous["result"].duplicate(true)
	var result := _execute_new(request_id, action, definition_id, options)
	_requests[request_id] = {"intent": intent, "result": result.duplicate(true)}
	return result

func _execute_new(request_id: String, action: StringName, definition_id: StringName, options: Dictionary) -> Dictionary:
	var controller := _owner.get_ref() as RunController
	if controller == null or not is_instance_valid(controller) or controller.run_state != _run:
		return _failure(request_id, &"stale_run")
	if _run == null or controller.player == null or not is_instance_valid(controller.player) or not controller.player.is_alive() or controller.run_finished:
		return _failure(request_id, &"run_unavailable")
	if _run.transaction_locked or controller.inventory_frozen or (controller.build_service != null and controller.build_service.has_pending_transaction()) or (controller.reward_service != null and controller.reward_service.has_pending_transaction()):
		return _failure(request_id, &"save_in_progress")
	if _run.has_open_offer() or controller.reward != null or (controller.reward_service != null and controller.reward_service.has_uncollected()):
		return _failure(request_id, &"offer_busy")
	match action:
		&"offer":
			return _offer(controller, request_id, definition_id, options)
		&"augment":
			return _augment(controller, request_id, definition_id, options)
		&"spawn":
			return _spawn(controller, request_id, definition_id, options)
		&"clear_spawns":
			return _clear_spawns(controller, request_id, definition_id, options)
		_:
			return _failure(request_id, &"invalid_action")

func _offer(controller: RunController, request_id: String, definition_id: StringName, options: Dictionary) -> Dictionary:
	if not definition_id.is_empty() or not options.is_empty():
		return _failure(request_id, &"invalid_options")
	if controller.encounter_active and not _paused_admin_panel(controller):
		return _failure(request_id, &"encounter_active")
	if _run.pending_choices > 0 or _run.has_open_offer() or controller.reward != null or (controller.reward_service != null and controller.reward_service.has_uncollected()):
		return _failure(request_id, &"offer_busy")
	_run.queue_choice()
	if controller.encounter_active:
		controller._admin_offer_override = true
	if controller.augment_button != null:
		controller.augment_button.disabled = false
	return _success(request_id, {"open_offer": true, "choice_id": _run._choice_ids[-1], "pending_choices": _run.pending_choices})

func _augment(controller: RunController, request_id: String, definition_id: StringName, options: Dictionary) -> Dictionary:
	if not options.is_empty():
		return _failure(request_id, &"invalid_options")
	if controller.encounter_active and not _paused_admin_panel(controller):
		return _failure(request_id, &"encounter_active")
	if _run.pending_choices > 0 or _run.has_open_offer() or controller.reward != null or (controller.reward_service != null and controller.reward_service.has_uncollected()):
		return _failure(request_id, &"offer_busy")
	var before := _run.composed_build()
	var candidate := _run._augment_candidate(definition_id, before)
	if not candidate.get("ok", false):
		return _failure(request_id, StringName(candidate.get("error_code", &"invalid_augment")))
	_run.augment_stacks[definition_id] = int(_run.augment_stacks.get(definition_id, 0)) + 1
	_run.runtime_revision += 1
	controller.player.apply_run_modifiers(_run)
	if not controller.training_mode:
		controller._acquisition_augment_serial += 1
		controller.acquisition_journal.record_augment("admin_%d" % controller._acquisition_augment_serial, controller.encounter_index, _run.effect_catalog().get_definition(&"augment", definition_id) as AugmentDefinition, int(_run.augment_stacks[definition_id]))
	return _success(request_id, {"augment_id": definition_id, "stacks": int(_run.augment_stacks[definition_id]), "runtime_revision": _run.runtime_revision})

func _spawn(controller: RunController, request_id: String, definition_id: StringName, options: Dictionary) -> Dictionary:
	if not controller.gameplay_extension or controller.encounter_index < 1 or controller.encounter_index > PlaytestGameplay.STAGE_COUNT:
		return _failure(request_id, &"route_unavailable")
	if options.size() > 2 or (not options.is_empty() and not options.has("category") and not options.has("position")):
		return _failure(request_id, &"invalid_options")
	for key: Variant in options:
		if key not in ["category", "position"]:
			return _failure(request_id, &"invalid_options")
	var category: StringName = StringName(options.get("category", &"normal")) if typeof(options.get("category", &"normal")) in [TYPE_STRING, TYPE_STRING_NAME] else &""
	if category.is_empty():
		return _failure(request_id, &"invalid_category")
	var catalog := _run.effect_catalog().mob_catalog()
	var occurrence := MobOccurrence.new()
	occurrence.mob_base_id = definition_id
	occurrence.category_id = category
	occurrence.origin_id = PlaytestGameplay.origin(controller.encounter_index)
	var checked := catalog.level_for_occurrence(occurrence)
	if not checked.get("ok", false):
		return _failure(request_id, StringName(checked.get("error_code", &"invalid_mob")))
	var living := 0
	for actor: CombatActor in controller.enemies:
		if is_instance_valid(actor) and actor.is_alive():
			living += 1
	if living >= ACTOR_CAP:
		return _failure(request_id, &"actor_cap")
	var position := Vector2.INF
	if options.has("position"):
		if typeof(options["position"]) != TYPE_VECTOR2:
			return _failure(request_id, &"invalid_position")
		position = options["position"]
		if not _valid_position(controller, position):
			return _failure(request_id, &"invalid_position")
	else:
		for offset: Vector2 in SPAWN_OFFSETS:
			var candidate := controller.player.global_position + offset
			if _valid_position(controller, candidate):
				position = candidate
				break
		if position == Vector2.INF:
			return _failure(request_id, &"no_spawn_space")
	var enemy := controller._spawn_route_enemy({"species": definition_id, "category": category, "position": position}, controller.encounter_index, false, 0, true)
	return _success(request_id, {"actor_id": enemy.get_instance_id(), "species": definition_id, "category": category, "level": int(checked["level"])})

func _valid_position(controller: RunController, point: Vector2) -> bool:
	if not point.is_finite() or not controller.navigation.is_walkable(point) or point.distance_to(controller.player.global_position) < 75.0:
		return false
	var path := controller.navigation.get_path(controller.player.global_position, point)
	if path.is_empty() or path[-1].distance_squared_to(point) > 1.0:
		return false
	for actor: CombatActor in controller.enemies:
		if is_instance_valid(actor) and actor.is_alive() and actor.global_position.distance_to(point) < 75.0:
			return false
	return true

func _paused_admin_panel(controller: RunController) -> bool:
	return controller.admin_panel != null and controller.admin_panel.visible and controller.get_tree().paused

func _clear_spawns(controller: RunController, request_id: String, definition_id: StringName, options: Dictionary) -> Dictionary:
	if not definition_id.is_empty() or not options.is_empty():
		return _failure(request_id, &"invalid_options")
	var cleared := 0
	for actor: CombatActor in controller.enemies.duplicate():
		if actor is EnemyActor and is_instance_valid(actor) and actor.get_meta("admin_spawn", false):
			controller._discard_companion(actor)
			cleared += 1
	return _success(request_id, {"cleared": cleared})

func _success(request_id: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"ok": true, "error_code": &"", "request_id": request_id}
	result.merge(extra)
	return result

func _failure(request_id: String, code: StringName) -> Dictionary:
	return {"ok": false, "error_code": code, "request_id": request_id}
