extends "res://tests/fixtures/e07/f4/suite.gd"
## The writer is real; only its documented fault points are injected.
class ProbeService:
	extends ExpeditionService
	var restores := 0
	var last_root: WeakRef
	func _restore(lock: ExpeditionAssetLock, prepared: Dictionary = {}) -> Dictionary:
		restores += 1
		var result := super._restore(lock,prepared)
		if result.get("ok",false): last_root = weakref(result.root)
		return result

func _run() -> void:
	for stage: StringName in [&"success",&"write_pending",&"validate_pending",&"backup",&"replace",&"after_replace",&"lost_ack",&"before_unknown"]:
		var f := make("resume_staging_"+String(stage))
		check(cut(f,"suspend",true).get("ok",false),"suspended durable base "+String(stage))
		var facade: ProfileFacade = f.facade
		var store: F.FaultStore = f.store
		var service := ProbeService.new(facade)
		var profile := facade.current_profile()
		var character: String = profile.characters[0].character_id
		var before_bytes := F.disk(f)
		check(service.resume("fixture_expedition","wrong_owner","wrong",profile.revision).get("error_code") == &"not_owner" and service.restores == 0,"owner rejected before allocation "+String(stage))
		check(service.resume("fixture_expedition",character,"stale",profile.revision-1).get("error_code") == &"stale_revision" and service.restores == 0,"revision rejected before allocation "+String(stage))
		if stage == &"lost_ack": store.uncertain = true
		elif stage == &"before_unknown": store.uncertain_before_write = true
		elif stage != &"success": store.failure_stage = stage
		var result := service.resume("fixture_expedition",character,"resume",profile.revision)
		check(service.restores == 1,"one precommit reconstruction "+String(stage))
		if stage in [&"lost_ack",&"before_unknown"]:
			var staged: RunController = service.last_root.get_ref()
			check(not result.get("ok",false) and result.get("read_only",false) and not result.has("root"),"uncertainty publishes no world "+String(stage))
			check(is_instance_valid(staged) and not staged.is_inside_tree() and staged.snapshot_passive and staged.process_mode == Node.PROCESS_MODE_DISABLED,"uncertain world stays detached and disabled "+String(stage))
			check(service.resume("fixture_expedition",character,"other",profile.revision).get("error_code") == &"recovery_required" and service.restores == 1,"pending write blocks another allocation "+String(stage))
			store.hide_reads = false
			result = service.reconcile("resume")
			check(service.restores == 1,"reconcile never rebuilds "+String(stage))
			if stage == &"lost_ack":
				check(result.get("ok",false) and result.get("root") == staged,"confirmed write returns the exact staged world")
			else:
				check(not result.get("ok",false) and not result.get("read_only",false) and not is_instance_valid(staged) and F.disk(f) == before_bytes,"confirmed no-write frees staged world and preserves bytes")
		elif stage not in [&"success",&"after_replace"]:
			check(not result.get("ok",false) and service.last_root.get_ref() == null and F.disk(f) == before_bytes,"definitive failure frees staged world and preserves bytes "+String(stage))
		if not result.get("ok",false):
			store.failure_stage = &""
			result = service.resume("fixture_expedition",character,"resume",facade.current_profile().revision)
			check(result.get("ok",false) and service.restores == 2,"same request retries after definitive failure "+String(stage))
		if result.get("ok",false):
			var host: RunController = result.root
			var authority: Dictionary = result.snapshot.authority
			var committed := facade.current_profile()
			check(host == service.last_root.get_ref() and not host.is_inside_tree() and host.snapshot_passive and host.process_mode == Node.PROCESS_MODE_DISABLED,"success still requires explicit installation "+String(stage))
			check(authority.revision == committed.revision and authority.reward_session == committed.reward_session and authority.profile_id == committed.profile_id,"confirmed external authority is rebound "+String(stage))
			check(host.player.health._hp_deficit == 3.25 and host.player._sp_deficit == 2.75 and host.rng.state == f.controller.rng.state,"resume preserves health resources and RNG "+String(stage))
			var durable_bytes := F.disk(f)
			var replay := service.resume("fixture_expedition",character,"resume",profile.revision)
			check(replay.get("ok",false) and replay.get("already_applied",false) and replay.root != host and F.disk(f) == durable_bytes,"confirmed retry reconstructs without another write "+String(stage))
			if replay.get("ok",false): replay.root.free()
			host.free()
		dispose(f)
	finish()
