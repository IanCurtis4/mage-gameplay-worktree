class_name RunInventoryPanel
extends Control
## Commands use only the service's preview/captured intent; no UI validity math.
signal closed
var slots: OptionButton
var equipment_list: ItemList
var cards_list: ItemList
var socket_selector: OptionButton
var preview_label: RichTextLabel
var equipped_label: RichTextLabel
var confirm_button: Button
var status_label: Label
var _controller: RunController
var _dto: Dictionary = {}
var _candidate: Dictionary = {}
var _serial := 0
var _busy := false
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.045, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24; panel.offset_top = 22; panel.offset_right = -24; panel.offset_bottom = -22
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Equipamentos e cartas"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Fechar (Esc)"
	close_button.pressed.connect(dismiss)
	header.add_child(close_button)
	var legend := Label.new()
	legend.text = "Equipamentos ficam na coleção. Cartas e encaixes desaparecem ao encerrar a run."
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(legend)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var worn := _column(body, "Equipado", 205)
	equipped_label = RichTextLabel.new()
	equipped_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	worn.add_child(equipped_label)
	var gear := _column(body, "Coleção permanente", 330)
	slots = OptionButton.new()
	for id: StringName in IdentityIds.equipment_slots():
		slots.add_item(EquipmentPresentation.SLOT_LABELS[id])
		slots.set_item_metadata(slots.item_count - 1, id)
	slots.item_selected.connect(func(_index: int) -> void:
		if _transaction_pending(): return
		_clear_preview(); refresh_view()
	)
	gear.add_child(slots)
	equipment_list = ItemList.new()
	equipment_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_list.icon_scale = 0.5
	equipment_list.item_selected.connect(_equipment_selected)
	gear.add_child(equipment_list)
	var gear_buttons := HBoxContainer.new()
	gear.add_child(gear_buttons)
	_button(gear_buttons, "Comparar peça", _compare_equipment)
	_button(gear_buttons, "Desequipar", func() -> void: propose({"kind": &"unequip", "slot": _slot()}))
	var pack := _column(body, "Cartas desta run", 300)
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
	preview_label = RichTextLabel.new()
	preview_label.custom_minimum_size.y = 130
	column.add_child(preview_label)
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(status_label)
	confirm_button = Button.new()
	confirm_button.text = "Confirmar troca"
	confirm_button.disabled = true
	confirm_button.pressed.connect(confirm_change)
	bottom.add_child(confirm_button)
	hide()
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
	_clear_preview()
	refresh_view()
	show()
	equipment_list.grab_focus()
func _transaction_pending() -> bool:
	return _controller != null and _controller.build_service.has_pending_transaction()
func _slot() -> StringName:
	return slots.get_item_metadata(maxi(0, slots.selected))
func refresh_view() -> void:
	_dto = BuildPresentation.describe(_controller)
	if not _dto.get("ok", false):
		status_label.text = BuildPresentation.error_text(_dto.get("error_code", &"invalid_session"))
		confirm_button.disabled = true
		return
	var selected_gear: Variant = equipment_list.get_item_metadata(equipment_list.get_selected_items()[0]) if not equipment_list.get_selected_items().is_empty() else null
	var selected_card: Variant = cards_list.get_item_metadata(cards_list.get_selected_items()[0]) if not cards_list.get_selected_items().is_empty() else null
	equipment_list.clear()
	cards_list.clear()
	var worn: Array[String] = []
	for slot: StringName in IdentityIds.equipment_slots():
		var instance: Variant = _dto["equipped"][slot]
		var name := "Vazio"
		for row: Dictionary in _dto["equipment"]:
			if row["id"] == instance: name = row["name"]
		worn.append("%s\n  %s" % [EquipmentPresentation.SLOT_LABELS[slot], name])
	equipped_label.text = "\n".join(worn)
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
	_refresh_sockets()
func _refresh_sockets() -> void:
	socket_selector.clear()
	var host: Variant = _dto.get("equipped", {}).get(_slot())
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
	_compare_equipment()
func _card_selected(_index: int) -> void:
	if _transaction_pending(): return
	_clear_preview()
	var entry: Dictionary = _dto["cards"][cards_list.get_selected_items()[0]]
	preview_label.text = entry["name"] + "\n" + entry["description"] + "\n" + entry["origin_label"]
func _compare_equipment() -> void:
	if equipment_list.get_selected_items().is_empty(): return
	propose({"kind": &"equip", "slot": _slot(), "equipment_instance_id": equipment_list.get_item_metadata(equipment_list.get_selected_items()[0])})
func _compare_unsocket() -> void:
	if socket_selector.selected < 0: return
	propose({"kind": &"unsocket", "equipment_instance_id": _dto["equipped"][_slot()], "socket_index": socket_selector.selected})
func _compare_card() -> void:
	if cards_list.get_selected_items().is_empty() or socket_selector.selected < 0: return
	var card: StringName = cards_list.get_item_metadata(cards_list.get_selected_items()[0])
	var values := {"kind": &"socket", "equipment_instance_id": _dto["equipped"][_slot()], "socket_index": socket_selector.selected, "card_instance_id": card}
	for host: Variant in _dto["inventory"]["sockets"]:
		var attached: Array = _dto["inventory"]["sockets"][host]
		if card in attached:
			values["kind"] = &"transfer"
			values["from_equipment_instance_id"] = host
			values["from_socket_index"] = attached.find(card)
	propose(values)
func propose(values: Dictionary) -> Dictionary:
	if _busy or (_controller != null and _controller.build_service.has_pending_transaction()): return BuildEffectCatalog.failure(&"save_in_progress")
	_clear_preview()
	_serial += 1
	var intent := _controller.build_service.context()
	intent.merge(values, true)
	intent["request_id"] = "inventory-%d-%d" % [get_instance_id(), _serial]
	var result := BuildPresentation.compare(_controller.build_service, intent)
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
	var result := _controller.build_service.commit_change(_candidate["intent"])
	_busy = false
	if result["ok"]:
		slots.disabled = false
		equipment_list.mouse_filter = Control.MOUSE_FILTER_STOP
		cards_list.mouse_filter = Control.MOUSE_FILTER_STOP
		_clear_preview()
		refresh_view()
		status_label.text = "Troca aplicada. Equipamentos salvos; cartas continuam nesta run."
	else:
		status_label.text = BuildPresentation.error_text(result.get("error_code", &"save_failed"))
		if result.get("read_only", false) or _controller.build_service.has_pending_transaction():
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
	if _controller != null and _controller.build_service.has_pending_transaction():
		status_label.text = "Confira a gravação antes de fechar."
		return
	_clear_preview()
	hide()
	closed.emit()
