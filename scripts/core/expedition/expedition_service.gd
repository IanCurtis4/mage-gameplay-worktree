class_name ExpeditionService
extends RefCounted
## Transaction coordinator. ProfileStore remains the only durable writer.
var facade: ProfileFacade
var _pending: Dictionary = {}

func _init(profile_facade: ProfileFacade) -> void:
	facade = profile_facade

func checkpoint(controller: RunController, barrier: SnapshotTickBarrier, expedition_id: String, phase_id: StringName, request_id: String, expected_revision: int, suspend: bool = false) -> Dictionary:
	if not _pending.is_empty(): return _fail(&"recovery_required")
	if controller == null or controller.persistent_facade != facade or controller.run_state == null: return _fail(&"invalid_session")
	if barrier == null or not barrier.owns(controller): return _fail(&"tick_barrier_required")
	var profile := facade.current_profile()
	if profile == null or profile.reward_session == null or profile.reward_session["run_id"] != controller.run_state.run_id or profile.reward_session["character_id"] != controller.run_state.character_id: return _fail(&"invalid_session")
	if not IdentityIds.is_technical_id(expedition_id) or not IdentityIds.is_technical_id(String(phase_id)): return _fail(&"invalid_identity")
	var lock := profile.expedition_for_character(controller.run_state.character_id)
	if lock != null and lock.lifecycle not in [&"active",&"suspended"]: return _fail(&"policy_unresolved")
	if lock != null and (lock.expedition_id != expedition_id or lock.phase_id != phase_id): return _fail(&"expedition_conflict")
	if profile.expeditions.has(expedition_id) and profile.expeditions[expedition_id].character_id != controller.run_state.character_id: return _fail(&"expedition_conflict")
	var captured := SnapshotRegistry.new().capture(controller,barrier)
	if not captured["ok"]: return captured
	return commit_cut(controller,captured["snapshot"],expedition_id,phase_id,request_id,expected_revision,suspend)

func commit_cut(controller: RunController, snapshot: Dictionary, expedition_id: String, phase_id: StringName, request_id: String, expected_revision: int, suspend: bool = false) -> Dictionary:
	if not _pending.is_empty(): return _fail(&"recovery_required")
	if controller == null or controller.persistent_facade != facade or controller._memory_snapshot_barrier == null and controller.is_inside_tree() and not controller.get_tree().paused: return _fail(&"tick_barrier_required")
	var profile := facade.current_profile()
	if profile == null: return _fail(&"profile_unavailable")
	if not IdentityIds.is_technical_id(expedition_id) or not IdentityIds.is_technical_id(String(phase_id)): return _fail(&"invalid_identity")
	var operation := "suspend" if suspend else "checkpoint"
	var fingerprint := _fingerprint(operation,expedition_id,phase_id,ExpeditionCheckpointCodec.digest_bytes(var_to_bytes(snapshot)))
	var replay := _replay(profile,expedition_id,request_id,fingerprint)
	if not replay.is_empty(): return replay
	if profile.reward_session == null or profile.reward_session["run_id"] != controller.run_state.run_id or profile.reward_session["character_id"] != controller.run_state.character_id: return _fail(&"invalid_session")
	if profile.revision != expected_revision: return _fail(&"stale_revision")
	var lock := profile.expedition_for_character(controller.run_state.character_id)
	if lock != null and lock.lifecycle not in [&"active",&"suspended"]: return _fail(&"policy_unresolved")
	if lock != null and (lock.expedition_id != expedition_id or lock.phase_id != phase_id): return _fail(&"expedition_conflict")
	if profile.expeditions.has(expedition_id) and profile.expeditions[expedition_id].character_id != controller.run_state.character_id: return _fail(&"expedition_conflict")
	var authority: Dictionary = snapshot.get("authority",{})
	if authority.get("profile_id") != profile.profile_id or authority.get("revision") != profile.revision or authority.get("reward_session") != profile.reward_session: return _fail(&"stale_revision")
	var candidate := profile.copy_state()
	var slot := lock if lock != null else ExpeditionAssetLock.new()
	slot.expedition_id = expedition_id
	slot.character_id = controller.run_state.character_id
	slot.phase_id = phase_id
	slot.lifecycle = &"suspended" if suspend else &"active"
	slot.revision += 1
	var packed := ExpeditionCheckpointCodec.pack(snapshot,ExpeditionCheckpointCodec.owner_digest(candidate,slot.character_id),profile.reward_session)
	if not packed["ok"]: return packed
	slot.checkpoint = packed["checkpoint"]
	slot.receipts[request_id] = {"fingerprint":fingerprint,"operation":operation,"revision":slot.revision}
	candidate.expeditions[expedition_id] = slot
	if suspend: candidate.reward_session = null
	return _commit(candidate,request_id,expected_revision,{"source":weakref(controller),"expedition_id":expedition_id})

