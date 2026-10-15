class_name RunInventoryPanel
extends Control
## Commands use only the service's preview/captured intent; no UI validity math.
const InventoryCharacterPreviewScript = preload("res://scripts/ui/inventory_character_preview.gd")
signal closed
var slots: OptionButton
var equipment_list: ItemList
var cards_list: ItemList
var socket_selector: OptionButton
var preview_label: RichTextLabel
var equipped_label: RichTextLabel
var legend_label: Label
var confirm_button: Button
var status_label: Label
var equipment_window: PanelContainer
var bag_window: PanelContainer
var close_buttons: Array[Button] = []
var slot_buttons: Dictionary[StringName, Button] = {}
var bag_tabs: TabContainer
var character_preview: Control
var _controller: RunController
var _facade: ProfileFacade
var _character_id := ""
var _dto: Dictionary = {}
var _candidate: Dictionary = {}
var _serial := 0
var _busy := false
var _dragging: PanelContainer
var _drag_start := Vector2.ZERO
var _window_start := Vector2.ZERO
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.045, 0.28)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	equipment_window = PanelContainer.new()
	equipment_window.name = "EquipmentWindow"
	equipment_window.mouse_filter = Control.MOUSE_FILTER_STOP
	equipment_window.add_theme_stylebox_override("panel", _window_style())
	add_child(equipment_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	equipment_window.add_child(column)
	_window_header(column, equipment_window, "Equipamentos")
	legend_label = Label.new()
	legend_label.text = "Peças e cartas permanecem no perfil, inclusive encaixadas."
	legend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(legend_label)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var left_slots := VBoxContainer.new()
	left_slots.custom_minimum_size.x = 134
	body.add_child(left_slots)
	var center := VBoxContainer.new()
	center.custom_minimum_size.x = 320
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var right_slots := VBoxContainer.new()
	right_slots.custom_minimum_size.x = 134
	body.add_child(right_slots)
	var all_slots := IdentityIds.equipment_slots()
	for index: int in all_slots.size():
		var slot: StringName = all_slots[index]
		var button := Button.new()
		button.name = "Slot_" + String(slot)
		button.custom_minimum_size.y = 38
		button.add_theme_font_size_override("font_size", 13)
		button.clip_text = true
		button.toggle_mode = true
		button.pressed.connect(_select_slot.bind(slot))
		(left_slots if index < 7 else right_slots).add_child(button)
		slot_buttons[slot] = button
	character_preview = InventoryCharacterPreviewScript.new()
	character_preview.name = "CharacterPreview"
	character_preview.custom_minimum_size = Vector2(300, 150)
	character_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(character_preview)
	equipped_label = RichTextLabel.new()
	equipped_label.custom_minimum_size.y = 42
	equipped_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(equipped_label)
	var gear := VBoxContainer.new()
	gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(gear)
	slots = OptionButton.new()
	slots.name = "EquipmentSlotSelector"
	for id: StringName in IdentityIds.equipment_slots():
		slots.add_item(EquipmentPresentation.SLOT_LABELS[id])
		slots.set_item_metadata(slots.item_count - 1, id)
	slots.item_selected.connect(func(_index: int) -> void:
		if _transaction_pending(): return
		_clear_preview(); refresh_view()
	)
	gear.add_child(slots)
	var gear_buttons := HBoxContainer.new()
	gear.add_child(gear_buttons)
	_button(gear_buttons, "Comparar peça", _compare_equipment)
	_button(gear_buttons, "Desequipar", func() -> void: propose({"kind": &"unequip", "slot": _slot()}))
	preview_label = RichTextLabel.new()
	preview_label.custom_minimum_size.y = 60
	column.add_child(preview_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)
	confirm_button = Button.new()
	confirm_button.text = "Confirmar troca"
	confirm_button.disabled = true
	confirm_button.custom_minimum_size.y = 44
	confirm_button.pressed.connect(confirm_change)
	column.add_child(confirm_button)
	bag_window = PanelContainer.new()
	bag_window.name = "BagWindow"
	bag_window.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_window.add_theme_stylebox_override("panel", _window_style())
	add_child(bag_window)
	var bag_column := VBoxContainer.new()
	bag_window.add_child(bag_column)
	_window_header(bag_column, bag_window, "Mochila")
	bag_tabs = TabContainer.new()
	bag_tabs.name = "BagTabs"
	bag_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_column.add_child(bag_tabs)
	_empty_tab("Consumíveis", "Nenhum consumível disponível.")
	var equipables := VBoxContainer.new()
	equipables.name = "Equipáveis"
	bag_tabs.add_child(equipables)
	equipment_list = ItemList.new()
	equipment_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_list.icon_scale = 0.5
	equipment_list.item_selected.connect(_equipment_selected)
	equipables.add_child(equipment_list)
	_empty_tab("Misc", "Nenhum item diverso disponível.")
	var pack := VBoxContainer.new()
	pack.name = "Cartas"
	bag_tabs.add_child(pack)
	cards_list = ItemList.new()
	cards_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_list.icon_scale = 0.5
	cards_list.item_selected.connect(_card_selected)
	pack.add_child(cards_list)
	socket_selector = OptionButton.new()
	socket_selector.fit_to_longest_item = false
	socket_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	socket_selector.item_selected.connect(func(_index: int) -> void:
		if not _transaction_pending(): _clear_preview()
	)
	pack.add_child(socket_selector)
	var socket_buttons := HBoxContainer.new()
	pack.add_child(socket_buttons)
	_button(socket_buttons, "Encaixar / transferir", _compare_card)
	_button(socket_buttons, "Retirar", _compare_unsocket)
	bag_tabs.current_tab = 1
	get_viewport().size_changed.connect(_layout_windows)
	_layout_windows()
	hide()
func _empty_tab(title: String, message: String) -> void:
	var page := VBoxContainer.new()
	page.name = title
	bag_tabs.add_child(page)
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(label)
func _window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182333")
	style.border_color = Color("83b7a5")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 7
	return style
func _window_header(parent: VBoxContainer, window: PanelContainer, title: String) -> void:
	var header := HBoxContainer.new()
	header.name = "DragHeader"
	header.custom_minimum_size.y = 48
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_header_input.bind(window))
	parent.add_child(header)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 21)
	header.add_child(label)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.custom_minimum_size = Vector2(52, 44)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(dismiss)
	header.add_child(close_button)
	close_buttons.append(close_button)
