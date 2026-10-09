class_name SpiritualistEchoState
extends RefCounted
## Run-only marks and finite delayed waves. Damage remains in CombatActor/CombatMath.

const MARK_DURATION := 5.0
const ECHO_DELAY := 0.35
const MAX_PENDING := 64
const MAX_WAVES := 64

var source_id := 0
var marks: Dictionary[int, Dictionary] = {}
var pending: Array[Dictionary] = []
var waves: Dictionary[int, Dictionary] = {}
var wave_by_emission: Dictionary[int, int] = {}
var next_wave_id := 1

func _init(owner_id: int = 0) -> void:
	source_id = owner_id

func mark(target_id: int, echo_power: float) -> void:
	if target_id <= 0 or not is_finite(echo_power) or echo_power <= 0.0:
		return
	marks[target_id] = {"remaining": MARK_DURATION, "echo_power": echo_power}

func has_mark(target_id: int) -> bool:
	return marks.has(target_id)

func consume_mark(target_id: int) -> bool:
	if not marks.has(target_id):
		return false
	marks.erase(target_id)
	return true

func record_hit(result: Dictionary, magic_attack_at_trigger: float) -> bool:
	var target_id := int(result.get("target_id", 0))
	if int(result.get("source_id", 0)) != source_id or not marks.has(target_id):
		return false
	if not bool(result.get("can_trigger_effects", false)) or float(result.get("actual_damage", 0.0)) <= 0.0:
		return false
	if StringName(result.get("skill_id", &"")) in [&"", &"basic_attack", &"burn_tick", &"bleed_tick"]:
		return false
	if bool(result.get("killed", false)):
		marks.erase(target_id)
		return false
	var emission_id := int(result.get("emission_id", 0))
	var wave_id := int(wave_by_emission.get(emission_id, 0)) if emission_id > 0 else 0
	if wave_id <= 0 or not waves.has(wave_id):
		if waves.size() >= MAX_WAVES:
			return false
		wave_id = next_wave_id
		next_wave_id += 1
		var eligible: Dictionary[int, float] = {}
		for marked_id: int in marks:
			eligible[marked_id] = float(marks[marked_id]["echo_power"])
		waves[wave_id] = {"eligible": eligible, "scheduled": {}, "pairs": {}, "shown_targets": {}, "magic_attack": maxf(0.0, magic_attack_at_trigger), "context": result.get("context"), "damage_multiplier": result.get("damage_dealt_multiplier", 1.0)}
		if emission_id > 0:
			wave_by_emission[emission_id] = wave_id
	return _schedule_carrier(wave_id, target_id)

func record_echo_impact(wave_id: int, result: Dictionary, echo_power: float) -> bool:
	if not waves.has(wave_id) or int(result.get("source_id", 0)) != source_id or float(result.get("actual_damage", 0.0)) <= 0.0:
		return false
	var target_id := int(result.get("target_id", 0))
	var wave: Dictionary = waves[wave_id]
	var first_visual: bool = not wave["shown_targets"].has(target_id)
	wave["shown_targets"][target_id] = true
	if bool(result.get("killed", false)):
		return first_visual
	if wave["eligible"].has(target_id):
		_schedule_carrier(wave_id, target_id)
	# Reapplication is for the next player action, never reentry into this wave.
	mark(target_id, echo_power)
	return first_visual

func claim_pair(wave_id: int, carrier_id: int, target_id: int) -> bool:
	if not waves.has(wave_id):
		return false
	var wave: Dictionary = waves[wave_id]
	if not wave["scheduled"].has(carrier_id):
		return false
	var pair_key := "%d:%d" % [carrier_id, target_id]
	if wave["pairs"].has(pair_key):
		return false
	wave["pairs"][pair_key] = true
	return true

func _schedule_carrier(wave_id: int, target_id: int) -> bool:
	if not waves.has(wave_id) or pending.size() >= MAX_PENDING:
		return false
	var wave: Dictionary = waves[wave_id]
	if not wave["eligible"].has(target_id) or wave["scheduled"].has(target_id):
		return false
	wave["scheduled"][target_id] = true
	marks.erase(target_id)
	var power := float(wave["eligible"][target_id])
	pending.append({"target_id": target_id, "wave_id": wave_id, "remaining": ECHO_DELAY, "magic_damage": float(wave["magic_attack"]) * power, "echo_power": power, "context": wave.get("context"), "damage_multiplier": wave.get("damage_multiplier", 1.0)})
	return true

func finish_resolution() -> void:
	var active: Dictionary[int, bool] = {}
	for echo: Dictionary in pending:
		active[int(echo["wave_id"])] = true
	for wave_id: int in waves.keys():
		if not active.has(wave_id):
			waves.erase(wave_id)
	for emission_id: int in wave_by_emission.keys():
		if not waves.has(wave_by_emission[emission_id]):
			wave_by_emission.erase(emission_id)

func advance(delta: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	if delta <= 0.0:
		return due
	for target_id: int in marks.keys():
		var mark_data: Dictionary = marks[target_id]
		mark_data["remaining"] = float(mark_data["remaining"]) - delta
		if float(mark_data["remaining"]) <= 0.0:
			marks.erase(target_id)
		else:
			marks[target_id] = mark_data
	for index: int in range(pending.size() - 1, -1, -1):
		var echo: Dictionary = pending[index]
		echo["remaining"] = float(echo["remaining"]) - delta
		if float(echo["remaining"]) <= 0.0:
			due.append(echo)
			pending.remove_at(index)
		else:
			pending[index] = echo
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["target_id"]) < int(b["target_id"]))
	return due

func remove_target(target_id: int) -> void:
	marks.erase(target_id)
	for index: int in range(pending.size() - 1, -1, -1):
		if int(pending[index]["target_id"]) == target_id:
			pending.remove_at(index)

func clear() -> void:
	marks.clear()
	pending.clear()
	waves.clear()
	wave_by_emission.clear()
	next_wave_id = 1

func can_record_hit(result: Dictionary) -> bool:
	var target := int(result.get("target_id", 0))
	return int(result.get("source_id", 0)) == source_id and marks.has(target) and bool(result.get("can_trigger_effects", false)) and float(result.get("actual_damage", 0.0)) > 0.0 and not bool(result.get("killed", false)) and StringName(result.get("skill_id", &"")) not in [&"", &"basic_attack", &"burn_tick", &"bleed_tick"] and pending.size() < MAX_PENDING and waves.size() < MAX_WAVES
