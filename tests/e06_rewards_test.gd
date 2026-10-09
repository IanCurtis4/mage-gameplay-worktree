extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var f := F.make(self, "rewards", &"mage", false)
	var c: RunController = f["controller"]
	var facade: ProfileFacade = f["facade"]
	var store: F.FaultStore = f["store"]
	var before := facade.current_profile()
	c.rng.seed = 227
	var first := c.reward_service.issue("stage1", &"encounter_one", true)
	var rng_state := c.rng.state
	var repeat := c.reward_service.issue("stage1", &"encounter_two", false)
	_check(first == repeat and c.rng.state == rng_state and first["card_id"] != &"", "issued event freezes ticket payload and RNG")
	first["payload"]["base_xp"] = 99999
	_check(c.reward_service.ticket(first["ticket_id"])["payload"]["base_xp"] == 100, "ticket DTO cannot alter durable payload")
	var second := c.reward_service.issue("stage2", &"encounter_two", true)
	var third := c.reward_service.issue("stage3", &"encounter_two", true)
	_check(first["card_id"] != second["card_id"] and second["card_id"] != third["card_id"] and first["card_id"] != third["card_id"], "queued stage draws reserve unique cards before collection")
	_check(c.reward_service.collect(second["ticket_id"])["error_code"] == &"invalid_reward_sequence", "reward queue serializes out-of-order requests")
	_check(not c.reward_service.collect("invented")["ok"], "UI cannot invent ticket or reward values")
	var disk := F.disk(f)
	rng_state = c.rng.state
	store.failure_stage = &"replace"
	var failed := c.reward_service.collect(first["ticket_id"])
	_check(not failed["ok"] and F.disk(f) == disk and c.run_state.card_inventory.describe()["owned"].is_empty() and c.run_state.pending_choices == 0, "failed persistent confirmation grants nothing transient")
	_check(c.rng.state == rng_state and c.reward_service.ticket(first["ticket_id"])["card_id"] == first["card_id"], "retry does not change RNG or chosen card")
	store.failure_stage = &""
	var collected := c.reward_service.collect(first["ticket_id"])
	_check(collected["ok"] and facade.current_profile().characters[0].base_xp_total == 100 and StringName(first["item_id"]) in facade.current_profile().equipment_collection, "item and XP confirmed in same commit")
	_check(c.run_state.pending_choices == 1 and c.run_state.card_inventory.owns(first["card_id"]), "confirmation publishes one card and one choice")
	var revision := facade.current_profile().revision
	_check(c.reward_service.collect(first["ticket_id"])["already_applied"] and facade.current_profile().revision == revision and c.run_state.pending_choices == 1, "replay creates no item XP card or choice")
	store.uncertain = true
	failed = c.reward_service.collect(second["ticket_id"])
	_check(not failed["ok"] and c.inventory_frozen and c.run_state.pending_choices == 1, "uncertain reward freezes before transient grant")
	_check(not c.reward_service.collect(third["ticket_id"])["ok"], "uncertain serial ticket blocks later reward")
	store.hide_reads = false
	collected = c.reward_service.collect(second["ticket_id"])
	_check(collected["ok"] and not c.inventory_frozen and c.run_state.pending_choices == 2 and facade.current_profile().characters[0].base_xp_total == 250, "same uncertain ticket reconciles committed XP once")
	_check(c.reward_service.collect(third["ticket_id"])["ok"] and c.run_state.pending_choices == 3, "three stage calls work without a campaign")
	var slots_before := c.run_state.build_snapshot.action_slots.duplicate()
	var item := StringName(first["item_id"])
	var definition := c.run_state.effect_catalog().get_definition(&"equipment", item) as EquipmentDefinition
	_check(F.change(c, &"equip", {"slot": definition.slot, "item_id": item})["ok"], "newly acquired item is immediately usable between encounters")
	_check(c.run_state.build_snapshot.action_slots == slots_before and facade.current_profile().characters[1].base_xp_total == before.characters[1].base_xp_total, "rewards and equip preserve action layout and alt XP")
	var directory: String = f["directory"]
	c._show_result(false)
	_check(c.run_state.card_inventory.describe()["owned"].is_empty() and c.run_state.augment_stacks.is_empty() and c.run_state.pending_choices == 0, "death discards all cards and choices")
	c.free()
	paused = false
	var reopened := ProfileFacade.new(ProfileStore.new(directory), ProfileRewardResolver.pilot_progression())
	var loaded := reopened.open_profile()
	_check(loaded["ok"] and loaded["abandoned_run_closed"] and reopened.current_profile().characters[0].base_xp_total == 400 and item in reopened.current_profile().equipment_collection, "reopen keeps durable XP/items and closes interrupted run")
	var fresh := reopened.start_run("new-run", reopened.current_profile().revision)
	_check(fresh["ok"] and fresh["run_state"].card_inventory.describe()["owned"].is_empty() and fresh["run_state"].augment_stacks.is_empty(), "restart never reconstructs cards or augments")
	await _terminal()
	await _reward_boundaries()
	await _training()
	print("E06 rewards: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _terminal() -> void:
	var f := F.make(self, "terminal", &"mage", false)
	var c: RunController = f["controller"]
	for encounter: int in [1, 2]:
		c.encounter_index = encounter
		c.reward = RewardPickup.new()
		c.add_child(c.reward)
		var issued := c._ensure_reward_ticket()
		var ticket_id: String = issued["ticket_id"]
		var result := c._collect_reward()
		_check(result["ok"] and c.reward == null and c.run_state.pending_choices == 1, "real pickup confirms before consumption")
		c._start_next_encounter()
		_check(not c.run_finished and c.encounter_index == encounter, "pending choices block transition")
		c._open_augment_menu()
		var offer := c.run_state.current_offer.duplicate()
		c._confirm_augment(offer[0].id)
		_check(not c.run_finished and not paused and c.run_state.pending_choices == 0, "choice resolves without automatic terminal")
		_check(c.reward_service.collect(ticket_id)["already_applied"], "same world ticket remains idempotent")
	_check(c.run_state.card_inventory.describe()["owned"].size() == 1, "only second encounter grants stage card")
	_check(c.next_button.visible and c.next_button.text == "Encerrar demonstração", "explicit terminal available after demonstration reward")
	c._start_next_encounter()
	_check(c.run_finished and paused and c.run_state.card_inventory.describe()["owned"].is_empty(), "explicit end closes and discards transient inventory")
	c.free()
	paused = false
	await process_frame

func _reward_boundaries() -> void:
	for stage: StringName in [&"write_pending", &"validate_pending", &"backup", &"replace"]:
		var f := F.make(self, "reward_failure_" + String(stage), &"mage", false)
		var c: RunController = f["controller"]
		var store: F.FaultStore = f["store"]
		var facade: ProfileFacade = f["facade"]
		var ticket := c.reward_service.issue("stage", &"encounter_two", true)
		var disk := F.disk(f)
		var rng_state := c.rng.state
		_check(not facade.grant_run_ticket(c, ticket["ticket_id"])["ok"], "direct facade call cannot bypass serial service")
		store.failure_stage = stage
		var result := c.reward_service.collect(ticket["ticket_id"])
		_check(not result["ok"] and F.disk(f) == disk and c.run_state.pending_choices == 0 and c.run_state.card_inventory.describe()["owned"].is_empty() and c.rng.state == rng_state, "reward failure preserves disk RNG and grants: " + String(stage))
		store.failure_stage = &""
		var revision := facade.current_profile().revision
		_check(c.reward_service.collect(ticket["ticket_id"])["ok"] and facade.current_profile().revision == revision + 1 and c.run_state.pending_choices == 1, "same ticket retries once: " + String(stage))
		c.free()
		await process_frame
	var f := F.make(self, "empty_pool")
	var c: RunController = f["controller"]
	for id: StringName in c.run_state.effect_catalog().ids(&"card"):
		c.run_state.card_inventory.grant(id, c.run_state.effect_catalog())
	_check(c.reward_service.eligible_cards().is_empty(), "owned free and socketed types exhaust card pool")
	var issued := c.reward_service.issue("empty-stage", &"encounter_two", true)
	_check(issued["card_id"] == &"" and not issued["message"].is_empty() and c.reward_service.collect(issued["ticket_id"])["ok"] and c.run_state.pending_choices == 1, "exhausted card pool warns and still delivers item XP and pending choice")
	var empty_augments := BuildEffectCatalog.new()
	for origin: StringName in [&"equipment", &"card"]:
		for id: StringName in c.run_state.effect_catalog().ids(origin):
			assert(empty_augments.register_definition(origin, c.run_state.effect_catalog().get_definition(origin, id))["ok"])
	assert(c.run_state.set_effect_catalog(empty_augments)["ok"])
	c.encounter_index = 2
	c.run_state.queue_choice()
	c._open_augment_menu()
	_check(c.run_state.pending_choices == 1 and not c.run_finished, "empty offer consumes exactly one of multiple pending choices")
	c._start_next_encounter()
	_check(not c.run_finished, "remaining empty choice still blocks terminal")
	c._open_augment_menu()
	_check(c.run_state.pending_choices == 0 and c.next_button.visible and not c.run_finished, "last empty offer leaves explicit terminal available")
	c._start_next_encounter()
	_check(c.run_finished, "empty pools cannot softlock demonstration end")
	paused = false
	c.free()
	await process_frame

func _training() -> void:
	var f := F.make(self, "training_no_write")
	var persistent_controller: RunController = f["controller"]
	var disk := F.disk(f)
	persistent_controller.free()
	var state := RunState.new(&"mage")
	assert(state.set_effect_catalog(F.catalog())["ok"])
	RunController.pending_run_state = state
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	var c := RunController.new()
	root.add_child(c)
	c.set_process(false)
	c.player.set_process(false)
	for enemy: CombatActor in c.enemies:
		enemy.set_process(false)
	c.encounter_active = false
	var issued := c.reward_service.issue("training-fixture", &"encounter_two", true)
	var collected := c.reward_service.collect(issued["ticket_id"])
	_check(collected["ok"] and not collected["persistent"] and F.disk(f) == disk, "training fixtures grant locally without a persistent facade or write")
	var item := StringName(issued["item_id"])
	var definition := state.effect_catalog().get_definition(&"equipment", item) as EquipmentDefinition
	_check(F.change(c, &"equip", {"slot": definition.slot, "item_id": item})["ok"] and F.disk(f) == disk, "training equipment transaction remains runtime-only")
	c.free()
	await process_frame

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
