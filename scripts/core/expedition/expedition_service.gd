class_name ExpeditionService
extends RefCounted
## Transaction coordinator. ProfileStore remains the only durable writer.
const Journal = preload("res://scripts/core/expedition/persistence/expedition_journal_codec.gd")
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
	if lock != null and lock.lifecycle not in [&"active",&"suspended",&"recovering"]: return _fail(&"policy_unresolved")
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
	if lock != null and lock.lifecycle not in [&"active",&"suspended",&"recovering"]: return _fail(&"policy_unresolved")
	if lock != null and (lock.expedition_id != expedition_id or lock.phase_id != phase_id): return _fail(&"expedition_conflict")
	if profile.expeditions.has(expedition_id) and profile.expeditions[expedition_id].character_id != controller.run_state.character_id: return _fail(&"expedition_conflict")
	var authority: Dictionary = snapshot.get("authority",{})
	if authority.get("profile_id") != profile.profile_id or authority.get("revision") != profile.revision or authority.get("reward_session") != profile.reward_session: return _fail(&"stale_revision")
	var candidate := profile.copy_state()
	var slot := lock if lock != null else ExpeditionAssetLock.new()
	slot.expedition_id = expedition_id
	slot.character_id = controller.run_state.character_id
	slot.phase_id = phase_id
	slot.lifecycle = &"suspended" if suspend else (&"recovering" if _unrevived_death(controller) else &"active")
	slot.revision += 1
	var packed := ExpeditionCheckpointCodec.pack(snapshot,ExpeditionCheckpointCodec.owner_digest(candidate,slot.character_id),profile.reward_session)
	if not packed["ok"]: return packed
	slot.checkpoint = packed["checkpoint"]
	slot.journal = []
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
	lock.journal = []
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
	if lock.lifecycle not in [&"active",&"suspended",&"recovering"]: return _fail(&"policy_unresolved")
	var fingerprint := _fingerprint("resume",expedition_id,lock.phase_id,character_id)
	var replay := _replay(profile,expedition_id,request_id,fingerprint)
	if not replay.is_empty():
		if not replay.get("ok",false): return replay
		if lock.lifecycle not in [&"active", &"recovering"] or profile.reward_session != lock.checkpoint["session"]: return _fail(&"invalid_session")
		var reopened := _restore(lock)
		if reopened["ok"]: reopened["already_applied"] = true
		return reopened
	if profile.revision != expected_revision: return _fail(&"stale_revision")
	if profile.reward_session != null and profile.reward_session != lock.checkpoint["session"]: return _fail(&"run_active")
	# Compatibility and passive reconstruction must succeed BEFORE changing the durable state.
	var restored := _restore(lock)
	if not restored["ok"]: return restored
	var recovering := _unrevived_death(restored["root"])
	restored["root"].free()
	var candidate := profile.copy_state()
	candidate.selected_character_id = character_id
	candidate.reward_session = lock.checkpoint["session"].duplicate(true)
	lock.lifecycle = &"recovering" if recovering else &"active"
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
	if not result.get("read_only",false):
		_discard_staged(_pending)
		_pending.clear()
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
		if not lock.journal.is_empty():
			var replayed := _journal_replay(result, lock)
			if not replayed["ok"]:
				result["root"].free()
				return replayed
		if host.campaign_runtime != null: host.campaign_runtime.state.lifecycle = "recovering" if _unrevived_death(host) else String(lock.lifecycle)
		result["registry"] = registry
	return result

func _commit(candidate: ProfileState, request_id: String, expected_revision: int, context: Dictionary) -> Dictionary:
	context["request_id"] = request_id
	var result := facade.commit_expedition_candidate(candidate,request_id,expected_revision)
	if result.get("ok",false): return _publish(result,context)
	if result.get("read_only",false): _pending = context
	else: _discard_staged(context)
	return result

