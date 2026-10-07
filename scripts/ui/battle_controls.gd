class_name BattleControls
extends Control

const SlotScript := preload("res://scripts/ui/action_bar_slot.gd")
const ActionEditorScript := preload("res://scripts/ui/action_bar_editor.gd")

signal skill_selected(skill: StringName)
signal settings_requested(open: bool)
signal preferences_changed(mode: int, smart_lock: bool)
signal layout_changed(slots: Array[Variant])
signal bindings_changed

var skill_buttons: Dictionary[StringName, Button] = {}
var settings_overlay: ColorRect
var settings_panel: PanelContainer
var mode_option: OptionButton
var lock_option: CheckBox
var mode_description: Label
var aim_panel: PanelContainer
var aim_label: Label
var settings_button: Button
var skill_bar: GridContainer
var action_editor: ActionBarEditor
var capture_binding := -1
var learned_skills: Array[StringName] = []
var action_slots: Array[Variant] = []
var control_preferences := ControlPreferences.new()
var slot_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	skill_bar = GridContainer.new()
	skill_bar.columns = 12
	skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_bar.add_theme_constant_override("h_separation", 4)
	skill_bar.add_theme_constant_override("v_separation", 4)
	add_child(skill_bar)
	_center_bottom(skill_bar, 1100, -158, -18)
	aim_panel = PanelContainer.new()
	aim_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(aim_panel)
	_center_bottom(aim_panel, 740, -204, -166)
	aim_label = Label.new()
	aim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_panel.add_child(aim_label)
	aim_panel.hide()
	settings_button = Button.new()
	settings_button.text = "Controles / Barra · Esc"
	settings_button.focus_mode = Control.FOCUS_NONE
	add_child(settings_button)
	settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -234
	settings_button.offset_top = 20
	settings_button.offset_right = -24
	settings_button.offset_bottom = 56
	settings_button.pressed.connect(func() -> void: settings_requested.emit(true))
	_build_settings()
	set_class_skills([&"slash", &"dash"])

func _build_settings() -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.color = Color(0.025, 0.045, 0.065, 0.94)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(settings_overlay)
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel = PanelContainer.new()
	settings_overlay.add_child(settings_panel)
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -480
	settings_panel.offset_right = 480
	settings_panel.offset_top = -330
	settings_panel.offset_bottom = 330
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	settings_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Controles e biblioteca de ações"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	mode_option = OptionButton.new()
	mode_option.add_item("Selecionar e confirmar com clique", CastIntent.Mode.CONFIRM)
	mode_option.add_item("Mirar segurando; lançar ao soltar", CastIntent.Mode.RELEASE)
	mode_option.add_item("Smart cast · lançar ao pressionar", CastIntent.Mode.INSTANT)
	mode_option.item_selected.connect(_mode_changed)
	column.add_child(mode_option)
	mode_description = Label.new()
	mode_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_description.add_theme_font_size_override("font_size", 14)
	mode_description.custom_minimum_size.y = 34
	column.add_child(mode_description)
	lock_option = CheckBox.new()
	lock_option.text = "Smart lock de alvos pelo mouse"
	lock_option.toggled.connect(func(value: bool) -> void: preferences_changed.emit(mode_option.selected, value))
	column.add_child(lock_option)
	action_editor = ActionEditorScript.new()
	action_editor.managed_externally = true
	action_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(action_editor)
	action_editor.assignment_requested.connect(assign_skill)
	action_editor.movement_requested.connect(move_skill)
	action_editor.removal_requested.connect(clear_slot)
	action_editor.capture_requested.connect(begin_binding_capture)
	action_editor.clear_binding_requested.connect(clear_binding)
	action_editor.restore_bindings_requested.connect(restore_bindings)
	var note := Label.new()
	note.text = "Esc / direito cancela mira. Elementos: F1/F2/F3 · Limpar figura: F6 · Recompensa: F8 · Reinício: F9."
	note.add_theme_font_size_override("font_size", 14)
	column.add_child(note)
	var close := Button.new()
	close.text = "Voltar à batalha"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size.y = 36
	close.pressed.connect(func() -> void:
		cancel_binding_capture()
		settings_requested.emit(false)
	)
	column.add_child(close)
	settings_overlay.hide()

func set_action_bar(skill_ids: Array[StringName], slots: Array[Variant], preferences: ControlPreferences) -> void:
	learned_skills = skill_ids.duplicate()
	control_preferences = preferences
	action_slots = slots.duplicate() if ActionBarLayout.valid(slots, learned_skills) else ActionBarLayout.empty()
	_rebuild_bar()

func set_class_skills(skill_ids: Array[StringName]) -> void:
	var initial := ActionBarLayout.empty()
	for index: int in range(mini(24, skill_ids.size())):
		initial[index] = skill_ids[index]
	set_action_bar(skill_ids, initial, control_preferences)

