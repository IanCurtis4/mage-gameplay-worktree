extends RefCounted
## Campaign journal over a base checkpoint (checkpoint37, contracts/f9_campaign_journal.md).
## Append-only, hash-chained entries. Each payload is the resolved effect of one
## commit, never a command to re-roll. Payload bytes are var_to_bytes without objects.
## - deaths: validated events, issued tickets, RNG and ticket sequence after them.
## - collect (checkpoint38): delivered tickets with their card instance, and the
##   reward session and owner digest after the grants (the profile holds the grants).
const MAX_ENTRIES := 256
const MAX_ENCODED := 262144
const MAX_EVENTS := 512
const PAYLOAD_KEYS := ["events","tickets","rng_state","next_sequence"]
const COLLECT_KEYS := ["kind","delivered","session","owner_digest"]
const MAX_DELIVERED := 512

static func digest(text: String) -> String:
	return text.sha256_text()

# The chain starts at the base checkpoint's snapshot digest.
static func root(checkpoint: Dictionary) -> String:
	return String(checkpoint.get("sha256",""))

static func entry_digest(entry: Dictionary) -> String:
	return digest("%d|%s|%s|%s" % [int(entry["seq"]),String(entry["request_id"]),String(entry["sha256"]),String(entry["prev"])])

static func make_entry(journal: Array, checkpoint: Dictionary, request_id: String, payload: Dictionary) -> Dictionary:
	var checked := validate_payload(payload)
	if not checked["ok"]: return checked
	if journal.size() >= MAX_ENTRIES: return fail(&"journal_full")
	var bytes := var_to_bytes(payload)
	var encoded := Marshalls.raw_to_base64(bytes)
	if encoded.length() > MAX_ENCODED: return fail(&"journal_entry_too_large")
	var prev := root(checkpoint) if journal.is_empty() else entry_digest(journal[-1])
	return {"ok":true,"entry":{"seq":journal.size()+1,"request_id":request_id,"payload":encoded,"sha256":ExpeditionCheckpointCodec.digest_bytes(bytes),"prev":prev}}

# Validates shape, sequence, chain and payloads. Returns normalized entries
# (integers restored after JSON) and their decoded payloads, in order.
static func validate(raw: Variant, checkpoint: Dictionary) -> Dictionary:
	if not raw is Array or raw.size() > MAX_ENTRIES: return fail(&"invalid_journal")
	var entries: Array = []; var payloads: Array = []
	var prev := root(checkpoint)
	for index: int in raw.size():
		var value: Variant = raw[index]
		if not value is Dictionary or value.size() != 5: return fail(&"invalid_journal")
		if not EquipmentRules.exact_integer(value.get("seq"),1) or int(value["seq"]) != index+1: return fail(&"invalid_journal")
		if not value.get("request_id") is String or not CharacterAssets.valid_request(value["request_id"]): return fail(&"invalid_journal")
		if not value.get("payload") is String or value["payload"].is_empty() or value["payload"].length() > MAX_ENCODED: return fail(&"invalid_journal")
		if not CharacterAssets.valid_digest(value.get("sha256")) or value.get("prev") != prev: return fail(&"invalid_journal")
		var bytes := Marshalls.base64_to_raw(value["payload"])
		if bytes.is_empty() or Marshalls.raw_to_base64(bytes) != value["payload"] or ExpeditionCheckpointCodec.digest_bytes(bytes) != value["sha256"]: return fail(&"invalid_journal")
		var payload: Variant = bytes_to_var(bytes)
		if not payload is Dictionary or not validate_payload(payload)["ok"]: return fail(&"invalid_journal")
		var entry := {"seq":int(value["seq"]),"request_id":value["request_id"],"payload":value["payload"],"sha256":value["sha256"],"prev":value["prev"]}
		entries.append(entry); payloads.append(payload)
		prev = entry_digest(entry)
	return {"ok":true,"entries":entries,"payloads":payloads}

