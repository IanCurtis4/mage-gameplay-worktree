class_name MobTierRules
extends RefCounted
## Central tier contributions; actors consume the resulting canonical breakdown.
const HP := [1.0, 1.5, 2.2, 3.0, 6.0]
const DAMAGE := [1.0, 1.10, 1.20, 1.30, 1.50]
static func lower_category(category: StringName) -> StringName:
	var index := MobCatalog.CATEGORIES.find(category)
	return MobCatalog.CATEGORIES[index - 1] if index > 0 else &""
static func sources(definition: MobDefinition, category: StringName, base: StatBreakdown) -> Array[Dictionary]:
	var result: Array[Dictionary] = definition.modifier_sources.duplicate(true)
	if not definition.encounter_tiers: return result
	var index := MobCatalog.CATEGORIES.find(category)
	var increased := {}
	for pair: Array in [[&"max_hp", HP[index]], [&"damage_dealt_multiplier", DAMAGE[index]]]:
		increased[pair[0]] = (1.0 + float(base.derived_detail(pair[0])["increased"])) * (float(pair[1]) - 1.0)
	result.append({"source_id": &"mob_occurrence_tier", "increased": increased})
	return result
