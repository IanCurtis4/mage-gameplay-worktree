class_name ProfileState
extends RefCounted
## Persistent profile-owned state. Persistence mechanics are introduced in E01.2.

const FORMAT_ID := "ragrpg_character_profile"
const SCHEMA_VERSION := 7
const CATALOG_VERSION := 14
const RULESET_ID := "stat_thresholds_v1"
const MAX_CHARACTERS := 8

var profile_id: String
var revision: int = 0
var next_character_counter: int = 1
var next_run_counter: int = 1
var selected_character_id: String = ""
var equipment_instances: Dictionary[StringName, EquipmentInstance] = {}
var next_equipment_counter: int = 1
var card_inventory := RunCardInventory.new()
# Read-only compatibility DTO. Mutating the returned array never mutates ownership.
var equipment_collection: Array[StringName]:
	get: return equipment_instance_ids()
# Used only while decoding a validated historical envelope; never serialized.
var _migration_equipment_ids: Array[StringName] = []
var characters: Array[CharacterState] = []
var settings: Dictionary = {}
var lifetime_stats: Dictionary[StringName, int] = {
	&"runs_started": 0,
	&"runs_completed": 0,
	&"deaths": 0,
	&"kills": 0,
	&"equipment_unlocked": 0,
}
var reward_session: Variant = null
var legacy_loadouts: Dictionary = {}
var unresolved_legacy: Dictionary = {}
var extension_fields: Dictionary = {}

func _init(new_profile_id: String = "") -> void:
	profile_id = new_profile_id

func character_by_id(search_id: String) -> CharacterState:
	for character: CharacterState in characters:
		if character.character_id == search_id:
			return character
	return null

func copy_state() -> ProfileState:
	var copy := ProfileState.new(profile_id)
	copy.revision = revision
	copy.next_character_counter = next_character_counter
	copy.next_run_counter = next_run_counter
	copy.selected_character_id = selected_character_id
	copy.next_equipment_counter = next_equipment_counter
	copy.card_inventory = card_inventory.copy_inventory()
	for id: StringName in equipment_instances:
		copy.equipment_instances[id] = equipment_instances[id].copy_instance()
	copy._migration_equipment_ids = _migration_equipment_ids.duplicate()
	for character: CharacterState in characters:
		copy.characters.append(character.copy_state())
	copy.settings = settings.duplicate(true)
	copy.lifetime_stats = lifetime_stats.duplicate(true)
	copy.reward_session = reward_session.duplicate(true) if reward_session is Dictionary or reward_session is Array else reward_session
	copy.legacy_loadouts = legacy_loadouts.duplicate(true)
	copy.unresolved_legacy = unresolved_legacy.duplicate(true)
	copy.extension_fields = extension_fields.duplicate(true)
	return copy

func equipment_instance_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(equipment_instances.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).trim_prefix("equipment_").to_int() < String(b).trim_prefix("equipment_").to_int())
	return ids

func first_instance_for_definition(id: StringName) -> StringName:
	for instance_id: StringName in equipment_instance_ids():
		if equipment_instances[instance_id].definition_id == id:
			return instance_id
	return &""

func add_equipment_instance(id: StringName, metadata: Dictionary) -> Dictionary:
	if next_equipment_counter < 1 or next_equipment_counter >= EquipmentRules.MAX_EXACT_INTEGER:
		return BuildEffectCatalog.failure(&"invalid_equipment_counter")
	var instance_id := StringName("equipment_%d" % next_equipment_counter)
	if equipment_instances.has(instance_id):
		return BuildEffectCatalog.failure(&"duplicate_equipment_instance")
	var created := EquipmentInstance.from_metadata(instance_id, id, metadata)
	if not created["ok"]:
		return created
	var instance: EquipmentInstance = created["instance"]
	var checked := EquipmentRules.validate_instance(instance, metadata)
	if not checked["ok"]:
		return checked
	equipment_instances[instance_id] = instance
	next_equipment_counter += 1
	return {"ok": true, "instance_id": instance_id}
