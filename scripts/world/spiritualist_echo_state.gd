class_name SpiritualistEchoState
extends RefCounted
## Run-only mark and delayed echoes. Damage remains in CombatActor/CombatMath.

const MARK_DURATION := 5.0
const ECHO_DELAY := 0.35

var source_id := 0
var marks: Dictionary[int, Dictionary] = {}
var pending: Array[Dictionary] = []

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
	if StringName(result.get("skill_id", &"")) in [&"spiritualist_echo_curse", &"spiritualist_dissipation"]:
		return false
	if bool(result.get("killed", false)):
		marks.erase(target_id)
		return false
	var mark_data: Dictionary = marks[target_id]
	marks.erase(target_id)
	pending.append({
		"target_id": target_id,
		"remaining": ECHO_DELAY,
		"magic_damage": maxf(0.0, magic_attack_at_trigger) * float(mark_data["echo_power"]),
	})
	return true

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
	return due

func remove_target(target_id: int) -> void:
	marks.erase(target_id)
	for index: int in range(pending.size() - 1, -1, -1):
		if int(pending[index]["target_id"]) == target_id:
			pending.remove_at(index)

func clear() -> void:
	marks.clear()
	pending.clear()
