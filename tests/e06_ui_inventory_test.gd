extends SceneTree
## T4: panel actions must preserve the service's intent and transaction boundary.
const F = preload("res://tests/e06_tx_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(BuildPresentation.value_text(&"crit_chance", 0.05) == "5%", "chance display formats canonical ratio as percent")
	_check(BuildPresentation.value_text(&"crit_chance", 0.105) == "10.5%", "fractional percentage remains precise")
	_check(BuildPresentation.value_text(&"crit_chance", 0.1) == "10%", "integer trailing zero remains significant")
	for axis: StringName in BuildEffectCatalog.KIT_POLICIES:
		var active := {"kit_policies": {axis: true}}
		var gained := BuildPresentation.mechanics_lines({}, active)
		var lost := BuildPresentation.mechanics_lines(active, {})
		var skill: StringName = BuildEffectCatalog.KIT_POLICIES[axis]["skills"][0]
		_check(gained.size() == 1 and gained[0].contains(ClassCatalog.skill_definition(skill).display_name) and gained[0].contains("ativada"), "policy gain resolves canonical skill label: " + String(axis))
		_check(lost.size() == 1 and lost[0].contains("removida") and BuildPresentation.mechanics_lines(active, active).is_empty(), "policy removal and unchanged preview: " + String(axis))
	var fixture := F.make(self, "ui_inventory")
	var controller: RunController = fixture["controller"]
	var store: Variant = fixture["store"]
	# Exercise Main's real pause/open/close coordinator before the isolated panel.
	controller.cast_intent.active_skill = &"fire_spear"
	controller._open_inventory()
	_check(controller.inventory_panel.visible and paused and controller.cast_intent.active_skill == &"", "real inventory pauses and cancels world intention")
	controller._open_inventory()
	_check(controller.inventory_panel.visible and paused, "repeat open cannot unpause or stack menus")
	controller.inventory_panel.dismiss()
	_check(not controller.inventory_panel.visible and not paused, "dismiss restores active world through Main signal")
	controller.encounter_active = true
	controller._open_inventory()
	_check(not controller.inventory_panel.visible and not paused, "encounter prevents actual panel opening")
	controller.encounter_active = false
	var panel := RunInventoryPanel.new()
	root.add_child(panel)
	panel.configure(controller)
	await process_frame
	var description := BuildPresentation.describe(controller)
	_check(description["ok"] and panel.slots.item_count == 14, "published view has fourteen positions")
	var current_slot: StringName = panel.slots.get_item_metadata(panel.slots.selected)
	var visible_equipment := 0
	for row: Dictionary in description["equipment"]:
		if EquipmentRules.slot_matches(row["slot"], current_slot): visible_equipment += 1
	_check(panel.equipment_list.item_count == visible_equipment and panel.cards_list.item_count == description["cards"].size(), "lists derive from canonical description")
	var armor := F.item(fixture, &"warden_mail")
	var before_disk := F.disk(fixture)
	var before_build := controller.run_state.build_snapshot.equipped.duplicate(true)
	var preview: Dictionary = panel.propose({"kind": &"equip", "slot": &"torso", "equipment_instance_id": armor})
	_check(preview["ok"] and preview["intent"].has("resource_state") and preview["intent"].has("inventory_revision") and not String(preview["request_id"]).is_empty(), "panel retains service-enriched intention")
	_check(preview.has("before") and preview.has("after") and panel.preview_label.text.contains("Comparação"), "before and after from compositor are visible")
	_check(F.disk(fixture) == before_disk and controller.run_state.build_snapshot.equipped == before_build, "preview does not mutate save or run")
	var committed: Dictionary = panel.confirm_change()
	_check(committed["ok"] and controller.run_state.build_snapshot.equipped[&"torso"] == armor and F.disk(fixture) != before_disk, "confirm persists one exemplar")
	var replay: Dictionary = controller.build_service.commit_change(preview["intent"])
	_check(not replay["ok"] and replay["error_code"] == &"replayed_request", "committed request cannot apply twice")
	var grants: Array[StringName] = []
	for index: int in 4:
		var grant: Dictionary = controller.run_state.card_inventory.grant(&"bulwark_card", controller.run_state.effect_catalog(), "ui-card-%d" % index)
		grants.append(grant["card_instance_id"])
	_check(grants.size() == 4 and grants[0] != grants[1], "repeated card definitions remain distinct")
	for index: int in 4:
		var socket: Dictionary = panel.propose({"kind": &"socket", "equipment_instance_id": armor, "socket_index": index, "card_instance_id": grants[index]})
		_check(socket["ok"] and panel.confirm_change()["ok"], "socket index %d uses its card instance" % index)
	_check(controller.run_state.card_inventory.sockets()[armor] == grants, "all four socket positions hold their own card")
	var invalid: Dictionary = panel.propose({"kind": &"socket", "equipment_instance_id": armor, "socket_index": 4, "card_instance_id": grants[0]})
	_check(not invalid["ok"] and invalid["error_code"] == &"invalid_socket_index" and not panel.status_label.text.is_empty(), "fifth socket rejects with feedback")
	var shield := F.item(fixture, &"fixture_shield")
	var wand := F.item(fixture, &"fixture_wand")
	_check(panel.propose({"kind": &"equip", "slot": &"main_hand", "equipment_instance_id": wand})["ok"] and panel.confirm_change()["ok"], "equip one-hand weapon")
	_check(panel.propose({"kind": &"equip", "slot": &"off_hand", "equipment_instance_id": shield})["ok"] and panel.confirm_change()["ok"], "equip shield")
	var transfer: Dictionary = panel.propose({"kind": &"transfer", "from_equipment_instance_id": armor, "from_socket_index": 2, "equipment_instance_id": shield, "socket_index": 3, "card_instance_id": grants[2]})
	_check(transfer["ok"] and controller.run_state.card_inventory.sockets()[armor][2] == grants[2] and panel.confirm_change()["ok"], "transfer previews exact source without early removal")
	_check(controller.run_state.card_inventory.sockets()[armor][2] == null and controller.run_state.card_inventory.sockets()[shield][3] == grants[2] and controller.run_state.card_inventory.describe()["owned"].size() == 4, "transfer is atomic and preserves inventory")
	panel.slots.select(4) # Tronco: actual equipped host with four occupied sockets.
	panel.refresh_view()
	var changed_socket: Dictionary = panel.propose({"kind": &"unsocket", "equipment_instance_id": armor, "socket_index": 0})
	_check(changed_socket["ok"] and not panel.confirm_button.disabled, "socket removal is reviewable before confirm")
	panel.socket_selector.select(1)
	panel.socket_selector.item_selected.emit(1)
	_check(panel.confirm_button.disabled and panel.confirm_change()["error_code"] == &"preview_required", "changing displayed socket invalidates earlier confirmation")
	var occupied: Dictionary = panel.propose({"kind": &"socket", "equipment_instance_id": armor, "socket_index": 0, "card_instance_id": grants[2]})
	_check(not occupied["ok"] and occupied["error_code"] == &"socket_occupied", "occupied target rejects")
	var hand_conflict: Dictionary = panel.propose({"kind": &"equip", "slot": &"main_hand", "equipment_instance_id": F.item(fixture, &"starter_staff")})
	_check(not hand_conflict["ok"] and hand_conflict["error_code"] == &"invalid_hand_configuration", "two-hand weapon and shield conflict")
	var charm := F.item(fixture, &"traveler_charm")
	var same_exemplar: Dictionary = panel.propose({"kind": &"equip", "slot": &"accessory_2", "equipment_instance_id": charm})
	_check(not same_exemplar["ok"] and same_exemplar["error_code"] == &"duplicate_equipment_instance", "one exemplar cannot occupy two positions")
	var other_charm: StringName = &""
	var owned: ProfileState = controller.persistent_facade.current_profile()
	for id: StringName in owned.equipment_instance_ids():
		if id != charm and owned.equipment_instances[id].definition_id == &"traveler_charm": other_charm = id
	var identical: Dictionary = panel.propose({"kind": &"equip", "slot": &"accessory_2", "equipment_instance_id": other_charm})
	_check(not identical["ok"] and identical["error_code"] == &"identical_accessory", "different copies of the same jewel remain incompatible")
	var restricted: Dictionary = panel.propose({"kind": &"equip", "slot": &"main_hand", "equipment_instance_id": F.item(fixture, &"starter_blade")})
	_check(not restricted["ok"] and restricted["error_code"] == &"identity_restricted", "identity restriction is reported by service")
	var unsocket: Dictionary = panel.propose({"kind": &"unsocket", "equipment_instance_id": shield, "socket_index": 3})
	_check(unsocket["ok"] and panel.confirm_change()["ok"] and grants[2] in controller.run_state.card_inventory.describe()["free"], "unsocket returns the same run card")
	var unequip: Dictionary = panel.propose({"kind": &"unequip", "slot": &"torso"})
	_check(unequip["ok"] and panel.confirm_change()["ok"] and controller.run_state.card_inventory.describe()["free"].size() == 4, "unequip releases all cards")
	controller.encounter_active = true
	var blocked: Dictionary = panel.propose({"kind": &"equip", "slot": &"torso", "equipment_instance_id": armor})
	_check(not blocked["ok"] and blocked["error_code"] == &"encounter_active" and panel.status_label.text.contains("encontro"), "encounter blocks proposal with pt-BR reason")
	controller.encounter_active = false
	var uncertain: Dictionary = panel.propose({"kind": &"equip", "slot": &"torso", "equipment_instance_id": armor})
	store.uncertain = true
	var first: Dictionary = panel.confirm_change()
	_check(uncertain["ok"] and not first["ok"] and first.get("read_only", false) and controller.build_service.has_pending_transaction(), "uncertain write freezes pending intent")
	var request_id: String = uncertain["request_id"]
	store.hide_reads = false
	var resolved: Dictionary = panel.confirm_change()
	_check(resolved["ok"] and controller.run_state.build_snapshot.equipped[&"torso"] == armor and not controller.build_service.has_pending_transaction(), "retry reconciles exactly once")
	_check(String(resolved.get("request_id", request_id)) == request_id, "retry keeps request identity")
	panel.dismiss()
	_check(not panel.visible, "dismiss closes panel")
	panel.queue_free()
	controller.queue_free()
	await process_frame
	print("E06 UI inventory: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
