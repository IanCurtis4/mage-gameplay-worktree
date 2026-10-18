class_name ExpeditionSpeciesDefinition
extends Resource
## Spatial eligibility only. Stats/loot remain with their existing authorities.
@export var species_id: String = ""
@export var revision: int = 0
@export var biome_tags: PackedStringArray = PackedStringArray()
@export var occurrence_categories: PackedStringArray = PackedStringArray()
@export var required_site_tags: PackedStringArray = PackedStringArray()

func to_data() -> Dictionary:
	var biomes := Array(biome_tags)
	var categories := Array(occurrence_categories)
	var tags := Array(required_site_tags)
	biomes.sort(); categories.sort(); tags.sort()
	return {"species_id": species_id,"revision": revision,"biome_tags": biomes,"occurrence_categories": categories,"required_site_tags": tags}
