class_name PlaytestAdminPanel
extends PanelContainer
## Explicit test commands; persistence and combat rules stay in their services.
signal closed
signal changed
signal offer_requested

var facade: ProfileFacade
var controller: RunController
var character_id := ""
var run_admin: PlaytestRunAdmin
var catalog: BuildEffectCatalog
var equipment: OptionButton
var cards: OptionButton
var augments: OptionButton
var mobs: OptionButton
var tiers: OptionButton
var quality: OptionButton
var item_level: SpinBox
var sockets: SpinBox
var status: Label
var _serial := 0
var _request_nonce := IdentityIds.new_profile_id()
var _pending: Dictionary = {}
var _runtime_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	var box := StyleBoxFlat.new()
	box.bg_color = Color("152332")
	box.border_color = Color("79afa8")
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", box)
	custom_minimum_size = Vector2(620, 520)
	set_anchors_preset(Control.PRESET_CENTER)
	position = Vector2(32, 32)
	size = Vector2(660, 580)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Admin de playtest"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Fechar"
	close.custom_minimum_size = Vector2(70, 32)
	close.pressed.connect(dismiss)
	header.add_child(close)
	var notice := Label.new()
	notice.text = "Equipamentos, cartas e liberação de skills alteram o save.\nAugments e inimigos extras duram só nesta run."
	column.add_child(notice)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	equipment = _selector(body, "Equipamento permanente")
	var fields := HBoxContainer.new()
	body.add_child(fields)
	_label(fields, "ilvl")
	item_level = _number(fields, 1, 30, 1)
	_label(fields, "Qualidade")
	quality = OptionButton.new()
	for id: StringName in EquipmentRules.QUALITY_IDS:
		quality.add_item(EquipmentPresentation.quality_name(id))
		quality.set_item_metadata(quality.item_count - 1, id)
	fields.add_child(quality)
	_label(fields, "Encaixes")
	sockets = _number(fields, 0, 4, 0)
	_button(body, "Adicionar exemplar à coleção", _grant_equipment)
	cards = _selector(body, "Carta permanente")
	_button(body, "Adicionar carta à coleção", func() -> void: _command(&"card", _selected(cards)))
	var skills := HBoxContainer.new()
	body.add_child(skills)
	_button(skills, "Liberar skills legais no máximo", func() -> void: _command(&"unlock_skills"))
	_button(skills, "Níveis máximos legais", func() -> void: _command(&"max_levels"))
	var runtime_notice := _label(body, "Durante a run: o painel pausa o combate. Inimigos admin não dão loot/XP.")
	runtime_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_runtime_buttons.append(_button(body, "Forçar escolha de augment", func() -> void: _command(&"offer")))
	augments = _selector(body, "Augment específico (respeita compatibilidade e limite)")
	_runtime_buttons.append(_button(body, "Conceder augment selecionado", func() -> void: _command(&"augment", _selected(augments))))
	mobs = _selector(body, "Espécie para invocar")
	tiers = _selector(body, "Categoria")
	for id: StringName in MobCatalog.CATEGORIES:
		tiers.add_item(MobPrototypeVisual.category_name(id))
		tiers.set_item_metadata(tiers.item_count - 1, id)
	_runtime_buttons.append(_button(body, "Invocar inimigo próximo", func() -> void: _command(&"spawn", _selected(mobs), {"category": _selected(tiers)})))
	_runtime_buttons.append(_button(body, "Remover inimigos admin", func() -> void: _command(&"clear_spawns")))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	_button(column, "Reconciliar / repetir ação pendente", _retry)
	equipment.item_selected.connect(_equipment_selected)
	hide()

func configure(owner_facade: ProfileFacade, owner_character_id: String, owner_controller: RunController = null) -> void:
	facade = owner_facade
	character_id = owner_character_id
	controller = owner_controller
	if controller != null and run_admin == null:
		run_admin = PlaytestRunAdmin.new(controller)
	var loaded := BuildContentLoader.load_catalog_for_profile(facade._catalog) if facade != null else {"ok": true, "catalog": controller.run_state.effect_catalog()}
	if not loaded.get("ok", false):
		status.text = "Catálogo indisponível."
		return
	catalog = loaded["catalog"]
	_fill(equipment, &"equipment")
	_fill(cards, &"card")
	_fill(augments, &"augment")
	mobs.clear()
	for id: StringName in catalog.mob_catalog().ids():
		var mob := catalog.mob_catalog().get_definition(id)
		mobs.add_item(mob.display_name)
		mobs.set_item_metadata(mobs.item_count - 1, id)
	for button: Button in _runtime_buttons:
		button.disabled = controller == null
	_equipment_selected(0)
	status.text = "Escolha uma ação. Cada concessão cria um exemplar."
	show()
	move_to_front()