func _publish(result: Dictionary, context: Dictionary) -> Dictionary:
	var profile := facade.current_profile()
	var lock: ExpeditionAssetLock = profile.expeditions[context["expedition_id"]]
	if context.get("inplace_build", false):
		var host := context["source"].get_ref() as RunController
		if host != null: host.build_service._publish(context["prepared_build"])
		_discard_staged(context)
	elif context.get("campaign", false):
		# This exact world was fully decoded/validated BEFORE the commit. Keep it
		# inert through uncertain writes and publish it only after confirmation.
		var restored: Dictionary = context["staged"]
		restored["snapshot"]["authority"] = {"profile_id": profile.profile_id, "revision": profile.revision, "reward_session": profile.reward_session}
		restored["root"].campaign_runtime.state.lifecycle = String(lock.lifecycle)
		result.merge(restored, true)
		result["registry"] = context["staged_registry"]
		var previous := context["source"].get_ref() as RunController
		if previous != null: previous.snapshot_passive = true
	if context.has("journal_payload"):
		var live := context["source"].get_ref() as RunController
		if live != null:
			var holder: SnapshotTickBarrier = context["barrier"].get_ref() if context.has("barrier") else null
			var applied := _journal_apply(live, context["journal_payload"], false, holder)
			if not applied["ok"]: return applied
		result["journal_seq"] = lock.journal.size()
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

# Active equipment/card changes use the same profile writer and a fully decoded
# post-change world. The inventory consumer keeps its original scene on success.
func change_build(controller: RunController, barrier: SnapshotTickBarrier, intent: Dictionary) -> Dictionary:
	if not _pending.is_empty(): return _fail(&"recovery_required")
	if controller == null or controller.persistent_facade != facade or controller.campaign_runtime == null or barrier == null or not barrier.owns(controller): return _fail(&"tick_barrier_required")
	var prepared := controller.build_service._prepare(intent)
	if not prepared["ok"]: return prepared
	var profile := facade.current_profile()
	var lock := profile.expedition_for_character(controller.run_state.character_id)
	if lock == null or lock.lifecycle != &"active": return _fail(&"invalid_session")
	var request_id: String = intent["request_id"]
	var fingerprint := _fingerprint("build", lock.expedition_id, lock.phase_id, ExpeditionCanonical.encode(intent))
	var replay := _replay(profile, lock.expedition_id, request_id, fingerprint)
	if not replay.is_empty(): return replay
	var material := facade.prepare_build_candidate(profile, prepared, lock.character_id)
	if not material["ok"]: return material
	var candidate: ProfileState = material["candidate"]
	var cut := SnapshotRegistry.new().capture(controller, barrier)
	if not cut["ok"]: return cut
	var restored := SnapshotRegistry.new().restore(cut["snapshot"], facade)
	if not restored["ok"]: return restored
	var staged: RunController = restored["root"]
	for id: String in cut["snapshot"]["objects"]:
		var object: Object = restored["entities"].resolve(id)
		if object is Node: object.process_mode = int(cut["snapshot"]["objects"][id]["node"]["mode"])
	var staged_prepared := staged.build_service._prepare(intent)
	if not staged_prepared["ok"]: staged.free(); return staged_prepared
	staged.build_service._publish(staged_prepared)
	staged.build_service._busy = false
	staged.build_service._committing_intent = {}
	staged.build_service._pending = {}
	var staged_barrier := SnapshotTickBarrier.new()
	staged_barrier.acquire(staged)
	var after := SnapshotRegistry.new().capture(staged, staged_barrier)
	staged_barrier.release()
	staged.free()
	if not after["ok"]: return after
	var final_registry := SnapshotRegistry.new()
	var final_world := final_registry.restore(after["snapshot"], facade)
	if not final_world["ok"]: return final_world
	lock.revision += 1
	var packed := ExpeditionCheckpointCodec.pack(after["snapshot"], ExpeditionCheckpointCodec.owner_digest(candidate, lock.character_id), candidate.reward_session)
	if not packed["ok"]: final_world["root"].free(); return packed
	lock.checkpoint = packed["checkpoint"]
	lock.journal = []
	lock.receipts[request_id] = {"fingerprint": fingerprint, "operation": "build", "revision": lock.revision}
	candidate.expeditions[lock.expedition_id] = lock
	return _commit(candidate, request_id, int(intent["profile_revision"]), {"source": weakref(controller), "expedition_id": lock.expedition_id, "inplace_build": true, "prepared_build": prepared, "staged": final_world})

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

