class_name ThreatService
extends RefCounted
## One ledger per hostile actor. Stable participant IDs are distinct from owners.
## Confirmed effective amounts only; never resolves damage or healing itself.
var enemy_id := ""
var participants: Dictionary = {}
var amounts: Dictionary = {}
var groups: Dictionary = {}
var current_id := ""
var forced_id := ""
var forced_remaining := 0.0
var engaged := false
var revision := 0
var claims: Dictionary = {}
## E09 C1.6: participant id -> remaining seconds without sight of that participant.
var sight_breaks: Dictionary = {}

func register(id: String, owner: String, group: String) -> Dictionary:
	if id.is_empty() or owner.is_empty() or group.is_empty(): return _fail(&"invalid_participant")
	var identity := {"owner": owner, "group": group, "alive": true, "eligible": true}
	if participants.has(id):
		if participants[id]["owner"] != owner or participants[id]["group"] != group: return _fail(&"request_conflict")
		return _ok()
	participants[id] = identity
	amounts[id] = 0.0
	revision += 1
	return _ok()

func eligibility(id: String, alive: bool, visible: bool) -> Dictionary:
	if not participants.has(id): return _fail(&"invalid_participant")
	if participants[id]["alive"] == alive and participants[id]["eligible"] == visible: return _ok()
	participants[id]["alive"] = alive
	participants[id]["eligible"] = visible
	if not _eligible(forced_id): forced_id = ""; forced_remaining = 0.0
	_choose()
	revision += 1
	return _ok()

func engage(source: String = "") -> void:
	if source.is_empty():
		var ids: Array = amounts.keys(); ids.sort()
		for id: String in ids:
			if _eligible(id) and (source.is_empty() or float(amounts[id]) > float(amounts[source])): source = id
	if not participants.has(source): return
	var group: String = participants[source]["group"]
	if not engaged or not groups.has(group): revision += 1
	groups[group] = true
	engaged = true
	_choose()

func disengage() -> void:
	# Leash/target death removes the hostile link, never HP or causal receipts.
	if engaged or not current_id.is_empty() or not forced_id.is_empty(): revision += 1
	engaged = false
	groups.clear()
	current_id = ""
	forced_id = ""
	forced_remaining = 0.0

func observe(event: String, kind: StringName, source: String, effective: float, divisor: int = 1, parameter: float = 0.0, immune: bool = false) -> Dictionary:
	if event.is_empty() or not participants.has(source): return _fail(&"invalid_participant")
	if not is_finite(effective) or effective < 0.0 or divisor < 1 or not is_finite(parameter): return _fail(&"invalid_payload")
	if kind not in [&"damage", &"heal", &"taunt", &"reduce"]: return _fail(&"unsupported_threat_rule")
	if kind == &"taunt" and parameter <= 0.0: return _fail(&"invalid_payload")
	if kind == &"reduce" and (parameter < 0.0 or parameter > 1.0): return _fail(&"invalid_payload")
	var payload := {"kind": String(kind), "source": source, "effective": effective, "divisor": divisor, "parameter": parameter, "immune": immune}
	if claims.has(event):
		if claims[event] != payload: return _fail(&"request_conflict")
		return _ok(true)
	var addition := effective if kind == &"damage" else effective * 0.5 / float(divisor)
	if kind in [&"damage", &"heal"] and (not is_finite(float(amounts[source]) + addition) or not is_finite((float(amounts[source]) + addition) * 1.1)): return _fail(&"invalid_payload")
	# Claim precedes any observable state transition. Failed immunity is a receipt.
	claims[event] = payload
	if kind in [&"damage", &"heal"]:
		amounts[source] = float(amounts[source]) + addition
		if addition > 0.0: engage(source)
	elif kind == &"reduce": amounts[source] = float(amounts[source]) * (1.0 - parameter)
	elif not immune and _eligible(source):
		var highest := 0.0
		for value: float in amounts.values(): highest = maxf(highest, value)
		amounts[source] = highest
		forced_id = source
		forced_remaining = parameter
		groups[participants[source]["group"]] = true
		engaged = true
	_choose()
	revision += 1
	return _ok()

func advance(delta: float, frozen: bool = false) -> void:
	if frozen or not is_finite(delta) or delta < 0.0: return
	var changed := false
	if not sight_breaks.is_empty():
		for id: String in sight_breaks.keys():
			sight_breaks[id] = maxf(0.0, float(sight_breaks[id]) - delta)
			if float(sight_breaks[id]) <= 0.0: sight_breaks.erase(id)
		changed = true
	if forced_remaining > 0.0:
		forced_remaining = maxf(0.0, forced_remaining - delta)
		if forced_remaining == 0.0: forced_id = ""
		changed = true
	if not changed: return
	_choose()
	revision += 1

## E09 C1.6: forces this enemy onto `source` for `duration` seconds, through the same
## forced slot as a taunt but without touching the threat amounts. A longer active
## force on the same source is kept.
func force_target(source: String, duration: float) -> Dictionary:
	if not participants.has(source): return _fail(&"invalid_participant")
	if not is_finite(duration) or duration <= 0.0: return _fail(&"invalid_payload")
	if not _eligible(source): return _fail(&"participant_ineligible")
	var kept := forced_remaining if forced_id == source else 0.0
	forced_id = source
	forced_remaining = maxf(duration, kept)
	groups[participants[source]["group"]] = true
	engaged = true
	_choose()
	revision += 1
	return _ok()

