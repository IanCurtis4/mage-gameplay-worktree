extends SceneTree
const F = preload("res://tests/e06_tx_fixture.gd")
func _initialize() -> void: run.call_deferred()
func need(ok: bool,label: String) -> void:
	if not ok: push_error(label); quit(1)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var directory := args[1]
	var store := F.FaultStore.new(directory,F.profile_catalog())
	var facade := ProfileFacade.new(store,ProfileRewardResolver.new({&"fixture_reward":{"base_xp":100,"job_xp":80,"equipment_ids":[&"traveler_charm"]}}))
	var host: RunController
	var service := ExpeditionService.new(facade)
	if phase == "write":
		need(facade.create_character("create",0,"Reinício",&"mage")["ok"],"worker creates isolated character")
		var started := facade.start_run("start",facade.current_profile().revision)
		need(started["ok"],"worker starts real run")
		RunController.pending_run_state = started["run_state"]
		RunController.pending_run_facade = facade
		host = RunController.new(); root.add_child(host)
		host.encounter_active = false
		host.player.health._hp_deficit = 3.25
		host.player.attack_cooldown = 0.375
		host.rng.seed = 77213
		var issued := host.reward_service.issue("persistent_source",&"fixture_reward")
		need(issued["ok"],"worker freezes ticket: "+str(issued.get("error_code")))
		if not issued["ok"]: return
		paused = true
		var barrier := SnapshotTickBarrier.new(); barrier.acquire(host)
		need(service.checkpoint(host,barrier,"restart_expedition",&"fixture_phase","write",facade.current_profile().revision)["ok"],"worker commits entire graph")
		var expected := {"ticket":issued["ticket_id"],"rng":str(host.rng.state),"character":host.run_state.character_id,"payload":MigrationPlan.canonical(issued["payload"]),"choices":host.run_state.pending_choices}
		var file := FileAccess.open(directory.path_join("test_expectations.json"),FileAccess.WRITE); file.store_string(JSON.stringify(expected)); file.close()
		# Deliberately leave an uncommitted pending candidate at a crash boundary.
		store.failure_stage = &"replace"
		var next := facade.current_profile(); next.settings["uncommitted_fixture"] = true
		need(not store.commit(next)["ok"] and store.has_pending_transaction(),"worker stops before rename with evidence intact")
		barrier.release(); host.free()
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("test_expectations.json")))
		if phase == "recover":
			need(facade.open_profile().get("error_code") == &"recovery_required","fresh process blocks uncommitted pending")
			need(facade.recover_expedition_pending().get("uncommitted_checkpoint_archived",false),"fresh writer preserves uncommitted candidate before rollback")
			need(not facade.current_profile().settings.has("uncommitted_fixture"),"only durable primary state is published")
		else: need(facade.open_profile()["ok"],"third process opens durable material checkpoint")
		var resumed := service.resume("restart_expedition",expected["character"],"resume_"+phase,facade.current_profile().revision)
		need(resumed.get("ok",false),"worker restores cross-process graph: "+str(resumed.get("error_code")))
		if not resumed.get("ok",false): quit(1); return
		host = resumed["root"]
		need(host.player.health._hp_deficit == 3.25 and host.player.attack_cooldown == 0.375 and str(host.rng.state) == expected["rng"],"cross-process clocks/resources/RNG exact")
		var ticket: String = expected["ticket"]
		need(MigrationPlan.canonical(host.reward_service.ticket(ticket)["payload"]) == expected["payload"],"cross-process ticket never rerolls")
		if phase == "recover":
			# F3 activation must release hydration ownership before another capture.
			need(resumed["registry"].install(resumed,root)["ok"] and resumed["registry"].activate(resumed)["ok"],"passive graph is installed only after committed resume")
			paused = true
			var barrier := SnapshotTickBarrier.new(); barrier.acquire(host)
			var grant := service.collect(host,barrier,ticket,"collect",facade.current_profile().revision)
			need(grant.get("ok",false),"second process commits material/world: "+str(grant.get("error_code")))
			barrier.release()
		else:
			need(host.reward_service.ticket(ticket)["delivered"] and host.run_state.pending_choices == int(expected["choices"])+1 and facade.current_profile().reward_session["last_committed_seq"] == 1,"third process sees one collected receipt/choice")
		host.free()
	print("E07 F4 restart worker PASS "+phase)
	quit(0)
