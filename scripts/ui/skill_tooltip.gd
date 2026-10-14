class_name SkillTooltip
extends RefCounted

static func create(text: String) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("131d2a")
	style.border_color = Color("a0b2cf")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 370
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("edf2f8"))
	panel.add_child(label)
	return panel
