class_name ActionBarSlot
extends Button
## UI payload only; the owner validates learned IDs and applies canonical layout rules.

signal drop_requested(data: Dictionary, destination: int)
signal removal_requested(index: int)

var slot_index := -1
var skill_id: StringName = &""
var drag_enabled := false
var cast_rank := 0

func _get_drag_data(_position: Vector2) -> Variant:
	if not drag_enabled or skill_id == &"":
		return null
	var preview := Label.new()
	preview.text = tooltip_text if not tooltip_text.is_empty() else text
	preview.add_theme_font_size_override("font_size", 16)
	set_drag_preview(preview)
	return {"kind": "action_skill", "skill_id": skill_id, "source_index": slot_index, "rank": cast_rank}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return drag_enabled and slot_index >= 0 and data is Dictionary and data.get("kind") == "action_skill" and data.get("skill_id") is StringName and (not data.has("rank") or (data["rank"] is int and data["rank"] >= 0))

func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		drop_requested.emit(data, slot_index)

func _gui_input(event: InputEvent) -> void:
	if drag_enabled and slot_index >= 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		removal_requested.emit(slot_index)
		accept_event()

func _make_custom_tooltip(for_text: String) -> Object:
	return SkillTooltip.create(for_text, self)

# Combat-only face. The paused editor keeps the normal Button icon/text layout.
var combat_icon: TextureRect
var key_hint: Label
var rank_hint: Label
var cooldown_hint: Label
var blocked_hint: Label
var cooldown_remaining := 0.0
var cooldown_fraction := 1.0
var combat_blocked := false
var _cooldown_material: ShaderMaterial

func configure_combat(texture: Texture2D, binding: String) -> void:
	text = ""
	icon = null
	combat_icon = TextureRect.new()
	combat_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_icon.texture = texture
	combat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	combat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	combat_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_icon.offset_left = 3
	combat_icon.offset_top = 3
	combat_icon.offset_right = -3
	combat_icon.offset_bottom = -3
	_cooldown_material = ShaderMaterial.new()
	_cooldown_material.shader = preload("res://scripts/ui/action_cooldown.gdshader")
	combat_icon.material = _cooldown_material
	add_child(combat_icon)
	key_hint = _combat_label(10, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP)
	key_hint.text = "" if binding == "Sem atalho" else binding
	rank_hint = _combat_label(10, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM)
	rank_hint.text = "R%d" % cast_rank if cast_rank > 0 else ""
	cooldown_hint = _combat_label(16, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	blocked_hint = _combat_label(12, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	blocked_hint.add_theme_color_override("font_color", Color("ffd296"))
	set_combat_blocked(disabled)
	show_cooldown(0.0, 0.0)

func _combat_label(font_size: int, horizontal: HorizontalAlignment, vertical: VerticalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 4
	label.offset_top = 2
	label.offset_right = -4
	label.offset_bottom = -2
	label.horizontal_alignment = horizontal
	label.vertical_alignment = vertical
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("edf1ee"))
	label.add_theme_color_override("font_outline_color", Color("111923"))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	return label

func set_combat_blocked(blocked: bool) -> void:
	combat_blocked = blocked
	if combat_icon == null: return
	_cooldown_material.set_shader_parameter("unavailable", blocked)
	blocked_hint.text = "!" if blocked and not skill_id.is_empty() else ""

func show_cooldown(remaining: float, observed_duration: float) -> void:
	cooldown_remaining = maxf(0.0, remaining)
	cooldown_fraction = clampf(1.0 - cooldown_remaining / observed_duration, 0.0, 1.0) if observed_duration > 0.0 else 1.0
	if combat_icon == null: return
	var cooling := cooldown_remaining > 0.0 and not skill_id.is_empty()
	_cooldown_material.set_shader_parameter("cooling_down", cooling)
	_cooldown_material.set_shader_parameter("elapsed_fraction", cooldown_fraction)
	cooldown_hint.text = ("%d" % ceili(cooldown_remaining) if cooldown_remaining >= 10.0 else "%.1f" % cooldown_remaining) if cooling else ""
