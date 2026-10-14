extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func intent(controller: RunController,fields: Dictionary,id: String) -> Dictionary:
	var value := controller.build_service.context(); value.merge(fields,true);value["request_id"] = id
	return value
func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_playtest_fixes/cards_%d" % Time.get_ticks_usec())
	var catalog := ProfileCatalog.pilot()
	var store := F.FaultStore.new(directory,catalog)
	var facade := ProfileFacade.new(store,ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("create",0,"Cartas persistentes",&"swordsman")
	check(created["ok"],"create isolated real profile")
	if not created["ok"]: print(created); quit(1);return
	var first := facade.current_profile().selected_character_id
	check(facade.create_character("alt",facade.current_profile().revision,"Colecao compartilhada",&"swordsman")["ok"],"create alt sharing starter instance")
	var second := facade.current_profile().selected_character_id
	check(facade.select_character("select",facade.current_profile().revision,first)["ok"],"select first")
	var old := ProfileCodec.encode(facade.current_profile(),catalog)["data"] as Dictionary
	old.erase("card_inventory");old["schema_version"] = 4;old["catalog_version"] = 11
	var migrated := ProfileCodec.decode(JSON.stringify(old),catalog)
	check(migrated["ok"] and migrated["migrated"] and migrated["profile"].card_inventory.describe()["owned"].is_empty(),"schema4 migration does not invent old discarded cards")
	if migrated["ok"]:
		var output: Dictionary = ProfileCodec.encode(migrated["profile"],catalog)["data"]
		for key: String in ["equipment_instances","characters","settings","lifetime_stats"]: check(output[key] == old[key],"legacy payload preserved: "+key)
	var reserved := old.duplicate(true);reserved["card_inventory"] = {}
	check(not ProfileCodec.decode(JSON.stringify(reserved),catalog)["ok"],"old schema cannot smuggle new collection extension")
	var started := facade.start_run("start",facade.current_profile().revision)
	check(started["ok"],"start real persistent run")
	if not started["ok"]: print(started);quit(1);return
	RunController.pending_run_state = started["run_state"];RunController.pending_run_facade = facade;RunController.pending_gameplay_extension = false
	var controller := RunController.new();root.add_child(controller);controller.set_process(false);controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies: enemy.set_process(false)
	controller.encounter_active = false
	# Explicit stage-card fixture, not a claim about production drop chances.
	controller.reward_service._loot_resolver = null
	var ticket := controller.reward_service.issue("persistent-card-fixture",ProfileRewardResolver.pilot_encounter_reward_id(1),true)
	check(ticket["ok"] and not StringName(ticket.get("card_id",&"")).is_empty(),"actual issued useful-card ticket")
	if not ticket["ok"] or StringName(ticket.get("card_id",&"")).is_empty():print(ticket);controller.queue_free();quit(1);return
	var before := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	store.failure_stage = &"write_pending"
	check(not controller.reward_service.collect(ticket["ticket_id"])["ok"],"failed durable card collection")
	check(FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == before and facade.current_profile().card_inventory.describe()["owned"].is_empty() and controller.run_state.card_instances.is_empty(),"failure publishes neither save nor runtime card")
	store.failure_stage = &""
	var collected := controller.reward_service.collect(ticket["ticket_id"])
	check(collected["ok"],"retry commits same frozen card")
	if not collected["ok"]:print(collected);controller.queue_free();quit(1);return
	var owned: Array = facade.current_profile().card_inventory.describe()["owned"]
	check(owned.size()==1 and controller.run_state.card_instances.size()==1,"one permanent exemplar after collection")
	var card := StringName(owned[0]);var host := StringName(controller.run_state.build_snapshot.equipped[&"main_hand"])
	check(controller.reward_service.collect(ticket["ticket_id"])["already_applied"] and facade.current_profile().card_inventory.describe()["owned"].size()==1,"issued-ticket replay cannot duplicate card")
	controller.run_state.reset()
	check(controller.run_state.card_inventory.owns(card) and controller.run_state.augment_stacks.is_empty(),"reset clears augments only, copies permanent inventory")
	controller.run_state.augment_stacks[&"battle_rhythm"] = 1
	var proposal := controller.build_service.preview_change(intent(controller,{"kind":&"socket","equipment_instance_id":host,"socket_index":0,"card_instance_id":card},"socket"))
	check(proposal["ok"],"runtime preview of permanent socket")
	if proposal["ok"]:check(controller.build_service.commit_change(proposal["intent"])["ok"],"socket commits durably")
	check(facade.current_profile().card_inventory.sockets().get(host,[]).has(card),"socket is profile-owned")
	var unequip := controller.build_service.preview_change(intent(controller,{"kind":&"unequip","slot":&"main_hand"},"unequip"))
	check(unequip["ok"],"unequip preview")
	if unequip["ok"]:check(controller.build_service.commit_change(unequip["intent"])["ok"],"unequip commits")
	check(facade.current_profile().card_inventory.sockets().get(host,[]).has(card) and not controller.run_state.effect_state()["card_sockets"].has(host),"unequipped host keeps physical socket but has no active effect")
	var inventory := facade.current_profile().card_inventory.to_record()
	for outcome: StringName in [&"death",&"completed",&"abandoned"]:
		var active_run: String = controller.run_state.run_id if outcome==&"death" else facade.current_profile().reward_session["run_id"]
		check(facade.end_run("end_"+String(outcome),facade.current_profile().revision,active_run,outcome)["ok"],"close outcome "+String(outcome))
		check(facade.current_profile().card_inventory.to_record()==inventory,"permanent card/socket survives "+String(outcome))
		if outcome!=&"abandoned":check(facade.start_run("start_"+String(outcome),facade.current_profile().revision)["ok"],"new run retains permanent collection")
	controller.queue_free();await process_frame
	check(facade.select_character("select_alt",facade.current_profile().revision,second)["ok"],"alt selected")
	var alt_preview := facade.build_preview(second)
	check(alt_preview["ok"] and alt_preview["snapshot"].card_inventory.owns(card),"alt observes same collection")
	var active: Dictionary = alt_preview["snapshot"].card_inventory.active_sockets(alt_preview["snapshot"].equipped)
	check(active.get(host,[]).has(card),"alt/preset sharing physical host sees socket")
	var menu_intent := {"request_id":"menu_unsocket","profile_revision":facade.current_profile().revision,"kind":&"unsocket","equipment_instance_id":host,"socket_index":0}
	check(facade.preview_inventory_change(second,menu_intent)["ok"],"menu card preview")
	store.uncertain = true
	check(not facade.commit_inventory_change(second,menu_intent)["ok"],"uncertain menu commit cannot publish false success")
	store.hide_reads = false
	check(facade.commit_inventory_change(second,menu_intent)["ok"],"menu retry reconciles captured transaction")
	check(facade.current_profile().card_inventory.owns(card) and facade.current_profile().card_inventory.describe()["free"].has(card),"free removal preserves permanent item")
	var reopened := ProfileFacade.new(F.FaultStore.new(directory,catalog),ProfileRewardResolver.pilot_progression())
	check(reopened.open_profile()["ok"] and reopened.current_profile().card_inventory.to_record()==facade.current_profile().card_inventory.to_record(),"restart roundtrip preserves inventory and receipts")
	var encoded := ProfileCodec.encode(reopened.current_profile(),catalog)
	check(encoded["ok"] and encoded["data"]["schema_version"]==5 and encoded["data"]["catalog_version"]==12,"current schema/catalog real JSON")
	var raw: Dictionary = encoded["data"]
	for change: Dictionary in [{"next_counter":0},{"next_counter":1},{"revision":-1},{"instances":{"card_01":String(ticket["card_id"])}}]:
		var corrupt := raw.duplicate(true);corrupt["card_inventory"].merge(change,true)
		check(not ProfileCodec.decode(JSON.stringify(corrupt),catalog)["ok"],"bad identity/counter/revision rejected")
	var corrupt := raw.duplicate(true);corrupt["card_inventory"]["sockets"] = {"equipment_99999":[String(card)]}
	check(not ProfileCodec.decode(JSON.stringify(corrupt),catalog)["ok"],"orphan socket rejected")
	var changed := raw.duplicate(true);changed["card_inventory"]["grants"].values()[0]["definition_id"] = "missing_card"
	check(not ProfileCodec.decode(JSON.stringify(changed),catalog)["ok"],"altered durable receipt rejected")
	print("E06 permanent cards: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