func _unrevived_death(host: RunController) -> bool:
	if host.campaign_runtime == null: return false
	var state := host.campaign_runtime.state
	return not host.player.is_alive() and state.death_events.has(state.current_death_id) and not state.death_events[state.current_death_id]["revived"]

func _discard_staged(context: Dictionary) -> void:
	if context.has("staged"):
		var root: Node = context["staged"].get("root")
		if is_instance_valid(root): root.free()

# F5 commands stage a complete passive graph. No world callback, grant, scene
# replacement or portal flag is published before the canonical writer commits.
func enter(controller: RunController, barrier: SnapshotTickBarrier, expedition_id: String, manifest: ExpeditionManifest, rules: Dictionary, request_id: String, expected_revision: int) -> Dictionary:
	if manifest == null: return _fail(&"invalid_manifest")
	return campaign_command(controller, barrier, {"kind": "enter", "expedition_id": expedition_id, "manifest": manifest.to_data(), "rules": rules.duplicate(true)}, request_id, expected_revision)

func travel(controller: RunController, barrier: SnapshotTickBarrier, portal_id: String, stage_id: String, request_id: String, expected_revision: int) -> Dictionary:
	return campaign_command(controller, barrier, {"kind": "travel", "portal_id": portal_id, "stage_id": stage_id}, request_id, expected_revision)

func record_death(controller: RunController, barrier: SnapshotTickBarrier, slot_id: String, generation: int, event_id: String, request_id: String, expected_revision: int) -> Dictionary:
	return campaign_command(controller, barrier, {"kind": "events", "events": [{"kind": "mob_death", "slot_id": slot_id, "generation": generation, "event_id": event_id}]}, request_id, expected_revision)

func revive(controller: RunController, barrier: SnapshotTickBarrier, death_event_id: String, request_id: String, expected_revision: int) -> Dictionary:
	return campaign_command(controller, barrier, {"kind": "revive", "event_id": death_event_id}, request_id, expected_revision)

func finish(controller: RunController, barrier: SnapshotTickBarrier, outcome: String, source: String, request_id: String, expected_revision: int) -> Dictionary:
	return campaign_command(controller, barrier, {"kind": "finish", "outcome": outcome, "source": source}, request_id, expected_revision)

