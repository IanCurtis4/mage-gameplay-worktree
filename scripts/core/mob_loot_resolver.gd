class_name MobLootResolver
extends RefCounted
## Pure explicit-table resolution. No default rates and no RNG mutation here.
const FLOORS := {&"rare": &"uncommon", &"rare_elite": &"rare", &"boss": &"epic"}
var _catalog: BuildEffectCatalog
var _profiles: Dictionary = {}
var _strict_quality_pools := false
var _recipe_revision_id: StringName = &"catalog_v1"
var _power_ruleset_id: StringName = &"legacy_unscaled"
var _cardless_base_ids: Array[StringName] = []
static func create(catalog: BuildEffectCatalog, table: MobLootTable) -> Dictionary:
	if catalog == null or table == null or table.profiles.is_empty():
		return BuildEffectCatalog.failure(&"invalid_loot_table")
	var resolver := MobLootResolver.new()
	resolver._catalog = catalog.copy_catalog()
	if table.recipe_revision_id != &"catalog_v1" or table.power_ruleset_id not in [&"legacy_unscaled", &"equipment_growth_v1"]:
		return BuildEffectCatalog.failure(&"invalid_equipment_power")
	resolver._strict_quality_pools = table.strict_quality_pools
	resolver._recipe_revision_id = table.recipe_revision_id
	resolver._power_ruleset_id = table.power_ruleset_id
	resolver._cardless_base_ids = table.cardless_base_ids.duplicate()
	for id: StringName in resolver._cardless_base_ids:
		var definition := catalog.mob_catalog().get_definition(id)
		if definition == null or not definition.card_id.is_empty():
			return BuildEffectCatalog.failure(&"invalid_loot_table")
	for raw_category: Variant in table.profiles:
		if typeof(raw_category) not in [TYPE_STRING, TYPE_STRING_NAME] or StringName(raw_category) not in MobCatalog.CATEGORIES:
			return BuildEffectCatalog.failure(&"invalid_loot_table")
		var category := StringName(raw_category)
		var raw: Variant = table.profiles[raw_category]
		if not raw is Dictionary or raw.size() != 5:
			return BuildEffectCatalog.failure(&"invalid_loot_table")
		for key: String in ["equipment_chance", "card_chance"]:
			if typeof(raw.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(raw[key])) or raw[key] < 0.0 or raw[key] > 1.0:
				return BuildEffectCatalog.failure(&"invalid_loot_chance")
		for key: String in ["quality_weights", "equipment_weights", "socket_weights"]:
			if not _valid_weights(raw.get(key)):
				return BuildEffectCatalog.failure(&"invalid_loot_weights")
		for quality: Variant in raw["quality_weights"]:
			if typeof(quality) not in [TYPE_STRING, TYPE_STRING_NAME] or StringName(quality) not in EquipmentRules.QUALITY_IDS:
				return BuildEffectCatalog.failure(&"invalid_loot_table")
			if quality == &"legendary" and category != &"boss":
				return BuildEffectCatalog.failure(&"legendary_requires_boss")
		for id: Variant in raw["equipment_weights"]:
			if typeof(id) not in [TYPE_STRING, TYPE_STRING_NAME]:
				return BuildEffectCatalog.failure(&"invalid_loot_table")
			var item := catalog.get_definition(&"equipment", StringName(id)) as EquipmentDefinition
			if item == null:
				return BuildEffectCatalog.failure(&"invalid_loot_table")
			var checked := EquipmentInstance.from_metadata(&"loot_validation", item.id, item.metadata())
			if not checked["ok"] or not EquipmentRules.validate_instance(checked["instance"], item.metadata())["ok"]:
				return BuildEffectCatalog.failure(&"invalid_loot_table")
		for socket: Variant in raw["socket_weights"]:
			if typeof(socket) != TYPE_INT or socket < 0 or socket > 4:
				return BuildEffectCatalog.failure(&"invalid_loot_table")
		resolver._profiles[category] = raw.duplicate(true)
		for quality: Variant in raw["quality_weights"]:
			var effective := minimum_quality(category, StringName(quality))
			if resolver._item_pool(category, effective).is_empty():
				return BuildEffectCatalog.failure(&"empty_guaranteed_pool" if FLOORS.has(category) else &"invalid_loot_table")
	return {"ok": true, "resolver": resolver}
