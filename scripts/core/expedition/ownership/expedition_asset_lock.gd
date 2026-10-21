class_name ExpeditionAssetLock
extends RefCounted
## Typed F2 reservation. Full checkpoint payload belongs to F3/F4.
var expedition_id: String
var character_id: String
var phase_id: StringName
var lifecycle: StringName = &"suspended"
var revision: int = 0

func to_record() -> Dictionary:
	return {"expedition_id": expedition_id, "character_id": character_id, "phase_id": String(phase_id), "lifecycle": String(lifecycle), "revision": revision}

func copy_lock() -> ExpeditionAssetLock:
	var copy := ExpeditionAssetLock.new()
	copy.expedition_id = expedition_id
	copy.character_id = character_id
	copy.phase_id = phase_id
	copy.lifecycle = lifecycle
	copy.revision = revision
	return copy

static func from_record(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size() != 5: return BuildEffectCatalog.failure(&"invalid_expedition_slot")
	for key: String in ["expedition_id", "character_id", "phase_id", "lifecycle"]:
		if not raw.get(key) is String or raw[key].is_empty(): return BuildEffectCatalog.failure(&"invalid_expedition_slot")
	if not IdentityIds.is_technical_id(raw["expedition_id"]) or not IdentityIds.is_technical_id(raw["phase_id"]) or raw["lifecycle"] not in ["active", "suspended", "recovering", "reconciling"] or not EquipmentRules.exact_integer(raw.get("revision"), 0): return BuildEffectCatalog.failure(&"invalid_expedition_slot")
	var slot := ExpeditionAssetLock.new()
	slot.expedition_id = raw["expedition_id"]
	slot.character_id = raw["character_id"]
	slot.phase_id = StringName(raw["phase_id"])
	slot.lifecycle = StringName(raw["lifecycle"])
	slot.revision = int(raw["revision"])
	return {"ok": true, "lock": slot}
