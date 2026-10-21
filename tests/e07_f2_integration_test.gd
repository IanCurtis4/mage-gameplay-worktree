extends "res://tests/fixtures/e07/f2/suite.gd"
func _run() -> void:
	var f := F.make("integration")
	var facade: ProfileFacade = f["facade"]
	var profile := facade.current_profile()
	var a: String = f["a"]; var b: String = f["b"]
	var started := facade.start_run("start", profile.revision)
	check(started["ok"], "production start_run creates owner projection")
	if not started["ok"]: finish(); return
	var state: RunState = started["run_state"]
	check(state.build_snapshot.equipment_instances.size() * 2 == profile.equipment_instances.size() and state.card_inventory.describe()["owned"].size() == 2, "run snapshot excludes alt equipment/cards")
	RunController.pending_run_state = state; RunController.pending_run_facade = facade
	var controller := RunController.new(); root.add_child(controller)
	controller.set_process(false); controller.player.set_process(false)
	for actor: CombatActor in controller.enemies: actor.set_process(false)
	controller.encounter_active = false
	var foreign := F.item(profile, b, &"starter_staff")
	var intent := controller.build_service.context()
	intent.merge({"kind": &"equip", "slot": &"main_hand", "equipment_instance_id": foreign, "request_id": "run_foreign"}, true)
	check(controller.build_service.preview_change(intent).get("error_code") == &"not_owner", "live build service denies foreign equipment")
	var own := F.item(profile, a, &"starter_staff")
	var own_card := F.card(profile, a, &"bulwark_card")
	intent = controller.build_service.context()
	intent.merge({"kind": &"socket", "equipment_instance_id": own, "card_instance_id": own_card, "socket_index": 0, "request_id": "run_socket"}, true)
	var preview := controller.build_service.preview_change(intent)
	check(preview["ok"], "owned card preview through real run service")
	if preview["ok"]:
		var result := controller.build_service.commit_change(preview["intent"])
		check(result["ok"], "owned socket commits through profile writer")
		check(facade.current_profile().card_inventory.describe()["owned"].size() == 4 and state.card_inventory.describe()["owned"].size() == 2, "run projection merge retains alt cards")
		check(facade.current_profile().card_inventory.owner_of(F.card(profile, b, &"echo_card")) == b, "alt ownership unchanged after socket commit")
	var view := BuildPresentation.describe(controller)
	check(view["ok"] and view["equipment"].size() == profile.equipment_for_character(a).size() and view["cards"].size() == 2, "real presentation DTO is owner-scoped")
	# Existing main admin refresh assigns global inventory; RunState setter must scope it.
	controller._refresh_admin_profile()
	check(state.card_inventory.describe()["owned"].size() == 2, "existing admin refresh cannot republish alt cards")
	profile = facade.current_profile()
	var payload := {"base_xp": 0, "job_xp": 0, "equipment_ids": [&"traveler_charm"], "card_id": &"echo_card", "stat_increments": {}}
	var reward := facade._grant_reward_payload("owner_loot", profile.revision, state.run_id, 1, &"fixture_reward", payload)
	check(reward["ok"], "frozen production reward payload committed")
	if reward["ok"]:
		profile = facade.current_profile()
		check(profile.equipment_instances[reward["equipment_instance_ids"][0]].owner_character_id == a and profile.card_inventory.owner_of(reward["card_instance_id"]) == a, "both loot types belong to run character")
		var retry := facade._grant_reward_payload("owner_loot", profile.revision, state.run_id, 1, &"fixture_reward", payload)
		check(retry.get("already_applied", false) and facade.current_profile().equipment_instances.size() == profile.equipment_instances.size(), "loot retry never duplicates exemplar")
	controller.reward_service = RunRewardService.new(controller)
	var issued := controller.reward_service.issue("owner_refresh", &"encounter_one", false)
	check(issued["ok"], "real reward ticket issued after preceding durable acquisition")
	if issued["ok"]:
		check(controller.reward_service.collect(issued["ticket_id"])["ok"], "real reward service collects through writer")
		check(state.local_equipment_instances.keys().all(func(id: StringName) -> bool: return facade.current_profile().equipment_instances[id].owner_character_id == a), "real loot refresh excludes alt equipment")
		check(state.card_inventory.describe()["owned"].all(func(id: StringName) -> bool: return facade.current_profile().card_inventory.owner_of(id) == a), "real loot refresh excludes alt cards")
	controller.free()
	check(facade.end_run("finish", facade.current_profile().revision, state.run_id, &"completed")["ok"], "legacy run lifecycle remains usable")
	var persistent_view := BuildPresentation.describe_profile(facade, b)
	check(persistent_view["ok"] and persistent_view["cards"].size() == 2, "lobby DTO uses same ownership authority")
	finish()
