class_name EquipmentInstance
extends RefCounted
## Acquisition data copied by value. Cards and combat state never persist here.

var owner_character_id: String = ""
var instance_id: StringName
var definition_id: StringName
var origin_id: StringName
var item_level: int
var quality_id: StringName
var socket_capacity: int
var recipe_revision_id: StringName = &"catalog_v1"
var power_ruleset_id: StringName = &"legacy_unscaled"

func copy_instance() -> EquipmentInstance:
	var copy := EquipmentInstance.new()
	copy.owner_character_id = owner_character_id
	copy.instance_id = instance_id
	copy.definition_id = definition_id
	copy.origin_id = origin_id
	copy.item_level = item_level
	copy.quality_id = quality_id
	copy.socket_capacity = socket_capacity
	copy.recipe_revision_id = recipe_revision_id
	copy.power_ruleset_id = power_ruleset_id
	return copy

func to_record() -> Dictionary:
	return {"instance_id": String(instance_id), "definition_id": String(definition_id), "origin_id": String(origin_id), "item_level": item_level, "quality_id": String(quality_id), "socket_capacity": socket_capacity, "recipe_revision_id": String(recipe_revision_id), "power_ruleset_id": String(power_ruleset_id)}

static func from_record(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size() not in [6, 8]:
		return BuildEffectCatalog.failure(&"invalid_equipment_instance")
	for field: String in ["instance_id", "definition_id", "origin_id", "quality_id"]:
		if typeof(raw.get(field)) not in [TYPE_STRING, TYPE_STRING_NAME] or not IdentityIds.is_technical_id(String(raw[field])):
			return BuildEffectCatalog.failure(&"invalid_equipment_instance")
	if not EquipmentRules.exact_integer(raw.get("item_level"), 1) or not EquipmentRules.exact_integer(raw.get("socket_capacity"), 0, 4) or StringName(raw["quality_id"]) not in EquipmentRules.QUALITY_IDS:
		return BuildEffectCatalog.failure(&"invalid_equipment_instance")
	var revision: Variant = raw.get("recipe_revision_id", "catalog_v1")
	var power: Variant = raw.get("power_ruleset_id", "legacy_unscaled")
	if typeof(revision) not in [TYPE_STRING, TYPE_STRING_NAME] or typeof(power) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return BuildEffectCatalog.failure(&"invalid_equipment_power")
	if raw.size() == 8 and (not raw.has("recipe_revision_id") or not raw.has("power_ruleset_id")):
		return BuildEffectCatalog.failure(&"invalid_equipment_power")
	var instance := EquipmentInstance.new()
	instance.instance_id = StringName(raw["instance_id"])
	instance.definition_id = StringName(raw["definition_id"])
	instance.origin_id = StringName(raw["origin_id"])
	instance.item_level = int(raw["item_level"])
	instance.quality_id = StringName(raw["quality_id"])
	instance.socket_capacity = int(raw["socket_capacity"])
	instance.recipe_revision_id = StringName(revision)
	instance.power_ruleset_id = StringName(power)
	var checked := EquipmentPowerRules.validate_instance(instance)
	if not checked["ok"]: return checked
	return {"ok": true, "instance": instance}

static func from_metadata(id: StringName, definition: StringName, metadata: Dictionary) -> Dictionary:
	return from_record({"instance_id": id, "definition_id": definition, "origin_id": metadata.get("origin_id"), "item_level": metadata.get("item_level"), "quality_id": metadata.get("quality_id"), "socket_capacity": metadata.get("socket_capacity"), "recipe_revision_id": metadata.get("recipe_revision_id", &"catalog_v1"), "power_ruleset_id": metadata.get("power_ruleset_id", &"legacy_unscaled")})