func campaign_command(controller: RunController, barrier: SnapshotTickBarrier, command: Dictionary, request_id: String, expected_revision: int, frozen_cut: Dictionary = {}) -> Dictionary:
	if not _pending.is_empty(): return _fail(&"recovery_required")
	if not _valid_campaign_command(command): return _fail(&"invalid_payload")
	if controller == null or controller.persistent_facade != facade or barrier == null or not barrier.owns(controller): return _fail(&"tick_barrier_required")
	var profile := facade.current_profile()
	if profile == null: return _fail(&"profile_unavailable")
	var entering: bool = command.get("kind") == "enter"
	if entering and controller.campaign_runtime != null: return _fail(&"expedition_conflict")
	if not entering and controller.campaign_runtime == null: return _fail(&"invalid_session")
	var id: String = command.get("expedition_id", "") if entering else controller.campaign_runtime.state.expedition_id
	var phase: StringName = StringName(command["manifest"]["input"]["phase_id"]) if entering else StringName(controller.campaign_runtime.state.manifest_data["input"]["phase_id"])
	if not IdentityIds.is_technical_id(id): return _fail(&"invalid_identity")
	var fingerprint := _fingerprint("campaign", id, phase, ExpeditionCanonical.encode(command))
	var replay := _replay(profile, id, request_id, fingerprint)
	if not replay.is_empty():
		if replay.get("ok", false):
			if profile.expeditions[id].lifecycle == &"completed": return replay
			var reopened := _restore(profile.expeditions[id])
			if not reopened["ok"]: return reopened
			replay.merge(reopened, true)
		return replay
	if profile.revision != expected_revision: return _fail(&"stale_revision")
	if profile.reward_session == null or profile.reward_session["run_id"] != controller.run_state.run_id or profile.reward_session["character_id"] != controller.run_state.character_id: return _fail(&"invalid_session")
	var lock := profile.expedition_for_character(controller.run_state.character_id)
	if entering and lock != null: return _fail(&"expedition_conflict")
	if not entering and (lock == null or lock.expedition_id != id): return _fail(&"invalid_session")
	# A cut taken under this same held barrier is identical to a fresh capture.
	var cut := frozen_cut if frozen_cut.get("ok", false) and frozen_cut.get("snapshot") is Dictionary else SnapshotRegistry.new().capture(controller, barrier)
	if not cut["ok"]: return cut
	var registry := SnapshotRegistry.new()
	var restored := registry.restore(cut["snapshot"], facade)
	if not restored["ok"]: return restored
	var staged: RunController = restored["root"]
	# Restore captured modes off-tree, without advancing or installing the graph.
	for entity_id: String in cut["snapshot"]["objects"]:
		var object: Object = restored["entities"].resolve(entity_id)
		if object is Node: object.process_mode = int(cut["snapshot"]["objects"][entity_id]["node"]["mode"])
	var changed := _apply_campaign(staged, command)
	if not changed["ok"]: staged.free(); return changed
	var candidate := profile.copy_state()
	var state := staged.campaign_runtime.state
	if state.completed:
		var character := candidate.character_by_id(state.character_id)
		var gold: int = int(state.policy["completion_gold"])
		if gold > EquipmentRules.MAX_EXACT_INTEGER - character.gold: staged.free(); return _fail(&"gold_overflow")
		character.gold += gold
		character.base_xp_total = ProgressionRules.add_base_xp(character.base_xp_total, int(state.policy["completion_base_xp"]))
		character.job_xp_total = ProgressionRules.add_job_xp(character.job_xp_total, int(state.policy["completion_job_xp"]), not character.evolution_id.is_empty())
		candidate.profile_unlocks[StringName("completed_" + String(phase).sha256_text().substr(0, 54))] = true
		candidate.lifetime_stats[&"runs_completed"] += 1
		candidate.reward_session = null
	var staged_barrier := SnapshotTickBarrier.new()
	staged_barrier.acquire(staged)
	var after := SnapshotRegistry.new().capture(staged, staged_barrier)
	staged_barrier.release()
	staged.free()
	if not after["ok"]: return after
	var final_registry := SnapshotRegistry.new()
	var final_world := final_registry.restore(after["snapshot"], facade)
	if not final_world["ok"]: return final_world
	var slot := lock if lock != null else ExpeditionAssetLock.new()
	slot.expedition_id = id
	slot.character_id = controller.run_state.character_id
	slot.phase_id = phase
	slot.lifecycle = StringName(state.lifecycle)
	slot.revision += 1
	var packed := ExpeditionCheckpointCodec.pack(after["snapshot"], ExpeditionCheckpointCodec.owner_digest(candidate, slot.character_id), profile.reward_session)
	if not packed["ok"]: final_world["root"].free(); return packed
	slot.checkpoint = packed["checkpoint"]
	slot.journal = []
	slot.receipts[request_id] = {"fingerprint": fingerprint, "operation": "campaign", "revision": slot.revision}
	candidate.expeditions[id] = slot
	if state.lifecycle == "suspended": candidate.reward_session = null
	return _commit(candidate, request_id, expected_revision, {"source": weakref(controller), "expedition_id": id, "campaign": true, "staged": final_world, "staged_registry": final_registry})

