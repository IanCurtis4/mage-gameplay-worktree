class_name ProfileCodec
extends RefCounted
## Owned schema-8 envelope; closed historical schema-7 reader precedes assisted migration.

const LEGACY_SCHEMA_VERSION := 7
const OWNERSHIP_FIELDS := ["profile_unlocks", "expeditions", "asset_receipts", "migration_receipt"]
const MAX_FILE_BYTES := 4 * 1024 * 1024
const MAX_EXACT_JSON_INTEGER := 9007199254740991
const LEGACY_CATALOG_VERSION := 1
const LEGACY_RULESET_ID := "e00_v1"
const PRE_DEFENDER_CATALOG_VERSION := 2
const PRE_BERSERKER_CATALOG_VERSION := 3
const PRE_ELEMENTALIST_CATALOG_VERSION := 4
const PRE_SPIRITUALIST_CATALOG_VERSION := 5
const PRE_THRESHOLDS_CATALOG_VERSION := 6
const PRE_HUNTER_CATALOG_VERSION := 7
const PRE_INVENTORY_CATALOG_VERSION := 8
const PRE_THRESHOLDS_RULESET_ID := "e04_learn_from_zero_v1"
const LEGACY_BASE_GRANTS := {
	"swordsman": {"slash": 1, "dash": 1, "swordsman_resistance": 1},
	"mage": {"fireball": 1, "fire_wall": 1, "mage_mana_regeneration": 1},
}
const LEGACY_ROOT_FIELDS := [
	"format_id", "schema_version", "catalog_version", "ruleset_id", "profile_id",
	"revision", "next_character_counter", "next_run_counter", "selected_character_id",
	"equipment_collection", "characters", "settings", "lifetime_stats",
	"reward_session", "legacy_loadouts", "unresolved_legacy",
]
const ROOT_FIELDS := [
	"format_id", "schema_version", "catalog_version", "ruleset_id", "profile_id",
	"revision", "next_character_counter", "next_run_counter", "next_equipment_counter", "selected_character_id",
	"equipment_instances", "card_inventory", "characters", "settings", "lifetime_stats",
	"reward_session", "legacy_loadouts", "unresolved_legacy",
]
const CHARACTER_FIELDS := [
	"character_id", "display_name", "base_class_id", "evolution_id", "base_xp_total",
	"job_xp_total", "attribute_allocations", "granted_skill_ranks", "purchased_skill_ranks", "equipped",
	"presets", "selected_preset", "action_slots",
	"admin_skills_unlocked",
]
const FORBIDDEN_RUNTIME_FIELDS := [
	"run_state", "build_snapshot", "current_hp", "max_hp", "current_sp", "max_sp",
	"mana", "cooldowns", "effects", "augment_stacks", "cards", "card_sockets",
	"current_offer", "pending_choices", "rng", "enemies", "phase", "encounter",
]

static func encode(profile: ProfileState, catalog: ProfileCatalog = null) -> Dictionary:
	var effective_catalog := catalog if catalog != null else ProfileCatalog.pilot()
	if not effective_catalog.is_valid():
		return _catalog_error(&"invalid_catalog")
	var validation := validate_profile(profile, effective_catalog)
	if not validation["ok"]:
		return validation
	var payload := owned_dictionary(profile)
	if not _is_json_value(payload):
		return _error(&"invalid_json_value")
	var text := JSON.stringify(payload, "\t")
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return _error(&"profile_too_large")
	return {"ok": true, "text": text, "data": payload}

static func _decode_legacy(text: String, catalog: ProfileCatalog = null) -> Dictionary:
	var effective := catalog if catalog != null else ProfileCatalog.pilot()
	var json := JSON.new()
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES or json.parse(text) != OK or not json.data is Dictionary:
		return _decode_envelope(text, effective)
	var data: Dictionary = json.data
	if _is_exact_integer(data.get("schema_version")) and int(data["schema_version"]) < 7 and data.get("characters") is Array:
		if data.has("playtest_admin_receipts_v1"):
			return _error(&"invalid_admin_receipts")
		for raw_character: Variant in data["characters"]:
			if raw_character is Dictionary and raw_character.has("admin_skills_unlocked"):
				return _error(&"invalid_admin_skills_unlocked")
	var historical := _is_exact_integer(data.get("schema_version")) and (int(data["schema_version"]) <= 5 or (int(data["schema_version"]) == 6 and _is_exact_integer(data.get("catalog_version")) and int(data["catalog_version"]) in [12, 13]))
	if not historical:
		return _decode_envelope(text, effective, true)
	var old_catalog := effective.pre_all_skill_dependencies_catalog()
	var input := data.duplicate(true)
	if int(input["schema_version"]) == 6:
		input["catalog_version"] = ProfileState.CATALOG_VERSION
	var decoded: Dictionary
	if int(data["schema_version"]) == 6 and int(data["catalog_version"]) == 13:
		decoded = _decode_envelope(JSON.stringify(input), old_catalog)
	else:
		decoded = _decode_previous_skill_tree(input, old_catalog)
	if not decoded.get("ok", false): return decoded
	var profile: ProfileState = decoded["profile"]
	var reports: Array[Dictionary] = []
	for previous: Dictionary in decoded.get("migration_removals", []):
		reports.append({"character_id": previous["character_id"], "removed": previous["removed"].duplicate(true), "base_refund": 0, "evolution_refund": previous["evolution_refund"]})
	for character: CharacterState in profile.characters:
		var report := CharacterProgression.refund_all_skill_dependencies(character, effective)
		if not report["removed"].is_empty():
			report["character_id"] = character.character_id
			var merged := false
			for previous: Dictionary in reports:
				if previous["character_id"] != character.character_id:
					continue
				previous["removed"].append_array(report["removed"])
				previous["base_refund"] += report["base_refund"]
				previous["evolution_refund"] += report["evolution_refund"]
				merged = true
				break
			if not merged:
				reports.append(report)
	if not reports.is_empty():
		profile.extension_fields["all_skill_dependencies_migration"] = JSON.parse_string(JSON.stringify({"catalog_version": ProfileState.CATALOG_VERSION, "characters": reports}))
	var valid := _validate_legacy_profile(profile, effective)
	if not valid.get("ok", false): return valid
	decoded["migrated"] = true
	var previous_kind: StringName = decoded.get("migration_kind", &"")
	var kinds: Array = decoded.get("migration_kinds", []).duplicate()
	if not previous_kind.is_empty() and previous_kind not in kinds:
		kinds.append(previous_kind)
	if &"all_skill_dependencies_v1" not in kinds:
		kinds.append(&"all_skill_dependencies_v1")
	decoded["migration_kinds"] = kinds
	if int(data["schema_version"]) == 6 and int(data["catalog_version"]) == 13:
		decoded["migration_kind"] = &"all_skill_dependencies_v1"
	decoded["migration_removals"] = reports.duplicate(true)
	return decoded

