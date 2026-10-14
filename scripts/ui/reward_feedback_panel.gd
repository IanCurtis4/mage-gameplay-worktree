class_name RewardFeedbackPanel
extends Control
## Passive recent notices plus a non-modal, scrollable history of confirmed receipts.
const NOTICE_SECONDS := 6.0
const QUALITY_COLORS := {&"common": Color("dce3ec"), &"uncommon": Color("a3dca7"), &"rare": Color("83bfff"), &"epic": Color("caa0ed"), &"legendary": Color("f4cf78")}
var recent_panel: PanelContainer
var history_panel: Panel
var summary_label: Label
var entries_column: VBoxContainer
var history_scroll: ScrollContainer
var close_button: Button
var _recent_column: VBoxContainer
var _title: Label
var _footer: Label
var _encounter_button: Button
var _journal: AcquisitionJournal
var _catalog: BuildEffectCatalog
var _persistent := false
var _encounter_filter := 0
var _latest_encounter := 0
var _remaining := 0.0
var _refresh_queued := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	recent_panel = PanelContainer.new()
	recent_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(recent_panel)
	recent_panel.position = Vector2(24, 176)
	recent_panel.size = Vector2(352, 0)
	_recent_column = _column(recent_panel, true)
	var recent_title := _label("Recebido", 15)
	_recent_column.add_child(recent_title)
	recent_panel.hide()

	history_panel = Panel.new()
	var window_style := get_theme_stylebox("panel","PanelContainer").duplicate() as StyleBoxFlat
	window_style.bg_color = Color("101c24")
	history_panel.add_theme_stylebox_override("panel", window_style)
	history_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(history_panel)
	history_panel.set_anchors_preset(Control.PRESET_CENTER)
	history_panel.offset_left = -350
	history_panel.offset_right = 350
	history_panel.offset_top = -245
	history_panel.offset_bottom = 245
	# Fixed regions keep scrolling content from growing the floating window.
	var heading := HBoxContainer.new()
	history_panel.add_child(heading)
	_region(heading,16,60)
	_title = _label("Recompensas da run", 23)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_title)
	close_button = Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.custom_minimum_size = Vector2(52, 44)
	close_button.pressed.connect(hide_history)
	heading.add_child(close_button)
	var filters := HBoxContainer.new()
	history_panel.add_child(filters)
	_region(filters,68,106)
	_encounter_button = Button.new()
	_encounter_button.text = "Este encontro"
	_encounter_button.pressed.connect(func() -> void: open_history(_latest_encounter))
	filters.add_child(_encounter_button)
	var run_button := Button.new()
	run_button.text = "Run inteira"
	run_button.pressed.connect(func() -> void: open_history(0))
	filters.add_child(run_button)
	summary_label = _label("", 17)
	history_panel.add_child(summary_label)
	_region(summary_label,115,157)
	history_scroll = ScrollContainer.new()
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_panel.add_child(history_scroll)
	history_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	history_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	history_scroll.offset_left=16
	history_scroll.offset_right=-16
	history_scroll.offset_top=170
	history_scroll.offset_bottom=-64
	entries_column = VBoxContainer.new()
	entries_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_column.add_theme_constant_override("separation", 9)
	history_scroll.add_child(entries_column)
	_footer = _label("", 15)
	history_panel.add_child(_footer)
	_footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_left=16
	_footer.offset_right=-16
	_footer.offset_top=-49
	_footer.offset_bottom=-12
	history_panel.hide()

func configure(journal: AcquisitionJournal, catalog: BuildEffectCatalog, persistent: bool) -> void:
	if _journal != null and _journal.changed.is_connected(_on_changed):
		_journal.changed.disconnect(_on_changed)
	_journal = journal
	_catalog = catalog
	_persistent = persistent
	_journal.changed.connect(_on_changed)
	_refresh()

