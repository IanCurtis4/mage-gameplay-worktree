class_name ActionBarLayout
extends RefCounted
## Organization only. Learning, stats, cooldowns and combat never belong here.

const SLOT_COUNT := 24

static func empty() -> Array[Variant]:
	var slots: Array[Variant] = []
	slots.resize(SLOT_COUNT)
	return slots

static func from_legacy(slots: Array) -> Array[Variant]:
	var result := empty()
	var seen: Dictionary[StringName, bool] = {}
	for index: int in mini(slots.size(), SLOT_COUNT):
		if slots[index] == null:
			continue
		var id := StringName(slots[index])
		if not seen.has(id):
			result[index] = id
			seen[id] = true
	return result

static func valid(slots: Array, learned: Array[StringName]) -> bool:
	if slots.size() != SLOT_COUNT:
		return false
	var seen: Dictionary[StringName, bool] = {}
	for value: Variant in slots:
		if value == null:
			continue
		if not (value is String or value is StringName):
			return false
		var id := StringName(value)
		if id not in learned or seen.has(id):
			return false
		seen[id] = true
	return true

static func assign(slots: Array[Variant], skill: StringName, destination: int) -> Array[Variant]:
	var result: Array[Variant] = slots.duplicate()
	if result.size() != SLOT_COUNT or destination < 0 or destination >= SLOT_COUNT:
		return result
	var old := result.find(skill)
	if old >= 0:
		return move(result, old, destination)
	result[destination] = null if skill.is_empty() else skill
	return result

static func move(slots: Array[Variant], source: int, destination: int) -> Array[Variant]:
	var result: Array[Variant] = slots.duplicate()
	if result.size() != SLOT_COUNT or source < 0 or source >= SLOT_COUNT or destination < 0 or destination >= SLOT_COUNT:
		return result
	var previous: Variant = result[destination]
	result[destination] = result[source]
	result[source] = previous
	return result

static func for_character(character: CharacterState) -> Array[Variant]:
	if not character.action_slots.is_empty():
		return character.action_slots.duplicate()
	return from_legacy(character.presets[character.selected_preset]["active_slots"])
