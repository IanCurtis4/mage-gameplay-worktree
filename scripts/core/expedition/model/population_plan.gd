class_name ExpeditionPopulationPlan
extends RefCounted
var _slots: Array[Dictionary] = []

func slots() -> Array[Dictionary]:
	return _slots.duplicate(true)

func find_slot(slot_id: String) -> Dictionary:
	for slot: Dictionary in _slots:
		if slot["slot_id"] == slot_id: return slot.duplicate(true)
	return {}

func to_data() -> Dictionary:
	return {"slots": slots()}
