extends "res://tests/fixtures/e07/f4/suite.gd"
func _run() -> void:
	var f := make("alt_isolation")
	var facade: ProfileFacade = f["facade"]
	var host: RunController = f["controller"]
	var a := host.run_state.character_id
	var issued := host.reward_service.issue("original_source",&"fixture_reward")
	check(issued["ok"] and cut(f,"base")["ok"] and cut(f,"suspend",true)["ok"],"original character and uncollected ticket are durably suspended")
	var created := facade.create_character("create_alt",facade.current_profile().revision,"Outro",&"mage")
	check(created["ok"],"create independent alt")
	var b: String = created["character_id"]
	var profile := facade.current_profile()
	var owner_digest: String = profile.expeditions["fixture_expedition"].checkpoint["owner_digest"]
	var next_card := profile.card_inventory._next_counter
	var acquired := facade.grant_playtest_admin("alt_card",profile.revision,b,&"card",&"bulwark_card",{})
	check(acquired.get("ok",false),"alt can acquire a card while original is suspended: "+str(acquired.get("error_code")))
	if not acquired.get("ok",false): dispose(f); finish(); return
	var card: StringName = acquired["card_instance_id"]
	check(facade.current_profile().card_inventory._next_counter > next_card,"global ID counter still advances without reuse")
	check(ExpeditionCheckpointCodec.owner_digest(facade.current_profile(),a) == owner_digest,"another owner's card/counter/revision cannot invalidate frozen assets")
	var item := facade.grant_playtest_admin("alt_item",facade.current_profile().revision,b,&"equipment",&"traveler_charm",{})
	check(item["ok"],"alt equipment remains independent too")
	var piece: StringName = item.get("equipment_instance_id",&"")
	var reopened := ProfileFacade.new(ProfileStore.new(f["directory"],f["catalog"]))
	check(reopened.open_profile()["ok"],"reopen both owners' durable assets")
	var service := ExpeditionService.new(reopened)
	var resumed := service.resume("fixture_expedition",a,"resume",reopened.current_profile().revision)
	check(resumed.get("ok",false),"original resumes after alt acquisitions")
	if resumed.get("ok",false):
		var copy: RunController = resumed["root"]
		check(not copy.run_state.card_inventory.owns(card) and not copy.run_state.local_equipment_instances.has(piece),"restored runtime never receives alt's exemplars")
		check(copy.rng.state == host.rng.state and copy.player.attack_cooldown == host.player.attack_cooldown,"alt progress never advances the suspended simulation")
		check(resumed["registry"].install(resumed,root)["ok"] and resumed["registry"].activate(resumed)["ok"],"same graph installs normally")
		disable(copy)
		var barrier := SnapshotTickBarrier.new(); barrier.acquire(copy)
		var granted := service.collect(copy,barrier,issued["ticket_id"],"original_collect",reopened.current_profile().revision)
		check(granted.get("ok",false),"original material transaction merges into latest profile: "+str(granted.get("error_code")))
		check(reopened.current_profile().card_inventory.owner_of(card) == b and reopened.current_profile().equipment_instances[piece].owner_character_id == b,"original's commit preserves alt acquisitions and owners")
		check(copy.run_state.card_inventory._next_counter == reopened.current_profile().card_inventory._next_counter and not copy.run_state.card_inventory.owns(card),"runtime refresh retains unique global IDs with owner-only inventory")
		check(service.collect(copy,barrier,issued["ticket_id"],"original_collect",0).get("already_applied",false),"retry remains idempotent across owner progress")
		barrier.release(); copy.free()
	dispose(f)
	finish()
