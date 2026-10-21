class_name RunRewardService
extends RefCounted
## Tickets are minted by world events. collect accepts only an issued ticket ID.

signal reward_confirmed(receipt: Dictionary)
# Baselines are presentation-only and retained across an uncertain retry.
var _presentation_xp_before: Dictionary = {}

var _owner: WeakRef
var _run: RunState
var _tickets: Dictionary = {}
var _events: Dictionary = {}
var _queue: Array[String] = []
var _next_sequence := 1
var _busy := false
var _uncertain_ticket := ""
var _loot_resolver: MobLootResolver
var _mob_actors: Dictionary = {}
var _occurrence_actors: Dictionary = {}

func _init(controller: RunController) -> void:
	if controller == null: return # Snapshot factory: references are linked in pass 2.
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
	if stage_reward and mob_loot_enabled():
		payload["equipment_ids"] = []
	payload["equipment_drops"] = []
	var catalog := _run.effect_catalog()
	var profile_catalog := _run.build_snapshot._skill_catalog
	for definition_id: StringName in payload["equipment_ids"]:
		var metadata := profile_catalog.equipment_metadata(definition_id)
		metadata["definition_id"] = definition_id
		var checked := EquipmentInstance.from_metadata(&"reward_candidate", definition_id, metadata)
		if not checked["ok"]:
			return checked
		checked = EquipmentRules.validate_instance(checked["instance"], metadata)
		if not checked["ok"]:
			return checked
		checked = catalog.validate_equipment_quality(catalog.get_definition(&"equipment", definition_id) as EquipmentDefinition, StringName(metadata["quality_id"]))
		if not checked["ok"]:
			return checked
		payload["equipment_drops"].append(metadata)
	var item_pool: Array[StringName] = []
	var card_pool: Array[StringName] = []
	if stage_reward and not mob_loot_enabled():
		for id: StringName in catalog.ids(&"equipment"):
			var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
			if not item.starter and item.quality_id != &"legendary" and BuildEffectCatalog.definition_allowed(item, _run.build_snapshot):
				var checked := EquipmentInstance.from_metadata(&"reward_candidate", id, item.metadata())
				if not checked["ok"]:
					return checked
				checked = EquipmentRules.validate_instance(checked["instance"], item.metadata())
				if not checked["ok"]:
					return checked
				checked = catalog.validate_equipment_quality(item, item.quality_id)
				if not checked["ok"]:
					return checked
				item_pool.append(id)
		card_pool = eligible_cards()
	var item_id: StringName = &""
	var card_id: StringName = &""
	if not item_pool.is_empty():
		item_id = item_pool[controller.rng.randi_range(0, item_pool.size() - 1)]
		payload["equipment_ids"].append(item_id)
		var metadata := (catalog.get_definition(&"equipment", item_id) as EquipmentDefinition).metadata()
		metadata["definition_id"] = item_id
		payload["equipment_drops"].append(metadata)
	if not card_pool.is_empty():
		card_id = card_pool[controller.rng.randi_range(0, card_pool.size() - 1)]
	var ticket_id := "reward-%s-%d" % [_run.run_id.md5_text(), _next_sequence]
	var message := "XP e escolha de augment disponíveis." if stage_reward and mob_loot_enabled() else ("Nenhuma carta útil disponível." if stage_reward and card_id.is_empty() else "")
	payload["card_id"] = card_id
	var entry := {"ok": true, "error_code": &"", "request_id": ticket_id, "ticket_id": ticket_id, "event_id": event_id, "reward_id": reward_id, "encounter_index": controller.encounter_index, "sequence": _next_sequence, "payload": payload, "item_id": item_id, "card_id": card_id, "stage_reward": stage_reward, "delivered": false, "message": message}
	_tickets[ticket_id] = entry
	_events[event_id] = ticket_id
	_queue.append(ticket_id)
	_next_sequence += 1
	return ticket(ticket_id)

