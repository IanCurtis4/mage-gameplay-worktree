class_name ActionBarInput
extends RefCounted
## A release belongs to its key-down, not the modifiers present at key-up.

var pending_slot := -1
var pending_skill: StringName = &""
var _pending_key := 0
var _pending_physical := false
var _held_keys: Dictionary = {}

func press(event: InputEventKey, preferences: ControlPreferences, slots: Array[Variant]) -> StringName:
	if event == null or not event.pressed or event.echo:
		return &""
	var slot := preferences.slot_for_event(event)
	if slot < 0 or slot >= slots.size():
		return &""
	if not (slots[slot] is String or slots[slot] is StringName):
		return &""
	var skill := StringName(str(slots[slot]))
	if skill == &"":
		return &""
	var binding: Dictionary = preferences.bindings[slot]
	var physical: bool = binding["physical"]
	var key: int = event.physical_keycode if physical else event.keycode
	var token := "%s:%d" % ["physical" if physical else "logical", key]
	if _held_keys.has(token):
		return &""
	_held_keys[token] = true
	pending_slot = slot
	pending_skill = skill
	_pending_key = key
	_pending_physical = physical
	return skill

func release(event: InputEventKey) -> StringName:
	if event == null or event.pressed or event.echo:
		return &""
	_held_keys.erase("logical:%d" % event.keycode)
	_held_keys.erase("physical:%d" % event.physical_keycode)
	var key: int = event.physical_keycode if _pending_physical else event.keycode
	if pending_slot < 0 or key != _pending_key:
		return &""
	var result := pending_skill
	pending_slot = -1
	pending_skill = &""
	_pending_key = 0
	_pending_physical = false
	return result

func cancel() -> void:
	pending_slot = -1
	pending_skill = &""
	_pending_key = 0
	_pending_physical = false
	_held_keys.clear()