func _header_input(event: InputEvent, window: PanelContainer) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			move_child(window, get_child_count() - 1)
			_dragging = window
			_drag_start = get_local_mouse_position()
			_window_start = window.position
		else:
			_dragging = null
		accept_event()
func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		dismiss()
		get_viewport().set_input_as_handled()
	elif _dragging != null and event is InputEventMouseMotion:
		_dragging.position = _clamp_window(_window_start + get_local_mouse_position() - _drag_start, _dragging.size)
		get_viewport().set_input_as_handled()
	elif _dragging != null and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = null
func _clamp_window(at: Vector2, extent: Vector2) -> Vector2:
	var viewport := GuiMetrics.local_extent(self)
	return Vector2(clampf(at.x, 0.0, maxf(0.0, viewport.x - extent.x)), clampf(at.y, 0.0, maxf(0.0, viewport.y - extent.y)))
func _layout_windows() -> void:
	if equipment_window == null or bag_window == null: return
	var viewport := GuiMetrics.local_extent(self)
	var gap := 12.0
	var width := minf(742.0, maxf(560.0, viewport.x * 0.62))
	var bag_width := minf(400.0, maxf(290.0, viewport.x - width - gap - 24.0))
	var height := minf(568.0, viewport.y - 48.0)
	equipment_window.size = Vector2(width, height)
	bag_window.size = Vector2(bag_width, height)
	var total := width + gap + bag_width
	equipment_window.position = _clamp_window(Vector2((viewport.x - total) * 0.5, (viewport.y - height) * 0.5), equipment_window.size)
	bag_window.position = _clamp_window(equipment_window.position + Vector2(width + gap, 0), bag_window.size)
func _select_slot(slot: StringName) -> void:
	if _transaction_pending(): return
	for index: int in slots.item_count:
		if slots.get_item_metadata(index) == slot:
			slots.select(index)
			break
	_clear_preview()
	refresh_view()
