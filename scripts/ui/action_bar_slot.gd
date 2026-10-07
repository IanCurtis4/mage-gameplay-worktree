class_name ActionBarSlot
extends Button
## UI payload only; the owner validates learned IDs and applies canonical layout rules.

signal drop_requested(data: Dictionary, destination: int)
signal removal_requested(index: int)

var slot_index := -1
var skill_id: StringName = &""
var drag_enabled := false

func _get_drag_data(_position: Vector2) -> Variant:
	if not drag_enabled or skill_id == &"":
		return null
	var preview := Label.new()
	preview.text = tooltip_text if not tooltip_text.is_empty() else text
	preview.add_theme_font_size_override("font_size", 16)
	set_drag_preview(preview)
	return {"kind": "action_skill", "skill_id": skill_id, "source_index": slot_index}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return drag_enabled and slot_index >= 0 and data is Dictionary and data.get("kind") == "action_skill" and data.get("skill_id") is StringName

func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		drop_requested.emit(data, slot_index)

func _gui_input(event: InputEvent) -> void:
	if drag_enabled and slot_index >= 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		removal_requested.emit(slot_index)
		accept_event()
