class_name ExpeditionAssetLock
extends RefCounted
## Typed reservation with optional versioned F4 checkpoint and immutable receipts.
const Journal = preload("res://scripts/core/expedition/persistence/expedition_journal_codec.gd")
var expedition_id: String
var character_id: String
var phase_id: StringName
var lifecycle: StringName = &"suspended"
var revision: int = 0
# Additive, fail-closed record revision: old five-field reservations stay readable.
var checkpoint: Dictionary = {}
var receipts: Dictionary = {}
# Checkpoint37: append-only campaign journal over the checkpoint (an eighth
# record field, present only when non-empty). Any new checkpoint clears it.
var journal: Array = []

func to_record() -> Dictionary:
	var record := {"expedition_id": expedition_id, "character_id": character_id, "phase_id": String(phase_id), "lifecycle": String(lifecycle), "revision": revision}
	if not checkpoint.is_empty():
		record["checkpoint"] = checkpoint.duplicate(true)
		record["receipts"] = receipts.duplicate(true)
		if not journal.is_empty(): record["journal"] = journal.duplicate(true)
	return record

## Reward session and owner digest in force: the last journaled collection, or
## the checkpoint's own when the journal collected nothing (checkpoint38).
func effective_session() -> Dictionary:
	return Journal.effective(journal,checkpoint)["session"] if not journal.is_empty() else checkpoint.get("session",{})

func effective_owner_digest() -> String:
	return String(Journal.effective(journal,checkpoint)["owner_digest"] if not journal.is_empty() else checkpoint.get("owner_digest",""))

func copy_lock() -> ExpeditionAssetLock:
	var copy := ExpeditionAssetLock.new()
	copy.expedition_id = expedition_id
	copy.character_id = character_id
	copy.phase_id = phase_id
	copy.lifecycle = lifecycle
	copy.revision = revision
	copy.checkpoint = checkpoint.duplicate(true)
	copy.receipts = receipts.duplicate(true)
	copy.journal = journal.duplicate(true)
	return copy

static func from_record(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size() not in [5,7,8]: return BuildEffectCatalog.failure(&"invalid_expedition_slot")
	for key: String in ["expedition_id", "character_id", "phase_id", "lifecycle"]:
		if not raw.get(key) is String or raw[key].is_empty(): return BuildEffectCatalog.failure(&"invalid_expedition_slot")
	if not IdentityIds.is_technical_id(raw["expedition_id"]) or not IdentityIds.is_technical_id(raw["phase_id"]) or raw["lifecycle"] not in ["active", "suspended", "recovering", "reconciling", "completed"] or not EquipmentRules.exact_integer(raw.get("revision"), 0): return BuildEffectCatalog.failure(&"invalid_expedition_slot")
	var slot := ExpeditionAssetLock.new()
	if raw["lifecycle"] == "completed" and raw.size() != 7: return BuildEffectCatalog.failure(&"invalid_expedition_slot")
	slot.expedition_id = raw["expedition_id"]
	slot.character_id = raw["character_id"]
	slot.phase_id = StringName(raw["phase_id"])
	slot.lifecycle = StringName(raw["lifecycle"])
	slot.revision = int(raw["revision"])
	if raw.size() == 8 and (raw["lifecycle"] == "completed" or not raw.has("journal")): return BuildEffectCatalog.failure(&"invalid_expedition_slot")
	if raw.size() >= 7:
		var checked := ExpeditionCheckpointCodec.validate_record(raw.get("checkpoint"))
		if not checked["ok"]: return checked
		if raw["checkpoint"]["session"]["character_id"] != slot.character_id: return BuildEffectCatalog.failure(&"invalid_checkpoint")
		if not raw.get("receipts") is Dictionary: return BuildEffectCatalog.failure(&"invalid_checkpoint")
		for request: Variant in raw["receipts"]:
			var receipt: Variant = raw["receipts"][request]
			if not request is String or not CharacterAssets.valid_request(request) or not receipt is Dictionary or receipt.size() != 3 or not CharacterAssets.valid_digest(receipt.get("fingerprint")) or receipt.get("operation") not in ["checkpoint","suspend","collect","resume","campaign","build","journal"] or not EquipmentRules.exact_integer(receipt.get("revision"),1,slot.revision): return BuildEffectCatalog.failure(&"invalid_checkpoint")
		slot.checkpoint = raw["checkpoint"].duplicate(true)
		slot.checkpoint["session"]["last_committed_seq"] = int(slot.checkpoint["session"]["last_committed_seq"])
		slot.checkpoint["format"] = int(slot.checkpoint["format"])
		slot.checkpoint["byte_count"] = int(slot.checkpoint["byte_count"])
		slot.receipts = raw["receipts"].duplicate(true)
		for receipt: Dictionary in slot.receipts.values(): receipt["revision"] = int(receipt["revision"])
		if raw.size() == 8:
			var logged := Journal.validate(raw["journal"],slot.checkpoint)
			if not logged["ok"] or logged["entries"].is_empty(): return BuildEffectCatalog.failure(&"invalid_checkpoint")
			slot.journal = logged["entries"]
	return {"ok": true, "lock": slot}
