class_name SkillTooltip
extends RefCounted

class BoundedTooltip extends PanelContainer:
	var content: RichTextLabel
	var scrolling: ScrollContainer
	func _ready() -> void:
		await get_tree().process_frame
		if not is_inside_tree(): return
		scrolling.custom_minimum_size.y = minf(580.0, maxf(90.0, content.get_content_height() + 6.0))

static func create(text: String) -> Control:
	var panel := BoundedTooltip.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("131d2a")
	style.border_color = Color("a0b2cf")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(420, 90)
	panel.add_child(scroll)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = text
	label.custom_minimum_size.x = 400
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_color_override("default_color", Color("edf2f8"))
	scroll.add_child(label)
	panel.content = label
	panel.scrolling = scroll
	return panel