func _valid_campaign_command(command: Dictionary) -> bool:
	if not command.get("kind") is String: return false
	match command["kind"]:
		"enter":
			if command.size() != 4 or not command.get("expedition_id") is String or not command.get("manifest") is Dictionary or not command.get("rules") is Dictionary: return false
			var manifest: Dictionary = command["manifest"]
			if not manifest.has_all(["input", "stages", "population", "witnesses", "portals", "objectives"]) or not manifest["input"] is Dictionary or not manifest["stages"] is Array or manifest["stages"].is_empty() or not manifest["population"] is Dictionary or not manifest["population"].get("slots") is Array or not manifest["witnesses"] is Dictionary or not manifest["portals"] is Array or not manifest["objectives"] is Array: return false
			return manifest["input"].get("phase_id") is String and manifest["input"].get("entry_stage_id") is String and manifest["input"].get("traversal") is Dictionary
		"travel": return command.size() == 3 and command.get("portal_id") is String and command.get("stage_id") is String
		"revive": return command.size() == 2 and command.get("event_id") is String and not command["event_id"].is_empty()
		"finish": return command.size() == 3 and command.get("outcome") in ["completed", "quest"] and command.get("source") is String
		"events":
			if command.size() != 2 or not command.get("events") is Array or command["events"].is_empty(): return false
			for event: Variant in command["events"]:
				if not event is Dictionary: return false
				match event.get("kind"):
					"wave":
						if event.size() != 2 or not EquipmentRules.exact_integer(event.get("wave_index"), 0): return false
					"player_death":
						if event.size() != 2 or not event.get("event_id") is String or event["event_id"].is_empty(): return false
					"mob_death":
						if event.size() != 4 or not event.get("slot_id") is String or not event.get("event_id") is String or event["event_id"].is_empty() or not EquipmentRules.exact_integer(event.get("generation"), 0): return false
					_: return false
			return true
	return false