static func decode(journal: Array, checkpoint: Dictionary) -> Dictionary:
	return validate(journal,checkpoint)

static func is_collect(payload: Dictionary) -> bool:
	return payload.get("kind") == "collect"

static func validate_payload(payload: Variant) -> Dictionary:
	if payload is Dictionary and is_collect(payload): return _validate_collect(payload)
	if not payload is Dictionary or payload.size() != PAYLOAD_KEYS.size() or not payload.has_all(PAYLOAD_KEYS): return fail(&"invalid_journal")
	if not payload["events"] is Array or payload["events"].is_empty() or payload["events"].size() > MAX_EVENTS: return fail(&"invalid_journal")
	var ids := {}
	for event: Variant in payload["events"]:
		if not event is Dictionary or event.size() != 4 or event.get("kind") != "mob_death" or not event.get("slot_id") is String or event["slot_id"].is_empty() or not event.get("event_id") is String or event["event_id"].is_empty() or typeof(event.get("generation")) != TYPE_INT or int(event["generation"]) < 0: return fail(&"invalid_journal")
		if ids.has(event["event_id"]): return fail(&"invalid_journal")
		ids[event["event_id"]] = true
	if not payload["tickets"] is Array or payload["tickets"].size() > payload["events"].size(): return fail(&"invalid_journal")
	for ticket: Variant in payload["tickets"]:
		if not ticket is Dictionary or not ticket.get("ticket_id") is String or String(ticket["ticket_id"]).is_empty() or not ticket.get("event_id") is String or ticket.get("mob_ticket") != true or ticket.get("delivered") != false or not ticket.get("payload") is Dictionary: return fail(&"invalid_journal")
	if typeof(payload["rng_state"]) != TYPE_INT or typeof(payload["next_sequence"]) != TYPE_INT or int(payload["next_sequence"]) < 1: return fail(&"invalid_journal")
	return {"ok":true}

static func _validate_collect(payload: Dictionary) -> Dictionary:
	if payload.size() != COLLECT_KEYS.size() or not payload.has_all(COLLECT_KEYS): return fail(&"invalid_journal")
	if not payload["delivered"] is Array or payload["delivered"].is_empty() or payload["delivered"].size() > MAX_DELIVERED: return fail(&"invalid_journal")
	var ids := {}
	for item: Variant in payload["delivered"]:
		if not item is Dictionary or item.size() != 2 or not item.get("ticket_id") is String or String(item["ticket_id"]).is_empty() or typeof(item.get("card_instance_id")) != TYPE_STRING_NAME or ids.has(item["ticket_id"]): return fail(&"invalid_journal")
		ids[item["ticket_id"]] = true
	var session: Variant = payload["session"]
	if not session is Dictionary or session.size() != 3 or not session.get("run_id") is String or String(session["run_id"]).is_empty() or not session.get("character_id") is String or typeof(session.get("last_committed_seq")) != TYPE_INT: return fail(&"invalid_journal")
	if not CharacterAssets.valid_digest(payload["owner_digest"]): return fail(&"invalid_journal")
	return {"ok":true}

## Reward session and owner digest in force after the journal (the last collect
## entry), or the base checkpoint's when no entry collected anything.
static func effective(journal: Array, checkpoint: Dictionary) -> Dictionary:
	var result := {"session":checkpoint.get("session",{}),"owner_digest":checkpoint.get("owner_digest","")}
	for index: int in range(journal.size()-1,-1,-1):
		var bytes := Marshalls.base64_to_raw(String(journal[index].get("payload","")))
		var payload: Variant = bytes_to_var(bytes) if not bytes.is_empty() else null
		if payload is Dictionary and is_collect(payload):
			result = {"session":payload["session"],"owner_digest":payload["owner_digest"]}
			break
	return result

static func fail(code: StringName) -> Dictionary:
	return {"ok":false,"error_code":code}