func _rebuild_bar() -> void:
	if skill_bar == null:
		return
	for child: Node in skill_bar.get_children():
		skill_bar.remove_child(child)
		child.queue_free()
	skill_buttons.clear()
	slot_buttons.clear()
	var labels: Array[String] = []
	for index: int in range(24):
		labels.append(control_preferences.binding_label(index))
		var id := StringName(action_slots[index]) if action_slots[index] != null else &""
		var button := SlotScript.new()
		button.slot_index = index
		button.skill_id = id
		button.custom_minimum_size = Vector2(88, 68)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 12)
		# The arena's large modal-button padding must not expand the two-row bar.
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			var style := get_theme_stylebox(state, &"Button").duplicate() as StyleBox
			style.content_margin_top = 3.0
			style.content_margin_bottom = 3.0
			style.content_margin_left = 4.0
			style.content_margin_right = 4.0
			button.add_theme_stylebox_override(state, style)
		button.text = "%s\n%s" % [labels[index], _short_name(id)]
		button.tooltip_text = "Slot %d · %s\n%s" % [index + 1, labels[index], _name(id)]
		if id != &"":
			button.pressed.connect(_choose_skill.bind(id))
			skill_buttons[id] = button
		else:
			button.pressed.connect(func() -> void: settings_requested.emit(true))
		skill_bar.add_child(button)
		slot_buttons.append(button)
	action_editor.configure(learned_skills, action_slots, control_preferences)

func assign_skill(skill: StringName, destination: int) -> void:
	if not learned_skills.has(skill) or destination < 0 or destination >= 24:
		return
	action_slots = ActionBarLayout.assign(action_slots, skill, destination)
	_rebuild_bar()
	layout_changed.emit(action_slots.duplicate())

func move_skill(source: int, destination: int) -> void:
	if source < 0 or source >= 24 or destination < 0 or destination >= 24:
		return
	action_slots = ActionBarLayout.move(action_slots, source, destination)
	_rebuild_bar()
	layout_changed.emit(action_slots.duplicate())

func clear_slot(index: int) -> void:
	if index < 0 or index >= 24:
		return
	action_slots[index] = null
	_rebuild_bar()
	layout_changed.emit(action_slots.duplicate())

func begin_binding_capture(index: int) -> void:
	if index < 0 or index >= 24:
		return
	capture_binding = index
	action_editor.message_label.text = "Slot %d: pressione a combinação (Esc cancela)." % (index + 1)
	bindings_changed.emit()

func cancel_binding_capture() -> void:
	capture_binding = -1

func handle_binding_event(event: InputEventKey) -> bool:
	if capture_binding < 0:
		return false
	if not event.pressed or event.echo:
		return true
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		cancel_binding_capture()
		action_editor.message_label.text = "Captura cancelada."
		return true
	if event.keycode in [KEY_ALT, KEY_SHIFT, KEY_CTRL, KEY_META] or event.physical_keycode in [KEY_ALT, KEY_SHIFT, KEY_CTRL, KEY_META]:
		return true
	var result := control_preferences.set_binding(capture_binding, event)
	if not result.get("ok", false):
		var conflict := int(result.get("conflict_slot", -1))
		action_editor.message_label.text = "Conflito com slot %d; escolha outra combinação." % (conflict + 1) if conflict >= 0 else "Tecla inválida ou reservada; escolha outra combinação."
		return true
	cancel_binding_capture()
	_rebuild_bar()
	action_editor.message_label.text = "Atalho alterado."
	bindings_changed.emit()
	return true

func clear_binding(index: int) -> void:
	cancel_binding_capture()
	if control_preferences.clear_binding(index):
		_rebuild_bar()
		bindings_changed.emit()

func restore_bindings() -> void:
	cancel_binding_capture()
	control_preferences.restore_bindings()
	_rebuild_bar()
	bindings_changed.emit()

func set_options(mode: int, smart_lock: bool) -> void:
	mode_option.select(mode)
	lock_option.set_pressed_no_signal(smart_lock)
	_update_description(mode)

func show_skill_state(skill: StringName, state_text: String, active: bool) -> void:
	if not skill_buttons.has(skill):
		return
	var button := skill_buttons[skill] as ActionBarSlot
	var lines := state_text.split("\n")
	var status := String(lines[-1]).split(" · ")[-1]
	button.text = "%s\n%s\n%s" % [control_preferences.binding_label(button.slot_index), _short_name(skill), status]
	button.tooltip_text = state_text
	button.set_pressed_no_signal(active)

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
		"A tecla abre a mira. Mova o mouse e clique para lançar. Soltar mantém a mira.",
		"Segure a combinação para mirar; solte a tecla principal para lançar. Clique também confirma uma única vez.",
		"A tecla lança no mouse. Os botões da barra selecionam para confirmar com clique."
	][clampi(mode, 0, 2)]

func _name(id: StringName) -> String:
	if id == &"":
		return "Vazio"
	var definition := ClassCatalog.skill_definition(id)
	return definition.display_name if definition != null else String(id)

func _short_name(id: StringName) -> String:
	var name := _name(id)
	if name.length() <= 11:
		return name
	var words := name.split(" ")
	var first := ""
	var second := ""
	for word: String in words:
		if (first.is_empty() or first.length() + 1 + word.length() <= 11) and second.is_empty():
			first += (" " if not first.is_empty() else "") + word
		else:
			second += (" " if not second.is_empty() else "") + word
	return first + "\n" + second

func _center_bottom(control: Control, width: float, top: float, bottom: float) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	control.offset_left = -width * 0.5
	control.offset_right = width * 0.5
	control.offset_top = top
	control.offset_bottom = bottom