func _apply_campaign(host: RunController, command: Dictionary) -> Dictionary:
	var kind: String = command.get("kind", "")
	if kind == "enter":
		var manifest := ExpeditionManifest.new()
		manifest._data = command["manifest"].duplicate(true)
		host.campaign_runtime = ExpeditionCampaignRuntime.new()
		host.combat_participation = CombatParticipation.new()
		return host.campaign_runtime.configure(host, command["expedition_id"], manifest, command["rules"])
	var runtime := host.campaign_runtime
	var state := runtime.state
	if kind in ["travel", "finish", "revive"] and runtime.pending_events.any(func(event: Dictionary) -> bool: return event["kind"] == "mob_death"):
		# Deaths deferred to the end of combat are applied before any other command.
		var flushed := _apply_campaign(host, {"kind": "events", "events": runtime.pending_events.duplicate(true)})
		if not flushed["ok"]: return flushed
	if kind == "events":
		for event: Dictionary in command.get("events", []):
			var result: Dictionary
			if event["kind"] == "wave":
				result = runtime.admit_pending(host)
			elif event["kind"] == "player_death":
				if host.player.is_alive(): return _fail(&"invalid_death_source")
				result = state.player_died(event["event_id"])
			else:
				if not runtime.actors.has(event.get("slot_id")): return _fail(&"invalid_death_source")
				var actor: EnemyActor = runtime.actors[event["slot_id"]]
				result = state.record_death(event["slot_id"], event["generation"], event["event_id"])
				if not result["ok"]: return result
				if not result.get("already_applied", false):
					if actor.is_alive(): return _fail(&"invalid_death_source")
					var ticket := host.reward_service.issue_mob_drop(actor)
					if not ticket["ok"]: return ticket
					_remove_dead_mob(host, actor)
			if not result["ok"]: return result
		runtime.pending_events.clear()
		return {"ok": true}
	if kind == "wave": return runtime.admit_pending(host)
	if kind == "travel":
		if state.lifecycle != "active" or command.get("stage_id") != state.current_stage_id or not host.player.is_alive(): return _fail(&"invalid_destination")
		var portal := state.portal_view(command.get("portal_id", ""))
		if portal.is_empty() or portal["from_stage"] != state.current_stage_id: return _fail(&"invalid_destination")
		if not portal["open"]: return _fail(&"portal_closed")
		if not _at_point(host, portal["from_anchor"]): return _fail(&"out_of_range")
		var moved := runtime.activate_stage(host, portal["to_stage"], portal["to_anchor"])
		if not moved["ok"]: return moved
		state.traversed_edges[ExpeditionCanonical.digest([portal["from_stage"], portal["to_stage"]])] = true
		if portal["kind"] != "local": state.anchor = portal["to_anchor"].duplicate(true)
		for source: String in state.visit(state.current_stage_id): host.run_state.queue_choice()
		return runtime.admit_pending(host)
	if kind == "revive":
		var revived := state.revive(command.get("event_id", ""))
		if not revived["ok"] or revived.get("already_applied", false): return revived
		var returned := runtime.activate_stage(host, state.anchor["stage_id"], state.anchor)
		if not returned["ok"]: return returned
		ExpeditionDeathRecovery.revive(host.player, state.policy)
		return runtime.admit_pending(host)
	if kind == "finish":
		if state.lifecycle != "active" or not host.player.is_alive(): return _fail(&"completion_unmet")
		var source := {}
		for objective: Dictionary in state.manifest_data["objectives"]:
			if objective["objective_id"] == command.get("source"): source = objective; break
		if source.is_empty() or not _at_point(host, source["point"]): return _fail(&"completion_unmet")
		if command.get("outcome") == "quest":
			if source["outcome"] != "early_exit": return _fail(&"unsupported_quest_exception")
			state.objectives[source["objective_id"]] = true
			state.lifecycle = "suspended"
			return {"ok": true}
		if command.get("outcome") != "completed" or source["outcome"] != "phase_completion" or not state.stages[state.current_stage_id]["cleared_once"]: return _fail(&"completion_unmet")
		if host.reward_service.has_uncollected(): return _fail(&"rewards_pending")
		for objective: Dictionary in state.manifest_data["objectives"]:
			if objective["required"] and objective["objective_id"] != source["objective_id"] and not state.objectives.has(objective["objective_id"]): return _fail(&"completion_unmet")
		state.completed = true
		state.lifecycle = "completed"
		host.run_finished = true
		host.run_state.augment_stacks.clear()
		host.run_state.pending_choices = 0
		host.run_state._choice_ids.clear()
		host.run_state.current_offer.clear()
		host.run_state._offer_ids.clear()
		host.run_state._offer_open = false
		host.run_state.runtime_revision += 1
		return {"ok": true}
	return _fail(&"invalid_payload")

# Checkpoint37 (J2): mob deaths become one small journal entry instead of a full
# world transaction. Effects are resolved on the live host and rolled back,
# written durably, and only then applied to the live host. Nothing is restored
# and the host is not replaced. Restoring the base replays the same payloads.
func journal_events(controller: RunController, barrier: SnapshotTickBarrier, events: Array, request_id: String, expected_revision: int) -> Dictionary:
	if not _pending.is_empty(): return _fail(&"recovery_required")
	if controller == null or controller.persistent_facade != facade or controller.campaign_runtime == null or barrier == null or not barrier.owns(controller): return _fail(&"tick_barrier_required")
	if events.is_empty() or events.any(func(event: Variant) -> bool: return not event is Dictionary or event.get("kind") != "mob_death"): return _fail(&"invalid_payload")
	if not _valid_campaign_command({"kind": "events", "events": events}): return _fail(&"invalid_payload")
	var profile := facade.current_profile()
	if profile == null: return _fail(&"profile_unavailable")
	var state := controller.campaign_runtime.state
	var id: String = state.expedition_id
	var phase := StringName(state.manifest_data["input"]["phase_id"])
	var fingerprint := _fingerprint("journal", id, phase, ExpeditionCanonical.encode(events))
	var replay := _replay(profile, id, request_id, fingerprint)
	if not replay.is_empty(): return replay
	if profile.revision != expected_revision: return _fail(&"stale_revision")
	if profile.reward_session == null or profile.reward_session["run_id"] != controller.run_state.run_id or profile.reward_session["character_id"] != controller.run_state.character_id: return _fail(&"invalid_session")
	var current := profile.expedition_for_character(controller.run_state.character_id)
	if current == null or current.expedition_id != id or current.checkpoint.is_empty() or current.lifecycle not in [&"active", &"recovering"]: return _fail(&"invalid_session")
	var resolved := _journal_effects(controller, events)
	if not resolved["ok"]: return resolved
	var candidate := profile.copy_state()
	var slot: ExpeditionAssetLock = candidate.expeditions[id]
	var made := Journal.make_entry(slot.journal, slot.checkpoint, request_id, resolved["payload"])
	if not made["ok"]: return made
	slot.journal.append(made["entry"])
	slot.revision += 1
	slot.receipts[request_id] = {"fingerprint": fingerprint, "operation": "journal", "revision": slot.revision}
	return _commit(candidate, request_id, expected_revision, {"source": weakref(controller), "barrier": weakref(barrier), "expedition_id": id, "journal_payload": resolved["payload"]})