func _column(parent: Container, title: String, minimum: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = minimum
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	var label := Label.new()
	label.text = title
	col.add_child(label)
	return col
func _button(parent: Container, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
func configure(controller: RunController) -> void:
	_controller = controller
	_facade = null
	_character_id = ""
	legend_label.text = "Treino: alterações não são gravadas no perfil." if controller.persistent_facade == null else "Peças e cartas permanecem no perfil, inclusive encaixadas."
	_clear_preview()
	refresh_view()
	show()
	_layout_windows.call_deferred()
	equipment_list.grab_focus()
func configure_profile(facade: ProfileFacade, character_id: String) -> void:
	_controller = null
	_facade = facade
	_character_id = character_id
	legend_label.text = "Peças e cartas permanecem no perfil, inclusive encaixadas."
	_clear_preview()
	refresh_view()
	show()
	_layout_windows.call_deferred()
	equipment_list.grab_focus()
func _transaction_pending() -> bool:
	if _controller != null:
		return _controller.build_service.has_pending_transaction()
	return _facade != null and not _facade._inventory_pending.is_empty()
func _slot() -> StringName:
	return slots.get_item_metadata(maxi(0, slots.selected))
func refresh_view() -> void:
	_dto = BuildPresentation.describe_profile(_facade, _character_id) if _facade != null else BuildPresentation.describe(_controller)
	if not _dto.get("ok", false):
		status_label.text = BuildPresentation.error_text(_dto.get("error_code", &"invalid_session"))
		confirm_button.disabled = true
		return
	var selected_gear: Variant = equipment_list.get_item_metadata(equipment_list.get_selected_items()[0]) if not equipment_list.get_selected_items().is_empty() else null
	var selected_card: Variant = cards_list.get_item_metadata(cards_list.get_selected_items()[0]) if not cards_list.get_selected_items().is_empty() else null
	equipment_list.clear()
	cards_list.clear()
	var selected_name := "Vazio"
	for slot: StringName in IdentityIds.equipment_slots():
		var instance: Variant = _dto["equipped"][slot]
		var name := "Vazio"
		for row: Dictionary in _dto["equipment"]:
			if row["id"] == instance: name = row["name"]
		if slot == _slot(): selected_name = name
		var button: Button = slot_buttons[slot]
		button.text = "%s\n%s" % [EquipmentPresentation.SLOT_LABELS[slot], name]
		button.tooltip_text = "%s: %s" % [EquipmentPresentation.SLOT_LABELS[slot], name]
		button.button_pressed = slot == _slot() if button.toggle_mode else false
	equipped_label.text = "Selecionado: %s\n%s" % [EquipmentPresentation.SLOT_LABELS[_slot()], selected_name]
	character_preview.call("configure", _dto.get("identity_id", &"swordsman"), _dto.get("equipment_visual", {}))
	for row: Dictionary in _dto["equipment"]:
		if not EquipmentRules.slot_matches(row["slot"], _slot()): continue
		var text := "%02d · %s · %s · ilvl %d · %d encaixe(s)" % [equipment_list.item_count + 1, row["name"], EquipmentPresentation.quality_name(row["quality_id"]), row["item_level"], row["socket_capacity"]]
		equipment_list.add_item(text, row["icon"])
		var index := equipment_list.item_count - 1
		equipment_list.set_item_metadata(index, row["id"])
		equipment_list.set_item_tooltip(index, "Exemplar %d · %s\n" % [index + 1, row["origin_label"]] + text + "\n" + row["description"] + "\n" + row["flavor"] + ("\nEquipado" if row["selected"] else ""))
		if not row["allowed"]: equipment_list.set_item_custom_fg_color(index, Color("bb8383"))
		if row["id"] == selected_gear: equipment_list.select(index)
	for row: Dictionary in _dto["cards"]:
		cards_list.add_item(row["name"] + (" · livre" if row["free"] else " · encaixada"), EquipmentPresentation.card_icon())
		var index := cards_list.item_count - 1
		cards_list.set_item_metadata(index, row["id"])
		cards_list.set_item_tooltip(index, row["description"] + "\n" + row["flavor"] + "\n" + row["origin_label"])
		if row["id"] == selected_card: cards_list.select(index)
	if _dto["cards"].is_empty():
		cards_list.add_item("Nenhuma carta obtida.")
		cards_list.set_item_disabled(0, true)
	if _dto["equipment"].is_empty():
		equipment_list.add_item("Nenhum equipamento obtido.")
		equipment_list.set_item_disabled(0, true)
	_refresh_sockets()
func _socket_host() -> Variant:
	if not equipment_list.get_selected_items().is_empty():
		var selected: Variant = equipment_list.get_item_metadata(equipment_list.get_selected_items()[0])
		for row: Dictionary in _dto.get("equipment",[]):
			if row["id"] == selected and EquipmentRules.slot_matches(row["slot"],_slot()): return selected
	return _dto.get("equipped",{}).get(_slot())
func _refresh_sockets() -> void:
	socket_selector.clear()
	var host: Variant = _socket_host()
	for row: Dictionary in _dto.get("equipment", []):
		if row["id"] != host: continue
		var attached: Array = _dto["inventory"]["sockets"].get(host, [])
		for index: int in row["socket_capacity"]:
			var name := "vazio"
			var card: Variant = attached[index] if index < attached.size() else null
			for entry: Dictionary in _dto["cards"]:
				if entry["id"] == card: name = entry["name"]
			socket_selector.add_item("Encaixe %d · %s" % [index + 1, name])
	socket_selector.disabled = socket_selector.item_count == 0
func _clear_preview() -> void:
	_candidate.clear()
	if confirm_button != null:
		confirm_button.disabled = true
		confirm_button.text = "Confirmar troca"
func _equipment_selected(_index: int) -> void:
	if _transaction_pending(): return
	_clear_preview()
	_refresh_sockets()
	_compare_equipment()
func _card_selected(_index: int) -> void:
	if _transaction_pending(): return
	_clear_preview()
	var selected_id: Variant = cards_list.get_item_metadata(cards_list.get_selected_items()[0])
	for entry: Dictionary in _dto["cards"]:
		if entry["id"] == selected_id:
			preview_label.text = entry["name"] + "\n" + entry["description"] + "\n" + entry["origin_label"]
			break
func _compare_equipment() -> void:
	if equipment_list.get_selected_items().is_empty(): return
	propose({"kind": &"equip", "slot": _slot(), "equipment_instance_id": equipment_list.get_item_metadata(equipment_list.get_selected_items()[0])})
func _compare_unsocket() -> void:
	if socket_selector.selected < 0: return
	propose({"kind": &"unsocket", "equipment_instance_id": _socket_host(), "socket_index": socket_selector.selected})
func _compare_card() -> void:
	if cards_list.get_selected_items().is_empty() or socket_selector.selected < 0: return
	var card: StringName = cards_list.get_item_metadata(cards_list.get_selected_items()[0])
	var values := {"kind": &"socket", "equipment_instance_id": _socket_host(), "socket_index": socket_selector.selected, "card_instance_id": card}
	for host: Variant in _dto["inventory"]["sockets"]:
		var attached: Array = _dto["inventory"]["sockets"][host]
		if card in attached:
			values["kind"] = &"transfer"
			values["from_equipment_instance_id"] = host
			values["from_socket_index"] = attached.find(card)
	propose(values)
func propose(values: Dictionary) -> Dictionary:
	if _busy or _transaction_pending(): return BuildEffectCatalog.failure(&"save_in_progress")
	_clear_preview()
	_serial += 1
	var intent: Dictionary = _controller.build_service.context() if _controller != null else _dto.get("context", {}).duplicate(true)
	intent.merge(values, true)
	intent["request_id"] = "inventory-%d-%d" % [get_instance_id(), _serial]
	var result: Dictionary = BuildPresentation.compare(_controller.build_service, intent) if _controller != null else _facade.preview_inventory_change(_character_id, intent)
	if _controller == null:
		result["message"] = "Troca disponível." if result.get("ok", false) else BuildPresentation.error_text(result.get("error_code", &""))
	status_label.text = result["message"]
	if result["ok"]:
		_candidate = result.duplicate(true)
		confirm_button.disabled = false
		var lines: Array[String] = ["Comparação · atual → depois"]
		for key: Variant in result["before"]:
			if key not in ContentAuthoring.STAT_LABELS: continue
			if not is_equal_approx(float(result["before"][key]), float(result["after"][key])):
				lines.append("%s: %s → %s" % [ContentAuthoring.STAT_LABELS.get(key, String(key)), BuildPresentation.value_text(key, result["before"][key]), BuildPresentation.value_text(key, result["after"][key])])
		if lines.size() == 1: lines.append("Atributos iguais; confira os efeitos e encaixes da peça.")
		if result.has("hp_after") and result.has("sp_after"):
			lines.append("Vida depois: %.0f · SP depois: %.0f" % [result["hp_after"], result["sp_after"]])
		for row: Dictionary in result["inactive"]: lines.append("Efeito inativo: %s" % row.get("reason", "pré-requisito ausente"))
		lines.append_array(BuildPresentation.mechanics_lines(_dto, result))
		preview_label.text = "\n".join(lines)
	else: preview_label.text = result["message"]
	return result
func confirm_change() -> Dictionary:
	if _busy or _candidate.is_empty(): return BuildEffectCatalog.failure(&"preview_required")
	_busy = true
	confirm_button.disabled = true
	var result: Dictionary = _controller.build_service.commit_change(_candidate["intent"]) if _controller != null else _facade.commit_inventory_change(_character_id, _candidate["intent"])
	_busy = false
	if result["ok"]:
		slots.disabled = false
		equipment_list.mouse_filter = Control.MOUSE_FILTER_STOP
		cards_list.mouse_filter = Control.MOUSE_FILTER_STOP
		_clear_preview()
		refresh_view()
		status_label.text = "Troca salva no perfil."
	else:
		status_label.text = BuildPresentation.error_text(result.get("error_code", &"save_failed"))
		if result.get("read_only", false) or _transaction_pending():
			slots.disabled = true
			socket_selector.disabled = true
			equipment_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cards_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
			confirm_button.grab_focus()
			confirm_button.text = "Conferir gravação"
			confirm_button.disabled = false
		elif result.get("error_code") == &"save_failed":
			confirm_button.text = "Tentar novamente"
			confirm_button.disabled = false
		else: _clear_preview()
	return result
func dismiss() -> void:
	if _transaction_pending():
		status_label.text = "Confira a gravação antes de fechar."
		return
	_clear_preview()
	hide()
	closed.emit()
