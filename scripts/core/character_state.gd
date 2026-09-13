class_name CharacterState
extends RefCounted
## Persistent per-character state. Runtime combat data must never be added here.

const PRESET_COUNT := 2
const ACTIVE_SLOT_COUNT := 5
const PASSIVE_SLOT_COUNT := 2

var character_id: String
var display_name: String
var base_class_id: StringName
var evolution_id: StringName = &""
var base_xp_total: int = 0
var job_xp_total: int = 0
var attribute_allocations: Dictionary[StringName, int] = {}
var purchased_skill_ranks: Dictionary[StringName, int] = {}
var equipped: Dictionary[StringName, Variant] = {}
var presets: Array[Dictionary] = []
var selected_preset: int = 0

func _init(
	new_character_id: String = "",
	new_display_name: String = "",
	new_base_class_id: StringName = &"swordsman"
) -> void:
	character_id = new_character_id
	display_name = new_display_name
	base_class_id = new_base_class_id
	for attribute_id: StringName in IdentityIds.attribute_ids():
		attribute_allocations[attribute_id] = 0
	equipped = _empty_equipment()
	for index: int in PRESET_COUNT:
		presets.append(_empty_preset())

func copy_state() -> CharacterState:
	var copy := CharacterState.new(character_id, display_name, base_class_id)
	copy.evolution_id = evolution_id
	copy.base_xp_total = base_xp_total
	copy.job_xp_total = job_xp_total
	copy.attribute_allocations = attribute_allocations.duplicate(true)
	copy.purchased_skill_ranks = purchased_skill_ranks.duplicate(true)
	copy.equipped = equipped.duplicate(true)
	copy.presets = presets.duplicate(true)
	copy.selected_preset = selected_preset
	return copy

static func _empty_equipment() -> Dictionary[StringName, Variant]:
	return {
		&"weapon": null,
		&"armor": null,
		&"accessory": null,
	}

static func _empty_preset() -> Dictionary:
	var active_slots: Array[Variant] = []
	var passive_slots: Array[Variant] = []
	active_slots.resize(ACTIVE_SLOT_COUNT)
	passive_slots.resize(PASSIVE_SLOT_COUNT)
	return {
		"active_slots": active_slots,
		"passive_slots": passive_slots,
		"equipped": _empty_equipment(),
	}
