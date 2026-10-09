extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var fixture := F.make(self, "inventory")
	var c: RunController = fixture["controller"]
	var facade: ProfileFacade = fixture["facade"]
	var state := c.run_state
	var before := facade.current_profile()
	var disk := F.disk(fixture)
	var intent := F.intent(c, &"equip", {"slot": &"armor", "item_id": &"warden_mail"})
	var preview := c.build_service.preview_change(intent)
	_check(preview["ok"] and F.disk(fixture) == disk and state.build_snapshot.equipped[&"armor"] == &"traveler_vest", "preview is pure on profile runtime and disk")
	var forged := facade.equip_between_encounters(intent["request_id"], before.revision, c, preview["intent"])
	_check(not forged["ok"] and F.disk(fixture) == disk, "facade requires active service commit, not UI-provided controller alone")
	var versions := c.build_service.context()
	c.player.health.current_hp -= 20.0
	_check(c.build_service.commit_change(preview["intent"])["error_code"] == &"stale_resources", "health changed after preview rejects stale resource stamp")
	preview = c.build_service.preview_change(intent)
	var emission := c.player._make_magic_request(null, &"fire_spear", 22.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	var captured := emission.copy()
	var committed := c.build_service.commit_change(preview["intent"])
	_check(committed["ok"] and state.runtime_revision == versions["runtime_revision"] + 1 and state.build_snapshot.build_version == versions["build_version"] + 1, "confirmed change publishes revisions once")
	_check(c.player.stat_breakdown.values() == preview["after"] and is_equal_approx(c.player.health.current_hp, preview["hp_after"]), "preview equals published canonical stats and HP")
	_check(emission.magic_damage == captured.magic_damage and emission.effect_snapshot == captured.effect_snapshot, "captured emission unaffected by equipment update")
	var after := facade.current_profile()
	var old := before.characters[0]
	var changed := after.characters[0]
	_check(changed.equipped[&"armor"] == &"warden_mail" and changed.presets[changed.selected_preset]["equipped"] == changed.equipped and changed.presets[1] == old.presets[1], "equipped and selected preset update atomically, other preset intact")
	_check(changed.base_xp_total == old.base_xp_total and changed.job_xp_total == old.job_xp_total and changed.attribute_allocations == old.attribute_allocations and changed.purchased_skill_ranks == old.purchased_skill_ranks and changed.action_slots == old.action_slots and changed.action_slots.size() == 24, "XP allocations ranks and actions24 preserved")
	_check(after.characters[1].equipped == before.characters[1].equipped and after.characters[1].presets == before.characters[1].presets, "alt build remains independent")
	disk = F.disk(fixture)
	_check(c.build_service.commit_change(preview["intent"])["error_code"] == &"replayed_request" and F.disk(fixture) == disk, "replayed commit preserves disk and runtime")
	_check(not F.change(c, &"equip", {"slot": &"weapon", "item_id": &"starter_blade"})["ok"], "wrong origin rejected")
	_check(not F.change(c, &"equip", {"slot": &"armor", "item_id": &"starter_staff"})["ok"], "wrong slot rejected")
	_check(F.change(c, &"equip", {"slot": &"accessory", "item_id": &"unknown"})["error_code"] == &"item_not_owned", "unowned item rejected")
	c.encounter_active = true
	intent = F.intent(c, &"unequip", {"slot": &"armor", "encounter_active": false})
	_check(c.build_service.preview_change(intent)["error_code"] == &"encounter_active", "UI boolean never authorizes encounter change")
	c.encounter_active = false
	state.queue_choice()
	var offer := state.open_offer(false, c.rng)
	_check(offer["ok"] and F.change(c, &"unequip", {"slot": &"armor"})["error_code"] == &"offer_open", "offer lock survives invisible UI")
	_check(state.confirm_offer(offer, offer["ids"][0], false)["ok"], "offer resolves through T1 token")
	c.player.apply_run_modifiers(state)
	state.queue_choice()
	_check(F.change(c, &"unequip", {"slot": &"armor"})["ok"], "pending unopened choice permits equipment change")
	var cards := state.card_inventory
	for id: StringName in [&"echo_card", &"ember_card", &"bulwark_card"]:
		_check(cards.grant(id, state.effect_catalog())["ok"], "fixture card acquired once")
	_check(cards.grant(&"echo_card", state.effect_catalog())["already_applied"] and cards.describe()["owned"].size() == 3, "duplicate card grant cannot duplicate ownership")
	_check(F.change(c, &"equip", {"slot": &"armor", "item_id": &"traveler_vest"})["ok"], "armor restored")
	disk = F.disk(fixture)
	_check(F.change(c, &"socket", {"item_id": &"starter_staff", "card_id": &"echo_card"})["ok"], "free card sockets on equipped item")
	_check(state.projectile_count(&"fire_spear") == 2 and F.disk(fixture) == disk, "card transforms skill through T1 and never saves")
	var unchanged := state.card_inventory.describe()
	_check(F.change(c, &"socket", {"item_id": &"traveler_vest", "card_id": &"ember_card"})["error_code"] == &"effect_conflict" and state.card_inventory.describe() == unchanged, "cross-card conflict rejects whole change")
	_check(F.change(c, &"equip", {"slot": &"weapon", "item_id": &"ember_staff"})["ok"], "unequipping card host returns card before composition")
	_check(state.card_inventory.describe()["free"].has(&"echo_card") and state.projectile_count(&"fire_spear") == 2, "new item transformation remains and removed card is free")
	_check(F.change(c, &"socket", {"item_id": &"traveler_vest", "card_id": &"echo_card"})["error_code"] == &"effect_conflict", "equipment/card exclusive conflict rejects")
	_check(F.change(c, &"equip", {"slot": &"weapon", "item_id": &"starter_staff"})["ok"], "conflicting equipment removable")
	_check(F.change(c, &"socket", {"item_id": &"starter_staff", "card_id": &"echo_card"})["ok"], "card can be reused without another draw")
	_check(F.change(c, &"transfer", {"from_item_id": &"starter_staff", "item_id": &"traveler_vest", "card_id": &"echo_card"})["ok"], "atomic transfer moves one card")
	_check(state.card_inventory.sockets() == {&"traveler_vest": &"echo_card"}, "transfer leaves exactly one host")
	_check(F.change(c, &"unsocket", {"item_id": &"traveler_vest"})["ok"] and state.card_inventory.describe()["free"].has(&"echo_card"), "unsocket returns ownership to free inventory")
	var dto := BuildPresentation.describe(c)
	dto["equipped"][&"weapon"] = null
	dto["inventory"]["owned"].clear()
	_check(state.build_snapshot.equipped[&"weapon"] == &"starter_staff" and state.card_inventory.describe()["owned"].size() == 3, "presentation DTO mutation does not leak")
	state.reset()
	_check(state.card_inventory.describe()["owned"].is_empty() and state.card_sockets.is_empty() and state.augment_stacks.is_empty(), "reset discards all transient ownership and effects")
	c.free()
	await _failures()
	await _adversarial()
	await _uncommitted()
	print("E06 inventory: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _failures() -> void:
	for stage: StringName in [&"write_pending", &"validate_pending", &"backup", &"replace", &"uncertain"]:
		var fixture := F.make(self, "save_" + String(stage))
		var c: RunController = fixture["controller"]
		var store: F.FaultStore = fixture["store"]
		var facade: ProfileFacade = fixture["facade"]
		var disk := F.disk(fixture)
		var before := c.build_service.context()
		var hp := c.player.health.current_hp
		var preview := c.build_service.preview_change(F.intent(c, &"equip", {"slot": &"armor", "item_id": &"warden_mail"}))
		if stage == &"uncertain": store.uncertain = true
		else: store.failure_stage = stage
		var result := c.build_service.commit_change(preview["intent"])
		_check(not result["ok"] and c.run_state.build_snapshot.equipped[&"armor"] == &"traveler_vest" and c.player.health.current_hp == hp and c.run_state.runtime_revision == before["runtime_revision"], "failed or uncertain save never publishes runtime: " + String(stage))
		if stage != &"uncertain":
			_check(F.disk(fixture) == disk and facade.current_profile().revision == before["profile_revision"], "definite failure preserves profile and primary: " + String(stage))
			store.failure_stage = &""
			result = c.build_service.commit_change(preview["intent"])
		else:
			_check(c.inventory_frozen and paused and not c.run_state.can_open_choice(false), "uncertain save freezes run and offers")
			_check(facade.open_profile()["error_code"] == &"result_uncertain", "live transaction cannot be discarded by generic reload")
			var other: Dictionary = preview["intent"].duplicate(true)
			other["item_id"] = &"trailcoat"
			_check(c.build_service.commit_change(other)["error_code"] == &"result_uncertain", "uncertain payload cannot be replaced")
			store.hide_reads = false
			result = c.build_service.commit_change(preview["intent"])
		_check(result["ok"] and c.run_state.build_snapshot.equipped[&"armor"] == &"warden_mail" and c.run_state.runtime_revision == before["runtime_revision"] + 1, "same request retry/reconcile publishes once: " + String(stage))
		_check(facade.current_profile().revision == before["profile_revision"] + 1 and not c.inventory_frozen, "one persistent revision, frozen state resolved")
		c.free()
		paused = false
		await process_frame

func _adversarial() -> void:
	var fixture := F.make(self, "adversarial")
	var c: RunController = fixture["controller"]
	var facade: ProfileFacade = fixture["facade"]
	var store: F.FaultStore = fixture["store"]
	var preview := c.build_service.preview_change(F.intent(c, &"equip", {"slot": &"armor", "item_id": &"warden_mail"}))
	var stale: Dictionary = preview["intent"].duplicate(true)
	stale["profile_revision"] -= 1
	_check(c.build_service.commit_change(stale)["error_code"] == &"stale_revision", "stale persistent revision cannot commit")
	var malformed := F.intent(c, &"equip", {"item_id": {"spoof": true}})
	_check(c.build_service.preview_change(malformed)["error_code"] == &"invalid_intent", "malformed intent is rejected without conversion exception")
	var reentrant: Array[Dictionary] = []
	store.callback = func() -> void:
		reentrant.append(c.build_service.commit_change(preview["intent"]))
		reentrant.append(facade.update_action_slots("nested-layout", facade.current_profile().revision, c.run_state.character_id, c.run_state.build_snapshot.action_slots))
	var before := facade.current_profile().revision
	_check(c.build_service.commit_change(preview["intent"])["ok"] and facade.current_profile().revision == before + 1, "reentrant callback cannot create second persistent commit")
	_check(reentrant.size() == 2 and reentrant[0]["error_code"] == &"save_in_progress" and reentrant[1]["error_code"] == &"save_in_progress", "service and facade both reject nested writers")
	var cards := c.run_state.card_inventory
	cards.grant(&"bulwark_card", c.run_state.effect_catalog())
	cards.grant(&"trail_card", c.run_state.effect_catalog())
	_check(F.change(c, &"socket", {"item_id": &"starter_staff", "card_id": &"bulwark_card"})["ok"] and F.change(c, &"socket", {"item_id": &"warden_mail", "card_id": &"trail_card"})["ok"], "two independent card hosts")
	var sockets := c.run_state.card_inventory.sockets()
	_check(F.change(c, &"transfer", {"from_item_id": &"starter_staff", "item_id": &"warden_mail", "card_id": &"bulwark_card"})["error_code"] == &"socket_occupied" and c.run_state.card_inventory.sockets() == sockets, "occupied target rejects atomic transfer and preserves both hosts")
	var actual_id := c.run_state.character_id
	c.run_state.character_id = "spoof-character"
	_check(F.change(c, &"unequip", {"slot": &"armor"})["error_code"] == &"invalid_session", "session ownership revalidated against persistent authority")
	c.run_state.character_id = actual_id
	c.player.health.current_hp = 0.0
	_check(F.change(c, &"unequip", {"slot": &"armor"})["error_code"] == &"actor_dead", "dead actor cannot mutate equipment")
	c.free()
	await process_frame

func _uncommitted() -> void:
	var fixture := F.make(self, "uncertain_before_write")
	var c: RunController = fixture["controller"]
	var store: F.FaultStore = fixture["store"]
	var preview := c.build_service.preview_change(F.intent(c, &"equip", {"slot": &"armor", "item_id": &"warden_mail"}))
	var disk := F.disk(fixture)
	var version := c.run_state.runtime_revision
	store.uncertain_before_write = true
	_check(not c.build_service.commit_change(preview["intent"])["ok"] and c.inventory_frozen, "unreadable result freezes even when disk may not have committed")
	store.hide_reads = false
	var reconciled := c.build_service.commit_change(preview["intent"])
	_check(not reconciled["ok"] and not c.inventory_frozen and F.disk(fixture) == disk and c.run_state.runtime_revision == version, "reconciliation of absent commit unfreezes without publishing or saving")
	_check(c.build_service.commit_change(preview["intent"])["ok"] and c.run_state.runtime_revision == version + 1, "same intent can retry after confirmed absence of commit")
	c.free()
	paused = false
	await process_frame

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
