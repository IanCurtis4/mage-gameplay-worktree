extends SceneTree
## Programmatic UI regression; native drag routing is exercised by the renderer probe.

const ControlsScript := preload("res://scripts/ui/battle_controls.gd")
const ActionEditorScript := preload("res://scripts/ui/action_bar_editor.gd")

var checks := 0
var failures := 0
var casts := 0
var changes := 0
var cast_rank := -1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var controls := ControlsScript.new()
	viewport.add_child(controls)
	await process_frame
	var preferences := ControlPreferences.new()
	var learned: Array[StringName] = [&"slash", &"dash", &"perseverance", &"terrifying_shout", &"concentrated_rage", &"brutal_strike"]
	var slots := ActionBarLayout.empty()
	slots[0] = &"slash"
	slots[12] = &"dash"
	controls.set_action_bar(learned, slots, preferences)
	controls.set_skill_ranks({&"slash": 3, &"dash": 2})
	controls.skill_selected.connect(func(_skill: StringName, rank: int) -> void:
		casts += 1
		cast_rank = rank
	)
	controls.layout_changed.connect(func(_slots: Array[Variant]) -> void: changes += 1)
	await process_frame
	await process_frame
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(controls.skill_bar.columns == 12 and controls.slot_buttons.size() == 24, "two rows of twelve slots")
	_check(bounds.encloses(controls.skill_bar.get_global_rect()), "bar fits 1280x720")
	controls.settings_overlay.show()
	await process_frame
	await process_frame
	_check(bounds.encloses(controls.settings_panel.get_global_rect()), "paused editor fits viewport")
	for index: int in range(24):
		_check(controls.skill_bar.get_global_rect().encloses(controls.slot_buttons[index].get_global_rect()), "battle slot inside bar")
		_check(controls.settings_panel.get_global_rect().encloses(controls.action_editor.slot_buttons[index].get_global_rect()), "editor slot inside modal")
	controls.skill_buttons[&"slash"].pressed.emit()
	_check(casts == 1 and cast_rank == 0, "battle click selects once at the highest-rank sentinel")
	controls.action_editor.select_slot(23)
	_check(controls.action_editor.library.get_child_count() == 0, "shortcut editor does not render a duplicate skill library")
	controls.action_editor.assignment_requested.emit(&"perseverance", 23, 0)
	_check(controls.action_slots[23] == &"perseverance" and casts == 1 and changes == 1, "rank-aware assignment signal organizes a shortcut without casting")
	controls.assign_skill(&"unlearned", 1)
	_check(changes == 1 and controls.action_slots[1] == null, "unlearned payload cannot grant a skill")
	controls.action_editor.slot_buttons[22]._drop_data(Vector2.ZERO, {"kind": "action_skill", "skill_id": &"slash", "source_index": 0, "rank": 0})
	_check(controls.action_slots[0] == null and controls.action_slots[22] == &"slash", "slot payload moves skill")
	controls.action_editor.slot_buttons[12]._drop_data(Vector2.ZERO, {"kind": "action_skill", "skill_id": &"slash", "source_index": 22, "rank": 0})
	_check(controls.action_slots[12] == &"slash" and controls.action_slots[22] == &"dash", "occupied slot drop swaps uniquely")
	controls.action_editor.slot_buttons[1]._drop_data(Vector2.ZERO, {"kind": "action_skill", "skill_id": &"perseverance", "source_index": -1, "rank": 0})
	_check(controls.action_slots[1] == &"perseverance" and controls.action_slots[23] == null, "library duplicate moves rather than copies")
	_check(ActionBarLayout.valid(controls.action_slots, learned), "drop layout remains canonical")
	var unchanged := controls.action_slots.duplicate()
	controls.action_editor.slot_buttons[4]._drop_data(Vector2.ZERO, {"kind": "action_skill", "skill_id": &"slash", "source_index": 0, "rank": 0})
	_check(controls.action_slots == unchanged, "stale source payload cannot move a different skill")
	_check(not controls.action_editor.slot_buttons[1]._can_drop_data(Vector2.ZERO, {"kind": "equipment", "skill_id": &"slash"}), "other draggable content rejected")
	controls.action_editor.slot_buttons[2]._drop_data(Vector2.ZERO, {"kind": "action_skill", "skill_id": &"slash", "source_index": -1, "rank": 2})
	_check(ActionBarLayout.skill_id(controls.action_slots[2]) == &"slash" and ActionBarLayout.selected_rank(controls.action_slots[2]) == 2, "explicit rank is stored as a distinct slot variant")
	controls.action_editor.slot_buttons[3]._drop_data(Vector2.ZERO, {"kind": "action_skill", "skill_id": &"slash", "source_index": -1, "rank": 99})
	_check(controls.action_slots[3] == null, "forged rank above confirmed access is rejected")
	var before_fake := controls.action_slots.duplicate(true)
	controls.action_editor.slot_buttons[3]._drop_data(Vector2.ZERO, {"kind": "action_skill", "skill_id": &"unlearned", "source_index": -1, "rank": 1})
	_check(controls.action_slots == before_fake, "forged unlearned skill payload cannot alter slots")
	controls.clear_slot(1)
	_check(controls.action_slots[1] == null and not controls.skill_buttons.has(&"perseverance"), "clear removes shortcut only")
	_check(controls.learned_skills.has(&"perseverance"), "clear preserves learned library")
	controls.show_skill_state(&"slash", "1 · CORTE R5\n20 SP · RECARGA 3s", true, 0)
	_check(controls.slot_buttons[12].tooltip_text.contains("20 SP") and controls.slot_buttons[12].text.is_empty() and controls.slot_buttons[12].tooltip_text.contains("RECARGA"), "compact state preserves full cost tooltip on the matching rank variant")
	_check(not controls.slot_buttons[2].tooltip_text.contains("3s"), "rank-filtered state leaves the other version unselected")
	controls.slot_buttons[2].pressed.emit()
	_check(casts == 2 and cast_rank == 2, "explicit shortcut selection emits its selected rank")
	controls.begin_binding_capture(2)
	var echo := _key(KEY_2)
	echo.echo = true
	_check(controls.handle_binding_event(echo) and controls.capture_binding == 2, "repeat consumed during capture")
	_check(controls.handle_binding_event(_key(KEY_ALT)) and controls.capture_binding == 2, "modifier alone does not end capture")
	_check(controls.handle_binding_event(_key(KEY_1)) and controls.capture_binding == 2 and controls.action_editor.message_label.text.contains("Conflito"), "binding conflict explicit and unchanged")
	_check(controls.handle_binding_event(_key(KEY_F1)) and controls.capture_binding == 2, "reserved auxiliary binding rejected")
	var mapped := _key(KEY_B)
	mapped.physical_keycode = KEY_B
	mapped.alt_pressed = true
	_check(controls.handle_binding_event(mapped) and controls.capture_binding == -1 and preferences.binding_label(2) == "Alt+B", "capture physical modifier binding")
	controls.clear_binding(2)
	_check(preferences.binding_label(2) == "Sem atalho", "clear binding")
	controls.restore_bindings()
	_check(preferences.binding_label(2) == "3" and preferences.binding_label(12) == "Alt+1", "restore both default rows")
	controls.begin_binding_capture(5)
	_check(controls.handle_binding_event(_key(KEY_ESCAPE)) and controls.capture_binding == -1, "escape cancels capture")
	_check(casts == 2, "all editing and capture never cast")
	var editor := ActionEditorScript.new()
	viewport.add_child(editor)
	editor.configure(learned, slots, preferences)
	await process_frame
	editor.select_slot(6)
	editor.assignment_requested.emit(&"dash", 6, 0)
	_check(editor.action_slots[6] == &"dash" and editor.action_slots[12] == null, "standalone menu editor shares canonical assignment")
	editor.begin_binding_capture(6)
	_check(editor.handle_binding_event(_key(KEY_B)) and editor.capture_binding == -1, "standalone menu editor captures bindings")
	viewport.queue_free()
	await process_frame
	print("Action bar UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
