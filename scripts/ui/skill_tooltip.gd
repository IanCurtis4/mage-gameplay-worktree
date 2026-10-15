class_name SkillTooltip
extends RefCounted

class BoundedTooltip extends PanelContainer:
	var content: RichTextLabel
	var scrolling: ScrollContainer
	var source: Control
	var height_limit := 420.0
	func _ready() -> void:
		var extent := source.get_viewport_rect().size if is_instance_valid(source) else get_viewport_rect().size
		var width := minf(360.0, maxf(120.0, extent.x - 48.0))
		height_limit = minf(420.0, maxf(64.0, extent.y - 64.0))
		scrolling.custom_minimum_size.x = width
		content.custom_minimum_size.x = width - 16.0
		await get_tree().process_frame
		if not is_inside_tree(): return
		scrolling.custom_minimum_size.y = minf(height_limit, maxf(48.0, content.get_content_height() + 4.0))
		await get_tree().process_frame
		if not is_inside_tree(): return
		var popup := get_window() as PopupPanel
		if popup != null and is_instance_valid(source):
			popup.size = Vector2i(get_combined_minimum_size().ceil())
			var available := source.get_viewport_rect().size
			popup.position = Vector2i(Vector2(popup.position).clamp(Vector2(8, 8), (available - Vector2(popup.size) - Vector2(8, 8)).max(Vector2(8, 8))))

static func create(text: String, source: Control = null) -> Control:
	var panel := BoundedTooltip.new()
	panel.source = source
	var style := StyleBoxFlat.new()
	style.bg_color = Color("131d2a")
	style.border_color = Color("a0b2cf")
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(360, 48)
	panel.add_child(scroll)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = text
	label.custom_minimum_size.x = 344
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for font: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		label.add_theme_font_size_override(font, 13)
	label.add_theme_color_override("default_color", Color("edf2f8"))
	scroll.add_child(label)
	panel.content = label
	panel.scrolling = scroll
	return panel
