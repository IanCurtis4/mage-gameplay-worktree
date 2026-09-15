class_name BuildSnapshot
extends RefCounted
## Value snapshot copied from persistent character state at run start.

var ruleset_id: String = ProfileState.RULESET_ID
var catalog_version: int = ProfileState.CATALOG_VERSION
var character_id: String
var base_class_id: StringName
var evolution_id: StringName = &""
var base_level: int = 1
var job_level: int = 1
var attribute_allocations: Dictionary[StringName, int] = {}
var skill_ranks: Dictionary[StringName, int] = {}
var active_slots: Array[Variant] = []
var passive_slots: Array[Variant] = []
var equipped: Dictionary[StringName, Variant] = {}
var build_version: int = 1

static func from_character(
	character: CharacterState,
	derived_base_level: int,
	derived_job_level: int,
	effective_skill_ranks: Dictionary[StringName, int]
) -> BuildSnapshot:
	assert(character != null)
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = character.character_id
	snapshot.base_class_id = character.base_class_id
	snapshot.evolution_id = character.evolution_id
	snapshot.base_level = derived_base_level
	snapshot.job_level = derived_job_level
	snapshot.attribute_allocations = character.attribute_allocations.duplicate(true)
	snapshot.skill_ranks = effective_skill_ranks.duplicate(true)
	var preset: Dictionary = character.presets[character.selected_preset]
	snapshot.active_slots = preset["active_slots"].duplicate(true)
	snapshot.passive_slots = preset["passive_slots"].duplicate(true)
	snapshot.equipped = preset["equipped"].duplicate(true)
	return snapshot

func copy_snapshot() -> BuildSnapshot:
	var copy := BuildSnapshot.new()
	copy.ruleset_id = ruleset_id
	copy.catalog_version = catalog_version
	copy.character_id = character_id
	copy.base_class_id = base_class_id
	copy.evolution_id = evolution_id
	copy.base_level = base_level
	copy.job_level = job_level
	copy.attribute_allocations = attribute_allocations.duplicate(true)
	copy.skill_ranks = skill_ranks.duplicate(true)
	copy.active_slots = active_slots.duplicate(true)
	copy.passive_slots = passive_slots.duplicate(true)
	copy.equipped = equipped.duplicate(true)
	copy.build_version = build_version
	return copy