func eligible_cards() -> Array[StringName]:
	var result: Array[StringName] = []
	var catalog := _run.effect_catalog()
	for id: StringName in catalog.ids(&"card"):
		var definition := catalog.get_definition(&"card", id) as CardDefinition
		if definition.effects.is_empty() or not BuildEffectCatalog.definition_allowed(definition, _run.build_snapshot):
			continue
		var useful := false
		for slot: StringName in IdentityIds.equipment_slots():
			var item: Variant = _run.build_snapshot.equipped[slot]
			if item == null or slot not in definition.allowed_slots:
				continue
			var instance: EquipmentInstance = _run.build_snapshot.equipment_instances.get(item)
			if instance == null or instance.socket_capacity == 0:
				continue
			var equipment := catalog.get_definition(&"equipment", instance.definition_id) as EquipmentDefinition
			if equipment == null or not EquipmentRules.allows_sockets(equipment.metadata()):
				continue
			for index: int in instance.socket_capacity:
				var before_effects := _run.effect_state()
				var socket_list: Array = before_effects["card_sockets"].get(item, [])
				if socket_list.is_empty():
					socket_list.resize(instance.socket_capacity)
				if socket_list.size() != instance.socket_capacity:
					continue
				socket_list[index] = null
				before_effects["card_sockets"][item] = socket_list
				var before := BuildEffectComposer.compose(_run.build_snapshot, before_effects, [], catalog)
				var after_effects := before_effects.duplicate(true)
				after_effects["card_sockets"][item][index] = &"candidate_card"
				after_effects["card_instances"][&"candidate_card"] = id
				var after := BuildEffectComposer.compose(_run.build_snapshot, after_effects, [], catalog)
				if _run.has_effective_gain(before, after):
					useful = true
					break
			if useful:
				break
		if useful:
			result.append(id)
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
	if persistent and not _presentation_xp_before.has(ticket_id):
		_presentation_xp_before[ticket_id] = _observe_xp(controller)
	var result := {"ok": true, "error_code": &"", "request_id": ticket_id}
	if persistent:
		result = controller.persistent_facade.reconcile_transaction(ticket_id) if _uncertain_ticket == ticket_id else controller.persistent_facade.grant_run_ticket(controller, ticket_id)
	if result["ok"]:
		entry["delivered"] = true # Claim before any grant/callback.
		_queue.pop_front()
		if persistent:
			var profile := controller.persistent_facade.current_profile()
			_run.local_equipment_instances.clear()
			for id: StringName in profile.equipment_for_character(_run.character_id):
				_run.local_equipment_instances[id] = profile.equipment_instances[id].copy_instance()
		else:
			for drop: Dictionary in entry["payload"]["equipment_drops"]:
				_run.add_local_equipment(StringName(drop["definition_id"]), drop)
		if persistent:
			_run.card_inventory = controller.persistent_facade.current_profile().card_inventory.for_character(_run.character_id, _run.local_equipment_instances)
			_run.build_snapshot.card_inventory = _run.card_inventory.copy_inventory()
			entry["card_instance_id"] = result.get("card_instance_id", &"")
			_run.card_instances = _run.card_inventory.describe()["instances"]
			_run.card_sockets = _run.card_inventory.sockets()
		if not persistent and not StringName(entry["card_id"]).is_empty():
			var granted := _run.card_inventory.grant(entry["card_id"], _run.effect_catalog(), ticket_id)
			entry["card_instance_id"] = granted.get("card_instance_id", &"")
			_run.card_instances = _run.card_inventory.describe()["instances"]
		if not entry.get("mob_ticket", false):
			_run.queue_choice()
		_uncertain_ticket = ""
		controller.set_inventory_freeze(false)
		result["persistent"] = persistent
		result["applied_reward"] = entry["payload"].duplicate(true)
		result["card_id"] = entry["card_id"]
		result["card_instance_id"] = entry.get("card_instance_id", &"")
		result["message"] = entry["message"]
	elif result.get("read_only", false):
		_uncertain_ticket = ticket_id
		controller.set_inventory_freeze(true)
	else:
		_uncertain_ticket = ""
		controller.set_inventory_freeze(false)
	_busy = false
	result["request_id"] = ticket_id
	if result["ok"]:
		var receipt := _confirmed_receipt(controller, entry, persistent)
		result["acquisition"] = receipt.duplicate(true)
		reward_confirmed.emit(receipt)
	return result

func has_pending_transaction() -> bool:
	return _busy or not _uncertain_ticket.is_empty()

func has_uncollected() -> bool:
	return not _queue.is_empty()

func mob_loot_enabled() -> bool:
	return _loot_resolver != null

func configure_mob_loot(table: MobLootTable) -> Dictionary:
	var controller := _owner.get_ref() as RunController
	if controller == null or not _events.is_empty() or has_pending_transaction() or controller.training_mode:
		return BuildEffectCatalog.failure(&"invalid_mob_event")
	var created := MobLootResolver.create(_run.effect_catalog(), table)
	if not created["ok"]: return created
	var resolver: MobLootResolver = created["resolver"]
	var actors: Dictionary = {}
	var occurrences: Dictionary = {}
	for actor: CombatActor in controller.enemies:
		if actor is EnemyActor and actor.is_summoned: continue
		if not actor is EnemyActor or actor.get_parent() != controller or actor.occurrence == null:
			return BuildEffectCatalog.failure(&"invalid_mob_event")
		var checked := resolver.validate_occurrence(actor.occurrence)
		if not checked["ok"]: return checked
		if occurrences.has(actor.occurrence.occurrence_id): return BuildEffectCatalog.failure(&"invalid_occurrence")
		actors[actor.get_instance_id()] = {"actor": weakref(actor), "occurrence": actor.occurrence.copy_occurrence()}
		occurrences[actor.occurrence.occurrence_id] = actor.get_instance_id()
	_loot_resolver = resolver
	_mob_actors = actors
	_occurrence_actors = occurrences
	_run.freeze_effect_catalog()
	return {"ok": true}