# Validates the deaths on a scratch copy of the slot data and rolls the drops on
# the live reward ledger, then restores the ledger and RNG exactly.
func _journal_effects(host: RunController, events: Array) -> Dictionary:
	var runtime := host.campaign_runtime
	var scratch := ExpeditionCampaignState.new()
	scratch.slots = runtime.state.slots.duplicate(true)
	scratch.stages = runtime.state.stages.duplicate(true)
	var fresh: Array = []
	for event: Dictionary in events:
		if not runtime.actors.has(event["slot_id"]): return _fail(&"invalid_death_source")
		var checked := scratch.record_death(event["slot_id"], int(event["generation"]), event["event_id"])
		if not checked["ok"]: return checked
		if checked.get("already_applied", false): continue
		var actor: EnemyActor = runtime.actors[event["slot_id"]]
		if actor.is_alive(): return _fail(&"invalid_death_source")
		fresh.append(actor)
	var rewards := host.reward_service
	var saved := {"tickets": rewards._tickets.duplicate(true), "events": rewards._events.duplicate(true), "queue": rewards._queue.duplicate(), "next": rewards._next_sequence, "rng": host.rng.state}
	var tickets: Array = []
	var failure := {}
	for actor: EnemyActor in fresh:
		var issued := rewards.issue_mob_drop(actor)
		if not issued["ok"]: failure = issued; break
		tickets.append(rewards._tickets[issued["ticket_id"]].duplicate(true))
	var payload := {"events": events.duplicate(true), "tickets": tickets, "rng_state": host.rng.state, "next_sequence": rewards._next_sequence}
	rewards._tickets = saved["tickets"]; rewards._events = saved["events"]; rewards._queue = saved["queue"]; rewards._next_sequence = saved["next"]; host.rng.state = saved["rng"]
	if not failure.is_empty(): return failure
	for event: Dictionary in payload["events"]: event["generation"] = int(event["generation"])
	return {"ok": true, "payload": payload}

