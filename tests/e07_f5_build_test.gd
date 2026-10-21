extends "res://tests/fixtures/e07/f5/suite.gd"
func proposal(host: RunController, fields: Dictionary, request: String) -> Dictionary:
	var intent := host.build_service.context()
	intent.merge(fields, true)
	intent["request_id"] = request
	return host.build_service.preview_change(intent)
func _run() -> void:
	var f := make("build", true)
	if not enter(f)["ok"]: dispose(f); finish_test(); return
	var host: RunController = f["controller"]
	# The inventory UI uses a paused tree. Release the fixture barrier so the
	# actual build consumer can acquire its own cut with the original modes.
	f["barrier"].release()
	var weapon: StringName = host.run_state.build_snapshot.equipped[&"main_hand"]
	var card: StringName = host.run_state.card_inventory.describe()["owned"][0]
	host.player.health.current_hp -= 7.0
	host.player.current_sp -= 3.0
	host.player.mage_cooldowns[&"fireball"] = 9.5
	var deficits := [host.player.health.hp_deficit(), host.player.sp_deficit()]
	var before := FileAccess.get_file_as_string(f["directory"].path_join("profile.json"))
	var preview := proposal(host, {"kind": &"socket", "equipment_instance_id": weapon, "socket_index": 0, "card_instance_id": card}, "socket")
	check(preview["ok"], "active owner can preview real card composition")
	check(before == FileAccess.get_file_as_string(f["directory"].path_join("profile.json")) and host.run_state.card_inventory.sockets().is_empty(), "preview has no durable or runtime mutation")
	if not preview["ok"]: print(preview); dispose(f); finish_test(); return
	var store: Fault.FaultStore = f["store"]
	store.failure_stage = &"write_pending"
	var result := host.build_service.commit_change(preview["intent"])
	check(not result["ok"] and before == FileAccess.get_file_as_string(f["directory"].path_join("profile.json")) and host.run_state.card_inventory.sockets().is_empty(), "known failure publishes neither socket nor checkpoint")
	store.failure_stage = &""
	result = host.build_service.commit_change(preview["intent"])
	check(result["ok"], "retry commits profile, build and world together: " + str(result.get("error_code")))
	if not result["ok"]: print(result); dispose(f); finish_test(); return
	check(host.run_state.card_inventory.sockets()[weapon][0] == card and f["facade"].current_profile().card_inventory.sockets()[weapon][0] == card, "published runtime and profile agree on owned socket")
	check([host.player.health.hp_deficit(), host.player.sp_deficit()] == deficits and host.player.mage_cooldowns[&"fireball"] == 9.5, "swap preserves deficits and paid cooldowns")
	check(host.build_service.commit_change(preview["intent"])["error_code"] == &"replayed_request", "retry cannot apply a second build revision")
	host.combat_participation.hostile_damage()
	check(proposal(host, {"kind": &"unequip", "slot": &"main_hand"}, "combat")["error_code"] == &"encounter_active", "hostile damage blocks swap immediately without waiting for another frame")
	host.combat_participation.observe({}, 5.0, false)
	check(not host.encounter_active, "real five-second grace releases build consumer")
	preview = proposal(host, {"kind": &"unequip", "slot": &"main_hand"}, "uncertain_build")
	check(preview["ok"], "out-of-combat unequip preview")
	if not preview["ok"]: print(preview); dispose(f); finish_test(); return
	store.uncertain = true
	result = host.build_service.commit_change(preview["intent"])
	check(not result["ok"] and result.get("read_only", false) and host.inventory_frozen and host.run_state.build_snapshot.equipped[&"main_hand"] == weapon, "lost acknowledgment freezes old runtime until reconciliation")
	store.hide_reads = false
	result = host.build_service.reconcile_change("uncertain_build")
	check(result["ok"] and not host.inventory_frozen and host.run_state.build_snapshot.equipped[&"main_hand"] == null, "reconciliation publishes exact build once")
	check([host.player.health.hp_deficit(), host.player.sp_deficit()] == deficits and host.player.mage_cooldowns[&"fireball"] == 9.5, "reconciliation cannot heal or reset cooldowns")
	var facade := ProfileFacade.new(store)
	check(facade.open_profile()["ok"], "restart reads transactional build checkpoint")
	var resumed := ExpeditionService.new(facade).resume("f5_expedition", host.run_state.character_id, "restart_build", facade.current_profile().revision)
	check(resumed["ok"], "restart restores post-build world")
	if resumed["ok"]:
		var restored: RunController = resumed["root"]
		check(restored.run_state.build_snapshot.equipped[&"main_hand"] == null and restored.run_state.card_inventory.sockets()[weapon][0] == card and restored.player.mage_cooldowns[&"fireball"] == 9.5, "restart preserves layout, socket and cooldown in one cut")
		check(facade.run_mutation_status("wrong_run", restored.run_state.character_id, restored)["error_code"] == &"invalid_session", "active exception cannot cross sessions")
		var barrier := SnapshotTickBarrier.new()
		barrier.acquire(restored)
		var suspended := ExpeditionService.new(facade).checkpoint(restored, barrier, "f5_expedition", &"f5_fixture_phase", "suspend_build", facade.current_profile().revision, true)
		barrier.release()
		check(suspended["ok"], "suspend post-build world")
		check(proposal(restored, {"kind": &"equip", "slot": &"main_hand", "equipment_instance_id": weapon}, "suspended_swap")["error_code"] == &"locked_by_expedition", "suspended owner cannot use active swap exception")
		restored.free()
	check(facade.run_mutation_status(host.run_state.run_id, host.run_state.character_id)["error_code"] == &"locked_by_expedition", "lobby cannot use the active build exception")
	dispose(f)
	finish_test()
