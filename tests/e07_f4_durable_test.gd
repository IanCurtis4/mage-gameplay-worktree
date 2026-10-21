extends "res://tests/fixtures/e07/f4/suite.gd"
func _run() -> void:
	var f := make("durable")
	var host: RunController = f["controller"]
	var facade: ProfileFacade = f["facade"]
	var service: ExpeditionService = f["service"]
	var created := cut(f,"first_cut")
	check(created.get("ok",false) and created.get("durable",false),"first full graph is durable: "+str(created.get("error_code")))
	if not created.get("ok",false): dispose(f); finish(); return
	var issued := host.reward_service.issue("dead_mob_source",&"fixture_reward")
	check(issued.get("ok",false),"real service mints a frozen ticket: "+str(issued.get("error_code")))
	var ticket: String = issued.get("ticket_id","")
	check(cut(f,"issued_cut")["ok"],"world and emitted uncollected source become durable together")
	var before := facade.current_profile()
	var count := before.equipment_instances.size()
	var choices := host.run_state.pending_choices
	var observer := preload("res://tests/fixtures/e07/f4/observer.gd").new()
	observer.facade = facade
	root.add_child(observer)
	host.reward_service.reward_confirmed.connect(observer.confirmed)
	check(host.reward_service.collect(ticket).get("error_code") == &"checkpoint_required","legacy collector cannot split assets from expedition world")
	var collected := service.collect(host,f["barrier"],ticket,"collect_once",before.revision)
	check(collected.get("ok",false),"material and world commit atomically: "+str(collected.get("error_code")))
	if not collected.get("ok",false): dispose(f); finish(); return
	check(observer.events == 1 and host.reward_service.ticket(ticket)["delivered"],"publish only after durable claim, once")
	check(collected.get("acquisition",{}).get("base_xp") == 100 and host.acquisition_journal.totals()["base_xp"] == 100 and host.acquisition_journal.totals()["equipment"] == 1,"existing journal receives complete confirmed acquisition payload")
	check(host.run_state.pending_choices == choices+1 and facade.current_profile().equipment_instances.size() == count+issued["payload"]["equipment_drops"].size(),"exact item and augment grant")
	check(service.collect(host,f["barrier"],ticket,"collect_once",before.revision).get("already_applied",false) and observer.events == 1,"retry with original revision grants nothing twice")
	check(service.collect(host,f["barrier"],ticket,"first_cut",facade.current_profile().revision).get("error_code") == &"request_conflict","request ID cannot change operation")
	check(cut(f,"suspend",true)["ok"] and facade.current_profile().reward_session == null,"suspension frees the active session but retains the expedition")
	var state := facade.current_profile()
	var a: String = state.characters[0].character_id
	check(facade.commit_assets(a,{"kind":"spend_gold","amount":1},"locked",state.revision).get("error_code") == &"locked_by_expedition","lobby mutations stay locked")
	var new_alt := facade.create_character("alt",state.revision,"Outro",&"archer")
	check(new_alt.get("ok",false),"alt remains free while original is suspended")
	var alt: String = new_alt.get("character_id","")
	check(facade.commit_assets(alt,{"kind":"credit_gold","amount":7},"alt_gold",facade.current_profile().revision)["ok"],"alt wallet advances profile independently")
	check(service.resume("fixture_expedition",alt,"wrong_owner",facade.current_profile().revision).get("error_code") == &"not_owner","cannot resume another character's expedition")
	var reopened := ProfileFacade.new(ProfileStore.new(f["directory"],f["catalog"]))
	var opened := reopened.open_profile()
	check(opened["ok"] and not opened.get("abandoned_run_closed",false),"new facade sees suspended graph without abandonment")
	var resumed := ExpeditionService.new(reopened).resume("fixture_expedition",a,"resume",reopened.current_profile().revision)
	check(resumed.get("ok",false),"resume after alt revisions uses owner binding: "+str(resumed.get("error_code")))
	if resumed.get("ok",false):
		var copy: RunController = resumed["root"]
		check(copy.run_state.pending_choices == choices+1 and copy.reward_service.ticket(ticket)["delivered"],"restart retains delivered ticket and choice")
		check(copy.player.health._hp_deficit == 3.25 and copy.player._sp_deficit == 2.75 and copy.player.attack_cooldown == 0.375,"no healing or offline cooldown advancement")
		check(copy.rng.state == host.rng.state and copy.reward_service.ticket(ticket)["payload"] == issued["payload"],"RNG and payload survive binary envelope")
		check(copy.process_mode == Node.PROCESS_MODE_DISABLED and copy.snapshot_passive,"resume returns passive graph for explicit installation")
		check(resumed["registry"].install(resumed,root)["ok"] and resumed["registry"].activate(resumed)["ok"],"restored graph installs and activates using F3")
		disable(copy)
		check(host.run_state.open_offer(false,host.rng)["ok"] and copy.run_state.open_offer(false,copy.rng)["ok"],"next real augment offers execute after disk resume")
		check(host.run_state.offer_token() == copy.run_state.offer_token() and host.run_state.current_offer.map(func(item: AugmentDefinition) -> StringName: return item.id) == copy.run_state.current_offer.map(func(item: AugmentDefinition) -> StringName: return item.id) and host.rng.state == copy.rng.state,"next offer identity/payload/RNG equal uninterrupted graph")
		var restart := ProfileFacade.new(ProfileStore.new(f["directory"],f["catalog"]))
		check(restart.open_profile().get("expedition_resume_available",false) and restart.current_profile().reward_session != null,"active checkpoint survives reopening without legacy abandonment")
		check(restart.end_run("legacy_close",restart.current_profile().revision,copy.run_state.run_id,&"abandoned").get("error_code") == &"locked_by_expedition","legacy end_run cannot erase expedition")
		copy.free()
	check(observer.saw_durable_cursor,"callback observes durable receipt cursor")
	observer.free()
	dispose(f)
	finish()
