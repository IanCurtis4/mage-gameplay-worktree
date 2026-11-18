extends Control
## E09 T9: shared read-only guide of the four kit hybrids (C1.12). A subclass only
## supplies texts and its identity; opening the help never changes targeting or the run.
## It deliberately has no class_name: ClassKitRegistry loads `<id>_onboarding.gd` by path.

var status_label: Label
var toggle_button: Button
var help_label: Label
var _player: PlayerActor
var _panel: PanelContainer
var _expanded := false

## Overridden by each kit guide.
func identity_id() -> StringName:
	return &""

func guide_title() -> String:
	return ""

func status_text() -> String:
	return ""

func help_text() -> String:
	return ""

func accent_color() -> Color:
	return Color("f4d69a")

func configure(player: PlayerActor) -> void:
	_player = player
	if is_node_ready():
		refresh()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	refresh()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -440.0
	_panel.offset_right = -24.0
	_panel.offset_top = 112.0
	_panel.offset_bottom = 112.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.88)
	style.border_color = Color(accent_color(), 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 9.0
	_panel.add_theme_stylebox_override("panel", style)
	_panel.minimum_size_changed.connect(_resize_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var title := Label.new()
	title.name = "Title"
	title.text = guide_title()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", accent_color())
	header.add_child(title)
	toggle_button = Button.new()
	toggle_button.text = "Guia +"
	toggle_button.tooltip_text = "Mostrar ou recolher o guia; não dispara nem cancela uma habilidade."
	toggle_button.focus_mode = Control.FOCUS_NONE
	toggle_button.add_theme_font_size_override("font_size", 13)
	toggle_button.pressed.connect(_toggle_help)
	header.add_child(toggle_button)
	status_label = Label.new()
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("e4e8ee"))
	column.add_child(status_label)
	help_label = Label.new()
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size", 13)
	help_label.add_theme_color_override("font_color", Color("bcc6d2"))
	help_label.text = help_text()
	column.add_child(help_label)
	help_label.hide()

func _toggle_help() -> void:
	_expanded = not _expanded
	help_label.visible = _expanded
	toggle_button.text = "Guia −" if _expanded else "Guia +"
	_resize_panel()

func _resize_panel() -> void:
	if _panel != null:
		_panel.size.y = _panel.get_combined_minimum_size().y

## E10a A7.5: `has_kit()` is true with an origin module only, so `kit` can be null; the guide
## of a base (acolyte) follows the origin module, the guide of a pure kit follows the kit.
func _active_identity() -> StringName:
	if _player.kit != null:
		return _player.kit.evolution_id
	if _player.origin_kit != null:
		return _player.origin_kit.evolution_id
	return &""

## Visible only for a player whose kit (or, before the evolution, base module) is this guide's identity.
func refresh() -> void:
	if status_label == null:
		return
	visible = is_instance_valid(_player) and _player.has_kit() and _active_identity() == identity_id()
	if not visible:
		return
	var message := status_text()
	if is_inside_tree() and get_tree().paused:
		message += " · pausa"
	if status_label.text != message:
		status_label.text = message
		_resize_panel()
