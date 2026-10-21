class_name CharacterAssets
extends RefCounted
## Pure ownership authority. Durable mutation is delegated to ProfileFacade/Store.

static func validate(profile: ProfileState) -> Dictionary:
	for id: StringName in profile.equipment_instances:
		var item: EquipmentInstance = profile.equipment_instances[id]
		if profile.character_by_id(item.owner_character_id) == null: return BuildEffectCatalog.failure(&"invalid_owner")
	for id: StringName in profile.card_inventory.describe()["owned"]:
		if profile.character_by_id(profile.card_inventory.owner_of(id)) == null: return BuildEffectCatalog.failure(&"invalid_owner")
	for host: Variant in profile.card_inventory.sockets():
		if not profile.equipment_instances.has(host): return BuildEffectCatalog.failure(&"invalid_owner")
		for card: Variant in profile.card_inventory.sockets()[host]:
			if card != null and profile.card_inventory.owner_of(card) != profile.equipment_instances[host].owner_character_id: return BuildEffectCatalog.failure(&"not_owner")
	for character: CharacterState in profile.characters:
		if character.gold < 0 or character.gold > EquipmentRules.MAX_EXACT_INTEGER: return BuildEffectCatalog.failure(&"invalid_gold")
		var layouts: Array[Dictionary] = [character.equipped]
		for preset: Dictionary in character.presets: layouts.append(preset["equipped"])
		for layout: Dictionary in layouts:
			for id: Variant in layout.values():
				if id != null and (not profile.equipment_instances.has(id) or profile.equipment_instances[id].owner_character_id != character.character_id): return BuildEffectCatalog.failure(&"not_owner")
	var seen := {}
	for id: String in profile.expeditions:
		var slot: ExpeditionAssetLock = profile.expeditions[id]
		var check := ExpeditionAssetLock.from_record(slot.to_record())
		if not check.get("ok", false) or id != slot.expedition_id or profile.character_by_id(slot.character_id) == null or seen.has(slot.character_id): return BuildEffectCatalog.failure(&"expedition_conflict")
		seen[slot.character_id] = true
	for id: StringName in profile.profile_unlocks:
		if not IdentityIds.is_technical_id(String(id)) or not profile.profile_unlocks[id]: return BuildEffectCatalog.failure(&"invalid_unlock")
	for id: Variant in profile.asset_receipts:
		var receipt: Variant = profile.asset_receipts[id]
		if not id is String or not valid_request(id) or not receipt is Dictionary or receipt.size() != 3 or not valid_digest(receipt.get("fingerprint")) or not receipt.get("character_id") is String or profile.character_by_id(receipt["character_id"]) == null or not receipt.get("data") is Dictionary: return BuildEffectCatalog.failure(&"invalid_asset_receipt")
		var data: Dictionary = receipt["data"]
		if data.size() != 2 or not EquipmentRules.exact_integer(data.get("gold"), 0) or not data.get("unlocks") is Dictionary: return BuildEffectCatalog.failure(&"invalid_asset_receipt")
		for unlock: Variant in data["unlocks"]:
			if not unlock is String or not IdentityIds.is_technical_id(unlock) or typeof(data["unlocks"][unlock]) != TYPE_BOOL or not data["unlocks"][unlock]: return BuildEffectCatalog.failure(&"invalid_asset_receipt")
	if not profile.migration_receipt.is_empty():
		if profile.migration_receipt.size() != 4: return BuildEffectCatalog.failure(&"invalid_migration_receipt")
		for key: String in ["source_digest", "plan_digest", "request_id", "policy_revision"]:
			if not profile.migration_receipt.get(key) is String or profile.migration_receipt[key].is_empty(): return BuildEffectCatalog.failure(&"invalid_migration_receipt")
		if not valid_digest(profile.migration_receipt["source_digest"]) or not valid_digest(profile.migration_receipt["plan_digest"]) or not valid_request(profile.migration_receipt["request_id"]) or profile.migration_receipt["policy_revision"] != MigrationPlan.POLICY_REVISION: return BuildEffectCatalog.failure(&"invalid_migration_receipt")
	return {"ok": true}

static func check_intent(profile: ProfileState, character_id: String, intent: Dictionary) -> Dictionary:
	if profile.ownership_migration_required: return BuildEffectCatalog.failure(&"migration_required")
	if profile.character_by_id(character_id) == null: return BuildEffectCatalog.failure(&"invalid_character_id")
	if profile.expedition_for_character(character_id) != null: return BuildEffectCatalog.failure(&"locked_by_expedition")
	for key: String in ["equipment_instance_id", "from_equipment_instance_id"]:
		var id := StringName(intent.get(key, &""))
		if not id.is_empty() and profile.equipment_instances.has(id) and profile.equipment_instances[id].owner_character_id != character_id: return BuildEffectCatalog.failure(&"not_owner")
	var card := StringName(intent.get("card_instance_id", &""))
	if profile.card_inventory.owns(card) and profile.card_inventory.owner_of(card) != character_id: return BuildEffectCatalog.failure(&"not_owner")
	return {"ok": true}

static func query(profile: ProfileState, character_id: String) -> Dictionary:
	if profile == null or profile.character_by_id(character_id) == null: return BuildEffectCatalog.failure(&"invalid_character_id")
	if profile.ownership_migration_required: return BuildEffectCatalog.failure(&"migration_required")
	var equipment := profile.equipment_for_character(character_id)
	return {"ok": true, "error_code": &"", "revision": profile.revision, "character_id": character_id, "gold": profile.character_by_id(character_id).gold, "equipment_instances": equipment, "inventory": profile.card_inventory.for_character(character_id, equipment).describe(), "unlocks": profile.profile_unlocks.duplicate(), "locked": profile.expedition_for_character(character_id) != null}

