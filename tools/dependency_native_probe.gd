extends "res://tools/compact_gui_native_probe.gd"
var dependency_checked := false
func _capture(viewport: SubViewport, directory: String, file_name: String) -> void:
	await super._capture(viewport,directory,file_name)
	if file_name != "berserker_tree" or dependency_checked: return
	dependency_checked = true
	var menu := viewport.get_child(0) as Control
	var window: SkillWindow = menu.skill_window
	window._select(&"berserker_obstinacy")
	var entry: Dictionary = window.skill_entries[&"berserker_obstinacy"]
	var badge := entry["card"].get_node("OriginBadge") as Label
	assert(Rect2(Vector2.ZERO,entry["card"].size).encloses(badge.get_rect()))
	assert(window._details.text.contains("Fúria") and window._details.text.contains("Base"))
	await super._capture(viewport,directory,"dependency_evolution")
	window._details.grab_focus()
	await _key(viewport,KEY_O)
	assert(window._job == &"" and window._selected == &"fury")
	await super._capture(viewport,directory,"dependency_origin")
	window._details.grab_focus()
	await _key(viewport,KEY_B)
	assert(window._job == &"berserker" and window._selected == &"berserker_obstinacy")
	await super._capture(viewport,directory,"dependency_return")
	print("DEPENDENCY_NATIVE_OK actual_keyboard_origin_and_return=true owned_jobs=2 badge_contained=true")
func _key(viewport: SubViewport, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	viewport.push_input(event,true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event,true)
	await process_frame
