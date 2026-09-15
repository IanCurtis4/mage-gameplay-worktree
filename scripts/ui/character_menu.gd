class_name CharacterMenu
extends Control
## E02.1 roster screen. It only asks ProfileFacade to mutate the normal profile.

const DEFAULT_PROFILE_DIRECTORY := "user://"
const MAX_CHARACTERS := 8
const ProfileFacadeScript := preload("res://scripts/core/profile_facade.gd")
const ProfileStoreScript := preload("res://scripts/core/profile_store.gd")
const ProfileCatalogScript := preload("res://scripts/core/profile_catalog.gd")

var profile_directory := DEFAULT_PROFILE_DIRECTORY
var facade: RefCounted
var _request_serial := 0
var _selected_index := -1
var _read_only := false

var status_label: Label
var roster_list: ItemList
var name_input: LineEdit
var create_button: Button
var create_buttons: Array[Button] = []
var select_button: Button
var empty_label: Label
var build_summary_label: Label
var preset_selector: OptionButton
var active_slot_a: OptionButton
var active_slot_b: OptionButton
var passive_slot: OptionButton
var weapon_selector: OptionButton
var armor_selector: OptionButton
var accessory_selector: OptionButton
var save_build_button: Button
var start_run_button: Button
var menu_scroll: ScrollContainer
var menu_panel: VBoxContainer

func set_profile_directory(directory: String) -> void:
	profile_directory = directory

