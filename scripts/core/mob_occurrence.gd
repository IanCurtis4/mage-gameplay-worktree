class_name MobOccurrence
extends RefCounted
## Frozen identity of a spawn, never a persistent catalog Resource.
var occurrence_id: String
var mob_base_id: StringName
var category_id: StringName
var origin_id: StringName
func copy_occurrence() -> MobOccurrence:
	var result := MobOccurrence.new()
	result.occurrence_id = occurrence_id
	result.mob_base_id = mob_base_id
	result.category_id = category_id
	result.origin_id = origin_id
	return result
func validate(catalog: MobCatalog) -> Dictionary:
	if catalog == null or not IdentityIds.is_technical_id(occurrence_id) or not IdentityIds.is_technical_id(String(origin_id)):
		return BuildEffectCatalog.failure(&"invalid_occurrence")
	var definition := catalog.get_definition(mob_base_id)
	if definition == null or category_id not in definition.allowed_occurrence_categories:
		return BuildEffectCatalog.failure(&"invalid_mob_category")
	return catalog.level_for_occurrence(self)
