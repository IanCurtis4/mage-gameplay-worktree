class_name EquipmentEligibilityRules
extends RefCounted
## A single optional policy for new recipes; absence preserves legacy contracts.
const CURRENT_IDENTITIES: Array[StringName] = [&"swordsman",&"mage",&"archer",&"defender",&"berserker",&"elementalist",&"spiritualist",&"sentinel",&"hunter",&"mg_ar"]
## E09 C1.10: kit hybrids are eligible restriction identities. Kept apart from
## CURRENT_IDENTITIES, which also enumerates the identities that own class sets.
const KIT_IDENTITIES: Array[StringName] = [&"sp_ac",&"mg_ac",&"sp_la",&"mg_la"]
## E10a C1.10: the registered bases and their pure kits (acolyte, priest, cultist) are
## eligible restriction identities too, read from the registries.
static func family_identities() -> Array[StringName]:
	var ids: Array[StringName] = ClassBaseRegistry.ids()
	ids.append_array(ClassKitRegistry.pure_ids())
	return ids
static func eligible_identities() -> Array[StringName]:
	var ids: Array[StringName] = CURRENT_IDENTITIES.duplicate()
	ids.append_array(KIT_IDENTITIES)
	ids.append_array(family_identities())
	return ids
static func validate(policy: Dictionary) -> Dictionary:
	if not EquipmentRules.exact_integer(policy.get("min_item_level",1),1,30) or not EquipmentRules.exact_integer(policy.get("max_item_level",30),1,30) or int(policy.get("min_item_level",1)) > int(policy.get("max_item_level",30)) or not policy.get("allowed_identities",[]) is Array: return BuildEffectCatalog.failure(&"invalid_equipment_eligibility")
	var seen := {}
	for id: Variant in policy.get("allowed_identities",[]):
		if typeof(id) not in [TYPE_STRING,TYPE_STRING_NAME] or (StringName(id) not in CURRENT_IDENTITIES and StringName(id) not in KIT_IDENTITIES and StringName(id) not in family_identities()) or seen.has(StringName(id)): return BuildEffectCatalog.failure(&"invalid_equipment_eligibility")
		seen[StringName(id)] = true
	return {"ok":true}
static func identity_allowed(policy: Dictionary, origin: StringName, evolution: StringName) -> bool:
	var ids: Array = policy.get("allowed_identities",[])
	return ids.is_empty() or (origin if evolution.is_empty() else evolution) in ids
static func level_allowed(policy: Dictionary, level: int) -> bool:
	if not policy.has("min_item_level") and not policy.has("max_item_level"): return true
	return level >= int(policy.get("min_item_level",1)) and level <= int(policy.get("max_item_level",30))
static func for_resource(resource: Resource) -> Dictionary:
	return {"min_item_level":resource.min_item_level,"max_item_level":resource.max_item_level,"allowed_identities":resource.allowed_identities}
