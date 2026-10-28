class_name ExpeditionCheckpointCodec
extends RefCounted
## Transport of the F3 envelope, never another runtime serializer or writer.
const Encoding = preload("res://scripts/core/expedition/snapshot/snapshot_graph_encoding.gd")
const FORMAT := 2
const MAX_BYTES := Encoding.MAX_BYTES
const MAX_ENCODED := 6 * 1024 * 1024

static func pack(snapshot: Dictionary, owner_digest: String, session: Dictionary) -> Dictionary:
	var checked := SnapshotRegistry.new().validate(snapshot)
	if not checked["ok"]: return checked
	var bytes: PackedByteArray = checked.encoding
	if bytes.size() > MAX_BYTES: return fail(&"snapshot_too_large")
	var compressed := bytes.compress(FileAccess.COMPRESSION_DEFLATE)
	return {"ok":true,"checkpoint":{"format":FORMAT,"snapshot":Marshalls.raw_to_base64(compressed),"byte_count":bytes.size(),"sha256":digest_bytes(bytes),"owner_digest":owner_digest,"session":session.duplicate(true)}}

static func validate_record(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size() != 6: return fail(&"invalid_checkpoint")
	if not EquipmentRules.exact_integer(raw.get("format"),1) or int(raw["format"]) not in [1,FORMAT]: return fail(&"checkpoint_version_unavailable")
	if not raw.get("snapshot") is String or raw["snapshot"].is_empty() or raw["snapshot"].length() > MAX_ENCODED: return fail(&"snapshot_too_large")
	if not EquipmentRules.exact_integer(raw.get("byte_count"),1,MAX_BYTES): return fail(&"snapshot_too_large")
	if not CharacterAssets.valid_digest(raw.get("sha256")) or not CharacterAssets.valid_digest(raw.get("owner_digest")): return fail(&"invalid_checkpoint")
	var session: Variant = raw.get("session")
	if not session is Dictionary or session.size() != 3 or not session.get("run_id") is String or session["run_id"].is_empty() or not session.get("character_id") is String or not EquipmentRules.exact_integer(session.get("last_committed_seq"),0): return fail(&"invalid_checkpoint")
	var encoded: String = raw["snapshot"]
	if not _canonical_base64(encoded): return fail(&"invalid_checkpoint")
	var compressed := Marshalls.base64_to_raw(encoded)
	if compressed.is_empty() or Marshalls.raw_to_base64(compressed) != encoded: return fail(&"invalid_checkpoint")
	var bytes := compressed.decompress(int(raw["byte_count"]),FileAccess.COMPRESSION_DEFLATE)
	if bytes.size() != int(raw["byte_count"]) or digest_bytes(bytes) != raw["sha256"]: return fail(&"invalid_checkpoint")
	return {"ok":true,"bytes":bytes}

static func _canonical_base64(encoded: String) -> bool:
	# Marshalls logs native errors on malformed input. Check syntax and padding
	# bits before invoking it; rejected checkpoint data is an ordinary result.
	if encoded.length() < 4 or encoded.length()%4 != 0: return false
	var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	var padding := 2 if encoded.ends_with("==") else (1 if encoded.ends_with("=") else 0)
	var data_end := encoded.length()-padding
	for index: int in encoded.length():
		if index < data_end:
			if alphabet.find(encoded[index]) < 0: return false
		elif encoded[index] != "=": return false
	if padding > 0:
		var tail := alphabet.find(encoded[data_end-1])
		if (tail & (15 if padding == 2 else 3)) != 0: return false
	return true

static func unpack(raw: Dictionary) -> Dictionary:
	var checked := validate_record(raw)
	if not checked["ok"]: return checked
	# Object decoding stays disabled. F3 owns all explicit runtime descriptors.
	var snapshot: Variant
	if int(raw["format"]) == 1:
		snapshot = bytes_to_var(checked["bytes"])
	else:
		var decoded := Encoding.decode_snapshot(checked["bytes"])
		if not decoded.ok: return decoded
		snapshot = decoded.snapshot
	if not snapshot is Dictionary: return fail(&"invalid_checkpoint")
	var valid := SnapshotRegistry.new().validate(snapshot)
	if not valid["ok"]: return valid
	return {"ok":true,"snapshot":snapshot}

static func owner_digest(profile: ProfileState, character_id: String) -> String:
	var character := profile.character_by_id(character_id)
	if character == null: return ""
	var equipment := {}
	for id: StringName in profile.equipment_for_character(character_id): equipment[String(id)] = profile.equipment_instances[id].to_record()
	var cards := profile.card_inventory.for_character(character_id,profile.equipment_for_character(character_id)).to_record()
	# These are profile-wide allocation/version counters, not this owner's assets.
	# They remain intact in ProfileState and the runtime snapshot for unique IDs.
	cards.erase("next_counter")
	cards.erase("revision")
	return MigrationPlan.canonical({"character":ProfileCodec._character_to_dictionary(character),"gold":character.gold,"equipment":equipment,"cards":cards}).sha256_text()

static func fail(code: StringName) -> Dictionary:
	return {"ok":false,"error_code":code}

static func digest_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
