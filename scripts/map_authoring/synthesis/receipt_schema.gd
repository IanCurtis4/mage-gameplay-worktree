@tool
extends RefCounted
## Checkpoint46 (F9-05, P3d): shape of the optional "synthesis_receipts" extension
## of a ROOT document (piece, map, encounters, patrols). Leaf helper with no
## preloads, so every document validator can call it. A receipt is passive data:
## the closed request (never the source), hashes and change counts.
const KEY := "synthesis_receipts"
const MAX := 32
const MAX_BYTES := 65536
const KINDS := ["piece","map","population","patrol"]
const KEYS := ["receipt_version","algorithm_revision","kind","request","request_hash","base_hash","dependencies_hash","result_content_hash","summary"]
const SUMMARY := ["terrain_samples","material_samples","objects_added","objects_removed","slots_added","slots_removed","anchors_remapped"]

static func _hash(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for c: String in value:
		if c not in "0123456789abcdef": return false
	return true

static func _count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floor(float(value)) and float(value) <= 1000000

static func valid_receipt(receipt: Variant) -> bool:
	if not receipt is Dictionary or receipt.size() != KEYS.size() or not receipt.has_all(KEYS): return false
	if not (receipt.receipt_version is int or receipt.receipt_version is float) or float(receipt.receipt_version) != 1.0: return false
	if not receipt.algorithm_revision is String or receipt.algorithm_revision.is_empty() or receipt.algorithm_revision.length() > 64: return false
	if not receipt.kind is String or receipt.kind not in KINDS or not receipt.request is Dictionary: return false
	for key: String in ["request_hash","base_hash","dependencies_hash","result_content_hash"]:
		if not _hash(receipt[key]): return false
	if not receipt.summary is Dictionary or receipt.summary.size() != SUMMARY.size() or not receipt.summary.has_all(SUMMARY): return false
	for key: String in SUMMARY:
		if not _count(receipt.summary[key]): return false
	return JSON.stringify(receipt).to_utf8_buffer().size() <= MAX_BYTES

## The extension itself: at most MAX receipts, each closed.
static func valid(value: Variant) -> bool:
	if not value is Array or value.size() > MAX: return false
	for receipt: Variant in value:
		if not valid_receipt(receipt): return false
	return true
