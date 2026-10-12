class_name ItemSkillAdapters
extends RefCounted
## Explicit executors verified for item access. This is not a class library grant.
const IDS: Array[StringName] = [&"fire_spear", &"ice_spear", &"teleport"]
static func supports(skill: StringName, origin: StringName) -> bool:
	return skill in IDS and origin in IdentityIds.base_class_ids()
static func reference_ids(origin: StringName) -> Array[StringName]:
	return IDS.duplicate() if origin in IdentityIds.base_class_ids() else []