func collect(controller: RunController, barrier: SnapshotTickBarrier, ticket_id: String, request_id: String, expected_revision: int) -> Dictionary:
	if not _pending.is_empty(): return _fail(&"recovery_required")
	if controller == null or controller.persistent_facade != facade or barrier == null or not barrier.owns(controller): return _fail(&"tick_barrier_required")
	var profile := facade.current_profile()
	if profile == null: return _fail(&"profile_unavailable")
	var lock := profile.expedition_for_character(controller.run_state.character_id)
	if lock == null or lock.checkpoint.is_empty() or lock.lifecycle != &"active" or profile.reward_session == null or profile.reward_session["run_id"] != controller.run_state.run_id: return _fail(&"invalid_session")
	var service := controller.reward_service
	var ticket := service.ticket(ticket_id)
	if not ticket.get("ok",false): return ticket
	var fingerprint := _fingerprint("collect",lock.expedition_id,lock.phase_id,ticket_id+":"+MigrationPlan.canonical(ticket["payload"]))
	var replay := _replay(profile,lock.expedition_id,request_id,fingerprint)
	if not replay.is_empty():
		if replay.get("ok",false) and not ticket["delivered"]: return _fail(&"checkpoint_reload_required")
		return replay
	if profile.revision != expected_revision: return _fail(&"stale_revision")
	if ticket["delivered"]: return _fail(&"request_conflict")
	if service.has_pending_transaction() or controller.inventory_frozen or controller.encounter_active or controller.run_state.has_open_offer() or controller.run_finished or not controller.player.is_alive(): return _fail(&"save_in_progress")
	if service._queue.is_empty() or service._queue[0] != ticket_id: return _fail(&"invalid_reward_sequence")
	if not service._presentation_xp_before.has(ticket_id): service._presentation_xp_before[ticket_id] = service._observe_xp(controller)
	var captured := SnapshotRegistry.new().capture(controller,barrier)
	if not captured["ok"]: return captured
	var prepared := facade.prepare_ticket_candidate(profile,request_id,ticket["sequence"],ticket["payload"])
	if not prepared["ok"]: return prepared
	var candidate: ProfileState = prepared["candidate"]
	# Mutate a detached graph only; callbacks and material publication wait for commit.
	var registry := SnapshotRegistry.new()
	var restored := registry.restore(captured["snapshot"],facade)
	if not restored["ok"]: return restored
	var staged: RunController = restored["root"]
	staged.reward_service.apply_collected(ticket_id,prepared,candidate)
	# Off-tree preparation may use original modes without advancing a single tick.
	for id: String in captured["snapshot"]["objects"]:
		var object: Object = restored["entities"].resolve(id)
		if object is Node: object.process_mode = int(captured["snapshot"]["objects"][id]["node"]["mode"])
	var staged_barrier := SnapshotTickBarrier.new()
	staged_barrier.acquire(staged)
	var after := SnapshotRegistry.new().capture(staged,staged_barrier)
	staged_barrier.release()
	staged.free()
	if not after["ok"]: return after
	lock.revision += 1
	var packed := ExpeditionCheckpointCodec.pack(after["snapshot"],ExpeditionCheckpointCodec.owner_digest(candidate,lock.character_id),candidate.reward_session)
	if not packed["ok"]: return packed
	lock.checkpoint = packed["checkpoint"]
	lock.receipts[request_id] = {"fingerprint":fingerprint,"operation":"collect","revision":lock.revision}
	candidate.expeditions[lock.expedition_id] = lock
	return _commit(candidate,request_id,expected_revision,{"source":weakref(controller),"expedition_id":lock.expedition_id,"ticket_id":ticket_id,"grant":prepared})

func resume(expedition_id: String, character_id: String, request_id: String, expected_revision: int) -> Dictionary:
	if not _pending.is_empty(): return _fail(&"recovery_required")
	var profile := facade.current_profile()
	if profile == null or not profile.expeditions.has(expedition_id): return _fail(&"invalid_session")
	var lock := profile.expeditions[expedition_id].copy_lock()
	if lock.character_id != character_id: return _fail(&"not_owner")
	if lock.checkpoint.is_empty(): return _fail(&"checkpoint_incomplete")
	if lock.lifecycle not in [&"active",&"suspended"]: return _fail(&"policy_unresolved")
	var fingerprint := _fingerprint("resume",expedition_id,lock.phase_id,character_id)
	var replay := _replay(profile,expedition_id,request_id,fingerprint)
	if not replay.is_empty():
		if not replay.get("ok",false): return replay
		if lock.lifecycle != &"active" or profile.reward_session != lock.checkpoint["session"]: return _fail(&"invalid_session")
		var reopened := _restore(lock)
		if reopened["ok"]: reopened["already_applied"] = true
		return reopened
	if profile.revision != expected_revision: return _fail(&"stale_revision")
	if profile.reward_session != null and profile.reward_session != lock.checkpoint["session"]: return _fail(&"run_active")
	# Compatibility and passive reconstruction must succeed BEFORE changing the durable state.
	var restored := _restore(lock)
	if not restored["ok"]: return restored
	restored["root"].free()
	var candidate := profile.copy_state()
	candidate.selected_character_id = character_id
	candidate.reward_session = lock.checkpoint["session"].duplicate(true)
	lock.lifecycle = &"active"
	lock.revision += 1
	lock.receipts[request_id] = {"fingerprint":fingerprint,"operation":"resume","revision":lock.revision}
	candidate.expeditions[expedition_id] = lock
	var committed := _commit(candidate,request_id,expected_revision,{"expedition_id":expedition_id,"resume":true})
	return committed