func _column(parent: Control, passive: bool = false) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE if passive else Control.MOUSE_FILTER_PASS
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14 if not passive else 10)
	parent.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE if passive else Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	return column

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _on_changed() -> void:
	_remaining = NOTICE_SECONDS
	if not _refresh_queued:
		_refresh_queued = true
		_flush_refresh.call_deferred()

func _flush_refresh() -> void:
	if _refresh_queued:
		_refresh()

func _refresh() -> void:
	_refresh_queued = false
	if _journal == null or history_panel == null:
		return
	var all := _journal.entries()
	if not all.is_empty():
		_latest_encounter = maxi(_latest_encounter, int(all[-1]["encounter"]))
	_encounter_button.text = "Encontro %d" % _latest_encounter
	_title.text = "Recompensas da run" if _encounter_filter == 0 else "Obtido no encontro %d" % _encounter_filter
	var total := _journal.totals(_encounter_filter)
	summary_label.text = "XP Base +%d · XP Job +%d\n%d equipamento(s) · %d carta(s) · %d augment(s)" % [total["base_xp"], total["job_xp"], total["equipment"], total["cards"], total["augments"]]
	_footer.text = "Equipamentos e cartas ficam no perfil. Augments valem somente nesta run." if _persistent else "Sessão local: as aquisições não são gravadas no perfil."
	_clear(entries_column)
	var entries := _journal.entries(_encounter_filter)
	if entries.is_empty():
		entries_column.add_child(_label("Nenhuma aquisição confirmada. Colete a recompensa ao terminar o encontro.", 17))
	for entry: Dictionary in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		entries_column.add_child(row)
		var icon := _icon(entry)
		if icon != null:
			var texture := TextureRect.new()
			texture.texture = icon
			texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			texture.custom_minimum_size = Vector2(32,32)
			texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(texture)
		var label := _label("Encontro %d · %s" % [entry["encounter"],entry["text"]],17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", _color(entry))
		row.add_child(label)
	for index: int in range(_recent_column.get_child_count()-1,0,-1):
		var child := _recent_column.get_child(index)
		_recent_column.remove_child(child)
		child.queue_free()
	for entry: Dictionary in all.slice(maxi(0,all.size()-3)):
		var label := _label(entry["text"],15)
		label.add_theme_color_override("font_color",_color(entry))
		_recent_column.add_child(label)
	recent_panel.visible = not all.is_empty() and _remaining > 0.0 and not history_panel.visible

func _icon(entry: Dictionary) -> Texture2D:
	if entry["kind"] == &"equipment":
		return EquipmentPresentation.icon(_catalog.get_definition(&"equipment",entry["definition_id"]) as EquipmentDefinition)
	if entry["kind"] == &"card":
		return EquipmentPresentation.card_icon()
	if entry["kind"] == &"augment":
		var definition := _catalog.get_definition(&"augment",entry["definition_id"]) as AugmentDefinition
		return definition.icon if definition != null else null
	return null

func _color(entry: Dictionary) -> Color:
	if entry["kind"] == &"xp": return Color("90d8ef")
	if entry["kind"] == &"augment": return Color("e9c67b")
	return QUALITY_COLORS.get(entry.get("quality_id",&"common"),Color("dce3ec"))

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func open_history(encounter: int = 0) -> void:
	_encounter_filter = encounter
	_latest_encounter = maxi(_latest_encounter,encounter)
	_refresh()
	history_scroll.scroll_vertical = 0
	history_panel.show()
	recent_panel.hide()
	close_button.grab_focus()

func hide_history() -> void:
	history_panel.hide()

func hide_recent() -> void:
	_remaining = 0.0
	recent_panel.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if history_panel != null and history_panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_history()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_remaining = maxf(0.0,_remaining-delta)
	if recent_panel != null:
		recent_panel.visible = _remaining > 0.0 and not history_panel.visible
		recent_panel.modulate.a = minf(1.0,_remaining)

func _region(control: Control, top: float, bottom: float) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_WIDE)
	control.offset_left = 16
	control.offset_right = -16
	control.offset_top = top
	control.offset_bottom = bottom
