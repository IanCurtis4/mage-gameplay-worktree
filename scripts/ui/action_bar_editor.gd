class_name ActionBarEditor
extends VBoxContainer
## Paused editor. Assigning shortcuts never buys, ranks or casts a skill.

const SlotScript := preload("res://scripts/ui/action_bar_slot.gd")

signal assignment_requested(skill: StringName, destination: int)
signal movement_requested(source: int, destination: int)
signal removal_requested(index: int)
signal capture_requested(index: int)
signal clear_binding_requested(index: int)
signal restore_bindings_requested
signal layout_changed(slots: Array[Variant])
signal bindings_changed

var selected_slot := 0
var managed_externally := false
var capture_binding := -1
var learned_skills: Array[StringName] = []
var action_slots: Array[Variant] = []
var control_preferences := ControlPreferences.new()
var slots_grid: GridContainer
var library: VBoxContainer
var selection_label: Label
var message_label: Label
var slot_buttons: Array[Button] = []

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if not managed_externally:
		assignment_requested.connect(assign_skill)
		movement_requested.connect(move_skill)
		removal_requested.connect(clear_slot)
		capture_requested.connect(begin_binding_capture)
		clear_binding_requested.connect(clear_binding)
		restore_bindings_requested.connect(restore_bindings)
	add_theme_constant_override("separation", 6)
	var instruction := Label.new()
	instruction.text = "Arraste uma skill ou selecione um slot e clique na biblioteca. Direito remove."
	instruction.add_theme_font_size_override("font_size", 14)
	add_child(instruction)
	slots_grid = GridContainer.new()
	slots_grid.columns = 12
	slots_grid.add_theme_constant_override("h_separation", 3)
	slots_grid.add_theme_constant_override("v_separation", 3)
	add_child(slots_grid)
	for index: int in range(24):
		var button := SlotScript.new()
		button.slot_index = index
		button.drag_enabled = true
		button.custom_minimum_size = Vector2(74, 48)
		button.clip_text = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		button.toggle_mode = true
		button.pressed.connect(select_slot.bind(index))
		button.drop_requested.connect(_drop)
		button.removal_requested.connect(func(i: int) -> void: removal_requested.emit(i))
		slots_grid.add_child(button)
		slot_buttons.append(button)
	var actions := HBoxContainer.new()
	add_child(actions)
	selection_label = Label.new()
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(selection_label)
	_action(actions, "Remover skill", func() -> void: removal_requested.emit(selected_slot))
	_action(actions, "Alterar tecla", func() -> void: capture_requested.emit(selected_slot))
	_action(actions, "Limpar tecla", func() -> void: clear_binding_requested.emit(selected_slot))
	_action(actions, "Teclas padrão", func() -> void: restore_bindings_requested.emit())
	message_label = Label.new()
	message_label.text = "Barra organiza atalhos; apenas skills aprendidas estão disponíveis."
	message_label.add_theme_font_size_override("font_size", 14)
	add_child(message_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 164
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	library = VBoxContainer.new()
	library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(library)
	select_slot(0)
	if action_slots.size() == 24:
		configure(learned_skills, action_slots, control_preferences)

func _action(row: HBoxContainer, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(callback)
	row.add_child(button)

func configure(learned: Array[StringName], slots: Array[Variant], preferences: ControlPreferences) -> void:
	learned_skills = learned.duplicate()
	action_slots = slots.duplicate() if ActionBarLayout.valid(slots, learned) else ActionBarLayout.empty()
	control_preferences = preferences
	if slots_grid == null:
		return
	for index: int in range(24):
		var id := StringName(action_slots[index]) if action_slots[index] != null else &""
		var button := slot_buttons[index] as ActionBarSlot
		button.skill_id = id
		button.text = "%s\n%s" % [preferences.binding_label(index), _name(id)]
		button.tooltip_text = "Slot %d · %s\n%s" % [index + 1, preferences.binding_label(index), _name(id)]
	for child: Node in library.get_children():
		library.remove_child(child)
		child.queue_free()
	for id: StringName in learned:
		var button := SlotScript.new()
		button.skill_id = id
		button.drag_enabled = true
		button.text = _name(id)
		button.tooltip_text = "Aprendida · %s\nClique para atribuir ao slot selecionado, ou arraste." % _name(id)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 32
		button.pressed.connect(func() -> void: assignment_requested.emit(id, selected_slot))
		library.add_child(button)
	select_slot(selected_slot)

func assign_skill(skill: StringName, destination: int) -> void:
	if not learned_skills.has(skill) or destination < 0 or destination >= 24:
		return
	configure(learned_skills, ActionBarLayout.assign(action_slots, skill, destination), control_preferences)
	layout_changed.emit(action_slots.duplicate())

func move_skill(source: int, destination: int) -> void:
	if source < 0 or source >= 24 or destination < 0 or destination >= 24:
		return
	configure(learned_skills, ActionBarLayout.move(action_slots, source, destination), control_preferences)
	layout_changed.emit(action_slots.duplicate())

func clear_slot(index: int) -> void:
	if index < 0 or index >= 24:
		return
	action_slots[index] = null
	configure(learned_skills, action_slots, control_preferences)
	layout_changed.emit(action_slots.duplicate())

func begin_binding_capture(index: int) -> void:
	if index < 0 or index >= 24:
		return
	capture_binding = index
	message_label.text = "Slot %d: pressione a combinação (Esc cancela)." % (index + 1)
	bindings_changed.emit()

func cancel_binding_capture() -> void:
	capture_binding = -1

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_binding_capture()

func handle_binding_event(event: InputEventKey) -> bool:
	if not is_visible_in_tree():
		cancel_binding_capture()
		return false
	if capture_binding < 0:
		return false
	if not event.pressed or event.echo:
		return true
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		cancel_binding_capture()
		message_label.text = "Captura cancelada."
		return true
	if event.keycode in [KEY_ALT, KEY_SHIFT, KEY_CTRL, KEY_META] or event.physical_keycode in [KEY_ALT, KEY_SHIFT, KEY_CTRL, KEY_META]:
		return true
	var result := control_preferences.set_binding(capture_binding, event)
	if not result.get("ok", false):
		var conflict := int(result.get("conflict_slot", -1))
		message_label.text = "Conflito com slot %d; escolha outra combinação." % (conflict + 1) if conflict >= 0 else "Tecla inválida ou reservada; escolha outra combinação."
		return true
	cancel_binding_capture()
	configure(learned_skills, action_slots, control_preferences)
	message_label.text = "Atalho alterado."
	bindings_changed.emit()
	return true

func clear_binding(index: int) -> void:
	cancel_binding_capture()
	if control_preferences.clear_binding(index):
		configure(learned_skills, action_slots, control_preferences)
		bindings_changed.emit()

func restore_bindings() -> void:
	cancel_binding_capture()
	control_preferences.restore_bindings()
	configure(learned_skills, action_slots, control_preferences)
	bindings_changed.emit()

func select_slot(index: int) -> void:
	selected_slot = clampi(index, 0, 23)
	selection_label.text = "Slot %d selecionado" % (selected_slot + 1)
	for i: int in range(slot_buttons.size()):
		slot_buttons[i].set_pressed_no_signal(i == selected_slot)

func _drop(data: Dictionary, destination: int) -> void:
	var source := int(data.get("source_index", -1))
	if source >= 0:
		if source >= action_slots.size() or action_slots[source] == null or StringName(action_slots[source]) != StringName(data.get("skill_id", &"")):
			return
		movement_requested.emit(source, destination)
	else:
		assignment_requested.emit(StringName(data.get("skill_id", &"")), destination)

func _name(id: StringName) -> String:
	if id == &"":
		return "—"
	var definition := ClassCatalog.skill_definition(id)
	return definition.display_name if definition != null else String(id)