func validate_occurrence(occurrence: MobOccurrence) -> Dictionary:
	if occurrence == null:
		return BuildEffectCatalog.failure(&"invalid_occurrence")
	var checked := occurrence.validate(_catalog.mob_catalog())
	if not checked["ok"]:
		return checked
	if not _profiles.has(occurrence.category_id):
		return BuildEffectCatalog.failure(&"invalid_loot_table")
	var definition: MobDefinition = checked["definition"]
	if _power_ruleset_id == &"equipment_growth_v1" and definition.fixed_level > 30:
		return BuildEffectCatalog.failure(&"invalid_equipment_power")
	if float(_profiles[occurrence.category_id]["card_chance"]) > 0.0 and definition.id not in _cardless_base_ids:
		var card := _catalog.get_definition(&"card", definition.card_id) as CardDefinition
		if card == null or card.mob_base_id != definition.id:
			return BuildEffectCatalog.failure(&"missing_mob_base")
	return checked
func roll(occurrence: MobOccurrence, uniforms: Array) -> Dictionary:
	var checked := validate_occurrence(occurrence)
	if not checked["ok"]:
		return checked
	if uniforms.size() != 5:
		return BuildEffectCatalog.failure(&"invalid_loot_roll")
	for value: Variant in uniforms:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value < 0 or value > 1:
			return BuildEffectCatalog.failure(&"invalid_loot_roll")
	var row: Dictionary = _profiles[occurrence.category_id]
	var mob: MobDefinition = checked["definition"]
	var drops: Array[Dictionary] = []
	if FLOORS.has(occurrence.category_id) or _passes(float(uniforms[0]), float(row["equipment_chance"])):
		var quality := minimum_quality(occurrence.category_id, StringName(_weighted(row["quality_weights"], float(uniforms[1]), EquipmentRules.QUALITY_IDS)))
		var id := StringName(_weighted(_item_pool(occurrence.category_id, quality), float(uniforms[2])))
		var item := _catalog.get_definition(&"equipment", id) as EquipmentDefinition
		var sockets := int(_weighted(row["socket_weights"], float(uniforms[3]))) if EquipmentRules.allows_sockets(item.metadata()) else 0
		drops.append({"definition_id": id, "origin_id": occurrence.origin_id, "item_level": mob.fixed_level, "quality_id": quality, "socket_capacity": sockets, "recipe_revision_id": _recipe_revision_id, "power_ruleset_id": _power_ruleset_id})
	var card: StringName = mob.card_id if mob.id not in _cardless_base_ids and _passes(float(uniforms[4]), float(row["card_chance"])) else &""
	return {"ok": true, "equipment_drops": drops, "card_id": card, "mob_base_id": mob.id, "category_id": occurrence.category_id, "occurrence_id": occurrence.occurrence_id}
func _item_pool(category: StringName, quality: StringName) -> Dictionary:
	var result: Dictionary = {}
	for raw_id: Variant in _profiles[category]["equipment_weights"]:
		var id := StringName(raw_id)
		var item := _catalog.get_definition(&"equipment", id) as EquipmentDefinition
		if (not _strict_quality_pools or item.quality_id == quality) and _catalog.validate_equipment_quality(item, quality)["ok"]:
			result[id] = _profiles[category]["equipment_weights"][raw_id]
	return result
static func minimum_quality(category: StringName, quality: StringName) -> StringName:
	var floor_quality: StringName = FLOORS.get(category, &"common")
	return quality if EquipmentRules.QUALITY_IDS.find(quality) >= EquipmentRules.QUALITY_IDS.find(floor_quality) else floor_quality
static func _passes(value: float, chance: float) -> bool:
	return chance >= 1.0 or value < chance
static func _valid_weights(raw: Variant) -> bool:
	if not raw is Dictionary or raw.is_empty():
		return false
	var total := 0.0
	for value: Variant in raw.values():
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value <= 0.0:
			return false
		total += float(value)
	return is_finite(total) and total > 0.0
static func _weighted(weights: Dictionary, uniform: float, order: Array = []) -> Variant:
	var keys: Array = []
	if order.is_empty():
		keys = weights.keys()
		keys.sort()
	else:
		for key: Variant in order:
			if weights.has(key): keys.append(key)
	var total := 0.0
	for value: Variant in weights.values(): total += float(value)
	var cursor := 0.0
	for key: Variant in keys:
		cursor += float(weights[key])
		if uniform < cursor / total: return key
	return keys.back()