func set_profile_facade(value: RefCounted) -> void:
	facade = value

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_layout_panel()
	get_viewport().size_changed.connect(_layout_panel)
	_open_profile()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or roster_list == null or roster_list.item_count == 0:
		return
	if event.is_action_pressed(&"ui_up"):
		_select_roster_index(maxi(0, _selected_index - 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down"):
		_select_roster_index(mini(roster_list.item_count - 1, _selected_index + 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") and _selected_index >= 0:
		_select_current_character()
		get_viewport().set_input_as_handled()

func create_character(base_class_id: StringName) -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null:
		return _show_result({"ok": false, "error_code": &"profile_unavailable"})
	var display_name := name_input.text.strip_edges()
	if display_name.is_empty():
		display_name = "Novo %s" % _class_name(base_class_id)
	var result: Dictionary = facade.create_character(_request_id("create"), profile.revision, display_name, base_class_id)
	if result.get("ok", false):
		name_input.clear()
	return _show_result(result, "Personagem criado.")

func select_character_at(index: int) -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null or index < 0 or index >= profile.characters.size():
		return _show_result({"ok": false, "error_code": &"invalid_character_id"})
	var character: Variant = profile.characters[index]
	return _show_result(facade.select_character(_request_id("select"), profile.revision, character.character_id), "Personagem selecionado.")

func _open_profile() -> void:
	if facade == null:
		facade = ProfileFacadeScript.new(ProfileStoreScript.new(profile_directory, ProfileCatalogScript.pilot()))
	_show_result(facade.open_profile(), "Perfil carregado.")

func _select_current_character() -> void:
	select_character_at(_selected_index)

func _select_roster_index(index: int) -> void:
	if index < 0 or index >= roster_list.item_count:
		return
	_selected_index = index
	roster_list.select(index)
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile != null:
		preset_selector.select(profile.characters[index].selected_preset)
		_populate_build_editor(profile.characters[index])
		build_summary_label.text = _build_summary(profile.characters[index])
	select_button.disabled = false
	preset_selector.disabled = _read_only
	save_build_button.disabled = _read_only

func _choose_preset(preset_index: int) -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null or _selected_index < 0:
		return _show_result({"ok": false, "error_code": &"invalid_character_id"})
	var character: Variant = profile.characters[_selected_index]
	return _show_result(facade.select_preset(_request_id("preset"), profile.revision, character.character_id, preset_index), "Preset selecionado.")

func _save_build() -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null or _selected_index < 0:
		return _show_result({"ok": false, "error_code": &"invalid_character_id"})
	var character: Variant = profile.characters[_selected_index]
	var preset: Dictionary = character.presets[character.selected_preset].duplicate(true)
	var active_slots: Array[Variant] = preset["active_slots"].duplicate(true)
	active_slots[0] = _selected_option(active_slot_a)
	active_slots[1] = _selected_option(active_slot_b)
	var passive_slots: Array[Variant] = preset["passive_slots"].duplicate(true)
	passive_slots[0] = _selected_option(passive_slot)
	var equipped: Dictionary[StringName, Variant] = preset["equipped"].duplicate(true)
	equipped[&"weapon"] = _selected_option(weapon_selector)
	equipped[&"armor"] = _selected_option(armor_selector)
	equipped[&"accessory"] = _selected_option(accessory_selector)
	return _show_result(facade.update_preset(_request_id("build"), profile.revision, character.character_id, character.selected_preset, active_slots, passive_slots, equipped), "Preset salvo.")

func _start_run() -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null or profile.selected_character_id.is_empty():
		return _show_result({"ok": false, "error_code": &"invalid_character_id"})
	var result: Dictionary = facade.start_run(_request_id("start"), profile.revision)
	if result.get("ok", false):
		RunController.pending_run_state = result["run_state"]
		RunController.pending_run_facade = facade
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	return _show_result(result, "Run iniciada.")

func _selected_option(selector: OptionButton) -> Variant:
	if selector.selected < 0:
		return null
	return selector.get_item_metadata(selector.selected)

func _populate_build_editor(character: Variant) -> void:
	var options: Dictionary = facade.available_build_options(character.character_id)
	if not options.get("ok", false):
		return
	var preset: Dictionary = character.presets[character.selected_preset]
	_populate_selector(active_slot_a, options["active_skills"], preset["active_slots"][0])
	_populate_selector(active_slot_b, options["active_skills"], preset["active_slots"][1])
	_populate_selector(passive_slot, options["passive_skills"], preset["passive_slots"][0])
	_populate_selector(weapon_selector, options["equipment_by_slot"][&"weapon"], preset["equipped"][&"weapon"])
	_populate_selector(armor_selector, options["equipment_by_slot"][&"armor"], preset["equipped"][&"armor"])
	_populate_selector(accessory_selector, options["equipment_by_slot"][&"accessory"], preset["equipped"][&"accessory"])

func _populate_selector(selector: OptionButton, values: Array, current: Variant) -> void:
	selector.clear()
	selector.add_item("Nenhum")
	selector.set_item_metadata(0, null)
	var current_index := 0
	for value: Variant in values:
		var item_id: StringName = StringName(value)
		selector.add_item(_skill_name(item_id) if selector in [active_slot_a, active_slot_b, passive_slot] else _equipment_name(item_id))
		var index := selector.item_count - 1
		selector.set_item_metadata(index, item_id)
		if value == current:
			current_index = index
	selector.select(current_index)

func _show_result(result: Dictionary, success_text: String = "Perfil atualizado.") -> Dictionary:
	var ok: bool = result.get("ok", false)
	if ok:
		_read_only = false
	elif result.has("read_only"):
		_read_only = result["read_only"]
	if ok:
		status_label.text = success_text if not result.get("already_applied", false) else "Essa escolha já está ativa."
	else:
		status_label.text = _error_text(StringName(result.get("error_code", &"unknown")), result.get("read_only", false))
	_refresh()
	return result

func _refresh() -> void:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null:
		roster_list.clear()
		empty_label.visible = true
		empty_label.text = "Não foi possível carregar os personagens."
		for button: Button in create_buttons:
			button.disabled = true
		select_button.disabled = true
		build_summary_label.text = "Build indisponível enquanto o perfil não puder ser lido."
		preset_selector.disabled = true
		save_build_button.disabled = true
		start_run_button.disabled = true
		return
	roster_list.clear()
	_selected_index = -1
	for character: Variant in profile.characters:
		var selected := "  • selecionado" if character.character_id == profile.selected_character_id else ""
		roster_list.add_item("%s — %s%s" % [character.display_name, _class_name(character.base_class_id), selected])
		if character.character_id == profile.selected_character_id:
			_selected_index = roster_list.item_count - 1
	if _selected_index >= 0:
		roster_list.select(_selected_index)
		_populate_build_editor(profile.characters[_selected_index])
		preset_selector.select(profile.characters[_selected_index].selected_preset)
		build_summary_label.text = _build_summary(profile.characters[_selected_index])
	else:
		build_summary_label.text = "Selecione ou crie um personagem para ver a build inicial."
	empty_label.visible = roster_list.item_count == 0
	empty_label.text = "Nenhum personagem criado. Crie seu primeiro alt para começar."
	var locked := _read_only
	for button: Button in create_buttons:
		button.disabled = locked or profile.characters.size() >= MAX_CHARACTERS
	select_button.disabled = locked or _selected_index < 0
	preset_selector.disabled = locked or _selected_index < 0
	save_build_button.disabled = locked or _selected_index < 0
	start_run_button.disabled = locked or profile.selected_character_id.is_empty()
	if profile.characters.size() >= MAX_CHARACTERS:
		status_label.text = "Limite de %d personagens atingido." % MAX_CHARACTERS

func _error_text(error_code: StringName, read_only: bool) -> String:
	if read_only:
		return "Perfil em modo somente leitura. %s" % _error_text(error_code, false)
	match error_code:
		&"save_in_progress": return "O perfil ainda está sendo salvo. Tente novamente em instantes."
		&"stale_revision": return "O perfil mudou; a lista foi atualizada. Escolha novamente."
		&"character_limit": return "Você atingiu o limite de personagens."
		&"run_active": return "Há uma run ativa. Volte ao menu após encerrá-la."
		&"invalid_origin": return "Essa classe ainda não está disponível."
		&"invalid_character_id": return "O personagem selecionado não existe mais. Escolha outro personagem."
		&"invalid_presets": return "O preset contém skills inválidas ou repetidas. Revise os slots escolhidos."
		&"invalid_equipment": return "O equipamento escolhido não pertence a este personagem ou ao slot informado."
		&"invalid_loadout": return "Configure ao menos uma skill ativa válida antes de iniciar a run."
		&"recovery_required": return "Há uma gravação pendente que precisa ser recuperada antes de iniciar uma run."
		&"unsupported_schema": return "Este perfil foi criado por uma versão mais nova do jogo."
		&"invalid_catalog": return "O catálogo de personagem está incompatível com este perfil."
		&"save_failed": return "Não foi possível salvar o perfil. Nenhuma alteração foi confirmada."
		_: return "Não foi possível atualizar o perfil (%s)." % error_code

func _class_name(base_class_id: StringName) -> String:
	match base_class_id:
		&"swordsman": return "Espadachim"
		&"mage": return "Mago"
		_: return "Classe indisponível"

func _build_summary(character: Variant) -> String:
	var preset: Dictionary = character.presets[character.selected_preset]
	var attributes: Dictionary = IdentityIds.initial_attributes(character.base_class_id)
	for attribute_id: StringName in IdentityIds.attribute_ids():
		attributes[attribute_id] = int(attributes.get(attribute_id, 0)) + int(character.attribute_allocations.get(attribute_id, 0))
	var derived_stats: Dictionary = RpgStats.derive(attributes)
	var active: Array[String] = []
	for skill_id: Variant in preset["active_slots"]:
		if skill_id != null:
			active.append(_skill_name(skill_id))
	var passive: Array[String] = []
	for skill_id: Variant in preset["passive_slots"]:
		if skill_id != null:
			passive.append(_skill_name(skill_id))
	var weapon: Variant = preset["equipped"].get(&"weapon")
	return "Build inicial\nAtivas: %s\nPassiva: %s\nArma: %s\nStats: Vida %d · Mana %d · Ataque físico %d · Ataque mágico %d\nAtributos livres e progressão serão liberados no contrato E03." % [", ".join(active), ", ".join(passive), _equipment_name(weapon), int(derived_stats["max_hp"]), int(derived_stats["max_mana"]), int(derived_stats["physical_attack"]), int(derived_stats["magic_attack"])]

func _skill_name(skill_id: Variant) -> String:
	match StringName(skill_id):
		&"slash": return "Corte"
		&"dash": return "Investida"
		&"swordsman_resistance": return "Resistência"
		&"fireball": return "Bola de fogo"
		&"fire_wall": return "Parede de fogo"
		&"mage_mana_regeneration": return "Regeneração de mana"
		_: return "Skill indisponível"

func _equipment_name(item_id: Variant) -> String:
	var normalized_id: StringName = StringName(item_id) if item_id != null else &""
	match normalized_id:
		&"training_sword": return "Espada de treino"
		&"apprentice_staff": return "Cajado de aprendiz"
		_: return "Nenhuma"

func _request_id(action: String) -> String:
	_request_serial += 1
	return "character-menu-%s-%d" % [action, _request_serial]

func _layout_panel() -> void:
	if menu_panel == null:
		return
	var half_height := clampf(get_viewport_rect().size.y * 0.5 - 20.0, 96.0, 300.0)
	menu_panel.offset_top = -half_height
	menu_panel.offset_bottom = half_height

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	menu_panel = VBoxContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.offset_left = -410
	menu_panel.offset_right = 410
	menu_panel.add_theme_constant_override("separation", 14)
	add_child(menu_panel)
	var title := Label.new()
	title.text = "RagRPG — Personagens"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	menu_panel.add_child(title)
	status_label = Label.new()
	status_label.name = "ProfileStatus"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_panel.add_child(status_label)
	menu_scroll = ScrollContainer.new()
	menu_scroll.name = "MenuScroll"
	menu_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	menu_panel.add_child(menu_scroll)
	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 18)
	menu_scroll.add_child(content)
	var roster_column := VBoxContainer.new()
	roster_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(roster_column)
	var roster_title := Label.new()
	roster_title.text = "Seus personagens"
	roster_title.add_theme_font_size_override("font_size", 22)
	roster_column.add_child(roster_title)
	roster_list = ItemList.new()
	roster_list.name = "CharacterRoster"
	roster_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_list.item_selected.connect(_select_roster_index)
	roster_list.item_activated.connect(select_character_at)
	roster_column.add_child(roster_list)
	empty_label = Label.new()
	empty_label.name = "EmptyState"
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster_column.add_child(empty_label)
	select_button = Button.new()
	select_button.text = "Selecionar personagem"
	select_button.custom_minimum_size = Vector2(0, 44)
	select_button.pressed.connect(_select_current_character)
	roster_column.add_child(select_button)
	preset_selector = OptionButton.new()
	preset_selector.name = "PresetSelector"
	preset_selector.add_item("Preset 1")
	preset_selector.add_item("Preset 2")
	preset_selector.item_selected.connect(_choose_preset)
	roster_column.add_child(preset_selector)
	build_summary_label = Label.new()
	build_summary_label.name = "BuildSummary"
	build_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster_column.add_child(build_summary_label)
	var editor_title := Label.new()
	editor_title.text = "Editar preset legal"
	editor_title.add_theme_font_size_override("font_size", 18)
	roster_column.add_child(editor_title)
	active_slot_a = _build_selector(roster_column, "Ativa 1")
	active_slot_b = _build_selector(roster_column, "Ativa 2")
	passive_slot = _build_selector(roster_column, "Passiva")
	weapon_selector = _build_selector(roster_column, "Arma")
	armor_selector = _build_selector(roster_column, "Armadura")
	accessory_selector = _build_selector(roster_column, "Acessório")
	save_build_button = Button.new()
	save_build_button.text = "Salvar preset"
	save_build_button.custom_minimum_size = Vector2(0, 40)
	save_build_button.pressed.connect(_save_build)
	roster_column.add_child(save_build_button)
	var create_column := VBoxContainer.new()
	create_column.custom_minimum_size = Vector2(310, 0)
	create_column.add_theme_constant_override("separation", 10)
	content.add_child(create_column)
	var create_title := Label.new()
	create_title.text = "Criar personagem"
	create_title.add_theme_font_size_override("font_size", 22)
	create_column.add_child(create_title)
	var description := Label.new()
	description.text = "Escolha uma classe disponível. A build será configurada no próximo passo do menu."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create_column.add_child(description)
	name_input = LineEdit.new()
	name_input.name = "CharacterName"
	name_input.placeholder_text = "Nome do personagem (opcional)"
	name_input.max_length = 48
	create_column.add_child(name_input)
	for class_id: StringName in [&"swordsman", &"mage"]:
		var button := Button.new()
		button.text = "Criar %s" % _class_name(class_id)
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(create_character.bind(class_id))
		create_column.add_child(button)
		create_buttons.append(button)
		if class_id == &"swordsman":
			create_button = button
	var notice := Label.new()
	notice.text = "A arena será liberada após a configuração de build."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create_column.add_child(notice)
	start_run_button = Button.new()
	start_run_button.name = "StartRun"
	start_run_button.text = "Iniciar run com este personagem"
	start_run_button.tooltip_text = "Abrir a arena usando o personagem selecionado"
	start_run_button.custom_minimum_size = Vector2(0, 48)
	start_run_button.pressed.connect(_start_run)
	menu_panel.add_child(start_run_button)

func _build_selector(parent: Container, label_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(82, 0)
	row.add_child(label)
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(190, 32)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(selector)
	return selector
