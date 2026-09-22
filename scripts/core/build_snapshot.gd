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

func stat_breakdown(modifier_sources: Array[Dictionary] = []) -> StatBreakdown:
	var result := try_stat_breakdown(modifier_sources)
	return result.get("breakdown") if result["ok"] else null

func try_stat_breakdown(modifier_sources: Array[Dictionary] = []) -> Dictionary:
	var all_sources := intrinsic_modifier_sources()
	all_sources.append_array(modifier_sources.duplicate(true))
	return StatCalculator.try_calculate(
		IdentityIds.initial_attributes(base_class_id),
		attribute_allocations.duplicate(true),
		base_level,
		all_sources
	)

func intrinsic_modifier_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if &"swordsman_resistance" in passive_slots:
		var resistance_source := ClassCatalog.passive_modifier_source(
			&"swordsman_resistance",
			int(skill_ranks.get(&"swordsman_resistance", 0))
		)
		if not resistance_source.is_empty():
			sources.append(resistance_source)
	if &"mage_mana_regeneration" in passive_slots and int(skill_ranks.get(&"mage_mana_regeneration", 0)) > 0:
		sources.append({
			"source_id": &"passive_mage_sp_regeneration",
			"label": "Regeneração de SP do Mago",
			"increased": {&"sp_regen": 0.50},
		})
	return sources
