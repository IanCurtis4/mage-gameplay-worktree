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
var library_skill_ids: Array[StringName] = []
var active_slots: Array[Variant] = []
var passive_slots: Array[Variant] = []
var equipped: Dictionary[StringName, Variant] = {}
var build_version: int = 1
var action_slots: Array[Variant] = []
var _skill_catalog := ProfileCatalog.pilot()

static func from_character(
	character: CharacterState,
	derived_base_level: int,
	derived_job_level: int,
	effective_skill_ranks: Dictionary[StringName, int],
	identity_skill_ids: Array[StringName] = [],
	catalog: ProfileCatalog = null
) -> BuildSnapshot:
	assert(character != null)
	var snapshot := BuildSnapshot.new()
	if catalog != null:
		snapshot._skill_catalog = catalog.copy_catalog()
	snapshot.character_id = character.character_id
	snapshot.base_class_id = character.base_class_id
	snapshot.evolution_id = character.evolution_id
	snapshot.base_level = derived_base_level
	snapshot.job_level = derived_job_level
	snapshot.attribute_allocations = character.attribute_allocations.duplicate(true)
	snapshot.skill_ranks = effective_skill_ranks.duplicate(true)
	snapshot.library_skill_ids = identity_skill_ids.duplicate()
	var preset: Dictionary = character.presets[character.selected_preset]
	snapshot.active_slots = preset["active_slots"].duplicate(true)
	snapshot.passive_slots = preset["passive_slots"].duplicate(true)
	snapshot.equipped = preset["equipped"].duplicate(true)
	snapshot.action_slots = ActionBarLayout.for_character(character)
	return snapshot

func copy_snapshot() -> BuildSnapshot:
	var copy := BuildSnapshot.new()
	copy._skill_catalog = _skill_catalog.copy_catalog()
	copy.ruleset_id = ruleset_id
	copy.catalog_version = catalog_version
	copy.character_id = character_id
	copy.base_class_id = base_class_id
	copy.evolution_id = evolution_id
	copy.base_level = base_level
	copy.job_level = job_level
	copy.attribute_allocations = attribute_allocations.duplicate(true)
	copy.skill_ranks = skill_ranks.duplicate(true)
	copy.library_skill_ids = library_skill_ids.duplicate()
	copy.active_slots = active_slots.duplicate(true)
	copy.passive_slots = passive_slots.duplicate(true)
	copy.equipped = equipped.duplicate(true)
	copy.build_version = build_version
	copy.action_slots = action_slots.duplicate()
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
	var seen: Dictionary[StringName, bool] = {}
	for raw_passive_id: Variant in learned_skill_ids(ProfileCatalog.PASSIVE):
		if raw_passive_id == null:
			continue
		var passive_id := StringName(raw_passive_id)
		if seen.has(passive_id):
			continue
		seen[passive_id] = true
		var source := ClassCatalog.passive_modifier_source(
			passive_id,
			int(skill_ranks.get(passive_id, 0)),
			float(attribute_allocations.get(&"vit", 0))
		)
		if not source.is_empty():
			sources.append(source)
	return sources

func intrinsic_rule_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	var seen: Dictionary[StringName, bool] = {}
	for raw_passive_id: Variant in learned_skill_ids(ProfileCatalog.PASSIVE):
		if raw_passive_id == null:
			continue
		var passive_id := StringName(raw_passive_id)
		if seen.has(passive_id):
			continue
		seen[passive_id] = true
		var source := ClassCatalog.passive_rule_source(
			passive_id,
			int(skill_ranks.get(passive_id, 0))
		)
		if not source.is_empty():
			sources.append(source)
	return sources

func trap_armed_duration(base_duration: float) -> float:
	assert(is_finite(base_duration) and base_duration > 0.0)
	var bonus := 0.0
	for source: Dictionary in intrinsic_rule_sources():
		bonus += float(source.get("armed_duration_bonus", 0.0))
	return base_duration + bonus

func learned_skill_ids(category: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var catalog := _skill_catalog
	for id: StringName in catalog.skill_ids_for_identity(base_class_id, evolution_id):
		if not library_skill_ids.is_empty() and id not in library_skill_ids:
			continue
		var metadata := catalog.skill_metadata(id)
		var rank := int(skill_ranks.get(id, 0))
		if rank <= 0 or metadata["category"] != category:
			continue
		if not catalog.check_rank_requirements(id, 1, job_level, skill_ranks)["ok"]:
			continue
		result.append(id)
	return result

func has_passive(id: StringName) -> bool:
	var metadata := _skill_catalog.skill_metadata(id)
	return not metadata.is_empty() and metadata["category"] == ProfileCatalog.PASSIVE and int(skill_ranks.get(id, 0)) > 0 and _skill_catalog.skill_is_allowed(id, base_class_id, evolution_id) and (library_skill_ids.is_empty() or id in library_skill_ids) and _skill_catalog.check_rank_requirements(id, 1, job_level, skill_ranks)["ok"]
