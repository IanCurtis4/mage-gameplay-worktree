extends "res://tests/fixtures/e07/f2/suite.gd"
func _run() -> void:
	var f := F.make("ownership")
	var facade: ProfileFacade = f["facade"]
	var profile := facade.current_profile()
	var a: String = f["a"]; var b: String = f["b"]
	var foreign := F.item(profile, b, &"starter_staff")
	var own := F.item(profile, a, &"starter_staff")
	check(own != foreign, "same starter definition creates distinct owned exemplars")
	var options := facade.available_build_options(a)
	check(own in options["equipment_by_slot"][&"main_hand"] and foreign not in options["equipment_by_slot"][&"main_hand"], "options are owner-scoped")
	var assets := facade.assets_for_character(a)
	check(assets["equipment_instances"].size() * 2 == profile.equipment_instances.size() and assets["inventory"]["owned"].size() == 2, "owner query exposes only own equipment and cards")
	assets["equipment_instances"].clear(); assets["inventory"]["owned"].clear()
	check(facade.assets_for_character(a)["inventory"]["owned"].size() == 2, "query DTO cannot mutate authority")
	var intent := {"kind": &"equip", "equipment_instance_id": foreign, "slot": &"main_hand", "request_id": "foreign", "profile_revision": profile.revision}
	check(facade.preview_inventory_change(a, intent).get("error_code") == &"not_owner", "foreign equip preview rejected")
	check(facade.commit_inventory_change(a, intent).get("error_code") == &"not_owner", "foreign equip commit rejected")
	intent = {"kind": &"socket", "equipment_instance_id": own, "card_instance_id": F.card(profile, b, &"echo_card"), "socket_index": 0, "request_id": "foreign_card", "profile_revision": profile.revision}
	check(facade.commit_inventory_change(a, intent).get("error_code") == &"not_owner", "foreign card rejected")
	var forged := profile.character_by_id(a).copy_state()
	forged.presets[0]["equipped"][&"main_hand"] = foreign
	var snap := BuildSnapshot.from_character(forged, 1, 1, {}, [], null, profile.equipment_instances)
	check(not snap.equipment_instances.has(foreign) and snap.equipped[&"main_hand"] == null, "snapshot cannot compose a foreign exemplar")
	var bad := profile.copy_state()
	bad.character_by_id(a).presets[1]["equipped"][&"main_hand"] = foreign
	check(ProfileCodec.encode(bad).get("error_code") == &"not_owner", "inactive presets also enforce ownership")
	var encoded := ProfileCodec.encode(profile)
	check(encoded["ok"] and encoded["data"]["schema_version"] == 8, "schema 8 emitted")
	var decoded := ProfileCodec.decode(encoded["text"])
	check(decoded["ok"] and ProfileCodec.encode(decoded["profile"])["text"] == encoded["text"], "owned schema roundtrip exact")
	var raw: Dictionary = encoded["data"].duplicate(true)
	raw["equipment_instances"][0]["owner_character_id"] = "missing"
	check(not ProfileCodec.decode(JSON.stringify(raw))["ok"], "unknown equipment owner refused")
	raw = encoded["data"].duplicate(true); raw["card_inventory"]["owners"].clear()
	check(not ProfileCodec.decode(JSON.stringify(raw))["ok"], "incomplete card owner map refused")
	for amount: Variant in [-1, 0.5, true, 9007199254740992.0]:
		raw = encoded["data"].duplicate(true); raw["characters"][0]["gold"] = amount
		check(not ProfileCodec.decode(JSON.stringify(raw))["ok"], "invalid wallet exact integer refused")
	check(facade.preview_assets(a, {"kind": "credit_gold", "amount": 10}, "gold", profile.revision)["ok"] and facade.current_profile().character_by_id(a).gold == 0, "wallet preview pure")
	check(facade.commit_assets(a, {"kind": "credit_gold", "amount": 10}, "gold", profile.revision)["ok"], "wallet credit uses same writer")
	check(facade.commit_assets(a, {"kind": "credit_gold", "amount": 10}, "gold", profile.revision).get("already_applied", false), "wallet retry idempotent even with old revision")
	check(facade.commit_assets(a, {"kind": "credit_gold", "amount": 11}, "gold", facade.current_profile().revision).get("error_code") == &"request_conflict", "request reuse with different payload conflicts")
	check(facade.commit_assets(a, {"kind": "spend_gold", "amount": 11}, "spend", facade.current_profile().revision).get("error_code") == &"insufficient_gold", "spend cannot underflow")
	check(facade.commit_assets(a, {"kind": "credit_gold", "amount": EquipmentRules.MAX_EXACT_INTEGER}, "overflow", facade.current_profile().revision).get("error_code") == &"gold_overflow", "credit cannot overflow exact codec range")
	check(facade.commit_assets(a, {"kind": "unlock", "unlock_id": "phase_fixture"}, "unlock", facade.current_profile().revision)["ok"], "unlock persisted once at profile")
	check(facade.assets_for_character(b)["unlocks"].has(&"phase_fixture") and facade.assets_for_character(b)["gold"] == 0, "alts share unlock but not wallet")
	var store: ProfileStore = f["store"]
	profile = facade.current_profile()
	var slot := ExpeditionAssetLock.new(); slot.expedition_id = "exp_fixture"; slot.character_id = a; slot.phase_id = &"phase_fixture"
	profile.expeditions[slot.expedition_id] = slot
	check(store.commit(profile)["ok"], "typed reservation accepted")
	facade = ProfileFacade.new(store); check(facade.open_profile()["ok"], "suspended slot opens without reset")
	profile = facade.current_profile()
	check(facade.assets_for_character(a)["locked"], "lock query comes from authority")
	check(facade.commit_assets(a, {"kind": "spend_gold", "amount": 1}, "locked_spend", profile.revision).get("error_code") == &"locked_by_expedition", "wallet spend locked")
	check(facade.select_preset("locked_preset", profile.revision, a, 1).get("error_code") == &"locked_by_expedition", "preset mutation locked")
	check(facade.start_run("locked_start", profile.revision).get("error_code") == &"locked_by_expedition", "new run locked")
	check(facade.update_action_slots("locked_actions", profile.revision, a, ActionBarLayout.empty()).get("error_code") == &"locked_by_expedition", "action build locked")
	check(facade.commit_assets(b, {"kind": "credit_gold", "amount": 2}, "alt_free", profile.revision)["ok"], "alt remains free")
	var direct := facade.current_profile(); direct.character_by_id(a).display_name = "forged"
	check(store.commit(direct).get("error_code") == &"locked_by_expedition", "writer also enforces lock")
	direct = facade.current_profile(); direct.equipment_instances[own].owner_character_id = b
	check(not store.commit(direct)["ok"], "writer cannot transfer existing property")
	direct = facade.current_profile(); var duplicate := slot.copy_lock(); duplicate.expedition_id = "exp_second"; direct.expeditions[duplicate.expedition_id] = duplicate
	check(not ProfileCodec.encode(direct)["ok"], "one pending expedition per character")
	var skill_preview := facade.skill_allocation_preview(a, facade.current_profile().revision, [])
	check(skill_preview["ok"] and not skill_preview["can_apply"] and skill_preview["locked_by_expedition"], "skill draft exposes same lock as commit")
	var attribute_preview := facade.attribute_purchase_preview(a, &"str")
	check(attribute_preview["ok"] and not attribute_preview["can_purchase"] and attribute_preview["blocking_reason"] == &"locked_by_expedition", "attribute preview exposes same lock as commit")
	var evolution_preview := facade.evolution_options(a)
	check(evolution_preview["options"].all(func(row: Dictionary) -> bool: return not row["can_select"] and &"locked_by_expedition" in row["blocking_reasons"]), "evolution preview exposes same lock as commit")
	var tampered := facade.current_profile(); tampered.asset_receipts.clear()
	check((f["store"] as ProfileStore).commit(tampered).get("error_code") == &"request_conflict", "writer cannot erase replay receipts")
	var maximum := F.make("maximum_wallet")
	var max_facade: ProfileFacade = maximum["facade"]
	check(max_facade.commit_assets(maximum["a"], {"kind": "credit_gold", "amount": EquipmentRules.MAX_EXACT_INTEGER}, "max", max_facade.current_profile().revision)["ok"], "maximum exact integer accepted")
	var loaded := ProfileStore.new(maximum["directory"]).load_profile()
	check(loaded["ok"] and loaded["profile"].character_by_id(maximum["a"]).gold == EquipmentRules.MAX_EXACT_INTEGER, "maximum wallet survives JSON without rounding")
	check(max_facade.commit_assets(maximum["a"], {"kind": "spend_gold", "amount": EquipmentRules.MAX_EXACT_INTEGER}, "empty", max_facade.current_profile().revision)["ok"] and max_facade.current_profile().character_by_id(maximum["a"]).gold == 0, "maximum spend reaches zero exactly")
	check(BuildPresentation.error_text(&"not_owner") == "Este item pertence a outro personagem.", "ownership error is translated for existing consumers")
	check(BuildPresentation.error_text(&"locked_by_expedition").contains("expedição"), "lock error is translated for existing consumers")
	finish()
