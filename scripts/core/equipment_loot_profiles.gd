class_name EquipmentLootProfiles
extends RefCounted
## Approved E06 rates. Production uses authored nominal tiers and fixed growth refs.
const LEGACY_IDS: Array[StringName] = [&"starter_blade", &"starter_staff", &"starter_bow", &"traveler_vest", &"traveler_charm", &"riposte_blade", &"ember_staff", &"hunters_bow", &"warden_mail", &"channeler_robe", &"trailcoat", &"prismatic_charm"]
const CHANCES := {&"normal": 0.04, &"rare": 1.0, &"elite": 0.12, &"rare_elite": 1.0, &"boss": 1.0}
const CARDS := {&"normal": 0.02, &"rare": 0.06, &"elite": 0.08, &"rare_elite": 0.16, &"boss": 0.40}
const QUALITY_WEIGHTS := {
	&"normal": {&"common": 790, &"uncommon": 200, &"rare": 9, &"epic": 1},
	&"rare": {&"uncommon": 900, &"rare": 90, &"epic": 10},
	&"elite": {&"common": 790, &"uncommon": 200, &"rare": 9, &"epic": 1},
	&"rare_elite": {&"rare": 900, &"epic": 100},
	&"boss": {&"epic": 980, &"legendary": 20},
}
static func production(catalog: BuildEffectCatalog) -> MobLootTable:
	var table := MobLootTable.new()
	table.strict_quality_pools = true
	table.recipe_revision_id = &"catalog_v1"
	table.power_ruleset_id = &"equipment_growth_v1"
	table.cardless_base_ids = [&"demo_chaser", &"demo_archer"]
	for category: StringName in CHANCES:
		var equipment: Dictionary = {}
		for id: StringName in catalog.ids(&"equipment"):
			var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
			if id in LEGACY_IDS or item.starter or item.quality_id == &"legendary" and category != &"boss": continue
			equipment[id] = 1
		table.profiles[category] = {"equipment_chance": CHANCES[category], "card_chance": CARDS[category], "quality_weights": QUALITY_WEIGHTS[category].duplicate(true), "equipment_weights": equipment, "socket_weights": {0: 60, 1: 25, 2: 10, 3: 4, 4: 1}}
	return table
