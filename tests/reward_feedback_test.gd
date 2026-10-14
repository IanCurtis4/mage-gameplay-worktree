extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _confirmed_reward_journal()
	await _confirmed_mob_drop()
	await _local_session_and_journal_lifetime()
	await _panel_layout_and_history()
	await _escape_closes_history()
	print("E06 reward feedback: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _confirmed_reward_journal() -> void:
	var fixture := F.make(self, "reward_feedback", &"mage", false)
	var controller: RunController = fixture["controller"]
	var facade: ProfileFacade = fixture["facade"]
	var store: F.FaultStore = fixture["store"]
	var journal: AcquisitionJournal = controller.acquisition_journal
	var first := controller.reward_service.issue("feedback_first", &"encounter_one", true)
	_check(first["ok"] and journal.entries().is_empty(), "issued ticket stays out of the journal before delivery")
	store.failure_stage = &"replace"
	var failed := controller.reward_service.collect(first["ticket_id"])
	_check(not failed["ok"] and journal.entries().is_empty(), "failed durable grant publishes no acquisition feedback")
	store.failure_stage = &""
	var delivered := controller.reward_service.collect(first["ticket_id"])
	var entries := journal.entries()
	var xp := _entry(entries, &"xp")
	_check(delivered["ok"] and xp.size() == 1 and xp[0]["base_xp"] == 100 and xp[0]["job_xp"] == 0, "receipt reports observed base XP and zero job XP at the fixture cap")
	_check(xp.size() == 1 and int(xp[0]["encounter"]) == int(first["encounter_index"]), "receipt keeps the encounter frozen at ticket issuance")
	var dto_copy := journal.entries()
	dto_copy[0]["text"] = "mutação externa"
	_check(journal.entries()[0]["text"] != "mutação externa", "journal entry DTO mutation cannot alter stored history")
	var equip_entries := _entry(entries, &"equipment")
	var card_entries := _entry(entries, &"card")
	var receipt_item: Dictionary = delivered["applied_reward"]["equipment_drops"][0]
	_check(equip_entries.size() == 1 and equip_entries[0]["definition_id"] == receipt_item["definition_id"] and equip_entries[0]["quality_id"] == receipt_item["quality_id"] and equip_entries[0]["item_level"] == receipt_item["item_level"] and equip_entries[0]["socket_capacity"] == receipt_item["socket_capacity"], "equipment feedback preserves acquired quality, ilvl and socket capacity")
	var definition := controller.run_state.effect_catalog().get_definition(&"equipment", StringName(receipt_item["definition_id"])) as EquipmentDefinition
	_check(equip_entries.size() == 1 and equip_entries[0]["text"].contains(EquipmentPresentation.item_name(definition)) and equip_entries[0]["text"].contains(EquipmentPresentation.quality_name(StringName(receipt_item["quality_id"]))), "equipment row uses catalog name and quality presentation")
	_check(card_entries.size() == 1 and card_entries[0]["definition_id"] == first["card_id"] and card_entries[0]["text"].contains((controller.run_state.effect_catalog().get_definition(&"card", first["card_id"]) as CardDefinition).display_name), "card row explains the card actually delivered")
	var count_after_first := entries.size()
	var revision := facade.current_profile().revision
	var replay := controller.reward_service.collect(first["ticket_id"])
	_check(replay["already_applied"] and journal.entries().size() == count_after_first and facade.current_profile().revision == revision, "replayed collection neither saves nor repeats feedback")

	# A distinct confirmed ticket carrying the same exemplar remains a separate acquisition.
	var repeat_receipt := {"ticket_id": "feedback-repeat-item", "encounter_index": 2, "persistent": true, "equipment_drops": [receipt_item.duplicate(true)], "card_id": &""}
	_check(journal.record_reward(repeat_receipt, controller.run_state.effect_catalog()), "a second ticket for the same equipment definition is recorded")
	var after_repeat := _entry(journal.entries(), &"equipment")
	_check(after_repeat.size() == 2 and after_repeat[0]["definition_id"] == after_repeat[1]["definition_id"], "repeated equipment definitions remain two acquisition rows")
	var count_before_empty := journal.entries().size()
	var empty_receipt := {"ticket_id": "feedback-empty", "encounter_index": 2, "persistent": true, "equipment_drops": [], "card_id": &"", "base_xp": 0, "job_xp": 0, "offered_base_xp": 0, "offered_job_xp": 0}
	_check(not journal.record_reward(empty_receipt, controller.run_state.effect_catalog()) and not journal.record_reward(empty_receipt, controller.run_state.effect_catalog()) and journal.entries().size() == count_before_empty, "zero-drop receipt and its replay create no empty log row")

	store.uncertain = true
	var second := controller.reward_service.issue("feedback_uncertain", &"encounter_two", true)
	var before_uncertain := journal.entries().size()
	var uncertain := controller.reward_service.collect(second["ticket_id"])
	_check(not uncertain["ok"] and journal.entries().size() == before_uncertain, "uncertain commit waits for reconciliation before showing a reward")
	store.hide_reads = false
	var reconciled := controller.reward_service.collect(second["ticket_id"])
	var xp_rows := _entry(journal.entries(), &"xp")
	_check(reconciled["ok"] and xp_rows.size() == 2 and xp_rows[1]["base_xp"] == 150 and xp_rows[1]["job_xp"] == 0, "reconciliation reports the committed XP delta from the original baseline once")
	var last_count := journal.entries().size()
	_check(controller.reward_service.collect(second["ticket_id"])["already_applied"] and journal.entries().size() == last_count, "reconciled replay does not duplicate journal entries")

	controller.run_state.queue_choice()
	controller._open_augment_menu()
	var offer: Array = controller.run_state.current_offer.duplicate()
	var augments_before := _entry(journal.entries(), &"augment").size()
	controller._confirm_augment(&"not_an_offered_augment")
	_check(_entry(journal.entries(), &"augment").size() == augments_before, "rejected augment choice is absent from the journal")
	if not offer.is_empty():
		controller._confirm_augment(offer[0].id)
	var accepted := _entry(journal.entries(), &"augment")
	_check(accepted.size() == 1 and not bool(accepted[0]["persistent"]) and accepted[0]["text"].contains("somente nesta run"), "accepted augment is logged as temporary run state")
	_check(int(journal.totals()["equipment"]) == _entry(journal.entries(), &"equipment").size() and int(journal.totals()["cards"]) == _entry(journal.entries(), &"card").size() and int(journal.totals()["augments"]) == accepted.size(), "journal totals count confirmed acquisitions by kind")
	controller.free()
	paused = false
	await process_frame

func _confirmed_mob_drop() -> void:
	var fixture := F.make(self, "reward_feedback_mob", &"mage", false)
	var controller: RunController = fixture["controller"]
	var journal: AcquisitionJournal = controller.acquisition_journal
	var catalog := _mob_feedback_catalog()
	var catalog_result := controller.run_state.set_effect_catalog(catalog)
	_check(catalog_result["ok"], "mob fixture catalog installs before spawn registration")
	if not catalog_result["ok"]:
		controller.free()
		paused = false
		await process_frame
		return
	for candidate: CombatActor in controller.enemies:
		if not candidate is EnemyActor:
			continue
		var occurrence := MobOccurrence.new()
		occurrence.occurrence_id = "reward_feedback_spawn_%d" % candidate.get_instance_id()
		occurrence.mob_base_id = &"loot_fixture"
		occurrence.category_id = &"normal"
		occurrence.origin_id = &"fixture_map"
		var spawn_configured := (candidate as EnemyActor).configure_occurrence(occurrence, catalog.mob_catalog(), controller.navigation, controller.player)
		_check(spawn_configured["ok"], "owned world spawn receives the existing loot fixture occurrence")
	var table := MobLootTable.new()
	for category: StringName in MobCatalog.CATEGORIES:
		table.profiles[category] = {
			"equipment_chance": 1.0,
			"card_chance": 0.0,
			"quality_weights": {&"common": 1.0, &"rare": 1.0, &"epic": 1.0},
			"equipment_weights": {&"starter_blade": 1.0},
			"socket_weights": {0: 1.0},
		}
	var configured := controller.reward_service.configure_mob_loot(table)
	_check(configured["ok"], "explicit fixture loot table registers current world spawns: %s" % str(configured))
	if not configured["ok"]:
		controller.free()
		paused = false
		await process_frame
		return
	var actor := controller.enemies[0] as EnemyActor
	controller.encounter_index = 2
	actor.health.current_hp = 0.0
	var ticket := controller.reward_service.issue_mob_drop(actor)
	_check(ticket["ok"], "actual dead world mob issues a ticket: %s" % str(ticket))
	if not ticket["ok"]:
		controller.free()
		paused = false
		await process_frame
		return
	_check(ticket["payload"]["equipment_drops"].size() == 1 and ticket["card_id"].is_empty(), "actual mob death issues one equipment drop without XP or card")
	_check(journal.entries().is_empty(), "mob ticket issuance stays out of history until collection")
	var drop: Dictionary = ticket["payload"]["equipment_drops"][0]
	var collected := controller.reward_service.collect(ticket["ticket_id"])
	var entries := journal.entries()
	var equipment := _entry(entries, &"equipment")
	var xp := _entry(entries, &"xp")
	var expected_text := "%s · %s · ilvl %d · %d encaixe(s)" % [EquipmentPresentation.item_name(controller.run_state.effect_catalog().get_definition(&"equipment", drop["definition_id"]) as EquipmentDefinition), EquipmentPresentation.quality_name(drop["quality_id"]), drop["item_level"], drop["socket_capacity"]]
	_check(collected["ok"] and equipment.size() == 1 and xp.is_empty() and _entry(entries, &"augment").is_empty(), "mob collection records the real drop without XP or an augment choice")
	_check(equipment.size() == 1 and equipment[0]["definition_id"] == drop["definition_id"] and equipment[0]["quality_id"] == drop["quality_id"] and equipment[0]["item_level"] == drop["item_level"] and equipment[0]["socket_capacity"] == drop["socket_capacity"] and equipment[0]["encounter"] == 2 and equipment[0]["text"] == expected_text, "mob feedback row exactly reflects its issued equipment metadata")
	var count_after_collect := entries.size()
	_check(controller.reward_service.collect(ticket["ticket_id"])["already_applied"] and journal.entries().size() == count_after_collect, "mob collection replay does not duplicate the real drop row")
	controller.free()
	paused = false
	await process_frame

func _local_session_and_journal_lifetime() -> void:
	var persistent_fixture := F.make(self, "reward_feedback_reset", &"mage", false)
	var controller: RunController = persistent_fixture["controller"]
	var first := controller.reward_service.issue("feedback_survives_result", &"encounter_one", true)
	_check(controller.reward_service.collect(first["ticket_id"])["ok"] and not controller.acquisition_journal.entries().is_empty(), "test acquisition is confirmed before the result screen")
	var history_size := controller.acquisition_journal.entries().size()
	controller._show_result(false)
	_check(controller.acquisition_journal.entries().size() == history_size and controller.run_state.augment_stacks.is_empty(), "result/reset clears run augments while keeping acquired history in the controller")
	controller.free()
	paused = false
	await process_frame

	var state := RunState.new(&"mage")
	assert(state.set_effect_catalog(F.catalog())["ok"])
	RunController.pending_run_state = state
	RunController.pending_run_facade = null
	RunController.pending_training_mode = false
	var local := RunController.new()
	root.add_child(local)
	local.set_process(false)
	local.player.set_process(false)
	for enemy: CombatActor in local.enemies:
		enemy.set_process(false)
	local.encounter_active = false
	var ticket := local.reward_service.issue("feedback_local", &"encounter_one", true)
	var collected := local.reward_service.collect(ticket["ticket_id"])
	var local_entries := local.acquisition_journal.entries()
	var local_xp := _entry(local_entries, &"xp")
	_check(collected["ok"] and not collected["persistent"] and (local_xp.is_empty() or (local_xp[0]["base_xp"] == 0 and local_xp[0]["job_xp"] == 0)), "local session does not announce persistent XP it did not grant")
	local.free()
	paused = false
	await process_frame

	var fresh := F.make(self, "reward_feedback_fresh", &"mage", false)
	var fresh_controller: RunController = fresh["controller"]
	_check(fresh_controller.acquisition_journal.entries().is_empty(), "a new run controller starts with an empty presentation journal")
	fresh_controller.free()
	paused = false
	await process_frame

func _panel_layout_and_history() -> void:
	var journal := AcquisitionJournal.new()
	var catalog := F.catalog()
	for index: int in 36:
		var encounter := 1 if index % 2 == 0 else 2
		journal.record_reward({"ticket_id": "panel-%d" % index, "encounter_index": encounter, "persistent": true, "base_xp": 1, "offered_base_xp": 1, "job_xp": 0, "offered_job_xp": 0, "equipment_drops": [], "card_id": &""}, catalog)
	for viewport_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var test_viewport := SubViewport.new()
		test_viewport.size = viewport_size
		test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(test_viewport)
		var panel := RewardFeedbackPanel.new()
		test_viewport.add_child(panel)
		panel.configure(journal, catalog, true)
		await process_frame
		var rect := panel.history_panel.get_global_rect()
		var host_rect := Rect2(Vector2.ZERO, test_viewport.size)
		_check(rect.size.x >= 640.0 and rect.size.x <= 720.0 and rect.position.x >= host_rect.position.x and rect.end.x <= host_rect.end.x and rect.position.y >= host_rect.position.y and rect.end.y <= host_rect.end.y, "history window fits the %dx%d viewport" % [int(viewport_size.x), int(viewport_size.y)])
		_check(panel.close_button.custom_minimum_size.x >= 52 and panel.close_button.custom_minimum_size.y >= 44 and panel.recent_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "close target meets size and recent feedback ignores world clicks")
		panel.open_history(1)
		await process_frame
		await process_frame
		_check(panel._title.text == "Obtido no encontro 1" and panel.summary_label.text.contains("XP Base +18"), "history filter and encounter totals update from the journal")
		_check(panel.history_scroll.get_v_scroll_bar().max_value > 0.0, "long filtered acquisition history can scroll")
		var run_filter: Button
		for candidate: Node in panel.history_panel.find_children("*", "Button", true, false):
			if candidate is Button and (candidate as Button).text == "Run inteira":
				run_filter = candidate as Button
				break
		_check(run_filter != null, "run history filter is present after opening history")
		if run_filter != null:
			run_filter.pressed.emit()
		await process_frame
		_check(panel._title.text == "Recompensas da run" and panel.summary_label.text.contains("XP Base +36"), "run filter restores the full acquisition history")
		_check(panel.history_scroll.get_v_scroll_bar().max_value > 0.0, "full history still scrolls after changing filters")
		panel.close_button.pressed.emit()
		_check(not panel.history_panel.visible, "close button hides history")
		test_viewport.queue_free()
		await process_frame

func _escape_closes_history() -> void:
	var fixture := F.make(self, "reward_feedback_escape", &"mage", false)
	var controller: RunController = fixture["controller"]
	controller.reward_feedback.open_history(0)
	var was_paused := paused
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	controller._input(escape)
	_check(not controller.reward_feedback.history_panel.visible, "Escape closes reward history during the run")
	_check(not controller.battle_controls.settings_overlay.visible and paused == was_paused, "closing run history does not open settings or change pause state")

	controller._show_result(false)
	_check(controller.run_finished and paused, "death result screen is active before checking its history control")
	var result_history_button: Button
	for candidate: Node in controller.result_panel.find_children("*", "Button", true, false):
		if candidate is Button and (candidate as Button).text == "Ver recompensas desta run":
			result_history_button = candidate as Button
			break
	_check(result_history_button != null, "death result exposes the acquired reward history control")
	if result_history_button != null:
		result_history_button.pressed.emit()
		_check(controller.reward_feedback.history_panel.visible, "result control opens the reward history after death")
		controller._input(escape)
		_check(not controller.reward_feedback.history_panel.visible, "Escape closes reward history after death")
		_check(not controller.battle_controls.settings_overlay.visible and paused, "closing post-death history keeps settings closed and result paused")
	controller.free()
	paused = false
	await process_frame

func _mob_feedback_catalog() -> BuildEffectCatalog:
	var source := F.catalog()
	var mobs := source.mob_catalog()
	var mob := MobDefinition.new()
	mob.id = &"loot_fixture"
	mob.fixed_level = 7
	mob.allowed_occurrence_categories = MobCatalog.CATEGORIES.duplicate()
	mob.card_id = &"bulwark_card"
	for axis: StringName in StatCalculator.PRIMARY_IDS:
		mob.primary_attributes[axis] = 3
	assert(mobs.register_definition(mob)["ok"])
	var catalog := BuildEffectCatalog.new()
	assert(catalog.set_mob_catalog(mobs)["ok"])
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for id: StringName in source.ids(origin):
			assert(catalog.register_definition(origin, source.get_definition(origin, id))["ok"])
	return catalog

func _entry(entries: Array[Dictionary], kind: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if entry["kind"] == kind:
			result.append(entry)
	return result

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
