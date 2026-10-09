class_name RunBuildService
extends RefCounted
## The controller supplies authority; UI intentions never supply encounter/resource state.

var _owner: WeakRef
var _run: RunState
var _actor: WeakRef
var _busy := false
var _committing_intent: Dictionary = {}
var _applied: Dictionary = {}
var _pending: Dictionary = {}

func _init(controller: RunController) -> void:
	_owner = weakref(controller)
	_run = controller.run_state
	_actor = weakref(controller.player)

func context() -> Dictionary:
	var controller := _owner.get_ref() as RunController
	var profile := controller.persistent_facade.current_profile() if controller != null and controller.persistent_facade != null else null
	return {"runtime_revision": _run.runtime_revision, "build_version": _run.build_snapshot.build_version if _run.build_snapshot != null else -1, "profile_revision": profile.revision if profile != null else -1}

func preview_change(intent: Dictionary) -> Dictionary:
	if _busy or not _pending.is_empty():
		return _failure(&"save_in_progress", intent)
	var prepared := _prepare(intent)
	if not prepared["ok"]:
		return prepared
	return _public_preview(prepared)

func commit_change(intent: Dictionary) -> Dictionary:
	if _busy:
		return _failure(&"save_in_progress", intent)
	if not _pending.is_empty():
		if intent != _pending["intent"]:
			return _failure(&"result_uncertain", intent)
		return reconcile_change(String(intent.get("request_id", "")))
	if not intent.has("resource_state") or not intent.has("inventory_revision"):
		return _failure(&"preview_required", intent)
	var prepared := _prepare(intent)
	if not prepared["ok"]:
		return prepared
	var controller := _owner.get_ref() as RunController
	_busy = true
	_committing_intent = intent.duplicate(true)
	var result := {"ok": true, "error_code": &"", "request_id": intent["request_id"]}
	if prepared["equipment_changed"] and controller.persistent_facade != null:
		result = controller.persistent_facade.equip_between_encounters(String(intent["request_id"]), int(intent["profile_revision"]), controller, intent)
	if result["ok"]:
		_publish(prepared)
		result.merge(context(), true)
	elif result.get("read_only", false):
		_pending = prepared
		controller.set_inventory_freeze(true)
	_busy = false
	_committing_intent = {}
	return result

func reconcile_change(request_id: String) -> Dictionary:
	if _busy or _pending.is_empty() or request_id != _pending["intent"]["request_id"]:
		return BuildEffectCatalog.failure(&"invalid_transaction")
	var controller := _owner.get_ref() as RunController
	if controller == null or controller.persistent_facade == null:
		return BuildEffectCatalog.failure(&"invalid_session")
	_busy = true
	_committing_intent = _pending["intent"].duplicate(true)
	var result := controller.persistent_facade.reconcile_transaction(request_id)
	if result["ok"]:
		_publish(_pending)
		_pending = {}
		controller.set_inventory_freeze(false)
		result.merge(context(), true)
	elif not result.get("read_only", false):
		_pending = {}
		controller.set_inventory_freeze(false)
	_busy = false
	_committing_intent = {}
	return result

func has_pending_transaction() -> bool:
	return _busy or not _pending.is_empty()

