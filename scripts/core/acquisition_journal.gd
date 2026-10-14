class_name AcquisitionJournal
extends RefCounted
## Presentation-only history of confirmed acquisitions. Never grants or saves rewards.
signal changed
var _entries: Array[Dictionary] = []
var _seen: Dictionary = {}

func record_reward(receipt: Dictionary, catalog: BuildEffectCatalog) -> bool:
	var id := String(receipt.get("ticket_id", ""))
	if id.is_empty() or catalog == null or _seen.has(id):
		return false
	_seen[id] = true
	var before := _entries.size()
	var encounter := int(receipt.get("encounter_index", 0))
	var persistent := bool(receipt.get("persistent", false))
	var base := int(receipt.get("base_xp", 0))
	var job := int(receipt.get("job_xp", 0))
	if base > 0 or job > 0 or int(receipt.get("offered_base_xp", 0)) > 0 or int(receipt.get("offered_job_xp", 0)) > 0:
		var limited := base < int(receipt.get("offered_base_xp", 0)) or job < int(receipt.get("offered_job_xp", 0))
		_entries.append({"kind": &"xp", "encounter": encounter, "persistent": persistent, "text": "XP Base +%d · XP Job +%d%s" % [base, job, " · limite de nível" if limited else ""], "base_xp": base, "job_xp": job})
	for drop: Dictionary in receipt.get("equipment_drops", []):
		var definition := catalog.get_definition(&"equipment", StringName(drop["definition_id"])) as EquipmentDefinition
		if definition == null:
			continue
		var quality := StringName(drop.get("quality_id", definition.quality_id))
		var level := int(drop.get("item_level", definition.item_level))
		var sockets := int(drop.get("socket_capacity", definition.socket_capacity))
		_entries.append({"kind": &"equipment", "encounter": encounter, "persistent": persistent, "definition_id": definition.id, "quality_id": quality, "item_level": level, "socket_capacity": sockets, "text": "%s · %s · ilvl %d · %d encaixe(s)" % [EquipmentPresentation.item_name(definition), EquipmentPresentation.quality_name(quality), level, sockets]})
	var card_id := StringName(receipt.get("card_id", &""))
	var card := catalog.get_definition(&"card", card_id) as CardDefinition if not card_id.is_empty() else null
	if card != null:
		_entries.append({"kind": &"card", "encounter": encounter, "persistent": persistent, "definition_id": card_id, "text": "Carta: %s" % card.display_name})
	if _entries.size() == before:
		return false
	changed.emit()
	return true

func record_augment(event_id: String, encounter: int, definition: AugmentDefinition, stacks: int) -> bool:
	var id := "augment:" + event_id
	if event_id.is_empty() or definition == null or stacks < 1 or _seen.has(id):
		return false
	_seen[id] = true
	_entries.append({"kind": &"augment", "encounter": encounter, "persistent": false, "definition_id": definition.id, "stacks": stacks, "text": "%s · acúmulo %d · somente nesta run" % [definition.display_name, stacks]})
	changed.emit()
	return true

func entries(encounter: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		if encounter == 0 or entry["encounter"] == encounter:
			result.append(entry.duplicate(true))
	return result

func totals(encounter: int = 0) -> Dictionary:
	var result := {"base_xp": 0, "job_xp": 0, "equipment": 0, "cards": 0, "augments": 0}
	for entry: Dictionary in _entries:
		if encounter != 0 and entry["encounter"] != encounter:
			continue
		match entry["kind"]:
			&"xp":
				result["base_xp"] += entry["base_xp"]
				result["job_xp"] += entry["job_xp"]
			&"equipment": result["equipment"] += 1
			&"card": result["cards"] += 1
			&"augment": result["augments"] += 1
	return result
