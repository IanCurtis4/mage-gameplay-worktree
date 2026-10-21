class_name MigrationPlan
extends RefCounted
## Pure assistive migration; suggestions never become confirmed assignments.
const POLICY_REVISION := "assisted_character_assets_v1"

static func canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		var entries: Array[String] = []
		for key: Variant in keys: entries.append(JSON.stringify(String(key)) + ":" + canonical(value[key]))
		return "{" + ",".join(entries) + "}"
	if value is Array:
		var entries: Array[String] = []
		for item: Variant in value: entries.append(canonical(item))
		return "[" + ",".join(entries) + "]"
	return JSON.stringify(value)

static func digest(plan: Dictionary) -> String:
	return canonical(plan).sha256_text()

static func dry_run(source_text: String, catalog: ProfileCatalog = null, assignments: Dictionary = {}) -> Dictionary:
	var decoded := ProfileCodec.decode(source_text, catalog)
	if decoded.get("error_code") != &"migration_required" or not decoded.has("legacy_profile"):
		return decoded if not decoded.get("ok", false) else BuildEffectCatalog.failure(&"migration_not_required")
	var source: ProfileState = decoded["legacy_profile"]
	for key: String in ProfileCodec.OWNERSHIP_FIELDS:
		if source.extension_fields.has(key): return BuildEffectCatalog.failure(&"reserved_migration_field")
	for character: CharacterState in source.characters:
		if character.extension_fields.has("gold"): return BuildEffectCatalog.failure(&"reserved_migration_field")
	for key: Variant in assignments:
		if not key is String or not assignments[key] is String or source.character_by_id(assignments[key]) == null: return BuildEffectCatalog.failure(&"invalid_destination")
	var destinations := assignments.duplicate(true)
	var suggestions := {}
	var references := {}
	var all_ids: Array[String] = []
	for id: StringName in source.equipment_instance_ids():
		var owners: Array[String] = []
		for character: CharacterState in source.characters:
			var referenced := id in character.equipped.values()
			for preset: Dictionary in character.presets: referenced = referenced or id in preset["equipped"].values()
			if referenced: owners.append(character.character_id)
		owners.sort()
		references[String(id)] = owners
		suggestions[String(id)] = owners[0] if owners.size() == 1 else ""
		all_ids.append(String(id))
	for id: StringName in source.card_inventory.describe()["owned"]:
		all_ids.append(String(id))
		suggestions[String(id)] = ""
	for host: Variant in source.card_inventory.sockets():
		for card: Variant in source.card_inventory.sockets()[host]:
			if card == null: continue
			if destinations.has(String(host)):
				if destinations.has(String(card)) and destinations[String(card)] != destinations[String(host)]: return BuildEffectCatalog.failure(&"host_owner_mismatch")
				destinations[String(card)] = destinations[String(host)]
			suggestions[String(card)] = suggestions[String(host)]
	for id: Variant in destinations:
		if id not in all_ids: return BuildEffectCatalog.failure(&"unknown_asset")
	var missing: Array[String] = []
	for id: String in all_ids:
		if not destinations.has(id): missing.append(id)
	missing.sort()
	var removals: Array[Dictionary] = []
	for character: CharacterState in source.characters:
		var layouts: Array[Dictionary] = [character.equipped]
		for preset: Dictionary in character.presets: layouts.append(preset["equipped"])
		for index: int in layouts.size():
			for slot: StringName in IdentityIds.equipment_slots():
				var item: Variant = layouts[index][slot]
				if item != null and destinations.has(String(item)) and destinations[String(item)] != character.character_id:
					removals.append({"character_id": character.character_id, "layout": index - 1, "slot": String(slot), "instance_id": String(item)})
	var warnings: Array[String] = ["legacy_gold_initialized_zero"]
	if not missing.is_empty(): warnings.append("missing_asset_destinations")
	if source.characters.is_empty() and not all_ids.is_empty(): warnings.append("no_destination_character")
	if decoded["historical_changes"]["converted"]: warnings.append("historical_conversion")
	var preserved_fields: Array[String] = ["existing_asset_ids", "equipment_metadata", "card_sockets", "acquisition_counters", "acquisition_receipts", "existing_identity", "unknown_fields", "source_archive"]
	var plan := {"warnings": warnings, "preserved_fields": preserved_fields, "historical_changes": decoded["historical_changes"].duplicate(true), "policy_revision": POLICY_REVISION, "source_digest": source_text.sha256_text(), "source_revision": source.revision, "profile_id": source.profile_id, "destinations": destinations, "suggestions": suggestions, "references": references, "removals": removals, "missing": missing, "gold_initial": 0}
	return {"ok": true, "plan": plan, "plan_digest": digest(plan), "complete": missing.is_empty()}

static func validate(plan: Dictionary, source_text: String, catalog: ProfileCatalog = null) -> Dictionary:
	if plan.get("source_digest") != source_text.sha256_text(): return BuildEffectCatalog.failure(&"source_changed")
	if not plan.get("destinations") is Dictionary: return BuildEffectCatalog.failure(&"invalid_migration_plan")
	var rebuilt := dry_run(source_text, catalog, plan["destinations"])
	if not rebuilt.get("ok", false): return rebuilt
	if canonical(rebuilt["plan"]) != canonical(plan): return BuildEffectCatalog.failure(&"invalid_migration_plan")
	if not rebuilt["complete"]: return BuildEffectCatalog.failure(&"incomplete_migration_map")
	return {"ok": true}

static func apply(plan: Dictionary, source_text: String, confirmed_digest: String, request_id: String, catalog: ProfileCatalog = null) -> Dictionary:
	if not CharacterAssets.valid_request(request_id): return BuildEffectCatalog.failure(&"invalid_request_id")
	if confirmed_digest != digest(plan): return BuildEffectCatalog.failure(&"confirmation_required")
	var valid := validate(plan, source_text, catalog)
	if not valid["ok"]: return valid
	var decoded := ProfileCodec.decode(source_text, catalog)
	var candidate: ProfileState = decoded["legacy_profile"].copy_state()
	for id: StringName in candidate.equipment_instances: candidate.equipment_instances[id].owner_character_id = plan["destinations"][String(id)]
	for id: StringName in candidate.card_inventory.describe()["owned"]: candidate.card_inventory._owners[id] = plan["destinations"][String(id)]
	for character: CharacterState in candidate.characters:
		character.gold = 0
		var layouts: Array[Dictionary] = [character.equipped]
		for preset: Dictionary in character.presets: layouts.append(preset["equipped"])
		for layout: Dictionary in layouts:
			for slot: StringName in IdentityIds.equipment_slots():
				var id: Variant = layout[slot]
				if id != null and plan["destinations"][String(id)] != character.character_id: layout[slot] = null
	candidate.ownership_migration_required = false
	candidate.migration_receipt = {"source_digest": source_text.sha256_text(), "plan_digest": confirmed_digest, "request_id": request_id, "policy_revision": POLICY_REVISION}
	var checked := ProfileCodec.validate_profile(candidate, catalog)
	if not checked["ok"]: return checked
	return {"ok": true, "profile": candidate}
