extends SceneTree

const BarInput = preload("res://scripts/core/action_bar_input.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var preferences := ControlPreferences.new()
	_check(preferences.bindings.size() == 24, "24 binds")
	for index in 12:
		var event := _key(ControlPreferences.DEFAULT_KEYS[index])
		_check(preferences.slot_for_event(event) == index, "first row exact")
		event.alt_pressed = true
		_check(preferences.slot_for_event(event) == index + 12, "Alt exact second row")
		event.shift_pressed = true
		_check(preferences.slot_for_event(event) == -1, "extra modifier does not fire")
		_check(not preferences.binding_label(index).is_empty(), "readable label")
	_check(preferences.binding_label(8) == "'", "apostrophe label")
	var repeat := _key(KEY_1)
	repeat.echo = true
	_check(preferences.slot_for_event(repeat) == -1, "repeat ignored")
	_check(not preferences.set_binding(0, _key(KEY_R))["ok"], "conflict blocked")
	_check(preferences.set_binding(0, _key(KEY_R))["conflict_slot"] == 4, "conflict identifies slot")
	_check(preferences.slot_for_event(_key(KEY_1)) == 0, "failed change atomic")
	_check(not preferences.clear_binding(-1), "negative clear rejected")
	_check(not preferences.set_binding(24, _key(KEY_Z))["ok"], "invalid slot rejected")
	for reserved in ControlPreferences.RESERVED_KEYS:
		_check(preferences.set_binding(0, _key(reserved))["error_code"] == &"reserved_key", "auxiliary reserved")
	for modifier in ControlPreferences.MODIFIER_KEYS:
		_check(not preferences.set_binding(0, _key(modifier))["ok"], "modifier only rejected")
	var slots: Array[Variant] = []
	slots.resize(24)
	slots.fill(&"")
	slots[0] = &"first"
	slots[12] = &"alt_first"
	var latch := BarInput.new()
	var alt_press := _key(KEY_1)
	alt_press.alt_pressed = true
	_check(latch.press(alt_press, preferences, slots) == &"alt_first", "Alt skill latched")
	_check(latch.press(alt_press, preferences, slots) == &"", "held duplicate ignored")
	_check(latch.pending_slot == 12, "slot captured")
	_check(latch.release(_key(KEY_ALT, false)) == &"", "release Alt does not cast")
	_check(latch.release(_key(KEY_1, false)) == &"alt_first", "release remains Alt skill after Alt lifted")
	_check(latch.release(_key(KEY_1, false)) == &"", "release once")
	_check(latch.press(_key(KEY_1), preferences, slots) == &"first", "new press after release")
	latch.cancel()
	_check(latch.release(_key(KEY_1, false)) == &"", "cancel prevents later release")
	_check(latch.press(repeat, preferences, slots) == &"", "latch ignores repeat")
	_check(latch.press(_key(KEY_2), preferences, slots) == &"", "empty slot inert")
	slots[1] = null
	_check(latch.press(_key(KEY_2), preferences, slots) == &"", "null slot inert")
	slots[1] = 123
	_check(latch.press(_key(KEY_2), preferences, slots) == &"", "invalid non-id slot inert")
	# ABNT apostrophe can have a distinct physical identity from its logical glyph.
	preferences.clear_binding(8)
	var abnt := _key(KEY_APOSTROPHE)
	abnt.physical_keycode = KEY_QUOTELEFT
	_check(preferences.set_binding(8, abnt)["ok"], "ABNT physical quote capture")
	_check(preferences.bindings[8]["physical"], "physical identity saved")
	_check(preferences.slot_for_event(abnt) == 8, "ABNT quote matches")
	var shifted_glyph := _key(KEY_ASCIITILDE)
	shifted_glyph.physical_keycode = KEY_QUOTELEFT
	_check(preferences.slot_for_event(shifted_glyph) == 8, "physical key independent of logical layout")
	slots[8] = &"quote_skill"
	_check(latch.press(abnt, preferences, slots) == &"quote_skill", "physical latch")
	shifted_glyph.pressed = false
	_check(latch.release(shifted_glyph) == &"quote_skill", "physical release uses captured key")
	var logical_conflict := _key(KEY_1)
	logical_conflict.physical_keycode = KEY_KP_1
	_check(not preferences.set_binding(8, logical_conflict)["ok"], "physical capture rejects matching logical default")
	_check(preferences.clear_binding(0), "clear supported")
	_check(preferences.slot_for_event(_key(KEY_1)) == -1, "cleared binding inert")
	var remap := _key(KEY_Z)
	remap.ctrl_pressed = true
	_check(preferences.set_binding(0, remap)["ok"], "Ctrl remap accepted")
	_check(preferences.slot_for_event(remap) == 0, "remap exact")
	_check(preferences.slot_for_event(_key(KEY_Z)) == -1, "remap requires modifier")
	DirAccess.make_dir_recursive_absolute("res://.godot/verification")
	preferences.path = "res://.godot/verification/action_bindings_%d.cfg" % Time.get_ticks_usec()
	preferences.cast_mode = CastIntent.Mode.RELEASE
	preferences.smart_lock = false
	preferences.clear_binding(23)
	_check(preferences.save_settings() == OK, "settings save")
	var restored := ControlPreferences.new()
	restored.path = preferences.path
	restored.load_settings()
	_check(restored.bindings == preferences.bindings, "binding roundtrip")
	_check(restored.cast_mode == CastIntent.Mode.RELEASE and not restored.smart_lock, "legacy preferences preserved")
	var config := ConfigFile.new()
	config.load(preferences.path)
	var corrupt := preferences.bindings.duplicate(true)
	corrupt[1] = corrupt[0].duplicate()
	corrupt[2] = {"keycode": "1"}
	corrupt[3] = {"keycode": -20, "physical": false, "alt": false, "ctrl": false, "shift": false, "meta": false}
	config.set_value("battle", "action_bindings", corrupt)
	config.save(preferences.path)
	restored.load_settings()
	_check(restored.bindings[1].is_empty(), "loaded conflict disabled")
	_check(restored.bindings[2].is_empty() and restored.bindings[3].is_empty(), "malformed slots disabled")
	_check(restored.slot_for_event(remap) == 0, "valid saved slot preserved")
	config.set_value("battle", "action_bindings", [false])
	config.save(preferences.path)
	restored.load_settings()
	_check(restored.slot_for_event(_key(KEY_1)) == 0, "invalid shape defaults")
	config.erase_section_key("battle", "action_bindings")
	config.save(preferences.path)
	restored.load_settings()
	_check(restored.bindings.size() == 24 and restored.slot_for_event(_key(KEY_E)) == 7, "legacy cfg migrates defaults")
	DirAccess.remove_absolute(preferences.path)
	restored.clear_binding(0)
	restored.load_settings()
	_check(restored.slot_for_event(_key(KEY_1)) == 0 and restored.smart_lock, "missing file resets defaults")
	preferences.restore_bindings()
	_check(preferences.slot_for_event(_key(KEY_1)) == 0, "restore default")
	print("Action bar input: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	return event

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