static func validate_transition(before: ProfileState, after: ProfileState) -> Dictionary:
	for id: StringName in before.equipment_instances:
		if not after.equipment_instances.has(id) or before.equipment_instances[id].owner_character_id != after.equipment_instances[id].owner_character_id: return BuildEffectCatalog.failure(&"not_owner")
	for id: StringName in before.card_inventory.describe()["owned"]:
		if not after.card_inventory.owns(id) or before.card_inventory.owner_of(id) != after.card_inventory.owner_of(id): return BuildEffectCatalog.failure(&"not_owner")
	for id: StringName in before.profile_unlocks:
		if not after.profile_unlocks.has(id): return BuildEffectCatalog.failure(&"invalid_unlock")
	for id: Variant in before.asset_receipts:
		if not after.asset_receipts.has(id) or before.asset_receipts[id] != after.asset_receipts[id]: return BuildEffectCatalog.failure(&"request_conflict")
	if before.migration_receipt != after.migration_receipt: return BuildEffectCatalog.failure(&"invalid_migration_receipt")
	for acquisition: Variant in before.card_inventory._grants:
		if not after.card_inventory._grants.has(acquisition) or before.card_inventory._grants[acquisition] != after.card_inventory._grants[acquisition]: return BuildEffectCatalog.failure(&"request_conflict")
	for character: CharacterState in before.characters:
		if before.expedition_for_character(character.character_id) == null: continue
		var changed := after.character_by_id(character.character_id)
		if changed == null or ProfileCodec._character_to_dictionary(character) != ProfileCodec._character_to_dictionary(changed) or changed.gold < character.gold: return BuildEffectCatalog.failure(&"locked_by_expedition")
		var old_cards := before.card_inventory.for_character(character.character_id, before.equipment_for_character(character.character_id))
		var new_cards := after.card_inventory.for_character(character.character_id, after.equipment_for_character(character.character_id))
		if old_cards.sockets() != new_cards.sockets(): return BuildEffectCatalog.failure(&"locked_by_expedition")
	return {"ok": true}

static func _preview(profile: ProfileState, character_id: String, intent: Dictionary, request_id: String, expected_revision: int) -> Dictionary:
	if not valid_request(request_id): return BuildEffectCatalog.failure(&"invalid_request_id")
	if profile == null: return BuildEffectCatalog.failure(&"profile_unavailable")
	var fingerprint := MigrationPlan.canonical({"character_id": character_id, "intent": intent}).sha256_text()
	if profile.asset_receipts.has(request_id):
		var receipt: Dictionary = profile.asset_receipts[request_id]
		if receipt["fingerprint"] != fingerprint: return BuildEffectCatalog.failure(&"request_conflict")
		return {"ok": true, "already_applied": true, "data": receipt["data"].duplicate(true), "request_id": request_id, "revision": profile.revision}
	if expected_revision != profile.revision: return BuildEffectCatalog.failure(&"stale_revision")
	var boundary := check_intent(profile, character_id, {})
	if not boundary["ok"]: return boundary
	var candidate := profile.copy_state()
	var character := candidate.character_by_id(character_id)
	var kind: Variant = intent.get("kind")
	if kind in ["credit_gold", "spend_gold"]:
		if intent.size() != 2 or typeof(intent.get("amount")) != TYPE_INT or intent["amount"] <= 0 or intent["amount"] > EquipmentRules.MAX_EXACT_INTEGER: return BuildEffectCatalog.failure(&"invalid_gold")
		var amount: int = intent["amount"]
		if kind == "spend_gold":
			if amount > character.gold: return BuildEffectCatalog.failure(&"insufficient_gold")
			character.gold -= amount
		else:
			if amount > EquipmentRules.MAX_EXACT_INTEGER - character.gold: return BuildEffectCatalog.failure(&"gold_overflow")
			character.gold += amount
	elif kind == "unlock":
		if intent.size() != 2 or not intent.get("unlock_id") is String or not IdentityIds.is_technical_id(intent["unlock_id"]): return BuildEffectCatalog.failure(&"invalid_unlock")
		candidate.profile_unlocks[StringName(intent["unlock_id"])] = true
	else: return BuildEffectCatalog.failure(&"invalid_intent")
	var data := {"gold": character.gold, "unlocks": ProfileCodec._integer_map_to_dictionary(candidate.profile_unlocks)}
	candidate.asset_receipts[request_id] = {"fingerprint": fingerprint, "character_id": character_id, "data": data.duplicate(true)}
	return {"ok": true, "error_code": &"", "candidate": candidate, "data": data, "request_id": request_id, "revision": profile.revision}

static func commit(facade: ProfileFacade, character_id: String, intent: Dictionary, request_id: String, expected_revision: int) -> Dictionary:
	return facade.commit_assets(character_id, intent, request_id, expected_revision)


static func preview(profile: ProfileState, character_id: String, intent: Dictionary, request_id: String, expected_revision: int) -> Dictionary:
	var result := _preview(profile, character_id, intent, request_id, expected_revision)
	result["request_id"] = request_id
	result["revision"] = profile.revision if profile != null else -1
	if not result.has("error_code"): result["error_code"] = &"" if result.get("ok", false) else &"invalid_payload"
	if not result.has("data"): result["data"] = {}
	return result


static func valid_request(id: String) -> bool:
	if id.is_empty() or id.length() > 64: return false
	for index: int in id.length():
		if id.unicode_at(index) < 32 or id.unicode_at(index) == 127: return false
	return true

static func valid_digest(value: Variant) -> bool:
	return value is String and value.length() == 64 and value == value.to_lower() and value.is_valid_hex_number(false)