func register_mob_actor(actor: EnemyActor) -> Dictionary:
	if is_instance_valid(actor) and actor.get_meta("admin_spawn", false): return BuildEffectCatalog.failure(&"admin_mob_ineligible")
	if is_instance_valid(actor) and actor.is_summoned: return BuildEffectCatalog.failure(&"summoned_mob_ineligible")
	var controller := _owner.get_ref() as RunController
	if not mob_loot_enabled() or controller == null or not is_instance_valid(actor) or not actor.is_alive() or actor.get_parent() != controller or actor not in controller.enemies or actor.occurrence == null:
		return BuildEffectCatalog.failure(&"invalid_mob_event")
	var checked := _loot_resolver.validate_occurrence(actor.occurrence)
	if not checked["ok"]: return checked
	var id := actor.get_instance_id()
	if _mob_actors.has(id): return {"ok": true, "already_applied": true}
	if _occurrence_actors.has(actor.occurrence.occurrence_id): return BuildEffectCatalog.failure(&"invalid_occurrence")
	_mob_actors[id] = {"actor": weakref(actor), "occurrence": actor.occurrence.copy_occurrence()}
	_occurrence_actors[actor.occurrence.occurrence_id] = id
	return {"ok": true}

func issue_mob_drop(actor: EnemyActor) -> Dictionary:
	if is_instance_valid(actor) and actor.get_meta("admin_spawn", false): return BuildEffectCatalog.failure(&"admin_mob_ineligible")
	if is_instance_valid(actor) and actor.is_summoned: return BuildEffectCatalog.failure(&"summoned_mob_ineligible")
	var controller := _owner.get_ref() as RunController
	if not mob_loot_enabled() or controller == null or controller.run_state != _run or controller.run_finished or not controller.player.is_alive() or not is_instance_valid(actor):
		return BuildEffectCatalog.failure(&"invalid_mob_event")
	var registered: Dictionary = _mob_actors.get(actor.get_instance_id(), {})
	if registered.is_empty() or registered["actor"].get_ref() != actor or actor.get_parent() != controller or actor.is_alive():
		return BuildEffectCatalog.failure(&"unknown_mob_actor")
	var occurrence: MobOccurrence = registered["occurrence"]
	var event := "mob:" + occurrence.occurrence_id
	if _events.has(event): return ticket(_events[event])
	if has_pending_transaction() or controller.inventory_frozen: return BuildEffectCatalog.failure(&"save_in_progress")
	var checked := _loot_resolver.validate_occurrence(occurrence)
	if not checked["ok"]: return checked
	var values: Array[float] = []
	for index: int in 5: values.append(controller.rng.randf())
	var rolled := _loot_resolver.roll(occurrence, values)
	assert(rolled["ok"], "Validated immutable loot must resolve without failure")
	var payload := {"base_xp": 0, "job_xp": 0, "equipment_ids": [], "equipment_drops": rolled["equipment_drops"].duplicate(true), "stat_increments": {}}
	for drop: Dictionary in payload["equipment_drops"]: payload["equipment_ids"].append(drop["definition_id"])
	payload["card_id"] = rolled["card_id"]
	var ticket_id := "reward-%s-%d" % [_run.run_id.md5_text(), _next_sequence]
	var entry := {"ok": true, "error_code": &"", "request_id": ticket_id, "ticket_id": ticket_id, "event_id": event, "reward_id": &"mob_drop", "encounter_index": controller.encounter_index, "sequence": _next_sequence, "payload": payload, "item_id": payload["equipment_ids"][0] if not payload["equipment_ids"].is_empty() else &"", "card_id": rolled["card_id"], "stage_reward": false, "mob_ticket": true, "delivered": false, "message": "Loot do inimigo coletado.", "mob_base_id": occurrence.mob_base_id, "category_id": occurrence.category_id, "occurrence_id": occurrence.occurrence_id}
	_tickets[ticket_id] = entry
	_events[event] = ticket_id
	_queue.append(ticket_id)
	_next_sequence += 1
	return ticket(ticket_id)

func collect_pending_mob_tickets() -> Dictionary:
	while not _queue.is_empty() and _tickets[_queue[0]].get("mob_ticket", false):
		var result := collect(_queue[0])
		if not result["ok"]: return result
	return {"ok": true}

func _observe_xp(controller: RunController) -> Dictionary:
	var profile := controller.persistent_facade.current_profile()
	var character := profile.character_by_id(_run.character_id) if profile != null else null
	return {"base_xp": character.base_xp_total, "job_xp": character.job_xp_total} if character != null else {"base_xp": 0, "job_xp": 0}

func _confirmed_receipt(controller: RunController, entry: Dictionary, persistent: bool) -> Dictionary:
	var before: Dictionary = _presentation_xp_before.get(entry["ticket_id"], {"base_xp": 0, "job_xp": 0})
	var after := _observe_xp(controller) if persistent else before
	var payload: Dictionary = entry["payload"]
	return {"ticket_id": entry["ticket_id"], "encounter_index": entry["encounter_index"], "persistent": persistent, "base_xp": maxi(0, int(after["base_xp"]) - int(before["base_xp"])), "job_xp": maxi(0, int(after["job_xp"]) - int(before["job_xp"])), "offered_base_xp": int(payload["base_xp"]) if persistent else 0, "offered_job_xp": int(payload["job_xp"]) if persistent else 0, "equipment_drops": payload["equipment_drops"].duplicate(true), "card_id": entry["card_id"]}
