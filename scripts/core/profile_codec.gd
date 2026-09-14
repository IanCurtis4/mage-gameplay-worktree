class_name ProfileCodec
extends RefCounted
## Pure schema-2 encoding, validation and conservative schema-1 migration.

const MAX_FILE_BYTES := 4 * 1024 * 1024
const MAX_EXACT_JSON_INTEGER := 9007199254740991
const ROOT_FIELDS := [
	"format_id", "schema_version", "catalog_version", "ruleset_id", "profile_id",
	"revision", "next_character_counter", "next_run_counter", "selected_character_id",
	"equipment_collection", "characters", "settings", "lifetime_stats",
	"reward_session", "legacy_loadouts", "unresolved_legacy",
]
const CHARACTER_FIELDS := [
	"character_id", "display_name", "base_class_id", "evolution_id", "base_xp_total",
	"job_xp_total", "attribute_allocations", "purchased_skill_ranks", "equipped",
	"presets", "selected_preset",
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
	var payload := _profile_to_dictionary(profile)
	if not _is_json_value(payload):
		return _error(&"invalid_json_value")
	var text := JSON.stringify(payload, "\t")
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return _error(&"profile_too_large")
	return {"ok": true, "text": text, "data": payload}

static func decode(text: String, catalog: ProfileCatalog = null) -> Dictionary:
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
	if schema_version > ProfileState.SCHEMA_VERSION:
		return {"ok": false, "error_code": &"unsupported_schema", "future_schema": true}
	if schema_version == 1:
		return _migrate_v1(data, effective_catalog)
	if schema_version != ProfileState.SCHEMA_VERSION:
		return _error(&"unsupported_schema")
	return _decode_v2(data, effective_catalog)

static func validate_profile(profile: ProfileState, catalog: ProfileCatalog = null) -> Dictionary:
	var effective_catalog := catalog if catalog != null else ProfileCatalog.pilot()
	if not effective_catalog.is_valid():
		return _catalog_error(&"invalid_catalog")
	return _decode_v2(_profile_to_dictionary(profile), effective_catalog)

static func _decode_v2(data: Dictionary, catalog: ProfileCatalog) -> Dictionary:
	if data.get("format_id") != ProfileState.FORMAT_ID:
		return _error(&"unsupported_schema")
	if not _is_exact_integer(data.get("catalog_version")) or int(data["catalog_version"]) != ProfileState.CATALOG_VERSION:
		return _error(&"invalid_catalog")
	if data.get("ruleset_id") != ProfileState.RULESET_ID:
		return _error(&"invalid_catalog")
	for field: String in ROOT_FIELDS:
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
		var decoded_character := _decode_character(raw_character, profile.profile_id, profile.next_character_counter, catalog)
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
	var collection_result := _decode_unique_ids(data["equipment_collection"])
	if not collection_result["ok"]:
		return collection_result
	profile.equipment_collection = collection_result["ids"]
	for item_id: StringName in profile.equipment_collection:
		if not catalog.knows_equipment(item_id):
			return _catalog_error(&"invalid_catalog")
	for character: CharacterState in profile.characters:
		if not _character_equipment_is_valid(character, profile.equipment_collection, catalog):
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
	profile.extension_fields = _unknown_fields(data, ROOT_FIELDS)
	return {"ok": true, "profile": profile, "migrated": false}

static func _decode_character(raw: Variant, profile_id: String, next_character_counter: int, catalog: ProfileCatalog) -> Dictionary:
	if not raw is Dictionary:
		return _error(&"invalid_character")
	var data: Dictionary = raw
	for field: String in CHARACTER_FIELDS:
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
	var allocations_result := _decode_allocations(data["attribute_allocations"], base_class_id, base_xp)
	if not allocations_result["ok"]:
		return allocations_result
	var ranks_result := _decode_rank_map(data["purchased_skill_ranks"], base_class_id, evolution_id, job_xp, catalog)
	if not ranks_result["ok"]:
		return ranks_result
	var equipped_result := _decode_equipped(data["equipped"])
	if not equipped_result["ok"]:
		return equipped_result
	if not data["presets"] is Array or data["presets"].size() != CharacterState.PRESET_COUNT:
		return _error(&"invalid_presets")
	var presets: Array[Dictionary] = []
	for raw_preset: Variant in data["presets"]:
		var preset_result := _decode_preset(raw_preset, base_class_id, evolution_id, ranks_result["ranks"], catalog)
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
	character.purchased_skill_ranks = ranks_result["ranks"]
	character.equipped = equipped_result["equipped"]
	character.presets = presets
	character.selected_preset = selected_preset
	character.extension_fields = _unknown_fields(data, CHARACTER_FIELDS)
	return {"ok": true, "character": character}

static func _decode_allocations(raw: Variant, base_class_id: StringName, base_xp: int) -> Dictionary:
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
	if invested > ProgressionRules.attribute_points_granted(base_xp):
		return _error(&"overspent_attributes")
	return {"ok": true, "allocations": allocations}

static func _decode_rank_map(raw: Variant, base_class_id: StringName, evolution_id: StringName, job_xp: int, catalog: ProfileCatalog) -> Dictionary:
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
	return {"ok": true, "ranks": ranks}

static func _decode_equipped(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size() != IdentityIds.equipment_slots().size():
		return _error(&"invalid_equipment")
	var equipped: Dictionary[StringName, Variant] = {}
	for slot: StringName in IdentityIds.equipment_slots():
		var key := String(slot)
		if not raw.has(key) or (raw[key] != null and (not raw[key] is String or not IdentityIds.is_technical_id(raw[key]))):
			return _error(&"invalid_equipment")
		equipped[slot] = null if raw[key] == null else StringName(raw[key])
	return {"ok": true, "equipped": equipped}

static func _decode_preset(raw: Variant, base_class_id: StringName, evolution_id: StringName, purchased_ranks: Dictionary[StringName, int], catalog: ProfileCatalog) -> Dictionary:
	if not raw is Dictionary or raw.size() != 3 or not raw.has("active_slots") or not raw.has("passive_slots") or not raw.has("equipped"):
		return _error(&"invalid_presets")
	var active_result := _decode_slots(raw["active_slots"], CharacterState.ACTIVE_SLOT_COUNT, ProfileCatalog.ACTIVE, base_class_id, evolution_id, purchased_ranks, catalog)
	var passive_result := _decode_slots(raw["passive_slots"], CharacterState.PASSIVE_SLOT_COUNT, ProfileCatalog.PASSIVE, base_class_id, evolution_id, purchased_ranks, catalog)
	var equipped_result := _decode_equipped(raw["equipped"])
	if not active_result["ok"]:
		return active_result
	if not passive_result["ok"]:
		return passive_result
	if not equipped_result["ok"]:
		return equipped_result
	return {"ok": true, "preset": {"active_slots": active_result["slots"], "passive_slots": passive_result["slots"], "equipped": equipped_result["equipped"]}}

static func _decode_slots(raw: Variant, expected_size: int, category: StringName, base_class_id: StringName, evolution_id: StringName, purchased_ranks: Dictionary[StringName, int], catalog: ProfileCatalog) -> Dictionary:
	if not raw is Array or raw.size() != expected_size:
		return _error(&"invalid_presets")
	var slots: Array[Variant] = []
	var seen: Dictionary[StringName, bool] = {}
	for value: Variant in raw:
		if value != null and (not value is String or not IdentityIds.is_technical_id(value)):
			return _error(&"invalid_presets")
		if value == null:
			slots.append(null)
			continue
		var skill_id := StringName(value)
		var metadata := catalog.skill_metadata(skill_id)
		if metadata.is_empty() or not catalog.skill_is_allowed(skill_id, base_class_id, evolution_id):
			return _catalog_error(&"invalid_catalog")
		if metadata["category"] != category or seen.has(skill_id):
			return _catalog_error(&"invalid_presets") if metadata["category"] != category else _error(&"invalid_presets")
		if int(metadata["free_rank"]) + purchased_ranks.get(skill_id, 0) <= 0:
			return _error(&"requirements_unmet")
		seen[skill_id] = true
		slots.append(skill_id)
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
				profile.equipment_collection.append(item_id)
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
	return {"ok": true, "profile": profile, "migrated": true}

static func _profile_to_dictionary(profile: ProfileState) -> Dictionary:
	var data := profile.extension_fields.duplicate(true)
	data.merge({
		"format_id": ProfileState.FORMAT_ID,
		"schema_version": ProfileState.SCHEMA_VERSION,
		"catalog_version": ProfileState.CATALOG_VERSION,
		"ruleset_id": ProfileState.RULESET_ID,
		"profile_id": profile.profile_id,
		"revision": profile.revision,
		"next_character_counter": profile.next_character_counter,
		"next_run_counter": profile.next_run_counter,
		"selected_character_id": null if profile.selected_character_id.is_empty() else profile.selected_character_id,
		"equipment_collection": _names_to_strings(profile.equipment_collection),
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
		"purchased_skill_ranks": _integer_map_to_dictionary(character.purchased_skill_ranks),
		"equipped": _equipped_to_dictionary(character.equipped),
		"presets": presets,
		"selected_preset": character.selected_preset,
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
		result.append(null if value == null else String(value))
	return result

static func _copy_json_candidate(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

static func _character_equipment_is_valid(character: CharacterState, collection: Array[StringName], catalog: ProfileCatalog) -> bool:
	for slot: StringName in IdentityIds.equipment_slots():
		var value: Variant = character.equipped[slot]
		if value != null and (value not in collection or not catalog.equipment_is_allowed(value, slot, character.base_class_id)):
			return false
	for preset: Dictionary in character.presets:
		for slot: StringName in IdentityIds.equipment_slots():
			var value: Variant = preset["equipped"][slot]
			if value != null and (value not in collection or not catalog.equipment_is_allowed(value, slot, character.base_class_id)):
				return false
	return true

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
	if value == null or value is bool or value is String or value is int:
		return true
	if value is float:
		return is_finite(value)
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