func _fill(selector: OptionButton, kind: StringName) -> void:
	selector.clear()
	for id: StringName in catalog.ids(kind):
		var definition: Resource = catalog.get_definition(kind, id)
		selector.add_item(definition.get("display_name"))
		selector.set_item_metadata(selector.item_count - 1, id)

func _equipment_selected(_index: int) -> void:
	if catalog == null or equipment.item_count == 0:
		return
	var definition := catalog.get_definition(&"equipment", _selected(equipment)) as EquipmentDefinition
	item_level.min_value = definition.min_item_level
	item_level.max_value = definition.max_item_level
	item_level.value = clampi(definition.item_level, definition.min_item_level, definition.max_item_level)
	sockets.editable = EquipmentRules.allows_sockets(definition.metadata())
	sockets.value = definition.socket_capacity if sockets.editable else 0
	for index: int in quality.item_count:
		if quality.get_item_metadata(index) == definition.quality_id:
			quality.select(index)

func _grant_equipment() -> void:
	_command(&"equipment", _selected(equipment), {"item_level": int(item_level.value), "quality_id": _selected(quality), "socket_capacity": int(sockets.value)})

func _command(action: StringName, definition_id: StringName = &"", options: Dictionary = {}) -> void:
	if not _pending.is_empty():
		status.text = "Reconcilie a ação pendente antes de enviar outra."
		return
	_serial += 1
	var revision := facade.current_profile().revision if facade != null else -1
	_pending = {"request_id": "admin_%s_%d" % [_request_nonce, _serial], "action": action, "id": definition_id, "options": options.duplicate(true), "revision": revision}
	_retry()

func _retry() -> void:
	if _pending.is_empty():
		status.text = "Nenhuma ação pendente."
		return
	var command := _pending
	var result: Dictionary
	if command["action"] in [&"offer", &"augment", &"spawn", &"clear_spawns"]:
		result = run_admin.execute(command["request_id"], command["action"], command["id"], command["options"]) if run_admin != null else BuildEffectCatalog.failure(&"invalid_session")
	elif facade != null:
		result = PlaytestProfileAdmin.grant(facade, command["request_id"], command["revision"], character_id, command["action"], command["id"], command["options"], controller)
	else:
		result = BuildEffectCatalog.failure(&"profile_unavailable")
	if result.get("ok", false):
		_pending = {}
		status.text = "Ação aplicada." if not result.get("already_applied", false) else "Ação já aplicada; nada foi duplicado."
		if command["action"] in [&"equipment", &"card", &"unlock_skills", &"max_levels"]:
			changed.emit()
		if result.get("open_offer", false):
			hide()
			offer_requested.emit()
	elif result.get("read_only", false) or result.get("error_code") in [&"result_uncertain", &"save_failed", &"recovery_required"]:
		status.text = "Gravação pendente. Use Reconciliar para resolver a mesma ação."
	else:
		_pending = {}
		var messages := {&"encounter_active": "Conclua o encontro para esta ação.", &"offer_open": "Resolva a oferta aberta primeiro.", &"stack_cap": "Este augment já atingiu o limite.", &"no_effective_gain": "Este augment não traz ganho para a build atual.", &"invalid_session": "Ação disponível apenas em uma run válida.", &"profile_unavailable": "Concessões permanentes exigem perfil; use o lobby.", &"actor_cap": "Limite de inimigos atingido.", &"stale_revision": "O perfil mudou. Selecione novamente a ação."}
		status.text = messages.get(result.get("error_code"), "Ação indisponível neste estado. Confira a classe, a seleção e as ofertas pendentes.")

func dismiss() -> void:
	hide()
	closed.emit()

func _selected(selector: OptionButton) -> StringName:
	return StringName(selector.get_item_metadata(selector.selected)) if selector.selected >= 0 else &""

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _number(parent: Node, minimum: int, maximum: int, value: int) -> SpinBox:
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.value = value
	field.custom_minimum_size.x = 72
	parent.add_child(field)
	return field

func _selector(parent: Node, text: String) -> OptionButton:
	_label(parent, text)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.clip_text = true
	parent.add_child(selector)
	return selector

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 30
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

