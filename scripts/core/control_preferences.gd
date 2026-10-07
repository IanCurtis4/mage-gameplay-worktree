class_name ControlPreferences
extends RefCounted

var cast_mode: int = CastIntent.Mode.CONFIRM
var smart_lock := true
var path := "user://controls.cfg"
const SLOT_COUNT := 24
const DEFAULT_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_R, KEY_F, KEY_Q, KEY_E, KEY_APOSTROPHE, KEY_V, KEY_5, KEY_T]
const RESERVED_KEYS := [KEY_ESCAPE, KEY_TAB, KEY_F1, KEY_F2, KEY_F3, KEY_F6, KEY_F8, KEY_F9]
const MODIFIER_KEYS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK]
var bindings: Array[Variant] = []

func _init() -> void:
	restore_bindings()

func load_settings() -> void:
	cast_mode = CastIntent.Mode.CONFIRM
	smart_lock = true
	restore_bindings()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var stored_mode: Variant = config.get_value("battle", "cast_mode", CastIntent.Mode.CONFIRM)
	if stored_mode is int and stored_mode >= CastIntent.Mode.CONFIRM and stored_mode <= CastIntent.Mode.INSTANT:
		cast_mode = stored_mode
	var stored_lock: Variant = config.get_value("battle", "smart_lock", true)
	if stored_lock is bool:
		smart_lock = stored_lock
	var stored: Variant = config.get_value("battle", "action_bindings") if config.has_section_key("battle", "action_bindings") else null
	if stored is Array and stored.size() == SLOT_COUNT:
		# A stored invalid/conflicting slot stays empty, never silently fires twice.
		bindings.fill({})
		for index in SLOT_COUNT:
			var binding := _validated_binding(stored[index])
			if not binding.is_empty() and _conflict_slot(binding, index) < 0:
				bindings[index] = binding

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("battle", "cast_mode", cast_mode)
	config.set_value("battle", "smart_lock", smart_lock)
	config.set_value("battle", "action_bindings", bindings)
	return config.save(path)

func restore_bindings() -> void:
	bindings.clear()
	for index in SLOT_COUNT:
		bindings.append({"keycode": int(DEFAULT_KEYS[index % 12]), "physical": false,
			"alt": index >= 12, "ctrl": false, "shift": false, "meta": false})

func clear_binding(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return false
	bindings[index] = {}
	return true

func binding_from_event(event: InputEventKey) -> Dictionary:
	if event == null:
		return {}
	var physical := event.physical_keycode != 0
	return _validated_binding({"keycode": int(event.physical_keycode if physical else event.keycode),
		"physical": physical, "alt": event.alt_pressed, "ctrl": event.ctrl_pressed,
		"shift": event.shift_pressed, "meta": event.meta_pressed})

func set_binding(index: int, value: Variant) -> Dictionary:
	if index < 0 or index >= SLOT_COUNT:
		return _binding_result(false, &"invalid_slot")
	var binding: Dictionary
	if value is InputEventKey:
		var key := int(value.physical_keycode if value.physical_keycode != 0 else value.keycode)
		if key in RESERVED_KEYS:
			return _binding_result(false, &"reserved_key")
		binding = binding_from_event(value)
	else:
		binding = _validated_binding(value)
	if binding.is_empty():
		return _binding_result(false, &"invalid_key")
	var conflict := _conflict_slot(binding, index)
	if value is InputEventKey:
		# A capture includes both identities; reject cross logical/physical matches too.
		for candidate in SLOT_COUNT:
			if candidate != index and _matches(bindings[candidate], value):
				conflict = candidate
				break
	if conflict >= 0:
		return _binding_result(false, &"binding_conflict", conflict)
	bindings[index] = binding.duplicate()
	return _binding_result(true, &"")

func binding_label(index: int) -> String:
	if index < 0 or index >= bindings.size() or bindings[index].is_empty():
		return "Sem atalho"
	var binding: Dictionary = bindings[index]
	var label := ""
	for modifier in ["ctrl", "alt", "shift", "meta"]:
		if binding[modifier]:
			label += {"ctrl": "Ctrl", "alt": "Alt", "shift": "Shift", "meta": "Meta"}[modifier] + "+"
	label += "'" if binding["keycode"] == KEY_APOSTROPHE else OS.get_keycode_string(binding["keycode"])
	return label

func slot_for_event(event: InputEventKey) -> int:
	if event == null or event.echo:
		return -1
	for index in SLOT_COUNT:
		if _matches(bindings[index], event):
			return index
	return -1

func binding_key_token(event: InputEventKey) -> String:
	if event == null:
		return ""
	return "physical:%d" % event.physical_keycode if event.physical_keycode != 0 else "logical:%d" % event.keycode

func _matches(value: Variant, event: InputEventKey) -> bool:
	var binding := _validated_binding(value)
	if binding.is_empty():
		return false
	var key := int(event.physical_keycode if binding["physical"] else event.keycode)
	return key == binding["keycode"] and event.alt_pressed == binding["alt"] \
		and event.ctrl_pressed == binding["ctrl"] and event.shift_pressed == binding["shift"] \
		and event.meta_pressed == binding["meta"]

func _validated_binding(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	for field in ["keycode", "physical", "alt", "ctrl", "shift", "meta"]:
		if not value.has(field):
			return {}
	if not value["keycode"] is int:
		return {}
	var key: int = value["keycode"]
	if key <= 0 or key in MODIFIER_KEYS or key in RESERVED_KEYS:
		return {}
	# Letters/digits/punctuation and defined Godot special keys only; no modifier mask.
	if (key < KEY_SPECIAL and (key < 32 or key > 0x10ffff)) or (key >= KEY_SPECIAL and key > KEY_LAUNCHF):
		return {}
	for field in ["physical", "alt", "ctrl", "shift", "meta"]:
		if not value[field] is bool:
			return {}
	return {"keycode": key, "physical": value["physical"], "alt": value["alt"],
		"ctrl": value["ctrl"], "shift": value["shift"], "meta": value["meta"]}

func _conflict_slot(binding: Dictionary, excluded: int) -> int:
	for index in SLOT_COUNT:
		if index == excluded:
			continue
		var candidate := _validated_binding(bindings[index])
		if candidate.is_empty():
			continue
		if binding["keycode"] == candidate["keycode"] and binding["alt"] == candidate["alt"] \
			and binding["ctrl"] == candidate["ctrl"] and binding["shift"] == candidate["shift"] \
			and binding["meta"] == candidate["meta"]:
			return index
	return -1

func _binding_result(ok: bool, code: StringName, conflict := -1) -> Dictionary:
	return {"ok": ok, "error_code": code, "conflict_slot": conflict}
