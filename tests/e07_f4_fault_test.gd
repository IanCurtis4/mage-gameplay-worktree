extends "res://tests/fixtures/e07/f4/suite.gd"
func _run() -> void:
	for stage: StringName in [&"write_pending",&"validate_pending",&"backup",&"replace",&"after_replace",&"lost_ack",&"before_unknown"]:
		var f := make("fault_"+String(stage))
		var facade: ProfileFacade = f["facade"]
		var store: F.FaultStore = f["store"]
		var host: RunController = f["controller"]
		var service: ExpeditionService = f["service"]
		check(cut(f,"base")["ok"],"known durable base "+String(stage))
		var issued := host.reward_service.issue("source",&"fixture_reward")
		var ticket: String = issued["ticket_id"]
		check(cut(f,"issued")["ok"],"emitted ticket persisted "+String(stage))
		var before := facade.current_profile()
		var bytes := F.disk(f)
		var choice_count := host.run_state.pending_choices
		if stage == &"lost_ack": store.uncertain = true
		elif stage == &"before_unknown": store.uncertain_before_write = true
		else: store.failure_stage = stage
		var result := service.collect(host,f["barrier"],ticket,"collect_fault",before.revision)
		if stage in [&"lost_ack",&"before_unknown"]:
			check(not result["ok"] and result.get("read_only",false),"uncertain outcome freezes "+String(stage))
			check(not host.reward_service.ticket(ticket)["delivered"] and host.run_state.pending_choices == choice_count,"uncertain result never publishes material/world")
			check(service.checkpoint(host,f["barrier"],"fixture_expedition",&"fixture_phase","different",before.revision).get("error_code") == &"recovery_required","commands blocked pending reconciliation")
			store.hide_reads = false
			var reconciled := service.reconcile("collect_fault")
			if stage == &"lost_ack": check(reconciled["ok"] and host.reward_service.ticket(ticket)["delivered"],"after-rename reconciliation publishes once")
			else: check(not reconciled["ok"] and not reconciled.get("read_only",false) and F.disk(f) == bytes,"known no-write reconciliation preserves before")
		elif stage == &"after_replace":
			check(result["ok"] and result.get("recovered_after_uncertain_result",false),"lost acknowledgment reconciles canonical primary")
		else:
			check(not result["ok"] and F.disk(f) == bytes and not host.reward_service.ticket(ticket)["delivered"],"known failure preserves prior world/assets "+String(stage))
		store.failure_stage = &""
		if not host.reward_service.ticket(ticket)["delivered"]:
			var retried := service.collect(host,f["barrier"],ticket,"collect_fault",facade.current_profile().revision)
			check(retried["ok"],"same ticket retries frozen payload "+String(stage)+": "+str(retried.get("error_code")))
		var current := facade.current_profile()
		check(current.reward_session["last_committed_seq"] == 1 and current.equipment_instances.size() == before.equipment_instances.size()+issued["payload"]["equipment_drops"].size() and host.run_state.pending_choices == choice_count+1,"exactly one receipt/item/choice "+String(stage))
		var opened := ProfileFacade.new(ProfileStore.new(f["directory"],f["catalog"]))
		check(opened.open_profile()["ok"],"restart after failure resolves complete durable cut")
		dispose(f)
	finish()
