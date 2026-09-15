class_name ProfileState
extends RefCounted
## Persistent profile-owned state. Persistence mechanics are introduced in E01.2.

const FORMAT_ID := "ragrpg_character_profile"
const SCHEMA_VERSION := 2
const CATALOG_VERSION := 1
const RULESET_ID := "e00_v1"
const MAX_CHARACTERS := 8

var profile_id: String
var revision: int = 0
var next_character_counter: int = 1
var next_run_counter: int = 1
var selected_character_id: String = ""
var equipment_collection: Array[StringName] = []
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
	copy.equipment_collection = equipment_collection.duplicate()
	for character: CharacterState in characters:
		copy.characters.append(character.copy_state())
	copy.settings = settings.duplicate(true)
	copy.lifetime_stats = lifetime_stats.duplicate(true)
	copy.reward_session = reward_session.duplicate(true) if reward_session is Dictionary or reward_session is Array else reward_session
	copy.legacy_loadouts = legacy_loadouts.duplicate(true)
	copy.unresolved_legacy = unresolved_legacy.duplicate(true)
	copy.extension_fields = extension_fields.duplicate(true)
	return copy
