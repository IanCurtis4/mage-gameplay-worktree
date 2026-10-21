extends "res://tests/fixtures/e07/f4/suite.gd"
func _run() -> void:
	var f := make("controller")
	var host: RunController = f["controller"]
	var facade: ProfileFacade = f["facade"]
	f["barrier"].release()
	paused = false
	var revision := facade.current_profile().revision
	var result: Dictionary = await host.request_durable_suspend("fixture_expedition",&"fixture_phase","controller_suspend",revision)
	check(result.get("ok",false) and result.get("durable",false) and paused,"async controller only confirms suspension after the tick cut and durable commit: "+str(result.get("error_code")))
	if not result.get("ok",false): host.release_memory_snapshot(); dispose(f); finish(); return
	check(host.snapshot_passive and not host.can_process(),"old host is retired after committed suspension")
	host.release_memory_snapshot()
	check(paused and not host.can_process(),"generic release cannot resurrect the suspended old world")
	var slot := facade.current_profile().expeditions["fixture_expedition"]
	var frozen := ExpeditionCheckpointCodec.unpack(slot.checkpoint)
	var service := ExpeditionService.new(facade)
	check(service.commit_cut(host,frozen["snapshot"],"fixture_expedition",&"fixture_phase","controller_suspend",revision,true).get("already_applied",false),"retry the identical frozen suspension with original revision is idempotent")
	check(service.commit_cut(host,frozen["snapshot"],"fixture_expedition",&"different_phase","controller_suspend",revision,true).get("error_code") == &"request_conflict","same request cannot replace phase")
	var before := facade.current_profile()
	var altered := before.copy_state()
	altered.expeditions["fixture_expedition"].receipts.clear()
	check((f["store"] as ProfileStore).commit(altered).get("error_code") == &"request_conflict","writer rejects receipt truncation")
	altered = before.copy_state(); altered.expeditions.erase("fixture_expedition")
	check((f["store"] as ProfileStore).commit(altered).get("error_code") == &"locked_by_expedition","writer rejects erasing suspended world")
	var resume := service.resume("fixture_expedition",host.run_state.character_id,"resume_controller",before.revision)
	check(resume.get("ok",false),"controller suspension restores through explicit resume")
	if resume.get("ok",false):
		host.release_memory_snapshot()
		check(host.snapshot_passive and not host.can_process(),"even after resume the retired source cannot reactivate")
		var copy: RunController = resume["root"]
		check(copy.player.attack_cooldown == host.player.attack_cooldown and copy.rng.state == host.rng.state,"async cut preserves the next clocks and RNG")
		copy.free()
	dispose(f)
	finish()