func _prepare(intent: Dictionary) -> Dictionary:
	if typeof(intent.get("request_id")) != TYPE_STRING:
		return BuildEffectCatalog.failure(&"invalid_request_id")
	for field: String in ["kind", "slot", "item_id", "card_id", "from_item_id"]:
		if intent.has(field) and typeof(intent[field]) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return _failure(&"invalid_intent", intent)
	if _run.build_snapshot == null:
		return _failure(&"missing_snapshot", intent)
	var request_id := String(intent.get("request_id", ""))
	if request_id.is_empty() or request_id.length() > ProfileFacade.MAX_REQUEST_ID_LENGTH:
		return _failure(&"invalid_request_id", intent)
	if _applied.has(request_id):
		return _failure(&"replayed_request", intent)
	var controller := _owner.get_ref() as RunController
	var actor := _actor.get_ref() as PlayerActor
	if controller == null or actor == null or controller.run_state != _run or controller.player != actor or actor.run_state != _run or controller.run_finished:
		return _failure(&"invalid_session", intent)
	if not actor.is_alive():
		return _failure(&"actor_dead", intent)
	if controller.encounter_active:
		return _failure(&"encounter_active", intent)
	if controller.inventory_frozen:
		return _failure(&"result_uncertain", intent)
	if _run.has_open_offer():
		return _failure(&"offer_open", intent)
	if controller.reward_service != null and controller.reward_service.has_pending_transaction():
		return _failure(&"save_in_progress", intent)
	var current := context()
	for key: String in ["runtime_revision", "build_version", "profile_revision"]:
		if typeof(intent.get(key)) != TYPE_INT or intent[key] != current[key]:
			return _failure(&"stale_revision", intent)
	var resources := actor.resource_state()
	if intent.has("resource_state") and intent["resource_state"] != resources:
		return _failure(&"stale_resources", intent)
	if intent.has("inventory_revision") and intent["inventory_revision"] != _run.card_inventory.revision:
		return _failure(&"stale_revision", intent)
	var owned := _run.local_equipment.duplicate()
	if controller.persistent_facade != null:
		var boundary := controller.persistent_facade.run_mutation_status(_run.run_id, _run.character_id)
		if not boundary["ok"]:
			return _failure(boundary["error_code"], intent)
		owned = controller.persistent_facade.current_profile().equipment_collection
	elif not _run.run_id.is_empty():
		return _failure(&"invalid_session", intent)
	var candidate := _run.build_snapshot.copy_snapshot()
	candidate.skill_ranks = _run.skill_levels.duplicate(true)
	for slot: StringName in IdentityIds.equipment_slots():
		if not candidate.equipped.has(slot):
			candidate.equipped[slot] = null
	var kind := StringName(intent.get("kind", &""))
	if kind in [&"equip", &"unequip"]:
		var slot := StringName(intent.get("slot", &""))
		if slot not in IdentityIds.equipment_slots():
			return _failure(&"invalid_slot", intent)
		var item := StringName(intent.get("item_id", &""))
		if kind == &"equip" and item not in owned:
			return _failure(&"item_not_owned", intent)
		candidate.equipped[slot] = item if kind == &"equip" else null
	elif kind not in [&"socket", &"unsocket", &"transfer"]:
		return _failure(&"invalid_intent", intent)
	for item: Variant in candidate.equipped.values():
		if item != null and item not in owned:
			return _failure(&"item_not_owned", intent)
	var inventory_result := _run.card_inventory.preview(intent, candidate.equipped)
	if not inventory_result["ok"]:
		return _failure(inventory_result["error_code"], intent)
	var inventory: RunCardInventory = inventory_result["inventory"]
	var effects := _run.effect_state()
	effects["card_sockets"] = inventory.sockets()
	candidate.build_version += 1
	var composition := BuildEffectComposer.compose(candidate, effects, actor.temporary_stat_sources(), _run.effect_catalog())
	if not composition["ok"]:
		composition["request_id"] = request_id
		return composition
	var stats: StatBreakdown = composition["breakdown"]
	if stats.value(&"max_hp") <= actor.health.hp_deficit():
		return _failure(&"hp_deficit", intent)
	if stats.value(&"max_sp") < actor.sp_deficit():
		return _failure(&"sp_deficit", intent)
	var equipment_changed := candidate.equipped != _run.build_snapshot.equipped
	if not equipment_changed and inventory.sockets() == _run.card_inventory.sockets():
		return _failure(&"no_change", intent)
	var captured := intent.duplicate(true)
	captured["resource_state"] = resources
	captured["inventory_revision"] = _run.card_inventory.revision
	return {"ok": true, "error_code": &"", "request_id": request_id, "intent": captured, "snapshot": candidate, "inventory": inventory, "composition": composition, "equipment_changed": equipment_changed}

func _publish(prepared: Dictionary) -> void:
	var actor := _actor.get_ref() as PlayerActor
	_run.build_snapshot = prepared["snapshot"].copy_snapshot()
	_run.card_inventory = prepared["inventory"].copy_inventory()
	_run.card_sockets = _run.card_inventory.sockets()
	_run.runtime_revision += 1
	_applied[prepared["intent"]["request_id"]] = true
	actor.apply_run_modifiers(_run)

func _public_preview(prepared: Dictionary) -> Dictionary:
	var actor := _actor.get_ref() as PlayerActor
	var stats: StatBreakdown = prepared["composition"]["breakdown"]
	return {"ok": true, "error_code": &"", "request_id": prepared["request_id"], "intent": prepared["intent"].duplicate(true), "equipped": prepared["snapshot"].equipped.duplicate(true), "inventory": prepared["inventory"].describe(), "before": actor.stat_breakdown.values(), "after": stats.values(), "hp_after": stats.value(&"max_hp") - actor.health.hp_deficit(), "sp_after": stats.value(&"max_sp") - actor.sp_deficit(), "sources": prepared["composition"]["provenance"].duplicate(true), "inactive": prepared["composition"]["inactive"].duplicate(true), "skill_rules": prepared["composition"]["skill_rules"].duplicate(true)}

func _failure(code: StringName, intent: Dictionary) -> Dictionary:
	var result := BuildEffectCatalog.failure(code)
	result["request_id"] = str(intent.get("request_id", ""))
	return result
