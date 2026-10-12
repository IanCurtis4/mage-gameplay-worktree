class_name EquipmentRules
extends RefCounted
## Single equipment compatibility and capacity authority; no combat formulas.

const QUALITY_IDS: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
const ARMOR_SLOTS: Array[StringName] = [&"head", &"shoulders", &"arms", &"torso", &"cloak", &"legs", &"feet"]
const LEGACY_SLOTS: Array[StringName] = [&"weapon", &"armor", &"accessory"]
const MAX_EXACT_INTEGER := 9007199254740991

static func exact_integer(value: Variant, minimum: int, maximum: int = MAX_EXACT_INTEGER) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

static func empty_layout() -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for slot: StringName in IdentityIds.equipment_slots():
		result[slot] = null
	return result

static func legacy_position(slot: StringName) -> StringName:
	return {&"weapon": &"main_hand", &"armor": &"torso", &"accessory": &"accessory_1"}.get(slot, slot)

static func definition_slot(slot: StringName) -> StringName:
	return &"accessory" if slot in [&"accessory_1", &"accessory_2", &"accessory_3", &"accessory_4"] else {&"weapon": &"main_hand", &"armor": &"torso"}.get(slot, slot)

static func default_kind(slot: StringName) -> StringName:
	var category := definition_slot(slot)
	if category in ARMOR_SLOTS:
		return &"armor"
	if category == &"main_hand":
		return &"weapon"
	if category == &"off_hand":
		return &"shield"
	return &"jewelry"

static func slot_matches(category: StringName, position: StringName) -> bool:
	return position in [&"accessory_1", &"accessory_2", &"accessory_3", &"accessory_4"] if category == &"accessory" else category == position

static func allows_sockets(metadata: Dictionary) -> bool:
	return metadata.get("item_kind") in [&"armor", &"weapon", &"shield"]

static func validate_definition(metadata: Dictionary) -> Dictionary:
	for field: String in ["slot", "item_kind", "hand_usage"]:
		if typeof(metadata.get(field)) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return BuildEffectCatalog.failure(&"invalid_equipment_definition")
	var slot := StringName(metadata.get("slot", &""))
	var kind := StringName(metadata.get("item_kind", &""))
	var hands := StringName(metadata.get("hand_usage", &"none"))
	if slot in ARMOR_SLOTS:
		if kind != &"armor" or hands != &"none":
			return BuildEffectCatalog.failure(&"invalid_slot")
	elif slot == &"main_hand":
		if kind != &"weapon" or hands not in [&"one_hand", &"two_hands"]:
			return BuildEffectCatalog.failure(&"invalid_hand_configuration")
	elif slot == &"off_hand":
		if kind not in [&"shield", &"focus"] or hands != &"none":
			return BuildEffectCatalog.failure(&"invalid_hand_configuration")
	elif slot == &"neck" or slot == &"accessory":
		if kind != &"jewelry" or hands != &"none":
			return BuildEffectCatalog.failure(&"invalid_slot")
	else:
		return BuildEffectCatalog.failure(&"invalid_slot")
	return {"ok": true}

static func validate_instance(instance: EquipmentInstance, metadata: Dictionary) -> Dictionary:
	if instance == null or metadata.is_empty():
		return BuildEffectCatalog.failure(&"unknown_equipment_instance")
	var checked := EquipmentInstance.from_record(instance.to_record())
	if not checked["ok"]:
		return checked
	if instance.socket_capacity > 0 and not allows_sockets(metadata):
		return BuildEffectCatalog.failure(&"socket_not_allowed")
	return validate_definition(metadata)

static func validate_layout(equipped: Dictionary, instances: Dictionary, definitions: Dictionary, origin: StringName, evolution: StringName) -> Dictionary:
	if equipped.size() != IdentityIds.equipment_slots().size():
		return BuildEffectCatalog.failure(&"invalid_equipment")
	var seen: Dictionary = {}
	var accessories: Dictionary = {}
	for slot: StringName in IdentityIds.equipment_slots():
		if not equipped.has(slot):
			return BuildEffectCatalog.failure(&"invalid_equipment")
		var raw_id: Variant = equipped[slot]
		if raw_id == null:
			continue
		if typeof(raw_id) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return BuildEffectCatalog.failure(&"invalid_equipment_instance")
		var id := StringName(raw_id)
		var instance: EquipmentInstance = instances.get(id)
		if instance == null or instance.instance_id != id:
			return BuildEffectCatalog.failure(&"unknown_equipment_instance")
		if seen.has(id):
			return BuildEffectCatalog.failure(&"duplicate_equipment_instance")
		seen[id] = true
		var metadata: Dictionary = definitions.get(instance.definition_id, {})
		var checked := validate_instance(instance, metadata)
		if not checked["ok"]:
			return checked
		if not slot_matches(metadata["slot"], slot):
			return BuildEffectCatalog.failure(&"slot_restricted")
		if origin not in metadata["allowed_base_classes"] or (not metadata["allowed_evolutions"].is_empty() and evolution not in metadata["allowed_evolutions"]):
			return BuildEffectCatalog.failure(&"identity_restricted")
		if metadata["slot"] == &"accessory":
			if accessories.has(instance.definition_id):
				return BuildEffectCatalog.failure(&"identical_accessory")
			accessories[instance.definition_id] = true
	var main: Variant = equipped.get(&"main_hand")
	if main != null:
		var instance: EquipmentInstance = instances[StringName(main)]
		if definitions[instance.definition_id]["hand_usage"] == &"two_hands" and equipped[&"off_hand"] != null:
			return BuildEffectCatalog.failure(&"invalid_hand_configuration")
	return {"ok": true}
