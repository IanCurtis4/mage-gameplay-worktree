class_name RunRewardService
extends RefCounted
## Tickets are minted by world events. collect accepts only an issued ticket ID.

var _owner: WeakRef
var _run: RunState
var _tickets: Dictionary = {}
var _events: Dictionary = {}
var _queue: Array[String] = []
var _next_sequence := 1
var _busy := false
var _uncertain_ticket := ""

func _init(controller: RunController) -> void:
	_owner = weakref(controller)
	_run = controller.run_state
	if controller.persistent_facade != null:
		var profile := controller.persistent_facade.current_profile()
		if profile != null and profile.reward_session != null:
			_next_sequence = int(profile.reward_session["last_committed_seq"]) + 1

func issue(event_id: String, reward_id: StringName, stage_reward: bool = false) -> Dictionary:
	var controller := _owner.get_ref() as RunController
	if controller == null or controller.run_state != _run or controller.encounter_active or controller.run_finished or not controller.player.is_alive() or event_id.is_empty():
		return BuildEffectCatalog.failure(&"invalid_reward_event")
	if _events.has(event_id):
		return ticket(_events[event_id])
	if has_pending_transaction() or controller.inventory_frozen:
		return BuildEffectCatalog.failure(&"save_in_progress")
	var resolved := controller.persistent_facade.reward_definition(reward_id) if controller.persistent_facade != null else ProfileRewardResolver.pilot_progression().resolve(reward_id)
	if not resolved["ok"]:
		return resolved
	var payload: Dictionary = resolved["reward"].duplicate(true)
	var catalog := _run.effect_catalog()
	var item_pool: Array[StringName] = []
	var card_pool: Array[StringName] = []
	if stage_reward:
		for id: StringName in catalog.ids(&"equipment"):
			var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
			if not item.starter and BuildEffectCatalog.definition_allowed(item, _run.build_snapshot):
				item_pool.append(id)
		card_pool = eligible_cards()
	var item_id: StringName = &""
	var card_id: StringName = &""
	if not item_pool.is_empty():
		item_id = item_pool[controller.rng.randi_range(0, item_pool.size() - 1)]
		if item_id not in payload["equipment_ids"]:
			payload["equipment_ids"].append(item_id)
	if not card_pool.is_empty():
		card_id = card_pool[controller.rng.randi_range(0, card_pool.size() - 1)]
	var ticket_id := "reward-%s-%d" % [_run.run_id.md5_text(), _next_sequence]
	var entry := {"ok": true, "error_code": &"", "request_id": ticket_id, "ticket_id": ticket_id, "event_id": event_id, "reward_id": reward_id, "sequence": _next_sequence, "payload": payload, "item_id": item_id, "card_id": card_id, "stage_reward": stage_reward, "delivered": false, "message": "Nenhuma carta útil disponível." if stage_reward and card_id.is_empty() else ""}
	_tickets[ticket_id] = entry
	_events[event_id] = ticket_id
	_queue.append(ticket_id)
	_next_sequence += 1
	return ticket(ticket_id)

func eligible_cards() -> Array[StringName]:
	var result: Array[StringName] = []
	var catalog := _run.effect_catalog()
	var reserved: Array = _run.card_inventory.describe()["owned"]
	for entry: Dictionary in _tickets.values():
		if not StringName(entry["card_id"]).is_empty():
			reserved.append(entry["card_id"])
	for id: StringName in catalog.ids(&"card"):
		if id in reserved:
			continue
		var definition := catalog.get_definition(&"card", id) as CardDefinition
		if definition.effects.is_empty() or not BuildEffectCatalog.definition_allowed(definition, _run.build_snapshot):
			continue
		for slot: Variant in _run.build_snapshot.equipped:
			var item: Variant = _run.build_snapshot.equipped[slot]
			if item == null or StringName(slot) not in definition.allowed_slots:
				continue
			var before_effects := _run.effect_state()
			before_effects["card_sockets"].erase(item)
			var before := BuildEffectComposer.compose(_run.build_snapshot, before_effects, [], catalog)
			var after_effects := before_effects.duplicate(true)
			after_effects["card_sockets"][item] = id
			var after := BuildEffectComposer.compose(_run.build_snapshot, after_effects, [], catalog)
			if before["ok"] and after["ok"] and (before["breakdown"].values() != after["breakdown"].values() or before["skill_rules"] != after["skill_rules"] or _run._effective_proc_signature(before["procs"]) != _run._effective_proc_signature(after["procs"])):
				result.append(id)
				break
	return result

func ticket(ticket_id: String) -> Dictionary:
	return _tickets[ticket_id].duplicate(true) if _tickets.has(ticket_id) else BuildEffectCatalog.failure(&"invalid_reward")

func _durable_ticket(ticket_id: String) -> Dictionary:
	return _tickets[ticket_id].duplicate(true) if _busy and _tickets.has(ticket_id) and not _queue.is_empty() and _queue[0] == ticket_id else {}

func collect(ticket_id: String) -> Dictionary:
	if _busy:
		return BuildEffectCatalog.failure(&"save_in_progress")
	var controller := _owner.get_ref() as RunController
	if controller == null or controller.run_state != _run or controller.run_finished or not controller.player.is_alive():
		return BuildEffectCatalog.failure(&"invalid_session")
	if not _tickets.has(ticket_id):
		return BuildEffectCatalog.failure(&"invalid_reward")
	var entry: Dictionary = _tickets[ticket_id]
	if entry["delivered"]:
		return {"ok": true, "error_code": &"", "request_id": ticket_id, "already_applied": true}
	if controller.encounter_active or _run.has_open_offer():
		return BuildEffectCatalog.failure(&"encounter_active" if controller.encounter_active else &"offer_open")
	if controller.build_service != null and controller.build_service.has_pending_transaction():
		return BuildEffectCatalog.failure(&"save_in_progress")
	if _queue.is_empty() or _queue[0] != ticket_id:
		return BuildEffectCatalog.failure(&"invalid_reward_sequence")
	if not _uncertain_ticket.is_empty() and _uncertain_ticket != ticket_id:
		return BuildEffectCatalog.failure(&"result_uncertain")
	_busy = true
	var persistent := controller.persistent_facade != null
	var result := {"ok": true, "error_code": &"", "request_id": ticket_id}
	if persistent:
		result = controller.persistent_facade.reconcile_transaction(ticket_id) if _uncertain_ticket == ticket_id else controller.persistent_facade.grant_run_ticket(controller, ticket_id)
	if result["ok"]:
		entry["delivered"] = true # Claim before any grant/callback.
		_queue.pop_front()
		for item: StringName in entry["payload"]["equipment_ids"]:
			if item not in _run.local_equipment:
				_run.local_equipment.append(item)
		if not StringName(entry["card_id"]).is_empty():
			_run.card_inventory.grant(entry["card_id"], _run.effect_catalog())
		_run.queue_choice()
		_uncertain_ticket = ""
		controller.set_inventory_freeze(false)
		result["persistent"] = persistent
		result["applied_reward"] = entry["payload"].duplicate(true)
		result["card_id"] = entry["card_id"]
		result["message"] = entry["message"]
	elif result.get("read_only", false):
		_uncertain_ticket = ticket_id
		controller.set_inventory_freeze(true)
	else:
		_uncertain_ticket = ""
		controller.set_inventory_freeze(false)
	_busy = false
	result["request_id"] = ticket_id
	return result

func has_pending_transaction() -> bool:
	return _busy or not _uncertain_ticket.is_empty()

func has_uncollected() -> bool:
	return not _queue.is_empty()