## E09 C1.6: this enemy loses sight of `source` for `duration` seconds: the source is
## not eligible and a force on it ends. The selection rule itself is unchanged.
func break_sight(source: String, duration: float) -> Dictionary:
	if not participants.has(source): return _fail(&"invalid_participant")
	if not is_finite(duration) or duration <= 0.0: return _fail(&"invalid_payload")
	sight_breaks[source] = maxf(duration, float(sight_breaks.get(source, 0.0)))
	if forced_id == source: forced_id = ""; forced_remaining = 0.0
	_choose()
	revision += 1
	return _ok()

func sight_broken(source: String) -> bool:
	return float(sight_breaks.get(source, 0.0)) > 0.0

func sight_break_remaining(source: String) -> float:
	return float(sight_breaks.get(source, 0.0))

func _eligible(id: String) -> bool:
	return participants.has(id) and participants[id]["alive"] and participants[id]["eligible"] and not sight_broken(id)

func _choose() -> void:
	if not engaged: current_id = ""; return
	if forced_remaining > 0.0 and _eligible(forced_id): current_id = forced_id; return
	var best := ""
	var ids: Array = amounts.keys()
	ids.sort()
	for id: String in ids:
		if _eligible(id) and groups.has(participants[id]["group"]) and (best.is_empty() or float(amounts[id]) > float(amounts[best])): best = id
	if not _eligible(current_id): current_id = best; return
	# Division avoids overflow when multiplying a large current value by 1.1.
	if not best.is_empty() and float(amounts[best]) / 1.1 > float(amounts[current_id]): current_id = best

func linked(group: String) -> bool:
	if not engaged or not groups.has(group): return false
	for id: String in participants:
		if participants[id]["alive"] and participants[id]["group"] == group: return true
	return false

func view() -> ThreatView:
	var result := ThreatView.new()
	result.enemy_id = enemy_id; result.current_id = current_id; result.forced_id = forced_id
	result.forced_remaining = forced_remaining; result.engaged = engaged; result.revision = revision
	result.switch_threshold = float(amounts.get(current_id, 0.0)) * 1.1
	var ids: Array = participants.keys(); ids.sort()
	for id: String in ids:
		result.entries.append({"id": id, "owner": participants[id]["owner"], "group": participants[id]["group"], "amount": amounts[id], "alive": participants[id]["alive"], "eligible": participants[id]["eligible"]})
	return result

func valid() -> bool:
	if revision < 0 or not is_finite(forced_remaining) or forced_remaining < 0.0 or participants.size() != amounts.size(): return false
	for id: Variant in sight_breaks:
		if not id is String or not participants.has(id) or typeof(sight_breaks[id]) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(sight_breaks[id])) or float(sight_breaks[id]) <= 0.0: return false
	for id: Variant in participants:
		if not id is String or id.is_empty() or not participants[id] is Dictionary or not amounts.has(id): return false
		var p: Dictionary = participants[id]
		if p.size() != 4 or not p.get("owner") is String or p["owner"].is_empty() or not p.get("group") is String or p["group"].is_empty() or not p.get("alive") is bool or not p.get("eligible") is bool: return false
		if typeof(amounts[id]) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(amounts[id])) or float(amounts[id]) < 0.0 or not is_finite(float(amounts[id]) * 1.1): return false
	if engaged == groups.is_empty(): return false
	for group: Variant in groups:
		if not group is String or group.is_empty() or typeof(groups[group]) != TYPE_BOOL or not groups[group]: return false
		var found := false
		for participant: Dictionary in participants.values():
			if participant["group"] == group: found = true
		if not found: return false
	if (forced_remaining > 0.0) != (not forced_id.is_empty()) or (not forced_id.is_empty() and not _eligible(forced_id)): return false
	if not current_id.is_empty() and (not engaged or not _eligible(current_id) or not groups.has(participants[current_id]["group"])): return false
	for event: Variant in claims:
		if not event is String or event.is_empty() or not claims[event] is Dictionary: return false
		var p: Dictionary = claims[event]
		if p.size() != 6 or not p.get("source") is String or not participants.has(p["source"]) or p.get("kind") not in ["damage", "heal", "taunt", "reduce"]: return false
		if typeof(p.get("effective")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(p["effective"])) or float(p["effective"]) < 0.0 or typeof(p.get("divisor")) != TYPE_INT or p["divisor"] < 1 or not p.get("immune") is bool: return false
		if typeof(p.get("parameter")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(p["parameter"])): return false
		if p["kind"] == "taunt" and p["parameter"] <= 0.0: return false
		if p["kind"] == "reduce" and (p["parameter"] < 0.0 or p["parameter"] > 1.0): return false
	return true

func _ok(replay: bool = false) -> Dictionary:
	return {"ok": true, "error_code": &"", "revision": revision, "already_applied": replay}
func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "error_code": code, "revision": revision}