static func _decode_previous_skill_tree(input: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	var decoded := _decode_envelope(JSON.stringify(input), catalog.pre_swordsman_cluster_catalog())
	if not decoded.get("ok", false):
		return decoded
	var profile: ProfileState = decoded["profile"]
	var reports: Array[Dictionary] = []
	for character: CharacterState in profile.characters:
		var retained_action_slots := ActionBarLayout.for_character(character)
		var retained_presets := character.presets.duplicate(true)
		var report := CharacterProgression.refund_illegal_swordsman_ranks(character, catalog)
		character.action_slots = retained_action_slots
		character.presets = retained_presets
		if not report["removed"].is_empty():
			report["cleared_action_slots"] = []
			report["character_id"] = character.character_id
			reports.append(report)
	if not reports.is_empty():
		profile.extension_fields["swordsman_skill_tree_migration"] = JSON.parse_string(JSON.stringify({"catalog_version": 13, "characters": reports}))
	var valid := _decode_envelope(JSON.stringify(_profile_to_dictionary(profile)), catalog, true)
	if not valid.get("ok", false):
		return valid
	var original_kind: StringName = decoded.get("migration_kind", &"")
	if original_kind.is_empty() or original_kind == &"admin_skills_v1":
		decoded["migration_kind"] = &"swordsman_clusters_v1"
	var kinds: Array = []
	if not original_kind.is_empty():
		kinds.append(original_kind)
	if &"swordsman_clusters_v1" not in kinds:
		kinds.append(&"swordsman_clusters_v1")
	decoded["migration_kinds"] = kinds
	decoded["migration_removals"] = reports.duplicate(true)
	return decoded

static func _decode_envelope(text: String, catalog: ProfileCatalog = null, allow_disabled_refs: bool = false) -> Dictionary:
	var effective_catalog := catalog if catalog != null else ProfileCatalog.pilot()
	if not effective_catalog.is_valid():
		return _catalog_error(&"invalid_catalog")
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return _error(&"profile_too_large")
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return _error(&"invalid_json")
	var data: Dictionary = json.data
	if not _is_exact_integer(data.get("schema_version")):
		return _error(&"unsupported_schema")
	var schema_version := int(data["schema_version"])
	if schema_version > LEGACY_SCHEMA_VERSION:
		return {"ok": false, "error_code": &"unsupported_schema", "future_schema": true}
	if schema_version < 6 and data.get("characters") is Array:
		for character: Variant in data["characters"]:
			if character is Dictionary and character.get("action_slots") is Array:
				for value: Variant in character["action_slots"]:
					if value is Dictionary:
						return _error(&"invalid_presets")
	if schema_version < 5 and data.has("card_inventory"):
		return _catalog_error(&"invalid_card_inventory")
	if schema_version == 5:
		if not _is_exact_integer(data.get("catalog_version")) or int(data["catalog_version"]) != 12:
			return _catalog_error(&"invalid_catalog")
		var upgraded := data.duplicate(true)
		upgraded["schema_version"] = LEGACY_SCHEMA_VERSION
		upgraded["catalog_version"] = ProfileState.CATALOG_VERSION
		var migrated := _decode_v2(upgraded, effective_catalog)
		if migrated["ok"]:
			migrated["migrated"] = true
			migrated["migration_kind"] = &"explicit_cast_ranks_v1"
		return migrated
	if schema_version == 4:
		if not _is_exact_integer(data.get("catalog_version")) or int(data["catalog_version"]) != 11:
			return _catalog_error(&"invalid_catalog")
		var upgraded := data.duplicate(true)
		upgraded["schema_version"] = LEGACY_SCHEMA_VERSION
		upgraded["catalog_version"] = ProfileState.CATALOG_VERSION
		var migrated := _decode_v2(upgraded,effective_catalog,false,false,true)
		if migrated["ok"]:
			migrated["migrated"] = true
			migrated["migration_kind"] = &"persistent_cards_v1"
		return migrated
	if schema_version == 1:
		return _upgrade_legacy(_migrate_v1(data, effective_catalog), effective_catalog)
	if schema_version == 3:
		return _migrate_power_v3(data, effective_catalog)
	if schema_version not in [2, 6, LEGACY_SCHEMA_VERSION]:
		return _error(&"unsupported_schema")
	if schema_version in [6, LEGACY_SCHEMA_VERSION]:
		if data.has("equipment_collection"):
			return _catalog_error(&"invalid_catalog")
		var decoded := _decode_v2(data, effective_catalog, false, false, false, allow_disabled_refs, schema_version == 7)
		if decoded["ok"] and schema_version == 6:
			decoded["migrated"] = true
			decoded["migration_kind"] = &"admin_skills_v1"
		return decoded
	if not _is_exact_integer(data.get("catalog_version")) or int(data["catalog_version"]) < 1 or int(data["catalog_version"]) > 9:
		return _catalog_error(&"invalid_catalog")
	for reserved: String in ["equipment_instances", "next_equipment_counter"]:
		if data.has(reserved):
			return _catalog_error(&"invalid_catalog")
	if (
		_is_exact_integer(data.get("catalog_version"))
		and int(data["catalog_version"]) == LEGACY_CATALOG_VERSION
		and data.get("ruleset_id") == LEGACY_RULESET_ID
	):
		return _upgrade_legacy(_migrate_catalog_v1(data, effective_catalog), effective_catalog)
	if (
		_is_exact_integer(data.get("catalog_version"))
		and int(data["catalog_version"]) == PRE_DEFENDER_CATALOG_VERSION
		and data.get("ruleset_id") == PRE_THRESHOLDS_RULESET_ID
	):
		return _upgrade_legacy(_migrate_catalog_v2(data, effective_catalog), effective_catalog)
	if (
		_is_exact_integer(data.get("catalog_version"))
		and int(data["catalog_version"]) == PRE_BERSERKER_CATALOG_VERSION
		and data.get("ruleset_id") == PRE_THRESHOLDS_RULESET_ID
	):
		return _upgrade_legacy(_migrate_catalog_v3(data, effective_catalog), effective_catalog)
	if (
		_is_exact_integer(data.get("catalog_version"))
		and int(data["catalog_version"]) == PRE_ELEMENTALIST_CATALOG_VERSION
		and data.get("ruleset_id") == PRE_THRESHOLDS_RULESET_ID
	):
		return _upgrade_legacy(_migrate_catalog_v4(data, effective_catalog), effective_catalog)
	if (
		_is_exact_integer(data.get("catalog_version"))
		and int(data["catalog_version"]) == PRE_SPIRITUALIST_CATALOG_VERSION
		and data.get("ruleset_id") == PRE_THRESHOLDS_RULESET_ID
	):
		return _upgrade_legacy(_migrate_catalog_v5(data, effective_catalog), effective_catalog)
	if (
		_is_exact_integer(data.get("catalog_version"))
		and int(data["catalog_version"]) == PRE_THRESHOLDS_CATALOG_VERSION
		and data.get("ruleset_id") == PRE_THRESHOLDS_RULESET_ID
	):
		return _upgrade_legacy(_migrate_catalog_v6(data, effective_catalog), effective_catalog)
	if (
		_is_exact_integer(data.get("catalog_version"))
		and int(data["catalog_version"]) == PRE_HUNTER_CATALOG_VERSION
		and data.get("ruleset_id") == ProfileState.RULESET_ID
	):
		return _upgrade_legacy(_migrate_catalog_v7(data, effective_catalog), effective_catalog)
	if _is_exact_integer(data.get("catalog_version")) and int(data["catalog_version"]) == PRE_INVENTORY_CATALOG_VERSION and data.get("ruleset_id") == ProfileState.RULESET_ID:
		return _upgrade_legacy(_migrate_catalog_v8(data, effective_catalog), effective_catalog)
	var normalized := data.duplicate(true)
	normalized["catalog_version"] = ProfileState.CATALOG_VERSION
	return _upgrade_legacy(_decode_v2(normalized, effective_catalog, false, true), effective_catalog)

static func _migrate_power_v3(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	if not _is_exact_integer(data.get("catalog_version")) or int(data["catalog_version"]) != 10 or not data.get("equipment_instances") is Array:
		return _catalog_error(&"invalid_catalog")
	var upgraded := data.duplicate(true)
	for record: Variant in upgraded["equipment_instances"]:
		if not record is Dictionary or record.size() != 6:
			return _catalog_error(&"invalid_equipment_power")
		var checked := EquipmentInstance.from_record(record)
		if not checked["ok"]: return _catalog_error(checked["error_code"])
		record["recipe_revision_id"] = "catalog_v1"
		record["power_ruleset_id"] = "legacy_unscaled"
	upgraded["schema_version"] = LEGACY_SCHEMA_VERSION
	upgraded["catalog_version"] = ProfileState.CATALOG_VERSION
	var decoded := _decode_v2(upgraded, catalog, false, false, true)
	if decoded["ok"]:
		decoded["migrated"] = true
		decoded["migration_kind"] = &"equipment_power_v1"
	return decoded

static func _validate_legacy_profile(profile: ProfileState, catalog: ProfileCatalog = null) -> Dictionary:
	var effective_catalog := catalog if catalog != null else ProfileCatalog.pilot()
	if not effective_catalog.is_valid():
		return _catalog_error(&"invalid_catalog")
	if not profile._migration_equipment_ids.is_empty():
		return _error(&"invalid_equipment_instance")
	return _decode_v2(_profile_to_dictionary(profile), effective_catalog, false, false, false, true, true)

static func _decode_v2(data: Dictionary, catalog: ProfileCatalog, legacy_attribute_budget: bool = false, legacy_inventory: bool = false, legacy_cards: bool = false, allow_disabled_refs: bool = false, strict_admin: bool = false) -> Dictionary:
	if data.get("format_id") != ProfileState.FORMAT_ID:
		return _error(&"unsupported_schema")
	if not _is_exact_integer(data.get("catalog_version")) or int(data["catalog_version"]) != ProfileState.CATALOG_VERSION:
		return _error(&"invalid_catalog")
	if data.get("ruleset_id") != ProfileState.RULESET_ID:
		return _error(&"invalid_catalog")
	for field: String in LEGACY_ROOT_FIELDS if legacy_inventory else ROOT_FIELDS:
		if field == "card_inventory" and legacy_cards: continue
		if not data.has(field):
			return _error(&"missing_field", field)
	if _contains_forbidden_fields(data):
		return _error(&"runtime_state_in_save")
	var profile_id_value: Variant = data["profile_id"]
	if not profile_id_value is String or not _is_uuid(profile_id_value):
		return _error(&"invalid_profile_id")
	for counter_field: String in ["revision", "next_character_counter", "next_run_counter"]:
		if not _is_exact_integer(data[counter_field]):
			return _error(&"invalid_integer", counter_field)
		var value := int(data[counter_field])
		var minimum := 0 if counter_field == "revision" else 1
		if value < minimum or value > MAX_EXACT_JSON_INTEGER:
			return _error(&"invalid_integer", counter_field)
	if not data["characters"] is Array or data["characters"].size() > ProfileState.MAX_CHARACTERS:
		return _error(&"invalid_characters")
	var profile := ProfileState.new(profile_id_value)
	profile.revision = int(data["revision"])
	profile.next_character_counter = int(data["next_character_counter"])
	profile.next_run_counter = int(data["next_run_counter"])
	var character_ids: Dictionary[String, bool] = {}
	for raw_character: Variant in data["characters"]:
		var decoded_character := _decode_character(raw_character, profile.profile_id, profile.next_character_counter, catalog, legacy_attribute_budget, legacy_inventory, allow_disabled_refs, strict_admin)
		if not decoded_character["ok"]:
			return decoded_character
		var character: CharacterState = decoded_character["character"]
		if character_ids.has(character.character_id):
			return _error(&"duplicate_character_id")
		character_ids[character.character_id] = true
		profile.characters.append(character)
	var selected: Variant = data["selected_character_id"]
	if selected != null and (not selected is String or not character_ids.has(selected)):
		return _error(&"invalid_selected_character")
	profile.selected_character_id = "" if selected == null else selected
	if legacy_inventory:
		var collection_result := _decode_unique_ids(data["equipment_collection"])
		if not collection_result["ok"]:
			return collection_result
		profile._migration_equipment_ids = collection_result["ids"]
		for item_id: StringName in profile._migration_equipment_ids:
			if not catalog.knows_equipment(item_id):
				return _catalog_error(&"invalid_catalog")
	else:
		if not _is_exact_integer(data["next_equipment_counter"]) or int(data["next_equipment_counter"]) < 1 or int(data["next_equipment_counter"]) > MAX_EXACT_JSON_INTEGER or not data["equipment_instances"] is Array:
			return _error(&"invalid_equipment_instance")
		profile.next_equipment_counter = int(data["next_equipment_counter"])
		for raw_instance: Variant in data["equipment_instances"]:
			if not raw_instance is Dictionary or raw_instance.size() != 8:
				return _catalog_error(&"invalid_equipment_power")
			var instance_result := EquipmentInstance.from_record(raw_instance)
			if not instance_result["ok"]:
				return _catalog_error(instance_result["error_code"])
			var instance: EquipmentInstance = instance_result["instance"]
			var id := instance.instance_id
			var counter := _derived_counter(String(id), "equipment")
			if counter < 1 or counter >= profile.next_equipment_counter or profile.equipment_instances.has(id):
				return _catalog_error(&"invalid_equipment_instance")
			if not catalog.knows_equipment(instance.definition_id):
				return _catalog_error(&"invalid_catalog")
			var instance_check := EquipmentRules.validate_instance(instance, catalog.equipment_metadata(instance.definition_id))
			if not instance_check["ok"]:
				return _catalog_error(instance_check["error_code"])
			profile.equipment_instances[id] = instance
	for character: CharacterState in profile.characters:
		if not _character_equipment_is_valid(character, profile, catalog, legacy_inventory):
			return _catalog_error(&"invalid_equipment")
	if not data["settings"] is Dictionary or not data["legacy_loadouts"] is Dictionary or not data["unresolved_legacy"] is Dictionary:
		return _error(&"invalid_profile_maps")
	profile.settings = data["settings"].duplicate(true)
	profile.legacy_loadouts = data["legacy_loadouts"].duplicate(true)
	profile.unresolved_legacy = data["unresolved_legacy"].duplicate(true)
	var lifetime_result := _decode_lifetime_stats(data["lifetime_stats"])
	if not lifetime_result["ok"]:
		return lifetime_result
	profile.lifetime_stats = lifetime_result["stats"]
	var reward_result := _decode_reward_session(data["reward_session"], character_ids, profile.profile_id, profile.next_run_counter)
	if not reward_result["ok"]:
		return reward_result
	profile.reward_session = reward_result["session"]
	if not legacy_inventory and not legacy_cards:
		var inventory_result := RunCardInventory.from_record(data.get("card_inventory"),profile.equipment_instances,catalog.all_equipment_metadata(),catalog.card_ids())
		if not inventory_result["ok"]: return _catalog_error(inventory_result["error_code"])
		profile.card_inventory = inventory_result["inventory"]
	profile.extension_fields = _unknown_fields(data, LEGACY_ROOT_FIELDS if legacy_inventory else ROOT_FIELDS)
	var receipt_check := _validate_admin_receipts(profile.extension_fields.get("playtest_admin_receipts_v1", []), profile)
	if not receipt_check["ok"]: return receipt_check
	_canonicalize_admin_receipts(profile)
	return {"ok": true, "profile": profile, "migrated": false}

static func _canonicalize_admin_receipts(profile: ProfileState) -> void:
	if not profile.extension_fields.has("playtest_admin_receipts_v1"):
		return
	for receipt: Dictionary in profile.extension_fields["playtest_admin_receipts_v1"]:
		var options: Dictionary = receipt["options"]
		for field: String in ["item_level", "socket_capacity"]:
			if options.has(field): options[field] = int(options[field])
		var result: Dictionary = receipt["result"]
		for field: String in ["base_level", "job_level"]:
			if result.has(field): result[field] = int(result[field])

static func _validate_admin_receipts(raw: Variant, profile: ProfileState) -> Dictionary:
	if not raw is Array or raw.size() > 128:
		return _error(&"invalid_admin_receipts")
	var seen := {}
	for item: Variant in raw:
		if not item is Dictionary or item.size() != 6:
			return _error(&"invalid_admin_receipts")
		for field: String in ["request_id", "character_id", "action", "definition_id"]:
			if not item.get(field) is String:
				return _error(&"invalid_admin_receipts")
		if item["request_id"].is_empty() or item["request_id"].length() > 64 or seen.has(item["request_id"]):
			return _error(&"invalid_admin_receipts")
		seen[item["request_id"]] = true
		if item["action"] not in ["equipment", "card", "unlock_skills", "max_levels"] or not item.get("options") is Dictionary or not item.get("result") is Dictionary or not _is_json_value(item["options"]) or not _is_json_value(item["result"]):
			return _error(&"invalid_admin_receipts")
		var result: Dictionary = item["result"]
		if result.get("character_id") != item["character_id"] or result.get("action") != item["action"] or result.get("definition_id") != item["definition_id"]:
			return _error(&"invalid_admin_receipts")
		if profile.character_by_id(item["character_id"]) == null:
			return _error(&"invalid_admin_receipts")
		var options: Dictionary = item["options"]
		match item["action"]:
			"equipment":
				if result.size() != 4 or not result.get("equipment_instance_id") is String or not profile.equipment_instances.has(StringName(result["equipment_instance_id"])) or String(profile.equipment_instances[StringName(result["equipment_instance_id"])].definition_id) != item["definition_id"]:
					return _error(&"invalid_admin_receipts")
				for key: Variant in options:
					if key not in ["item_level", "quality_id", "socket_capacity"]:
						return _error(&"invalid_admin_receipts")
				if options.has("item_level") and (not _is_exact_integer(options["item_level"]) or not EquipmentRules.exact_integer(options["item_level"], 1, 30)):
					return _error(&"invalid_admin_receipts")
				if options.has("quality_id") and (not options["quality_id"] is String or StringName(options["quality_id"]) not in EquipmentRules.QUALITY_IDS):
					return _error(&"invalid_admin_receipts")
				if options.has("socket_capacity") and (not _is_exact_integer(options["socket_capacity"]) or not EquipmentRules.exact_integer(options["socket_capacity"], 0, 4)):
					return _error(&"invalid_admin_receipts")
			"card":
				if not options.is_empty() or result.size() != 4 or not result.get("card_instance_id") is String or profile.card_inventory.definition_id(StringName(result["card_instance_id"])) != StringName(item["definition_id"]):
					return _error(&"invalid_admin_receipts")
			"unlock_skills":
				if not options.is_empty() or item["definition_id"] != "" or result.size() != 4 or result.get("admin_skills_unlocked") != true:
					return _error(&"invalid_admin_receipts")
			"max_levels":
				if not options.is_empty() or item["definition_id"] != "" or result.size() != 5 or not _is_exact_integer(result.get("base_level")) or not _is_exact_integer(result.get("job_level")) or int(result["base_level"]) < 1 or int(result["job_level"]) < 1:
					return _error(&"invalid_admin_receipts")
	return {"ok": true}

static func _decode_character(raw: Variant, profile_id: String, next_character_counter: int, catalog: ProfileCatalog, legacy_attribute_budget: bool = false, legacy_inventory: bool = false, allow_disabled_refs: bool = false, strict_admin: bool = false) -> Dictionary:
	if not raw is Dictionary:
		return _error(&"invalid_character")
	var data: Dictionary = raw
	for field: String in CHARACTER_FIELDS:
		if field == "action_slots" or (field == "admin_skills_unlocked" and not strict_admin): # Legacy fields.
			continue
		if not data.has(field):
			return _error(&"missing_character_field", field)
	if _contains_forbidden_fields(data):
		return _error(&"runtime_state_in_save")
	if not data["character_id"] is String or data["character_id"].is_empty() or data["character_id"].length() > 64 or not data["character_id"].begins_with(profile_id + "_"):
		return _error(&"invalid_character_id")
	var character_counter := _derived_counter(data["character_id"], profile_id)
	if character_counter < 1 or character_counter >= next_character_counter:
		return _error(&"invalid_character_id")
	if not data["display_name"] is String or not _valid_display_name(data["display_name"]):
		return _error(&"invalid_display_name")
	if not data["base_class_id"] is String:
		return _error(&"invalid_origin")
	var base_class_id := StringName(data["base_class_id"])
	if not IdentityIds.is_base_class(base_class_id):
		return _error(&"invalid_origin")
	var evolution_id := &""
	if data["evolution_id"] != null:
		if not data["evolution_id"] is String:
			return _error(&"invalid_origin")
		evolution_id = StringName(data["evolution_id"])
		if not IdentityIds.evolution_belongs_to(evolution_id, base_class_id):
			return _error(&"invalid_origin")
	for xp_field: String in ["base_xp_total", "job_xp_total"]:
		if not _is_exact_integer(data[xp_field]) or int(data[xp_field]) < 0:
			return _error(&"invalid_integer", xp_field)
	var base_xp := int(data["base_xp_total"])
	var job_xp := int(data["job_xp_total"])
	if base_xp > ProgressionRules.MAX_BASE_XP or job_xp > (ProgressionRules.MAX_JOB_XP if not evolution_id.is_empty() else ProgressionRules.UNEVOLVED_MAX_JOB_XP):
		return _error(&"xp_out_of_range")
	if not evolution_id.is_empty() and (base_xp < ProgressionRules.EVOLUTION_MIN_BASE_XP or job_xp < ProgressionRules.EVOLUTION_MIN_JOB_XP):
		return _error(&"requirements_unmet")
	var allocations_result := _decode_allocations(data["attribute_allocations"], base_class_id, base_xp, legacy_attribute_budget)
	if not allocations_result["ok"]:
		return allocations_result
	var grants_result := _decode_granted_rank_map(data["granted_skill_ranks"], base_class_id, evolution_id, catalog)
	if not grants_result["ok"]:
		return grants_result
	var ranks_result := _decode_rank_map(
		data["purchased_skill_ranks"],
		base_class_id,
		evolution_id,
		job_xp,
		grants_result["ranks"],
		catalog
	)
	if not ranks_result["ok"]:
		return ranks_result
	if data.has("admin_skills_unlocked") and typeof(data["admin_skills_unlocked"]) != TYPE_BOOL:
		return _error(&"invalid_admin_skills_unlocked")
	var equipped_result := _decode_equipped(data["equipped"], legacy_inventory)
	if not equipped_result["ok"]:
		return equipped_result
	if not data["presets"] is Array or data["presets"].size() != CharacterState.PRESET_COUNT:
		return _error(&"invalid_presets")
	var presets: Array[Dictionary] = []
	var effective_ranks := catalog.effective_skill_ranks(
		base_class_id,
		evolution_id,
		ranks_result["ranks"],
		grants_result["ranks"]
	)
	if data.get("admin_skills_unlocked", false):
		var projection := CharacterState.new(data["character_id"], data["display_name"], base_class_id)
		projection.evolution_id = evolution_id
		projection.job_xp_total = job_xp
		projection.purchased_skill_ranks = ranks_result["ranks"]
		projection.granted_skill_ranks = grants_result["ranks"]
		projection.admin_skills_unlocked = true
		effective_ranks = CharacterProgression.effective_skill_ranks(projection, catalog)
	for raw_preset: Variant in data["presets"]:
		var preset_result := _decode_preset(raw_preset, base_class_id, evolution_id, effective_ranks, catalog, legacy_inventory, allow_disabled_refs)
		if not preset_result["ok"]:
			return preset_result
		presets.append(preset_result["preset"])
	if not _is_exact_integer(data["selected_preset"]):
		return _error(&"invalid_selected_preset")
	var selected_preset := int(data["selected_preset"])
	if selected_preset < 0 or selected_preset >= CharacterState.PRESET_COUNT:
		return _error(&"invalid_selected_preset")
	var character := CharacterState.new(data["character_id"], data["display_name"], base_class_id)
	character.evolution_id = evolution_id
	character.base_xp_total = base_xp
	character.job_xp_total = job_xp
	character.attribute_allocations = allocations_result["allocations"]
	character.granted_skill_ranks = grants_result["ranks"]
	character.purchased_skill_ranks = ranks_result["ranks"]
	character.admin_skills_unlocked = data.get("admin_skills_unlocked", false)
	character.equipped = equipped_result["equipped"]
	character.presets = presets
	character.selected_preset = selected_preset
	if data.has("action_slots"):
		var layout := _decode_slots(data["action_slots"], ActionBarLayout.SLOT_COUNT, ProfileCatalog.ACTIVE, base_class_id, evolution_id, effective_ranks, catalog, not legacy_inventory, allow_disabled_refs)
		if not layout["ok"]:
			return layout
		character.action_slots = layout["slots"]
	else:
		character.action_slots = ActionBarLayout.from_legacy(presets[selected_preset]["active_slots"])
	character.extension_fields = _unknown_fields(data, CHARACTER_FIELDS)
	return {"ok": true, "character": character}

static func _decode_allocations(raw: Variant, base_class_id: StringName, base_xp: int, legacy_attribute_budget: bool = false) -> Dictionary:
	if not raw is Dictionary or raw.size() != IdentityIds.attribute_ids().size():
		return _error(&"invalid_attribute_allocations")
	var allocations: Dictionary[StringName, int] = {}
	var invested := 0
	var initial := IdentityIds.initial_attributes(base_class_id)
	for attribute_id: StringName in IdentityIds.attribute_ids():
		var key := String(attribute_id)
		if not raw.has(key) or not _is_exact_integer(raw[key]) or int(raw[key]) < 0:
			return _error(&"invalid_attribute_allocations")
		var allocation := int(raw[key])
		if int(initial[attribute_id]) + allocation > 60:
			return _error(&"overspent_attributes")
		allocations[attribute_id] = allocation
		invested += allocation
	if legacy_attribute_budget and invested > ProgressionRules.legacy_attribute_points_granted(base_xp):
		return _error(&"overspent_attributes")
	var spent := ProgressionRules.attribute_points_spent(allocations, base_class_id)
	if spent < 0 or spent > ProgressionRules.attribute_points_granted(base_xp):
		return _error(&"overspent_attributes")
	return {"ok": true, "allocations": allocations}

static func _decode_granted_rank_map(raw: Variant, base_class_id: StringName, evolution_id: StringName, catalog: ProfileCatalog) -> Dictionary:
	if not raw is Dictionary:
		return _error(&"invalid_skill_ranks")
	var ranks: Dictionary[StringName, int] = {}
	var expected: Dictionary = LEGACY_BASE_GRANTS.get(String(base_class_id), {})
	for raw_id: Variant in raw:
		if not raw_id is String or not IdentityIds.is_technical_id(raw_id) or not _is_exact_integer(raw[raw_id]):
			return _error(&"invalid_skill_ranks")
		var skill_id := StringName(raw_id)
		var rank := int(raw[raw_id])
		if int(expected.get(raw_id, 0)) != rank:
			return _error(&"invalid_skill_ranks")
		var metadata := catalog.skill_metadata(skill_id)
		if metadata.is_empty() or not catalog.skill_is_allowed(skill_id, base_class_id, evolution_id):
			return _catalog_error(&"invalid_catalog")
		ranks[skill_id] = rank
	if not ranks.is_empty() and ranks.size() != expected.size():
		return _error(&"invalid_skill_ranks")
	return {"ok": true, "ranks": ranks}

static func _decode_rank_map(
	raw: Variant,
	base_class_id: StringName,
	evolution_id: StringName,
	job_xp: int,
	granted_ranks: Dictionary[StringName, int],
	catalog: ProfileCatalog
) -> Dictionary:
	if not raw is Dictionary:
		return _error(&"invalid_skill_ranks")
	var ranks: Dictionary[StringName, int] = {}
	var base_spent := 0
	var evolution_spent := 0
	for raw_id: Variant in raw:
		if not raw_id is String or not IdentityIds.is_technical_id(raw_id) or not _is_exact_integer(raw[raw_id]):
			return _error(&"invalid_skill_ranks")
		var rank := int(raw[raw_id])
		var skill_id := StringName(raw_id)
		var metadata := catalog.skill_metadata(skill_id)
		if metadata.is_empty() or not catalog.skill_is_allowed(skill_id, base_class_id, evolution_id):
			return _catalog_error(&"invalid_catalog")
		if rank < 0 or rank > int(metadata["max_purchased_rank"]):
			return _catalog_error(&"invalid_skill_ranks")
		if metadata["wallet"] == ProfileCatalog.BASE_WALLET:
			base_spent += rank
		else:
			evolution_spent += rank
		ranks[skill_id] = rank
	var evolved := not evolution_id.is_empty()
	if base_spent > ProgressionRules.base_skill_points_granted(job_xp, evolved) or evolution_spent > ProgressionRules.evolution_skill_points_granted(job_xp, evolved):
		return _error(&"overspent_skill_points")
	var requirements := catalog.validate_purchased_ranks(
		base_class_id,
		evolution_id,
		ProgressionRules.job_level_for_xp(job_xp, evolved),
		ranks,
		granted_ranks
	)
	if not requirements["ok"]:
		return requirements
	return {"ok": true, "ranks": ranks}

static func _decode_equipped(raw: Variant, legacy_inventory: bool = false) -> Dictionary:
	var slots: Array[StringName] = EquipmentRules.LEGACY_SLOTS if legacy_inventory else IdentityIds.equipment_slots()
	if not raw is Dictionary or raw.size() != slots.size():
		return _error(&"invalid_equipment")
	var equipped: Dictionary[StringName, Variant] = {}
	for slot: StringName in slots:
		var key := String(slot)
		if not raw.has(key) or (raw[key] != null and (not raw[key] is String or not IdentityIds.is_technical_id(raw[key]))):
			return _error(&"invalid_equipment")
		equipped[slot] = null if raw[key] == null else StringName(raw[key])
	return {"ok": true, "equipped": equipped}

static func _decode_preset(raw: Variant, base_class_id: StringName, evolution_id: StringName, effective_ranks: Dictionary[StringName, int], catalog: ProfileCatalog, legacy_inventory: bool = false, allow_disabled_refs: bool = false) -> Dictionary:
	if not raw is Dictionary or raw.size() != 3 or not raw.has("active_slots") or not raw.has("passive_slots") or not raw.has("equipped"):
		return _error(&"invalid_presets")
	var active_result := _decode_slots(raw["active_slots"], CharacterState.ACTIVE_SLOT_COUNT, ProfileCatalog.ACTIVE, base_class_id, evolution_id, effective_ranks, catalog, false, allow_disabled_refs)
	var passive_result := _decode_slots(raw["passive_slots"], CharacterState.PASSIVE_SLOT_COUNT, ProfileCatalog.PASSIVE, base_class_id, evolution_id, effective_ranks, catalog, false, allow_disabled_refs)
	var equipped_result := _decode_equipped(raw["equipped"], legacy_inventory)
	if not active_result["ok"]:
		return active_result
	if not passive_result["ok"]:
		return passive_result
	if not equipped_result["ok"]:
		return equipped_result
	return {"ok": true, "preset": {"active_slots": active_result["slots"], "passive_slots": passive_result["slots"], "equipped": equipped_result["equipped"]}}

static func _decode_slots(raw: Variant, expected_size: int, category: StringName, base_class_id: StringName, evolution_id: StringName, effective_ranks: Dictionary[StringName, int], catalog: ProfileCatalog, allow_item_refs: bool = false, allow_disabled_refs: bool = false) -> Dictionary:
	if not raw is Array or raw.size() != expected_size:
		return _error(&"invalid_presets")
	var slots: Array[Variant] = []
	var seen: Dictionary[String, bool] = {}
	for value: Variant in raw:
		var id := ActionBarLayout.skill_id(value)
		var selected := ActionBarLayout.selected_rank(value)
		var explicit := value is Dictionary
		if explicit and (expected_size != ActionBarLayout.SLOT_COUNT or value.size() != 2 or not value.has("rank") or not _is_exact_integer(value["rank"]) or selected <= 0 or not SkillCastRank.supports(id)):
			return _error(&"invalid_presets")
		if value != null and (id.is_empty() or not IdentityIds.is_technical_id(String(id))):
			return _error(&"invalid_presets")
		if value == null:
			slots.append(null)
			continue
		var skill_id := id
		var key := "%s:%d" % [id, selected]
		var metadata := catalog.skill_metadata(skill_id)
		var item_reference := allow_item_refs and category == ProfileCatalog.ACTIVE and ItemSkillAdapters.supports(skill_id, base_class_id)
		if metadata.is_empty() or (not catalog.skill_is_allowed(skill_id, base_class_id, evolution_id) and not item_reference):
			return _catalog_error(&"invalid_catalog")
		if metadata["category"] != category or seen.has(key):
			return _catalog_error(&"invalid_presets") if metadata["category"] != category else _error(&"invalid_presets")
		if effective_ranks.get(skill_id, 0) <= 0 and not item_reference and not allow_disabled_refs:
			return _error(&"requirements_unmet")
		if explicit and ClassCatalog.skill_definition(skill_id).rank_definition(selected) == null:
			return _error(&"invalid_presets")
		# Retain a formerly granted or higher rank disabled; execution revalidates access.
		seen[key] = true
		slots.append(ActionBarLayout.entry(skill_id, selected))
	return {"ok": true, "slots": slots}

static func _decode_unique_ids(raw: Variant) -> Dictionary:
	if not raw is Array:
		return _error(&"invalid_equipment_collection")
	var ids: Array[StringName] = []
	var seen: Dictionary[StringName, bool] = {}
	for value: Variant in raw:
		if not value is String or not IdentityIds.is_technical_id(value):
			return _error(&"invalid_equipment_collection")
		var item_id := StringName(value)
		if seen.has(item_id):
			return _error(&"duplicate_equipment_id")
		seen[item_id] = true
		ids.append(item_id)
	return {"ok": true, "ids": ids}

static func _decode_lifetime_stats(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return _error(&"invalid_lifetime_stats")
	var stats: Dictionary[StringName, int] = {}
	for raw_id: Variant in raw:
		if not raw_id is String or not IdentityIds.is_technical_id(raw_id) or not _is_exact_integer(raw[raw_id]) or int(raw[raw_id]) < 0:
			return _error(&"invalid_lifetime_stats")
		stats[StringName(raw_id)] = int(raw[raw_id])
	for stat_id: StringName in [&"runs_started", &"runs_completed", &"deaths", &"kills", &"equipment_unlocked"]:
		if not stats.has(stat_id):
			stats[stat_id] = 0
	return {"ok": true, "stats": stats}

static func _decode_reward_session(raw: Variant, character_ids: Dictionary[String, bool], profile_id: String, next_run_counter: int) -> Dictionary:
	if raw == null:
		return {"ok": true, "session": null}
	if not raw is Dictionary or raw.size() != 3 or not raw.has("run_id") or not raw.has("character_id") or not raw.has("last_committed_seq"):
		return _error(&"invalid_reward_session")
	if not raw["run_id"] is String or not raw["character_id"] is String or not character_ids.has(raw["character_id"]):
		return _error(&"invalid_reward_session")
	var run_counter := _derived_counter(raw["run_id"], profile_id)
	if run_counter < 1 or run_counter >= next_run_counter:
		return _error(&"invalid_reward_session")
	if not _is_exact_integer(raw["last_committed_seq"]) or int(raw["last_committed_seq"]) < 0:
		return _error(&"invalid_reward_session")
	return {"ok": true, "session": {"run_id": raw["run_id"], "character_id": raw["character_id"], "last_committed_seq": int(raw["last_committed_seq"])}}

static func _migrate_v1(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	if not data.has("equipment_collection") or not data.has("equipped") or not data["equipment_collection"] is Dictionary or not data["equipped"] is Dictionary:
		return _error(&"unsupported_schema")
	var profile := ProfileState.new(IdentityIds.new_profile_id())
	var unresolved: Array[String] = []
	var seen: Dictionary[StringName, bool] = {}
	for class_items: Variant in data["equipment_collection"].values():
		if not class_items is Array:
			return _error(&"invalid_legacy_profile")
		for raw_item_id: Variant in class_items:
			if not raw_item_id is String or not IdentityIds.is_technical_id(raw_item_id):
				return _error(&"invalid_legacy_profile")
			var item_id := StringName(raw_item_id)
			if seen.has(item_id):
				continue
			seen[item_id] = true
			if catalog.knows_equipment(item_id):
				profile._migration_equipment_ids.append(item_id)
			else:
				unresolved.append(raw_item_id)
	profile.legacy_loadouts = data["equipped"].duplicate(true)
	profile.unresolved_legacy = {"equipment_ids": unresolved}
	if data.has("settings"):
		if not data["settings"] is Dictionary:
			return _error(&"invalid_legacy_profile")
		profile.settings = data["settings"].duplicate(true)
	if data.has("lifetime_stats"):
		var stats_result := _decode_lifetime_stats(data["lifetime_stats"])
		if not stats_result["ok"]:
			return stats_result
		profile.lifetime_stats = stats_result["stats"]
	return {"ok": true, "profile": profile, "migrated": true, "migration_kind": &"schema_v1"}

static func _migrate_catalog_v1(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	if not data.get("characters") is Array:
		return _error(&"invalid_characters")
	var migrated := data.duplicate(true)
	migrated["catalog_version"] = ProfileState.CATALOG_VERSION
	migrated["ruleset_id"] = ProfileState.RULESET_ID
	for index: int in migrated["characters"].size():
		var raw_character: Variant = migrated["characters"][index]
		if not raw_character is Dictionary or not raw_character.get("base_class_id") is String:
			return _error(&"invalid_character")
		if raw_character.has("granted_skill_ranks"):
			return _error(&"invalid_skill_ranks")
		var grants: Dictionary = LEGACY_BASE_GRANTS.get(raw_character["base_class_id"], {}).duplicate(true)
		raw_character["granted_skill_ranks"] = grants
		migrated["characters"][index] = raw_character
	var decoded := _decode_v2(migrated, catalog, true, true)
	if not decoded["ok"]:
		return decoded
	_add_inventory_starters(decoded["profile"], catalog)
	decoded["migrated"] = true
	decoded["migration_kind"] = &"catalog_v1"
	return decoded

static func _migrate_catalog_v2(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	# The Defender catalog adds IDs but does not reinterpret any catalog-2 field.
	var migrated := data.duplicate(true)
	migrated["catalog_version"] = ProfileState.CATALOG_VERSION
	migrated["ruleset_id"] = ProfileState.RULESET_ID
	var decoded := _decode_v2(migrated, catalog, true, true)
	if not decoded["ok"]:
		return decoded
	_add_inventory_starters(decoded["profile"], catalog)
	decoded["migrated"] = true
	decoded["migration_kind"] = &"catalog_v2"
	return decoded

static func _migrate_catalog_v3(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	# Berserker adds exclusive IDs without reinterpreting catalog-3 fields.
	var migrated := data.duplicate(true)
	migrated["catalog_version"] = ProfileState.CATALOG_VERSION
	migrated["ruleset_id"] = ProfileState.RULESET_ID
	var decoded := _decode_v2(migrated, catalog, true, true)
	if not decoded["ok"]:
		return decoded
	_add_inventory_starters(decoded["profile"], catalog)
	decoded["migrated"] = true
	decoded["migration_kind"] = &"catalog_v3"
	return decoded

static func _migrate_catalog_v4(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	# Elementalist adds exclusive IDs without reinterpreting catalog-4 fields.
	var migrated := data.duplicate(true)
	migrated["catalog_version"] = ProfileState.CATALOG_VERSION
	migrated["ruleset_id"] = ProfileState.RULESET_ID
	var decoded := _decode_v2(migrated, catalog, true, true)
	if not decoded["ok"]:
		return decoded
	_add_inventory_starters(decoded["profile"], catalog)
	decoded["migrated"] = true
	decoded["migration_kind"] = &"catalog_v4"
	return decoded

static func _migrate_catalog_v5(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	# Spiritualist only adds IDs; catalog-5 character fields and ranks are unchanged.
	var migrated := data.duplicate(true)
	migrated["catalog_version"] = ProfileState.CATALOG_VERSION
	migrated["ruleset_id"] = ProfileState.RULESET_ID
	var decoded := _decode_v2(migrated, catalog, true, true)
	if not decoded["ok"]:
		return decoded
	_add_inventory_starters(decoded["profile"], catalog)
	decoded["migrated"] = true
	decoded["migration_kind"] = &"catalog_v5"
	return decoded

static func _migrate_catalog_v6(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	var migrated := data.duplicate(true)
	migrated["catalog_version"] = ProfileState.CATALOG_VERSION
	migrated["ruleset_id"] = ProfileState.RULESET_ID
	# Validate all old allocations against the old wallet before accepting the
	# larger new budget. The new cost is then checked too; no debt or reset.
	var decoded := _decode_v2(migrated, catalog, true, true)
	if not decoded["ok"]:
		return decoded
	_add_inventory_starters(decoded["profile"], catalog)
	decoded["migrated"] = true
	decoded["migration_kind"] = &"catalog_v6"
	return decoded

static func _migrate_catalog_v7(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	# Catalog 7 already uses threshold costs/budget. Hunter only adds identities:
	# never revalidate legitimate investments against the pre-threshold wallet.
	var migrated := data.duplicate(true)
	migrated["catalog_version"] = ProfileState.CATALOG_VERSION
	var decoded := _decode_v2(migrated, catalog, false, true)
	if not decoded["ok"]:
		return decoded
	_add_inventory_starters(decoded["profile"], catalog)
	decoded["migrated"] = true
	decoded["migration_kind"] = &"catalog_v7"
	return decoded

static func _migrate_catalog_v8(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	var migrated := data.duplicate(true)
	migrated["catalog_version"] = ProfileState.CATALOG_VERSION
	var decoded := _decode_v2(migrated, catalog, false, true)
	if not decoded["ok"]:
		return decoded
	_add_inventory_starters(decoded["profile"], catalog)
	decoded["migrated"] = true
	decoded["migration_kind"] = &"catalog_v8"
	return decoded

static func _add_inventory_starters(profile: ProfileState, catalog: ProfileCatalog) -> void:
	for character: CharacterState in profile.characters:
		var starters := catalog.starter_equipment(character.base_class_id)
		for slot: StringName in EquipmentRules.LEGACY_SLOTS:
			var item: Variant = starters.get(EquipmentRules.legacy_position(slot))
			if item == null:
				continue
			if item not in profile._migration_equipment_ids:
				profile._migration_equipment_ids.append(item)
			if character.equipped[slot] == null:
				character.equipped[slot] = item
			for preset: Dictionary in character.presets:
				if preset["equipped"][slot] == null:
					preset["equipped"][slot] = item

static func _profile_to_dictionary(profile: ProfileState) -> Dictionary:
	var data := profile.extension_fields.duplicate(true)
	data.merge({
		"format_id": ProfileState.FORMAT_ID,
		"schema_version": LEGACY_SCHEMA_VERSION,
		"catalog_version": ProfileState.CATALOG_VERSION,
		"ruleset_id": ProfileState.RULESET_ID,
		"profile_id": profile.profile_id,
		"revision": profile.revision,
		"next_character_counter": profile.next_character_counter,
		"next_run_counter": profile.next_run_counter,
		"selected_character_id": null if profile.selected_character_id.is_empty() else profile.selected_character_id,
		"equipment_instances": _instance_records(profile),
		"next_equipment_counter": profile.next_equipment_counter,
		"card_inventory": profile.card_inventory.to_record(),
		"characters": [],
		"settings": profile.settings.duplicate(true),
		"lifetime_stats": _integer_map_to_dictionary(profile.lifetime_stats),
		"reward_session": _copy_json_candidate(profile.reward_session),
		"legacy_loadouts": profile.legacy_loadouts.duplicate(true),
		"unresolved_legacy": profile.unresolved_legacy.duplicate(true),
	}, true)
	for character: CharacterState in profile.characters:
		data["characters"].append(_character_to_dictionary(character))
	return data

static func _character_to_dictionary(character: CharacterState) -> Dictionary:
	var data := character.extension_fields.duplicate(true)
	var presets: Array[Dictionary] = []
	for preset: Dictionary in character.presets:
		presets.append({
			"active_slots": _nullable_names_to_values(preset["active_slots"]),
			"passive_slots": _nullable_names_to_values(preset["passive_slots"]),
			"equipped": _equipped_to_dictionary(preset["equipped"]),
		})
	data.merge({
		"character_id": character.character_id,
		"display_name": character.display_name,
		"base_class_id": String(character.base_class_id),
		"evolution_id": null if character.evolution_id.is_empty() else String(character.evolution_id),
		"base_xp_total": character.base_xp_total,
		"job_xp_total": character.job_xp_total,
		"attribute_allocations": _integer_map_to_dictionary(character.attribute_allocations),
		"granted_skill_ranks": _integer_map_to_dictionary(character.granted_skill_ranks),
		"purchased_skill_ranks": _integer_map_to_dictionary(character.purchased_skill_ranks),
		"admin_skills_unlocked": character.admin_skills_unlocked,
		"equipped": _equipped_to_dictionary(character.equipped),
		"presets": presets,
		"selected_preset": character.selected_preset,
		"action_slots": _nullable_names_to_values(ActionBarLayout.for_character(character)),
	}, true)
	return data

static func _equipped_to_dictionary(equipped: Dictionary) -> Dictionary:
	var result := {}
	for slot: StringName in IdentityIds.equipment_slots():
		var value: Variant = equipped.get(slot)
		result[String(slot)] = null if value == null else String(value)
	return result

static func _integer_map_to_dictionary(values: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in values:
		result[String(key)] = values[key]
	return result

static func _names_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result

static func _nullable_names_to_values(values: Array) -> Array[Variant]:
	var result: Array[Variant] = []
	for value: Variant in values:
		result.append({"skill_id": String(ActionBarLayout.skill_id(value)), "rank": ActionBarLayout.selected_rank(value)} if value is Dictionary else (null if value == null else String(value)))
	return result

static func _copy_json_candidate(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

static func _character_equipment_is_valid(character: CharacterState, profile: ProfileState, catalog: ProfileCatalog, legacy_inventory: bool = false) -> bool:
	var layouts: Array[Dictionary] = [character.equipped]
	for preset: Dictionary in character.presets:
		layouts.append(preset["equipped"])
	for layout: Dictionary in layouts:
		if legacy_inventory:
			for slot: StringName in EquipmentRules.LEGACY_SLOTS:
				var value: Variant = layout[slot]
				if value != null and (value not in profile._migration_equipment_ids or not catalog.equipment_is_allowed(value, EquipmentRules.legacy_position(slot), character.base_class_id, character.evolution_id)):
					return false
		elif not EquipmentRules.validate_layout(layout, profile.equipment_instances, catalog.all_equipment_metadata(), character.base_class_id, character.evolution_id)["ok"]:
			return false
	return true

static func _instance_records(profile: ProfileState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: StringName in profile.equipment_instance_ids():
		result.append(profile.equipment_instances[id].to_record())
	return result

static func _upgrade_legacy(decoded: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	if not decoded["ok"]:
		return decoded
	var profile: ProfileState = decoded["profile"]
	for reserved: String in ["equipment_instances", "next_equipment_counter"]:
		if profile.extension_fields.has(reserved):
			return _catalog_error(&"invalid_catalog")
	var mapping: Dictionary = {}
	for id: StringName in profile._migration_equipment_ids:
		var created := profile.add_equipment_instance(id, catalog.equipment_metadata(id))
		if not created["ok"]:
			return _catalog_error(created["error_code"])
		mapping[id] = created["instance_id"]
	for character: CharacterState in profile.characters:
		character.equipped = _upgrade_layout(character.equipped, mapping)
		for preset: Dictionary in character.presets:
			preset["equipped"] = _upgrade_layout(preset["equipped"], mapping)
	profile._migration_equipment_ids.clear()
	for character: CharacterState in profile.characters:
		if not _character_equipment_is_valid(character, profile, catalog):
			return _catalog_error(&"invalid_equipment")
	decoded["migrated"] = true
	if StringName(decoded.get("migration_kind", &"")).is_empty():
		decoded["migration_kind"] = &"equipment_instances_v1"
	return decoded

static func _upgrade_layout(legacy: Dictionary, mapping: Dictionary) -> Dictionary[StringName, Variant]:
	var result := EquipmentRules.empty_layout()
	for slot: StringName in EquipmentRules.LEGACY_SLOTS:
		var id: Variant = legacy[slot]
		result[EquipmentRules.legacy_position(slot)] = null if id == null else mapping[id]
	return result

static func _unknown_fields(data: Dictionary, known_fields: Array) -> Dictionary:
	var unknown := {}
	for key: Variant in data:
		if key not in known_fields:
			unknown[key] = data[key]
	return unknown

static func _contains_forbidden_fields(data: Dictionary) -> bool:
	for field: String in FORBIDDEN_RUNTIME_FIELDS:
		if data.has(field):
			return true
	return false

static func _is_exact_integer(value: Variant) -> bool:
	if value is bool:
		return false
	if value is int:
		return abs(value) <= MAX_EXACT_JSON_INTEGER
	if value is float:
		return is_finite(value) and value == floor(value) and abs(value) <= MAX_EXACT_JSON_INTEGER
	return false

static func _is_uuid(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
	return regex.search(value) != null

static func _valid_display_name(value: String) -> bool:
	if value.length() < 1 or value.length() > 24:
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159):
			return false
	return true

static func _derived_counter(identifier: String, profile_id: String) -> int:
	var prefix := profile_id + "_"
	if not identifier.begins_with(prefix):
		return -1
	var suffix := identifier.trim_prefix(prefix)
	if suffix.is_empty() or not suffix.is_valid_int():
		return -1
	var counter := int(suffix)
	if String.num_int64(counter) != suffix:
		return -1
	return counter

static func _is_json_value(value: Variant) -> bool:
	if value == null or value is bool or value is String:
		return true
	if value is int:
		return value >= -MAX_EXACT_JSON_INTEGER and value <= MAX_EXACT_JSON_INTEGER
	if value is float:
		return is_finite(value) and (value != floor(value) or abs(value) <= MAX_EXACT_JSON_INTEGER)
	if value is Array:
		for item: Variant in value:
			if not _is_json_value(item):
				return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _is_json_value(value[key]):
				return false
		return true
	return false

static func _error(error_code: StringName, field: String = "") -> Dictionary:
	var result := {"ok": false, "error_code": error_code}
	if not field.is_empty():
		result["field"] = field
	return result

static func _catalog_error(error_code: StringName) -> Dictionary:
	return {"ok": false, "error_code": error_code, "catalog_incompatible": true}


static func validate_profile(profile: ProfileState, catalog: ProfileCatalog = null) -> Dictionary:
	if profile == null: return _error(&"invalid_profile")
	if profile.ownership_migration_required: return _error(&"migration_required")
	var legacy := _validate_legacy_profile(profile, catalog)
	if not legacy.get("ok", false): return legacy
	return CharacterAssets.validate(profile)

static func owned_dictionary(profile: ProfileState) -> Dictionary:
	var data := _profile_to_dictionary(profile)
	data["schema_version"] = ProfileState.SCHEMA_VERSION
	data["profile_unlocks"] = _integer_map_to_dictionary(profile.profile_unlocks)
	data["expeditions"] = {}
	for id: String in profile.expeditions: data["expeditions"][id] = profile.expeditions[id].to_record()
	data["asset_receipts"] = profile.asset_receipts.duplicate(true)
	data["migration_receipt"] = profile.migration_receipt.duplicate(true)
	for raw: Dictionary in data["characters"]:
		raw["gold"] = profile.character_by_id(raw["character_id"]).gold
	for raw: Dictionary in data["equipment_instances"]:
		raw["owner_character_id"] = profile.equipment_instances[StringName(raw["instance_id"])].owner_character_id
	data["card_inventory"]["owners"] = profile.card_inventory.owner_records()
	return data

static func decode(text: String, catalog: ProfileCatalog = null) -> Dictionary:
	var json := JSON.new()
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES or json.parse(text) != OK or not json.data is Dictionary:
		return _decode_legacy(text, catalog)
	var raw: Dictionary = json.data
	if not _is_json_value(raw): return _error(&"invalid_json_value")
	if not _is_exact_integer(raw.get("schema_version")): return _error(&"unsupported_schema")
	var schema := int(raw["schema_version"])
	if schema > ProfileState.SCHEMA_VERSION: return {"ok": false, "error_code": &"unsupported_schema", "future_schema": true}
	if schema <= LEGACY_SCHEMA_VERSION:
		var historical := _decode_legacy(text, catalog)
		if not historical.get("ok", false): return historical
		var profile: ProfileState = historical["profile"]
		if schema == 1:
			# Historical schema1 had no identity; derive one stably without inventing a character.
			var hash := text.sha256_text()
			profile.profile_id = "%s-%s-5%s-a%s-%s" % [hash.substr(0,8), hash.substr(8,4), hash.substr(13,3), hash.substr(17,3), hash.substr(20,12)]
		profile.ownership_migration_required = true
		var historical_changes := {"source_schema": schema, "source_catalog": raw.get("catalog_version", 0), "source_ruleset": raw.get("ruleset_id", ""), "converted": historical.get("migrated", false), "kind": String(historical.get("migration_kind", "")), "kinds": [], "removals": historical.get("migration_removals", []).duplicate(true)}
		for kind: Variant in historical.get("migration_kinds", []): historical_changes["kinds"].append(String(kind))
		return {"ok": false, "error_code": &"migration_required", "read_only": true, "legacy_profile": profile, "source_digest": text.sha256_text(), "historical_changes": historical_changes}
	if schema != ProfileState.SCHEMA_VERSION: return _error(&"unsupported_schema")
	for field: String in OWNERSHIP_FIELDS:
		if not raw.get(field) is Dictionary: return _error(&"invalid_ownership_section", field)
	if not raw.get("characters") is Array or not raw.get("equipment_instances") is Array or not raw.get("card_inventory") is Dictionary or not raw["card_inventory"].get("owners") is Dictionary: return _error(&"invalid_ownership_section")
	var legacy := raw.duplicate(true)
	legacy["schema_version"] = LEGACY_SCHEMA_VERSION
	for field: String in OWNERSHIP_FIELDS: legacy.erase(field)
	for item: Variant in legacy["equipment_instances"]:
		if not item is Dictionary or not item.get("owner_character_id") is String: return _error(&"invalid_owner")
		item.erase("owner_character_id")
	for character: Variant in legacy["characters"]:
		if not character is Dictionary or not EquipmentRules.exact_integer(character.get("gold"), 0): return _error(&"invalid_gold")
		character.erase("gold")
	legacy["card_inventory"].erase("owners")
	var decoded := _decode_legacy(JSON.stringify(legacy), catalog)
	if not decoded.get("ok", false): return decoded
	var profile: ProfileState = decoded["profile"]
	for item: Dictionary in raw["equipment_instances"]:
		profile.equipment_instances[StringName(item["instance_id"])].owner_character_id = item["owner_character_id"]
	for character: Dictionary in raw["characters"]:
		profile.character_by_id(character["character_id"]).gold = int(character["gold"])
	var owners: Dictionary = raw["card_inventory"]["owners"]
	if owners.size() != profile.card_inventory.describe()["owned"].size(): return _error(&"invalid_owner")
	for id: Variant in owners:
		if not id is String or not owners[id] is String or not profile.card_inventory.owns(StringName(id)): return _error(&"invalid_owner")
		profile.card_inventory._owners[StringName(id)] = owners[id]
	for id: Variant in raw["profile_unlocks"]:
		if not id is String or not IdentityIds.is_technical_id(id) or typeof(raw["profile_unlocks"][id]) != TYPE_BOOL or not raw["profile_unlocks"][id]: return _error(&"invalid_unlock")
		profile.profile_unlocks[StringName(id)] = true
	for id: Variant in raw["expeditions"]:
		var slot := ExpeditionAssetLock.from_record(raw["expeditions"][id])
		if not id is String or not slot.get("ok", false) or slot["lock"].expedition_id != id: return _error(&"invalid_expedition_slot")
		profile.expeditions[id] = slot["lock"]
	profile.asset_receipts = raw["asset_receipts"].duplicate(true)
	profile.migration_receipt = raw["migration_receipt"].duplicate(true)
	var valid := CharacterAssets.validate(profile)
	if not valid.get("ok", false): return valid
	# JSON parses numeric receipt fields as float; normalize only after exact-integer validation.
	for receipt: Dictionary in profile.asset_receipts.values(): receipt["data"]["gold"] = int(receipt["data"]["gold"])
	return {"ok": true, "profile": profile, "migrated": false}