# Same effect live (after the durable write) and on replay over the base. Idempotent.
func _journal_apply(host: RunController, payload: Dictionary, replay: bool, barrier: SnapshotTickBarrier = null) -> Dictionary:
	var runtime := host.campaign_runtime
	if runtime == null: return _fail(&"invalid_session")
	var disabled: Array[Node] = []
	var applied := {}
	for event: Dictionary in payload["events"]:
		if not runtime.actors.has(event["slot_id"]): return _fail(&"invalid_death_source")
		var actor: EnemyActor = runtime.actors[event["slot_id"]]
		var recorded := runtime.state.record_death(event["slot_id"], int(event["generation"]), event["event_id"])
		if not recorded["ok"]: return recorded
		applied[event["event_id"]] = true
		if not host.enemies.has(actor): continue
		if actor.is_alive():
			if not replay: return _fail(&"invalid_death_source")
			actor.health.current_hp = 0.0
			actor.health._death_emitted = true
		disabled.append_array(_remove_dead_mob(host, actor, barrier))
	var rewards := host.reward_service
	for ticket: Dictionary in payload["tickets"]:
		var ticket_id: String = ticket["ticket_id"]
		if rewards._tickets.has(ticket_id): continue
		rewards._tickets[ticket_id] = ticket.duplicate(true)
		rewards._events[ticket["event_id"]] = ticket_id
		rewards._queue.append(ticket_id)
	rewards._next_sequence = maxi(rewards._next_sequence, int(payload["next_sequence"]))
	host.rng.state = payload["rng_state"]
	var kept: Array[Dictionary] = []
	for event: Dictionary in runtime.pending_events:
		if event["kind"] == "mob_death" and applied.has(event["event_id"]): continue
		kept.append(event)
	runtime.pending_events = kept
	return {"ok": true, "disabled": disabled}

# Replays the journal over a restored base before anything activates it. The
# registry would re-enable removed mobs from their recorded modes, so those
# records are updated to the replayed state.
func _journal_replay(restored: Dictionary, lock: ExpeditionAssetLock) -> Dictionary:
	var decoded := Journal.decode(lock.journal, lock.checkpoint)
	if not decoded["ok"]: return decoded
	var host := restored["root"] as RunController
	for payload: Dictionary in decoded["payloads"]:
		var applied := _journal_apply(host, payload, true)
		if not applied["ok"]: return _fail(&"journal_replay_failed")
		for node: Node in applied["disabled"]:
			var stable: String = restored["entities"].stable_for(node.get_instance_id())
			if stable.is_empty() or not restored["snapshot"]["objects"].has(stable): continue
			var record: Dictionary = restored["snapshot"]["objects"][stable]
			if record.get("node") is Dictionary:
				record["node"]["mode"] = Node.PROCESS_MODE_DISABLED
				if record["node"].get("canvas") is Dictionary: record["node"]["canvas"]["visible"] = false
	return {"ok": true}

# The finite companion follows its dead owner, without rewards or affecting the
# required population. Keep tombstones for snapshot. Returns the disabled nodes;
# a held barrier keeps them disabled when it releases.
func _remove_dead_mob(host: RunController, actor: EnemyActor, barrier: SnapshotTickBarrier = null) -> Array[Node]:
	var disabled: Array[Node] = []
	for companion: CombatActor in host.enemies.duplicate():
		if companion is EnemyActor and companion.is_summoned and companion.summoner_id == actor.get_instance_id():
			host.enemies.erase(companion)
			if companion.world_motion != null: companion.world_motion.release()
			companion.health.current_hp = 0.0
			companion.health._death_emitted = true
			companion.hide()
			companion.process_mode = Node.PROCESS_MODE_DISABLED
			disabled.append(companion)
	host._world_pending_companions.erase(actor.get_instance_id())
	if actor.world_motion != null: actor.world_motion.release()
	host.enemies.erase(actor)
	actor.hide()
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	disabled.append(actor)
	if barrier != null:
		for node: Node in disabled: barrier.retain_mode(node, Node.PROCESS_MODE_DISABLED)
	return disabled

func _at_point(host: RunController, record: Dictionary) -> bool:
	var from := host.player.world_point()
	var target := ExpeditionPopulationPlanner.point(record)
	if from == null or from.stage_id != target.stage_id or from.position.distance_to(target.position) > 48.0: return false
	var world := host.player.world_motion.geometry
	var path := world.path(from, target, host.player.world_motion.profile(), world.geometry_revision)
	if not path["ok"]: return false
	var distance := 0.0
	var points: Array = path["data"]["points"]
	for index: int in range(1, points.size()): distance += points[index - 1]["position"].distance_to(points[index]["position"])
	return distance <= 48.0