func reconcile(request_id: String) -> Dictionary:
	if _pending.is_empty() or _pending.get("request_id") != request_id: return _fail(&"invalid_transaction")
	var result := facade.reconcile_transaction(request_id)
	if result.get("ok",false):
		var context := _pending.duplicate()
		_pending.clear()
		return _publish(result,context)
	if not result.get("read_only",false): _pending.clear()
	return result

func _restore(lock: ExpeditionAssetLock) -> Dictionary:
	var profile := facade.current_profile()
	if ExpeditionCheckpointCodec.owner_digest(profile,lock.character_id) != lock.checkpoint["owner_digest"]: return _fail(&"checkpoint_assets_mismatch")
	var decoded := ExpeditionCheckpointCodec.unpack(lock.checkpoint)
	if not decoded["ok"]: return decoded
	var snapshot: Dictionary = decoded["snapshot"]
	# Rebind only the external authority, after owner digest/receipt validation.
	# Alts may advance the profile revision without changing this frozen character.
	snapshot["authority"] = {"profile_id":profile.profile_id,"revision":profile.revision,"reward_session":profile.reward_session}
	var registry := SnapshotRegistry.new()
	var result := registry.restore(snapshot,facade)
	if result["ok"]:
		var host := result["root"] as RunController
		if host == null or host.run_state.character_id != lock.character_id or host.run_state.run_id != lock.checkpoint["session"]["run_id"]:
			result["root"].free()
			return _fail(&"invalid_session")
		result["registry"] = registry
	return result

func _commit(candidate: ProfileState, request_id: String, expected_revision: int, context: Dictionary) -> Dictionary:
	context["request_id"] = request_id
	var result := facade.commit_expedition_candidate(candidate,request_id,expected_revision)
	if result.get("ok",false): return _publish(result,context)
	if result.get("read_only",false): _pending = context
	return result

func _publish(result: Dictionary, context: Dictionary) -> Dictionary:
	var profile := facade.current_profile()
	var lock: ExpeditionAssetLock = profile.expeditions[context["expedition_id"]]
	if lock.lifecycle == &"suspended" and context.has("source"):
		var suspended_host := context["source"].get_ref() as RunController
		if suspended_host != null: suspended_host.snapshot_passive = true
	if context.get("resume",false):
		var restored := _restore(lock)
		if not restored["ok"]:
			restored["durable"] = true
			return restored
		result.merge(restored,true)
	if context.has("ticket_id"):
		var controller := context["source"].get_ref() as RunController
		if controller != null:
			var ticket_id: String = context["ticket_id"]
			if not controller.reward_service.ticket(ticket_id).get("delivered",false):
				controller.reward_service.apply_collected(ticket_id,context["grant"],profile)
				# Claim already durable and applied before this reentrant callback.
				var entry := controller.reward_service.ticket(ticket_id)
				var receipt := controller.reward_service._confirmed_receipt(controller,entry,true)
				result["acquisition"] = receipt.duplicate(true)
				result["persistent"] = true
				result["applied_reward"] = entry["payload"].duplicate(true)
				result["card_id"] = entry["card_id"]
				result["card_instance_id"] = entry.get("card_instance_id",&"")
				controller.reward_service.reward_confirmed.emit(receipt)
	result["expedition_id"] = lock.expedition_id
	result["durable"] = true
	result["lifecycle"] = lock.lifecycle
	return result

func _replay(profile: ProfileState, expedition_id: String, request_id: String, fingerprint: String) -> Dictionary:
	if not CharacterAssets.valid_request(request_id): return _fail(&"invalid_request_id")
	# A request ID cannot silently move to another character/expedition.
	for slot: ExpeditionAssetLock in profile.expeditions.values():
		if not slot.receipts.has(request_id): continue
		if slot.expedition_id != expedition_id or slot.receipts[request_id]["fingerprint"] != fingerprint: return _fail(&"request_conflict")
		return {"ok":true,"already_applied":true,"durable":true,"expedition_id":expedition_id,"new_revision":profile.revision}
	return {}

func _fingerprint(operation: String, expedition_id: String, phase_id: StringName, payload: String) -> String:
	return MigrationPlan.canonical([operation,expedition_id,String(phase_id),payload]).sha256_text()

func _fail(code: StringName) -> Dictionary:
	return ExpeditionCheckpointCodec.fail(code)
