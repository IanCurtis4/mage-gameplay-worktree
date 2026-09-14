class_name ProfileCatalog
extends RefCounted
## Minimal persistence metadata. E03/E06 extend this catalog before new IDs are saved.

const ACTIVE: StringName = &"active"
const PASSIVE: StringName = &"passive"
const BASE_WALLET: StringName = &"base"
const EVOLUTION_WALLET: StringName = &"evolution"

var _skills: Dictionary[StringName, Dictionary] = {}
var _equipment: Dictionary[StringName, Dictionary] = {}
var _sealed := false

static func pilot(additional_equipment: Dictionary = {}) -> ProfileCatalog:
	var catalog := ProfileCatalog.new()
	catalog.add_skill(&"slash", [&"swordsman"], ACTIVE, BASE_WALLET, 1, 4)
	catalog.add_skill(&"dash", [&"swordsman"], ACTIVE, BASE_WALLET, 1, 4)
	catalog.add_skill(&"swordsman_resistance", [&"swordsman"], PASSIVE, BASE_WALLET, 1, 2)
	catalog.add_skill(&"fireball", [&"mage"], ACTIVE, BASE_WALLET, 1, 4)
	catalog.add_skill(&"fire_wall", [&"mage"], ACTIVE, BASE_WALLET, 1, 4)
	catalog.add_skill(&"fire_spear", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"ice_spear", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"teleport", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"mage_mana_regeneration", [&"mage"], PASSIVE, BASE_WALLET, 1, 2)
	for raw_item_id: Variant in additional_equipment:
		var metadata: Dictionary = additional_equipment[raw_item_id]
		var allowed_base_classes: Array[StringName] = []
		allowed_base_classes.assign(metadata.get("allowed_base_classes", []))
		catalog.add_equipment(StringName(raw_item_id), metadata.get("slot", &""), allowed_base_classes)
	return catalog.seal()

func add_skill(
	skill_id: StringName,
	allowed_base_classes: Array[StringName],
	category: StringName,
	wallet: StringName,
	free_rank: int,
	max_purchased_rank: int
) -> bool:
	if _sealed:
		return false
	_skills[skill_id] = {
		"allowed_base_classes": allowed_base_classes.duplicate(),
		"category": category,
		"wallet": wallet,
		"free_rank": free_rank,
		"max_purchased_rank": max_purchased_rank,
	}
	return true

func add_equipment(item_id: StringName, slot: StringName, allowed_base_classes: Array[StringName]) -> bool:
	if _sealed:
		return false
	_equipment[item_id] = {
		"slot": slot,
		"allowed_base_classes": allowed_base_classes.duplicate(),
	}
	return true

func seal() -> ProfileCatalog:
	_sealed = true
	return self

func copy_catalog() -> ProfileCatalog:
	var copy := ProfileCatalog.new()
	copy._skills = _skills.duplicate(true)
	copy._equipment = _equipment.duplicate(true)
	return copy.seal()

func is_valid() -> bool:
	for metadata: Dictionary in _skills.values():
		if metadata.get("category") not in [ACTIVE, PASSIVE] or metadata.get("wallet") not in [BASE_WALLET, EVOLUTION_WALLET]:
			return false
		if int(metadata.get("free_rank", -1)) < 0 or int(metadata.get("max_purchased_rank", -1)) < 0:
			return false
		if not _valid_origins(metadata.get("allowed_base_classes")):
			return false
	for metadata: Dictionary in _equipment.values():
		if metadata.get("slot") not in IdentityIds.equipment_slots() or not _valid_origins(metadata.get("allowed_base_classes")):
			return false
	return true

func skill_metadata(skill_id: StringName) -> Dictionary:
	return _skills.get(skill_id, {}).duplicate(true)

func equipment_metadata(item_id: StringName) -> Dictionary:
	return _equipment.get(item_id, {}).duplicate(true)

func knows_equipment(item_id: StringName) -> bool:
	return _equipment.has(item_id)

func skill_is_allowed(skill_id: StringName, base_class_id: StringName) -> bool:
	var metadata: Dictionary = _skills.get(skill_id, {})
	return not metadata.is_empty() and base_class_id in metadata["allowed_base_classes"]

func equipment_is_allowed(item_id: StringName, slot: StringName, base_class_id: StringName) -> bool:
	var metadata: Dictionary = _equipment.get(item_id, {})
	return not metadata.is_empty() and metadata["slot"] == slot and base_class_id in metadata["allowed_base_classes"]

func _valid_origins(value: Variant) -> bool:
	if not value is Array or value.is_empty():
		return false
	for base_class_id: Variant in value:
		if not base_class_id is StringName or not IdentityIds.is_base_class(base_class_id):
			return false
	return true
