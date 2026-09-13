class_name BattleControls
extends Control

signal skill_selected(skill: StringName)
signal settings_requested(open: bool)
signal preferences_changed(mode: int, smart_lock: bool)

var skill_buttons: Dictionary[StringName, Button] = {}
var settings_overlay: ColorRect
var settings_panel: PanelContainer
var mode_option: OptionButton
var lock_option: CheckBox
var mode_description: Label
var aim_panel: PanelContainer
var aim_label: Label
var settings_button: Button
var skill_bar: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	skill_bar = HBoxContainer.new()
	add_child(skill_bar)
	skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_bar.add_theme_constant_override("separation", 10)
	set_class_skills([&"slash", &"dash"])
	aim_panel = PanelContainer.new()
	add_child(aim_panel)
	aim_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_bottom(aim_panel, 740, -146, -102)
	aim_label = Label.new()
	aim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_panel.add_child(aim_label)
	aim_panel.hide()
	settings_button = Button.new()
	settings_button.text = "Controles  ·  Esc"
	settings_button.focus_mode = Control.FOCUS_NONE
	add_child(settings_button)
	settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -208
	settings_button.offset_top = 20
	settings_button.offset_right = -24
	settings_button.offset_bottom = 56
	settings_button.pressed.connect(func() -> void: settings_requested.emit(true))
	_build_settings()

func _build_settings() -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.color = Color(0.025, 0.045, 0.065, 0.88)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(settings_overlay)
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel = PanelContainer.new()
	settings_overlay.add_child(settings_panel)
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -290
	settings_panel.offset_right = 290
	settings_panel.offset_top = -215
	settings_panel.offset_bottom = 215
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	settings_panel.add_child(column)
	var title := Label.new()
	title.text = "Controles de batalha"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("f5cc77"))
	column.add_child(title)
	var caption := Label.new()
	caption.text = "Como lançar Q / W / A / S / D"
	column.add_child(caption)
	mode_option = OptionButton.new()
	mode_option.add_item("Selecionar e confirmar com clique", CastIntent.Mode.CONFIRM)
	mode_option.add_item("Mirar segurando; lançar ao soltar", CastIntent.Mode.RELEASE)
	mode_option.add_item("Smart cast · lançar ao pressionar", CastIntent.Mode.INSTANT)
	mode_option.custom_minimum_size.y = 44
	mode_option.item_selected.connect(_mode_changed)
	column.add_child(mode_option)
	mode_description = Label.new()
	mode_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_description.custom_minimum_size.y = 56
	column.add_child(mode_description)
	lock_option = CheckBox.new()
	lock_option.text = "Smart lock de alvos pelo mouse"
	lock_option.toggled.connect(func(value: bool) -> void: preferences_changed.emit(mode_option.selected, value))
	column.add_child(lock_option)
	var note := Label.new()
	note.text = "Botão direito / Esc cancela a mira.\nOs botões de skill selecionam para confirmar no chão."
	note.add_theme_color_override("font_color", Color("b9cbd3"))
	column.add_child(note)
	var close := Button.new()
	close.text = "Voltar à batalha"
	close.custom_minimum_size.y = 42
	close.pressed.connect(func() -> void: settings_requested.emit(false))
	column.add_child(close)
	settings_overlay.hide()

func set_options(mode: int, smart_lock: bool) -> void:
	mode_option.select(mode)
	lock_option.set_pressed_no_signal(smart_lock)
	_update_description(mode)

func show_skill_state(skill: StringName, text: String, active: bool) -> void:
	if not skill_buttons.has(skill):
		return
	skill_buttons[skill].text = text
	skill_buttons[skill].set_pressed_no_signal(active)

func set_class_skills(skill_ids: Array[StringName]) -> void:
	if skill_bar == null:
		return
	for child: Node in skill_bar.get_children():
		child.free()
	skill_buttons.clear()
	var button_width := 138.0 if skill_ids.size() > 2 else 185.0
	var bar_width := button_width * skill_ids.size() + 10.0 * maxi(0, skill_ids.size() - 1)
	_center_bottom(skill_bar, bar_width, -86, -18)
	for id: StringName in skill_ids:
		var button := Button.new()
		button.custom_minimum_size = Vector2(button_width, 68)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.pressed.connect(_choose_skill.bind(id))
		skill_bar.add_child(button)
		skill_buttons[id] = button

func set_aim_text(text: String) -> void:
	aim_panel.visible = not text.is_empty()
	aim_label.text = text

func _choose_skill(skill: StringName) -> void:
	skill_selected.emit(skill)

func _mode_changed(mode: int) -> void:
	_update_description(mode)
	preferences_changed.emit(mode, lock_option.button_pressed)

func _update_description(mode: int) -> void:
	mode_description.text = [
		"A tecla da ação abre a mira. Mova o mouse e clique para lançar. Soltar mantém a mira.",
		"Segure a tecla para mirar. Solte para lançar; um clique também confirma. Só um lançamento por comando.",
		"A tecla lança imediatamente no mouse. Use um botão da barra quando quiser mirar com calma."
	][mode]

func _center_bottom(control: Control, width: float, top: float, bottom: float) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	control.offset_left = -width * 0.5
	control.offset_right = width * 0.5
	control.offset_top = top
	control.offset_bottom = bottom
