extends SceneTree
const F = preload("res://tests/e06_tx_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var f := F.make(self, "inventory")
	var c: RunController = f["controller"]
	var facade: ProfileFacade = f["facade"]
	var profile := facade.current_profile()
	_check(profile.characters[0].equipped.size() == 14 and IdentityIds.equipment_slots().size() == 14, "fourteen positions")
	var armor := F.item(f, &"warden_mail")
	var wand := F.item(f, &"fixture_wand")
	var shield := F.item(f, &"fixture_shield")
	var focus := F.item(f, &"fixture_focus")
	_check(F.change(f, &"equip", {"slot": &"torso", "equipment_instance_id": armor})["ok"], "equip exemplar")
	var hp_before := c.player.health.max_hp
	c.player.health.current_hp = hp_before - 25.0
	var debt := c.player.health.hp_deficit()
	var cards: Array[StringName] = []
	for index: int in 4:
		var granted := c.run_state.card_inventory.grant(&"bulwark_card", c.run_state.effect_catalog(), "card-acquisition-%d" % index)
		cards.append(granted["card_instance_id"])
		_check(F.change(f, &"socket", {"equipment_instance_id": armor, "socket_index": index, "card_instance_id": cards[-1]})["ok"], "socket repeated definition: %d" % index)
	_check(cards.size() == 4 and cards[0] != cards[1] and c.run_state.card_inventory.describe()["owned"].size() == 4, "copies remain distinct")
	_check(is_equal_approx(c.player.health.max_hp, hp_before + 120.0) and is_equal_approx(c.player.health.hp_deficit(), debt), "four contributions, debt preserved")
	var replay := c.run_state.card_inventory.grant(&"bulwark_card", c.run_state.effect_catalog(), "card-acquisition-0")
	_check(replay.get("already_applied", false) and replay["card_instance_id"] == cards[0] and c.run_state.card_inventory.describe()["owned"].size() == 4, "same acquisition id replays once")
	var before_disk := F.disk(f)
	var before_cards := c.run_state.card_inventory.describe()
	_check(F.change(f, &"socket", {"equipment_instance_id": armor, "socket_index": 4, "card_instance_id": cards[0]})["error_code"] == &"invalid_socket_index" and F.disk(f) == before_disk and c.run_state.card_inventory.describe() == before_cards, "invalid fifth index is atomic")
	var charm := F.item(f, &"traveler_charm")
	_check(F.change(f, &"socket", {"equipment_instance_id": charm, "socket_index": 0, "card_instance_id": cards[0]})["error_code"] == &"socket_not_allowed", "jewelry cannot socket")
	_check(F.change(f, &"equip", {"slot": &"main_hand", "equipment_instance_id": wand})["ok"] and F.change(f, &"equip", {"slot": &"off_hand", "equipment_instance_id": shield})["ok"], "one hand plus shield")
	_check(F.change(f, &"transfer", {"from_equipment_instance_id": armor, "from_socket_index": 0, "equipment_instance_id": shield, "socket_index": 3, "card_instance_id": cards[0]})["ok"] and c.run_state.card_inventory.sockets()[shield][3] == cards[0] and c.run_state.card_inventory.sockets()[armor][0] == null, "transfer by exact indices")
	before_disk = F.disk(f)
	var equipped := c.run_state.build_snapshot.equipped.duplicate(true)
	_check(F.change(f, &"equip", {"slot": &"main_hand", "equipment_instance_id": F.item(f, &"starter_staff")})["error_code"] == &"invalid_hand_configuration" and F.disk(f) == before_disk and c.run_state.build_snapshot.equipped == equipped, "two hands rejects shield without partial write")
	_check(F.change(f, &"equip", {"slot": &"off_hand", "equipment_instance_id": focus})["ok"] and c.run_state.card_inventory.sockets()[shield][3] == cards[0] and not c.run_state.effect_state()["card_sockets"].has(shield), "desequipped shield keeps physical card and removes active effect")
	_check(F.change(f, &"socket", {"equipment_instance_id": focus, "socket_index": 0, "card_instance_id": cards[0]})["error_code"] == &"socket_not_allowed", "focus cannot socket")
	_check(F.change(f, &"unequip", {"slot": &"torso"})["ok"] and c.run_state.card_inventory.describe()["free"].is_empty() and c.run_state.effect_state()["card_sockets"].is_empty() and is_equal_approx(c.player.health.hp_deficit(), debt), "unequip retains all sockets without active effects or healing")
	_check(F.change(f, &"equip", {"slot": &"accessory_2", "equipment_instance_id": charm})["error_code"] == &"duplicate_equipment_instance", "same exemplar cannot occupy two positions")
	var another_charm: StringName = &""
	for id: StringName in facade.current_profile().equipment_instance_ids():
		if facade.current_profile().equipment_instances[id].definition_id == &"traveler_charm" and id != charm:
			another_charm = id
	var duplicate_disk := F.disk(f)
	_check(not another_charm.is_empty() and F.change(f, &"equip", {"slot": &"accessory_2", "equipment_instance_id": another_charm})["error_code"] == &"identical_accessory" and F.disk(f) == duplicate_disk, "distinct copies of identical accessory reject without partial save")
	var copied := c.run_state.build_snapshot.copy_snapshot()
	copied.equipment_instances[wand].socket_capacity = 0
	_check(c.run_state.build_snapshot.equipment_instances[wand].socket_capacity == 1, "snapshot metadata is copied")
	var reward_catalog := ProfileRewardResolver.new({&"fixture_repeat": {"equipment_ids": [&"warden_mail", &"warden_mail"]}})
	_check(reward_catalog.resolve(&"fixture_repeat")["reward"]["equipment_ids"].size() == 2, "reward table retains separate acquisitions")
	_check(not EquipmentRules.validate_definition({"slot": false, "item_kind": &"weapon", "hand_usage": &"one_hand"})["ok"], "malformed metadata is rejected before conversion")
	var invalid_catalog := c.run_state.effect_catalog()
	var invalid_item := EquipmentDefinition.new()
	invalid_item.id = &"invalid_acquisition_fixture"
	invalid_item.allowed_origins = [&"mage"]
	_check(invalid_catalog.register_definition(&"equipment", invalid_item)["ok"] and c.run_state.set_effect_catalog(invalid_catalog)["ok"], "unused recipe fixture isolated from acquired exemplars")
	var rng_before := c.rng.state
	var acquisition_disk := F.disk(f)
	var rejected := c.reward_service.issue("invalid-acquisition", &"encounter_two", true)
	_check(not rejected["ok"] and c.rng.state == rng_before and not c.reward_service.has_uncollected() and F.disk(f) == acquisition_disk, "invalid acquisition metadata creates no ticket RNG or save")
	c.queue_free()
	await process_frame
	print("E06 TX1 inventory: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
